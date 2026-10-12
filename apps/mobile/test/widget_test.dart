import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App smoke test: HomeScreen loads and navigates to SetupScreen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LudoMasterApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Mode cards exist
    expect(find.text('LUDO PLAY'), findsOneWidget);
    expect(find.text('Play vs Computer'), findsOneWidget);
    expect(find.text('Pass & Play', skipOffstage: false), findsOneWidget);

    // Tap 'Play vs Computer'
    await tester.tap(find.text('Play vs Computer'));
    await tester.pumpAndSettle();

    // Verify navigated to SetupScreen
    expect(find.text('VS COMPUTER'), findsOneWidget);
    expect(find.text('START MATCH'), findsOneWidget);
    expect(find.text('4 Players'), findsOneWidget);
  });
}
