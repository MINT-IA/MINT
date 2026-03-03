import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  PLAN REALITY CARD — Phase 5 / Dashboard Assembly
// ────────────────────────────────────────────────────────────
//
// Carte d'adhérence au plan : badge + barres de progression
// + prochaines actions + impact composé projeté.
//
// Outil éducatif — ne constitue pas un conseil financier (LSFin).
// ────────────────────────────────────────────────────────────

class PlanRealityCard extends StatelessWidget {
  final PlanStatus status;
  final double compoundImpact;
  final int monthsToRetirement;

  const PlanRealityCard({
    super.key,
    required this.status,
    required this.compoundImpact,
    required this.monthsToRetirement,
  });

  @override
  Widget build(BuildContext context) {
    final adherence = status.adherenceRate;
    final badgeColor = adherence >= 0.8
        ? MintColors.success
        : adherence >= 0.5
            ? MintColors.warning
            : MintColors.error;
    final badgeLabel = adherence >= 0.8
        ? 'En bonne voie'
        : adherence >= 0.5
            ? 'Peut progresser'
            : 'À renforcer';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mon plan',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textSecondary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Adherence progress bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: adherence,
                      backgroundColor: MintColors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(adherence * 100).round()}%',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${status.completedActions} / ${status.totalActions} actions complétées',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Next actions
            if (status.nextActions.isNotEmpty) ...[
              Text(
                'Prochaines actions',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...status.nextActions.map((action) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.radio_button_unchecked,
                            size: 16, color: MintColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            action,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: MintColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],

            // Compound impact
            if (compoundImpact > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Impact composé estimé sur ${(monthsToRetirement / 12).round()} ans',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatChf(compoundImpact),
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: MintColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rendement conservateur 2% réel / an. Outil éducatif.',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: MintColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
