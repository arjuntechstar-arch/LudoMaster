import random
import uuid
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.dependencies import get_current_user
from app.core.security import (
    create_access_token,
    decode_access_token,
    create_refresh_token,
    get_password_hash,
    hash_token,
    verify_password,
)
from app.db.session import get_db
from app.models.profile import PlayerStats, Profile
from app.models.user import Device, RefreshSession, User, UserIdentity
from app.models.wallet import Wallet, WalletLedger
from app.models.inventory import CatalogItem, UserInventory
from app.models.purchase import PurchaseOrder
from app.models.notification import Notification
from app.schemas.auth import (
    GuestLoginRequest,
    GuestUpgradeRequest,
    LoginRequest,
    RefreshTokenRequest,
    RegisterRequest,
    TokenResponse,
    GoogleLoginRequest,
    PlayGamesLoginRequest,
)
from app.services.social_auth import social_auth_service
from app.services.account_deletion import remove_account_data, remove_live_account

router = APIRouter(prefix="/auth", tags=["Authentication"])

async def _social_current_user(request: Request, db: AsyncSession, link: bool) -> User | None:
    if not link:
        return None
    header = request.headers.get("Authorization", "")
    token = header[7:] if header.startswith("Bearer ") else ""
    user_id = decode_access_token(token) if token else None
    if not user_id:
        raise HTTPException(401, "Sign in before connecting this Google account")
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user or user.status != "ACTIVE":
        raise HTTPException(401, "Player account is unavailable")
    return user


def _social_profile_setup(req: GoogleLoginRequest | PlayGamesLoginRequest) -> dict | None:
    values = (req.display_name, req.username, req.avatar_id)
    if not any(value is not None for value in values):
        return None
    if not all(value is not None for value in values):
        raise HTTPException(422, "Choose a display name, username, and avatar to create your account")
    return {
        "display_name": req.display_name,
        "username": req.username,
        "avatar_id": req.avatar_id,
    }

@router.get("/providers")
async def get_auth_providers():
    return {
        "google_client_id": settings.GOOGLE_WEB_CLIENT_ID,
        "google_enabled": bool(settings.GOOGLE_WEB_CLIENT_ID),
        "play_games_enabled": bool(settings.GOOGLE_PLAY_GAMES_CLIENT_ID and settings.GOOGLE_PLAY_GAMES_CLIENT_SECRET),
        "play_games_server_client_id": settings.GOOGLE_PLAY_GAMES_CLIENT_ID,
    }

@router.post("/google", response_model=TokenResponse)
async def google_login(req: GoogleLoginRequest, request: Request, db: AsyncSession = Depends(get_db)):
    current = await _social_current_user(request, db, req.link_to_current_user)
    identity = await social_auth_service.verify_google(req.id_token)
    user = await social_auth_service.resolve_account(
        db, "GOOGLE", identity, current, link=req.link_to_current_user,
        profile_setup=_social_profile_setup(req),
    )
    return await _issue_token_response(db, user)

@router.post("/play-games", response_model=TokenResponse)
async def play_games_login(req: PlayGamesLoginRequest, request: Request, db: AsyncSession = Depends(get_db)):
    current = await _social_current_user(request, db, req.link_to_current_user)
    identity = await social_auth_service.verify_play_games(req.server_auth_code)
    user = await social_auth_service.resolve_account(
        db, "PLAY_GAMES", identity, current, link=req.link_to_current_user,
        profile_setup=_social_profile_setup(req),
    )
    return await _issue_token_response(db, user)

def _generate_player_id() -> str:
    """Generates unique player ID like LM-49821."""
    digits = random.randint(10000, 99999)
    return f"LM-{digits}"

async def _issue_token_response(
    db: AsyncSession,
    user: User,
    device_id: str | None = None,
) -> TokenResponse:
    # Generate tokens
    access_token = create_access_token(user.id)
    raw_refresh_token, refresh_hash = create_refresh_token()

    # Store refresh session
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    refresh_session = RefreshSession(
        user_id=user.id,
        device_id=device_id,
        refresh_token_hash=refresh_hash,
        expires_at=expires_at,
        revoked=False,
    )
    db.add(refresh_session)
    await db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=raw_refresh_token,
        token_type="Bearer",
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        user_id=user.id,
        player_id=user.profile.player_id if user.profile else "LM-00000",
        display_name=user.profile.display_name if user.profile else "Player",
        is_guest=user.is_guest,
    )

@router.post("/guest", response_model=TokenResponse)
async def login_as_guest(
    req: GuestLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    # Check if guest identity exists for this device
    stmt = (
        select(User)
        .join(UserIdentity)
        .where(
            UserIdentity.provider == "GUEST",
            UserIdentity.provider_user_id == req.device_id,
        )
    )
    result = await db.execute(stmt)
    existing_user = result.scalar_one_or_none()

    if existing_user:
        # Re-login existing guest
        return await _issue_token_response(db, existing_user, req.device_id)

    # Create brand new guest user
    user = User(is_guest=True, is_verified=False, status="ACTIVE")
    db.add(user)
    await db.flush()

    identity = UserIdentity(
        user_id=user.id,
        provider="GUEST",
        provider_user_id=req.device_id,
    )
    db.add(identity)

    device = Device(
        user_id=user.id,
        device_id=req.device_id,
        platform=req.platform,
        app_version=req.app_version,
        push_token=req.push_token,
    )
    db.add(device)

    # Initialize Profile with unique player ID
    player_id = _generate_player_id()
    profile = Profile(
        user_id=user.id,
        player_id=player_id,
        display_name=f"Guest_{player_id[-4:]}",
        avatar_id="avatar_0",
        level=1,
        xp=0,
    )
    db.add(profile)

    stats = PlayerStats(user_id=user.id)
    db.add(stats)

    wallet = Wallet(user_id=user.id, coins=1000, gems=10)
    db.add(wallet)
    await db.flush()

    # Initial balance ledger entry
    ledger = WalletLedger(
        wallet_id=wallet.id,
        amount=1000,
        currency="COINS",
        balance_after=1000,
        reason="WELCOME_BONUS",
        idempotency_key=f"welcome_{user.id}",
    )
    db.add(ledger)

    await db.commit()
    await db.refresh(user)

    return await _issue_token_response(db, user, req.device_id)

@router.post("/register", response_model=TokenResponse)
async def register(
    req: RegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    normalized_email = req.email.lower()

    # Check if email is already taken
    stmt = select(UserIdentity).where(
        UserIdentity.provider == "EMAIL",
        UserIdentity.provider_user_id == normalized_email,
    )
    result = await db.execute(stmt)
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email already exists",
        )

    username_owner = await db.scalar(select(Profile.user_id).where(Profile.username == req.username))
    if username_owner is not None:
        raise HTTPException(status_code=409, detail="This username is already taken.")

    user = User(is_guest=False, is_verified=True, status="ACTIVE")
    db.add(user)
    await db.flush()

    identity = UserIdentity(
        user_id=user.id,
        provider="EMAIL",
        provider_user_id=normalized_email,
        credential_hash=get_password_hash(req.password),
    )
    db.add(identity)

    device = Device(
        user_id=user.id,
        device_id=req.device_id,
        platform=req.platform,
        app_version=req.app_version,
    )
    db.add(device)

    player_id = _generate_player_id()
    profile = Profile(
        user_id=user.id,
        player_id=player_id,
        display_name=req.display_name,
        username=req.username,
        avatar_id=req.avatar_id,
        level=1,
        xp=0,
    )
    db.add(profile)

    stats = PlayerStats(user_id=user.id)
    db.add(stats)

    wallet = Wallet(user_id=user.id, coins=1000, gems=10)
    db.add(wallet)
    await db.flush()

    ledger = WalletLedger(
        wallet_id=wallet.id,
        amount=1000,
        currency="COINS",
        balance_after=1000,
        reason="WELCOME_BONUS",
        idempotency_key=f"welcome_{user.id}",
    )
    db.add(ledger)

    await db.commit()
    await db.refresh(user)

    return await _issue_token_response(db, user, req.device_id)

@router.post("/login", response_model=TokenResponse)
async def login(
    req: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    normalized_email = req.email.lower()

    stmt = select(UserIdentity).where(
        UserIdentity.provider == "EMAIL",
        UserIdentity.provider_user_id == normalized_email,
    )
    result = await db.execute(stmt)
    identity = result.scalar_one_or_none()

    if not identity or not identity.credential_hash or not verify_password(req.password, identity.credential_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    stmt_user = select(User).where(User.id == identity.user_id)
    res_user = await db.execute(stmt_user)
    user = res_user.scalar_one_or_none()

    if not user or user.status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is not active",
        )

    # Update or add device
    if req.device_id:
        stmt_dev = select(Device).where(Device.user_id == user.id, Device.device_id == req.device_id)
        res_dev = await db.execute(stmt_dev)
        device = res_dev.scalar_one_or_none()
        if device:
            device.last_active_at = datetime.now(timezone.utc)
            device.app_version = req.app_version
        else:
            db.add(Device(
                user_id=user.id,
                device_id=req.device_id,
                platform=req.platform,
                app_version=req.app_version,
            ))

    return await _issue_token_response(db, user, req.device_id)

@router.post("/upgrade", response_model=TokenResponse)
async def upgrade_guest_account(
    req: GuestUpgradeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not current_user.is_guest:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This account is already a verified full account",
        )

    normalized_email = req.email.lower()

    # Ensure email is not already taken
    stmt = select(UserIdentity).where(
        UserIdentity.provider == "EMAIL",
        UserIdentity.provider_user_id == normalized_email,
    )
    res = await db.execute(stmt)
    if res.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email already exists",
        )

    if current_user.profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    username_owner = await db.scalar(select(Profile.user_id).where(Profile.username == req.username))
    if username_owner is not None and username_owner != current_user.id:
        raise HTTPException(status_code=409, detail="This username is already taken.")

    # Attach email identity to existing user, preserving profile, stats, wallet!
    new_identity = UserIdentity(
        user_id=current_user.id,
        provider="EMAIL",
        provider_user_id=normalized_email,
        credential_hash=get_password_hash(req.password),
    )
    db.add(new_identity)

    current_user.is_guest = False
    current_user.is_verified = True
    current_user.profile.display_name = req.display_name
    current_user.profile.username = req.username
    current_user.profile.avatar_id = req.avatar_id

    await db.commit()
    await db.refresh(current_user)

    return await _issue_token_response(db, current_user)

@router.post("/refresh", response_model=TokenResponse)
async def refresh_access_token(
    req: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    token_hash = hash_token(req.refresh_token)

    stmt = select(RefreshSession).where(
        RefreshSession.refresh_token_hash == token_hash,
        RefreshSession.revoked == False,
    )
    res = await db.execute(stmt)
    session = res.scalar_one_or_none()

    now = datetime.now(timezone.utc)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    session_expires = (
        session.expires_at
        if session.expires_at.tzinfo
        else session.expires_at.replace(tzinfo=timezone.utc)
    )
    if session_expires < now:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    # Revoke old refresh session (token rotation)
    session.revoked = True

    stmt_user = select(User).where(User.id == session.user_id)
    res_user = await db.execute(stmt_user)
    user = res_user.scalar_one_or_none()

    if not user or user.status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is inactive",
        )

    return await _issue_token_response(db, user, session.device_id)

@router.post("/logout")
async def logout(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Revoke all active refresh sessions for this user
    stmt = select(RefreshSession).where(
        RefreshSession.user_id == current_user.id,
        RefreshSession.revoked == False,
    )
    res = await db.execute(stmt)
    sessions = res.scalars().all()
    for s in sessions:
        s.revoked = True
    await db.commit()

    return {"status": "success", "message": "Successfully logged out"}

@router.get("/export-data")
async def export_my_data(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """GDPR/Privacy export: returns personal data, statistics, wallet balances, inventory, notifications, and orders."""
    # 1. Profile & Stats
    profile_data = None
    if current_user.profile:
        profile_data = {
            "player_id": current_user.profile.player_id,
            "display_name": current_user.profile.display_name,
            "username": current_user.profile.username,
            "avatar_id": current_user.profile.avatar_id,
            "level": current_user.profile.level,
            "xp": current_user.profile.xp,
            "country_code": current_user.profile.country_code,
        }

    stats_data = None
    if current_user.stats:
        win_rate = (
            round((current_user.stats.matches_won / current_user.stats.matches_played * 100), 2)
            if current_user.stats.matches_played > 0
            else 0.0
        )
        stats_data = {
            "matches_played": current_user.stats.matches_played,
            "matches_won": current_user.stats.matches_won,
            "win_rate_percent": win_rate,
            "win_streak": current_user.stats.win_streak,
            "best_streak": current_user.stats.best_streak,
            "total_captures": current_user.stats.total_captures,
            "total_tokens_home": current_user.stats.total_tokens_home,
        }

    # 2. Wallet
    wallet_data = None
    if current_user.wallet:
        wallet_data = {
            "coins": current_user.wallet.coins,
            "gems": current_user.wallet.gems,
        }

    # 3. Inventory
    stmt_inv = (
        select(CatalogItem.id, CatalogItem.name, CatalogItem.category, UserInventory.is_equipped)
        .join(CatalogItem, UserInventory.item_id == CatalogItem.id)
        .where(UserInventory.user_id == current_user.id)
    )
    res_inv = await db.execute(stmt_inv)
    inventory_items = [
        {"item_id": row[0], "name": row[1], "category": row[2], "is_equipped": row[3]}
        for row in res_inv.all()
    ]

    # 4. Purchases
    stmt_purchases = select(PurchaseOrder).where(PurchaseOrder.user_id == current_user.id)
    res_purchases = await db.execute(stmt_purchases)
    purchases = [
        {
            "order_id": p.id,
            "product_id": p.product_id,
            "platform": p.platform,
            "price_cents": p.price_cents,
            "currency_code": p.currency_code,
            "status": p.status,
            "created_at": p.created_at.isoformat() if p.created_at else None,
        }
        for p in res_purchases.scalars().all()
    ]

    # 5. Notifications
    stmt_notifs = select(Notification).where(Notification.user_id == current_user.id)
    res_notifs = await db.execute(stmt_notifs)
    notifications = [
        {
            "id": n.id,
            "title": n.title,
            "body": n.body,
            "category": n.category,
            "is_read": n.is_read,
            "created_at": n.created_at.isoformat() if n.created_at else None,
        }
        for n in res_notifs.scalars().all()
    ]

    email = next(
        (i.provider_user_id for i in (current_user.identities or []) if i.provider == "EMAIL"),
        None,
    )

    return {
        "user_id": current_user.id,
        "email": email,
        "is_guest": current_user.is_guest,
        "status": current_user.status,
        "created_at": current_user.created_at.isoformat() if current_user.created_at else None,
        "profile": profile_data,
        "stats": stats_data,
        "wallet": wallet_data,
        "inventory": inventory_items,
        "purchases": purchases,
        "notifications": notifications,
        "export_timestamp": datetime.now(timezone.utc).isoformat(),
    }

@router.post("/delete-account")
async def delete_my_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete private account data and retire its live game connections."""
    await remove_account_data(db, current_user)
    await remove_live_account(current_user.id)
    return {
        "status": "DELETED",
        "message": "Account deleted. Login, device, profile and personal progress data removed. "
                   "Limited transaction, safety and shared match records are retained as described in the Privacy Policy.",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
