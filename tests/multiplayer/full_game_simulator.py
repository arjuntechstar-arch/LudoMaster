#!/usr/bin/env python3
import argparse
import random
import time
from collections import Counter

from services.realtime.engine.ludo_server_engine import LudoServerEngine
from services.realtime.engine.models import Color, Seat, TokenLocation, TurnPhase

COLORS = [Color.RED, Color.GREEN, Color.YELLOW, Color.BLUE, Color.ORANGE, Color.PURPLE]


def make_engine(game_id: str, players: int) -> LudoServerEngine:
    seats = [
        Seat(
            seat_index=i,
            user_id=f"sim-user-{i}",
            display_name=f"Player {i + 1}",
            avatar_id="avatar_0",
            color=COLORS[i],
            is_connected=True,
            is_bot=False,
        )
        for i in range(players)
    ]
    return LudoServerEngine(game_id, seats, mode="CLASSIC")


def assert_invariants(engine: LudoServerEngine) -> None:
    assert 0 <= engine.current_seat_index < len(engine.seats)
    assert len(set(engine.placements)) == len(engine.placements)
    for seat in engine.seats:
        assert len(seat.tokens) == engine.tokens_per_player
        ids = [token.id for token in seat.tokens]
        assert len(ids) == len(set(ids))
        for token in seat.tokens:
            assert 0 <= token.steps_taken <= engine.total_steps_to_finish
            if token.location == TokenLocation.YARD:
                assert token.position == -1
                assert token.steps_taken == 0
            elif token.location == TokenLocation.TRACK:
                assert 0 <= token.position < engine.track_length
            elif token.location == TokenLocation.HOME_LANE:
                assert 0 <= token.position <= 5
            elif token.location == TokenLocation.HOME:
                assert token.position == -1
                assert token.steps_taken == engine.total_steps_to_finish


def run_game(index: int, players: int, rng: random.Random, stress: bool) -> dict:
    engine = make_engine(f"sim-{players}-{index}", players)
    rolls = moves = captures = 0
    max_actions = 25000

    for action in range(max_actions):
        assert_invariants(engine)
        if engine.phase == TurnPhase.FINISHED:
            break
        if engine.phase == TurnPhase.ROLL_REQUIRED:
            forced_roll = rng.randint(1, 6)
            _, legal_moves = engine.roll_dice(forced_value=forced_roll)
            rolls += 1
            if stress and rng.random() < 0.03:
                # Duplicate roll attempts must be rejected once a move is required.
                try:
                    engine.roll_dice(forced_value=rng.randint(1, 6))
                    if engine.phase == TurnPhase.MOVE_REQUIRED:
                        raise AssertionError("Duplicate roll was accepted during MOVE_REQUIRED")
                except ValueError:
                    pass
            if not legal_moves:
                continue
        if engine.phase == TurnPhase.MOVE_REQUIRED:
            move = rng.choice(engine.legal_moves)
            _, capture, _ = engine.apply_move(move.token_id)
            moves += 1
            if capture:
                captures += len(capture.get("captured", []))
            if stress and rng.random() < 0.03:
                # A stale/duplicate move must not be accepted after resolution.
                try:
                    engine.apply_move(move.token_id)
                    raise AssertionError("Duplicate move was accepted")
                except ValueError:
                    pass
    else:
        raise AssertionError(f"Game {index} exceeded {max_actions} actions")

    assert engine.phase == TurnPhase.FINISHED
    assert len(engine.placements) == players
    assert_invariants(engine)
    return {"players": players, "rolls": rolls, "moves": moves, "captures": captures}


def main() -> None:
    parser = argparse.ArgumentParser(description="LudoMaster full-game multiplayer simulator")
    parser.add_argument("--games", type=int, default=200)
    parser.add_argument("--seed", type=int, default=20261012)
    parser.add_argument("--stress", action="store_true")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    distribution = [2, 3, 4, 6]
    stats = Counter()
    started = time.perf_counter()
    for game_index in range(args.games):
        players = distribution[game_index % len(distribution)]
        result = run_game(game_index, players, rng, args.stress)
        stats["games"] += 1
        stats[f"{players}p_games"] += 1
        stats["rolls"] += result["rolls"]
        stats["moves"] += result["moves"]
        stats["captures"] += result["captures"]

    elapsed = time.perf_counter() - started
    print("LudoMaster multiplayer simulation PASS")
    print(f"games={stats['games']} rolls={stats['rolls']} moves={stats['moves']} captures={stats['captures']} elapsed={elapsed:.2f}s")
    print("distribution=" + ", ".join(f"{p}p:{stats[f'{p}p_games']}" for p in distribution))


if __name__ == "__main__":
    main()
