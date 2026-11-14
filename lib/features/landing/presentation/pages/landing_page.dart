import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ace_background_waves.dart';
import '../../../../core/widgets/ace_brand_header.dart';
import '../../domain/entities/landing_entry_mode.dart';
import '../controllers/landing_controller.dart';
import '../widgets/landing_action_buttons.dart';
import '../widgets/landing_club_divider.dart';
import '../widgets/landing_hero_emblem.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({
    super.key,
    required this.controller,
  });

  final LandingController controller;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (widget.controller.status == LandingStatus.navigate) {
      final mode = widget.controller.selectedMode;
      widget.controller.resetNavigation();

      if (mode == LandingEntryMode.guest) {
        Navigator.of(context).pushNamed(AppRoutes.profileSetup);
      } else if (mode == LandingEntryMode.signIn) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Sign In flow coming soon.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _entranceController.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: AceBackgroundWaves(),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heroSize = math.min(
                  constraints.maxWidth * 0.64,
                  constraints.maxHeight * 0.34,
                ).clamp(180.0, 300.0);

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),
                            const AceBrandHeader(clubSize: 26),
                            SizedBox(
                              height: (constraints.maxHeight * 0.03)
                                  .clamp(12.0, 28.0),
                            ),
                            LandingHeroEmblem(size: heroSize),
                            const SizedBox(height: 8),
                            const Text(
                              'Your seat at the\ntable awaits',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.landingTagline,
                            ),
                            const SizedBox(height: 18),
                            const LandingClubDivider(),
                            const SizedBox(height: 24),
                            ListenableBuilder(
                              listenable: widget.controller,
                              builder: (context, _) {
                                return LandingActionButtons(
                                  isLoading: widget.controller.status ==
                                      LandingStatus.loading,
                                  onPlayAsGuest: widget.controller.playAsGuest,
                                  onSignIn: widget.controller.requestSignIn,
                                );
                              },
                            ),
                            SizedBox(
                              height: (constraints.maxHeight * 0.08)
                                  .clamp(32.0, 72.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

