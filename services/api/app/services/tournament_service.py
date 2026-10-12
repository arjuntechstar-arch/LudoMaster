import datetime
import json
import uuid
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status
from app.models.tournament import Tournament, TournamentParticipant, TournamentMatch
from app.models.match import Match, MatchPlayer
from app.models.notification import Notification
from app.models.profile import Profile
from app.models.user import User
from app.services.economy import EconomyService

class TournamentService:
    @staticmethod
    async def _create_game(db: AsyncSession, participant_ids: List[str]) -> str:
        if len(participant_ids) != 4 or len(set(participant_ids)) != 4:
            raise ValueError("A championship match requires four distinct players")
        game = Match(id=str(uuid.uuid4()), mode="CLASSIC", status="ACTIVE")
        db.add(game)
        active_ids = set((await db.execute(select(User.id).where(
            User.id.in_(participant_ids), User.status == "ACTIVE"
        ))).scalars().all())
        for seat, user_id in enumerate(participant_ids):
            db.add(MatchPlayer(
                match_id=game.id,
                user_id=user_id,
                seat_index=seat,
                color=["RED", "GREEN", "YELLOW", "BLUE"][seat],
                is_bot=user_id not in active_ids,
            ))
        await db.flush()
        return game.id

    @staticmethod
    async def seed_default_tournaments(db: AsyncSession) -> None:
        stmt = select(Tournament).limit(1)
        res = await db.execute(stmt)
        if not res.scalars().first():
            t1 = Tournament(
                id="tourn_royal_crown",
                title="Royal Crown Championship",
                description="8-Player standard knockout bracket. 2 Semifinals boards, top 2 advance to Grand Final!",
                entry_fee_coins=500,
                prize_pool_coins=3000,
                prize_pool_gems=25,
                max_participants=8,
                current_participants=0,
                status="REGISTRATION",
            )
            t2 = Tournament(
                id="tourn_grand_masters",
                title="Grand Masters Blitz",
                description="High stakes 8-Player championship with massive gem rewards!",
                entry_fee_coins=1500,
                prize_pool_coins=10000,
                prize_pool_gems=100,
                max_participants=8,
                current_participants=0,
                status="REGISTRATION",
            )
            db.add_all([t1, t2])
            await db.commit()

    @staticmethod
    async def list_tournaments(db: AsyncSession, current_user_id: Optional[str] = None) -> List[dict]:
        await TournamentService.seed_default_tournaments(db)
        stmt = select(Tournament).order_by(Tournament.created_at.desc())
        res = await db.execute(stmt)
        tournaments = res.scalars().all()

        results = []
        for t in tournaments:
            is_joined = False
            if current_user_id:
                part_stmt = select(TournamentParticipant).where(
                    TournamentParticipant.tournament_id == t.id,
                    TournamentParticipant.user_id == current_user_id,
                )
                part_res = await db.execute(part_stmt)
                is_joined = part_res.scalars().first() is not None

            results.append({
                "id": t.id,
                "title": t.title,
                "description": t.description,
                "entry_fee_coins": t.entry_fee_coins,
                "prize_pool_coins": t.prize_pool_coins,
                "prize_pool_gems": t.prize_pool_gems,
                "max_participants": t.max_participants,
                "current_participants": t.current_participants,
                "status": t.status,
                "winner_user_id": t.winner_user_id,
                "is_joined": is_joined,
            })
        return results

    @staticmethod
    async def get_tournament_details(db: AsyncSession, tournament_id: str, current_user_id: Optional[str] = None) -> dict:
        stmt = (
            select(Tournament)
            .options(
                selectinload(Tournament.participants).selectinload(TournamentParticipant.user).selectinload(User.profile),
                selectinload(Tournament.matches),
            )
            .where(Tournament.id == tournament_id)
        )
        res = await db.execute(stmt)
        t = res.scalars().first()
        if not t:
            raise HTTPException(status_code=404, detail="Tournament not found")

        is_joined = any(p.user_id == current_user_id for p in t.participants) if current_user_id else False

        participants_data = []
        for p in t.participants:
            prof = p.user.profile if p.user and p.user.profile else None
            participants_data.append({
                "id": p.id,
                "user_id": p.user_id,
                "display_name": prof.display_name if prof else "Player",
                "avatar_id": prof.avatar_id if prof else "avatar_0",
                "seed": p.seed,
                "placement": p.placement,
                "prize_coins": p.prize_coins,
                "prize_gems": p.prize_gems,
                "eliminated_round": p.eliminated_round,
            })

        matches_data = []
        for m in sorted(t.matches, key=lambda x: (x.round_number, x.match_index)):
            matches_data.append({
                "id": m.id,
                "round_number": m.round_number,
                "match_index": m.match_index,
                "status": m.status,
                "match_id": m.match_id,
                "participant_ids": m.participant_ids or [],
                "winner_ids": m.winner_ids or [],
            })

        return {
            "tournament": {
                "id": t.id,
                "title": t.title,
                "description": t.description,
                "entry_fee_coins": t.entry_fee_coins,
                "prize_pool_coins": t.prize_pool_coins,
                "prize_pool_gems": t.prize_pool_gems,
                "max_participants": t.max_participants,
                "current_participants": t.current_participants,
                "status": t.status,
                "winner_user_id": t.winner_user_id,
                "is_joined": is_joined,
            },
            "participants": participants_data,
            "matches": matches_data,
        }

    @staticmethod
    async def join_tournament(db: AsyncSession, user_id: str, tournament_id: str) -> dict:
        stmt = select(Tournament).where(Tournament.id == tournament_id).with_for_update()
        res = await db.execute(stmt)
        tournament = res.scalars().first()
        if not tournament:
            raise HTTPException(status_code=404, detail="Tournament not found")

        if tournament.status != "REGISTRATION":
            raise HTTPException(status_code=400, detail="Tournament is not open for registration")

        if tournament.current_participants >= tournament.max_participants:
            raise HTTPException(status_code=400, detail="Tournament is already full")

        part_stmt = select(TournamentParticipant).where(
            TournamentParticipant.tournament_id == tournament_id,
            TournamentParticipant.user_id == user_id,
        )
        part_res = await db.execute(part_stmt)
        if part_res.scalars().first():
            raise HTTPException(status_code=400, detail="Already registered in this tournament")

        # Deduct entry fee via immutable ledger
        if tournament.entry_fee_coins > 0:
            idempotency_key = f"tourn_fee_{tournament_id}_{user_id}"
            try:
                await EconomyService.record_transaction(
                    db=db,
                    user_id=user_id,
                    amount=-tournament.entry_fee_coins,
                    currency="COINS",
                    reason=f"TOURNAMENT_ENTRY:{tournament.title}",
                    idempotency_key=idempotency_key,
                    commit=False,
                )
            except ValueError as exc:
                raise HTTPException(status_code=400, detail=str(exc)) from exc

        new_seed = tournament.current_participants + 1
        participant = TournamentParticipant(
            id=str(uuid.uuid4()),
            tournament_id=tournament_id,
            user_id=user_id,
            seed=new_seed,
        )
        db.add(participant)
        tournament.current_participants += 1
        await db.flush()

        # Check if full (8 players) -> Generate bracket and start
        if tournament.current_participants == tournament.max_participants:
            tournament.status = "IN_PROGRESS"
            tournament.started_at = datetime.datetime.utcnow()

            # Load all 8 participant IDs
            all_parts_stmt = select(TournamentParticipant).where(
                TournamentParticipant.tournament_id == tournament_id
            ).order_by(TournamentParticipant.seed)
            all_parts_res = await db.execute(all_parts_stmt)
            all_parts = all_parts_res.scalars().all()
            part_ids = [p.user_id for p in all_parts]
            if len(part_ids) != tournament.max_participants:
                raise ValueError("Tournament participant count is inconsistent")

            semi_a_ids = [part_ids[0], part_ids[2], part_ids[4], part_ids[6]]
            semi_b_ids = [part_ids[1], part_ids[3], part_ids[5], part_ids[7]]

            # Semifinal A (Seeds 1, 3, 5, 7)
            semi_a = TournamentMatch(
                id=str(uuid.uuid4()),
                tournament_id=tournament_id,
                round_number=1,
                match_index=0,
                status="IN_PROGRESS",
                match_id=await TournamentService._create_game(db, semi_a_ids),
                participant_ids=semi_a_ids,
            )
            # Semifinal B (Seeds 2, 4, 6, 8)
            semi_b = TournamentMatch(
                id=str(uuid.uuid4()),
                tournament_id=tournament_id,
                round_number=1,
                match_index=1,
                status="IN_PROGRESS",
                match_id=await TournamentService._create_game(db, semi_b_ids),
                participant_ids=semi_b_ids,
            )
            # Finals (Top 2 from Semi A & Top 2 from Semi B)
            final_match = TournamentMatch(
                id=str(uuid.uuid4()),
                tournament_id=tournament_id,
                round_number=2,
                match_index=0,
                status="PENDING",
                participant_ids=[],
            )
            db.add_all([semi_a, semi_b, final_match])
            for user_id in part_ids:
                semifinal = semi_a if user_id in semi_a_ids else semi_b
                db.add(Notification(
                    user_id=user_id,
                    title="Championship match ready",
                    body=f"Your {tournament.title} semifinal is ready. Open Championship to play.",
                    category="TOURNAMENT",
                    data_payload=json.dumps({
                        "tournament_id": tournament_id,
                        "match_id": semifinal.match_id,
                    }),
                ))

        await db.commit()
        return {
            "message": "Successfully registered for tournament!",
            "tournament_id": tournament_id,
            "current_participants": tournament.current_participants,
            "status": tournament.status,
            "seed": new_seed,
        }

    @staticmethod
    async def report_match_result(
        db: AsyncSession,
        tournament_id: str,
        round_number: int,
        match_index: int,
        ranking_user_ids: List[str],  # [1st, 2nd, 3rd, 4th]
        *,
        commit: bool = True,
    ) -> None:
        stmt = (
            select(Tournament)
            .options(selectinload(Tournament.matches), selectinload(Tournament.participants))
            .where(Tournament.id == tournament_id)
        )
        res = await db.execute(stmt)
        tournament = res.scalars().first()
        if not tournament:
            raise HTTPException(status_code=404, detail="Tournament not found")

        curr_match = next(
            (m for m in tournament.matches if m.round_number == round_number and m.match_index == match_index),
            None,
        )
        if not curr_match:
            raise HTTPException(status_code=404, detail="Tournament match not found")
        if curr_match.status == "COMPLETED":
            return
        if curr_match.status != "IN_PROGRESS" or set(ranking_user_ids) != set(curr_match.participant_ids) or len(ranking_user_ids) != 4:
            raise ValueError("Invalid championship match result")

        curr_match.status = "COMPLETED"
        advancing = ranking_user_ids[:2]  # top 2 advance
        curr_match.winner_ids = advancing

        # Mark eliminated players
        eliminated = ranking_user_ids[2:]
        for uid in eliminated:
            part = next((p for p in tournament.participants if p.user_id == uid), None)
            if part:
                part.eliminated_round = round_number

        if round_number == 1:
            # Check if both semifinal matches are completed
            semi_matches = [m for m in tournament.matches if m.round_number == 1]
            if all(m.status == "COMPLETED" for m in semi_matches):
                final_match = next((m for m in tournament.matches if m.round_number == 2), None)
                if final_match:
                    final_participants = []
                    for m in sorted(semi_matches, key=lambda x: x.match_index):
                        final_participants.extend(m.winner_ids)
                    final_match.participant_ids = final_participants
                    final_match.match_id = await TournamentService._create_game(db, final_participants)
                    final_match.status = "IN_PROGRESS"
                    for user_id in final_participants:
                        account_status = await db.scalar(select(User.status).where(User.id == user_id))
                        if account_status != "ACTIVE":
                            continue
                        db.add(Notification(
                            user_id=user_id,
                            title="Championship final ready",
                            body=f"The {tournament.title} final is ready. Open Championship to play.",
                            category="TOURNAMENT",
                            data_payload=json.dumps({
                                "tournament_id": tournament_id,
                                "match_id": final_match.match_id,
                            }),
                        ))

        elif round_number == 2:
            # Grand final completed!
            tournament.status = "COMPLETED"
            tournament.completed_at = datetime.datetime.utcnow()
            winner_id = ranking_user_ids[0]
            tournament.winner_user_id = winner_id

            # Award prizes
            # 1st place: 60% coins + 60% gems
            # 2nd place: 25% coins + 25% gems
            # 3rd place: 15% coins + 15% gems
            prize_splits = [
                (0.60, 0.60),  # 1st
                (0.25, 0.25),  # 2nd
                (0.15, 0.15),  # 3rd
            ]

            for rank_idx, uid in enumerate(ranking_user_ids[:3]):
                coin_pct, gem_pct = prize_splits[rank_idx]
                award_coins = int(tournament.prize_pool_coins * coin_pct)
                award_gems = int(tournament.prize_pool_gems * gem_pct)

                part = next((p for p in tournament.participants if p.user_id == uid), None)
                if part:
                    part.placement = rank_idx + 1
                    part.prize_coins = award_coins
                    part.prize_gems = award_gems

                account_status = await db.scalar(select(User.status).where(User.id == uid))
                if account_status != "ACTIVE":
                    continue
                if award_coins > 0:
                    await EconomyService.record_transaction(
                        db=db,
                        user_id=uid,
                        amount=award_coins,
                        currency="COINS",
                        reason=f"TOURNAMENT_PRIZE:{tournament.title}:RANK_{rank_idx + 1}",
                        idempotency_key=f"tourn_prize_coins_{tournament.id}_{uid}",
                        commit=False,
                    )
                if award_gems > 0:
                    await EconomyService.record_transaction(
                        db=db,
                        user_id=uid,
                        amount=award_gems,
                        currency="GEMS",
                        reason=f"TOURNAMENT_PRIZE:{tournament.title}:RANK_{rank_idx + 1}",
                        idempotency_key=f"tourn_prize_gems_{tournament.id}_{uid}",
                        commit=False,
                    )

        if commit:
            await db.commit()
        else:
            await db.flush()
