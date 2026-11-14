import 'package:flutter/material.dart';

import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';

class AceSocietyApp extends StatelessWidget {
  const AceSocietyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ace Society - Teen Patti',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}

