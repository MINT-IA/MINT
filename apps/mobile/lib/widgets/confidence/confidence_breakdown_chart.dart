import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Horizontal 3-axis confidence visualization used by S46 dashboard.
class ConfidenceBreakdownChart extends StatelessWidget {
  final double completeness;
  final double accuracy;
  final double freshness;

  const ConfidenceBreakdownChart({
    super.key,
    required this.completeness,
    required this.accuracy,
    required this.freshness,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AxisRow(
          label: 'Completude',
          value: completeness,
          color: _colorFor(completeness),
        ),
        const SizedBox(height: 12),
        _AxisRow(
          label: 'Fiabilite source',
          value: accuracy,
          color: _colorFor(accuracy),
        ),
        const SizedBox(height: 12),
        _AxisRow(
          label: 'Fraicheur',
          value: freshness,
          color: _colorFor(freshness),
        ),
      ],
    );
  }

  Color _colorFor(double value) {
    if (value >= 70) return MintColors.success;
    if (value >= 40) return MintColors.warning;
    return MintColors.error;
  }
}

class _AxisRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _AxisRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = value.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: const Borderconst Radius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: pct / 100.0,
            backgroundColor: MintColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
