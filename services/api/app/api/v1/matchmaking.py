from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.matchmaking import EnqueueRequest, TicketResponse
from app.services.matchmaker import matchmaker_service

router = APIRouter(prefix="/matchmaking", tags=["Matchmaking"])

def map_ticket_response(ticket) -> TicketResponse:
    now = datetime.now(timezone.utc)
    created = ticket.created_at.replace(tzinfo=timezone.utc) if ticket.created_at.tzinfo is None else ticket.created_at
    queue_time = int((now - created).total_seconds())
    return TicketResponse(
        ticket_id=ticket.id,
        status=ticket.status,
        matched_match_id=ticket.matched_match_id,
        player_count=ticket.player_count,
        rating=ticket.rating,
        queue_time_seconds=max(0, queue_time),
    )

@router.post("/enqueue", response_model=TicketResponse, status_code=status.HTTP_201_CREATED)
async def enqueue_for_match(
    payload: EnqueueRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ticket = await matchmaker_service.enqueue(
        db=db,
        user=current_user,
        mode=payload.mode,
        player_count=payload.player_count,
        region=payload.region,
    )
    return map_ticket_response(ticket)

@router.get("/ticket/{ticket_id}", response_model=TicketResponse)
async def get_matchmaking_ticket(
    ticket_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ticket = await matchmaker_service.get_ticket(db, ticket_id, current_user.id)
    if not ticket:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found.")
    return map_ticket_response(ticket)

@router.post("/ticket/{ticket_id}/cancel")
async def cancel_matchmaking_ticket(
    ticket_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    cancelled = await matchmaker_service.cancel_ticket(db, ticket_id, current_user.id)
    if not cancelled:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Ticket could not be cancelled.")
    return {"message": "Matchmaking ticket cancelled.", "status": "CANCELLED"}
