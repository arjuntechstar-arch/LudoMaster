import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../screens/store_inventory_screen.dart';

/// Interactive modal allowing players to watch a short sponsored ad to claim extra coins & gems.
class WatchAdRewardDialog extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback onRewardClaimed;

  const WatchAdRewardDialog({
    super.key,
    required this.apiClient,
    required this.onRewardClaimed,
  });

  @override
  State<WatchAdRewardDialog> createState() => _WatchAdRewardDialogState();
}

class _WatchAdRewardDialogState extends State<WatchAdRewardDialog>
    with SingleTickerProviderStateMixin {
  bool _isPlayingAd = false;
  bool _adCompleted = false;
  bool _isClaiming = false;
  int _secondsLeft = 5;
  Timer? _timer;
  late AnimationController _celebrationController;
  late Animation<double> _scaleAnimation;
  Map<String, dynamic>? _adStatus;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.elasticOut,
    );
    _loadAdStatus();
  }

  Future<void> _loadAdStatus() async {
    try {
      final status = await widget.apiClient.getAdRewardStatus();
      if (mounted) setState(() => _adStatus = status);
    } catch (_) {
      if (mounted) {
        setState(
          () => _adStatus = {
            'can_watch': false,
            'message': 'Ads are currently unavailable',
          },
        );
      }
    }
  }

  void _buyCoins() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => StoreInventoryScreen(
          apiClient: widget.apiClient,
          initialTabIndex: 1,
          onInventoryChanged: widget.onRewardClaimed,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _celebrationController.dispose();
    super.dispose();
  }

  void _startWatchingAd() {
    if (_adStatus?['can_watch'] != true || kReleaseMode) return;
    setState(() {
      _isPlayingAd = true;
      _secondsLeft = 5;
      _adCompleted = false;
    });

    AudioService.playRollHaptic();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
        AudioService.playMoveHaptic();
      } else {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _isPlayingAd = false;
          _adCompleted = true;
        });
        AudioService.playVictoryHaptic();
        _celebrationController.forward(from: 0);
      }
    });
  }

  Future<void> _claimReward() async {
    setState(() => _isClaiming = true);
    try {
      await widget.apiClient.claimWatchAdReward();
    } catch (_) {
      if (mounted) {
        setState(() => _isClaiming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rewarded ads are unavailable. Please try again later.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    widget.onRewardClaimed();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.stars, color: AppColors.gold),
              SizedBox(width: 8),
              Text('🎉 +500 Coins & +2 Gems added to your wallet!'),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_adStatus == null) {
      return const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (kReleaseMode || _adStatus?['can_watch'] != true) {
      return AlertDialog(
        title: const Text('Get more coins'),
        content: Text(
          '${_adStatus?['message'] ?? 'Ads are currently unavailable'}. Browse coin packs in the Store.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
          FilledButton.icon(
            onPressed: _buyCoins,
            icon: const Icon(Icons.shopping_bag),
            label: const Text('BUY COINS'),
          ),
        ],
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.video_library, color: AppColors.gold, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'EXTRA REWARDS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 0.8,
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
            const SizedBox(height: 12),

            if (!_isPlayingAd && !_adCompleted) ...[
              // Prompt to watch ad
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1F2937),
                      const Color(0xFF374151).withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.gold, width: 2),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: AppColors.gold,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Watch a Short Sponsor Clip',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Support Ludo Play and instantly unlock bonus currency for your matches!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRewardBadge(
                          Icons.monetization_on,
                          '+500 Coins',
                          AppColors.gold,
                        ),
                        const SizedBox(width: 12),
                        _buildRewardBadge(
                          Icons.diamond,
                          '+2 Gems',
                          const Color(0xFF38BDF8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.play_circle_fill,
                    color: Color(0xFF0F172A),
                  ),
                  label: const Text(
                    'WATCH AD (5s)',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _startWatchingAd,
                ),
              ),
            ] else if (_isPlayingAd) ...[
              // Simulated Video Ad Player
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: const Color(0xFF38BDF8),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.smart_display,
                          color: Color(0xFF38BDF8),
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'SPONSORED ADVERTISEMENT',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'LudoMaster Club Battle Royale Season',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          'Reward in ${_secondsLeft}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(14),
                        ),
                        child: LinearProgressIndicator(
                          value: (5 - _secondsLeft) / 5.0,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF38BDF8),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please wait for the ad clip to finish...',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ] else if (_adCompleted) ...[
              // Ad Completed - Claim Reward View
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '🎉 REWARD READY!',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildRewardBadge(
                            Icons.monetization_on,
                            '+500 Coins',
                            AppColors.gold,
                          ),
                          const SizedBox(width: 12),
                          _buildRewardBadge(
                            Icons.diamond,
                            '+2 Gems',
                            const Color(0xFF38BDF8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.card_giftcard,
                    color: Color(0xFF0F172A),
                  ),
                  label: _isClaiming
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'CLAIM NOW',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _isClaiming ? null : _claimReward,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRewardBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
