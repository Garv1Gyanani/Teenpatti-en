import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teen_patti/core/audio/app_audio_cue.dart';
import 'package:teen_patti/core/audio/app_audio_service.dart';
import 'package:teen_patti/core/audio/audio_backend.dart';
import 'package:teen_patti/core/session/app_session_store.dart';
import 'package:teen_patti/core/theme/app_text_styles.dart';
import 'package:teen_patti/core/theme/app_theme.dart';
import 'package:teen_patti/core/widgets/ace_card.dart';
import 'package:teen_patti/core/widgets/ace_press_scale.dart';
import 'package:teen_patti/core/widgets/chip_balance_pill.dart';
import 'package:teen_patti/features/game_table/domain/entities/playing_card.dart';
import 'package:teen_patti/features/game_table/domain/entities/round_result.dart';
import 'package:teen_patti/features/game_table/domain/entities/table_player.dart';
import 'package:teen_patti/features/game_table/presentation/widgets/animated_card_hand.dart';
import 'package:teen_patti/features/game_table/presentation/widgets/chip_flight_overlay.dart';
import 'package:teen_patti/features/game_table/presentation/widgets/face_up_card_fan.dart';
import 'package:teen_patti/features/game_table/presentation/widgets/player_seat_widget.dart';
import 'package:teen_patti/features/game_table/presentation/widgets/round_result_dialog.dart';
import 'package:teen_patti/features/game_table/presentation/widgets/table_action_bar.dart';
import 'package:teen_patti/features/game_table/presentation/widgets/table_pot_badge.dart';
import 'package:teen_patti/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:teen_patti/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:teen_patti/features/settings/presentation/controllers/settings_controller.dart';
import 'package:teen_patti/features/settings/presentation/pages/settings_page.dart';

class _FakeAudioBackend implements AudioBackend {
  final List<String> playedSfx = <String>[];
  final List<double> playedVolumes = <double>[];
  final List<String> loopAssets = <String>[];
  int startLoopCalls = 0;
  int stopLoopCalls = 0;
  final List<double> loopVolumes = <double>[];
  int gestureCount = 0;

  @override
  void notifyUserGesture() {
    gestureCount += 1;
  }

  @override
  Future<void> playSfx(String assetPath, {double volume = 0.6}) async {
    playedSfx.add(assetPath);
    playedVolumes.add(volume);
  }

  @override
  Future<void> setLoopVolume(double volume) async {
    loopVolumes.add(volume);
  }

  @override
  Future<void> startLoop(String assetPath, {double volume = 0.18}) async {
    startLoopCalls += 1;
    loopAssets.add(assetPath);
    loopVolumes.add(volume);
  }

  @override
  Future<void> stopLoop() async {
    stopLoopCalls += 1;
  }

  @override
  void dispose() {}
}

void main() {
  group('Typography & theme tokens', () {
    test('AppTextStyles and AppTheme wire bundled fonts and tabular figures', () {
      expect(AppTextStyles.brandTitle.fontFamily, 'CormorantGaramond');
      expect(AppTextStyles.brandTitle.fontWeight, FontWeight.w600);
      expect(AppTextStyles.screenTitle.fontFamily, 'PlayfairDisplay');
      expect(AppTextStyles.winnerHeading.fontFamily, 'PlayfairDisplay');
      expect(AppTextStyles.playerName.fontFamily, 'Inter');
      expect(AppTextStyles.chipBalance.fontFamily, 'Inter');
      expect(
        AppTextStyles.chipBalance.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(
        AppTheme.light.textTheme.bodyMedium?.fontFamily,
        AppTextStyles.sansFontFamily,
      );
      expect(
        AppTheme.light.textTheme.displayLarge?.fontFamily,
        'CormorantGaramond',
      );
      expect(
        AppTheme.light.textTheme.headlineMedium?.fontFamily,
        'PlayfairDisplay',
      );
    });
  });

  group('UI animations & counters', () {
    testWidgets(
        'ChipBalancePill starts immediately at initial value and rolls up cleanly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChipBalancePill(chips: 25000, onAddTap: () {}),
          ),
        ),
      );

      expect(find.text('25,000'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChipBalancePill(chips: 26500, onAddTap: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('25,000'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('26,500'), findsOneWidget);
    });

    testWidgets(
        'TablePotBadge rolls up on increases and snaps cleanly on new-hand reset',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TablePotBadge(potAmount: 300),
          ),
        ),
      );
      expect(find.text('₹300'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TablePotBadge(potAmount: 900),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('₹300'), findsNothing);
      expect(find.text('₹900'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('₹900'), findsOneWidget);

      // Resetting pot back to next hand boot (900 -> 300) displays immediately.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TablePotBadge(potAmount: 300),
          ),
        ),
      );
      expect(find.text('₹300'), findsOneWidget);
    });

    testWidgets(
        'AnimatedCardRevealFlip and AnimatedDealIn complete cleanly without pending timers',
        (tester) async {
      const revealWidget = AnimatedCardRevealFlip(
        isRevealed: false,
        hiddenChild: Text('HIDDEN_HAND'),
        revealedChild: Text('SEEN_HAND'),
      );
      expect(revealWidget.duration, const Duration(milliseconds: 280));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedDealIn(
              roundKey: 1,
              seatIndex: 2,
              child: revealWidget,
            ),
          ),
        ),
      );

      expect(find.text('HIDDEN_HAND'), findsOneWidget);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedDealIn(
              roundKey: 1,
              seatIndex: 2,
              child: AnimatedCardRevealFlip(
                isRevealed: true,
                hiddenChild: Text('HIDDEN_HAND'),
                revealedChild: Text('SEEN_HAND'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('HIDDEN_HAND'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('SEEN_HAND'), findsOneWidget);
    });

    testWidgets(
        'ChipFlightOverlay launches bet and showdown winner chip flights cleanly',
        (tester) async {
      const anchors = <String, Alignment>{
        'p1': Alignment(0.0, 0.8),
        'p2': Alignment(-0.5, -0.5),
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 600,
              child: ChipFlightOverlay(
                roundNumber: 1,
                seatAnchors: anchors,
                playerContributions: <String, int>{'p1': 100, 'p2': 100},
                isRoundOver: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsNothing);

      // Simulate p1 betting chips -> launches chip flight toward pot.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 600,
              child: ChipFlightOverlay(
                roundNumber: 1,
                seatAnchors: anchors,
                playerContributions: <String, int>{'p1': 300, 'p2': 100},
                isRoundOver: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(Container), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.byType(Container), findsNothing);

      // Simulate showdown -> sweeps 3 staggered chips to winner.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 600,
              child: ChipFlightOverlay(
                roundNumber: 1,
                seatAnchors: anchors,
                playerContributions: <String, int>{'p1': 300, 'p2': 100},
                isRoundOver: true,
                winnerPlayerId: 'p1',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.byType(Container), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.byType(Container), findsNothing);

      // Fresh round transition (round 1 -> round 2) launches Boot chip flights
      // even when prior round contribution was higher (400 -> 100).
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 600,
              child: ChipFlightOverlay(
                roundNumber: 2,
                seatAnchors: anchors,
                playerContributions: <String, int>{'p1': 100, 'p2': 100},
                isRoundOver: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      // 2 Boot flights launched (p1 and p2), each token renders 2 Containers.
      expect(find.byType(Container), findsNWidgets(4));

      await tester.pumpAndSettle();
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('AcePressScale shrinks on pointer down and springs back on pointer up',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AcePressScale(
                child: SizedBox(width: 120, height: 48, child: Text('Tap Me')),
              ),
            ),
          ),
        ),
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Tap Me')));
      await tester.pump(const Duration(milliseconds: 60));
      var animatedScale =
          tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(animatedScale.scale, 0.96);

      await gesture.up();
      await tester.pumpAndSettle();
      animatedScale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(animatedScale.scale, 1.0);
    });

    testWidgets(
        'OpponentSeatWidget uses 280ms 3D showdown flip and auto-fading action callout pill',
        (tester) async {
      const showdownCards = <PlayingCard>[
        PlayingCard(rank: 'A', suit: CardSuit.spades),
        PlayingCard(rank: 'K', suit: CardSuit.spades),
        PlayingCard(rank: 'Q', suit: CardSuit.spades),
      ];

      expect(formatSeatActionCallout('Blind ₹100'), 'BLIND +100');
      expect(formatSeatActionCallout('Chaal ₹200'), 'CHAAL +200');
      expect(formatSeatActionCallout('Packed'), 'PACK');
      expect(formatSeatActionCallout('Side Show'), 'SIDE SHOW');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: OpponentSeatWidget(
                roundNumber: 1,
                player: TablePlayer(
                  id: 'ai_1',
                  name: 'Rohit',
                  chips: 5200,
                  avatarAsset: 'assets/images/avatar_2.png',
                  cards: showdownCards,
                  lastActionText: 'Chaal ₹200',
                ),
                revealCards: false,
              ),
            ),
          ),
        ),
      );

      // Floating callout fades in cleanly around ~240ms.
      await tester.pump(const Duration(milliseconds: 240));
      expect(find.text('CHAAL +200'), findsOneWidget);

      // Callout auto-fades out cleanly once animation finishes.
      await tester.pumpAndSettle();
      expect(find.text('CHAAL +200'), findsNothing);

      // Showdown flips opponent cards using AnimatedCardRevealFlip.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: OpponentSeatWidget(
                roundNumber: 1,
                player: TablePlayer(
                  id: 'ai_1',
                  name: 'Rohit',
                  chips: 5200,
                  avatarAsset: 'assets/images/avatar_2.png',
                  cards: showdownCards,
                  lastActionText: 'Show',
                ),
                revealCards: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedCardRevealFlip), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(FaceUpCardFan), findsOneWidget);
      expect(find.text('SHOW'), findsNothing);
    });

    test('Turn countdown ring shifts emerald -> amber -> crimson at <= 5s', () {
      const duration = Duration(seconds: 15);
      // 12s remaining -> emerald
      expect(
        turnRingColorForProgress(12 / 15, duration),
        const Color(0xFF9DF0B8),
      );
      // 7s remaining -> amber
      expect(
        turnRingColorForProgress(7 / 15, duration),
        const Color(0xFFF2C96D),
      );
      // 5s and 2s remaining -> crimson
      expect(
        turnRingColorForProgress(5 / 15, duration),
        const Color(0xFFE55353),
      );
      expect(
        turnRingColorForProgress(2 / 15, duration),
        const Color(0xFFE55353),
      );
    });

    testWidgets(
        'RoundResultDialog animates won chips and balance counters to final values',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const cards = <PlayingCard>[
        PlayingCard(rank: 'A', suit: CardSuit.hearts),
        PlayingCard(rank: 'K', suit: CardSuit.hearts),
        PlayingCard(rank: 'Q', suit: CardSuit.hearts),
      ];
      const winner = TablePlayer(
        id: 'local',
        name: 'You',
        chips: 26400,
        avatarAsset: 'assets/images/splash_character.png',
        isLocalPlayer: true,
        cards: cards,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: RoundResultDialog(
              result: const RoundResult(
                wonAmount: 2400,
                previousBalance: 24000,
                newBalance: 26400,
                handLabel: 'Pure Sequence',
                winner: winner,
                packedOpponents: <TablePlayer>[],
              ),
              onBackToLobby: () {},
              onPlayAgain: () {},
            ),
          ),
        ),
      );

      expect(find.text('+₹0'), findsOneWidget);
      expect(find.text('₹26,400'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('+₹2,400'), findsOneWidget);
      expect(find.text('₹26,400'), findsOneWidget);
    });

    testWidgets(
        'AceCard(onTap) and TableActionBar controls use AcePressScale cleanly',
        (tester) async {
      var tappedCard = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AceCard(
                  onTap: () => tappedCard = true,
                  padding: const EdgeInsets.all(12),
                  child: const Text('Interactive Tile'),
                ),
                TableActionBar(
                  blindAmount: 100,
                  chaalAmount: 200,
                  hasPacked: false,
                  isDisabled: false,
                  canRaiseStake: true,
                  onToggleRaise: () {},
                  onAction: (_) {},
                  onDealNewHand: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final gesture = await tester
          .startGesture(tester.getCenter(find.text('Interactive Tile')));
      await tester.pump(const Duration(milliseconds: 60));
      final tileScale = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byType(AceCard),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(tileScale.scale, 0.96);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tappedCard, isTrue);

      // Verify 2x Stake toggle in TableActionBar also has AcePressScale.
      expect(
        find.ancestor(
          of: find.byKey(const Key('raise_2x_toggle')),
          matching: find.byType(AcePressScale),
        ),
        findsOneWidget,
      );
    });
  });

  group('Audio engine & settings gating', () {
    late AppSessionStore store;
    late _FakeAudioBackend backend;
    late AppAudioService service;

    setUp(() {
      store = AppSessionStore();
      backend = _FakeAudioBackend();
      service = AppAudioService(
        sessionStore: store,
        backend: backend,
      );
      service.markUserInteracted();
    });

    tearDown(() {
      service.dispose();
    });

    test(
        'AppAudioService plays jazz MP3 at lowered default, scales music/SFX volumes live, and ducks for showdown',
        () async {
      expect(backend.gestureCount, 1);
      expect(backend.startLoopCalls, 1);
      expect(backend.loopAssets.last, 'assets/audio/jazz_lounge_loop.mp3');
      expect(
        backend.loopVolumes.last,
        closeTo(0.25 * AppAudioService.maxAmbientGain, 0.0001),
      );

      service.play(AppAudioCue.cardFlip);
      expect(backend.playedSfx, <String>[AppAudioCue.cardFlip.assetPath]);
      expect(
        backend.playedVolumes.last,
        closeTo(AppAudioCue.cardFlip.defaultVolume * 0.85, 0.0001),
      );

      // Live volume slider adjustment changes gain without restarting the track.
      store.previewAudioVolumes(musicVolume: 0.6, sfxVolume: 0.4);
      expect(backend.startLoopCalls, 1);
      expect(
        backend.loopVolumes.last,
        closeTo(0.6 * AppAudioService.maxAmbientGain, 0.0001),
      );

      service.play(AppAudioCue.chipToss);
      expect(
        backend.playedVolumes.last,
        closeTo(AppAudioCue.chipToss.defaultVolume * 0.4, 0.0001),
      );

      await store.updateSettings(soundEffects: false);
      service.play(AppAudioCue.chipToss);
      expect(backend.playedSfx.length, 2);

      await store.updateSettings(backgroundMusic: false);
      expect(backend.stopLoopCalls, 1);

      await store.updateSettings(backgroundMusic: true);
      expect(backend.startLoopCalls, 2);
      expect(
        backend.loopVolumes.last,
        closeTo(0.6 * AppAudioService.maxAmbientGain, 0.0001),
      );

      service.duckAmbientForShowdown();
      expect(
        backend.loopVolumes.last,
        closeTo(0.6 * AppAudioService.maxAmbientGain * 0.30, 0.0001),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1050));
      expect(
        backend.loopVolumes.last,
        closeTo(0.6 * AppAudioService.maxAmbientGain, 0.0001),
      );
    });

    testWidgets(
        'SettingsPage renders volume sliders at 360x800 without overflow and updates AppSessionStore',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = SettingsController(
        getSettingsUseCase: GetSettingsUseCase(
          repository: SettingsRepositoryImpl(sessionStore: store),
        ),
        sessionStore: store,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SettingsPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Music Volume'), findsOneWidget);
      expect(find.text('SFX Volume'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      controller.setMusicVolume(0.5, persist: true);
      await tester.pumpAndSettle();
      expect(store.musicVolume, 0.5);
      expect(find.text('50%'), findsOneWidget);
    });
  });
}
