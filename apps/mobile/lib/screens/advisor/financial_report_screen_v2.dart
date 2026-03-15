import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
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
      ActionCategory.avs => '/retirement',
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
    final safeModeReasons = _buildSafeModeReasons(wizardAnswers);

    return Scaffold(
      backgroundColor: MintColors.surface,
      appBar: AppBar(
        title: const Text('Ton Plan Mint'),
        backgroundColor: MintColors.primary,
        foregroundColor: MintColors.white,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          PdfService.generateFinancialReportPdf(report);
        },
        backgroundColor: MintColors.primary,
        child: const Icon(Icons.picture_as_pdf, color: MintColors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header personnalisé (greeting + status summary)
            _buildHeader(report.profile, report.healthScore),

            const SizedBox(height: 24),

            // ── Debt alert banner (conditional) ──
            if (hasDebt)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildBudgetSection(context, wizardAnswers),
            ),

            // ── Protection thematic card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildProtectionSection(
                  context, wizardAnswers, report.healthScore),
            ),

            // ── Retirement thematic card ──
            if (report.retirementProjection != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildRetirementThematicSection(
                    context, report, wizardAnswers),
              ),

            // ── Tax thematic card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTaxThematicSection(context, report),
            ),

            const SizedBox(height: 24),

            // ── Top 3 Priorities ──
            SafeModeGate(
              hasDebt: hasDebt,
              lockedTitle: 'Priorit\u00e9 au d\u00e9sendettement',
              lockedMessage:
                  'Tes actions prioritaires sont remplac\u00e9es par un plan de d\u00e9sendettement. '
                  'Stabilise ta situation avant d\'explorer les recommandations.',
              reasons: safeModeReasons,
              child: _buildTopPriorities(context, report.priorityActions),
            ),

            const SizedBox(height: 24),

            // ── Comparateur 3a (si applicable) ──
            if (report.pillar3aAnalysis != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Optimise ton 3a',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SafeModeGate(
                  hasDebt: hasDebt,
                  lockedTitle: 'Priorit\u00e9 au d\u00e9sendettement',
                  lockedMessage:
                      'Le comparateur 3a est d\u00e9sactiv\u00e9e tant que tu as des dettes actives. '
                      'Rembourser tes dettes est prioritaire avant toute \u00e9pargne 3a.',
                  reasons: safeModeReasons,
                  child: Pillar3aComparatorWidget(
                    monthlyIncome: report.profile.monthlyNetIncome,
                    yearsUntilRetirement: report.profile.yearsToRetirement,
                    hasPensionFund: report.profile.isSalaried,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Strat\u00e9gie rachat LPP ──
            if (report.lppBuybackStrategy != null)
              SafeModeGate(
                hasDebt: hasDebt,
                lockedTitle: 'Rachat LPP bloqu\u00e9',
                lockedMessage:
                    'Le rachat LPP est d\u00e9sactiv\u00e9 en mode protection. '
                    'Rembourser tes dettes avant de bloquer de la liquidit\u00e9 dans la pr\u00e9voyance.',
                reasons: safeModeReasons,
                child: _buildLppBuybackSection(report.lppBuybackStrategy!, report.profile),
              ),

            const SizedBox(height: 24),

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

            const SizedBox(height: 32),

            // ── SoA Compliance Section ──
            _buildSoaComplianceSection(report),

            const SizedBox(height: 24),

            // ── Disclaimer Footer ──
            _buildDisclaimerFooter(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  HEADER — Greeting + contextual status (replaces numeric score)
  // ════════════════════════════════════════════════════════════════

  Widget _buildHeader(UserProfile profile, FinancialHealthScore healthScore) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
              'Bonjour ${profile.firstName ?? ""}!',
              style: const TextStyle(
                color: MintColors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${profile.age} ans \u2022 ${profile.canton} \u2022 ${profile.civilStatus}',
              style: const TextStyle(color: MintColors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Contextual status phrase (replaces XX/100 score)
            _buildStatusSummary(healthScore),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSummary(FinancialHealthScore healthScore) {
    final level = healthScore.overallScore;
    String message;
    String emoji;
    if (level >= 70) {
      message = 'Ta base est solide, continue ainsi !';
      emoji = '\ud83d\udfe2'; // green circle
    } else if (level >= 40) {
      message = 'Quelques ajustements pour \u00eatre serein';
      emoji = '\ud83d\udfe1'; // yellow circle
    } else {
      message = 'Priorit\u00e9 : stabilise ta situation';
      emoji = '\ud83d\udd34'; // red circle
    }
    return Text(
      '$emoji $message',
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: MintColors.white,
      ),
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
      title: 'Ton Budget',
      status: status,
      keyNumber:
          'CHF ${available.clamp(0, double.infinity).toStringAsFixed(0)}',
      keyNumberLabel: 'Reste à vivre (après fixes)',
      actionLabel: 'Configurer mes enveloppes',
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

  List<String> _buildSafeModeReasons(Map<String, dynamic> answers) {
    final reasons = <String>[];

    if (answers['q_has_consumer_credit'] == 'yes' ||
        answers['q_has_consumer_debt'] == 'yes') {
      reasons.add('Dette à la consommation active.');
    }
    if (answers['q_has_leasing'] == 'yes') {
      reasons.add('Leasing actif avec charge mensuelle.');
    }

    final debtPayment =
        (answers['q_debt_payments_period_chf'] as num?)?.toDouble() ?? 0;
    if (debtPayment > 0) {
      reasons.add(
          'Remboursements de dette: CHF ${debtPayment.toStringAsFixed(0)} / mois.');
    }

    final emergencyFund = answers['q_emergency_fund'] as String?;
    if (emergencyFund == null || emergencyFund == 'no') {
      reasons.add('Fonds d’urgence insuffisant (< 3 mois).');
    }

    if (reasons.isEmpty) {
      reasons.add(
          'Signal de fragilité détecté: priorité à la stabilité budgétaire.');
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
      title: 'Ta Protection',
      status: fundStatus,
      keyNumber: '$fundMonths mois',
      keyNumberLabel: 'Fonds d\'urgence (cible : 6 mois)',
      source: 'Source : LP art. 93 \u2014 Minimum vital',
      actionLabel: fundStatus != CardStatus.serein
          ? 'Constituer mon fonds d\'urgence'
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
      threeAText =
          'Pas encore de 3a \u2014 jusqu\'\u00e0 CHF 7\'258/an de d\u00e9duction fiscale possible';
    } else if (nb3a == 1) {
      threeAText = '1 compte 3a \u2014 ouvre un 2e pour optimiser le retrait';
    } else {
      threeAText = '$nb3a comptes 3a \u2014 bonne diversification';
    }

    // LPP sub-section
    final lppBuyback = report.lppBuybackStrategy;
    String? lppText;
    if (lppBuyback != null) {
      lppText =
          'Rachat LPP disponible : CHF ${lppBuyback.totalBuybackAvailable.toStringAsFixed(0)} \u2014 \u00e9conomie fiscale estim\u00e9e : CHF ${lppBuyback.totalTaxSavings.toStringAsFixed(0)}';
    }

    return ThematicCard(
      emoji: '\ud83c\udfe6', // bank
      title: 'Ta Retraite',
      status: status,
      keyNumber: 'CHF ${projection.totalMonthlyIncome.toStringAsFixed(0)}/mois',
      keyNumberLabel: 'Revenu estim\u00e9 \u00e0 65 ans',
      source: 'Sources : LPP art. 14, OPP3, LAVS',
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
      title: 'Tes Imp\u00f4ts',
      status: status,
      keyNumber: 'CHF ${tax.totalTax.toStringAsFixed(0)}/an',
      keyNumberLabel:
          'Imp\u00f4ts estim\u00e9s (taux effectif : ${(tax.effectiveRate * 100).toStringAsFixed(1)}%)',
      actionLabel: 'Comparer 26 cantons',
      onActionTap: () => context.push('/fiscal'),
      source: 'Source : LIFD art. 33',
      children: [
        _taxRow(
            'Revenu imposable', 'CHF ${tax.taxableIncome.toStringAsFixed(0)}'),
        if (tax.totalDeductions > 0) ...[
          const SizedBox(height: 4),
          _taxRow('D\u00e9ductions',
              '\u2013 CHF ${tax.totalDeductions.toStringAsFixed(0)}'),
        ],
        const Divider(height: 16),
        _taxRow('Imp\u00f4ts estim\u00e9s',
            'CHF ${tax.totalTax.toStringAsFixed(0)}',
            isBold: true),
        if (tax.taxSavingsFromBuyback != null &&
            tax.taxSavingsFromBuyback! > 0) ...[
          const SizedBox(height: 8),
          _buildInfoChip(
            Icons.lightbulb_outline,
            '\u00c9conomie possible avec rachat LPP : CHF ${tax.taxSavingsFromBuyback!.toStringAsFixed(0)}/an',
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
              style: GoogleFonts.inter(
                  fontSize: 12, color: MintColors.textPrimary, height: 1.4),
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
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: isBold ? MintColors.textPrimary : MintColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: MintColors.textPrimary,
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\ud83c\udfaf Tes 3 Actions Prioritaires',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
          const SizedBox(height: 8),
          Text(
            action.description,
            style: const TextStyle(fontSize: 13, color: MintColors.textMuted),
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
                        style: const TextStyle(fontSize: 12),
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
              label: const Text('Commencer'),
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

  Widget _buildLppBuybackSection(LppBuybackStrategy strategy, UserProfile profile) {
    // Taux marginal estimé selon canton + revenu (LIFD + ICC)
    final double marginalRate = profile.canton.isNotEmpty && profile.canton != 'CH'
        ? TaxEstimatorService.estimateMarginalTaxRate(
            netMonthlyIncome: profile.monthlyNetIncome,
            cantonCode: profile.canton,
            civilStatus: profile.civilStatus,
          ).clamp(0.10, 0.50)
        : 0.30; // Fallback conservateur si canton inconnu
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
              '\ud83d\udcb0 Strat\u00e9gie Rachat LPP',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\u00c9conomie fiscale totale : CHF ${strategy.totalTaxSavings.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 14,
                color: MintColors.greenDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
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
                            'Ann\u00e9e ${buyback.year}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Rachat: CHF ${buyback.amount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12),
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
                          '\u00c9conomie: CHF ${buyback.estimatedTaxSavings.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: MintColors.greenDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

            // Widget d'explication p\u00e9dagogique
            EducationalExplanationWidget(
              title: 'Comment \u00e7a marche ?',
              shortExplanation:
                  'Comprends pourquoi \u00e9chelonner tes rachats LPP te fait \u00e9conomiser des milliers de francs suppl\u00e9mentaires.',
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

  Widget _buildSoaComplianceSection(FinancialReport report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  'Transparence et conformit\u00e9',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MintColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nature du service
            _buildSoaRow(
              'Nature du service',
              report.personalizedRoadmap.phases.isNotEmpty
                  ? '\u00c9ducation financi\u00e8re \u2014 ${report.personalizedRoadmap.phases.length} phases identifi\u00e9es'
                  : '\u00c9ducation financi\u00e8re personnalis\u00e9e',
            ),
            const SizedBox(height: 12),

            // Hypoth\u00e8ses de travail
            _buildSoaSubSection(
              'Hypoth\u00e8ses de travail',
              Icons.settings_suggest_outlined,
              [
                'Revenus d\u00e9clar\u00e9s stables sur la p\u00e9riode',
                'Taux de conversion LPP obligatoire : 6.8%',
                'Plafond 3a salari\u00e9 : 7\'258 CHF/an',
                'Rente AVS maximale : 30\'240 CHF/an',
                if (report.simulationAssumptions != null)
                  ...report.simulationAssumptions!.entries
                      .map((e) => '${e.key} : ${e.value}'),
              ],
            ),
            const SizedBox(height: 12),

            // Conflits d'int\u00e9r\u00eats
            _buildSoaSubSection(
              'Conflits d\'int\u00e9r\u00eats',
              Icons.handshake_outlined,
              [
                'Aucun conflit d\'int\u00e9r\u00eat identifi\u00e9 pour ce rapport.',
                'MINT ne per\u00e7oit aucune commission sur les produits mentionn\u00e9s.',
              ],
            ),
            const SizedBox(height: 12),

            // Limitations
            _buildSoaSubSection(
              'Limitations',
              Icons.info_outline,
              [
                'Bas\u00e9 sur les informations d\u00e9claratives uniquement',
                'Estimation fiscale approximative (taux moyens cantonaux)',
                'Ne prend pas en compte les revenus de fortune mobili\u00e8re',
                'Les projections ne tiennent pas compte de l\'inflation',
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
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MintColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textPrimary,
            ),
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
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
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
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: MintColors.textSecondary,
                        height: 1.4,
                      ),
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

  Widget _buildDisclaimerFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
                  'Mention legale',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Outil \u00e9ducatif \u2014 ne constitue pas un conseil financier au sens de la LSFin. '
              'Les montants sont des estimations bas\u00e9es sur les donn\u00e9es d\u00e9clar\u00e9es.',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
