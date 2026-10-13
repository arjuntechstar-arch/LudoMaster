import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';

import '../controllers/game_controller.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_loader.dart';
import '../widgets/auth_dialog.dart';
import '../widgets/play_with_friends_dialog.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/watch_ad_reward_dialog.dart';
import 'achievements_screen.dart';
import 'clubs_screen.dart';
import 'daily_rewards_dialog.dart';
import 'friends_screen.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'match_history_screen.dart';
import 'matchmaking_screen.dart';
import 'missions_screen.dart';
import 'notifications_dialog.dart';
import 'online_room_screen.dart';
import 'profile_editor_screen.dart';
import 'season_screen.dart';
import 'setup_screen.dart';
import 'store_inventory_screen.dart';
import 'tournament_screen.dart';

class TabbedHomeScreen extends ConsumerStatefulWidget {
  const TabbedHomeScreen({super.key});

  @override
  ConsumerState<TabbedHomeScreen> createState() => _TabbedHomeScreenState();
}

class _TabbedHomeScreenState extends ConsumerState<TabbedHomeScreen> {
  final ApiClient _apiClient = ApiClient();
  UserMeModel? _account;
  DailyRewardStatusModel? _dailyReward;
  GameState? _savedGame;
  int _unreadNotifications = 0;
  int _roomInvites = 0;
  int _selectedIndex = 0;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshBadges(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait<void>([
      _loadAccount(),
      _loadSavedGame(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _ensureSession() async {
    final hasSession =
        _apiClient.accessToken != null || await _apiClient.restoreSession();
    if (!hasSession) await _apiClient.loginGuest();
  }

  Future<void> _loadAccount() async {
    try {
      await _ensureSession();
      final account = await _apiClient.getMyAccount();
      DailyRewardStatusModel? reward;
      try {
        reward = await _apiClient.getDailyRewardStatus();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _account = account;
        _dailyReward = reward;
      });
      await _refreshBadges();
    } catch (_) {
      // Keep the landing experience usable offline.
    }
  }

  Future<void> _refreshBadges() async {
    try {
      await _ensureSession();
      final notifications = await _apiClient.getNotifications();
      final invites = await _apiClient.getMyRoomInvites();
      if (!mounted) return;
      setState(() {
        _unreadNotifications = notifications.where((n) => !n.isRead).length;
        _roomInvites = invites.length;
      });
    } catch (_) {}
  }

  Future<void> _loadSavedGame() async {
    final game = await StorageService.loadActiveGame();
    if (mounted) setState(() => _savedGame = game);
  }

  Future<void> _openAuthenticated(Widget Function(ApiClient) builder) async {
    try {
      await _ensureSession();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => builder(_apiClient)),
      );
      await _loadAccount();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to connect: $error')),
      );
    }
  }

  void _openStore({int initialTab = 0}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => StoreInventoryScreen(
              apiClient: _apiClient,
              onInventoryChanged: _loadAccount,
              initialTabIndex: initialTab,
            ),
          ),
        )
        .then((_) => _loadAccount());
  }

  Future<void> _openProfile() async {
    final account = _account;
    if (account == null || account.profile.isGuest) {
      await showDialog<void>(
        context: context,
        builder: (_) => AuthDialog(
          apiClient: _apiClient,
          onAuthenticated: _loadAccount,
        ),
      );
      await _loadAccount();
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileEditorScreen(
          apiClient: _apiClient,
          profile: account.profile,
        ),
      ),
    );
    if (changed == true) await _loadAccount();
  }

  Future<void> _playOnline() => _openAuthenticated(
        (api) => MatchmakingScreen(apiClient: api),
      );

  Future<void> _openRoom() => _openAuthenticated(
        (api) => OnlineRoomScreen(apiClient: api),
      );

  void _playFriends() {
    final username = _account?.profile.username ?? '';
    showDialog<void>(
      context: context,
      builder: (_) => PlayWithFriendsDialog(
        apiClient: _apiClient,
        myUsername: username,
        onRefresh: _loadAccount,
      ),
    ).then((_) => _loadAccount());
  }

  void _resumeGame() {
    final game = _savedGame;
    if (game == null) return;
    ref.read(gameControllerProvider.notifier).resumeSavedGame(game);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const GameScreen()))
        .then((_) => _loadSavedGame());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _account == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: AppLoader(message: 'Preparing your lobby...'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  account: _account,
                  unreadNotifications: _unreadNotifications,
                  onProfileTap: _openProfile,
                  onNotificationsTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => NotificationsDialog(
                        apiClient: _apiClient,
                        onRefreshHome: _loadAccount,
                      ),
                    ).then((_) => _refreshBadges());
                  },
                  onWalletTap: () => _openStore(initialTab: 1),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      _buildHomeTab(),
                      _buildPlayTab(),
                      _buildProgressTab(),
                      _buildSocialTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.22),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_rounded),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryLight),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.sports_esports_rounded),
            selectedIcon: Icon(Icons.sports_esports_rounded, color: AppColors.primaryLight),
            label: 'Play',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _dailyReward?.canClaim ?? false,
              child: const Icon(Icons.auto_awesome_rounded),
            ),
            selectedIcon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _roomInvites > 0,
              label: Text('$_roomInvites'),
              child: const Icon(Icons.people_alt_rounded),
            ),
            selectedIcon: const Icon(Icons.people_alt_rounded, color: AppColors.primaryLight),
            label: 'Social',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final account = _account;
    final level = account?.profile.level ?? 1;
    final xp = account?.profile.xp ?? 0;
    final xpTarget = 100 * level + 50 * (level - 1) * (level - 1);
    final progress = (xp / (xpTarget <= 0 ? 1 : xpTarget)).clamp(0.0, 1.0);

    return _TabScroll(
      children: [
        _WelcomeCard(
          name: account?.profile.displayName ?? 'Player',
          level: level,
          progress: progress,
          onTap: _openProfile,
        ),
        const SizedBox(height: 18),
        if (_savedGame != null) ...[
          _ResumeCard(
            playerCount: _savedGame!.players.length,
            turn: _savedGame!.sequence,
            onTap: _resumeGame,
          ),
          const SizedBox(height: 18),
        ],
        _PrimaryPlayCard(
          onPlay: _playOnline,
          onFriends: _playFriends,
        ),
        const SizedBox(height: 24),
        const _SectionTitle(
          title: 'For you',
          subtitle: 'A few useful shortcuts, not every feature at once',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _MiniActionCard(
                icon: Icons.card_giftcard_rounded,
                title: 'Daily reward',
                subtitle: (_dailyReward?.canClaim ?? false)
                    ? 'Ready to claim'
                    : 'Come back tomorrow',
                color: AppColors.gold,
                badge: (_dailyReward?.canClaim ?? false) ? 'CLAIM' : null,
                onTap: () async {
                  await _ensureSession();
                  if (!mounted) return;
                  await DailyRewardsDialog.show(
                    context,
                    _apiClient,
                    onRewardClaimed: _loadAccount,
                  );
                  await _loadAccount();
                },
              ),
              _MiniActionCard(
                icon: Icons.flag_rounded,
                title: 'Missions',
                subtitle: 'Complete goals',
                color: AppColors.mint,
                onTap: () => _openAuthenticated(
                  (api) => MissionsScreen(apiClient: api),
                ),
              ),
              _MiniActionCard(
                icon: Icons.storefront_rounded,
                title: 'Store',
                subtitle: 'Boards & avatars',
                color: AppColors.cyan,
                onTap: () => _openStore(initialTab: 0),
              ),
              _MiniActionCard(
                icon: Icons.workspace_premium_rounded,
                title: 'Season',
                subtitle: 'Track your pass',
                color: AppColors.coral,
                onTap: () => _openAuthenticated(
                  (api) => SeasonScreen(apiClient: api),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayTab() => _TabScroll(
        children: [
          const _PageHeading(
            eyebrow: 'CHOOSE A MODE',
            title: 'How do you want to play?',
            subtitle: 'Jump into the right match without scrolling through the whole app.',
          ),
          const SizedBox(height: 22),
          _FeatureTile(
            icon: Icons.flash_on_rounded,
            title: 'Quick Match',
            subtitle: 'Fast online matchmaking for 2–6 players',
            color: AppColors.primary,
            badge: 'ONLINE',
            onTap: _playOnline,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SquareModeCard(
                  icon: Icons.smart_toy_rounded,
                  title: 'Vs Computer',
                  subtitle: 'Practice offline',
                  color: AppColors.blue,
                  onTap: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SetupScreen(isVsComputer: true),
                        ),
                      )
                      .then((_) => _loadSavedGame()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SquareModeCard(
                  icon: Icons.groups_2_rounded,
                  title: 'Pass & Play',
                  subtitle: 'Same device',
                  color: AppColors.mint,
                  onTap: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SetupScreen(isVsComputer: false),
                        ),
                      )
                      .then((_) => _loadSavedGame()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SquareModeCard(
                  icon: Icons.group_add_rounded,
                  title: 'Friends',
                  subtitle: 'Invite by username',
                  color: AppColors.coral,
                  onTap: _playFriends,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SquareModeCard(
                  icon: Icons.key_rounded,
                  title: 'Room Code',
                  subtitle: 'Create or join room',
                  color: AppColors.gold,
                  onTap: _openRoom,
                ),
              ),
            ],
          ),
        ],
      );

  Widget _buildProgressTab() => _TabScroll(
        children: [
          const _PageHeading(
            eyebrow: 'YOUR JOURNEY',
            title: 'Progress & rewards',
            subtitle: 'Challenges, achievements and competitive progression live here.',
          ),
          const SizedBox(height: 22),
          _FeatureTile(
            icon: Icons.card_giftcard_rounded,
            title: 'Daily Rewards',
            subtitle: (_dailyReward?.canClaim ?? false)
                ? 'Your reward is ready to claim'
                : 'Check your reward streak',
            color: AppColors.gold,
            badge: (_dailyReward?.canClaim ?? false) ? 'CLAIM' : null,
            onTap: () async {
              await _ensureSession();
              if (!mounted) return;
              await DailyRewardsDialog.show(
                context,
                _apiClient,
                onRewardClaimed: _loadAccount,
              );
              await _loadAccount();
            },
          ),
          const SizedBox(height: 12),
          _ListAction(
            icon: Icons.flag_rounded,
            title: 'Missions',
            subtitle: 'Daily and weekly objectives',
            color: AppColors.mint,
            onTap: () => _openAuthenticated((api) => MissionsScreen(apiClient: api)),
          ),
          _ListAction(
            icon: Icons.emoji_events_rounded,
            title: 'Achievements',
            subtitle: 'Badges and milestones',
            color: AppColors.purple,
            onTap: () => _openAuthenticated((api) => AchievementsScreen(apiClient: api)),
          ),
          _ListAction(
            icon: Icons.workspace_premium_rounded,
            title: 'Season Pass',
            subtitle: 'Season rewards and progression',
            color: AppColors.coral,
            onTap: () => _openAuthenticated((api) => SeasonScreen(apiClient: api)),
          ),
          _ListAction(
            icon: Icons.account_tree_rounded,
            title: 'Tournaments',
            subtitle: 'Enter competitive brackets',
            color: AppColors.gold,
            onTap: () => _openAuthenticated((api) => TournamentScreen(apiClient: api)),
          ),
          _ListAction(
            icon: Icons.leaderboard_rounded,
            title: 'Leaderboard',
            subtitle: 'See how you rank',
            color: AppColors.blue,
            onTap: () => _openAuthenticated((api) => LeaderboardScreen(apiClient: api)),
          ),
          _ListAction(
            icon: Icons.play_circle_fill_rounded,
            title: 'Reward Packs',
            subtitle: 'Watch an ad or collect bonus coins',
            color: AppColors.cyan,
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (_) => WatchAdRewardDialog(
                  apiClient: _apiClient,
                  onRewardClaimed: _loadAccount,
                ),
              ).then((_) => _loadAccount());
            },
          ),
          _ListAction(
            icon: Icons.storefront_rounded,
            title: 'Store & Inventory',
            subtitle: 'Customize your board and profile',
            color: AppColors.primaryLight,
            onTap: () => _openStore(initialTab: 0),
          ),
        ],
      );

  Widget _buildSocialTab() => _TabScroll(
        children: [
          const _PageHeading(
            eyebrow: 'COMMUNITY',
            title: 'Play together',
            subtitle: 'Friends, clubs and your match history are grouped in one place.',
          ),
          const SizedBox(height: 22),
          _FeatureTile(
            icon: Icons.people_alt_rounded,
            title: 'Friends & Invites',
            subtitle: _roomInvites > 0
                ? '$_roomInvites room invite${_roomInvites == 1 ? '' : 's'} waiting'
                : 'Find friends and manage invitations',
            color: AppColors.mint,
            badge: _roomInvites > 0 ? '$_roomInvites NEW' : null,
            onTap: () => _openAuthenticated((api) => FriendsScreen(apiClient: api)),
          ),
          const SizedBox(height: 12),
          _ListAction(
            icon: Icons.group_add_rounded,
            title: 'Play With Friends',
            subtitle: 'Invite by username or share a room',
            color: AppColors.coral,
            onTap: _playFriends,
          ),
          _ListAction(
            icon: Icons.shield_rounded,
            title: 'Clubs',
            subtitle: 'Build or join a community',
            color: AppColors.gold,
            onTap: () => _openAuthenticated((api) => ClubsScreen(apiClient: api)),
          ),
          _ListAction(
            icon: Icons.history_rounded,
            title: 'Match History',
            subtitle: 'Review recent games and results',
            color: AppColors.primaryLight,
            onTap: () => _openAuthenticated((api) => MatchHistoryScreen(apiClient: api)),
          ),
          _ListAction(
            icon: Icons.key_rounded,
            title: 'Online Rooms',
            subtitle: 'Create or join with a room code',
            color: AppColors.blue,
            onTap: _openRoom,
          ),
        ],
      );
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -110,
              right: -90,
              child: _GlowOrb(color: AppColors.primary, size: 260),
            ),
            Positioned(
              top: 300,
              left: -120,
              child: _GlowOrb(color: AppColors.cyan, size: 230),
            ),
          ],
        ),
      );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.16),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.account,
    required this.unreadNotifications,
    required this.onProfileTap,
    required this.onNotificationsTap,
    required this.onWalletTap,
  });

  final UserMeModel? account;
  final int unreadNotifications;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onWalletTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 10),
        child: Row(
          children: [
            const AppLogo(size: 38),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LUDOMASTER',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Play. Progress. Connect.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            _WalletPill(
              icon: Icons.monetization_on_rounded,
              value: account?.wallet.coins ?? 1000,
              color: AppColors.gold,
              onTap: onWalletTap,
            ),
            const SizedBox(width: 6),
            _RoundIconButton(
              icon: Icons.notifications_none_rounded,
              badge: unreadNotifications,
              onTap: onNotificationsTap,
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onProfileTap,
              child: ProfileAvatar(
                avatarId: account?.profile.avatarId ?? 'avatar_0',
                radius: 18,
              ),
            ),
          ],
        ),
      );
}

class _WalletPill extends StatelessWidget {
  const _WalletPill({
    required this.icon,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final int value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 4),
              Text(
                value > 9999 ? '${(value / 1000).toStringAsFixed(1)}k' : '$value',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.badge, required this.onTap});

  final IconData icon;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Badge(
        isLabelVisible: badge > 0,
        label: Text('$badge'),
        child: IconButton.filledTonal(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceCard,
            foregroundColor: AppColors.textPrimary,
          ),
        ),
      );
}

class _TabScroll extends StatelessWidget {
  const _TabScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
        children: children,
      );
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.name,
    required this.level,
    required this.progress,
    required this.onTap,
  });

  final String name;
  final int level;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceElevated,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('LEVEL', style: TextStyle(color: Colors.white70, fontSize: 8)),
                    Text(
                      '$level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _PrimaryPlayCard extends StatelessWidget {
  const _PrimaryPlayCard({required this.onPlay, required this.onFriends});

  final VoidCallback onPlay;
  final VoidCallback onFriends;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [Color(0xFF6D4AFF), Color(0xFF3D2CA8), Color(0xFF183D7A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'QUICK MATCH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Ready for a match?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Find players instantly or invite your crew.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.flash_on_rounded),
                    label: const Text('PLAY NOW'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4B34C4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: onFriends,
                  tooltip: 'Play with friends',
                  icon: const Icon(Icons.group_add_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(13),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.playerCount, required this.turn, required this.onTap});

  final int playerCount;
  final int turn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.mint.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.mint.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              const Icon(Icons.play_circle_fill_rounded, color: AppColors.mint, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Continue your game',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '$playerCount players • turn $turn',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.mint),
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      );
}

class _MiniActionCard extends StatelessWidget {
  const _MiniActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) => Container(
        width: 154,
        margin: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 24),
                    const Spacer(),
                    if (badge != null)
                      Text(
                        badge!,
                        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      );
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.eyebrow, required this.title, required this.subtitle});

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: AppColors.primaryLight,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      );
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.20), AppColors.surfaceCard],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 16),
            ],
          ),
        ),
      );
}

class _SquareModeCard extends StatelessWidget {
  const _SquareModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      );
}

class _ListAction extends StatelessWidget {
  const _ListAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          onTap: onTap,
          tileColor: AppColors.surfaceCard.withValues(alpha: 0.85),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ),
      );
}
