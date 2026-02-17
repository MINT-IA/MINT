import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/models/circle_score.dart';
import 'package:mint_mobile/services/financial_report_service.dart';
import 'package:mint_mobile/widgets/report/circle_score_card.dart';
import 'package:mint_mobile/widgets/comparators/pillar3a_comparator_widget.dart';
import 'package:mint_mobile/widgets/educational_explanation_widget.dart';
import 'package:mint_mobile/data/financial_explanations.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:provider/provider.dart';

/// Ecran d'affichage du rapport financier exhaustif V2
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
      ActionCategory.pillar3a => '/simulator/3a',
      ActionCategory.lpp => '/lpp-deep/rachat',
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
    final hasDebt = context.watch<ProfileProvider>().profile?.hasDebt ?? false;

    return Scaffold(
      backgroundColor: MintColors.surface,
      appBar: AppBar(
        title: const Text('Ton Plan Mint'),
        backgroundColor: MintColors.primary,
        foregroundColor: Colors.white,
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
        child: const Icon(Icons.picture_as_pdf, color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header personnalisé
            _buildHeader(report.profile, report.healthScore),

            const SizedBox(height: 24),

            // Top 3 Priorités
            SafeModeGate(
              hasDebt: hasDebt,
              lockedTitle: 'Priorité au désendettement',
              lockedMessage:
                  'Tes actions prioritaires sont remplacées par un plan de désendettement. '
                  'Stabilise ta situation avant d\'explorer les recommandations.',
              child: _buildTopPriorities(context, report.priorityActions),
            ),

            const SizedBox(height: 24),

            // Scores par Cercle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Diagnostic par Cercle',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  CircleScoreCard(score: report.healthScore.circle1Protection),
            ),
            // Source juridique: Protection
            _buildSourceReference('LP art. 93, Directives CSIAS'),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  CircleScoreCard(score: report.healthScore.circle2Prevoyance),
            ),
            // Source juridique: Prévoyance
            _buildSourceReference('LPP art. 14, OPP3, LAVS'),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  CircleScoreCard(score: report.healthScore.circle3Croissance),
            ),
            // Source juridique: Croissance
            _buildSourceReference('LIFD art. 33'),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CircleScoreCard(
                  score: report.healthScore.circle4Optimisation),
            ),
            // Source juridique: Optimisation
            _buildSourceReference('CC art. 470, LIFD'),

            const SizedBox(height: 24),

            // Comparateur 3a (si applicable)
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
                  lockedTitle: 'Priorité au désendettement',
                  lockedMessage:
                      'Le comparateur 3a est désactivée tant que tu as des dettes actives. '
                      'Rembourser tes dettes est prioritaire avant toute épargne 3a.',
                  child: Pillar3aComparatorWidget(
                    monthlyIncome: report.profile.monthlyNetIncome,
                    yearsUntilRetirement: report.profile.yearsToRetirement,
                    hasPensionFund: report.profile.isSalaried,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Simulation fiscale
            _buildTaxSection(report.taxSimulation),

            const SizedBox(height: 24),

            // Projection retraite
            if (report.retirementProjection != null)
              _buildRetirementSection(
                  report.retirementProjection!, report.profile.isMarried),

            const SizedBox(height: 24),

            // Stratégie rachat LPP
            if (report.lppBuybackStrategy != null)
              SafeModeGate(
                hasDebt: hasDebt,
                lockedTitle: 'Rachat LPP bloque',
                lockedMessage:
                    'Le rachat LPP est désactivée en mode protection. '
                    'Rembourser tes dettes avant de bloquer de la liquidité dans la prévoyance.',
                child: _buildLppBuybackSection(report.lppBuybackStrategy!),
              ),

            const SizedBox(height: 24),

            // Life event suggestions based on profile
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

  Widget _buildHeader(UserProfile profile, FinancialHealthScore healthScore) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MintColors.primary, MintColors.primary.withOpacity(0.7)],
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
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${profile.age} ans • ${profile.canton} • ${profile.civilStatus}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Score de Santé Financière',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${healthScore.overallScore.toInt()}/100',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        healthScore.overallLevel.label,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        healthScore.overallLevel.emoji,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPriorities(BuildContext context, List<ActionItem> actions) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 Tes 3 Actions Prioritaires',
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
        priorityColor = Colors.red.shade600;
        break;
      case ActionPriority.high:
        priorityColor = Colors.orange.shade600;
        break;
      case ActionPriority.medium:
        priorityColor = Colors.blue.shade600;
        break;
      case ActionPriority.low:
        priorityColor = Colors.grey.shade600;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: priorityColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: priorityColor.withOpacity(0.1),
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
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+CHF ${action.potentialGainChf!.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
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
                    Text('• ', style: TextStyle(color: priorityColor)),
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
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxSection(TaxSimulation tax) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💸 Simulation Fiscale',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTaxRow('Revenu imposable',
                'CHF ${tax.taxableIncome.toStringAsFixed(0)}'),
            if (tax.deductions.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Déductions',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ...tax.deductions.entries.map((e) => _buildTaxRow(
                    e.key,
                    '-CHF ${e.value.toStringAsFixed(0)}',
                    isDeduction: true,
                  )),
            ],
            const Divider(height: 24),
            _buildTaxRow(
                'Impôts estimés', 'CHF ${tax.totalTax.toStringAsFixed(0)}',
                isBold: true),
            _buildTaxRow('Taux effectif',
                '${(tax.effectiveRate * 100).toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRow(String label, String value,
      {bool isDeduction = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color:
                  isDeduction ? MintColors.textMuted : MintColors.textPrimary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color:
                  isDeduction ? Colors.green.shade700 : MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetirementSection(
      RetirementProjection projection, bool isMarried) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.purple.shade50],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎯 Projection Retraite (65 ans)',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Capital estimé',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
            Text(
              'CHF ${projection.totalCapital.toStringAsFixed(0)}',
              style: GoogleFonts.montserrat(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 16),
            _buildRetirementRow(
                isMarried
                    ? 'Rente AVS mensuelle (Couple)'
                    : 'Rente AVS mensuelle',
                'CHF ${projection.monthlyAvsRent.toStringAsFixed(0)}'),
            _buildRetirementRow('Rente LPP mensuelle',
                'CHF ${projection.monthlyLppRent.toStringAsFixed(0)}'),
            const Divider(height: 24),
            _buildRetirementRow(
              'TOTAL mensuel',
              'CHF ${projection.totalMonthlyIncome.toStringAsFixed(0)}',
              isBold: true,
            ),
            if (projection.avsReductionFactor < 1.0 ||
                projection.spouseAvsReductionFactor < 1.0)
              _buildAvsGapWarning(projection),
          ],
        ),
      ),
    );
  }

  Widget _buildAvsGapWarning(RetirementProjection projection) {
    // Get contribution years from wizards answers if available, otherwise estimate from reduction factor
    final years = (projection.avsReductionFactor * 44).round();
    final gap = 44 - years;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attention : Lacunes AVS détectées ($gap ans)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Il te manque $gap années de cotisation sur les 44 requises. Ta rente sera réduite de ${(projection.avsReductionFactor * 100).toStringAsFixed(1)}% par rapport au maximum.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        EducationalExplanationWidget(
          title: 'Comprendre mes lacunes AVS',
          shortExplanation:
              'Découvre pourquoi chaque année compte et comment éviter une perte de rente à vie.',
          sections: FinancialExplanations.avsGapExplanation(
            years,
            projection.spouseAvsReductionFactor < 1.0,
            (projection.spouseAvsReductionFactor * 44).round(),
          ),
          accentColor: Colors.orange.shade700,
        ),
      ],
    );
  }

  Widget _buildRetirementRow(String label, String value,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLppBuybackSection(LppBuybackStrategy strategy) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.teal.shade50],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💰 Stratégie Rachat LPP',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Économie fiscale totale : CHF ${strategy.totalTaxSavings.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...strategy.yearlyPlan.map((buyback) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Année ${buyback.year}',
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
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Économie: CHF ${buyback.estimatedTaxSavings.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

            // Widget d'explication pédagogique
            EducationalExplanationWidget(
              title: 'Comment ça marche ?',
              shortExplanation:
                  'Comprends pourquoi échelonner tes rachats LPP te fait économiser des milliers de francs supplémentaires.',
              sections: FinancialExplanations.lppBuybackExplanation(
                strategy.totalBuybackAvailable,
                0.35, // TODO: Utiliser le vrai taux marginal du profil
              ),
              accentColor: Colors.green.shade700,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SOURCES JURIDIQUES — Reference after each circle section
  // ════════════════════════════════════════════════════════════════

  Widget _buildSourceReference(String source) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.gavel,
            size: 12,
            color: MintColors.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Source : $source',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: MintColors.textMuted,
              ),
            ),
          ),
        ],
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined,
                    size: 20, color: MintColors.info),
                const SizedBox(width: 8),
                Text(
                  'Transparence et conformité',
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
                  ? 'Éducation financière — ${report.personalizedRoadmap.phases.length} phases identifiées'
                  : 'Éducation financière personnalisée',
            ),
            const SizedBox(height: 12),

            // Hypothèses de travail
            _buildSoaSubSection(
              'Hypothèses de travail',
              Icons.settings_suggest_outlined,
              [
                'Revenus déclarés stables sur la période',
                'Taux de conversion LPP obligatoire : 6.8%',
                'Plafond 3a salarié : 7\'258 CHF/an',
                'Rente AVS maximale : 30\'240 CHF/an',
                if (report.simulationAssumptions != null)
                  ...report.simulationAssumptions!.entries
                      .map((e) => '${e.key} : ${e.value}'),
              ],
            ),
            const SizedBox(height: 12),

            // Conflits d'intérêts
            _buildSoaSubSection(
              'Conflits d\'intérêts',
              Icons.handshake_outlined,
              [
                'Aucun conflit d\'intérêt identifié pour ce rapport.',
                'MINT ne perçoit aucune commission sur les produits mentionnés.',
              ],
            ),
            const SizedBox(height: 12),

            // Limitations
            _buildSoaSubSection(
              'Limitations',
              Icons.info_outline,
              [
                'Basé sur les informations déclaratives uniquement',
                'Estimation fiscale approximative (taux moyens cantonaux)',
                'Ne prend pas en compte les revenus de fortune mobilière',
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
                Icon(Icons.shield_outlined,
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
              'Outil éducatif \u2014 ne constitue pas un conseil financier au sens de la LSFin. '
              'Les montants sont des estimations basées sur les données déclarées.',
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
