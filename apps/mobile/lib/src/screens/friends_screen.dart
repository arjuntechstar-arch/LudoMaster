import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/profile_avatar.dart';
import '../theme/app_colors.dart';
import '../widgets/report_user_dialog.dart';
import 'clubs_screen.dart';
import 'online_room_screen.dart';

class FriendsScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String? inviteRoomId;
  final int initialTabIndex;

  const FriendsScreen({
    super.key,
    required this.apiClient,
    this.inviteRoomId,
    this.initialTabIndex = 0,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<FriendModel> _friends = [];
  List<FriendRequestModel> _incomingRequests = [];
  List<FriendRequestModel> _outgoingRequests = [];
  List<BlockedUserModel> _blockedUsers = [];
  List<RoomInviteModel> _roomInvites = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3).toInt(),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final friends = await widget.apiClient.getFriends();
      final reqs = await widget.apiClient.getFriendRequests();
      final blocked = await widget.apiClient.getBlockedUsers();
      final roomInvites = await widget.apiClient.getMyRoomInvites();

      if (mounted) {
        setState(() {
          _friends = friends;
          _incomingRequests = reqs['incoming'] ?? [];
          _outgoingRequests = reqs['outgoing'] ?? [];
          _blockedUsers = blocked;
          _roomInvites = roomInvites;
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

  void _showAddFriendDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Add Friend by Username',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. @ludo_player',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final pid = controller.text.trim().toUpperCase();
              if (pid.isNotEmpty) {
                Navigator.of(ctx).pop();
                try {
                  await widget.apiClient.sendFriendRequest(
                    username: pid.replaceFirst('@', '').toLowerCase(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Friend request sent to $pid!'),
                        backgroundColor: AppColors.green,
                      ),
                    );
                    _loadAll();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: AppColors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('FRIENDS & SOCIAL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield, color: AppColors.gold),
            tooltip: 'Clubs & Social Rooms',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ClubsScreen(apiClient: widget.apiClient),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: AppColors.gold),
            tooltip: 'Add Friend',
            onPressed: _showAddFriendDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.gold,
          indicatorWeight: 3,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: 'FRIENDS (${_friends.length})'),
            Tab(text: 'REQUESTS (${_incomingRequests.length})'),
            Tab(text: 'BLOCKED (${_blockedUsers.length})'),
            Tab(text: 'INVITES (${_roomInvites.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Error: $_errorMessage',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadAll,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(),
                _buildRequestsTab(),
                _buildBlockedTab(),
                _buildRoomInvitesTab(),
              ],
            ),
    );
  }

  Widget _buildRoomInvitesTab() {
    if (_roomInvites.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAll,
        color: AppColors.gold,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.mail_outline,
                    color: AppColors.textSecondary,
                    size: 56,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No room invitations',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pull down to check for new invitations.',
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
      onRefresh: _loadAll,
      color: AppColors.gold,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _roomInvites.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final invite = _roomInvites[index];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x2238BDF8),
                child: Icon(Icons.sports_esports, color: Color(0xFF38BDF8)),
              ),
              title: Text(
                '${invite.senderName} invited you',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Room ${invite.roomCode ?? 'invite'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Accept and join room',
                    icon: const Icon(
                      Icons.check_circle,
                      color: AppColors.green,
                    ),
                    onPressed: () => _respondToRoomInvite(invite, accept: true),
                  ),
                  IconButton(
                    tooltip: 'Decline invitation',
                    icon: const Icon(Icons.cancel, color: AppColors.red),
                    onPressed: () =>
                        _respondToRoomInvite(invite, accept: false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _respondToRoomInvite(
    RoomInviteModel invite, {
    required bool accept,
  }) async {
    try {
      await widget.apiClient.respondToRoomInvite(invite.id, accept);
      if (!mounted) return;

      if (accept) {
        final room = await widget.apiClient.getRoom(invite.roomId);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OnlineRoomScreen(
              apiClient: widget.apiClient,
              initialRoom: room,
            ),
          ),
        );
      }

      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Could not join room: $e' : 'Could not decline invite: $e',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      await _loadAll();
    }
  }

  Widget _buildFriendsTab() {
    if (_friends.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAll,
        color: AppColors.gold,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.people_outline,
                    color: AppColors.textSecondary,
                    size: 64,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No friends added yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Add friends by their username!',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _showAddFriendDialog,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add a Friend'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.gold,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final f = _friends[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Stack(
                children: [
                  ProfileAvatar(avatarId: f.avatarId),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: f.isOnline
                            ? AppColors.green
                            : AppColors.textMuted,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surfaceCard,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                f.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                '${f.username == null ? '' : '@${f.username}'} • LVL ${f.level} • ${f.countryCode}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.inviteRoomId != null)
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await widget.apiClient.inviteToRoom(
                            widget.inviteRoomId!,
                            f.userId,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Invited ${f.displayName} to room!',
                                ),
                                backgroundColor: AppColors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invite failed: $e'),
                                backgroundColor: AppColors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Invite',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (val) async {
                      if (val == 'REMOVE') {
                        await widget.apiClient.removeFriend(f.userId);
                        _loadAll();
                      } else if (val == 'REPORT') {
                        ReportUserDialog.show(
                          context,
                          apiClient: widget.apiClient,
                          reportedUserId: f.userId,
                          reportedDisplayName: f.displayName,
                        ).then((_) => _loadAll());
                      } else if (val == 'BLOCK') {
                        await widget.apiClient.blockUser(f.userId);
                        _loadAll();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'REMOVE',
                        child: Text('Remove Friend'),
                      ),
                      const PopupMenuItem(
                        value: 'REPORT',
                        child: Text(
                          'Report User',
                          style: TextStyle(color: AppColors.red),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'BLOCK',
                        child: Text(
                          'Block User',
                          style: TextStyle(color: AppColors.red),
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

  Widget _buildRequestsTab() {
    if (_incomingRequests.isEmpty && _outgoingRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAll,
        color: AppColors.gold,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.mail_outline,
                    color: AppColors.textSecondary,
                    size: 64,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'No pending requests',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
      onRefresh: _loadAll,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_incomingRequests.isNotEmpty) ...[
            const Text(
              'INCOMING REQUESTS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            ..._incomingRequests.map(
              (r) => Card(
                child: ListTile(
                  leading: ProfileAvatar(avatarId: r.avatarId),
                  title: Text(
                    r.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    r.username == null ? 'Player' : '@${r.username}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle,
                          color: AppColors.green,
                        ),
                        tooltip: 'Accept',
                        onPressed: () async {
                          await widget.apiClient.acceptFriendRequest(r.id);
                          _loadAll();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: AppColors.red),
                        tooltip: 'Decline',
                        onPressed: () async {
                          await widget.apiClient.declineFriendRequest(r.id);
                          _loadAll();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_outgoingRequests.isNotEmpty) ...[
            const Text(
              'OUTGOING REQUESTS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            ..._outgoingRequests.map(
              (r) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surfaceElevated,
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white70,
                    ),
                  ),
                  title: Text(
                    r.displayName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    r.username == null ? 'Player' : '@${r.username}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Chip(
                    label: Text('Pending', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockedTab() {
    if (_blockedUsers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAll,
        color: AppColors.gold,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            const Center(
              child: Column(
                children: [
                  Icon(Icons.block, color: AppColors.textSecondary, size: 64),
                  SizedBox(height: 14),
                  Text(
                    'No blocked players',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
      onRefresh: _loadAll,
      color: AppColors.gold,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _blockedUsers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final b = _blockedUsers[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.block, color: AppColors.red),
              title: Text(
                b.blockedDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: TextButton(
                onPressed: () async {
                  await widget.apiClient.unblockUser(b.blockedId);
                  _loadAll();
                },
                child: const Text(
                  'Unblock',
                  style: TextStyle(color: AppColors.gold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
