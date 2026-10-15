import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/services/api_client.dart';
import 'package:mobile/src/widgets/play_with_friends_dialog.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(390, 844)]) {
    testWidgets('friends room options fit at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayWithFriendsDialog(
              apiClient: ApiClient(),
              myUsername: '',
              onRefresh: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Classic Ludo'));
      await tester.tap(find.text('Classic Ludo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick (2 Tokens)').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
