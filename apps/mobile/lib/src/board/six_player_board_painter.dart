import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../theme/app_colors.dart';
import 'six_player_board_geometry.dart';

/// Compact six-color board renderer matching the server's 72-cell track.
class SixPlayerBoardPainter extends CustomPainter {
  const SixPlayerBoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = min(size.width, size.height);
    final tile = boardSize / SixPlayerBoardGeometry.gridSize;
    final boardRect = Rect.fromLTWH(0, 0, boardSize, boardSize);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(12)),
      Paint()..color = AppColors.boardBackground,
    );

    _drawYards(canvas, tile);
    _drawTrack(canvas, tile);
    _drawHomeLanes(canvas, tile);
    _drawCenter(canvas, tile);
  }

  void _drawYards(Canvas canvas, double tile) {
    const origins = <PlayerColor, Point<int>>{
      PlayerColor.red: Point(2, 2),
      PlayerColor.green: Point(14, 2),
      PlayerColor.yellow: Point(14, 8),
      PlayerColor.blue: Point(14, 14),
      PlayerColor.orange: Point(2, 14),
      PlayerColor.purple: Point(2, 8),
    };

    for (final entry in origins.entries) {
      final origin = entry.value;
      final color = AppColors.getPlayerColor(entry.key);
      final yard = Rect.fromLTWH(
        origin.x * tile,
        origin.y * tile,
        5 * tile,
        5 * tile,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(yard, Radius.circular(tile * 0.35)),
        Paint()..color = color.withValues(alpha: 0.38),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(yard, Radius.circular(tile * 0.35)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      for (var token = 0; token < 4; token++) {
        final center = SixPlayerBoardGeometry.yardCenter(entry.key, token);
        canvas.drawCircle(
          Offset(center.x * tile, center.y * tile),
          tile * 0.48,
          Paint()..color = const Color(0xFF111827),
        );
      }
    }
  }

  void _drawTrack(Canvas canvas, double tile) {
    final trackPaint = Paint()..color = const Color(0xFFE2E8F0);
    final borderPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final startColorByCell = <int, PlayerColor>{
      for (var i = 0; i < SixPlayerBoardGeometry.startCells.length; i++)
        SixPlayerBoardGeometry.startCells[i]: PlayerColor.values[i],
    };

    for (var i = 0; i < SixPlayerBoardGeometry.trackLength; i++) {
      final point = SixPlayerBoardGeometry.trackGridPositions[i];
      final rect = Rect.fromLTWH(point.x * tile, point.y * tile, tile, tile);
      final startColor = startColorByCell[i];
      canvas.drawRect(
        rect,
        Paint()
          ..color = startColor == null
              ? trackPaint.color
              : AppColors.getPlayerColor(startColor).withValues(alpha: 0.82),
      );
      canvas.drawRect(rect, borderPaint);

      if (SixPlayerBoardGeometry.safeCells.contains(i)) {
        canvas.drawCircle(
          rect.center,
          tile * 0.17,
          Paint()..color = const Color(0xFFFFD700),
        );
      }
    }
  }

  void _drawHomeLanes(Canvas canvas, double tile) {
    for (final color in PlayerColor.values) {
      for (var step = 1; step <= 5; step++) {
        final point = SixPlayerBoardGeometry.homeLaneCenter(color, step);
        final rect = Rect.fromCenter(
          center: Offset(point.x * tile, point.y * tile),
          width: tile,
          height: tile,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = AppColors.getPlayerColor(color).withValues(alpha: 0.88),
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = const Color(0xFF334155)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  void _drawCenter(Canvas canvas, double tile) {
    final center = Offset(10.5 * tile, 10.5 * tile);
    canvas.drawCircle(
      center,
      tile * 1.15,
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawCircle(
      center,
      tile * 1.15,
      Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    for (final color in PlayerColor.values) {
      final point = SixPlayerBoardGeometry.homeCenter(color);
      canvas.drawCircle(
        Offset(point.x * tile, point.y * tile),
        tile * 0.22,
        Paint()..color = AppColors.getPlayerColor(color),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SixPlayerBoardPainter oldDelegate) => false;
}
