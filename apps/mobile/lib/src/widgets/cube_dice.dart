import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Six projected faces, depth sorted and lit, with a value-preserving landing.
class CubeDice extends StatelessWidget {
  const CubeDice({
    super.key,
    required this.value,
    this.progress = 1,
    this.size = 100,
    this.faceColor = const Color(0xFFF3F8FF),
    this.pipColor = const Color(0xFF173563),
  });
  final int value;
  final double progress, size;
  final Color faceColor, pipColor;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _CubePainter(value.clamp(1, 6), progress, faceColor, pipColor),
    ),
  );
}

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V add(_V b) => _V(x + b.x, y + b.y, z + b.z);
  _V mul(double a) => _V(x * a, y * a, z * a);
}

class _Face {
  const _Face(this.normal, this.u, this.v, this.number);
  final _V normal, u, v;
  final int number;
}

class _CubePainter extends CustomPainter {
  const _CubePainter(this.value, this.progress, this.faceColor, this.pipColor);
  final int value;
  final double progress;
  final Color faceColor, pipColor;
  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    // Keep angular momentum through the throw, then settle after two impacts.
    final spinning = t < .78;
    final rotation = spinning ? math.pow(1 - t / .78, 1.45).toDouble() : 0.0;
    final settle = t < .78
        ? 0.0
        : math.sin((t - .78) / .22 * math.pi * 3) * (1 - t) / .22;
    final ax = -.08 + rotation * math.pi * 6 + settle * .08,
        ay = -.12 + rotation * math.pi * 4 + settle * .06,
        az = rotation * math.pi * 2 + settle * .06;
    _V rotate(_V p) {
      final y = p.y * math.cos(ax) - p.z * math.sin(ax),
          z = p.y * math.sin(ax) + p.z * math.cos(ax);
      final x = p.x * math.cos(ay) + z * math.sin(ay),
          zz = -p.x * math.sin(ay) + z * math.cos(ay);
      return _V(
        x * math.cos(az) - y * math.sin(az),
        x * math.sin(az) + y * math.cos(az),
        zz,
      );
    }

    final bounce = t < .6
        ? math.sin(t / .6 * math.pi) * .23
        : t < .82
        ? math.sin((t - .6) / .22 * math.pi) * .09
        : math.sin((t - .82) / .18 * math.pi) * .025;
    final lift = bounce * size.height;
    final travel = math.sin(t * math.pi * 2) * (1 - t) * size.width * .10;
    Offset project(_V p) {
      final r = rotate(p), f = 4.8 / (4.8 - r.z);
      return Offset(
        size.width * .5 + travel + r.x * f * size.width * .265,
        size.height * .45 + r.y * f * size.height * .265 - lift,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .88),
        width: size.width * (.63 - bounce * .8),
        height: size.height * .09,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: .32 - bounce * .6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final remaining = [
      1,
      2,
      3,
      4,
      5,
      6,
    ].where((n) => n != value && n != 7 - value).toList();
    final top = remaining.first,
        right = remaining.firstWhere((n) => n != top && n != 7 - top);
    final faces =
        [
          _Face(const _V(0, 0, 1), const _V(1, 0, 0), const _V(0, 1, 0), value),
          _Face(
            const _V(0, 0, -1),
            const _V(-1, 0, 0),
            const _V(0, 1, 0),
            7 - value,
          ),
          _Face(const _V(0, -1, 0), const _V(1, 0, 0), const _V(0, 0, 1), top),
          _Face(
            const _V(0, 1, 0),
            const _V(1, 0, 0),
            const _V(0, 0, -1),
            7 - top,
          ),
          _Face(
            const _V(1, 0, 0),
            const _V(0, 0, -1),
            const _V(0, 1, 0),
            right,
          ),
          _Face(
            const _V(-1, 0, 0),
            const _V(0, 0, 1),
            const _V(0, 1, 0),
            7 - right,
          ),
        ].where((f) => rotate(f.normal).z > .05).toList()..sort(
          (a, b) => rotate(a.normal).z.compareTo(rotate(b.normal).z),
        );
    for (final face in faces) {
      _V point(double x, double y) =>
          face.normal.add(face.u.mul(x)).add(face.v.mul(y));
      final corners = [
        project(point(-1, -1)),
        project(point(1, -1)),
        project(point(1, 1)),
        project(point(-1, 1)),
      ];
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = corners[(i + 3) % 4],
            b = corners[i],
            c = corners[(i + 1) % 4];
        final before = Offset.lerp(b, a, .09)!, after = Offset.lerp(b, c, .09)!;
        if (i == 0) {
          path.moveTo(before.dx, before.dy);
        } else {
          path.lineTo(before.dx, before.dy);
        }
        path.quadraticBezierTo(b.dx, b.dy, after.dx, after.dy);
      }
      path.close();
      final normal = rotate(face.normal);
      final light = (.66 + normal.z * .22 - normal.y * .15 - normal.x * .08)
          .clamp(.45, 1.0);
      final shaded = Color.lerp(Colors.black, faceColor, light)!;
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(shaded, Colors.white, .23)!, shaded],
          ).createShader(path.getBounds()),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round,
      );
      final dots = <Offset>[
        if (face.number.isOdd) Offset.zero,
        if (face.number >= 2) ...[
          const Offset(-.47, -.47),
          const Offset(.47, .47),
        ],
        if (face.number >= 4) ...[
          const Offset(.47, -.47),
          const Offset(-.47, .47),
        ],
        if (face.number == 6) ...[const Offset(-.47, 0), const Offset(.47, 0)],
      ];
      for (final dot in dots) {
        final points = List.generate(20, (i) {
          final angle = i * math.pi / 10;
          return project(
            point(
              dot.dx + math.cos(angle) * .115,
              dot.dy + math.sin(angle) * .115,
            ),
          );
        });
        final pip = Path()..addPolygon(points, true);
        canvas.drawPath(
          pip,
          Paint()..color = Color.lerp(pipColor, Colors.black, .3)!,
        );
        canvas.save();
        canvas.translate(0, size.height * .008);
        canvas.drawPath(pip, Paint()..color = pipColor);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CubePainter old) =>
      value != old.value ||
      progress != old.progress ||
      faceColor != old.faceColor ||
      pipColor != old.pipColor;
}
