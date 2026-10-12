import 'dart:math';
import '../board/board_metrics.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/token.dart';

/// Configurable bot difficulty levels.
enum BotDifficulty {
  easy,
  medium,
  hard;

  static BotDifficulty fromString(String val) {
    return BotDifficulty.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => throw ArgumentError('Unknown BotDifficulty: $val'),
    );
  }
}

/// Evaluates legal moves for computer players using heuristic scoring.
/// Never bypasses rules and never peeks at future RNG rolls.
class BotEvaluator {
  const BotEvaluator._();

  /// Selects the best move from [legalMoves] for [player] according to [difficulty].
  static MoveOption chooseMove({
    required GameState state,
    required PlayerState player,
    required List<MoveOption> legalMoves,
    BotDifficulty difficulty = BotDifficulty.hard,
    Random? rng,
  }) {
    if (legalMoves.isEmpty) {
      throw ArgumentError('Cannot evaluate move: legalMoves is empty');
    }

    if (legalMoves.length == 1) {
      return legalMoves.first;
    }

    final random = rng ?? Random();

    switch (difficulty) {
      case BotDifficulty.easy:
        // Pure random selection
        return legalMoves[random.nextInt(legalMoves.length)];

      case BotDifficulty.medium:
        // Basic heuristic: complete > capture > leave yard > safe cell > progress
        MoveOption best = legalMoves.first;
        var bestScore = double.negativeInfinity;

        for (final move in legalMoves) {
          var score = 0.0;
          if (move.willReachHome) score += 500;
          if (move.willCapture) score += 400;
          if (move.fromState == TokenState.yard) score += 200;
          if (move.toTrackCell != null && state.ruleset.isSafeCell(move.toTrackCell!)) {
            score += 150;
          }
          score += move.toLaneStep * 10;
          // Add small random noise to prevent identical ties
          score += random.nextDouble() * 5;

          if (score > bestScore) {
            bestScore = score;
            best = move;
          }
        }
        return best;

      case BotDifficulty.hard:
        // Comprehensive heuristic weighing threats, escapes, captures, and home progress
        MoveOption best = legalMoves.first;
        var bestScore = double.negativeInfinity;

        for (final move in legalMoves) {
          final score = _evaluateHardMove(state, player, move, random);
          if (score > bestScore) {
            bestScore = score;
            best = move;
          }
        }
        return best;
    }
  }

  static double _evaluateHardMove(
    GameState state,
    PlayerState player,
    MoveOption move,
    Random random,
  ) {
    var score = 0.0;

    // 1. Reaching home is the highest priority
    if (move.willReachHome) {
      score += 1000.0;
    }

    // 2. Capturing opponent
    if (move.willCapture) {
      score += 800.0;
      // High bonus if capturing an opponent that was far along
      if (move.capturedTokenId != null) {
        score += 50.0;
      }
    }

    // 3. Leaving yard
    if (move.fromState == TokenState.yard) {
      score += 450.0;
    }

    // 4. Moving into home lane (safe from all attacks)
    if (move.toState == TokenState.homeLane && move.fromState == TokenState.track) {
      score += 350.0;
    }

    // 5. Landing on a safe cell
    if (move.toTrackCell != null && state.ruleset.isSafeCell(move.toTrackCell!)) {
      score += 300.0;
    }

    // 6. Escaping vulnerability: if token is currently on an unsafe track cell with an enemy 1..6 steps behind
    if (move.fromState == TokenState.track &&
        move.fromTrackCell != null &&
        !state.ruleset.isSafeCell(move.fromTrackCell!)) {
      final isCurrentlyThreatened = _isCellThreatened(state, player, move.fromTrackCell!);
      if (isCurrentlyThreatened) {
        score += 400.0; // Urgent escape bonus
      }
    }

    // 7. Landing on an unsafe cell with threat behind
    if (move.toTrackCell != null && !state.ruleset.isSafeCell(move.toTrackCell!)) {
      final willBeThreatened = _isCellThreatened(state, player, move.toTrackCell!);
      if (willBeThreatened) {
        score -= 250.0; // Penalty for moving into danger
      }
    }

    // 8. General progress towards finish
    if (move.toState == TokenState.track) {
      final token = player.getToken(move.tokenId)!;
      final stepProgress = token.stepCount + (state.diceValue ?? 0);
      score += stepProgress * 2.0;
    } else if (move.toState == TokenState.homeLane) {
      score += 100.0 + (move.toLaneStep * 20.0);
    }

    // Small deterministic tie-breaker noise
    score += random.nextDouble();

    return score;
  }

  /// Checks if any opponent token can reach [targetCell] in a single 1..6 roll.
  static bool _isCellThreatened(GameState state, PlayerState player, int targetCell) {
    for (final opp in state.players) {
      if (opp.id == player.id || opp.seat == player.seat) continue;
      for (final enemyToken in opp.tokens) {
        if (enemyToken.state != TokenState.track || enemyToken.trackCell == null) {
          continue;
        }
        final enemyCell = enemyToken.trackCell!;
        final distance = (targetCell - enemyCell) % BoardMetrics.trackLength;
        if (distance >= 1 && distance <= 6) {
          // Opponent can reach this cell with a 1..6 roll!
          return true;
        }
      }
    }
    return false;
  }
}
