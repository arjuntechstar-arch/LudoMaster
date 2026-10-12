import pytest
from datetime import datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.tournament import Tournament, TournamentParticipant, TournamentMatch
from app.models.season import Season, UserSeasonProgress
from app.models.wallet import Wallet, WalletLedger
from app.models.match import Match, MatchPlayer
from app.models.notification import Notification
from app.services.economy import EconomyService
from app.services.tournament_service import TournamentService
from app.services.season_service import SeasonService

@pytest.mark.asyncio
async def test_tournaments_flow_and_bracket(db_session: AsyncSession, client: AsyncClient):
    # 1. Register 8 guest users
    users = []
    headers_list = []
    for i in range(8):
        res = await client.post("/api/v1/auth/guest", json={"device_id": f"dev_tourn_user_{i}"})
        assert res.status_code == 200
        data = res.json()
        users.append(data["user_id"])
        headers_list.append({"Authorization": f"Bearer {data['access_token']}"})

    # Give them plenty of coins for entry fee
    for uid in users:
        await EconomyService.record_transaction(
            db=db_session,
            user_id=uid,
            amount=5000,
            currency="COINS",
            reason="TEST_SEEDING",
        )

    # 2. List tournaments
    res = await client.get("/api/v1/tournaments", headers=headers_list[0])
    assert res.status_code == 200
    tournaments = res.json()
    assert len(tournaments) >= 2
    target_tourn = tournaments[0]
    tourn_id = target_tourn["id"]

    # 3. 7 players join
    for i in range(7):
        join_res = await client.post(f"/api/v1/tournaments/{tourn_id}/join", headers=headers_list[i])
        assert join_res.status_code == 200
        join_data = join_res.json()
        assert join_data["current_participants"] == i + 1
        assert join_data["status"] == "REGISTRATION"

    # Attempting to re-join should fail with 400
    rejoin_res = await client.post(f"/api/v1/tournaments/{tourn_id}/join", headers=headers_list[0])
    assert rejoin_res.status_code == 400

    # 4. 8th player joins -> triggers bracket generation & IN_PROGRESS
    final_join_res = await client.post(f"/api/v1/tournaments/{tourn_id}/join", headers=headers_list[7])
    assert final_join_res.status_code == 200
    assert final_join_res.json()["current_participants"] == 8
    assert final_join_res.json()["status"] == "IN_PROGRESS"

    # 5. Check tournament details (bracket matches)
    detail_res = await client.get(f"/api/v1/tournaments/{tourn_id}", headers=headers_list[0])
    assert detail_res.status_code == 200
    detail = detail_res.json()
    assert detail["tournament"]["status"] == "IN_PROGRESS"
    assert len(detail["participants"]) == 8
    assert len(detail["matches"]) == 3  # 2 Semifinals, 1 Final

    # Check match structure: 2 Semis IN_PROGRESS, 1 Final PENDING
    semis = [m for m in detail["matches"] if m["round_number"] == 1]
    final_m = next(m for m in detail["matches"] if m["round_number"] == 2)
    assert len(semis) == 2
    assert all(s["status"] == "IN_PROGRESS" for s in semis)
    assert final_m["status"] == "PENDING"
    assert len(semis[0]["participant_ids"]) == 4
    assert len(semis[1]["participant_ids"]) == 4
    assert all(s["match_id"] for s in semis)
    first_player_notices = (await db_session.execute(
        select(Notification).where(Notification.user_id == users[0])
    )).scalars().all()
    assert any(n.category == "TOURNAMENT" and "semifinal" in n.body for n in first_player_notices)
    for semifinal in semis:
        players = (await db_session.execute(
            select(MatchPlayer).where(MatchPlayer.match_id == semifinal["match_id"])
        )).scalars().all()
        assert {p.user_id for p in players} == set(semifinal["participant_ids"])

    # 6. Complete Semifinal A
    semi_a_players = semis[0]["participant_ids"]
    # Suppose semi_a_players[0] and semi_a_players[1] advance
    await TournamentService.report_match_result(
        db=db_session,
        tournament_id=tourn_id,
        round_number=1,
        match_index=0,
        ranking_user_ids=semi_a_players,  # rank 1, 2 advance; 3, 4 eliminated
    )

    # 7. Complete Semifinal B
    semi_b_players = semis[1]["participant_ids"]
    await TournamentService.report_match_result(
        db=db_session,
        tournament_id=tourn_id,
        round_number=1,
        match_index=1,
        ranking_user_ids=semi_b_players,  # rank 1, 2 advance; 3, 4 eliminated
    )

    # Now Final match must be IN_PROGRESS with 4 finalists
    detail_res2 = await client.get(f"/api/v1/tournaments/{tourn_id}", headers=headers_list[0])
    final_m2 = next(m for m in detail_res2.json()["matches"] if m["round_number"] == 2)
    assert final_m2["status"] == "IN_PROGRESS"
    assert final_m2["match_id"]
    expected_finalists = [semi_a_players[0], semi_a_players[1], semi_b_players[0], semi_b_players[1]]
    finalist_notices = (await db_session.execute(
        select(Notification).where(Notification.user_id == expected_finalists[0])
    )).scalars().all()
    assert any(n.category == "TOURNAMENT" and "final" in n.title.lower() for n in finalist_notices)
    assert len(final_m2["participant_ids"]) == 4
    assert final_m2["participant_ids"] == expected_finalists

    # 8. Complete Grand Final
    # Ranking in Final: 1st: semi_a_players[0], 2nd: semi_b_players[0], 3rd: semi_a_players[1], 4th: semi_b_players[1]
    final_ranking = [semi_a_players[0], semi_b_players[0], semi_a_players[1], semi_b_players[1]]
    await TournamentService.report_match_result(
        db=db_session,
        tournament_id=tourn_id,
        round_number=2,
        match_index=0,
        ranking_user_ids=final_ranking,
    )

    # 9. Verify Tournament is COMPLETED, winner set, and prizes awarded in ledger
    completed_res = await client.get(f"/api/v1/tournaments/{tourn_id}", headers=headers_list[0])
    comp_data = completed_res.json()
    assert comp_data["tournament"]["status"] == "COMPLETED"
    assert comp_data["tournament"]["winner_user_id"] == final_ranking[0]

    # Verify prize splits in ledger
    # 1st place winner gets 60% of prize_pool_coins (3000 * 0.6 = 1800) and prize_pool_gems (25 * 0.6 = 15)
    winner_wallet = await EconomyService.get_wallet_balance(db_session, final_ranking[0])
    assert winner_wallet["coins"] > 5000  # starting 1000 + 5000 - 500 + 1800 = 7300
    assert winner_wallet["gems"] >= 25    # starting 10 + 15 = 25

    # Check that ledger entry has TOURNAMENT_PRIZE reason
    winner_ledgers = await db_session.execute(
        select(WalletLedger)
        .join(Wallet, Wallet.id == WalletLedger.wallet_id)
        .where(Wallet.user_id == final_ranking[0])
    )
    reasons = [l.reason for l in winner_ledgers.scalars().all()]
    assert any("TOURNAMENT_PRIZE" in r for r in reasons)


@pytest.mark.asyncio
async def test_seasons_and_tier_progression(db_session: AsyncSession, client: AsyncClient):
    # 1. Login user
    res = await client.post("/api/v1/auth/guest", json={"device_id": "dev_season_user_1"})
    user_id = res.json()["user_id"]
    headers = {"Authorization": f"Bearer {res.json()['access_token']}"}

    # 2. Get current season
    s_res = await client.get("/api/v1/seasons/current", headers=headers)
    assert s_res.status_code == 200
    s_data = s_res.json()
    assert s_data["is_active"] is True
    assert len(s_data["tiers"]) >= 10
    assert s_data["current_xp"] == 0
    assert s_data["current_tier"] == 1
    assert s_data["has_premium_pass"] is False

    tier_1 = s_data["tiers"][0]
    tier_1_xp = tier_1["xp_required"]

    # 3. Attempting to claim before reaching XP must fail (400)
    claim_fail = await client.post(
        "/api/v1/seasons/claim",
        headers=headers,
        json={"tier_number": 1, "is_premium": False},
    )
    assert claim_fail.status_code == 400

    # 4. Award Season XP
    await SeasonService.add_season_xp(db_session, user_id, tier_1_xp + 50)

    # Verify XP updated
    s_res2 = await client.get("/api/v1/seasons/current", headers=headers)
    assert s_res2.json()["current_xp"] >= tier_1_xp
    assert s_res2.json()["tiers"][0]["is_unlocked"] is True

    # 5. Claim free tier reward successfully
    claim_res = await client.post(
        "/api/v1/seasons/claim",
        headers=headers,
        json={"tier_number": 1, "is_premium": False},
    )
    assert claim_res.status_code == 200
    claim_data = claim_res.json()
    assert claim_data["tier_number"] == 1
    assert claim_data["coins_awarded"] > 0

    # 6. Duplicate claim must fail (400)
    dup_res = await client.post(
        "/api/v1/seasons/claim",
        headers=headers,
        json={"tier_number": 1, "is_premium": False},
    )
    assert dup_res.status_code == 400

    # 7. Claiming premium without premium pass must fail (400)
    prem_fail = await client.post(
        "/api/v1/seasons/claim",
        headers=headers,
        json={"tier_number": 1, "is_premium": True},
    )
    assert prem_fail.status_code == 400

    # 8. Buy this season's Royal Pass with earned gems.
    await EconomyService.record_transaction(
        db_session, user_id, s_data["premium_pass_cost_gems"], "GEMS", "TEST_GEMS"
    )
    unlock = await client.post("/api/v1/seasons/premium-pass", headers=headers)
    assert unlock.status_code == 200
    assert unlock.json()["has_premium_pass"] is True
    duplicate_unlock = await client.post("/api/v1/seasons/premium-pass", headers=headers)
    assert duplicate_unlock.status_code == 400

    prem_res = await client.post(
        "/api/v1/seasons/claim",
        headers=headers,
        json={"tier_number": 1, "is_premium": True},
    )
    assert prem_res.status_code == 200
    assert prem_res.json()["gems_awarded"] > 0


@pytest.mark.asyncio
async def test_leaderboards_and_my_rank(db_session: AsyncSession, client: AsyncClient):
    # 1. Login user
    res = await client.post("/api/v1/auth/guest", json={"device_id": "dev_lb_user_1"})
    headers = {"Authorization": f"Bearer {res.json()['access_token']}"}
    user_id = res.json()["user_id"]
    game = Match(status="COMPLETED", mode="CLASSIC", finished_at=datetime.now(timezone.utc))
    db_session.add(game)
    await db_session.flush()
    db_session.add(MatchPlayer(
        match_id=game.id, user_id=user_id, seat_index=0,
        color="RED", placement=1, is_bot=False,
    ))
    await db_session.commit()

    # 2. Get leaderboards for ALL_TIME, WEEKLY, SEASONAL
    for scope in ["ALL_TIME", "WEEKLY", "SEASONAL"]:
        lb_res = await client.get(f"/api/v1/leaderboards?scope={scope}", headers=headers)
        assert lb_res.status_code == 200
        data = lb_res.json()
        assert data["scope"] == scope
        assert "entries" in data
        if scope == "WEEKLY":
            assert data["total_players"] == 1
            assert data["entries"][0]["user_id"] == user_id
            assert data["entries"][0]["matches_won"] == 1

    # 3. Get my rank
    rank_res = await client.get("/api/v1/leaderboards/my-rank?scope=ALL_TIME", headers=headers)
    assert rank_res.status_code == 200
    my_rank = rank_res.json()
    assert "rank" in my_rank
    assert "score" in my_rank
