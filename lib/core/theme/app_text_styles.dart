import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralized typography tokens for Ace Society:
/// - [brandFontFamily] (`CormorantGaramond` SemiBold): app branding & club titles
/// - [displayFontFamily] (`PlayfairDisplay` Medium/SemiBold): screen & modal titles
/// - [sansFontFamily] (`Inter` Regular/Medium/SemiBold): UI, buttons, balances, player names
abstract final class AppTextStyles {
  static const String brandFontFamily = 'CormorantGaramond';
  static const String displayFontFamily = 'PlayfairDisplay';
  static const String sansFontFamily = 'Inter';

  static const List<FontFeature> tabularNumbers = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static const TextStyle brandTitle = TextStyle(
    fontFamily: brandFontFamily,
    fontSize: 38,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    height: 1.08,
    color: AppColors.forestGreen,
  );

  static const TextStyle brandCompact = TextStyle(
    fontFamily: brandFontFamily,
    fontSize: 23,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    height: 1.1,
    color: AppColors.forestGreen,
  );

  static const TextStyle clubHero = TextStyle(
    fontFamily: brandFontFamily,
    fontSize: 25,
    fontWeight: FontWeight.w600,
    height: 1.16,
    color: AppColors.forestGreen,
  );

  static const TextStyle brandSubtitle = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 6.2,
    height: 1.2,
    color: AppColors.forestGreen,
  );

  static const TextStyle landingTagline = TextStyle(
    fontFamily: brandFontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.18,
    letterSpacing: 0.2,
    color: AppColors.forestGreen,
  );

  static const TextStyle pageHeading = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 27,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.forestGreen,
  );

  static const TextStyle screenTitle = pageHeading;

  static const TextStyle winnerHeading = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 27,
    fontWeight: FontWeight.w600,
    height: 1.15,
    color: AppColors.forestGreen,
  );

  static const TextStyle modalHeading = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 21,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.forestGreen,
  );

  static const TextStyle modalHeadingCream = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: Color(0xFFF0E9D8),
  );

  static const TextStyle screenBarTitle = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.forestGreen,
  );

  static const TextStyle tableTitleWatermark = TextStyle(
    fontFamily: brandFontFamily,
    fontSize: 21,
    fontWeight: FontWeight.w600,
    color: Color(0xD8FFFFFF),
    height: 1.1,
  );

  static const TextStyle cardHeading = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w600,
    color: AppColors.forestGreen,
    height: 1.15,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 18.5,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.forestGreen,
  );

  static const TextStyle pageSubheading = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.38,
    color: AppColors.mutedText,
  );

  static const TextStyle body = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.forestGreen,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.forestGreen,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  static const TextStyle playerName = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.15,
    color: Colors.white,
  );

  static const TextStyle chipBalance = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: tabularNumbers,
    letterSpacing: 0.2,
    color: Colors.white,
  );
}
