import 'package:flutter/material.dart';

import 'game_asset.dart';

/// Bundled 3D game art with local vector and Material utility fallbacks.
class GameSymbol extends StatelessWidget {
  const GameSymbol(this.icon, {super.key, this.size = 24, this.color});
  final IconData icon;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final asset = GameAsset.forIcon(icon);
    if (asset != null) return GameAsset(asset, size: size);
    final kind = _kind(icon);
    if (kind == null) return Icon(icon, size: size, color: color);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SymbolPainter(
          kind,
          color ?? IconTheme.of(context).color ?? Colors.white,
        ),
      ),
    );
  }

  static String? _kind(IconData i) {
    if ({Icons.home_outlined, Icons.home_rounded}.contains(i)) {
      return 'home';
    }
    if ({
      Icons.sports_esports_outlined,
      Icons.sports_esports_rounded,
    }.contains(i)) {
      return 'game';
    }
    if ({
      Icons.auto_awesome_outlined,
      Icons.auto_awesome_rounded,
      Icons.verified_outlined,
    }.contains(i)) {
      return 'star';
    }
    if ({
      Icons.people_outline_rounded,
      Icons.people_rounded,
      Icons.people_outline,
      Icons.groups_outlined,
    }.contains(i)) {
      return 'people';
    }
    if ({Icons.smart_toy_outlined, Icons.smart_toy_rounded}.contains(i)) {
      return 'robot';
    }
    if ({Icons.flash_on_rounded, Icons.bolt_rounded}.contains(i)) {
      return 'bolt';
    }
    if ({Icons.favorite_outline, Icons.favorite_rounded}.contains(i)) {
      return 'heart';
    }
    if ({Icons.meeting_room_outlined}.contains(i)) {
      return 'door';
    }
    if ({
      Icons.card_giftcard_rounded,
      Icons.card_giftcard_outlined,
    }.contains(i)) {
      return 'gift';
    }
    if ({Icons.workspace_premium_outlined}.contains(i)) {
      return 'crown';
    }
    if ({Icons.emoji_events_outlined}.contains(i)) {
      return 'trophy';
    }
    if ({Icons.flag_outlined}.contains(i)) {
      return 'flag';
    }
    if ({Icons.leaderboard_outlined}.contains(i)) {
      return 'chart';
    }
    if ({Icons.storefront_outlined}.contains(i)) {
      return 'store';
    }
    if ({Icons.monetization_on_outlined}.contains(i)) {
      return 'coin';
    }
    if ({Icons.diamond_outlined}.contains(i)) {
      return 'diamond';
    }
    if ({Icons.shield_outlined, Icons.privacy_tip_outlined}.contains(i)) {
      return 'shield';
    }
    if ({Icons.person_outline, Icons.person_rounded}.contains(i)) {
      return 'person';
    }
    if ({Icons.history_rounded}.contains(i)) {
      return 'history';
    }
    if ({Icons.tune_rounded}.contains(i)) {
      return 'settings';
    }
    if ({Icons.notifications_none_rounded}.contains(i)) {
      return 'bell';
    }
    if ({Icons.chevron_right_rounded}.contains(i)) {
      return 'arrow';
    }
    if ({Icons.play_arrow_rounded}.contains(i)) {
      return 'play';
    }
    return null;
  }
}

class _SymbolPainter extends CustomPainter {
  const _SymbolPainter(this.kind, this.color);
  final String kind;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    void line(double x, double y, double a, double b) =>
        canvas.drawLine(Offset(x, y), Offset(a, b), p);
    void circle(double x, double y, double r) =>
        canvas.drawCircle(Offset(x, y), r, p);
    void box(double x, double y, double w, double h, [double r = 2]) =>
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h),
            Radius.circular(r),
          ),
          p,
        );
    void path(List<Offset> points, {bool closed = false, bool solid = false}) {
      final shape = Path()..addPolygon(points, closed);
      if (closed) {
        canvas.drawPath(
          shape,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, Colors.white, .6)!,
                color,
                Color.lerp(color, Colors.black, .25)!,
              ],
            ).createShader(const Rect.fromLTWH(0, 0, 24, 24)),
        );
      }
      canvas.drawPath(shape, solid ? fill : p);
    }

    switch (kind) {
      case 'home':
        path([const Offset(3, 10), const Offset(12, 3), const Offset(21, 10)]);
        path([
          const Offset(5, 9),
          const Offset(5, 21),
          const Offset(19, 21),
          const Offset(19, 9),
        ]);
        box(10, 14, 4, 7, 1);
      case 'game':
        box(2, 6, 20, 13, 4);
        line(6, 12, 12, 12);
        line(9, 9, 9, 15);
        canvas.drawCircle(const Offset(17, 10), 1.3, fill);
        canvas.drawCircle(const Offset(19, 14), 1.3, fill);
      case 'star':
        path([
          const Offset(12, 2),
          const Offset(15, 8),
          const Offset(22, 10),
          const Offset(16, 14),
          const Offset(17, 21),
          const Offset(12, 18),
          const Offset(7, 21),
          const Offset(8, 14),
          const Offset(2, 10),
          const Offset(9, 8),
        ], closed: true);
      case 'people':
        circle(8, 7, 3);
        circle(17, 8, 2.5);
        canvas.drawArc(
          const Rect.fromLTWH(2, 12, 12, 10),
          3.14,
          3.14,
          false,
          p,
        );
        canvas.drawArc(const Rect.fromLTWH(13, 13, 9, 8), 3.14, 3.14, false, p);
        line(2, 17, 2, 20);
        line(14, 17, 14, 20);
        line(2, 20, 14, 20);
        line(22, 17, 22, 20);
        line(17, 20, 22, 20);
      case 'robot':
        box(4, 7, 16, 14, 3);
        line(12, 3, 12, 7);
        circle(12, 3, 1);
        canvas.drawCircle(const Offset(8, 12), 1.6, fill);
        canvas.drawCircle(const Offset(16, 12), 1.6, fill);
        line(9, 17, 15, 17);
        line(1, 11, 1, 17);
        line(23, 11, 23, 17);
      case 'bolt':
        path(
          [
            const Offset(14, 2),
            const Offset(4, 14),
            const Offset(11, 14),
            const Offset(9, 22),
            const Offset(21, 9),
            const Offset(14, 9),
          ],
          closed: true,
          solid: true,
        );
      case 'heart':
        final shape = Path()
          ..moveTo(12, 21)
          ..cubicTo(-6, 10, 4, -3, 12, 6)
          ..cubicTo(20, -3, 30, 10, 12, 21);
        canvas.drawPath(shape, p);
      case 'door':
        box(5, 3, 14, 19);
        line(2, 22, 22, 22);
        canvas.drawCircle(const Offset(15, 13), 1.2, fill);
      case 'gift':
        box(3, 10, 18, 12);
        box(2, 7, 20, 4, 1);
        line(12, 7, 12, 22);
        canvas.drawOval(const Rect.fromLTWH(5, 1, 7, 6), p);
        canvas.drawOval(const Rect.fromLTWH(12, 1, 7, 6), p);
      case 'crown':
        path([
          const Offset(3, 6),
          const Offset(7, 11),
          const Offset(12, 3),
          const Offset(17, 11),
          const Offset(21, 6),
          const Offset(19, 19),
          const Offset(5, 19),
        ], closed: true);
        line(6, 22, 18, 22);
      case 'trophy':
        box(6, 3, 12, 11, 3);
        canvas.drawArc(const Rect.fromLTWH(1, 4, 8, 9), 1.5, 3.2, false, p);
        canvas.drawArc(const Rect.fromLTWH(15, 4, 8, 9), -1.5, 3.2, false, p);
        line(12, 14, 12, 21);
        line(7, 22, 17, 22);
      case 'flag':
        line(5, 2, 5, 22);
        path([
          const Offset(5, 3),
          const Offset(20, 3),
          const Offset(17, 8),
          const Offset(20, 13),
          const Offset(5, 13),
        ], closed: true);
      case 'chart':
        box(3, 13, 4, 9, 1);
        box(10, 4, 4, 18, 1);
        box(17, 9, 4, 13, 1);
      case 'store':
        box(4, 10, 16, 12);
        path([
          const Offset(2, 10),
          const Offset(5, 3),
          const Offset(19, 3),
          const Offset(22, 10),
        ], closed: true);
        line(8, 3, 7, 10);
        line(16, 3, 17, 10);
        box(9, 15, 6, 7, 1);
      case 'coin':
        circle(12, 12, 10);
        line(12, 5, 12, 19);
        final shape = Path()
          ..moveTo(16, 8)
          ..cubicTo(6, 3, 6, 13, 12, 12)
          ..cubicTo(19, 12, 17, 21, 8, 17);
        canvas.drawPath(shape, p);
      case 'diamond':
        path([
          const Offset(2, 8),
          const Offset(7, 3),
          const Offset(17, 3),
          const Offset(22, 8),
          const Offset(12, 22),
        ], closed: true);
        line(2, 8, 22, 8);
        line(7, 3, 12, 22);
        line(17, 3, 12, 22);
      case 'shield':
        final shape = Path()
          ..moveTo(12, 2)
          ..lineTo(21, 6)
          ..lineTo(20, 14)
          ..quadraticBezierTo(18, 20, 12, 23)
          ..quadraticBezierTo(6, 20, 4, 14)
          ..lineTo(3, 6)
          ..close();
        canvas.drawPath(shape, p);
        line(8, 12, 11, 15);
        line(11, 15, 16, 9);
      case 'person':
        circle(12, 7, 4);
        canvas.drawArc(
          const Rect.fromLTWH(3, 13, 18, 16),
          3.14,
          3.14,
          false,
          p,
        );
        line(3, 21, 21, 21);
      case 'history':
        circle(13, 12, 9);
        line(13, 6, 13, 12);
        line(13, 12, 17, 14);
        path([const Offset(1, 4), const Offset(1, 10), const Offset(7, 10)]);
      case 'settings':
        for (var j = 0; j < 3; j++) {
          final y = 5.0 + j * 7;
          line(2, y, 22, y);
          circle(j == 1 ? 15 : 8, y, 2.5);
        }
      case 'bell':
        final shape = Path()
          ..moveTo(4, 18)
          ..lineTo(6, 15)
          ..lineTo(6, 9)
          ..cubicTo(6, 0, 18, 0, 18, 9)
          ..lineTo(18, 15)
          ..lineTo(20, 18)
          ..close();
        canvas.drawPath(shape, p);
        canvas.drawArc(const Rect.fromLTWH(9, 18, 6, 5), 0, 3.14, false, p);
      case 'arrow':
        path([const Offset(9, 5), const Offset(16, 12), const Offset(9, 19)]);
      case 'play':
        path(
          [const Offset(7, 3), const Offset(21, 12), const Offset(7, 21)],
          closed: true,
          solid: true,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SymbolPainter old) =>
      old.kind != kind || old.color != color;
}
