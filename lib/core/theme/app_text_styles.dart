import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const TextStyle brandTitle = TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: ['Times New Roman', 'serif'],
    fontSize: 34,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.0,
    height: 1.1,
    color: AppColors.forestGreen,
  );

  static const TextStyle brandSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 6.2,
    height: 1.2,
    color: AppColors.forestGreen,
  );

  static const TextStyle landingTagline = TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: ['Times New Roman', 'serif'],
    fontSize: 27,
    fontWeight: FontWeight.w500,
    height: 1.24,
    letterSpacing: 0.2,
    color: AppColors.forestGreen,
  );

  static const TextStyle pageHeading = TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: ['Times New Roman', 'serif'],
    fontSize: 27,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.forestGreen,
  );

  static const TextStyle pageSubheading = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppColors.mutedText,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.forestGreen,
  );
}

