// Budget deep-dive — detailed view of spending breakdown.
// Primary budget display is now in PulseScreen via BudgetSnapshot.
// This screen provides the detailed envelope editing.
//
// Hero number and flow map are sourced from the BudgetInputs passed to this
// screen. This keeps the detailed budget coherent after direct setup/relaunch.

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
import 'package:mint_mobile/domain/budget/present_budget_builder.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/services/e2e_runtime_flags.dart';
import 'package:mint_mobile/services/financial_core/pillar3a_room_calculator.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
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
  final Object? routeExtra;

  const BudgetScreen({
    super.key,
    required this.inputs,
    this.routeExtra,
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
    });
  }

  void _readSequenceContext() {
    final extra = widget.routeExtra;
    if (extra is Map<String, dynamic>) {
      _seqRunId = extra['runId'] as String?;
      _seqStepId = extra['stepId'] as String?;
    }
  }

  void _emitFinalReturn() {
    if (_finalReturnEmitted) return;
    if (_seqRunId == null || _seqStepId == null) return;
    _finalReturnEmitted = true;

    final inputs = widget.inputs;
    final chargesTotal = PresentBudgetBuilder.fixedChargesFromInputs(inputs);
    ScreenCompletionTracker.markCompletedWithReturn(
        'budget',
        ScreenReturn.completed(
          route: '/budget',
          stepOutputs: {
            'revenu_net': PresentBudgetBuilder.displayChf(inputs.netIncome),
            'charges_totales': chargesTotal,
          },
          runId: _seqRunId,
          stepId: _seqStepId,
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
    return Semantics(
        key: const Key('budget_screen'),
        identifier: 'budget_screen',
        container: true,
        explicitChildNodes: true,
        child: PopScope(
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
              body: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: SafeArea(
                          top: false,
                          child: Consumer<BudgetProvider>(
                            builder: (context, provider, child) {
                              if (_hasError) {
                                return Center(
                                  child: Container(
                                    padding:
                                        const EdgeInsets.all(MintSpacing.md),
                                    margin:
                                        const EdgeInsets.all(MintSpacing.lg),
                                    decoration: BoxDecoration(
                                      color: MintColors.error
                                          .withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: MintColors.error
                                            .withValues(alpha: 0.15),
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

                              // SALVAGE-00 SC-2: read the profile defensively —
                              // when the CoachProfileProvider is absent from the
                              // tree (widget tests that pump BudgetScreen in
                              // isolation), fall back to plan.future via a null
                              // profile instead of throwing.
                              CoachProfile? flowProfile;
                              try {
                                flowProfile = context
                                    .read<CoachProfileProvider>()
                                    .profile;
                              } catch (_) {
                                flowProfile = null;
                              }
                              final flowPresent =
                                  _presentBudgetFromInputs(plan, flowProfile);
                              final displayNet = flowPresent.monthlyNet;
                              final displayHousing =
                                  _displayChf(widget.inputs.housingCost);
                              final displayDebt =
                                  _displayChf(widget.inputs.debtPayments);
                              final displayTax =
                                  _displayChf(widget.inputs.taxProvision);
                              final displayHealth =
                                  _displayChf(widget.inputs.healthInsurance);
                              final displayOtherFixed =
                                  _displayChf(widget.inputs.otherFixedCosts);
                              final displayVariables =
                                  _displayChf(plan.variables);
                              final displayAllocatable =
                                  flowPresent.monthlyNet -
                                      flowPresent.monthlyCharges;
                              final displayEnvelopeBase = displayAllocatable > 0
                                  ? displayAllocatable
                                  : 0.0;
                              final displayNeedsTarget =
                                  _displayChf(displayEnvelopeBase * 0.50);
                              final displayLifeTarget =
                                  _displayChf(displayEnvelopeBase * 0.30);
                              final displayFutureTarget =
                                  _displayChf(displayEnvelopeBase * 0.20);

                              return SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: MintSpacing.lg,
                                  vertical: MintSpacing.md,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // ── ABOVE FOLD: Section 1 — Data quality banner ──
                                    _staggeredEntry(
                                      index: 0,
                                      child: _buildDataQualityBanner(
                                          widget.inputs, l),
                                    ),
                                    const SizedBox(height: MintSpacing.md),

                                    // ── ABOVE FOLD: Section 2 — Hero: budget libre (result FIRST) ──
                                    _staggeredEntry(
                                        index: 0,
                                        child: _buildHeader(
                                          l: l,
                                          present: flowPresent,
                                          profile: flowProfile,
                                        )),
                                    const SizedBox(height: MintSpacing.md),

                                    _staggeredEntry(
                                      index: 1,
                                      child: _BudgetCalculationDetailSection(
                                        present: flowPresent,
                                        l: l,
                                      ),
                                    ),
                                    const SizedBox(height: MintSpacing.xxl),

                                    // ── ABOVE FOLD: Section 3 — Spending meter ──
                                    _staggeredEntry(
                                      index: 1,
                                      child: SpendingMeter(
                                        variablesAmount:
                                            flowPresent.monthlyFree,
                                        futureAmount:
                                            flowPresent.monthlySavings,
                                        totalAvailable:
                                            flowPresent.monthlyFree +
                                                flowPresent.monthlySavings,
                                      ),
                                    ),
                                    const SizedBox(height: MintSpacing.xxl),

                                    // ── Secondary: next action ──
                                    _staggeredEntry(
                                      index: 2,
                                      child: _buildActionInsight(l),
                                    ),
                                    const SizedBox(height: MintSpacing.xxl),

                                    if (_isIndependentNoLppProfile(
                                        flowProfile)) ...[
                                      _staggeredEntry(
                                        index: 2,
                                        child: _buildIndependentNoLppCapacityGuard(
                                          l: l,
                                          profile: flowProfile!,
                                          present: flowPresent,
                                        ),
                                      ),
                                      const SizedBox(height: MintSpacing.xxl),
                                    ],

                                    // ── BELOW FOLD: Envelopes sliders (secondary visually) ──
                                    if (widget.inputs.style ==
                                        BudgetStyle.envelopes3) ...[
                                      _staggeredEntry(
                                        index: 2,
                                        child: _buildSliders(
                                            context, provider, plan, l),
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
                                        netIncome: displayNet,
                                        premierEclairage: displayEnvelopeBase >
                                                0
                                            ? l.budgetPremierEclairage503020(
                                                formatChf(displayFutureTarget),
                                                formatChf(
                                                    displayFutureTarget * 120),
                                              )
                                            : null,
                                        categories: [
                                          BudgetCategory(
                                            label: l.budgetNeeds,
                                            emoji: '',
                                            percent: 50,
                                            amount: displayNeedsTarget,
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
                                            amount: displayLifeTarget,
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
                                            amount: displayFutureTarget,
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
                                              amount: displayNet),
                                        ],
                                        expenses: [
                                          if (displayHousing > 0)
                                            BudgetLineItem(
                                                label: l.budgetHousing,
                                                amount: displayHousing),
                                          if (displayTax > 0)
                                            BudgetLineItem(
                                                label: l.budgetTaxProvision,
                                                amount: displayTax),
                                          if (displayHealth > 0)
                                            BudgetLineItem(
                                                label: l.budgetHealthInsurance,
                                                amount: displayHealth),
                                          if (displayDebt > 0)
                                            BudgetLineItem(
                                                label: l.budgetDebts,
                                                amount: displayDebt),
                                          if (displayOtherFixed > 0)
                                            BudgetLineItem(
                                                label: l.budgetOtherFixed,
                                                amount: displayOtherFixed),
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
                                        monthlyIncome: displayNet,
                                        survivalIncome:
                                            _displayChf(displayNet * 0.70),
                                        reserveMonths: widget.inputs
                                                    .emergencyFundMonths >
                                                0
                                            ? widget.inputs.emergencyFundMonths
                                                .toDouble()
                                            : null,
                                        lines: [
                                          if (displayHousing > 0)
                                            BudgetLine(
                                              label: l.budgetHousing,
                                              emoji: '',
                                              normalAmount: displayHousing,
                                              survivalAmount: displayHousing,
                                              status: BudgetLineStatus.locked,
                                            ),
                                          if (displayHealth > 0)
                                            BudgetLine(
                                              label: l.budgetHealthInsurance,
                                              emoji: '',
                                              normalAmount: displayHealth,
                                              survivalAmount: displayHealth,
                                              status: BudgetLineStatus.locked,
                                            ),
                                          if (displayTax > 0)
                                            BudgetLine(
                                              label: l.budgetTaxProvision,
                                              emoji: '',
                                              normalAmount: displayTax,
                                              survivalAmount: _displayChf(
                                                  displayTax * 0.80),
                                              status: BudgetLineStatus.paused,
                                            ),
                                          if (displayDebt > 0)
                                            BudgetLine(
                                              label: l.budgetDebts,
                                              emoji: '',
                                              normalAmount: displayDebt,
                                              survivalAmount: displayDebt,
                                              status: BudgetLineStatus.locked,
                                            ),
                                          if (displayOtherFixed > 0)
                                            BudgetLine(
                                              label: l.budgetOtherFixed,
                                              emoji: '',
                                              normalAmount: displayOtherFixed,
                                              survivalAmount: displayOtherFixed,
                                              status: BudgetLineStatus.locked,
                                            ),
                                          BudgetLine(
                                            label: l.budgetVariables,
                                            emoji: '',
                                            normalAmount: displayVariables,
                                            survivalAmount: _displayChf(
                                                displayVariables * 0.50),
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
        ));
  }

  PresentBudget _presentBudgetFromInputs(BudgetPlan plan,
      [CoachProfile? profile]) {
    final monthlyNet = _displayChf(widget.inputs.netIncome);
    final monthlyCharges = _displayChf(widget.inputs.housingCost) +
        _displayChf(widget.inputs.debtPayments) +
        _displayChf(widget.inputs.taxProvision) +
        _displayChf(widget.inputs.healthInsurance) +
        _displayChf(widget.inputs.otherFixedCosts);
    // SALVAGE-00 SC-2 / Gate Fix 2 (arch-03): source planned savings from the
    // SAME shared helper the engine uses (3a + LPP buyback) instead of
    // plan.future (which is 0 until the user sets a target). This converges the
    // builder path with the engine path — a 3a-contributing user sees the SAME
    // Disponible everywhere. Falls back to plan.future when no profile.
    final monthlySavings = profile != null
        ? BudgetLivingEngine.computeMonthlySavings(profile)
        : _displayChf(plan.future);
    final monthlyFree = monthlyNet - monthlyCharges - monthlySavings;
    return PresentBudget(
      monthlyNet: monthlyNet,
      monthlyCharges: monthlyCharges,
      monthlySavings: monthlySavings,
      monthlyFree: monthlyFree,
    );
  }

  double _displayChf(double value) => PresentBudgetBuilder.displayChf(value);

  Widget _buildHeader({
    required S l,
    required PresentBudget present,
    CoachProfile? profile,
  }) {
    final heroFree = present.monthlyFree;
    final isPositive = heroFree >= 0;
    final heroColor = isPositive ? MintColors.success : MintColors.warning;

    return Semantics(
      key: const Key('budget_hero_summary'),
      identifier: 'budget_hero_summary',
      container: true,
      explicitChildNodes: true,
      label: '${l.budgetAvailableThisMonth}: '
          '${formatChfWithPrefix(heroFree)}. '
          '${l.budgetPremierEclairageCaption}',
      child: Column(
        children: [
          // Hero: budget libre — MintHeroNumber (consequence, not output)
          // Uses the same BudgetInputs/BudgetPlan values as the breakdown and
          // flow map below.
          MintCountUp(
            value: heroFree,
            prefix: 'CHF\u00a0',
            color: heroColor,
            showLigne: false,
            contextText: l.budgetPremierEclairageCaption,
            semanticsLabel:
                '${formatChfWithPrefix(heroFree)} ${l.budgetAvailableThisMonth}',
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildHeroFormula(l: l, present: present),
          _buildIncomeBasisAnchor(present: present, profile: profile),
          if (widget.inputs.debtPayments > 0) ...[
            const SizedBox(height: MintSpacing.xs),
            _buildDebtDisclosure(l),
          ],
        ],
      ),
    );
  }

  bool _isIndependentNoLppProfile(CoachProfile? profile) {
    if (profile == null) return false;
    final lpp = profile.prevoyance.avoirLppTotal;
    return profile.employmentStatus == 'independant' &&
        (lpp == null || lpp == 0);
  }

  Widget _buildIndependentNoLppCapacityGuard({
    required S l,
    required CoachProfile profile,
    required PresentBudget present,
  }) {
    final rawRemainingAnnual3a = Pillar3aRoomCalculator.remainingAnnualRoom(
      profile,
      archetype: FinancialArchetype.independentNoLpp,
    );
    final remainingAnnual3a = _displayChf(rawRemainingAnnual3a);
    final monthlyEquivalent = _displayChf(rawRemainingAnnual3a / 12);
    final decisionSummary = l.budgetIndependentNoLppDecisionSummary(
      formatChfWithPrefix(remainingAnnual3a),
      formatChfWithPrefix(monthlyEquivalent),
      formatChfWithPrefix(present.monthlyFree),
    );
    final steps = [
      l.reportActionStep3aIndependentNoLpp1,
      l.reportActionStep3aIndependentNoLpp2,
      l.reportActionStep3aIndependentNoLpp3,
      l.reportActionStep3aIndependentNoLpp4,
    ];
    final label = [
      l.reportActionTitle3aIndependentNoLpp,
      l.reportActionDesc3aIndependentNoLpp,
      l.budgetIndependentNoLppDecisionTitle,
      decisionSummary,
      ...steps,
    ].join('. ');

    return Semantics(
      key: const Key('budget_independent_no_lpp_capacity_guard'),
      identifier: 'budget_independent_no_lpp_capacity_guard',
      container: true,
      excludeSemantics: true,
      label: label,
      child: MintSurface(
        tone: MintSurfaceTone.sauge,
        padding: const EdgeInsets.all(MintSpacing.lg),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.account_balance_outlined,
                  size: 18,
                  color: MintColors.mintForest,
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    l.reportActionTitle3aIndependentNoLpp,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              l.reportActionDesc3aIndependentNoLpp,
              style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.md),
            Text(
              l.budgetIndependentNoLppDecisionTitle,
              style: MintTextStyles.labelLarge(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              decisionSummary,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.md),
            ...steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.xs),
                child: Text(
                  step,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeBasisAnchor({
    required PresentBudget present,
    CoachProfile? profile,
  }) {
    if (!E2eRuntimeFlags.proofAnchors) return const SizedBox.shrink();

    final annual = profile?.independentNetProfessionalIncomeAnnual;
    final label = annual != null &&
            annual.isFinite &&
            annual > 0 &&
            profile?.employmentStatus == 'independant'
        ? 'source=derived_self_employed_annual_proxy '
            'q_self_employed_net_income_annual_chf=${annual.round()} '
            'monthly_net=${formatChfWithPrefix(present.monthlyNet)}'
        : 'source=budget_inputs '
            'monthly_net=${formatChfWithPrefix(present.monthlyNet)}';
    return Semantics(
      key: const Key('budget_income_basis'),
      identifier: 'budget_income_basis',
      container: true,
      label: label,
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          color: Color(0x01000000), // lint-ignore: prefer_mint_color_token
          fontSize: 8, // lint-ignore: prefer_mint_text_style
          height: 1,
        ),
      ),
    );
  }

  Widget _buildHeroFormula({
    required S l,
    required PresentBudget present,
  }) {
    final formula = present.monthlySavings > 0
        ? '${formatChfWithPrefix(present.monthlyNet)} − '
            '${formatChfWithPrefix(present.monthlyCharges)} − '
            '${formatChfWithPrefix(present.monthlySavings)} = '
            '${formatChfWithPrefix(present.monthlyFree)}'
        : '${formatChfWithPrefix(present.monthlyNet)} − '
            '${formatChfWithPrefix(present.monthlyCharges)} = '
            '${formatChfWithPrefix(present.monthlyFree)}';

    return Semantics(
      key: const Key('budget_hero_formula'),
      container: true,
      identifier: 'budget_hero_formula',
      excludeSemantics: true,
      label: '${l.budgetAvailableThisMonth}: '
          '${formatChfWithPrefix(present.monthlyFree)}. $formula',
      child: Text(
        formula,
        textAlign: TextAlign.center,
        style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
      ),
    );
  }

  Widget _buildDebtDisclosure(S l) {
    final label =
        '${l.budgetDebtRepayment}: ${formatChfWithPrefix(_displayChf(widget.inputs.debtPayments))}';
    return Semantics(
      key: const Key('budget_debt_disclosure'),
      container: true,
      identifier: 'budget_debt_disclosure',
      excludeSemantics: true,
      label: label,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: MintTextStyles.labelSmall(color: MintColors.terracotta)
            .copyWith(fontWeight: FontWeight.w700),
      ),
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
      key: const Key('budget_data_quality_banner'),
      identifier: 'budget_data_quality_banner',
      container: true,
      label: '$message. ${l.budgetCompleteMyData}',
      button: true,
      excludeSemantics: true,
      onTap: () => context.push('/profile/bilan'),
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
                      style: MintTextStyles.bodySmall(color: MintColors.primary)
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
              const Icon(Icons.info_outline, size: 18, color: MintColors.info),
              const SizedBox(width: MintSpacing.sm),
              Flexible(
                child: Text(
                  l.budgetMethodTitle,
                  style: MintTextStyles.titleMedium(color: MintColors.info),
                  softWrap: true,
                ),
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
        MintEntrance(
            child: Text(
          l.budgetExploreAlso,
          style: MintTextStyles.titleMedium(),
        )),
        const SizedBox(height: MintSpacing.sm),
        MintEntrance(
            delay: const Duration(milliseconds: 100),
            child: CollapsibleSection(
              title: l.budgetDebtRatio,
              subtitle: l.budgetDebtRatioSubtitle,
              icon: Icons.warning_amber_rounded,
              child: _buildSectionCta(l.budgetCtaEvaluate, '/debt/ratio'),
            )),
        MintEntrance(
            delay: const Duration(milliseconds: 200),
            child: CollapsibleSection(
              title: l.budgetRepaymentPlan,
              subtitle: l.budgetRepaymentPlanSubtitle,
              icon: Icons.trending_down,
              child: _buildSectionCta(l.budgetCtaPlan, '/debt/repayment'),
            )),
        MintEntrance(
            delay: const Duration(milliseconds: 300),
            child: CollapsibleSection(
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
          // lint-ignore: prefer_mint_cta
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

class _BudgetFlowMap extends StatelessWidget {
  final PresentBudget present;
  final S l;

  const _BudgetFlowMap({
    required this.present,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final free = present.monthlyFree > 0 ? present.monthlyFree : 0.0;
    final total = present.monthlyNet > 0
        ? present.monthlyNet
        : present.monthlyCharges + present.monthlySavings + free;
    final denominator = total > 0 ? total : 1.0;

    return Semantics(
      key: const Key('budget_flow_map'),
      identifier: 'budget_flow_map',
      label: '${l.budgetNetIncome} ${formatChfWithPrefix(present.monthlyNet)}. '
          '${l.pulseBudgetCharges} '
          '${formatChfWithPrefix(present.monthlyCharges)}. '
          '${l.budgetFuture} '
          '${formatChfWithPrefix(present.monthlySavings)}. '
          '${l.budgetAvailable} ${formatChfWithPrefix(present.monthlyFree)}.',
      child: MintSurface(
        tone: MintSurfaceTone.craie,
        padding: const EdgeInsets.all(MintSpacing.lg),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BudgetFlowAmountRow(
              label: l.budgetNetIncome,
              amount: present.monthlyNet,
              shareLabel: '100%',
              color: MintColors.textPrimary,
            ),
            const SizedBox(height: MintSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    if (present.monthlyCharges > 0)
                      _BudgetFlowSegment(
                        flex: _segmentFlex(
                          present.monthlyCharges,
                          denominator,
                        ),
                        color: MintColors.terracotta,
                      ),
                    if (present.monthlySavings > 0)
                      _BudgetFlowSegment(
                        flex: _segmentFlex(
                          present.monthlySavings,
                          denominator,
                        ),
                        color: MintColors.info,
                      ),
                    if (free > 0)
                      _BudgetFlowSegment(
                        flex: _segmentFlex(free, denominator),
                        color: MintColors.success,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            _BudgetFormulaProof(present: present, l: l),
            const SizedBox(height: MintSpacing.md),
            _BudgetFlowAmountRow(
              label: l.pulseBudgetCharges,
              amount: present.monthlyCharges,
              shareLabel: _formatShare(present.monthlyCharges, denominator),
              color: MintColors.terracotta,
            ),
            const SizedBox(height: MintSpacing.sm),
            _BudgetFlowAmountRow(
              label: l.budgetFuture,
              amount: present.monthlySavings,
              shareLabel: _formatShare(present.monthlySavings, denominator),
              color: MintColors.info,
            ),
            const SizedBox(height: MintSpacing.sm),
            _BudgetFlowAmountRow(
              label: l.budgetAvailable,
              amount: present.monthlyFree,
              shareLabel: _formatShare(free, denominator),
              color: present.isDeficit ? MintColors.error : MintColors.success,
              isStrong: true,
            ),
          ],
        ),
      ),
    );
  }

  int _segmentFlex(double amount, double denominator) {
    final ratio = amount / denominator;
    return (ratio * 1000).round().clamp(1, 1000).toInt();
  }

  String _formatShare(double amount, double denominator) {
    if (denominator <= 0) return '0%';
    return '${((amount / denominator) * 100).round()}%';
  }
}

class _BudgetCalculationDetailSection extends StatefulWidget {
  final PresentBudget present;
  final S l;

  // Local disclosure instead of CollapsibleSection because Maestro iOS can
  // resolve the wrapped ExpansionTile semantics id but does not dispatch the
  // tap to Flutter reliably. Keep this widget scoped to Budget until the
  // shared disclosure supports stable simulator tap semantics.
  const _BudgetCalculationDetailSection({
    required this.present,
    required this.l,
  });

  @override
  State<_BudgetCalculationDetailSection> createState() =>
      _BudgetCalculationDetailSectionState();
}

class _BudgetCalculationDetailSectionState
    extends State<_BudgetCalculationDetailSection> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          Semantics(
            key: const Key('budget_calculation_detail_toggle'),
            identifier: 'budget_calculation_detail_toggle',
            container: true,
            excludeSemantics: true,
            button: true,
            enabled: true,
            expanded: _expanded,
            onTap: _toggle,
            label: widget.l.affordabilityCalculationDetail,
            child: Material(
              color: MintColors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                excludeFromSemantics: true,
                onTap: _toggle,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.functions,
                          color: MintColors.primary, size: 20),
                      const SizedBox(width: MintSpacing.md),
                      Expanded(
                        child: Text(
                          widget.l.affordabilityCalculationDetail,
                          style: MintTextStyles.bodyMedium(
                                  color: MintColors.textPrimary)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: MintColors.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _BudgetFlowMap(
                present: widget.present,
                l: widget.l,
              ),
            ),
        ],
      ),
    );
  }
}

class _BudgetFormulaProof extends StatelessWidget {
  final PresentBudget present;
  final S l;

  const _BudgetFormulaProof({
    required this.present,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('budget_formula_proof'),
      container: true,
      identifier: 'budget_formula_proof',
      label: '${l.budgetNetIncome} ${formatChfWithPrefix(present.monthlyNet)} '
          '- ${l.pulseBudgetCharges} '
          '${formatChfWithPrefix(present.monthlyCharges)} '
          '- ${l.budgetFuture} '
          '${formatChfWithPrefix(present.monthlySavings)} '
          '= ${l.budgetAvailable} '
          '${formatChfWithPrefix(present.monthlyFree)}.',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
        child: Column(
          children: [
            _BudgetFormulaLine(
              label: l.budgetNetIncome,
              amount: present.monthlyNet,
              color: MintColors.textPrimary,
            ),
            const SizedBox(height: MintSpacing.xs),
            _BudgetFormulaLine(
              operator: '-',
              label: l.pulseBudgetCharges,
              amount: present.monthlyCharges,
              color: MintColors.terracotta,
            ),
            const SizedBox(height: MintSpacing.xs),
            _BudgetFormulaLine(
              operator: '-',
              label: l.budgetFuture,
              amount: present.monthlySavings,
              color: MintColors.info,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: MintSpacing.xs),
              child: Divider(height: 1, color: MintColors.border),
            ),
            _BudgetFormulaLine(
              operator: '=',
              label: l.budgetAvailable,
              amount: present.monthlyFree,
              color: present.isDeficit ? MintColors.error : MintColors.success,
              isStrong: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetFormulaLine extends StatelessWidget {
  final String operator;
  final String label;
  final double amount;
  final Color color;
  final bool isStrong;

  const _BudgetFormulaLine({
    this.operator = '',
    required this.label,
    required this.amount,
    required this.color,
    this.isStrong = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = MintTextStyles.labelSmall(
      color: isStrong ? color : MintColors.textSecondary,
    ).copyWith(fontWeight: isStrong ? FontWeight.w800 : FontWeight.w600);
    final amountStyle = MintTextStyles.labelSmall(color: color).copyWith(
      fontWeight: isStrong ? FontWeight.w800 : FontWeight.w700,
    );

    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            operator,
            textAlign: TextAlign.center,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: MintSpacing.xs),
        Expanded(child: Text(label, style: labelStyle)),
        Text(formatChfWithPrefix(amount), style: amountStyle),
      ],
    );
  }
}

class _BudgetFlowSegment extends StatelessWidget {
  final int flex;
  final Color color;

  const _BudgetFlowSegment({
    required this.flex,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      flex: flex,
      child: ColoredBox(color: color),
    );
  }
}

class _BudgetFlowAmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final String shareLabel;
  final Color color;
  final bool isStrong;

  const _BudgetFlowAmountRow({
    required this.label,
    required this.amount,
    required this.shareLabel,
    required this.color,
    this.isStrong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: MintSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: MintTextStyles.bodySmall(
              color: MintColors.textSecondary,
            ).copyWith(
              fontWeight: isStrong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          shareLabel,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: MintSpacing.sm),
        Text(
          formatChfWithPrefix(amount),
          style: MintTextStyles.bodyMedium(
            color: isStrong ? color : MintColors.textPrimary,
          ).copyWith(
            fontWeight: isStrong ? FontWeight.w800 : FontWeight.w600,
          ),
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
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
