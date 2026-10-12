import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';

/// Screen displaying global and seasonal rankings, Top 3 Podium, and user's rank.
class LeaderboardScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const LeaderboardScreen({super.key, this.apiClient});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final ApiClient _apiClient;
  late final TabController _tabController;

  final List<String> _scopes = ['WEEKLY', 'SEASONAL', 'ALL_TIME'];
  final List<String> _scopeLabels = ['Weekly', 'Seasonal', 'All-Time'];

  LeaderboardModel? _leaderboard;
  MyLeaderboardRankModel? _myRank;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _tabController = TabController(length: _scopes.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadLeaderboard();
      }
    });
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentScope = _scopes[_tabController.index];
    try {
      final lbFuture = _apiClient.getLeaderboard(scope: currentScope, limit: 50);
      final rankFuture = _apiClient.getMyLeaderboardRank(scope: currentScope);

      final results = await Future.wait([lbFuture, rankFuture]);
      if (!mounted) return;

      setState(() {
        _leaderboard = results[0] as LeaderboardModel;
        _myRank = results[1] as MyLeaderboardRankModel;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.leaderboard, color: AppColors.gold),
            SizedBox(width: 8),
            Text(
              'Hall of Fame',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          indicatorWeight: 3,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: _scopeLabels.map((l) => Tab(text: l)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.goldLight),
            onPressed: _loadLeaderboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContent(),
      bottomNavigationBar: _myRank != null ? _buildMyRankBottomBar() : null,
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
              onPressed: _loadLeaderboard,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              child: const Text('Retry', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final entries = _leaderboard?.entries ?? [];
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'No rankings recorded yet for this period.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLeaderboard,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              child: const Text('Refresh', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }

    final top3 = entries.take(3).toList();
    final remaining = entries.skip(3).toList();

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceCard,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: _buildPodium(top3),
            ),
          ),
          if (remaining.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'TOP CONTENDERS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = remaining[index];
                  return _buildLeaderboardRow(entry);
                },
                childCount: remaining.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntryModel> top3) {
    LeaderboardEntryModel? first = top3.isNotEmpty ? top3[0] : null;
    LeaderboardEntryModel? second = top3.length > 1 ? top3[1] : null;
    LeaderboardEntryModel? third = top3.length > 2 ? top3[2] : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 2nd Place (Silver)
              Expanded(
                child: second != null
                    ? _buildPodiumStep(
                        entry: second,
                        rank: 2,
                        podiumHeight: 90,
                        medalColor: const Color(0xFFC0C0C0),
                        medalIcon: '🥈',
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              // 1st Place (Gold)
              Expanded(
                child: first != null
                    ? _buildPodiumStep(
                        entry: first,
                        rank: 1,
                        podiumHeight: 120,
                        medalColor: AppColors.gold,
                        medalIcon: '👑',
                        isChampion: true,
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              // 3rd Place (Bronze)
              Expanded(
                child: third != null
                    ? _buildPodiumStep(
                        entry: third,
                        rank: 3,
                        podiumHeight: 70,
                        medalColor: const Color(0xFFCD7F32),
                        medalIcon: '🥉',
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumStep({
    required LeaderboardEntryModel entry,
    required int rank,
    required double podiumHeight,
    required Color medalColor,
    required String medalIcon,
    bool isChampion = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medalIcon, style: TextStyle(fontSize: isChampion ? 24 : 18)),
        const SizedBox(height: 2),
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: isChampion ? 28 : 22,
              backgroundColor: medalColor,
              child: CircleAvatar(
                radius: isChampion ? 25 : 19,
                backgroundColor: AppColors.surface,
                child: Text(
                  entry.displayName.isNotEmpty
                      ? entry.displayName.substring(0, 1).toUpperCase()
                      : 'P',
                  style: TextStyle(
                    color: medalColor,
                    fontSize: isChampion ? 18 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: medalColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          entry.displayName,
          style: TextStyle(
            color: isChampion ? AppColors.goldLight : Colors.white,
            fontSize: isChampion ? 13 : 11,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          '${entry.score} pts',
          style: TextStyle(
            color: medalColor,
            fontSize: isChampion ? 12 : 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        // Podium Box
        Container(
          width: double.infinity,
          height: podiumHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                medalColor.withValues(alpha: 0.35),
                medalColor.withValues(alpha: 0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: medalColor.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: TextStyle(
                  color: medalColor,
                  fontSize: isChampion ? 22 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Lv.${entry.level}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardRow(LeaderboardEntryModel entry) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Rank Badge
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.rank}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceElevated,
            child: Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName.substring(0, 1).toUpperCase()
                  : 'P',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          // Name & Country
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Lv.${entry.level}',
                        style: const TextStyle(color: AppColors.goldLight, fontSize: 9),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${entry.matchesWon} wins • ${entry.winRate}% win rate',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'points',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyRankBottomBar() {
    final rank = _myRank!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                rank.rank == 0 ? 'UNRANKED' : '#${rank.rank}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Rank This Period',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${rank.matchesWon} wins / ${rank.matchesPlayed} matches',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${rank.score} PTS',
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  rank.scope,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
