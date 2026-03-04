import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';
import 'package:mint_mobile/services/document_parser/avs_extract_parser.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/tax_declaration_parser.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  DOCUMENT SCAN SCREEN — production flow
// ────────────────────────────────────────────────────────────
//
//  Real flow:
//    1) Camera/Gallery input
//    2) OCR extraction when available (mobile)
//    3) Manual OCR text fallback (web/unreadable file)
//    4) Parser by document type
//    5) Extraction review + confirmation
//
//  Supported parsers today:
//    - LPP certificate
//    - Tax declaration
//    - AVS extract
//
//  Privacy:
//    - image bytes are not persisted
//    - only confirmed structured values are saved to profile
// ────────────────────────────────────────────────────────────

class DocumentScanScreen extends StatefulWidget {
  final DocumentType? initialType;

  const DocumentScanScreen({super.key, this.initialType});

  @override
  State<DocumentScanScreen> createState() => _DocumentScanScreenState();
}

class _DocumentScanScreenState extends State<DocumentScanScreen> {
  static const _supportedTypes = <DocumentType>{
    DocumentType.lppCertificate,
    DocumentType.taxDeclaration,
    DocumentType.avsExtract,
  };

  final _imagePicker = ImagePicker();
  DocumentType _selectedType = DocumentType.lppCertificate;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialType;
    if (initial != null && _supportedTypes.contains(initial)) {
      _selectedType = initial;
    }
  }

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
                const SizedBox(height: 12),
                _buildPasteTextButton(),
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  _buildDebugExampleButton(),
                ],
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
          'pour toi. Tu verifies ensuite chaque valeur avant confirmation.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: MintColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentTypeSelector() {
    final selectable = DocumentType.values
        .where((type) => _supportedTypes.contains(type))
        .toList(growable: false);

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
          children: selectable.map((type) {
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
                color: isSelected ? MintColors.primary : MintColors.lightBorder,
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
              const Icon(Icons.info_outline, color: MintColors.info, size: 18),
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
              const Icon(Icons.trending_up,
                  color: MintColors.success, size: 16),
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

  Widget _buildCaptureButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _isProcessing ? null : _onCameraPressed,
            icon: const Icon(Icons.camera_alt_outlined, size: 22),
            label: Text(
              _isProcessing ? 'Extraction en cours...' : 'Prendre une photo',
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

  Widget _buildPasteTextButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextButton.icon(
        onPressed: _isProcessing ? null : _onPasteTextPressed,
        icon: const Icon(Icons.text_snippet_outlined, size: 20),
        label: Text(
          'Coller le texte OCR',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: MintColors.info,
          backgroundColor: MintColors.info.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: MintColors.info.withValues(alpha: 0.22)),
          ),
        ),
      ),
    );
  }

  Widget _buildDebugExampleButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _isProcessing ? null : _onUseExamplePressed,
        icon: const Icon(Icons.science_outlined, size: 20),
        label: Text(
          'Utiliser un exemple de test',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: MintColors.purple,
          side: BorderSide(color: MintColors.purple.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

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
              'Seules les valeurs confirmees sont conservees dans ton profil.',
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

  Future<void> _onCameraPressed() async {
    if (kIsWeb) {
      // On web we fallback to file upload to avoid a dead-end camera path.
      await _onGalleryPressed();
      return;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (image == null) return;
      await _processImageFile(image);
    } catch (e) {
      _showErrorSnack('Impossible d\'ouvrir la camera. Utilise la galerie.');
    }
  }

  Future<void> _onGalleryPressed() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        withData: kIsWeb,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'pdf', 'txt'],
      );

      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      final ext = (file.extension ?? '').toLowerCase();

      if (ext == 'txt') {
        final text = await _readTextFile(file);
        if (text.trim().isEmpty) {
          _showErrorSnack('Le fichier texte est vide.');
          return;
        }
        await _processOcrText(text);
        return;
      }

      if (ext == 'pdf') {
        await _requestManualOcrText(
          title: 'PDF detecte',
          hint:
              'Colle ici le texte OCR de ton PDF (issu de ton scanner ou export).',
        );
        return;
      }

      if (file.path == null || file.path!.isEmpty) {
        await _requestManualOcrText(
          title: 'Image selectionnee',
          hint: 'Impossible de lire directement cette image sur cet appareil.',
        );
        return;
      }

      await _processImageFile(XFile(file.path!));
    } catch (e) {
      _showErrorSnack('Impossible d\'importer le fichier: $e');
    }
  }

  Future<void> _onPasteTextPressed() async {
    await _requestManualOcrText(
      title: 'Texte OCR',
      hint: 'Colle le texte extrait du document pour lancer le parsing.',
    );
  }

  Future<void> _onUseExamplePressed() async {
    await _processOcrText(_sampleTextForType(_selectedType));
  }

  Future<void> _processImageFile(XFile file) async {
    setState(() => _isProcessing = true);

    try {
      String extractedText = '';

      if (!kIsWeb) {
        final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
        try {
          final input = InputImage.fromFilePath(file.path);
          final result = await recognizer.processImage(input);
          extractedText = result.text;
        } finally {
          recognizer.close();
        }
      }

      if (extractedText.trim().length < 12) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        await _requestManualOcrText(
          title: 'Texte non detecte',
          hint:
              'Nous n\'avons pas pu lire suffisamment de texte automatiquement. Colle le texte OCR pour continuer.',
        );
        return;
      }

      await _processOcrText(extractedText);
    } catch (e) {
      _showErrorSnack('Extraction OCR impossible: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processOcrText(String text) async {
    if (!mounted) return;

    setState(() => _isProcessing = true);
    try {
      final result = _parseByDocumentType(text);
      if (result.fields.isEmpty) {
        _showErrorSnack(
          'Aucun champ reconnu. Verifie le type de document ou colle un texte OCR plus complet.',
        );
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExtractionReviewScreen(result: result),
        ),
      );
    } catch (e) {
      _showErrorSnack('Parsing impossible pour ce document: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _requestManualOcrText({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hint,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                minLines: 5,
                decoration: InputDecoration(
                  hintText: 'Colle ici le texte OCR brut... ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Analyser'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    final text = controller.text.trim();
    controller.dispose();

    if (submitted == true && text.isNotEmpty) {
      await _processOcrText(text);
    }
  }

  ExtractionResult _parseByDocumentType(String text) {
    switch (_selectedType) {
      case DocumentType.lppCertificate:
        return LppCertificateParser.parseLppCertificate(text);
      case DocumentType.taxDeclaration:
        return TaxDeclarationParser.parseTaxDeclaration(text);
      case DocumentType.avsExtract:
        final age = context.read<CoachProfileProvider>().hasProfile
            ? context.read<CoachProfileProvider>().profile!.age
            : null;
        return AvsExtractParser.parseAvsExtract(text, userAge: age);
      case DocumentType.threeAAttestation:
      case DocumentType.mortgageAttestation:
        throw UnsupportedError(
          'Type non supporte pour le moment: ${_selectedType.label}',
        );
    }
  }

  String _sampleTextForType(DocumentType type) {
    switch (type) {
      case DocumentType.lppCertificate:
        return LppCertificateParser.sampleOcrText;
      case DocumentType.taxDeclaration:
        return TaxDeclarationParser.sampleOcrText;
      case DocumentType.avsExtract:
        return AvsExtractParser.sampleOcrText;
      case DocumentType.threeAAttestation:
      case DocumentType.mortgageAttestation:
        return LppCertificateParser.sampleOcrText;
    }
  }

  Future<String> _readTextFile(PlatformFile file) async {
    if (file.bytes != null) {
      return utf8.decode(file.bytes!, allowMalformed: true);
    }
    if (file.path != null && file.path!.isNotEmpty) {
      final bytes = await XFile(file.path!).readAsBytes();
      return utf8.decode(bytes, allowMalformed: true);
    }
    return '';
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: MintColors.error,
      ),
    );
  }
}
