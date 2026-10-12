import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_profile_and_stats_flow(client: AsyncClient):
    # 1. Create user
    res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "profile_test_device"},
    )
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    player_id = res.json()["player_id"]

    # 2. Get profile
    prof_res = await client.get("/api/v1/me/profile", headers=headers)
    assert prof_res.status_code == 200
    assert prof_res.json()["player_id"] == player_id

    # 3. Profile editing currently supports avatar selection only.
    patch_res = await client.patch(
        "/api/v1/me/profile",
        headers=headers,
        json={"avatar_id": "avatar_7"},
    )
    assert patch_res.status_code == 200, patch_res.text
    updated_data = patch_res.json()
    assert updated_data["avatar_id"] == "avatar_7"

    lookup_res = await client.get(f"/api/v1/players/{player_id}")
    assert lookup_res.status_code == 200
    assert lookup_res.json()["avatar_id"] == "avatar_7"
    bad_lookup = await client.get("/api/v1/players/LM-99999999")
    assert bad_lookup.status_code == 404

@pytest.mark.asyncio
async def test_profile_update_rejects_locked_identity_fields_and_allows_free_avatars(client: AsyncClient):
    first = (await client.post('/api/v1/auth/guest', json={'device_id': 'username_first'})).json()
    headers = {'Authorization': f"Bearer {first['access_token']}"}

    # display_name/username/country are selected during sign-up and are not
    # mutable through the current profile PATCH contract.
    assert (await client.patch('/api/v1/me/profile', headers=headers, json={'username': 'royal_roller'})).status_code == 422
    assert (await client.patch('/api/v1/me/profile', headers=headers, json={'display_name': 'Royal Roller'})).status_code == 422
    assert (await client.patch('/api/v1/me/profile', headers=headers, json={'country_code': 'IND'})).status_code == 422

    for index in range(8):
        response = await client.patch('/api/v1/me/profile', headers=headers, json={'avatar_id': f'avatar_{index}'})
        assert response.status_code == 200, response.text
        assert response.json()['avatar_id'] == f'avatar_{index}'

    assert (await client.patch('/api/v1/me/profile', headers=headers, json={'avatar_id': 'paid_unowned'})).status_code == 400
