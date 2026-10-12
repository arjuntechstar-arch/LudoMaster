import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../theme/app_colors.dart';
import 'board_coordinate_mapper.dart';

/// High-performance, original vector board renderer using [CustomPainter].
class LudoBoardPainter extends CustomPainter {
  final String themeAssetKey;

  const LudoBoardPainter({this.themeAssetKey = 'theme_classic_wood'});

  Color get _boardBackgroundColor {
    switch (themeAssetKey) {
      case 'theme_classic_wood':
        return const Color(0xFF2C1E14);
      case 'theme_neon_cyber':
        return const Color(0xFF030712);
      case 'theme_royal_marble':
        return const Color(0xFF1E1B4B);
      default:
        return AppColors.boardBackground;
    }
  }

  Color get _outerBorderColor {
    switch (themeAssetKey) {
      case 'theme_classic_wood':
        return const Color(0xFF8B5A2B);
      case 'theme_neon_cyber':
        return const Color(0xFF06B6D4);
      case 'theme_royal_marble':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF2E3D59);
    }
  }

  Color get _yardInnerPlateColor {
    switch (themeAssetKey) {
      case 'theme_classic_wood':
        return const Color(0xFF1F150E);
      case 'theme_neon_cyber':
        return const Color(0xFF0B1120);
      case 'theme_royal_marble':
        return const Color(0xFF2E1065);
      default:
        return const Color(0xFF0F172A);
    }
  }

  Color get _pedestalFillColor {
    switch (themeAssetKey) {
      case 'theme_classic_wood':
        return const Color(0xFF382315);
      case 'theme_neon_cyber':
        return const Color(0xFF1E293B);
      case 'theme_royal_marble':
        return const Color(0xFF3B0764);
      default:
        return const Color(0xFF1E293B);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = min(size.width, size.height);
    final tileSize = boardSize / BoardCoordinateMapper.gridSize;

    // 1. Board Background
    final bgPaint = Paint()..color = _boardBackgroundColor;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, boardSize, boardSize),
      Radius.circular(tileSize * 0.8),
    );
    canvas.drawRRect(rrect, bgPaint);

    // 2. Yard Bases (6x6 tiles each)
    _drawYardBase(canvas, 0, 0, tileSize, PlayerColor.red);
    _drawYardBase(canvas, 9 * tileSize, 0, tileSize, PlayerColor.green);
    _drawYardBase(
      canvas,
      9 * tileSize,
      9 * tileSize,
      tileSize,
      PlayerColor.yellow,
    );
    _drawYardBase(canvas, 0, 9 * tileSize, tileSize, PlayerColor.blue);

    // 3. Center Triangles (rows 6..8, cols 6..8)
    _drawCenterFinish(canvas, tileSize);

    // 4. Track Cells (all 52 tiles)
    _drawTrackCells(canvas, tileSize);

    // 5. Home Columns (5 tiles for each color)
    _drawHomeColumns(canvas, tileSize);

    // 6. Safe Stars & Emblems
    _drawSafeCellStars(canvas, tileSize);

    // 7. Outer border
    final borderPaint = Paint()
      ..color = _outerBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(rrect, borderPaint);
  }

  void _drawYardBase(
    Canvas canvas,
    double x,
    double y,
    double tileSize,
    PlayerColor color,
  ) {
    final yardSize = 6 * tileSize;
    final primaryColor = AppColors.getPlayerColor(color);
    final lightColor = AppColors.getPlayerLightColor(color);

    // Outer colored quadrant
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, yardSize, yardSize),
      Radius.circular(tileSize * 0.6),
    );
    final outerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, AppColors.getPlayerDarkColor(color)],
      ).createShader(Rect.fromLTWH(x, y, yardSize, yardSize));
    canvas.drawRRect(outerRect, outerPaint);

    // Inner white/marble plate (4x4)
    final innerPadding = tileSize * 0.8;
    final innerSize = yardSize - (innerPadding * 2);
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + innerPadding, y + innerPadding, innerSize, innerSize),
      Radius.circular(tileSize * 0.5),
    );
    final innerPaint = Paint()..color = _yardInnerPlateColor;
    canvas.drawRRect(innerRect, innerPaint);

    final innerBorder = Paint()
      ..color = lightColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(innerRect, innerBorder);

    // 4 token pedestals
    final pedestalOffsets = [
      Offset(x + 1.75 * tileSize, y + 1.75 * tileSize),
      Offset(x + 4.25 * tileSize, y + 1.75 * tileSize),
      Offset(x + 1.75 * tileSize, y + 4.25 * tileSize),
      Offset(x + 4.25 * tileSize, y + 4.25 * tileSize),
    ];

    for (final center in pedestalOffsets) {
      final pedestalRadius = tileSize * 0.7;

      // Glow shadow
      canvas.drawCircle(
        center,
        pedestalRadius + 2,
        Paint()..color = primaryColor.withValues(alpha: 0.2),
      );

      // Pedestal fill
      canvas.drawCircle(
        center,
        pedestalRadius,
        Paint()..color = _pedestalFillColor,
      );

      // Inner colored ring
      canvas.drawCircle(
        center,
        pedestalRadius - 3,
        Paint()
          ..color = primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  void _drawCenterFinish(Canvas canvas, double tileSize) {
    final centerLeft = 6 * tileSize;
    final centerTop = 6 * tileSize;
    final centerRight = 9 * tileSize;
    final centerBottom = 9 * tileSize;
    final midX = 7.5 * tileSize;
    final midY = 7.5 * tileSize;

    // Red (West) Triangle
    final redPath = Path()
      ..moveTo(centerLeft, centerTop)
      ..lineTo(centerLeft, centerBottom)
      ..lineTo(midX, midY)
      ..close();
    canvas.drawPath(redPath, Paint()..color = AppColors.red);

    // Green (North) Triangle
    final greenPath = Path()
      ..moveTo(centerLeft, centerTop)
      ..lineTo(centerRight, centerTop)
      ..lineTo(midX, midY)
      ..close();
    canvas.drawPath(greenPath, Paint()..color = AppColors.green);

    // Yellow (East) Triangle
    final yellowPath = Path()
      ..moveTo(centerRight, centerTop)
      ..lineTo(centerRight, centerBottom)
      ..lineTo(midX, midY)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = AppColors.yellow);

    // Blue (South) Triangle
    final bluePath = Path()
      ..moveTo(centerLeft, centerBottom)
      ..lineTo(centerRight, centerBottom)
      ..lineTo(midX, midY)
      ..close();
    canvas.drawPath(bluePath, Paint()..color = AppColors.blue);

    // Golden center star crest
    final starPaint = Paint()..color = AppColors.gold;
    _drawStar(
      canvas,
      Offset(midX, midY),
      5,
      tileSize * 0.45,
      tileSize * 0.22,
      starPaint,
    );
  }

  void _drawTrackCells(Canvas canvas, double tileSize) {
    final cellPaint = Paint()..color = AppColors.trackCellFill;
    final borderPaint = Paint()
      ..color = AppColors.trackCellBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var i = 0; i < BoardCoordinateMapper.trackGridPositions.length; i++) {
      final pos = BoardCoordinateMapper.trackGridPositions[i];
      final rect = Rect.fromLTWH(
        pos.x * tileSize,
        pos.y * tileSize,
        tileSize,
        tileSize,
      );

      // Color starting tiles
      if (i == 0) {
        canvas.drawRect(
          rect,
          Paint()..color = AppColors.red.withValues(alpha: 0.35),
        );
      } else if (i == 13) {
        canvas.drawRect(
          rect,
          Paint()..color = AppColors.green.withValues(alpha: 0.35),
        );
      } else if (i == 26) {
        canvas.drawRect(
          rect,
          Paint()..color = AppColors.yellow.withValues(alpha: 0.35),
        );
      } else if (i == 39) {
        canvas.drawRect(
          rect,
          Paint()..color = AppColors.blue.withValues(alpha: 0.35),
        );
      } else {
        canvas.drawRect(rect, cellPaint);
      }

      canvas.drawRect(rect, borderPaint);
    }
  }

  void _drawHomeColumns(Canvas canvas, double tileSize) {
    // Red Home Column (row 7, cols 1..5)
    _drawColoredLane(canvas, tileSize, 1, 7, 5, 0, AppColors.red);

    // Green Home Column (col 7, rows 1..5)
    _drawColoredLane(canvas, tileSize, 7, 1, 0, 5, AppColors.green);

    // Yellow Home Column (row 7, cols 9..13)
    _drawColoredLane(canvas, tileSize, 9, 7, 5, 0, AppColors.yellow);

    // Blue Home Column (col 7, rows 9..13)
    _drawColoredLane(canvas, tileSize, 7, 9, 0, 5, AppColors.blue);
  }

  void _drawColoredLane(
    Canvas canvas,
    double tileSize,
    int startCol,
    int startRow,
    int widthCount,
    int heightCount,
    Color color,
  ) {
    final count = max(widthCount, heightCount);
    final dx = widthCount > 0 ? 1 : 0;
    final dy = heightCount > 0 ? 1 : 0;

    final lanePaint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 0; i < count; i++) {
      final rect = Rect.fromLTWH(
        (startCol + (i * dx)) * tileSize,
        (startRow + (i * dy)) * tileSize,
        tileSize,
        tileSize,
      );
      canvas.drawRect(rect, lanePaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  void _drawSafeCellStars(Canvas canvas, double tileSize) {
    final starPaint = Paint()..color = AppColors.gold;

    for (final safeIndex in BoardMetrics.standardSafeCells) {
      final pos = BoardCoordinateMapper.trackGridPositions[safeIndex];
      final center = Offset((pos.x + 0.5) * tileSize, (pos.y + 0.5) * tileSize);
      _drawStar(canvas, center, 5, tileSize * 0.35, tileSize * 0.17, starPaint);
    }
  }

  void _drawStar(
    Canvas canvas,
    Offset center,
    int points,
    double outerRadius,
    double innerRadius,
    Paint paint,
  ) {
    final path = Path();
    final angle = pi / points;

    for (var i = 0; i < points * 2; i++) {
      final r = (i % 2 == 0) ? outerRadius : innerRadius;
      final currAngle = i * angle - (pi / 2);
      final x = center.dx + r * cos(currAngle);
      final y = center.dy + r * sin(currAngle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LudoBoardPainter oldDelegate) =>
      oldDelegate.themeAssetKey != themeAssetKey;
}
