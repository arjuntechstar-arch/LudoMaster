import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Short, finite motion keeps scrolling smooth and respects reduced motion.
class GameEntrance extends StatelessWidget {
  const GameEntrance({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 440 + index.clamp(0, 6) * 65),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class GameIconMotion extends StatefulWidget {
  const GameIconMotion({super.key, required this.child, this.floating = false});
  final Widget child;
  final bool floating;
  @override
  State<GameIconMotion> createState() => _GameIconMotionState();
}

class _GameIconMotionState extends State<GameIconMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 1;
    } else {
      _motion.forward();
    }
  }

  void _replay() {
    if (!MediaQuery.disableAnimationsOf(context)) _motion.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _replay(),
    child: Listener(
      onPointerDown: (_) => _replay(),
      child: AnimatedBuilder(
        animation: _motion,
        child: widget.child,
        builder: (_, child) {
          final wave =
              math.sin(_motion.value * math.pi * 4) * (1 - _motion.value);
          return Transform.translate(
            offset: Offset(0, wave * (widget.floating ? 7 : 3)),
            child: Transform.rotate(
              angle: wave * (widget.floating ? .08 : .16),
              child: child,
            ),
          );
        },
      ),
    ),
  );
  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }
}

class GameCardSurface extends StatefulWidget {
  const GameCardSurface({
    super.key,
    required this.child,
    required this.color,
    required this.onTap,
  });
  final Widget child;
  final Color color;
  final VoidCallback onTap;
  @override
  State<GameCardSurface> createState() => _GameCardSurfaceState();
}

class _GameCardSurfaceState extends State<GameCardSurface> {
  bool _pressed = false;
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _pressed ? .975 : (_hovered ? 1.012 : 1),
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: duration,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _hovered ? .2 : .07),
                blurRadius: _hovered ? 24 : 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            clipBehavior: Clip.antiAlias,
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: widget.color.withValues(alpha: _hovered ? .65 : .25),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      widget.color.withValues(alpha: .12),
                      const Color(0xFF19263D),
                    ),
                    const Color(0xFF101C2E),
                  ],
                ),
              ),
              child: InkWell(
                onTap: widget.onTap,
                onHighlightChanged: (value) => setState(() => _pressed = value),
                splashColor: widget.color.withValues(alpha: .15),
                child: CustomPaint(
                  painter: GameCardPattern(widget.color),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Board tracks, orbit rings and a die give each card a game-table texture.
class GameCardPattern extends CustomPainter {
  const GameCardPattern(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final stroke = Paint()
      ..color = color.withValues(alpha: .13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final glow = Paint()..color = color.withValues(alpha: .055);
    final center = Offset(size.width + 8, size.height * .15);
    canvas.drawCircle(center, 86, glow);
    canvas.drawCircle(center, 61, stroke);
    canvas.drawCircle(center, 82, stroke);
    canvas.drawCircle(
      center,
      104,
      stroke..color = color.withValues(alpha: .06),
    );
    final dieCenter = Offset(size.width - 28, size.height - 18);
    canvas.save();
    canvas.translate(dieCenter.dx, dieCenter.dy);
    canvas.rotate(-.23);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-23, -23, 46, 46),
        const Radius.circular(10),
      ),
      Paint()..color = color.withValues(alpha: .055),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-23, -23, 46, 46),
        const Radius.circular(10),
      ),
      Paint()
        ..color = color.withValues(alpha: .13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    for (final point in [
      const Offset(-10, -10),
      const Offset(10, -10),
      const Offset(0, 0),
      const Offset(-10, 10),
      const Offset(10, 10),
    ]) {
      canvas.drawCircle(
        point,
        2.5,
        Paint()..color = color.withValues(alpha: .16),
      );
    }
    canvas.restore();
    final tiles = Paint()..color = color.withValues(alpha: .07);
    for (var i = 0; i < 5; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width - 148 + i * 15,
            size.height - 8 - (i % 2) * 4,
            10,
            10,
          ),
          const Radius.circular(2),
        ),
        tiles,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GameCardPattern oldDelegate) =>
      oldDelegate.color != color;
}
