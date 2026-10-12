import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/screens/profile_editor_screen.dart';
import 'package:mobile/src/services/api_client.dart';
import 'package:mobile/src/widgets/profile_avatar.dart';

UserProfileModel profile({
  String name = 'Player',
  String? username,
  String avatar = 'avatar_0',
}) => UserProfileModel(
  userId: 'internal-user',
  playerId: 'INTERNAL-ID',
  displayName: name,
  username: username,
  avatarId: avatar,
  level: 1,
  xp: 0,
  countryCode: 'IND',
  isGuest: false,
  isVerified: false,
);

class ProfileApi extends ApiClient {
  String? checkedUsername;
  UserProfileModel? saved;
  @override
  Future<Map<String, dynamic>> checkUsernameAvailability(
    String username,
  ) async {
    checkedUsername = username;
    return {
      'available': username != 'occupied',
      'reason': 'This username is already taken.',
    };
  }

  @override
  Future<UserProfileModel> updateProfile({
    required String displayName,
    String? username,
    required String avatarId,
  }) async {
    return saved = profile(
      name: displayName,
      username: username,
      avatar: avatarId,
    );
  }
}

void main() {
  testWidgets(
    'checks username availability, selects a free avatar and hides internal IDs',
    (tester) async {
      tester.view.physicalSize = const Size(520, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final api = ProfileApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ProfileEditorScreen(apiClient: api, profile: profile()),
                  ),
                ),
                child: const Text('EDIT'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();
      expect(find.text('INTERNAL-ID'), findsNothing);
      expect(find.text('internal-user'), findsNothing);
      expect(find.byType(ProfileAvatar), findsNWidgets(9));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'occupied');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('This username is already taken.'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'SAVE PROFILE'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(fields.at(1), 'Royal_Roller');
      await tester.enterText(fields.at(0), '  Royal Player  ');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(api.checkedUsername, 'royal_roller');
      expect(find.text('Username available'), findsOneWidget);
      await tester.tap(find.text('Rocket'));
      await tester.tap(find.text('SAVE PROFILE'));
      await tester.pumpAndSettle();
      expect(api.saved!.avatarId, 'avatar_1');
      expect(api.saved!.displayName, 'Royal Player');
      expect(api.saved!.username, 'royal_roller');
    },
  );
}
