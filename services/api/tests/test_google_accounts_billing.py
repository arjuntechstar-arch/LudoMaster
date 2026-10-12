import hashlib

import httpx
import pytest
from fastapi import HTTPException
from sqlalchemy import func, select

from app.core.config import settings
from app.models.inventory import UserInventory
from app.models.purchase import PurchaseReceipt
from app.models.wallet import Wallet
from app.services.purchase_service import purchase_service
from app.services.social_auth import social_auth_service


async def guest(client, device):
    response = await client.post("/api/v1/auth/guest", json={"device_id": device})
    assert response.status_code == 200
    data = response.json()
    return data["user_id"], {"Authorization": f"Bearer {data['access_token']}"}


@pytest.mark.asyncio
async def test_google_link_preserves_wallet_and_prevents_device_login(client, db_session, monkeypatch):
    user_id, headers = await guest(client, "google_link_device")
    wallet = (await db_session.execute(select(Wallet).where(Wallet.user_id == user_id))).scalar_one()
    wallet.coins = 4200
    await db_session.commit()
    async def identity(token):
        return {"id": "verified-google-user", "name": "Google Player"}
    monkeypatch.setattr(social_auth_service, "verify_google", identity)
    linked = await client.post("/api/v1/auth/google", headers=headers, json={
        "id_token": "verified-by-provider", "link_to_current_user": True,
        "display_name": "Google Player", "username": "google_player", "avatar_id": "avatar_5",
    })
    assert linked.status_code == 200, linked.text
    assert linked.json()["user_id"] == user_id
    assert linked.json()["is_guest"] is False
    new_headers = {"Authorization": f"Bearer {linked.json()['access_token']}"}
    me = await client.get("/api/v1/me", headers=new_headers)
    assert me.json()["wallet"]["coins"] == 4200
    assert me.json()["profile"]["username"] == "google_player"
    again = await client.post("/api/v1/auth/google", json={"id_token": "verified-by-provider"})
    assert again.status_code == 200
    assert again.json()["user_id"] == user_id
    new_guest_id, _ = await guest(client, "google_link_device")
    assert new_guest_id != user_id


@pytest.mark.asyncio
async def test_google_link_conflict_and_auth_required(client, monkeypatch):
    async def identity(token):
        return {"id": "google-identity", "name": "Google Player"}
    monkeypatch.setattr(social_auth_service, "verify_google", identity)
    first = await client.post("/api/v1/auth/google", json={
        "id_token": "verified",
        "display_name": "Google Player",
        "username": "google_primary",
        "avatar_id": "avatar_1",
    })
    assert first.status_code == 200, first.text
    second = await client.post("/api/v1/auth/register", json={
        "email": "player@example.com", "password": "Password123!",
        "display_name": "Email Player", "username": "email_player",
        "avatar_id": "avatar_2", "device_id": "email-player-device",
    })
    assert second.status_code == 200, second.text
    headers = {"Authorization": f"Bearer {second.json()['access_token']}"}
    conflict = await client.post("/api/v1/auth/google", headers=headers, json={
        "id_token": "verified", "link_to_current_user": True,
    })
    assert conflict.status_code == 409
    unauth = await client.post("/api/v1/auth/google", json={"id_token": "verified", "link_to_current_user": True})
    assert unauth.status_code == 401


@pytest.mark.asyncio
async def test_google_audience_is_checked(monkeypatch):
    monkeypatch.setattr(settings, "GOOGLE_WEB_CLIENT_ID", "approved-client")
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_IDS", [])
    monkeypatch.setattr("app.services.social_auth.id_token.verify_oauth2_token",
                        lambda *args: {"aud": "another-client", "sub": "google-player"})
    with pytest.raises(HTTPException) as exc:
        await social_auth_service.verify_google("provider-token")
    assert exc.value.status_code == 401
    monkeypatch.setattr("app.services.social_auth.id_token.verify_oauth2_token",
                        lambda *args: {"aud": "approved-client", "sub": "google-player", "name": "Player"})
    assert (await social_auth_service.verify_google("provider-token"))["id"] == "google-player"


@pytest.mark.asyncio
async def test_unconfigured_providers_and_unverified_payments_are_closed(client, monkeypatch):
    monkeypatch.setattr(settings, "GOOGLE_WEB_CLIENT_ID", "")
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_IDS", [])
    monkeypatch.setattr(settings, "GOOGLE_PLAY_GAMES_CLIENT_ID", "")
    monkeypatch.setattr(settings, "GOOGLE_PLAY_BILLING_ENABLED", False)
    monkeypatch.setattr(settings, "ALLOW_TEST_PURCHASES", False)
    assert (await client.get("/api/v1/auth/providers")).json()["google_enabled"] is False
    assert (await client.get("/api/v1/purchases/config")).json()["google_play_enabled"] is False
    assert (await client.post("/api/v1/auth/google", json={"id_token": "fake-token"})).status_code == 503
    assert (await client.post("/api/v1/auth/play-games", json={"server_auth_code": "fake-code"})).status_code == 503
    _, headers = await guest(client, "unverified_purchase_device")
    for platform, expected in [("GOOGLE_PLAY", 503), ("MOCK", 400), ("WEB_STRIPE", 400)]:
        response = await client.post("/api/v1/purchases/verify-receipt", headers=headers, json={
            "product_id": "coin_pouch_5k", "platform": platform,
            "transaction_id": "fake", "raw_receipt": "unverified-receipt",
        })
        assert response.status_code == expected, response.text


@pytest.mark.asyncio
@pytest.mark.parametrize("state,account,quantity,accepted", [
    (0, "player", 1, True), (2, "player", 1, False),
    (1, "player", 1, False), (0, "other", 1, False), (0, "player", 2, False),
])
async def test_google_payment_state_and_account_binding(monkeypatch, state, account, quantity, accepted):
    monkeypatch.setattr(purchase_service, "billing_enabled", lambda: True)
    class Credentials:
        token = "server-access-token"
        def refresh(self, request):
            pass
    monkeypatch.setattr("app.services.purchase_service.service_account.Credentials.from_service_account_file",
                        lambda *args, **kwargs: Credentials())
    real_client = httpx.AsyncClient
    def response(request):
        assert "/com.ludomaster.app.mobile/purchases/products/coin_pouch_5k/tokens/" in request.url.path
        return httpx.Response(200, json={
            "purchaseState": state, "quantity": quantity,
            "obfuscatedExternalAccountId": hashlib.sha256(account.encode()).hexdigest(),
        })
    monkeypatch.setattr("app.services.purchase_service.httpx.AsyncClient",
                        lambda **kwargs: real_client(transport=httpx.MockTransport(response)))
    if accepted:
        assert (await purchase_service._verify_google_purchase("player", "coin_pouch_5k", "token"))["purchaseState"] == 0
    else:
        with pytest.raises(ValueError):
            await purchase_service._verify_google_purchase("player", "coin_pouch_5k", "token")


@pytest.mark.asyncio
async def test_cosmetic_fulfillment_once_and_purchase_replay_owner(client, db_session, monkeypatch):
    async def verified(user_id, product_id, token):
        return {"purchaseState": 0}
    monkeypatch.setattr(purchase_service, "_verify_google_purchase", verified)
    user_id, headers = await guest(client, "cosmetic_buyer")
    payload = {"product_id": "cosmetic_neon_board", "platform": "GOOGLE_PLAY",
               "transaction_id": "ignored-client-id", "raw_receipt": "verified-purchase-token"}
    first = await client.post("/api/v1/purchases/verify-receipt", headers=headers, json=payload)
    assert first.status_code == 200, first.text
    assert first.json()["granted_item_id"] == "theme_neon_cyber"
    payload["transaction_id"] = "different-client-id"
    repeat = await client.post("/api/v1/purchases/verify-receipt", headers=headers, json=payload)
    assert repeat.status_code == 200
    assert repeat.json()["new_coins_balance"] == 1000
    items = (await db_session.execute(select(func.count(UserInventory.id)).where(
        UserInventory.user_id == user_id, UserInventory.item_id == "theme_neon_cyber"))).scalar_one()
    receipts = (await db_session.execute(select(func.count(PurchaseReceipt.id)))).scalar_one()
    assert items == 1 and receipts == 1
    _, other_headers = await guest(client, "other_cosmetic_buyer")
    other = await client.post("/api/v1/purchases/verify-receipt", headers=other_headers, json=payload)
    assert other.status_code == 400


@pytest.mark.asyncio
async def test_ad_reward_limit_and_production_block(client, monkeypatch):
    monkeypatch.setattr(settings, "ENVIRONMENT", "development")
    monkeypatch.setattr(settings, "ALLOW_TEST_AD_REWARDS", True)
    monkeypatch.setattr(settings, "DAILY_AD_REWARD_LIMIT", 2)
    _, headers = await guest(client, "ad_cap_device")
    for _ in range(2):
        claim = await client.post("/api/v1/economy/watch-ad/claim", headers=headers)
        assert claim.status_code == 200, claim.text
    status = (await client.get("/api/v1/economy/watch-ad/status", headers=headers)).json()
    assert status["remaining_today"] == 0 and status["can_watch"] is False
    assert (await client.post("/api/v1/economy/watch-ad/claim", headers=headers)).status_code == 429
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    assert (await client.post("/api/v1/economy/watch-ad/claim", headers=headers)).status_code == 503
