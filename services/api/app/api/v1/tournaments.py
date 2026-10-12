from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.tournament import (
    TournamentResponse,
    TournamentDetailResponse,
    TournamentJoinResponse,
)
from app.services.tournament_service import TournamentService

router = APIRouter(prefix="/tournaments", tags=["Tournaments"])

@router.get("", response_model=List[TournamentResponse])
async def list_tournaments(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await TournamentService.list_tournaments(db, current_user.id)

@router.get("/{tournament_id}", response_model=TournamentDetailResponse)
async def get_tournament_details(
    tournament_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await TournamentService.get_tournament_details(db, tournament_id, current_user.id)

@router.post("/{tournament_id}/join", response_model=TournamentJoinResponse)
async def join_tournament(
    tournament_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await TournamentService.join_tournament(db, current_user.id, tournament_id)
