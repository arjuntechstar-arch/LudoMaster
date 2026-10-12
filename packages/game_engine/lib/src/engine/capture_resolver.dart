import '../models/domain_event.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/token.dart';

/// Pure resolver for handling captures and resetting captured tokens back to yard.
class CaptureResolver {
  const CaptureResolver._();

  /// Resolves token capture if [move] lands on an opponent's vulnerable token.
  /// Returns the updated list of [PlayerState]s and optional [DomainEvent].
  static (List<PlayerState>, DomainEvent?, bool) resolveCapture({
    required GameState state,
    required PlayerState movingPlayer,
    required MoveOption move,
    required int sequence,
    required String serverTime,
  }) {
    if (!move.willCapture || move.toTrackCell == null) {
      return (state.players, null, false);
    }

    final targetCell = move.toTrackCell!;
    if (state.ruleset.isSafeCell(targetCell)) {
      return (state.players, null, false);
    }

    Token? capturedToken;
    PlayerState? targetOpponent;

    // Locate the opponent whose token is captured
    final updatedPlayers = state.players.map((player) {
      if (player.id == movingPlayer.id || player.seat == movingPlayer.seat) {
        return player;
      }

      // In Team Mode, ignore teammate tokens if friendly fire is disabled
      if (state.ruleset.isTeamMode &&
          !state.ruleset.teammateCaptureAllowed &&
          player.teamId != null &&
          player.teamId == movingPlayer.teamId) {
        return player;
      }

      final updatedTokens = player.tokens.map((token) {
        if (token.state == TokenState.track &&
            token.trackCell == targetCell &&
            capturedToken == null) {
          capturedToken = token;
          targetOpponent = player;
          // Return captured token back to YARD
          return token.copyWith(
            state: TokenState.yard,
            stepCount: 0,
            laneStep: 0,
            clearTrackCell: true,
          );
        }
        return token;
      }).toList();

      return player.copyWith(tokens: updatedTokens);
    }).toList();

    if (capturedToken != null && targetOpponent != null) {
      // Mark moving player as having made a capture
      final finalPlayers = updatedPlayers.map((p) {
        if (p.id == movingPlayer.id || p.seat == movingPlayer.seat) {
          return p.copyWith(hasCaptured: true);
        }
        return p;
      }).toList();

      final captureEvent = DomainEvent(
        event: EventType.tokenCaptured,
        matchId: state.matchId,
        sequence: sequence,
        serverTime: serverTime,
        payload: {
          'capturedByPlayerId': movingPlayer.id,
          'capturedTokenId': capturedToken!.id,
          'victimPlayerId': targetOpponent!.id,
          'trackCell': targetCell,
        },
      );

      final grantsBonus = state.ruleset.captureGrantsBonusTurn;
      return (finalPlayers, captureEvent, grantsBonus);
    }

    return (state.players, null, false);
  }
}
