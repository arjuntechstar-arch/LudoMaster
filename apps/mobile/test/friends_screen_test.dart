import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/screens/friends_screen.dart';
import 'package:mobile/src/services/api_client.dart';

class MockApiClient extends ApiClient {
  @override
  Future<List<FriendModel>> getFriends() async => [];

  @override
  Future<Map<String, List<FriendRequestModel>>> getFriendRequests() async => {
    'incoming': [],
    'outgoing': [],
  };

  @override
  Future<List<BlockedUserModel>> getBlockedUsers() async => [];

  @override
  Future<List<RoomInviteModel>> getMyRoomInvites() async => [];

  @override
  Future<void> sendFriendRequest({
    String? targetUserId,
    String? playerId,
    String? username,
  }) async {}
}

void main() {
  testWidgets('FriendsScreen renders tabs, empty state and add friend dialog', (
    tester,
  ) async {
    final mockClient = MockApiClient();

    await tester.pumpWidget(
      MaterialApp(home: FriendsScreen(apiClient: mockClient)),
    );

    // Initial loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // Verify TabBar
    expect(find.text('FRIENDS & SOCIAL'), findsOneWidget);
    expect(find.text('FRIENDS (0)'), findsOneWidget);
    expect(find.text('REQUESTS (0)'), findsOneWidget);
    expect(find.text('BLOCKED (0)'), findsOneWidget);
    expect(find.text('INVITES (0)'), findsOneWidget);

    // Empty friends state
    expect(find.text('No friends added yet'), findsOneWidget);
    expect(find.text('Add a Friend'), findsOneWidget);

    // Switch to Requests tab
    await tester.tap(find.text('REQUESTS (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No pending requests'), findsOneWidget);

    // Switch to Blocked tab
    await tester.tap(find.text('BLOCKED (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No blocked players'), findsOneWidget);

    // Tap Add Friend icon
    await tester.tap(find.byTooltip('Add Friend'));
    await tester.pumpAndSettle();

    expect(find.text('Add Friend by Username'), findsOneWidget);
    expect(find.text('Send Request'), findsOneWidget);

    // Enter player ID
    await tester.enterText(find.byType(TextField), 'LM-XYZ99');
    await tester.tap(find.text('Send Request'));
    await tester.pumpAndSettle();

    expect(find.text('Add Friend by Player ID'), findsNothing);
  });
}
