import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/models/financial_report.dart';

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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Text("MINT - RAPPORT FINANCIER V2"),
        build: (context) => [
          pw.Header(
              level: 1,
              text: "Bilan pour ${report.profile.firstName ?? 'Vous'}"),
          pw.Text(
              "Score de Santé: ${report.healthScore.overallScore.toInt()}/100"),
          pw.SizedBox(height: 20),
          pw.Header(level: 2, text: "Priorités"),
          ...report.priorityActions.map((a) => pw.Bullet(text: a.title)),
          pw.SizedBox(height: 20),
          pw.Header(level: 2, text: "Simulation Fiscale"),
          pw.Text(
              "Impôts estimés: CHF ${report.taxSimulation.totalTax.toStringAsFixed(0)}"),
          pw.SizedBox(height: 20),
          pw.Footer(title: pw.Text("Généré par Mint Mobile")),
        ],
      ),
    );

    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'mint_report_v2.pdf');
  }
}
