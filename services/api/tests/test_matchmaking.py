import asyncio
from datetime import datetime, timedelta, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.matchmaking import MatchmakingTicket
from app.models.match import Match, MatchPlayer
from app.services.matchmaker import matchmaker_service

@pytest.mark.asyncio
async def test_matchmaking_enqueue_and_cancel(client: AsyncClient):
    # 1. Login user
    auth_res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "mm_user_cancel_1", "platform": "ANDROID"},
    )
    assert auth_res.status_code == 200
    token = auth_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Enqueue for 4 players (won't match immediately because need 4 or timeout)
    enqueue_res = await client.post(
        "/api/v1/matchmaking/enqueue",
        json={"mode": "CLASSIC", "player_count": 4, "bet_coins": 100},
        headers=headers,
    )
    assert enqueue_res.status_code == 201
    ticket = enqueue_res.json()
    ticket_id = ticket["ticket_id"]
    assert ticket["status"] in ("QUEUED", "MATCHED")

    if ticket["status"] == "QUEUED":
        # 3. Check status
        poll_res = await client.get(
            f"/api/v1/matchmaking/ticket/{ticket_id}",
            headers=headers,
        )
        assert poll_res.status_code == 200
        assert poll_res.json()["ticket_id"] == ticket_id

        # 4. Cancel
        cancel_res = await client.post(
            f"/api/v1/matchmaking/ticket/{ticket_id}/cancel",
            headers=headers,
        )
        assert cancel_res.status_code == 200
        assert cancel_res.json()["status"] == "CANCELLED"

@pytest.mark.asyncio
async def test_matchmaking_pair_two_players(client: AsyncClient, db_session: AsyncSession):
    # Login player 1
    p1_res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "mm_p1_dev", "platform": "ANDROID"},
    )
    p1_token = p1_res.json()["access_token"]
    p1_headers = {"Authorization": f"Bearer {p1_token}"}

    # Login player 2
    p2_res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "mm_p2_dev", "platform": "IOS"},
    )
    p2_token = p2_res.json()["access_token"]
    p2_headers = {"Authorization": f"Bearer {p2_token}"}

    # Player 1 enqueues for 2-player match
    t1_res = await client.post(
        "/api/v1/matchmaking/enqueue",
        json={"mode": "CLASSIC", "player_count": 2, "bet_coins": 500},
        headers=p1_headers,
    )
    assert t1_res.status_code == 201
    t1_data = t1_res.json()
    assert t1_data["status"] == "QUEUED"

    # Player 2 enqueues for 2-player match
    t2_res = await client.post(
        "/api/v1/matchmaking/enqueue",
        json={"mode": "CLASSIC", "player_count": 2, "bet_coins": 500},
        headers=p2_headers,
    )
    assert t2_res.status_code == 201
    t2_data = t2_res.json()

    # Now both should be matched!
    assert t2_data["status"] == "MATCHED"
    assert t2_data["matched_match_id"] is not None

    # Check player 1's ticket
    p1_check = await client.get(
        f"/api/v1/matchmaking/ticket/{t1_data['ticket_id']}",
        headers=p1_headers,
    )
    assert p1_check.status_code == 200
    assert p1_check.json()["status"] == "MATCHED"
    assert p1_check.json()["matched_match_id"] == t2_data["matched_match_id"]

    # Verify match players in db
    match_id = t2_data["matched_match_id"]
    q = select(MatchPlayer).where(MatchPlayer.match_id == match_id)
    res = await db_session.execute(q)
    players = res.scalars().all()
    assert len(players) == 2
    user_ids = {p.user_id for p in players}
    assert p1_res.json()["user_id"] in user_ids
    assert p2_res.json()["user_id"] in user_ids

@pytest.mark.asyncio
async def test_matchmaking_bot_fill(client: AsyncClient, db_session: AsyncSession):
    # Login player
    res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "mm_bot_fill_p1", "platform": "ANDROID"},
    )
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Enqueue for 4 players
    enqueue_res = await client.post(
        "/api/v1/matchmaking/enqueue",
        json={"mode": "CLASSIC", "player_count": 4, "bet_coins": 100},
        headers=headers,
    )
    assert enqueue_res.status_code == 201
    ticket_id = enqueue_res.json()["ticket_id"]

    # Backdate ticket created_at to trigger bot fill (> 5 seconds ago)
    q = select(MatchmakingTicket).where(MatchmakingTicket.id == ticket_id)
    t = (await db_session.execute(q)).scalar_one()
    t.created_at = datetime.now(timezone.utc) - timedelta(seconds=10)
    await db_session.commit()

    # Poll ticket via API which re-evaluates queue and bot fills
    poll_res = await client.get(
        f"/api/v1/matchmaking/ticket/{ticket_id}",
        headers=headers,
    )
    assert poll_res.status_code == 200
    poll_data = poll_res.json()
    assert poll_data["status"] == "MATCHED"
    assert poll_data["matched_match_id"] is not None

    # Verify match has 1 human and 3 bots
    q_players = select(MatchPlayer).where(MatchPlayer.match_id == poll_data["matched_match_id"])
    players = (await db_session.execute(q_players)).scalars().all()
    assert len(players) == 4
    bots = [p for p in players if p.is_bot]
    humans = [p for p in players if not p.is_bot]
    assert len(humans) == 1
    assert len(bots) == 3
