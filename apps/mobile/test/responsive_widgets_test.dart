import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/src/theme/app_theme.dart';
import 'package:mobile/src/services/api_client.dart';
import 'package:mobile/src/screens/setup_screen.dart';
import 'package:mobile/src/screens/clubs_screen.dart';
import 'package:mobile/src/screens/match_history_screen.dart';
import 'package:mobile/src/screens/mobile_home_screen.dart';
import 'package:mobile/src/screens/settings_screen.dart';
import 'package:mobile/src/screens/matchmaking_screen.dart';
import 'package:mobile/src/screens/online_room_screen.dart';
import 'package:mobile/src/screens/friends_screen.dart';
import 'package:mobile/src/screens/store_inventory_screen.dart';
import 'package:mobile/src/screens/missions_screen.dart';
import 'package:mobile/src/screens/achievements_screen.dart';
import 'package:mobile/src/screens/leaderboard_screen.dart';
import 'package:mobile/src/screens/season_screen.dart';
import 'package:mobile/src/screens/tournament_screen.dart';
import 'package:mobile/src/screens/daily_rewards_dialog.dart';
import 'package:mobile/src/screens/notifications_dialog.dart';
import 'package:mobile/src/screens/profile_editor_screen.dart';
import 'package:mobile/src/screens/privacy_policy_screen.dart';
import 'package:mobile/src/widgets/auth_dialog.dart';
import 'package:mobile/src/widgets/report_user_dialog.dart';
import 'package:mobile/src/widgets/play_with_friends_dialog.dart';
import 'package:mobile/src/widgets/watch_ad_reward_dialog.dart';
import 'package:mobile/src/widgets/google_account_buttons.dart';
import 'package:mobile/src/widgets/app_loader.dart';
import 'package:mobile/src/widgets/voice_chat_controller_widget.dart';

import 'branding_accounts_test.dart' show AccountPreviewApi;
import 'economy_progression_widget_test.dart' show MockEconomyApiClient;
import 'tournaments_seasons_widget_test.dart'
    show MockTournamentsSeasonsApiClient;
import 'friends_screen_test.dart' show MockApiClient;
import 'purchases_notifications_test.dart'
    show MockPurchasesNotificationsApiClient;
import 'profile_editor_test.dart' show ProfileApi, profile;

class ResponsiveSocialApi extends ApiClient {
  @override
  Future<ClubDetailModel?> getMyClub() async => null;
  @override
  Future<List<ClubModel>> getClubs({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async => [];
  @override
  Future<List<MatchHistoryModel>> getMyMatchHistory({int limit = 20}) async =>
      [];
  @override
  Future<List<RecentPlayerModel>> getRecentPlayers({int limit = 20}) async =>
      [];
}

void main() {
  final widgets = <String, Widget Function()>{
    'home': () => const MobileHomeScreen(),
    'settings': () => const SettingsScreen(),
    'clubs': () => ClubsScreen(apiClient: ResponsiveSocialApi()),
    'history': () => MatchHistoryScreen(apiClient: ResponsiveSocialApi()),
    'setup': () => const SetupScreen(isVsComputer: true),
    'local setup': () => const SetupScreen(isVsComputer: false),
    'matchmaking': () => MatchmakingScreen(apiClient: ApiClient()),
    'rooms': () => OnlineRoomScreen(apiClient: ApiClient()),
    'friends': () => FriendsScreen(apiClient: MockApiClient()),
    'store': () => StoreInventoryScreen(
      apiClient: MockEconomyApiClient(),
      onInventoryChanged: () {},
    ),
    'missions': () => MissionsScreen(apiClient: MockEconomyApiClient()),
    'achievements': () => AchievementsScreen(apiClient: MockEconomyApiClient()),
    'leaderboard': () =>
        LeaderboardScreen(apiClient: MockTournamentsSeasonsApiClient()),
    'season': () => SeasonScreen(apiClient: MockTournamentsSeasonsApiClient()),
    'tournament': () =>
        TournamentScreen(apiClient: MockTournamentsSeasonsApiClient()),
    'daily rewards': () =>
        DailyRewardsDialog(apiClient: MockEconomyApiClient()),
    'notifications': () => NotificationsDialog(
      apiClient: MockPurchasesNotificationsApiClient(),
      onRefreshHome: () {},
    ),
    'profile': () => ProfileEditorScreen(
      apiClient: ProfileApi(),
      profile: profile(
        name: 'A long player display name',
        username: 'a_long_player_username',
      ),
    ),
    'privacy': () => const PrivacyPolicyScreen(),
    'auth': () =>
        AuthDialog(apiClient: AccountPreviewApi(), onAuthenticated: () {}),
    'report': () => ReportUserDialog(
      apiClient: ApiClient(),
      reportedUserId: 'test',
      reportedDisplayName: 'A long player display name',
    ),
    'friends dialog': () => PlayWithFriendsDialog(
      apiClient: ApiClient(),
      myUsername: 'a_long_player_username',
      onRefresh: () {},
    ),
    'ad rewards': () => WatchAdRewardDialog(
      apiClient: AccountPreviewApi(),
      onRewardClaimed: () {},
    ),
    'google buttons': () => GoogleAccountButtons(
      apiClient: AccountPreviewApi(),
      onSignedIn: (_) {},
    ),
    'loader': () => const AppLoader(),
    'voice': () => VoiceChatControllerWidget(
      apiClient: ApiClient(),
      roomId: 'test',
      roomMembers: const [],
    ),
  };
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1366, 768),
  ]) {
    for (final entry in widgets.entries) {
      testWidgets('${entry.key} fits $size with large text', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: Scaffold(body: entry.value()),
            ),
          ),
        );
        // Some widgets animate continuously; do not wait for all animations.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(tester.takeException(), isNull);
        if (entry.key == 'home') {
          final mode = find.byKey(const Key('mode-computer'));
          await tester.scrollUntilVisible(
            mode,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();
          expect(mode, findsOneWidget);
          expect(tester.getRect(mode).height, greaterThanOrEqualTo(44));
          await tester.ensureVisible(mode);
          await tester.pump();
          expect(mode.hitTestable(), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
  for (final name in ['auth', 'report', 'friends dialog']) {
    testWidgets('$name remains usable with keyboard open', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: const EdgeInsets.only(bottom: 280),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: Scaffold(body: widgets[name]!()),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
