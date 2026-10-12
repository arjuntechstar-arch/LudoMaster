import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

/// Grid coordinates for the six-player, 72-cell board used by online matches.
class SixPlayerBoardGeometry {
  const SixPlayerBoardGeometry._();

  static const int gridSize = 21;
  static const int trackLength = 72;
  static const List<int> startCells = [0, 12, 24, 36, 48, 60];
  static const List<int> safeCells = [
    0,
    8,
    12,
    20,
    24,
    32,
    36,
    44,
    48,
    56,
    60,
    68,
  ];

  static final List<Point<int>> trackGridPositions = _buildTrack();

  static List<Point<int>> _buildTrack() {
    final points = <Point<int>>[];
    for (var x = 1; x <= 19; x++) {
      points.add(Point(x, 1));
    }
    for (var y = 2; y <= 19; y++) {
      points.add(Point(19, y));
    }
    for (var x = 18; x >= 1; x--) {
      points.add(Point(x, 19));
    }
    for (var y = 18; y >= 2; y--) {
      points.add(Point(1, y));
    }
    return points;
  }

  static const Map<PlayerColor, List<Point<int>>> _homeLanes = {
    PlayerColor.red: [
      Point(6, 6),
      Point(7, 7),
      Point(8, 8),
      Point(9, 9),
      Point(10, 10),
    ],
    PlayerColor.green: [
      Point(13, 3),
      Point(12, 4),
      Point(11, 5),
      Point(10, 6),
      Point(9, 7),
    ],
    PlayerColor.yellow: [
      Point(17, 8),
      Point(16, 8),
      Point(15, 9),
      Point(14, 10),
      Point(13, 11),
    ],
    PlayerColor.blue: [
      Point(15, 15),
      Point(14, 14),
      Point(13, 13),
      Point(12, 12),
      Point(11, 11),
    ],
    PlayerColor.orange: [
      Point(7, 17),
      Point(8, 16),
      Point(9, 15),
      Point(10, 14),
      Point(11, 13),
    ],
    PlayerColor.purple: [
      Point(3, 13),
      Point(4, 12),
      Point(5, 11),
      Point(6, 10),
      Point(7, 9),
    ],
  };

  static const Map<PlayerColor, Point<int>> _yardOrigins = {
    PlayerColor.red: Point(2, 2),
    PlayerColor.green: Point(14, 2),
    PlayerColor.yellow: Point(14, 8),
    PlayerColor.blue: Point(14, 14),
    PlayerColor.orange: Point(2, 14),
    PlayerColor.purple: Point(2, 8),
  };

  static Point<double> trackCenter(int cell) {
    if (cell < 0 || cell >= trackLength) {
      throw ArgumentError('Invalid six-player track cell: $cell');
    }
    final point = trackGridPositions[cell];
    return Point(point.x + 0.5, point.y + 0.5);
  }

  static Point<double> homeLaneCenter(PlayerColor color, int laneStep) {
    if (laneStep < 1 || laneStep > 5) {
      throw ArgumentError('Invalid home lane step: $laneStep');
    }
    final point = _homeLanes[color]![laneStep - 1];
    return Point(point.x + 0.5, point.y + 0.5);
  }

  static Point<double> homeCenter(PlayerColor color) {
    const centers = <PlayerColor, Point<double>>{
      PlayerColor.red: Point(9.2, 9.2),
      PlayerColor.green: Point(10.8, 9.2),
      PlayerColor.yellow: Point(11.8, 9.6),
      PlayerColor.blue: Point(11.8, 10.8),
      PlayerColor.orange: Point(10.2, 11.8),
      PlayerColor.purple: Point(9.0, 10.8),
    };
    return centers[color]!;
  }

  static Point<double> yardCenter(PlayerColor color, int tokenIndex) {
    final origin = _yardOrigins[color]!;
    const offsets = [
      Point(1.5, 1.5),
      Point(3.5, 1.5),
      Point(1.5, 3.5),
      Point(3.5, 3.5),
    ];
    final offset = offsets[tokenIndex % offsets.length];
    return Point(origin.x + offset.x, origin.y + offset.y);
  }

  static Offset tokenPixelPosition({
    required Token token,
    required double boardSize,
    int stackIndex = 0,
    int totalInStack = 1,
  }) {
    final tileSize = boardSize / gridSize;
    final tokenIndex = int.tryParse(token.id.split('_').last) ?? 0;
    final center = switch (token.state) {
      TokenState.yard => yardCenter(token.color, tokenIndex),
      TokenState.track => trackCenter(token.trackCell ?? 0),
      TokenState.homeLane => homeLaneCenter(token.color, token.laneStep),
      TokenState.home => homeCenter(token.color),
    };

    var x = center.x * tileSize;
    var y = center.y * tileSize;
    if (totalInStack > 1 && token.state != TokenState.yard) {
      final spread = tileSize * 0.2;
      final angle = (2 * pi / totalInStack) * stackIndex;
      x += cos(angle) * spread;
      y += sin(angle) * spread;
    }
    return Offset(x, y);
  }
}
