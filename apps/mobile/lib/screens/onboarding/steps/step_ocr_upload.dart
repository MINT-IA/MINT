import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/onboarding/smart_onboarding_viewmodel.dart';
import 'package:mint_mobile/services/document_parser/avs_extract_parser.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/salary_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/tax_declaration_parser.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

/// Step OCR — Enrichissement du profil par scan de documents.
///
/// Position dans le flux : apres StepChiffreChoc (hook emotionnel intact).
///
/// Affiche 4 types de documents que l'utilisateur peut scanner :
/// - Lettre de retraite LPP
/// - Extrait AVS
/// - Declaration fiscale
/// - Compte 3a
///
/// Contraintes LPD / FINMA :
/// - Banniere LPD visible avant toute possibilite de scan.
/// - "Traite sur ton appareil, supprime apres extraction" (LPD art. 6).
/// - Skip sans friction depuis l'entree dans le step.
/// - Aucun stockage de document : seules les donnees extraites vont
///   dans CoachProfile via le ViewModel.
///
/// Le pipeline OCR utilise ML Kit on-device + parsers Dart regex
/// (ExtractionResult de document_models.dart).
/// Aucune cle API, aucun envoi reseau.
class StepOcrUpload extends StatefulWidget {
  final SmartOnboardingViewModel viewModel;

  /// Appelé quand l'utilisateur termine le step (avec ou sans document).
  final VoidCallback onNext;

  const StepOcrUpload({
    super.key,
    required this.viewModel,
    required this.onNext,
  });

  @override
  State<StepOcrUpload> createState() => _StepOcrUploadState();
}

class _StepOcrUploadState extends State<StepOcrUpload> {
  DocumentType? _scanning;
  final Set<DocumentType> _scanned = {};
  final _imagePicker = ImagePicker();

  Future<void> _scanDocument(DocumentType type) async {
    // LPD : demander confirmation avant de lancer le scan
    final confirmed = await _showLpdConfirmation(type);
    if (!confirmed || !mounted) return;

    setState(() => _scanning = type);
    try {
      final result = await _pickAndParse(type);
      if (!mounted) return;
      if (result != null) {
        widget.viewModel.applyOcrResult(result);
        setState(() {
          _scanning = null;
          _scanned.add(type);
        });
        final count = result.fields.where((f) => f.confidence >= 0.5).length;
        if (mounted) {
          final l = S.of(context)!;
          final plural = count > 1 ? 's' : '';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(count > 0
                ? l.stepOcrSnackSuccess(count, plural)
                : l.stepOcrSnackEmpty),
            duration: const Duration(seconds: 3),
          ));
        }
      } else {
        // User cancelled picker
        setState(() => _scanning = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = null);
        final l = S.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.stepOcrSnackError('$e')),
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  /// Pick a file and parse it through the appropriate parser.
  /// Returns null if the user cancelled.
  Future<ExtractionResult?> _pickAndParse(DocumentType type) async {
    if (kIsWeb) {
      return _pickAndParseWeb(type);
    } else {
      return _pickAndParseMobile(type);
    }
  }

  Future<ExtractionResult?> _pickAndParseWeb(DocumentType type) async {
    // On web: file picker (txt or image). OCR on images not possible without
    // a server — txt files go directly to the parser.
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      withData: true,
      allowedExtensions: const ['txt', 'jpg', 'jpeg', 'png', 'pdf'],
    );
    if (picked == null || picked.files.isEmpty) return null;

    final file = picked.files.first;
    final ext = (file.extension ?? '').toLowerCase();

    if (ext == 'txt' && file.bytes != null) {
      final text = String.fromCharCodes(file.bytes!);
      return _parseText(text, type);
    }

    // Image on web — OCR not possible without ML Kit (mobile only).
    if (mounted) {
      final l = S.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.stepOcrSnackWebOnly),
        duration: const Duration(seconds: 5),
      ));
    }
    // Mark as "attempted" so user gets visual feedback
    return ExtractionResult(
      documentType: type,
      fields: const [],
      overallConfidence: 0,
      confidenceDelta: 0,
      warnings: const ['OCR image non disponible sur web — utilise l\'app mobile'],
      disclaimer: 'Outil educatif (LSFin). Traitement local (LPD art. 6).',
      sources: const [],
    );
  }

  Future<ExtractionResult?> _pickAndParseMobile(DocumentType type) async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(image.path);
      final recognised = await recognizer.processImage(input);
      return _parseText(recognised.text, type);
    } finally {
      recognizer.close();
    }
  }

  ExtractionResult _parseText(String text, DocumentType type) {
    switch (type) {
      case DocumentType.lppCertificate:
        return LppCertificateParser.parseLppCertificate(text);
      case DocumentType.avsExtract:
        return AvsExtractParser.parseAvsExtract(text);
      case DocumentType.taxDeclaration:
        return TaxDeclarationParser.parseTaxDeclaration(text);
      case DocumentType.salaryCertificate:
        return SalaryCertificateParser.parse(text);
      case DocumentType.threeAAttestation:
      case DocumentType.mortgageAttestation:
        // No dedicated parser yet — return minimal result
        return ExtractionResult(
          documentType: type,
          fields: const [],
          overallConfidence: 0,
          confidenceDelta: 0,
          warnings: const ['Parser non encore disponible pour ce type de document'],
          disclaimer: 'Outil educatif (LSFin). Traitement local (LPD art. 6).',
          sources: const [],
        );
    }
  }

  Future<bool> _showLpdConfirmation(DocumentType type) async {
    if (!mounted) return false;
    final l = S.of(context)!;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MintColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MintColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        color: MintColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.stepOcrLpdTitle,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l.stepOcrLpdBody,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.stepOcrLpdLegal,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  button: true,
                  label: l.stepOcrLpdScan,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: MintColors.primary,
                        foregroundColor: MintColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l.stepOcrLpdScan,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(
                      l.stepOcrLpdCancel,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final scannedCount = _scanned.length;
    final l = S.of(context)!;

    final docTitles = [l.stepOcrLppTitle, l.stepOcrAvsTitle, l.stepOcrTaxTitle, l.stepOcr3aTitle];
    final docSubtitles = [l.stepOcrLppSubtitle, l.stepOcrAvsSubtitle, l.stepOcrTaxSubtitle, l.stepOcr3aSubtitle];
    final docBoosts = [l.stepOcrLppBoost, l.stepOcrAvsBoost, l.stepOcrTaxBoost, l.stepOcr3aBoost];
    const docTypes = [DocumentType.lppCertificate, DocumentType.avsExtract, DocumentType.taxDeclaration, DocumentType.threeAAttestation];
    const docIcons = [Icons.account_balance_outlined, Icons.security_outlined, Icons.receipt_long_outlined, Icons.savings_outlined];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar gradient MINT ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 24, bottom: 16, right: 24),
              title: Text(
                l.stepOcrTitle,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: MintColors.background,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MintColors.primary, MintColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Lien skip — visible sans friction DES l'entree ──────
                  MintEntrance(child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.onNext,
                      child: Text(
                        l.stepOcrSkip,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )),
                  const SizedBox(height: 4),

                  // ── Banniere LPD — obligatoire avant tout scan ──────────
                  _LpdBanner(text: l.stepOcrLpdBanner),
                  const SizedBox(height: 24),

                  // ── Texte intro ─────────────────────────────────────────
                  MintEntrance(delay: const Duration(milliseconds: 100), child: Text(
                    l.stepOcrIntro,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  )),
                  const SizedBox(height: 20),

                  // ── Cartes documents ────────────────────────────────────
                  ...List.generate(docTypes.length, (i) {
                    final isScanned = _scanned.contains(docTypes[i]);
                    final isScanning = _scanning == docTypes[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DocumentCard(
                        title: docTitles[i],
                        subtitle: docSubtitles[i],
                        icon: docIcons[i],
                        confidenceBoost: docBoosts[i],
                        isScanned: isScanned,
                        isLoading: isScanning,
                        scannedLabel: l.stepOcrScanned,
                        onTap: isScanning
                            ? null
                            : () => _scanDocument(docTypes[i]),
                      ),
                    );
                  }),

                  const SizedBox(height: 28),

                  // ── CTA principal ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor: scannedCount > 0
                            ? MintColors.primary
                            : MintColors.primary.withAlpha(180),
                        foregroundColor: MintColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        scannedCount > 0
                            ? l.stepOcrContinueWith(scannedCount, scannedCount > 1 ? 's' : '')
                            : l.stepOcrContinueWithout,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Disclaimer FINMA/LPD
                  MintEntrance(delay: const Duration(milliseconds: 200), child: Text(
                    l.stepOcrDisclaimer,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  )),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  LPD BANNER — affichee avant toute possibilite de scan
// ════════════════════════════════════════════════════════════════════════════

class _LpdBanner extends StatelessWidget {
  final String text;
  const _LpdBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MintColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.primary.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 18,
            color: MintColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.primary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DOCUMENT CARD — carte pour un type de document scannable
// ════════════════════════════════════════════════════════════════════════════

class _DocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String confidenceBoost;
  final bool isScanned;
  final bool isLoading;
  final String scannedLabel;
  final VoidCallback? onTap;

  const _DocumentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.confidenceBoost,
    required this.isScanned,
    required this.isLoading,
    required this.scannedLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isScanned
              ? MintColors.primary.withAlpha(12)
              : MintColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isScanned ? MintColors.primary : MintColors.lightBorder,
            width: isScanned ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isScanned
                    ? MintColors.primary.withAlpha(24)
                    : MintColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MintColors.primary,
                      ),
                    )
                  : Icon(
                      isScanned ? Icons.check_circle_outline : icon,
                      color: isScanned
                          ? MintColors.primary
                          : MintColors.textSecondary,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),

            // Textes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Badge precision
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isScanned
                    ? MintColors.primary
                    : MintColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isScanned
                      ? MintColors.primary
                      : MintColors.lightBorder,
                ),
              ),
              child: Text(
                isScanned ? scannedLabel : confidenceBoost,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      isScanned ? MintColors.background : MintColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
