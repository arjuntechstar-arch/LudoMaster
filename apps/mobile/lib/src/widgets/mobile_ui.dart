import 'package:flutter/material.dart';

import 'game_symbol.dart';

import '../theme/app_colors.dart';
import 'game_motion.dart';

class MobileDialog extends StatelessWidget {
  const MobileDialog({super.key, required this.child, this.maxWidth = 480});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Dialog(
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: child,
      ),
    ),
  );
}

/// Shared, content-sized primitives for the mobile app.
class MobilePageBody extends StatelessWidget {
  const MobilePageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      for (var i = 0; i < children.length; i++)
        GameEntrance(index: i, child: children[i]),
    ],
  );
}

class MobileHeading extends StatelessWidget {
  const MobileHeading(this.title, {super.key, this.subtitle, this.eyebrow});
  final String title;
  final String? subtitle;
  final String? eyebrow;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: const TextStyle(
              color: AppColors.mint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    ),
  );
}

class MobileAction extends StatelessWidget {
  const MobileAction({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primaryLight,
    this.trailing,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GameCardSurface(
      color: color,
      surfaceColor: icon == Icons.emoji_events_outlined
          ? const Color(0xFF592C47)
          : icon == Icons.workspace_premium_outlined
          ? const Color(0xFF352B68)
          : Color.alphaBlend(
              color.withValues(alpha: .28),
              const Color(0xFF112039),
            ),
      radius: icon == Icons.emoji_events_outlined
          ? 12
          : icon == Icons.workspace_premium_outlined
          ? 28
          : 18,
      pattern: icon == Icons.emoji_events_outlined ? 2 : 1,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: GameIconMotion(
                child: GameSymbol(icon, color: color, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
          ],
        ),
      ),
    ),
  );
}

class MobileSection extends StatelessWidget {
  const MobileSection(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 14),
    child: Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
  );
}

class MobileModeCard extends StatelessWidget {
  const MobileModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GameCardSurface(
    color: color,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: .28),
                  color.withValues(alpha: .08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: .3)),
            ),
            child: GameIconMotion(
              child: GameSymbol(icon, color: color, size: 30),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Gives every route its actual available width; never scales the UI canvas.
class MobileAppFrame extends StatelessWidget {
  const MobileAppFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF060C17),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, 640.0);
        return Center(
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(size: Size(width, constraints.maxHeight)),
              child: child,
            ),
          ),
        );
      },
    ),
  );
}
