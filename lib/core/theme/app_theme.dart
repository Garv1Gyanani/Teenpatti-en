import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.forestGreen,
      surface: AppColors.creamBackground,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.sansFontFamily,
      scaffoldBackgroundColor: AppColors.creamBackground,
      colorScheme: baseScheme,
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.brandTitle,
        headlineMedium: AppTextStyles.screenTitle,
        titleLarge: AppTextStyles.sectionHeading,
        titleMedium: AppTextStyles.fieldLabel,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.pageSubheading,
        labelLarge: AppTextStyles.buttonLabel,
      ),
    );
  }
}
