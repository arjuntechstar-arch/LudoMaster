import '../models/game_state.dart';
import '../models/player.dart';

/// Pure turn management, seat rotation, bonus turns, and placement calculation.
class TurnManager {
  const TurnManager._();

  /// Calculates the next seat to play among active, unfinished players.
  static int getNextActiveSeat({
    required List<PlayerState> players,
    required int currentSeat,
    bool isTeamMode = false,
  }) {
    final sortedSeats = players.map((p) => p.seat).toList()..sort();
    final currentIndex = sortedSeats.indexOf(currentSeat);

    for (var i = 1; i <= sortedSeats.length; i++) {
      final nextSeatIndex = (currentIndex + i) % sortedSeats.length;
      final candidateSeat = sortedSeats[nextSeatIndex];
      final candidatePlayer = players.firstWhere((p) => p.seat == candidateSeat);

      if (isTeamMode && candidatePlayer.teamId != null) {
        // In team mode, seat can play if their team still has unfinished tokens to move
        final teamHasActiveTokens = players.any(
          (p) => p.teamId == candidatePlayer.teamId && !p.areAllTokensHome,
        );
        if (teamHasActiveTokens) {
          return candidateSeat;
        }
      } else {
        if (!candidatePlayer.hasFinished) {
          return candidateSeat;
        }
      }
    }

    return currentSeat;
  }

  /// Checks if match completion conditions are met.
  /// In Team Mode, game completes when all tokens of a team reach home.
  /// In Standard Ludo: game ends when only 1 active player remains unfinished.
  static (bool isFinished, List<String> updatedPlacements, List<PlayerState> updatedPlayers)
      evaluateGameCompletion({
    required List<PlayerState> players,
    required List<String> currentPlacements,
    bool isTeamMode = false,
  }) {
    if (isTeamMode) {
      final team0 = players.where((p) => p.teamId == 0).toList();
      final team1 = players.where((p) => p.teamId == 1).toList();

      final team0Won = team0.isNotEmpty && team0.every((p) => p.areAllTokensHome);
      final team1Won = team1.isNotEmpty && team1.every((p) => p.areAllTokensHome);

      if (team0Won || team1Won) {
        final winningTeam = team0Won ? team0 : team1;
        final losingTeam = team0Won ? team1 : team0;

        final placements = <String>[
          ...winningTeam.map((p) => p.id),
          ...losingTeam.map((p) => p.id),
        ];

        final finalPlayers = players.map((p) {
          final isWinner = winningTeam.any((w) => w.id == p.id);
          return p.copyWith(
            hasFinished: true,
            placement: isWinner ? 1 : 2,
          );
        }).toList();

        return (true, List.unmodifiable(placements), List.unmodifiable(finalPlayers));
      }

      return (false, currentPlacements, players);
    }

    final unfinished = players.where((p) => !p.hasFinished).toList();

    // If 1 or fewer players remain unfinished, assign remaining placement and finish game.
    if (unfinished.length <= 1) {
      final placements = List<String>.from(currentPlacements);
      final finalPlayers = players.map((p) {
        if (!p.hasFinished && unfinished.contains(p)) {
          if (!placements.contains(p.id)) {
            placements.add(p.id);
          }
          return p.copyWith(
            hasFinished: true,
            placement: placements.length,
          );
        }
        return p;
      }).toList();

      return (true, List.unmodifiable(placements), List.unmodifiable(finalPlayers));
    }

    return (false, currentPlacements, players);
  }

  /// Evaluates bonus turn conditions.
  static bool shouldGrantBonusTurn({
    required PlayerState player,
    required bool rolledSix,
    required bool madeCapture,
    required bool tokenReachedHome,
    required bool consecutiveSixForfeit,
    required GameState state,
  }) {
    if (player.hasFinished) {
      final canAssistPartner = state.ruleset.isTeamMode &&
          state.ruleset.partnerControlWhenFinished &&
          player.teamId != null &&
          state.players.any(
            (p) => p.teamId == player.teamId && !p.areAllTokensHome,
          );
      if (!canAssistPartner) return false;
    }
    if (consecutiveSixForfeit) return false;

    if (rolledSix) return true;
    if (madeCapture && state.ruleset.captureGrantsBonusTurn) return true;
    if (tokenReachedHome && state.ruleset.homeEntryGrantsBonusTurn) return true;

    return false;
  }
}
