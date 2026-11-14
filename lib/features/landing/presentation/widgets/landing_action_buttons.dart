import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Primary ("Play as Guest") and secondary ("Sign In") pill action buttons.
class LandingActionButtons extends StatelessWidget {
  const LandingActionButtons({
    super.key,
    required this.onPlayAsGuest,
    required this.onSignIn,
    this.isLoading = false,
  });

  final VoidCallback onPlayAsGuest;
  final VoidCallback onSignIn;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: isLoading ? null : onPlayAsGuest,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.forestGreen.withValues(alpha: 0.7),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text(
                'Play as Guest',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onSignIn,
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.creamBackground,
                foregroundColor: AppColors.forestGreen,
                side: const BorderSide(
                  color: AppColors.forestGreen,
                  width: 1.25,
                ),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.person_outline_rounded, size: 21),
              label: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

