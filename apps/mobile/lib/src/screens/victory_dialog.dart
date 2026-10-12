import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';
import '../theme/app_colors.dart';

/// Victory celebration modal displaying final rankings, statistics, and rematch controls.
class VictoryDialog extends StatelessWidget {
  const VictoryDialog({
    super.key,
    required this.gameState,
    required this.onRematch,
    required this.onHome,
  });

  final GameState gameState;
  final VoidCallback onRematch;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final placements = gameState.placements;
    final winnerId = placements.isNotEmpty ? placements.first : null;
    final winner = winnerId != null ? gameState.getPlayerById(winnerId) : null;
    final winnerColor = winner != null ? AppColors.getPlayerColor(winner.color) : AppColors.gold;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.3),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Golden Trophy Icon
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2A2000),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: AppColors.gold,
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'MATCH FINISHED',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                winner != null ? '${winner.name} Wins!' : 'Game Over',
                style: TextStyle(
                  color: winnerColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Placements List
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: placements.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final playerId = entry.value;
                    final player = gameState.getPlayerById(playerId);
                    if (player == null) return const SizedBox.shrink();

                    final pColor = AppColors.getPlayerColor(player.color);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: rank == 1
                                  ? AppColors.gold
                                  : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32)),
                            ),
                            child: Text(
                              '$rank',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: pColor,
                            child: Icon(
                              player.isBot ? Icons.smart_toy : Icons.person,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              player.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onHome,
                      child: const Text('Main Menu'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onRematch,
                      child: const Text('Rematch'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
