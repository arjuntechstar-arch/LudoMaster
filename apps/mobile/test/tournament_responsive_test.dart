import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/screens/tournament_screen.dart';

import 'tournaments_seasons_widget_test.dart' show MockTournamentsSeasonsApiClient;

void main() {
  testWidgets('narrow tournament brackets wrap board titles and advancement tags', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      home: TournamentScreen(apiClient: MockTournamentsSeasonsApiClient()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Championship Board'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
