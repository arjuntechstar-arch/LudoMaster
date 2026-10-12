import 'package:game_engine/game_engine.dart';

class BoardPerspective {
  static int quarterTurnsFor(PlayerColor color) => switch (color) {
    PlayerColor.red => 3,
    PlayerColor.green => 2,
    PlayerColor.yellow => 1,
    _ => 0,
  };

  static int position(PlayerColor color, PlayerColor viewer) {
    if (color.index >= 4 || viewer.index >= 4) {
      return (color.index - viewer.index + PlayerColor.values.length) %
          PlayerColor.values.length;
    }
    return (color.index + quarterTurnsFor(viewer)) % 4;
  }
}
