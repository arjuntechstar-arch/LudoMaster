import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';

class AchievementsScreen extends StatefulWidget {
  final ApiClient apiClient;

  const AchievementsScreen({super.key, required this.apiClient});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<AchievementModel> _achievements = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await widget.apiClient.getAchievements();
      if (mounted) {
        setState(() {
          _achievements = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _claimAchievement(String achievementId) async {
    try {
      final res = await widget.apiClient.claimAchievement(achievementId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Achievement Reward Claimed: +${res.coinsAwarded} Coins, +${res.gemsAwarded} Gems, +${res.xpAwarded} XP!',
          ),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
      await _loadAchievements();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to claim: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _achievements.where((a) => a.isUnlocked).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('ACHIEVEMENTS & BADGES')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: $_errorMessage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFEF4444)),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadAchievements,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF334155)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.military_tech,
                            color: AppColors.gold,
                            size: 40,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lifetime Hall of Fame',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$unlockedCount of ${_achievements.length} Achievements Unlocked',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAchievements,
                        color: AppColors.gold,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          itemCount: _achievements.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final a = _achievements[index];
                            final progress =
                                (a.currentCount / a.targetCount).clamp(0.0, 1.0);
                            final canClaim = a.isUnlocked && !a.isClaimed;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: canClaim
                                      ? AppColors.gold
                                      : (a.isUnlocked
                                            ? const Color(0xFF22C55E)
                                            : Colors.white12),
                                  width: canClaim ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: a.isUnlocked
                                              ? AppColors.gold.withValues(alpha: 0.2)
                                              : Colors.white10,
                                        ),
                                        child: Icon(
                                          a.isUnlocked
                                              ? Icons.emoji_events
                                              : Icons.lock,
                                          color: a.isUnlocked
                                              ? AppColors.gold
                                              : Colors.white38,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              a.title,
                                              style: TextStyle(
                                                color: a.isUnlocked
                                                    ? Colors.white
                                                    : Colors.white60,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              a.description,
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (canClaim || a.isClaimed) ...[
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: canClaim
                                          ? ElevatedButton(
                                              onPressed: () =>
                                                  _claimAchievement(a.id),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.gold,
                                                foregroundColor: Colors.black,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 8,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: const Text(
                                                'CLAIM',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF22C55E)
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'UNLOCKED',
                                                style: TextStyle(
                                                  color: Color(0xFF22C55E),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            backgroundColor: Colors.white10,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              a.isUnlocked
                                                  ? const Color(0xFF22C55E)
                                                  : AppColors.gold,
                                            ),
                                            minHeight: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${a.currentCount} / ${a.targetCount}',
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (a.rewardCoins > 0)
                                        _RewardLabel(
                                          icon: Icons.monetization_on,
                                          color: AppColors.gold,
                                          text: '+${a.rewardCoins}',
                                        ),
                                      if (a.rewardGems > 0)
                                        _RewardLabel(
                                          icon: Icons.diamond,
                                          color: const Color(0xFF38BDF8),
                                          text: '+${a.rewardGems}',
                                        ),
                                      _RewardLabel(
                                        icon: Icons.star,
                                        color: const Color(0xFFA855F7),
                                        text: '+${a.rewardXp} XP',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _RewardLabel extends StatelessWidget {
  const _RewardLabel({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      );
}
