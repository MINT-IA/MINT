/// FinancialPlanCard — Persistent plan card for the Aujourd'hui tab.
///
/// Displays the user's current [FinancialPlan] between Section 1
/// (ChiffreVivant) and Section 2 (ItineraireAlternatif) on MintHomeScreen.
///
/// Features:
///   - Hero monthly CHF (displayMedium)
///   - Goal prefix + description
///   - Target date
///   - Progress bar (0% in Phase 4 — no check-ins yet)
///   - "Voir le détail" toggle to expand milestones + confidence bands
///   - Stale state: amber badge + "Recalculer" CTA
///
/// Threat T-04-10: "Recalculer" passes a pre-formatted i18n prompt via
/// [onRecalculate]; the user must explicitly tap Send in the coach.
///
/// Compliance: educational tool only (LSFin). No advice, no ranking.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Persistent financial plan card shown on the Aujourd'hui tab.
///
/// Hidden entirely when [hasPlan] is false — the caller (MintHomeScreen)
/// is responsible for gating visibility via `if (provider.hasPlan)`.
class FinancialPlanCard extends StatefulWidget {
  /// The current persisted plan. Must not be null when this widget is shown.
  final FinancialPlan plan;

  /// When true, shows amber "Profil modifié" badge and "Recalculer" CTA.
  final bool isStale;

  /// Called when user taps "Recalculer". Caller opens coach with pre-seeded text.
  /// The pre-seeded text is derived here and passed via the callback indirection
  /// in MintHomeScreen.
  final void Function(String recalculatePrompt) onRecalculate;

  /// True while the caller is replacing a stale plan.
  final bool isRecalculating;

  /// True when the latest replacement attempt failed.
  final bool hasRecalculationError;

  const FinancialPlanCard({
    super.key,
    required this.plan,
    required this.isStale,
    required this.onRecalculate,
    this.isRecalculating = false,
    this.hasRecalculationError = false,
  });

  @override
  State<FinancialPlanCard> createState() => _FinancialPlanCardState();
}

class _FinancialPlanCardState extends State<FinancialPlanCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final plan = widget.plan;

    if (widget.isStale) {
      return _StalePlanState(
        isRecalculating: widget.isRecalculating,
        hasError: widget.hasRecalculationError,
        onRecalculate: () => widget.onRecalculate(
          l10n.planCard_recalculatePrompt(plan.goalDescription),
        ),
      );
    }

    // Number formatters
    final localeName = Localizations.localeOf(context).toString();
    final chfFmt = NumberFormat('#,##0', localeName);
    final dateFmt = DateFormat.yMMMM(localeName);
    final quarterFmt = DateFormat('QQQ yyyy', localeName);

    final freshCard = Container(
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.border.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Goal row: label + description + stale badge ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${l10n.planCard_goalPrefix} ',
                        style: MintTextStyles.titleMedium(
                          color: MintColors.textSecondary,
                        ),
                      ),
                      TextSpan(
                        text: plan.goalDescription,
                        style: MintTextStyles.titleMedium(
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.isStale) ...[
                const SizedBox(width: MintSpacing.sm),
                _StaleBadge(label: l10n.planCard_staleBadge),
              ],
            ],
          ),

          const SizedBox(height: MintSpacing.xs),

          // ── Hero: monthly CHF target ──
          Semantics(
            identifier: 'financial_plan_home_monthly_amount',
            container: true,
            child: Text(
              l10n.planCard_monthlyAmount(chfFmt.format(plan.monthlyTarget)),
              style: MintTextStyles.displayMedium(
                color: MintColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(height: MintSpacing.sm),

          // ── Target date ──
          Text(
            l10n.planCard_targetDate(dateFmt.format(plan.targetDate)),
            style: MintTextStyles.bodyMedium(
              color: MintColors.textMuted,
            ),
          ),

          const SizedBox(height: MintSpacing.md),

          _PlanTransparencySummary(
            plan: plan,
            chfFmt: chfFmt,
            l10n: l10n,
          ),

          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              identifier: 'financial_plan_home_details',
              button: true,
              child: _CtaButton(
                isStale: widget.isStale,
                isExpanded: _isExpanded,
                ctaDetail: l10n.planCard_ctaDetail,
                ctaHide: l10n.planCard_ctaHide,
                ctaRecalculate: l10n.planCard_ctaRecalculate,
                onDetailTap: () => setState(() => _isExpanded = !_isExpanded),
                onRecalculateTap: () => widget.onRecalculate(
                  l10n.planCard_recalculatePrompt(plan.goalDescription),
                ),
              ),
            ),
          ),

          // ── Expanded detail section ──
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isExpanded ? 1.0 : 0.0,
              child: _isExpanded
                  ? _ExpandedDetail(
                      plan: plan,
                      quarterFmt: quarterFmt,
                      chfFmt: chfFmt,
                      l10n: l10n,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      identifier: 'financial_plan_home_fresh_state',
      container: true,
      explicitChildNodes: true,
      child: freshCard,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StalePlanState extends StatelessWidget {
  const _StalePlanState({
    required this.isRecalculating,
    required this.hasError,
    required this.onRecalculate,
  });

  final bool isRecalculating;
  final bool hasError;
  final VoidCallback onRecalculate;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.warning.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            identifier: 'financial_plan_stale_state',
            container: true,
            liveRegion: hasError,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.update_outlined,
                      color: MintColors.warning,
                    ),
                    const SizedBox(width: MintSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.planCard_staleBadge,
                        style: MintTextStyles.titleMedium(
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasError) ...[
                  const SizedBox(height: MintSpacing.sm),
                  Text(
                    l10n.planCard_errorBody,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.md),
          Semantics(
            identifier: 'financial_plan_stale_recalculate',
            container: true,
            button: true,
            enabled: !isRecalculating,
            onTap: isRecalculating ? null : onRecalculate,
            child: ExcludeSemantics(
              child: FilledButton.icon(
                onPressed: isRecalculating ? null : onRecalculate,
                icon: isRecalculating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(l10n.planCard_ctaRecalculate),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Amber badge shown when the plan is stale (profile changed since generation).
class _StaleBadge extends StatelessWidget {
  final String label;

  const _StaleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.sm,
        vertical: MintSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: MintTextStyles.bodyMedium(color: MintColors.warning),
      ),
    );
  }
}

/// CTA button that changes label based on state (normal vs stale, expanded vs collapsed).
class _CtaButton extends StatelessWidget {
  final bool isStale;
  final bool isExpanded;
  final String ctaDetail;
  final String ctaHide;
  final String ctaRecalculate;
  final VoidCallback onDetailTap;
  final VoidCallback onRecalculateTap;

  const _CtaButton({
    required this.isStale,
    required this.isExpanded,
    required this.ctaDetail,
    required this.ctaHide,
    required this.ctaRecalculate,
    required this.onDetailTap,
    required this.onRecalculateTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isStale) {
      return TextButton(
        onPressed: onRecalculateTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.sm,
            vertical: MintSpacing.xs,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          ctaRecalculate,
          style: MintTextStyles.bodyMedium(color: MintColors.warning),
        ),
      );
    }

    return TextButton(
      onPressed: onDetailTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.sm,
          vertical: MintSpacing.xs,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        isExpanded ? ctaHide : ctaDetail,
        style: MintTextStyles.bodyMedium(color: MintColors.primary),
      ),
    );
  }
}

class _PlanTransparencySummary extends StatelessWidget {
  const _PlanTransparencySummary({
    required this.plan,
    required this.chfFmt,
    required this.l10n,
  });

  final FinancialPlan plan;
  final NumberFormat chfFmt;
  final S l10n;

  @override
  Widget build(BuildContext context) {
    final isRetirement = plan.goalCategory == 'goal_retirement_plan' ||
        plan.goalCategory == 'goal_pension_opt';
    final assumptions = plan.projectionAssumptions;
    final isNoLppRetirement = plan.dependencyBranch == 'retirementNoLpp';
    final isLppRetirement = plan.dependencyBranch == 'retirementLpp';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRetirement) ...[
          Text(
            isNoLppRetirement
                ? l10n.planCard_retirementScopeNoLpp
                : l10n.planCard_retirementScopeLpp,
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.sm),
        ],
        if (plan.projectedLow != null && plan.projectedHigh != null) ...[
          Text(
            l10n.planCard_confidenceBands(
              chfFmt.format(plan.projectedLow!),
              chfFmt.format(plan.projectedOutcome),
              chfFmt.format(plan.projectedHigh!),
            ),
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.sm),
        ],
        Text(
          l10n.planCard_dataConfidence(
            plan.confidenceLevel.round().toString(),
          ),
          style: MintTextStyles.micro(color: MintColors.textMuted),
        ),
        if (plan.confidenceLevel < 70 &&
            (!isRetirement ||
                (isLppRetirement &&
                    FeatureFlags.lppEvidenceIngestionEnabled))) ...[
          const SizedBox(height: MintSpacing.xs),
          Semantics(
            identifier: 'financial_plan_home_improve_precision',
            button: true,
            child: TextButton(
              onPressed: () => context.push(
                isLppRetirement
                    ? '/scan?type=lppCertificate'
                    : '/data-block/revenu',
              ),
              child: Text(l10n.planCard_improvePrecision),
            ),
          ),
        ],
        if (assumptions != null) ...[
          const SizedBox(height: MintSpacing.sm),
          ..._assumptionLines(context, assumptions).map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.xs),
              child: Text(
                line,
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
            ),
          ),
        ],
        const SizedBox(height: MintSpacing.sm),
      ],
    );
  }

  List<String> _assumptionLines(
    BuildContext context,
    FinancialPlanProjectionAssumptions assumptions,
  ) {
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
      lines.add(l10n.planCard_returnBase(percent.format(value)));
    }
    if (assumptions.caisseReturnLow case final value?) {
      lines.add(l10n.planCard_returnLow(percent.format(value)));
    }
    if (assumptions.caisseReturnHigh case final value?) {
      lines.add(l10n.planCard_returnHigh(percent.format(value)));
    }
    if (assumptions.supplementalMonthlySavingsReturn == 0) {
      lines.add(l10n.planCard_supplementalSavingsReturnZero);
    }
    final salary = assumptions.salaryBasis;
    if (salary.annualChf case final amount?) {
      final formatted = chf.format(amount).trim();
      if (salary.kind == 'declaredInsuredSalary') {
        lines.add(l10n.planCard_salaryDeclared(formatted));
      } else if (salary.kind == 'monthlySalaryTimesTwelve') {
        lines.add(l10n.planCard_salaryFallback(formatted));
      }
    }
    final bonification = assumptions.bonificationBasis;
    if (bonification.kind == 'declaredFundRate' &&
        bonification.annualRate != null) {
      lines.add(
        l10n.planCard_bonificationDeclared(
          percent.format(bonification.annualRate),
        ),
      );
    } else if (bonification.kind == 'legalAgeSchedule') {
      lines.add(l10n.planCard_bonificationLegal);
    }
    if (assumptions.annualProjectionUsesWholeYears) {
      lines.add(l10n.planCard_annualWholeYearsAssumption);
    }
    if (assumptions.requiresFundAuthorizationBefore63) {
      lines.add(l10n.planCard_earlyRetirementFundAuthorization);
    }
    if (assumptions.assumesPostReferenceGainfulActivity) {
      lines.add(l10n.planCard_postReferenceActivityAssumption);
    }
    if (assumptions.projectionAsOf.millisecondsSinceEpoch > 0) {
      lines.add(
        l10n.planCard_projectionAsOf(
          DateFormat.yMd(localeName).format(assumptions.projectionAsOf),
        ),
      );
    }
    return lines;
  }
}

/// Expanded detail showing milestones, economic assumptions and provenance.
class _ExpandedDetail extends StatelessWidget {
  final FinancialPlan plan;
  final DateFormat quarterFmt;
  final NumberFormat chfFmt;
  final S l10n;

  const _ExpandedDetail({
    required this.plan,
    required this.quarterFmt,
    required this.chfFmt,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final milestones = plan.milestones.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: MintSpacing.md),

        // ── Milestones heading ──
        Text(
          l10n.planCard_milestonesHeading,
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),

        const SizedBox(height: MintSpacing.xs),

        // ── Milestone rows ──
        ...milestones.asMap().entries.map((entry) => _MilestoneRow(
              date: quarterFmt.format(entry.value.targetDate),
              amount: l10n.budgetReportChfAmount(
                chfFmt.format(entry.value.targetAmount),
              ),
              description: l10n.planCard_milestoneLabel(
                (((entry.key + 1) * 100) / milestones.length)
                    .round()
                    .toString(),
              ),
            )),

        const SizedBox(height: MintSpacing.md),

        if (plan.sources.isNotEmpty) ...[
          Text(
            l10n.askMintSourcesTitle,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.xs),
          ...plan.sources.map(
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

        // ── Disclaimer ──
        Text(
          l10n.planCard_disclaimer,
          style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),

        const SizedBox(height: MintSpacing.xs),
      ],
    );
  }
}

/// A single milestone row: date | description | CHF amount.
class _MilestoneRow extends StatelessWidget {
  final String date;
  final String amount;
  final String description;

  const _MilestoneRow({
    required this.date,
    required this.amount,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              date,
              style: MintTextStyles.bodyMedium(color: MintColors.textMuted),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              description,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Text(
            amount,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
