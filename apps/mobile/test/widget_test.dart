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

      // Startup/account bootstrap is asynchronous. Pump bounded frames until
      // the game-mode grid is available instead of relying on network settling.
      for (
        var i = 0;
        i < 20 &&
            find.byKey(const Key('mode-computer')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.text('LUDO MASTER'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('FRIENDS'), findsOneWidget);
      expect(find.text('COMPUTER'), findsOneWidget);
      expect(find.text('PASS N PLAY'), findsOneWidget);
      expect(find.text('TOURNAMENT'), findsOneWidget);
      expect(find.byKey(const Key('mode-computer')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mode-computer')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('VS COMPUTER'), findsOneWidget);
      expect(find.text('START MATCH'), findsOneWidget);
      expect(find.text('4 Players'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
