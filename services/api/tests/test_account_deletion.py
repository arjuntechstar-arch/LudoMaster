import json
from contextlib import asynccontextmanager
from unittest.mock import AsyncMock
import pytest
from sqlalchemy import func, select
from app.models import (
    Block, CatalogItem, Club, ClubMember, Device, Friendship, GameEvent,
    GameSnapshot, Match, MatchPlayer, MatchmakingTicket, Notification,
    RefreshSession, Report, Room, RoomInvite, RoomMember, Tournament,
    TournamentParticipant, User, UserAchievement, UserDailyReward,
    UserIdentity, UserInventory, UserMission, UserSeasonProgress, WalletLedger,
)
from app.services.account_deletion import remove_account_data
from app.services.rewards_service import rewards_service
from app.services.season_service import SeasonService
from services.realtime import gateway
from services.realtime.engine.ludo_server_engine import LudoServerEngine
from services.realtime.engine.models import Color, Seat
from services.realtime.session_manager import GameSession, SessionManager


async def login(client, suffix):
    response = await client.post('/api/v1/auth/guest', json={
        'device_id': f'deletion-review-{suffix}', 'platform': 'ANDROID', 'app_version': '1.0.5',
    })
    assert response.status_code == 200
    data = response.json()
    return data, {'Authorization': f'Bearer {data["access_token"]}'}


@pytest.mark.asyncio
async def test_deletion_removes_private_rows_preserves_other_players(client, db_session):
    data, headers = await login(client, 'owner')
    peer_data, _ = await login(client, 'peer')
    owner = await db_session.get(User, data['user_id'])
    peer = await db_session.get(User, peer_data['user_id'])
    owner.profile.username = 'remove_this_name'
    owner.profile.display_name = 'Private Name'
    await rewards_service.ensure_user_missions(db_session, owner.id)
    await rewards_service.ensure_user_achievements(db_session, owner.id)
    season = await SeasonService.seed_default_season(db_session)
    await SeasonService.get_or_create_user_progress(db_session, owner.id, season.id)
    db_session.add(CatalogItem(id='deletion-item', name='Review item', category='AVATAR',
                              description='Review avatar', asset_key='avatar_0'))
    await db_session.flush()
    db_session.add_all([
        UserInventory(user_id=owner.id, item_id='deletion-item'),
        UserDailyReward(user_id=owner.id), MatchmakingTicket(user_id=owner.id),
        Friendship(user_id=owner.id, friend_user_id=peer.id, status='ACCEPTED'),
        Block(blocker_id=peer.id, blocked_id=owner.id),
        Report(reporter_id=peer.id, reported_user_id=owner.id, category='CHEATING'),
        Notification(user_id=owner.id, title='Personal', body='Private'),
        Room(id='deletion-room', code='DEL123', host_user_id=owner.id),
        Club(id='deletion-club', name='Review club', tag='DEL', leader_user_id=owner.id),
        Tournament(id='deletion-tournament', title='Review tournament', current_participants=1),
        Match(id='deletion-match'),
    ])
    await db_session.flush()
    db_session.add_all([
        RoomMember(room_id='deletion-room', user_id=owner.id, seat_index=0, is_host=True),
        RoomMember(room_id='deletion-room', user_id=peer.id, seat_index=1),
        ClubMember(club_id='deletion-club', user_id=owner.id, role='LEADER'),
        ClubMember(club_id='deletion-club', user_id=peer.id),
        TournamentParticipant(tournament_id='deletion-tournament', user_id=owner.id),
        RoomInvite(id='deletion-invite', room_id='deletion-room', sender_id=owner.id, recipient_id=peer.id),
        Notification(user_id=peer.id, title='Invite', body='Private Name invites you',
                     category='INVITE', data_payload=json.dumps({'invite_id': 'deletion-invite'})),
        Notification(user_id=peer.id, title='Keep this', body='Other information'),
        MatchPlayer(match_id='deletion-match', user_id=owner.id, seat_index=0, color='RED'),
        MatchPlayer(match_id='deletion-match', user_id=peer.id, seat_index=1, color='GREEN'),
        GameSnapshot(match_id='deletion-match', sequence=1, state_json=json.dumps({'seats': [
            {'userId': owner.id, 'displayName': 'Private Name', 'avatarId': 'avatar_7', 'username': 'remove_this_name'},
            {'userId': peer.id, 'displayName': 'Keep Peer'},
        ]})),
        GameEvent(match_id='deletion-match', sequence=2, event_type='CHAT_MESSAGE',
                  payload=json.dumps({'userId': owner.id, 'displayName': 'Private Name', 'message': 'Private message'})),
    ])
    await db_session.commit()
    # Reload collections because the dependency and setup use the same session.
    db_session.expire_all()
    response = await client.post('/api/v1/auth/delete-account', headers=headers)
    assert response.status_code == 200
    db_session.expire_all()
    deleted = await db_session.get(User, data['user_id'])
    peer = await db_session.get(User, peer_data['user_id'])
    assert deleted.status == 'DELETED'
    assert deleted.profile.username is None
    assert deleted.profile.display_name == 'Deleted User'
    assert deleted.profile.level == 1 and deleted.profile.xp == 0
    for model in (UserIdentity, Device, RefreshSession, UserInventory, UserMission,
                  UserAchievement, UserDailyReward, UserSeasonProgress, Notification,
                  MatchmakingTicket, RoomMember, ClubMember, TournamentParticipant):
        assert await db_session.scalar(select(func.count()).select_from(model).where(model.user_id == deleted.id)) == 0
    for model in (Friendship, Block, RoomInvite):
        assert await db_session.scalar(select(func.count()).select_from(model)) == 0
    room = await db_session.get(Room, 'deletion-room')
    assert room.host_user_id == peer.id and room.members[0].is_host
    club = await db_session.get(Club, 'deletion-club')
    assert club.leader_user_id == peer.id and club.member_count == 1
    assert club.members[0].role == 'LEADER'
    assert (await db_session.get(Tournament, 'deletion-tournament')).current_participants == 0
    snapshot = (await db_session.scalars(select(GameSnapshot))).one()
    seats = json.loads(snapshot.state_json)['seats']
    assert seats[0]['displayName'] == 'Deleted User' and seats[0]['username'] is None
    assert seats[1]['displayName'] == 'Keep Peer'
    event = (await db_session.scalars(select(GameEvent))).one()
    assert json.loads(event.payload)['message'] == '[removed]'
    assert await db_session.scalar(select(func.count()).select_from(Report)) == 1
    assert await db_session.scalar(select(func.count()).select_from(WalletLedger)) == 2
    assert await db_session.scalar(select(func.count()).select_from(Notification).where(Notification.user_id == peer.id)) == 1
    assert (await client.get('/api/v1/me', headers=headers)).status_code == 403
    assert (await client.post('/api/v1/auth/refresh', json={'refresh_token': data['refresh_token']})).status_code == 401


def game_session(owner_id, peer_id):
    seats = [Seat(seat_index=0, user_id=owner_id, display_name='Private Name', avatar_id='avatar_7', color=Color.RED),
             Seat(seat_index=1, user_id=peer_id, display_name='Keep Peer', avatar_id='avatar_0', color=Color.GREEN)]
    return GameSession('review-live-match', LudoServerEngine(match_id='review-live-match', seats=seats))


@pytest.mark.asyncio
async def test_live_account_deletion_closes_socket_redacts_history():
    session = game_session('closed-owner', 'peer')
    socket = AsyncMock()
    session.connections[0] = socket
    session.event_history = [{'payload': {'userId': 'closed-owner', 'displayName': 'Private Name', 'message': 'Secret'}}]
    await session.remove_account('closed-owner')
    assert 'closed-owner' not in session.user_to_seat
    assert 0 not in session.connections
    assert session.engine.seats[0].is_bot
    assert session.engine.seats[0].display_name == 'Deleted User'
    assert session.event_history[0]['payload']['message'] == '[removed]'
    socket.close.assert_awaited_once_with(code=1000, reason='Account deleted')
    reconnect_socket = AsyncMock()
    await session.handle_connect('closed-owner', reconnect_socket)
    reconnect_socket.close.assert_awaited_once_with(code=1008, reason='Account deleted')
    await session.remove_account('closed-owner')  # Safe to retry.


@pytest.mark.asyncio
async def test_closed_account_cannot_reconnect_or_receive_progress(client, db_session, monkeypatch):
    data, _ = await login(client, 'settlement-owner')
    peer_data, _ = await login(client, 'settlement-peer')
    owner_id, peer_id = data['user_id'], peer_data['user_id']
    session = game_session(owner_id, peer_id)
    db_session.add(Match(id=session.match_id))
    await db_session.flush()
    db_session.add_all([MatchPlayer(match_id=session.match_id, user_id=uid, seat_index=index, color=color)
                       for index, (uid, color) in enumerate([(owner_id, 'RED'), (peer_id, 'GREEN')])])
    await db_session.commit()

    @asynccontextmanager
    async def isolated_session():
        yield db_session
    monkeypatch.setattr(gateway, 'async_session_maker', isolated_session)
    import services.realtime.session_manager as sessions
    monkeypatch.setattr(sessions, 'async_session_maker', isolated_session)
    assert await gateway._can_play(owner_id, session.match_id)
    assert not await gateway._can_play(owner_id, 'other-match')
    owner = await db_session.get(User, owner_id)
    await remove_account_data(db_session, owner)
    assert not await gateway._can_play(owner_id, session.match_id)
    restored = await SessionManager().get_or_create_session(session.match_id, db_session)
    assert restored.engine.seats[0].is_bot
    assert restored.engine.seats[0].display_name == 'Deleted User'
    results = [{'userId': uid, 'seatIndex': index, 'placement': index + 1,
                'coinsDelta': 0, 'xpGained': 120, 'captures': 0, 'tokensHome': 4}
               for index, uid in enumerate([owner_id, peer_id])]
    await session._persist_match_completion(results, 0)
    assert (await db_session.get(Match, session.match_id)).status == 'COMPLETED'
    for model in (UserMission, UserAchievement, UserSeasonProgress):
        assert await db_session.scalar(select(func.count()).select_from(model).where(model.user_id == owner_id)) == 0
    assert owner.profile.xp == 0 and owner.stats.matches_played == 0
    peer = await db_session.get(User, peer_id)
    assert peer.stats.matches_played == 1
    snapshot = (await db_session.scalars(select(GameSnapshot))).one()
    assert json.loads(snapshot.state_json)['seats'][0]['displayName'] == 'Deleted User'
