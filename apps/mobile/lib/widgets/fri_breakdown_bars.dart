/// FRI Breakdown Bars — Sprint S39.
///
/// 4 labeled horizontal bars showing each FRI component.
/// Each bar: label + score/25 + colored progress bar.
///
/// Components:
///   - L (Liquidite): info (blue)
///   - F (Fiscalite): purple
///   - R (Retraite): teal
///   - S (Risque): amber
///
/// Design: Material 3, Inter font, MintColors palette.
/// All text in French (informal "tu"). No banned terms.
///
/// References:
///   - ONBOARDING_ARBITRAGE_ENGINE.md § V
///   - LAVS art. 21-29, LPP art. 14-16, LIFD art. 38
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Displays 4 horizontal progress bars for FRI component breakdown.
///
/// Each bar shows a component label, numeric score (out of 25),
/// and a colored progress indicator. Components are:
///   - Liquidite (blue), Fiscalite (purple), Retraite (teal), Risque (amber).
class FriBreakdownBars extends StatelessWidget {
  /// Liquidity score (0-25).
  final double liquidite;

  /// Fiscal efficiency score (0-25).
  final double fiscalite;

  /// Retirement readiness score (0-25).
  final double retraite;

  /// Structural risk score (0-25).
  final double risque;

  const FriBreakdownBars({
    super.key,
    required this.liquidite,
    required this.fiscalite,
    required this.retraite,
    required this.risque,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BarRow(
          label: 'Liquidite',
          shortLabel: 'L',
          value: liquidite,
          color: MintColors.info,
        ),
        const SizedBox(height: 10),
        _BarRow(
          label: 'Fiscalite',
          shortLabel: 'F',
          value: fiscalite,
          color: MintColors.purple,
        ),
        const SizedBox(height: 10),
        _BarRow(
          label: 'Retraite',
          shortLabel: 'R',
          value: retraite,
          color: MintColors.teal,
        ),
        const SizedBox(height: 10),
        _BarRow(
          label: 'Risque',
          shortLabel: 'S',
          value: risque,
          color: MintColors.amber,
        ),
      ],
    );
  }
}

/// Single bar row: [short label badge] [label text] [spacer] [score/25] [bar].
class _BarRow extends StatelessWidget {
  final String label;
  final String shortLabel;
  final double value;
  final Color color;

  const _BarRow({
    required this.label,
    required this.shortLabel,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 25.0);
    final fraction = clamped / 25.0;

    return Semantics(
      label: '$label: ${clamped.toStringAsFixed(1)} sur 25',
      child: Row(
        children: [
          // Short label badge
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: const Borderconst Radius.circular(7),
            ),
            child: Center(
              child: Text(
                shortLabel,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Label
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ),

          // Progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: const Borderconst Radius.circular(4),
              child: SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: fraction,
                  backgroundColor: color.withAlpha(20),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Score text
          SizedBox(
            width: 42,
            child: Text(
              '${clamped.toStringAsFixed(0)}/25',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
