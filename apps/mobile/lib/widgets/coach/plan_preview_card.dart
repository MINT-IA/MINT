import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
//    - Localized calculator-backed narrative
//    - Economic sensitivity bands and explicit assumptions
//    - Data confidence (with enrichment action when low)
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

  /// App-owned scenario category used to select localized explanatory copy.
  final String goalCategory;

  /// Monthly savings target in CHF (calculator-backed, not LLM output).
  final double monthlyTarget;

  /// Calculator-backed milestones, rendered with localized progress labels.
  final List<PlanMilestone> milestones;

  /// Coach narrative (LLM-generated, compliance-filtered).
  final String coachNarrative;

  /// Educational disclaimer (LSFin compliant).
  final String disclaimer;

  /// Sources used by this specific calculator branch.
  final List<String> sources;

  /// Structured calculator assumptions for a retirement scenario.
  final FinancialPlanProjectionAssumptions? projectionAssumptions;

  /// Lower-bound projection (pessimistic). Null if not computed.
  final double? projectedLow;

  /// Central projected outcome.
  final double projectedMid;

  /// Upper-bound projection (optimistic). Null if not computed.
  final double? projectedHigh;

  /// Confidence level 0–100. Bands shown when < 70.
  final double confidenceLevel;

  /// True only for the initial calculator generation state. No financial
  /// amount is rendered until a persisted [FinancialPlan] exists.
  final bool isGenerating;

  /// Whether the initial calculator generation failed.
  final bool generationFailed;

  const PlanPreviewCard({
    super.key,
    required this.goalDescription,
    required this.goalCategory,
    required this.monthlyTarget,
    required this.milestones,
    required this.coachNarrative,
    required this.disclaimer,
    required this.sources,
    this.projectionAssumptions,
    this.projectedLow,
    required this.projectedMid,
    this.projectedHigh,
    required this.confidenceLevel,
    this.isGenerating = false,
    this.generationFailed = false,
  }) : assert(!generationFailed || isGenerating);

  /// Non-numeric placeholder used while the calculator creates the first
  /// persisted plan. It intentionally accepts no monthly target or narrative.
  factory PlanPreviewCard.generating({
    required String goalDescription,
    bool hasError = false,
  }) {
    return PlanPreviewCard(
      goalDescription: goalDescription,
      goalCategory: '',
      monthlyTarget: 0,
      milestones: const [],
      coachNarrative: '',
      disclaimer: '',
      sources: const [],
      projectedMid: 0,
      confidenceLevel: 0,
      isGenerating: true,
      generationFailed: hasError,
    );
  }

  /// Build a [PlanPreviewCard] from a [FinancialPlan].
  factory PlanPreviewCard.fromPlan(FinancialPlan plan) {
    return PlanPreviewCard(
      goalDescription: plan.goalDescription,
      goalCategory: plan.goalCategory,
      monthlyTarget: plan.monthlyTarget,
      milestones: plan.milestones,
      coachNarrative: plan.coachNarrative,
      disclaimer: plan.disclaimer,
      sources: plan.sources,
      projectionAssumptions: plan.projectionAssumptions,
      projectedLow: plan.projectedLow,
      projectedMid: plan.projectedOutcome,
      projectedHigh: plan.projectedHigh,
      confidenceLevel: plan.confidenceLevel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    if (isGenerating) {
      return Semantics(
        identifier: generationFailed
            ? 'financial_plan_generation_error'
            : 'financial_plan_generation_pending',
        container: true,
        liveRegion: true,
        child: Container(
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(MintSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l.planCard_goalPrefix} $goalDescription',
                style: MintTextStyles.titleMedium(
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: MintSpacing.md),
              if (generationFailed)
                Text(
                  l.planCard_errorBody,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    }

    final localeName = Localizations.localeOf(context).toString();
    final chfFormat = NumberFormat.currency(
      locale: localeName,
      symbol: '',
      decimalDigits: 0,
    );
    final isRetirement = goalCategory == 'goal_retirement_plan' ||
        goalCategory == 'goal_pension_opt';
    final isNoLppRetirement = isRetirement &&
        projectionAssumptions?.salaryBasis.kind == 'notApplicable' &&
        projectionAssumptions?.bonificationBasis.kind == 'notApplicable';

    return Container(
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(MintSpacing.md),
      child: SingleChildScrollView(
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
              l.planCard_monthlyAmount(chfFormat.format(monthlyTarget).trim()),
              style:
                  MintTextStyles.displayMedium(color: MintColors.textPrimary),
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
            ...milestones.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: MintSpacing.xs),
                    child: Row(
                      children: [
                        Text(
                          DateFormat.yMMM(localeName)
                              .format(entry.value.targetDate),
                          style: MintTextStyles.bodyMedium(
                              color: MintColors.textSecondary),
                        ),
                        const SizedBox(width: MintSpacing.sm),
                        Text(
                          l.budgetReportChfAmount(
                            chfFormat.format(entry.value.targetAmount).trim(),
                          ),
                          style: MintTextStyles.bodyMedium(
                              color: MintColors.textSecondary),
                        ),
                        const SizedBox(width: MintSpacing.sm),
                        Expanded(
                          child: Text(
                            l.planCard_milestoneLabel(
                              (((entry.key + 1) * 100) / milestones.length)
                                  .round()
                                  .toString(),
                            ),
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
              isNoLppRetirement
                  ? l.planCard_retirementNoLppNarrative(
                      chfFormat.format(monthlyTarget).trim(),
                    )
                  : isRetirement
                      ? l.planCard_retirementNarrative(
                          chfFormat.format(monthlyTarget).trim(),
                        )
                      : l.planCard_generalNarrative(
                          chfFormat.format(monthlyTarget).trim(),
                        ),
              style: MintTextStyles.bodyLarge(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.md),

            if (isRetirement) ...[
              Text(
                isNoLppRetirement
                    ? l.planCard_retirementScopeNoLpp
                    : l.planCard_retirementScopeLpp,
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
              const SizedBox(height: MintSpacing.sm),
            ],

            // Economic sensitivity is independent from ledger confidence.
            if (projectedLow != null && projectedHigh != null) ...[
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

            Text(
              l.planCard_dataConfidence(confidenceLevel.round().toString()),
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
            if (confidenceLevel < 70) ...[
              const SizedBox(height: MintSpacing.xs),
              Semantics(
                identifier: 'financial_plan_coach_improve_precision',
                button: true,
                child: TextButton(
                  onPressed: () => context.push(
                    isRetirement ? '/data-block/lpp' : '/data-block/revenu',
                  ),
                  child: Text(l.planCard_improvePrecision),
                ),
              ),
            ],
            const SizedBox(height: MintSpacing.sm),

            if (projectionAssumptions case final assumptions?) ...[
              ..._assumptionLines(
                context: context,
                l: l,
                assumptions: assumptions,
              ).map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: MintSpacing.xs),
                  child: Text(
                    line,
                    style: MintTextStyles.micro(color: MintColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.xs),
            ],

            if (sources.isNotEmpty) ...[
              Text(
                l.askMintSourcesTitle,
                style: MintTextStyles.bodyMedium(color: MintColors.textMuted),
              ),
              const SizedBox(height: MintSpacing.xs),
              ...sources.map(
                (source) => Padding(
                  padding: const EdgeInsets.only(bottom: MintSpacing.xs),
                  child: Text(
                    source,
                    style: MintTextStyles.micro(color: MintColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.sm),
            ],

            // ── Disclaimer ────────────────────────────────────────────────
            Text(
              l.planCard_disclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted)
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _assumptionLines({
    required BuildContext context,
    required S l,
    required FinancialPlanProjectionAssumptions assumptions,
  }) {
    final localeName = Localizations.localeOf(context).toString();
    final percent = NumberFormat.decimalPercentPattern(
      locale: localeName,
      decimalDigits: 1,
    );
    final chf = NumberFormat.currency(
      locale: localeName,
      symbol: '',
      decimalDigits: 0,
    );
    final lines = <String>[];
    if (assumptions.caisseReturnBase case final value?) {
      lines.add(l.planCard_returnBase(percent.format(value)));
    }
    if (assumptions.caisseReturnLow case final value?) {
      lines.add(l.planCard_returnLow(percent.format(value)));
    }
    if (assumptions.caisseReturnHigh case final value?) {
      lines.add(l.planCard_returnHigh(percent.format(value)));
    }
    if (assumptions.supplementalMonthlySavingsReturn == 0) {
      lines.add(l.planCard_supplementalSavingsReturnZero);
    }
    final salary = assumptions.salaryBasis;
    if (salary.annualChf case final amount?) {
      final formatted = chf.format(amount).trim();
      if (salary.kind == 'declaredInsuredSalary') {
        lines.add(l.planCard_salaryDeclared(formatted));
      } else if (salary.kind == 'monthlySalaryTimesTwelve') {
        lines.add(l.planCard_salaryFallback(formatted));
      }
    }
    final bonification = assumptions.bonificationBasis;
    if (bonification.kind == 'declaredFundRate' &&
        bonification.annualRate != null) {
      lines.add(
        l.planCard_bonificationDeclared(
          percent.format(bonification.annualRate),
        ),
      );
    } else if (bonification.kind == 'legalAgeSchedule') {
      lines.add(l.planCard_bonificationLegal);
    }
    if (assumptions.projectionAsOf.millisecondsSinceEpoch > 0) {
      lines.add(
        l.planCard_projectionAsOf(
          DateFormat.yMd(localeName).format(assumptions.projectionAsOf),
        ),
      );
    }
    return lines;
  }
}
