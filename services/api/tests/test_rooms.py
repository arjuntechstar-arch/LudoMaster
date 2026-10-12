import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_room_lifecycle(client: AsyncClient):
    # 1. Login Host
    host_res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "host_device_1", "platform": "ANDROID"},
    )
    assert host_res.status_code == 200
    host_token = host_res.json()["access_token"]
    host_headers = {"Authorization": f"Bearer {host_token}"}

    # 2. Host creates room
    create_res = await client.post(
        "/api/v1/rooms",
        json={"mode": "CLASSIC", "max_players": 4, "bet_coins": 100},
        headers=host_headers,
    )
    assert create_res.status_code == 201, create_res.text
    room_data = create_res.json()
    assert len(room_data["code"]) == 6
    assert room_data["status"] == "WAITING"
    assert len(room_data["members"]) == 1
    assert room_data["members"][0]["seat_index"] == 0
    assert room_data["members"][0]["is_host"] is True
    assert room_data["members"][0]["is_ready"] is True
    room_id = room_data["id"]
    room_code = room_data["code"]

    # 3. Login Player 2
    p2_res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "player2_device", "platform": "IOS"},
    )
    assert p2_res.status_code == 200
    p2_token = p2_res.json()["access_token"]
    p2_headers = {"Authorization": f"Bearer {p2_token}"}

    # 4. Player 2 joins room
    join_res = await client.post(
        "/api/v1/rooms/join",
        json={"code": room_code},
        headers=p2_headers,
    )
    assert join_res.status_code == 200, join_res.text
    join_data = join_res.json()
    assert len(join_data["members"]) == 2
    p2_member = next(m for m in join_data["members"] if m["seat_index"] == 1)
    assert p2_member["is_host"] is False
    assert p2_member["is_ready"] is False

    # 5. Player 2 toggles ready
    ready_res = await client.post(
        f"/api/v1/rooms/{room_id}/ready",
        json={"is_ready": True},
        headers=p2_headers,
    )
    assert ready_res.status_code == 200
    ready_member = next(m for m in ready_res.json()["members"] if m["seat_index"] == 1)
    assert ready_member["is_ready"] is True

    # 6. Host starts match
    start_res = await client.post(
        f"/api/v1/rooms/{room_id}/start",
        headers=host_headers,
    )
    assert start_res.status_code == 200, start_res.text
    start_data = start_res.json()
    assert start_data["status"] == "ACTIVE"
    assert start_data["match_id"] is not None

    # The lobby's polling endpoint must return the match ID so every player
    # moves from the room into the same realtime game.
    poll_res = await client.get(f"/api/v1/rooms/{room_id}", headers=p2_headers)
    assert poll_res.status_code == 200
    assert poll_res.json()["match_id"] == start_data["match_id"]


@pytest.mark.asyncio
async def test_room_start_requires_two_ready_players(client: AsyncClient):
    host_res = await client.post("/api/v1/auth/guest", json={"device_id": "ready_host"})
    host_headers = {"Authorization": f"Bearer {host_res.json()['access_token']}"}
    room_res = await client.post(
        "/api/v1/rooms",
        json={"mode": "CLASSIC", "max_players": 4},
        headers=host_headers,
    )
    room = room_res.json()

    solo_start = await client.post(
        f"/api/v1/rooms/{room['id']}/start", headers=host_headers
    )
    assert solo_start.status_code == 400

    guest_res = await client.post("/api/v1/auth/guest", json={"device_id": "ready_guest"})
    guest_headers = {"Authorization": f"Bearer {guest_res.json()['access_token']}"}
    await client.post(
        "/api/v1/rooms/join",
        json={"code": room["code"]},
        headers=guest_headers,
    )

    unready_start = await client.post(
        f"/api/v1/rooms/{room['id']}/start", headers=host_headers
    )
    assert unready_start.status_code == 400

@pytest.mark.asyncio
async def test_room_leave_and_host_transfer(client: AsyncClient):
    # Host logs in
    h_res = await client.post("/api/v1/auth/guest", json={"device_id": "h_dev"})
    h_token = h_res.json()["access_token"]
    h_headers = {"Authorization": f"Bearer {h_token}"}

    # Create room
    c_res = await client.post("/api/v1/rooms", json={"mode": "CLASSIC", "max_players": 4}, headers=h_headers)
    room = c_res.json()

    # Member 2 logs in and joins
    m2_res = await client.post("/api/v1/auth/guest", json={"device_id": "m2_dev"})
    m2_token = m2_res.json()["access_token"]
    m2_headers = {"Authorization": f"Bearer {m2_token}"}

    await client.post("/api/v1/rooms/join", json={"code": room["code"]}, headers=m2_headers)

    # Host leaves room
    leave_res = await client.post(f"/api/v1/rooms/{room['id']}/leave", headers=h_headers)
    assert leave_res.status_code == 200

    # Member 2 inspects room -> should now be host
    get_res = await client.get(f"/api/v1/rooms/{room['id']}", headers=m2_headers)
    assert get_res.status_code == 200
    updated_room = get_res.json()
    assert len(updated_room["members"]) == 1
    assert updated_room["members"][0]["is_host"] is True

@pytest.mark.asyncio
async def test_join_nonexistent_room(client: AsyncClient):
    res = await client.post("/api/v1/auth/guest", json={"device_id": "dev_test"})
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    bad_res = await client.post("/api/v1/rooms/join", json={"code": "ZZZZZZ"}, headers=headers)
    assert bad_res.status_code == 404
