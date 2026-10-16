import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_asset.dart';
import 'cube_dice.dart';

/// An interactive tabletop illustration, independent of match dice and state.
class ArenaHero extends StatefulWidget {
  const ArenaHero({super.key, required this.onPlay, required this.name});
  final VoidCallback onPlay;
  final String name;
  @override
  State<ArenaHero> createState() => _ArenaHeroState();
}

class _ArenaHeroState extends State<ArenaHero> {
  int _face = 5;
  int _turns = 0;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF76BFFF).withValues(alpha: .5),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF255EAE), Color(0xFF102752), Color(0xFF183F78)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x5505163B),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _ArenaArt())),
          const Positioned(
            left: 8,
            bottom: 104,
            child: IgnorePointer(
              child: GameDepth(
                floating: true,
                phase: 1,
                child: GameAsset('coin', size: 48),
              ),
            ),
          ),
          const Positioned(
            right: 108,
            bottom: 178,
            child: IgnorePointer(
              child: GameDepth(
                floating: true,
                phase: 3,
                child: GameAsset('gem', size: 42),
              ),
            ),
          ),
          const Positioned(
            left: 22,
            bottom: 208,
            child: IgnorePointer(child: GameAsset('sparkles', size: 25)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD15B),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        'THE ROYAL TABLE',
                        style: TextStyle(
                          color: Color(0xFF342400),
                          fontSize: 10,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const GameAsset('crown', size: 34),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Your move, ${widget.name}.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC2DFFF),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Small dice.\nBig moments.',
                  style: TextStyle(
                    fontSize: 33,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                SizedBox(
                  height: 155,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Tooltip(
                      message: 'Roll the lobby dice',
                      child: Semantics(
                        button: true,
                        label: 'Roll the lobby dice. Showing $_face',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => setState(() {
                            _turns++;
                            _face = _face % 6 + 1;
                          }),
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(_turns),
                            tween: Tween(
                              begin: _turns == 0 ? 1.0 : 0.0,
                              end: 1.0,
                            ),
                            duration: Duration(milliseconds: reduced ? 0 : 950),
                            builder: (_, progress, _) => CubeDice(
                              value: _face,
                              progress: progress,
                              size: 112,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.onPlay,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD15B),
                      foregroundColor: const Color(0xFF162A50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'FIND MY TABLE',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.arrow_forward_rounded, size: 19),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Online matchmaking · 2–6 players',
                    style: TextStyle(color: Color(0xFFB5D0F6), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .45, size.height * .62);
    final orbit = Paint()
      ..color = const Color(0xFF70BFFF).withValues(alpha: .15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final radius in [90.0, 125.0, 160.0, 205.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: center, width: radius * 2, height: radius),
        orbit,
      );
    }
    canvas.save();
    canvas.translate(center.dx - 20, center.dy - 30);
    canvas.transform(Matrix4.skewX(-.35).storage);
    canvas.scale(1, .58);
    canvas.rotate(-math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-76, -76, 152, 152),
        const Radius.circular(14),
      ),
      Paint()..color = const Color(0xFF061C43),
    );
    const colors = [
      Color(0xFFF76985),
      Color(0xFF5CD8CB),
      Color(0xFF77B9FF),
      Color(0xFFFFD565),
    ];
    for (var i = 0; i < 4; i++) {
      final x = -68.0 + (i % 2) * 76;
      final y = -68.0 + (i ~/ 2) * 76;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 60, 60),
          const Radius.circular(8),
        ),
        Paint()..color = colors[i],
      );
      for (var j = 0; j < 4; j++) {
        canvas.drawCircle(
          Offset(x + 19 + (j % 2) * 22, y + 19 + (j ~/ 2) * 22),
          6,
          Paint()..color = Colors.white.withValues(alpha: .85),
        );
      }
    }
    canvas.restore();
    for (var i = 0; i < 12; i++) {
      final x = (i * 71.0 + 25) % size.width;
      final y = (i * 47.0 + 15) % size.height;
      canvas.drawCircle(
        Offset(x, y),
        i % 3 == 0 ? 2 : 1,
        Paint()..color = const Color(0xFFFFDE93).withValues(alpha: .5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
