import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'online_game_screen.dart';
import '../theme/app_colors.dart';

/// Screen presenting the 8-Player Knockout Tournament Lobby & Visual Bracket
class TournamentScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const TournamentScreen({super.key, this.apiClient});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  late final ApiClient _apiClient;
  List<TournamentModel> _tournaments = [];
  TournamentDetailModel? _selectedDetail;
  String? _selectedTournamentId;
  String? _currentUserId;
  bool _isLoading = true;
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _apiClient.getTournaments();
      UserMeModel? me;
      try {
        me = await _apiClient.getMyAccount();
      } catch (_) {
        // The bracket can still be viewed while account details are unavailable.
      }
      if (!mounted) return;
      setState(() {
        _tournaments = list;
        _currentUserId = me?.id;
        if (_tournaments.isNotEmpty && _selectedTournamentId == null) {
          _selectedTournamentId = _tournaments.first.id;
        }
      });

      if (_selectedTournamentId != null) {
        await _loadTournamentDetails(_selectedTournamentId!);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTournamentDetails(String id) async {
    try {
      final detail = await _apiClient.getTournamentDetails(id);
      if (!mounted) return;
      setState(() {
        _selectedTournamentId = id;
        _selectedDetail = detail;
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

  Future<void> _joinTournament(TournamentModel tournament) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Join ${tournament.title}?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entry fee of ${tournament.entryFeeCoins} coins will be deducted from your wallet.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: AppColors.gold,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Prize Pool: ${tournament.prizePoolCoins} Coins + ${tournament.prizePoolGems} Gems',
                      style: const TextStyle(
                        color: AppColors.goldLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'JOIN NOW',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isJoining = true);
    try {
      final joinResult = await _apiClient.joinTournament(tournament.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(joinResult.message),
          backgroundColor: AppColors.green,
        ),
      );
      await _loadTournamentDetails(tournament.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
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
            Icon(Icons.emoji_events, color: AppColors.gold),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Tournaments',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.goldLight),
            onPressed: _loadTournaments,
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
              onPressed: _loadTournaments,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              child: const Text('Retry', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadTournaments,
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTournamentSelector(),
            const SizedBox(height: 16),
            if (_selectedDetail != null) ...[
              _buildTournamentInfoCard(_selectedDetail!.tournament),
              const SizedBox(height: 20),
              _buildVisualBracket(_selectedDetail!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentSelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tournaments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final t = _tournaments[index];
          final isSelected = t.id == _selectedTournamentId;
          return ChoiceChip(
            label: Text(
              t.title,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.gold,
            backgroundColor: AppColors.surfaceCard,
            onSelected: (val) {
              if (val) {
                _loadTournamentDetails(t.id);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildTournamentInfoCard(TournamentModel t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  t.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusPill(t.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatChip(
                icon: Icons.monetization_on,
                label: 'Entry',
                value: '${t.entryFeeCoins} Coins',
                color: AppColors.amber,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                icon: Icons.emoji_events,
                label: 'Pool',
                value: '${t.prizePoolCoins} C / ${t.prizePoolGems} G',
                color: AppColors.goldLight,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                icon: Icons.people,
                label: 'Players',
                value: '${t.currentParticipants}/${t.maxParticipants}',
                color: AppColors.blueLight,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildActionButton(t),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    String text;
    switch (status) {
      case 'REGISTRATION':
        bg = AppColors.green.withValues(alpha: 0.2);
        fg = AppColors.greenLight;
        text = 'OPEN';
        break;
      case 'IN_PROGRESS':
        bg = AppColors.amber.withValues(alpha: 0.2);
        fg = AppColors.yellowLight;
        text = 'IN PROGRESS';
        break;
      case 'COMPLETED':
        bg = Colors.purple.withValues(alpha: 0.2);
        fg = AppColors.purpleLight;
        text = 'FINISHED';
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.2);
        fg = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(TournamentModel t) {
    if (t.isJoined) {
      final playable = _selectedDetail?.matches
          .where(
            (match) =>
                match.status == 'IN_PROGRESS' &&
                match.matchId != null &&
                match.participantIds.contains(_currentUserId),
          )
          .firstOrNull;
      if (playable != null && _apiClient.accessToken != null) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OnlineGameScreen(
                    matchId: playable.matchId!,
                    token: _apiClient.accessToken!,
                    apiClient: _apiClient,
                  ),
                ),
              );
              if (mounted) await _loadTournaments();
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('PLAY CHAMPIONSHIP MATCH'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
          ),
        );
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.greenLight),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: AppColors.greenLight, size: 18),
              SizedBox(width: 8),
              Text(
                'You are Registered in this Tournament!',
                style: TextStyle(
                  color: AppColors.greenLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (t.status == 'REGISTRATION') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isJoining ? null : () => _joinTournament(t),
          icon: _isJoining
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Icon(Icons.add_circle, color: Colors.black, size: 18),
          label: Text(
            _isJoining ? 'JOINING...' : 'REGISTER (${t.entryFeeCoins} COINS)',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildVisualBracket(TournamentDetailModel detail) {
    final participantsMap = {for (var p in detail.participants) p.userId: p};
    final semi1 = detail.matches
        .where((m) => m.roundNumber == 1 && m.matchIndex == 0)
        .firstOrNull;
    final semi2 = detail.matches
        .where((m) => m.roundNumber == 1 && m.matchIndex == 1)
        .firstOrNull;
    final finalMatch = detail.matches
        .where((m) => m.roundNumber == 2)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TOURNAMENT BRACKET',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        // Bracket Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              // Round 1 Header
              _buildRoundHeader('ROUND 1: SEMIFINALS (2 Boards of 4)'),
              const SizedBox(height: 10),
              _buildMatchBoardCard(
                title: 'Semifinal Board A (Seeds 1, 3, 5, 7)',
                match: semi1,
                participantsMap: participantsMap,
                tag: 'Top 2 Advance',
              ),
              const SizedBox(height: 12),
              _buildMatchBoardCard(
                title: 'Semifinal Board B (Seeds 2, 4, 6, 8)',
                match: semi2,
                participantsMap: participantsMap,
                tag: 'Top 2 Advance',
              ),
              const SizedBox(height: 16),
              // Round 2 Header
              _buildRoundHeader('ROUND 2: GRAND FINAL (4 Finalists)'),
              const SizedBox(height: 10),
              _buildMatchBoardCard(
                title: 'Championship Board',
                match: finalMatch,
                participantsMap: participantsMap,
                tag: '1st: 60% • 2nd: 25% • 3rd: 15%',
                isFinal: true,
              ),
              const SizedBox(height: 14),
              // Trophy / Winner Spotlight
              if (detail.tournament.winnerUserId != null)
                _buildChampionSpotlight(
                  winnerId: detail.tournament.winnerUserId!,
                  participantsMap: participantsMap,
                  prizeCoins: (detail.tournament.prizePoolCoins * 0.6).round(),
                  prizeGems: (detail.tournament.prizePoolGems * 0.6).round(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoundHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: AppColors.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchBoardCard({
    required String title,
    required TournamentMatchModel? match,
    required Map<String, TournamentParticipantModel> participantsMap,
    required String tag,
    bool isFinal = false,
  }) {
    final status = match?.status ?? 'PENDING';
    final participantIds = match?.participantIds ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFinal ? AppColors.gold : Colors.white10,
          width: isFinal ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isFinal ? AppColors.goldLight : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 4 Player Slots
          Row(
            children: List.generate(4, (index) {
              final uid = index < participantIds.length
                  ? participantIds[index]
                  : null;
              final participant = uid != null ? participantsMap[uid] : null;
              final isWinner =
                  match != null && uid != null && match.winnerIds.contains(uid);

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isWinner
                        ? AppColors.green.withValues(alpha: 0.15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isWinner ? AppColors.greenLight : Colors.white12,
                    ),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isWinner
                            ? AppColors.gold
                            : AppColors.surfaceElevated,
                        child: Text(
                          participant != null
                              ? participant.displayName
                                    .substring(0, 1)
                                    .toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: isWinner ? Colors.black : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        participant?.displayName ?? 'TBD',
                        style: TextStyle(
                          color: isWinner
                              ? AppColors.greenLight
                              : Colors.white70,
                          fontSize: 10,
                          fontWeight: isWinner
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      if (isWinner)
                        const Text(
                          'Advancing',
                          style: TextStyle(
                            color: AppColors.greenLight,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Status: $status',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChampionSpotlight({
    required String winnerId,
    required Map<String, TournamentParticipantModel> participantsMap,
    required int prizeCoins,
    required int prizeGems,
  }) {
    final winner = participantsMap[winnerId];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.goldDark.withValues(alpha: 0.6),
            AppColors.amber.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, color: AppColors.gold, size: 40),
          const SizedBox(height: 4),
          const Text(
            'TOURNAMENT CHAMPION',
            style: TextStyle(
              color: AppColors.goldLight,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            winner?.displayName ?? 'Champion',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Awarded: 🪙 $prizeCoins Coins + 💎 $prizeGems Gems',
            style: const TextStyle(color: AppColors.goldLight, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
