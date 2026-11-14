import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.creamBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.forestGreen,
        surface: AppColors.creamBackground,
      ),
    );
  }
}

