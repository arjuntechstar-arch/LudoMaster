import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_guest_login_flow(client: AsyncClient):
    # 1. First guest login
    res = await client.post(
        "/api/v1/auth/guest",
        json={
            "device_id": "test_device_12345",
            "platform": "ANDROID",
            "app_version": "1.0.0",
        },
    )
    assert res.status_code == 200, res.text
    data = res.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["is_guest"] is True
    assert data["player_id"].startswith("LM-")
    user_id = data["user_id"]

    # 2. Same device logs in again -> should return existing user ID
    res2 = await client.post(
        "/api/v1/auth/guest",
        json={
            "device_id": "test_device_12345",
            "platform": "ANDROID",
            "app_version": "1.0.0",
        },
    )
    assert res2.status_code == 200
    assert res2.json()["user_id"] == user_id

@pytest.mark.asyncio
async def test_email_registration_and_login(client: AsyncClient):
    # 1. Register new email with the complete required sign-up profile.
    reg_res = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "player1@example.com",
            "password": "Password123!",
            "display_name": "LudoChamp",
            "username": "ludo_champ",
            "avatar_id": "avatar_2",
            "device_id": "device_reg_1",
            "platform": "IOS",
        },
    )
    assert reg_res.status_code == 200, reg_res.text
    reg_data = reg_res.json()
    assert reg_data["display_name"] == "LudoChamp"
    assert reg_data["is_guest"] is False

    # 2. Duplicate email should still fail after request validation succeeds.
    dup_res = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "player1@example.com",
            "password": "Password123!",
            "display_name": "LudoChamp2",
            "username": "ludo_champ2",
            "avatar_id": "avatar_3",
            "device_id": "device_reg_2",
        },
    )
    assert dup_res.status_code == 400, dup_res.text

    # 3. Successful login
    login_res = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "player1@example.com",
            "password": "Password123!",
            "device_id": "device_reg_1",
        },
    )
    assert login_res.status_code == 200
    assert "access_token" in login_res.json()

    # 4. Incorrect password
    bad_login = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "player1@example.com",
            "password": "WrongPassword",
        },
    )
    assert bad_login.status_code == 401

@pytest.mark.asyncio
async def test_guest_upgrade_preserves_account(client: AsyncClient):
    # 1. Start as guest
    guest_res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "upgrade_device_999"},
    )
    assert guest_res.status_code == 200
    guest_data = guest_res.json()
    token = guest_data["access_token"]
    player_id = guest_data["player_id"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Verify account info before upgrade
    me_res = await client.get("/api/v1/me", headers=headers)
    assert me_res.status_code == 200
    assert me_res.json()["is_guest"] is True
    assert me_res.json()["wallet"]["coins"] == 1000

    # 3. Upgrade to full verified account with required profile setup.
    upgrade_res = await client.post(
        "/api/v1/auth/upgrade",
        headers=headers,
        json={
            "email": "upgraded_player@example.com",
            "password": "SecurePassword456!",
            "display_name": "Upgraded Player",
            "username": "upgraded_player",
            "avatar_id": "avatar_4",
        },
    )
    assert upgrade_res.status_code == 200, upgrade_res.text
    upgrade_data = upgrade_res.json()
    assert upgrade_data["is_guest"] is False
    assert upgrade_data["player_id"] == player_id  # Player ID preserved!
    assert upgrade_data["display_name"] == "Upgraded Player"
    new_token = upgrade_data["access_token"]

    # 4. Verify account info after upgrade: coins and ID retained
    new_headers = {"Authorization": f"Bearer {new_token}"}
    me_after = await client.get("/api/v1/me", headers=new_headers)
    assert me_after.status_code == 200
    assert me_after.json()["is_guest"] is False
    assert me_after.json()["is_verified"] is True
    assert me_after.json()["wallet"]["coins"] == 1000
    assert me_after.json()["profile"]["display_name"] == "Upgraded Player"
    assert me_after.json()["profile"]["username"] == "upgraded_player"
    assert me_after.json()["profile"]["avatar_id"] == "avatar_4"

    # 5. Verify can now login with email
    login_check = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "upgraded_player@example.com",
            "password": "SecurePassword456!",
        },
    )
    assert login_check.status_code == 200
    assert login_check.json()["player_id"] == player_id

@pytest.mark.asyncio
async def test_refresh_token_rotation(client: AsyncClient):
    # 1. Login as guest
    res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "refresh_device_1"},
    )
    refresh_token = res.json()["refresh_token"]

    # 2. Refresh token
    refresh_res = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert refresh_res.status_code == 200
    new_refresh_token = refresh_res.json()["refresh_token"]
    assert new_refresh_token != refresh_token

    # 3. Old refresh token is now revoked and must fail
    reused_res = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert reused_res.status_code == 401

@pytest.mark.asyncio
async def test_logout_revokes_sessions(client: AsyncClient):
    res = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": "logout_device_1"},
    )
    access_token = res.json()["access_token"]
    refresh_token = res.json()["refresh_token"]
    headers = {"Authorization": f"Bearer {access_token}"}

    # Logout
    logout_res = await client.post("/api/v1/auth/logout", headers=headers)
    assert logout_res.status_code == 200

    # Refreshing after logout fails
    refresh_res = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert refresh_res.status_code == 401
