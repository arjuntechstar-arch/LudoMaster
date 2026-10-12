import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';

class DailyRewardsDialog extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback? onRewardClaimed;

  const DailyRewardsDialog({
    super.key,
    required this.apiClient,
    this.onRewardClaimed,
  });

  static Future<void> show(
    BuildContext context,
    ApiClient apiClient, {
    VoidCallback? onRewardClaimed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => DailyRewardsDialog(
        apiClient: apiClient,
        onRewardClaimed: onRewardClaimed,
      ),
    );
  }

  @override
  State<DailyRewardsDialog> createState() => _DailyRewardsDialogState();
}

class _DailyRewardsDialogState extends State<DailyRewardsDialog> {
  DailyRewardStatusModel? _status;
  bool _isLoading = true;
  bool _isClaiming = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final s = await widget.apiClient.getDailyRewardStatus();
      if (mounted) {
        setState(() {
          _status = s;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Rewards are temporarily unavailable. Please retry.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _claim() async {
    setState(() => _isClaiming = true);
    try {
      final res = await widget.apiClient.claimDailyReward();
      widget.onRewardClaimed?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
      await _fetchStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Claim failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: AppColors.gold.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with flame icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Color(0xFFF97316),
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DAILY REWARDS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _status != null
                  ? 'Streak: ${_status!.currentStreak} Days • Log in daily for grand rewards!'
                  : 'Log in every day to claim bonus coins, gems & XP!',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            else if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _message!,
                      style: const TextStyle(color: Color(0xFFEF4444)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _fetchStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('RETRY'),
                    ),
                  ],
                ),
              )
            else if (_status != null) ...[
              // Grid of 7 days
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _status!.days
                    .map((day) => _buildDayCard(day))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_status!.canClaim && !_isClaiming)
                      ? _claim
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white38,
                  ),
                  child: _isClaiming
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _status!.canClaim
                              ? 'CLAIM DAY ${_status!.days.firstWhere((d) => d.isToday, orElse: () => _status!.days.first).day} REWARD'
                              : 'ALREADY CLAIMED TODAY',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(DailyRewardDayModel day) {
    final isSpecial = day.day == 7;
    final isToday = day.isToday;
    final isClaimed = day.isClaimed;

    return Container(
      width: isSpecial ? 230 : 72,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.gold.withValues(alpha: 0.15)
            : (isClaimed
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFF1E293B)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? AppColors.gold
              : (isSpecial ? const Color(0xFF8B5CF6) : Colors.white12),
          width: isToday ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isSpecial ? 'DAY 7 BONUS' : 'DAY ${day.day}',
            style: TextStyle(
              color: isToday ? AppColors.gold : const Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (day.coins > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: AppColors.gold,
                        size: 13,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${day.coins}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                if (day.gems > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.diamond,
                        color: Color(0xFF38BDF8),
                        size: 13,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${day.gems}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (isClaimed)
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 12),
                  SizedBox(width: 2),
                  Text(
                    'Claimed',
                    style: TextStyle(color: Color(0xFF22C55E), fontSize: 9),
                  ),
                ],
              ),
            )
          else if (isToday)
            const Text(
              'READY',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            )
          else
            Text(
              '+${day.xp} XP',
              style: const TextStyle(color: Colors.white38, fontSize: 9),
            ),
        ],
      ),
    );
  }
}
