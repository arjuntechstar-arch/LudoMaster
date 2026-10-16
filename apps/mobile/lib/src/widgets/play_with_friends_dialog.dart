import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/online_room_screen.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import 'mobile_ui.dart';

/// Interactive modal allowing players to play with friends based on username or Room Code.
class PlayWithFriendsDialog extends StatefulWidget {
  final ApiClient apiClient;
  final String myUsername;
  final VoidCallback onRefresh;

  const PlayWithFriendsDialog({
    super.key,
    required this.apiClient,
    required this.myUsername,
    required this.onRefresh,
  });

  @override
  State<PlayWithFriendsDialog> createState() => _PlayWithFriendsDialogState();
}

class _PlayWithFriendsDialogState extends State<PlayWithFriendsDialog> {
  final _inputController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  int _betCoins = 100;
  String _mode = 'CLASSIC';
  int _maxPlayers = 4;
  bool _fillWithBots = true;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _handleJoinOrCreate(bool isCreate) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (isCreate) {
        // Create Room
        final room = await widget.apiClient.createRoom(
          mode: _mode,
          maxPlayers: _maxPlayers,
          fillWithBots: _fillWithBots,
          betCoins: _betCoins,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OnlineRoomScreen(
              apiClient: widget.apiClient,
              initialRoom: room,
            ),
          ),
        );
      } else {
        // Join Friend by Room Code or @username
        final input = _inputController.text.trim();
        if (input.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Enter a room code, or @username to add a friend';
          });
          return;
        }

        if (input.startsWith('@')) {
          // Send friend request / invite by Player ID
          await widget.apiClient.sendFriendRequest(
            username: input.substring(1).toLowerCase(),
          );
          if (!mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎉 Friend request sent to $input! They can now invite you to rooms.',
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // Join by Room Code
          final room = await widget.apiClient.joinRoom(input.toUpperCase());
          if (!mounted) return;
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OnlineRoomScreen(
                apiClient: widget.apiClient,
                initialRoom: room,
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: const [
                    Icon(
                      Icons.groups_outlined,
                      color: AppColors.gold,
                      size: 26,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'PLAY WITH FRIENDS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect with friends using your username or Room Code.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Your Username Card with Copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR USERNAME',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.myUsername.isEmpty
                            ? 'Choose in your profile'
                            : '@${widget.myUsername}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: AppColors.gold, size: 20),
                  tooltip: 'Copy username',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.myUsername));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Your Unique Username copied! Share it with your friends.',
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Error display
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),

          // SECTION 1: JOIN BY FRIEND ID OR ROOM CODE
          const Text(
            'JOIN FRIEND\'S ROOM OR CONNECT',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter @username or Room Code',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                onPressed: _isLoading ? null : () => _handleJoinOrCreate(false),
                child: const Text(
                  'JOIN',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // DIVIDER
          Row(
            children: const [
              Expanded(child: Divider(color: Colors.white12)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OR',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
              Expanded(child: Divider(color: Colors.white12)),
            ],
          ),
          const SizedBox(height: 18),

          // SECTION 2: CREATE PRIVATE ROOM
          const Text(
            'HOST A PRIVATE ROOM',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _mode,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Game Mode',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'CLASSIC',
                      child: Text('Classic Ludo'),
                    ),
                    DropdownMenuItem(
                      value: 'QUICK',
                      child: Text('Quick (2 Tokens)'),
                    ),
                    DropdownMenuItem(value: 'TEAM', child: Text('Team 2v2')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _mode = val;
                        if (_mode == 'TEAM') _maxPlayers = 4;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _betCoins,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Entry Coins',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Free (0 🪙)')),
                    DropdownMenuItem(value: 100, child: Text('100 🪙')),
                    DropdownMenuItem(value: 500, child: Text('500 🪙')),
                    DropdownMenuItem(value: 2000, child: Text('2,000 🪙')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _betCoins = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _maxPlayers,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Player seats',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: (_mode == 'TEAM' ? [4] : [2, 3, 4, 5, 6])
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
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: _fillWithBots,
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _fillWithBots = value);
                      }
                    },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.gold,
              title: const Text(
                'Fill empty seats with bots',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: Text(
                _fillWithBots
                    ? 'Bots join open seats when the match starts.'
                    : 'Only your friends can fill seats.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF0F172A),
              ),
              label: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'CREATE PRIVATE ROOM',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
              onPressed: _isLoading ? null : () => _handleJoinOrCreate(true),
            ),
          ),
        ],
      ),
    );
  }
}
