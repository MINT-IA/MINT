import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/circle_score.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/services/report/lpp_capital_notice_section_content.dart';
import 'package:mint_mobile/services/report/lpp_regulation_handoff_section_content.dart';
import 'package:mint_mobile/services/report/pillar3a_beneficiary_handoff_section_content.dart';

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
              'MENTORAT ÉDUCATIF — CONFIDENTIEL', // lint-ignore: legacy i18n debt predates this G1 slice
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
                  'Généré par Mint le ${report.generatedAt.toLocal().toString().split('.')[0]}', // lint-ignore: legacy i18n debt predates this G1 slice
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
              pw.Text('Indicateurs de Score'.toUpperCase(), // lint-ignore: legacy i18n debt predates this G1 slice
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
              pw.Text('Statement of Advice (Conformité)'.toUpperCase(), // lint-ignore: legacy i18n debt predates this G1 slice
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
                        'Nature du service : ${report.mintRoadmap.natureOfService}', // lint-ignore: legacy i18n debt predates this G1 slice
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
                pw.Text('Hypothèses :', // lint-ignore: legacy i18n debt predates this G1 slice
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                for (var a in report.mintRoadmap.assumptions)
                  pw.Text('• $a', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 8),
                pw.Text('Conflits d\'intérêts & Commissions :', // lint-ignore: legacy i18n debt predates this G1 slice
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
              pw.Text('Détail des Analyses'.toUpperCase(), // lint-ignore: legacy i18n debt predates this G1 slice
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
              pw.Text('Disclaimers Légaux'.toUpperCase(), // lint-ignore: legacy i18n debt predates this G1 slice
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

  static Future<Uint8List> buildFinancialReportPdfBytes(
    FinancialReport report, {
    required S l,
  }) async {
    final pdf = pw.Document();
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/LibreFranklin-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/LibreFranklin-Bold.ttf'),
    );
    final pdfTheme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
      italic: regularFont,
      boldItalic: boldFont,
      fontFallback: <pw.Font>[regularFont],
    );
    final generatedDate = report.generatedAt.toLocal().toString().split('.')[0];
    final capitalHandoff = report.lppCapitalNoticeHandoff;
    final lppCapitalContent = capitalHandoff == null
        ? null
        : LppCapitalNoticeSectionContent.fromHandoff(
            handoff: capitalHandoff,
            l: l,
            localeName: l.localeName,
            asOf: report.generatedAt,
          );
    final regulationHandoff = report.lppRegulationHandoff;
    final lppRegulationContent = regulationHandoff == null
        ? null
        : LppRegulationHandoffSectionContent.fromHandoff(
            handoff: regulationHandoff,
            l: l,
            localeName: l.localeName,
          );
    final pillar3aBeneficiaryContents =
        report.pillar3aBeneficiaryHandoff?.entries
                .map(
                  (entry) => Pillar3aBeneficiaryHandoffSectionContent.fromEntry(
                    entry: entry,
                    l: l,
                    localeName: l.localeName,
                  ),
                )
                .toList(growable: false) ??
            const <Pillar3aBeneficiaryHandoffSectionContent>[];

    pdf.addPage(
      pw.MultiPage(
        theme: pdfTheme,
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
                  'Outil éducatif — MINT — ne constitue pas un conseil financier au sens de la LSFin', // lint-ignore: legacy i18n debt predates this G1 slice
                  style:
                      const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text('Généré le $generatedDate', // lint-ignore: legacy i18n debt predates this G1 slice
                  style: const pw.TextStyle(
                      fontSize: 6, color: PdfColors.grey500)),
              pw.SizedBox(width: 10),
              pw.Text('Page ${context.pageNumber} sur ${context.pagesCount}',
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
            'Ton Plan Mint — Rapport Financier', // lint-ignore: legacy i18n debt predates this G1 slice
            style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900),
          ));
          children.add(pw.SizedBox(height: 4));
          children.add(pw.Text(
            'Bilan personnalisé pour ${report.profile.firstName ?? 'toi'} — ${report.profile.canton.toUpperCase()}', // lint-ignore: legacy i18n debt predates this G1 slice
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
              'Score de santé financière : ${report.healthScore.overallScore.toInt()}/100 — ${report.healthScore.overallLevel.label}', // lint-ignore: legacy i18n debt predates this G1 slice
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
          children.add(_pdfSectionTitle('Indicateurs Clés')); // lint-ignore: legacy i18n debt predates this G1 slice
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
              'value': formatChfWithPrefix(monthlyAvailable),
              'note': 'Après impôts estimés', // lint-ignore: legacy i18n debt predates this G1 slice
            },
            {
              'label': 'Impôts estimés / an', // lint-ignore: legacy i18n debt predates this G1 slice
              'value': formatChfWithPrefix(report.taxSimulation.totalTax),
              'note':
                  'Taux effectif : ${(report.taxSimulation.effectiveRate * 100).toStringAsFixed(1)}%',
            },
            {
              'label': 'Taux d\'épargne', // lint-ignore: legacy i18n debt predates this G1 slice
              'value': '${savingsRate.toStringAsFixed(1)}%',
              'note': 'Du revenu net mensuel', // lint-ignore: legacy i18n debt predates this G1 slice
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
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.green100,
                            borderRadius:
                                pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            '+${formatChfWithPrefix(action.potentialGainChf!)}',
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
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfKeyValue('Revenu imposable',
                    formatChfPreciseWithPrefix(tax.taxableIncome)),
                if (tax.deductions.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text('Déductions appliquées :', // lint-ignore: legacy i18n debt predates this G1 slice
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  for (final entry in tax.deductions.entries)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10),
                      child: pw.Text(
                          '- ${entry.key} : ${formatChfPreciseWithPrefix(entry.value)}',
                          style: const pw.TextStyle(fontSize: 8)),
                    ),
                  pw.Text(
                      'Total déductions : ${formatChfPreciseWithPrefix(tax.totalDeductions)}', // lint-ignore: legacy i18n debt predates this G1 slice
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800)),
                ],
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.SizedBox(height: 6),
                _pdfKeyValue('Impôt cantonal + communal', // lint-ignore: legacy i18n debt predates this G1 slice
                    formatChfPreciseWithPrefix(tax.cantonalTax)),
                _pdfKeyValue('Impôt fédéral direct', // lint-ignore: legacy i18n debt predates this G1 slice
                    formatChfPreciseWithPrefix(tax.federalTax)),
                pw.SizedBox(height: 4),
                _pdfKeyValue(
                    'TOTAL estimé', // lint-ignore: legacy i18n debt predates this G1 slice
                    formatChfPreciseWithPrefix(tax.totalTax),
                    bold: true),
                _pdfKeyValue('Taux effectif',
                    '${(tax.effectiveRate * 100).toStringAsFixed(1)}%'),
                if (tax.taxSavingsFromBuyback != null &&
                    tax.taxSavingsFromBuyback! > 0) ...[
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 0.5, color: PdfColors.green200),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Avec rachat LPP : ${formatChfPreciseWithPrefix(tax.taxWithLppBuyback!)} (économie : ${formatChfPreciseWithPrefix(tax.taxSavingsFromBuyback!)})', // lint-ignore: legacy i18n debt predates this G1 slice
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
            children
                .add(_pdfSectionTitle(l.reportPdfRetirementProjectionTitle));
            children.add(pw.SizedBox(height: 10));

            children.add(pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: PdfColors.grey200),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    l.reportPdfRetirementHorizon(
                      ret.yearsUntilRetirement,
                      ret.retirementAge,
                    ),
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(l.reportPdfRetirementMonthlyPensions,
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600)),
                  _pdfKeyValue(
                    l.futurRenteAvs,
                    l.coverageCheckAVerifier,
                  ),
                  _pdfKeyValue(
                    l.futurRenteLpp,
                    l.coverageCheckAVerifier,
                  ),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  pw.SizedBox(height: 8),
                  pw.Text(l.reportPdfRetirementCapitalsAtAge(ret.retirementAge),
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600)),
                  _pdfKeyValue(l.reportPdfRetirementLppCapital,
                      l.coverageCheckAVerifier),
                  _pdfKeyValue(l.reportPdfRetirementPillar3aCapital,
                      l.coverageCheckAVerifier),
                  if (ret.otherAssets != null && ret.otherAssets! > 0)
                    _pdfKeyValue(l.reportPdfRetirementOtherAssets,
                        formatChfWithPrefix(ret.otherAssets!)),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  _pdfKeyValue(
                    l.reportPdfRetirementTotalCapital,
                    l.coverageCheckAVerifier,
                    bold: true,
                  ),
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
            children.add(_pdfSectionTitle('Stratégie Rachat LPP')); // lint-ignore: legacy i18n debt predates this G1 slice
            children.add(pw.SizedBox(height: 10));

            children.add(pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: PdfColors.grey200),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfKeyValue('Montant rachetable total',
                      formatChfWithPrefix(lpp.totalBuybackAvailable)),
                  _pdfKeyValue('Économie fiscale totale estimée', // lint-ignore: legacy i18n debt predates this G1 slice
                      formatChfWithPrefix(lpp.totalTaxSavings),
                      bold: true),
                  pw.SizedBox(height: 8),
                  pw.Text('Plan annuel recommandé', // lint-ignore: legacy i18n debt predates this G1 slice
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
                            child: pw.Text('Année', // lint-ignore: legacy i18n debt predates this G1 slice
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
                            child: pw.Text('Économie fiscale', // lint-ignore: legacy i18n debt predates this G1 slice
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
                              child: pw.Text(formatChfWithPrefix(year.amount),
                                  style: const pw.TextStyle(fontSize: 8))),
                          pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                  formatChfWithPrefix(year.estimatedTaxSavings),
                                  style: const pw.TextStyle(
                                      fontSize: 8, color: PdfColors.green800))),
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Rappel : le rachat LPP est soumis à un blocage de 3 ans pour les retraits en capital (LPP art. 79b al. 3).', // lint-ignore: legacy i18n debt predates this G1 slice
                    style: pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.orange800,
                        fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ),
            ));
          }

          if (lppCapitalContent != null) {
            final content = lppCapitalContent;
            children.add(pw.SizedBox(height: 25));
            children.add(_pdfSectionTitle(content.title));
            children.add(pw.SizedBox(height: 10));
            children.add(pw.Text(
              content.statusBody,
              style: const pw.TextStyle(fontSize: 9),
            ));
            children.add(pw.SizedBox(height: 6));
            children.add(pw.Text(
              content.caveat,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ));
            children.add(pw.SizedBox(height: 6));
            children.add(pw.Text(
              content.boundary,
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.orange800,
                fontStyle: pw.FontStyle.italic,
              ),
            ));
            children.add(pw.SizedBox(height: 8));
            children.add(
              _pdfKeyValue(content.documentKindLabel, content.documentKindValue),
            );
            children.add(
              _pdfKeyValue(content.sourceDateLabel, content.sourceDateValue),
            );
            children.add(
              _pdfKeyValue(content.legalYearLabel, content.legalYearValue),
            );
            children.add(
              _pdfKeyValue(content.confirmedAtLabel, content.confirmedAtValue),
            );
            children.add(_pdfKeyValue(
              content.fundRelationshipLabel,
              content.fundRelationshipValue,
            ));
            children.add(
              _pdfKeyValue(content.deadlineLabel, content.deadlineValue),
            );
            children.add(pw.SizedBox(height: 12));
            children.add(pw.Text(
              content.questionsTitle,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ));
            children.add(pw.SizedBox(height: 6));
            for (final question in content.questions) {
              children.add(pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  question.body,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ));
            }
          }

          if (lppRegulationContent != null) {
            final content = lppRegulationContent;
            children.add(pw.SizedBox(height: 25));
            children.add(_pdfSectionTitle(content.title));
            children.add(pw.SizedBox(height: 10));
            children.add(pw.Text(
              content.referenceBody,
              style: const pw.TextStyle(fontSize: 9),
            ));
            children.add(pw.SizedBox(height: 8));
            children.add(
              _pdfKeyValue(content.documentKindLabel, content.documentKindValue),
            );
            children.add(
              _pdfKeyValue(content.sourceDateLabel, content.sourceDateValue),
            );
            children.add(
              _pdfKeyValue(content.legalYearLabel, content.legalYearValue),
            );
            children.add(
              _pdfKeyValue(content.confirmedAtLabel, content.confirmedAtValue),
            );
            children.add(_pdfKeyValue(
              content.fundRelationshipLabel,
              content.fundRelationshipValue,
            ));
            children.add(pw.SizedBox(height: 10));
            children.add(pw.Text(
              content.applicabilityQuestion,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ));
            children.add(pw.SizedBox(height: 12));
            children.add(pw.Text(
              content.questionsTitle,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ));
            children.add(pw.SizedBox(height: 6));
            for (final question in content.questions) {
              children.add(pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    question.title,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    question.body,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                ],
              ));
            }
            children.add(pw.Text(
              content.boundary,
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.orange800,
                fontStyle: pw.FontStyle.italic,
              ),
            ));
            children.add(pw.SizedBox(height: 4));
            children.add(pw.Text(
              content.privacy,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ));
          }

          for (final content in pillar3aBeneficiaryContents) {
            children.add(pw.SizedBox(height: 25));
            children.add(_pdfSectionTitle(content.title));
            children.add(pw.SizedBox(height: 10));
            children.add(pw.Text(
              content.statusBody,
              style: const pw.TextStyle(fontSize: 9),
            ));
            children.add(pw.SizedBox(height: 8));
            children.add(
              _pdfKeyValue(content.documentKindLabel, content.documentKindValue),
            );
            children.add(
              _pdfKeyValue(content.sourceDateLabel, content.sourceDateValue),
            );
            children.add(
              _pdfKeyValue(content.legalYearLabel, content.legalYearValue),
            );
            children.add(pw.SizedBox(height: 6));
            children.add(pw.Text(
              content.temporalBasisLabel,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ));
            for (final line in content.temporalBasisLines) {
              children.add(pw.Text(
                line,
                style: const pw.TextStyle(fontSize: 8),
              ));
            }
            children.add(pw.SizedBox(height: 6));
            children.add(pw.Text(
              content.declaredRelation,
              style: const pw.TextStyle(fontSize: 8),
            ));
            children.add(pw.SizedBox(height: 6));
            children.add(pw.Text(
              content.freshnessCaveat,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ));
            children.add(pw.SizedBox(height: 12));
            children.add(pw.Text(
              content.questionsTitle,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ));
            children.add(pw.SizedBox(height: 6));
            for (final question in content.questions) {
              children.add(pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  question,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ));
            }
            children.add(pw.Text(
              content.boundary,
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.orange800,
                fontStyle: pw.FontStyle.italic,
              ),
            ));
            children.add(pw.SizedBox(height: 6));
            children.add(pw.Text(
              content.legalFooter,
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey700,
              ),
            ));
          }

          // ═══════════════════════════════════════════════════════
          // 7. CONFORMITÉ (Statement of Advice)
          // ═══════════════════════════════════════════════════════
          children.add(pw.SizedBox(height: 25));
          children.add(_pdfSectionTitle('Conformité — Statement of Advice')); // lint-ignore: legacy i18n debt predates this G1 slice
          children.add(pw.SizedBox(height: 10));

          children.add(pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: PdfColors.blue50,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Nature du service : Éducation financière (non-régulée)', // lint-ignore: legacy i18n debt predates this G1 slice
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Hypothèses :', // lint-ignore: legacy i18n debt predates this G1 slice
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    '• Les données utilisées sont celles déclarées par l\'utilisateur·trice.', // lint-ignore: legacy i18n debt predates this G1 slice
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                    '• Les taux fiscaux sont des estimations simplifiées par canton.', // lint-ignore: legacy i18n debt predates this G1 slice
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                    '• Les projections de rendement utilisent des hypothèses prudentes (3-5%).', // lint-ignore: legacy i18n debt predates this G1 slice
                    style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 6),
                pw.Text('Conflits d\'intérêts :', // lint-ignore: legacy i18n debt predates this G1 slice
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    '• MINT ne perçoit aucune commission des fournisseurs de 3a mentionnés.', // lint-ignore: legacy i18n debt predates this G1 slice
                    style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ));

          // ═══════════════════════════════════════════════════════
          // 8. DISCLAIMERS LÉGAUX
          // ═══════════════════════════════════════════════════════
          if (report.disclaimers.isNotEmpty) {
            children.add(pw.SizedBox(height: 25));
            children.add(_pdfSectionTitle('Disclaimers Légaux')); // lint-ignore: legacy i18n debt predates this G1 slice
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

    return pdf.save();
  }

  static Future<void> generateFinancialReportPdf(
    FinancialReport report, {
    required S l,
  }) async {
    final bytes = await buildFinancialReportPdfBytes(report, l: l);
    await Printing.sharePdf(bytes: bytes, filename: 'mint_report_v2.pdf');
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
  static pw.Widget _pdfKeyValue(String key, String value, {bool bold = false}) {
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

  /// Generates a PDF decision report from coach conversation highlights.
  ///
  /// Export educatif — inclut le contexte financier de l'utilisateur,
  /// les echanges Q&A pertinents, les sources juridiques, et les disclaimers.
  static Future<void> generateDecisionReportPdf({
    required String firstName,
    required String canton,
    required int fitnessScore,
    required List<Map<String, String>> conversationHighlights,
    required List<String> legalSources,
  }) async {
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
              'RAPPORT DÉCISIONNEL — CONFIDENTIEL', // lint-ignore: legacy i18n debt predates this G1 slice
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
                  'Généré par MINT le ${DateTime.now().toLocal().toString().split('.')[0]}', // lint-ignore: legacy i18n debt predates this G1 slice
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

          // Title
          children.add(pw.Text(
            'Rapport décisionnel', // lint-ignore: legacy i18n debt predates this G1 slice
            style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900),
          ));
          children.add(pw.SizedBox(height: 8));
          children.add(pw.Text(
            'Coach MINT — Conversation éducative', // lint-ignore: legacy i18n debt predates this G1 slice
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ));
          children.add(pw.SizedBox(height: 20));

          // Profile snapshot
          children.add(pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Profil',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                    pw.SizedBox(height: 4),
                    pw.Text('$firstName — Canton $canton',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Score Fitness',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                    pw.SizedBox(height: 4),
                    pw.Text('$fitnessScore / 100',
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: fitnessScore >= 60
                                ? PdfColors.green700
                                : PdfColors.orange700)),
                  ],
                ),
              ],
            ),
          ));
          children.add(pw.SizedBox(height: 20));

          // Conversation highlights
          if (conversationHighlights.isNotEmpty) {
            children.add(pw.Text(
              'Points clés de la conversation', // lint-ignore: legacy i18n debt predates this G1 slice
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900),
            ));
            children.add(pw.SizedBox(height: 10));

            for (int i = 0; i < conversationHighlights.length; i++) {
              final highlight = conversationHighlights[i];
              children.add(pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Q${i + 1} : ',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800)),
                        pw.Expanded(
                          child: pw.Text(highlight['question'] ?? '',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(highlight['answer'] ?? '',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
              ));
            }
            children.add(pw.SizedBox(height: 10));
          }

          // Legal sources
          if (legalSources.isNotEmpty) {
            children.add(pw.Text(
              'Sources juridiques',
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900),
            ));
            children.add(pw.SizedBox(height: 8));
            for (final source in legalSources) {
              children.add(pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ', style: const pw.TextStyle(fontSize: 9)),
                    pw.Expanded(
                      child: pw.Text(source,
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey700)),
                    ),
                  ],
                ),
              ));
            }
            children.add(pw.SizedBox(height: 16));
          }

          // Disclaimer
          children.add(pw.Divider(thickness: 0.5, color: PdfColors.grey300));
          children.add(pw.SizedBox(height: 8));
          children.add(pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
            ),
            child: pw.Text(
              'Outil éducatif — ne constitue pas un conseil financier au sens de la LSFin. ' // lint-ignore: legacy i18n debt predates this G1 slice
              'Les estimations sont basées sur des hypothèses simplifiées et des données déclaratives. ' // lint-ignore: legacy i18n debt predates this G1 slice
              'Consulte un·e spécialiste certifié·e pour toute décision financière importante.', // lint-ignore: legacy i18n debt predates this G1 slice
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ));

          return children;
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
