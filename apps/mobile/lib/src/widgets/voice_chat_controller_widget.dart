import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';

class VoiceChatControllerWidget extends StatefulWidget {
  final ApiClient apiClient;
  final String roomId;
  final List<RoomMemberModel> roomMembers;

  const VoiceChatControllerWidget({
    super.key,
    required this.apiClient,
    required this.roomId,
    required this.roomMembers,
  });

  @override
  State<VoiceChatControllerWidget> createState() =>
      _VoiceChatControllerWidgetState();
}

class _VoiceChatControllerWidgetState extends State<VoiceChatControllerWidget> {
  bool _isConnected = false;
  bool _isMicMuted = false;
  bool _isLoading = false;

  Future<void> _toggleVoiceConnection() async {
    if (_isConnected) {
      // Disconnect
      setState(() {
        _isConnected = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected from Voice Chat')),
      );
      return;
    }

    // Show privacy consent first
    final consentGranted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.mic, color: AppColors.gold),
            SizedBox(width: 8),
            Text(
              'Voice Chat & Privacy',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'To connect to voice chat in this room, audio will be streamed ephemerally between room members. '
          'No voice streams are permanently recorded. You can mute or report any player at any time.\n\n'
          'Do you consent to join voice chat?',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Decline',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Agree & Connect'),
          ),
        ],
      ),
    );

    if (consentGranted != true) return;

    setState(() => _isLoading = true);
    try {
      await widget.apiClient.getVoiceToken(
        roomId: widget.roomId,
        enableMic: true,
        privacyConsent: true,
      );
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isMicMuted = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to Voice Chat!'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice connection failed: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleMicMute() async {
    if (!_isConnected) return;
    final nextMute = !_isMicMuted;
    try {
      await widget.apiClient.setVoiceMute(
        roomId: widget.roomId,
        isMuted: nextMute,
      );
      setState(() => _isMicMuted = nextMute);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mute failed: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  void _showPlayerSafetySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.security, color: AppColors.gold, size: 20),
                SizedBox(width: 8),
                Text(
                  'Voice Safety & Moderation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a player to mute locally or report for voice harassment.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...widget.roomMembers.map((m) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF334155),
                  child: Text(
                    m.displayName.isNotEmpty
                        ? m.displayName[0].toUpperCase()
                        : 'P',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  m.displayName.isNotEmpty
                      ? m.displayName
                      : 'Player (Seat ${m.seatIndex + 1})',
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.volume_off,
                        color: Colors.orangeAccent,
                      ),
                      tooltip: 'Mute Player',
                      onPressed: () async {
                        await widget.apiClient.setVoiceMute(
                          roomId: widget.roomId,
                          targetUserId: m.userId,
                          isMuted: true,
                        );
                        if (mounted && ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Muted ${m.displayName}')),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.report, color: AppColors.red),
                      tooltip: 'Report Voice Abuse',
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        _reportPlayer(m);
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _reportPlayer(RoomMemberModel member) {
    final reasonCtrl = TextEditingController(
      text: 'Abusive language in voice chat',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Report ${member.displayName}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Provide details for the automated moderation safety system.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await widget.apiClient.reportVoiceAbuse(
                  roomId: widget.roomId,
                  reportedUserId: member.userId,
                  reason: reasonCtrl.text.trim(),
                );
                if (mounted && ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Report submitted. Thank you for keeping LudoMaster safe.',
                      ),
                      backgroundColor: AppColors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Report failed: $e'),
                      backgroundColor: AppColors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text(
              'Submit Report',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isConnected
              ? AppColors.green.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Voice Connection Toggle Button
          InkWell(
            onTap: _isLoading ? null : _toggleVoiceConnection,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isConnected
                    ? AppColors.green.withValues(alpha: 0.2)
                    : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isConnected ? AppColors.green : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.headset_mic : Icons.headset_off,
                    color: _isConnected
                        ? AppColors.green
                        : const Color(0xFF94A3B8),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isLoading
                        ? 'Connecting...'
                        : _isConnected
                        ? 'Voice On'
                        : 'Join Voice',
                    style: TextStyle(
                      color: _isConnected ? AppColors.green : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Mic Mute Button (if connected)
          if (_isConnected) ...[
            IconButton(
              icon: Icon(
                _isMicMuted ? Icons.mic_off : Icons.mic,
                color: _isMicMuted ? AppColors.red : AppColors.green,
                size: 20,
              ),
              tooltip: _isMicMuted ? 'Unmute Mic' : 'Mute Mic',
              onPressed: _toggleMicMute,
            ),
            const SizedBox(width: 4),
            // Audio wave indicator
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 3,
                    height: _isMicMuted
                        ? 4
                        : (8 + (i % 2 == 0 ? 8 : 4)).toDouble(),
                    decoration: BoxDecoration(
                      color: _isMicMuted
                          ? const Color(0xFF64748B)
                          : AppColors.green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ] else ...[
            const Spacer(),
          ],

          // Voice Safety / Mute Others Action
          IconButton(
            icon: const Icon(
              Icons.shield_outlined,
              color: AppColors.gold,
              size: 20,
            ),
            tooltip: 'Voice Safety & Mute Options',
            onPressed: _showPlayerSafetySheet,
          ),
        ],
      ),
    );
  }
}
