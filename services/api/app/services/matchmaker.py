import asyncio
from datetime import datetime, timezone
import logging
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.match import Match, MatchPlayer
from app.models.matchmaking import MatchmakingTicket
from app.models.profile import PlayerStats
from app.models.user import User

logger = logging.getLogger("matchmaking")

COLORS_4 = ["RED", "GREEN", "YELLOW", "BLUE"]
COLORS_6 = ["RED", "GREEN", "YELLOW", "BLUE", "ORANGE", "PURPLE"]

def calculate_rating(stats: Optional[PlayerStats]) -> int:
    if not stats or stats.matches_played == 0:
        return 1000
    won = stats.matches_won
    lost = max(0, stats.matches_played - won)
    mmr = 1000 + (won * 25) - (lost * 15)
    return max(500, min(3000, mmr))

class MatchmakingService:
    async def enqueue(
        self,
        db: AsyncSession,
        user: User,
        mode: str = "CLASSIC",
        player_count: int = 4,
        region: str = "GLOBAL",
    ) -> MatchmakingTicket:
        # Cancel any existing queued ticket for this user
        existing_q = await db.execute(
            select(MatchmakingTicket).where(
                MatchmakingTicket.user_id == user.id,
                MatchmakingTicket.status == "QUEUED",
            )
        )
        for old in existing_q.scalars().all():
            old.status = "CANCELLED"

        rating = calculate_rating(user.stats)

        ticket = MatchmakingTicket(
            user_id=user.id,
            mode=mode,
            player_count=player_count,
            rating=rating,
            region=region,
            status="QUEUED",
        )
        db.add(ticket)
        await db.commit()
        await db.refresh(ticket)

        # Trigger matching evaluation
        await self.evaluate_queue(db, mode, player_count, region)
        await db.refresh(ticket)
        return ticket

    async def get_ticket(
        self, db: AsyncSession, ticket_id: str, user_id: str
    ) -> Optional[MatchmakingTicket]:
        q = await db.execute(
            select(MatchmakingTicket).where(
                MatchmakingTicket.id == ticket_id,
                MatchmakingTicket.user_id == user_id,
            )
        )
        ticket = q.scalar_one_or_none()
        if ticket and ticket.status == "QUEUED":
            # Re-evaluate queue on poll
            await self.evaluate_queue(db, ticket.mode, ticket.player_count, ticket.region)
            await db.refresh(ticket)
        return ticket

    async def cancel_ticket(
        self, db: AsyncSession, ticket_id: str, user_id: str
    ) -> bool:
        q = await db.execute(
            select(MatchmakingTicket).where(
                MatchmakingTicket.id == ticket_id,
                MatchmakingTicket.user_id == user_id,
                MatchmakingTicket.status == "QUEUED",
            )
        )
        ticket = q.scalar_one_or_none()
        if ticket:
            ticket.status = "CANCELLED"
            await db.commit()
            return True
        return False

    async def evaluate_queue(
        self, db: AsyncSession, mode: str, player_count: int, region: str
    ):
        q = await db.execute(
            select(MatchmakingTicket)
            .where(
                MatchmakingTicket.mode == mode,
                MatchmakingTicket.player_count == player_count,
                MatchmakingTicket.region == region,
                MatchmakingTicket.status == "QUEUED",
            )
            .order_by(MatchmakingTicket.created_at.asc())
        )
        tickets = list(q.scalars().all())
        if not tickets:
            return

        now = datetime.now(timezone.utc)
        colors = (
            ["RED", "YELLOW"]
            if player_count == 2
            else COLORS_6 if player_count > 4 else COLORS_4
        )

        # Grouping with gradual rating relaxation
        matched_groups: List[List[MatchmakingTicket]] = []
        unassigned = list(tickets)

        while unassigned:
            head = unassigned.pop(0)
            wait_seconds = (now - head.created_at.replace(tzinfo=timezone.utc if head.created_at.tzinfo is None else head.created_at.tzinfo)).total_seconds()
            rating_tolerance = 150 + int(wait_seconds * 35)

            group = [head]
            i = 0
            while i < len(unassigned) and len(group) < player_count:
                cand = unassigned[i]
                if abs(cand.rating - head.rating) <= rating_tolerance:
                    group.append(cand)
                    unassigned.pop(i)
                else:
                    i += 1

            # Match criteria: Full human group OR wait time > 5.0 seconds (bot fill fallback)
            if len(group) == player_count or wait_seconds >= 5.0:
                matched_groups.append(group)

        # Form matches for all matched groups
        for group in matched_groups:
            match = Match(
                mode=mode,
                status="ACTIVE",
                ruleset_version=1,
            )
            db.add(match)
            await db.flush()

            # Seat humans
            for seat_idx, ticket in enumerate(group):
                color = colors[seat_idx % len(colors)]
                mp = MatchPlayer(
                    match_id=match.id,
                    user_id=ticket.user_id,
                    seat_index=seat_idx,
                    color=color,
                    is_bot=False,
                )
                db.add(mp)
                ticket.status = "MATCHED"
                ticket.matched_match_id = match.id

            # Fill remaining seats with bots
            for seat_idx in range(len(group), player_count):
                color = colors[seat_idx % len(colors)]
                bot_mp = MatchPlayer(
                    match_id=match.id,
                    user_id=None,
                    seat_index=seat_idx,
                    color=color,
                    is_bot=True,
                )
                db.add(bot_mp)

        await db.commit()

matchmaker_service = MatchmakingService()
