import 'dart:async';

import 'package:flutter/services.dart';

import '../session/app_session_store.dart';

/// Haptic feedback helper gated on `AppSessionStore.instance.vibration`.
abstract final class AppHapticService {
  static void selection() {
    if (!AppSessionStore.instance.vibration) return;
    try {
      unawaited(HapticFeedback.selectionClick());
    } catch (_) {}
  }

  static void light() {
    if (!AppSessionStore.instance.vibration) return;
    try {
      unawaited(HapticFeedback.lightImpact());
    } catch (_) {}
  }

  static void medium() {
    if (!AppSessionStore.instance.vibration) return;
    try {
      unawaited(HapticFeedback.mediumImpact());
    } catch (_) {}
  }
}
