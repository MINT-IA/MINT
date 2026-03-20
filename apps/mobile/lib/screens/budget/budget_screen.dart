import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/budget/spending_meter.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/budget/stop_rule_callout.dart';
import 'package:mint_mobile/widgets/budget/emergency_fund_ring.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/coach/budget_sandwich_chart.dart';
import 'package:mint_mobile/widgets/coach/budget_503020_widget.dart';
import 'package:mint_mobile/widgets/coach/crash_test_budget_widget.dart';
import 'package:mint_mobile/widgets/collapsible_section.dart';

class BudgetScreen extends StatefulWidget {
  final BudgetInputs inputs;

  const BudgetScreen({
    super.key,
    required this.inputs,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  late Animation<double> _staggerAnimation;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('budget');
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _staggerAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<BudgetProvider>().setInputs(widget.inputs);
        _staggerController.forward();
      } catch (_) {
        if (mounted) setState(() => _hasError = true);
      }
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _staggeredEntry({required int index, required Widget child}) {
    const totalSlots = 6;
    return AnimatedBuilder(
      animation: _staggerAnimation,
      builder: (context, _) {
        final cardProgress =
            ((_staggerAnimation.value * totalSlots) - index).clamp(0.0, 1.0);
        return Opacity(
          opacity: cardProgress,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - cardProgress)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        title: Text(
          l.budgetMonthlyTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: Consumer<BudgetProvider>(
        builder: (context, provider, child) {
          if (_hasError) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(MintSpacing.md),
                margin: const EdgeInsets.all(MintSpacing.lg),
                decoration: BoxDecoration(
                  color: MintColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: MintColors.error.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: MintColors.error, size: 20),
                    const SizedBox(width: MintSpacing.sm),
                    Expanded(
                      child: Text(
                        l.budgetErrorRetry,
                        style: MintTextStyles.bodySmall(
                            color: MintColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final plan = provider.plan;

          if (plan == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(MintSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── ABOVE FOLD: Section 1 — Data quality banner ──
                _staggeredEntry(
                  index: 0,
                  child: _buildDataQualityBanner(widget.inputs, l),
                ),
                const SizedBox(height: MintSpacing.sm),

                // ── ABOVE FOLD: Section 2 — Hero chiffre + caption ──
                _staggeredEntry(index: 0, child: _buildHeader(plan, l)),
                const SizedBox(height: MintSpacing.lg),

                // ── ABOVE FOLD: Section 3 — Spending meter ──
                _staggeredEntry(
                  index: 1,
                  child: SpendingMeter(
                    variablesAmount: plan.variables,
                    futureAmount: plan.future,
                    totalAvailable: plan.available,
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),

                // ── BELOW FOLD: Envelopes sliders ──
                if (widget.inputs.style == BudgetStyle.envelopes3) ...[
                  _staggeredEntry(
                    index: 2,
                    child: _buildSliders(context, provider, plan, l),
                  ),
                  const SizedBox(height: MintSpacing.lg),
                ],
                if (plan.stopRuleTriggered) ...[
                  _staggeredEntry(
                    index: 2,
                    child: const StopRuleCallout(),
                  ),
                  const SizedBox(height: MintSpacing.lg),
                ],

                // ── Educational insert ──
                _staggeredEntry(
                  index: 2,
                  child: _buildEducationalInsert(l),
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── 50/30/20 Rule ──
                _staggeredEntry(
                  index: 3,
                  child: Budget503020Widget(
                    netSalary: widget.inputs.netIncome,
                    chiffreChoc: plan.available > 0
                        ? l.budgetChiffreChoc503020(
                            (plan.available * 0.20).toStringAsFixed(0),
                            (plan.available * 0.20 * 120).toStringAsFixed(0),
                          )
                        : null,
                    categories: [
                      BudgetCategory(
                        label: l.budgetNeeds,
                        emoji: '',
                        percent: 50,
                        amount: plan.available * 0.50,
                        examples: [
                          l.budgetExampleRent,
                          l.budgetExampleLamal,
                          l.budgetExampleTaxes,
                          l.budgetExampleDebts,
                        ],
                      ),
                      BudgetCategory(
                        label: l.budgetLife,
                        emoji: '',
                        percent: 30,
                        amount: plan.available * 0.30,
                        examples: [
                          l.budgetExampleFood,
                          l.budgetExampleTransport,
                          l.budgetExampleLeisure,
                        ],
                      ),
                      BudgetCategory(
                        label: l.budgetFuture,
                        emoji: '',
                        percent: 20,
                        amount: plan.available * 0.20,
                        examples: [
                          l.budgetExampleSavings,
                          '3a',
                          l.budgetExampleProjects,
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── Sandwich chart ──
                _staggeredEntry(
                  index: 3,
                  child: BudgetSandwichChart(
                    incomes: [
                      BudgetLineItem(
                          label: l.budgetNetIncome,
                          amount: widget.inputs.netIncome),
                    ],
                    expenses: [
                      if (widget.inputs.housingCost > 0)
                        BudgetLineItem(
                            label: l.budgetHousing,
                            amount: widget.inputs.housingCost),
                      if (widget.inputs.taxProvision > 0)
                        BudgetLineItem(
                            label: l.budgetTaxProvision,
                            amount: widget.inputs.taxProvision),
                      if (widget.inputs.healthInsurance > 0)
                        BudgetLineItem(
                            label: l.budgetHealthInsurance,
                            amount: widget.inputs.healthInsurance),
                      if (widget.inputs.debtPayments > 0)
                        BudgetLineItem(
                            label: l.budgetDebts,
                            amount: widget.inputs.debtPayments),
                    ],
                  ),
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── Emergency fund ──
                if (plan.emergencyFundMonths > 0 ||
                    widget.inputs.emergencyFundMonths > 0)
                  _staggeredEntry(
                    index: 3,
                    child: _buildEmergencyFundCard(plan, l),
                  ),
                const SizedBox(height: MintSpacing.lg),

                // ── Crash test ──
                _staggeredEntry(
                  index: 4,
                  child: CrashTestBudgetWidget(
                    monthlyIncome: widget.inputs.netIncome,
                    survivalIncome: widget.inputs.netIncome * 0.70,
                    reserveMonths: widget.inputs.emergencyFundMonths > 0
                        ? widget.inputs.emergencyFundMonths.toDouble()
                        : null,
                    lines: [
                      if (widget.inputs.housingCost > 0)
                        BudgetLine(
                          label: l.budgetHousing,
                          emoji: '',
                          normalAmount: widget.inputs.housingCost,
                          survivalAmount: widget.inputs.housingCost,
                          status: BudgetLineStatus.locked,
                        ),
                      if (widget.inputs.healthInsurance > 0)
                        BudgetLine(
                          label: l.budgetHealthInsurance,
                          emoji: '',
                          normalAmount: widget.inputs.healthInsurance,
                          survivalAmount: widget.inputs.healthInsurance,
                          status: BudgetLineStatus.locked,
                        ),
                      if (widget.inputs.taxProvision > 0)
                        BudgetLine(
                          label: l.budgetTaxProvision,
                          emoji: '',
                          normalAmount: widget.inputs.taxProvision,
                          survivalAmount: widget.inputs.taxProvision * 0.80,
                          status: BudgetLineStatus.paused,
                        ),
                      if (widget.inputs.debtPayments > 0)
                        BudgetLine(
                          label: l.budgetDebts,
                          emoji: '',
                          normalAmount: widget.inputs.debtPayments,
                          survivalAmount: widget.inputs.debtPayments,
                          status: BudgetLineStatus.locked,
                        ),
                      BudgetLine(
                        label: l.budgetVariables,
                        emoji: '',
                        normalAmount: plan.variables,
                        survivalAmount: plan.variables * 0.50,
                        status: BudgetLineStatus.cut,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── Related sections ──
                _staggeredEntry(
                  index: 4,
                  child: _buildRelatedSections(l),
                ),
                const SizedBox(height: MintSpacing.lg),

                // ── Disclaimer ──
                _staggeredEntry(
                  index: 5,
                  child: _buildDisclaimer(l),
                ),
                const SizedBox(height: MintSpacing.md),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BudgetPlan plan, S l) {
    return Column(
      children: [
        Text(
          l.budgetAvailableThisMonth,
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        const SizedBox(height: MintSpacing.sm),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: plan.available),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return Semantics(
              label:
                  'CHF ${plan.available.toStringAsFixed(0)} ${l.budgetAvailableThisMonth}',
              child: Text(
                'CHF\u00a0${value.toStringAsFixed(0)}',
                style: MintTextStyles.displayMedium(),
              ),
            );
          },
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          l.budgetChiffreChocCaption,
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MintSpacing.md),
        _buildBreakdown(l),
      ],
    );
  }

  Widget _buildBreakdown(S l) {
    final income = widget.inputs.netIncome;
    final housing = widget.inputs.housingCost;
    final debt = widget.inputs.debtPayments;
    final taxes = widget.inputs.taxProvision;
    final health = widget.inputs.healthInsurance;
    final otherFixed = widget.inputs.otherFixedCosts;
    final available = income - housing - debt - taxes - health - otherFixed;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          _breakdownRow(l.budgetNetIncome, income, isPositive: true),
          if (housing > 0) ...[
            const SizedBox(height: MintSpacing.sm),
            _breakdownRow(l.budgetHousing, housing),
          ],
          if (debt > 0) ...[
            const SizedBox(height: MintSpacing.sm),
            _breakdownRow(l.budgetDebtRepayment, debt),
          ],
          const SizedBox(height: MintSpacing.sm),
          _breakdownRow(
            taxes > 0 ? l.budgetTaxProvision : l.budgetTaxProvisionNotProvided,
            taxes,
            qualityTag: widget.inputs.isTaxEstimated
                ? l.budgetQualityEstimated
                : l.budgetQualityProvided,
          ),
          const SizedBox(height: MintSpacing.sm),
          _breakdownRow(
            health > 0
                ? l.budgetHealthInsurance
                : l.budgetHealthInsuranceNotProvided,
            health,
            qualityTag: widget.inputs.isHealthEstimated
                ? l.budgetQualityEstimated
                : l.budgetQualityProvided,
          ),
          const SizedBox(height: MintSpacing.sm),
          _breakdownRow(
            otherFixed > 0
                ? l.budgetOtherFixedCosts
                : l.budgetOtherFixedCostsNotProvided,
            otherFixed,
            qualityTag: widget.inputs.isOtherFixedMissing
                ? l.budgetQualityMissing
                : l.budgetQualityProvided,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: MintSpacing.sm),
            child: Divider(height: 1),
          ),
          _breakdownRow(
            l.budgetAvailable,
            available.clamp(0, double.infinity),
            isPositive: true,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double amount,
      {bool isPositive = false, bool isBold = false, String? qualityTag}) {
    final sign = isPositive ? '' : '– ';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: MintTextStyles.bodySmall(
              color: isBold ? MintColors.textPrimary : MintColors.textSecondary,
            ).copyWith(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (qualityTag != null && !isBold) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: MintSpacing.sm),
                decoration: BoxDecoration(
                  color: qualityTag == S.of(context)!.budgetQualityProvided
                      ? MintColors.success.withValues(alpha: 0.12)
                      : qualityTag == S.of(context)!.budgetQualityEstimated
                          ? MintColors.warning.withValues(alpha: 0.12)
                          : MintColors.textMuted.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  qualityTag,
                  style: MintTextStyles.labelSmall(
                    color: qualityTag == S.of(context)!.budgetQualityProvided
                        ? MintColors.success
                        : qualityTag == S.of(context)!.budgetQualityEstimated
                            ? MintColors.warning
                            : MintColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            Text(
              '$sign CHF\u00a0${amount.toStringAsFixed(0)}',
              style: MintTextStyles.bodySmall(
                color: isBold
                    ? MintColors.primary
                    : isPositive
                        ? MintColors.textPrimary
                        : MintColors.error,
              ).copyWith(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataQualityBanner(BudgetInputs inputs, S l) {
    final hasEstimate = inputs.hasEstimatedValues;
    final hasMissing = inputs.hasMissingValues;
    if (!hasEstimate && !hasMissing) {
      return const SizedBox.shrink();
    }
    final message =
        hasMissing ? l.budgetBannerMissing : l.budgetBannerEstimated;
    return Semantics(
      label: l.budgetCompleteMyData,
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/profile/bilan'),
        child: Container(
          padding: const EdgeInsets.all(MintSpacing.sm + MintSpacing.xs),
          decoration: BoxDecoration(
            color: MintColors.warning.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: MintColors.warning),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: MintTextStyles.bodySmall(
                          color: MintColors.textPrimary),
                    ),
                    const SizedBox(height: MintSpacing.xs + 2),
                    Text(
                      l.budgetCompleteMyData,
                      style: MintTextStyles.bodySmall(
                              color: MintColors.primary)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliders(
      BuildContext context, BudgetProvider provider, BudgetPlan plan, S l) {
    return Column(
      children: [
        MintPremiumSlider(
          label: l.budgetEnvelopeFuture,
          value: plan.future,
          min: 0,
          max: plan.available,
          formatValue: (v) => 'CHF\u00a0${v.toInt()}',
          activeColor: MintColors.info,
          onChanged: (val) {
            provider.updateOverride('future', val);
          },
        ),
        const SizedBox(height: MintSpacing.md),
        MintPremiumSlider(
          label: l.budgetEnvelopeVariables,
          value: plan.variables,
          min: 0,
          max: plan.available,
          formatValue: (v) => 'CHF\u00a0${v.toInt()}',
          activeColor: MintColors.success,
          onChanged: (val) {
            provider.updateOverride('variables', val);
          },
        ),
      ],
    );
  }

  Widget _buildEducationalInsert(S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 18, color: MintColors.info),
              const SizedBox(width: MintSpacing.sm),
              Text(
                l.budgetMethodTitle,
                style: MintTextStyles.titleMedium(color: MintColors.info),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l.budgetMethodBody,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            l.budgetMethodSource,
            style: MintTextStyles.micro(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyFundCard(BudgetPlan plan, S l) {
    final months = plan.emergencyFundMonths;
    const target = BudgetPlan.emergencyFundTarget;
    final isComplete = months >= target;

    final progressColor = isComplete
        ? MintColors.success
        : months >= 3
            ? MintColors.warning
            : MintColors.error;

    final statusText = isComplete
        ? l.budgetGoalReached
        : months >= 3
            ? l.budgetOnTrack
            : l.budgetToReinforce;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + MintSpacing.xs),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: MintColors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.shield_rounded : Icons.shield_outlined,
                color: progressColor,
                size: 22,
              ),
              const SizedBox(width: MintSpacing.sm + 2),
              Text(
                l.budgetEmergencyFundTitle,
                style: MintTextStyles.titleMedium(),
              ),
              const Spacer(),
              Semantics(
                label: statusText,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: MintTextStyles.labelSmall(color: progressColor)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          Row(
            children: [
              EmergencyFundRing(
                months: months,
                target: target,
              ),
              const SizedBox(width: MintSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.budgetMonthsCovered(months.toStringAsFixed(1)),
                      style: MintTextStyles.bodySmall(
                              color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      l.budgetTargetMonths(target.toStringAsFixed(0)),
                      style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary),
                    ),
                    const SizedBox(height: MintSpacing.sm + 2),
                    Text(
                      isComplete
                          ? l.budgetEmergencyProtected
                          : l.budgetEmergencySaveMore(
                              target.toStringAsFixed(0)),
                      style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedSections(S l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.budgetExploreAlso,
          style: MintTextStyles.titleMedium(),
        ),
        const SizedBox(height: MintSpacing.sm),
        CollapsibleSection(
          title: l.budgetDebtRatio,
          subtitle: l.budgetDebtRatioSubtitle,
          icon: Icons.warning_amber_rounded,
          child: _buildSectionCta(l.budgetCtaEvaluate, '/debt/ratio'),
        ),
        CollapsibleSection(
          title: l.budgetRepaymentPlan,
          subtitle: l.budgetRepaymentPlanSubtitle,
          icon: Icons.trending_down,
          child: _buildSectionCta(l.budgetCtaPlan, '/debt/repayment'),
        ),
        CollapsibleSection(
          title: l.budgetHelpResources,
          subtitle: l.budgetHelpResourcesSubtitle,
          icon: Icons.help_outline,
          child: _buildSectionCta(l.budgetCtaDiscover, '/debt/help'),
        ),
      ],
    );
  }

  Widget _buildSectionCta(String label, String route) {
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        button: true,
        label: label,
        child: OutlinedButton(
          onPressed: () => context.push(route),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildDisclaimer(S l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: MintSpacing.sm),
        Text(
          l.budgetDisclaimerNote,
          style: MintTextStyles.micro(),
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          l.budgetDisclaimerBased,
          style: MintTextStyles.micro(),
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          l.budgetDisclaimerFormula,
          style: MintTextStyles.micro(),
        ),
      ],
    );
  }
}
