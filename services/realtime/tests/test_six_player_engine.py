import pytest
from services.realtime.engine.ludo_server_engine import LudoServerEngine
from services.realtime.engine.models import Color, Seat, TokenLocation, TurnPhase

def make_six_player_engine():
    colors = [
        Color.RED,
        Color.GREEN,
        Color.YELLOW,
        Color.BLUE,
        Color.ORANGE,
        Color.PURPLE,
    ]
    seats = [
        Seat(
            seat_index=i,
            user_id=f"user_{i}",
            display_name=f"Player {i+1}",
            avatar_id="avatar_1",
            color=colors[i],
            is_bot=(i > 0),
        )
        for i in range(6)
    ]
    return LudoServerEngine(match_id="test_6p_match", seats=seats, mode="CLASSIC")

def test_six_player_engine_initial_geometry():
    engine = make_six_player_engine()
    assert engine.is_six_player is True
    assert engine.track_length == 72
    assert len(engine.safe_cells) == 12
    assert 48 in engine.safe_cells  # Orange start
    assert 60 in engine.safe_cells  # Purple start
    assert 56 in engine.safe_cells  # Orange star cell
    assert 68 in engine.safe_cells  # Purple star cell
    assert engine.steps_to_home_entry == 71
    assert engine.total_steps_to_finish == 76

    # Test seat offsets
    assert engine.color_offsets[Color.RED] == 0
    assert engine.color_offsets[Color.GREEN] == 12
    assert engine.color_offsets[Color.YELLOW] == 24
    assert engine.color_offsets[Color.BLUE] == 36
    assert engine.color_offsets[Color.ORANGE] == 48
    assert engine.color_offsets[Color.PURPLE] == 60

def test_six_player_orange_and_purple_yard_exit():
    engine = make_six_player_engine()
    
    # Orange (seat 4) yard exit on 6
    orange_seat = engine.seats[4]
    assert orange_seat.color == Color.ORANGE
    moves = engine.calculate_legal_moves(orange_seat, 6)
    assert len(moves) == 4
    assert all(m.to_location == TokenLocation.TRACK for m in moves)
    assert all(m.to_position == 48 for m in moves)

    # Purple (seat 5) yard exit on 6
    purple_seat = engine.seats[5]
    assert purple_seat.color == Color.PURPLE
    moves_purple = engine.calculate_legal_moves(purple_seat, 6)
    assert len(moves_purple) == 4
    assert all(m.to_location == TokenLocation.TRACK for m in moves_purple)
    assert all(m.to_position == 60 for m in moves_purple)

def test_six_player_capture_on_72_track():
    engine = make_six_player_engine()

    # Red token at cell 55
    red_token = engine.seats[0].tokens[0]
    red_token.location = TokenLocation.TRACK
    red_token.position = 55
    red_token.steps_taken = 55

    # Orange token at cell 53 (5 steps from start 48)
    orange_token = engine.seats[4].tokens[0]
    orange_token.location = TokenLocation.TRACK
    orange_token.position = 53
    orange_token.steps_taken = 5

    # Set turn to Orange
    engine.current_seat_index = 4
    engine.phase = TurnPhase.ROLL_REQUIRED

    # Orange rolls 2 -> lands on 55 (where Red is)
    val, moves = engine.roll_dice(forced_value=2)
    assert val == 2
    move = next((m for m in moves if m.token_id == 0), None)
    assert move is not None
    assert move.to_position == 55
    assert move.is_capture is True

    # Apply move: red token sent back to YARD
    applied_move, capture_info, is_bonus = engine.apply_move(0)
    assert capture_info is not None
    assert capture_info["cell"] == 55
    assert red_token.location == TokenLocation.YARD
    assert is_bonus is True  # Bonus turn for capture

def test_six_player_safe_cell_prevents_capture():
    engine = make_six_player_engine()

    # Red token at cell 48 (Orange safe start cell)
    red_token = engine.seats[0].tokens[0]
    red_token.location = TokenLocation.TRACK
    red_token.position = 48
    red_token.steps_taken = 48

    # Orange rolls 6 and exits yard onto 48
    engine.current_seat_index = 4
    engine.phase = TurnPhase.ROLL_REQUIRED
    val, moves = engine.roll_dice(forced_value=6)
    
    # 48 is safe, so is_capture MUST be False!
    assert all(m.is_capture is False for m in moves)

def test_six_player_exact_home_finish():
    engine = make_six_player_engine()

    # Purple token on home lane step 3 (steps_taken = 74)
    # Total finish is 76 (requires roll of 2)
    purple_token = engine.seats[5].tokens[0]
    purple_token.location = TokenLocation.HOME_LANE
    purple_token.position = 3
    purple_token.steps_taken = 74

    engine.current_seat_index = 5
    engine.phase = TurnPhase.ROLL_REQUIRED

    # Roll 3 -> Overshoot (74 + 3 = 77 > 76) -> No moves
    val, moves = engine.roll_dice(forced_value=3)
    assert len(moves) == 0

    # Advance to purple turn again
    engine.current_seat_index = 5
    engine.phase = TurnPhase.ROLL_REQUIRED

    # Roll 2 -> Exact finish (74 + 2 = 76)
    val, moves = engine.roll_dice(forced_value=2)
    assert len(moves) == 1
    assert moves[0].to_location == TokenLocation.HOME
    assert moves[0].is_home_finish is True

    applied_move, capture_info, is_bonus = engine.apply_move(0)
    assert purple_token.location == TokenLocation.HOME
