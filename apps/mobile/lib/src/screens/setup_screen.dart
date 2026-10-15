import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/game_controller.dart';
import '../theme/app_colors.dart';
import 'game_screen.dart';

/// Screen allowing players to configure player counts, rules, and bot difficulty before starting.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key, required this.isVsComputer});

  final bool isVsComputer;

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

enum SetupGameMode { classic, quick, team }

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _playerCount = 4;
  SetupGameMode _mode = SetupGameMode.classic;
  BotDifficulty _difficulty = BotDifficulty.hard;
  PlayerColor _humanColor = PlayerColor.red;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isVsComputer ? 'VS COMPUTER' : 'PASS & PLAY'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    _buildSectionHeader('Game Mode'),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<SetupGameMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: SetupGameMode.classic,
                            label: Text('Classic'),
                            icon: Icon(Icons.casino),
                          ),
                          ButtonSegment(
                            value: SetupGameMode.quick,
                            label: Text('Quick'),
                            icon: Icon(Icons.flash_on),
                          ),
                          ButtonSegment(
                            value: SetupGameMode.team,
                            label: Text('2v2 Team'),
                            icon: Icon(Icons.group),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (val) {
                          setState(() {
                            _mode = val.first;
                            if (_mode == SetupGameMode.team) {
                              _playerCount = 4;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: AppColors.surfaceCard,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              _mode == SetupGameMode.team
                                  ? Icons.groups
                                  : _mode == SetupGameMode.quick
                                  ? Icons.bolt
                                  : Icons.sports_esports,
                              color: AppColors.gold,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _mode == SetupGameMode.team
                                    ? '2v2 Team Mode: Team 1 (Red & Yellow) vs Team 2 (Green & Blue). Stack with partner & help partner finish!'
                                    : _mode == SetupGameMode.quick
                                    ? 'Quick Mode: 2 tokens per player. Must capture an opponent before entering home lane!'
                                    : 'Classic Ludo: 4 tokens per player, standard international rules.',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_mode != SetupGameMode.team) ...[
                      _buildSectionHeader('Number of Players'),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 2, label: Text('2 Players')),
                            ButtonSegment(value: 3, label: Text('3 Players')),
                            ButtonSegment(value: 4, label: Text('4 Players')),
                          ],
                          selected: {_playerCount},
                          onSelectionChanged: (val) {
                            setState(() => _playerCount = val.first);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (widget.isVsComputer) ...[
                      _buildSectionHeader('Your Color'),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        spacing: 10,
                        runSpacing: 10,
                        children: PlayerColor.values.take(4).map((color) {
                          final isSelected = _humanColor == color;
                          final pColor = AppColors.getPlayerColor(color);

                          return GestureDetector(
                            onTap: () => setState(() => _humanColor = color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: pColor,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 3.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: pColor.withValues(alpha: 0.7),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      _buildSectionHeader('Bot Difficulty'),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<BotDifficulty>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: BotDifficulty.easy,
                              label: Text('Easy'),
                            ),
                            ButtonSegment(
                              value: BotDifficulty.medium,
                              label: Text('Medium'),
                            ),
                            ButtonSegment(
                              value: BotDifficulty.hard,
                              label: Text('Hard'),
                            ),
                          ],
                          selected: {_difficulty},
                          onSelectionChanged: (val) {
                            setState(() => _difficulty = val.first);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _startMatch,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'START MATCH',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.gold,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Future<void> _startMatch() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final displayName = prefs.getString('display_name') ?? 'You';
    final RulesetConfig ruleset;
    switch (_mode) {
      case SetupGameMode.classic:
        ruleset = RulesetConfig.classic;
        break;
      case SetupGameMode.quick:
        ruleset = RulesetConfig.quick;
        break;
      case SetupGameMode.team:
        ruleset = RulesetConfig.team;
        break;
    }

    final players = <PlayerState>[];

    final allColors = [
      PlayerColor.red,
      PlayerColor.green,
      PlayerColor.yellow,
      PlayerColor.blue,
    ];

    if (_mode == SetupGameMode.team) {
      for (final c in allColors) {
        final seat = c.seatIndex;
        final teamId = (seat % 2 == 0) ? 0 : 1;
        final isHuman = widget.isVsComputer && c == _humanColor;
        final isPassAndPlay = !widget.isVsComputer;

        final String name;
        if (isHuman) {
          name = '$displayName (Team ${teamId + 1})';
        } else if (isPassAndPlay) {
          name =
              'Player ${seat + 1} (Team ${teamId + 1} - ${c.name.toUpperCase()})';
        } else {
          final isTeammate = teamId == (_humanColor.seatIndex % 2);
          name = isTeammate
              ? 'Teammate (${c.name.toUpperCase()})'
              : 'Opponent (${c.name.toUpperCase()})';
        }

        players.add(
          PlayerState(
            id: isHuman ? 'human_player' : 'bot_${c.name}',
            name: name,
            seat: seat,
            color: c,
            teamId: teamId,
            isBot: widget.isVsComputer ? !isHuman : false,
            tokens: const [],
          ),
        );
      }
    } else if (widget.isVsComputer) {
      final opponentColor = PlayerColor.values[(_humanColor.index + 2) % 4];
      final otherColors = allColors.where((c) => c != _humanColor).toList();
      final selectedColors = [
        _humanColor,
        if (_playerCount == 2) opponentColor else ...otherColors,
      ].take(_playerCount).toList();

      for (var i = 0; i < selectedColors.length; i++) {
        final c = selectedColors[i];
        final isHuman = c == _humanColor;
        players.add(
          PlayerState(
            id: isHuman ? 'human_player' : 'bot_${c.name}',
            name: isHuman ? displayName : 'Bot ${c.name.toUpperCase()}',
            seat: i,
            color: c,
            isBot: !isHuman,
            tokens: const [],
          ),
        );
      }
    } else {
      final selectedColors = _playerCount == 2
          ? [PlayerColor.red, PlayerColor.yellow]
          : allColors.take(_playerCount).toList();
      for (var i = 0; i < selectedColors.length; i++) {
        final c = selectedColors[i];
        players.add(
          PlayerState(
            id: 'player_${c.name}',
            name: i == 0
                ? displayName
                : 'Player ${i + 1} (${c.name.toUpperCase()})',
            seat: i,
            color: c,
            isBot: false,
            tokens: const [],
          ),
        );
      }
    }

    players.sort((a, b) => a.seat.compareTo(b.seat));

    ref
        .read(gameControllerProvider.notifier)
        .startNewGame(
          players: players,
          ruleset: ruleset,
          botDifficulty: _difficulty,
        );

    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const GameScreen()));
  }
}
