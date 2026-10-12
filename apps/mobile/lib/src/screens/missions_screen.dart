import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';

class MissionsScreen extends StatefulWidget {
  final ApiClient apiClient;

  const MissionsScreen({super.key, required this.apiClient});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MissionModel> _missions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await widget.apiClient.getMissions();
      if (mounted) {
        setState(() {
          _missions = list;
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

  Future<void> _claimMission(String missionId) async {
    try {
      final res = await widget.apiClient.claimMission(missionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Claimed +${res.coinsAwarded} Coins, +${res.gemsAwarded} Gems, +${res.xpAwarded} XP!'),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
      await _loadMissions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to claim: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyMissions = _missions.where((m) => m.category == 'DAILY').toList();
    final weeklyMissions = _missions.where((m) => m.category == 'WEEKLY').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('MISSIONS & QUESTS'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'DAILY (${dailyMissions.where((m) => m.isCompleted && !m.isClaimed).length} READY)'),
            Tab(text: 'WEEKLY (${weeklyMissions.where((m) => m.isCompleted && !m.isClaimed).length} READY)'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_errorMessage', style: const TextStyle(color: Color(0xFFEF4444))),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadMissions, child: const Text('Retry')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMissionsList(dailyMissions),
                    _buildMissionsList(weeklyMissions),
                  ],
                ),
    );
  }

  Widget _buildMissionsList(List<MissionModel> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text('No active missions available.', style: TextStyle(color: Colors.white54)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMissions,
      color: AppColors.gold,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final m = list[index];
          final progress = (m.currentCount / m.targetCount).clamp(0.0, 1.0);
          final canClaim = m.isCompleted && !m.isClaimed;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: canClaim ? AppColors.gold : Colors.white12,
                width: canClaim ? 1.5 : 1.0,
              ),
              boxShadow: canClaim
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: canClaim ? AppColors.gold.withValues(alpha: 0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        m.isCompleted ? Icons.check_circle : Icons.sports_esports,
                        color: canClaim ? AppColors.gold : Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.description,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (canClaim)
                      ElevatedButton(
                        onPressed: () => _claimMission(m.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('CLAIM', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    else if (m.isClaimed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'COMPLETED',
                          style: TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            m.isCompleted ? const Color(0xFF22C55E) : AppColors.gold,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${m.currentCount} / ${m.targetCount}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (m.rewardCoins > 0) ...[
                      const Icon(Icons.monetization_on, color: AppColors.gold, size: 14),
                      const SizedBox(width: 4),
                      Text('+${m.rewardCoins}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(width: 10),
                    ],
                    if (m.rewardGems > 0) ...[
                      const Icon(Icons.diamond, color: Color(0xFF38BDF8), size: 14),
                      const SizedBox(width: 4),
                      Text('+${m.rewardGems}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(width: 10),
                    ],
                    const Icon(Icons.star, color: Color(0xFFA855F7), size: 14),
                    const SizedBox(width: 4),
                    Text('+${m.rewardXp} XP', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
