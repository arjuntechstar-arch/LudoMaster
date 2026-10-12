from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.match import Match, MatchPlayer
from app.models.user import User
from app.schemas.match import MatchHistoryItem, MatchHistoryResponse, MatchPlayerHistoryItem

router = APIRouter(prefix="/matches", tags=["Matches"])

@router.get("/my-history", response_model=MatchHistoryResponse)
async def get_my_match_history(
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Find match IDs where current_user participated
    subq = (
        select(MatchPlayer.match_id)
        .where(MatchPlayer.user_id == current_user.id)
        .order_by(MatchPlayer.id.desc())
        .limit(limit)
    )
    match_ids_res = await db.execute(subq)
    match_ids = [m[0] for m in match_ids_res.fetchall()]

    if not match_ids:
        return MatchHistoryResponse(matches=[])

    matches_q = await db.execute(
        select(Match)
        .options(selectinload(Match.players).selectinload(MatchPlayer.user).selectinload(User.profile))
        .where(Match.id.in_(match_ids))
        .order_by(Match.started_at.desc())
    )
    matches = matches_q.scalars().all()

    items: List[MatchHistoryItem] = []
    for m in matches:
        my_player = next((p for p in m.players if p.user_id == current_user.id), None)
        if not my_player:
            continue

        player_items = []
        for p in sorted(m.players, key=lambda x: x.seat_index):
            profile = p.user.profile if p.user else None
            name = profile.display_name if profile else ("Bot" if p.is_bot else f"Player {p.seat_index + 1}")
            avatar = profile.avatar_id if profile else "avatar_0"
            player_items.append(
                MatchPlayerHistoryItem(
                    user_id=p.user_id,
                    seat_index=p.seat_index,
                    display_name=name,
                    avatar_id=avatar,
                    color=p.color,
                    placement=p.placement,
                    is_bot=p.is_bot,
                )
            )

        items.append(
            MatchHistoryItem(
                id=m.id,
                mode=m.mode,
                status=m.status,
                my_placement=my_player.placement,
                my_color=my_player.color,
                coins_delta=my_player.coins_delta,
                xp_gained=my_player.xp_gained,
                started_at=m.started_at,
                finished_at=m.finished_at,
                players=player_items,
            )
        )

    return MatchHistoryResponse(matches=items)
