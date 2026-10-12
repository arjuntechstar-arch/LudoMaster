import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App smoke test: ModernHomeScreen loads and navigates to SetupScreen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LudoMasterApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the redesigned home shell and bottom navigation are visible.
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Social'), findsOneWidget);

    // Open the dedicated Play tab introduced by the modern home redesign.
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(find.text('How do you want to play?'), findsOneWidget);
    expect(find.text('Vs Computer'), findsOneWidget);
    expect(find.text('Pass & Play'), findsOneWidget);

    // Navigate to the existing setup flow from the redesigned Play tab.
    await tester.tap(find.text('Vs Computer'));
    await tester.pumpAndSettle();

    expect(find.text('VS COMPUTER'), findsOneWidget);
    expect(find.text('START MATCH'), findsOneWidget);
    expect(find.text('4 Players'), findsOneWidget);
  });
}
