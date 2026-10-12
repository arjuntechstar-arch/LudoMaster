import pytest
from services.realtime.engine.ludo_server_engine import LudoServerEngine
from services.realtime.engine.models import Color, Seat, TokenLocation, TurnPhase

def make_engine():
    seats = [
        Seat(seat_index=0, user_id="u1", display_name="RedPlayer", avatar_id="a1", color=Color.RED),
        Seat(seat_index=1, user_id="u2", display_name="GreenPlayer", avatar_id="a2", color=Color.GREEN),
    ]
    return LudoServerEngine(match_id="test_match_1", seats=seats, tokens_per_player=2)

def test_engine_initial_state():
    engine = make_engine()
    assert engine.current_seat_index == 0
    assert engine.phase == TurnPhase.ROLL_REQUIRED
    assert len(engine.seats[0].tokens) == 2
    assert engine.seats[0].tokens[0].location == TokenLocation.YARD

def test_engine_yard_exit_on_six():
    engine = make_engine()
    val, moves = engine.roll_dice(forced_value=5)
    assert val == 5
    assert len(moves) == 0  # Cannot leave yard with 5
    # Turn should have advanced to player 1
    assert engine.current_seat_index == 1

    # Player 1 rolls 6
    val, moves = engine.roll_dice(forced_value=6)
    assert val == 6
    assert len(moves) == 2  # Either of the 2 yard tokens
    assert engine.phase == TurnPhase.MOVE_REQUIRED

    # Move token 0
    move, cap, bonus = engine.apply_move(token_id=0)
    assert move.to_location == TokenLocation.TRACK
    assert move.to_position == 13  # Green start cell
    assert bonus is True  # 6 gives bonus turn
    assert engine.phase == TurnPhase.ROLL_REQUIRED
    assert engine.current_seat_index == 1  # Still Green's turn!

def test_engine_capture_and_bonus():
    engine = make_engine()
    # Seat 0 (Red) places token on track at position 5
    t_red = engine.seats[0].tokens[0]
    t_red.location = TokenLocation.TRACK
    t_red.position = 5
    t_red.steps_taken = 5

    # Seat 1 (Green) places token on track at position 0 (steps_taken 39 for Green to reach track 0)
    # Green start is 13. To land on 5, Green needs to be at 1 and roll 4.
    t_green = engine.seats[1].tokens[0]
    t_green.location = TokenLocation.TRACK
    t_green.position = 1
    # distance from 13 to 1 is (1 - 13) % 52 = 40
    t_green.steps_taken = 40

    # Let it be Green's turn
    engine.current_seat_index = 1
    engine.phase = TurnPhase.ROLL_REQUIRED

    val, moves = engine.roll_dice(forced_value=4)
    assert val == 4
    # Move Green token to 5 (capturing Red!)
    move, capture, bonus = engine.apply_move(token_id=0)
    assert move.to_position == 5
    assert capture is not None
    assert capture["capturingSeatIndex"] == 1
    assert bonus is True  # Capture gives bonus turn
    # Verify Red token returned to YARD
    assert t_red.location == TokenLocation.YARD
    assert t_red.position == -1
    assert t_red.steps_taken == 0

def test_engine_safe_cell_no_capture():
    engine = make_engine()
    # Position 8 is a SAFE_CELL
    t_red = engine.seats[0].tokens[0]
    t_red.location = TokenLocation.TRACK
    t_red.position = 8
    t_red.steps_taken = 8

    # Green token moves to 8
    t_green = engine.seats[1].tokens[0]
    t_green.location = TokenLocation.TRACK
    t_green.position = 6
    t_green.steps_taken = 45  # (13 + 45) % 52 = 58 % 52 = 6

    engine.current_seat_index = 1
    engine.phase = TurnPhase.ROLL_REQUIRED

    val, moves = engine.roll_dice(forced_value=2)
    assert moves[0].is_capture is False  # Safe cell!
    move, capture, bonus = engine.apply_move(token_id=0)
    assert capture is None
    assert t_red.location == TokenLocation.TRACK  # Not captured!

def test_engine_consecutive_sixes_penalty():
    engine = make_engine()
    # First 6
    val1, moves1 = engine.roll_dice(forced_value=6)
    assert engine.consecutive_sixes == 1
    engine.apply_move(token_id=0)

    # Second 6
    val2, moves2 = engine.roll_dice(forced_value=6)
    assert engine.consecutive_sixes == 2
    engine.apply_move(token_id=1)

    # Third 6 -> PENALTY
    val3, moves3 = engine.roll_dice(forced_value=6)
    assert len(moves3) == 0  # No moves allowed
    assert engine.consecutive_sixes == 0
    # Turn passed to Seat 1!
    assert engine.current_seat_index == 1

def test_engine_exact_home_finish_and_placements():
    engine = make_engine()
    # Red token 0 at step 55 (needs exact 1 to finish)
    t0 = engine.seats[0].tokens[0]
    t0.location = TokenLocation.HOME_LANE
    t0.position = 4
    t0.steps_taken = 55

    # Red token 1 already finished in home
    t1 = engine.seats[0].tokens[1]
    t1.location = TokenLocation.HOME
    t1.position = -1
    t1.steps_taken = 56

    val, moves = engine.roll_dice(forced_value=2)
    assert len(moves) == 0  # Overshoots 56! Cannot move

    # Now roll 1
    engine.current_seat_index = 0
    engine.phase = TurnPhase.ROLL_REQUIRED
    val, moves = engine.roll_dice(forced_value=1)
    assert len(moves) == 1
    assert moves[0].is_home_finish is True

    move, cap, bonus = engine.apply_move(token_id=0)
    assert t0.location == TokenLocation.HOME
    assert engine.seats[0].has_finished is True
    assert engine.placements[0] == 0  # Seat 0 finished 1st
    # With only 1 player remaining, game automatically finishes!
    assert engine.phase == TurnPhase.FINISHED
    assert len(engine.placements) == 2  # Seat 0 (1st), Seat 1 (2nd)
