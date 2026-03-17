import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/factory/letter_generator_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

class LetterGeneratorSheet extends StatelessWidget {
  final String userName;

  const LetterGeneratorSheet({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.letterGenTitle,
            style:
                GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            s.letterGenSubtitle,
            style: GoogleFonts.inter(
                fontSize: 14, color: MintColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _buildActionItem(
            context,
            icon: Icons.savings,
            title: s.letterGenBuybackTitle,
            subtitle: s.letterGenBuybackSubtitle,
            onTap: () async {
              final letter = LetterGeneratorService.generateBuybackRequest(
                userName: userName,
                userAddress: "[Ton Adresse]",
                insuranceNumber: "[N° AVS]",
              );
              await _generateAndSharePdf(letter);
            },
          ),
          _buildActionItem(
            context,
            icon: Icons.receipt_long,
            title: s.letterGenTaxTitle,
            subtitle: s.letterGenTaxSubtitle,
            onTap: () async {
              final letter =
                  LetterGeneratorService.generateTaxCertificateRequest(
                userName: userName,
                year: DateTime.now().year - 1,
              );
              await _generateAndSharePdf(letter);
            },
          ),
          const SizedBox(height: 30),
          Text(
            s.letterGenDisclaimer,
            style: GoogleFonts.inter(fontSize: 10, color: MintColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActionItem(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: MintColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: MintColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: MintColors.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndSharePdf(GeneratedLetter letter) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(letter.title,
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20), // Spacer
              pw.SizedBox(height: 40),
              pw.Text(letter.content,
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 5)),
              pw.Spacer(),
              pw.Divider(),
              pw.Text(letter.disclaimer,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    // 1. Generate & Share
    await Printing.sharePdf(
        bytes: await pdf.save(), filename: '${letter.title}.pdf');

    // 2. Log History (Audit Trail)
    try {
      final currentHistory =
          await ReportPersistenceService.loadLettersHistory();
      currentHistory.add({
        'title': letter.title,
        'date': DateTime.now().toIso8601String(),
        'type':
            letter.title.contains('Rachat') ? 'LPP_BUYBACK' : 'TAX_CERTIFICATE',
      });
      await ReportPersistenceService.saveLettersHistory(currentHistory);
      if (kDebugMode) {
        debugPrint('Audit Trail: Letter logged.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Audit Trail Error: $e');
      }
    }
  }
}
