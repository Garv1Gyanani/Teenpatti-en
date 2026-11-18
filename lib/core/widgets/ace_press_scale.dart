import 'package:flutter/widgets.dart';

import '../audio/app_audio_cue.dart';
import '../audio/app_audio_service.dart';
import '../audio/app_haptic_service.dart';

/// Tactile micro-spring press scale wrapper that shrinks cleanly on pointer down
/// without interfering with child [InkWell] / [GestureDetector] gesture arenas.
class AcePressScale extends StatefulWidget {
  const AcePressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.96,
    this.duration = const Duration(milliseconds: 120),
    this.audioCue,
    this.enableHaptic = false,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;
  final Duration duration;
  final AppAudioCue? audioCue;
  final bool enableHaptic;

  @override
  State<AcePressScale> createState() => _AcePressScaleState();
}

class _AcePressScaleState extends State<AcePressScale> {
  bool _pressed = false;

  void _setPressed(bool next) {
    if (_pressed == next) return;
    setState(() {
      _pressed = next;
    });
  }

  void _handlePointerDown(PointerDownEvent _) {
    if (!widget.enabled) return;
    _setPressed(true);
    if (widget.audioCue != null) {
      AppAudioService.instance.play(widget.audioCue!);
    }
    if (widget.enableHaptic) {
      AppHapticService.selection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetScale =
        widget.enabled && _pressed ? widget.pressedScale : 1.0;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: targetScale,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
