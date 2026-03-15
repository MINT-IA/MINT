import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/models/circle_score.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

class PdfService {
  static Future<void> generateSessionReportPdf(SessionReport report, {required S s}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(s.pdfServiceHeaderTitle,
                style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold)),
            pw.Text(
              s.pdfServiceSessionHeaderRight,
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
                  s.pdfServiceGeneratedBy(report.generatedAt.toLocal().toString().split('.')[0]),
                  style: const pw.TextStyle(
                      fontSize: 7, color: PdfColors.grey500)),
              pw.Text(s.pdfServicePageOf('${context.pageNumber}', '${context.pagesCount}'),
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
                    s.pdfServicePrecision('${(report.precisionScore * 100).toInt()}'),
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
                    pw.Text(s.pdfServiceCanton,
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
                    pw.Text(s.pdfServiceFoyer,
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
                    pw.Text(s.pdfServiceObjectif,
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
              pw.Text(s.pdfServiceScoreIndicators.toUpperCase(),
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
              pw.Text(s.pdfServiceActionPlanTop3.toUpperCase(),
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
                  pw.Text(s.pdfServiceWhyPrefix(a.why),
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 4),
                  pw.Text(s.pdfServiceNextAction(a.nextAction.label),
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
              pw.Text(s.pdfServiceStatementOfAdvice.toUpperCase(),
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
                        s.pdfServiceNatureOfService(report.mintRoadmap.natureOfService),
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
                pw.Text(s.pdfServiceHypotheses,
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                for (var a in report.mintRoadmap.assumptions)
                  pw.Text('\u2022 $a', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 8),
                pw.Text(s.pdfServiceConflictsAndCommissions,
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                for (var c in report.mintRoadmap.conflicts)
                  pw.Text('\u2022 ${s.pdfServiceConflictLine(c.partner, c.disclosure)}',
                      style: pw.TextStyle(
                          fontSize: 8, fontStyle: pw.FontStyle.italic)),
              ],
            ),
          ));

          children.add(pw.SizedBox(height: 40));

          children.add(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(s.pdfServiceDetailAnalyses.toUpperCase(),
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
                        s.pdfServiceSourcesLabel(r.evidenceLinks.map((l) => l.label).join(', ')),
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
              pw.Text(s.pdfServiceDisclaimersLegaux.toUpperCase(),
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
                  pw.Text('\u2022 ',
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

  static Future<void> generateFinancialReportPdf(FinancialReport report, {required S s}) async {
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
            pw.Text(s.pdfServiceHeaderTitle,
                style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold)),
            pw.Text(
              s.pdfServiceFinancialHeaderRight,
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
                  s.pdfServiceFooterDisclaimer,
                  style: const pw.TextStyle(
                      fontSize: 6, color: PdfColors.grey500),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(s.pdfServiceGeneratedOn(generatedDate),
                  style: const pw.TextStyle(
                      fontSize: 6, color: PdfColors.grey500)),
              pw.SizedBox(width: 10),
              pw.Text(
                  s.pdfServicePageOf('${context.pageNumber}', '${context.pagesCount}'),
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
            s.pdfServiceMainTitle,
            style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900),
          ));
          children.add(pw.SizedBox(height: 4));
          children.add(pw.Text(
            s.pdfServiceSubtitle(
                report.profile.firstName ?? s.pdfServiceSubtitleFallback,
                report.profile.canton.toUpperCase()),
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
              s.pdfServiceHealthScore(
                  '${report.healthScore.overallScore.toInt()}',
                  report.healthScore.overallLevel.label),
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
          children.add(_pdfSectionTitle(s.pdfServiceKeyIndicators));
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
              'label': s.pdfServiceAvailablePerMonth,
              'value':
                  'CHF ${monthlyAvailable.toStringAsFixed(0)}',
              'note': s.pdfServiceAfterEstimatedTaxes,
            },
            {
              'label': s.pdfServiceEstimatedTaxPerYear,
              'value':
                  'CHF ${report.taxSimulation.totalTax.toStringAsFixed(0)}',
              'note':
                  s.pdfServiceEffectiveRate((report.taxSimulation.effectiveRate * 100).toStringAsFixed(1)),
            },
            {
              'label': s.pdfServiceSavingsRate,
              'value': '${savingsRate.toStringAsFixed(1)}%',
              'note': s.pdfServiceOfNetMonthlyIncome,
            },
            {
              'label': s.pdfServiceProtectionScore,
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
          children.add(_pdfSectionTitle(s.pdfServiceTop3PriorityActions));
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
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.green100,
                            borderRadius: pw.BorderRadius.all(
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
                  pw.Text(s.pdfServiceWhyPrefix(action.description),
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
          children.add(_pdfSectionTitle(s.pdfServiceTaxSimulation));
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
                _pdfKeyValue(s.pdfServiceTaxableIncome,
                    'CHF ${tax.taxableIncome.toStringAsFixed(0)}'),
                if (tax.deductions.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(s.pdfServiceAppliedDeductions,
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  for (final entry in tax.deductions.entries)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10),
                      child: pw.Text(
                          s.pdfServiceDeductionLine(entry.key, entry.value.toStringAsFixed(0)),
                          style: const pw.TextStyle(fontSize: 8)),
                    ),
                  pw.Text(
                      s.pdfServiceTotalDeductions(tax.totalDeductions.toStringAsFixed(0)),
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800)),
                ],
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.SizedBox(height: 6),
                _pdfKeyValue(s.pdfServiceCantonalCommunalTax,
                    'CHF ${tax.cantonalTax.toStringAsFixed(0)}'),
                _pdfKeyValue(s.pdfServiceFederalDirectTax,
                    'CHF ${tax.federalTax.toStringAsFixed(0)}'),
                pw.SizedBox(height: 4),
                _pdfKeyValue(
                    s.pdfServiceTotalEstimated,
                    'CHF ${tax.totalTax.toStringAsFixed(0)}',
                    bold: true),
                _pdfKeyValue(s.pdfServiceEffectiveRateLabel,
                    '${(tax.effectiveRate * 100).toStringAsFixed(1)}%'),
                if (tax.taxSavingsFromBuyback != null &&
                    tax.taxSavingsFromBuyback! > 0) ...[
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 0.5, color: PdfColors.green200),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    s.pdfServiceWithLppBuyback(
                        tax.taxWithLppBuyback!.toStringAsFixed(0),
                        tax.taxSavingsFromBuyback!.toStringAsFixed(0)),
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
            children.add(_pdfSectionTitle(s.pdfServiceRetirementProjection));
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
                    s.pdfServiceHorizon('${ret.yearsUntilRetirement}', '${ret.retirementAge}'),
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(s.pdfServiceEstimatedMonthlyPensions,
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600)),
                  _pdfKeyValue(s.pdfServiceAvsRent,
                      'CHF ${ret.monthlyAvsRent.toStringAsFixed(0)}/mois'),
                  _pdfKeyValue(s.pdfServiceLppRent,
                      'CHF ${ret.monthlyLppRent.toStringAsFixed(0)}/mois'),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  _pdfKeyValue(
                    s.pdfServiceTotalMonthly,
                    'CHF ${ret.totalMonthlyIncome.toStringAsFixed(0)}/mois',
                    bold: true,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(s.pdfServiceEstimatedCapitalAt65,
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600)),
                  _pdfKeyValue(s.pdfServiceLppCapital,
                      'CHF ${ret.lppCapital.toStringAsFixed(0)}'),
                  _pdfKeyValue(s.pdfServicePillar3aCapital,
                      'CHF ${ret.pillar3aCapital.toStringAsFixed(0)}'),
                  if (ret.otherAssets != null && ret.otherAssets! > 0)
                    _pdfKeyValue(s.pdfServiceOtherAssets,
                        'CHF ${ret.otherAssets!.toStringAsFixed(0)}'),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  _pdfKeyValue(
                    s.pdfServiceTotalEstimatedCapital,
                    'CHF ${ret.totalCapital.toStringAsFixed(0)}',
                    bold: true,
                  ),
                  if (ret.avsReductionFactor < 1.0) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      s.pdfServiceAvsReductionWarning((ret.avsReductionFactor * 100).toStringAsFixed(1)),
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
            children.add(_pdfSectionTitle(s.pdfServiceLppBuybackStrategy));
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
                  _pdfKeyValue(s.pdfServiceTotalBuybackAvailable,
                      'CHF ${lpp.totalBuybackAvailable.toStringAsFixed(0)}'),
                  _pdfKeyValue(s.pdfServiceTotalTaxSavingsEstimated,
                      'CHF ${lpp.totalTaxSavings.toStringAsFixed(0)}',
                      bold: true),
                  pw.SizedBox(height: 8),
                  pw.Text(s.pdfServiceRecommendedAnnualPlan,
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
                            child: pw.Text(s.pdfServiceYear,
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(
                            flex: 3,
                            child: pw.Text(s.pdfServiceBuyback,
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(
                            flex: 3,
                            child: pw.Text(s.pdfServiceTaxSaving,
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
                                  style: const pw.TextStyle(
                                      fontSize: 8,
                                      color: PdfColors.green800))),
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    s.pdfServiceLppBuybackReminder,
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
          children.add(_pdfSectionTitle(s.pdfServiceComplianceTitle));
          children.add(pw.SizedBox(height: 10));

          children.add(pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: PdfColors.blue50,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(s.pdfServiceComplianceNature,
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text(s.pdfServiceComplianceHypotheses,
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    '\u2022 ${s.pdfServiceComplianceHyp1}',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                    '\u2022 ${s.pdfServiceComplianceHyp2}',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                    '\u2022 ${s.pdfServiceComplianceHyp3}',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                    '\u2022 ${s.pdfServiceComplianceHyp4}',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 6),
                pw.Text(s.pdfServiceComplianceConflicts,
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    '\u2022 ${s.pdfServiceComplianceConflict1}',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text(
                    '\u2022 ${s.pdfServiceComplianceConflict2}',
                    style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ));

          // ═══════════════════════════════════════════════════════
          // 8. DISCLAIMERS LÉGAUX
          // ═══════════════════════════════════════════════════════
          if (report.disclaimers.isNotEmpty) {
            children.add(pw.SizedBox(height: 25));
            children.add(_pdfSectionTitle(s.pdfServiceDisclaimersLegaux));
            children.add(pw.SizedBox(height: 8));

            for (final d in report.disclaimers) {
              children.add(pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('\u2022 ',
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
            children.add(_pdfSectionTitle(s.pdfServiceLegalSources));
            children.add(pw.SizedBox(height: 8));

            for (final src in report.sources) {
              children.add(pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('\u2022 ',
                        style: pw.TextStyle(
                            color: PdfColors.grey600,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Expanded(
                        child: pw.Text(src,
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
    required S s,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(s.pdfServiceHeaderTitle,
                style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold)),
            pw.Text(
              s.pdfServiceDecisionHeaderRight,
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
                  s.pdfServiceGeneratedByMint(DateTime.now().toLocal().toString().split('.')[0]),
                  style: const pw.TextStyle(
                      fontSize: 7, color: PdfColors.grey500)),
              pw.Text(s.pdfServicePageOf('${context.pageNumber}', '${context.pagesCount}'),
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
            s.pdfServiceDecisionReportTitle,
            style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900),
          ));
          children.add(pw.SizedBox(height: 8));
          children.add(pw.Text(
            s.pdfServiceDecisionReportSubtitle,
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
                    pw.Text(s.pdfServiceProfile,
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                    pw.SizedBox(height: 4),
                    pw.Text(s.pdfServiceProfileLine(firstName, canton),
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(s.pdfServiceFitnessScore,
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                    pw.SizedBox(height: 4),
                    pw.Text(s.pdfServiceFitnessScoreValue('$fitnessScore'),
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
              s.pdfServiceConversationHighlights,
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
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
              ));
            }
            children.add(pw.SizedBox(height: 10));
          }

          // Legal sources
          if (legalSources.isNotEmpty) {
            children.add(pw.Text(
              s.pdfServiceLegalSourcesTitle,
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
                    pw.Text('\u2022 ', style: const pw.TextStyle(fontSize: 9)),
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
              s.pdfServiceFullDisclaimer,
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
