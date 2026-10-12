import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../widgets/voice_chat_controller_widget.dart';
import 'friends_screen.dart';
import 'online_game_screen.dart';

class OnlineRoomScreen extends StatefulWidget {
  final ApiClient apiClient;
  final RoomModel? initialRoom;

  const OnlineRoomScreen({
    super.key,
    required this.apiClient,
    this.initialRoom,
  });

  @override
  State<OnlineRoomScreen> createState() => _OnlineRoomScreenState();
}

class _OnlineRoomScreenState extends State<OnlineRoomScreen> {
  RoomModel? _room;
  bool _isLoading = false;
  String? _errorMessage;
  String _createMode = 'CLASSIC';
  int _maxPlayers = 4;
  bool _fillWithBots = true;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialRoom != null) {
      _room = widget.initialRoom;
      if (_room!.status == 'ACTIVE' && _room!.matchId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _launchGame(_room!.matchId!);
        });
      } else {
        _startPollingRoom(widget.initialRoom!.id);
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final room = await widget.apiClient.createRoom(
        mode: _createMode,
        maxPlayers: _maxPlayers,
        fillWithBots: _fillWithBots,
      );
      setState(() {
        _room = room;
        _isLoading = false;
      });
      _startPollingRoom(room.id);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _joinRoom(String code) async {
    if (code.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final room = await widget.apiClient.joinRoom(code);
      setState(() {
        _room = room;
        _isLoading = false;
      });
      _startPollingRoom(room.id);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startPollingRoom(String roomId) {
    // Poll room state every 2 seconds until match starts
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || _room == null) return false;

      try {
        final updated = await widget.apiClient.getRoom(roomId);
        if (!mounted) return false;

        setState(() {
          _room = updated;
        });

        if (updated.status == 'ACTIVE' && updated.matchId != null) {
          _launchGame(updated.matchId!);
          return false;
        }
      } catch (_) {}
      return mounted &&
          _room != null &&
          (_room!.status == 'WAITING' ||
              (_room!.status == 'ACTIVE' && _room!.matchId == null));
    });
  }

  Future<void> _toggleReady() async {
    if (_room == null) return;
    final myMember = _room!.members.firstWhere(
      (m) => m.userId == widget.apiClient.userId,
      orElse: () => _room!.members.first,
    );
    try {
      final updated = await widget.apiClient.toggleReady(
        _room!.id,
        !myMember.isReady,
      );
      if (!mounted) return;
      setState(() {
        _room = updated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _startMatch() async {
    if (_room == null) return;
    setState(() => _isLoading = true);

    try {
      final updated = await widget.apiClient.startRoomMatch(_room!.id);
      if (!mounted) return;
      if (updated.matchId != null) {
        _launchGame(updated.matchId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error starting: $e')));
    }
  }

  void _launchGame(String matchId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          matchId: matchId,
          token: widget.apiClient.accessToken!,
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Online Room',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _room == null ? _buildLobbySelection() : _buildRoomLobby(),
      ),
    );
  }

  Widget _buildLobbySelection() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.groups_rounded, size: 80, color: Color(0xFF38BDF8)),
          const SizedBox(height: 16),
          const Text(
            'Play With Friends',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a private room for 2–6 friends or join with a room code',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ],
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'CLASSIC', label: Text('Classic')),
              ButtonSegment(value: 'QUICK', label: Text('Quick')),
              ButtonSegment(value: 'TEAM', label: Text('2v2 Team')),
            ],
            selected: {_createMode},
            onSelectionChanged: (val) {
              setState(() {
                _createMode = val.first;
                if (_createMode == 'TEAM') _maxPlayers = 4;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _maxPlayers,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Player seats',
              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: (_createMode == 'TEAM' ? [4] : [2, 3, 4, 5, 6])
                .map<DropdownMenuItem<int>>(
                  (count) => DropdownMenuItem(
                    value: count,
                    child: Text('$count players'),
                  ),
                )
                .toList(),
            onChanged: _isLoading
                ? null
                : (count) {
                    if (count != null) setState(() => _maxPlayers = count);
                  },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Fill empty seats with bots',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _fillWithBots
                  ? 'Start with at least 2 people; bots fill open seats.'
                  : 'Wait until every seat is filled by a friend.',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            value: _fillWithBots,
            activeTrackColor: const Color(0xFF38BDF8),
            onChanged: _isLoading
                ? null
                : (value) => setState(() => _fillWithBots = value),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : _createRoom,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'CREATE ROOM',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _isLoading ? null : _showJoinDialog,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF38BDF8), width: 2),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'JOIN WITH CODE',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF38BDF8),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Enter Room Code',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            letterSpacing: 4,
          ),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: 'e.g. 7X9K2B',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF38BDF8)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _joinRoom(_codeController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomLobby() {
    final room = _room!;
    final isHost = room.hostUserId == widget.apiClient.userId;
    final hasEnoughPlayers =
        room.members.length >= 2 &&
        (room.fillWithBots || room.members.length == room.maxPlayers);
    final canStartMatch =
        hasEnoughPlayers && room.members.every((member) => member.isReady);
    final myMember = room.members.firstWhere(
      (m) => m.userId == widget.apiClient.userId,
      orElse: () => room.members.first,
    );

    final colors = room.maxPlayers == 2
        ? [const Color(0xFFEF4444), const Color(0xFFEAB308)]
        : [
            const Color(0xFFEF4444), // Red
            const Color(0xFF22C55E), // Green
            const Color(0xFFEAB308), // Yellow
            const Color(0xFF3B82F6), // Blue
            const Color(0xFFFF6B00), // Orange
            const Color(0xFFA855F7), // Purple
          ];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Room Code Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ROOM CODE',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.code,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: room.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Room code copied to clipboard!'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final shareText =
                        'Join my Ludo Master room. Open Play With Friends, tap JOIN WITH CODE, and enter ${room.code}.';
                    Clipboard.setData(ClipboardData(text: shareText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Room invitation copied to clipboard!'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text(
                    'Copy Invite',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FriendsScreen(
                          apiClient: widget.apiClient,
                          inviteRoomId: room.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text(
                    'Invite Friends',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!kReleaseMode) ...[
            VoiceChatControllerWidget(
              apiClient: widget.apiClient,
              roomId: room.id,
              roomMembers: room.members,
            ),
            const SizedBox(height: 16),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PLAYERS (${room.members.length}/${room.maxPlayers}) • ${room.mode} MODE${room.fillWithBots ? ' • BOTS ON' : ' • NO BOTS'}',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Room seats
          Expanded(
            child: ListView.separated(
              itemCount: room.maxPlayers,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                final member = room.members.firstWhere(
                  (m) => m.seatIndex == index,
                  orElse: () => RoomMemberModel(
                    id: '',
                    userId: '',
                    seatIndex: index,
                    isReady: false,
                    isHost: false,
                    displayName: '',
                    avatarId: '',
                    level: 1,
                  ),
                );

                final isOccupied = member.userId.isNotEmpty;
                final seatColor = colors[index % colors.length];

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isOccupied
                          ? seatColor.withValues(alpha: 0.6)
                          : Colors.white10,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: seatColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: seatColor, width: 2),
                        ),
                        child: Icon(
                          isOccupied ? Icons.person : Icons.person_outline,
                          color: seatColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOccupied
                                  ? member.displayName
                                  : room.fillWithBots
                                  ? 'Empty Seat (Bot Fill)'
                                  : 'Waiting for friend',
                              style: TextStyle(
                                color: isOccupied
                                    ? Colors.white
                                    : Colors.white38,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                if (isOccupied)
                                  Text(
                                    member.isHost
                                        ? 'Host'
                                        : (member.isReady
                                              ? 'Ready'
                                              : 'Not Ready'),
                                    style: TextStyle(
                                      color: member.isReady
                                          ? const Color(0xFF22C55E)
                                          : Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (room.mode == 'TEAM') ...[
                                  if (isOccupied) const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (index % 2 == 0)
                                          ? const Color(0xFFE65100)
                                          : const Color(0xFF0277BD),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'TEAM ${(index % 2) + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isOccupied && member.isReady)
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF22C55E),
                          size: 24,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Actions
          if (isHost)
            ElevatedButton(
              onPressed: _isLoading || !canStartMatch ? null : _startMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: canStartMatch
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF475569),
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _isLoading
                    ? 'STARTING…'
                    : room.members.length < 2
                    ? 'WAITING FOR PLAYER'
                    : !room.fillWithBots &&
                          room.members.length < room.maxPlayers
                    ? 'WAITING FOR ${room.maxPlayers - room.members.length} MORE'
                    : canStartMatch
                    ? 'START MATCH'
                    : 'WAITING FOR READY PLAYERS',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: _toggleReady,
              style: ElevatedButton.styleFrom(
                backgroundColor: myMember.isReady
                    ? Colors.orange
                    : const Color(0xFF2563EB),
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                myMember.isReady ? 'NOT READY' : 'I AM READY',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              widget.apiClient.leaveRoom(room.id);
              setState(() => _room = null);
            },
            child: const Text(
              'Leave Room',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }
}
