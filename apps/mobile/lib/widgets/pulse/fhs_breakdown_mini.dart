/// FHS Breakdown Mini — Sprint S54.
///
/// Compact 4-bar breakdown of the FHS sub-scores (L/F/R/S),
/// displayed below the FHS Thermometer on the Pulse screen.
///
/// Each bar shows:
///   - Short label badge (L, F, R, S) with component color
///   - Component name
///   - Horizontal progress bar (0-25)
///   - Numeric score "/25"
///
/// Color mapping (MintColors):
///   L (Liquidite)  → info (blue)
///   F (Fiscalite)  → categoryPurple (purple)
///   R (Retraite)   → teal
///   S (Risque)     → warning (amber)
///
/// Sources: LAVS art. 21-29, LPP art. 14-16, LIFD art. 38.
/// Outil educatif — ne constitue pas un conseil financier (LSFin).
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Compact 4-bar breakdown of FHS sub-scores (Liquidite, Fiscalite, Retraite, Risque).
///
/// Each axis is scored 0-25. Displays as horizontal bars with
/// colored badges, labels, progress indicators, and numeric values.
class FhsBreakdownMini extends StatelessWidget {
  /// Liquidity axis score (0-25).
  final double liquidite;

  /// Fiscal efficiency axis score (0-25).
  final double fiscalite;

  /// Retirement readiness axis score (0-25).
  final double retraite;

  /// Structural risk axis score (0-25).
  final double risque;

  const FhsBreakdownMini({
    super.key,
    required this.liquidite,
    required this.fiscalite,
    required this.retraite,
    required this.risque,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniBar(
            shortLabel: 'L',
            label: S.of(context)!.fhsBreakdownLiquidite,
            value: liquidite,
            color: MintColors.info,
          ),
          const SizedBox(height: 8),
          _MiniBar(
            shortLabel: 'F',
            label: S.of(context)!.fhsBreakdownFiscalite,
            value: fiscalite,
            color: MintColors.categoryPurple,
          ),
          const SizedBox(height: 8),
          _MiniBar(
            shortLabel: 'R',
            label: S.of(context)!.fhsBreakdownRetraite,
            value: retraite,
            color: MintColors.teal,
          ),
          const SizedBox(height: 8),
          _MiniBar(
            shortLabel: 'S',
            label: S.of(context)!.fhsBreakdownRisque,
            value: risque,
            color: MintColors.warning,
          ),
        ],
      ),
    );
  }
}

/// Single mini bar row: [badge] [label] [bar] [score/25].
class _MiniBar extends StatelessWidget {
  final String shortLabel;
  final String label;
  final double value;
  final Color color;

  const _MiniBar({
    required this.shortLabel,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 25.0);
    final fraction = clamped / 25.0;

    return Semantics(
      label: '$label\u00a0: ${clamped.toStringAsFixed(1)} sur 25',
      child: Row(
        children: [
          // Short label badge
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                shortLabel,
                style: MintTextStyles.labelSmall(color: color).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Label
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
            ),
          ),

          // Progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: fraction,
                  backgroundColor: color.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Score text
          SizedBox(
            width: 38,
            child: Text(
              '${clamped.toStringAsFixed(0)}/25',
              textAlign: TextAlign.right,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
