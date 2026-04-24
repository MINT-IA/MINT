// Budget deep-dive — detailed view of spending breakdown.
// Primary budget display is now in PulseScreen via BudgetSnapshot.
// This screen provides the detailed envelope editing.
//
// Hero number sourced from BudgetSnapshot.present.monthlyFree (via
// BudgetLivingEngine) when a CoachProfile is available, ensuring
// consistency with PulseScreen. Falls back to plan.available when not.

import 'package:flutter/material.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/services/cap_engine.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/widgets/action_insight_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_loading_skeleton.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/budget/spending_meter.dart';
import 'package:mint_mobile/widgets/premium/mint_count_up.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/budget/stop_rule_callout.dart';
import 'package:mint_mobile/widgets/budget/emergency_fund_ring.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/coach/budget_sandwich_chart.dart';
import 'package:mint_mobile/widgets/coach/budget_503020_widget.dart';
import 'package:mint_mobile/widgets/coach/crash_test_budget_widget.dart';
import 'package:mint_mobile/widgets/collapsible_section.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/common/mint_empty_state.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

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
  /// Vertical offset (px) for staggered card slide-up animation.
  static const double _slideUpOffset = 20;

  late AnimationController _staggerController;
  late Animation<double> _staggerAnimation;
  bool _hasError = false;
  String? _seqRunId;
  String? _seqStepId;
  bool _finalReturnEmitted = false;

  /// BudgetSnapshot from BudgetLivingEngine — provides the authoritative
  /// hero number (monthlyFree) consistent with PulseScreen.
  /// Null when CoachProfile is unavailable (graceful degradation to plan.available).
  BudgetSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _staggerAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readSequenceContext();
      if (_seqRunId == null) {
        ReportPersistenceService.markSimulatorExplored('budget');
      }
      try {
        context.read<BudgetProvider>().setInputs(widget.inputs);
        _staggerController.forward();
        _emitScreenReturn({
          'netIncome': widget.inputs.netIncome,
          'housingCost': widget.inputs.housingCost,
          'healthInsurance': widget.inputs.healthInsurance,
          'taxProvision': widget.inputs.taxProvision,
        });
      } catch (_) {
        if (mounted) setState(() => _hasError = true);
      }
      // Resolve BudgetSnapshot — prefer the pre-computed value from
      // MintStateProvider (single computation source) to avoid duplicating
      // BudgetLivingEngine.compute(). Fall back to direct computation only
      // when MintStateProvider is not in the widget tree (e.g. tests).
      try {
        final mintSnap =
            context.read<MintStateProvider>().state?.budgetSnapshot;
        if (mintSnap != null) {
          if (mounted) setState(() => _snapshot = mintSnap);
          return;
        }
      } catch (_) {
        // MintStateProvider not in tree — fall through to direct computation.
      }
      try {
        final profileProvider = context.read<CoachProfileProvider>();
        if (profileProvider.hasProfile) {
          final snap =
              BudgetLivingEngine.compute(profileProvider.profile!);
          if (mounted) setState(() => _snapshot = snap);
        }
      } catch (_) {
        // Graceful degradation: keep _snapshot null, fall back to plan.available.
      }
    });
  }

  void _readSequenceContext() {
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map<String, dynamic>) {
        _seqRunId = extra['runId'] as String?;
        _seqStepId = extra['stepId'] as String?;
      }
    } catch (_) {
      // GoRouterState unavailable (no active match) — no sequence context, fine.
    }
  }

  void _emitFinalReturn() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    final inputs = widget.inputs;
    final chargesTotal = inputs.housingCost + inputs.healthInsurance +
        inputs.taxProvision + inputs.otherFixedCosts;
    ScreenCompletionTracker.markCompletedWithReturn('budget',
      ScreenReturn.completed(
        route: '/budget',
        stepOutputs: {
          'revenu_net': inputs.netIncome,
          'charges_totales': chargesTotal,
        },
        runId: _seqRunId, stepId: _seqStepId,
        eventId: 'evt_${_seqRunId}_${DateTime.now().millisecondsSinceEpoch}',
      ));
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  void _emitScreenReturn(Map<String, dynamic> updatedFields) {
    if (_seqRunId != null) return; // Sequence mode: terminal only on pop
    final screenReturn = ScreenReturn.changedInputs(
      route: '/budget',
      updatedFields: updatedFields,
      confidenceDelta: 0.05,
    );
    ScreenCompletionTracker.markCompletedWithReturn('budget', screenReturn);
  }

  Widget _buildActionInsight(S l) {
    CapDecision? cap;
    try {
      final profileProvider = context.read<CoachProfileProvider>();
      if (profileProvider.hasProfile) {
        cap = CapEngine.compute(
          profile: profileProvider.profile!,
          now: DateTime.now(),
          l: l,
          memory: const CapMemory(),
        );
      }
    } catch (_) {
      // Provider not in tree — graceful degradation.
    }
    if (cap != null && cap.ctaRoute != null) {
      return ActionInsightWidget(
        contextLine: cap.whyNow,
        actionLine: cap.ctaLabel,
        impactLine: cap.expectedImpact,
        route: cap.ctaRoute,
      );
    }
    return ActionInsightWidget(
      contextLine: '',
      actionLine: l.actionInsightFallback,
      route: '/coach/chat',
    );
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
            offset: Offset(0, _slideUpOffset * (1 - cardProgress)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    if (widget.inputs.netIncome <= 0) {
      return Scaffold(
        backgroundColor: MintColors.porcelaine,
        appBar: AppBar(
          backgroundColor: MintColors.porcelaine,
          foregroundColor: MintColors.textPrimary,
          elevation: 0,
          surfaceTintColor: MintColors.transparent,
          title: Text(l.budgetMonthlyTitle,
              style: MintTextStyles.headlineMedium()),
        ),
        body: MintEmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: S.of(context)!.budgetEmptyTitle,
          subtitle: S.of(context)!.budgetEmptySubtitle,
          ctaLabel: S.of(context)!.budgetEmptyCta,
          onCta: () => context.go('/coach/chat'),
        ),
      );
    }
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _emitFinalReturn();
      },
      child: Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.porcelaine,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        surfaceTintColor: MintColors.transparent,
        title: Text(
          l.budgetMonthlyTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SafeArea(
        top: false,
        child: Consumer<BudgetProvider>(
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
            return const MintLoadingSkeleton();
          }

          // Hero number: BudgetSnapshot.present.monthlyFree when available,
          // guaranteeing consistency with PulseScreen.
          // Falls back to plan.available when snapshot is not yet computed.
          final heroFree =
              _snapshot?.present.monthlyFree ?? plan.available;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.lg,
              vertical: MintSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── ABOVE FOLD: Section 1 — Data quality banner ──
                _staggeredEntry(
                  index: 0,
                  child: _buildDataQualityBanner(widget.inputs, l),
                ),
                const SizedBox(height: MintSpacing.md),

                // ── ABOVE FOLD: Section 2 — Hero: budget libre (result FIRST) ──
                _staggeredEntry(
                    index: 0, child: _buildHeader(plan, l, heroFree)),
                const SizedBox(height: MintSpacing.md),

                // ── ABOVE FOLD: Section 2b — Action insight ──
                _staggeredEntry(
                  index: 0,
                  child: _buildActionInsight(l),
                ),
                const SizedBox(height: MintSpacing.xxl),

                // ── ABOVE FOLD: Section 3 — Spending meter ──
                _staggeredEntry(
                  index: 1,
                  child: SpendingMeter(
                    variablesAmount: plan.variables,
                    futureAmount: plan.future,
                    totalAvailable: plan.available,
                  ),
                ),
                const SizedBox(height: MintSpacing.xxl),

                // ── BELOW FOLD: Envelopes sliders (secondary visually) ──
                if (widget.inputs.style == BudgetStyle.envelopes3) ...[
                  _staggeredEntry(
                    index: 2,
                    child: _buildSliders(context, provider, plan, l),
                  ),
                  const SizedBox(height: MintSpacing.xl),
                ],
                if (plan.stopRuleTriggered) ...[
                  _staggeredEntry(
                    index: 2,
                    child: const StopRuleCallout(),
                  ),
                  const SizedBox(height: MintSpacing.xl),
                ],

                // ── Educational insert ──
                _staggeredEntry(
                  index: 2,
                  child: _buildEducationalInsert(l),
                ),
                const SizedBox(height: MintSpacing.xxl),

                // ── 50/30/20 Rule ──
                _staggeredEntry(
                  index: 3,
                  child: Budget503020Widget(
                    netSalary: widget.inputs.netIncome,
                    premierEclairage: plan.available > 0
                        ? l.budgetPremierEclairage503020(
                            formatChf(plan.available * 0.20),
                            formatChf(plan.available * 0.20 * 120),
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
      ))))),
    );
  }

  Widget _buildHeader(BudgetPlan plan, S l, double heroFree) {
    final isPositive = heroFree >= 0;
    final heroColor = isPositive ? MintColors.success : MintColors.warning;

    return Column(
      children: [
        // Hero: budget libre — MintHeroNumber (consequence, not output)
        // Uses BudgetSnapshot.present.monthlyFree when available for
        // consistency with PulseScreen, falls back to plan.available.
        MintCountUp(
          value: heroFree,
          prefix: 'CHF\u00a0',
          color: heroColor,
          showLigne: false,
          contextText: l.budgetPremierEclairageCaption,
          semanticsLabel:
              '${formatChfWithPrefix(heroFree)} ${l.budgetAvailableThisMonth}',
        ),
        const SizedBox(height: MintSpacing.xl),

        // Breakdown in MintSurface (craie — warm, no border)
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

    return MintSurface(
      tone: MintSurfaceTone.craie,
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
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
              '$sign ${formatChfWithPrefix(amount)}',
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
        // ── Épargne future: tap-to-type ──
        _BudgetAmountField(
          label: l.budgetEnvelopeFieldFuture,
          initialValue: plan.future,
          max: plan.available,
          accentColor: MintColors.info,
          onChanged: (val) {
            provider.updateOverride('future', val);
            _emitScreenReturn({'budgetFuture': val});
          },
        ),
        const SizedBox(height: MintSpacing.lg),
        // ── Dépenses variables: tap-to-type ──
        _BudgetAmountField(
          label: l.budgetEnvelopeFieldVariables,
          initialValue: plan.variables,
          max: plan.available,
          accentColor: MintColors.success,
          onChanged: (val) {
            provider.updateOverride('variables', val);
            _emitScreenReturn({'budgetVariables': val});
          },
        ),
      ],
    );
  }

  Widget _buildEducationalInsert(S l) {
    return MintSurface(
      tone: MintSurfaceTone.bleu,
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
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

    return MintSurface(
      tone: isComplete ? MintSurfaceTone.sauge : MintSurfaceTone.peche,
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
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
        MintEntrance(child: Text(
          l.budgetExploreAlso,
          style: MintTextStyles.titleMedium(),
        )),
        const SizedBox(height: MintSpacing.sm),
        MintEntrance(delay: const Duration(milliseconds: 100), child: CollapsibleSection(
          title: l.budgetDebtRatio,
          subtitle: l.budgetDebtRatioSubtitle,
          icon: Icons.warning_amber_rounded,
          child: _buildSectionCta(l.budgetCtaEvaluate, '/debt/ratio'),
        )),
        MintEntrance(delay: const Duration(milliseconds: 200), child: CollapsibleSection(
          title: l.budgetRepaymentPlan,
          subtitle: l.budgetRepaymentPlanSubtitle,
          icon: Icons.trending_down,
          child: _buildSectionCta(l.budgetCtaPlan, '/debt/repayment'),
        )),
        MintEntrance(delay: const Duration(milliseconds: 300), child: CollapsibleSection(
          title: l.budgetHelpResources,
          subtitle: l.budgetHelpResourcesSubtitle,
          icon: Icons.help_outline,
          child: _buildSectionCta(l.budgetCtaDiscover, '/debt/help'),
        )),
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

/// Tap-to-type CHF amount field replacing MintPremiumSlider.
///
/// Shows a labelled text field with CHF suffix, constrained to [0, max].
/// On valid input, calls [onChanged] with the parsed value.
class _BudgetAmountField extends StatefulWidget {
  final String label;
  final double initialValue;
  final double max;
  final Color accentColor;
  final ValueChanged<double> onChanged;

  const _BudgetAmountField({
    required this.label,
    required this.initialValue,
    required this.max,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<_BudgetAmountField> createState() => _BudgetAmountFieldState();
}

class _BudgetAmountFieldState extends State<_BudgetAmountField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialValue.round().toString(),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
        ),
        const SizedBox(height: MintSpacing.xs),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            suffixText: 'CHF',
            suffixStyle: MintTextStyles.bodySmall(color: MintColors.textMuted),
            hintText: S.of(context)!.budgetEnvelopeFieldHint,
            hintStyle: MintTextStyles.bodyMedium(color: MintColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md,
              vertical: MintSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MintColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MintColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.accentColor, width: 1.5),
            ),
          ),
          onChanged: (text) {
            final parsed = double.tryParse(
              text.replaceAll(RegExp(r"[^0-9.]"), ''),
            );
            if (parsed != null) {
              widget.onChanged(parsed.clamp(0, widget.max));
            }
          },
        ),
      ],
    );
  }
}
