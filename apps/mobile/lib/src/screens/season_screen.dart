import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';

/// Screen presenting the Season Pass roadmap, XP progression, and Tier reward claims.
class SeasonScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const SeasonScreen({super.key, this.apiClient});

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen> {
  late final ApiClient _apiClient;
  SeasonDetailModel? _season;
  bool _isLoading = true;
  String? _errorMessage;
  int? _claimingTier;
  bool _isUnlocking = false;

  Future<void> _unlockPass() async {
    setState(() => _isUnlocking = true);
    try {
      await _apiClient.unlockPremiumPass();
      if (!mounted) return;
      await _loadSeason();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Royal Pass unlocked for this season!'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not unlock Royal Pass: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUnlocking = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _loadSeason();
  }

  Future<void> _loadSeason() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final season = await _apiClient.getCurrentSeason();
      if (!mounted) return;
      setState(() {
        _season = season;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _claimReward(int tierNumber, {required bool isPremium}) async {
    setState(() => _claimingTier = tierNumber);
    try {
      final res = await _apiClient.claimSeasonReward(
        tierNumber,
        isPremium: isPremium,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Claimed Tier $tierNumber: +${res.coinsAwarded} Coins, +${res.gemsAwarded} Gems!',
          ),
          backgroundColor: AppColors.green,
        ),
      );
      await _loadSeason();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to claim: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _claimingTier = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.military_tech, color: AppColors.gold),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Season Pass',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.goldLight),
            onPressed: _loadSeason,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : _errorMessage != null
          ? _buildErrorView()
          : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.red),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSeason,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              child: const Text('Retry', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final season = _season!;
    return RefreshIndicator(
      onRefresh: _loadSeason,
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSeasonBanner(season),
            const SizedBox(height: 16),
            _buildProgressCard(season),
            const SizedBox(height: 20),
            const Text(
              'TIER ROADMAP',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            ...season.tiers.map((tier) => _buildTierCard(tier, season)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonBanner(SeasonDetailModel season) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1C4D), Color(0xFF161E2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purpleLight.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.purpleLight.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  season.themeName.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.purpleLight,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ACTIVE SEASON',
                  style: TextStyle(
                    color: AppColors.greenLight,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            season.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Play matches to earn Season XP and unlock exclusive coins, gems, and cosmetics!',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          _buildPassStatusBanner(season),
        ],
      ),
    );
  }

  Widget _buildPassStatusBanner(SeasonDetailModel season) {
    if (season.hasPremiumPass) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.goldDark, AppColors.amber],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          runSpacing: 4,
          children: [
            Icon(Icons.star, color: Colors.black, size: 20),
            SizedBox(width: 8),
            Text(
              '★ Royal Pass Unlocked',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _isUnlocking ? null : _unlockPass,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 8,
          children: [
            const Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              runSpacing: 4,
              children: [
                Icon(Icons.workspace_premium, color: AppColors.gold, size: 20),
                SizedBox(width: 8),
                Text(
                  'Free Pass Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Text(
              _isUnlocking
                  ? 'Unlocking...'
                  : 'Unlock for ${season.premiumPassCostGems} Gems',
              style: const TextStyle(
                color: AppColors.goldLight,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(SeasonDetailModel season) {
    final nextTier = season.tiers
        .where((t) => t.xpRequired > season.currentXp)
        .firstOrNull;
    final maxTierXp =
        nextTier?.xpRequired ??
        (season.tiers.isNotEmpty ? season.tiers.last.xpRequired : 100);
    final progressRatio = (season.currentXp / maxTierXp).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 2,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'TIER ${season.currentTier}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${season.currentXp} XP Total',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              if (nextTier != null)
                Text(
                  'Next Tier: ${nextTier.xpRequired} XP',
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 10,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(SeasonTierModel tier, SeasonDetailModel season) {
    final isClaiming = _claimingTier == tier.tierNumber;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tier.isUnlocked
            ? AppColors.surfaceCard
            : AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tier.isUnlocked
              ? AppColors.gold.withValues(alpha: 0.4)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tier Number & Status
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 2,
                runSpacing: 4,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: tier.isUnlocked
                        ? AppColors.gold
                        : Colors.white12,
                    child: Text(
                      '${tier.tierNumber}',
                      style: TextStyle(
                        color: tier.isUnlocked ? Colors.black : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tier ${tier.tierNumber}',
                    style: TextStyle(
                      color: tier.isUnlocked ? Colors.white : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 2,
                runSpacing: 4,
                children: [
                  Icon(
                    tier.isUnlocked ? Icons.lock_open : Icons.lock,
                    size: 14,
                    color: tier.isUnlocked
                        ? AppColors.greenLight
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${tier.xpRequired} XP',
                    style: TextStyle(
                      color: tier.isUnlocked
                          ? AppColors.greenLight
                          : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Free Track
          _buildTrackRow(
            trackName: 'FREE TRACK',
            trackColor: AppColors.blueLight,
            coins: tier.freeRewardCoins,
            gems: tier.freeRewardGems,
            itemName: tier.freeRewardItemName,
            isUnlocked: tier.isUnlocked,
            isClaimed: tier.isFreeClaimed,
            canClaim: tier.isUnlocked && !tier.isFreeClaimed,
            isClaiming: isClaiming,
            onClaim: () => _claimReward(tier.tierNumber, isPremium: false),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          // Premium Track
          _buildTrackRow(
            trackName: 'ROYAL TRACK',
            trackColor: AppColors.gold,
            coins: tier.premiumRewardCoins,
            gems: tier.premiumRewardGems,
            itemName: tier.premiumRewardItemName,
            isUnlocked: tier.isUnlocked && season.hasPremiumPass,
            isClaimed: tier.isPremiumClaimed,
            canClaim:
                tier.isUnlocked &&
                season.hasPremiumPass &&
                !tier.isPremiumClaimed,
            isClaiming: isClaiming,
            onClaim: () => _claimReward(tier.tierNumber, isPremium: true),
            requiresPass: !season.hasPremiumPass,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackRow({
    required String trackName,
    required Color trackColor,
    required int coins,
    required int gems,
    required String? itemName,
    required bool isUnlocked,
    required bool isClaimed,
    required bool canClaim,
    required bool isClaiming,
    required VoidCallback onClaim,
    bool requiresPass = false,
  }) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 8,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: trackColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                trackName,
                style: TextStyle(
                  color: trackColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (coins > 0) ...[
              const Text('🪙', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 2),
              Text(
                '$coins',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (gems > 0) ...[
              const Text('💎', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 2),
              Text(
                '$gems',
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (itemName != null) ...[
              const Icon(Icons.palette, size: 12, color: AppColors.purpleLight),
              const SizedBox(width: 2),
              Text(
                itemName,
                style: const TextStyle(
                  color: AppColors.purpleLight,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        // Claim / Status Button
        if (isClaimed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              runSpacing: 4,
              children: [
                Icon(Icons.check, size: 12, color: AppColors.greenLight),
                SizedBox(width: 4),
                Text(
                  'Claimed',
                  style: TextStyle(
                    color: AppColors.greenLight,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        else if (canClaim)
          ElevatedButton(
            onPressed: isClaiming ? null : onClaim,
            style: ElevatedButton.styleFrom(
              backgroundColor: trackColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(60, 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: isClaiming
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text(
                    'CLAIM',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
          )
        else if (requiresPass)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Pass Req',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              runSpacing: 4,
              children: [
                Icon(Icons.lock, size: 10, color: Colors.white38),
                SizedBox(width: 4),
                Text(
                  'Locked',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
