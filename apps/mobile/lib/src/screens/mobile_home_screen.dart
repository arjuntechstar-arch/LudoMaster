import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/game_symbol.dart';
import '../widgets/royal_ui.dart';
import '../widgets/event_showcase.dart';
import '../widgets/arena_hero.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';

import '../controllers/game_controller.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/mobile_ui.dart';
import 'settings_screen.dart';
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

class MobileHomeScreen extends ConsumerStatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  ConsumerState<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends ConsumerState<MobileHomeScreen> {
  final ApiClient _apiClient = ApiClient();
  UserMeModel? _account;
  DailyRewardStatusModel? _dailyReward;
  GameState? _savedGame;
  int _unreadNotifications = 0;
  int _roomInvites = 0;
  int _selectedIndex = 0;
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
    await Future.wait<void>([_loadAccount(), _loadSavedGame()]);
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
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => builder(_apiClient)));
      await _loadAccount();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to connect: $error')));
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
        builder: (_) =>
            AuthDialog(apiClient: _apiClient, onAuthenticated: _loadAccount),
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

  Future<void> _playOnline() =>
      _openAuthenticated((api) => MatchmakingScreen(apiClient: api));

  Future<void> _openRoom() =>
      _openAuthenticated((api) => OnlineRoomScreen(apiClient: api));

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

  Future<void> _daily() async {
    try {
      await _ensureSession();
      if (!mounted) return;
      await DailyRewardsDialog.show(
        context,
        _apiClient,
        onRewardClaimed: _loadAccount,
      );
      await _loadAccount();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rewards are unavailable right now. Please try again.',
            ),
          ),
        );
      }
    }
  }

  void _local(bool computer) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => SetupScreen(isVsComputer: computer),
          ),
        )
        .then((_) => _loadSavedGame());
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_home(), _play(), _rewards(), _social()];
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _openProfile,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ProfileAvatar(
                  avatarId: _account?.profile.avatarId ?? 'avatar_0',
                  radius: 18,
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          'LUDO PLAY',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Store and wallet',
            onPressed: () => _openStore(),
            icon: const GameSymbol(Icons.storefront_outlined),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => NotificationsDialog(
                apiClient: _apiClient,
                onRefreshHome: _loadAccount,
              ),
            ),
            icon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              child: const GameSymbol(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RoyalBackdrop(
        child: SafeArea(bottom: false, child: pages[_selectedIndex]),
      ),
      bottomNavigationBar: RoyalNavigation(
        selected: [0, 2, 1, 4][_selectedIndex],
        onSelect: (index) {
          if (index == 3) {
            _openStore(initialTab: 2);
            return;
          }
          setState(() => _selectedIndex = [0, 2, 1, 0, 3][index]);
        },
      ),
    );
  }

  Widget _home() => MobilePageBody(
    key: const ValueKey('home-tab'),
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _balance(
            Icons.diamond_outlined,
            '${_account?.wallet.gems ?? 0}',
            AppColors.cyan,
          ),
          _balance(
            Icons.monetization_on_outlined,
            '${_account?.wallet.coins ?? 0}',
            AppColors.gold,
          ),
        ],
      ),
      const SizedBox(height: 20),
      ArenaHero(
        onPlay: _playOnline,
        name: _account?.profile.displayName ?? 'Player',
      ),
      const SizedBox(height: 24),
      const MobileSection('Choose your kind of fun'),
      Row(
        children: [
          Expanded(
            child: RoyalMode(
              label: 'Online',
              icon: Icons.public_rounded,
              onTap: _playOnline,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RoyalMode(
              label: 'Team up',
              icon: Icons.shield_rounded,
              onTap: _openRoom,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RoyalMode(
              label: 'Friends',
              icon: Icons.favorite_rounded,
              onTap: _playFriends,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: RoyalMode(
              key: const Key('mode-computer'),
              label: 'Computer',
              icon: Icons.smart_toy_rounded,
              onTap: () => _local(true),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: RoyalMode(
              key: const Key('mode-pass-play'),
              label: 'Pass N Play',
              icon: Icons.groups_rounded,
              onTap: () => _local(false),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      MobileAction(
        title: 'TOURNAMENT',
        subtitle: 'Play for the crown',
        icon: Icons.emoji_events_outlined,
        color: AppColors.gold,
        onTap: () =>
            _openAuthenticated((api) => TournamentScreen(apiClient: api)),
      ),
      if (_savedGame != null) ...[
        const SizedBox(height: 16),
        MobileAction(
          title: 'Continue your game',
          subtitle:
              '${_savedGame!.players.length} players - Your board is waiting',
          icon: Icons.play_circle_outline,
          color: AppColors.mint,
          onTap: _resumeGame,
        ),
      ],
      const MobileSection('Make today rewarding'),
      RoyalRewardCard(ready: _dailyReward?.canClaim ?? false, onTap: _daily),
      MobileAction(
        title: 'Royal Arena',
        subtitle: 'Compete in the season and unlock rewards',
        icon: Icons.workspace_premium_outlined,
        color: AppColors.primaryLight,
        onTap: () => _openAuthenticated((api) => SeasonScreen(apiClient: api)),
      ),
    ],
  );

  Widget _balance(IconData icon, String label, Color color) => InkWell(
    onTap: () => _openStore(initialTab: 1),
    borderRadius: BorderRadius.circular(24),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF28364C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameSymbol(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );

  Widget _localModes() => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 340 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: MobileModeCard(
              key: const Key('mode-computer'),
              title: 'Vs Computer',
              subtitle: 'Your pace. Play offline.',
              icon: Icons.smart_toy_outlined,
              color: AppColors.cyan,
              onTap: () => _local(true),
            ),
          ),
          SizedBox(
            width: width,
            child: MobileModeCard(
              key: const Key('mode-local'),
              title: 'Pass & Play',
              subtitle: 'One device. All friends.',
              icon: Icons.groups_outlined,
              color: AppColors.mint,
              onTap: () => _local(false),
            ),
          ),
        ],
      );
    },
  );

  Widget _play() => MobilePageBody(
    key: const ValueKey('play-tab'),
    children: [
      const MobileHeading(
        'Find your game',
        eyebrow: 'TIME TO PLAY',
        subtitle:
            'A quick match or a familiar face. There is a seat for everyone.',
      ),
      MobileAction(
        title: 'Quick match',
        subtitle: 'Find an online table for 2-6 players',
        icon: Icons.flash_on_rounded,
        color: AppColors.mint,
        onTap: _playOnline,
      ),
      MobileAction(
        title: 'Play with friends',
        subtitle: 'Invite a friend or enter a room code',
        icon: Icons.favorite_outline,
        color: AppColors.coral,
        onTap: _playFriends,
      ),
      MobileAction(
        title: 'Private rooms',
        subtitle: 'Set the rules and host your own table',
        icon: Icons.meeting_room_outlined,
        onTap: _openRoom,
      ),
      const MobileSection('Play offline'),
      _localModes(),
      const MobileSection('Raise the stakes'),
      MobileAction(
        title: 'Tournaments',
        subtitle: 'Enter the bracket. Play for the crown.',
        icon: Icons.emoji_events_outlined,
        color: AppColors.gold,
        onTap: () =>
            _openAuthenticated((api) => TournamentScreen(apiClient: api)),
      ),
    ],
  );

  Widget _rewards() => MobilePageBody(
    key: const ValueKey('rewards-tab'),
    children: [
      const EventMarquee(),
      EventBanner(
        title: 'ROYAL\nARENA',
        eyebrow: 'SEASON PASS',
        description: 'Play your way to exclusive season rewards.',
        asset: 'crown',
        accent: const Color(0xFFFFD36D),
        surface: const Color(0xFF54258B),
        featured: true,
        onTap: () => _openAuthenticated((api) => SeasonScreen(apiClient: api)),
      ),
      EventBanner(
        title: 'DAILY\nGOALS',
        eyebrow: 'THE NEXT CHALLENGE',
        description: 'Take on missions. Make every game count.',
        asset: 'target',
        reverse: true,
        accent: const Color(0xFF6BEBF7),
        surface: const Color(0xFF09526E),
        action: 'EXPLORE',
        onTap: () =>
            _openAuthenticated((api) => MissionsScreen(apiClient: api)),
      ),
      EventBanner(
        title: 'DAILY\nBONUS',
        eyebrow: (_dailyReward?.canClaim ?? false)
            ? 'READY FOR YOU'
            : 'KEEP THE STREAK',
        description: 'A new reason to come back and roll.',
        asset: 'gift',
        accent: const Color(0xFFFFBD75),
        surface: const Color(0xFF95401D),
        action: (_dailyReward?.canClaim ?? false) ? 'CLAIM' : 'VIEW',
        onTap: _daily,
      ),
      const MobileSection('More to play for'),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: EventShortcut(
              title: 'Achievements',
              asset: 'medal',
              color: AppColors.gold,
              onTap: () => _openAuthenticated(
                (api) => AchievementsScreen(apiClient: api),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: EventShortcut(
              title: 'Leaderboard',
              asset: 'trophy',
              color: AppColors.cyan,
              onTap: () => _openAuthenticated(
                (api) => LeaderboardScreen(apiClient: api),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: EventShortcut(
              title: 'Store & inventory',
              asset: 'bag',
              color: AppColors.coral,
              onTap: () => _openStore(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: EventShortcut(
              title: 'Coin rewards',
              asset: 'coin',
              color: AppColors.mint,
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => WatchAdRewardDialog(
                  apiClient: _apiClient,
                  onRewardClaimed: _loadAccount,
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _social() => MobilePageBody(
    key: const ValueKey('social-tab'),
    children: [
      const MobileHeading(
        'Better together',
        eyebrow: 'YOUR PEOPLE',
        subtitle: 'Find your friends, build your club, and keep the good games going.',
      ),
      MobileAction(
        title: 'Friends & invites',
        subtitle: _roomInvites > 0
            ? '$_roomInvites room invites waiting'
            : 'Add friends and see who is around',
        icon: Icons.people_outline,
        color: AppColors.mint,
        onTap: () => _openAuthenticated((api) => FriendsScreen(apiClient: api)),
      ),
      MobileAction(
        title: 'Clubs',
        subtitle: 'Find a community at your table',
        icon: Icons.shield_outlined,
        color: AppColors.gold,
        onTap: () => _openAuthenticated((api) => ClubsScreen(apiClient: api)),
      ),
      MobileAction(
        title: 'Match history',
        subtitle: 'Your games and recent opponents',
        icon: Icons.history_rounded,
        color: AppColors.cyan,
        onTap: () =>
            _openAuthenticated((api) => MatchHistoryScreen(apiClient: api)),
      ),
      const MobileSection('Your space'),
      MobileAction(
        title: 'Your profile',
        subtitle: 'Account, identity, and your avatar',
        icon: Icons.person_outline,
        onTap: _openProfile,
      ),
      MobileAction(
        title: 'Settings',
        subtitle: 'Sound, language, accessibility & privacy',
        icon: Icons.tune_rounded,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
      ),
    ],
  );
}
