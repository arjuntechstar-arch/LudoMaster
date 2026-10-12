import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:mobile/src/board/board_coordinate_mapper.dart';

void main() {
  group('BoardCoordinateMapper Tests', () {
    test('trackGridPositions length equals 52', () {
      expect(BoardCoordinateMapper.trackGridPositions.length, equals(52));
    });

    test('validates safe cells match BoardMetrics safe cells', () {
      // 0, 8, 13, 21, 26, 34, 39, 47
      final redStart = BoardCoordinateMapper.trackGridPositions[0];
      expect(redStart.x, equals(1));
      expect(redStart.y, equals(6));

      final greenStart = BoardCoordinateMapper.trackGridPositions[13];
      expect(greenStart.x, equals(8));
      expect(greenStart.y, equals(1));

      final yellowStart = BoardCoordinateMapper.trackGridPositions[26];
      expect(yellowStart.x, equals(13));
      expect(yellowStart.y, equals(8));

      final blueStart = BoardCoordinateMapper.trackGridPositions[39];
      expect(blueStart.x, equals(6));
      expect(blueStart.y, equals(13));
    });

    test('yard pedestals are within valid yard quadrants', () {
      for (final color in PlayerColor.values) {
        for (var i = 0; i < 4; i++) {
          final pt = BoardCoordinateMapper.getYardPedestalCoordinate(color, i);
          expect(pt.x, greaterThanOrEqualTo(0.0));
          expect(pt.x, lessThanOrEqualTo(15.0));
          expect(pt.y, greaterThanOrEqualTo(0.0));
          expect(pt.y, lessThanOrEqualTo(15.0));
        }
      }
    });

    test('home lane coordinates span steps 1 to 5', () {
      for (final color in PlayerColor.values) {
        for (var step = 1; step <= 5; step++) {
          final pt = BoardCoordinateMapper.getHomeLaneTileCoordinate(color, step);
          expect(pt.x, greaterThan(0.0));
          expect(pt.x, lessThan(15.0));
          expect(pt.y, greaterThan(0.0));
          expect(pt.y, lessThan(15.0));
        }
      }
    });

    test('pixel position calculates correctly for track token', () {
      const token = Token(
        id: 'red_0',
        color: PlayerColor.red,
        state: TokenState.track,
        stepCount: 0,
        trackCell: 0,
      );

      final offset = BoardCoordinateMapper.getTokenPixelPosition(
        token: token,
        boardSize: 300,
        stackIndex: 0,
        totalInStack: 1,
      );

      // Board tile size = 300 / 15 = 20
      // Cell 0 is at (col: 1.5, row: 6.5) -> x: 30, y: 130
      expect(offset.dx, closeTo(30.0, 0.1));
      expect(offset.dy, closeTo(130.0, 0.1));
    });
  });
}
