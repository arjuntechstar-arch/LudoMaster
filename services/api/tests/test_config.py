import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    res = await client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "healthy"

@pytest.mark.asyncio
async def test_version_check_endpoint(client: AsyncClient):
    # Equal or newer version
    res = await client.get("/api/v1/config/version-check?platform=ANDROID&app_version=1.0.0")
    assert res.status_code == 200
    assert res.json()["upgrade_required"] is False

    # Outdated version
    res_old = await client.get("/api/v1/config/version-check?platform=ANDROID&app_version=0.9.0")
    assert res_old.status_code == 200
    assert res_old.json()["upgrade_required"] is True

@pytest.mark.asyncio
async def test_app_remote_config(client: AsyncClient):
    res = await client.get("/api/v1/config/app")
    assert res.status_code == 200
    data = res.json()
    assert "configs" in data
    assert data["configs"]["classic_tokens_per_player"] == 4
    assert data["configs"]["quick_tokens_per_player"] == 2
    assert "feature_flags" in data
    assert data["feature_flags"]["online_multiplayer"] is True
