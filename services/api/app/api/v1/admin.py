from datetime import datetime, timezone
import json
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
import jwt
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.core.dependencies import get_current_admin, require_admin_role
from app.core.security import get_password_hash, verify_password
from app.db.session import get_db
from app.models.admin import AdminAuditLog, AdminUser
from app.models.config import FeatureFlag, RemoteConfig
from app.models.inventory import CatalogItem
from app.models.match import GameEvent, GameSnapshot, Match, MatchPlayer
from app.models.profile import PlayerStats, Profile
from app.models.room import Room
from app.models.social import Report
from app.models.tournament import Tournament
from app.models.user import Device, RefreshSession, User, UserIdentity
from app.models.wallet import Wallet, WalletLedger
from app.schemas.admin import (
    AdminAuditLogResponse,
    AdminCatalogItemRequest,
    AdminConfigUpdateRequest,
    AdminFeatureFlagToggleRequest,
    AdminKpiOverview,
    AdminLoginRequest,
    AdminLoginResponse,
    AdminReportActionRequest,
    AdminSuspendRequest,
    AdminUserDetailResponse,
    AdminUserResponse,
    AdminUserSummary,
    AdminWalletAdjustRequest,
)

router = APIRouter(prefix="/admin", tags=["Admin & Live Ops"])

async def record_audit_log(
    db: AsyncSession,
    admin: AdminUser,
    action: str,
    target_type: str,
    target_id: Optional[str] = None,
    details: Optional[Dict[str, Any] | str] = None,
    ip_address: Optional[str] = None,
):
    details_str = json.dumps(details) if isinstance(details, dict) else details
    audit_log = AdminAuditLog(
        admin_id=admin.id,
        admin_username=admin.username,
        action=action,
        target_type=target_type,
        target_id=target_id,
        details=details_str,
        ip_address=ip_address,
    )
    db.add(audit_log)
    await db.commit()

@router.post("/auth/login", response_model=AdminLoginResponse)
async def admin_login(
    payload: AdminLoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    stmt = select(AdminUser).where(AdminUser.username == payload.username)
    result = await db.execute(stmt)
    admin = result.scalar_one_or_none()

    if admin is None or not verify_password(payload.password, admin.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin username or password",
        )

    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin account is deactivated",
        )

    admin.last_login_at = datetime.now(timezone.utc)
    await db.commit()

    token_payload = {
        "sub": admin.id,
        "type": "admin",
        "username": admin.username,
        "role": admin.role,
        "iat": datetime.now(timezone.utc),
    }
    token = jwt.encode(token_payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

    await record_audit_log(
        db,
        admin,
        action="ADMIN_LOGIN",
        target_type="ADMIN",
        target_id=admin.id,
        ip_address=request.client.host if request.client else None,
    )

    return AdminLoginResponse(
        access_token=token,
        token_type="bearer",
        admin=AdminUserResponse.model_validate(admin),
    )

@router.get("/auth/me", response_model=AdminUserResponse)
async def admin_get_me(current_admin: AdminUser = Depends(get_current_admin)):
    return AdminUserResponse.model_validate(current_admin)

@router.get("/dashboard/kpis", response_model=AdminKpiOverview)
async def get_dashboard_kpis(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    total_users = await db.scalar(select(func.count(User.id))) or 0
    active_rooms = await db.scalar(
        select(func.count(Room.id)).where(Room.status.in_(["WAITING", "STARTING"]))
    ) or 0
    total_matches = await db.scalar(select(func.count(Match.id))) or 0
    total_coins = await db.scalar(select(func.sum(Wallet.coins))) or 0
    total_gems = await db.scalar(select(func.sum(Wallet.gems))) or 0
    pending_reports = await db.scalar(
        select(func.count(Report.id)).where(Report.status.in_(["PENDING", "OPEN"]))
    ) or 0
    active_tournaments = await db.scalar(
        select(func.count(Tournament.id)).where(
            Tournament.status.in_(["REGISTRATION", "IN_PROGRESS"])
        )
    ) or 0

    return AdminKpiOverview(
        total_users=total_users,
        active_users_today=total_users,
        active_rooms=active_rooms,
        total_matches=total_matches,
        total_coins_in_circulation=int(total_coins),
        total_gems_in_circulation=int(total_gems),
        pending_reports_count=pending_reports,
        active_tournaments_count=active_tournaments,
    )

@router.get("/users", response_model=List[AdminUserSummary])
async def list_users(
    query: Optional[str] = Query(None, description="Search by player_id, username or user_id"),
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(50, le=100),
    offset: int = Query(0, ge=0),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(User)
        .options(
            selectinload(User.profile),
            selectinload(User.stats),
            selectinload(User.wallet),
        )
        .order_by(User.created_at.desc())
        .limit(limit)
        .offset(offset)
    )

    if status_filter:
        stmt = stmt.where(User.status == status_filter)

    if query:
        search_term = f"%{query}%"
        stmt = stmt.join(User.profile).where(
            (User.id == query)
            | (Profile.player_id.ilike(search_term))
            | (Profile.display_name.ilike(search_term))
        )

    result = await db.execute(stmt)
    users = result.scalars().all()

    summaries = []
    for u in users:
        summaries.append(
            AdminUserSummary(
                id=u.id,
                player_id=u.profile.player_id if u.profile else "UNKNOWN",
                display_name=u.profile.display_name if u.profile else "Guest",
                level=u.profile.level if u.profile else 1,
                status=u.status,
                is_guest=u.is_guest,
                is_verified=u.is_verified,
                coins=u.wallet.coins if u.wallet else 0,
                gems=u.wallet.gems if u.wallet else 0,
                matches_played=u.stats.matches_played if u.stats else 0,
                matches_won=u.stats.matches_won if u.stats else 0,
                created_at=u.created_at,
            )
        )
    return summaries

@router.get("/users/{user_id}", response_model=AdminUserDetailResponse)
async def get_user_detail(
    user_id: str,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(User)
        .options(
            selectinload(User.profile),
            selectinload(User.stats),
            selectinload(User.wallet),
            selectinload(User.devices),
            selectinload(User.identities),
        )
        .where(User.id == user_id)
    )
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    profile_dict = (
        {
            "player_id": user.profile.player_id,
            "display_name": user.profile.display_name,
            "avatar_id": user.profile.avatar_id,
            "level": user.profile.level,
            "xp": user.profile.xp,
            "country_code": user.profile.country_code,
        }
        if user.profile
        else None
    )

    stats_dict = (
        {
            "matches_played": user.stats.matches_played,
            "matches_won": user.stats.matches_won,
            "win_streak": user.stats.win_streak,
            "best_streak": user.stats.best_streak,
            "total_captures": user.stats.total_captures,
            "total_tokens_home": user.stats.total_tokens_home,
        }
        if user.stats
        else None
    )

    wallet_dict = (
        {"coins": user.wallet.coins, "gems": user.wallet.gems}
        if user.wallet
        else None
    )

    devices_list = [
        {
            "device_id": d.device_id,
            "platform": d.platform,
            "app_version": d.app_version,
            "last_active_at": d.last_active_at.isoformat(),
        }
        for d in user.devices
    ]

    identities_list = [
        {
            "provider": i.provider,
            "provider_user_id": i.provider_user_id,
            "created_at": i.created_at.isoformat(),
        }
        for i in user.identities
    ]

    return AdminUserDetailResponse(
        id=user.id,
        status=user.status,
        is_guest=user.is_guest,
        is_verified=user.is_verified,
        created_at=user.created_at,
        updated_at=user.updated_at,
        profile=profile_dict,
        stats=stats_dict,
        wallet=wallet_dict,
        devices=devices_list,
        identities=identities_list,
    )

@router.post("/users/{user_id}/suspend")
async def suspend_user(
    user_id: str,
    payload: AdminSuspendRequest,
    current_admin: AdminUser = Depends(require_admin_role(["SUPER_ADMIN", "MODERATOR"])),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(User).where(User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    user.status = "SUSPENDED"

    # Revoke sessions
    revoke_stmt = select(RefreshSession).where(RefreshSession.user_id == user_id)
    sessions = (await db.execute(revoke_stmt)).scalars().all()
    for s in sessions:
        s.revoked = True

    await db.commit()

    await record_audit_log(
        db,
        current_admin,
        action="USER_SUSPEND",
        target_type="USER",
        target_id=user_id,
        details={"reason": payload.reason, "duration_days": payload.duration_days},
    )

    return {"status": "success", "message": f"User {user_id} suspended", "user_status": "SUSPENDED"}

@router.post("/users/{user_id}/unsuspend")
async def unsuspend_user(
    user_id: str,
    current_admin: AdminUser = Depends(require_admin_role(["SUPER_ADMIN", "MODERATOR"])),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(User).where(User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    user.status = "ACTIVE"
    await db.commit()

    await record_audit_log(
        db,
        current_admin,
        action="USER_UNSUSPEND",
        target_type="USER",
        target_id=user_id,
    )

    return {"status": "success", "message": f"User {user_id} unsuspended", "user_status": "ACTIVE"}

@router.post("/users/{user_id}/wallet-adjust")
async def adjust_user_wallet(
    user_id: str,
    payload: AdminWalletAdjustRequest,
    current_admin: AdminUser = Depends(require_admin_role(["SUPER_ADMIN"])),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Wallet).where(Wallet.user_id == user_id)
    result = await db.execute(stmt)
    wallet = result.scalar_one_or_none()

    if wallet is None:
        raise HTTPException(status_code=404, detail="User wallet not found")

    currency_upper = payload.currency.upper()
    if currency_upper == "COINS":
        wallet.coins = max(0, wallet.coins + payload.amount)
        balance_after = wallet.coins
    elif currency_upper == "GEMS":
        wallet.gems = max(0, wallet.gems + payload.amount)
        balance_after = wallet.gems
    else:
        raise HTTPException(status_code=400, detail="Invalid currency, must be COINS or GEMS")

    ledger_entry = WalletLedger(
        wallet_id=wallet.id,
        amount=payload.amount,
        currency=currency_upper,
        balance_after=balance_after,
        reason=f"ADMIN_ADJUST: {payload.reason}",
        idempotency_key=payload.idempotency_key,
    )
    db.add(ledger_entry)
    await db.commit()

    await record_audit_log(
        db,
        current_admin,
        action="WALLET_ADJUST",
        target_type="ECONOMY",
        target_id=user_id,
        details={
            "amount": payload.amount,
            "currency": currency_upper,
            "reason": payload.reason,
            "balance_after": balance_after,
        },
    )

    return {
        "status": "success",
        "currency": currency_upper,
        "amount_adjusted": payload.amount,
        "balance_after": balance_after,
    }

@router.get("/matches")
async def list_matches(
    status_filter: Optional[str] = Query(None, alias="status"),
    mode_filter: Optional[str] = Query(None, alias="mode"),
    limit: int = Query(50, le=100),
    offset: int = Query(0, ge=0),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(Match)
        .options(selectinload(Match.players))
        .order_by(Match.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    if status_filter:
        stmt = stmt.where(Match.status == status_filter)
    if mode_filter:
        stmt = stmt.where(Match.mode == mode_filter)

    result = await db.execute(stmt)
    matches = result.scalars().all()

    items = []
    for m in matches:
        items.append(
            {
                "id": m.id,
                "room_id": m.room_id,
                "mode": m.mode,
                "ruleset_version": m.ruleset_version,
                "status": m.status,
                "winning_color": m.winning_color,
                "winning_user_id": m.winning_user_id,
                "player_count": len(m.players),
                "players": [
                    {
                        "user_id": p.user_id,
                        "color": p.color,
                        "seat_index": p.seat_index,
                        "is_bot": p.is_bot,
                        "rank": p.rank,
                    }
                    for p in m.players
                ],
                "created_at": m.created_at.isoformat(),
                "finished_at": m.finished_at.isoformat() if m.finished_at else None,
            }
        )
    return items

@router.get("/matches/{match_id}")
async def get_match_timeline(
    match_id: str,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(Match)
        .options(
            selectinload(Match.players),
            selectinload(Match.snapshots),
            selectinload(Match.events),
        )
        .where(Match.id == match_id)
    )
    result = await db.execute(stmt)
    match = result.scalar_one_or_none()

    if match is None:
        raise HTTPException(status_code=404, detail="Match not found")

    events = sorted(match.events, key=lambda e: e.sequence)
    snapshots = sorted(match.snapshots, key=lambda s: s.sequence)

    return {
        "id": match.id,
        "mode": match.mode,
        "status": match.status,
        "winning_color": match.winning_color,
        "winning_user_id": match.winning_user_id,
        "created_at": match.created_at.isoformat(),
        "finished_at": match.finished_at.isoformat() if match.finished_at else None,
        "players": [
            {
                "user_id": p.user_id,
                "color": p.color,
                "seat_index": p.seat_index,
                "is_bot": p.is_bot,
                "rank": p.rank,
            }
            for p in match.players
        ],
        "events": [
            {
                "sequence": e.sequence,
                "event_type": e.event_type,
                "payload": json.loads(e.payload) if isinstance(e.payload, str) else e.payload,
                "created_at": e.created_at.isoformat(),
            }
            for e in events
        ],
        "snapshots_count": len(snapshots),
    }

@router.get("/reports")
async def list_reports(
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(50, le=100),
    offset: int = Query(0, ge=0),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(Report)
        .order_by(Report.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    if status_filter:
        if status_filter.upper() == "PENDING":
            stmt = stmt.where(Report.status.in_(["PENDING", "OPEN"]))
        else:
            stmt = stmt.where(Report.status == status_filter.upper())

    result = await db.execute(stmt)
    reports = result.scalars().all()

    return [
        {
            "id": r.id,
            "reporter_id": r.reporter_id,
            "reported_user_id": r.reported_user_id,
            "match_id": r.match_id,
            "category": r.category,
            "reason": r.description or "",
            "description": r.description or "",
            "status": r.status,
            "created_at": r.created_at.isoformat(),
        }
        for r in reports
    ]

@router.post("/reports/{report_id}/action")
async def action_report(
    report_id: str,
    payload: AdminReportActionRequest,
    current_admin: AdminUser = Depends(require_admin_role(["SUPER_ADMIN", "MODERATOR"])),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Report).where(Report.id == report_id)
    result = await db.execute(stmt)
    report = result.scalar_one_or_none()

    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")

    action_upper = payload.action.upper()
    if action_upper == "DISMISS":
        report.status = "DISMISSED"
    elif action_upper in ["SUSPEND_USER", "WARN"]:
        report.status = "RESOLVED"
        if action_upper == "SUSPEND_USER":
            user_stmt = select(User).where(User.id == report.reported_user_id)
            user = (await db.execute(user_stmt)).scalar_one_or_none()
            if user:
                user.status = "SUSPENDED"
    else:
        raise HTTPException(status_code=400, detail="Invalid action")

    await db.commit()

    await record_audit_log(
        db,
        current_admin,
        action=f"REPORT_{action_upper}",
        target_type="REPORT",
        target_id=report_id,
        details={"action": action_upper, "notes": payload.notes, "reported_user": report.reported_user_id},
    )

    return {"status": "success", "report_status": report.status, "action_applied": action_upper}

@router.get("/catalog")
async def list_catalog(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(CatalogItem).order_by(CatalogItem.created_at.desc())
    result = await db.execute(stmt)
    items = result.scalars().all()
    return items

@router.post("/catalog")
async def upsert_catalog_item(
    payload: AdminCatalogItemRequest,
    current_admin: AdminUser = Depends(require_admin_role(["SUPER_ADMIN"])),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(CatalogItem).where(CatalogItem.id == payload.id)
    result = await db.execute(stmt)
    item = result.scalar_one_or_none()

    if item is None:
        item = CatalogItem(
            id=payload.id,
            name=payload.name,
            category=payload.category,
            price_coins=payload.price_coins,
            price_gems=payload.price_gems,
            is_active=payload.is_active,
            rarity=payload.rarity,
            asset_path=payload.asset_path,
        )
        db.add(item)
    else:
        item.name = payload.name
        item.category = payload.category
        item.price_coins = payload.price_coins
        item.price_gems = payload.price_gems
        item.is_active = payload.is_active
        item.rarity = payload.rarity
        item.asset_path = payload.asset_path

    await db.commit()

    await record_audit_log(
        db,
        current_admin,
        action="CATALOG_UPSERT",
        target_type="CATALOG",
        target_id=item.id,
        details={"name": item.name, "category": item.category, "price_coins": item.price_coins},
    )

    return {"status": "success", "item_id": item.id}

@router.get("/config")
async def get_config_and_flags(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    configs = (await db.execute(select(RemoteConfig))).scalars().all()
    flags = (await db.execute(select(FeatureFlag))).scalars().all()
    return {
        "remote_config": {c.key: {"value": c.value, "description": c.description} for c in configs},
        "feature_flags": {f.name: {"enabled": f.enabled, "description": f.description} for f in flags},
    }

@router.post("/config/remote-config")
async def update_remote_config(
    payload: AdminConfigUpdateRequest,
    current_admin: AdminUser = Depends(require_admin_role(["SUPER_ADMIN"])),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(RemoteConfig).where(RemoteConfig.key == payload.key)
    result = await db.execute(stmt)
    config = result.scalar_one_or_none()

    if config is None:
        config = RemoteConfig(key=payload.key, value=payload.value, description=payload.description)
        db.add(config)
    else:
        config.value = payload.value
        if payload.description:
            config.description = payload.description

    await db.commit()

    await record_audit_log(
        db,
        current_admin,
        action="CONFIG_UPDATE",
        target_type="CONFIG",
        target_id=payload.key,
        details={"value": payload.value},
    )

    return {"status": "success", "key": payload.key, "value": payload.value}

@router.post("/config/feature-flags")
async def toggle_feature_flag(
    payload: AdminFeatureFlagToggleRequest,
    current_admin: AdminUser = Depends(require_admin_role(["SUPER_ADMIN"])),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(FeatureFlag).where(FeatureFlag.name == payload.name)
    result = await db.execute(stmt)
    flag = result.scalar_one_or_none()

    if flag is None:
        flag = FeatureFlag(name=payload.name, enabled=payload.enabled, description=payload.description)
        db.add(flag)
    else:
        flag.enabled = payload.enabled
        if payload.description:
            flag.description = payload.description

    await db.commit()

    await record_audit_log(
        db,
        current_admin,
        action="FEATURE_FLAG_TOGGLE",
        target_type="CONFIG",
        target_id=payload.name,
        details={"enabled": payload.enabled},
    )

    return {"status": "success", "name": payload.name, "enabled": payload.enabled}

@router.get("/audit-logs", response_model=List[AdminAuditLogResponse])
async def list_audit_logs(
    limit: int = Query(50, le=100),
    offset: int = Query(0, ge=0),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(AdminAuditLog)
        .order_by(AdminAuditLog.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    result = await db.execute(stmt)
    logs = result.scalars().all()
    return logs
