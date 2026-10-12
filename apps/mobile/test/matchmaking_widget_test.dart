import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/screens/matchmaking_screen.dart';
import 'package:mobile/src/services/api_client.dart';

void main() {
  testWidgets('MatchmakingScreen renders player counts, mode selector and hex tag', (tester) async {
    final apiClient = ApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: MatchmakingScreen(apiClient: apiClient),
      ),
    );

    expect(find.text('QUICK MATCHMAKING'), findsOneWidget);
    expect(find.text('SELECT PLAYERS'), findsOneWidget);
    expect(find.text('2 Players'), findsOneWidget);
    expect(find.text('4 Players'), findsOneWidget);
    expect(find.text('6 Players'), findsOneWidget);
    expect(find.text('HEXAGON'), findsOneWidget);
    expect(find.text('CLASSIC (4 Tokens)'), findsOneWidget);
    expect(find.text('QUICK (2 Tokens)'), findsOneWidget);

    // Initial button text for 4 players
    expect(find.text('FIND 4-PLAYER MATCH'), findsOneWidget);

    // Tap 6 players
    await tester.tap(find.text('6 Players'));
    await tester.pumpAndSettle();

    // Button updates to 6 players
    expect(find.text('FIND 6-PLAYER MATCH'), findsOneWidget);

    // Tap 2 players
    await tester.tap(find.text('2 Players'));
    await tester.pumpAndSettle();

    expect(find.text('FIND 2-PLAYER MATCH'), findsOneWidget);
  });
}
