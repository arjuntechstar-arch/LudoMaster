import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_club_lifecycle(client: AsyncClient):
    # 1. Login Player 1 (Leader)
    p1_res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "club_dev_1", "platform": "ANDROID"},
    )
    assert p1_res.status_code == 200
    p1_token = p1_res.json()["access_token"]
    p1_headers = {"Authorization": f"Bearer {p1_token}"}

    # 2. Player 1 creates a club
    create_res = await client.post(
        "/api/v1/clubs",
        json={
            "name": "Ludo Champions",
            "tag": "CHAMP",
            "description": "Elite club for competitive roll masters.",
            "badge_icon": "trophy_gold",
            "min_level": 1,
            "is_open": True,
        },
        headers=p1_headers,
    )
    assert create_res.status_code == 201, create_res.text
    club_data = create_res.json()
    assert club_data["name"] == "Ludo Champions"
    assert club_data["tag"] == "CHAMP"
    assert club_data["member_count"] == 1
    club_id = club_data["id"]

    # 3. Player 1 cannot create another club while already a member
    dup_create_res = await client.post(
        "/api/v1/clubs",
        json={
            "name": "Second Club",
            "tag": "SECND",
            "description": "Another club attempt",
            "badge_icon": "shield",
            "min_level": 1,
            "is_open": True,
        },
        headers=p1_headers,
    )
    assert dup_create_res.status_code == 400

    # 4. Login Player 2
    p2_res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "club_dev_2", "platform": "IOS"},
    )
    assert p2_res.status_code == 200
    p2_token = p2_res.json()["access_token"]
    p2_headers = {"Authorization": f"Bearer {p2_token}"}

    # 5. Player 2 lists/searches clubs
    list_res = await client.get("/api/v1/clubs?query=Champ", headers=p2_headers)
    assert list_res.status_code == 200
    clubs = list_res.json()
    assert len(clubs) >= 1
    assert any(c["id"] == club_id for c in clubs)

    # 6. Player 2 joins the club
    join_res = await client.post(f"/api/v1/clubs/{club_id}/join", headers=p2_headers)
    assert join_res.status_code == 200, join_res.text
    joined_club = join_res.json()
    assert joined_club["member_count"] == 2
    assert len(joined_club["members"]) == 2

    # 7. Player 2 checks their my-club endpoint
    my_club_res = await client.get("/api/v1/clubs/my-club", headers=p2_headers)
    assert my_club_res.status_code == 200
    my_club = my_club_res.json()
    assert my_club is not None
    assert my_club["id"] == club_id

    # 8. Player 2 leaves the club
    leave_res = await client.post(f"/api/v1/clubs/{club_id}/leave", headers=p2_headers)
    assert leave_res.status_code == 200
    assert leave_res.json()["status"] == "LEFT"

    # Verify club member count decreased
    detail_res = await client.get(f"/api/v1/clubs/{club_id}", headers=p1_headers)
    assert detail_res.status_code == 200
    assert detail_res.json()["member_count"] == 1

    # 9. Player 1 (sole member and leader) leaves club -> club dissolves
    leave_leader_res = await client.post(f"/api/v1/clubs/{club_id}/leave", headers=p1_headers)
    assert leave_leader_res.status_code == 200

    # Club no longer found
    not_found_res = await client.get(f"/api/v1/clubs/{club_id}", headers=p1_headers)
    assert not_found_res.status_code == 404

@pytest.mark.asyncio
async def test_club_validation(client: AsyncClient):
    p1_res = await client.post("/api/v1/auth/guest", json={"device_id": "val_dev_1"})
    p1_token = p1_res.json()["access_token"]
    p1_headers = {"Authorization": f"Bearer {p1_token}"}

    create_res = await client.post(
        "/api/v1/clubs",
        json={"name": "Royal Rollers", "tag": "ROYAL", "description": "Royal club", "badge_icon": "crown"},
        headers=p1_headers,
    )
    assert create_res.status_code == 201

    p2_res = await client.post("/api/v1/auth/guest", json={"device_id": "val_dev_2"})
    p2_token = p2_res.json()["access_token"]
    p2_headers = {"Authorization": f"Bearer {p2_token}"}

    # Duplicate name should fail
    dup_name_res = await client.post(
        "/api/v1/clubs",
        json={"name": "Royal Rollers", "tag": "OTHER", "description": "Dup name", "badge_icon": "crown"},
        headers=p2_headers,
    )
    assert dup_name_res.status_code == 400

    # Duplicate tag should fail
    dup_tag_res = await client.post(
        "/api/v1/clubs",
        json={"name": "Other Name", "tag": "ROYAL", "description": "Dup tag", "badge_icon": "crown"},
        headers=p2_headers,
    )
    assert dup_tag_res.status_code == 400

@pytest.mark.asyncio
async def test_voice_token_and_moderation(client: AsyncClient):
    # 1. Login Host
    host_res = await client.post("/api/v1/auth/guest", json={"device_id": "voice_host_dev"})
    host_token = host_res.json()["access_token"]
    host_headers = {"Authorization": f"Bearer {host_token}"}

    # 2. Host creates room
    room_res = await client.post(
        "/api/v1/rooms",
        json={"mode": "CLASSIC", "max_players": 4},
        headers=host_headers,
    )
    assert room_res.status_code == 201
    room = room_res.json()
    room_id = room["id"]

    # 3. Host requests voice token with privacy consent
    vt_res = await client.post(
        f"/api/v1/rooms/{room_id}/voice/token",
        json={"enable_mic": True, "privacy_consent": True},
        headers=host_headers,
    )
    assert vt_res.status_code == 200, vt_res.text
    vt_data = vt_res.json()
    assert vt_data["room_id"] == room_id
    assert vt_data["token"].startswith("vt_")
    assert vt_data["mic_enabled"] is True

    # 4. Outsider cannot request voice token
    outsider_res = await client.post("/api/v1/auth/guest", json={"device_id": "voice_outsider"})
    outsider_token = outsider_res.json()["access_token"]
    outsider_headers = {"Authorization": f"Bearer {outsider_token}"}

    bad_vt_res = await client.post(
        f"/api/v1/rooms/{room_id}/voice/token",
        json={"enable_mic": True, "privacy_consent": True},
        headers=outsider_headers,
    )
    assert bad_vt_res.status_code == 403

    # 5. Member 2 joins room
    p2_res = await client.post("/api/v1/auth/guest", json={"device_id": "voice_p2_dev"})
    p2_id = p2_res.json()["user_id"]
    p2_token = p2_res.json()["access_token"]
    p2_headers = {"Authorization": f"Bearer {p2_token}"}

    await client.post("/api/v1/rooms/join", json={"code": room["code"]}, headers=p2_headers)

    # 6. Mute signaling
    mute_res = await client.post(
        f"/api/v1/rooms/{room_id}/voice/mute",
        json={"target_user_id": p2_id, "is_muted": True},
        headers=host_headers,
    )
    assert mute_res.status_code == 200
    assert mute_res.json()["is_muted"] is True

    # 7. Voice harassment abuse report
    report_res = await client.post(
        f"/api/v1/rooms/{room_id}/voice/report",
        json={
            "reported_user_id": p2_id,
            "reason": "Abusive audio behavior",
            "details": "Loud background screaming and vulgarities",
        },
        headers=host_headers,
    )
    assert report_res.status_code == 200
    report_data = report_res.json()
    assert report_data["status"] == "REPORTED"
    assert "report_id" in report_data
