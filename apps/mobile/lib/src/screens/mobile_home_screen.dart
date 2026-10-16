import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/game_symbol.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';

import '../controllers/game_controller.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/mobile_ui.dart';
import '../widgets/game_motion.dart';
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
        title: const Text('Ludo Play'),
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
      body: SafeArea(bottom: false, child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: GameSymbol(Icons.home_outlined),
            selectedIcon: GameSymbol(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: GameSymbol(Icons.sports_esports_outlined),
            selectedIcon: GameSymbol(Icons.sports_esports_rounded),
            label: 'Play',
          ),
          NavigationDestination(
            icon: GameSymbol(Icons.auto_awesome_outlined),
            selectedIcon: GameSymbol(Icons.auto_awesome_rounded),
            label: 'Rewards',
          ),
          NavigationDestination(
            icon: GameSymbol(Icons.people_outline_rounded),
            selectedIcon: GameSymbol(Icons.people_rounded),
            label: 'Social',
          ),
        ],
      ),
    );
  }

  Widget _home() => MobilePageBody(
    key: const ValueKey('home-tab'),
    children: [
      MobileHeading(
        'Ready to roll?',
        eyebrow: 'YOUR NEXT GREAT GAME',
        subtitle:
            'Welcome back, ${_account?.profile.displayName ?? 'Player'}. Make your next move.',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _balance(
            Icons.monetization_on_outlined,
            '${_account?.wallet.coins ?? 0} coins',
            AppColors.gold,
          ),
          _balance(
            Icons.diamond_outlined,
            '${_account?.wallet.gems ?? 0} gems',
            AppColors.cyan,
          ),
          _balance(
            Icons.bolt_rounded,
            'Level ${_account?.profile.level ?? 1}',
            AppColors.mint,
          ),
        ],
      ),
      const SizedBox(height: 22),
      _hero(),
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
      const MobileSection('Your table. Your rules.'),
      _localModes(),
      const MobileSection('A little more to play for'),
      MobileAction(
        title: 'Daily rewards',
        subtitle: (_dailyReward?.canClaim ?? false)
            ? 'Your next reward is ready to claim'
            : 'Keep your streak going',
        icon: Icons.card_giftcard_rounded,
        color: AppColors.gold,
        onTap: _daily,
      ),
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

  Widget _hero() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF293766), Color(0xFF192841)],
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFF3B4C76)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'THE WORLD IS AT YOUR TABLE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.mint,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your next\ngreat game.',
                    style: TextStyle(
                      fontSize: 25,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -.5,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Roll. Connect. Repeat.',
                    style: TextStyle(
                      color: Color(0xFFBECAE0),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 104,
              height: 100,
              child: GameIconMotion(
                floating: true,
                child: CustomPaint(painter: _LobbyBoardPainter()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _playOnline,
            icon: const GameSymbol(Icons.play_arrow_rounded),
            label: const Text('Play online'),
          ),
        ),
      ],
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
      const MobileHeading(
        'Make every roll count',
        eyebrow: 'YOUR PROGRESS',
        subtitle:
            'Small wins, bigger milestones, and something to come back for.',
      ),
      MobileAction(
        title: 'Daily rewards',
        subtitle: 'Check in and keep your streak alive',
        icon: Icons.card_giftcard_outlined,
        color: AppColors.gold,
        onTap: _daily,
      ),
      MobileAction(
        title: 'Missions',
        subtitle: 'Daily and weekly challenges',
        icon: Icons.flag_outlined,
        color: AppColors.mint,
        onTap: () =>
            _openAuthenticated((api) => MissionsScreen(apiClient: api)),
      ),
      MobileAction(
        title: 'Achievements',
        subtitle: 'Celebrate your best moments',
        icon: Icons.verified_outlined,
        onTap: () =>
            _openAuthenticated((api) => AchievementsScreen(apiClient: api)),
      ),
      MobileAction(
        title: 'Season pass',
        subtitle: 'Follow your path through Royal Arena',
        icon: Icons.workspace_premium_outlined,
        color: AppColors.coral,
        onTap: () => _openAuthenticated((api) => SeasonScreen(apiClient: api)),
      ),
      MobileAction(
        title: 'Leaderboard',
        subtitle: 'See where you stand',
        icon: Icons.leaderboard_outlined,
        color: AppColors.cyan,
        onTap: () =>
            _openAuthenticated((api) => LeaderboardScreen(apiClient: api)),
      ),
      MobileAction(
        title: 'Store & inventory',
        subtitle: 'Give your next game a new look',
        icon: Icons.storefront_outlined,
        onTap: () => _openStore(),
      ),
      MobileAction(
        title: 'Get more coins',
        subtitle: 'Explore available reward options',
        icon: Icons.monetization_on_outlined,
        color: AppColors.gold,
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => WatchAdRewardDialog(
            apiClient: _apiClient,
            onRewardClaimed: _loadAccount,
          ),
        ),
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

class _LobbyBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 170);
    final colors = [
      AppColors.red,
      AppColors.mint,
      AppColors.gold,
      AppColors.blue,
    ];
    final board = Rect.fromLTWH(30, 4, 112, 112);
    canvas.save();
    canvas.translate(86, 60);
    canvas.rotate(-.12);
    canvas.translate(-86, -60);
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.inflate(5), const Radius.circular(18)),
      Paint()..color = const Color(0xFF101A30),
    );
    for (var i = 0; i < 4; i++) {
      final left = 30.0 + (i % 2) * 58;
      final top = 4.0 + (i ~/ 2) * 58;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, 54, 54),
          const Radius.circular(12),
        ),
        Paint()..color = colors[i].withValues(alpha: .85),
      );
      for (var j = 0; j < 4; j++) {
        canvas.drawCircle(
          Offset(left + 17 + (j % 2) * 20, top + 17 + (j ~/ 2) * 20),
          6,
          Paint()..color = Colors.white.withValues(alpha: .85),
        );
      }
    }
    canvas.restore();
    canvas.save();
    canvas.translate(116, 91);
    canvas.rotate(.17);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-22, -22, 48, 48),
        const Radius.circular(12),
      ),
      Paint()..color = Colors.black26,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-24, -26, 48, 48),
        const Radius.circular(12),
      ),
      Paint()..color = Colors.white,
    );
    for (final p in [
      const Offset(-12, -14),
      const Offset(12, -14),
      const Offset(0, -2),
      const Offset(-12, 10),
      const Offset(12, 10),
    ]) {
      canvas.drawCircle(
        p,
        3.5,
        Paint()..color = p.dx == 0 ? AppColors.coral : const Color(0xFF253456),
      );
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
