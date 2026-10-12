import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:mobile/src/board/dice_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DiceWidget Interaction Tests', () {
    testWidgets(
      'forwards allowed taps while waiting for the authoritative roll',
      (tester) async {
        int rollCount = 0;
        bool canRoll = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return DiceWidget(
                    diceValue: 6,
                    canRoll: canRoll,
                    playerColor: PlayerColor.red,
                    onRoll: () {
                      rollCount++;
                    },
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DiceWidget));
        expect(rollCount, equals(1));

        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byType(DiceWidget));
        expect(rollCount, equals(2));

        // DiceWidget intentionally runs a repeating idle animation while it can
        // be rolled, so pumpAndSettle would never terminate. Advance a bounded
        // amount of fake time and verify no extra roll is emitted.
        await tester.pump(const Duration(seconds: 1));
        expect(rollCount, equals(2));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('triggers onDisabledTap when canRoll is false', (tester) async {
      bool disabledTapTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiceWidget(
              diceValue: 6,
              canRoll: false,
              playerColor: PlayerColor.red,
              onRoll: () {},
              onDisabledTap: () {
                disabledTapTriggered = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DiceWidget));
      expect(disabledTapTriggered, isTrue);
    });
  });
}
