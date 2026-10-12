import '../board/board_metrics.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/token.dart';

/// Pure validator that calculates legal moves for a given player and dice roll.
class MoveValidator {
  const MoveValidator._();

  /// Computes all legal moves available to [player] given the [diceValue] and current [state].
  static List<MoveOption> calculateLegalMoves({
    required GameState state,
    required PlayerState player,
    required int diceValue,
  }) {
    if (diceValue < 1 || diceValue > 6) {
      return const [];
    }

    final ruleset = state.ruleset;

    // Team Mode partner assistance:
    // If this player has all tokens in home, and partnerControlWhenFinished is enabled,
    // they can roll and move their active teammate's tokens!
    if (ruleset.isTeamMode &&
        ruleset.partnerControlWhenFinished &&
        player.areAllTokensHome &&
        player.teamId != null) {
      final teammate = state.players.cast<PlayerState?>().firstWhere(
            (p) => p?.teamId == player.teamId && p?.id != player.id,
            orElse: () => null,
          );
      if (teammate != null && !teammate.areAllTokensHome) {
        return calculateLegalMoves(
          state: state,
          player: teammate,
          diceValue: diceValue,
        );
      }
      return const [];
    }

    final options = <MoveOption>[];

    for (final token in player.tokens) {
      switch (token.state) {
        case TokenState.home:
          // Finished tokens cannot move.
          continue;

        case TokenState.yard:
          if (diceValue == 6) {
            final startCell = player.color.startTrackCell;

            // Check if player's own token blocks start cell if stacking is disabled.
            if (!ruleset.allowSameColorStacking) {
              final selfBlocking = player.tokens.any(
                (t) => t.state == TokenState.track && t.trackCell == startCell,
              );
              if (selfBlocking) continue;
            }

            // Check if an enemy token can be captured on start cell.
            final captureTarget = _findVulnerableOpponent(
              state: state,
              currentPlayer: player,
              targetTrackCell: startCell,
            );

            options.add(
              MoveOption(
                tokenId: token.id,
                color: token.color,
                fromState: TokenState.yard,
                toState: TokenState.track,
                fromTrackCell: null,
                toTrackCell: startCell,
                fromLaneStep: 0,
                toLaneStep: 0,
                willCapture: captureTarget != null,
                capturedTokenId: captureTarget?.$1.id,
                capturedPlayerId: captureTarget?.$2.id,
                willReachHome: false,
              ),
            );
          }
          break;

        case TokenState.track:
          final newProgress = token.stepCount + diceValue;

          if (newProgress < BoardMetrics.trackStepsBeforeHomeLane) {
            // Token remains on the common circular track.
            final targetCell = BoardMetrics.getTrackCell(player.color, newProgress);

            if (!ruleset.allowSameColorStacking) {
              final selfBlocking = player.tokens.any(
                (t) =>
                    t.id != token.id &&
                    t.state == TokenState.track &&
                    t.trackCell == targetCell,
              );
              if (selfBlocking) continue;
            }

            final captureTarget = _findVulnerableOpponent(
              state: state,
              currentPlayer: player,
              targetTrackCell: targetCell,
            );

            options.add(
              MoveOption(
                tokenId: token.id,
                color: token.color,
                fromState: TokenState.track,
                toState: TokenState.track,
                fromTrackCell: token.trackCell,
                toTrackCell: targetCell,
                fromLaneStep: 0,
                toLaneStep: 0,
                willCapture: captureTarget != null,
                capturedTokenId: captureTarget?.$1.id,
                capturedPlayerId: captureTarget?.$2.id,
                willReachHome: false,
              ),
            );
          } else {
            // In Quick Mode, a capture must have been performed before entering home lane.
            if (ruleset.requireCaptureForHomeEntry && !player.hasCaptured) {
              continue;
            }

            // Token transitions towards home lane or home.
            // step 50 is the last common track step (index 50).
            // newProgress 51 -> home lane step 1.
            // newProgress 56 -> home lane step 6 (HOME).
            final targetLaneStep = newProgress - (BoardMetrics.trackStepsBeforeHomeLane - 1);

            if (targetLaneStep <= BoardMetrics.homeLaneSteps) {
              options.add(
                MoveOption(
                  tokenId: token.id,
                  color: token.color,
                  fromState: TokenState.track,
                  toState: TokenState.homeLane,
                  fromTrackCell: token.trackCell,
                  toTrackCell: null,
                  fromLaneStep: 0,
                  toLaneStep: targetLaneStep,
                  willCapture: false,
                  willReachHome: false,
                ),
              );
            } else if (targetLaneStep == BoardMetrics.homeLaneSteps + 1) {
              // Lands exactly into HOME!
              options.add(
                MoveOption(
                  tokenId: token.id,
                  color: token.color,
                  fromState: TokenState.track,
                  toState: TokenState.home,
                  fromTrackCell: token.trackCell,
                  toTrackCell: null,
                  fromLaneStep: 0,
                  toLaneStep: 6,
                  willCapture: false,
                  willReachHome: true,
                ),
              );
            } else {
              // Target step > 6: Overshoot!
              if (!ruleset.exactRollRequiredForHome) {
                options.add(
                  MoveOption(
                    tokenId: token.id,
                    color: token.color,
                    fromState: TokenState.track,
                    toState: TokenState.home,
                    fromTrackCell: token.trackCell,
                    toTrackCell: null,
                    fromLaneStep: 0,
                    toLaneStep: 6,
                    willCapture: false,
                    willReachHome: true,
                  ),
                );
              }
            }
          }
          break;

        case TokenState.homeLane:
          final targetLaneStep = token.laneStep + diceValue;

          if (targetLaneStep <= BoardMetrics.homeLaneSteps) {
            options.add(
              MoveOption(
                tokenId: token.id,
                color: token.color,
                fromState: TokenState.homeLane,
                toState: TokenState.homeLane,
                fromTrackCell: null,
                toTrackCell: null,
                fromLaneStep: token.laneStep,
                toLaneStep: targetLaneStep,
                willCapture: false,
                willReachHome: false,
              ),
            );
          } else if (targetLaneStep == BoardMetrics.homeLaneSteps + 1) {
            // Exactly lands into HOME
            options.add(
              MoveOption(
                tokenId: token.id,
                color: token.color,
                fromState: TokenState.homeLane,
                toState: TokenState.home,
                fromTrackCell: null,
                toTrackCell: null,
                fromLaneStep: token.laneStep,
                toLaneStep: 6,
                willCapture: false,
                willReachHome: true,
              ),
            );
          } else {
            // Overshoot
            if (!ruleset.exactRollRequiredForHome) {
              options.add(
                MoveOption(
                  tokenId: token.id,
                  color: token.color,
                  fromState: TokenState.homeLane,
                  toState: TokenState.home,
                  fromTrackCell: null,
                  toTrackCell: null,
                  fromLaneStep: token.laneStep,
                  toLaneStep: 6,
                  willCapture: false,
                  willReachHome: true,
                ),
              );
            }
          }
          break;
      }
    }

    return List.unmodifiable(options);
  }

  /// Locates an opponent token occupying [targetTrackCell] that can be captured.
  /// Returns null if the cell is safe or occupied only by teammates/self.
  static (Token, PlayerState)? _findVulnerableOpponent({
    required GameState state,
    required PlayerState currentPlayer,
    required int targetTrackCell,
  }) {
    if (state.ruleset.isSafeCell(targetTrackCell)) {
      return null;
    }

    for (final opponent in state.players) {
      if (opponent.id == currentPlayer.id || opponent.seat == currentPlayer.seat) {
        continue;
      }

      // In Team Mode, exclude teammates from capture
      if (state.ruleset.isTeamMode &&
          !state.ruleset.teammateCaptureAllowed &&
          opponent.teamId != null &&
          opponent.teamId == currentPlayer.teamId) {
        continue;
      }

      for (final enemyToken in opponent.tokens) {
        if (enemyToken.state == TokenState.track &&
            enemyToken.trackCell == targetTrackCell) {
          return (enemyToken, opponent);
        }
      }
    }

    return null;
  }
}
