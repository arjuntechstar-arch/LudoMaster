import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import 'online_game_screen.dart';

class MatchmakingScreen extends StatefulWidget {
  final ApiClient apiClient;

  const MatchmakingScreen({super.key, required this.apiClient});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  int _playerCount = 4;
  String _mode = 'CLASSIC';
  int _betCoins = 100;
  bool _isSearching = false;
  String? _ticketId;
  int _queueSeconds = 0;
  Timer? _timer;
  Timer? _pollTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
    _pulseController.dispose();
    if (_isSearching && _ticketId != null) {
      widget.apiClient.cancelMatchmakingTicket(_ticketId!).catchError((_) {});
    }
    super.dispose();
  }

  void _startSearching() async {
    setState(() {
      _isSearching = true;
      _queueSeconds = 0;
    });
    _pulseController.repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _queueSeconds++;
        });
      }
    });

    try {
      final ticket = await widget.apiClient.enqueueMatchmaking(
        mode: _mode,
        playerCount: _playerCount,
        betCoins: _betCoins,
      );

      if (!mounted) return;
      _ticketId = ticket.ticketId;

      if (ticket.status == 'MATCHED' && ticket.matchedMatchId != null) {
        _onMatchFound(ticket.matchedMatchId!);
        return;
      }

      // Poll every 1.5 seconds
      _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (
        t,
      ) async {
        if (!_isSearching || _ticketId == null || !mounted) {
          t.cancel();
          return;
        }

        try {
          final poll = await widget.apiClient.getMatchmakingTicket(_ticketId!);
          if (poll.status == 'MATCHED' && poll.matchedMatchId != null) {
            t.cancel();
            _onMatchFound(poll.matchedMatchId!);
          }
        } catch (e) {
          debugPrint('Matchmaking poll error: $e');
        }
      });
    } catch (e) {
      if (!mounted) return;
      _stopSearching();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to enter matchmaking: $e')),
      );
    }
  }

  void _stopSearching() {
    _timer?.cancel();
    _pollTimer?.cancel();
    _pulseController.stop();
    if (_ticketId != null) {
      widget.apiClient.cancelMatchmakingTicket(_ticketId!).catchError((_) {});
      _ticketId = null;
    }
    if (mounted) {
      setState(() {
        _isSearching = false;
        _queueSeconds = 0;
      });
    }
  }

  void _onMatchFound(String matchId) {
    _timer?.cancel();
    _pollTimer?.cancel();
    _pulseController.stop();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Match found! Connecting to arena...'),
        backgroundColor: AppColors.green,
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OnlineGameScreen(
          matchId: matchId,
          token: widget.apiClient.accessToken ?? '',
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('QUICK MATCHMAKING'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isSearching) {
              _stopSearching();
            }
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isSearching) ...[
                // Player Count Selector
                const Text(
                  'SELECT PLAYERS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [2, 4, 6].map((count) {
                    final isSelected = _playerCount == count;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () => setState(() => _playerCount = count),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (count == 6
                                        ? const Color(0xFF8B5CF6)
                                        : AppColors.gold)
                                  : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.cardBackgroundLight,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  count == 6
                                      ? Icons.hexagon
                                      : (count == 4
                                            ? Icons.groups
                                            : Icons.person),
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white70,
                                  size: 26,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$count Players',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                if (count == 6)
                                  Text(
                                    'HEXAGON',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.black87
                                          : const Color(0xFFC084FC),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Game Mode
                const Text(
                  'GAME MODE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        label: 'CLASSIC (4 Tokens)',
                        isSelected: _mode == 'CLASSIC',
                        onTap: () => setState(() => _mode = 'CLASSIC'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        label: 'QUICK (2 Tokens)',
                        isSelected: _mode == 'QUICK',
                        onTap: () => setState(() => _mode = 'QUICK'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        label: 'TEAM (2v2)',
                        isSelected: _mode == 'TEAM',
                        onTap: () => setState(() {
                          _mode = 'TEAM';
                          _playerCount = 4;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Bet Coins
                const Text(
                  'ENTRY BET',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [100, 500, 2000].map((coins) {
                    final isSelected = _betCoins == coins;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () => setState(() => _betCoins = coins),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.amber.withValues(alpha: 0.25)
                                  : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.gold
                                    : AppColors.cardBackgroundLight,
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.monetization_on,
                                  color: AppColors.gold,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$coins',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? AppColors.gold
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const Spacer(),

              // Search Animation Radar Area
              if (_isSearching) ...[
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated pulse circle 1
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, _) {
                          return Container(
                            width: 180 + (_pulseController.value * 60),
                            height: 180 + (_pulseController.value * 60),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.gold.withValues(
                                  alpha: (1.0 - _pulseController.value) * 0.4,
                                ),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),
                      // Animated pulse circle 2
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, _) {
                          final v = (_pulseController.value + 0.5) % 1.0;
                          return Container(
                            width: 140 + (v * 70),
                            height: 140 + (v * 70),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    (_playerCount == 6
                                            ? const Color(0xFF8B5CF6)
                                            : AppColors.blue)
                                        .withValues(alpha: (1.0 - v) * 0.5),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),
                      // Central Radar Core
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cardBackgroundLight,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _playerCount == 6 ? Icons.hexagon : Icons.radar,
                          color: _playerCount == 6
                              ? const Color(0xFFC084FC)
                              : AppColors.gold,
                          size: 48,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'FINDING FAIR OPPONENTS (${_playerCount}P)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Time Elapsed: ${_formatDuration(_queueSeconds)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Expanding skill band (±150 MMR)...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],

              const Spacer(),

              // Action Buttons
              if (!_isSearching)
                ElevatedButton(
                  onPressed: _startSearching,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _playerCount == 6
                        ? const Color(0xFF8B5CF6)
                        : AppColors.gold,
                    foregroundColor: _playerCount == 6
                        ? Colors.white
                        : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _playerCount == 6 ? Icons.hexagon : Icons.flash_on,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'FIND $_playerCount-PLAYER MATCH',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton(
                  onPressed: _stopSearching,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'CANCEL SEARCH',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.2)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.cardBackgroundLight,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isSelected ? AppColors.gold : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
