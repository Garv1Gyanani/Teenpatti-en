import 'package:flutter/material.dart';

import 'core/audio/app_audio_service.dart';
import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';

class AceSocietyApp extends StatelessWidget {
  const AceSocietyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => AppAudioService.instance.markUserInteracted(),
      child: MaterialApp(
        title: 'Ace Society - Teen Patti',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}

