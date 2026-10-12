import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/services/api_client.dart';
import 'package:mobile/src/widgets/app_loader.dart';
import 'package:mobile/src/widgets/google_account_buttons.dart';
import 'package:mobile/src/widgets/watch_ad_reward_dialog.dart';

class AccountPreviewApi extends ApiClient {
  @override
  Future<Map<String, dynamic>> getAuthProviders() async => {
    'google_enabled': false,
    'play_games_enabled': false,
  };

  @override
  Future<Map<String, dynamic>> getAdRewardStatus() async => {
    'can_watch': false,
    'remaining_today': 0,
    'message': "All of today's ad rewards have been claimed",
  };
}

void main() {
  testWidgets('Loader shows Ludo Play branding and progress', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLoader())),
    );
    expect(find.text('Ludo Play'), findsOneWidget);
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Account buttons are disabled until providers are configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleAccountButtons(
            apiClient: AccountPreviewApi(),
            onSignedIn: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Connect Google Play Games'), findsOneWidget);
    for (final button in tester.widgetList<OutlinedButton>(
      find.byType(OutlinedButton),
    )) {
      expect(button.onPressed, isNull);
    }
  });

  testWidgets('Exhausted ad rewards show the buy-coins option', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WatchAdRewardDialog(
            apiClient: AccountPreviewApi(),
            onRewardClaimed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Get more coins'), findsOneWidget);
    expect(find.text('BUY COINS'), findsOneWidget);
    expect(find.textContaining("All of today's ad rewards"), findsOneWidget);
  });
}
