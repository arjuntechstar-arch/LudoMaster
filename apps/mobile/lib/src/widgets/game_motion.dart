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
    this.surfaceColor,
    this.radius = 22,
    this.pattern = 0,
  });
  final Color? surfaceColor;
  final double radius;
  final int pattern;
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
        scale: _pressed ? .99 : (_hovered ? 1.012 : 1),
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: duration,
          margin: const EdgeInsets.only(bottom: 10),
          transform: Matrix4.translationValues(
            0,
            _pressed ? 5 : (_hovered ? -3 : 0),
            0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .5),
                blurRadius: 16,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Color.lerp(
                  widget.surfaceColor ?? widget.color,
                  const Color(0xFF02091B),
                  .65,
                )!,
                offset: Offset(0, _pressed ? 3 : 9),
              ),
              BoxShadow(
                color: widget.color.withValues(alpha: _hovered ? .22 : .08),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            clipBehavior: Clip.antiAlias,
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.radius),
              side: BorderSide(
                color: widget.color.withValues(alpha: _hovered ? 1 : .8),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      widget.color.withValues(alpha: .22),
                      widget.surfaceColor ?? const Color(0xFF164277),
                    ),
                    Color.lerp(
                      widget.surfaceColor ?? const Color(0xFF164277),
                      const Color(0xFF07182F),
                      .42,
                    )!,
                  ],
                ),
              ),
              child: InkWell(
                onTap: widget.onTap,
                onHighlightChanged: (value) => setState(() => _pressed = value),
                splashColor: widget.color.withValues(alpha: .15),
                child: CustomPaint(
                  painter: GameCardPattern(widget.color, widget.pattern),
                  foregroundPainter: _CardBevel(widget.radius),
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
  const GameCardPattern(this.color, [this.pattern = 0]);
  final int pattern;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (pattern != 0) {
      final detail = Paint()
        ..color = color.withValues(alpha: .10)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      if (pattern.isEven) {
        for (
          double x = size.width * .5;
          x < size.width + size.height;
          x += 16
        ) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x - size.height, size.height),
            detail,
          );
        }
      } else {
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                size.width * .62 + i * 10,
                -25 + i * 10,
                size.width * .6,
                size.height + 30,
              ),
              const Radius.circular(20),
            ),
            detail,
          );
        }
      }
    }
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
      oldDelegate.color != color || oldDelegate.pattern != pattern;
}

/// Raised rim, top reflection and lower bevel create thickness even at rest.
class _CardBevel extends CustomPainter {
  const _CardBevel(this.radius);
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final rim = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(2),
      Radius.circular(radius - 2),
    );
    canvas.save();
    canvas.clipRRect(rim);
    canvas.drawRRect(
      rim,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xBBFFFFFF),
            Color(0x22FFFFFF),
            Color(0x08000000),
            Color(0x9900051A),
          ],
          stops: [0, .14, .55, 1],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    final shine = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * .9, 0)
      ..lineTo(size.width * .5, size.height * .32)
      ..lineTo(0, size.height * .2)
      ..close();
    canvas.drawPath(
      shine,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .14),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CardBevel old) => radius != old.radius;
}
