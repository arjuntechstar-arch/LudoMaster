import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/controllers/game_controller.dart';
import 'package:mobile/src/screens/setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('SetupScreen allows selecting Quick Mode and Team 2v2', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SetupScreen(isVsComputer: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PASS & PLAY'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Quick'), findsOneWidget);
    expect(find.text('2v2 Team'), findsOneWidget);
    expect(find.text('NUMBER OF PLAYERS'), findsOneWidget);

    await tester.tap(find.text('Quick'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Must capture an opponent before entering home lane'),
      findsOneWidget,
    );

    await tester.tap(find.text('2v2 Team'));
    await tester.pumpAndSettle();
    expect(find.text('NUMBER OF PLAYERS'), findsNothing);
    expect(
      find.textContaining(
        '2v2 Team Mode: Team 1 (Red & Yellow) vs Team 2 (Green & Blue)',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'SetupScreen launches game with team mode ruleset and assignments',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SetupScreen(isVsComputer: true)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('2v2 Team'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('START MATCH'));
      // Do not pumpAndSettle here: a live game intentionally schedules turn and
      // bot timers. One frame is enough for navigation/state publication.
      await tester.pump();

      final controllerState = container.read(gameControllerProvider);
      expect(controllerState, isNotNull);
      final gameState = controllerState!.gameState;
      expect(gameState.ruleset.isTeamMode, isTrue);
      expect(gameState.players.length, 4);
      expect(gameState.players[0].teamId, 0); // Red
      expect(gameState.players[1].teamId, 1); // Green
      expect(gameState.players[2].teamId, 0); // Yellow
      expect(gameState.players[3].teamId, 1); // Blue

      // A started match owns periodic/action timers; cancel them explicitly
      // before the widget test verifies that no fake timers remain pending.
      container.read(gameControllerProvider.notifier).quitMatch();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
