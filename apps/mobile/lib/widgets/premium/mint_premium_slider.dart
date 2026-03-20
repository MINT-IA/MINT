import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// A premium slider with anneau thumb, value pill, and porcelaine track.
///
/// Visually secondary — controls serve the decision, they don't lead it.
/// Used in simulators and budget screens below the hero result.
class MintPremiumSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? formatValue;
  final Color? activeColor;
  final ValueChanged<double> onChanged;

  const MintPremiumSlider({
    super.key,
    required this.label,
    required this.value,
    this.min = 0,
    required this.max,
    this.divisions,
    this.formatValue,
    this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? MintColors.primary;
    final displayValue = formatValue?.call(value) ??
        value.toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label + value pill
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                displayValue,
                style: MintTextStyles.bodySmall(color: color)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm),

        // Slider with porcelaine track
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: color,
            inactiveTrackColor: MintColors.porcelaine,
            thumbColor: MintColors.white,
            overlayColor: color.withValues(alpha: 0.08),
            thumbShape: _AnnularThumbShape(color: color),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Custom thumb with annular (ring) shape — premium feel.
class _AnnularThumbShape extends SliderComponentShape {
  final Color color;
  const _AnnularThumbShape({required this.color});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(10);

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

    // Outer ring
    canvas.drawCircle(
      center,
      10,
      Paint()..color = color,
    );
    // Inner white circle
    canvas.drawCircle(
      center,
      6,
      Paint()..color = MintColors.white,
    );
  }
}
