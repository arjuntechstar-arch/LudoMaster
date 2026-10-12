import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

/// Accurate mathematical mapper translating logical Ludo track, home lane, and yard positions
/// onto a normalized 15x15 board coordinate space (0.0 to 15.0).
class BoardCoordinateMapper {
  const BoardCoordinateMapper._();

  /// Total grid tiles per side on a standard Ludo board.
  static const int gridSize = 15;

  /// Exact 15x15 grid (col, row) mapping for all 52 main track cells (0 to 51).
  /// Player 0 (Red): Start cell 0 is at (col: 1, row: 6).
  /// Safe cells: [0, 8, 13, 21, 26, 34, 39, 47].
  static const List<Point<int>> trackGridPositions = [
    // Red quadrant arm (heading East)
    Point(1, 6), // 0: Red Start (Safe)
    Point(2, 6), // 1
    Point(3, 6), // 2
    Point(4, 6), // 3
    Point(5, 6), // 4
    Point(6, 5), // 5: turn North
    Point(6, 4), // 6
    Point(6, 3), // 7
    Point(6, 2), // 8: Safe Star
    Point(6, 1), // 9
    Point(6, 0), // 10
    Point(7, 0), // 11: Top corridor turn
    Point(8, 0), // 12
    // Green quadrant arm (heading South)
    Point(8, 1), // 13: Green Start (Safe)
    Point(8, 2), // 14
    Point(8, 3), // 15
    Point(8, 4), // 16
    Point(8, 5), // 17
    Point(9, 6), // 18: turn East
    Point(10, 6), // 19
    Point(11, 6), // 20
    Point(12, 6), // 21: Safe Star
    Point(13, 6), // 22
    Point(14, 6), // 23
    Point(14, 7), // 24: Right corridor turn
    Point(14, 8), // 25
    // Yellow quadrant arm (heading West)
    Point(13, 8), // 26: Yellow Start (Safe)
    Point(12, 8), // 27
    Point(11, 8), // 28
    Point(10, 8), // 29
    Point(9, 8), // 30
    Point(8, 9), // 31: turn South
    Point(8, 10), // 32
    Point(8, 11), // 33
    Point(8, 12), // 34: Safe Star
    Point(8, 13), // 35
    Point(8, 14), // 36
    Point(7, 14), // 37: Bottom corridor turn
    Point(6, 14), // 38
    // Blue quadrant arm (heading North)
    Point(6, 13), // 39: Blue Start (Safe)
    Point(6, 12), // 40
    Point(6, 11), // 41
    Point(6, 10), // 42
    Point(6, 9), // 43
    Point(5, 8), // 44: turn West
    Point(4, 8), // 45
    Point(3, 8), // 46
    Point(2, 8), // 47: Safe Star
    Point(1, 8), // 48
    Point(0, 8), // 49
    Point(0, 7), // 50: Left corridor turn (Home Entrance for Red)
    Point(0, 6), // 51: closes loop to cell 0
  ];

  /// Returns grid coordinate for a track cell (0..51).
  static Point<double> getTrackTileCoordinate(int trackCellIndex) {
    if (trackCellIndex < 0 || trackCellIndex >= trackGridPositions.length) {
      throw ArgumentError('Invalid track cell index: $trackCellIndex');
    }
    final pt = trackGridPositions[trackCellIndex];
    return Point(pt.x + 0.5, pt.y + 0.5);
  }

  /// Returns grid coordinate for a home lane step (1..5).
  static Point<double> getHomeLaneTileCoordinate(
    PlayerColor color,
    int laneStep,
  ) {
    if (laneStep < 1 || laneStep > 5) {
      throw ArgumentError('Invalid lane step: $laneStep (must be 1..5)');
    }

    switch (color) {
      case PlayerColor.red:
        // Heading East from col 1 to 5 along row 7
        return Point(laneStep.toDouble() + 0.5, 7.5);

      case PlayerColor.green:
        // Heading South from row 1 to 5 along col 7
        return Point(7.5, laneStep.toDouble() + 0.5);

      case PlayerColor.yellow:
        // Heading West from col 13 down to 9 along row 7
        return Point(14.0 - laneStep + 0.5, 7.5);

      case PlayerColor.blue:
        // Heading North from row 13 down to 9 along col 7
        return Point(7.5, 14.0 - laneStep + 0.5);

      case PlayerColor.orange:
        return Point(laneStep.toDouble() + 0.5, 7.5);

      case PlayerColor.purple:
        return Point(7.5, laneStep.toDouble() + 0.5);
    }
  }

  /// Returns central triangle coordinate for finished tokens.
  static Point<double> getHomeCenterCoordinate(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return const Point(6.8, 7.5);
      case PlayerColor.green:
        return const Point(7.5, 6.8);
      case PlayerColor.yellow:
        return const Point(8.2, 7.5);
      case PlayerColor.blue:
        return const Point(7.5, 8.2);
      case PlayerColor.orange:
        return const Point(6.8, 7.5);
      case PlayerColor.purple:
        return const Point(7.5, 6.8);
    }
  }

  /// Returns pedestal coordinate inside player's yard base (tokenIndex 0..3).
  static Point<double> getYardPedestalCoordinate(
    PlayerColor color,
    int tokenIndex,
  ) {
    // 4 pedestal offsets within each 6x6 yard base
    final offsets = [
      const Point(1.75, 1.75),
      const Point(4.25, 1.75),
      const Point(1.75, 4.25),
      const Point(4.25, 4.25),
    ];

    final offset = offsets[tokenIndex % 4];

    switch (color) {
      case PlayerColor.red:
        // Top-Left yard: [0..5, 0..5]
        return Point(offset.x, offset.y);

      case PlayerColor.green:
        // Top-Right yard: [9..14, 0..5]
        return Point(9.0 + offset.x, offset.y);

      case PlayerColor.yellow:
        // Bottom-Right yard: [9..14, 9..14]
        return Point(9.0 + offset.x, 9.0 + offset.y);

      case PlayerColor.blue:
        // Bottom-Left yard: [0..5, 9..14]
        return Point(offset.x, 9.0 + offset.y);

      case PlayerColor.orange:
        return Point(offset.x, offset.y);

      case PlayerColor.purple:
        return Point(9.0 + offset.x, offset.y);
    }
  }

  /// Calculates exact pixel position `Offset` on a canvas of `boardSize x boardSize`
  /// with automatic stacking displacement when multiple tokens share a tile.
  static Offset getTokenPixelPosition({
    required Token token,
    required double boardSize,
    int stackIndex = 0,
    int totalInStack = 1,
  }) {
    final tileSize = boardSize / gridSize;
    Point<double> baseCoord;

    switch (token.state) {
      case TokenState.yard:
        final idx = int.tryParse(token.id.split('_').last) ?? 0;
        baseCoord = getYardPedestalCoordinate(token.color, idx);
        break;

      case TokenState.track:
        if (token.trackCell == null) {
          baseCoord = getTrackTileCoordinate(token.color.startTrackCell);
        } else {
          baseCoord = getTrackTileCoordinate(token.trackCell!);
        }
        break;

      case TokenState.homeLane:
        baseCoord = getHomeLaneTileCoordinate(token.color, token.laneStep);
        break;

      case TokenState.home:
        baseCoord = getHomeCenterCoordinate(token.color);
        break;
    }

    var pixelX = baseCoord.x * tileSize;
    var pixelY = baseCoord.y * tileSize;

    // Apply stacking offset if multiple tokens share the cell
    if (totalInStack > 1 && token.state != TokenState.yard) {
      final spread = tileSize * 0.22;
      final angle = (2 * pi / totalInStack) * stackIndex;
      pixelX += cos(angle) * spread;
      pixelY += sin(angle) * spread;
    }

    return Offset(pixelX, pixelY);
  }
}
