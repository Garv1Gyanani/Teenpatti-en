import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teen_patti/app.dart';
import 'package:teen_patti/core/session/app_session_store.dart';
import 'package:teen_patti/features/friends/data/repositories/friends_repository_impl.dart';
import 'package:teen_patti/features/friends/domain/entities/friend_member.dart';
import 'package:teen_patti/features/friends/domain/usecases/get_friends_data_usecase.dart';
import 'package:teen_patti/features/friends/presentation/controllers/friends_controller.dart';
import 'package:teen_patti/features/game_table/data/repositories/game_table_repository_impl.dart';
import 'package:teen_patti/features/game_table/domain/entities/table_state.dart';
import 'package:teen_patti/features/game_table/presentation/controllers/game_table_controller.dart';
import 'package:teen_patti/features/home/data/repositories/home_repository_impl.dart';
import 'package:teen_patti/features/home/domain/entities/game_mode_item.dart';
import 'package:teen_patti/features/home/domain/usecases/claim_daily_reward_usecase.dart';
import 'package:teen_patti/features/home/domain/usecases/get_home_dashboard_usecase.dart';
import 'package:teen_patti/features/home/presentation/controllers/home_controller.dart';
import 'package:teen_patti/features/landing/domain/entities/landing_entry_mode.dart';
import 'package:teen_patti/features/landing/domain/repositories/landing_repository.dart';
import 'package:teen_patti/features/landing/domain/usecases/enter_as_guest_usecase.dart';
import 'package:teen_patti/features/landing/presentation/controllers/landing_controller.dart';
import 'package:teen_patti/features/profile_setup/data/repositories/profile_setup_repository_impl.dart';
import 'package:teen_patti/features/profile_setup/domain/usecases/get_avatar_options_usecase.dart';
import 'package:teen_patti/features/profile_setup/domain/usecases/save_user_profile_usecase.dart';
import 'package:teen_patti/features/profile_setup/presentation/controllers/profile_setup_controller.dart';
import 'package:teen_patti/features/splash/domain/entities/app_init_result.dart';
import 'package:teen_patti/features/splash/domain/repositories/splash_repository.dart';
import 'package:teen_patti/features/splash/domain/usecases/initialize_app_usecase.dart';
import 'package:teen_patti/features/splash/presentation/controllers/splash_controller.dart';
import 'package:teen_patti/features/splash/presentation/widgets/splash_loading_indicator.dart';
import 'package:teen_patti/features/table_lobby/data/repositories/table_lobby_repository_impl.dart';
import 'package:teen_patti/features/table_lobby/domain/entities/game_table_room.dart';
import 'package:teen_patti/features/table_lobby/domain/usecases/get_available_tables_usecase.dart';
import 'package:teen_patti/features/table_lobby/presentation/controllers/table_lobby_controller.dart';

class _FakeSplashRepository implements SplashRepository {
  @override
  Future<AppInitResult> initializeApp() async {
    return const AppInitResult(isReady: true);
  }
}

class _FakeLandingRepository implements LandingRepository {
  @override
  Future<void> enterAsGuest() async {}
}

void main() {
  test('SplashController transitions from initial to completed', () async {
    final controller = SplashController(
      initializeAppUseCase: InitializeAppUseCase(
        repository: _FakeSplashRepository(),
        minimumDuration: Duration.zero,
      ),
    );

    expect(controller.status, SplashStatus.initial);
    await controller.initialize();
    expect(controller.status, SplashStatus.completed);
    controller.dispose();
  });

  test('LandingController handles guest and sign-in actions', () async {
    final controller = LandingController(
      enterAsGuestUseCase: EnterAsGuestUseCase(
        repository: _FakeLandingRepository(),
      ),
    );

    expect(controller.status, LandingStatus.idle);
    await controller.playAsGuest();
    expect(controller.status, LandingStatus.navigate);
    expect(controller.selectedMode, LandingEntryMode.guest);

    controller.resetNavigation();
    expect(controller.status, LandingStatus.idle);

    controller.requestSignIn();
    expect(controller.status, LandingStatus.navigate);
    expect(controller.selectedMode, LandingEntryMode.signIn);
    controller.dispose();
  });

  test('ProfileSetupController validates nickname and saves profile',
      () async {
    const repo = ProfileSetupRepositoryImpl();
    final controller = ProfileSetupController(
      getAvatarOptionsUseCase: const GetAvatarOptionsUseCase(repository: repo),
      saveUserProfileUseCase: const SaveUserProfileUseCase(repository: repo),
    );

    expect(controller.avatars.length, 5);
    expect(controller.selectedAvatarId, 'avatar_1');

    await controller.submit();
    expect(controller.status, ProfileSetupStatus.error);
    expect(controller.errorMessage, isNotNull);

    controller.updateNickname('AcePlayer');
    expect(controller.errorMessage, isNull);

    controller.selectAvatar('avatar_3');
    expect(controller.selectedAvatarId, 'avatar_3');

    controller.toggleLinkedProvider('google');
    expect(controller.linkedProvider, 'google');

    await controller.submit();
    expect(controller.status, ProfileSetupStatus.saved);
    controller.dispose();
  });

  test('HomeController loads dashboard and claims daily reward', () async {
    const repo = HomeRepositoryImpl();
    final controller = HomeController(
      getDashboardUseCase: const GetHomeDashboardUseCase(repository: repo),
      claimDailyRewardUseCase: const ClaimDailyRewardUseCase(repository: repo),
    );

    await controller.loadDashboard();
    expect(controller.isLoading, isFalse);
    expect(controller.dashboard, isNotNull);
    expect(controller.dashboard!.chips, 25000);
    expect(controller.dashboard!.isDailyRewardClaimed, isFalse);

    controller.selectGameMode(GameModeType.privateTable);
    expect(controller.selectedMode, GameModeType.privateTable);

    final reward = await controller.claimDailyReward();
    expect(reward, 2500);
    expect(controller.dashboard!.chips, 27500);
    expect(controller.dashboard!.isDailyRewardClaimed, isTrue);

    controller.dispose();
  });

  test('GameTableController loads table and runs Blind, See Cards, Chaal and Pack against AI',
      () async {
    final repo = GameTableRepositoryImpl(random: Random(42));
    final controller = GameTableController.forRepository(
      repository: repo,
      botTurnDelay: Duration.zero,
    );

    await controller.loadTable();
    expect(controller.isLoading, isFalse);
    expect(controller.state, isNotNull);
    expect(controller.state!.potAmount, 700);
    expect(controller.state!.localPlayer.chips, 24900);
    expect(controller.state!.localPlayer.hasSeenCards, isFalse);
    expect(controller.canLocalBlind, isTrue);
    expect(controller.canLocalChaal, isFalse);

    await controller.seeCards();
    expect(controller.state!.localPlayer.hasSeenCards, isTrue);
    expect(controller.canLocalBlind, isFalse);
    expect(controller.canLocalChaal, isTrue);

    await controller.performAction(PlayerTableAction.chaal);
    expect(controller.state!.potAmount, greaterThanOrEqualTo(900));
    expect(controller.state!.localPlayer.totalBet, greaterThanOrEqualTo(300));

    if (!controller.state!.isRoundOver) {
      await controller.performAction(PlayerTableAction.pack);
      expect(controller.state!.localPlayer.hasPacked, isTrue);
      expect(controller.state!.isRoundOver, isTrue);
      expect(controller.state!.roundResult, isNotNull);
    }

    controller.dispose();
  });

  test('TableLobbyController loads tables and filters by tier and open seats',
      () async {
    const repo = TableLobbyRepositoryImpl();
    final controller = TableLobbyController(
      getAvailableTablesUseCase:
          const GetAvailableTablesUseCase(repository: repo),
    );

    await controller.loadTables();
    expect(controller.isLoading, isFalse);
    expect(controller.filteredTables.length, 5);

    controller.selectTier(TableTier.beginner);
    expect(controller.filteredTables.length, 2);

    controller.selectTier(TableTier.beginner);
    expect(controller.filteredTables.length, 5);

    controller.toggleOpenOnly();
    expect(controller.filteredTables.length, 4);

    controller.dispose();
  });

  test('FriendsController filters by tab and search query', () async {
    const repo = FriendsRepositoryImpl();
    final controller = FriendsController(
      getFriendsDataUseCase: const GetFriendsDataUseCase(repository: repo),
    );

    await controller.loadFriends();
    expect(controller.isLoading, isFalse);
    expect(controller.directory!.inviteCode, 'A7K9D4');
    expect(controller.filteredFriends.length, 5);

    controller.selectTab(FriendsFilterTab.online);
    expect(controller.filteredFriends.every((f) => f.isOnline), isTrue);
    expect(controller.filteredFriends.length, 3);

    controller.selectTab(FriendsFilterTab.all);
    controller.updateSearch('sne');
    expect(controller.filteredFriends.length, 1);
    expect(controller.filteredFriends.first.name, 'Sneha');

    controller.dispose();
  });

  testWidgets(
      'AceSocietyApp flows from splash to landing to profile setup to home to lobby to table',
      (WidgetTester tester) async {
    AppSessionStore.setInstance(AppSessionStore());

    await tester.pumpWidget(const AceSocietyApp());
    await tester.pump();

    expect(find.text('ACE SOCIETY'), findsOneWidget);
    expect(find.byType(SplashLoadingIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Play as Guest'), findsOneWidget);

    await tester.tap(find.text('Play as Guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Set Up Your Profile'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'RoyalAce');
    await tester.pump();

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Set Up Your Profile'), findsNothing);
    expect(find.text('RoyalAce'), findsOneWidget);
    expect(find.text('Your Teen Patti\nClub'), findsOneWidget);
    expect(find.text('25,000'), findsOneWidget);
    expect(find.text('Daily Reward'), findsOneWidget);
    expect(find.text('Friends'), findsNWidgets(2));

    await tester.tap(find.text('Play Now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Choose a Table'), findsOneWidget);
    expect(find.text('Emerald Room'), findsOneWidget);

    await tester.tap(find.text('Join').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Emerald Room'), findsOneWidget);
    expect(find.text('RoyalAce'), findsOneWidget);
    expect(find.text('₹300'), findsOneWidget);
    expect(find.text('Your Turn'), findsOneWidget);
    expect(find.text('See Cards'), findsOneWidget);
    expect(find.text('Chaal'), findsOneWidget);

    // Reveal local cards and transition from Blind to Seen betting.
    await tester.tap(find.text('See Cards'));
    await tester.pump();
    expect(find.text('See Cards'), findsNothing);

    // Fold hand and let client-side AI bots play out the round to showdown.
    await tester.tap(find.text('Pack'));
    await tester.pump();
    expect(find.text('Deal New Hand'), findsOneWidget);

    for (var i = 0; i < 40; i++) {
      if (find.text('Play Again').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.text('Back to Lobby'), findsOneWidget);
    expect(find.text('Play Again'), findsOneWidget);
    expect(AppSessionStore.instance.gamesPlayed, 1);
    expect(AppSessionStore.instance.chips, 24950);

    await tester.tap(find.text('Play Again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Play Again'), findsNothing);
    expect(find.text('₹300'), findsOneWidget);
  });
}
