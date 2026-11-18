import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/session/app_session_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ace_brand_header.dart';
import '../../../../core/widgets/subpage_background_waves.dart';
import '../../../daily_rewards/data/repositories/daily_rewards_repository_impl.dart';
import '../../../daily_rewards/domain/usecases/get_daily_rewards_usecase.dart';
import '../../../daily_rewards/presentation/controllers/daily_rewards_controller.dart';
import '../../../daily_rewards/presentation/pages/daily_rewards_page.dart';
import '../../../friends/data/repositories/friends_repository_impl.dart';
import '../../../friends/domain/usecases/get_friends_data_usecase.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../friends/presentation/pages/friends_page.dart';
import '../../../game_table/domain/entities/game_table_config.dart';
import '../../../profile/data/repositories/profile_repository_impl.dart';
import '../../../profile/domain/usecases/get_player_profile_usecase.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../table_lobby/data/repositories/table_lobby_repository_impl.dart';
import '../../../table_lobby/domain/usecases/get_available_tables_usecase.dart';
import '../../../table_lobby/presentation/controllers/table_lobby_controller.dart';
import '../../../table_lobby/presentation/pages/table_lobby_page.dart';
import '../../domain/entities/game_mode_item.dart';
import '../controllers/home_controller.dart';
import '../widgets/daily_reward_card.dart';
import '../widgets/friends_strip.dart';
import '../widgets/game_mode_grid.dart';
import '../widgets/home_bottom_nav_bar.dart';
import '../widgets/home_hero_banner.dart';
import '../widgets/home_top_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    this.sessionStore,
  });

  final HomeController controller;
  final AppSessionStore? sessionStore;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TableLobbyController? _tableLobbyController;
  FriendsController? _friendsController;
  DailyRewardsController? _dailyRewardsController;
  ProfileController? _profileController;

  @override
  void initState() {
    super.initState();
    widget.controller.loadDashboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = widget.sessionStore ?? AppSessionStore.instance;
      final pendingRoomCode = session.consumePendingRoomCode();
      if (pendingRoomCode != null && pendingRoomCode.isNotEmpty) {
        Navigator.of(context).pushNamed(
          AppRoutes.privateRoom,
          arguments: pendingRoomCode,
        );
      }
    });
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  void _syncEmbeddedControllersForTab(int tabIndex) {
    if (tabIndex != 1) _tableLobbyController = null;
    if (tabIndex != 2) _friendsController = null;
    if (tabIndex != 3) _dailyRewardsController = null;
    if (tabIndex != 4) _profileController = null;
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _handleClaimReward() async {
    final amount = await widget.controller.claimDailyReward();
    if (amount != null && mounted) {
      _showFeedback('Claimed +$amount chips!');
    }
  }

  void _openWallet() {
    Navigator.of(context).pushNamed(AppRoutes.wallet);
  }

  void _launchVariantTable({
    required String tableName,
    required String variant,
    int minStake = 100,
    int maxStake = 3200,
  }) {
    Navigator.of(context).pushNamed(
      AppRoutes.gameTable,
      arguments: GameTableConfig(
        tableName: tableName,
        minStake: minStake,
        maxStake: maxStake,
        maxPlayers: 6,
        entryChips: minStake,
        variant: variant,
        isOnline: AppSessionStore.instance.supabaseClient.isConfigured,
      ),
    );
  }

  void _showVariantPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.forestGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Choose Teen Patti Variant',
                  style: AppTextStyles.brandTitle.copyWith(fontSize: 21),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select a special rule set to play against Club AI.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 14),
                _VariantOptionTile(
                  icon: Icons.swap_vert_circle_outlined,
                  title: 'Muflis (Lowball)',
                  subtitle: 'Inverted rankings — lowest high-card 5-3-2 wins',
                  badge: '₹100 Boot',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _launchVariantTable(
                      tableName: 'Royal Muflis',
                      variant: 'Muflis',
                    );
                  },
                ),
                const SizedBox(height: 10),
                _VariantOptionTile(
                  icon: Icons.bolt_rounded,
                  title: 'AK47 (4 Wild Ranks)',
                  subtitle: 'Every A, K, 4 & 7 card acts as a Wild Joker',
                  badge: '₹100 Boot',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _launchVariantTable(
                      tableName: 'Royal AK47',
                      variant: 'AK47',
                    );
                  },
                ),
                const SizedBox(height: 10),
                _VariantOptionTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Joker (Random Wild)',
                  subtitle: 'One face-up Joker rank drawn fresh every hand',
                  badge: '₹100 Boot',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _launchVariantTable(
                      tableName: 'Joker Lounge',
                      variant: 'Joker',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _launchMode(GameModeType mode) {
    switch (mode) {
      case GameModeType.classic:
        widget.controller.selectTab(1);
      case GameModeType.privateTable:
        Navigator.of(context).pushNamed(AppRoutes.privateRoom);
      case GameModeType.variants:
        _showVariantPickerSheet();
      case GameModeType.practice:
        Navigator.of(context).pushNamed(
          AppRoutes.gameTable,
          arguments: const GameTableConfig(
            tableName: 'Practice Table',
            minStake: 50,
            maxStake: 1600,
            maxPlayers: 5,
            entryChips: 50,
            variant: 'Practice',
            isPractice: true,
          ),
        );
    }
  }

  void _handlePlayNow() {
    _launchMode(widget.controller.selectedMode);
  }

  void _handleModeSelect(GameModeType mode) {
    if (widget.controller.selectedMode == mode &&
        mode != GameModeType.classic) {
      _launchMode(mode);
      return;
    }
    widget.controller.selectGameMode(mode);
    if (mode == GameModeType.privateTable) {
      Navigator.of(context).pushNamed(AppRoutes.privateRoom);
    } else if (mode == GameModeType.variants) {
      _showVariantPickerSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final tabIndex = widget.controller.currentTabIndex;
          _syncEmbeddedControllersForTab(tabIndex);
          final isHomeTab = tabIndex == 0;

          return Stack(
            children: [
              if (isHomeTab)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 165,
                  child: CustomPaint(
                    painter: HomeHeaderWavePainter(),
                  ),
                )
              else
                const Positioned.fill(
                  child: RepaintBoundary(
                    child: SubpageBackgroundWaves(showBottomWaves: false),
                  ),
                ),
              SafeArea(
                bottom: false,
                child: Builder(
                  builder: (context) {
                    final dashboard = widget.controller.dashboard;
                    if (widget.controller.isLoading || dashboard == null) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.forestGreen,
                        ),
                      );
                    }

                    return Column(
                      children: [
                        if (isHomeTab)
                          HomeTopHeader(
                            playerName: dashboard.playerName,
                            avatarAsset: dashboard.avatarAsset,
                            level: dashboard.level,
                            levelProgress: dashboard.levelProgress,
                            chips: dashboard.chips,
                            hasUnreadNotifications:
                                dashboard.hasUnreadNotifications,
                            onAddChipsTap: _openWallet,
                            onNotificationTap: () {
                              widget.controller.clearNotifications();
                              _showFeedback('You are all caught up!');
                            },
                            onProfileTap: () => widget.controller.selectTab(4),
                          ),
                        Expanded(
                          child: switch (widget.controller.currentTabIndex) {
                            0 => SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  4,
                                  18,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AceBrandHeader(
                                      clubSize: 22,
                                      titleStyle: AppTextStyles.brandTitle
                                          .copyWith(fontSize: 25),
                                    ),
                                    const SizedBox(height: 6),
                                    HomeHeroBanner(
                                      onPlayNow: _handlePlayNow,
                                    ),
                                    const SizedBox(height: 12),
                                    GameModeGrid(
                                      modes: dashboard.gameModes,
                                      selectedMode:
                                          widget.controller.selectedMode,
                                      onSelect: _handleModeSelect,
                                    ),
                                    const SizedBox(height: 14),
                                    DailyRewardCard(
                                      isClaimed:
                                          dashboard.isDailyRewardClaimed,
                                      isClaiming:
                                          widget.controller.isClaimingReward,
                                      onClaim: _handleClaimReward,
                                    ),
                                    const SizedBox(height: 16),
                                    FriendsStrip(
                                      friends: dashboard.friends,
                                      onSeeAllTap: () =>
                                          widget.controller.selectTab(2),
                                      onAddFriendTap: () =>
                                          widget.controller.selectTab(2),
                                      onFriendTap: (friend) => _showFeedback(
                                        '${friend.name} is online',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            1 => TableLobbyPage(
                                controller: _tableLobbyController ??=
                                    TableLobbyController(
                                  getAvailableTablesUseCase:
                                      const GetAvailableTablesUseCase(
                                    repository: TableLobbyRepositoryImpl(),
                                  ),
                                ),
                                chips: dashboard.chips,
                                onBackTap: () => widget.controller.selectTab(0),
                                onAddChipsTap: _openWallet,
                              ),
                            2 => FriendsPage(
                                embedded: true,
                                controller: _friendsController ??=
                                    FriendsController(
                                  getFriendsDataUseCase:
                                      GetFriendsDataUseCase(
                                    repository: FriendsRepositoryImpl(
                                      sessionStore: widget.sessionStore,
                                    ),
                                  ),
                                  sessionStore: widget.sessionStore,
                                ),
                                onBackTap: () => widget.controller.selectTab(0),
                              ),
                            3 => DailyRewardsPage(
                                embedded: true,
                                controller: _dailyRewardsController ??=
                                    DailyRewardsController(
                                  getDailyRewardsUseCase:
                                      GetDailyRewardsUseCase(
                                    repository: DailyRewardsRepositoryImpl(
                                      sessionStore: widget.sessionStore,
                                    ),
                                  ),
                                  sessionStore: widget.sessionStore,
                                ),
                                onBackTap: () => widget.controller.selectTab(0),
                              ),
                            4 => ProfilePage(
                                embedded: true,
                                controller: _profileController ??=
                                    ProfileController(
                                  getPlayerProfileUseCase:
                                      GetPlayerProfileUseCase(
                                    repository: ProfileRepositoryImpl(
                                      sessionStore: widget.sessionStore,
                                    ),
                                  ),
                                  sessionStore: widget.sessionStore,
                                ),
                                onBackTap: () => widget.controller.selectTab(0),
                                onAddChipsTap: _openWallet,
                                onSettingsTap: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.settings),
                              ),
                            _ => const SizedBox.shrink(),
                          },
                        ),
                        SafeArea(
                          top: false,
                          child: HomeBottomNavBar(
                            currentIndex: widget.controller.currentTabIndex,
                            onTap: widget.controller.selectTab,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VariantOptionTile extends StatelessWidget {
  const _VariantOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.forestGreen.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.forestGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.forestGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
