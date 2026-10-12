from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.season import (
    SeasonDetailResponse,
    ClaimSeasonRewardRequest,
    ClaimSeasonRewardResponse,
)
from app.services.season_service import SeasonService

router = APIRouter(prefix="/seasons", tags=["Seasons"])

@router.post("/premium-pass")
async def unlock_premium_pass(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await SeasonService.unlock_premium_pass(db, current_user.id)

@router.get("/current", response_model=SeasonDetailResponse)
async def get_current_season(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await SeasonService.get_current_season_details(db, current_user.id)

@router.post("/claim", response_model=ClaimSeasonRewardResponse)
async def claim_season_reward(
    req: ClaimSeasonRewardRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await SeasonService.claim_tier_reward(
        db=db,
        user_id=current_user.id,
        tier_number=req.tier_number,
        is_premium=req.is_premium,
    )
