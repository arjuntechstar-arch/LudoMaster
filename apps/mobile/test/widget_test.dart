import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'App smoke test: game lobby loads and navigates to SetupScreen',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: LudoMasterApp(),
        ),
      );

      // The lobby contains a deliberately repeating pulse animation, so
      // pumpAndSettle() can never complete while this screen is mounted.
      // Pump bounded frames until startup/auth bootstrap exposes the mode grid.
      for (
        var i = 0;
        i < 20 &&
            find.byKey(const Key('mode-computer')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // The landing screen is a game lobby, not a standard app-tab dashboard.
      expect(find.text('LUDO MASTER'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('FRIENDS'), findsOneWidget);
      expect(find.text('VS COMPUTER'), findsOneWidget);
      expect(find.text('PASS & PLAY'), findsOneWidget);
      expect(find.byKey(const Key('mode-computer')), findsOneWidget);

      // Navigate into the existing setup flow from the game-style mode button.
      await tester.tap(find.byKey(const Key('mode-computer')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('VS COMPUTER'), findsOneWidget);
      expect(find.text('START MATCH'), findsOneWidget);
      expect(find.text('4 Players'), findsOneWidget);

      // Explicitly unmount the lobby so its repeating animation and timers are
      // disposed before the test completes.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
