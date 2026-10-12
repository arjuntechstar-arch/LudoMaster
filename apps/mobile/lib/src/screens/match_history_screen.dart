import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';

class MatchHistoryScreen extends StatefulWidget {
  final ApiClient apiClient;

  const MatchHistoryScreen({super.key, required this.apiClient});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingMatches = true;
  bool _isLoadingPlayers = true;
  List<MatchHistoryModel> _matches = [];
  List<RecentPlayerModel> _players = [];
  String? _errorMatches;
  String? _errorPlayers;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
    _loadPlayers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingMatches = true;
      _errorMatches = null;
    });
    try {
      final list = await widget.apiClient.getMyMatchHistory();
      if (mounted) {
        setState(() {
          _matches = list;
          _isLoadingMatches = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMatches = e.toString();
          _isLoadingMatches = false;
        });
      }
    }
  }

  Future<void> _loadPlayers() async {
    setState(() {
      _isLoadingPlayers = true;
      _errorPlayers = null;
    });
    try {
      final list = await widget.apiClient.getRecentPlayers();
      if (mounted) {
        setState(() {
          _players = list;
          _isLoadingPlayers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorPlayers = e.toString();
          _isLoadingPlayers = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('MATCH LOGS & PLAYERS'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          indicatorWeight: 3,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'MATCH HISTORY'),
            Tab(icon: Icon(Icons.people_outline), text: 'RECENT OPPONENTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMatchHistoryTab(), _buildRecentPlayersTab()],
      ),
    );
  }

  Widget _buildMatchHistoryTab() {
    if (_isLoadingMatches) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_errorMatches != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'Error: $_errorMatches',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadHistory, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_matches.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadHistory,
        color: AppColors.gold,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    color: AppColors.textSecondary,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No matches recorded yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Play quick or room matches to build your combat log!',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: AppColors.gold,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _matches.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final m = _matches[index];
          final isWin = m.myPlacement == 1;
          final coinsPositive = m.coinsDelta >= 0;

          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isWin
                    ? AppColors.gold.withValues(alpha: 0.6)
                    : AppColors.cardBackgroundLight,
                width: isWin ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isWin
                              ? AppColors.gold
                              : AppColors.cardBackgroundLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          m.myPlacement != null
                              ? _formatPlacement(m.myPlacement!)
                              : 'COMPLETED',
                          style: TextStyle(
                            color: isWin ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${m.mode} MATCH',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${coinsPositive ? '+' : ''}${m.coinsDelta} Coins',
                        style: TextStyle(
                          color: coinsPositive ? AppColors.gold : AppColors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Players in match row
                  Row(
                    children: [
                      const Text(
                        'Players:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          children: m.players.map((p) {
                            return Chip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: AppColors.cardBackgroundLight,
                              avatar: CircleAvatar(
                                backgroundColor: _getColorFromString(p.color),
                                radius: 8,
                              ),
                              label: Text(
                                p.displayName,
                                style: TextStyle(
                                  color: p.isBot
                                      ? AppColors.textSecondary
                                      : Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'XP Gained: +${m.xpGained} XP',
                        style: const TextStyle(
                          color: Color(0xFF60A5FA),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatTimestamp(m.startedAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentPlayersTab() {
    if (_isLoadingPlayers) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_errorPlayers != null) {
      return Center(
        child: Text(
          'Error: $_errorPlayers',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    if (_players.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPlayers,
        color: AppColors.gold,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.person_search_outlined,
                    color: AppColors.textSecondary,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No recent opponents',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Players you meet in online matches will appear here.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlayers,
      color: AppColors.gold,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _players.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final p = _players[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.surfaceElevated),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: AppColors.gold),
              ),
              title: Text(
                p.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                p.countryCode,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'LVL ${p.level}',
                  style: const TextStyle(
                    color: Color(0xFFC084FC),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatPlacement(int rank) {
    switch (rank) {
      case 1:
        return '🥇 1ST PLACE';
      case 2:
        return '🥈 2ND PLACE';
      case 3:
        return '🥉 3RD PLACE';
      default:
        return '${rank}TH PLACE';
    }
  }

  Color _getColorFromString(String name) {
    switch (name.toUpperCase()) {
      case 'RED':
        return AppColors.red;
      case 'GREEN':
        return AppColors.green;
      case 'YELLOW':
        return AppColors.amber;
      case 'BLUE':
        return AppColors.blue;
      case 'ORANGE':
        return const Color(0xFFF97316);
      case 'PURPLE':
        return const Color(0xFF9333EA);
      default:
        return AppColors.gold;
    }
  }

  String _formatTimestamp(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
