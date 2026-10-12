import secrets
from typing import Dict, List, Optional, Tuple
from app.models.room import Room
from services.realtime.engine.models import (
    Color,
    LegalMove,
    Seat,
    Token,
    TokenLocation,
    TurnPhase,
)

TRACK_LENGTH_4 = 52
SAFE_CELLS_4 = {0, 8, 13, 21, 26, 34, 39, 47}
COLOR_OFFSETS_4: Dict[Color, int] = {
    Color.RED: 0,
    Color.GREEN: 13,
    Color.YELLOW: 26,
    Color.BLUE: 39,
}
STEPS_TO_HOME_ENTRY_4 = 51
TOTAL_STEPS_TO_FINISH_4 = 56

TRACK_LENGTH_6 = 72
SAFE_CELLS_6 = {0, 8, 12, 20, 24, 32, 36, 44, 48, 56, 60, 68}
COLOR_OFFSETS_6: Dict[Color, int] = {
    Color.RED: 0,
    Color.GREEN: 12,
    Color.YELLOW: 24,
    Color.BLUE: 36,
    Color.ORANGE: 48,
    Color.PURPLE: 60,
}
STEPS_TO_HOME_ENTRY_6 = 71
TOTAL_STEPS_TO_FINISH_6 = 76

# For backwards compatibility
TRACK_LENGTH = TRACK_LENGTH_4
SAFE_CELLS = SAFE_CELLS_4
COLOR_OFFSETS = COLOR_OFFSETS_4
STEPS_TO_HOME_ENTRY = STEPS_TO_HOME_ENTRY_4
HOME_LANE_LENGTH = 5
TOTAL_STEPS_TO_FINISH = TOTAL_STEPS_TO_FINISH_4

class LudoServerEngine:
    def __init__(
        self,
        match_id: str,
        seats: List[Seat],
        mode: str = "CLASSIC",
        tokens_per_player: int = 4,
        is_team_mode: Optional[bool] = None,
        require_capture_for_home: Optional[bool] = None,
    ):
        self.match_id = match_id
        self.mode = mode
        self.tokens_per_player = 2 if mode == "QUICK" else tokens_per_player
        self.is_team_mode = (mode in ("TEAM", "2V2")) if is_team_mode is None else is_team_mode
        self.require_capture_for_home = (mode == "QUICK") if require_capture_for_home is None else require_capture_for_home
        self.seats = seats
        self.current_seat_index = 0
        self.phase = TurnPhase.ROLL_REQUIRED
        self.dice_value: Optional[int] = None
        self.consecutive_sixes = 0
        self.placements: List[int] = []  # Seat indices in order of winning
        self.legal_moves: List[LegalMove] = []
        self.turn_deadline: Optional[float] = None
        self.last_capture: Optional[dict] = None
        self.last_move: Optional[dict] = None
        self.bonus_turn_reason: Optional[str] = None

        if self.is_team_mode and len(seats) == 4:
            seats[0].team_id = 0
            seats[2].team_id = 0
            seats[1].team_id = 1
            seats[3].team_id = 1

        self.is_six_player = len(seats) > 4
        if self.is_six_player:
            self.track_length = TRACK_LENGTH_6
            self.safe_cells = SAFE_CELLS_6
            self.color_offsets = COLOR_OFFSETS_6
            self.steps_to_home_entry = STEPS_TO_HOME_ENTRY_6
            self.total_steps_to_finish = TOTAL_STEPS_TO_FINISH_6
        else:
            self.track_length = TRACK_LENGTH_4
            self.safe_cells = SAFE_CELLS_4
            self.color_offsets = COLOR_OFFSETS_4
            self.steps_to_home_entry = STEPS_TO_HOME_ENTRY_4
            self.total_steps_to_finish = TOTAL_STEPS_TO_FINISH_4

        # Initialize tokens for each seat
        for seat in self.seats:
            seat.tokens = [
                Token(
                    id=i,
                    seat_index=seat.seat_index,
                    color=seat.color,
                    location=TokenLocation.YARD,
                    position=-1,
                    steps_taken=0,
                )
                for i in range(self.tokens_per_player)
            ]

    @property
    def current_seat(self) -> Seat:
        return self.seats[self.current_seat_index]

    @property
    def is_finished(self) -> bool:
        return self.phase == TurnPhase.FINISHED

    def generate_fair_die(self) -> int:
        """Cryptographically secure server-authoritative die roll (1..6)."""
        return secrets.randbelow(6) + 1

    def calculate_legal_moves(self, seat: Seat, roll: int) -> List[LegalMove]:
        # Team mode: If this seat has finished all tokens, they control their teammate's tokens
        if self.is_team_mode and all(t.location == TokenLocation.HOME for t in seat.tokens):
            teammate = next((s for s in self.seats if s.team_id == seat.team_id and s.seat_index != seat.seat_index), None)
            if teammate and not all(t.location == TokenLocation.HOME for t in teammate.tokens):
                return self.calculate_legal_moves(teammate, roll)
            return []

        moves: List[LegalMove] = []
        offset = self.color_offsets[seat.color]

        for token in seat.tokens:
            if token.location == TokenLocation.HOME:
                continue

            # Token in Yard: Requires 6 to enter track at start cell
            if token.location == TokenLocation.YARD:
                if roll == 6:
                    target_pos = offset
                    is_capture = self._check_is_capture(target_pos, seat.seat_index)
                    moves.append(
                        LegalMove(
                            token_id=token.id,
                            from_location=TokenLocation.YARD,
                            from_position=-1,
                            to_location=TokenLocation.TRACK,
                            to_position=target_pos,
                            steps_to_take=1,
                            is_capture=is_capture,
                            is_home_finish=False,
                        )
                    )
                continue

            # Token on Track or Home Lane
            new_steps = token.steps_taken + roll
            if new_steps > self.total_steps_to_finish:
                # Overshoots home - illegal move
                continue

            # Quick Mode rule: cannot enter home lane until at least 1 capture is made
            if self.require_capture_for_home and not seat.has_captured and new_steps >= self.steps_to_home_entry:
                continue

            if new_steps == self.total_steps_to_finish:
                # Exact finish into HOME
                moves.append(
                    LegalMove(
                        token_id=token.id,
                        from_location=token.location,
                        from_position=token.position,
                        to_location=TokenLocation.HOME,
                        to_position=-1,
                        steps_to_take=roll,
                        is_capture=False,
                        is_home_finish=True,
                    )
                )
            elif new_steps >= self.steps_to_home_entry:
                # In Home Lane (0..4)
                lane_pos = new_steps - self.steps_to_home_entry
                moves.append(
                    LegalMove(
                        token_id=token.id,
                        from_location=token.location,
                        from_position=token.position,
                        to_location=TokenLocation.HOME_LANE,
                        to_position=lane_pos,
                        steps_to_take=roll,
                        is_capture=False,
                        is_home_finish=False,
                    )
                )
            else:
                # On Track
                target_pos = (offset + new_steps) % self.track_length
                is_capture = self._check_is_capture(target_pos, seat.seat_index)
                moves.append(
                    LegalMove(
                        token_id=token.id,
                        from_location=token.location,
                        from_position=token.position,
                        to_location=TokenLocation.TRACK,
                        to_position=target_pos,
                        steps_to_take=roll,
                        is_capture=is_capture,
                        is_home_finish=False,
                    )
                )

        return moves

    def _check_is_capture(self, track_position: int, moving_seat_index: int) -> bool:
        if track_position in self.safe_cells:
            return False
        moving_seat = self.seats[moving_seat_index]
        for seat in self.seats:
            if seat.seat_index == moving_seat_index:
                continue
            if self.is_team_mode and seat.team_id is not None and seat.team_id == moving_seat.team_id:
                continue
            for token in seat.tokens:
                if token.location == TokenLocation.TRACK and token.position == track_position:
                    return True
        return False

    def roll_dice(self, forced_value: Optional[int] = None) -> Tuple[int, List[LegalMove]]:
        if self.phase != TurnPhase.ROLL_REQUIRED:
            raise ValueError(f"Cannot roll in phase {self.phase}")

        val = forced_value if forced_value is not None else self.generate_fair_die()
        self.dice_value = val
        self.last_capture = None
        self.last_move = None
        self.bonus_turn_reason = None

        if val == 6:
            self.consecutive_sixes += 1
        else:
            self.consecutive_sixes = 0

        # Three consecutive sixes penalty: turn forfeited!
        if self.consecutive_sixes >= 3:
            self.consecutive_sixes = 0
            self.legal_moves = []
            self.advance_turn()
            return val, []

        self.legal_moves = self.calculate_legal_moves(self.current_seat, val)

        if not self.legal_moves:
            # No legal moves available: turn ends immediately
            self.advance_turn()
            return val, []

        self.phase = TurnPhase.MOVE_REQUIRED
        return val, self.legal_moves

    def apply_move(self, token_id: int) -> Tuple[LegalMove, Optional[dict], bool]:
        """Applies move for given token_id. Returns (move, capture_info, is_bonus_turn)."""
        if self.phase != TurnPhase.MOVE_REQUIRED:
            raise ValueError(f"Cannot move in phase {self.phase}")

        legal = next((m for m in self.legal_moves if m.token_id == token_id), None)
        if not legal:
            raise ValueError(f"Token {token_id} has no legal move for roll {self.dice_value}")

        current_seat = self.current_seat
        if self.is_team_mode and all(t.location == TokenLocation.HOME for t in current_seat.tokens):
            teammate = next((s for s in self.seats if s.team_id == current_seat.team_id and s.seat_index != current_seat.seat_index), None)
            token_owner = teammate if teammate else current_seat
        else:
            token_owner = current_seat
        token = next(t for t in token_owner.tokens if t.id == token_id)

        # Apply transition
        token.location = legal.to_location
        token.position = legal.to_position
        if legal.from_location == TokenLocation.YARD:
            token.steps_taken = 0
        else:
            token.steps_taken += legal.steps_to_take

        capture_info = None
        bonus_turn = False

        # Check Capture
        if legal.is_capture and legal.to_location == TokenLocation.TRACK:
            captured_tokens = []
            for seat in self.seats:
                if seat.seat_index == current_seat.seat_index:
                    continue
                if self.is_team_mode and seat.team_id is not None and seat.team_id == current_seat.team_id:
                    continue
                for opp_token in seat.tokens:
                    if opp_token.location == TokenLocation.TRACK and opp_token.position == legal.to_position:
                        opp_token.location = TokenLocation.YARD
                        opp_token.position = -1
                        opp_token.steps_taken = 0
                        captured_tokens.append({
                            "seatIndex": seat.seat_index,
                            "tokenId": opp_token.id,
                        })
            if captured_tokens:
                current_seat.has_captured = True
                token_owner.has_captured = True
                capture_info = {
                    "capturingSeatIndex": current_seat.seat_index,
                    "capturingTokenId": token.id,
                    "cell": legal.to_position,
                    "captured": captured_tokens,
                }
                self.last_capture = capture_info
                bonus_turn = True
                self.bonus_turn_reason = "CAPTURE"

        # Check Home Finish
        if legal.is_home_finish:
            bonus_turn = True
            self.bonus_turn_reason = "HOME_FINISH"

        # Check Roll 6 bonus turn (if not already granted)
        if self.dice_value == 6 and not bonus_turn:
            bonus_turn = True
            self.bonus_turn_reason = "SIX_ROLLED"

        # Check if token owner has won
        all_home = all(t.location == TokenLocation.HOME for t in token_owner.tokens)
        if all_home and not token_owner.has_finished:
            token_owner.has_finished = True
            if token_owner.seat_index not in self.placements:
                self.placements.append(token_owner.seat_index)
            token_owner.placement = len(self.placements)
            if not self.is_team_mode:
                bonus_turn = False

        # Check match completion
        if self.is_team_mode:
            team0 = [s for s in self.seats if s.team_id == 0]
            team1 = [s for s in self.seats if s.team_id == 1]
            team0_won = team0 and all(all(t.location == TokenLocation.HOME for t in s.tokens) for s in team0)
            team1_won = team1 and all(all(t.location == TokenLocation.HOME for t in s.tokens) for s in team1)
            if team0_won or team1_won:
                winning_team = team0 if team0_won else team1
                losing_team = team1 if team0_won else team0
                self.placements = [s.seat_index for s in winning_team] + [s.seat_index for s in losing_team]
                for s in winning_team:
                    s.has_finished = True
                    s.placement = 1
                for s in losing_team:
                    s.has_finished = True
                    s.placement = 2
                self.phase = TurnPhase.FINISHED
                return legal, capture_info, False
        else:
            active_seats = [s for s in self.seats if not s.has_finished]
            if len(active_seats) <= 1:
                if active_seats:
                    last_seat = active_seats[0]
                    last_seat.has_finished = True
                    self.placements.append(last_seat.seat_index)
                    last_seat.placement = len(self.placements)
                self.phase = TurnPhase.FINISHED
                return legal, capture_info, False

        # Next turn resolution
        if bonus_turn:
            self.phase = TurnPhase.ROLL_REQUIRED
            self.legal_moves = []
            self.dice_value = None
        else:
            self.advance_turn()

        return legal, capture_info, bonus_turn

    def advance_turn(self):
        """Passes turn to the next player who has not finished."""
        self.consecutive_sixes = 0
        self.dice_value = None
        self.legal_moves = []

        if self.is_team_mode:
            next_seat = (self.current_seat_index + 1) % len(self.seats)
            for _ in range(len(self.seats)):
                candidate = self.seats[next_seat]
                team = [s for s in self.seats if s.team_id == candidate.team_id]
                if any(not all(t.location == TokenLocation.HOME for t in s.tokens) for s in team):
                    self.current_seat_index = next_seat
                    self.phase = TurnPhase.ROLL_REQUIRED
                    return
                next_seat = (next_seat + 1) % len(self.seats)
            self.phase = TurnPhase.FINISHED
            return

        active_seats = [s for s in self.seats if not s.has_finished]
        if len(active_seats) <= 1:
            if active_seats:
                active_seats[0].has_finished = True
                self.placements.append(active_seats[0].seat_index)
                active_seats[0].placement = len(self.placements)
            self.phase = TurnPhase.FINISHED
            return

        next_seat = (self.current_seat_index + 1) % len(self.seats)
        while self.seats[next_seat].has_finished:
            next_seat = (next_seat + 1) % len(self.seats)

        self.current_seat_index = next_seat
        self.phase = TurnPhase.ROLL_REQUIRED

    def resolve_timeout(self) -> Tuple[Optional[LegalMove], Optional[dict], bool]:
        """Pass a missed roll or auto-move a legal token after a move timeout."""
        if self.phase == TurnPhase.ROLL_REQUIRED:
            self.advance_turn()
            return None, None, False
        elif self.phase == TurnPhase.MOVE_REQUIRED and self.legal_moves:
            chosen = self._pick_best_move(self.legal_moves)
            return self.apply_move(chosen.token_id)
        else:
            self.advance_turn()
            return None, None, False

    def _pick_best_move(self, moves: List[LegalMove]) -> LegalMove:
        # Prioritize: capture > home finish > leave yard > max forward progress
        captures = [m for m in moves if m.is_capture]
        if captures:
            return captures[0]
        home_finishes = [m for m in moves if m.is_home_finish]
        if home_finishes:
            return home_finishes[0]
        yard_exits = [m for m in moves if m.from_location == TokenLocation.YARD]
        if yard_exits:
            return yard_exits[0]
        return moves[0]

    def to_snapshot(self) -> dict:
        return {
            "matchId": self.match_id,
            "mode": self.mode,
            "isTeamMode": self.is_team_mode,
            "requireCaptureForHome": self.require_capture_for_home,
            "phase": self.phase.value,
            "currentSeatIndex": self.current_seat_index,
            "diceValue": self.dice_value,
            "consecutiveSixes": self.consecutive_sixes,
            "placements": self.placements,
            "bonusTurnReason": self.bonus_turn_reason,
            "seats": [s.to_dict() for s in self.seats],
            "legalMoves": [m.to_dict() for m in self.legal_moves],
        }
