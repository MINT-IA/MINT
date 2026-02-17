import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/models/circle_score.dart';

class PdfService {
  static Future<void> generateSessionReportPdf(SessionReport report) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('MINT — MENTORAT FINANCIER',
                style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold)),
            pw.Text(
              'RECOMMANDATION PROFESSIONNELLE - CONFIDENTIEL',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        footer: (pw.Context context) => pw.Column(children: [
          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                  'Généré par Mint le ${report.generatedAt.toLocal().toString().split('.')[0]}',
                  style: const pw.TextStyle(
                      fontSize: 7, color: PdfColors.grey500)),
              pw.Text('Page ${context.pageNumber} sur ${context.pagesCount}',
                  style: const pw.TextStyle(
                      fontSize: 7, color: PdfColors.grey500)),
            ],
          ),
        ]),
        build: (pw.Context context) {
          final List<pw.Widget> children = [];

          children.add(pw.SizedBox(height: 20));

          children.add(pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(report.title,
                  style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900)),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: report.precisionScore < 0.5
                      ? PdfColors.orange100
                      : PdfColors.green100,
                  border: pw.Border.all(
                      color: report.precisionScore < 0.5
                          ? PdfColors.orange
                          : PdfColors.green,
                      width: 0.5),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                    'PRECISION: ${(report.precisionScore * 100).toInt()}%',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: report.precisionScore < 0.5
                            ? PdfColors.orange900
                            : PdfColors.green900)),
              ),
            ],
          ));

          children.add(pw.SizedBox(height: 12));

          children.add(pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: PdfColors.grey100,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CANTON',
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600)),
                    pw.Text(report.overview.canton.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FOYER',
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600)),
                    pw.Text(report.overview.householdType.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('OBJECTIF',
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600)),
                    pw.Text(report.overview.goalRecommendedLabel.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ));

          children.add(pw.SizedBox(height: 30));

          children.add(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Indicateurs de Score'.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1,
                      color: PdfColors.blue800)),
              pw.Divider(thickness: 1, color: PdfColors.blue800),
            ],
          ));

          children.add(pw.SizedBox(height: 12));

          final List<pw.Widget> scoreboxes = [];
          for (var item in report.scoreboard) {
            scoreboxes.add(pw.Container(
              width: 140,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(item.label,
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600)),
                  pw.SizedBox(height: 2),
                  pw.Text(item.value,
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(item.note,
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
            ));
          }
          children.add(pw.Wrap(
            spacing: 15,
            runSpacing: 15,
            children: scoreboxes,
          ));

          children.add(pw.SizedBox(height: 40));

          children.add(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Plan d\'Action Mentor (Top 3)'.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1,
                      color: PdfColors.blue800)),
              pw.Divider(thickness: 1, color: PdfColors.blue800),
            ],
          ));

          children.add(pw.SizedBox(height: 12));

          for (var a in report.topActions) {
            children.add(pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(a.label,
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900)),
                  pw.SizedBox(height: 4),
                  pw.Text('Pourquoi : ${a.why}',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 4),
                  pw.Text('Action suivante : ${a.nextAction.label}',
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ));
          }

          children.add(pw.SizedBox(height: 40));

          children.add(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Statement of Advice (Conformité)'.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1,
                      color: PdfColors.blue800)),
              pw.Divider(thickness: 1, color: PdfColors.blue800),
            ],
          ));

          children.add(pw.SizedBox(height: 12));

          children.add(pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: PdfColors.blue50,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        'Nature du service : ${report.mintRoadmap.natureOfService}',
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text(report.mintRoadmap.mentorshipLevel,
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text('Hypothèses :',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                for (var a in report.mintRoadmap.assumptions)
                  pw.Text('• $a', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 8),
                pw.Text('Conflits d\'intérêts & Commissions :',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                for (var c in report.mintRoadmap.conflicts)
                  pw.Text('• ${c.partner} : ${c.disclosure}',
                      style: pw.TextStyle(
                          fontSize: 8, fontStyle: pw.FontStyle.italic)),
              ],
            ),
          ));

          children.add(pw.SizedBox(height: 40));

          children.add(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Détail des Analyses'.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1,
                      color: PdfColors.blue800)),
              pw.Divider(thickness: 1, color: PdfColors.blue800),
            ],
          ));

          children.add(pw.SizedBox(height: 12));

          for (var r in report.recommendations) {
            children.add(pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 15),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(r.title,
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text(r.summary, style: const pw.TextStyle(fontSize: 9)),
                  if (r.evidenceLinks.isNotEmpty) pw.SizedBox(height: 4),
                  if (r.evidenceLinks.isNotEmpty)
                    pw.Text(
                        'Sources : ${r.evidenceLinks.map((l) => l.label).join(', ')}',
                        style: pw.TextStyle(
                            fontSize: 7,
                            color: PdfColors.grey700,
                            fontStyle: pw.FontStyle.italic)),
                ],
              ),
            ));
          }

          children.add(pw.SizedBox(height: 30));

          children.add(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Disclaimers Légaux'.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1,
                      color: PdfColors.blue800)),
              pw.Divider(thickness: 1, color: PdfColors.blue800),
            ],
          ));

          children.add(pw.SizedBox(height: 10));

          for (var d in report.disclaimers) {
            children.add(pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ',
                      style: pw.TextStyle(
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Expanded(
                      child: pw.Text(d,
                          style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                              lineSpacing: 1.2))),
                ],
              ),
            ));
          }

          return children;
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateFinancialReportPdf(FinancialReport report) async {
    final pdf = pw.Document();
    final generatedDate = report.generatedAt.toLocal().toString().split('.')[0];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        // ── Header ──
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('MINT — MENTORAT FINANCIER',
                style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold)),
            pw.Text(
              'RAPPORT FINANCIER — CONFIDENTIEL',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        // ── Footer ──
        footer: (pw.Context context) => pw.Column(children: [
          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Outil éducatif — MINT — ne constitue pas un conseil financier au sens de la LSFin',
                  style: const pw.TextStyle(
                      fontSize: 6, color: PdfColors.grey500),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text('Généré le $generatedDate',
                  style: const pw.TextStyle(
                      fontSize: 6, color: PdfColors.grey500)),
              pw.SizedBox(width: 10),
              pw.Text(
                  'Page ${context.pageNumber} sur ${context.pagesCount}',
                  style: const pw.TextStyle(
                      fontSize: 6, color: PdfColors.grey500)),
            ],
          ),
        ]),
        // ── Body ──
        build: (pw.Context context) {
          final List<pw.Widget> children = [];

          // ═══════════════════════════════════════════════════════
          // 1. TITRE PRINCIPAL
          // ═══════════════════════════════════════════════════════
          children.add(pw.SizedBox(height: 10));
          children.add(pw.Text(
            'Ton Plan Mint — Rapport Financier',
            style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900),
          ));
          children.add(pw.SizedBox(height: 4));
          children.add(pw.Text(
            'Bilan personnalisé pour ${report.profile.firstName ?? 'toi'} — ${report.profile.canton.toUpperCase()}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ));
          children.add(pw.SizedBox(height: 4));
          children.add(pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green200, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              'Score de santé financière : ${report.healthScore.overallScore.toInt()}/100 — ${report.healthScore.overallLevel.label}',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900),
            ),
          ));

          // ═══════════════════════════════════════════════════════
          // 2. SCOREBOARD (4 KPI)
          // ═══════════════════════════════════════════════════════
          children.add(pw.SizedBox(height: 25));
          children.add(_pdfSectionTitle('Indicateurs Clés'));
          children.add(pw.SizedBox(height: 10));

          final monthlyAvailable = report.profile.monthlyNetIncome -
              (report.taxSimulation.totalTax / 12);
          final savingsRate = report.profile.monthlyNetIncome > 0
              ? ((report.profile.monthlyNetIncome - monthlyAvailable) /
                      report.profile.monthlyNetIncome *
                      100)
                  .clamp(0, 100)
              : 0.0;

          final kpis = <Map<String, String>>[
            {
              'label': 'Disponible / mois',
              'value':
                  'CHF ${monthlyAvailable.toStringAsFixed(0)}',
              'note': 'Après impôts estimés',
            },
            {
              'label': 'Impôts estimés / an',
              'value':
                  'CHF ${report.taxSimulation.totalTax.toStringAsFixed(0)}',
              'note':
                  'Taux effectif : ${(report.taxSimulation.effectiveRate * 100).toStringAsFixed(1)}%',
            },
            {
              'label': 'Taux d\'épargne',
              'value': '${savingsRate.toStringAsFixed(1)}%',
              'note': 'Du revenu net mensuel',
            },
            {
              'label': 'Score protection',
              'value':
                  '${report.healthScore.circle1Protection.percentage.toInt()}%',
              'note': report.healthScore.circle1Protection.level.label,
            },
          ];

          final kpiWidgets = <pw.Widget>[];
          for (final kpi in kpis) {
            kpiWidgets.add(pw.Container(
              width: 115,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(kpi['label']!,
                      style: const pw.TextStyle(
                          fontSize: 7, color: PdfColors.grey600)),
                  pw.SizedBox(height: 2),
                  pw.Text(kpi['value']!,
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text(kpi['note']!,
                      style: const pw.TextStyle(
                          fontSize: 7, color: PdfColors.grey700)),
                ],
              ),
            ));
          }
          children.add(pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: kpiWidgets,
          ));

          // ═══════════════════════════════════════════════════════
          // 3. TOP 3 ACTIONS PRIORITAIRES
          // ═══════════════════════════════════════════════════════
          children.add(pw.SizedBox(height: 30));
          children.add(_pdfSectionTitle('Top 3 — Actions Prioritaires'));
          children.add(pw.SizedBox(height: 10));

          for (int i = 0; i < report.priorityActions.length; i++) {
            final action = report.priorityActions[i];
            children.add(pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: action.priority == ActionPriority.critical
                    ? PdfColors.red50
                    : PdfColors.blue50,
                border: pw.Border.all(
                    color: action.priority == ActionPriority.critical
                        ? PdfColors.red200
                        : PdfColors.blue200,
                    width: 0.5),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text('${i + 1}. ${action.title}',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900)),
                      ),
                      if (action.potentialGainChf != null &&
                          action.potentialGainChf! > 0)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.green100,
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            '+CHF ${action.potentialGainChf!.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green900),
                          ),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Pourquoi : ${action.description}',
                      style: const pw.TextStyle(fontSize: 9)),
                  if (action.steps.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    for (final step in action.steps)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 8, bottom: 1),
                        child: pw.Text(step,
                            style: const pw.TextStyle(
                                fontSize: 8, color: PdfColors.grey700)),
                      ),
                  ],
                ],
              ),
            ));
          }

          // ═══════════════════════════════════════════════════════
          // 4. SIMULATION FISCALE
          // ═══════════════════════════════════════════════════════
          children.add(pw.SizedBox(height: 25));
          children.add(_pdfSectionTitle('Simulation Fiscale'));
          children.add(pw.SizedBox(height: 10));

          final tax = report.taxSimulation;
          children.add(pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              border: pw.Border.all(color: PdfColors.grey200),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfKeyValue('Revenu imposable',
                    'CHF ${tax.taxableIncome.toStringAsFixed(0)}'),
                if (tax.deductions.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text('Déductions appliquées :',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  for (final entry in tax.deductions.entries)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10),
                      child: pw.Text(
                          '- ${entry.key} : CHF ${entry.value.toStringAsFixed(0)}',
                          style: const pw.TextStyle(fontSize: 8)),
                    ),
                  pw.Text(
                      'Total déductions : CHF ${tax.totalDeductions.toStringAsFixed(0)}',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800)),
                ],
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.SizedBox(height: 6),
                _pdfKeyValue('Impôt cantonal + communal',
                    'CHF ${tax.cantonalTax.toStringAsFixed(0)}'),
                _pdfKeyValue('Impôt fédéral direct',
                    'CHF ${tax.federalTax.toStringAsFixed(0)}'),
                pw.SizedBox(height: 4),
                _pdfKeyValue(
                    'TOTAL estimé',
                    'CHF ${tax.totalTax.toStringAsFixed(0)}',
                    bold: true),
                _pdfKeyValue('Taux effectif',
                    '${(tax.effectiveRate * 100).toStringAsFixed(1)}%'),
                if (tax.taxSavingsFromBuyback != null &&
                    tax.taxSavingsFromBuyback! > 0) ...[
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 0.5, color: PdfColors.green200),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Avec rachat LPP : CHF ${tax.taxWithLppBuyback!.toStringAsFixed(0)} (économie : CHF ${tax.taxSavingsFromBuyback!.toStringAsFixed(0)})',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800),
                  ),
                ],
              ],
            ),
          ));

          // ═══════════════════════════════════════════════════════
          // 5. PROJECTION RETRAITE
          // ═══════════════════════════════════════════════════════
          if (report.retirementProjection != null) {
            final ret = report.retirementProjection!;
            children.add(pw.SizedBox(height: 25));
            children.add(_pdfSectionTitle('Projection Retraite'));
            children.add(pw.SizedBox(height: 10));

            children.add(pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: PdfColors.grey200),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Horizon : ${ret.yearsUntilRetirement} ans (retraite à ${ret.retirementAge} ans)',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Rentes mensuelles estimées',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600)),
                  _pdfKeyValue('Rente AVS',
                      'CHF ${ret.monthlyAvsRent.toStringAsFixed(0)}/mois'),
                  _pdfKeyValue('Rente LPP',
                      'CHF ${ret.monthlyLppRent.toStringAsFixed(0)}/mois'),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  _pdfKeyValue(
                    'Total mensuel',
                    'CHF ${ret.totalMonthlyIncome.toStringAsFixed(0)}/mois',
                    bold: true,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Capitaux estimés à 65 ans',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600)),
                  _pdfKeyValue('Capital LPP',
                      'CHF ${ret.lppCapital.toStringAsFixed(0)}'),
                  _pdfKeyValue('Capital 3a',
                      'CHF ${ret.pillar3aCapital.toStringAsFixed(0)}'),
                  if (ret.otherAssets != null && ret.otherAssets! > 0)
                    _pdfKeyValue('Autres actifs',
                        'CHF ${ret.otherAssets!.toStringAsFixed(0)}'),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  _pdfKeyValue(
                    'Capital total estimé',
                    'CHF ${ret.totalCapital.toStringAsFixed(0)}',
                    bold: true,
                  ),
                  if (ret.avsReductionFactor < 1.0) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Attention : facteur de réduction AVS ${(ret.avsReductionFactor * 100).toStringAsFixed(1)}% (lacunes de cotisation détectées)',
                      style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.orange800,
                          fontStyle: pw.FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ));
          }

          // ═══════════════════════════════════════════════════════
          // 6. STRATÉGIE RACHAT LPP
          // ═══════════════════════════════════════════════════════
          if (report.lppBuybackStrategy != null) {
            final lpp = report.lppBuybackStrategy!;
            children.add(pw.SizedBox(height: 25));
            children.add(_pdfSectionTitle('Stratégie Rachat LPP'));
            children.add(pw.SizedBox(height: 10));

            children.add(pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: PdfColors.grey200),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfKeyValue('Montant rachetable total',
                      'CHF ${lpp.totalBuybackAvailable.toStringAsFixed(0)}'),
                  _pdfKeyValue('Économie fiscale totale estimée',
                      'CHF ${lpp.totalTaxSavings.toStringAsFixed(0)}',
                      bold: true),
                  pw.SizedBox(height: 8),
                  pw.Text('Plan annuel recommandé',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600)),
                  pw.SizedBox(height: 4),
                  // Table header
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 4, horizontal: 6),
                    color: PdfColors.blue100,
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                            flex: 2,
                            child: pw.Text('Année',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(
                            flex: 3,
                            child: pw.Text('Rachat',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(
                            flex: 3,
                            child: pw.Text('Économie fiscale',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                  ),
                  for (final year in lpp.yearlyPlan)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 3, horizontal: 6),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                            bottom: pw.BorderSide(
                                color: PdfColors.grey200, width: 0.5)),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                              flex: 2,
                              child: pw.Text('${year.year}',
                                  style: const pw.TextStyle(fontSize: 8))),
                          pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                  'CHF ${year.amount.toStringAsFixed(0)}',
                                  style: const pw.TextStyle(fontSize: 8))),
                          pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                  'CHF ${year.estimatedTaxSavings.toStringAsFixed(0)}',
                                  style: pw.TextStyle(
                                      fontSize: 8,
                                      color: PdfColors.green800))),
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Rappel : le rachat LPP est soumis à un blocage de 3 ans pour les retraits en capital (LPP art. 79b al. 3).',
                    style: pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.orange800,
                        fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ),
            ));
          }

          // ═══════════════════════════════════════════════════════
          // 7. CONFORMITÉ (Statement of Advice)
          // ═══════════════════════════════════════════════════════
          children.add(pw.SizedBox(height: 25));
          children.add(_pdfSectionTitle('Conformité — Statement of Advice'));
          children.add(pw.SizedBox(height: 10));

          children.add(pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: PdfColors.blue50,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Nature du service : Éducation financière (non-régulée)',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Hypothèses :',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    '• Les données utilisées sont celles déclarées par l\'utilisateur·trice.',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                    '• Les taux fiscaux sont des estimations simplifiées par canton.',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                    '• Les projections de rendement utilisent des hypothèses prudentes (3-5%).',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                    '• Le taux de conversion LPP utilisé est de 6% (hypothèse prudente vs 6.8% légal).',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 6),
                pw.Text('Conflits d\'intérêts :',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    '• MINT ne perçoit aucune commission des fournisseurs de 3a mentionnés.',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                    '• Les comparaisons de fournisseurs sont basées sur des données publiques de frais et rendements.',
                    style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ));

          // ═══════════════════════════════════════════════════════
          // 8. DISCLAIMERS LÉGAUX
          // ═══════════════════════════════════════════════════════
          if (report.disclaimers.isNotEmpty) {
            children.add(pw.SizedBox(height: 25));
            children.add(_pdfSectionTitle('Disclaimers Légaux'));
            children.add(pw.SizedBox(height: 8));

            for (final d in report.disclaimers) {
              children.add(pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ',
                        style: pw.TextStyle(
                            color: PdfColors.grey700,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Expanded(
                        child: pw.Text(d,
                            style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700,
                                lineSpacing: 1.2))),
                  ],
                ),
              ));
            }
          }

          // ═══════════════════════════════════════════════════════
          // 9. SOURCES JURIDIQUES
          // ═══════════════════════════════════════════════════════
          if (report.sources.isNotEmpty) {
            children.add(pw.SizedBox(height: 20));
            children.add(_pdfSectionTitle('Sources Juridiques'));
            children.add(pw.SizedBox(height: 8));

            for (final s in report.sources) {
              children.add(pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ',
                        style: pw.TextStyle(
                            color: PdfColors.grey600,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Expanded(
                        child: pw.Text(s,
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey600,
                                fontStyle: pw.FontStyle.italic))),
                  ],
                ),
              ));
            }
          }

          return children;
        },
      ),
    );

    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'mint_report_v2.pdf');
  }

  // ===== PDF V2 HELPERS =====

  /// Titre de section stylé pour le PDF V2
  static pw.Widget _pdfSectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title.toUpperCase(),
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1,
                color: PdfColors.blue800)),
        pw.Divider(thickness: 1, color: PdfColors.blue800),
      ],
    );
  }

  /// Ligne clé-valeur pour le PDF V2
  static pw.Widget _pdfKeyValue(String key, String value,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(key,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}
