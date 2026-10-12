import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:mobile/src/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GameController Tests', () {
    test('startNewGame initializes game session', () {
      final controller = GameController();
      final red = const PlayerState(
        id: 'human_red',
        name: 'You',
        seat: 0,
        color: PlayerColor.red,
        tokens: [],
      );
      final green = const PlayerState(
        id: 'bot_green',
        name: 'Bot Green',
        seat: 1,
        color: PlayerColor.green,
        isBot: true,
        tokens: [],
      );

      controller.startNewGame(players: [red, green]);

      expect(controller.state, isNotNull);
      expect(controller.state!.gameState.status, equals(GameStatus.inProgress));
      expect(controller.state!.gameState.currentSeat, equals(0));
      expect(controller.state!.gameState.phase, equals(GamePhase.rollRequired));

      controller.dispose();
    });

    test('quitMatch clears controller state', () {
      final controller = GameController();
      final red = const PlayerState(
        id: 'human_red',
        name: 'You',
        seat: 0,
        color: PlayerColor.red,
        tokens: [],
      );
      final green = const PlayerState(
        id: 'bot_green',
        name: 'Bot Green',
        seat: 1,
        color: PlayerColor.green,
        isBot: true,
        tokens: [],
      );

      controller.startNewGame(players: [red, green]);
      expect(controller.state, isNotNull);

      controller.quitMatch();
      expect(controller.state, isNull);

      controller.dispose();
    });
  });
}
