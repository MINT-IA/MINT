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
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:mint_mobile/services/native_document_scanner.dart';
import 'package:mint_mobile/services/local_image_classifier.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/document_parser/avs_extract_parser.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';
import 'package:mint_mobile/services/document_parser/salary_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/tax_declaration_parser.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/rag_error_localizations.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/consent/partner_accountability_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:uuid/uuid.dart';

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

typedef DocumentScanFilePicker = Future<PlatformFile?> Function();
typedef DocumentScanFileBytesReader = Future<Uint8List> Function(String path);
typedef DocumentScanDocumentHasher = String Function(Uint8List bytes);

typedef DocumentScanConsentRequester = Future<bool> Function(
  BuildContext context,
  List<ConsentPurpose> purposes,
);

typedef DocumentScanVisionExtractor = Future<Map<String, dynamic>?> Function({
  required String imageBase64,
  required String documentType,
  String? canton,
  String? languageHint,
  String? subjectKind,
  String? receiptId,
});

typedef DocumentScanPdfUploader = Future<DocumentUploadResult> Function(
  File file, {
  required VaultDocumentType type,
});

typedef PartnerExternalGateResolver = PartnerAccountabilityExternalGate?
    Function();
typedef DocumentScanReviewNavigator = Future<void> Function(
  BuildContext context,
  String scanSessionId,
);
typedef DocumentScanTempFileWriter = Future<void> Function(
  File file,
  Uint8List bytes,
);

final class _LppAcquisitionDecision {
  const _LppAcquisitionDecision({
    required this.acquisitionId,
    required this.subject,
    required this.partnerAttested,
    required this.policyVersion,
    required this.declaredAt,
    this.manualPartnerOwnerId,
    this.receiptId,
    this.receiptCreated = false,
    this.accountabilityContext,
  });

  final String acquisitionId;
  final LppEvidenceOwnerKind subject;
  final bool partnerAttested;
  final String policyVersion;
  final DateTime declaredAt;
  final String? manualPartnerOwnerId;
  final String? receiptId;
  final bool receiptCreated;
  final ManualPartnerAccountabilityContext? accountabilityContext;

  bool isValidAt(DateTime now) => LppAcquisitionAuthorization.hasValidEnvelope(
        acquisitionId: acquisitionId,
        subject: subject,
        partnerAttested: partnerAttested,
        policyVersion: policyVersion,
        declaredAt: declaredAt,
        now: now,
      );

  LppAcquisitionAuthorization bindDocument(
    Uint8List transmittedBytes,
    DocumentScanDocumentHasher hashDocumentBytes,
  ) {
    return LppAcquisitionAuthorization(
      acquisitionId: acquisitionId,
      subject: subject,
      partnerAttested: partnerAttested,
      policyVersion: policyVersion,
      declaredAt: declaredAt,
      documentSha256: hashDocumentBytes(transmittedBytes),
      manualPartnerOwnerId: manualPartnerOwnerId,
      receiptId: receiptId,
    );
  }

  _LppAcquisitionDecision withReceiptCreated(
    PartnerAccountabilityReceipt receipt,
  ) =>
      _LppAcquisitionDecision(
        acquisitionId: acquisitionId,
        subject: subject,
        partnerAttested: partnerAttested,
        policyVersion: policyVersion,
        declaredAt: declaredAt,
        manualPartnerOwnerId: manualPartnerOwnerId,
        receiptId: receiptId,
        receiptCreated: true,
        accountabilityContext: ManualPartnerAccountabilityContext(
          receiptId: receipt.receiptId,
          ownerId: manualPartnerOwnerId!,
          expiresAt: receipt.expiresAt!,
          noticeVersion: receipt.noticeVersion,
          policyVersion: receipt.policyVersion,
          receiptStatus: receipt.status,
        ),
      );
}

final class _DocumentVisionResult {
  const _DocumentVisionResult({
    required this.extraction,
    this.lppAuthorization,
    this.manualPartnerAccountability,
  });

  final ExtractionResult extraction;
  final LppAcquisitionAuthorization? lppAuthorization;
  final ManualPartnerAccountabilityContext? manualPartnerAccountability;
}

class DocumentScanScreen extends StatefulWidget {
  final DocumentType? initialType;
  final String Function()? taxSnapshotIdFactory;
  final DocumentScanFilePicker? pickFile;
  final DocumentScanFileBytesReader? readFileBytes;
  final String Function()? lppAcquisitionIdFactory;
  final DateTime Function()? now;
  final DocumentScanDocumentHasher? hashDocumentBytes;
  final DocumentScanConsentRequester? requireConsent;
  final DocumentScanVisionExtractor? visionExtractor;
  final DocumentScanPdfUploader? uploadDocument;
  final PartnerAccountabilityBindingStore? partnerBindingStore;
  final PartnerAccountabilityService? partnerAccountabilityService;
  final Future<bool> Function()? isAuthenticated;
  final PartnerAccountabilityExternalGate? partnerExternalGate;
  final PartnerExternalGateResolver? partnerExternalGateResolver;
  final String Function()? partnerOwnerIdFactory;
  final String Function()? partnerReceiptIdFactory;

  /// Test seam for observing or failing the volatile review handoff.
  @visibleForTesting
  final DocumentScanReviewNavigator? navigateToReview;

  /// Test seam for verifying cleanup of screen-owned byte-only temp files.
  @visibleForTesting
  final DocumentScanTempFileWriter? writeOwnedTempFile;

  const DocumentScanScreen({
    super.key,
    this.initialType,
    this.taxSnapshotIdFactory,
    this.pickFile,
    this.readFileBytes,
    this.lppAcquisitionIdFactory,
    this.now,
    this.hashDocumentBytes,
    this.requireConsent,
    this.visionExtractor,
    this.uploadDocument,
    this.partnerBindingStore,
    this.partnerAccountabilityService,
    this.isAuthenticated,
    this.partnerExternalGate,
    this.partnerExternalGateResolver,
    this.partnerOwnerIdFactory,
    this.partnerReceiptIdFactory,
    this.navigateToReview,
    this.writeOwnedTempFile,
  });

  @override
  State<DocumentScanScreen> createState() => _DocumentScanScreenState();
}

class _DocumentScanScreenState extends State<DocumentScanScreen> {
  static const _supportedTypes = <DocumentType>{
    DocumentType.lppCertificate,
    DocumentType.taxDeclaration,
    DocumentType.avsExtract,
    DocumentType.salaryCertificate,
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
  final Set<String> _ownedTempPaths = <String>{};
  final Set<String> _partnerReceiptsHandedToReview = <String>{};
  final Set<String> _terminalPartnerReceiptIds = <String>{};
  final Set<String> _erasedPartnerReceiptIds = <String>{};
  late final PartnerAccountabilityBindingStore _partnerBindingStore =
      widget.partnerBindingStore ?? PartnerAccountabilityBindingStore();
  late final PartnerAccountabilityService _partnerAccountabilityService =
      widget.partnerAccountabilityService ?? PartnerAccountabilityService();

  PartnerAccountabilityExternalGate? get _currentPartnerExternalGate {
    final resolver = widget.partnerExternalGateResolver;
    final gate = resolver == null ? widget.partnerExternalGate : resolver();
    return FeatureFlags.partnerLppAccountabilityEnabled &&
            gate != null &&
            gate.isCurrentAt(_currentTime())
        ? gate
        : null;
  }

  bool get _taxAssessmentEnabled => FeatureFlags.taxAssessmentIngestionEnabled;
  bool get _lppEvidenceEnabled => FeatureFlags.lppEvidenceIngestionEnabled;

  bool _isSupportedType(DocumentType type) =>
      _supportedTypes.contains(type) &&
      (type != DocumentType.lppCertificate || _lppEvidenceEnabled) &&
      (type != DocumentType.taxDeclaration || _taxAssessmentEnabled);

  DocumentType get _defaultSupportedType =>
      DocumentType.values.firstWhere(_isSupportedType);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialType;
    if (initial != null && _isSupportedType(initial)) {
      _selectedType = initial;
    } else if (!_isSupportedType(_selectedType)) {
      _selectedType = _defaultSupportedType;
    }
  }

  @override
  void dispose() {
    for (final path in _ownedTempPaths.toList(growable: false)) {
      _cleanupTempFile(path);
    }
    super.dispose();
  }

  DateTime _currentTime() => (widget.now ?? DateTime.now)().toUtc();

  bool get _lppAcquisitionStillEnabled =>
      _selectedType != DocumentType.lppCertificate ||
      FeatureFlags.lppEvidenceIngestionEnabled;

  bool _lppAcquisitionStillEnabledFor(_LppAcquisitionDecision? decision) =>
      _lppAcquisitionStillEnabled &&
      (decision?.subject != LppEvidenceOwnerKind.manualPartner ||
          (FeatureFlags.partnerLppAccountabilityEnabled &&
              !_terminalPartnerReceiptIds.contains(decision?.receiptId)));

  Future<_LppAcquisitionDecision?> _authorizeLppBeforeAcquisition({
    bool syntheticLocal = false,
  }) async {
    if (_selectedType != DocumentType.lppCertificate ||
        !FeatureFlags.typedLppEvidence ||
        !FeatureFlags.documentLppEvidenceEnabled) {
      return null;
    }

    final l10n = S.of(context)!;
    final hasLocalPartnerProfile =
        context.read<CoachProfileProvider>().profile?.conjoint != null;
    final LppEvidenceOwnerKind? subject;
    if (!hasLocalPartnerProfile) {
      subject = await showDialog<LppEvidenceOwnerKind>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          key: const Key('lpp_acquisition_self_gate'),
          title: Text(l10n.lppAcquisitionSelfTitle),
          content: Text(l10n.lppAcquisitionSelfBody),
          actions: [
            TextButton(
              key: const Key('lpp_acquisition_cancel'),
              onPressed: () => dialogContext.pop(),
              child: Text(l10n.documentScanCancel),
            ),
            FilledButton(
              key: const Key('lpp_acquisition_self_continue'),
              onPressed: () => dialogContext.pop(LppEvidenceOwnerKind.self),
              child: Text(l10n.lppAcquisitionSelfContinue),
            ),
          ],
        ),
      );
    } else {
      subject = await showDialog<LppEvidenceOwnerKind>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          key: const Key('lpp_acquisition_owner_gate'),
          title: Text(l10n.lppAcquisitionOwnerTitle),
          actions: [
            TextButton(
              key: const Key('lpp_acquisition_cancel'),
              onPressed: () => dialogContext.pop(),
              child: Text(l10n.documentScanCancel),
            ),
            OutlinedButton(
              key: const Key('lpp_acquisition_owner_self'),
              onPressed: () => dialogContext.pop(LppEvidenceOwnerKind.self),
              child: Text(l10n.lppAcquisitionOwnerSelf),
            ),
            FilledButton(
              key: const Key('lpp_acquisition_owner_manual_partner'),
              onPressed: () =>
                  dialogContext.pop(LppEvidenceOwnerKind.manualPartner),
              child: Text(l10n.lppAcquisitionOwnerPartner),
            ),
          ],
        ),
      );
    }
    if (subject == null || !mounted || !_lppAcquisitionStillEnabled) {
      return null;
    }

    var partnerAttested = false;
    String? manualPartnerOwnerId;
    String? receiptId;
    if (subject == LppEvidenceOwnerKind.manualPartner) {
      final externalGate = _currentPartnerExternalGate;
      if (externalGate == null) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const Key('lpp_partner_external_gate_blocked'),
            title: Text(l10n.lppPartnerNoticeTitle),
            content: Text(l10n.lppPartnerExternalGateBlocked),
            actions: [
              TextButton(
                onPressed: dialogContext.pop,
                child: Text(l10n.documentScanCancel),
              ),
            ],
          ),
        );
        return null;
      }
      final noticeAccepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          key: const Key('lpp_partner_notice_gate'),
          title: Text(l10n.lppPartnerNoticeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.lppPartnerNoticeSummary(
                  externalGate.controllerIdentity,
                  externalGate.privacyContact,
                  externalGate.recipient,
                  externalGate.processingRegions,
                  externalGate.transferMechanism,
                  externalGate.retentionContract,
                ),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                l10n.lppPartnerNoticeVersion(
                  externalGate.noticeVersion,
                  externalGate.effectiveAt.toIso8601String().split('T').first,
                ),
                key: const Key('lpp_partner_notice_version'),
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('lpp_partner_notice_open'),
              onPressed: () => _showPartnerInformation(
                title: l10n.lppPartnerNoticeTitle,
                body: l10n.lppPartnerNoticeSummary(
                  externalGate.controllerIdentity,
                  externalGate.privacyContact,
                  externalGate.recipient,
                  externalGate.processingRegions,
                  externalGate.transferMechanism,
                  externalGate.retentionContract,
                ),
              ),
              child: Text(l10n.lppPartnerNoticeOpen),
            ),
            TextButton(
              key: const Key('lpp_partner_rights_link'),
              onPressed: () => _showPartnerInformation(
                title: l10n.lppPartnerRightsOpen,
                body:
                    '${externalGate.rightsChannel}\n${externalGate.privacyContact}',
              ),
              child: Text(l10n.lppPartnerRightsOpen),
            ),
            TextButton(
              onPressed: () => dialogContext.pop(false),
              child: Text(l10n.documentScanCancel),
            ),
            FilledButton(
              key: const Key('lpp_partner_notice_continue'),
              onPressed: () => dialogContext.pop(true),
              child: Text(l10n.lppPartnerAuthorizationContinue),
            ),
          ],
        ),
      );
      if (noticeAccepted != true || !mounted) return null;

      final authenticated =
          await (widget.isAuthenticated ?? AuthService.isLoggedIn)();
      if (!authenticated || !mounted) {
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              key: const Key('lpp_partner_auth_required'),
              title: Text(l10n.lppPartnerNoticeTitle),
              content: Text(l10n.lppPartnerAuthRequired),
              actions: [
                TextButton(
                  onPressed: dialogContext.pop,
                  child: Text(l10n.documentScanCancel),
                ),
              ],
            ),
          );
        }
        return null;
      }
      var declarationChecked = false;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            key: const Key('lpp_acquisition_partner_attestation'),
            title: Text(l10n.lppAcquisitionPartnerAttestationTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  key: const Key('lpp_partner_authorization_declaration'),
                  value: declarationChecked,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) => setDialogState(
                    () => declarationChecked = value == true,
                  ),
                  title: Text(
                    syntheticLocal
                        ? l10n.lppAcquisitionSyntheticPartnerAttestationBody
                        : l10n.lppPartnerAuthorizationDeclaration(
                            externalGate.noticeVersion,
                          ),
                  ),
                ),
                Text(
                  l10n.lppAcquisitionPartnerAttestationNote,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
            ),
            actions: [
              TextButton(
                key: const Key('lpp_acquisition_cancel'),
                onPressed: () => dialogContext.pop(false),
                child: Text(l10n.documentScanCancel),
              ),
              FilledButton(
                key: const Key('lpp_partner_authorization_continue'),
                onPressed:
                    declarationChecked ? () => dialogContext.pop(true) : null,
                child: Text(l10n.lppPartnerAuthorizationContinue),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true ||
          !mounted ||
          !_lppAcquisitionStillEnabled ||
          !FeatureFlags.partnerLppAccountabilityEnabled) {
        return null;
      }
      partnerAttested = true;

      final envelope = await _partnerBindingStore.load();
      final pending = envelope.pending;
      manualPartnerOwnerId = pending?.manualPartnerOwnerId ??
          envelope.active?.manualPartnerOwnerId ??
          (widget.partnerOwnerIdFactory ?? const Uuid().v4)();
      receiptId = pending?.receiptId ??
          (widget.partnerReceiptIdFactory ?? const Uuid().v4)();
      if (!FeatureFlags.partnerLppAccountabilityEnabled) return null;
      try {
        await _partnerBindingStore.beginPending(
          receiptId: receiptId,
          manualPartnerOwnerId: manualPartnerOwnerId,
          now: _currentTime(),
          noticeVersion: externalGate.noticeVersion,
          policyVersion: externalGate.policyVersion,
          privacyContact: externalGate.privacyContact,
          rightsChannel: externalGate.rightsChannel,
        );
      } catch (_) {
        return null;
      }
    }

    if (!_lppAcquisitionStillEnabled ||
        (subject == LppEvidenceOwnerKind.manualPartner &&
            !FeatureFlags.partnerLppAccountabilityEnabled)) {
      if (manualPartnerOwnerId != null && receiptId != null) {
        await _partnerBindingStore.rollback(
          receiptId: receiptId,
          manualPartnerOwnerId: manualPartnerOwnerId,
        );
      }
      return null;
    }

    final decision = _LppAcquisitionDecision(
      acquisitionId: (widget.lppAcquisitionIdFactory ?? const Uuid().v4)(),
      subject: subject,
      partnerAttested: partnerAttested,
      policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
      declaredAt: _currentTime(),
      manualPartnerOwnerId: manualPartnerOwnerId,
      receiptId: receiptId,
    );
    return _lppAcquisitionStillEnabled && decision.isValidAt(_currentTime())
        ? decision
        : null;
  }

  Future<void> _showPartnerInformation({
    required String title,
    required String body,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: dialogContext.pop,
            child: Text(S.of(context)!.documentScanCancel),
          ),
        ],
      ),
    );
  }

  Future<bool> _requestAcquisitionConsent(
    _LppAcquisitionDecision? decision,
  ) {
    final purposes = _selectedType == DocumentType.lppCertificate
        ? decision?.subject == LppEvidenceOwnerKind.manualPartner
            ? const [ConsentPurpose.visionExtraction]
            : const [
                ConsentPurpose.visionExtraction,
                ConsentPurpose.transferUsAnthropic,
              ]
        : const [
            ConsentPurpose.visionExtraction,
            ConsentPurpose.persistence365d,
            ConsentPurpose.transferUsAnthropic,
          ];
    final requester = widget.requireConsent;
    return requester != null
        ? requester(context, purposes)
        : ConsentService().requireGrantedOrPrompt(context, purposes);
  }

  Future<void> _rollbackPartnerAttempt(_LppAcquisitionDecision? decision,
      {bool remoteReceiptCreated = false}) async {
    if (decision?.subject != LppEvidenceOwnerKind.manualPartner ||
        decision?.receiptId == null ||
        decision?.manualPartnerOwnerId == null) {
      return;
    }
    final partnerDecision = decision!;
    var shouldErase = remoteReceiptCreated || partnerDecision.receiptCreated;
    if (!shouldErase) {
      try {
        final pending = (await _partnerBindingStore.load()).pending;
        shouldErase = pending?.receiptId == partnerDecision.receiptId &&
            pending?.manualPartnerOwnerId ==
                partnerDecision.manualPartnerOwnerId &&
            pending?.hasCreatedReceipt == true;
      } catch (_) {
        // Rollback below remains the authoritative local restoration attempt.
      }
    }
    if (shouldErase) {
      final receiptId = partnerDecision.receiptId!;
      if (_erasedPartnerReceiptIds.add(receiptId)) {
        try {
          await _partnerAccountabilityService.erase(receiptId);
        } catch (_) {
          // One terminal attempt owns DELETE; later UI callbacks stay no-op.
        }
      }
    }
    await _partnerBindingStore.rollback(
      receiptId: partnerDecision.receiptId!,
      manualPartnerOwnerId: partnerDecision.manualPartnerOwnerId!,
    );
  }

  Future<void> _rollbackUnlessReviewOwns(
    _LppAcquisitionDecision? decision,
  ) async {
    final receiptId = decision?.receiptId;
    if (receiptId == null ||
        _partnerReceiptsHandedToReview.contains(receiptId)) {
      return;
    }
    await _rollbackPartnerAttempt(decision);
  }

  Future<void> _failPartnerExtraction(
    _LppAcquisitionDecision? decision,
  ) async {
    if (decision?.subject != LppEvidenceOwnerKind.manualPartner) return;
    await _rollbackPartnerAttempt(decision);
    if (!mounted) return;
    setState(() {
      _preValidationError = S.of(context)!.lppPartnerReceiptFailed;
      _preValidationHint = S.of(context)!.lppPartnerManualRecovery;
    });
  }

  Future<bool> _partnerAuthorityMatches(
    _LppAcquisitionDecision? decision,
  ) async {
    if (decision?.subject != LppEvidenceOwnerKind.manualPartner) return true;
    final receiptId = decision?.receiptId;
    if (receiptId == null || _terminalPartnerReceiptIds.contains(receiptId)) {
      return false;
    }
    final context = decision?.accountabilityContext;
    final gate = _currentPartnerExternalGate;
    final now = _currentTime();
    if (gate == null ||
        context == null ||
        !context.isActiveAt(now) ||
        gate.noticeVersion != context.noticeVersion ||
        gate.policyVersion != context.policyVersion) {
      return false;
    }
    final pending = (await _partnerBindingStore.load()).pending;
    return pending != null &&
        context.matchesPending(pending) &&
        pending.privacyContact == gate.privacyContact &&
        pending.rightsChannel == gate.rightsChannel;
  }

  Future<void> _terminalizePartnerAttempt(
    _LppAcquisitionDecision? decision,
  ) async {
    if (decision?.subject != LppEvidenceOwnerKind.manualPartner ||
        decision?.receiptId == null) {
      return;
    }
    if (!_terminalPartnerReceiptIds.add(decision!.receiptId!)) return;
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _preValidationError = S.of(context)!.lppPartnerReceiptFailed;
        _preValidationHint = null;
      });
    }
    await _rollbackPartnerAttempt(decision);
  }

  Future<bool> _revalidatePartnerByteBoundary(
    _LppAcquisitionDecision? decision,
  ) async {
    if (await _partnerAuthorityMatches(decision)) return true;
    await _terminalizePartnerAttempt(decision);
    return false;
  }

  Future<_LppAcquisitionDecision?> _ensurePartnerReceipt(
    _LppAcquisitionDecision? decision,
  ) async {
    if (decision == null ||
        decision.subject != LppEvidenceOwnerKind.manualPartner) {
      return decision;
    }
    if (decision.receiptCreated) return decision;
    while (mounted && _lppAcquisitionStillEnabledFor(decision)) {
      final externalGate = _currentPartnerExternalGate;
      if (externalGate == null) {
        await _rollbackPartnerAttempt(decision);
        return null;
      }
      try {
        final receipt = await _partnerAccountabilityService.createReceipt(
          receiptId: decision.receiptId!,
          manualPartnerOwnerId: decision.manualPartnerOwnerId!,
          noticeVersion: externalGate.noticeVersion,
          policyVersion: externalGate.policyVersion,
        );
        if (!receipt.isCurrent ||
            receipt.receiptId != decision.receiptId ||
            receipt.noticeVersion != externalGate.noticeVersion ||
            receipt.policyVersion != externalGate.policyVersion ||
            receipt.expiresAt == null ||
            !_currentTime().isBefore(receipt.expiresAt!)) {
          await _rollbackPartnerAttempt(
            decision,
            remoteReceiptCreated: true,
          );
          return null;
        }
        try {
          await _partnerBindingStore.markReceiptCreated(
            receiptId: decision.receiptId!,
            manualPartnerOwnerId: decision.manualPartnerOwnerId!,
            now: _currentTime(),
            expiresAt: receipt.expiresAt!,
          );
        } catch (_) {
          await _rollbackPartnerAttempt(
            decision,
            remoteReceiptCreated: true,
          );
          return null;
        }
        return decision.withReceiptCreated(receipt);
      } on PartnerAccountabilityException catch (error) {
        if (!error.retryable) {
          await _rollbackPartnerAttempt(decision);
          if (mounted) {
            setState(() {
              _preValidationError = S.of(context)!.lppPartnerReceiptFailed;
              _preValidationHint = null;
            });
          }
          return null;
        }
        if (!mounted) break;
        final retry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            key: const Key('lpp_partner_receipt_retry'),
            title: Text(S.of(context)!.lppPartnerReceiptRetryTitle),
            content: Text(S.of(context)!.lppPartnerReceiptRetryable),
            actions: [
              TextButton(
                onPressed: () => dialogContext.pop(false),
                child: Text(S.of(context)!.documentScanCancel),
              ),
              FilledButton(
                key: const Key('lpp_partner_receipt_pending'),
                onPressed: () => dialogContext.pop(true),
                child: Text(S.of(context)!.lppPartnerAuthorizationContinue),
              ),
            ],
          ),
        );
        if (retry != true) break;
      } catch (_) {
        await _rollbackPartnerAttempt(decision);
        if (mounted) {
          setState(() {
            _preValidationError = S.of(context)!.lppPartnerReceiptFailed;
            _preValidationHint = null;
          });
        }
        return null;
      }
    }
    await _rollbackPartnerAttempt(decision);
    return null;
  }

  LppAcquisitionAuthorization? _bindLppAuthorization(
    _LppAcquisitionDecision decision,
    Uint8List transmittedBytes,
  ) {
    if (!_lppAcquisitionStillEnabledFor(decision) ||
        (decision.subject == LppEvidenceOwnerKind.manualPartner &&
            (decision.accountabilityContext == null ||
                !decision.accountabilityContext!.isActiveAt(_currentTime())))) {
      return null;
    }
    final authorization = decision.bindDocument(
      transmittedBytes,
      widget.hashDocumentBytes ?? LppAcquisitionAuthorization.sha256Hex,
    );
    return authorization.isValidAt(_currentTime()) ? authorization : null;
  }

  Future<void> _openReview(
    ExtractionResult extraction, {
    TaxExtractionCandidate? taxCandidate,
    LppAcquisitionSource? lppSource,
    LppAcquisitionAuthorization? lppAuthorization,
    ManualPartnerAccountabilityContext? manualPartnerAccountability,
    _LppAcquisitionDecision? lppDecision,
  }) async {
    if (extraction.documentType == DocumentType.lppCertificate &&
        !FeatureFlags.lppEvidenceIngestionEnabled) {
      return;
    }
    LppExtractionCandidate? lppCandidate;
    var reviewExtraction = extraction;
    if (extraction.documentType == DocumentType.lppCertificate) {
      if (lppAuthorization?.subject == LppEvidenceOwnerKind.manualPartner &&
          (lppDecision == null ||
              !await _revalidatePartnerByteBoundary(lppDecision))) {
        return;
      }
      if (!mounted) return;
      if (lppSource == null ||
          lppAuthorization == null ||
          !lppAuthorization.isValidAt(_currentTime()) ||
          (lppAuthorization.subject == LppEvidenceOwnerKind.manualPartner &&
              (lppAuthorization.receiptId == null ||
                  lppAuthorization.manualPartnerOwnerId == null ||
                  manualPartnerAccountability == null ||
                  !FeatureFlags.partnerLppAccountabilityEnabled ||
                  !manualPartnerAccountability.isActiveAt(_currentTime()) ||
                  !manualPartnerAccountability.matchesAuthorization(
                    receiptId: lppAuthorization.receiptId,
                    ownerId: lppAuthorization.manualPartnerOwnerId,
                  )))) {
        return;
      }
      final adaptation = LppExtractionAdapter.adapt(
        source: lppSource,
        sourceOverallConfidence: extraction.overallConfidence,
        fields: extraction.fields,
      );
      lppCandidate = adaptation.candidate;
      if (lppCandidate == null || lppCandidate.facts.isEmpty) {
        if (mounted) {
          setState(() {
            _preValidationError = S.of(context)!.docScanNoFieldRecognized;
            _preValidationHint = S.of(context)!.docScanNoFieldHint;
          });
        }
        return;
      }
      reviewExtraction = _canonicalLppReviewExtraction(
        lppCandidate,
        confidenceDelta: extraction.confidenceDelta,
      );
    }
    final scanSessions = context.read<ScanSessionProvider>();
    final scanSessionId = scanSessions.retainExtraction(
      reviewExtraction,
      lppCandidate: lppCandidate,
      lppAuthorization: lppAuthorization,
      manualPartnerAccountability: manualPartnerAccountability,
      taxCandidate: taxCandidate,
    );
    final partnerReceiptId = manualPartnerAccountability?.receiptId;
    if (partnerReceiptId != null) {
      _partnerReceiptsHandedToReview.add(partnerReceiptId);
    }
    try {
      final navigateToReview = widget.navigateToReview;
      if (navigateToReview == null) {
        await context.push(
          '/scan/review?scanSessionId=${Uri.encodeQueryComponent(scanSessionId)}',
        );
      } else {
        await navigateToReview(context, scanSessionId);
      }
    } catch (_) {
      scanSessions.discard(scanSessionId);
      if (partnerReceiptId != null) {
        _partnerReceiptsHandedToReview.remove(partnerReceiptId);
        await _rollbackPartnerAttempt(lppDecision);
      }
      rethrow;
    }
  }

  ExtractionResult _canonicalLppReviewExtraction(
    LppExtractionCandidate candidate, {
    required double confidenceDelta,
  }) {
    return ExtractionResult(
      documentType: DocumentType.lppCertificate,
      fields: candidate.facts.values
          .map(
            (fact) => ExtractedField(
              fieldName: fact.key.wireName,
              label: fact.key.wireName,
              value: fact.unit == LppEvidenceUnit.ratio
                  ? fact.value * 100
                  : fact.value,
              confidence: fact.confidence,
              sourceText: '',
              needsReview: fact.needsReview,
              profileField: fact.key.profilePath,
            ),
          )
          .toList(growable: false),
      overallConfidence: candidate.overallConfidence,
      confidenceDelta: confidenceDelta,
      warnings: const [],
      disclaimer: '',
      sources: const [],
    );
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
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: CustomScrollView(
                    slivers: [
                      _buildAppBar(context),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const SizedBox(height: 12),
                            MintEntrance(child: _buildHeader()),
                            const SizedBox(height: 24),
                            MintEntrance(
                                delay: const Duration(milliseconds: 100),
                                child: _buildDocumentTypeSelector()),
                            const SizedBox(height: 32),
                            MintEntrance(
                                delay: const Duration(milliseconds: 200),
                                child: _buildDocumentDescription()),
                            const SizedBox(height: 32),
                            if (_selectedType != DocumentType.taxDeclaration)
                              MintEntrance(
                                  delay: const Duration(milliseconds: 300),
                                  child: _buildCaptureButtons()),
                            if (_preValidationError != null) ...[
                              const SizedBox(height: 12),
                              _buildPreValidationError(),
                            ],
                            const SizedBox(height: 12),
                            if (_selectedType != DocumentType.lppCertificate)
                              MintEntrance(
                                delay: const Duration(milliseconds: 400),
                                child: _buildPasteTextButton(),
                              ),
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
    final selectable =
        DocumentType.values.where(_isSupportedType).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.docScanDocumentType,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selectable.map((type) {
            final isSelected = type == _selectedType;
            final isTax = type == DocumentType.taxDeclaration;
            final isLpp = type == DocumentType.lppCertificate;
            return Semantics(
              identifier: isTax
                  ? 'document_scan_tax_type_selector'
                  : isLpp
                      ? 'document_scan_lpp_type_selector'
                      : null,
              child: ChoiceChip(
                key: isTax
                    ? const Key('document_scan_tax_type_selector')
                    : isLpp
                        ? const Key('document_scan_lpp_type_selector')
                        : null,
                label: Text(
                  _documentTypeLabel(type),
                  style: MintTextStyles.bodySmall(
                    color: isSelected
                        ? MintColors.background
                        : MintColors.textPrimary,
                  ).copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400),
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
              ),
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
                  _documentTypeLabel(_selectedType),
                  style:
                      MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            _documentTypeDescription(_selectedType),
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                .copyWith(height: 1.5),
          ),
          if (_selectedType != DocumentType.taxDeclaration) ...[
            const SizedBox(height: MintSpacing.sm),
            Row(
              children: [
                const Icon(Icons.trending_up,
                    color: MintColors.success, size: 16),
                const SizedBox(width: 6),
                Text(
                  S.of(context)!.docScanConfidencePoints(
                        _selectedType.confidenceImpact,
                      ),
                  style: MintTextStyles.bodySmall(color: MintColors.success)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _documentTypeLabel(DocumentType type) =>
      type == DocumentType.taxDeclaration
          ? S.of(context)!.docScanTaxDocumentLabel
          : type.label;

  String _documentTypeDescription(DocumentType type) =>
      type == DocumentType.taxDeclaration
          ? S.of(context)!.docScanTaxDocumentDescription
          : type.description!;

  Widget _buildCaptureButtons() {
    return Column(
      children: [
        Semantics(
          button: true,
          identifier: 'document_scan_capture_cta',
          label: S.of(context)!.documentScanTakePhoto,
          onTap: _isProcessing
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  (_onCameraPressed)();
                },
          child: ExcludeSemantics(
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                key: const Key('document_scan_capture_cta'),
                onPressed: _isProcessing
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        (_onCameraPressed)();
                      },
                icon: const Icon(
                  kIsWeb
                      ? Icons.upload_file_outlined
                      : Icons.camera_alt_outlined,
                  size: 22,
                ),
                label: Text(
                  _isProcessing
                      ? S.of(context)!.documentScanExtracting
                      : kIsWeb
                          ? S.of(context)!.documentScanImportFile
                          : S.of(context)!.documentScanTakePhoto,
                  style: MintTextStyles.titleMedium()
                      .copyWith(fontWeight: FontWeight.w600),
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
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: S.of(context)!.docScanFromGallery,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              key: const Key('document_scan_gallery_cta'),
              onPressed: _isProcessing ? null : _onGalleryPressed,
              icon: const Icon(Icons.photo_library_outlined, size: 22),
              label: Text(
                S.of(context)!.docScanFromGallery,
                style: MintTextStyles.titleMedium()
                    .copyWith(fontWeight: FontWeight.w600),
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
    return Semantics(
      identifier: _selectedType == DocumentType.taxDeclaration
          ? 'document_scan_tax_local_text_cta'
          : null,
      button: true,
      label: S.of(context)!.docScanPasteOcrText,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: TextButton.icon(
          key: _selectedType == DocumentType.taxDeclaration
              ? const Key('document_scan_tax_local_text_cta')
              : null,
          onPressed: _isProcessing ? null : _onPasteTextPressed,
          icon: const Icon(Icons.text_snippet_outlined, size: 20),
          label: Text(
            S.of(context)!.docScanPasteOcrText,
            style: MintTextStyles.bodyLarge()
                .copyWith(fontWeight: FontWeight.w600),
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
      ),
    );
  }

  Widget _buildDebugExampleButton() {
    return Semantics(
      identifier: _selectedType == DocumentType.taxDeclaration
          ? 'document_scan_tax_example_cta'
          : null,
      button: true,
      label: S.of(context)!.docScanUseExample,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          key: switch (_selectedType) {
            DocumentType.taxDeclaration =>
              const Key('document_scan_tax_example_cta'),
            DocumentType.lppCertificate =>
              const Key('document_scan_lpp_example_cta'),
            _ => null,
          },
          onPressed: _isProcessing ? null : _onUseExamplePressed,
          icon: const Icon(Icons.science_outlined, size: 20),
          label: Text(
            S.of(context)!.docScanUseExample,
            style: MintTextStyles.bodyMedium()
                .copyWith(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: MintColors.purple,
            side: BorderSide(color: MintColors.purple.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
          const Icon(Icons.warning_amber_outlined,
              size: 18, color: MintColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _preValidationError!,
                  style:
                      MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                ),
                if (_preValidationHint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _preValidationHint!,
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary),
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
              style: MintTextStyles.labelSmall(color: MintColors.textMuted)
                  .copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCameraPressed() async {
    if (!_isSupportedType(_selectedType)) return;
    if (_selectedType == DocumentType.taxDeclaration) {
      return;
    }
    final lppDecision = _selectedType == DocumentType.lppCertificate
        ? await _authorizeLppBeforeAcquisition()
        : null;
    if (_selectedType == DocumentType.lppCertificate && lppDecision == null) {
      return;
    }
    if (!_lppAcquisitionStillEnabledFor(lppDecision)) {
      await _rollbackPartnerAttempt(lppDecision);
      return;
    }
    if (!await _requestAcquisitionConsent(lppDecision)) {
      await _rollbackPartnerAttempt(lppDecision);
      return;
    }
    if (!mounted || !_lppAcquisitionStillEnabledFor(lppDecision)) {
      await _rollbackPartnerAttempt(lppDecision);
      return;
    }

    // Web/desktop have no native scanner — degrade gracefully to gallery upload.
    if (!NativeDocumentScanner.isAvailable) {
      if (!_lppAcquisitionStillEnabledFor(lppDecision)) {
        await _rollbackPartnerAttempt(lppDecision);
        return;
      }
      await _pickFromGalleryAfterGates(lppDecision);
      await _rollbackUnlessReviewOwns(lppDecision);
      return;
    }

    try {
      // Phase 28-03 — VisionKit (iOS) / ML Kit Document Scanner (Android).
      // Auto crop + deskew + shadow removal happen client-side, gratis,
      // offline. Multi-page natively supported (capped at 5 here).
      if (!_lppAcquisitionStillEnabledFor(lppDecision)) {
        await _rollbackPartnerAttempt(lppDecision);
        return;
      }
      final pages = await NativeDocumentScanner.scan(maxPages: 5);
      if (!_lppAcquisitionStillEnabledFor(lppDecision)) {
        await _rollbackPartnerAttempt(lppDecision);
        return;
      }
      if (pages == null || pages.isEmpty) {
        await _rollbackPartnerAttempt(lppDecision);
        return;
      }
      final effectiveDecision = await _ensurePartnerReceipt(lppDecision);
      if (lppDecision?.subject == LppEvidenceOwnerKind.manualPartner &&
          effectiveDecision == null) {
        return;
      }
      if (!await _revalidatePartnerByteBoundary(effectiveDecision)) return;
      // Pipeline today consumes one page at a time; we ship the first page
      // and queue the rest for the streaming flow in 28-04.
      final firstFile = await _materializeBytesAsXFile(pages.first);
      final processImageFile = _processImageFile;
      await processImageFile(firstFile, lppDecision: effectiveDecision);
      await _rollbackUnlessReviewOwns(lppDecision);
    } on DocumentScannerException catch (e) {
      await _rollbackPartnerAttempt(lppDecision);
      debugPrint('[DocumentScan] Scanner error: ${e.code}');
      if (!mounted) return;
      _showErrorSnack(S.of(context)!.docScanScannerError);
    } catch (e) {
      await _rollbackPartnerAttempt(lppDecision);
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
    _ownedTempPaths.add(path);
    try {
      await File(path).writeAsBytes(bytes, flush: true);
      return XFile(path);
    } catch (_) {
      _cleanupTempFile(path);
      rethrow;
    }
  }

  Future<void> _onGalleryPressed() async {
    if (!_isSupportedType(_selectedType)) return;
    if (_selectedType == DocumentType.taxDeclaration) {
      return;
    }
    final lppDecision = _selectedType == DocumentType.lppCertificate
        ? await _authorizeLppBeforeAcquisition()
        : null;
    if (_selectedType == DocumentType.lppCertificate && lppDecision == null) {
      return;
    }
    if (!_lppAcquisitionStillEnabledFor(lppDecision)) {
      await _rollbackPartnerAttempt(lppDecision);
      return;
    }
    if (!await _requestAcquisitionConsent(lppDecision)) {
      await _rollbackPartnerAttempt(lppDecision);
      return;
    }
    if (!mounted || !_lppAcquisitionStillEnabledFor(lppDecision)) {
      await _rollbackPartnerAttempt(lppDecision);
      return;
    }

    await _pickFromGalleryAfterGates(lppDecision);
    await _rollbackUnlessReviewOwns(lppDecision);
  }

  Future<void> _pickFromGalleryAfterGates(
    _LppAcquisitionDecision? lppDecision,
  ) async {
    if (!_lppAcquisitionStillEnabledFor(lppDecision)) return;
    try {
      final allowedExtensions = <String>[
        'jpg',
        'jpeg',
        'png',
        'heic',
        'txt',
        'pdf',
      ];
      final injectedPicker = widget.pickFile;
      final PlatformFile? file;
      if (!_lppAcquisitionStillEnabledFor(lppDecision)) return;
      if (injectedPicker != null) {
        file = await injectedPicker();
      } else {
        final picked = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          // Accountability receipt creation happens after choice and before
          // any document bytes are read into the extraction pipeline.
          withData: false,
          allowedExtensions: allowedExtensions,
        );
        file =
            picked == null || picked.files.isEmpty ? null : picked.files.first;
      }
      if (file == null || !_lppAcquisitionStillEnabledFor(lppDecision)) {
        await _rollbackPartnerAttempt(lppDecision);
        return;
      }
      final effectiveDecision = await _ensurePartnerReceipt(lppDecision);
      if (lppDecision?.subject == LppEvidenceOwnerKind.manualPartner &&
          effectiveDecision == null) {
        return;
      }
      if (!await _revalidatePartnerByteBoundary(effectiveDecision)) return;
      final ext = _detectExtension(file);

      if (ext == 'txt') {
        if (!_lppAcquisitionStillEnabledFor(effectiveDecision)) return;
        final exactBytes = await _readPlatformFileBytes(file);
        final text = exactBytes == null ? '' : utf8.decode(exactBytes);
        if (text.trim().isEmpty) {
          if (!mounted) return;
          _showErrorSnack(S.of(context)!.docScanEmptyTextFile);
          return;
        }
        await _processOcrText(
          text,
          lppDecision: effectiveDecision,
          exactDocumentBytes: exactBytes,
        );
        return;
      }

      if (ext == 'pdf') {
        if (!_lppAcquisitionStillEnabledFor(effectiveDecision)) return;
        final handlePdfImport = _handlePdfImport;
        await handlePdfImport(
          file,
          ext: ext,
          lppDecision: effectiveDecision,
        );
        return;
      }

      if (!_lppAcquisitionStillEnabledFor(effectiveDecision)) return;
      final localPath = await _resolveLocalPath(file, ext: ext);
      if (localPath == null || localPath.isEmpty) {
        if (!mounted) return;
        await _showOcrRecoverySheet(
          title: S.of(context)!.docScanFileUnreadableTitle,
          message: S.of(context)!.docScanFileUnreadableMessage,
          lppDecision: effectiveDecision,
        );
        return;
      }

      final processImageFile = _processImageFile;
      await processImageFile(
        XFile(localPath),
        lppDecision: effectiveDecision,
      );
    } catch (e) {
      await _rollbackPartnerAttempt(lppDecision);
      debugPrint('[DocumentScan] Import error: $e');
      if (!mounted) return;
      _showErrorSnack(S.of(context)!.docScanGenericError);
    }
  }

  Future<void> _onPasteTextPressed() async {
    if (!_isSupportedType(_selectedType)) return;
    if (_selectedType == DocumentType.lppCertificate) return;
    if (_selectedType == DocumentType.taxDeclaration &&
        !_taxAssessmentEnabled) {
      return;
    }
    if (!mounted) return;
    final l10n = S.of(context)!;
    await _requestManualOcrText(
      title: l10n.documentScanOcrTitle,
      hint: l10n.documentScanOcrHint,
    );
  }

  Future<void> _onUseExamplePressed() async {
    if (!_isSupportedType(_selectedType)) return;
    if (_selectedType == DocumentType.taxDeclaration &&
        !_taxAssessmentEnabled) {
      return;
    }
    final lppDecision = _selectedType == DocumentType.lppCertificate
        ? await _authorizeLppBeforeAcquisition(syntheticLocal: true)
        : null;
    if (_selectedType == DocumentType.lppCertificate && lppDecision == null) {
      return;
    }
    if (!_lppAcquisitionStillEnabled) return;
    final text = _sampleTextForType(_selectedType);
    await _processOcrText(
      text,
      lppDecision: lppDecision,
      exactDocumentBytes: Uint8List.fromList(utf8.encode(text)),
    );
  }

  Future<void> _processImageFile(
    XFile file, {
    _LppAcquisitionDecision? lppDecision,
  }) async {
    if (!_isSupportedType(_selectedType)) {
      _cleanupTempFile(file.path);
      return;
    }
    if (_selectedType == DocumentType.taxDeclaration) {
      return;
    }
    if (_selectedType == DocumentType.lppCertificate && lppDecision == null) {
      _cleanupTempFile(file.path);
      return;
    }
    if (!_lppAcquisitionStillEnabled) {
      _cleanupTempFile(file.path);
      return;
    }
    if (!await _revalidatePartnerByteBoundary(lppDecision)) {
      _cleanupTempFile(file.path);
      return;
    }
    // Client-side file validation: size and format checks.
    if (!kIsWeb) {
      final fileObj = File(file.path);
      if (fileObj.existsSync()) {
        final fileSize = fileObj.lengthSync();
        if (fileSize > _maxFileSizeBytes) {
          _cleanupTempFile(file.path);
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
        _cleanupTempFile(file.path);
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
        if (!_lppAcquisitionStillEnabled) {
          _cleanupTempFile(file.path);
          return;
        }
        final bytes = await _readFileBytes(file.path);
        if (!_lppAcquisitionStillEnabled) {
          _cleanupTempFile(file.path);
          return;
        }
        final decision = await classifier.shouldRejectAsNonFinancial(bytes);
        if (!_lppAcquisitionStillEnabled) {
          _cleanupTempFile(file.path);
          return;
        }
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
      final visionResult = await _tryVisionExtraction(
        file,
        lppDecision: lppDecision,
      );
      if (!_lppAcquisitionStillEnabled) return;
      if (visionResult != null && mounted) {
        await _openReview(
          visionResult.extraction,
          lppSource: _selectedType == DocumentType.lppCertificate
              ? LppAcquisitionSource.backendVision
              : null,
          lppAuthorization: visionResult.lppAuthorization,
          manualPartnerAccountability: visionResult.manualPartnerAccountability,
          lppDecision: lppDecision,
        );
        return;
      }

      // If 422 rejection was shown, don't fall through to OCR
      if (_preValidationError != null) return;

      // Local MLKit OCR fallback was removed 2026-04-17 along with the
      // google_mlkit_text_recognition dep (MLKit 7.x has no arm64-simulator
      // slice, which blocked iterating on Apple Silicon simulators). Backend
      // Claude Vision is the single source of OCR — it already ran above;
      // if it produced nothing, the user sees the OCR recovery sheet.
      const String extractedText = '';

      if (extractedText.trim().length < 12) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        await _showOcrRecoverySheet(
          title: S.of(context)!.docScanOcrNotDetectedTitle,
          message: S.of(context)!.docScanOcrNotDetectedMessage,
          imageFile: file,
          lppDecision: lppDecision,
        );
        return;
      }

      await _processOcrText(
        extractedText,
        lppDecision: lppDecision,
        exactDocumentBytes: Uint8List.fromList(utf8.encode(extractedText)),
      );
    } catch (_) {
      if (!mounted) return;
      await _showOcrRecoverySheet(
        title: S.of(context)!.docScanPhotoAnalysisTitle,
        message: S.of(context)!.docScanPhotoAnalysisMessage,
        imageFile: file,
        lppDecision: lppDecision,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
      _cleanupTempFile(file.path); // FIX-053
    }
  }

  /// Try Claude Vision extraction via backend API.
  /// Returns ExtractionResult if successful, null otherwise.
  Future<_DocumentVisionResult?> _tryVisionExtraction(
    XFile file, {
    _LppAcquisitionDecision? lppDecision,
  }) async {
    if (!_isSupportedType(_selectedType)) return null;
    if (_selectedType == DocumentType.lppCertificate && lppDecision == null) {
      return null;
    }
    if (!_lppAcquisitionStillEnabledFor(lppDecision)) return null;
    // Read context-dependent values BEFORE async gap
    final canton = Provider.of<CoachProfileProvider>(context, listen: false)
        .profile
        ?.canton;
    final visionDisclaimer = S.of(context)!.documentVisionDisclaimer;
    try {
      if (!_lppAcquisitionStillEnabledFor(lppDecision)) return null;
      if (!await _revalidatePartnerByteBoundary(lppDecision)) return null;
      final rawBytes = await _readFileBytes(file.path);
      if (!_lppAcquisitionStillEnabledFor(lppDecision)) return null;
      // TODO(P2-W12): Strip EXIF metadata before Vision API call.
      // Requires `image` package. GPS location and camera info currently exposed.
      final bytes = await _compressForVision(rawBytes, file.path);
      if (!_lppAcquisitionStillEnabledFor(lppDecision)) return null;
      final lppAuthorization = lppDecision == null
          ? null
          : _bindLppAuthorization(lppDecision, bytes);
      if (_selectedType == DocumentType.lppCertificate &&
          lppAuthorization == null) {
        return null;
      }
      final base64Image = base64Encode(bytes);

      final extractor = widget.visionExtractor ??
          ({
            required String imageBase64,
            required String documentType,
            String? canton,
            String? languageHint,
            String? subjectKind,
            String? receiptId,
          }) =>
              DocumentService.extractWithVision(
                imageBase64: imageBase64,
                documentType: documentType,
                canton: canton,
                languageHint: languageHint,
                subjectKind: subjectKind,
                receiptId: receiptId,
              );
      if (!_lppAcquisitionStillEnabledFor(lppDecision)) return null;
      if (!await _revalidatePartnerByteBoundary(lppDecision)) return null;
      final response = await extractor(
        imageBase64: base64Image,
        // Convert camelCase enum to snake_case for backend contract.
        documentType: _selectedType.name.replaceAllMapped(
            RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}'),
        canton: canton,
        languageHint: 'fr',
        subjectKind: lppDecision?.subject == LppEvidenceOwnerKind.manualPartner
            ? PartnerAccountabilityService.subjectKind
            : null,
        receiptId: lppDecision?.receiptId,
      );

      if (!_lppAcquisitionStillEnabledFor(lppDecision)) return null;

      if (response == null) {
        await _failPartnerExtraction(lppDecision);
        return null;
      }

      final strictLppConfidence = _selectedType == DocumentType.lppCertificate;
      final lppOverallConfidence = strictLppConfidence
          ? _parseLppOverallConfidence(response['overallConfidence'])
          : null;
      if (strictLppConfidence && lppOverallConfidence == null) {
        await _failPartnerExtraction(lppDecision);
        return null;
      }
      final responseFields = response['extractedFields'] as List?;
      if (strictLppConfidence &&
          (responseFields == null ||
              responseFields.any(
                (field) =>
                    field is! Map<String, dynamic> ||
                    _parseLppFieldConfidence(field['confidence']) == null,
              ))) {
        await _failPartnerExtraction(lppDecision);
        return null;
      }

      final extractedFields = responseFields?.map<ExtractedField>((f) {
        final map = f as Map<String, dynamic>;
        final conf = strictLppConfidence
            ? _parseLppFieldConfidence(map['confidence'])!
            : _parseConfidence(map['confidence'] as String?);
        return ExtractedField(
          fieldName: map['fieldName'] as String? ?? '',
          label: map['fieldName'] as String? ?? '',
          value: map['value'],
          confidence: conf,
          sourceText: (map['sourceText'] as String?) ?? '',
          profileField: map['fieldName'] as String?,
          needsReview: map['needsReview'] == true || conf < 0.80,
        );
      }).toList();

      if (extractedFields == null || extractedFields.isEmpty) {
        await _failPartnerExtraction(lppDecision);
        return null;
      }

      return _DocumentVisionResult(
        extraction: ExtractionResult(
          documentType: _selectedType,
          fields: extractedFields,
          overallConfidence: lppOverallConfidence ??
              (response['overallConfidence'] as num?)?.toDouble() ??
              0.5,
          confidenceDelta: (_confidenceDeltaForType)(_selectedType),
          warnings: const [],
          disclaimer: visionDisclaimer,
          sources: const ['Claude Vision API'],
          planType: response['planType'] as String?,
          planTypeWarning: response['planTypeWarning'] as String?,
          coherenceWarnings: (response['coherenceWarnings'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
        ),
        lppAuthorization: lppAuthorization,
        manualPartnerAccountability: lppDecision?.accountabilityContext,
      );
    } on DocumentServiceException catch (e) {
      debugPrint(
          '[DocumentScan] Vision error: code=${e.code} msg=${e.message}');
      if (!mounted) return null;
      await _failPartnerExtraction(lppDecision);
      if (!mounted || e.code == 'partner_receipt_consumed') return null;
      switch (e.code) {
        case 'not_financial':
          _setVisionKindRejection();
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
      await _failPartnerExtraction(lppDecision);
      if (mounted) {
        _showErrorSnack(S.of(context)!.docScanScannerError);
      }
      return null;
    } catch (e) {
      debugPrint('[DocumentScan] Vision extraction failed: $e');
      await _failPartnerExtraction(lppDecision);
      return null;
    }
  }

  /// Vision API fallback for PDF files when backend Docling fails.
  /// Reads PDF bytes, encodes to base64, and calls Claude Vision extraction.
  Future<_DocumentVisionResult?> _tryVisionExtractionFromPdf(
    String pdfPath, {
    _LppAcquisitionDecision? lppDecision,
  }) async {
    if (!_isSupportedType(_selectedType)) return null;
    if (_selectedType == DocumentType.lppCertificate && lppDecision == null) {
      return null;
    }
    if (!_lppAcquisitionStillEnabledFor(lppDecision)) return null;
    // Read context-dependent values BEFORE async gap
    final canton = Provider.of<CoachProfileProvider>(context, listen: false)
        .profile
        ?.canton;
    final visionDisclaimer = S.of(context)!.documentVisionDisclaimer;
    try {
      if (!_lppAcquisitionStillEnabledFor(lppDecision)) return null;
      if (!await _revalidatePartnerByteBoundary(lppDecision)) return null;
      final bytes = await _readFileBytes(pdfPath);
      if (!_lppAcquisitionStillEnabledFor(lppDecision)) return null;
      final lppAuthorization = lppDecision == null
          ? null
          : _bindLppAuthorization(lppDecision, bytes);
      if (_selectedType == DocumentType.lppCertificate &&
          lppAuthorization == null) {
        return null;
      }
      final base64Pdf = base64Encode(bytes);

      final extractor = widget.visionExtractor ??
          ({
            required String imageBase64,
            required String documentType,
            String? canton,
            String? languageHint,
            String? subjectKind,
            String? receiptId,
          }) =>
              DocumentService.extractWithVision(
                imageBase64: imageBase64,
                documentType: documentType,
                canton: canton,
                languageHint: languageHint,
                subjectKind: subjectKind,
                receiptId: receiptId,
              );
      if (!_lppAcquisitionStillEnabledFor(lppDecision)) return null;
      if (!await _revalidatePartnerByteBoundary(lppDecision)) return null;
      final response = await extractor(
        imageBase64: base64Pdf,
        documentType: _selectedType.name.replaceAllMapped(
            RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}'),
        canton: canton,
        languageHint: 'fr',
        subjectKind: lppDecision?.subject == LppEvidenceOwnerKind.manualPartner
            ? PartnerAccountabilityService.subjectKind
            : null,
        receiptId: lppDecision?.receiptId,
      );

      if (!_lppAcquisitionStillEnabledFor(lppDecision)) return null;

      if (response == null) {
        await _failPartnerExtraction(lppDecision);
        return null;
      }

      final strictLppConfidence = _selectedType == DocumentType.lppCertificate;
      final lppOverallConfidence = strictLppConfidence
          ? _parseLppOverallConfidence(response['overallConfidence'])
          : null;
      if (strictLppConfidence && lppOverallConfidence == null) {
        await _failPartnerExtraction(lppDecision);
        return null;
      }
      final responseFields = response['extractedFields'] as List?;
      if (strictLppConfidence &&
          (responseFields == null ||
              responseFields.any(
                (field) =>
                    field is! Map<String, dynamic> ||
                    _parseLppFieldConfidence(field['confidence']) == null,
              ))) {
        await _failPartnerExtraction(lppDecision);
        return null;
      }

      final extractedFields = responseFields?.map<ExtractedField>((f) {
        final map = f as Map<String, dynamic>;
        final conf = strictLppConfidence
            ? _parseLppFieldConfidence(map['confidence'])!
            : _parseConfidence(map['confidence'] as String?);
        return ExtractedField(
          fieldName: map['fieldName'] as String? ?? '',
          label: map['fieldName'] as String? ?? '',
          value: map['value'],
          confidence: conf,
          sourceText: (map['sourceText'] as String?) ?? '',
          profileField: map['fieldName'] as String?,
          needsReview: map['needsReview'] == true || conf < 0.80,
        );
      }).toList();

      if (extractedFields == null || extractedFields.isEmpty) {
        await _failPartnerExtraction(lppDecision);
        return null;
      }

      return _DocumentVisionResult(
        extraction: ExtractionResult(
          documentType: _selectedType,
          fields: extractedFields,
          overallConfidence: lppOverallConfidence ??
              (response['overallConfidence'] as num?)?.toDouble() ??
              0.5,
          confidenceDelta: (_confidenceDeltaForType)(_selectedType),
          warnings: const [],
          disclaimer: visionDisclaimer,
          sources: const ['Claude Vision API (PDF)'],
          planType: response['planType'] as String?,
          planTypeWarning: response['planTypeWarning'] as String?,
          coherenceWarnings: (response['coherenceWarnings'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
        ),
        lppAuthorization: lppAuthorization,
        manualPartnerAccountability: lppDecision?.accountabilityContext,
      );
    } on DocumentServiceException catch (e) {
      debugPrint(
        '[DocumentScan] Vision PDF error: code=${e.code} msg=${e.message}',
      );
      if (!mounted) return null;
      await _failPartnerExtraction(lppDecision);
      if (!mounted || e.code == 'partner_receipt_consumed') return null;
      if (e.code == 'not_financial') {
        _setVisionKindRejection();
      } else {
        _showErrorSnack(S.of(context)!.docScanGenericError);
      }
      return null;
    } catch (e) {
      debugPrint('[DocumentScan] Vision PDF fallback failed: $e');
      await _failPartnerExtraction(lppDecision);
      return null;
    }
  }

  Future<Uint8List> _readFileBytes(String path) {
    if (!_lppAcquisitionStillEnabled) {
      throw StateError('LPP acquisition disabled before reading bytes');
    }
    final reader = widget.readFileBytes;
    if (reader != null) return reader(path);
    return File(path).readAsBytes();
  }

  double _parseConfidence(String? level) {
    return switch (level) {
      'high' => 0.95,
      'medium' => 0.70,
      'low' => 0.40,
      _ => 0.50,
    };
  }

  double? _parseLppFieldConfidence(Object? level) {
    return switch (level) {
      'high' => 0.95,
      'medium' => 0.70,
      'low' => 0.40,
      _ => null,
    };
  }

  double? _parseLppOverallConfidence(Object? value) {
    if (value is! num) return null;
    final confidence = value.toDouble();
    if (!confidence.isFinite || confidence < 0 || confidence > 1) return null;
    return confidence;
  }

  double _confidenceDeltaForType(DocumentType type) {
    return switch (type) {
      DocumentType.lppCertificate => 27.0,
      DocumentType.avsExtract => 22.0,
      DocumentType.taxDeclaration => 0.0,
      DocumentType.salaryCertificate => 20.0,
      _ => 10.0,
    };
  }

  Future<void> _processOcrText(
    String text, {
    _LppAcquisitionDecision? lppDecision,
    Uint8List? exactDocumentBytes,
  }) async {
    if (!_isSupportedType(_selectedType)) return;
    if (!mounted) return;
    if (_selectedType == DocumentType.taxDeclaration &&
        !_taxAssessmentEnabled) {
      return;
    }
    if (!_lppAcquisitionStillEnabled) return;
    if (!await _revalidatePartnerByteBoundary(lppDecision)) return;
    final lppAuthorization = _selectedType == DocumentType.lppCertificate &&
            lppDecision != null &&
            exactDocumentBytes != null
        ? _bindLppAuthorization(lppDecision, exactDocumentBytes)
        : null;
    if (!await _revalidatePartnerByteBoundary(lppDecision)) return;
    if (!mounted) return;
    if (_selectedType == DocumentType.lppCertificate &&
        lppAuthorization == null) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final bundle = _parseByDocumentType(text);
      if (bundle.extraction.fields.isEmpty) {
        await _requestManualOcrText(
          title: S.of(context)!.docScanNoFieldRecognized,
          hint: S.of(context)!.docScanNoFieldHint,
          initialText: text,
          lppDecision: lppDecision,
        );
        return;
      }

      if (!mounted) return;
      await _openReview(
        bundle.extraction,
        taxCandidate: bundle.taxCandidate,
        lppSource: _selectedType == DocumentType.lppCertificate
            ? LppAcquisitionSource.localParser
            : null,
        lppAuthorization: lppAuthorization,
        manualPartnerAccountability: lppDecision?.accountabilityContext,
        lppDecision: lppDecision,
      );
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
    _LppAcquisitionDecision? lppDecision,
  }) async {
    var authorizedDecision = lppDecision;
    if (_selectedType == DocumentType.lppCertificate &&
        authorizedDecision == null) {
      return;
    }
    if (!_lppAcquisitionStillEnabled) return;
    if (!mounted) return;
    if (!await _revalidatePartnerByteBoundary(authorizedDecision)) return;
    if (!mounted) return;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final l10n = S.of(context)!;

    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: maxHeight),
      backgroundColor: MintColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _ManualOcrTextSheet(
        title: title,
        hint: hint,
        initialText: initialText,
        pasteHint: l10n.docScanOcrPasteHint,
        cancelLabel: l10n.documentScanCancel,
        analyzeLabel: l10n.documentScanAnalyze,
      ),
    );

    if (text != null && text.isNotEmpty) {
      await _processOcrText(
        text,
        lppDecision: authorizedDecision,
        exactDocumentBytes: Uint8List.fromList(utf8.encode(text)),
      );
    }
  }

  Future<void> _handlePdfImport(
    PlatformFile file, {
    required String ext,
    _LppAcquisitionDecision? lppDecision,
  }) async {
    if (!_isSupportedType(_selectedType)) return;
    if (_selectedType == DocumentType.taxDeclaration) {
      return;
    }
    if (_preValidationError != null || _preValidationHint != null) {
      if (!mounted) return;
      setState(() {
        _preValidationError = null;
        _preValidationHint = null;
      });
    }
    if (!_lppAcquisitionStillEnabled) return;
    final localPath = await _resolveLocalPath(file, ext: ext);
    if (localPath == null || localPath.isEmpty) {
      if (!mounted) return;
      await _showPdfImportFallback(
        title: S.of(context)!.docScanPdfDetected,
        message: S.of(context)!.docScanPdfCannotRead,
        lppDecision: lppDecision,
      );
      return;
    }

    try {
      if (_selectedType == DocumentType.lppCertificate) {
        if (lppDecision == null || !_lppAcquisitionStillEnabled) return;
        final visionResult = await _tryVisionExtractionFromPdf(
          localPath,
          lppDecision: lppDecision,
        );
        if (visionResult != null && mounted) {
          await _openReview(
            visionResult.extraction,
            lppSource: LppAcquisitionSource.backendVision,
            lppAuthorization: visionResult.lppAuthorization,
            manualPartnerAccountability:
                visionResult.manualPartnerAccountability,
            lppDecision: lppDecision,
          );
          return;
        }
        if (_preValidationError != null) return;
        if (!mounted || !_lppAcquisitionStillEnabled) return;
        await _showPdfImportFallback(
          title: S.of(context)!.docScanPdfAnalysisUnavailable,
          message: S.of(context)!.docScanPdfNotParsed,
          lppDecision: lppDecision,
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
            await _openReview(visionResult.extraction);
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
    } finally {
      _cleanupTempFile(localPath);
    }
  }

  Future<void> _showPdfImportFallback({
    required String title,
    required String message,
    _LppAcquisitionDecision? lppDecision,
  }) async {
    if (!mounted) return;
    if (!await _revalidatePartnerByteBoundary(lppDecision)) return;
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
                style: MintTextStyles.titleLarge(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                message,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                    .copyWith(height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    ctx.pop();
                    (_onCameraPressed)();
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(S.of(context)!.documentScanTakePhoto),
                ),
              ),
              if (_selectedType != DocumentType.lppCertificate ||
                  lppDecision != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: _selectedType == DocumentType.lppCertificate
                        ? const Key('lpp_recovery_manual_text_cta')
                        : null,
                    onPressed: () {
                      ctx.pop();
                      _requestManualOcrText(
                        title: S.of(context)!.documentScanOcrTitle,
                        hint: S.of(context)!.documentScanOcrHint,
                        lppDecision: lppDecision,
                      );
                    },
                    icon: const Icon(Icons.text_snippet_outlined),
                    label: Text(S.of(context)!.documentScanPasteOcr),
                  ),
                ),
              ],
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
                style: MintTextStyles.titleLarge(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                S.of(context)!.documentScanPdfAuthContent,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                    .copyWith(height: 1.4),
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
                    (_onCameraPressed)();
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
    _LppAcquisitionDecision? lppDecision,
  }) async {
    if (!mounted) return;
    if (!await _revalidatePartnerByteBoundary(lppDecision)) return;
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
                style: MintTextStyles.titleLarge(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                message,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                    .copyWith(height: 1.4),
              ),
              if (showVision) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      ctx.pop();
                      final processImageViaVision = _processImageViaVision;
                      processImageViaVision(imageFile);
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
                    style:
                        MintTextStyles.labelSmall(color: MintColors.textMuted)
                            .copyWith(height: 1.4),
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
                    (_onCameraPressed)();
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(S.of(context)!.documentScanRetakePhoto),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: _selectedType == DocumentType.lppCertificate
                      ? const Key('lpp_recovery_manual_text_cta')
                      : null,
                  onPressed: () {
                    ctx.pop();
                    _requestManualOcrText(
                      title: S.of(context)!.documentScanOcrTitle,
                      hint: S.of(context)!.documentScanOcrRetryHint,
                      lppDecision: lppDecision,
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

  ({ExtractionResult extraction, TaxExtractionCandidate? taxCandidate})
      _parseByDocumentType(String text) {
    switch (_selectedType) {
      case DocumentType.lppCertificate:
        return (
          extraction: LppCertificateParser.parseLppCertificate(text),
          taxCandidate: null,
        );
      case DocumentType.taxDeclaration:
        final taxCandidate = TaxDeclarationParser.parseTaxDocument(
          text,
          snapshotIdFactory: widget.taxSnapshotIdFactory ?? const Uuid().v4,
        );
        return (
          extraction: taxCandidate.extraction,
          taxCandidate: taxCandidate,
        );
      case DocumentType.avsExtract:
        final age = context.read<CoachProfileProvider>().hasProfile
            ? context.read<CoachProfileProvider>().profile!.age
            : null;
        return (
          extraction: AvsExtractParser.parseAvsExtract(text, userAge: age),
          taxCandidate: null,
        );
      case DocumentType.salaryCertificate:
        return (
          extraction: SalaryCertificateParser.parse(text),
          taxCandidate: null,
        );
      case DocumentType.threeAAttestation:
      case DocumentType.mortgageAttestation:
        throw UnsupportedError(S.of(context)!.docScanPdfTypeUnsupported);
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

  Future<Uint8List?> _readPlatformFileBytes(PlatformFile file) async {
    if (!_lppAcquisitionStillEnabled) return null;
    if (file.bytes != null) return file.bytes;
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return _readFileBytes(path);
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
    if (!_lppAcquisitionStillEnabled) return null;
    if (file.path != null && file.path!.isNotEmpty) return file.path;
    if (kIsWeb || file.bytes == null) return null;

    final safeExt = ext.trim().isEmpty ? 'bin' : ext.trim();
    final tempPath =
        '${Directory.systemTemp.path}/mint_upload_${DateTime.now().microsecondsSinceEpoch}.$safeExt';
    final tempFile = File(tempPath);
    _ownedTempPaths.add(tempFile.path);
    try {
      final writeOwnedTempFile = widget.writeOwnedTempFile;
      if (writeOwnedTempFile == null) {
        await tempFile.writeAsBytes(file.bytes!, flush: true);
      } else {
        await writeOwnedTempFile(tempFile, file.bytes!);
      }
      return tempFile.path;
    } catch (error) {
      _cleanupTempFile(tempFile.path);
      debugPrint('[DocumentScan] Temporary file creation failed: $error');
      return null;
    }
  }

  /// Deletes only exact paths created by this screen instance.
  void _cleanupTempFile(String? path) {
    if (path == null) return;
    if (!_ownedTempPaths.remove(path)) return;
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
    if (!_isSupportedType(_selectedType)) {
      return const _PdfParseResult(success: false);
    }
    if (_selectedType == DocumentType.lppCertificate) {
      return const _PdfParseResult(success: false);
    }
    if (kIsWeb) {
      return _PdfParseResult(
        success: false,
        errorMessage: S.of(context)!.docScanPdfTypeUnsupported,
      );
    }

    setState(() => _isProcessing = true);
    try {
      final uploader = widget.uploadDocument;
      final upload = uploader == null
          ? await DocumentService().uploadDocument(
              File(path),
              type: _toVaultType(_selectedType),
            )
          : await uploader(
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
      await _openReview(extraction);
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
        errorMessage:
            mounted ? S.of(context)!.docScanGenericError : 'PDF parsing error',
      );
    } catch (e) {
      debugPrint('[DocumentScan] Backend PDF parsing unavailable: $e');
      return _PdfParseResult(
        success: false,
        errorMessage:
            mounted ? S.of(context)!.docScanGenericError : 'PDF parsing error',
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
        disclaimer: S.of(context)!.docScanBackendDisclaimer,
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
      disclaimer: S.of(context)!.docScanBackendDisclaimerShort,
      sources: const ['Extraction backend Docling (LPP)'],
    );
  }

  /// Whether the user has a BYOK key for a vision-capable provider.
  bool _isVisionAvailable(BuildContext ctx) {
    if (_selectedType == DocumentType.lppCertificate) return false;
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
    if (!_isSupportedType(_selectedType)) return;
    if (_selectedType == DocumentType.taxDeclaration) {
      return;
    }
    if (_selectedType == DocumentType.lppCertificate) {
      return;
    }
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
        overallConfidence:
            fields.fold<double>(0, (sum, f) => sum + f.confidence) /
                fields.length,
        confidenceDelta: visionResponse.confidenceDelta.toDouble(),
        warnings: const [],
        disclaimer: visionResponse.disclaimers.isNotEmpty
            ? visionResponse.disclaimers.first
            : S.of(context)!.docScanVisionDefaultDisclaimer,
        sources: const ['Extraction Vision IA (BYOK)'],
      );

      await _openReview(result);
    } on RagApiException catch (e) {
      if (!mounted) return;
      final l10n = S.of(context)!;
      _showErrorSnack(
        e.errorCode.localizedRagMessage(
          l10n,
          fallback: l10n.docScanGenericError,
        ),
      );
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

  void _setVisionKindRejection() {
    final l10n = S.of(context)!;
    setState(() {
      _isProcessing = false;
      if (_selectedType == DocumentType.lppCertificate) {
        _preValidationError = l10n.lppDocumentKindUnverified;
        _preValidationHint = l10n.lppDocumentKindUnverifiedHint;
      } else {
        _preValidationError = l10n.docNotFinancial;
        _preValidationHint = l10n.docNotFinancialHint;
      }
    });
  }
}

class _ManualOcrTextSheet extends StatefulWidget {
  const _ManualOcrTextSheet({
    required this.title,
    required this.hint,
    required this.initialText,
    required this.pasteHint,
    required this.cancelLabel,
    required this.analyzeLabel,
  });

  final String title;
  final String hint;
  final String? initialText;
  final String pasteHint;
  final String cancelLabel;
  final String analyzeLabel;

  @override
  State<_ManualOcrTextSheet> createState() => _ManualOcrTextSheetState();
}

class _ManualOcrTextSheetState extends State<_ManualOcrTextSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: MintTextStyles.titleLarge(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            widget.hint,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                .copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 8,
            minLines: 5,
            decoration: InputDecoration(
              hintText: widget.pasteHint,
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
                  onPressed: () => context.pop(),
                  child: Text(widget.cancelLabel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const Key('document_scan_manual_analyze_cta'),
                  onPressed: () {
                    final text = _controller.text.trim();
                    context.pop(text.isEmpty ? null : text);
                  },
                  child: Text(widget.analyzeLabel),
                ),
              ),
            ],
          ),
        ],
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
