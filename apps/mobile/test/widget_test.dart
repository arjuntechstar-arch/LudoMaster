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
    'App smoke test: reference lobby loads and navigates to SetupScreen',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: LudoMasterApp(),
        ),
      );

      for (
        var i = 0;
        i < 20 &&
            find.byKey(const Key('mode-computer')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.text('KING'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('TEAM UP'), findsOneWidget);
      expect(find.text('FRIENDS'), findsOneWidget);
      expect(find.text('COMPUTER'), findsOneWidget);
      expect(find.text('PASS N PLAY'), findsOneWidget);
      expect(find.text('TOURNAMENT'), findsOneWidget);
      expect(find.text('CLAIM'), findsOneWidget);

      final computerMode = find.byKey(const Key('mode-computer'));
      expect(computerMode, findsOneWidget);
      await tester.ensureVisible(computerMode);
      await tester.pump();
      await tester.tap(computerMode);
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
