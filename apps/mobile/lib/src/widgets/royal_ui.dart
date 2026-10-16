import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_motion.dart';
import 'game_asset.dart';
import 'game_symbol.dart';

/// Repeating board-and-dice wallpaper, drawn locally at every screen size.
class RoyalBackdrop extends StatelessWidget {
  const RoyalBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        radius: 1.1,
        colors: [Color(0xFF1B4783), Color(0xFF091B3B)],
      ),
    ),
    child: CustomPaint(painter: _Wallpaper(), child: child),
  );
}

class _Wallpaper extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final ink = Paint()..color = Colors.white.withValues(alpha: .025);
    final dark = Paint()
      ..color = const Color(0xFF082456).withValues(alpha: .24);
    for (double y = -80; y < size.height + 100; y += 150) {
      for (double x = -80; x < size.width + 100; x += 150) {
        canvas.save();
        canvas.translate(x + (y % 300 == 70 ? 60 : 0), y);
        canvas.rotate(-math.pi / 4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 108, 108),
            const Radius.circular(10),
          ),
          ink,
        );
        for (final p in [
          const Offset(26, 26),
          const Offset(82, 26),
          const Offset(26, 82),
          const Offset(82, 82),
        ]) {
          canvas.drawRect(
            Rect.fromCenter(center: p, width: 32, height: 32),
            dark,
          );
          canvas.drawCircle(p, 7, ink);
        }
        canvas.drawRect(const Rect.fromLTWH(48, 8, 12, 92), ink);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoyalMode extends StatelessWidget {
  const RoyalMode({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final accent = switch (label.toLowerCase()) {
      'friends' => const Color(0xFFFF8CA7),
      'team up' => const Color(0xFF6CE0CD),
      'computer' => const Color(0xFFB4A1FF),
      'pass n play' => const Color(0xFFFFD77C),
      _ => const Color(0xFF8AD7FF),
    };
    return GameCardSurface(
      color: accent,
      surfaceColor: switch (label.toLowerCase()) {
        'friends' => const Color(0xFF672F59),
        'team up' => const Color(0xFF13594F),
        'computer' => const Color(0xFF443475),
        'pass n play' => const Color(0xFF6D4B22),
        _ => const Color(0xFF124C7F),
      },
      radius: label == 'Team up'
          ? 12
          : label == 'Friends'
          ? 30
          : 20,
      pattern: label == 'Computer' || label == 'Team up' ? 2 : 1,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 17, 8, 14),
        child: Column(
          children: [
            GameIconMotion(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    label == 'Friends'
                        ? 28
                        : label == 'Team up'
                        ? 10
                        : 18,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: .5),
                      accent.withValues(alpha: .08),
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: .5)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: .14),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: GameDepth(
                  child: GameAsset(GameAsset.forIcon(icon) ?? 'dice', size: 46),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Icon(Icons.arrow_forward_rounded, size: 15, color: accent),
          ],
        ),
      ),
    );
  }
}

class RoyalNavigation extends StatelessWidget {
  const RoyalNavigation({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFF70D8FF), width: 2)),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF208CEA), Color(0xFF0B3479)],
      ),
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          for (var i = 0; i < 5; i++)
            Expanded(
              child: Semantics(
                selected: selected == i,
                button: true,
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selected == i
                          ? const Color(0xFF38A9FF)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GameSymbol(
                          [
                            Icons.home_rounded,
                            Icons.event_available_rounded,
                            Icons.sports_esports_rounded,
                            Icons.casino_rounded,
                            Icons.forum_rounded,
                          ][i],
                          size: 34,
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          child: Text(
                            ['HOME', 'EVENT', 'PLAY', 'INVENTORY', 'SOCIAL'][i],
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// A reward display that uses the actual daily-reward availability.
class RoyalRewardCard extends StatelessWidget {
  const RoyalRewardCard({super.key, required this.ready, required this.onTap});
  final bool ready;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: GameCardSurface(
      color: const Color(0xFFFFD16B),
      surfaceColor: const Color(0xFF61401E),
      radius: 12,
      pattern: 2,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const GameDepth(child: GameAsset('gift', size: 72)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DAILY TREASURE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      color: Color(0xFFFFDF8E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ready ? 'A little luck, on us.' : 'Keep your streak alive.',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD16B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ready ? 'CLAIM REWARD' : 'VIEW REWARDS',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF19335B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
