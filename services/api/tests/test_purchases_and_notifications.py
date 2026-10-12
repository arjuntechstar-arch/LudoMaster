import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import get_password_hash
from app.models.admin import AdminUser
from app.models.user import User
from app.models.wallet import Wallet, WalletLedger
from app.services.purchase_service import purchase_service

@pytest.mark.asyncio
async def test_iap_catalog_and_order_flow(client: AsyncClient, db_session: AsyncSession, monkeypatch):
    monkeypatch.setattr(purchase_service, "billing_enabled", lambda: True)
    async def verified_purchase(user_id, product_id, token):
        return {"purchaseState": 0}
    monkeypatch.setattr(purchase_service, "_verify_google_purchase", verified_purchase)
    # Setup player
    user = User(status="ACTIVE", is_guest=True)
    db_session.add(user)
    await db_session.flush()

    wallet = Wallet(user_id=user.id, coins=1000, gems=10)
    db_session.add(wallet)
    await db_session.commit()

    # Login guest
    login_resp = await client.post("/api/v1/auth/guest", json={"device_id": "test_device_iap"})
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]
    user_id = login_resp.json()["user_id"]
    headers = {"Authorization": f"Bearer {token}"}

    # 1. List Products
    products_resp = await client.get("/api/v1/purchases/products")
    assert products_resp.status_code == 200
    products = products_resp.json()
    assert len(products) >= 5
    product_ids = [p["id"] for p in products]
    assert "coin_sack_30k" in product_ids
    assert "gem_bag_300" in product_ids

    # 2. Create Order
    order_resp = await client.post(
        "/api/v1/purchases/create-order",
        headers=headers,
        json={"product_id": "coin_sack_30k", "platform": "GOOGLE_PLAY"},
    )
    assert order_resp.status_code == 200
    order_data = order_resp.json()
    assert "order_id" in order_data
    assert order_data["price_cents"] == 499
    assert order_data["status"] == "PENDING"
    order_id = order_data["order_id"]

    # 3. Verify Receipt (Fulfillment)
    tx_id = f"GPA.1234-5678-9012-{user_id[:6]}"
    verify_resp = await client.post(
        "/api/v1/purchases/verify-receipt",
        headers=headers,
        json={
            "order_id": order_id,
            "product_id": "coin_sack_30k",
            "platform": "GOOGLE_PLAY",
            "transaction_id": tx_id,
            "raw_receipt": '{"orderId":"' + tx_id + '","packageName":"com.ludomaster.game"}',
        },
    )
    assert verify_resp.status_code == 200
    verify_data = verify_resp.json()
    assert verify_data["status"] == "SUCCESS"
    assert verify_data["granted_coins"] == 30000
    assert verify_data["new_coins_balance"] >= 30000

    # 4. Anti-Replay: same transaction cannot be verified again
    replay_resp = await client.post(
        "/api/v1/purchases/verify-receipt",
        headers=headers,
        json={
            "order_id": order_id,
            "product_id": "coin_sack_30k",
            "platform": "GOOGLE_PLAY",
            "transaction_id": tx_id,
            "raw_receipt": '{"orderId":"' + tx_id + '","packageName":"com.ludomaster.game"}',
        },
    )
    assert replay_resp.status_code == 200
    assert replay_resp.json()["new_coins_balance"] == verify_data["new_coins_balance"]
    assert "unchanged" in replay_resp.json()["message"]

    # 5. Purchase History
    history_resp = await client.get("/api/v1/purchases/history", headers=headers)
    assert history_resp.status_code == 200
    history = history_resp.json()
    assert len(history) >= 1
    assert any(h["id"] == order_id for h in history)

@pytest.mark.asyncio
async def test_notifications_inbox_and_broadcast(client: AsyncClient, db_session: AsyncSession):
    # Setup player and super admin
    admin = AdminUser(
        username="broadcast_admin",
        email="bcast@ludomaster.io",
        hashed_password=get_password_hash("Pass123!"),
        role="SUPER_ADMIN",
        is_active=True,
    )
    db_session.add(admin)
    await db_session.commit()

    # Login player
    player_resp = await client.post("/api/v1/auth/guest", json={"device_id": "device_notif"})
    assert player_resp.status_code == 200
    player_token = player_resp.json()["access_token"]
    player_id = player_resp.json()["user_id"]
    player_headers = {"Authorization": f"Bearer {player_token}"}

    # Login admin
    admin_login = await client.post(
        "/api/v1/admin/auth/login",
        json={"username": "broadcast_admin", "password": "Pass123!"},
    )
    admin_headers = {"Authorization": f"Bearer {admin_login.json()['access_token']}"}

    # 1. Admin Broadcasts Announcement
    bcast_resp = await client.post(
        "/api/v1/notifications/broadcast",
        headers=admin_headers,
        json={
            "title": "Welcome to Season 1!",
            "body": "Season 1 Royale has begun with double XP on all tournament matches.",
            "category": "ANNOUNCEMENT",
            "data_payload": {"deep_link": "ludomaster://season/season_1"},
        },
    )
    assert bcast_resp.status_code == 200
    assert bcast_resp.json()["recipients_count"] >= 1

    # 2. Player checks inbox
    inbox_resp = await client.get("/api/v1/notifications", headers=player_headers)
    assert inbox_resp.status_code == 200
    inbox = inbox_resp.json()
    assert len(inbox) >= 1
    notif = inbox[0]
    assert notif["title"] == "Welcome to Season 1!"
    assert notif["is_read"] is False

    # 3. Mark notification as read
    read_resp = await client.post(
        f"/api/v1/notifications/{notif['id']}/read", headers=player_headers
    )
    assert read_resp.status_code == 200
    assert read_resp.json()["is_read"] is True

    # 4. Mark all read
    mark_all = await client.post("/api/v1/notifications/read-all", headers=player_headers)
    assert mark_all.status_code == 200
