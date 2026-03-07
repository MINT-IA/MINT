import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  COUPLE NARRATIVE TIMELINE — P1-F / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  Remplace les swim lanes par un "film en 3 actes".
//  Raconte l'histoire du couple au lieu de montrer des barres.
//
//  Widget pur — aucune dependance Provider.
//  Lois : L4 (raconte, ne montre pas) + L2 (avant/apres)
// ────────────────────────────────────────────────────────────

/// A single act in the couple's retirement story.
class CoupleAct {
  /// Act number (1, 2, 3).
  final int number;

  /// Title (e.g., "Vous travaillez tous les deux").
  final String title;

  /// Period (e.g., "2026-2041 (15 ans)").
  final String period;

  /// Combined monthly income.
  final double monthlyIncome;

  /// Percentage change vs previous act (null for act 1).
  final double? deltaPercent;

  /// Key insight or tip for this phase.
  final String insight;

  /// Whether this act is a "dip" (lower income phase).
  final bool isDip;

  const CoupleAct({
    required this.number,
    required this.title,
    required this.period,
    required this.monthlyIncome,
    this.deltaPercent,
    required this.insight,
    this.isDip = false,
  });
}

class CoupleNarrativeTimeline extends StatelessWidget {
  /// The 3 acts of the couple's story.
  final List<CoupleAct> acts;

  /// Names of the partners.
  final String partner1Name;
  final String partner2Name;

  /// Optional coaching tip.
  final String? coachTip;

  const CoupleNarrativeTimeline({
    super.key,
    required this.acts,
    required this.partner1Name,
    required this.partner2Name,
    this.coachTip,
  });

  @override
  Widget build(BuildContext context) {
    if (acts.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: 'Histoire du couple $partner1Name et $partner2Name en '
          '${acts.length} actes.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Icon(Icons.movie_outlined,
                    size: 20, color: MintColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Votre histoire \u00e0 deux',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Acts ──
            ...acts.map((act) => _buildAct(act)),

            // ── Coach tip ──
            if (coachTip != null) ...[
              const SizedBox(height: 12),
              _buildCoachTip(),
            ],

            // ── Disclaimer ──
            const SizedBox(height: 12),
            Text(
              'Estimations \u00e9ducatives \u2014 ne constitue pas un conseil financier (LSFin).',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAct(CoupleAct act) {
    final actColor = act.isDip ? MintColors.scoreAttention : MintColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline dot + line ──
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: actColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${act.number}',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: actColor,
                    ),
                  ),
                ),
              ),
              if (act.number < acts.length)
                Container(
                  width: 2,
                  height: 30,
                  color: MintColors.lightBorder,
                ),
            ],
          ),
          const SizedBox(width: 12),

          // ── Content ──
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: act.isDip
                    ? MintColors.scoreAttention.withValues(alpha: 0.06)
                    : MintColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Act label
                  Text(
                    'ACTE ${act.number} \u00b7 ${act.period}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Title
                  Text(
                    act.title,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Income
                  Row(
                    children: [
                      Text(
                        'Revenus\u00a0: ${formatChfWithPrefix(act.monthlyIncome)}/mois',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: actColor,
                        ),
                      ),
                      if (act.deltaPercent != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(${act.deltaPercent! >= 0 ? "+" : ""}${act.deltaPercent!.toStringAsFixed(0)}%)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: MintColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Insight
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        act.isDip
                            ? Icons.warning_amber_rounded
                            : Icons.arrow_forward,
                        size: 14,
                        color: actColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          act.insight,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: MintColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachTip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              size: 16, color: MintColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              coachTip!,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
