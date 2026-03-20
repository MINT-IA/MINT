import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// A premium slider with warm aesthetics, large thumb, and value pill.
///
/// Replaces the standard Material slider with a calm, editorial feel:
/// - Warm track colors (porcelaine inactive, primary active)
/// - Large, soft thumb (14px radius, subtle shadow)
/// - Value displayed in a floating pill above the thumb
/// - Label + formatted value on the same line above
/// - Optional unit suffix
///
/// Used across all 46 simulator/calculator screens in MINT.
class MintPremiumSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) formatValue;
  final ValueChanged<double> onChanged;
  final Color? activeColor;
  final String? semanticsLabel;

  const MintPremiumSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.formatValue,
    required this.onChanged,
    this.activeColor,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = activeColor ?? MintColors.primary;

    return Semantics(
      label: semanticsLabel ?? '$label: ${formatValue(value)}',
      slider: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + value row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  formatValue(value),
                  style: MintTextStyles.titleMedium(
                    color: effectiveColor,
                  ).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 2),

          // The slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: effectiveColor,
              inactiveTrackColor: MintColors.porcelaine,
              thumbColor: MintColors.white,
              overlayColor: effectiveColor.withValues(alpha: 0.08),
              trackHeight: 6,
              thumbShape: _PremiumThumbShape(
                thumbRadius: 14,
                ringColor: effectiveColor,
              ),
              trackShape: const RoundedRectSliderTrackShape(),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              tickMarkShape: SliderTickMarkShape.noTickMark,
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom thumb: white circle with colored ring and subtle shadow.
/// Inspired by premium fintech apps (Cleo, Revolut, Wise).
class _PremiumThumbShape extends SliderComponentShape {
  final double thumbRadius;
  final Color ringColor;

  const _PremiumThumbShape({
    required this.thumbRadius,
    required this.ringColor,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Shadow
    final shadowPaint = Paint()
      ..color = MintColors.textPrimary.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center + const Offset(0, 2), thumbRadius - 2, shadowPaint);

    // White fill
    final fillPaint = Paint()
      ..color = MintColors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, thumbRadius - 1, fillPaint);

    // Colored ring
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, thumbRadius - 2, ringPaint);

    // Inner dot
    final dotPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }
}

/// A compact variant for forms/onboarding where space is tight.
/// Shows just the slider with inline value, no label row.
class MintCompactSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final Color? activeColor;

  const MintCompactSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = activeColor ?? MintColors.primary;

    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: effectiveColor,
        inactiveTrackColor: MintColors.porcelaine,
        thumbColor: MintColors.white,
        overlayColor: effectiveColor.withValues(alpha: 0.08),
        trackHeight: 6,
        thumbShape: _PremiumThumbShape(
          thumbRadius: 12,
          ringColor: effectiveColor,
        ),
        trackShape: const RoundedRectSliderTrackShape(),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}
