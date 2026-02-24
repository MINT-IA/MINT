import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';

// ────────────────────────────────────────────────────────────
//  DOCUMENT SCAN SCREEN — Sprint S42-S43
// ────────────────────────────────────────────────────────────
//
//  Entry point for scanning financial documents.
//  User selects document type, then captures or picks an image.
//
//  Prototype: no real OCR — "Simuler un scan" injects sample text.
//  Production: integrate image_picker + google_mlkit_text_recognition.
//
//  Privacy: "L'image n'est jamais stockee ni envoyee."
//
//  Reference: DATA_ACQUISITION_STRATEGY.md — Channel 1
// ────────────────────────────────────────────────────────────

class DocumentScanScreen extends StatefulWidget {
  const DocumentScanScreen({super.key});

  @override
  State<DocumentScanScreen> createState() => _DocumentScanScreenState();
}

class _DocumentScanScreenState extends State<DocumentScanScreen> {
  DocumentType _selectedType = DocumentType.lppCertificate;
  bool _isProcessing = false;

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildDocumentTypeSelector(),
                const SizedBox(height: 32),
                _buildDocumentDescription(),
                const SizedBox(height: 32),
                _buildCaptureButtons(),
                const SizedBox(height: 24),
                _buildSimulateButton(),
                const SizedBox(height: 32),
                _buildPrivacyNote(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'SCANNER UN DOCUMENT',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ameliore la precision de ton profil',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Photographie un document financier et on extrait les chiffres '
          'pour toi. Plus besoin de chercher dans tes papiers.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: MintColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Document type selector ───────────────────────────────

  Widget _buildDocumentTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de document',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DocumentType.values.map((type) {
            final isSelected = type == _selectedType;
            return ChoiceChip(
              label: Text(
                type.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? MintColors.background
                      : MintColors.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: MintColors.primary,
              backgroundColor: MintColors.surface,
              side: BorderSide(
                color:
                    isSelected ? MintColors.primary : MintColors.lightBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) {
                setState(() => _selectedType = type);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Document description card ────────────────────────────

  Widget _buildDocumentDescription() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: MintColors.info, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedType.label,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _selectedType.description,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.trending_up, color: MintColors.success, size: 16),
              const SizedBox(width: 6),
              Text(
                '+${_selectedType.confidenceImpact} points de confiance',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Capture buttons ──────────────────────────────────────

  Widget _buildCaptureButtons() {
    return Column(
      children: [
        // Camera button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _isProcessing ? null : _onCameraPressed,
            icon: const Icon(Icons.camera_alt_outlined, size: 22),
            label: Text(
              'Prendre une photo',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Gallery button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : _onGalleryPressed,
            icon: const Icon(Icons.photo_library_outlined, size: 22),
            label: Text(
              'Depuis la galerie',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: MintColors.textPrimary,
              side: const BorderSide(color: MintColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Simulate button (prototype) ──────────────────────────

  Widget _buildSimulateButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            'MODE PROTOTYPE',
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: MintColors.purple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pas de document sous la main ? Simule un scan '
            'avec un certificat LPP de test.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: _isProcessing
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MintColors.purple,
                      ),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _onSimulateScan,
                    icon: const Icon(Icons.science_outlined, size: 20),
                    label: Text(
                      'Simuler un scan',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Privacy note ─────────────────────────────────────────

  Widget _buildPrivacyNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 18, color: MintColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "L'image n'est jamais stockee ni envoyee. "
              "L'extraction se fait sur ton appareil. "
              "Seules les valeurs que tu confirmes sont conservees dans ton profil.",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────

  void _onCameraPressed() {
    // Production: integrate image_picker with ImageSource.camera
    // For prototype, show info dialog
    _showPrototypeDialog(
      'Camera',
      'En production, cette fonctionnalite utilisera image_picker '
          'pour capturer une photo de ton document.',
    );
  }

  void _onGalleryPressed() {
    // Production: integrate image_picker with ImageSource.gallery
    _showPrototypeDialog(
      'Galerie',
      'En production, cette fonctionnalite permettra de selectionner '
          'une image existante de ton document.',
    );
  }

  void _onSimulateScan() async {
    setState(() => _isProcessing = true);

    // Simulate processing delay (OCR would take 2-5 seconds)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Parse the sample OCR text
    final result = LppCertificateParser.parseLppCertificate(
      LppCertificateParser.sampleOcrText,
    );

    setState(() => _isProcessing = false);

    // Navigate to extraction review
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExtractionReviewScreen(result: result),
      ),
    );
  }

  void _showPrototypeDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _onSimulateScan();
            },
            child: Text(
              'Simuler un scan a la place',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: MintColors.purple,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Fermer',
              style: GoogleFonts.inter(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
