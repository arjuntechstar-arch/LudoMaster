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
  UserProfileModel? saved;

  @override
  Future<UserProfileModel> updateProfile({required String avatarId}) async {
    return saved = profile(
      name: 'Player',
      username: 'royal_roller',
      avatar: avatarId,
    );
  }
}

void main() {
  testWidgets(
    'shows locked identity fields and saves a free avatar',
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
                    builder: (_) => ProfileEditorScreen(
                      apiClient: api,
                      profile: profile(
                        name: 'Royal Player',
                        username: 'royal_roller',
                      ),
                    ),
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
      expect(find.text('Royal Player'), findsOneWidget);
      expect(find.text('@royal_roller'), findsOneWidget);
      expect(
        find.text('Name and username are set during signup and cannot be changed.'),
        findsOneWidget,
      );
      expect(find.byType(ProfileAvatar), findsNWidgets(9));

      await tester.tap(find.text('Rocket'));
      await tester.tap(find.text('SAVE AVATAR'));
      await tester.pumpAndSettle();

      expect(api.saved, isNotNull);
      expect(api.saved!.avatarId, 'avatar_1');
    },
  );
}
