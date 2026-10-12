import asyncio
from datetime import datetime, timezone
import json
import logging
from typing import Any, Dict, List, Optional
from fastapi import WebSocket
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import async_session_maker
from app.models.match import GameEvent, GameSnapshot, Match, MatchPlayer
from app.models.user import User
from app.models.tournament import TournamentMatch
from app.services.economy import economy_service
from app.services.progression import progression_service
from app.services.rewards_service import rewards_service
from app.services.season_service import SeasonService
from app.services.tournament_service import TournamentService
from app.services.account_deletion import redact_player
from services.realtime.engine.events import RealtimeEventType, create_event_envelope
from services.realtime.engine.ludo_server_engine import LudoServerEngine
from services.realtime.engine.models import Color, LegalMove, Seat, TokenLocation, TurnPhase
from services.realtime.moderation import is_preset_message, sanitize_chat_message

logger = logging.getLogger("realtime.session")

class GameSession:
    def __init__(self, match_id: str, engine: LudoServerEngine, bet_coins: int = 0):
        self.match_id = match_id
        self.engine = engine
        self.bet_coins = bet_coins
        self.sequence = 0
        self.connections: Dict[int, WebSocket] = {}  # seat_index -> WebSocket
        self.user_to_seat: Dict[str, int] = {}       # user_id -> seat_index
        self.retired_users: set[str] = set()
        self.event_history: List[dict] = []
        self.turn_timer_task: Optional[asyncio.Task] = None
        self.disconnect_timers: Dict[int, asyncio.Task] = {}
        self.is_settled = False
        self.match_started = False
        self.engine.phase = TurnPhase.WAITING
        self.joined_seats: set[int] = set()
        self.turn_timeout_seconds = 15.0
        self._presenting_move = False

        for seat in self.engine.seats:
            if seat.user_id:
                self.user_to_seat[seat.user_id] = seat.seat_index

    async def broadcast_event(self, event_type: RealtimeEventType | str, payload: Dict[str, Any]) -> dict:
        self.sequence += 1
        envelope = create_event_envelope(event_type, self.match_id, self.sequence, payload)
        self.event_history.append(envelope)

        dead_connections = []
        for seat_idx, ws in self.connections.items():
            try:
                await ws.send_json(envelope)
            except Exception as e:
                logger.warning(f"Error sending to seat {seat_idx}: {e}")
                dead_connections.append(seat_idx)

        for dead_seat in dead_connections:
            self.connections.pop(dead_seat, None)

        return envelope

    async def send_to_seat(self, seat_index: int, envelope: dict):
        ws = self.connections.get(seat_index)
        if ws:
            try:
                await ws.send_json(envelope)
            except Exception as e:
                logger.warning(f"Error sending directly to seat {seat_index}: {e}")

    async def handle_connect(
        self, user_id: str, websocket: WebSocket, last_received_seq: Optional[int] = None
    ):
        if user_id in self.retired_users:
            await websocket.close(code=1008, reason="Account deleted")
            return
        seat_idx = self.user_to_seat.get(user_id)
        if seat_idx is None:
            # Check if user can be assigned to an empty human seat
            for s in self.engine.seats:
                if not s.is_bot and s.user_id is None:
                    s.user_id = user_id
                    self.user_to_seat[user_id] = s.seat_index
                    seat_idx = s.seat_index
                    break

        if seat_idx is None:
            await websocket.send_json(
                create_event_envelope(
                    RealtimeEventType.ERROR,
                    self.match_id,
                    self.sequence,
                    {"code": "NOT_IN_MATCH", "message": "User is not a player in this match."},
                )
            )
            return

        # Cancel any active disconnect grace period timer
        if seat_idx in self.disconnect_timers:
            self.disconnect_timers[seat_idx].cancel()
            self.disconnect_timers.pop(seat_idx, None)

        self.connections[seat_idx] = websocket
        seat = self.engine.seats[seat_idx]
        is_first_join = seat_idx not in self.joined_seats
        self.joined_seats.add(seat_idx)
        seat.is_connected = True

        # Send AUTHENTICATED
        await self.send_to_seat(
            seat_idx,
            create_event_envelope(
                RealtimeEventType.AUTHENTICATED,
                self.match_id,
                self.sequence,
                {"seatIndex": seat_idx, "userId": user_id, "color": seat.color.value},
            ),
        )

        # Handle Reconnect catch-up
        if last_received_seq is not None and last_received_seq < self.sequence:
            # Replay missing events
            missed_events = [ev for ev in self.event_history if ev["sequence"] > last_received_seq]
            for ev in missed_events:
                await self.send_to_seat(seat_idx, ev)

        # Send canonical STATE_SNAPSHOT
        await self.send_to_seat(
            seat_idx,
            create_event_envelope(
                RealtimeEventType.STATE_SNAPSHOT,
                self.match_id,
                self.sequence,
                self.engine.to_snapshot(),
            ),
        )

        # Broadcast Player Joined / Reconnected
        if is_first_join:
            await self.broadcast_event(
                RealtimeEventType.PLAYER_JOINED,
                {"seatIndex": seat_idx, "userId": user_id, "displayName": seat.display_name},
            )
        else:
            await self.broadcast_event(
                RealtimeEventType.PLAYER_RECONNECTED,
                {"seatIndex": seat_idx, "userId": user_id},
            )

        # If match has not started yet, check if all human players are connected and start
        human_seats = [s for s in self.engine.seats if not s.is_bot and s.user_id is not None]
        all_human_connected = all(s.seat_index in self.connections for s in human_seats)
        if all_human_connected and not self.match_started:
            self.match_started = True
            await self.start_match()

    async def start_match(self):
        self.engine.phase = TurnPhase.ROLL_REQUIRED
        await self.broadcast_event(
            RealtimeEventType.MATCH_STARTED,
            {"mode": self.engine.mode, "seats": [s.to_dict() for s in self.engine.seats]},
        )
        await self.start_turn()

    async def start_turn(self):
        if self.engine.is_finished:
            await self.finish_match()
            return

        active_task = asyncio.current_task()
        if (
            self.turn_timer_task
            and self.turn_timer_task is not active_task
            and not self.turn_timer_task.done()
        ):
            self.turn_timer_task.cancel()
        self.turn_timer_task = None

        curr_seat = self.engine.current_seat
        deadline = datetime.now(timezone.utc).timestamp() + self.turn_timeout_seconds
        self.engine.turn_deadline = deadline

        await self.broadcast_event(
            RealtimeEventType.TURN_STARTED,
            {
                "currentSeatIndex": curr_seat.seat_index,
                "deadline": deadline,
                "timeoutSeconds": self.turn_timeout_seconds,
                "isBot": curr_seat.is_bot,
            },
        )

        if curr_seat.is_bot or not curr_seat.is_connected:
            # Bot or disconnected player auto-plays
            asyncio.create_task(self._bot_turn_cycle())
        else:
            # Arm human turn timer
            self.turn_timer_task = asyncio.create_task(self._turn_timer_countdown(curr_seat.seat_index))

    async def _turn_timer_countdown(self, expected_seat_index: int):
        try:
            await asyncio.sleep(self.turn_timeout_seconds)
            if self.engine.current_seat_index == expected_seat_index and not self.engine.is_finished:
                await self.broadcast_event(
                    RealtimeEventType.TURN_TIMEOUT,
                    {"seatIndex": expected_seat_index},
                )
                # Auto-play on timeout
                move, capture, bonus = self.engine.resolve_timeout()
                if move:
                    await self._broadcast_move_and_resolve(
                        move, capture, bonus, seat_index=expected_seat_index
                    )
                else:
                    await self.start_turn()
        except asyncio.CancelledError:
            pass

    async def _bot_turn_cycle(self):
        await asyncio.sleep(0.7)
        if self.engine.is_finished:
            return

        try:
            roller_seat_index = self.engine.current_seat_index
            val, moves = self.engine.roll_dice()
            await self.broadcast_event(
                RealtimeEventType.DICE_ROLLED,
                {
                    "seatIndex": roller_seat_index,
                    "value": val,
                    "consecutiveSixes": self.engine.consecutive_sixes,
                },
            )

            if not moves:
                await asyncio.sleep(1.5)
                await self.start_turn()
                return

            await self.broadcast_event(
                RealtimeEventType.LEGAL_MOVES,
                {"seatIndex": self.engine.current_seat_index, "moves": [m.to_dict() for m in moves]},
            )

            await asyncio.sleep(1.9)  # Dice animation plus a pause to see its value.
            # Pick best move
            chosen = self.engine._pick_best_move(moves)
            mover_seat_index = self.engine.current_seat_index
            move, capture, bonus = self.engine.apply_move(chosen.token_id)
            await self._broadcast_move_and_resolve(
                move, capture, bonus, seat_index=mover_seat_index
            )
        except Exception as e:
            logger.error(f"Error during bot turn: {e}", exc_info=True)
            self.engine.advance_turn()
            await self.start_turn()

    async def handle_roll_request(self, user_id: str):
        if not self.match_started or self._presenting_move:
            return
        seat_idx = self.user_to_seat.get(user_id)
        if seat_idx is None:
            return
        if seat_idx != self.engine.current_seat_index:
            await self.send_to_seat(
                seat_idx,
                create_event_envelope(
                    RealtimeEventType.ERROR,
                    self.match_id,
                    self.sequence,
                    {"code": "NOT_YOUR_TURN", "message": "It is not your turn to roll."},
                ),
            )
            return

        if self.engine.phase != TurnPhase.ROLL_REQUIRED:
            return

        # Cancel turn timer during action
        if self.turn_timer_task and not self.turn_timer_task.done():
            self.turn_timer_task.cancel()

        val, moves = self.engine.roll_dice()
        await self.broadcast_event(
            RealtimeEventType.DICE_ROLLED,
            {
                "seatIndex": seat_idx,
                "value": val,
                "consecutiveSixes": self.engine.consecutive_sixes,
            },
        )

        if not moves:
            # Turn advanced because no legal moves or 3 sixes
            await asyncio.sleep(1.5)
            await self.start_turn()
            return

        await self.broadcast_event(
            RealtimeEventType.LEGAL_MOVES,
            {"seatIndex": seat_idx, "moves": [m.to_dict() for m in moves]},
        )

        # Give the client time to finish its dice animation before the move timer starts.
        await asyncio.sleep(1.5)
        if (
            self.engine.current_seat_index == seat_idx
            and self.engine.phase == TurnPhase.MOVE_REQUIRED
            and not self.engine.is_finished
        ):
            self.turn_timer_task = asyncio.create_task(
                self._turn_timer_countdown(seat_idx)
            )

    async def handle_move_request(self, user_id: str, token_id: int):
        if not self.match_started or self._presenting_move:
            return
        seat_idx = self.user_to_seat.get(user_id)
        if seat_idx != self.engine.current_seat_index:
            return

        if self.engine.phase != TurnPhase.MOVE_REQUIRED:
            return

        try:
            move, capture, bonus = self.engine.apply_move(token_id)
            if self.turn_timer_task and not self.turn_timer_task.done():
                self.turn_timer_task.cancel()
            await self._broadcast_move_and_resolve(
                move, capture, bonus, seat_index=seat_idx
            )
        except Exception as e:
            await self.send_to_seat(
                seat_idx,
                create_event_envelope(
                    RealtimeEventType.ERROR,
                    self.match_id,
                    self.sequence,
                    {"code": "ILLEGAL_MOVE", "message": str(e)},
                ),
            )

    async def _broadcast_move_and_resolve(
        self,
        move: LegalMove,
        capture: Optional[dict],
        bonus: bool,
        *,
        seat_index: int,
    ):
        self._presenting_move = True
        await self.broadcast_event(
            RealtimeEventType.MOVE_APPLIED,
            {
                "seatIndex": seat_index,
                "tokenId": move.token_id,
                "fromLocation": move.from_location.value,
                "fromPosition": move.from_position,
                "toLocation": move.to_location.value,
                "toPosition": move.to_position,
                "stepsTaken": move.steps_to_take,
            },
        )

        if capture:
            await self.broadcast_event(RealtimeEventType.TOKEN_CAPTURED, capture)

        if move.is_home_finish:
            await self.broadcast_event(
                RealtimeEventType.TOKEN_HOME,
                {
                    "seatIndex": seat_index,
                    "tokenId": move.token_id,
                },
            )

        if bonus:
            await self.broadcast_event(
                RealtimeEventType.BONUS_TURN,
                {
                    "seatIndex": seat_index,
                    "reason": self.engine.bonus_turn_reason,
                },
            )

        await asyncio.sleep(1.0)
        self._presenting_move = False
        if self.engine.is_finished:
            await self.finish_match()
        else:
            await self.start_turn()

    async def handle_disconnect(self, user_id: str):
        seat_idx = self.user_to_seat.get(user_id)
        if seat_idx is None:
            return

        self.connections.pop(seat_idx, None)
        self.engine.seats[seat_idx].is_connected = False

        await self.broadcast_event(
            RealtimeEventType.PLAYER_DISCONNECTED,
            {"seatIndex": seat_idx, "userId": user_id, "gracePeriodSeconds": 30},
        )

        # 30-second grace period timer
        self.disconnect_timers[seat_idx] = asyncio.create_task(
            self._disconnect_grace_period(seat_idx, user_id)
        )

    async def remove_account(self, user_id: str):
        self.retired_users.add(user_id)
        seat_idx = self.user_to_seat.pop(user_id, None)
        if seat_idx is None:
            return
        ws = self.connections.pop(seat_idx, None)
        timer = self.disconnect_timers.pop(seat_idx, None)
        if timer:
            timer.cancel()
        seat = self.engine.seats[seat_idx]
        already_bot = seat.is_bot
        seat.display_name = "Deleted User"
        seat.avatar_id = "avatar_0"
        seat.is_connected = False
        seat.is_bot = True
        self.event_history = redact_player(self.event_history, user_id)
        await self.broadcast_event(
            RealtimeEventType.PLAYER_FORFEITED,
            {"seatIndex": seat_idx, "userId": user_id, "botTakingOver": True},
        )
        if ws:
            try:
                await ws.close(code=1000, reason="Account deleted")
            except Exception:
                logger.info("Deleted account's socket was already closed")
        if not self.match_started and all(
            player.is_bot or player.seat_index in self.connections for player in self.engine.seats
        ):
            self.match_started = True
            await self.start_match()
        elif self.match_started and not already_bot and self.engine.current_seat_index == seat_idx and not self.engine.is_finished:
            asyncio.create_task(self._bot_turn_cycle())

    async def _disconnect_grace_period(self, seat_idx: int, user_id: str):
        try:
            await asyncio.sleep(30.0)
            seat = self.engine.seats[seat_idx]
            if not seat.is_connected:
                seat.is_bot = True  # Bot takes over seat
                await self.broadcast_event(
                    RealtimeEventType.PLAYER_FORFEITED,
                    {"seatIndex": seat_idx, "userId": user_id, "botTakingOver": True},
                )
                if self.engine.current_seat_index == seat_idx and not self.engine.is_finished:
                    asyncio.create_task(self._bot_turn_cycle())
        except asyncio.CancelledError:
            pass

    async def handle_chat(self, user_id: str, message: str):
        seat_idx = self.user_to_seat.get(user_id)
        if seat_idx is not None:
            clean_message = sanitize_chat_message(message)
            await self.broadcast_event(
                RealtimeEventType.CHAT_MESSAGE,
                {
                    "seatIndex": seat_idx,
                    "userId": user_id,
                    "displayName": self.engine.seats[seat_idx].display_name,
                    "message": clean_message,
                    "isPreset": is_preset_message(clean_message),
                },
            )

    async def handle_emoji(self, user_id: str, emoji_id: str):
        seat_idx = self.user_to_seat.get(user_id)
        if seat_idx is not None:
            await self.broadcast_event(
                RealtimeEventType.EMOJI_SENT,
                {
                    "seatIndex": seat_idx,
                    "userId": user_id,
                    "emojiId": emoji_id,
                },
            )

    async def finish_match(self):
        if self.is_settled:
            return
        self.is_settled = True

        if self.turn_timer_task and not self.turn_timer_task.done():
            self.turn_timer_task.cancel()

        # Placements and awards
        results = []
        winner_seat_idx = self.engine.placements[0] if self.engine.placements else 0
        total_pot = self.bet_coins * len(self.engine.seats)

        for rank, seat_idx in enumerate(self.engine.placements, start=1):
            seat = self.engine.seats[seat_idx]
            coins_won = total_pot if rank == 1 else 0
            captures = sum(
                len(event.get("payload", {}).get("captured", []))
                for event in self.event_history
                if event.get("event") == RealtimeEventType.TOKEN_CAPTURED.value
                and event.get("payload", {}).get("capturingSeatIndex") == seat_idx
            )
            tokens_home = sum(token.location == TokenLocation.HOME for token in seat.tokens)
            xp_gained = (120 if rank == 1 else 70 if rank == 2 else 35) + 10 * captures + 15 * tokens_home
            results.append({
                "placement": rank,
                "seatIndex": seat_idx,
                "userId": seat.user_id,
                "displayName": seat.display_name,
                "coinsDelta": coins_won - self.bet_coins,
                "xpGained": xp_gained,
                "captures": captures,
                "tokensHome": tokens_home,
            })

        await self.broadcast_event(
            RealtimeEventType.MATCH_FINISHED,
            {
                "placements": self.engine.placements,
                "results": results,
            },
        )

        # Persist results in DB
        asyncio.create_task(self._persist_match_completion(results, winner_seat_idx))

    async def _persist_match_completion(self, results: List[dict], winner_seat_idx: int):
        try:
            async with async_session_maker() as db:
                match_query = await db.execute(
                    select(Match)
                    .options(selectinload(Match.players))
                    .where(Match.id == self.match_id)
                )
                match = match_query.scalar_one_or_none()
                if not match or match.status == "COMPLETED":
                    return

                # Serialize deletion with result settlement. Helpers must not
                # commit/release these locks until this transaction completes.
                result_user_ids = sorted({res["userId"] for res in results if res["userId"]})
                statuses = dict((await db.execute(select(User.id, User.status).where(
                    User.id.in_(result_user_ids)
                ).order_by(User.id).with_for_update())).all())
                active_users = {uid for uid, account_status in statuses.items() if account_status == "ACTIVE"}
                season = await SeasonService.seed_default_season(db, commit=False)
                for res in results:
                    if res["userId"] in active_users:
                        await rewards_service.ensure_user_missions(db, res["userId"], commit=False)
                        await rewards_service.ensure_user_achievements(db, res["userId"], commit=False)
                        await SeasonService.get_or_create_user_progress(db, res["userId"], season.id, commit=False)
                        await economy_service.get_or_create_wallet(db, res["userId"], commit=False)

                winner_seat = self.engine.seats[winner_seat_idx]
                match.status = "COMPLETED"
                match.winner_user_id = winner_seat.user_id
                match.finished_at = datetime.now(timezone.utc)
                match.sequence = self.sequence

                # Save GameSnapshot
                snapshot_state = self.engine.to_snapshot()
                for uid, account_status in statuses.items():
                    if account_status != "ACTIVE":
                        snapshot_state = redact_player(snapshot_state, uid)
                snapshot = GameSnapshot(
                    match_id=self.match_id,
                    sequence=self.sequence,
                    state_json=json.dumps(snapshot_state),
                )
                db.add(snapshot)

                # Persist the authoritative game result before awarding progression.
                for res in results:
                    u_id = res["userId"]
                    rank = res["placement"]
                    coins_delta = res["coinsDelta"]
                    xp_gained = res["xpGained"]

                    mp = next((p for p in match.players if p.seat_index == res["seatIndex"]), None)
                    if mp:
                        mp.placement = rank
                        mp.coins_delta = coins_delta
                        mp.xp_gained = xp_gained

                for res in results:
                    u_id = res["userId"]
                    if u_id not in active_users:
                        continue
                    await progression_service.record_match_progress(
                        db, u_id, res["placement"], res["captures"],
                        res["tokensHome"], mode=match.mode,
                        commit=False, prepared=True,
                    )
                    await SeasonService.add_season_xp(db, u_id, res["xpGained"], commit=False)
                    if res["coinsDelta"]:
                        await economy_service.record_transaction(
                            db, u_id, res["coinsDelta"], "COINS",
                            "MATCH_REWARD" if res["coinsDelta"] > 0 else "MATCH_BET",
                            idempotency_key=f"match_{self.match_id}_{u_id}",
                            commit=False,
                        )

                bracket = (await db.execute(
                    select(TournamentMatch).where(TournamentMatch.match_id == self.match_id)
                )).scalar_one_or_none()
                if bracket:
                    ranking = [res["userId"] for res in results if res["userId"]]
                    await TournamentService.report_match_result(
                        db, bracket.tournament_id, bracket.round_number,
                        bracket.match_index, ranking, commit=False,
                    )
                await db.commit()
                logger.info(f"Match {self.match_id} results persisted successfully.")
        except Exception as e:
            logger.error(f"Error persisting match completion: {e}", exc_info=True)


class SessionManager:
    def __init__(self):
        self.sessions: Dict[str, GameSession] = {}

    def get_session(self, match_id: str) -> Optional[GameSession]:
        return self.sessions.get(match_id)

    async def get_or_create_session(self, match_id: str, db: AsyncSession) -> GameSession:
        if match_id in self.sessions:
            return self.sessions[match_id]

        match_q = await db.execute(
            select(Match)
            .options(
                selectinload(Match.players).selectinload(MatchPlayer.user).selectinload(User.profile)
            )
            .where(Match.id == match_id)
        )
        match = match_q.scalar_one_or_none()
        if not match:
            raise ValueError(f"Match {match_id} not found in database.")

        seats: List[Seat] = []
        for mp in sorted(match.players, key=lambda p: p.seat_index):
            profile = mp.user.profile if mp.user else None
            display_name = profile.display_name if profile else f"Bot {mp.seat_index + 1}"
            avatar_id = profile.avatar_id if profile else "avatar_0"
            color = Color(mp.color)
            seats.append(
                Seat(
                    seat_index=mp.seat_index,
                    user_id=mp.user_id,
                    display_name=display_name,
                    avatar_id=avatar_id,
                    color=color,
                    is_connected=False,
                    is_bot=mp.is_bot or bool(mp.user and mp.user.status != "ACTIVE"),
                )
            )

        tokens_per_player = 2 if match.mode == "QUICK" else 4
        engine = LudoServerEngine(
            match_id=match_id,
            seats=seats,
            mode=match.mode,
            tokens_per_player=tokens_per_player,
        )

        session = GameSession(match_id=match_id, engine=engine)
        self.sessions[match_id] = session
        return session

    def remove_session(self, match_id: str):
        self.sessions.pop(match_id, None)

session_manager = SessionManager()
