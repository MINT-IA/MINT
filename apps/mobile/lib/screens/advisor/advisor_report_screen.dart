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

class AdvisorReportScreen extends StatefulWidget {
  final String? sessionId;
  final Map<String, dynamic>? answers;

  const AdvisorReportScreen({
    super.key,
    this.sessionId,
    this.answers,
  }) : assert(sessionId != null || answers != null,
            'Either sessionId or answers must be provided');

  @override
  State<AdvisorReportScreen> createState() => _AdvisorReportScreenState();
}

class _AdvisorReportScreenState extends State<AdvisorReportScreen> {
  late Future<SessionReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    if (widget.answers != null) {
      _reportFuture = Future.value(ReportBuilder(widget.answers!).build());
    } else {
      _reportFuture = ApiService.getSessionReport(widget.sessionId!);
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
                  'Le Conseil de votre Mentor (Top 3)',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                for (var a in report.topActions) _buildTopActionCard(a),
                const SizedBox(height: 40),
                _buildSoASection(report),
                const SizedBox(height: 40),
                _buildDetailedRecos(report),
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
        label: const Text('Export PDF Professionnel'),
        icon: const Icon(Icons.picture_as_pdf),
        backgroundColor: MintColors.primary,
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
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.history_edu,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'Généré le ${report.generatedAt.day}/${report.generatedAt.month}/${report.generatedAt.year}',
              style: const TextStyle(fontSize: 14, color: MintColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrecisionBanner(SessionReport report) {
    final bool isLow = report.precisionScore < 0.5;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLow
            ? MintColors.warning.withOpacity(0.1)
            : MintColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isLow ? MintColors.warning : MintColors.success, width: 0.5),
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
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
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
        Icon(icon, size: 20, color: MintColors.primary),
        const SizedBox(height: 4),
        Text(category,
            style: const TextStyle(
                fontSize: 10,
                color: MintColors.textMuted,
                fontWeight: FontWeight.bold)),
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildScoreboard(SessionReport report) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MintColors.border),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 2.5,
        ),
        itemCount: report.scoreboard.length,
        itemBuilder: (context, index) {
          final item = report.scoreboard[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label,
                  style: const TextStyle(
                      fontSize: 11, color: MintColors.textSecondary)),
              Text(item.value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: MintColors.textPrimary)),
              Text(item.note,
                  style: const TextStyle(
                      fontSize: 10, color: MintColors.textMuted)),
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
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action.effortTag.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: MintColors.primary)),
                const SizedBox(height: 8),
                Text(action.label,
                    style: GoogleFonts.montserrat(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(action.why,
                    style: const TextStyle(
                        fontSize: 14, color: MintColors.textSecondary)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: MintColors.background,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(action.ifThen,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(19),
                        bottomRight: Radius.circular(19))),
              ),
              child: Text(action.nextAction.label),
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

  Widget _buildDisclaimers(SessionReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MENTIONS LÉGALES',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: MintColors.textMuted,
                letterSpacing: 1.2)),
        const SizedBox(height: 16),
        ...report.disclaimers.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(color: MintColors.textMuted)),
                  Expanded(
                      child: Text(d,
                          style: const TextStyle(
                              fontSize: 12,
                              color: MintColors.textMuted,
                              height: 1.4))),
                ],
              ),
            )),
      ],
    );
  }
}
