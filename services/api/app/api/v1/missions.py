from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.mission import ClaimMissionResponse, MissionResponse
from app.services.rewards_service import rewards_service

router = APIRouter(prefix="/missions", tags=["Missions"])

@router.get("", response_model=List[MissionResponse])
async def get_missions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user_missions = await rewards_service.ensure_user_missions(db, current_user.id)
    return [
        MissionResponse(
            id=um.mission.id,
            title=um.mission.title,
            description=um.mission.description,
            category=um.mission.category,
            action_type=um.mission.action_type,
            current_count=um.current_count,
            target_count=um.mission.target_count,
            reward_coins=um.mission.reward_coins,
            reward_gems=um.mission.reward_gems,
            reward_xp=um.mission.reward_xp,
            icon=um.mission.icon,
            is_completed=um.is_completed,
            is_claimed=um.is_claimed,
        )
        for um in user_missions
    ]

@router.post("/{mission_id}/claim", response_model=ClaimMissionResponse)
async def claim_mission(
    mission_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        res = await rewards_service.claim_mission(db, current_user.id, mission_id)
        return ClaimMissionResponse(**res)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
