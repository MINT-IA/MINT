import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/models/circle_score.dart';
import 'package:mint_mobile/services/dossier/dossier_payload_service.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

class FinancialReportPdfAuditManifest {
  final String title;
  final String educationalDisclaimer;
  final List<String> sections;
  final int actionCount;
  final int disclaimerCount;
  final int sourceCount;

  const FinancialReportPdfAuditManifest({
    required this.title,
    required this.educationalDisclaimer,
    required this.sections,
    required this.actionCount,
    required this.disclaimerCount,
    required this.sourceCount,
  });
}

class DossierPayloadPdfAuditManifest {
  final String caseId;
  final String pdfSectionId;
  final String title;
  final String educationalDisclaimer;
  final List<String> sections;
  final int inputCount;
  final int outputCount;
  final int assumptionCount;
  final int warningCount;
  final int nextQuestionCount;

  const DossierPayloadPdfAuditManifest({
    required this.caseId,
    required this.pdfSectionId,
    required this.title,
    required this.educationalDisclaimer,
    required this.sections,
    required this.inputCount,
    required this.outputCount,
    required this.assumptionCount,
    required this.warningCount,
    required this.nextQuestionCount,
  });
}

class PdfService {
  static const _financialReportPdfTitle = 'Ton Plan Mint — Rapport Financier';
  static const _financialReportEducationalDisclaimer =
      'Outil éducatif — MINT — ne constitue pas un conseil financier au sens de la LSFin';
  static const _dossierPayloadEducationalDisclaimer =
      'Dossier éducatif MINT — ne constitue pas un conseil financier, fiscal, successoral ou hypothécaire au sens de la LSFin';
  static pw.ThemeData? _cachedPdfTheme;

  static Future<pw.ThemeData> _loadPdfTheme() async {
    final cached = _cachedPdfTheme;
    if (cached != null) return cached;

    final regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Lato-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Lato-Bold.ttf'));
    final italic =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Lato-Italic.ttf'));
    final boldItalic =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Lato-BoldItalic.ttf'));

    return _cachedPdfTheme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
      fontFallback: [regular],
    );
  }

  static Future<void> generateSessionReportPdf(SessionReport report) async {
    final pdf = pw.Document(theme: await _loadPdfTheme());

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
              'MENTORAT ÉDUCATIF — CONFIDENTIEL',
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
              pw.Text('Pistes éducatives à examiner (Top 3)'.toUpperCase(),
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
              pw.Text('Cadre éducatif et limites'.toUpperCase(),
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

  static FinancialReportPdfAuditManifest buildFinancialReportPdfAuditManifest(
      FinancialReport report) {
    return FinancialReportPdfAuditManifest(
      title: _financialReportPdfTitle,
      educationalDisclaimer: _financialReportEducationalDisclaimer,
      sections: [
        'Indicateurs Clés',
        'Top 3 — Pistes à examiner',
        'Simulation Fiscale',
        if (report.retirementProjection != null) 'Projection Retraite',
        if (report.lppBuybackStrategy != null) 'Stratégie Rachat LPP',
        'Cadre éducatif et limites',
        if (report.disclaimers.isNotEmpty) 'Disclaimers Légaux',
        if (report.sources.isNotEmpty) 'Sources Juridiques',
      ],
      actionCount: report.priorityActions.length,
      disclaimerCount: report.disclaimers.length,
      sourceCount: report.sources.length,
    );
  }

  static DossierPayloadPdfAuditManifest buildDossierPayloadPdfAuditManifest(
    DossierPayload dossier,
  ) {
    return DossierPayloadPdfAuditManifest(
      caseId: dossier.caseId,
      pdfSectionId: dossier.pdfSectionId,
      title: _dossierPayloadTitle(dossier),
      educationalDisclaimer: _dossierPayloadEducationalDisclaimer,
      sections: [
        'Variables de dossier',
        'Résultats éducatifs',
        'Hypothèses de scénario',
        'Données à confirmer',
        'Questions spécialiste',
        if (dossier.nextQuestions.isNotEmpty) 'Données encore utiles',
      ],
      inputCount: dossier.inputs.length,
      outputCount: dossier.outputs.length,
      assumptionCount: dossier.assumptions.length,
      warningCount: dossier.warnings.length,
      nextQuestionCount: dossier.nextQuestions.length,
    );
  }

  static Future<Uint8List> buildDossierPayloadPdfBytes(
    DossierPayload dossier, {
    bool compress = true,
  }) async {
    final pdf = pw.Document(
      theme: await _loadPdfTheme(),
      compress: compress,
      title: _dossierPayloadTitle(dossier),
      author: 'MINT',
      creator: 'MINT',
      subject: 'Dossier éducatif MINT',
    );
    final generatedDate =
        dossier.generatedAt.toLocal().toString().split('.')[0];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'MINT — DOSSIER DE LUCIDITÉ',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              dossier.pdfSectionId.toUpperCase(),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    _dossierPayloadEducationalDisclaimer,
                    style: const pw.TextStyle(
                      fontSize: 6,
                      color: PdfColors.grey500,
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Text(
                  'Page ${context.pageNumber} sur ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 6,
                    color: PdfColors.grey500,
                  ),
                ),
              ],
            ),
          ],
        ),
        build: (pw.Context context) {
          final children = <pw.Widget>[
            pw.SizedBox(height: 10),
            pw.Text(
              _dossierPayloadTitle(dossier),
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Cas ${dossier.caseId} — généré le $generatedDate',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                _dossierPayloadEducationalDisclaimer,
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
              ),
            ),
            pw.SizedBox(height: 22),
            _pdfSectionTitle('Variables de dossier'),
            pw.SizedBox(height: 8),
            _pdfDossierInputsTable(dossier.inputs),
            pw.SizedBox(height: 22),
            _pdfSectionTitle('Résultats éducatifs'),
            pw.SizedBox(height: 8),
            _pdfDossierMapTable(dossier.outputs),
            pw.SizedBox(height: 22),
            _pdfSectionTitle('Hypothèses de scénario'),
            pw.SizedBox(height: 8),
            _pdfDossierAssumptionsTable(dossier.assumptions),
            pw.SizedBox(height: 22),
            _pdfSectionTitle('Données à confirmer'),
            pw.SizedBox(height: 8),
            _pdfBulletList(
              dossier.warnings.isEmpty
                  ? const ['Aucune alerte bloquante dans le dossier actuel.']
                  : dossier.warnings,
            ),
            pw.SizedBox(height: 22),
            _pdfSectionTitle('Questions spécialiste'),
            pw.SizedBox(height: 8),
            _pdfBulletList(
              _dossierSpecialistQuestions(dossier),
            ),
            if (dossier.nextQuestions.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _pdfSectionTitle('Données encore utiles'),
              pw.SizedBox(height: 8),
              _pdfBulletList(_dossierNextQuestionLabels(dossier)),
            ],
          ];

          return children;
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> generateDossierPayloadPdf(DossierPayload dossier) async {
    await Printing.sharePdf(
      bytes: await buildDossierPayloadPdfBytes(dossier),
      filename: 'mint_${dossier.pdfSectionId}.pdf',
    );
  }

  static Future<Uint8List> buildFinancialReportPdfBytes(
    FinancialReport report, {
    bool compress = true,
  }) async {
    final pdf = pw.Document(
      theme: await _loadPdfTheme(),
      compress: compress,
      title: _financialReportPdfTitle,
      author: 'MINT',
      creator: 'MINT',
      subject: 'Rapport financier éducatif',
    );
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
                  _financialReportEducationalDisclaimer,
                  style:
                      const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text('Généré le $generatedDate',
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
            _financialReportPdfTitle,
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
              'value': formatChfWithPrefix(monthlyAvailable),
              'note': 'Après impôts estimés',
            },
            {
              'label': 'Impôts estimés / an',
              'value': formatChfWithPrefix(report.taxSimulation.totalTax),
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
          // 3. TOP 3 PISTES À EXAMINER
          // ═══════════════════════════════════════════════════════
          children.add(pw.SizedBox(height: 30));
          children.add(_pdfSectionTitle('Top 3 — Pistes à examiner'));
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
                  pw.Text('Déductions appliquées :',
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
                      'Total déductions : ${formatChfPreciseWithPrefix(tax.totalDeductions)}',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800)),
                ],
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.SizedBox(height: 6),
                _pdfKeyValue('Impôt cantonal + communal',
                    formatChfPreciseWithPrefix(tax.cantonalTax)),
                _pdfKeyValue('Impôt fédéral direct',
                    formatChfPreciseWithPrefix(tax.federalTax)),
                pw.SizedBox(height: 4),
                _pdfKeyValue(
                    'TOTAL estimé', formatChfPreciseWithPrefix(tax.totalTax),
                    bold: true),
                _pdfKeyValue('Taux effectif',
                    '${(tax.effectiveRate * 100).toStringAsFixed(1)}%'),
                if (tax.taxSavingsFromBuyback != null &&
                    tax.taxSavingsFromBuyback! > 0) ...[
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 0.5, color: PdfColors.green200),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Avec rachat LPP : ${formatChfPreciseWithPrefix(tax.taxWithLppBuyback!)} (économie : ${formatChfPreciseWithPrefix(tax.taxSavingsFromBuyback!)})',
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
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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
                      '${formatChfWithPrefix(ret.monthlyAvsRent)}/mois'),
                  _pdfKeyValue('Rente LPP',
                      '${formatChfWithPrefix(ret.monthlyLppRent)}/mois'),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  _pdfKeyValue(
                    'Total mensuel',
                    '${formatChfWithPrefix(ret.totalMonthlyIncome)}/mois',
                    bold: true,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Capitaux estimés à 65 ans',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600)),
                  _pdfKeyValue(
                      'Capital LPP', formatChfWithPrefix(ret.lppCapital)),
                  _pdfKeyValue(
                      'Capital 3a', formatChfWithPrefix(ret.pillar3aCapital)),
                  if (ret.otherAssets != null && ret.otherAssets! > 0)
                    _pdfKeyValue(
                        'Autres actifs', formatChfWithPrefix(ret.otherAssets!)),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  _pdfKeyValue(
                    'Capital total estimé',
                    formatChfWithPrefix(ret.totalCapital),
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
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfKeyValue('Montant rachetable total',
                      formatChfWithPrefix(lpp.totalBuybackAvailable)),
                  _pdfKeyValue('Économie fiscale totale estimée',
                      formatChfWithPrefix(lpp.totalTaxSavings),
                      bold: true),
                  pw.SizedBox(height: 8),
                  pw.Text('Simulation annuelle indicative',
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
          // 7. CADRE ÉDUCATIF ET LIMITES
          // ═══════════════════════════════════════════════════════
          children.add(pw.SizedBox(height: 25));
          children.add(_pdfSectionTitle('Cadre éducatif et limites'));
          children.add(pw.SizedBox(height: 10));

          children.add(pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: PdfColors.blue50,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    'Nature du service : Éducation financière (non-régulée)',
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

    return pdf.save();
  }

  static Future<void> generateFinancialReportPdf(FinancialReport report) async {
    await Printing.sharePdf(
        bytes: await buildFinancialReportPdfBytes(report),
        filename: 'mint_report_v2.pdf');
  }

  // ===== PDF V2 HELPERS =====

  @visibleForTesting
  static List<String> dossierNextQuestionLabelsForTesting(
    DossierPayload dossier,
  ) =>
      _dossierNextQuestionLabels(dossier);

  @visibleForTesting
  static String formatDossierFieldValueForTesting(
    String fieldKey,
    dynamic value,
  ) =>
      _formatDossierFieldValue(fieldKey, value);

  static String _dossierPayloadTitle(DossierPayload dossier) {
    return switch (dossier.caseId) {
      'first_salary_tax' => 'Dossier Mint — Premier salaire & impôts',
      'buy_property' => 'Dossier Mint — Achat immobilier',
      'transmit_property' => 'Dossier Mint — Transmission immobilière',
      _ => 'Dossier Mint — ${dossier.caseId}',
    };
  }

  static pw.Widget _pdfDossierInputsTable(Map<String, dynamic> inputs) {
    final rows = inputs.entries.map((entry) {
      final value = entry.value;
      final map = value is Map ? value : const <String, dynamic>{};
      return [
        entry.key,
        _formatDossierFieldValue(entry.key, map['value']),
        _formatDossierValue(map['source']),
        _formatDossierValue(map['confidence']),
        _formatDossierValue(map['source_date']),
      ];
    }).toList(growable: false);

    return _pdfTextTable(
      headers: const [
        'Variable',
        'Valeur',
        'Source',
        'Confiance',
        'Date source'
      ],
      rows: rows,
    );
  }

  static pw.Widget _pdfDossierMapTable(Map<String, dynamic> values) {
    final rows = <List<String>>[];
    void append(String prefix, dynamic value) {
      if (value is Map) {
        for (final entry in value.entries) {
          append('$prefix.${entry.key}', entry.value);
        }
        return;
      }
      if (value is List) {
        rows.add([
          prefix,
          value.map((item) => _formatDossierFieldValue(prefix, item)).join(', ')
        ]);
        return;
      }
      rows.add([prefix, _formatDossierFieldValue(prefix, value)]);
    }

    for (final entry in values.entries) {
      append(entry.key, entry.value);
    }

    return _pdfTextTable(
      headers: const ['Champ', 'Valeur'],
      rows: rows,
    );
  }

  static pw.Widget _pdfDossierAssumptionsTable(
    List<DossierAssumption> assumptions,
  ) {
    final rows = assumptions
        .map(
          (assumption) => [
            assumption.inputKey,
            _formatDossierFieldValue(assumption.inputKey, assumption.value),
            assumption.source,
            assumption.confidence,
          ],
        )
        .toList(growable: false);

    return _pdfTextTable(
      headers: const ['Hypothèse', 'Valeur', 'Source', 'Confiance'],
      rows: rows,
    );
  }

  static pw.Widget _pdfTextTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) {
      return pw.Text(
        'Aucune donnée disponible.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      );
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
      headerStyle: pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      ),
      cellStyle: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    );
  }

  static pw.Widget _pdfBulletList(List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final item in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('• ', style: const pw.TextStyle(fontSize: 8)),
                pw.Expanded(
                  child: pw.Text(
                    item,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static List<String> _dossierSpecialistQuestions(DossierPayload dossier) {
    return switch (dossier.caseId) {
      'first_salary_tax' => const [
          'Les déductions fiscales disponibles dans mon canton sont-elles complètes ?',
          'Le montant 3a prévu respecte-t-il mon statut LPP et le plafond annuel ?',
          'Dois-je adapter mes acomptes ou ma déclaration fiscale ?',
        ],
      'buy_property' => const [
          'Le taux de tenue, les charges et les fonds propres respectent-ils vos critères bancaires ?',
          'Quelle part de LPP ou de 3a peut être engagée sans fragiliser ma retraite ?',
          'Quels frais d’achat, impôts et réserves de rénovation dois-je ajouter ?',
        ],
      'transmit_property' => const [
          'La donation, l’avancement d’hoirie ou la vente partielle est-elle adaptée à ma famille ?',
          'Comment préserver mes revenus de retraite avec l’hypothèque et un éventuel droit d’habitation ?',
          'Quels impôts cantonaux, actes notariés et clauses successorales faut-il confirmer ?',
        ],
      _ => const [
          'Quelles données doivent être confirmées avant une décision irréversible ?',
          'Quels spécialistes doivent valider ce dossier ?',
        ],
    };
  }

  static List<String> _dossierNextQuestionLabels(DossierPayload dossier) {
    return dossier.nextQuestions
        .map(_dossierQuestionLabel)
        .toList(growable: false);
  }

  static String _dossierQuestionLabel(String questionId) {
    return switch (questionId) {
      'ask_income_gross_yearly' => 'Confirmer le revenu brut annuel.',
      'ask_canton' => 'Confirmer le canton fiscal.',
      'ask_birth_year' => 'Confirmer l’année de naissance.',
      'ask_has_second_pillar' => 'Confirmer l’affiliation à une caisse LPP.',
      'ask_pillar3a_annual' => 'Ajouter le versement 3a annuel prévu.',
      'ask_liquid_assets' => 'Confirmer les liquidités disponibles.',
      'ask_target_property_value' =>
        'Confirmer le prix ou la valeur cible du bien.',
      'ask_household_type' => 'Confirmer la composition du ménage.',
      'ask_mortgage_rate' => 'Ajouter le taux hypothécaire réel si disponible.',
      'ask_property_market_value' =>
        'Confirmer la valeur de marché du logement.',
      'ask_target_retirement_age' => 'Confirmer l’âge de retraite visé.',
      'ask_lpp_assets' => 'Ajouter l’avoir LPP actuel.',
      'ask_pillar3a_balance' => 'Ajouter le solde total du pilier 3a.',
      'ask_parent_liquid_assets' => 'Confirmer les liquidités des parents.',
      'ask_parent_annual_retirement_income' =>
        'Confirmer les revenus annuels de retraite des parents.',
      'ask_parent_annual_living_costs' =>
        'Confirmer les coûts de vie annuels des parents.',
      'ask_mortgage_balance' => 'Confirmer le solde hypothécaire.',
      'ask_heirs_count' => 'Confirmer le nombre d’héritiers ou d’enfants.',
      'ask_cash_paid_by_recipient' =>
        'Préciser le montant payé par le repreneur.',
      'ask_mortgage_assumed_by_recipient' =>
        'Préciser l’hypothèque reprise par le repreneur.',
      'ask_recipient_relationship' =>
        'Préciser le lien de parenté du repreneur.',
      'ask_retained_right' =>
        'Préciser un éventuel droit d’habitation ou usufruit.',
      'ask_avancement_hoirie' =>
        'Confirmer si la transmission est traitée comme avancement d’hoirie.',
      _ => questionId,
    };
  }

  static String _formatDossierFieldValue(String fieldKey, dynamic value) {
    if (value == null) return 'manquant';
    if (value is num) {
      if (_isDossierMoneyField(fieldKey)) {
        return formatChfWithPrefix(value.toDouble());
      }
      return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    }
    if (value is bool) return value ? 'oui' : 'non';
    if (value is DateTime) return value.toIso8601String();
    return value.toString();
  }

  static String _formatDossierValue(dynamic value) {
    return _formatDossierFieldValue('', value);
  }

  static bool _isDossierMoneyField(String fieldKey) {
    final normalized = fieldKey.toLowerCase();
    if (normalized.isEmpty) return false;
    if ([
      'birthyear',
      'tax_year',
      'taxyear',
      'targetretirementage',
      'heirscount',
      'children',
      'count',
      'ratio',
      'rate',
      'coverage_years',
      'source_date',
      'confidence',
    ].any(normalized.contains)) {
      return false;
    }
    return [
      'chf',
      'income',
      'salary',
      'gross',
      'capital',
      'balance',
      'assets',
      'epargne',
      'cash',
      'lpp',
      'pillar3a',
      'propertymarketvalue',
      'property_value',
      'marketvalue',
      'mortgagebalance',
      'cost',
      'charges',
      'prix',
      'fonds',
      'manque',
      'need',
      'gap',
      'margin',
      'liquidity',
      'ceiling',
      'room',
      'contribution',
    ].any(normalized.contains);
  }

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
    final pdf = pw.Document(theme: await _loadPdfTheme());

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
              'RAPPORT DÉCISIONNEL — CONFIDENTIEL',
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
                  'Généré par MINT le ${DateTime.now().toLocal().toString().split('.')[0]}',
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
            'Rapport décisionnel',
            style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900),
          ));
          children.add(pw.SizedBox(height: 8));
          children.add(pw.Text(
            'Coach MINT — Conversation éducative',
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
              'Points clés de la conversation',
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
              'Outil éducatif — ne constitue pas un conseil financier au sens de la LSFin. '
              'Les estimations sont basées sur des hypothèses simplifiées et des données déclaratives. '
              'Consulte un·e spécialiste certifié·e pour toute décision financière importante.',
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
