import '../board/board_metrics.dart';
import '../models/game_state.dart';
import '../models/token.dart';

/// Invariant validation to guarantee zero corrupt states across transitions and simulations.
class InvariantChecker {
  const InvariantChecker._();

  /// Validates all domain invariants for a [GameState].
  /// Throws [StateError] if any invariant is violated.
  static void validate(GameState state) {
    // 1. Match ID and sequence
    if (state.matchId.isEmpty) {
      throw StateError('Invariant violation: matchId cannot be empty.');
    }
    if (state.sequence < 0) {
      throw StateError('Invariant violation: sequence cannot be negative (${state.sequence}).');
    }

    // 2. Players count
    if (state.players.length < 2 || state.players.length > 6) {
      throw StateError(
        'Invariant violation: player count must be between 2 and 6 (got ${state.players.length}).',
      );
    }

    // 3. Current seat validation
    if (state.status == GameStatus.inProgress) {
      final activePlayer = state.getPlayerBySeat(state.currentSeat);
      if (activePlayer == null) {
        throw StateError(
          'Invariant violation: currentSeat ${state.currentSeat} does not correspond to any player.',
        );
      }
      if (activePlayer.hasFinished) {
        final isTeamPartnerAssisting = state.ruleset.isTeamMode &&
            state.ruleset.partnerControlWhenFinished &&
            activePlayer.teamId != null &&
            state.players.any(
              (p) => p.teamId == activePlayer.teamId && !p.areAllTokensHome,
            );
        if (!isTeamPartnerAssisting) {
          throw StateError(
            'Invariant violation: activePlayer seat ${state.currentSeat} has already finished.',
          );
        }
      }
    }

    // 4. Consecutive sixes range
    if (state.consecutiveSixes < 0 ||
        state.consecutiveSixes > state.ruleset.maxConsecutiveSixes) {
      throw StateError(
        'Invariant violation: consecutiveSixes (${state.consecutiveSixes}) exceeded limit (${state.ruleset.maxConsecutiveSixes}).',
      );
    }

    // 5. Token invariants per player
    for (final player in state.players) {
      if (player.tokens.length != state.ruleset.tokensPerPlayer) {
        throw StateError(
          'Invariant violation: player ${player.id} has ${player.tokens.length} tokens, expected ${state.ruleset.tokensPerPlayer}.',
        );
      }

      for (final token in player.tokens) {
        // Correct color assignment
        if (token.color != player.color) {
          throw StateError(
            'Invariant violation: token ${token.id} has color ${token.color} but player has ${player.color}.',
          );
        }

        switch (token.state) {
          case TokenState.yard:
            if (token.trackCell != null) {
              throw StateError(
                'Invariant violation: token ${token.id} in YARD must have trackCell == null.',
              );
            }
            if (token.stepCount != 0 || token.laneStep != 0) {
              throw StateError(
                'Invariant violation: token ${token.id} in YARD must have stepCount == 0 and laneStep == 0.',
              );
            }
            break;

          case TokenState.track:
            if (token.trackCell == null) {
              throw StateError(
                'Invariant violation: token ${token.id} on TRACK must have a non-null trackCell.',
              );
            }
            if (token.trackCell! < 0 || token.trackCell! >= BoardMetrics.trackLength) {
              throw StateError(
                'Invariant violation: token ${token.id} trackCell ${token.trackCell} out of bounds (0..51).',
              );
            }
            if (token.stepCount < 0 ||
                token.stepCount >= BoardMetrics.trackStepsBeforeHomeLane) {
              throw StateError(
                'Invariant violation: token ${token.id} stepCount ${token.stepCount} out of bounds (0..50).',
              );
            }
            // Verify coordinate consistency
            final expectedCell = BoardMetrics.getTrackCell(token.color, token.stepCount);
            if (token.trackCell != expectedCell) {
              throw StateError(
                'Invariant violation: token ${token.id} trackCell ${token.trackCell} != expected $expectedCell.',
              );
            }
            break;

          case TokenState.homeLane:
            if (token.trackCell != null) {
              throw StateError(
                'Invariant violation: token ${token.id} in HOME_LANE must have trackCell == null.',
              );
            }
            if (token.laneStep < 1 || token.laneStep > BoardMetrics.homeLaneSteps) {
              throw StateError(
                'Invariant violation: token ${token.id} laneStep ${token.laneStep} out of bounds (1..5).',
              );
            }
            break;

          case TokenState.home:
            if (token.trackCell != null) {
              throw StateError(
                'Invariant violation: token ${token.id} in HOME must have trackCell == null.',
              );
            }
            if (token.laneStep != 6) {
              throw StateError(
                'Invariant violation: token ${token.id} in HOME must have laneStep == 6.',
              );
            }
            break;
        }
      }

      // Check player finish status consistency
      final allHome = player.tokens.every((t) => t.state == TokenState.home);
      if (allHome && !player.hasFinished) {
        throw StateError(
          'Invariant violation: all tokens of player ${player.id} are home, but hasFinished is false.',
        );
      }
    }

    // 6. Placements consistency
    final placementSet = <String>{};
    for (final id in state.placements) {
      if (!placementSet.add(id)) {
        throw StateError(
          'Invariant violation: duplicate player ID in placements list ($id).',
        );
      }
      final player = state.getPlayerById(id);
      if (player == null) {
        throw StateError(
          'Invariant violation: unknown player ID in placements ($id).',
        );
      }
    }
  }
}
