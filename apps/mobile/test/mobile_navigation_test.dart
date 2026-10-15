import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/screens/mobile_home_screen.dart';
import 'package:mobile/src/screens/settings_screen.dart';
import 'package:mobile/src/theme/app_theme.dart';
import 'package:mobile/src/widgets/mobile_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1366, 768),
  ]) {
    testWidgets('mobile navigation and settings stay usable at $size', (
      tester,
    ) async {
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
            builder: (context, child) => MobileAppFrame(child: child!),
            home: const MobileHomeScreen(),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(
        tester.getSize(find.byType(MobileHomeScreen)).width,
        lessThanOrEqualTo(640),
      );
      for (final tab in ['Play', 'Rewards', 'Social', 'Home']) {
        expect(find.text(tab).hitTestable(), findsOneWidget);
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Social'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Settings'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Larger text'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Larger text'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ludomaster_setting_large_text'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
