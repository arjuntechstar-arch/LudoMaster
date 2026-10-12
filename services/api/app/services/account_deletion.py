"""Remove personal account data when the account owner confirms deletion.

The non-authenticating user stub keeps shared match, abuse and transaction
records referentially valid. It must never be used to recreate player progress.
"""
import json
from sqlalchemy import delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models import (
    Block, Club, ClubMember, Device, Friendship, GameEvent, GameSnapshot,
    MatchPlayer, MatchmakingTicket, Notification, RefreshSession, Room,
    RoomInvite, RoomMember, Tournament, TournamentParticipant, User,
    UserAchievement, UserDailyReward, UserIdentity, UserInventory, UserMission,
    UserSeasonProgress,
)


def redact_player(value, user_id: str):
    """Remove profile/chat fields while preserving shared game mechanics."""
    if isinstance(value, list):
        return [redact_player(item, user_id) for item in value]
    if not isinstance(value, dict):
        return value
    own = value.get("userId") == user_id or value.get("user_id") == user_id
    result = {key: redact_player(item, user_id) for key, item in value.items()}
    if own:
        # Internal IDs remain only to interpret shared results and abuse records.
        for key in ("displayName", "display_name", "name"):
            if key in result:
                result[key] = "Deleted User"
        for key in ("username", "email", "deviceId", "device_id"):
            if key in result:
                result[key] = None
        for key in ("avatarId", "avatar_id"):
            if key in result:
                result[key] = "avatar_0"
        for key in ("countryCode", "country_code"):
            if key in result:
                result[key] = "XX"
        for key in ("message", "text"):
            if key in result:
                result[key] = "[removed]"
    return result


async def remove_account_data(db: AsyncSession, user: User) -> None:
    # Settlement takes the same lock so it cannot restore progress after deletion.
    await db.execute(select(User.id).where(User.id == user.id).with_for_update())
    user.status = "DELETED"
    user.is_verified = False
    if user.profile:
        user.profile.username = None
        user.profile.display_name = "Deleted User"
        user.profile.avatar_id = "avatar_0"
        user.profile.country_code = "XX"
        user.profile.level = 1
        user.profile.xp = 0
    if user.stats:
        for field in ("matches_played", "matches_won", "win_streak", "best_streak",
                      "total_captures", "total_tokens_home"):
            setattr(user.stats, field, 0)
    # Keep the ledger and closed wallet consistent for purchase/fraud
    # reconciliation. A deleted account cannot access or spend this balance.

    memberships = select(ClubMember.club_id).where(ClubMember.user_id == user.id)
    clubs = (await db.execute(select(Club).where(or_(
        Club.leader_user_id == user.id, Club.id.in_(memberships)
    )).with_for_update())).scalars().all()
    for club in clubs:
        remaining = [member for member in club.members if member.user_id != user.id]
        if not remaining:
            await db.delete(club)
        else:
            club.member_count = len(remaining)
            if club.leader_user_id == user.id:
                successor = min(remaining, key=lambda member: (member.joined_at, member.id))
                club.leader_user_id = successor.user_id
                successor.role = "LEADER"

    rooms = (await db.execute(select(Room).where(
        Room.host_user_id == user.id
    ).with_for_update())).scalars().all()
    for room in rooms:
        remaining = [member for member in room.members if member.user_id != user.id]
        if remaining:
            successor = min(remaining, key=lambda member: member.seat_index)
            room.host_user_id = successor.user_id
            successor.is_host = True
        else:
            # No other player needs this room; match FK uses SET NULL.
            await db.delete(room)

    # Withdrawal is safe before a championship starts. Started brackets retain
    # a nameless internal participant to preserve the other players' results.
    registrations = (await db.execute(select(TournamentParticipant).join(Tournament).where(
        TournamentParticipant.user_id == user.id, Tournament.status == "REGISTRATION"
    ))).scalars().all()
    for registration in registrations:
        tournament = await db.get(Tournament, registration.tournament_id)
        tournament.current_participants = max(0, tournament.current_participants - 1)
        await db.delete(registration)

    invite_ids = set((await db.execute(select(RoomInvite.id).where(or_(
        RoomInvite.sender_id == user.id, RoomInvite.recipient_id == user.id
    )))).scalars().all())
    if invite_ids:
        # Also remove the counterpart's notification containing the old name.
        notifications = (await db.execute(select(Notification).where(
            Notification.category == "INVITE", Notification.data_payload.is_not(None)
        ))).scalars().all()
        for notification in notifications:
            try:
                payload = json.loads(notification.data_payload)
            except (ValueError, TypeError):
                continue
            if isinstance(payload, dict) and payload.get("invite_id") in invite_ids:
                await db.delete(notification)

    match_ids = select(MatchPlayer.match_id).where(MatchPlayer.user_id == user.id)
    for model, field in ((GameSnapshot, "state_json"), (GameEvent, "payload")):
        records = (await db.execute(select(model).where(
            model.match_id.in_(match_ids), getattr(model, field).contains(user.id)
        ))).scalars().all()
        for record in records:
            original = getattr(record, field)
            try:
                value = json.loads(original)
            except (ValueError, TypeError):
                # Legacy malformed payloads cannot be safely attributed.
                # They are not needed to interpret the structured match result.
                setattr(record, field, "{}")
            else:
                setattr(record, field, json.dumps(redact_player(value, user.id)))

    await db.flush()
    for model in (UserIdentity, Device, RefreshSession, UserInventory, UserMission,
                  UserAchievement, UserDailyReward, UserSeasonProgress, Notification,
                  MatchmakingTicket, RoomMember, ClubMember):
        await db.execute(delete(model).where(model.user_id == user.id))
    for model, left, right in (
        (Friendship, Friendship.user_id, Friendship.friend_user_id),
        (Block, Block.blocker_id, Block.blocked_id),
        (RoomInvite, RoomInvite.sender_id, RoomInvite.recipient_id),
    ):
        await db.execute(delete(model).where(or_(left == user.id, right == user.id)))
    await db.commit()


async def remove_live_account(user_id: str) -> None:
    from services.realtime.session_manager import session_manager

    for session in list(session_manager.sessions.values()):
        await session.remove_account(user_id)
