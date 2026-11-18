import 'package:flutter/widgets.dart';

import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';

/// Animated integer readout with tabular figures that starts cleanly at [value]
/// on initial mount (no `0` flicker) and rolls smoothly between subsequent updates.
class AnimatedNumberText extends StatefulWidget {
  const AnimatedNumberText({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutCubic,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.animateDecrease = true,
    this.formatter = formatCommaNumber,
  });

  final int value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool animateDecrease;
  final String Function(int) formatter;

  @override
  State<AnimatedNumberText> createState() => _AnimatedNumberTextState();
}

class _AnimatedNumberTextState extends State<AnimatedNumberText> {
  late int _beginValue;

  @override
  void initState() {
    super.initState();
    _beginValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedNumberText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _beginValue = (!widget.animateDecrease && widget.value < oldWidget.value)
          ? widget.value
          : oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (widget.style ?? AppTextStyles.chipBalance).copyWith(
      fontFeatures: AppTextStyles.tabularNumbers,
    );
    final effectiveDuration =
        (!widget.animateDecrease && widget.value < _beginValue) ||
                _beginValue == widget.value
            ? Duration.zero
            : widget.duration;

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: _beginValue, end: widget.value),
      duration: effectiveDuration,
      curve: widget.curve,
      builder: (context, currentValue, _) {
        return Text(
          '${widget.prefix}${widget.formatter(currentValue)}${widget.suffix}',
          maxLines: widget.maxLines,
          overflow: widget.overflow,
          textAlign: widget.textAlign,
          style: effectiveStyle,
        );
      },
    );
  }
}
