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

        // First tap
        await tester.tap(find.byType(DiceWidget));
        expect(rollCount, equals(1));

        // Immediate second tap while animation is running (300ms)
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byType(DiceWidget));
        expect(rollCount, equals(2));

        // Settle animation
        await tester.pumpAndSettle();
        expect(rollCount, equals(2));
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
