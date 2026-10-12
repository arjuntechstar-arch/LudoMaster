import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_friends_request_accept_and_remove(client: AsyncClient):
    # 1. Login player 1 & player 2
    p1_res = await client.post("/api/v1/auth/guest", json={"device_id": "f_p1_dev"})
    p1_id = p1_res.json()["user_id"]
    p1_headers = {"Authorization": f"Bearer {p1_res.json()['access_token']}"}

    p2_res = await client.post("/api/v1/auth/guest", json={"device_id": "f_p2_dev"})
    p2_id = p2_res.json()["user_id"]
    p2_pid = p2_res.json()["player_id"]
    p2_headers = {"Authorization": f"Bearer {p2_res.json()['access_token']}"}

    # 2. Player 1 sends friend request to Player 2
    req_res = await client.post(
        "/api/v1/friends/request",
        json={"target_user_id": p2_id},
        headers=p1_headers,
    )
    assert req_res.status_code == 201
    assert req_res.json()["status"] == "PENDING"
    req_id = req_res.json()["id"]

    # 3. Player 2 lists requests
    p2_reqs = await client.get("/api/v1/friends/requests", headers=p2_headers)
    assert p2_reqs.status_code == 200
    incoming = p2_reqs.json()["incoming"]
    assert len(incoming) == 1
    assert incoming[0]["user_id"] == p1_id

    # 4. Player 2 accepts request
    accept_res = await client.post(f"/api/v1/friends/requests/{req_id}/accept", headers=p2_headers)
    assert accept_res.status_code == 200
    assert accept_res.json()["status"] == "ACCEPTED"

    # 5. Both check their friends list
    f1_res = await client.get("/api/v1/friends", headers=p1_headers)
    assert f1_res.status_code == 200
    f1_list = f1_res.json()
    assert len(f1_list) == 1
    assert f1_list[0]["user_id"] == p2_id

    f2_res = await client.get("/api/v1/friends", headers=p2_headers)
    assert f2_res.status_code == 200
    f2_list = f2_res.json()
    assert len(f2_list) == 1
    assert f2_list[0]["user_id"] == p1_id

    # 6. Player 1 removes friend
    del_res = await client.delete(f"/api/v1/friends/{p2_id}", headers=p1_headers)
    assert del_res.status_code == 200

    # Verify friends list is now empty
    f1_after = await client.get("/api/v1/friends", headers=p1_headers)
    assert len(f1_after.json()) == 0

@pytest.mark.asyncio
async def test_friend_request_by_player_id_and_decline(client: AsyncClient):
    p1_res = await client.post("/api/v1/auth/guest", json={"device_id": "f_p1_pid_dev"})
    p1_headers = {"Authorization": f"Bearer {p1_res.json()['access_token']}"}

    p2_res = await client.post("/api/v1/auth/guest", json={"device_id": "f_p2_pid_dev"})
    p2_pid = p2_res.json()["player_id"]
    p2_headers = {"Authorization": f"Bearer {p2_res.json()['access_token']}"}

    # P1 requests P2 by player_id
    req_res = await client.post(
        "/api/v1/friends/request",
        json={"player_id": p2_pid},
        headers=p1_headers,
    )
    assert req_res.status_code == 201
    req_id = req_res.json()["id"]

    # P2 declines
    dec_res = await client.post(f"/api/v1/friends/requests/{req_id}/decline", headers=p2_headers)
    assert dec_res.status_code == 200

    # Friends list remains empty
    f1_res = await client.get("/api/v1/friends", headers=p1_headers)
    assert len(f1_res.json()) == 0
