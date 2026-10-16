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
    'Mobile lobby keeps navigation accessible and opens offline setup',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: LudoMasterApp()));

      for (
        var i = 0;
        i < 20 && find.byKey(const Key('mode-computer')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.text('Ready to roll?'), findsOneWidget);
      expect(find.text('Play online'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Social').hitTestable(), findsOneWidget);

      final computerMode = find.byKey(const Key('mode-computer'));
      await tester.scrollUntilVisible(
        computerMode,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('Vs Computer'), findsOneWidget);
      expect(find.text('Pass & Play'), findsOneWidget);
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
