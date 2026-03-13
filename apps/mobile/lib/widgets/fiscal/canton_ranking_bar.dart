import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/fiscal_service.dart';

// ────────────────────────────────────────────────────────────
//  CANTON RANKING BAR — Sprint S20 / Comparateur 26 cantons
// ────────────────────────────────────────────────────────────
//
// Reusable horizontal bar chart row for canton ranking.
// Shows: [rank] [canton code] [canton name] [bar] [CHF amount]
// Color gradient: green (cheapest) → red (most expensive).
// ────────────────────────────────────────────────────────────

class CantonRankingBar extends StatelessWidget {
  final String cantonCode;
  final String cantonName;
  final int rang;
  final double chargeTotale;
  final double tauxEffectif;
  final double maxCharge;
  final bool isHighlighted;

  const CantonRankingBar({
    super.key,
    required this.cantonCode,
    required this.cantonName,
    required this.rang,
    required this.chargeTotale,
    required this.tauxEffectif,
    required this.maxCharge,
    this.isHighlighted = false,
  });

  /// Color gradient from green (rank 1) to red (rank 26).
  Color _barColor() {
    // Normalize rang 1-26 to 0.0-1.0
    final t = (rang - 1) / 25.0;
    if (t < 0.33) {
      // Green zone
      return Color.lerp(
        MintColors.greenDirect,
        MintColors.amberLight,
        t / 0.33,
      )!;
    } else if (t < 0.66) {
      // Yellow zone
      return Color.lerp(
        MintColors.amberLight,
        MintColors.orangeMaterial,
        (t - 0.33) / 0.33,
      )!;
    } else {
      // Red zone
      return Color.lerp(
        MintColors.orangeMaterial,
        MintColors.danger,
        (t - 0.66) / 0.34,
      )!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final barFraction = maxCharge > 0 ? (chargeTotale / maxCharge) : 0.0;
    final color = _barColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? MintColors.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isHighlighted
            ? Border.all(color: MintColors.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 24,
            child: Text(
              '$rang',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isHighlighted
                    ? MintColors.primary
                    : MintColors.textMuted,
              ),
            ),
          ),
          // Canton code badge
          Container(
            width: 34,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isHighlighted
                  ? MintColors.primary
                  : color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              cantonCode,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isHighlighted ? MintColors.white : color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Canton name
          SizedBox(
            width: 90,
            child: Text(
              cantonName,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
                color: isHighlighted
                    ? MintColors.textPrimary
                    : MintColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Horizontal bar
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth * barFraction;
                return Stack(
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: MintColors.appleSurface,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      height: 14,
                      width: barWidth.clamp(0.0, constraints.maxWidth),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // CHF amount
          SizedBox(
            width: 70,
            child: Text(
              FiscalService.formatChf(chargeTotale),
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isHighlighted
                    ? MintColors.primary
                    : MintColors.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
