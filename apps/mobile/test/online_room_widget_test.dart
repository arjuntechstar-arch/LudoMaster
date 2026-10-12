import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/screens/online_room_screen.dart';
import 'package:mobile/src/services/api_client.dart';

void main() {
  testWidgets('OnlineRoomScreen renders lobby selection with Create and Join buttons', (tester) async {
    final apiClient = ApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: OnlineRoomScreen(apiClient: apiClient),
      ),
    );

    expect(find.text('Online Room'), findsOneWidget);
    expect(find.text('Play With Friends'), findsOneWidget);
    expect(find.text('CREATE ROOM'), findsOneWidget);
    expect(find.text('JOIN WITH CODE'), findsOneWidget);

    // Tap Join With Code -> dialog appears
    await tester.tap(find.text('JOIN WITH CODE'));
    await tester.pumpAndSettle();

    expect(find.text('Enter Room Code'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Enter Room Code'), findsNothing);
  });
}
