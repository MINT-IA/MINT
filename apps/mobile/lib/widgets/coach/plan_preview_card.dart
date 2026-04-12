import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────────────────────
//  PlanPreviewCard — Inline chat widget for generated financial plans
//
//  Displays a FinancialPlan inline in the coach chat.
//  Numbers come exclusively from the persisted, calculator-backed plan
//  (T-04-04: NOT from LLM tool call input).
//
//  Layout per 04-UI-SPEC.md:
//    - Goal description (titleMedium)
//    - Hero monthly CHF (displayMedium)
//    - Divider
//    - Jalons (4 milestones at 25/50/75/100%)
//    - Coach narrative
//    - Confidence bands (when confidenceLevel < 70)
//    - Disclaimer (micro, italic)
// ────────────────────────────────────────────────────────────────────────────

/// Inline chat card for a generated financial plan.
///
/// All user-facing strings are loaded from [AppLocalizations].
/// All colors use [MintColors.*] — no hardcoded hex values.
/// All spacing uses [MintSpacing.*] — no hardcoded numbers.
class PlanPreviewCard extends StatelessWidget {
  /// User-readable goal description.
  final String goalDescription;

  /// Monthly savings target in CHF (calculator-backed, not LLM output).
  final double monthlyTarget;

  /// 4 milestones at 25/50/75/100% of goal.
  final List<PlanMilestone> milestones;

  /// Coach narrative (LLM-generated, compliance-filtered).
  final String coachNarrative;

  /// Educational disclaimer (LSFin compliant).
  final String disclaimer;

  /// Lower-bound projection (pessimistic). Null if not computed.
  final double? projectedLow;

  /// Central projected outcome.
  final double projectedMid;

  /// Upper-bound projection (optimistic). Null if not computed.
  final double? projectedHigh;

  /// Confidence level 0–100. Bands shown when < 70.
  final double confidenceLevel;

  const PlanPreviewCard({
    super.key,
    required this.goalDescription,
    required this.monthlyTarget,
    required this.milestones,
    required this.coachNarrative,
    required this.disclaimer,
    this.projectedLow,
    required this.projectedMid,
    this.projectedHigh,
    required this.confidenceLevel,
  });

  /// Build a [PlanPreviewCard] from a [FinancialPlan].
  factory PlanPreviewCard.fromPlan(FinancialPlan plan) {
    return PlanPreviewCard(
      goalDescription: plan.goalDescription,
      monthlyTarget: plan.monthlyTarget,
      milestones: plan.milestones,
      coachNarrative: plan.coachNarrative,
      disclaimer: plan.disclaimer,
      projectedLow: plan.projectedLow,
      projectedMid: plan.projectedOutcome,
      projectedHigh: plan.projectedHigh,
      confidenceLevel: plan.confidenceLevel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final chfFormat = NumberFormat.currency(
      locale: 'fr_CH',
      symbol: '',
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Goal description ──────────────────────────────────────────
          Text(
            '${l.planCard_goalPrefix} $goalDescription',
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.sm),

          // ── Hero monthly CHF ──────────────────────────────────────────
          Text(
            "${chfFormat.format(monthlyTarget).trim()}\u00a0CHF\u00a0/\u00a0mois",
            style: MintTextStyles.displayMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.md),

          // ── Divider ───────────────────────────────────────────────────
          Divider(
            color: MintColors.border.withAlpha(128),
            thickness: 0.5,
          ),
          const SizedBox(height: MintSpacing.sm),

          // ── Jalons heading ────────────────────────────────────────────
          Text(
            l.planCard_milestonesHeading,
            style: MintTextStyles.bodyMedium(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.xs),

          // ── 4 milestone rows ──────────────────────────────────────────
          ...milestones.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.xs),
              child: Row(
                children: [
                  Text(
                    DateFormat('MMM yyyy', 'fr_CH').format(m.targetDate),
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Text(
                    '${chfFormat.format(m.targetAmount).trim()}\u00a0CHF',
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(
                      m.description,
                      style: MintTextStyles.bodyMedium(
                          color: MintColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.md),

          // ── Coach narrative ───────────────────────────────────────────
          Text(
            coachNarrative,
            style: MintTextStyles.bodyLarge(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.md),

          // ── Confidence bands (shown when confidence < 70) ─────────────
          if (confidenceLevel < 70 &&
              projectedLow != null &&
              projectedHigh != null) ...[
            Text(
              l.planCard_confidenceBands(
                chfFormat.format(projectedLow).trim(),
                chfFormat.format(projectedMid).trim(),
                chfFormat.format(projectedHigh).trim(),
              ),
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
            const SizedBox(height: MintSpacing.sm),
          ],

          // ── Disclaimer ────────────────────────────────────────────────
          Text(
            disclaimer,
            style: MintTextStyles.micro(color: MintColors.textMuted)
                .copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
