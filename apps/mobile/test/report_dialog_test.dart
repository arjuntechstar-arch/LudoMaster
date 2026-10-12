import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/services/api_client.dart';
import 'package:mobile/src/widgets/report_user_dialog.dart';

class MockReportApiClient extends ApiClient {
  String? lastReportedId;
  String? lastCategory;
  String? lastDescription;

  @override
  Future<void> submitReport({
    required String reportedUserId,
    required String category,
    String? description,
    String? matchId,
  }) async {
    lastReportedId = reportedUserId;
    lastCategory = category;
    lastDescription = description;
  }
}

void main() {
  testWidgets('ReportUserDialog allows selecting violation category and submitting report', (tester) async {
    final mockClient = MockReportApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ReportUserDialog.show(
                  context,
                  apiClient: mockClient,
                  reportedUserId: 'target_user_123',
                  reportedDisplayName: 'RudePlayer',
                );
              },
              child: const Text('Open Report'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open Report'));
    await tester.pumpAndSettle();

    expect(find.text('Report RudePlayer'), findsOneWidget);
    expect(find.text('Select violation category:'), findsOneWidget);
    expect(find.text('Verbal Abuse / Harassment'), findsOneWidget);
    expect(find.text('Suspected Cheating / Exploit'), findsOneWidget);
    expect(find.text('Chat Spamming'), findsOneWidget);

    // Select "Suspected Cheating / Exploit"
    await tester.tap(find.text('Suspected Cheating / Exploit'));
    await tester.pumpAndSettle();

    // Enter optional description
    await tester.enterText(find.byType(TextField), 'Player manipulated rolls somehow');
    await tester.pumpAndSettle();

    // Submit report
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(mockClient.lastReportedId, 'target_user_123');
    expect(mockClient.lastCategory, 'CHEATING');
    expect(mockClient.lastDescription, 'Player manipulated rolls somehow');

    // Dialog should be dismissed
    expect(find.text('Report Player'), findsNothing);
  });
}
