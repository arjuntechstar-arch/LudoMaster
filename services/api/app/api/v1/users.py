import re
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.core.security import get_password_hash, verify_password
from app.db.session import get_db
from app.models.match import MatchPlayer
from app.models.profile import Profile
from app.models.user import User, UserIdentity
from app.schemas.user import (
    PlayerStatsResponse,
    ProfileResponse,
    ProfileUpdateRequest,
    PasswordChangeRequest,
    UserMeResponse,
    WalletResponse,
)

router = APIRouter(prefix="/me", tags=["User & Profile"])

@router.get("", response_model=UserMeResponse)
async def get_my_account(
    current_user: User = Depends(get_current_user),
):
    profile = current_user.profile
    stats = current_user.stats
    wallet = current_user.wallet

    matches_played = stats.matches_played if stats else 0
    matches_won = stats.matches_won if stats else 0
    win_rate = (matches_won / matches_played * 100.0) if matches_played > 0 else 0.0

    return UserMeResponse(
        id=current_user.id,
        is_guest=current_user.is_guest,
        is_verified=current_user.is_verified,
        profile=ProfileResponse(
            user_id=current_user.id,
            player_id=profile.player_id if profile else "LM-00000",
            username=profile.username if profile else None,
            display_name=profile.display_name if profile else "Player",
            avatar_id=profile.avatar_id if profile else "avatar_0",
            level=profile.level if profile else 1,
            xp=profile.xp if profile else 0,
            country_code=profile.country_code if profile else "GLB",
            is_guest=current_user.is_guest,
            is_verified=current_user.is_verified,
        ),
        stats=PlayerStatsResponse(
            user_id=current_user.id,
            matches_played=matches_played,
            matches_won=matches_won,
            win_rate_percent=round(win_rate, 1),
            win_streak=stats.win_streak if stats else 0,
            best_streak=stats.best_streak if stats else 0,
            total_captures=stats.total_captures if stats else 0,
            total_tokens_home=stats.total_tokens_home if stats else 0,
        ),
        wallet=WalletResponse(
            user_id=current_user.id,
            coins=wallet.coins if wallet else 0,
            gems=wallet.gems if wallet else 0,
        ),
    )

@router.get("/profile", response_model=ProfileResponse)
async def get_my_profile(
    current_user: User = Depends(get_current_user),
):
    p = current_user.profile
    if not p:
        raise HTTPException(status_code=404, detail="Profile not found")

    return ProfileResponse(
        user_id=current_user.id,
        player_id=p.player_id,
        username=p.username,
        display_name=p.display_name,
        avatar_id=p.avatar_id,
        level=p.level,
        xp=p.xp,
        country_code=p.country_code,
        is_guest=current_user.is_guest,
        is_verified=current_user.is_verified,
    )

@router.get("/username-availability")
async def username_availability(username: str, db: AsyncSession = Depends(get_db)):
    name = username.strip().removeprefix("@").lower()
    if not re.fullmatch(r"[a-z][a-z0-9_]{2,19}", name):
        return {"username": name, "available": False, "reason": "Use 3–20 characters: start with a letter, then letters, numbers or underscores."}
    result = await db.execute(select(Profile.user_id).where(Profile.username == name))
    owner = result.scalar_one_or_none()
    available = owner is None
    return {"username": name, "available": available, "reason": None if available else "This username is already taken."}

@router.patch("/profile", response_model=ProfileResponse)
async def update_my_profile(
    req: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    p = current_user.profile
    if not p:
        raise HTTPException(status_code=404, detail="Profile not found")

    if req.avatar_id is not None and req.avatar_id not in {f"avatar_{i}" for i in range(8)}:
        # Owned store avatars remain selectable; free avatars need no purchase.
        from app.models.inventory import CatalogItem, UserInventory
        owned = await db.scalar(select(UserInventory.id).join(CatalogItem, UserInventory.item_id == CatalogItem.id).where(
            UserInventory.user_id == current_user.id, CatalogItem.asset_key == req.avatar_id, CatalogItem.category == "AVATAR"))
        if not owned:
            raise HTTPException(status_code=400, detail="Choose a free avatar or one you own.")
    if req.avatar_id is not None:
        p.avatar_id = req.avatar_id
    await db.commit()
    await db.refresh(p)

    return ProfileResponse(
        user_id=current_user.id,
        player_id=p.player_id,
        username=p.username,
        display_name=p.display_name,
        avatar_id=p.avatar_id,
        level=p.level,
        xp=p.xp,
        country_code=p.country_code,
        is_guest=current_user.is_guest,
        is_verified=current_user.is_verified,
    )


@router.patch("/password")
async def change_my_password(
    req: PasswordChangeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    identity = await db.scalar(select(UserIdentity).where(
        UserIdentity.user_id == current_user.id,
        UserIdentity.provider == "EMAIL",
    ))
    if identity is None or identity.credential_hash is None:
        raise HTTPException(
            status_code=400,
            detail="This account has no email password. Manage its password through the sign-in provider.",
        )
    if not verify_password(req.current_password, identity.credential_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect.")
    identity.credential_hash = get_password_hash(req.new_password)
    await db.commit()
    return {"status": "success", "message": "Password updated."}

@router.get("/stats", response_model=PlayerStatsResponse)
async def get_my_stats(
    current_user: User = Depends(get_current_user),
):
    s = current_user.stats
    if not s:
        raise HTTPException(status_code=404, detail="Stats not found")

    win_rate = (s.matches_won / s.matches_played * 100.0) if s.matches_played > 0 else 0.0

    return PlayerStatsResponse(
        user_id=current_user.id,
        matches_played=s.matches_played,
        matches_won=s.matches_won,
        win_rate_percent=round(win_rate, 1),
        win_streak=s.win_streak,
        best_streak=s.best_streak,
        total_captures=s.total_captures,
        total_tokens_home=s.total_tokens_home,
    )

# Public player lookup router
players_router = APIRouter(prefix="/players", tags=["Public Players"])

@players_router.get("/recent", response_model=List[ProfileResponse])
async def get_recent_players(
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    subq = (
        select(MatchPlayer.match_id)
        .where(MatchPlayer.user_id == current_user.id)
        .order_by(MatchPlayer.id.desc())
        .limit(10)
    )
    match_ids_res = await db.execute(subq)
    match_ids = [m[0] for m in match_ids_res.fetchall()]

    if not match_ids:
        return []

    opponents_q = await db.execute(
        select(MatchPlayer.user_id)
        .where(
            MatchPlayer.match_id.in_(match_ids),
            MatchPlayer.user_id.isnot(None),
            MatchPlayer.user_id != current_user.id,
        )
        .distinct()
        .limit(limit)
    )
    opp_user_ids = [o[0] for o in opponents_q.fetchall()]

    if not opp_user_ids:
        return []

    profiles_q = await db.execute(
        select(Profile)
        .options(selectinload(Profile.user))
        .where(Profile.user_id.in_(opp_user_ids))
    )
    profiles = profiles_q.scalars().all()

    return [
        ProfileResponse(
            user_id=p.user_id,
            player_id=p.player_id,
            username=p.username,
            display_name=p.display_name,
            avatar_id=p.avatar_id,
            level=p.level,
            xp=p.xp,
            country_code=p.country_code,
            is_guest=p.user.is_guest,
            is_verified=p.user.is_verified,
        )
        for p in profiles
    ]

@players_router.get("/{player_id}", response_model=ProfileResponse)
async def get_player_by_id(
    player_id: str,
    db: AsyncSession = Depends(get_db),
):
    # Lookup by player_id (e.g. LM-12345) or user UUID
    stmt = (
        select(Profile)
        .join(User)
        .where(
            (Profile.username == player_id.strip().removeprefix("@").lower()) | (Profile.player_id == player_id) | (Profile.user_id == player_id)
        )
    )
    res = await db.execute(stmt)
    p = res.scalar_one_or_none()

    if not p:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Player not found")

    return ProfileResponse(
        user_id=p.user_id,
        player_id=p.player_id,
        username=p.username,
        display_name=p.display_name,
        avatar_id=p.avatar_id,
        level=p.level,
        xp=p.xp,
        country_code=p.country_code,
        is_guest=p.user.is_guest,
        is_verified=p.user.is_verified,
    )
