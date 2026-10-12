import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/screens/clubs_screen.dart';
import 'package:mobile/src/services/api_client.dart';
import 'package:mobile/src/widgets/voice_chat_controller_widget.dart';

void main() {
  group('Clubs & Voice Chat Tests', () {
    test('Club and Voice data model JSON parsing', () {
      final clubJson = {
        'id': 'club-123',
        'name': 'Golden Rollers',
        'tag': 'GOLD',
        'description': 'Elite players',
        'badge_icon': 'shield_gold',
        'leader_user_id': 'u1',
        'min_level': 2,
        'is_open': true,
        'member_count': 5,
        'max_members': 30,
        'created_at': '2026-10-02T12:00:00Z',
      };

      final club = ClubModel.fromJson(clubJson);
      expect(club.id, 'club-123');
      expect(club.name, 'Golden Rollers');
      expect(club.tag, 'GOLD');
      expect(club.minLevel, 2);
      expect(club.isOpen, true);
      expect(club.memberCount, 5);

      final memberJson = {
        'id': 'mem-1',
        'user_id': 'u1',
        'role': 'LEADER',
        'joined_at': '2026-10-02T12:00:00Z',
        'display_name': 'AceRoller',
        'avatar_id': 'avatar_1',
        'level': 5,
      };

      final member = ClubMemberModel.fromJson(memberJson);
      expect(member.id, 'mem-1');
      expect(member.role, 'LEADER');
      expect(member.displayName, 'AceRoller');
      expect(member.level, 5);

      final detailJson = {
        ...clubJson,
        'members': [memberJson],
      };

      final detail = ClubDetailModel.fromJson(detailJson);
      expect(detail.id, 'club-123');
      expect(detail.members.length, 1);
      expect(detail.members.first.displayName, 'AceRoller');

      final voiceTokenJson = {
        'room_id': 'room-xyz',
        'user_id': 'u1',
        'voice_session_id': 'session-456',
        'token': 'vt_token_secret',
        'mic_enabled': true,
      };

      final voice = VoiceTokenModel.fromJson(voiceTokenJson);
      expect(voice.roomId, 'room-xyz');
      expect(voice.voiceSessionId, 'session-456');
      expect(voice.token, 'vt_token_secret');
      expect(voice.micEnabled, true);
    });

    testWidgets('ClubsScreen renders appbar tabs and empty state', (tester) async {
      final apiClient = ApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: ClubsScreen(apiClient: apiClient),
        ),
      );

      // Verify app bar title
      expect(find.text('Clubs & Social Rooms'), findsOneWidget);
      expect(find.text('My Club'), findsOneWidget);
      expect(find.text('Explore Clubs'), findsOneWidget);

      await tester.pumpAndSettle();

      // Verify empty state or create club action
      expect(find.text('Create Club'), findsWidgets);
    });

    testWidgets('VoiceChatControllerWidget renders join voice and safety dialog', (tester) async {
      final apiClient = ApiClient();
      final members = [
        RoomMemberModel(
          id: 'rm-1',
          userId: 'u1',
          seatIndex: 0,
          isReady: true,
          isHost: true,
          displayName: 'Player One',
          avatarId: 'avatar_0',
          level: 3,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceChatControllerWidget(
              apiClient: apiClient,
              roomId: 'room-test-123',
              roomMembers: members,
            ),
          ),
        ),
      );

      expect(find.text('Join Voice'), findsOneWidget);
      expect(find.byIcon(Icons.headset_off), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      // Tap Join Voice -> shows Privacy Consent Dialog
      await tester.tap(find.text('Join Voice'));
      await tester.pumpAndSettle();

      expect(find.text('Voice Chat & Privacy'), findsOneWidget);
      expect(find.text('Agree & Connect'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      // Decline closes dialog
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      expect(find.text('Voice Chat & Privacy'), findsNothing);

      // Tap safety shield -> opens safety sheet
      await tester.tap(find.byIcon(Icons.shield_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Voice Safety & Moderation'), findsOneWidget);
      expect(find.text('Player One'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);
      expect(find.byIcon(Icons.report), findsOneWidget);
    });
  });
}
