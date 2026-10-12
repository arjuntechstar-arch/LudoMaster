from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.achievement import AchievementResponse, ClaimAchievementResponse
from app.services.rewards_service import rewards_service

router = APIRouter(prefix="/achievements", tags=["Achievements"])

@router.get("", response_model=List[AchievementResponse])
async def get_achievements(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user_achievements = await rewards_service.ensure_user_achievements(db, current_user.id)
    return [
        AchievementResponse(
            id=ua.achievement.id,
            title=ua.achievement.title,
            description=ua.achievement.description,
            action_type=ua.achievement.action_type,
            current_count=ua.current_count,
            target_count=ua.achievement.target_count,
            reward_coins=ua.achievement.reward_coins,
            reward_gems=ua.achievement.reward_gems,
            reward_xp=ua.achievement.reward_xp,
            badge_key=ua.achievement.badge_key,
            is_unlocked=ua.is_unlocked,
            is_claimed=ua.is_claimed,
        )
        for ua in user_achievements
    ]

@router.post("/{achievement_id}/claim", response_model=ClaimAchievementResponse)
async def claim_achievement(
    achievement_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        res = await rewards_service.claim_achievement(db, current_user.id, achievement_id)
        return ClaimAchievementResponse(**res)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
