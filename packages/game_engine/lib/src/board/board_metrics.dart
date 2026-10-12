import '../models/player_color.dart';

/// Board geometry and standard indexing constants for Ludo.
class BoardMetrics {
  const BoardMetrics._();

  /// Total number of tiles along the outer circular track.
  static const int trackLength = 52;

  /// Max steps on the main track before turning into the home lane.
  /// Step 0 is the color's starting cell; step 50 is the last cell on the common track.
  static const int trackStepsBeforeHomeLane = 51; // steps 0 through 50

  /// Steps in each player's colored home lane (steps 1 through 5).
  static const int homeLaneSteps = 5;

  /// Exact step count to reach HOME from the yard entrance (step 6 in home lane).
  static const int totalStepsToFinish = 56; // 0..50 (51 steps) + 5 in lane = 56 steps moved to reach Home

  /// Standard 8 safe cells on a 4-player board.
  static const List<int> standardSafeCells = [0, 8, 13, 21, 26, 34, 39, 47];

  /// Calculates the absolute track cell (0..51) for a given player and track step count (0..50).
  static int getTrackCell(PlayerColor color, int stepCount) {
    if (stepCount < 0 || stepCount >= trackStepsBeforeHomeLane) {
      throw ArgumentError(
        'Step count $stepCount is out of track bounds (0..${trackStepsBeforeHomeLane - 1})',
      );
    }
    return (color.startTrackCell + stepCount) % trackLength;
  }

  /// Checks if a cell is one of the standard safe cells.
  static bool isSafeCell(int cell) => standardSafeCells.contains(cell);
}
