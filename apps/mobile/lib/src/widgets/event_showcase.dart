import 'package:flutter/material.dart';

import 'game_asset.dart';
import 'game_motion.dart';

class EventMarquee extends StatelessWidget {
  const EventMarquee({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      children: [
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameAsset('coin', size: 38),
            SizedBox(width: 6),
            GameDepth(floating: true, child: GameAsset('trophy', size: 86)),
            SizedBox(width: 6),
            GameAsset('gem', size: 38),
          ],
        ),
        Transform.rotate(
          angle: -.025,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFF6391),
                  Color(0xFFB60E4A),
                  Color(0xFF700C36),
                ],
              ),
              border: Border.all(color: const Color(0xFFFFB5BE), width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0xFF4D0B30), offset: Offset(0, 6)),
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 16,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Text(
              'EVENTS',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 3,
                shadows: [
                  Shadow(color: Color(0xFF65002A), offset: Offset(0, 3)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Big plays. Bigger celebrations.',
          style: TextStyle(color: Color(0xFFB8CDEB), fontSize: 12),
        ),
      ],
    ),
  );
}

class EventBanner extends StatelessWidget {
  const EventBanner({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.description,
    required this.asset,
    required this.accent,
    required this.surface,
    required this.onTap,
    this.action = 'OPEN',
    this.featured = false,
    this.reverse = false,
  });
  final String title, eyebrow, description, asset, action;
  final Color accent, surface;
  final VoidCallback onTap;
  final bool featured, reverse;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: GameCardSurface(
      color: accent,
      surfaceColor: surface,
      radius: featured ? 26 : 16,
      pattern: reverse ? 2 : 1,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, box) {
          final artSize = box.maxWidth < 330 ? 82.0 : 112.0;
          final art = SizedBox(
            width: artSize + 16,
            height: artSize + 46,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  bottom: 5,
                  child: Container(
                    width: artSize + 8,
                    height: 25,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent,
                          Color.lerp(accent, Colors.black, .65)!,
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          offset: Offset(0, 6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  child: Container(
                    width: artSize + 20,
                    height: artSize + 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: .45),
                          accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 18,
                  child: GameDepth(child: GameAsset(asset, size: artSize)),
                ),
                const Positioned(
                  top: 0,
                  right: 0,
                  child: GameAsset('sparkles', size: 25),
                ),
                if (featured) ...[
                  const Positioned(
                    bottom: 0,
                    left: -3,
                    child: GameAsset('coin', size: 33),
                  ),
                  const Positioned(
                    bottom: 2,
                    right: -3,
                    child: GameAsset('gem', size: 30),
                  ),
                ],
              ],
            ),
          );
          final text = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: featured ? 28 : 24,
                    height: 1.03,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Colors.black38, offset: Offset(0, 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFE3E9FA),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFA5F65D), Color(0xFF48B51E)],
                    ),
                    border: Border.all(color: const Color(0xFFC4FF8B)),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF1D620A), offset: Offset(0, 4)),
                    ],
                  ),
                  child: Text(
                    action,
                    style: const TextStyle(
                      color: Color(0xFF123C05),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            child: Row(
              children: reverse
                  ? [text, const SizedBox(width: 12), art]
                  : [art, const SizedBox(width: 16), text],
            ),
          );
        },
      ),
    ),
  );
}

class EventShortcut extends StatelessWidget {
  const EventShortcut({
    super.key,
    required this.title,
    required this.asset,
    required this.onTap,
    required this.color,
  });
  final String title, asset;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => GameCardSurface(
    color: color,
    surfaceColor: Color.lerp(color, const Color(0xFF0C1635), .75),
    radius: 18,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          GameAsset(asset, size: 44),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}
