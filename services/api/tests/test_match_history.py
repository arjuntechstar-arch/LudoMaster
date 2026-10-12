import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.match import Match, MatchPlayer

@pytest.mark.asyncio
async def test_match_history_and_recent_players(client: AsyncClient, db_session: AsyncSession):
    # 1. Login player 1 & player 2
    p1_res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "hist_p1_dev", "platform": "ANDROID"},
    )
    p1_id = p1_res.json()["user_id"]
    p1_token = p1_res.json()["access_token"]
    p1_headers = {"Authorization": f"Bearer {p1_token}"}

    p2_res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "hist_p2_dev", "platform": "IOS"},
    )
    p2_id = p2_res.json()["user_id"]
    p2_token = p2_res.json()["access_token"]

    # 2. Insert completed match in db
    match = Match(
        room_id=None,
        mode="CLASSIC",
        status="COMPLETED",
        winner_user_id=p1_id,
    )
    db_session.add(match)
    await db_session.flush()

    mp1 = MatchPlayer(
        match_id=match.id,
        user_id=p1_id,
        seat_index=0,
        color="RED",
        is_bot=False,
        placement=1,
        coins_delta=250,
        xp_gained=50,
    )
    mp2 = MatchPlayer(
        match_id=match.id,
        user_id=p2_id,
        seat_index=1,
        color="GREEN",
        is_bot=False,
        placement=2,
        coins_delta=-250,
        xp_gained=10,
    )
    db_session.add_all([mp1, mp2])
    await db_session.commit()

    # 3. Query match history for player 1
    history_res = await client.get("/api/v1/matches/my-history", headers=p1_headers)
    assert history_res.status_code == 200
    data = history_res.json()
    assert len(data["matches"]) == 1
    item = data["matches"][0]
    assert item["id"] == match.id
    assert item["mode"] == "CLASSIC"
    assert item["my_placement"] == 1
    assert len(item["players"]) == 2

    # 4. Query recent players for player 1
    recent_res = await client.get("/api/v1/players/recent", headers=p1_headers)
    assert recent_res.status_code == 200
    recent_players = recent_res.json()
    assert len(recent_players) == 1
    assert recent_players[0]["user_id"] == p2_id
