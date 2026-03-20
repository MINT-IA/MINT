import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/models/circle_score.dart';
import 'package:mint_mobile/services/financial_report_service.dart';
import 'package:mint_mobile/widgets/report/thematic_card.dart';
import 'package:mint_mobile/widgets/report/debt_alert_banner.dart';
import 'package:mint_mobile/widgets/report/budget_waterfall.dart';
import 'package:mint_mobile/widgets/report/retirement_projection_card.dart';
import 'package:mint_mobile/widgets/comparators/pillar3a_comparator_widget.dart';
import 'package:mint_mobile/widgets/educational_explanation_widget.dart';
import 'package:mint_mobile/data/financial_explanations.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';
import 'package:mint_mobile/services/wizard_service.dart';
// ProfileProvider removed — hasDebt now derived from wizardAnswers directly

/// Ecran d'affichage du rapport financier exhaustif V2
/// Refonte : cartes thématiques (Budget, Protection, Retraite, Impôts)
/// remplaçant les cercles abstraits (Protection, Prévoyance, Croissance, Optimisation).
class FinancialReportScreenV2 extends StatelessWidget {
  final Map<String, dynamic> wizardAnswers;

  const FinancialReportScreenV2({
    super.key,
    required this.wizardAnswers,
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
    final reportService = FinancialReportService();
    final report = reportService.generateReport(wizardAnswers);
    final hasDebt = WizardService.isSafeModeActive(wizardAnswers);
    final safeModeReasons = _buildSafeModeReasons(context, wizardAnswers);

    return Scaffold(
      backgroundColor: MintColors.surface,
      appBar: AppBar(
        title: Text(S.of(context)!.reportTonPlanMint, style: MintTextStyles.titleMedium(color: MintColors.textPrimary)),
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/home'),
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header personnalisé (greeting + status summary)
            _buildHeader(context, report.profile, report.healthScore),

            const SizedBox(height: MintSpacing.lg),

            // ── Debt alert banner (conditional) ──
            if (hasDebt)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
                child: DebtAlertBanner(
                  totalBalance: (wizardAnswers['q_debt_total_balance'] as num?)
                      ?.toDouble(),
                  monthlyPayment:
                      (wizardAnswers['q_debt_payments_period_chf'] as num?)
                          ?.toDouble(),
                  onTap: () => context.push('/budget'),
                ),
              ),

            // ── Budget thematic card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
              child: _buildBudgetSection(context, wizardAnswers),
            ),

            // ── Protection thematic card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
              child: _buildProtectionSection(
                  context, wizardAnswers, report.healthScore),
            ),

            // ── Retirement thematic card ──
            if (report.retirementProjection != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
                child: _buildRetirementThematicSection(
                    context, report, wizardAnswers),
              ),

            // ── Tax thematic card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
              child: _buildTaxThematicSection(context, report),
            ),

            const SizedBox(height: MintSpacing.lg),

            // ── Top 3 Priorities ──
            SafeModeGate(
              hasDebt: hasDebt,
              lockedTitle: S.of(context)!.reportSafeModePriority,
              lockedMessage: S.of(context)!.reportSafeModeActions,
              reasons: safeModeReasons,
              child: _buildTopPriorities(context, report.priorityActions),
            ),

            const SizedBox(height: MintSpacing.lg),

            // ── Comparateur 3a (si applicable) ──
            if (report.pillar3aAnalysis != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
                child: Text(
                  S.of(context)!.reportOptimise3a,
                  style: MintTextStyles.headlineMedium(),
                ),
              ),
              const SizedBox(height: MintSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
                child: SafeModeGate(
                  hasDebt: hasDebt,
                  lockedTitle: S.of(context)!.reportSafeModePriority,
                  lockedMessage: S.of(context)!.reportSafeMode3a,
                  reasons: safeModeReasons,
                  child: Pillar3aComparatorWidget(
                    monthlyIncome: report.profile.monthlyNetIncome,
                    yearsUntilRetirement: report.profile.yearsToRetirement,
                    hasPensionFund: report.profile.isSalaried,
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.lg),
            ],

            // ── Strat\u00e9gie rachat LPP ──
            if (report.lppBuybackStrategy != null)
              SafeModeGate(
                hasDebt: hasDebt,
                lockedTitle: S.of(context)!.reportSafeModeLpp,
                lockedMessage: S.of(context)!.reportSafeModeLppMessage,
                reasons: safeModeReasons,
                child: _buildLppBuybackSection(context, report.lppBuybackStrategy!, report.profile),
              ),

            const SizedBox(height: MintSpacing.lg),

            // ── Life event suggestions based on profile ──
            LifeEventSuggestionsSection(
              suggestions: buildLifeEventSuggestions(
                age: report.profile.age,
                civilStatus: report.profile.civilStatus,
                childrenCount: report.profile.childrenCount,
                employmentStatus: report.profile.employmentStatus,
                monthlyNetIncome: report.profile.monthlyNetIncome,
                canton: report.profile.canton,
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
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  HEADER — Greeting + contextual status (replaces numeric score)
  // ════════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context, UserProfile profile, FinancialHealthScore healthScore) {
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
            Text(
              S.of(context)!.reportProfileSummary(profile.age, profile.canton, profile.civilStatus),
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

  Widget _buildStatusSummary(BuildContext context, FinancialHealthScore healthScore) {
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
    return Text(
      '$emoji $message',
      style: MintTextStyles.bodyLarge(color: MintColors.white).copyWith(fontWeight: FontWeight.w600),
      textAlign: TextAlign.center,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  THEMATIC CARD: BUDGET
  // ════════════════════════════════════════════════════════════════

  Widget _buildBudgetSection(
      BuildContext context, Map<String, dynamic> answers) {
    final income = WizardService.getMonthlyIncome(answers);
    final housing =
        (answers['q_housing_cost_period_chf'] as num?)?.toDouble() ?? 0;
    final debt =
        (answers['q_debt_payments_period_chf'] as num?)?.toDouble() ?? 0;
    final civilStatus = answers['q_civil_status'] as String? ?? 'single';
    final childrenCount = _parseChildren(answers['q_children']);
    final canton = answers['q_canton'] as String? ?? 'CH';

    final taxProvision =
        (answers['q_tax_provision_monthly_chf'] as num?)?.toDouble() ??
            TaxEstimatorService.estimateMonthlyProvision(
              TaxEstimatorService.estimateAnnualTax(
                netMonthlyIncome: income,
                cantonCode: canton,
                civilStatus: civilStatus,
                childrenCount: childrenCount,
                age: 35,
                isSourceTaxed: false,
              ),
            );
    final healthInsurance = (answers['q_lamal_premium_monthly_chf'] as num?)
            ?.toDouble() ??
        _estimateLamalMonthly(canton, answers['q_household_type'] as String?);
    final otherFixed =
        (answers['q_other_fixed_costs_monthly_chf'] as num?)?.toDouble() ?? 0;

    final available =
        income - housing - debt - taxProvision - healthInsurance - otherFixed;
    final ratio = income > 0 ? available / income : 0.0;

    final status = ratio > 0.3
        ? CardStatus.serein
        : ratio > 0.1
            ? CardStatus.aRenforcer
            : CardStatus.alerte;

    return ThematicCard(
      emoji: '\ud83d\udcb0', // money bag
      title: S.of(context)!.reportBudgetTitle,
      status: status,
      keyNumber:
          'CHF ${available.clamp(0, double.infinity).toStringAsFixed(0)}',
      keyNumberLabel: S.of(context)!.reportBudgetKeyLabel,
      actionLabel: S.of(context)!.reportBudgetAction,
      onActionTap: () => context.push('/budget'),
      children: [
        BudgetWaterfall(
          income: income,
          housing: housing,
          debt: debt,
          taxes: taxProvision,
          healthInsurance: healthInsurance,
          otherFixed: otherFixed,
        ),
      ],
    );
  }

  int _parseChildren(dynamic raw) {
    if (raw == null) return 0;
    final text = raw.toString().replaceAll('+', '');
    return int.tryParse(text) ?? 0;
  }

  double _estimateLamalMonthly(String cantonCode, String? householdType) {
    const highCantons = {'GE', 'VD', 'BS', 'NE'};
    const lowCantons = {'ZG', 'AI', 'UR', 'OW', 'NW'};
    final adults =
        householdType == 'couple' || householdType == 'family' ? 2 : 1;

    final baseAdult = highCantons.contains(cantonCode)
        ? 520.0
        : lowCantons.contains(cantonCode)
            ? 350.0
            : 430.0;

    return baseAdult * adults;
  }

  List<String> _buildSafeModeReasons(BuildContext context, Map<String, dynamic> answers) {
    final reasons = <String>[];

    if (answers['q_has_consumer_credit'] == 'yes' ||
        answers['q_has_consumer_debt'] == 'yes') {
      reasons.add(S.of(context)!.reportReasonDebt);
    }
    if (answers['q_has_leasing'] == 'yes') {
      reasons.add(S.of(context)!.reportReasonLeasing);
    }

    final debtPayment =
        (answers['q_debt_payments_period_chf'] as num?)?.toDouble() ?? 0;
    if (debtPayment > 0) {
      reasons.add(S.of(context)!.reportReasonPayments(debtPayment.toStringAsFixed(0)));
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
    final birthYear = (answers['q_birth_year'] as num?)?.toInt();
    int? contributionYears;
    if (birthYear != null) {
      final theoretical = (DateTime.now().year - (birthYear + 21)).clamp(0, 44);
      final avsStatus = answers['q_avs_lacunes_status'];
      if (avsStatus == 'no_gaps') {
        contributionYears = theoretical;
      } else if (avsStatus == 'arrived_late') {
        final arrivalYear = (answers['q_avs_arrival_year'] as num?)?.toInt();
        if (arrivalYear != null) {
          final gaps = (arrivalYear - (birthYear + 21)).clamp(0, 44);
          contributionYears = (theoretical - gaps).clamp(0, 44);
        }
      } else if (avsStatus == 'lived_abroad') {
        final yearsAbroad =
            (answers['q_avs_years_abroad'] as num?)?.toInt() ?? 0;
        contributionYears = (theoretical - yearsAbroad).clamp(0, 44);
      }
      // Fallback legacy: q_first_employment_year
      if (contributionYears == null) {
        final firstEmploymentYear =
            (answers['q_first_employment_year'] as num?)?.toInt();
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
      threeAText = S.of(context)!.reportRetirement3aNone;
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
        lppBuyback.totalBuybackAvailable.toStringAsFixed(0),
        lppBuyback.totalTaxSavings.toStringAsFixed(0),
      );
    }

    return ThematicCard(
      emoji: '\ud83c\udfe6', // bank
      title: S.of(context)!.reportRetirementTitle,
      status: status,
      keyNumber: 'CHF ${projection.totalMonthlyIncome.toStringAsFixed(0)}/mois',
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
      keyNumber: 'CHF ${tax.totalTax.toStringAsFixed(0)}/an',
      keyNumberLabel: S.of(context)!.reportTaxKeyLabel((tax.effectiveRate * 100).toStringAsFixed(1)),
      actionLabel: S.of(context)!.reportTaxAction,
      onActionTap: () => context.push('/fiscal'),
      source: S.of(context)!.reportTaxSource,
      children: [
        _taxRow(S.of(context)!.reportTaxIncome, 'CHF ${tax.taxableIncome.toStringAsFixed(0)}'),
        if (tax.totalDeductions > 0) ...[
          const SizedBox(height: 4),
          _taxRow(S.of(context)!.reportTaxDeductions,
              '\u2013 CHF ${tax.totalDeductions.toStringAsFixed(0)}'),
        ],
        const Divider(height: 16),
        _taxRow(S.of(context)!.reportTaxEstimated,
            'CHF ${tax.totalTax.toStringAsFixed(0)}',
            isBold: true),
        if (tax.taxSavingsFromBuyback != null &&
            tax.taxSavingsFromBuyback! > 0) ...[
          const SizedBox(height: 8),
          _buildInfoChip(
            Icons.lightbulb_outline,
            S.of(context)!.reportTaxSavings(tax.taxSavingsFromBuyback!.toStringAsFixed(0)),
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

    return Container(
      margin: const EdgeInsets.only(bottom: MintSpacing.md),
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: priorityColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: priorityColor.withValues(alpha: 0.1),
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
                    '+CHF ${action.potentialGainChf!.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: MintColors.greenDark,
                    ),
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

  Widget _buildLppBuybackSection(BuildContext context, LppBuybackStrategy strategy, UserProfile profile) {
    // Taux marginal estimé selon canton + revenu (LIFD + ICC)
    final double marginalRate = profile.canton.isNotEmpty && profile.canton != 'CH'
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
              S.of(context)!.reportLppEconomie(strategy.totalTaxSavings.toStringAsFixed(0)),
              style: MintTextStyles.bodyMedium(color: MintColors.greenDark)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: MintSpacing.md),
            ...strategy.yearlyPlan.map((buyback) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MintColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.of(context)!.reportLppYear(buyback.year),
                            style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            S.of(context)!.reportLppBuyback(buyback.amount.toStringAsFixed(0)),
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
                          S.of(context)!.reportLppSaving(buyback.estimatedTaxSavings.toStringAsFixed(0)),
                          style: MintTextStyles.labelSmall(color: MintColors.greenDark)
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

  Widget _buildSoaComplianceSection(BuildContext context, FinancialReport report) {
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
                const Icon(Icons.verified_outlined, size: 20, color: MintColors.info),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.reportSoaTitle,
                  style: MintTextStyles.headlineMedium(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nature du service
            _buildSoaRow(
              S.of(context)!.reportSoaNature,
              report.personalizedRoadmap.phases.isNotEmpty
                  ? S.of(context)!.reportSoaEduPhases(report.personalizedRoadmap.phases.length)
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
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
                      style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MintColors.lightBorder,
          ),
        ),
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
                  style: MintTextStyles.labelSmall().copyWith(fontWeight: FontWeight.w600),
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
}
