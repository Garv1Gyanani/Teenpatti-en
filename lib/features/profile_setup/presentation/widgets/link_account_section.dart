import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Optional "Link Account" section with Google and Email pill buttons.
class LinkAccountSection extends StatelessWidget {
  const LinkAccountSection({
    super.key,
    required this.selectedProvider,
    required this.onToggleProvider,
  });

  final String? selectedProvider;
  final ValueChanged<String> onToggleProvider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.inputBorder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.forestGreen,
                  ),
                  children: [
                    TextSpan(
                      text: 'Link Account ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: '(Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.inputBorder,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _LinkProviderButton(
                label: 'Google',
                isSelected: selectedProvider == 'google',
                icon: const _GoogleGMark(),
                onTap: () => onToggleProvider('google'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LinkProviderButton(
                label: 'Email',
                isSelected: selectedProvider == 'email',
                icon: const Icon(
                  Icons.mail_outline_rounded,
                  size: 19,
                  color: AppColors.forestGreen,
                ),
                onTap: () => onToggleProvider('email'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LinkProviderButton extends StatelessWidget {
  const _LinkProviderButton({
    required this.label,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? AppColors.forestGreen.withValues(alpha: 0.08)
              : AppColors.inputFill,
          foregroundColor: AppColors.forestGreen,
          side: BorderSide(
            color: isSelected ? AppColors.forestGreen : AppColors.inputBorder,
            width: isSelected ? 1.6 : 1.1,
          ),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.forestGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGMark extends StatelessWidget {
  const _GoogleGMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    // Red top
    canvas.drawArc(rect, -2.55, 1.85, false, arcPaint(const Color(0xFFEA4335)));
    // Yellow left
    canvas.drawArc(rect, 2.35, 1.45, false, arcPaint(const Color(0xFFFBBC05)));
    // Green bottom
    canvas.drawArc(rect, 0.72, 1.65, false, arcPaint(const Color(0xFF34A853)));
    // Blue right
    canvas.drawArc(rect, -0.08, 0.85, false, arcPaint(const Color(0xFF4285F4)));

    // Blue crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(size.width * 0.52, size.height * 0.50),
      Offset(size.width * 0.92, size.height * 0.50),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

