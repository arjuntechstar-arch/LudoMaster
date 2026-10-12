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

    # 3. Update profile
    patch_res = await client.patch(
        "/api/v1/me/profile",
        headers=headers,
        json={
            "display_name": "RoyalRoller",
            "avatar_id": "avatar_7",
            "country_code": "IND",
        },
    )
    assert patch_res.status_code == 200
    updated_data = patch_res.json()
    assert updated_data["display_name"] == "RoyalRoller"
    assert updated_data["avatar_id"] == "avatar_7"
    assert updated_data["country_code"] == "IND"

    lookup_res = await client.get(f"/api/v1/players/{player_id}")
    assert lookup_res.status_code == 200
    assert lookup_res.json()["display_name"] == "RoyalRoller"
    bad_lookup = await client.get("/api/v1/players/LM-99999999")
    assert bad_lookup.status_code == 404

@pytest.mark.asyncio
async def test_unique_usernames_and_free_avatars(client: AsyncClient):
    first = (await client.post('/api/v1/auth/guest', json={'device_id': 'username_first'})).json()
    second = (await client.post('/api/v1/auth/guest', json={'device_id': 'username_second'})).json()
    headers = {'Authorization': f"Bearer {first['access_token']}"}
    other = {'Authorization': f"Bearer {second['access_token']}"}
    available = await client.get('/api/v1/me/username-availability?username=Royal_Roller', headers=headers)
    assert available.json()['available'] is True
    saved = await client.patch('/api/v1/me/profile', headers=headers, json={'username': '  @Royal_Roller  ', 'display_name': '  Royal Roller  ', 'avatar_id': 'avatar_3'})
    assert saved.status_code == 200
    assert saved.json()['username'] == 'royal_roller'
    assert saved.json()['display_name'] == 'Royal Roller'
    taken = await client.get('/api/v1/me/username-availability?username=ROYAL_ROLLER', headers=other)
    assert taken.json()['available'] is False
    assert (await client.patch('/api/v1/me/profile', headers=other, json={'username': 'ROYAL_ROLLER'})).status_code == 409
    assert (await client.patch('/api/v1/me/profile', headers=other, json={'display_name': '   '})).status_code == 422
    assert (await client.patch('/api/v1/me/profile', headers=other, json={'username': 'bad name'})).status_code == 422
    for index in range(8):
        assert (await client.patch('/api/v1/me/profile', headers=other, json={'avatar_id': f'avatar_{index}'})).status_code == 200
    assert (await client.patch('/api/v1/me/profile', headers=other, json={'avatar_id': 'paid_unowned'})).status_code == 400
    friend = await client.post('/api/v1/friends/request', headers=other, json={'username': '@Royal_Roller'})
    assert friend.status_code == 201
    requests = (await client.get('/api/v1/friends/requests', headers=headers)).json()
    assert requests['incoming'][0]['user_id'] == second['user_id']
