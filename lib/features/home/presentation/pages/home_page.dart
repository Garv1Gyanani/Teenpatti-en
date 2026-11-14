import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ace_brand_header.dart';
import '../../../friends/data/repositories/friends_repository_impl.dart';
import '../../../friends/domain/usecases/get_friends_data_usecase.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../friends/presentation/pages/friends_page.dart';
import '../../../table_lobby/data/repositories/table_lobby_repository_impl.dart';
import '../../../table_lobby/domain/usecases/get_available_tables_usecase.dart';
import '../../../table_lobby/presentation/controllers/table_lobby_controller.dart';
import '../../../table_lobby/presentation/pages/table_lobby_page.dart';
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
  });

  final HomeController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadDashboard();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 165,
            child: CustomPaint(
              painter: HomeHeaderWavePainter(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
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
                    if (widget.controller.currentTabIndex == 0)
                      HomeTopHeader(
                        playerName: dashboard.playerName,
                        avatarAsset: dashboard.avatarAsset,
                        level: dashboard.level,
                        levelProgress: dashboard.levelProgress,
                        chips: dashboard.chips,
                        hasUnreadNotifications:
                            dashboard.hasUnreadNotifications,
                        onAddChipsTap: () =>
                            _showFeedback('Chip store coming soon.'),
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AceBrandHeader(
                                  clubSize: 22,
                                  titleStyle: AppTextStyles.brandTitle
                                      .copyWith(fontSize: 25),
                                ),
                                const SizedBox(height: 6),
                                HomeHeroBanner(
                                  onPlayNow: () =>
                                      widget.controller.selectTab(1),
                                ),
                                const SizedBox(height: 12),
                                GameModeGrid(
                                  modes: dashboard.gameModes,
                                  selectedMode:
                                      widget.controller.selectedMode,
                                  onSelect: widget.controller.selectGameMode,
                                ),
                                const SizedBox(height: 14),
                                DailyRewardCard(
                                  isClaimed: dashboard.isDailyRewardClaimed,
                                  isClaiming:
                                      widget.controller.isClaimingReward,
                                  onClaim: _handleClaimReward,
                                ),
                                const SizedBox(height: 16),
                                FriendsStrip(
                                  friends: dashboard.friends,
                                  onSeeAllTap: () =>
                                      widget.controller.selectTab(2),
                                  onAddFriendTap: () => _showFeedback(
                                    'Invite friends feature coming soon.',
                                  ),
                                  onFriendTap: (friend) => _showFeedback(
                                    '${friend.name} is online',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        1 => TableLobbyPage(
                            controller: TableLobbyController(
                              getAvailableTablesUseCase:
                                  const GetAvailableTablesUseCase(
                                repository: TableLobbyRepositoryImpl(),
                              ),
                            ),
                            chips: dashboard.chips,
                            onBackTap: () => widget.controller.selectTab(0),
                            onAddChipsTap: () =>
                                _showFeedback('Chip store coming soon.'),
                          ),
                        2 => FriendsPage(
                            controller: FriendsController(
                              getFriendsDataUseCase:
                                  const GetFriendsDataUseCase(
                                repository: FriendsRepositoryImpl(),
                              ),
                            ),
                            onBackTap: () => widget.controller.selectTab(0),
                          ),
                        _ => _SecondaryTabPlaceholder(
                            tabIndex: widget.controller.currentTabIndex,
                            onBackHome: () => widget.controller.selectTab(0),
                          ),
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
      ),
    );
  }
}

class _SecondaryTabPlaceholder extends StatelessWidget {
  const _SecondaryTabPlaceholder({
    required this.tabIndex,
    required this.onBackHome,
  });

  final int tabIndex;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    const titles = ['Home', 'Games', 'Friends', 'Rewards', 'Profile'];
    final title = titles[tabIndex.clamp(0, titles.length - 1)];

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTextStyles.pageHeading,
          ),
          const SizedBox(height: 8),
          const Text(
            'Coming soon to Ace Society',
            style: AppTextStyles.pageSubheading,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onBackHome,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.forestGreen,
              side: const BorderSide(color: AppColors.forestGreen),
              shape: const StadiumBorder(),
            ),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
}
