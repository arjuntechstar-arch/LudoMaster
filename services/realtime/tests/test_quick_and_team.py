import pytest
from services.realtime.engine.ludo_server_engine import LudoServerEngine
from services.realtime.engine.models import Color, Seat, TokenLocation, TurnPhase

def test_quick_mode_capture_requirement():
    """In quick mode, home lane entry is forbidden until player has captured an opponent."""
    seats = [
        Seat(seat_index=0, user_id="u1", display_name="RedPlayer", avatar_id="a1", color=Color.RED),
        Seat(seat_index=1, user_id="u2", display_name="GreenPlayer", avatar_id="a2", color=Color.GREEN),
    ]
    engine = LudoServerEngine(
        match_id="test_quick_1",
        seats=seats,
        tokens_per_player=2,
        require_capture_for_home=True,
    )

    token0 = engine.seats[0].tokens[0]
    token0.location = TokenLocation.TRACK
    token0.position = 50
    token0.steps_taken = 50  # Steps to home entry is 51

    # Red has not captured yet
    assert not engine.seats[0].has_captured

    # Roll 2: new_steps = 52 >= 51 (home entry). Should be rejected because has_captured is False
    legal_moves = engine.calculate_legal_moves(engine.seats[0], 2)
    assert len(legal_moves) == 0

    # Roll 1: new_steps = 51 == steps_to_home_entry. Also enters home lane, so rejected
    legal_moves = engine.calculate_legal_moves(engine.seats[0], 1)
    assert len(legal_moves) == 0

    # Now simulate a capture for Red
    engine.seats[0].has_captured = True

    # Roll 2: enters home lane at pos 1 (52 - 51 = 1). Now permitted!
    legal_moves = engine.calculate_legal_moves(engine.seats[0], 2)
    assert len(legal_moves) == 1
    assert legal_moves[0].to_location == TokenLocation.HOME_LANE
    assert legal_moves[0].to_position == 1

def test_team_mode_assignments_and_friendly_fire():
    """In team mode, seats 0 & 2 are Team 0, seats 1 & 3 are Team 1. Teammates cannot capture each other."""
    seats = [
        Seat(seat_index=0, user_id="u0", display_name="Red", avatar_id="a0", color=Color.RED),
        Seat(seat_index=1, user_id="u1", display_name="Green", avatar_id="a1", color=Color.GREEN),
        Seat(seat_index=2, user_id="u2", display_name="Yellow", avatar_id="a2", color=Color.YELLOW),
        Seat(seat_index=3, user_id="u3", display_name="Blue", avatar_id="a3", color=Color.BLUE),
    ]
    engine = LudoServerEngine(
        match_id="test_team_1",
        seats=seats,
        tokens_per_player=4,
        is_team_mode=True,
    )

    assert engine.seats[0].team_id == 0
    assert engine.seats[2].team_id == 0
    assert engine.seats[1].team_id == 1
    assert engine.seats[3].team_id == 1

    # Place Yellow (team 0) token at cell 10 (unsafe cell)
    yellow_token = engine.seats[2].tokens[0]
    yellow_token.location = TokenLocation.TRACK
    yellow_token.position = 10
    yellow_token.steps_taken = 36  # Yellow offset is 26, (26 + 36) % 52 = 10

    # Red (team 0) token at cell 7 (steps 7)
    red_token = engine.seats[0].tokens[0]
    red_token.location = TokenLocation.TRACK
    red_token.position = 7
    red_token.steps_taken = 7

    # Red rolls 3 to land on 10 (where Yellow teammate sits)
    val, moves = engine.roll_dice(forced_value=3)
    assert val == 3
    red_move = next((m for m in moves if m.token_id == red_token.id), None)
    assert red_move is not None
    assert red_move.to_position == 10
    # Capture MUST be false because Yellow is on the same team!
    assert red_move.is_capture is False

    # Apply move: Yellow token must NOT be sent back to Yard
    move, cap, bonus = engine.apply_move(token_id=red_token.id)
    assert cap is None
    assert yellow_token.location == TokenLocation.TRACK
    assert yellow_token.position == 10
    assert red_token.position == 10

def test_team_mode_partner_control_when_finished():
    """When a teammate finishes all 4 tokens, they roll for and move their partner's tokens."""
    seats = [
        Seat(seat_index=0, user_id="u0", display_name="Red", avatar_id="a0", color=Color.RED),
        Seat(seat_index=1, user_id="u1", display_name="Green", avatar_id="a1", color=Color.GREEN),
        Seat(seat_index=2, user_id="u2", display_name="Yellow", avatar_id="a2", color=Color.YELLOW),
        Seat(seat_index=3, user_id="u3", display_name="Blue", avatar_id="a3", color=Color.BLUE),
    ]
    engine = LudoServerEngine(
        match_id="test_team_control",
        seats=seats,
        tokens_per_player=4,
        is_team_mode=True,
    )

    # Set Red (seat 0) all tokens to HOME
    for t in engine.seats[0].tokens:
        t.location = TokenLocation.HOME
        t.position = -1
        t.steps_taken = 56

    # Yellow (seat 2, teammate) has 1 token on track, 3 in Yard
    yellow_token = engine.seats[2].tokens[0]
    yellow_token.location = TokenLocation.TRACK
    yellow_token.position = 28
    yellow_token.steps_taken = 2

    # It is Red's turn (seat 0)
    engine.current_seat_index = 0
    engine.phase = TurnPhase.ROLL_REQUIRED

    # Red rolls 4
    val, moves = engine.roll_dice(forced_value=4)
    assert val == 4
    # Legal moves should be for Yellow's tokens!
    assert len(moves) == 1
    assert moves[0].token_id == yellow_token.id
    assert moves[0].to_position == 32

    # Red applies the move for Yellow's token
    move, cap, bonus = engine.apply_move(token_id=yellow_token.id)
    assert yellow_token.position == 32
    assert yellow_token.steps_taken == 6

def test_team_mode_victory_condition():
    """Team wins when all 8 tokens of both teammates reach HOME."""
    seats = [
        Seat(seat_index=0, user_id="u0", display_name="Red", avatar_id="a0", color=Color.RED),
        Seat(seat_index=1, user_id="u1", display_name="Green", avatar_id="a1", color=Color.GREEN),
        Seat(seat_index=2, user_id="u2", display_name="Yellow", avatar_id="a2", color=Color.YELLOW),
        Seat(seat_index=3, user_id="u3", display_name="Blue", avatar_id="a3", color=Color.BLUE),
    ]
    engine = LudoServerEngine(
        match_id="test_team_win",
        seats=seats,
        tokens_per_player=2,
        is_team_mode=True,
    )

    # Red's 2 tokens already HOME
    for t in engine.seats[0].tokens:
        t.location = TokenLocation.HOME

    # Yellow's token 0 in HOME, token 1 in Home Lane at step 55 (needs 1 to finish)
    engine.seats[2].tokens[0].location = TokenLocation.HOME
    last_yellow = engine.seats[2].tokens[1]
    last_yellow.location = TokenLocation.HOME_LANE
    last_yellow.position = 4
    last_yellow.steps_taken = 55

    # Yellow's turn, rolls 1
    engine.current_seat_index = 2
    engine.phase = TurnPhase.ROLL_REQUIRED

    val, moves = engine.roll_dice(forced_value=1)
    assert val == 1
    assert moves[0].is_home_finish is True

    move, cap, bonus = engine.apply_move(token_id=last_yellow.id)
    assert engine.phase == TurnPhase.FINISHED
    assert engine.seats[0].placement == 1
    assert engine.seats[2].placement == 1
    assert engine.seats[1].placement == 2
    assert engine.seats[3].placement == 2
