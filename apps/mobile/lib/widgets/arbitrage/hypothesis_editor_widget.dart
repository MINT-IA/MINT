import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Configuration for a single hypothesis slider.
class HypothesisConfig {
  final String key;
  final String label;
  final double min;
  final double max;
  final int divisions;
  final double defaultValue;
  final String unit;

  const HypothesisConfig({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
    required this.divisions,
    required this.defaultValue,
    this.unit = '%',
  });
}

/// Editable sliders for simulation hypotheses.
///
/// Sprint S32 — Arbitrage Phase 1.
/// Each slider shows label + current value + unit.
/// On change, calls [onChanged] with updated values map.
class HypothesisEditorWidget extends StatelessWidget {
  final List<HypothesisConfig> hypotheses;
  final Map<String, double> values;
  final ValueChanged<Map<String, double>> onChanged;

  const HypothesisEditorWidget({
    super.key,
    required this.hypotheses,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hypotheses de simulation',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ajuste les parametres pour voir l\'impact sur les trajectoires.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        for (final h in hypotheses) _buildSlider(h),
      ],
    );
  }

  Widget _buildSlider(HypothesisConfig config) {
    final currentValue = values[config.key] ?? config.defaultValue;
    final displayValue = config.unit == '%'
        ? '${currentValue.toStringAsFixed(1)} %'
        : '${currentValue.toStringAsFixed(0)} ${config.unit}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  config.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                displayValue,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.textMuted.withAlpha(40),
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withAlpha(30),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: currentValue.clamp(config.min, config.max),
              min: config.min,
              max: config.max,
              divisions: config.divisions,
              onChanged: (v) {
                final updated = Map<String, double>.from(values);
                updated[config.key] = v;
                onChanged(updated);
              },
            ),
          ),
        ],
      ),
    );
  }
}
