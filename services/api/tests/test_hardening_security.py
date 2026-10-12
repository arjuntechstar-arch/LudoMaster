import pytest
from httpx import AsyncClient
from app.core.security import check_rate_limit

@pytest.mark.asyncio
async def test_version_check_endpoint(client: AsyncClient):
    # Test with current version
    resp = await client.get("/api/v1/config/version-check?platform=ANDROID&app_version=1.0.0")
    assert resp.status_code == 200
    data = resp.json()
    assert "upgrade_required" in data
    assert "latest_version" in data
    assert "min_version" in data

    # Test with ancient version that requires upgrade
    resp_old = await client.get("/api/v1/config/version-check?platform=ANDROID&app_version=0.0.1")
    assert resp_old.status_code == 200
    data_old = resp_old.json()
    assert data_old["upgrade_required"] is True
    assert data_old["message"] is not None

def test_rate_limiter_logic():
    key = "test_device_rate_limit"
    # Allow up to 5 requests in 10-second window
    for _ in range(5):
        assert check_rate_limit(key, max_requests=5, window_seconds=10) is True

    # 6th request should be blocked
    assert check_rate_limit(key, max_requests=5, window_seconds=10) is False

@pytest.mark.asyncio
async def test_gdpr_export_data(client: AsyncClient):
    # 1. Login guest
    login_resp = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "gdpr_export_device_test", "platform": "ANDROID", "app_version": "1.0.0"},
    )
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Export data
    export_resp = await client.get("/api/v1/auth/export-data", headers=headers)
    assert export_resp.status_code == 200
    data = export_resp.json()

    assert "user_id" in data
    assert "profile" in data
    assert data["profile"]["display_name"] is not None
    assert "stats" in data
    assert "wallet" in data
    assert data["wallet"]["coins"] >= 0
    assert "inventory" in data
    assert "purchases" in data
    assert "notifications" in data
    assert "export_timestamp" in data

@pytest.mark.asyncio
async def test_gdpr_delete_account(client: AsyncClient):
    # 1. Login guest
    login_resp = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "gdpr_delete_device_test", "platform": "ANDROID", "app_version": "1.0.0"},
    )
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]
    refresh_token = login_resp.json()["refresh_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Delete account
    del_resp = await client.post("/api/v1/auth/delete-account", headers=headers)
    assert del_resp.status_code == 200
    del_data = del_resp.json()
    assert del_data["status"] == "DELETED"

    # 3. Subsequent authenticated calls must be rejected (403 account deleted)
    after_resp = await client.get("/api/v1/me", headers=headers)
    assert after_resp.status_code == 403

    # 4. Refreshing token must also be rejected
    refresh_resp = await client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert refresh_resp.status_code == 401
