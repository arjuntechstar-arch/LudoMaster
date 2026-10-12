import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';

import '../controllers/game_controller.dart';
import '../controllers/settings_controller.dart';
import '../services/api_client.dart';
import '../services/cosmetic_selection.dart';
import '../widgets/app_loader.dart';
import '../widgets/profile_avatar.dart';
import 'profile_editor_screen.dart';
import 'privacy_policy_screen.dart';
import '../widgets/google_account_buttons.dart';
import '../services/billing_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_dialog.dart';
import '../widgets/play_with_friends_dialog.dart';
import '../widgets/watch_ad_reward_dialog.dart';
import 'achievements_screen.dart';
import 'daily_rewards_dialog.dart';
import 'friends_screen.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'match_history_screen.dart';
import 'matchmaking_screen.dart';
import 'missions_screen.dart';
import 'notifications_dialog.dart';
import 'online_room_screen.dart';
import 'season_screen.dart';
import 'setup_screen.dart';
import 'store_inventory_screen.dart';
import 'tournament_screen.dart';
import 'clubs_screen.dart';
import '../localization/app_localizations.dart';
import '../services/crash_reporting_service.dart';

/// Main dashboard screen with original branding, game mode selection, and saved game resume banner.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  GameState? _savedGame;
  bool _isLoadingSaved = true;

  final ApiClient _apiClient = ApiClient();
  UserMeModel? _myAccount;
  DailyRewardStatusModel? _dailyRewardStatus;
  int _unreadNotificationCount = 0;
  int _pendingRoomInviteCount = 0;
  final Set<String> _knownRoomInviteIds = {};
  Timer? _invitePollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSavedGame();
    _initAccount();
    _startInvitePolling();
  }

  @override
  void dispose() {
    _invitePollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshInviteBadges(showNewInvites: true);
      _startInvitePolling();
    } else {
      _invitePollTimer?.cancel();
      _invitePollTimer = null;
    }
  }

  void _startInvitePolling() {
    _invitePollTimer?.cancel();
    _refreshInviteBadges(showNewInvites: false);
    _invitePollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshInviteBadges(showNewInvites: true);
    });
  }

  Future<void> _refreshInviteBadges({required bool showNewInvites}) async {
    try {
      final invitations = await _apiClient.getMyRoomInvites();
      final notifications = await _apiClient.getNotifications();
      if (!mounted) return;

      final fresh = invitations
          .where((invite) => !_knownRoomInviteIds.contains(invite.id))
          .toList();
      _knownRoomInviteIds.addAll(invitations.map((invite) => invite.id));
      setState(() {
        _pendingRoomInviteCount = invitations.length;
        _unreadNotificationCount = notifications
            .where((item) => !item.isRead)
            .length;
      });

      if (showNewInvites && fresh.isNotEmpty) {
        final message = fresh.length == 1
            ? '${fresh.first.senderName} invited you to a Ludo room.'
            : 'You received ${fresh.length} Ludo room invitations.';
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'VIEW',
                onPressed: _openRoomInvites,
              ),
            ),
          );
      }
    } catch (_) {
      // Keep the home screen usable during brief network failures.
    }
  }

  Future<void> _checkSavedGame() async {
    final saved = await StorageService.loadActiveGame();
    if (mounted) {
      setState(() {
        _savedGame = saved;
        _isLoadingSaved = false;
      });
    }
  }

  Future<void> _accountRefresh = Future.value();
  Future<void> _initAccount() {
    final next = _accountRefresh.then((_) => _loadAccount());
    _accountRefresh = next.catchError((Object _) {});
    return next;
  }

  Future<void> _loadAccount() async {
    try {
      final hasSession =
          _apiClient.accessToken != null || await _apiClient.restoreSession();
      if (!hasSession) {
        await _apiClient.loginGuest();
      }
      final account = await _apiClient.getMyAccount();
      if (mounted) setState(() => _myAccount = account);
      unawaited(BillingService.instance.initialize(_apiClient));
      try {
        await CosmeticSelection.refresh(_apiClient);
      } catch (_) {}
      DailyRewardStatusModel? dailyStatus;
      try {
        dailyStatus = await _apiClient.getDailyRewardStatus();
      } catch (_) {}

      int unreadCount = 0;
      List<RoomInviteModel> roomInvites = [];
      try {
        final notifs = await _apiClient.getNotifications();
        unreadCount = notifs.where((n) => !n.isRead).length;
      } catch (_) {}
      try {
        roomInvites = await _apiClient.getMyRoomInvites();
      } catch (_) {}

      if (mounted) {
        _knownRoomInviteIds.addAll(roomInvites.map((invite) => invite.id));
        setState(() {
          _myAccount = account;
          _dailyRewardStatus = dailyStatus;
          _unreadNotificationCount = unreadCount;
          _pendingRoomInviteCount = roomInvites.length;
        });
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Account initialization failed: $error');
      }
      // Offline mode fallback: gracefully ignore network errors
    }
  }

  int _getXpThreshold(int level) =>
      100 * level + 50 * (level - 1) * (level - 1);

  Widget _buildAccountIcon() {
    final account = _myAccount;
    if (account == null || account.profile.isGuest) {
      return const Icon(Icons.account_circle_outlined, color: AppColors.gold);
    }

    final avatar = ProfileAvatar(
      avatarId: account.profile.avatarId,
      radius: 17,
    );
    if (CosmeticSelection.frame != 'frame_crown') return avatar;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.goldLight, width: 2),
      ),
      child: avatar,
    );
  }

  Future<void> _editProfile() async {
    final account = _myAccount;
    if (account == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfileEditorScreen(
          apiClient: _apiClient,
          profile: account.profile,
        ),
      ),
    );
    if (saved == true && mounted) await _initAccount();
  }

  void _showProfileSheet(UserMeModel account) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProfileAvatar(avatarId: account.profile.avatarId, radius: 32),
                const SizedBox(height: 12),
                Text(
                  account.profile.displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level ${account.profile.level} • ${account.stats.matchesPlayed} matches',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const Icon(
                    Icons.alternate_email,
                    color: AppColors.gold,
                  ),
                  title: Text(
                    account.profile.username == null
                        ? 'Identity set during signup'
                        : '@${account.profile.username}',
                  ),
                  subtitle: const Text(
                    'Name and username are locked. Change avatar or password.',
                  ),
                  trailing: const Icon(Icons.edit, color: AppColors.gold),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _editProfile();
                  },
                ),
                const SizedBox(height: 8),
                if (!account.profile.isGuest)
                  GoogleAccountButtons(
                    apiClient: _apiClient,
                    link: true,
                    onSignedIn: (_) {
                      Navigator.of(sheetContext).pop();
                      _initAccount();
                    },
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Set your name, username, and avatar in Sign Up before connecting a social account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('CLOSE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openRoomInvites() async {
    try {
      if (_apiClient.accessToken == null) {
        await _apiClient.loginGuest();
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FriendsScreen(
            apiClient: _apiClient,
            initialTabIndex: _pendingRoomInviteCount > 0 ? 3 : 0,
          ),
        ),
      );
      if (mounted) _refreshInviteBadges(showNewInvites: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not open friends: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  void _openStore({int initialTab = 0}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => StoreInventoryScreen(
              apiClient: _apiClient,
              onInventoryChanged: _initAccount,
              initialTabIndex: initialTab,
            ),
          ),
        )
        .then((_) => _initAccount());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations(settings.languageCode);
    final currentLevel = _myAccount?.profile.level ?? 1;
    final currentXp = _myAccount?.profile.xp ?? 0;
    final xpTarget = _getXpThreshold(currentLevel);
    final xpProgress = (currentXp / (xpTarget > 0 ? xpTarget : 1)).clamp(
      0.0,
      1.0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 32),
            const SizedBox(width: 10),
            Flexible(child: Text(l10n.text('app_title'))),
          ],
        ),
        actions: [
          IconButton(
            icon: _buildAccountIcon(),
            tooltip: _myAccount == null || _myAccount!.profile.isGuest
                ? 'Sign In / Create Account'
                : 'Profile: ${_myAccount!.profile.displayName}',
            onPressed: () {
              final account = _myAccount;
              if (account != null && !account.profile.isGuest) {
                _showProfileSheet(account);
                return;
              }
              showDialog<void>(
                context: context,
                builder: (_) => AuthDialog(
                  apiClient: _apiClient,
                  onAuthenticated: _initAccount,
                ),
              ).then((_) => _initAccount());
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadNotificationCount > 0,
              label: Text('$_unreadNotificationCount'),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppColors.gold,
              ),
            ),
            tooltip: 'Notifications',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => NotificationsDialog(
                  apiClient: _apiClient,
                  onRefreshHome: _initAccount,
                ),
              ).then((_) => _initAccount());
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _pendingRoomInviteCount > 0,
              label: Text('$_pendingRoomInviteCount'),
              child: const Icon(
                Icons.people_alt_outlined,
                color: AppColors.gold,
              ),
            ),
            tooltip: 'Friends & Social',
            onPressed: _openRoomInvites,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.gold),
            tooltip: 'Settings',
            onPressed: () => _showSettingsModal(context, settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Level & Economy Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceElevated),
                ),
                child: Row(
                  children: [
                    // Level Badge & XP bar
                    Expanded(
                      child: InkWell(
                        onTap: () => _openStore(initialTab: 2),
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.gold,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'LV. $currentLevel',
                                    style: const TextStyle(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _myAccount?.profile.displayName ?? 'Player',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: xpProgress,
                                backgroundColor: AppColors.surfaceElevated,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.gold,
                                ),
                                minHeight: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Coins Chip
                    InkWell(
                      onTap: () => _openStore(initialTab: 1),
                      borderRadius: BorderRadius.circular(16),
                      child: _buildHeaderChip(
                        icon: Icons.monetization_on,
                        amount: _myAccount?.wallet.coins ?? 1000,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Gems Chip
                    InkWell(
                      onTap: () => _openStore(initialTab: 1),
                      borderRadius: BorderRadius.circular(16),
                      child: _buildHeaderChip(
                        icon: Icons.diamond,
                        amount: _myAccount?.wallet.gems ?? 50,
                        color: const Color(0xFF06B6D4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    ProfileAvatar(
                      avatarId: _myAccount?.profile.avatarId ?? 'avatar_0',
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _myAccount?.profile.displayName ?? 'Player',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_myAccount?.profile.username != null)
                            Text(
                              '@${_myAccount!.profile.username}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: Icon(
                        _myAccount?.profile.isGuest == false
                            ? Icons.edit
                            : Icons.login,
                        size: 16,
                      ),
                      label: Text(
                        _myAccount?.profile.isGuest == false
                            ? 'Edit profile'
                            : 'Sign In / Up',
                      ),
                      onPressed: _myAccount == null
                          ? null
                          : () {
                              if (!_myAccount!.profile.isGuest) {
                                _editProfile();
                                return;
                              }
                              showDialog<void>(
                                context: context,
                                builder: (_) => AuthDialog(
                                  apiClient: _apiClient,
                                  onAuthenticated: _initAccount,
                                ),
                              ).then((_) => _initAccount());
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 2. Progression Quick Actions (Daily Rewards, Missions, Achievements, Shop)
              Row(
                children: [
                  _buildQuickActionBtn(
                    title: l10n.text('rewards'),
                    icon: Icons.card_giftcard,
                    color: AppColors.amber,
                    badge: (_dailyRewardStatus?.canClaim ?? false)
                        ? 'CLAIM'
                        : null,
                    onTap: () async {
                      if (_apiClient.accessToken == null) {
                        await _apiClient.loginGuest();
                      }
                      if (!context.mounted) return;
                      DailyRewardsDialog.show(
                        context,
                        _apiClient,
                        onRewardClaimed: _initAccount,
                      ).then((_) => _initAccount());
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionBtn(
                    title: l10n.text('missions'),
                    icon: Icons.military_tech,
                    color: AppColors.green,
                    onTap: () async {
                      if (_apiClient.accessToken == null) {
                        await _apiClient.loginGuest();
                      }
                      if (!context.mounted) return;
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  MissionsScreen(apiClient: _apiClient),
                            ),
                          )
                          .then((_) => _initAccount());
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionBtn(
                    title: l10n.text('badges'),
                    icon: Icons.emoji_events,
                    color: const Color(0xFFA855F7),
                    onTap: () async {
                      if (_apiClient.accessToken == null) {
                        await _apiClient.loginGuest();
                      }
                      if (!context.mounted) return;
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AchievementsScreen(apiClient: _apiClient),
                            ),
                          )
                          .then((_) => _initAccount());
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionBtn(
                    title: l10n.text('store'),
                    icon: Icons.storefront,
                    color: const Color(0xFF06B6D4),
                    onTap: () => _openStore(initialTab: 0),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Phase 9 Meta Actions: Tournaments, Season Pass, Leaderboard, Friends
              Row(
                children: [
                  _buildQuickActionBtn(
                    title: l10n.text('tournaments'),
                    icon: Icons.emoji_events,
                    color: AppColors.gold,
                    badge: '8-P',
                    onTap: () async {
                      if (_apiClient.accessToken == null) {
                        await _apiClient.loginGuest();
                      }
                      if (!context.mounted) return;
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  TournamentScreen(apiClient: _apiClient),
                            ),
                          )
                          .then((_) => _initAccount());
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionBtn(
                    title: l10n.text('season_pass'),
                    icon: Icons.workspace_premium,
                    color: const Color(0xFFE11D48),
                    onTap: () async {
                      if (_apiClient.accessToken == null) {
                        await _apiClient.loginGuest();
                      }
                      if (!context.mounted) return;
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  SeasonScreen(apiClient: _apiClient),
                            ),
                          )
                          .then((_) => _initAccount());
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionBtn(
                    title: l10n.text('leaderboard'),
                    icon: Icons.leaderboard,
                    color: const Color(0xFFF59E0B),
                    onTap: () async {
                      if (_apiClient.accessToken == null) {
                        await _apiClient.loginGuest();
                      }
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              LeaderboardScreen(apiClient: _apiClient),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionBtn(
                    title: l10n.text('friends_social'),
                    icon: Icons.group,
                    color: AppColors.blue,
                    onTap: () async {
                      if (_apiClient.accessToken == null) {
                        await _apiClient.loginGuest();
                      }
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FriendsScreen(apiClient: _apiClient),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Watch Ad Reward & Play With Friends Dual Action Banner
              Row(
                children: [
                  // Watch Ad Card
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => WatchAdRewardDialog(
                            apiClient: _apiClient,
                            onRewardClaimed: _initAccount,
                          ),
                        ).then((_) => _initAccount());
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF818CF8),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF818CF8)
                                    .withValues(alpha: 0.2),
                              ),
                              child: const Icon(
                                Icons.video_library,
                                color: Color(0xFF818CF8),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'GET COINS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Coin packs & rewards',
                                    style: TextStyle(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Play With Friends Card
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        final username = _myAccount?.profile.username ?? '';
                        showDialog<void>(
                          context: context,
                          builder: (_) => PlayWithFriendsDialog(
                            apiClient: _apiClient,
                            myUsername: username,
                            onRefresh: _initAccount,
                          ),
                        ).then((_) => _initAccount());
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF064E3B), Color(0xFF022C22)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF34D399),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF34D399)
                                    .withValues(alpha: 0.2),
                              ),
                              child: const Icon(
                                Icons.group_add,
                                color: Color(0xFF34D399),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'PLAY FRIENDS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Username / Room',
                                    style: TextStyle(
                                      color: Color(0xFF6EE7B7),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Hero Brand Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.gold, width: 2),
                      ),
                      child: const AppLogo(size: 44),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ludo Play',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Progression & Online Multiplayer',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Resume Game Banner (if available)
              if (!_isLoadingSaved && _savedGame != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_circle_fill,
                        color: AppColors.gold,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Game in Progress',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${_savedGame!.players.length} Players • Turn ${_savedGame!.sequence}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ref
                              .read(gameControllerProvider.notifier)
                              .resumeSavedGame(_savedGame!);
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const GameScreen(),
                                ),
                              )
                              .then((_) => _checkSavedGame());
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: const Text('RESUME'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Mode Selection List
              Expanded(
                child: ListView(
                  children: [
                    _buildModeCard(
                      title: l10n.text('play_vs_computer'),
                      subtitle: l10n.text('play_vs_computer_desc'),
                      icon: Icons.smart_toy,
                      accentColor: AppColors.blue,
                      onTap: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const SetupScreen(isVsComputer: true),
                              ),
                            )
                            .then((_) => _checkSavedGame());
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModeCard(
                      title: l10n.text('pass_and_play'),
                      subtitle: l10n.text('pass_and_play_desc'),
                      icon: Icons.people_alt,
                      accentColor: AppColors.green,
                      onTap: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const SetupScreen(isVsComputer: false),
                              ),
                            )
                            .then((_) => _checkSavedGame());
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModeCard(
                      title: 'Play With Friends',
                      subtitle: 'Connect & battle friends using username or Room Code',
                      icon: Icons.groups,
                      accentColor: const Color(0xFF10B981),
                      badge: 'USERNAME',
                      onTap: () {
                        final username = _myAccount?.profile.username ?? '';
                        showDialog<void>(
                          context: context,
                          builder: (_) => PlayWithFriendsDialog(
                            apiClient: _apiClient,
                            myUsername: username,
                            onRefresh: _initAccount,
                          ),
                        ).then((_) => _initAccount());
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModeCard(
                      title: l10n.text('online_multiplayer'),
                      subtitle: l10n.text('online_multiplayer_desc'),
                      icon: Icons.public,
                      accentColor: AppColors.amber,
                      badge: 'LIVE',
                      onTap: () async {
                        final apiClient = ApiClient();
                        try {
                          await apiClient.loginGuest();
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  OnlineRoomScreen(apiClient: apiClient),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to connect to backend: $e'),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModeCard(
                      title: l10n.text('quick_matchmaking'),
                      subtitle: l10n.text('quick_matchmaking_desc'),
                      icon: Icons.flash_on,
                      accentColor: AppColors.gold,
                      badge: '2-6 PLAYERS',
                      onTap: () async {
                        final apiClient = ApiClient();
                        try {
                          await apiClient.loginGuest();
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  MatchmakingScreen(apiClient: apiClient),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to connect to backend: $e'),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModeCard(
                      title: l10n.text('match_logs'),
                      subtitle: l10n.text('match_logs_desc'),
                      icon: Icons.military_tech,
                      accentColor: const Color(0xFF8B5CF6),
                      onTap: () async {
                        final apiClient = ApiClient();
                        try {
                          await apiClient.loginGuest();
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  MatchHistoryScreen(apiClient: apiClient),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to connect to backend: $e'),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModeCard(
                      title: l10n.text('friends_social'),
                      subtitle: l10n.text('friends_social_desc'),
                      icon: Icons.group,
                      accentColor: const Color(0xFF10B981),
                      badge: 'SOCIAL',
                      onTap: () async {
                        final apiClient = ApiClient();
                        try {
                          await apiClient.loginGuest();
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  FriendsScreen(apiClient: apiClient),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to connect to backend: $e'),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModeCard(
                      title: l10n.text('tournaments'),
                      subtitle: l10n.text('tournaments_desc'),
                      icon: Icons.emoji_events,
                      accentColor: AppColors.gold,
                      badge: 'BRACKET',
                      onTap: () async {
                        if (_apiClient.accessToken == null) {
                          await _apiClient.loginGuest();
                        }
                        if (!context.mounted) return;
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    TournamentScreen(apiClient: _apiClient),
                              ),
                            )
                            .then((_) => _initAccount());
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModeCard(
                      title: l10n.text('season_pass'),
                      subtitle: l10n.text('season_pass_desc'),
                      icon: Icons.workspace_premium,
                      accentColor: const Color(0xFFE11D48),
                      badge: 'SEASON 1',
                      onTap: () async {
                        if (_apiClient.accessToken == null) {
                          await _apiClient.loginGuest();
                        }
                        if (!context.mounted) return;
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    SeasonScreen(apiClient: _apiClient),
                              ),
                            )
                            .then((_) => _initAccount());
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModeCard(
                      title: l10n.text('leaderboard'),
                      subtitle: l10n.text('leaderboard_desc'),
                      icon: Icons.leaderboard,
                      accentColor: const Color(0xFFF59E0B),
                      badge: 'RANKED',
                      onTap: () async {
                        if (_apiClient.accessToken == null) {
                          await _apiClient.loginGuest();
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                LeaderboardScreen(apiClient: _apiClient),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModeCard(
                      title: 'Clubs & Social Rooms',
                      subtitle: 'Form or join clubs and play with friends',
                      icon: Icons.shield,
                      accentColor: AppColors.gold,
                      badge: 'NEW',
                      onTap: () async {
                        if (_apiClient.accessToken == null) {
                          await _apiClient.loginGuest();
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ClubsScreen(apiClient: _apiClient),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderChip({
    required IconData icon,
    required int amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 4),
          Text(
            amount > 99999
                ? '${(amount / 1000).toStringAsFixed(1)}k'
                : '$amount',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required String title,
    required IconData icon,
    required Color color,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                if (badge != null)
                  Positioned(
                    top: -6,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withValues(alpha: 0.3), width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 88),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.amber,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                badge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsModal(BuildContext context, SettingsState settings) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final settings = ref.watch(settingsProvider);
          final l10n = AppLocalizations(settings.languageCode);
          final currentLang = AppLocalizations.supportedLanguages.firstWhere(
            (l) => l['code'] == settings.languageCode,
            orElse: () => AppLocalizations.supportedLanguages.first,
          );

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      l10n.text('settings_title'),
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(l10n.text('sound_effects')),
                    secondary: const Icon(
                      Icons.volume_up,
                      color: AppColors.gold,
                    ),
                    activeThumbColor: AppColors.gold,
                    value: settings.soundEnabled,
                    onChanged: (_) =>
                        ref.read(settingsProvider.notifier).toggleSound(),
                  ),
                  SwitchListTile(
                    title: Text(l10n.text('haptic_vibration')),
                    secondary: const Icon(
                      Icons.vibration,
                      color: AppColors.gold,
                    ),
                    activeThumbColor: AppColors.gold,
                    value: settings.hapticsEnabled,
                    onChanged: (_) =>
                        ref.read(settingsProvider.notifier).toggleHaptics(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.translate, color: AppColors.gold),
                    title: Text(
                      l10n.text('language'),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      '${currentLang['flag']} ${currentLang['native']} (${currentLang['name']})',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showLanguagePicker(context, settings.languageCode);
                    },
                  ),
                  const Divider(color: AppColors.surfaceElevated),
                  const SizedBox(height: 4),
                  const Text(
                    'ACCESSIBILITY (A11Y)',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    title: Text(l10n.text('high_contrast')),
                    subtitle: Text(
                      l10n.text('high_contrast_desc'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    secondary: const Icon(
                      Icons.contrast,
                      color: AppColors.amber,
                    ),
                    activeThumbColor: AppColors.gold,
                    value: settings.highContrast,
                    onChanged: (_) => ref
                        .read(settingsProvider.notifier)
                        .toggleHighContrast(),
                  ),
                  SwitchListTile(
                    title: Text(l10n.text('large_text')),
                    subtitle: Text(
                      l10n.text('large_text_desc'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    secondary: const Icon(
                      Icons.format_size,
                      color: AppColors.green,
                    ),
                    activeThumbColor: AppColors.gold,
                    value: settings.largeText,
                    onChanged: (_) =>
                        ref.read(settingsProvider.notifier).toggleLargeText(),
                  ),
                  const Divider(color: AppColors.surfaceElevated),
                  const SizedBox(height: 4),
                  Text(
                    l10n.text('privacy_compliance'),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    leading: const Icon(
                      Icons.download_for_offline_outlined,
                      color: AppColors.blue,
                    ),
                    title: Text(
                      l10n.text('export_data'),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      l10n.text('export_data_desc'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _exportDataDialog(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.privacy_tip_outlined,
                      color: AppColors.gold,
                    ),
                    title: const Text('Privacy Policy'),
                    subtitle: const Text(
                      'How Ludo Play collects, uses, and shares information',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_outlined,
                      color: Colors.redAccent,
                    ),
                    title: Text(
                      l10n.text('delete_account'),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    subtitle: Text(
                      l10n.text('delete_account_desc'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _confirmDeleteAccountDialog(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.system_update_outlined,
                      color: AppColors.gold,
                    ),
                    title: Text(
                      l10n.text('check_updates'),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      l10n.text('check_updates_desc'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _checkUpdate(context);
                    },
                  ),
                  const Divider(color: AppColors.surfaceElevated),
                  const SizedBox(height: 4),
                  Text(
                    l10n.text('diagnostics_title'),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    leading: const Icon(
                      Icons.bug_report_outlined,
                      color: Colors.orangeAccent,
                    ),
                    title: Text(
                      l10n.text('crash_logs'),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      l10n.text('crash_logs_desc'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showCrashLogsDialog(context);
                    },
                  ),
                  const Divider(color: AppColors.surfaceElevated),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        'Ludo Play',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, String currentCode) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.translate, color: AppColors.gold),
              SizedBox(width: 8),
              Text(
                'Select Language',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLocalizations.supportedLanguages.map((lang) {
              final isSelected = lang['code'] == currentCode;
              return ListTile(
                leading: Text(
                  lang['flag']!,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(
                  lang['native']!,
                  style: TextStyle(
                    color: isSelected ? AppColors.gold : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  lang['name']!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.gold)
                    : null,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setLanguage(lang['code']!);
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showCrashLogsDialog(BuildContext context) async {
    final logs = await CrashReportingService.getPersistedLogs();
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Row(
                children: [
                  const Icon(Icons.bug_report_outlined, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text(
                    'Crash Diagnostics (${logs.length})',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No crashes or unhandled exceptions logged.\nSystem running smoothly with 0 fatal errors!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: logs.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: AppColors.surfaceElevated),
                        itemBuilder: (_, idx) {
                          final log = logs[idx];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      log.context,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    log.timestamp.length > 19
                                        ? log.timestamp.substring(11, 19)
                                        : log.timestamp,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                log.message,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                log.stackTrace.split('\n').take(3).join('\n'),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              actions: [
                if (logs.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await CrashReportingService.clearLogs();
                      setDialogState(() {
                        logs.clear();
                      });
                    },
                    child: const Text(
                      'CLEAR LOGS',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(color: AppColors.gold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportDataDialog(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        );
      },
    );

    try {
      final data = await _apiClient.exportMyData();
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close loader

      showDialog<void>(
        context: context,
        builder: (ctx) {
          final profile = data['profile'] as Map<String, dynamic>?;
          final stats = data['stats'] as Map<String, dynamic>?;
          final wallet = data['wallet'] as Map<String, dynamic>?;
          final inventory = (data['inventory'] as List<dynamic>?)?.length ?? 0;
          final purchases = (data['purchases'] as List<dynamic>?)?.length ?? 0;
          final notifs = (data['notifications'] as List<dynamic>?)?.length ?? 0;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Row(
              children: [
                Icon(Icons.privacy_tip_outlined, color: AppColors.gold),
                SizedBox(width: 8),
                Text(
                  'GDPR Data Export',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your personal account data summary per GDPR/CCPA compliance:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDataRow(
                    'Username',
                    '${data['profile']?['username'] ?? 'Not selected'}',
                  ),
                  _buildDataRow(
                    'Display Name',
                    '${profile?['display_name'] ?? 'N/A'}',
                  ),
                  _buildDataRow(
                    'Player Tag',
                    '${profile?['player_id'] ?? 'N/A'}',
                  ),
                  _buildDataRow(
                    'Coins / Gems',
                    '${wallet?['coins'] ?? 0} / ${wallet?['gems'] ?? 0}',
                  ),
                  _buildDataRow(
                    'Matches Played',
                    '${stats?['matches_played'] ?? 0} (Won: ${stats?['matches_won'] ?? 0})',
                  ),
                  _buildDataRow('Inventory Items', '$inventory items owned'),
                  _buildDataRow('Store Purchases', '$purchases completed'),
                  _buildDataRow('Notifications', '$notifs total messages'),
                  _buildDataRow('Exported At', '${data['export_timestamp']}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(color: AppColors.gold),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // close loader
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to export data: $e')));
      }
    }
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccountDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: const Text(
          'Delete this account, login details, device records, username, inventory, personal progress and social connections? This cannot be undone. Limited transaction, safety and shared match records remain as explained in the Privacy Policy.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'DELETE PERMANENTLY',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await _apiClient.deleteMyAccount();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account deleted. Reinitializing new guest account...',
            ),
          ),
        );
        await _initAccount();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete account: $e')));
      }
    }
  }

  Future<void> _checkUpdate(BuildContext context) async {
    try {
      final info = await _apiClient.checkAppVersion(
        platform: 'ANDROID',
        appVersion: '1.0.0',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            info.upgradeRequired
                ? (info.message ?? 'An update is required to continue playing.')
                : 'Ludo Play is up to date (v${info.latestVersion}).',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reach version server: $e')),
      );
    }
  }
}
