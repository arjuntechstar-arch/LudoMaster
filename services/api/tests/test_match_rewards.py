import importlib

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.match import Match, MatchPlayer
from app.models.profile import PlayerStats
from app.models.mission import UserMission
from app.models.achievement import UserAchievement
from app.models.season import UserSeasonProgress
from services.realtime.engine.ludo_server_engine import LudoServerEngine
from services.realtime.engine.models import Color, Seat, TokenLocation


@pytest.mark.asyncio
async def test_completed_online_match_awards_progress_once(
    client: AsyncClient, db_session: AsyncSession, monkeypatch,
):
    players = []
    for index in range(2):
        response = await client.post(
            "/api/v1/auth/guest", json={"device_id": f"match_reward_{index}"}
        )
        assert response.status_code == 200
        players.append(response.json()["user_id"])

    match = Match(mode="CLASSIC", status="ACTIVE")
    db_session.add(match)
    await db_session.flush()
    match_id = match.id
    for seat, user_id in enumerate(players):
        db_session.add(MatchPlayer(
            match_id=match_id, user_id=user_id, seat_index=seat,
            color=["RED", "GREEN"][seat], is_bot=False,
        ))
    await db_session.commit()

    seats = [
        Seat(seat_index=seat, user_id=user_id, display_name=f"Player {seat}",
             avatar_id="avatar_0", color=[Color.RED, Color.GREEN][seat])
        for seat, user_id in enumerate(players)
    ]
    engine = LudoServerEngine(match_id, seats)
    engine.placements = [0, 1]
    for token in seats[0].tokens:
        token.location = TokenLocation.HOME

    realtime = importlib.import_module("services.realtime.session_manager")
    maker = async_sessionmaker(bind=db_session.bind, expire_on_commit=False)
    monkeypatch.setattr(realtime, "async_session_maker", maker)
    session = realtime.GameSession(match_id, engine)
    session.sequence = 4
    results = [
        {"seatIndex": 0, "userId": players[0], "placement": 1,
         "coinsDelta": 0, "xpGained": 190, "captures": 1, "tokensHome": 4},
        {"seatIndex": 1, "userId": players[1], "placement": 2,
         "coinsDelta": 0, "xpGained": 70, "captures": 0, "tokensHome": 0},
    ]
    await session._persist_match_completion(results, 0)
    await session._persist_match_completion(results, 0)

    db_session.expire_all()
    saved = (await db_session.execute(select(Match).where(Match.id == match_id))).scalar_one()
    assert saved.status == "COMPLETED"
    assert saved.winner_user_id == players[0]
    stats = (await db_session.execute(
        select(PlayerStats).where(PlayerStats.user_id == players[0])
    )).scalar_one()
    assert stats.matches_played == 1
    assert stats.matches_won == 1
    assert stats.total_captures == 1
    assert stats.total_tokens_home == 4
    missions = (await db_session.execute(
        select(UserMission).where(UserMission.user_id == players[0])
    )).scalars().all()
    assert any(m.mission_id == "m_daily_play_1" and m.is_completed for m in missions)
    badges = (await db_session.execute(
        select(UserAchievement).where(UserAchievement.user_id == players[0])
    )).scalars().all()
    assert any(a.achievement_id == "ach_first_win" and a.is_unlocked for a in badges)
    season = (await db_session.execute(
        select(UserSeasonProgress).where(UserSeasonProgress.user_id == players[0])
    )).scalar_one()
    assert season.current_xp == 190
