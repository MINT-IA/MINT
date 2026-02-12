import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_service.dart';
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/report/report_builder.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/budget/budget_report_section.dart';
import 'package:mint_mobile/widgets/recommendation_card.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

class AdvisorReportScreen extends StatefulWidget {
  final String? sessionId;
  final Map<String, dynamic>? answers;

  const AdvisorReportScreen({
    super.key,
    this.sessionId,
    this.answers,
  });

  @override
  State<AdvisorReportScreen> createState() => _AdvisorReportScreenState();
}

class _AdvisorReportScreenState extends State<AdvisorReportScreen> {
  late Future<SessionReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _loadReport();
  }

  Future<SessionReport> _loadReport() async {
    if (widget.answers != null) {
      return ReportBuilder(widget.answers!).build();
    } else if (widget.sessionId != null) {
      return ApiService.getSessionReport(widget.sessionId!);
    } else {
      // Fallback for browser refresh: try to load from persistence
      final savedAnswers = await ReportPersistenceService.loadAnswers();
      if (savedAnswers.isNotEmpty) {
        return ReportBuilder(savedAnswers).build();
      }
      throw Exception(
          "Données du rapport non trouvées (essayez de recommencer le wizard).");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: const Text('Statement of Advice'),
        actions: [
          IconButton(
            onPressed: () async {
              final report = await _reportFuture;
              await PdfService.generateSessionReportPdf(report);
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: FutureBuilder<SessionReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          final report = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(report),
                const SizedBox(height: 24),
                _buildPrecisionBanner(report),
                const SizedBox(height: 24),
                _buildOverviewBar(report),
                const SizedBox(height: 32),
                _buildScoreboard(report),
                if (widget.answers != null) ...[
                  const SizedBox(height: 32),
                  _buildBudgetSection(context),
                ],
                const SizedBox(height: 40),
                Text(
                  'Le Conseil de votre Mentor',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                for (var a in report.topActions) _buildTopActionCard(a),
                const SizedBox(height: 40),
                _buildSoASection(report),
                const SizedBox(height: 40),
                _buildDetailedRecos(report),
                const SizedBox(height: 40),
                _buildLifeEventSuggestionsFromAnswers(),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final report = await _reportFuture;
          await PdfService.generateSessionReportPdf(report);
        },
        label: Text('Export PDF Professionnel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        icon: const Icon(Icons.picture_as_pdf_outlined),
        backgroundColor: MintColors.textPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBudgetSection(BuildContext context) {
    // Calcul à la volée pour l'affichage via Widget dédié
    final inputs = BudgetInputs.fromMap(widget.answers!);
    final service = BudgetService();
    // On pourrait récupérer les overrides locaux ici si on voulait (via BudgetLocalStore)
    // Pour simplifier, on affiche le plan par défaut standard
    final plan = service.computePlan(inputs);

    return BudgetReportSection(
      plan: plan,
      onEdit: () {
        // Naviguer vers l'écran budget si besoin
        // context.push('/budget', extra: inputs);
      },
    );
  }

  Widget _buildHeader(SessionReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          report.title,
          style: GoogleFonts.outfit(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.verified_user,
                size: 14, color: MintColors.textMuted),
            const SizedBox(width: 6),
            Text(
              'Généré le ${report.generatedAt.day}/${report.generatedAt.month}/${report.generatedAt.year}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrecisionBanner(SessionReport report) {
    final bool isLow = report.precisionScore < 0.5;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          Icon(
              isLow
                  ? Icons.warning_amber_rounded
                  : Icons.verified_user_outlined,
              color: isLow ? MintColors.warning : MintColors.success),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Indice de Précision : ${(report.precisionScore * 100).toInt()}%',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: isLow ? MintColors.warning : MintColors.success),
                ),
                Text(
                  isLow
                      ? 'Complétez votre FactFind pour rabaisser vos marges d\'erreur.'
                      : 'Votre diagnostic est hautement personnalisé.',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewBar(SessionReport report) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildOverviewItem(
            Icons.location_on_outlined, report.overview.canton, 'Canton'),
        _buildOverviewItem(
            Icons.group_outlined, report.overview.householdType, 'Foyer'),
        _buildOverviewItem(Icons.flag_outlined,
            report.overview.goalRecommendedLabel, 'Objectif'),
      ],
    );
  }

  Widget _buildOverviewItem(IconData icon, String label, String category) {
    return Column(
      children: [
        Icon(icon, size: 24, color: MintColors.primary),
        const SizedBox(height: 8),
        Text(category.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildScoreboard(SessionReport report) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 24,
          childAspectRatio: 2.5,
        ),
        itemCount: report.scoreboard.length,
        itemBuilder: (context, index) {
          final item = report.scoreboard[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(item.value,
                  style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                      letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(item.note,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopActionCard(TopAction action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action.effortTag.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: MintColors.primary,
                        letterSpacing: 1.0)),
                const SizedBox(height: 12),
                Text(action.label,
                    style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5)),
                const SizedBox(height: 10),
                Text(action.why,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: MintColors.textSecondary,
                        height: 1.5)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: MintColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MintColors.lightBorder)),
                  child: Text(action.ifThen,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: MintColors.textPrimary)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(19),
                        bottomRight: Radius.circular(19))),
              ),
              child: Text(
                action.nextAction.label,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoASection(SessionReport report) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('⚖️ Transparence & Plan de Route',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: MintColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  report.mintRoadmap.mentorshipLevel,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: MintColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Nature : ${report.mintRoadmap.natureOfService}',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          const Text('Hypothèses de Travail :',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ...report.mintRoadmap.assumptions
              .map((a) => Text('• $a', style: const TextStyle(fontSize: 12))),
          const SizedBox(height: 16),
          const Text('Conflits d\'intérêts & Commissions :',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: MintColors.warning)),
          if (report.mintRoadmap.conflicts.isEmpty)
            const Text('Aucun conflit d\'intérêt identifié pour ce rapport.',
                style: TextStyle(fontSize: 12, color: MintColors.success)),
          ...report.mintRoadmap.conflicts.map((c) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ${c.partner}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(c.disclosure,
                      style: const TextStyle(
                          fontSize: 11, fontStyle: FontStyle.italic)),
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildDetailedRecos(SessionReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Analyses Détaillées',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        for (var r in report.recommendations)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RecommendationCard(recommendation: r),
          ),
      ],
    );
  }

  Widget _buildLifeEventSuggestionsFromAnswers() {
    final answers = widget.answers ?? {};
    final currentYear = DateTime.now().year;
    final birthYear = answers['q_birth_year'] as int? ?? (currentYear - 30);
    final age = currentYear - birthYear;
    final civilStatus = answers['q_civil_status'] as String? ?? 'single';
    final childrenCount = answers['q_children'] as int? ?? 0;
    final employmentStatus =
        answers['q_employment_status'] as String? ?? 'employee';
    final monthlyNetIncome =
        (answers['q_net_income_period_chf'] as num?)?.toDouble() ?? 5000.0;
    final canton = answers['q_canton'] as String? ?? 'VD';

    final suggestions = buildLifeEventSuggestions(
      age: age,
      civilStatus: civilStatus,
      childrenCount: childrenCount,
      employmentStatus: employmentStatus,
      monthlyNetIncome: monthlyNetIncome,
      canton: canton,
    );

    return LifeEventSuggestionsSection(suggestions: suggestions);
  }

}
