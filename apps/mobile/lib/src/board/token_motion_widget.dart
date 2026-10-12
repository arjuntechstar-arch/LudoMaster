import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../services/game_pacing.dart';
import 'board_coordinate_mapper.dart';
import 'token_widget.dart';

/// Follow each track tile instead of cutting across the board between moves.
class TokenMotionWidget extends StatefulWidget {
  const TokenMotionWidget({
    super.key,
    required this.token,
    required this.position,
    required this.boardSize,
    required this.size,
    required this.isLegal,
    this.onTap,
  });
  final Token token;
  final Offset position;
  final double boardSize;
  final double size;
  final bool isLegal;
  final VoidCallback? onTap;
  @override
  State<TokenMotionWidget> createState() => _TokenMotionWidgetState();
}

class _TokenMotionWidgetState extends State<TokenMotionWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<Offset> _path;
  @override
  void initState() {
    super.initState();
    _path = [widget.position, widget.position];
    _controller = AnimationController(
      vsync: this,
      duration: GamePacing.tokenMove,
      value: 1,
    );
  }

  int _progress(Token token) => switch (token.state) {
    TokenState.yard => 0,
    TokenState.track =>
      ((token.trackCell ?? token.color.startTrackCell) -
                  token.color.startTrackCell +
                  52) %
              52 +
          1,
    TokenState.homeLane => 51 + token.laneStep,
    TokenState.home => 57,
  };

  Offset _point(Point<double> point) =>
      Offset(point.x, point.y) *
      (widget.boardSize / BoardCoordinateMapper.gridSize);

  Offset _position() {
    final progress = _controller.value * (_path.length - 1);
    final segment = min(progress.floor(), _path.length - 2);
    return Offset.lerp(
      _path[segment],
      _path[segment + 1],
      Curves.easeInOut.transform(progress - segment),
    )!;
  }

  @override
  void didUpdateWidget(TokenMotionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position == oldWidget.position) return;
    final start = _position();
    final from = _progress(oldWidget.token);
    final to = _progress(widget.token);
    _controller.duration = GamePacing.tokenMoveForSteps((to - from).abs());
    _path = [start];
    // Captures return to the yard; resize/stack adjustments use a short direct path.
    if (widget.boardSize == oldWidget.boardSize &&
        from > 0 &&
        to > from &&
        to - from <= 6) {
      for (var step = from + 1; step < to; step++) {
        _path.add(
          step <= 51
              ? _point(
                  BoardCoordinateMapper.getTrackTileCoordinate(
                    (widget.token.color.startTrackCell + step - 1) % 52,
                  ),
                )
              : _point(
                  BoardCoordinateMapper.getHomeLaneTileCoordinate(
                    widget.token.color,
                    step - 51,
                  ),
                ),
        );
      }
    }
    _path.add(widget.position);
    if (widget.boardSize != oldWidget.boardSize) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final point = _position();
      final progress = _controller.value * (_path.length - 1);
      final segmentProgress = progress - progress.floor();
      final hop =
          sin(Curves.easeInOut.transform(segmentProgress) * pi) *
          widget.size *
          0.18;
      final hopScale = 1 + sin(pi * segmentProgress) * 0.06;
      return Positioned(
        left: point.dx - widget.size / 2,
        top: point.dy - widget.size / 2 - hop,
        child: Transform.scale(scale: hopScale, child: child!),
      );
    },
    child: TokenWidget(
      token: widget.token,
      size: widget.size,
      isLegalMove: widget.isLegal,
      onTap: widget.onTap,
    ),
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
