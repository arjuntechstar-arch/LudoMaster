import 'package:game_engine/game_engine.dart';
import 'package:test/test.dart';

void main() {
  group('BoardMetrics', () {
    test('standard track length and step constants', () {
      expect(BoardMetrics.trackLength, equals(52));
      expect(BoardMetrics.trackStepsBeforeHomeLane, equals(51));
      expect(BoardMetrics.homeLaneSteps, equals(5));
      expect(BoardMetrics.totalStepsToFinish, equals(56));
    });

    test('player color start cell and home entrance mapping', () {
      expect(PlayerColor.red.startTrackCell, equals(0));
      expect(PlayerColor.red.homeEntranceTrackCell, equals(50));

      expect(PlayerColor.green.startTrackCell, equals(13));
      expect(PlayerColor.green.homeEntranceTrackCell, equals(11));

      expect(PlayerColor.yellow.startTrackCell, equals(26));
      expect(PlayerColor.yellow.homeEntranceTrackCell, equals(24));

      expect(PlayerColor.blue.startTrackCell, equals(39));
      expect(PlayerColor.blue.homeEntranceTrackCell, equals(37));
    });

    test('track cell calculations for Red across 51 steps', () {
      expect(BoardMetrics.getTrackCell(PlayerColor.red, 0), equals(0));
      expect(BoardMetrics.getTrackCell(PlayerColor.red, 25), equals(25));
      expect(BoardMetrics.getTrackCell(PlayerColor.red, 50), equals(50));
    });

    test('track cell calculations for Green across 51 steps', () {
      expect(BoardMetrics.getTrackCell(PlayerColor.green, 0), equals(13));
      expect(BoardMetrics.getTrackCell(PlayerColor.green, 38), equals(51));
      expect(BoardMetrics.getTrackCell(PlayerColor.green, 39), equals(0));
      expect(BoardMetrics.getTrackCell(PlayerColor.green, 50), equals(11));
    });

    test('track cell bounds checks', () {
      expect(() => BoardMetrics.getTrackCell(PlayerColor.red, -1), throwsArgumentError);
      expect(() => BoardMetrics.getTrackCell(PlayerColor.red, 51), throwsArgumentError);
    });

    test('safe cells identification', () {
      final safe = [0, 8, 13, 21, 26, 34, 39, 47];
      for (final cell in safe) {
        expect(BoardMetrics.isSafeCell(cell), isTrue, reason: 'Cell $cell should be safe');
      }
      expect(BoardMetrics.isSafeCell(1), isFalse);
      expect(BoardMetrics.isSafeCell(51), isFalse);
      expect(BoardMetrics.isSafeCell(25), isFalse);
    });
  });
}
