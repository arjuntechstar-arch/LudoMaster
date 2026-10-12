import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import get_password_hash
from app.models.admin import AdminUser
from app.models.user import User
from app.models.profile import Profile
from app.models.wallet import Wallet
from app.models.social import Report

@pytest.mark.asyncio
async def test_admin_auth_and_kpis(client: AsyncClient, db_session: AsyncSession):
    # Create super admin
    admin = AdminUser(
        username="superadmin",
        email="super@ludomaster.io",
        hashed_password=get_password_hash("SuperSecret123!"),
        role="SUPER_ADMIN",
        is_active=True,
    )
    db_session.add(admin)
    await db_session.commit()

    # Login failed (wrong password)
    resp = await client.post(
        "/api/v1/admin/auth/login",
        json={"username": "superadmin", "password": "WrongPassword"},
    )
    assert resp.status_code == 401

    # Login success
    login_resp = await client.post(
        "/api/v1/admin/auth/login",
        json={"username": "superadmin", "password": "SuperSecret123!"},
    )
    assert login_resp.status_code == 200
    data = login_resp.json()
    assert "access_token" in data
    assert data["admin"]["role"] == "SUPER_ADMIN"
    token = data["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Verify /admin/auth/me
    me_resp = await client.get("/api/v1/admin/auth/me", headers=headers)
    assert me_resp.status_code == 200
    assert me_resp.json()["username"] == "superadmin"

    # Verify /admin/dashboard/kpis
    kpi_resp = await client.get("/api/v1/admin/dashboard/kpis", headers=headers)
    assert kpi_resp.status_code == 200
    kpis = kpi_resp.json()
    assert "total_users" in kpis
    assert "total_coins_in_circulation" in kpis
    assert "pending_reports_count" in kpis

@pytest.mark.asyncio
async def test_admin_user_management_and_suspension(client: AsyncClient, db_session: AsyncSession):
    # Setup admin
    admin = AdminUser(
        username="mod_admin",
        email="mod@ludomaster.io",
        hashed_password=get_password_hash("ModPass123!"),
        role="MODERATOR",
        is_active=True,
    )
    db_session.add(admin)

    # Setup player user
    user = User(status="ACTIVE", is_guest=True)
    db_session.add(user)
    await db_session.flush()

    profile = Profile(
        user_id=user.id,
        player_id="TESTUSER",
        display_name="TestPlayer",
        avatar_id="avatar_1",
        level=5,
        xp=450,
        country_code="US",
    )
    wallet = Wallet(user_id=user.id, coins=1000, gems=50)
    db_session.add_all([profile, wallet])
    await db_session.commit()

    # Login as admin
    login_resp = await client.post(
        "/api/v1/admin/auth/login",
        json={"username": "mod_admin", "password": "ModPass123!"},
    )
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # List users
    users_resp = await client.get("/api/v1/admin/users", headers=headers)
    assert users_resp.status_code == 200
    user_list = users_resp.json()
    assert len(user_list) >= 1
    assert any(u["id"] == user.id for u in user_list)

    # Get user detail
    detail_resp = await client.get(f"/api/v1/admin/users/{user.id}", headers=headers)
    assert detail_resp.status_code == 200
    detail = detail_resp.json()
    assert detail["profile"]["player_id"] == "TESTUSER"
    assert detail["wallet"]["coins"] == 1000

    # Suspend user
    suspend_resp = await client.post(
        f"/api/v1/admin/users/{user.id}/suspend",
        headers=headers,
        json={"reason": "Abusive behavior in chat", "duration_days": 7},
    )
    assert suspend_resp.status_code == 200
    assert suspend_resp.json()["user_status"] == "SUSPENDED"

    # Unsuspend user
    unsuspend_resp = await client.post(
        f"/api/v1/admin/users/{user.id}/unsuspend",
        headers=headers,
    )
    assert unsuspend_resp.status_code == 200
    assert unsuspend_resp.json()["user_status"] == "ACTIVE"

@pytest.mark.asyncio
async def test_admin_wallet_adjust_and_rbac(client: AsyncClient, db_session: AsyncSession):
    # Setup moderator and superadmin
    mod = AdminUser(
        username="mod_only",
        email="mod_only@ludomaster.io",
        hashed_password=get_password_hash("Pass123!"),
        role="MODERATOR",
        is_active=True,
    )
    superadmin = AdminUser(
        username="super_exec",
        email="super_exec@ludomaster.io",
        hashed_password=get_password_hash("Pass123!"),
        role="SUPER_ADMIN",
        is_active=True,
    )
    user = User(status="ACTIVE", is_guest=True)
    db_session.add_all([mod, superadmin, user])
    await db_session.flush()

    wallet = Wallet(user_id=user.id, coins=200, gems=10)
    db_session.add(wallet)
    await db_session.commit()

    # Moderator tries to adjust wallet -> should be forbidden (SUPER_ADMIN only)
    mod_login = await client.post(
        "/api/v1/admin/auth/login",
        json={"username": "mod_only", "password": "Pass123!"},
    )
    mod_headers = {"Authorization": f"Bearer {mod_login.json()['access_token']}"}

    forbidden_resp = await client.post(
        f"/api/v1/admin/users/{user.id}/wallet-adjust",
        headers=mod_headers,
        json={"amount": 500, "currency": "COINS", "reason": "Tournament compensation"},
    )
    assert forbidden_resp.status_code == 403

    # SuperAdmin adjusts wallet -> success
    super_login = await client.post(
        "/api/v1/admin/auth/login",
        json={"username": "super_exec", "password": "Pass123!"},
    )
    super_headers = {"Authorization": f"Bearer {super_login.json()['access_token']}"}

    adjust_resp = await client.post(
        f"/api/v1/admin/users/{user.id}/wallet-adjust",
        headers=super_headers,
        json={"amount": 500, "currency": "COINS", "reason": "Tournament compensation"},
    )
    assert adjust_resp.status_code == 200
    assert adjust_resp.json()["balance_after"] == 700

@pytest.mark.asyncio
async def test_admin_reports_and_audit_logs(client: AsyncClient, db_session: AsyncSession):
    # Setup super admin
    admin = AdminUser(
        username="admin_audit",
        email="audit@ludomaster.io",
        hashed_password=get_password_hash("AuditPass123!"),
        role="SUPER_ADMIN",
        is_active=True,
    )
    user_reported = User(status="ACTIVE", is_guest=True)
    db_session.add_all([admin, user_reported])
    await db_session.flush()

    report = Report(
        reporter_id="user_reporter_123",
        reported_user_id=user_reported.id,
        category="INAPPROPRIATE_LANGUAGE",
        description="Repeated toxic language in match",
        status="OPEN",
    )
    db_session.add(report)
    await db_session.commit()

    login_resp = await client.post(
        "/api/v1/admin/auth/login",
        json={"username": "admin_audit", "password": "AuditPass123!"},
    )
    headers = {"Authorization": f"Bearer {login_resp.json()['access_token']}"}

    # List reports
    reports_resp = await client.get("/api/v1/admin/reports", headers=headers)
    assert reports_resp.status_code == 200
    reports = reports_resp.json()
    assert len(reports) >= 1
    target_report = next(r for r in reports if r["id"] == report.id)
    assert target_report["status"] in ["OPEN", "PENDING"]

    # Action report: SUSPEND_USER
    action_resp = await client.post(
        f"/api/v1/admin/reports/{report.id}/action",
        headers=headers,
        json={"action": "SUSPEND_USER", "notes": "Confirmed violation from timeline"},
    )
    assert action_resp.status_code == 200
    assert action_resp.json()["report_status"] == "RESOLVED"

    # Config update & Feature flag toggle
    cfg_resp = await client.post(
        "/api/v1/admin/config/remote-config",
        headers=headers,
        json={"key": "maintenance_mode", "value": "false", "description": "Global maintenance"},
    )
    assert cfg_resp.status_code == 200

    flag_resp = await client.post(
        "/api/v1/admin/config/feature-flags",
        headers=headers,
        json={"name": "voice_chat_beta", "enabled": True, "description": "Enable voice test"},
    )
    assert flag_resp.status_code == 200

    # Verify audit logs recorded actions
    audit_resp = await client.get("/api/v1/admin/audit-logs", headers=headers)
    assert audit_resp.status_code == 200
    logs = audit_resp.json()
    assert len(logs) >= 3
    actions = [l["action"] for l in logs]
    assert "ADMIN_LOGIN" in actions
    assert "REPORT_SUSPEND_USER" in actions
    assert "CONFIG_UPDATE" in actions
