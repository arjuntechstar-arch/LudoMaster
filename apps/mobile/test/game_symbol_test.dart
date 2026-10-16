import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/widgets/game_symbol.dart';

void main() {
  testWidgets('core navigation and card icons render without icon fonts', (
    tester,
  ) async {
    const icons = [
      Icons.home_outlined,
      Icons.sports_esports_outlined,
      Icons.auto_awesome_outlined,
      Icons.people_outline,
      Icons.smart_toy_outlined,
      Icons.flash_on_rounded,
      Icons.favorite_outline,
      Icons.card_giftcard_outlined,
      Icons.workspace_premium_outlined,
      Icons.emoji_events_outlined,
      Icons.flag_outlined,
      Icons.leaderboard_outlined,
      Icons.storefront_outlined,
      Icons.monetization_on_outlined,
      Icons.diamond_outlined,
      Icons.shield_outlined,
      Icons.person_rounded,
      Icons.history_rounded,
      Icons.tune_rounded,
      Icons.notifications_none_rounded,
      Icons.chevron_right_rounded,
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [for (final icon in icons) GameSymbol(icon, size: 32)],
          ),
        ),
      ),
    );
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(icons.length));
    expect(find.byType(Icon), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
