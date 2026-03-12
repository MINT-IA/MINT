import 'dart:convert';
import 'dart:io';

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
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/document_parser/avs_extract_parser.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/salary_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/tax_declaration_parser.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/services/rag_service.dart';
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
          'Améliore la précision de ton profil',
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
          'pour toi. Tu vérifies ensuite chaque valeur avant confirmation.',
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
            icon: Icon(
              kIsWeb ? Icons.upload_file_outlined : Icons.camera_alt_outlined,
              size: 22,
            ),
            label: Text(
              _isProcessing
                  ? S.of(context)!.documentScanExtracting
                  : kIsWeb
                      ? S.of(context)!.documentScanImportFile
                      : S.of(context)!.documentScanTakePhoto,
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
              "L'image est analysée localement (OCR sur l'appareil). "
              "Si tu utilises l'analyse Vision IA, l'image est envoyée "
              "à ton fournisseur IA via ta propre clé API. "
              'Seules les valeurs confirmées sont conservées dans ton profil.',
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
      _showErrorSnack("Impossible d'ouvrir la caméra. Utilise la galerie.");
    }
  }

  Future<void> _onGalleryPressed() async {
    try {
      final allowedExtensions = <String>[
        'jpg',
        'jpeg',
        'png',
        'heic',
        'txt',
        'pdf',
      ];
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        // On iOS Files provider can return bytes-only entries.
        withData: true,
        allowedExtensions: allowedExtensions,
      );

      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      final ext = _detectExtension(file);

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
        await _handlePdfImport(file, ext: ext);
        return;
      }

      final localPath = await _resolveLocalPath(file, ext: ext);
      if (localPath == null || localPath.isEmpty) {
        await _showOcrRecoverySheet(
          title: 'Fichier non exploitable',
          message: "Nous n'avons pas pu lire ce fichier directement depuis ton "
              'appareil. Prends une photo du document ou colle un texte OCR.',
        );
        return;
      }

      await _processImageFile(XFile(localPath));
    } catch (e) {
      _showErrorSnack('Impossible d\'importer le fichier: $e');
    }
  }

  Future<void> _onPasteTextPressed() async {
    await _requestManualOcrText(
      title: S.of(context)!.documentScanOcrTitle,
      hint: S.of(context)!.documentScanOcrHint,
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
        await _showOcrRecoverySheet(
          title: 'Texte non détecté',
          message:
              "Nous n'avons pas pu lire suffisamment de texte sur la photo.",
          imageFile: file,
        );
        return;
      }

      await _processOcrText(extractedText);
    } catch (_) {
      if (!mounted) return;
      await _showOcrRecoverySheet(
        title: 'Analyse de la photo indisponible',
        message: "Nous n'avons pas pu extraire le texte automatiquement. "
            'Réessaie avec une photo plus nette ou colle le texte OCR.',
        imageFile: file,
      );
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
        await _requestManualOcrText(
          title: 'Aucun champ reconnu automatiquement',
          hint:
              "Ajoute ou corrige le texte OCR pour améliorer l'analyse, puis relance.",
          initialText: text,
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
    String? initialText,
  }) async {
    final controller = TextEditingController(text: initialText ?? '');

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
                  hintText: 'Colle ici le texte OCR brut…',
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
                      child: Text(S.of(context)!.documentScanCancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(S.of(context)!.documentScanAnalyze),
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

  Future<void> _handlePdfImport(
    PlatformFile file, {
    required String ext,
  }) async {
    final localPath = await _resolveLocalPath(file, ext: ext);
    if (localPath == null || localPath.isEmpty) {
      await _showPdfImportFallback(
        title: 'PDF détecté',
        message: 'Impossible de lire ce PDF directement sur cet appareil. '
            'Prends une photo du document ou colle un texte OCR.',
      );
      return;
    }

    if (!kIsWeb && _selectedType == DocumentType.lppCertificate) {
      final parse = await _processPdfViaBackend(localPath);
      if (parse.success) return;
      if (parse.requiresAuthentication) {
        await _showPdfAuthRequiredSheet();
        return;
      }
      await _showPdfImportFallback(
        title: 'Analyse PDF indisponible',
        message: parse.errorMessage ??
            'Le PDF n\'a pas pu être analysé automatiquement. '
                'Tu peux prendre une photo (recommandé) ou coller un texte OCR.',
      );
      return;
    }

    await _showPdfImportFallback(
      title: 'PDF détecté',
      message: _selectedType == DocumentType.lppCertificate
          ? 'Le parsing PDF n\'est pas disponible dans ce contexte. '
              'Prends une photo ou colle un texte OCR.'
          : 'Pour le moment, le parsing PDF automatique est surtout optimisé '
              'pour les certificats LPP. Prends une photo du document.',
    );
  }

  Future<void> _showPdfImportFallback({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _onCameraPressed();
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(S.of(context)!.documentScanTakePhoto),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _requestManualOcrText(
                      title: S.of(context)!.documentScanOcrTitle,
                      hint: S.of(context)!.documentScanOcrHint,
                    );
                  },
                  icon: const Icon(Icons.text_snippet_outlined),
                  label: Text(S.of(context)!.documentScanPasteOcr),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPdfAuthRequiredSheet() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)!.documentScanPdfAuthTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                S.of(context)!.documentScanPdfAuthContent,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/auth/register');
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(S.of(context)!.documentScanCreateAccount),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _onCameraPressed();
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(S.of(context)!.documentScanTakePhoto),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showOcrRecoverySheet({
    required String title,
    required String message,
    XFile? imageFile,
  }) async {
    if (!mounted) return;
    final showVision = imageFile != null && _isVisionAvailable(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (showVision) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _processImageViaVision(imageFile);
                    },
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Analyser via Vision IA'),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'L\'image sera envoyée à ton fournisseur IA via ta clé API.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              SizedBox(height: showVision ? 8 : 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _onCameraPressed();
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(S.of(context)!.documentScanRetakePhoto),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _requestManualOcrText(
                      title: S.of(context)!.documentScanOcrTitle,
                      hint: S.of(context)!.documentScanOcrRetryHint,
                    );
                  },
                  icon: const Icon(Icons.text_snippet_outlined),
                  label: Text(S.of(context)!.documentScanPasteOcr),
                ),
              ),
            ],
          ),
        );
      },
    );
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
      case DocumentType.salaryCertificate:
        return SalaryCertificateParser.parse(text);
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
      case DocumentType.salaryCertificate:
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

  String _detectExtension(PlatformFile file) {
    final ext = (file.extension ?? '').trim().toLowerCase();
    if (ext.isNotEmpty) return ext;

    final name = file.name.trim().toLowerCase();
    final nameDot = name.lastIndexOf('.');
    if (nameDot > 0 && nameDot < name.length - 1) {
      return name.substring(nameDot + 1);
    }

    final path = (file.path ?? '').trim().toLowerCase();
    final pathDot = path.lastIndexOf('.');
    if (pathDot > 0 && pathDot < path.length - 1) {
      return path.substring(pathDot + 1);
    }

    return '';
  }

  Future<String?> _resolveLocalPath(
    PlatformFile file, {
    required String ext,
  }) async {
    if (file.path != null && file.path!.isNotEmpty) return file.path;
    if (kIsWeb || file.bytes == null) return null;

    final safeExt = ext.trim().isEmpty ? 'bin' : ext.trim();
    final tempPath =
        '${Directory.systemTemp.path}/mint_upload_${DateTime.now().microsecondsSinceEpoch}.$safeExt';
    try {
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(file.bytes!, flush: true);
      return tempFile.path;
    } catch (_) {
      return null;
    }
  }

  Future<_PdfParseResult> _processPdfViaBackend(String path) async {
    if (kIsWeb || _selectedType != DocumentType.lppCertificate) {
      return const _PdfParseResult(
        success: false,
        errorMessage:
            'Type de document non pris en charge pour le parsing PDF.',
      );
    }

    setState(() => _isProcessing = true);
    try {
      final upload = await DocumentService().uploadDocument(
        File(path),
        type: VaultDocumentType.lppCertificate,
      );
      final extraction = _mapLppUploadToExtraction(upload);
      if (extraction.fields.isEmpty) {
        return const _PdfParseResult(
          success: false,
          errorMessage: 'Aucune donnée utile n’a été extraite depuis ce PDF.',
        );
      }
      if (!mounted) return const _PdfParseResult(success: true);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExtractionReviewScreen(result: extraction),
        ),
      );
      return const _PdfParseResult(success: true);
    } on DocumentServiceException catch (e) {
      final lower = e.message.toLowerCase();
      final requiresAuthentication = lower.contains('authentication requise') ||
          lower.contains('unauthorized') ||
          lower.contains('forbidden');
      debugPrint('[DocumentScan] Backend PDF parsing unavailable: $e');
      return _PdfParseResult(
        success: false,
        requiresAuthentication: requiresAuthentication,
        errorMessage: 'Erreur backend pendant le parsing PDF: $e',
      );
    } catch (e) {
      debugPrint('[DocumentScan] Backend PDF parsing unavailable: $e');
      return _PdfParseResult(
        success: false,
        errorMessage: 'Erreur backend pendant le parsing PDF: $e',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  ExtractionResult _mapLppUploadToExtraction(DocumentUploadResult upload) {
    final lpp = upload.extractedFields.lpp;
    if (lpp == null) {
      return ExtractionResult(
        documentType: DocumentType.lppCertificate,
        fields: const [],
        overallConfidence: upload.confidence,
        confidenceDelta:
            DocumentType.lppCertificate.confidenceImpact.toDouble(),
        warnings: upload.warnings,
        disclaimer:
            "Données extraites automatiquement : vérifie chaque valeur avant confirmation.",
        sources: const ['Extraction backend Docling (LPP)'],
      );
    }

    final fields = <ExtractedField>[];
    void addField({
      required String fieldName,
      required String label,
      required double? value,
      String? profileField,
    }) {
      if (value == null) return;
      fields.add(
        ExtractedField(
          fieldName: fieldName,
          label: label,
          value: value,
          confidence: upload.confidence,
          sourceText: '',
          needsReview: upload.confidence < 0.8,
          profileField: profileField,
        ),
      );
    }

    addField(
      fieldName: 'avoir_vieillesse_total',
      label: 'Avoir LPP total',
      value: lpp.avoirVieillesseTotal,
      profileField: 'avoirLppTotal',
    );
    addField(
      fieldName: 'avoir_obligatoire',
      label: 'Part obligatoire',
      value: lpp.avoirObligatoire,
      profileField: 'lppObligatoire',
    );
    addField(
      fieldName: 'avoir_surobligatoire',
      label: 'Part surobligatoire',
      value: lpp.avoirSurobligatoire,
      profileField: 'lppSurobligatoire',
    );
    addField(
      fieldName: 'taux_conversion_obligatoire',
      label: 'Taux de conversion obligatoire',
      value: lpp.tauxConversionObligatoire,
      profileField: 'tauxConversionOblig',
    );
    addField(
      fieldName: 'taux_conversion_surobligatoire',
      label: 'Taux de conversion surobligatoire',
      value: lpp.tauxConversionSurobligatoire,
      profileField: 'tauxConversionSuroblig',
    );
    addField(
      fieldName: 'rachat_maximum',
      label: 'Rachat maximal',
      value: lpp.rachatMaximum,
      profileField: 'buybackPotential',
    );
    addField(
      fieldName: 'salaire_assure',
      label: 'Salaire assuré',
      value: lpp.salaireAssure,
      profileField: 'lppInsuredSalary',
    );
    addField(
      fieldName: 'remuneration_rate',
      label: 'Taux de rémunération',
      value: lpp.remunerationRate,
      profileField: 'rendementCaisse',
    );

    return ExtractionResult(
      documentType: DocumentType.lppCertificate,
      fields: fields,
      overallConfidence: upload.confidence,
      confidenceDelta: DocumentType.lppCertificate.confidenceImpact.toDouble(),
      warnings: upload.warnings,
      disclaimer:
          "Vérifie les montants avant confirmation. Outil éducatif (LSFin).",
      sources: const ['Extraction backend Docling (LPP)'],
    );
  }

  /// Whether the user has a BYOK key for a vision-capable provider.
  bool _isVisionAvailable(BuildContext ctx) {
    final byok = ctx.read<ByokProvider>();
    if (!byok.isConfigured || byok.apiKey == null || byok.provider == null) {
      return false;
    }
    const visionProviders = {'claude', 'openai', 'anthropic'};
    return visionProviders.contains(byok.provider!.toLowerCase());
  }

  /// Map DocumentType to backend vision document_type string.
  String _documentTypeToVisionKey(DocumentType type) {
    switch (type) {
      case DocumentType.lppCertificate:
        return 'lpp_certificate';
      case DocumentType.taxDeclaration:
        return 'tax_declaration';
      case DocumentType.avsExtract:
        return 'avs_extract';
      default:
        return 'generic';
    }
  }

  /// Process image via BYOK Vision LLM (Claude/GPT-4o).
  Future<void> _processImageViaVision(XFile file) async {
    final byok = context.read<ByokProvider>();
    if (!byok.isConfigured || byok.apiKey == null || byok.provider == null) {
      _showErrorSnack('Configure une cle API dans les parametres Coach.');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final ext = file.path.split('.').last.toLowerCase();
      final mediaType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      // Map provider name (anthropic → claude for backend)
      final provider = byok.provider!.toLowerCase() == 'anthropic'
          ? 'claude'
          : byok.provider!.toLowerCase();

      final ragService = RagService();
      final visionResponse = await ragService.extractFromImage(
        imageBase64: base64Image,
        mediaType: mediaType,
        documentType: _documentTypeToVisionKey(_selectedType),
        apiKey: byok.apiKey!,
        provider: provider,
      );

      if (!mounted) return;

      final fields = visionResponse.extractedFields.map((f) {
        return ExtractedField(
          fieldName: f.fieldName,
          label: f.label,
          value: f.value,
          confidence: f.confidence,
          sourceText: f.sourceText,
          needsReview: f.confidence < 0.80,
        );
      }).toList();

      if (fields.isEmpty) {
        _showErrorSnack(
          "L'IA n'a pas pu extraire de champs de ce document.",
        );
        return;
      }

      final result = ExtractionResult(
        documentType: _selectedType,
        fields: fields,
        overallConfidence: fields.fold<double>(0, (sum, f) => sum + f.confidence) /
            fields.length,
        confidenceDelta: visionResponse.confidenceDelta.toDouble(),
        warnings: const [],
        disclaimer: visionResponse.disclaimers.isNotEmpty
            ? visionResponse.disclaimers.first
            : "Donnees extraites par IA : verifie chaque valeur. "
                "Outil educatif, ne constitue pas un conseil (LSFin).",
        sources: const ['Extraction Vision IA (BYOK)'],
      );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExtractionReviewScreen(result: result),
        ),
      );
    } on RagApiException catch (e) {
      _showErrorSnack(e.message);
    } catch (e) {
      _showErrorSnack("Erreur Vision IA : $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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

class _PdfParseResult {
  final bool success;
  final bool requiresAuthentication;
  final String? errorMessage;

  const _PdfParseResult({
    required this.success,
    this.requiresAuthentication = false,
    this.errorMessage,
  });
}
