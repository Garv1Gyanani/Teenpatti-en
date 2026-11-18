import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ace_background_waves.dart';
import '../../../../core/widgets/ace_brand_header.dart';
import '../controllers/splash_controller.dart';
import '../widgets/splash_hero_emblem.dart';
import '../widgets/splash_loading_indicator.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.controller,
  });

  final SplashController controller;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    _entranceController.forward();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.initialize();
  }

  void _onControllerChanged() {
    if (!mounted || _hasNavigated) return;
    if (widget.controller.status == SplashStatus.completed) {
      _hasNavigated = true;
      final target = widget.controller.hasActiveProfile
          ? AppRoutes.home
          : AppRoutes.landing;
      Navigator.of(context).pushReplacementNamed(target);
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
                  constraints.maxHeight * 0.36,
                ).clamp(180.0, 320.0);

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SplashHeroEmblem(size: heroSize),
                            Transform.translate(
                              offset: Offset(0, -heroSize * 0.05),
                              child: const AceBrandHeader(),
                            ),
                            SizedBox(
                              height: (constraints.maxHeight * 0.065)
                                  .clamp(28.0, 64.0),
                            ),
                            const SplashLoadingIndicator(),
                            SizedBox(
                              height: constraints.maxHeight * 0.06,
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

