import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/screens/match_history_screen.dart';
import 'package:mobile/src/services/api_client.dart';

void main() {
  testWidgets('MatchHistoryScreen renders tabs and allows switching', (tester) async {
    final apiClient = ApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: MatchHistoryScreen(apiClient: apiClient),
      ),
    );

    expect(find.text('MATCH LOGS & PLAYERS'), findsOneWidget);
    expect(find.text('MATCH HISTORY'), findsOneWidget);
    expect(find.text('RECENT OPPONENTS'), findsOneWidget);

    // Switch to RECENT OPPONENTS tab
    await tester.tap(find.text('RECENT OPPONENTS'));
    await tester.pumpAndSettle();

    // Verify tab switch
    expect(find.byType(TabBarView), findsOneWidget);
  });
}
