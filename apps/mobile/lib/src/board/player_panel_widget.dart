import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../theme/app_colors.dart';

/// Player status panel showing avatar, turn indicator, tokens in home, and timer bar.
class PlayerPanelWidget extends StatelessWidget {
  const PlayerPanelWidget({
    super.key,
    required this.player,
    required this.isActiveTurn,
    required this.tokensFinished,
    required this.totalTokens,
    this.onTap,
    this.compact = false,
  });

  final PlayerState player;
  final bool isActiveTurn;
  final int tokensFinished;
  final int totalTokens;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getPlayerColor(player.color);

    // Keep a pair of panels inside a 320px viewport even with the game
    // screen's horizontal padding. Text already ellipsizes where required.
    final panel = SizedBox(
      width: compact ? 124 : 140,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isActiveTurn
              ? Color.alphaBlend(
                  color.withValues(alpha: 0.16),
                  AppColors.surfaceElevated,
                )
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActiveTurn ? color : color.withValues(alpha: 0.4),
            width: isActiveTurn ? 2.5 : 1.0,
          ),
          boxShadow: isActiveTurn
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: compact ? 12 : 16,
              backgroundColor: color,
              child: Icon(
                player.isBot ? Icons.smart_toy : Icons.person,
                size: compact ? 14 : 18,
                color: Colors.white,
              ),
            ),
            SizedBox(width: compact ? 5 : 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActiveTurn ? color : AppColors.textPrimary,
                      fontSize: compact ? 10 : 13,
                      fontWeight: isActiveTurn
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: compact ? 1 : 2),
                  Wrap(
                    spacing: 2,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.home,
                        size: compact ? 10 : 12,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: compact ? 2 : 4),
                      Text(
                        '$tokensFinished / $totalTokens',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: compact ? 9 : 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (player.teamId != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: player.teamId == 0
                                ? const Color(0xFFE65100)
                                : const Color(0xFF0277BD),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'T${player.teamId! + 1}',
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (player.hasFinished) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${player.placement ?? 1}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: panel,
      );
    }
    return panel;
  }
}
