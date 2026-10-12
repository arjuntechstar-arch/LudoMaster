import pytest
from httpx import AsyncClient
from services.realtime.moderation import is_preset_message, sanitize_chat_message

@pytest.mark.asyncio
async def test_block_and_unblock_flow(client: AsyncClient):
    p1_res = await client.post("/api/v1/auth/guest", json={"device_id": "blk_p1_dev"})
    p1_headers = {"Authorization": f"Bearer {p1_res.json()['access_token']}"}

    p2_res = await client.post("/api/v1/auth/guest", json={"device_id": "blk_p2_dev"})
    p2_id = p2_res.json()["user_id"]
    p2_headers = {"Authorization": f"Bearer {p2_res.json()['access_token']}"}

    # 1. P1 blocks P2
    blk_res = await client.post(
        "/api/v1/blocks",
        json={"blocked_user_id": p2_id, "reason": "Abusive chat"},
        headers=p1_headers,
    )
    assert blk_res.status_code == 201

    # 2. List blocks
    list_res = await client.get("/api/v1/blocks", headers=p1_headers)
    assert list_res.status_code == 200
    blocks = list_res.json()
    assert len(blocks) == 1
    assert blocks[0]["blocked_id"] == p2_id

    # 3. Friend request to blocked user should fail
    freq = await client.post(
        "/api/v1/friends/request",
        json={"target_user_id": p2_id},
        headers=p1_headers,
    )
    assert freq.status_code == 400

    # 4. P1 creates room and tries to invite P2 -> should fail
    room_res = await client.post(
        "/api/v1/rooms",
        json={"mode": "CLASSIC", "max_players": 4},
        headers=p1_headers,
    )
    room_id = room_res.json()["id"]

    inv_res = await client.post(
        f"/api/v1/rooms/{room_id}/invite",
        json={"recipient_id": p2_id},
        headers=p1_headers,
    )
    assert inv_res.status_code == 400

    # 5. P1 unblocks P2
    unblk_res = await client.delete(f"/api/v1/blocks/{p2_id}", headers=p1_headers)
    assert unblk_res.status_code == 200

    # Verify blocks list is empty
    list_after = await client.get("/api/v1/blocks", headers=p1_headers)
    assert len(list_after.json()) == 0

@pytest.mark.asyncio
async def test_report_submission(client: AsyncClient):
    p1_res = await client.post("/api/v1/auth/guest", json={"device_id": "rep_p1_dev"})
    p1_headers = {"Authorization": f"Bearer {p1_res.json()['access_token']}"}

    p2_res = await client.post("/api/v1/auth/guest", json={"device_id": "rep_p2_dev"})
    p2_id = p2_res.json()["user_id"]

    # Submit report
    rep_res = await client.post(
        "/api/v1/reports",
        json={
            "reported_user_id": p2_id,
            "category": "CHEATING",
            "description": "Used dice exploit to roll all sixes",
        },
        headers=p1_headers,
    )
    assert rep_res.status_code == 201
    data = rep_res.json()
    assert data["category"] == "CHEATING"
    assert data["status"] == "OPEN"
    assert data["reported_user_id"] == p2_id

@pytest.mark.asyncio
async def test_room_invite_lifecycle(client: AsyncClient):
    p1_res = await client.post("/api/v1/auth/guest", json={"device_id": "inv_host_dev"})
    p1_headers = {"Authorization": f"Bearer {p1_res.json()['access_token']}"}

    p2_res = await client.post("/api/v1/auth/guest", json={"device_id": "inv_guest_dev"})
    p2_id = p2_res.json()["user_id"]
    p2_headers = {"Authorization": f"Bearer {p2_res.json()['access_token']}"}

    # 1. P1 creates room
    room_res = await client.post(
        "/api/v1/rooms",
        json={"mode": "CLASSIC", "max_players": 4},
        headers=p1_headers,
    )
    room_id = room_res.json()["id"]

    # 2. P1 invites P2
    inv_res = await client.post(
        f"/api/v1/rooms/{room_id}/invite",
        json={"recipient_id": p2_id},
        headers=p1_headers,
    )
    assert inv_res.status_code == 201
    inv_id = inv_res.json()["id"]

    # 3. P2 gets pending invites
    p2_invs = await client.get("/api/v1/rooms/invites/my-invites", headers=p2_headers)
    assert p2_invs.status_code == 200
    inv_list = p2_invs.json()
    assert len(inv_list) == 1
    assert inv_list[0]["id"] == inv_id
    assert inv_list[0]["room_id"] == room_id

    # 4. P2 responds to invite
    resp = await client.post(
        f"/api/v1/rooms/invites/{inv_id}/respond?accept=true",
        headers=p2_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["room_id"] == room_id

    # Accepting an invite joins the room, so the host cannot start a game
    # that has silently replaced the invited friend with a bot.
    room_after_accept = await client.get(f"/api/v1/rooms/{room_id}", headers=p2_headers)
    assert room_after_accept.status_code == 200
    assert len(room_after_accept.json()["members"]) == 2

def test_chat_moderation_profanity_filter():
    clean = sanitize_chat_message("Hello friend, good luck!")
    assert clean == "Hello friend, good luck!"

    bad = sanitize_chat_message("You are an idiot and a loser!")
    assert bad == "You are an *** and a ***!"

    preset = "Good game!"
    assert is_preset_message(preset) is True
    assert is_preset_message("random text") is False
