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

/// Écran d'affichage du rapport financier exhaustif V2
class FinancialReportScreenV2 extends StatelessWidget {
  final Map<String, dynamic> wizardAnswers;

  const FinancialReportScreenV2({
    super.key,
    required this.wizardAnswers,
  });

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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header personnalisé
            _buildHeader(report.profile, report.healthScore),

            const SizedBox(height: 24),

            // Top 3 Priorites
            SafeModeGate(
              hasDebt: hasDebt,
              lockedTitle: 'Priorite au desendettement',
              lockedMessage:
                  'Tes actions prioritaires sont remplacees par un plan de desendettement. '
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
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  CircleScoreCard(score: report.healthScore.circle2Prevoyance),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  CircleScoreCard(score: report.healthScore.circle3Croissance),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CircleScoreCard(
                  score: report.healthScore.circle4Optimisation),
            ),

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
                  lockedTitle: 'Priorite au desendettement',
                  lockedMessage:
                      'Le comparateur 3a est desactive tant que tu as des dettes actives. '
                      'Rembourser tes dettes est prioritaire avant toute epargne 3a.',
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

            // Strategie rachat LPP
            if (report.lppBuybackStrategy != null)
              SafeModeGate(
                hasDebt: hasDebt,
                lockedTitle: 'Rachat LPP bloque',
                lockedMessage:
                    'Le rachat LPP est desactive en mode protection. '
                    'Rembourser tes dettes avant de bloquer de la liquidite dans la prevoyance.',
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

  String _getActionRoute(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('3a') || lower.contains('pilier')) return '/education/theme/3a';
    if (lower.contains('lpp') || lower.contains('caisse')) return '/education/theme/lpp';
    if (lower.contains('dette') || lower.contains('crédit')) return '/budget';
    if (lower.contains('urgence') || lower.contains('épargne')) return '/education/theme/emergency';
    if (lower.contains('impôt') || lower.contains('fiscal')) return '/tools';
    if (lower.contains('avs')) return '/education/theme/avs';
    if (lower.contains('budget')) return '/budget';
    if (lower.contains('assurance') || lower.contains('lamal')) return '/education/theme/lamal';
    if (lower.contains('hypothèque') || lower.contains('immobilier')) return '/tools';
    return '/tools';
  }

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
              onPressed: () => context.push(_getActionRoute(action.title)),
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
}
