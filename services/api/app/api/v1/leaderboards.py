from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.leaderboard import (
    LeaderboardResponse,
    MyLeaderboardRankResponse,
)
from app.services.leaderboard_service import LeaderboardService

router = APIRouter(prefix="/leaderboards", tags=["Leaderboards"])

@router.get("", response_model=LeaderboardResponse)
async def get_leaderboard(
    scope: str = Query("ALL_TIME", pattern="^(ALL_TIME|WEEKLY|SEASONAL)$"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await LeaderboardService.get_leaderboard(db, scope=scope, limit=limit, offset=offset)

@router.get("/my-rank", response_model=MyLeaderboardRankResponse)
async def get_my_rank(
    scope: str = Query("ALL_TIME", pattern="^(ALL_TIME|WEEKLY|SEASONAL)$"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await LeaderboardService.get_my_rank(db, current_user.id, scope=scope)
