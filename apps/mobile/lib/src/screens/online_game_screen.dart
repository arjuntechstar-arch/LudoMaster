import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import '../board/dice_widget.dart';
import '../board/board_perspective.dart';
import '../board/funny_capture_overlay.dart';
import '../board/ludo_board_widget.dart';
import '../board/player_panel_widget.dart';
import '../controllers/online_match_controller.dart';
import '../services/api_client.dart';
import '../services/cosmetic_selection.dart';
import '../services/audio_service.dart';
import '../services/realtime_client.dart';
import '../services/runtime_config.dart';
import '../theme/app_colors.dart';
import '../widgets/report_user_dialog.dart';

class OnlineGameScreen extends StatefulWidget {
  final String matchId;
  final String token;
  final String? wsBaseUrl;
  final ApiClient? apiClient;

  const OnlineGameScreen({
    super.key,
    required this.matchId,
    required this.token,
    this.wsBaseUrl,
    this.apiClient,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  late final RealtimeClient _client;
  late final OnlineMatchController _controller;
  late final ApiClient _apiClient;
  VoidCallback? _removeListener;

  @override
  void initState() {
    super.initState();
    AudioService.startGameMusic();
    _apiClient = widget.apiClient ?? ApiClient();
    CosmeticSelection.refresh(_apiClient)
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((_) {});
    _client = RealtimeClient(
      wsBaseUrl: widget.wsBaseUrl ?? RuntimeConfig.realtimeBaseUrl,
      matchId: widget.matchId,
      token: widget.token,
    );
    _controller = OnlineMatchController(client: _client);
    _removeListener = _controller.addListener((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    AudioService.stopGameMusic();
    _removeListener?.call();
    _controller.dispose();
    super.dispose();
  }

  GameState _buildEngineGameState(OnlineMatchState state) {
    final colors = PlayerColor.values;
    final isSixPlayerMatch = state.seats.length > 4;

    final players = <PlayerState>[];
    final usedSeats = <int>{};
    final usedColors = <PlayerColor>{};
    for (int i = 0; i < state.seats.length; i++) {
      final seatMap = state.seats[i];
      final seat = seatMap['seatIndex'] as int? ?? i;
      final rawColor = (seatMap['color'] as String?)?.toLowerCase();
      final color = PlayerColor.values.firstWhere(
        (candidate) => candidate.name == rawColor,
        orElse: () => colors[seat % colors.length],
      );
      usedSeats.add(seat);
      usedColors.add(color);
      final rawTokens = (seatMap['tokens'] as List<dynamic>?) ?? [];

      final tokens = rawTokens.map((t) {
        final tMap = t as Map<String, dynamic>;
        final id = '${color.name}_${tMap['id']}';
        final loc = tMap['location'] as String? ?? 'YARD';
        final pos = tMap['position'] as int? ?? -1;

        TokenState tState = TokenState.yard;
        int? trackCell;
        int laneStep = 0;

        if (loc == 'TRACK') {
          tState = TokenState.track;
          trackCell = pos;
        } else if (loc == 'HOME_LANE') {
          tState = TokenState.homeLane;
          laneStep = pos + 1; // 1..5
        } else if (loc == 'HOME') {
          tState = TokenState.home;
        }

        return Token(
          id: id,
          color: color,
          state: tState,
          trackCell: trackCell,
          laneStep: laneStep,
          stepCount: tState == TokenState.track
              ? isSixPlayerMatch
                    ? ((pos - seat * 12 + 72) % 72)
                    : ((pos - color.startTrackCell + 52) % 52)
              : 0,
        );
      }).toList();

      players.add(
        PlayerState(
          id: seatMap['userId'] as String? ?? 'bot_$i',
          name: seatMap['displayName'] as String? ?? 'Player ${i + 1}',
          seat: seat,
          color: color,
          isBot: seatMap['isBot'] as bool? ?? false,
          tokens: tokens,
        ),
      );
    }

    // Add board-only placeholders for missing quadrants, using unused colors.
    final boardSeatCount = isSixPlayerMatch ? state.seats.length : 4;
    for (
      var seat = 0;
      seat < boardSeatCount && players.length < boardSeatCount;
      seat++
    ) {
      if (usedSeats.contains(seat)) continue;
      final c = colors.firstWhere(
        (color) => !usedColors.contains(color),
        orElse: () => colors[seat % colors.length],
      );
      usedSeats.add(seat);
      usedColors.add(c);
      players.add(
        PlayerState(
          id: 'bot_$seat',
          name: 'Player ${seat + 1}',
          seat: seat,
          color: c,
          isBot: true,
          tokens: [
            for (int t = 0; t < 4; t++)
              Token(id: '${c.name}_$t', color: c, state: TokenState.yard),
          ],
        ),
      );
    }

    GamePhase phase = GamePhase.rollRequired;
    if (state.isAnimating) {
      phase = GamePhase.resolving;
    } else if (state.phase == 'MOVE_REQUIRED') {
      phase = GamePhase.moveRequired;
    } else if (state.phase == 'FINISHED') {
      phase = GamePhase.finished;
    }

    final currSeat =
        (state.currentSeatIndex >= 0 && state.currentSeatIndex < players.length)
        ? state.currentSeatIndex
        : 0;

    final legalMoveOptions = state.legalMoves.map((m) {
      final tId = m['tokenId'] as int;
      final color = players
          .firstWhere((player) => player.seat == currSeat)
          .color;
      TokenState locationToState(Object? location) => switch (location) {
        'TRACK' => TokenState.track,
        'HOME_LANE' => TokenState.homeLane,
        'HOME' => TokenState.home,
        _ => TokenState.yard,
      };
      return MoveOption(
        tokenId: '${color.name}_$tId',
        color: color,
        fromState: locationToState(m['fromLocation']),
        toState: locationToState(m['toLocation']),
      );
    }).toList();

    return GameState(
      matchId: state.matchId,
      ruleset: const RulesetConfig(),
      status: state.isGameOver ? GameStatus.finished : GameStatus.inProgress,
      phase: phase,
      players: players,
      currentSeat: currSeat,
      diceValue: state.diceValue,
      legalMoves: legalMoveOptions,
    );
  }

  Widget _buildPlayerPanelStrip(
    List<PlayerState> players, {
    required bool compact,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final player in players)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: PlayerPanelWidget(
                  player: player,
                  isActiveTurn:
                      _controller.currentState.currentSeatIndex == player.seat,
                  tokensFinished: player.tokensInHome.length,
                  totalTokens: player.tokens.length,
                  compact: compact,
                  onTap: () => _showPlayerSafetyOptions(player.id, player.name),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showChatDialog() {
    final textController = TextEditingController();
    final presets = [
      'Good game!',
      'Well played!',
      'Hurry up!',
      'Nice move!',
      'Oops!',
      'Good luck!',
      'Thanks!',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Quick Chat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets
                  .map(
                    (p) => ActionChip(
                      label: Text(
                        p,
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF334155),
                      onPressed: () {
                        _controller.sendChat(p);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF38BDF8)),
                  onPressed: () {
                    if (textController.text.trim().isNotEmpty) {
                      _controller.sendChat(textController.text);
                      Navigator.of(ctx).pop();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPlayerSafetyOptions(String userId, String displayName) {
    if (userId.startsWith('bot_')) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.red),
              title: const Text(
                'Report Player',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Report harassment, cheating, or abusive chat',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                ReportUserDialog.show(
                  context,
                  apiClient: _apiClient,
                  reportedUserId: userId,
                  reportedDisplayName: displayName,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppColors.red),
              title: const Text(
                'Block Player',
                style: TextStyle(color: AppColors.red),
              ),
              subtitle: const Text(
                'Prevents future invites and chat messages',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await _apiClient.blockUser(userId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Blocked $displayName'),
                        backgroundColor: AppColors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to block: $e'),
                        backgroundColor: AppColors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMatchSafetySheet() {
    final state = _controller.currentState;
    final opponents = state.seats
        .where((s) => (s['isBot'] as bool? ?? false) == false)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Match Moderation & Safety',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select an opponent to report or block:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (opponents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No human opponents in this match.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              ...opponents.map((p) {
                final uid = p['userId'] as String? ?? '';
                final name = p['displayName'] as String? ?? 'Player';
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceElevated,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showPlayerSafetyOptions(uid, name);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.currentState;
    final engineState = _buildEngineGameState(state);
    final viewerPlayer = engineState.players.firstWhere(
      (player) => player.seat == state.mySeatIndex,
      orElse: () => engineState.players.first,
    );
    final viewerColor = viewerPlayer.color;
    final panels = [...engineState.players]
      ..sort(
        (a, b) => BoardPerspective.position(
          a.color,
          viewerColor,
        ).compareTo(BoardPerspective.position(b.color, viewerColor)),
      );
    final isSixPlayerMatch = engineState.players.length > 4;
    final displayPanels = isSixPlayerMatch
        ? panels
        : [panels[0], panels[1], panels[3], panels[2]];
    final topPanels = isSixPlayerMatch
        ? displayPanels.take(3).toList()
        : displayPanels.take(2).toList();
    final bottomPanels = isSixPlayerMatch
        ? displayPanels.skip(3).toList()
        : displayPanels.skip(2).take(2).toList();
    final activePlayer = engineState.players[engineState.currentSeat];

    // Check Game Over Dialog
    if (state.isGameOver && state.matchResults != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPodiumDialog(state.matchResults!);
      });
    }

    // Check for capture event in online match
    final captureData = state.latestCapture;
    String capturingName = 'Player';
    String capturedPlayerName = 'Opponent';
    if (captureData != null) {
      final bySeat =
          captureData['capturedBySeatIndex'] as int? ??
          captureData['capturingSeat'] as int?;
      final victimSeat =
          captureData['victimSeatIndex'] as int? ??
          captureData['victimSeat'] as int?;
      if (bySeat != null &&
          bySeat >= 0 &&
          bySeat < engineState.players.length) {
        capturingName = engineState.players[bySeat].name;
      }
      if (victimSeat != null &&
          victimSeat >= 0 &&
          victimSeat < engineState.players.length) {
        capturedPlayerName = engineState.players[victimSeat].name;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      // Connection Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                state.connectionStatus ==
                                    RealtimeConnectionStatus.connected
                                ? const Color(0xFF22C55E)
                                : Colors.orange,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 4,
                              backgroundColor:
                                  state.connectionStatus ==
                                      RealtimeConnectionStatus.connected
                                  ? const Color(0xFF22C55E)
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              state.connectionStatus ==
                                      RealtimeConnectionStatus.connected
                                  ? 'ONLINE'
                                  : 'RECONNECTING',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.shield_outlined,
                              color: Colors.white70,
                            ),
                            tooltip: 'Safety & Report',
                            onPressed: _showMatchSafetySheet,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white,
                            ),
                            tooltip: 'Chat',
                            onPressed: _showChatDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (state.phase == 'WAITING')
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Waiting for all players to join this match...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 13,
                      ),
                    ),
                  ),

                // Opponent Disconnect Notice Banner
                if (state.opponentNotice != null)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFEF4444),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.opponentNotice!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Player panels: three per side in six-player rooms.
                _buildPlayerPanelStrip(topPanels, compact: isSixPlayerMatch),

                // Centered Interactive Ludo Board
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: LudoBoardWidget(
                          gameState: engineState,
                          viewerColor: viewerColor,
                          interactionEnabled:
                              state.isMyTurn &&
                              !state.isAnimating &&
                              !state.requestPending,
                          boardThemeAssetKey: CosmeticSelection.boardTheme,
                          onTokenTapped: (rawTokenId) {
                            if (state.isMyTurn &&
                                state.phase == 'MOVE_REQUIRED') {
                              final parts = rawTokenId.split('_');
                              if (parts.length > 1) {
                                final id = int.tryParse(parts[1]);
                                if (id != null) {
                                  _controller.moveToken(id);
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                _buildPlayerPanelStrip(bottomPanels, compact: isSixPlayerMatch),

                // Emoji Reaction Bar
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ['👑', '🔥', '😎', '🎯', '😂', '🎲'].map((emoji) {
                      return InkWell(
                        onTap: () => _controller.sendEmoji(emoji),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Bottom Action Zone with Turn Timer and Bottom-Centered Dice Pedestal
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.getPlayerColor(
                                activePlayer.color,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.getPlayerColor(
                                    activePlayer.color,
                                  ).withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.isMyTurn
                                ? 'YOUR TURN'
                                : "${activePlayer.name}'S TURN",
                            style: TextStyle(
                              color: AppColors.getPlayerColor(
                                activePlayer.color,
                              ),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer,
                                size: 15,
                                color: state.remainingSeconds <= 5
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${state.remainingSeconds}s',
                                style: TextStyle(
                                  color: state.remainingSeconds <= 5
                                      ? const Color(0xFFEF4444)
                                      : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Prominent Bottom-Centered Dice Pedestal
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.getPlayerColor(activePlayer.color)
                                    .withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: DiceWidget(
                            diceSkinAssetKey: CosmeticSelection.diceSkin,
                            diceValue: state.diceValue,
                            canRoll:
                                state.isMyTurn &&
                                state.phase == 'ROLL_REQUIRED' &&
                                !state.isAnimating &&
                                !state.requestPending,
                            playerColor: activePlayer.color,
                            rollSequence: state.rollSequence,
                            remainingSeconds:
                                !state.isAnimating &&
                                    !state.requestPending &&
                                    (state.phase == 'ROLL_REQUIRED' ||
                                        state.phase == 'MOVE_REQUIRED')
                                ? state.remainingSeconds
                                : null,
                            onRoll: () => _controller.rollDice(),
                            onDisabledTap: () {
                              if (state.isMyTurn &&
                                  state.phase == 'MOVE_REQUIRED' &&
                                  state.legalMoves.isNotEmpty) {
                                if (state.legalMoves.length == 1 &&
                                    !state.isAnimating &&
                                    !state.requestPending) {
                                  final firstMove = state.legalMoves.first;
                                  final rawTokenId = firstMove['tokenId'];
                                  int? id;
                                  if (rawTokenId is int) {
                                    id = rawTokenId;
                                  } else if (rawTokenId is String) {
                                    final parts = rawTokenId.split('_');
                                    id = int.tryParse(
                                      parts.length > 1 ? parts[1] : rawTokenId,
                                    );
                                  }
                                  if (id != null) {
                                    _controller.moveToken(id);
                                    return;
                                  }
                                }
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Tap a highlighted token on the board to move!',
                                    ),
                                    duration: Duration(seconds: 3),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Funny Comic Cartoon Capture Animation Overlay
            if (captureData != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: Center(
                    child: FunnyCaptureOverlay(
                      capturingPlayerName: capturingName,
                      capturedPlayerName: capturedPlayerName,
                      onDismissed: () => _controller.clearCapture(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPodiumDialog(List<Map<String, dynamic>> results) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'MATCH FINISHED',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: results.map((r) {
            final rank = r['placement'] as int? ?? 1;
            final name = r['displayName'] as String? ?? 'Player';
            final coins = r['coinsDelta'] as int? ?? 0;
            final xp = r['xpGained'] as int? ?? 0;

            final medal = rank == 1
                ? '🥇'
                : (rank == 2 ? '🥈' : (rank == 3 ? '🥉' : '4th'));

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: rank == 1 ? const Color(0xFFEAB308) : Colors.white12,
                  width: rank == 1 ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(medal, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '+$xp XP',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    coins >= 0 ? '+$coins 🪙' : '$coins 🪙',
                    style: TextStyle(
                      color: coins >= 0
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Back to Home',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
