import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/models/circle_score.dart';
import 'package:mint_mobile/services/financial_report_service.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/widgets/report/thematic_card.dart';
// Wave E-PRIME (2026-04-18): MintAlertObject + VoiceResolutionContext imports
// removed — widgets/alert/ cluster deleted with AnticipationProvider (Panel A
// P0-3/P0-6). Debt state is now surfaced exclusively via SafeModeGate wrapper
// at screen level, not a dedicated alert widget here.
import 'package:mint_mobile/widgets/report/retirement_projection_card.dart';
import 'package:mint_mobile/widgets/comparators/pillar3a_comparator_widget.dart';
import 'package:mint_mobile/widgets/educational_explanation_widget.dart';
import 'package:mint_mobile/data/financial_explanations.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';
import 'package:mint_mobile/services/wizard_service.dart';
import 'package:mint_mobile/widgets/common/mint_empty_state.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_service.dart';
import 'package:mint_mobile/domain/budget/present_budget_builder.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:provider/provider.dart';
// ProfileProvider removed — Safe Mode now derived from wizardAnswers directly

/// Ecran d'affichage du rapport financier exhaustif V2
/// Refonte : cartes thématiques (Budget, Protection, Retraite, Impôts)
/// remplaçant les cercles abstraits (Protection, Prévoyance, Croissance, Optimisation).
class FinancialReportScreenV2 extends StatelessWidget {
  final Map<String, dynamic> wizardAnswers;
  final BudgetSnapshot? budgetSnapshot;

  const FinancialReportScreenV2({
    super.key,
    required this.wizardAnswers,
    this.budgetSnapshot,
  });

  // ── Route mapping by ActionCategory (replaces fragile keyword matching) ──
  String _routeForCategory(ActionCategory category) {
    return switch (category) {
      ActionCategory.protection => '/budget',
      ActionCategory.pillar3a => '/pilier-3a',
      ActionCategory.lpp => '/rachat-lpp',
      ActionCategory.avs => '/retraite',
      ActionCategory.tax => '/fiscal',
      ActionCategory.insurance => '/assurances/lamal',
      ActionCategory.investment => '/tools',
      ActionCategory.other => '/tools',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (wizardAnswers.isEmpty && !_hasReportFallback(context)) {
      return Scaffold(
        backgroundColor: MintColors.surface,
        appBar: AppBar(
          title: Text(S.of(context)!.reportTonPlanMint,
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary)),
          backgroundColor: MintColors.white,
          foregroundColor: MintColors.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => context.go('/coach/chat'),
          ),
        ),
        body: MintEmptyState(
          icon: Icons.assessment_outlined,
          title: S.of(context)!.financialReportEmptyTitle,
          subtitle: S.of(context)!.financialReportEmptySubtitle,
          ctaLabel: S.of(context)!.financialReportEmptyCta,
          // B7-cascade fix 2026-05-09 : push (not go) so the user can
          // back-out of the coach without losing this empty-state screen.
          onCta: () => context.push('/coach/chat'),
        ),
      );
    }
    final reportService = FinancialReportService();
    final report = reportService.generateReport(wizardAnswers);
    final safeModeActive = WizardService.isSafeModeActive(wizardAnswers);
    final safeModeReasons = _buildSafeModeReasons(context, wizardAnswers);

    return Scaffold(
      backgroundColor: MintColors.surface,
      appBar: AppBar(
        title: Text(S.of(context)!.reportTonPlanMint,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary)),
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/coach/chat'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              PdfService.generateFinancialReportPdf(report);
            },
          ),
        ],
      ),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header personnalisé (greeting + status summary)
                    MintEntrance(
                        child: _buildHeader(
                            context, report.profile, report.healthScore)),

                    const SizedBox(height: MintSpacing.lg),

                    // Wave E-PRIME (2026-04-18): Debt alert block removed.
                    // The screen is already wrapped by SafeModeGate at the caller
                    // level (widgets/common/safe_mode_gate.dart, imported L20), which
                    // handles toxic-debt state globally. The redundant inline alert
                    // relied on MintAlertObject (widgets/alert/, deleted in Phase 2c
                    // cascade with AnticipationProvider Panel A P0-3).

                    // ── Budget thematic card ──
                    MintEntrance(
                        delay: const Duration(milliseconds: 100),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: MintSpacing.md),
                          child: _buildBudgetSection(
                              context, wizardAnswers, report),
                        )),

                    // ── Protection thematic card ──
                    MintEntrance(
                        delay: const Duration(milliseconds: 200),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: MintSpacing.md),
                          child: _buildProtectionSection(
                              context, wizardAnswers, report.healthScore),
                        )),

                    // ── Retirement thematic card ──
                    if (report.retirementProjection != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: MintSpacing.md),
                        child: _buildRetirementThematicSection(
                            context, report, wizardAnswers),
                      ),

                    // ── Tax thematic card ──
                    MintEntrance(
                        delay: const Duration(milliseconds: 300),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: MintSpacing.md),
                          child: _buildTaxThematicSection(context, report),
                        )),

                    const SizedBox(height: MintSpacing.lg),

                    // ── Top 3 Priorities ──
                    MintEntrance(
                        delay: const Duration(milliseconds: 400),
                        child: SafeModeGate(
                          hasDebt: safeModeActive,
                          lockedTitle: S.of(context)!.reportSafeModePriority,
                          lockedMessage: S.of(context)!.reportSafeModeActions,
                          reasons: safeModeReasons,
                          child: _buildTopPriorities(
                              context, report.priorityActions),
                        )),

                    const SizedBox(height: MintSpacing.lg),

                    // ── Comparateur 3a (si applicable) ──
                    if (report.pillar3aAnalysis != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: MintSpacing.md),
                        child: Text(
                          S.of(context)!.reportOptimise3a,
                          style: MintTextStyles.headlineMedium(),
                        ),
                      ),
                      const SizedBox(height: MintSpacing.md),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: MintSpacing.md),
                        child: SafeModeGate(
                          hasDebt: safeModeActive,
                          lockedTitle: S.of(context)!.reportSafeModePriority,
                          lockedMessage: S.of(context)!.reportSafeMode3a,
                          reasons: safeModeReasons,
                          child: Pillar3aComparatorWidget(
                            monthlyIncome: report.profile.monthlyNetIncome,
                            yearsUntilRetirement:
                                report.profile.yearsToRetirement,
                            hasPensionFund: report.profile.isSalaried,
                          ),
                        ),
                      ),
                      const SizedBox(height: MintSpacing.lg),
                    ],

                    // ── Strat\u00e9gie rachat LPP ──
                    if (report.lppBuybackStrategy != null)
                      SafeModeGate(
                        hasDebt: safeModeActive,
                        lockedTitle: S.of(context)!.reportSafeModeLpp,
                        lockedMessage: S.of(context)!.reportSafeModeLppMessage,
                        reasons: safeModeReasons,
                        child: _buildLppBuybackSection(context,
                            report.lppBuybackStrategy!, report.profile),
                      ),

                    const SizedBox(height: MintSpacing.lg),

                    // ── Life event suggestions based on profile ──
                    if (report.profile.ageOrNull != null)
                      LifeEventSuggestionsSection(
                        suggestions: buildLifeEventSuggestions(
                          age: report.profile.ageOrNull!,
                          civilStatus: report.profile.civilStatus,
                          childrenCount: report.profile.childrenCount,
                          employmentStatus: report.profile.employmentStatus,
                          monthlyNetIncome: report.profile.monthlyNetIncome,
                          canton: report.profile.canton,
                          s: S.of(context)!,
                        ),
                      ),

                    const SizedBox(height: MintSpacing.xl),

                    // ── SoA Compliance Section ──
                    _buildSoaComplianceSection(context, report),

                    const SizedBox(height: MintSpacing.lg),

                    // ── Disclaimer Footer ──
                    _buildDisclaimerFooter(context),

                    const SizedBox(height: MintSpacing.xxl),
                  ],
                ),
              ))),
    );
  }

  bool _hasReportFallback(BuildContext context) {
    return budgetSnapshot != null ||
        _readMintStateBudgetIfAvailable(context) != null ||
        _readBudgetProviderIfAvailable(context)?.inputs != null;
  }

  // ════════════════════════════════════════════════════════════════
  //  HEADER — Greeting + contextual status (replaces numeric score)
  // ════════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context, UserProfile profile,
      FinancialHealthScore healthScore) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary,
            MintColors.primary.withValues(alpha: 0.7)
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context)!.reportBonjour(profile.firstName ?? ''),
              style: MintTextStyles.headlineLarge(color: MintColors.white),
            ),
            const SizedBox(height: MintSpacing.sm),
            if (profile.ageOrNull != null)
              Text(
                S.of(context)!.reportProfileSummary(
                    profile.ageOrNull!, profile.canton, profile.civilStatus),
                style: MintTextStyles.bodyMedium(color: MintColors.white70),
              )
            else
              Text(
                '${profile.canton} · ${profile.civilStatus}',
                style: MintTextStyles.bodyMedium(color: MintColors.white70),
              ),
            const SizedBox(height: 20),
            // Contextual status phrase (replaces XX/100 score)
            _buildStatusSummary(context, healthScore),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSummary(
      BuildContext context, FinancialHealthScore healthScore) {
    final level = healthScore.overallScore;
    String message;
    String emoji;
    if (level >= 70) {
      message = S.of(context)!.reportStatusGood;
      emoji = '\ud83d\udfe2'; // green circle
    } else if (level >= 40) {
      message = S.of(context)!.reportStatusMedium;
      emoji = '\ud83d\udfe1'; // yellow circle
    } else {
      message = S.of(context)!.reportStatusLow;
      emoji = '\ud83d\udd34'; // red circle
    }
    return Semantics(
      label: message,
      child: Text(
        '$emoji $message',
        style: MintTextStyles.bodyLarge(color: MintColors.white)
            .copyWith(fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  THEMATIC CARD: BUDGET
  // ════════════════════════════════════════════════════════════════

  Widget _buildBudgetSection(BuildContext context, Map<String, dynamic> answers,
      FinancialReport report) {
    final budgetProvider = _readBudgetProviderIfAvailable(context);
    final useProviderFallback =
        _shouldUseBudgetProviderFallback(answers, budgetProvider);
    final useAnswerBudget = !useProviderFallback &&
        _answersHaveExplicitBudgetInputs(answers);
    final canonicalBudget =
        budgetSnapshot ?? _readMintStateBudgetIfAvailable(context);
    if (!useProviderFallback && !useAnswerBudget && canonicalBudget != null) {
      return _buildBudgetCardFromPresent(context, canonicalBudget.present);
    }

    final inputs = useProviderFallback
        ? budgetProvider!.inputs!
        : BudgetInputs.fromMap(
            _answersWithReportBudgetFallbacks(answers, report),
          );
    final plan = useProviderFallback && budgetProvider!.plan != null
        ? budgetProvider.plan!
        : BudgetService().computePlan(inputs);
    final present = PresentBudgetBuilder.fromInputs(
      inputs: inputs,
      plan: plan,
    );
    final ratio =
        present.monthlyNet > 0 ? present.monthlyFree / present.monthlyNet : 0.0;

    final status = ratio > 0.3
        ? CardStatus.serein
        : ratio > 0.1
            ? CardStatus.aRenforcer
            : CardStatus.alerte;

    return ThematicCard(
      emoji: '\ud83d\udcb0', // money bag
      title: S.of(context)!.reportBudgetTitle,
      status: status,
      keyNumber: formatChfWithPrefix(present.monthlyFree),
      keyNumberLabel: S.of(context)!.reportBudgetKeyLabel,
      children: [
        _buildBudgetProofSummary(context, present),
      ],
    );
  }

  bool _answersHaveExplicitBudgetInputs(Map<String, dynamic> answers) {
    if (answers.isEmpty) return false;
    final inputs = BudgetInputs.fromMap(answers);
    return inputs.netIncome.isFinite &&
        inputs.netIncome > 0 &&
        (answers.containsKey('q_housing_cost_period_chf') ||
            answers.containsKey('q_lamal_premium_monthly_chf') ||
            answers.containsKey('q_tax_provision_monthly_chf') ||
            answers.containsKey('q_other_fixed_costs_monthly_chf') ||
            answers.containsKey('q_debt_payments_period_chf'));
  }

  Widget _buildBudgetCardFromPresent(
      BuildContext context, PresentBudget present) {
    final ratio =
        present.monthlyNet > 0 ? present.monthlyFree / present.monthlyNet : 0.0;
    final status = ratio > 0.3
        ? CardStatus.serein
        : ratio > 0.1
            ? CardStatus.aRenforcer
            : CardStatus.alerte;

    return ThematicCard(
      emoji: '\ud83d\udcb0',
      title: S.of(context)!.reportBudgetTitle,
      status: status,
      keyNumber: formatChfWithPrefix(present.monthlyFree),
      keyNumberLabel: S.of(context)!.reportBudgetKeyLabel,
      children: [
        _buildBudgetProofSummary(context, present),
      ],
    );
  }

  Widget _buildBudgetProofSummary(BuildContext context, PresentBudget present) {
    return Column(
      children: [
        _budgetProofRow(
          S.of(context)!.budgetNetIncome,
          formatChfWithPrefix(present.monthlyNet),
          MintColors.success,
        ),
        const SizedBox(height: 8),
        _budgetProofRow(
          S.of(context)!.summaryChargesFixes,
          '\u2013 ${formatChfWithPrefix(present.monthlyCharges)}',
          MintColors.textSecondary,
          isBold: true,
        ),
      ],
    );
  }

  Widget _budgetProofRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: MintTextStyles.bodySmall(
              color: isBold ? MintColors.textPrimary : MintColors.textSecondary,
            ).copyWith(fontWeight: isBold ? FontWeight.w700 : FontWeight.w400),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: MintTextStyles.bodySmall(color: color)
              .copyWith(fontWeight: isBold ? FontWeight.w700 : FontWeight.w500),
        ),
      ],
    );
  }

  BudgetSnapshot? _readMintStateBudgetIfAvailable(BuildContext context) {
    try {
      final state = context.read<MintStateProvider>().state;
      return state?.dataSpineSnapshot?.budget ?? state?.budgetSnapshot;
    } on ProviderNotFoundException {
      return null;
    }
  }

  BudgetProvider? _readBudgetProviderIfAvailable(BuildContext context) {
    try {
      return context.read<BudgetProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  bool _answersNeedBudgetProviderFallback(Map<String, dynamic> answers) {
    final inputs = BudgetInputs.fromMap(answers);
    return !inputs.netIncome.isFinite ||
        inputs.netIncome <= 0 ||
        !answers.containsKey('q_canton') ||
        (!answers.containsKey('q_tax_provision_monthly_chf') &&
            inputs.isTaxEstimated);
  }

  bool _shouldUseBudgetProviderFallback(
    Map<String, dynamic> answers,
    BudgetProvider? budgetProvider,
  ) {
    if (budgetProvider?.inputs == null) return false;
    if (budgetProvider!.source == BudgetDataSource.directInput) return true;
    return _answersNeedBudgetProviderFallback(answers);
  }

  Map<String, dynamic> _answersWithReportBudgetFallbacks(
    Map<String, dynamic> answers,
    FinancialReport report,
  ) {
    final budgetAnswers = Map<String, dynamic>.from(answers);
    final netIncome = BudgetInputs.fromMap(budgetAnswers).netIncome;
    final needsProfileFallback = !netIncome.isFinite || netIncome <= 0;
    if (needsProfileFallback && report.profile.monthlyNetIncome > 0) {
      budgetAnswers['q_net_income_period_chf'] =
          report.profile.monthlyNetIncome;
      budgetAnswers['q_pay_frequency'] = 'monthly';
    }
    return budgetAnswers;
  }

  List<String> _buildSafeModeReasons(
      BuildContext context, Map<String, dynamic> answers) {
    final reasons = <String>[];

    if (answers['q_has_consumer_credit'] == 'yes' ||
        answers['q_has_consumer_debt'] == 'yes') {
      reasons.add(S.of(context)!.reportReasonDebt);
    }
    if (answers['q_has_leasing'] == 'yes') {
      reasons.add(S.of(context)!.reportReasonLeasing);
    }

    final debtPayment = BudgetInputs.fromMap(answers).debtPayments;
    if (debtPayment > 0) {
      reasons.add(S.of(context)!.reportReasonPayments(formatChf(debtPayment)));
    }

    final emergencyFund = answers['q_emergency_fund'] as String?;
    if (emergencyFund == null || emergencyFund == 'no') {
      reasons.add(S.of(context)!.reportReasonEmergency);
    }

    if (reasons.isEmpty) {
      reasons.add(S.of(context)!.reportReasonFragility);
    }

    return reasons;
  }

  // ════════════════════════════════════════════════════════════════
  //  THEMATIC CARD: PROTECTION
  // ════════════════════════════════════════════════════════════════

  Widget _buildProtectionSection(BuildContext context,
      Map<String, dynamic> answers, FinancialHealthScore healthScore) {
    final hasEmergencyFund = answers['q_emergency_fund'] as String?;
    final fundStatus = hasEmergencyFund == 'yes_6months'
        ? CardStatus.serein
        : hasEmergencyFund == 'yes_3months'
            ? CardStatus.aRenforcer
            : CardStatus.alerte;

    final fundMonths = hasEmergencyFund == 'yes_6months'
        ? '6+'
        : hasEmergencyFund == 'yes_3months'
            ? '3-6'
            : '< 3';

    return ThematicCard(
      emoji: '\ud83d\udee1\ufe0f', // shield
      title: S.of(context)!.reportProtectionTitle,
      status: fundStatus,
      keyNumber: '$fundMonths mois',
      keyNumberLabel: S.of(context)!.reportProtectionKeyLabel,
      source: S.of(context)!.reportProtectionSource,
      actionLabel: fundStatus != CardStatus.serein
          ? S.of(context)!.reportProtectionAction
          : null,
      onActionTap: () => context.push('/budget'),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  THEMATIC CARD: RETIREMENT
  // ════════════════════════════════════════════════════════════════

  Widget _buildRetirementThematicSection(BuildContext context,
      FinancialReport report, Map<String, dynamic> answers) {
    final projection = report.retirementProjection;
    if (projection == null) return const SizedBox.shrink();

    final replacementRate = projection.replacementRate;
    final status = replacementRate >= 60
        ? CardStatus.serein
        : replacementRate >= 40
            ? CardStatus.aRenforcer
            : CardStatus.alerte;

    // Calculate contribution years from new AVS gap questions or legacy fallback
    final birthYear = _parseIntAnswer(answers['q_birth_year']);
    int? contributionYears;
    if (birthYear != null) {
      final theoretical = (DateTime.now().year - (birthYear + 21)).clamp(0, 44);
      final avsStatus = answers['q_avs_lacunes_status'];
      if (avsStatus == 'no_gaps') {
        contributionYears = theoretical;
      } else if (avsStatus == 'arrived_late') {
        final arrivalYear = _parseIntAnswer(answers['q_avs_arrival_year']);
        if (arrivalYear != null) {
          final gaps = (arrivalYear - (birthYear + 21)).clamp(0, 44);
          contributionYears = (theoretical - gaps).clamp(0, 44);
        }
      } else if (avsStatus == 'lived_abroad') {
        final yearsAbroad = _parseIntAnswer(answers['q_avs_years_abroad']) ?? 0;
        contributionYears = (theoretical - yearsAbroad).clamp(0, 44);
      }
      // Fallback legacy: q_first_employment_year
      if (contributionYears == null) {
        final firstEmploymentYear =
            _parseIntAnswer(answers['q_first_employment_year']);
        if (firstEmploymentYear != null) {
          final startYear = [firstEmploymentYear, birthYear + 21]
              .reduce((a, b) => a > b ? a : b);
          contributionYears = (DateTime.now().year - startYear).clamp(0, 44);
        }
      }
    }

    // 3a sub-section
    final has3a = answers['q_has_3a'] == 'yes';
    final nb3a =
        int.tryParse(answers['q_3a_accounts_count']?.toString() ?? '0') ?? 0;

    final String threeAText;
    if (!has3a || nb3a == 0) {
      final remaining3aDeduction =
          _estimateRemaining3aDeduction(report, answers);
      threeAText = remaining3aDeduction > 0
          ? S
              .of(context)!
              .reportRetirement3aNoneWithRoom(formatChf(remaining3aDeduction))
          : S.of(context)!.reportRetirement3aNone;
    } else if (nb3a == 1) {
      threeAText = S.of(context)!.reportRetirement3aOne;
    } else {
      threeAText = S.of(context)!.reportRetirement3aMulti(nb3a);
    }

    // LPP sub-section
    final lppBuyback = report.lppBuybackStrategy;
    String? lppText;
    if (lppBuyback != null) {
      lppText = S.of(context)!.reportRetirementLppText(
            formatChf(lppBuyback.totalBuybackAvailable),
            formatChf(lppBuyback.totalTaxSavings),
          );
    }

    return ThematicCard(
      emoji: '\ud83c\udfe6', // bank
      title: S.of(context)!.reportRetirementTitle,
      status: status,
      keyNumber: '${formatChfWithPrefix(projection.totalMonthlyIncome)}/mois',
      keyNumberLabel: S.of(context)!.reportRetirementKeyLabel,
      source: S.of(context)!.reportRetirementSource,
      children: [
        RetirementProjectionCard(
          projection: projection,
          contributionYears: contributionYears,
          avsLacunesStatus: answers['q_avs_lacunes_status'] as String?,
        ),
        const SizedBox(height: 12),
        _buildInfoChip(
          has3a && nb3a >= 2 ? Icons.check_circle : Icons.info_outline,
          threeAText,
          has3a && nb3a >= 2 ? MintColors.success : MintColors.warning,
        ),
        if (lppText != null) ...[
          const SizedBox(height: 8),
          _buildInfoChip(Icons.savings, lppText, MintColors.info),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  THEMATIC CARD: TAX
  // ════════════════════════════════════════════════════════════════

  Widget _buildTaxThematicSection(
      BuildContext context, FinancialReport report) {
    final tax = report.taxSimulation;

    final status = tax.effectiveRate < 0.15
        ? CardStatus.serein
        : tax.effectiveRate < 0.25
            ? CardStatus.aRenforcer
            : CardStatus.alerte;

    return ThematicCard(
      emoji: '\ud83d\udcca', // bar chart
      title: S.of(context)!.reportTaxTitle,
      status: status,
      keyNumber: '${formatChfWithPrefix(tax.totalTax)}/an',
      keyNumberLabel: S
          .of(context)!
          .reportTaxKeyLabel((tax.effectiveRate * 100).toStringAsFixed(1)),
      actionLabel: S.of(context)!.reportTaxAction,
      onActionTap: () => context.push('/fiscal'),
      source: S.of(context)!.reportTaxSource,
      children: [
        _taxRow(S.of(context)!.reportTaxIncome,
            formatChfWithPrefix(tax.taxableIncome)),
        if (tax.totalDeductions > 0) ...[
          const SizedBox(height: 4),
          _taxRow(S.of(context)!.reportTaxDeductions,
              '\u2013 ${formatChfWithPrefix(tax.totalDeductions)}'),
        ],
        const Divider(height: 16),
        _taxRow(S.of(context)!.reportTaxEstimated,
            formatChfWithPrefix(tax.totalTax),
            isBold: true),
        if (tax.taxSavingsFromBuyback != null &&
            tax.taxSavingsFromBuyback! > 0) ...[
          const SizedBox(height: 8),
          _buildInfoChip(
            Icons.lightbulb_outline,
            S
                .of(context)!
                .reportTaxSavings(formatChf(tax.taxSavingsFromBuyback!)),
            MintColors.success,
          ),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPER WIDGETS
  // ════════════════════════════════════════════════════════════════

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: MintTextStyles.labelSmall(color: MintColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taxRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: MintTextStyles.bodySmall(
            color: isBold ? MintColors.textPrimary : MintColors.textSecondary,
          ).copyWith(fontWeight: isBold ? FontWeight.w700 : FontWeight.w400),
        ),
        Text(
          value,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
              .copyWith(fontWeight: isBold ? FontWeight.w700 : FontWeight.w500),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  TOP PRIORITIES (kept from original)
  // ════════════════════════════════════════════════════════════════

  Widget _buildTopPriorities(BuildContext context, List<ActionItem> actions) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.reportActions,
            style: MintTextStyles.headlineMedium(),
          ),
          const SizedBox(height: MintSpacing.md),
          ...actions.map((action) => _buildActionCard(context, action)),
        ],
      ),
    );
  }

  // _getActionRoute removed — use _routeForCategory(action.category) instead

  Widget _buildActionCard(BuildContext context, ActionItem action) {
    Color priorityColor;
    switch (action.priority) {
      case ActionPriority.critical:
        priorityColor = MintColors.redDeep;
        break;
      case ActionPriority.high:
        priorityColor = MintColors.warning;
        break;
      case ActionPriority.medium:
        priorityColor = MintColors.categoryBlue;
        break;
      case ActionPriority.low:
        priorityColor = MintColors.textSecondary;
        break;
    }

    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  action.title,
                  style: MintTextStyles.titleMedium(),
                ),
              ),
              if (action.potentialGainChf != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MintColors.successBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${formatChfWithPrefix(action.potentialGainChf!)}',
                    style:
                        MintTextStyles.labelMedium(color: MintColors.greenDark)
                            .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            action.description,
            style: MintTextStyles.bodySmall(),
          ),
          const SizedBox(height: 12),
          ...action.steps.take(3).map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\u2022 ', style: TextStyle(color: priorityColor)),
                    Expanded(
                      child: Text(
                        step,
                        style: MintTextStyles.labelSmall(),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(_routeForCategory(action.category)),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(S.of(context)!.reportCommencer),
              style: FilledButton.styleFrom(
                backgroundColor: priorityColor,
                foregroundColor: MintColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  LPP BUYBACK SECTION (kept from original)
  // ════════════════════════════════════════════════════════════════

  Widget _buildLppBuybackSection(
      BuildContext context, LppBuybackStrategy strategy, UserProfile profile) {
    // Taux marginal estimé selon canton + revenu (LIFD + ICC)
    final double marginalRate =
        profile.canton.isNotEmpty && profile.canton != 'CH'
            ? TaxEstimatorService.estimateMarginalTaxRate(
                netMonthlyIncome: profile.monthlyNetIncome,
                cantonCode: profile.canton,
                civilStatus: profile.civilStatus,
              ).clamp(0.10, 0.50)
            : 0.30; // Fallback conservateur si canton inconnu
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [MintColors.successBg, MintColors.accentPastel],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.greenLight, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context)!.reportLppTitle,
              style: MintTextStyles.headlineMedium(),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              S
                  .of(context)!
                  .reportLppEconomie(formatChf(strategy.totalTaxSavings)),
              style: MintTextStyles.bodyMedium(color: MintColors.greenDark)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: MintSpacing.md),
            ...strategy.yearlyPlan.map((buyback) => MintSurface(
                  padding: const EdgeInsets.all(12),
                  radius: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.of(context)!.reportLppYear(buyback.year),
                            style: MintTextStyles.bodySmall(
                                    color: MintColors.textPrimary)
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            S
                                .of(context)!
                                .reportLppBuyback(formatChf(buyback.amount)),
                            style: MintTextStyles.labelSmall(),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: MintColors.successBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          S.of(context)!.reportLppSaving(
                              formatChf(buyback.estimatedTaxSavings)),
                          style: MintTextStyles.labelSmall(
                                  color: MintColors.greenDark)
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )),

            // Widget d'explication p\u00e9dagogique
            EducationalExplanationWidget(
              title: S.of(context)!.reportLppHowTitle,
              shortExplanation: S.of(context)!.reportLppHowBody,
              sections: FinancialExplanations.lppBuybackExplanation(
                strategy.totalBuybackAvailable,
                marginalRate,
              ),
              accentColor: MintColors.greenDark,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SOA COMPLIANCE SECTION — Transparence reglementaire
  // ════════════════════════════════════════════════════════════════

  Widget _buildSoaComplianceSection(
      BuildContext context, FinancialReport report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_outlined,
                    size: 20, color: MintColors.info),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(
                  S.of(context)!.reportSoaTitle,
                  style: MintTextStyles.headlineMedium(),
                  overflow: TextOverflow.ellipsis,
                )),
              ],
            ),
            const SizedBox(height: 20),

            // Nature du service
            _buildSoaRow(
              S.of(context)!.reportSoaNature,
              report.personalizedRoadmap.phases.isNotEmpty
                  ? S.of(context)!.reportSoaEduPhases(
                      report.personalizedRoadmap.phases.length)
                  : S.of(context)!.reportSoaEduSimple,
            ),
            const SizedBox(height: 12),

            // Hypoth\u00e8ses de travail
            _buildSoaSubSection(
              S.of(context)!.reportSoaHypotheses,
              Icons.settings_suggest_outlined,
              [
                S.of(context)!.reportSoaHyp1,
                S.of(context)!.reportSoaHyp2,
                S.of(context)!.reportSoaHyp3,
                S.of(context)!.reportSoaHyp4,
                if (report.simulationAssumptions != null)
                  ...report.simulationAssumptions!.entries
                      .map((e) => '${e.key} : ${e.value}'),
              ],
            ),
            const SizedBox(height: 12),

            // Conflits d'int\u00e9r\u00eats
            _buildSoaSubSection(
              S.of(context)!.reportSoaConflicts,
              Icons.handshake_outlined,
              [
                S.of(context)!.reportSoaNoConflict,
                S.of(context)!.reportSoaNoCommission,
              ],
            ),
            const SizedBox(height: 12),

            // Limitations
            _buildSoaSubSection(
              S.of(context)!.reportSoaLimitations,
              Icons.info_outline,
              [
                S.of(context)!.reportSoaLim1,
                S.of(context)!.reportSoaLim2,
                S.of(context)!.reportSoaLim3,
                S.of(context)!.reportSoaLim4,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: MintTextStyles.labelSmall(color: MintColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildSoaSubSection(
    String title,
    IconData icon,
    List<String> items,
  ) {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(12),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: MintColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                title,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u2022 ',
                    style: MintTextStyles.labelSmall(),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: MintTextStyles.labelSmall(
                          color: MintColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  DISCLAIMER FOOTER — Mention legale obligatoire
  // ════════════════════════════════════════════════════════════════

  Widget _buildDisclaimerFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 14, color: MintColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  S.of(context)!.reportMentionLegale,
                  style: MintTextStyles.labelSmall()
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.reportDisclaimerText,
              style: MintTextStyles.micro(),
            ),
          ],
        ),
      ),
    );
  }

  int? _parseIntAnswer(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  double? _parseDoubleAnswer(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }

  bool? _parseBoolAnswer(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'yes' || normalized == 'true') return true;
      if (normalized == 'no' || normalized == 'false') return false;
    }
    return null;
  }

  double _estimateRemaining3aDeduction(
    FinancialReport report,
    Map<String, dynamic> answers,
  ) {
    final profile = report.profile;
    if (profile.monthlyNetIncome <= 0) return 0.0;
    final declaredAnnualGross =
        _parseDoubleAnswer(answers['q_gross_salary_annual']);
    final declaredMonthlyGross =
        _parseDoubleAnswer(answers['q_gross_income_monthly']);
    final age = profile.ageOrNull;
    final annualGrossSalary = declaredAnnualGross ??
        (declaredMonthlyGross != null ? declaredMonthlyGross * 12 : null) ??
        (age == null
            ? profile.monthlyNetIncome * 12
            : NetIncomeBreakdown.estimateBrutFromNet(
                profile.monthlyNetIncome * 12,
                age: age,
              ));
    final declaredLpp = _parseBoolAnswer(answers['q_has_pension_fund']);
    final hasLpp = declaredLpp ??
        (profile.isSalaried &&
            annualGrossSalary >= reg('lpp.entry_threshold', lppSeuilEntree));
    final annualCeiling = hasLpp
        ? reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp)
        : (annualGrossSalary * pilier3aTauxRevenuSansLpp)
            .clamp(0.0, reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp))
            .toDouble();
    final currentContribution =
        _parseDoubleAnswer(answers['q_3a_annual_contribution']) ?? 0.0;
    return (annualCeiling - currentContribution).clamp(0.0, annualCeiling);
  }
}
