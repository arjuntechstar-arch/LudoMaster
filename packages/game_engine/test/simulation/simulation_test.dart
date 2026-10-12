import 'dart:math';
import 'package:game_engine/game_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Ludo Simulation Suite (Phase 1 Exit Criteria)', () {
    void runSimulation({
      required int playerCount,
      required RulesetConfig ruleset,
      required BotDifficulty difficulty,
      int seed = 42,
    }) {
      final rng = Random(seed);
      final colors = [
        PlayerColor.red,
        PlayerColor.green,
        PlayerColor.yellow,
        PlayerColor.blue,
      ].take(playerCount).toList();

      final players = colors.map((color) {
        return PlayerState(
          id: 'bot_${color.name}',
          name: 'Bot ${color.name.toUpperCase()}',
          seat: color.seatIndex,
          color: color,
          isBot: true,
          tokens: const [],
        );
      }).toList();

      var result = LudoEngine.initializeGame(
        matchId: 'sim_${playerCount}p_${difficulty.name}_$seed',
        ruleset: ruleset,
        players: players,
      );

      var turns = 0;
      const maxTurns = 5000;

      while (result.state.status == GameStatus.inProgress && turns < maxTurns) {
        turns++;
        final activePlayer = result.state.currentPlayer;

        // Roll dice
        final roll = rng.nextInt(6) + 1;
        result = LudoEngine.applyRoll(
          state: result.state,
          player: activePlayer,
          diceValue: roll,
        );

        InvariantChecker.validate(result.state);

        // Move if required
        if (result.state.phase == GamePhase.moveRequired) {
          final move = BotEvaluator.chooseMove(
            state: result.state,
            player: activePlayer,
            legalMoves: result.state.legalMoves,
            difficulty: difficulty,
            rng: rng,
          );

          result = LudoEngine.applyMove(
            state: result.state,
            player: activePlayer,
            tokenId: move.tokenId,
          );

          InvariantChecker.validate(result.state);
        }
      }

      expect(
        result.state.status,
        equals(GameStatus.finished),
        reason: 'Game should reach finished status without exceeding $maxTurns turns',
      );
      expect(result.state.placements.length, equals(playerCount));
      expect(result.state.placements.toSet().length, equals(playerCount));
    }

    test('2-player classic simulation completes with valid placements', () {
      runSimulation(
        playerCount: 2,
        ruleset: RulesetConfig.classic,
        difficulty: BotDifficulty.hard,
        seed: 101,
      );
    });

    test('3-player classic simulation completes with valid placements', () {
      runSimulation(
        playerCount: 3,
        ruleset: RulesetConfig.classic,
        difficulty: BotDifficulty.medium,
        seed: 202,
      );
    });

    test('4-player classic simulation completes with valid placements', () {
      runSimulation(
        playerCount: 4,
        ruleset: RulesetConfig.classic,
        difficulty: BotDifficulty.hard,
        seed: 303,
      );
    });

    test('Quick mode (2 tokens) simulation completes cleanly', () {
      runSimulation(
        playerCount: 4,
        ruleset: RulesetConfig.quick,
        difficulty: BotDifficulty.hard,
        seed: 404,
      );
    });

    test('Easy bot simulation completes without invariant violations', () {
      runSimulation(
        playerCount: 4,
        ruleset: RulesetConfig.classic,
        difficulty: BotDifficulty.easy,
        seed: 505,
      );
    });
  });
}
