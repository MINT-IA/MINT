import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// A circular arc gauge inspired by Cleo's spending gauge.
///
/// Shows a percentage or score as a calm arc with a large central number.
/// Used in Aujourd'hui hero and score screens.
class MintProgressArc extends StatelessWidget {
  final double value;
  final double maxValue;
  final String label;
  final String? subtitle;
  final Color? color;
  final double size;

  const MintProgressArc({
    super.key,
    required this.value,
    this.maxValue = 100,
    required this.label,
    this.subtitle,
    this.color,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value / maxValue).clamp(0.0, 1.0);
    final effectiveColor = color ?? _colorForProgress(progress);

    return Semantics(
      label: '$label: ${value.round()} sur ${maxValue.round()}',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _ArcPainter(
                progress: progress,
                color: effectiveColor,
                trackColor: MintColors.border.withValues(alpha: 0.3),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: MintTextStyles.displayLarge(color: effectiveColor)
                      .copyWith(fontSize: size * 0.22),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForProgress(double p) {
    if (p >= 0.7) return MintColors.success;
    if (p >= 0.4) return MintColors.corailDiscret;
    return MintColors.error;
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const startAngle = 0.75 * pi; // 135 degrees
    const sweepTotal = 1.5 * pi; // 270 degrees

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    // Progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
