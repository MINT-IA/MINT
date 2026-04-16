import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:mint_mobile/services/native_document_scanner.dart';
import 'package:mint_mobile/services/local_image_classifier.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/document_parser/avs_extract_parser.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/salary_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/tax_declaration_parser.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

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

  /// Maximum file size: 4 MB.
  static const _maxFileSizeBytes = 4 * 1024 * 1024;

  /// Vision API size threshold: compress images larger than 2 MB before encoding.
  static const _visionCompressThresholdBytes = 2 * 1024 * 1024;

  /// Accepted file extensions for image/PDF capture.
  static const _acceptedExtensions = {'jpg', 'jpeg', 'png', 'heic', 'pdf'};

  /// Phase 28-03 — kept as nullable for tests to inject a fake. Production
  /// code uses the default constructor (real ML Kit labeler).
  @visibleForTesting
  LocalImageClassifier? imageClassifierOverride;
  DocumentType _selectedType = DocumentType.lppCertificate;
  bool _isProcessing = false;
  String? _preValidationError;
  String? _preValidationHint;

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
      body: Stack(
        children: [
          // FIX-064: Show linear progress during Vision extraction (10-30s on 3G)
          if (_isProcessing)
            const Positioned(
              top: 0, left: 0, right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),
                MintEntrance(child: _buildHeader()),
                const SizedBox(height: 24),
                MintEntrance(delay: const Duration(milliseconds: 100), child: _buildDocumentTypeSelector()),
                const SizedBox(height: 32),
                MintEntrance(delay: const Duration(milliseconds: 200), child: _buildDocumentDescription()),
                const SizedBox(height: 32),
                MintEntrance(delay: const Duration(milliseconds: 300), child: _buildCaptureButtons()),
                if (_preValidationError != null) ...[
                  const SizedBox(height: 12),
                  _buildPreValidationError(),
                ],
                const SizedBox(height: 12),
                MintEntrance(delay: const Duration(milliseconds: 400), child: _buildPasteTextButton()),
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
      ))),
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
        onPressed: () => safePop(context),
      ),
      title: Text(
        S.of(context)!.docScanAppBarTitle,
        style: MintTextStyles.headlineMedium(),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.docScanHeaderTitle,
          style: MintTextStyles.headlineMedium(),
        ),
        const SizedBox(height: 8),
        Text(
          S.of(context)!.docScanHeaderSubtitle,
          style: MintTextStyles.bodyLarge(color: MintColors.textSecondary),
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
          S.of(context)!.docScanDocumentType,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
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
                style: MintTextStyles.bodySmall(
                  color: isSelected ? MintColors.background : MintColors.textPrimary,
                ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
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
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            _selectedType.description,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
          ),
          const SizedBox(height: MintSpacing.sm),
          Row(
            children: [
              const Icon(Icons.trending_up,
                  color: MintColors.success, size: 16),
              const SizedBox(width: 6),
              Text(
                S.of(context)!.docScanConfidencePoints(_selectedType.confidenceImpact),
                style: MintTextStyles.bodySmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600),
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
        Semantics(
          button: true,
          label: S.of(context)!.documentScanTakePhoto,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      _onCameraPressed();
                    },
            icon: const Icon(
              kIsWeb ? Icons.upload_file_outlined : Icons.camera_alt_outlined,
              size: 22,
            ),
            label: Text(
              _isProcessing
                  ? S.of(context)!.documentScanExtracting
                  : kIsWeb
                      ? S.of(context)!.documentScanImportFile
                      : S.of(context)!.documentScanTakePhoto,
              style: MintTextStyles.titleMedium().copyWith(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: S.of(context)!.docScanFromGallery,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _onGalleryPressed,
            icon: const Icon(Icons.photo_library_outlined, size: 22),
            label: Text(
              S.of(context)!.docScanFromGallery,
              style: MintTextStyles.titleMedium().copyWith(fontWeight: FontWeight.w600),
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
          S.of(context)!.docScanPasteOcrText,
          style: MintTextStyles.bodyLarge().copyWith(fontWeight: FontWeight.w600),
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
          S.of(context)!.docScanUseExample,
          style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600),
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

  Widget _buildPreValidationError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_outlined, size: 18, color: MintColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _preValidationError!,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                ),
                if (_preValidationHint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _preValidationHint!,
                    style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 18, color: MintColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S.of(context)!.docScanPrivacyNote,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCameraPressed() async {
    // v2.7 Phase 29 / PRIV-01 — granular consent gate (nLPD art. 6 al. 6).
    final granted = await ConsentService().requireGrantedOrPrompt(
      context,
      const [
        ConsentPurpose.visionExtraction,
        ConsentPurpose.persistence365d,
        ConsentPurpose.transferUsAnthropic,
      ],
    );
    if (!granted) return;
    if (!mounted) return;

    // Web/desktop have no native scanner — degrade gracefully to gallery upload.
    if (!NativeDocumentScanner.isAvailable) {
      await _onGalleryPressed();
      return;
    }

    try {
      // Phase 28-03 — VisionKit (iOS) / ML Kit Document Scanner (Android).
      // Auto crop + deskew + shadow removal happen client-side, gratis,
      // offline. Multi-page natively supported (capped at 5 here).
      final pages = await NativeDocumentScanner.scan(maxPages: 5);
      if (pages == null || pages.isEmpty) return; // user cancelled
      // Pipeline today consumes one page at a time; we ship the first page
      // and queue the rest for the streaming flow in 28-04.
      final firstFile = await _materializeBytesAsXFile(pages.first);
      await _processImageFile(firstFile);
    } on DocumentScannerException catch (e) {
      debugPrint('[DocumentScan] Scanner error: ${e.code}');
      if (!mounted) return;
      _showErrorSnack(S.of(context)!.docScanScannerError);
    } catch (e) {
      debugPrint('[DocumentScan] Unexpected scanner error: $e');
      if (!mounted) return;
      _showErrorSnack(S.of(context)!.docScanCameraError);
    }
  }

  /// Phase 28-03 — write scanned bytes to a temp JPEG so the rest of the
  /// pipeline (which expects [XFile.path]) keeps working unchanged.
  Future<XFile> _materializeBytesAsXFile(Uint8List bytes) async {
    final tmpDir = await getTemporaryDirectory();
    final path =
        '${tmpDir.path}/mint_scan_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(bytes, flush: true);
    return XFile(path);
  }

  Future<void> _onGalleryPressed() async {
    // v2.7 Phase 29 / PRIV-01 — granular consent gate (nLPD art. 6 al. 6).
    // Guarded here too because _onGalleryPressed is sometimes called directly
    // (from _onCameraPressed fallback path). requireGrantedOrPrompt is a no-op
    // when all required purposes are already granted at the current policy
    // version, so the double-check has zero UX cost.
    final granted = await ConsentService().requireGrantedOrPrompt(
      context,
      const [
        ConsentPurpose.visionExtraction,
        ConsentPurpose.persistence365d,
        ConsentPurpose.transferUsAnthropic,
      ],
    );
    if (!granted) return;
    if (!mounted) return;

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
          if (!mounted) return;
          _showErrorSnack(S.of(context)!.docScanEmptyTextFile);
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
        if (!mounted) return;
        await _showOcrRecoverySheet(
          title: S.of(context)!.docScanFileUnreadableTitle,
          message: S.of(context)!.docScanFileUnreadableMessage,
        );
        return;
      }

      await _processImageFile(XFile(localPath));
    } catch (e) {
      debugPrint('[DocumentScan] Import error: $e');
      if (!mounted) return;
      _showErrorSnack(S.of(context)!.docScanGenericError);
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
    // Client-side file validation: size and format checks.
    if (!kIsWeb) {
      final fileObj = File(file.path);
      if (fileObj.existsSync()) {
        final fileSize = fileObj.lengthSync();
        if (fileSize > _maxFileSizeBytes) {
          if (!mounted) return;
          setState(() {
            _preValidationError = S.of(context)!.docFileTooLarge;
            _preValidationHint = null;
          });
          return;
        }
      }
      final ext = file.path.split('.').last.toLowerCase();
      if (!_acceptedExtensions.contains(ext)) {
        if (!mounted) return;
        setState(() {
          _preValidationError = S.of(context)!.docWrongFormat;
          _preValidationHint = null;
        });
        return;
      }
    }

    // Phase 28-03 — local pre-reject before paying ~3500 Vision tokens + 15s
    // for clearly non-financial images (food, selfie, landscape, pet, meme).
    // Web is skipped (labeler unavailable). PDFs short-circuit inside the
    // classifier itself (not labeled). Failure mode is fail-open.
    if (!kIsWeb) {
      try {
        final classifier = imageClassifierOverride ?? LocalImageClassifier();
        final bytes = await file.readAsBytes();
        final decision = await classifier.shouldRejectAsNonFinancial(bytes);
        if (decision.reject) {
          if (!mounted) return;
          setState(() {
            _preValidationError = S.of(context)!.docScanRejectedNonFinancial;
            _preValidationHint = null;
          });
          _cleanupTempFile(file.path);
          return;
        }
      } catch (_) {
        // Fail-open: never block a legit doc on classifier hiccup.
      }
    }

    setState(() {
      _isProcessing = true;
      _preValidationError = null;
      _preValidationHint = null;
    });

    try {
      // Strategy: Claude Vision (backend) FIRST, MLKit OCR as fallback.
      // Vision understands Swiss document context, OCR only reads text.
      final visionResult = await _tryVisionExtraction(file);
      if (visionResult != null && mounted) {
        await context.push('/scan/review', extra: visionResult);
        return;
      }

      // If 422 rejection was shown, don't fall through to OCR
      if (_preValidationError != null) return;

      // Fallback: local MLKit OCR (for offline or when Vision fails)
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
          title: S.of(context)!.docScanOcrNotDetectedTitle,
          message: S.of(context)!.docScanOcrNotDetectedMessage,
          imageFile: file,
        );
        return;
      }

      await _processOcrText(extractedText);
    } catch (_) {
      if (!mounted) return;
      await _showOcrRecoverySheet(
        title: S.of(context)!.docScanPhotoAnalysisTitle,
        message: S.of(context)!.docScanPhotoAnalysisMessage,
        imageFile: file,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
      _cleanupTempFile(file.path); // FIX-053
    }
  }

  /// Try Claude Vision extraction via backend API.
  /// Returns ExtractionResult if successful, null otherwise.
  Future<ExtractionResult?> _tryVisionExtraction(XFile file) async {
    // Read context-dependent values BEFORE async gap
    final canton = Provider.of<CoachProfileProvider>(context, listen: false)
        .profile?.canton;
    final visionDisclaimer = S.of(context)!.documentVisionDisclaimer;
    try {
      final rawBytes = await file.readAsBytes();
      // TODO(P2-W12): Strip EXIF metadata before Vision API call.
      // Requires `image` package. GPS location and camera info currently exposed.
      final bytes = await _compressForVision(rawBytes, file.path);
      final base64Image = base64Encode(bytes);

      final response = await DocumentService.extractWithVision(
        imageBase64: base64Image,
        // Convert camelCase enum to snake_case for backend contract.
        documentType: _selectedType.name
            .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}'),
        canton: canton,
        languageHint: 'fr',
      );

      if (response == null) return null;

      final extractedFields = (response['extractedFields'] as List?)
          ?.map<ExtractedField>((f) {
            final map = f as Map<String, dynamic>;
            final conf = _parseConfidence(map['confidence'] as String?);
            return ExtractedField(
              fieldName: map['fieldName'] as String? ?? '',
              label: map['fieldName'] as String? ?? '',
              value: map['value'],
              confidence: conf,
              sourceText: (map['sourceText'] as String?) ?? '',
              profileField: map['fieldName'] as String?,
              needsReview: conf < 0.80,
            );
          })
          .toList();

      if (extractedFields == null || extractedFields.isEmpty) return null;

      return ExtractionResult(
        documentType: _selectedType,
        fields: extractedFields,
        overallConfidence: (response['overallConfidence'] as num?)?.toDouble() ?? 0.5,
        confidenceDelta: _confidenceDeltaForType(_selectedType),
        warnings: const [],
        disclaimer: visionDisclaimer,
        sources: const ['Claude Vision API'],
        planType: response['planType'] as String?,
        planTypeWarning: response['planTypeWarning'] as String?,
        coherenceWarnings: (response['coherenceWarnings'] as List?)
            ?.map((e) => e.toString())
            .toList() ?? const [],
      );
    } on DocumentServiceException catch (e) {
      debugPrint('[DocumentScan] Vision error: code=${e.code} msg=${e.message}');
      if (!mounted) return null;
      switch (e.code) {
        case 'not_financial':
          setState(() {
            _isProcessing = false;
            _preValidationError = S.of(context)!.docNotFinancial;
            _preValidationHint = S.of(context)!.docNotFinancialHint;
          });
        case 'file_too_large':
          _showErrorSnack(e.message);
        case 'upload_failed':
          _showErrorSnack(S.of(context)!.docScanScannerError);
        default:
          _showErrorSnack(S.of(context)!.docScanGenericError);
      }
      return null;
    } on TimeoutException catch (_) {
      debugPrint('[DocumentScan] Vision extraction timed out');
      if (mounted) {
        _showErrorSnack(S.of(context)!.docScanScannerError);
      }
      return null;
    } catch (e) {
      debugPrint('[DocumentScan] Vision extraction failed: $e');
      return null;
    }
  }

  /// Vision API fallback for PDF files when backend Docling fails.
  /// Reads PDF bytes, encodes to base64, and calls Claude Vision extraction.
  Future<ExtractionResult?> _tryVisionExtractionFromPdf(String pdfPath) async {
    // Read context-dependent values BEFORE async gap
    final canton = Provider.of<CoachProfileProvider>(context, listen: false)
        .profile?.canton;
    final visionDisclaimer = S.of(context)!.documentVisionDisclaimer;
    try {
      final bytes = await File(pdfPath).readAsBytes();
      final base64Pdf = base64Encode(bytes);

      final response = await DocumentService.extractWithVision(
        imageBase64: base64Pdf,
        documentType: _selectedType.name
            .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}'),
        canton: canton,
        languageHint: 'fr',
      );

      if (response == null) return null;

      final extractedFields = (response['extractedFields'] as List?)
          ?.map<ExtractedField>((f) {
            final map = f as Map<String, dynamic>;
            final conf = _parseConfidence(map['confidence'] as String?);
            return ExtractedField(
              fieldName: map['fieldName'] as String? ?? '',
              label: map['fieldName'] as String? ?? '',
              value: map['value'],
              confidence: conf,
              sourceText: (map['sourceText'] as String?) ?? '',
              profileField: map['fieldName'] as String?,
              needsReview: conf < 0.80,
            );
          })
          .toList();

      if (extractedFields == null || extractedFields.isEmpty) return null;

      return ExtractionResult(
        documentType: _selectedType,
        fields: extractedFields,
        overallConfidence: (response['overallConfidence'] as num?)?.toDouble() ?? 0.5,
        confidenceDelta: _confidenceDeltaForType(_selectedType),
        warnings: const [],
        disclaimer: visionDisclaimer,
        sources: const ['Claude Vision API (PDF)'],
        planType: response['planType'] as String?,
        planTypeWarning: response['planTypeWarning'] as String?,
        coherenceWarnings: (response['coherenceWarnings'] as List?)
            ?.map((e) => e.toString())
            .toList() ?? const [],
      );
    } catch (e) {
      debugPrint('[DocumentScan] Vision PDF fallback failed: $e');
      return null;
    }
  }

  double _parseConfidence(String? level) {
    return switch (level) {
      'high' => 0.95,
      'medium' => 0.70,
      'low' => 0.40,
      _ => 0.50,
    };
  }

  double _confidenceDeltaForType(DocumentType type) {
    return switch (type) {
      DocumentType.lppCertificate => 27.0,
      DocumentType.avsExtract => 22.0,
      DocumentType.taxDeclaration => 17.0,
      DocumentType.salaryCertificate => 20.0,
      _ => 10.0,
    };
  }

  Future<void> _processOcrText(String text) async {
    if (!mounted) return;

    setState(() => _isProcessing = true);
    try {
      final result = _parseByDocumentType(text);
      if (result.fields.isEmpty) {
        await _requestManualOcrText(
          title: S.of(context)!.docScanNoFieldRecognized,
          hint: S.of(context)!.docScanNoFieldHint,
          initialText: text,
        );
        return;
      }

      if (!mounted) return;
      await context.push('/scan/review', extra: result);
    } catch (e) {
      debugPrint('[DocumentScan] Parsing error: $e');
      if (!mounted) return;
      _showErrorSnack(S.of(context)!.docScanGenericError);
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.white,
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
                style: MintTextStyles.titleLarge(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                hint,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                minLines: 5,
                decoration: InputDecoration(
                  hintText: S.of(context)!.docScanOcrPasteHint,
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
                      onPressed: () => ctx.pop(false),
                      child: Text(S.of(context)!.documentScanCancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => ctx.pop(true),
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
      if (!mounted) return;
      await _showPdfImportFallback(
        title: S.of(context)!.docScanPdfDetected,
        message: S.of(context)!.docScanPdfCannotRead,
      );
      return;
    }

    if (!kIsWeb) {
      final parse = await _processPdfViaBackend(localPath);
      if (parse.success) return;
      if (parse.requiresAuthentication) {
        await _showPdfAuthRequiredSheet();
        return;
      }
      // Fallback: try Vision API with PDF bytes as base64
      if (!parse.success && !parse.requiresAuthentication) {
        final visionResult = await _tryVisionExtractionFromPdf(localPath);
        if (visionResult != null && mounted) {
          await context.push('/scan/review', extra: visionResult);
          return;
        }
      }
      if (!mounted) return;
      await _showPdfImportFallback(
        title: S.of(context)!.docScanPdfAnalysisUnavailable,
        message: parse.errorMessage ?? S.of(context)!.docScanPdfNotParsed,
      );
      return;
    }

    if (!mounted) return;
    await _showPdfImportFallback(
      title: S.of(context)!.docScanPdfDetected,
      message: S.of(context)!.docScanPdfNotAvailable,
    );
  }

  Future<void> _showPdfImportFallback({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.white,
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
                style: MintTextStyles.titleLarge(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                message,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    ctx.pop();
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
                    ctx.pop();
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
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.white,
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
                style: MintTextStyles.titleLarge(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                S.of(context)!.documentScanPdfAuthContent,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    ctx.pop();
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
                    ctx.pop();
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
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.white,
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
                style: MintTextStyles.titleLarge(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                message,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
              ),
              if (showVision) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      ctx.pop();
                      _processImageViaVision(imageFile);
                    },
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(S.of(context)!.docScanVisionAnalyze),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      foregroundColor: MintColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    S.of(context)!.docScanVisionDisclaimer,
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              SizedBox(height: showVision ? 8 : 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ctx.pop();
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
                    ctx.pop();
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
    // P1-8: Removed allowMalformed: true — reject malformed UTF-8 in scanned docs.
    try {
      if (file.bytes != null) {
        return utf8.decode(file.bytes!);
      }
      if (file.path != null && file.path!.isNotEmpty) {
        final bytes = await XFile(file.path!).readAsBytes();
        return utf8.decode(bytes);
      }
    } on FormatException catch (e) {
      debugPrint('[DocumentScan] Malformed UTF-8 in file: $e');
    }
    return '';
  }

  /// Compress image bytes if they exceed [_visionCompressThresholdBytes].
  ///
  /// Resizes to max 1920px on the longest side and re-encodes as JPEG at 85%
  /// quality. Uses dart:ui decoding which is available on all Flutter platforms.
  /// Returns original bytes unchanged for PDFs or if already small enough.
  Future<Uint8List> _compressForVision(Uint8List bytes, String filePath) async {
    // Skip compression for PDFs — Vision API handles them natively.
    if (filePath.toLowerCase().endsWith('.pdf')) return bytes;

    if (bytes.length <= _visionCompressThresholdBytes) return bytes;

    try {
      const maxDimension = 1920;
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxDimension,
        targetHeight: maxDimension,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Re-encode as PNG (dart:ui toByteData), then let the API handle it.
      // dart:ui doesn't expose JPEG encoding, but resizing alone cuts
      // a 10 MP photo (≈8 MB) down to ≈1-2 MB at 1920px.
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();

      if (byteData != null) {
        final compressed = byteData.buffer.asUint8List();
        debugPrint(
          '[DocumentScan] Compressed ${bytes.length} → ${compressed.length} bytes '
          '(${(compressed.length / bytes.length * 100).toStringAsFixed(0)}%)',
        );
        return compressed;
      }
    } catch (e) {
      debugPrint('[DocumentScan] Compression failed, using original: $e');
    }
    return bytes;
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

  /// FIX-053: Clean up temporary files created by _resolveLocalPath().
  void _cleanupTempFile(String? path) {
    if (path == null || !path.contains('mint_upload_')) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Best-effort cleanup — don't crash on permission issues.
    }
  }

  /// Map scan-screen DocumentType to backend VaultDocumentType.
  VaultDocumentType _toVaultType(DocumentType type) {
    return switch (type) {
      DocumentType.lppCertificate => VaultDocumentType.lppCertificate,
      DocumentType.salaryCertificate => VaultDocumentType.salaryCertificate,
      DocumentType.threeAAttestation => VaultDocumentType.pillar3aAttestation,
      _ => VaultDocumentType.other,
    };
  }

  Future<_PdfParseResult> _processPdfViaBackend(String path) async {
    if (kIsWeb) {
      return _PdfParseResult(
        success: false,
        errorMessage:
            S.of(context)!.docScanPdfTypeUnsupported,
      );
    }

    setState(() => _isProcessing = true);
    try {
      final upload = await DocumentService().uploadDocument(
        File(path),
        type: _toVaultType(_selectedType),
      );
      final extraction = _mapLppUploadToExtraction(upload);
      if (extraction.fields.isEmpty) {
        if (!mounted) {
          return const _PdfParseResult(success: false);
        }
        return _PdfParseResult(
          success: false,
          errorMessage: S.of(context)!.docScanPdfNoData,
        );
      }
      if (!mounted) return const _PdfParseResult(success: true);
      await context.push('/scan/review', extra: extraction);
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
        errorMessage: mounted
            ? S.of(context)!.docScanGenericError
            : 'PDF parsing error',
      );
    } catch (e) {
      debugPrint('[DocumentScan] Backend PDF parsing unavailable: $e');
      return _PdfParseResult(
        success: false,
        errorMessage: mounted
            ? S.of(context)!.docScanGenericError
            : 'PDF parsing error',
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
            S.of(context)!.docScanBackendDisclaimer,
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
      label: S.of(context)!.docScanLabelLppTotal,
      value: lpp.avoirVieillesseTotal,
      profileField: 'avoirLppTotal',
    );
    addField(
      fieldName: 'avoir_obligatoire',
      label: S.of(context)!.docScanLabelObligatoire,
      value: lpp.avoirObligatoire,
      profileField: 'lppObligatoire',
    );
    addField(
      fieldName: 'avoir_surobligatoire',
      label: S.of(context)!.docScanLabelSurobligatoire,
      value: lpp.avoirSurobligatoire,
      profileField: 'lppSurobligatoire',
    );
    addField(
      fieldName: 'taux_conversion_obligatoire',
      label: S.of(context)!.docScanLabelTauxConvOblig,
      value: lpp.tauxConversionObligatoire,
      profileField: 'tauxConversionOblig',
    );
    addField(
      fieldName: 'taux_conversion_surobligatoire',
      label: S.of(context)!.docScanLabelTauxConvSuroblig,
      value: lpp.tauxConversionSurobligatoire,
      profileField: 'tauxConversionSuroblig',
    );
    addField(
      fieldName: 'rachat_maximum',
      label: S.of(context)!.docScanLabelRachatMax,
      value: lpp.rachatMaximum,
      profileField: 'buybackPotential',
    );
    addField(
      fieldName: 'salaire_assure',
      label: S.of(context)!.docScanLabelSalaireAssure,
      value: lpp.salaireAssure,
      profileField: 'lppInsuredSalary',
    );
    addField(
      fieldName: 'remuneration_rate',
      label: S.of(context)!.docScanLabelTauxRemuneration,
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
          S.of(context)!.docScanBackendDisclaimerShort,
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
      _showErrorSnack(S.of(context)!.docScanVisionConfigError);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final rawBytes = await file.readAsBytes();
      // TODO(P2-W12): Strip EXIF metadata before Vision API call.
      // Requires `image` package. GPS location and camera info currently exposed.
      final bytes = await _compressForVision(rawBytes, file.path);
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
        if (!mounted) return;
        _showErrorSnack(S.of(context)!.docScanVisionNoFields);
        return;
      }

      if (!mounted) return;
      final result = ExtractionResult(
        documentType: _selectedType,
        fields: fields,
        overallConfidence: fields.fold<double>(0, (sum, f) => sum + f.confidence) /
            fields.length,
        confidenceDelta: visionResponse.confidenceDelta.toDouble(),
        warnings: const [],
        disclaimer: visionResponse.disclaimers.isNotEmpty
            ? visionResponse.disclaimers.first
            : S.of(context)!.docScanVisionDefaultDisclaimer,
        sources: const ['Extraction Vision IA (BYOK)'],
      );

      await context.push('/scan/review', extra: result);
    } on RagApiException catch (e) {
      _showErrorSnack(e.message);
    } catch (e) {
      debugPrint('[DocumentScan] Vision error: $e');
      if (!mounted) return;
      _showErrorSnack(S.of(context)!.docScanGenericError);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: MintTextStyles.bodySmall()),
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
