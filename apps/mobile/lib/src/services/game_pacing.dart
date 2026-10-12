/// Shared presentation timing; rules and dice fairness stay in the engine.
class GamePacing {
  static const turnDurationSeconds = 15;
  static const diceColorHold = Duration(milliseconds: 500);
  static const diceRoll = Duration(milliseconds: 1500);
  static const tokenMove = Duration(milliseconds: 1000);
  static const autoMovePause = Duration(milliseconds: 800);
  static const botPause = Duration(milliseconds: 700);

  /// Scale movement time with the number of squares while keeping short moves
  /// responsive and long moves easy to follow.
  static Duration tokenMoveForSteps(int steps) {
    final visibleSteps = steps < 1 ? 1 : (steps > 6 ? 6 : steps);
    return Duration(milliseconds: 320 + visibleSteps * 110);
  }
}
