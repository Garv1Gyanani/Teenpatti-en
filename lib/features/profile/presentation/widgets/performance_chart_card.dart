import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ace_card.dart';
import '../../domain/entities/player_profile_data.dart';

/// Performance line chart card showing 7-day smooth area spline and metric picker.
class PerformanceChartCard extends StatelessWidget {
  const PerformanceChartCard({
    super.key,
    required this.values,
    required this.selectedMetric,
    required this.onSelectMetric,
  });

  final List<double> values;
  final PerformanceMetric selectedMetric;
  final ValueChanged<PerformanceMetric> onSelectMetric;

  static const List<String> _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final maxY = selectedMetric == PerformanceMetric.winRate ? 90.0 : 30.0;

    return AceCard(
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up_rounded,
                size: 20,
                color: AppColors.forestGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Performance ',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF14281D),
                        ),
                      ),
                      TextSpan(
                        text: '(Last 7 Days)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<PerformanceMetric>(
                onSelected: onSelectMetric,
                color: AppColors.inputFill,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                itemBuilder: (context) => PerformanceMetric.values
                    .map(
                      (metric) => PopupMenuItem<PerformanceMetric>(
                        value: metric,
                        child: Text(
                          metric.label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: metric == selectedMetric
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EFE5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedMetric.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.forestGreen,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.forestGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 122,
            child: CustomPaint(
              painter: _SmoothSplineChartPainter(
                values: values,
                maxY: maxY,
                days: _days,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmoothSplineChartPainter extends CustomPainter {
  const _SmoothSplineChartPainter({
    required this.values,
    required this.maxY,
    required this.days,
  });

  final List<double> values;
  final double maxY;
  final List<String> days;

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxisWidth = 28.0;
    const rightPadding = 12.0;
    const topPadding = 8.0;
    const bottomAxisHeight = 22.0;

    final chartLeft = leftAxisWidth;
    final chartRight = size.width - rightPadding;
    final chartTop = topPadding;
    final chartBottom = size.height - bottomAxisHeight;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    final gridPaint = Paint()
      ..color = AppColors.inputBorder.withValues(alpha: 0.45)
      ..strokeWidth = 0.8;

    const steps = 3;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final y = chartBottom - chartHeight * t;
      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartRight, y),
        gridPaint,
      );

      final labelVal = (maxY * t).round().toString();
      final tp = TextPainter(
        text: TextSpan(
          text: labelVal,
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF47574C),
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(leftAxisWidth - tp.width - 8, y - tp.height / 2),
      );
    }

    if (values.isEmpty) return;

    final points = <Offset>[];
    final count = values.length;
    for (int i = 0; i < count; i++) {
      final x = count == 1
          ? chartLeft + chartWidth / 2
          : chartLeft + (chartWidth / (count - 1)) * i;
      final norm = (values[i] / maxY).clamp(0.0, 1.0);
      final y = chartBottom - chartHeight * norm;
      points.add(Offset(x, y));

      if (i < days.length) {
        final dayTp = TextPainter(
          text: TextSpan(
            text: days[i],
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF47574C),
              fontWeight: FontWeight.w400,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        dayTp.paint(
          canvas,
          Offset(x - dayTp.width / 2, chartBottom + 6),
        );
      }
    }

    // Build smooth cubic curve passing through points
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;

      const tension = 0.22;
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) * tension,
        p1.dy + (p2.dy - p0.dy) * tension,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) * tension,
        p2.dy - (p3.dy - p1.dy) * tension,
      );

      linePath.cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy.clamp(chartTop, chartBottom),
        p2.dx,
        p2.dy,
      );
    }

    // Soft green gradient fill under curve
    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, chartBottom)
      ..lineTo(points.first.dx, chartBottom)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF217A38).withValues(alpha: 0.28),
            const Color(0xFF217A38).withValues(alpha: 0.02),
          ],
        ).createShader(
          Rect.fromLTRB(chartLeft, chartTop, chartRight, chartBottom),
        ),
    );

    // Line stroke
    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFF1A6B2F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // Points with crisp white outer ring
    final outerDotPaint = Paint()..color = Colors.white;
    final innerDotPaint = Paint()..color = const Color(0xFF16692B);
    for (final pt in points) {
      canvas.drawCircle(pt, 4.6, outerDotPaint);
      canvas.drawCircle(pt, 3.1, innerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SmoothSplineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.maxY != maxY;
  }
}
