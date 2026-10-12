import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:mobile/src/controllers/game_controller.dart';
import 'package:mobile/src/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final sizes = <Size>[
    const Size(360, 640),
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(768, 1024),
    const Size(1366, 768),
  ];

  for (final size in sizes) {
    testWidgets('game screen renders without overflow at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = GameController();
      controller.startNewGame(
        players: const [
          PlayerState(
            id: 'human_red',
            name: 'You',
            seat: 0,
            color: PlayerColor.red,
            tokens: [],
          ),
          PlayerState(
            id: 'bot_green',
            name: 'Bot Green',
            seat: 1,
            color: PlayerColor.green,
            isBot: true,
            tokens: [],
          ),
          PlayerState(
            id: 'bot_yellow',
            name: 'Bot Yellow',
            seat: 2,
            color: PlayerColor.yellow,
            isBot: true,
            tokens: [],
          ),
          PlayerState(
            id: 'bot_blue',
            name: 'Bot Blue',
            seat: 3,
            color: PlayerColor.blue,
            isBot: true,
            tokens: [],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: GameScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(GameScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      controller.dispose();
    });
  }
}
