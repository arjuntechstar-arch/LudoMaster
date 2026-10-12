import pytest
from datetime import datetime, timedelta, timezone
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.wallet import Wallet, WalletLedger
from app.models.mission import UserMission
from app.services.economy import economy_service
from app.services.progression import progression_service

@pytest.mark.asyncio
async def test_wallet_ledger_and_idempotency(db_session: AsyncSession, client: AsyncClient):
    # 1. Login user
    res = await client.post("/api/v1/auth/guest", json={"device_id": "dev_econ_1"})
    assert res.status_code == 200
    user_id = res.json()["user_id"]
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Check initial wallet
    wallet = await economy_service.get_or_create_wallet(db_session, user_id)
    assert wallet.coins >= 1000
    assert wallet.gems >= 10

    # 3. Record transaction with idempotency key
    ledger1, w1 = await economy_service.record_transaction(
        db=db_session,
        user_id=user_id,
        amount=500,
        currency="COINS",
        reason="BONUS",
        idempotency_key="unique_key_123",
    )
    assert ledger1.amount == 500
    assert ledger1.balance_after == 1500

    # 4. Duplicate request with same idempotency key must not double-grant
    ledger2, w2 = await economy_service.record_transaction(
        db=db_session,
        user_id=user_id,
        amount=500,
        currency="COINS",
        reason="BONUS",
        idempotency_key="unique_key_123",
    )
    assert ledger2.id == ledger1.id
    assert w2.coins == 1500

    # 5. Overdraft check
    with pytest.raises(ValueError, match="Insufficient coins"):
        await economy_service.record_transaction(
            db=db_session,
            user_id=user_id,
            amount=-2000,
            currency="COINS",
            reason="OVERDRAFT",
        )

@pytest.mark.asyncio
async def test_daily_rewards_claim_and_streak(client: AsyncClient):
    res = await client.post("/api/v1/auth/guest", json={"device_id": "dev_daily_1"})
    headers = {"Authorization": f"Bearer {res.json()['access_token']}"}

    # 1. Check daily reward status
    s_res = await client.get("/api/v1/economy/daily-reward", headers=headers)
    assert s_res.status_code == 200
    status = s_res.json()
    assert status["can_claim"] is True
    assert len(status["days"]) == 7
    assert status["days"][0]["day"] == 1
    assert status["days"][0]["coins"] == 250

    # 2. Claim Day 1
    c_res = await client.post("/api/v1/economy/daily-reward/claim", headers=headers)
    assert c_res.status_code == 200
    claimed = c_res.json()
    assert claimed["day"] == 1
    assert claimed["coins_awarded"] == 250
    assert claimed["xp_awarded"] == 50

    # 3. Double claim on same day must be rejected
    c2_res = await client.post("/api/v1/economy/daily-reward/claim", headers=headers)
    assert c2_res.status_code == 400
    assert "already been claimed" in c2_res.json()["detail"]

@pytest.mark.asyncio
async def test_missions_lifecycle(db_session: AsyncSession, client: AsyncClient):
    res = await client.post("/api/v1/auth/guest", json={"device_id": "dev_mission_1"})
    user_id = res.json()["user_id"]
    headers = {"Authorization": f"Bearer {res.json()['access_token']}"}

    # 1. Get missions
    m_res = await client.get("/api/v1/missions", headers=headers)
    assert m_res.status_code == 200
    missions = m_res.json()
    assert len(missions) >= 6
    play_m = next(m for m in missions if m["action_type"] == "MATCH_PLAY" and m["target_count"] == 1)
    assert play_m["is_completed"] is False

    # 2. Complete match progress via progression service
    await progression_service.record_match_progress(
        db=db_session,
        user_id=user_id,
        placement=1,
        captures=3,
        tokens_home=4,
        mode="CLASSIC",
    )

    # 3. Check missions again -> should be completed
    m2_res = await client.get("/api/v1/missions", headers=headers)
    m2_list = m2_res.json()
    play_m_after = next(m for m in m2_list if m["id"] == play_m["id"])
    assert play_m_after["is_completed"] is True
    assert play_m_after["is_claimed"] is False

    # 4. Claim mission
    claim_res = await client.post(f"/api/v1/missions/{play_m['id']}/claim", headers=headers)
    assert claim_res.status_code == 200
    assert claim_res.json()["mission_id"] == play_m["id"]
    assert claim_res.json()["coins_awarded"] == play_m["reward_coins"]

    # 5. Claiming again fails
    claim2_res = await client.post(f"/api/v1/missions/{play_m['id']}/claim", headers=headers)
    assert claim2_res.status_code == 400

    # A claimed daily mission becomes available again in the next period.
    mission_row = (await db_session.execute(
        select(UserMission).where(
            UserMission.user_id == user_id,
            UserMission.mission_id == play_m["id"],
        )
    )).scalar_one()
    mission_row.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
    await db_session.commit()
    refreshed = await client.get("/api/v1/missions", headers=headers)
    daily = next(m for m in refreshed.json() if m["id"] == play_m["id"])
    assert daily["is_completed"] is False
    assert daily["is_claimed"] is False
    assert daily["current_count"] == 0

@pytest.mark.asyncio
async def test_achievements_unlock_and_claim(db_session: AsyncSession, client: AsyncClient):
    res = await client.post("/api/v1/auth/guest", json={"device_id": "dev_ach_1"})
    user_id = res.json()["user_id"]
    headers = {"Authorization": f"Bearer {res.json()['access_token']}"}

    # 1. Get achievements
    a_res = await client.get("/api/v1/achievements", headers=headers)
    assert a_res.status_code == 200
    achievements = a_res.json()
    first_win_ach = next(a for a in achievements if a["id"] == "ach_first_win")
    assert first_win_ach["is_unlocked"] is False

    # 2. Record 1st place win
    await progression_service.record_match_progress(
        db=db_session,
        user_id=user_id,
        placement=1,
        captures=2,
        tokens_home=4,
    )

    # 3. Check achievement now unlocked
    a2_res = await client.get("/api/v1/achievements", headers=headers)
    first_win_after = next(a for a in a2_res.json() if a["id"] == "ach_first_win")
    assert first_win_after["is_unlocked"] is True
    assert first_win_after["is_claimed"] is False

    # 4. Claim achievement
    claim_res = await client.post(f"/api/v1/achievements/ach_first_win/claim", headers=headers)
    assert claim_res.status_code == 200
    assert claim_res.json()["achievement_id"] == "ach_first_win"
    assert claim_res.json()["coins_awarded"] == 500

@pytest.mark.asyncio
async def test_store_catalog_purchase_and_inventory_equip(client: AsyncClient):
    res = await client.post("/api/v1/auth/guest", json={"device_id": "dev_store_1"})
    headers = {"Authorization": f"Bearer {res.json()['access_token']}"}

    # 1. Browse Catalog
    cat_res = await client.get("/api/v1/economy/catalog", headers=headers)
    assert cat_res.status_code == 200
    catalog = cat_res.json()
    assert len(catalog) >= 8

    # Default items should be owned and equipped
    wood_board = next(item for item in catalog if item["id"] == "theme_classic_wood")
    assert wood_board["is_owned"] is True
    assert wood_board["is_equipped"] is True

    # 2. Check Inventory endpoint
    inv_res = await client.get("/api/v1/inventory", headers=headers)
    assert inv_res.status_code == 200
    inventory = inv_res.json()
    assert any(i["id"] == "theme_classic_wood" and i["is_equipped"] for i in inventory)

    # 3. Purchase a board theme (Neon Cyber: 1500 coins; user starts with 1000 + 250 from daily or let's grant coins)
    # Give user extra coins via daily reward claim
    await client.post("/api/v1/economy/daily-reward/claim", headers=headers)

    # User balance: 1000 + 250 = 1250, still need 250 for 1500 coins. Purchase should fail for insufficient funds
    p_fail = await client.post("/api/v1/economy/purchase", json={"item_id": "theme_neon_cyber", "currency": "COINS"}, headers=headers)
    assert p_fail.status_code == 400
    assert "Insufficient coins" in p_fail.json()["detail"]

    # A zero gem price on a coins-only item means that payment option is unavailable.
    unavailable_currency = await client.post(
        "/api/v1/economy/purchase",
        json={"item_id": "theme_neon_cyber", "currency": "GEMS"},
        headers=headers,
    )
    assert unavailable_currency.status_code == 400
    assert "not available" in unavailable_currency.json()["detail"]

    # Purchase Golden Dice with Gems (Golden Luxury Dice is 10 gems, user starts with 10 gems)
    p_gems = await client.post("/api/v1/economy/purchase", json={"item_id": "dice_golden_luxury", "currency": "GEMS"}, headers=headers)
    assert p_gems.status_code == 200
    assert p_gems.json()["item_id"] == "dice_golden_luxury"

    # 4. Equip Golden Dice
    eq_res = await client.post("/api/v1/inventory/equip", json={"item_id": "dice_golden_luxury"}, headers=headers)
    assert eq_res.status_code == 200
    assert eq_res.json()["item_id"] == "dice_golden_luxury"

    # 5. Verify inventory reflects golden dice as equipped and ivory dice as unequipped
    inv2_res = await client.get("/api/v1/inventory", headers=headers)
    inv2 = inv2_res.json()
    gold_item = next(i for i in inv2 if i["id"] == "dice_golden_luxury")
    ivory_item = next(i for i in inv2 if i["id"] == "dice_classic_ivory")
    assert gold_item["is_equipped"] is True
    assert ivory_item["is_equipped"] is False
