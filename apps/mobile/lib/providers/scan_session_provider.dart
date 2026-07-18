import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';
import 'package:mint_mobile/services/session_epoch.dart';

@immutable
class ScanSessionPayload {
  final ExtractionResult extraction;
  final LppExtractionCandidate? lppCandidate;
  final LppAcquisitionAuthorization? lppAuthorization;
  final LppRegulationAcquisitionCandidate? lppRegulationCandidate;
  final ManualPartnerAccountabilityContext? manualPartnerAccountability;
  final TaxExtractionCandidate? taxCandidate;
  final int? previousConfidence;

  const ScanSessionPayload({
    required this.extraction,
    this.lppCandidate,
    this.lppAuthorization,
    this.lppRegulationCandidate,
    this.manualPartnerAccountability,
    this.taxCandidate,
    this.previousConfidence,
  });

  ScanSessionPayload withImpact({
    required ExtractionResult extraction,
    required int previousConfidence,
  }) {
    return ScanSessionPayload(
      extraction: _withoutSourceText(extraction),
      lppCandidate: null,
      lppAuthorization: null,
      lppRegulationCandidate: null,
      manualPartnerAccountability: null,
      taxCandidate: null,
      previousConfidence: previousConfidence,
    );
  }
}

ExtractionResult _withoutSourceText(ExtractionResult extraction) {
  return ExtractionResult(
    documentType: extraction.documentType,
    fields: extraction.fields
        .map(
          (field) => ExtractedField(
            fieldName: field.fieldName,
            label: field.label,
            value: field.value,
            confidence: field.confidence,
            sourceText: '',
            needsReview: field.needsReview,
            profileField: field.profileField,
            labelCode: field.labelCode,
          ),
        )
        .toList(growable: false),
    overallConfidence: extraction.overallConfidence,
    confidenceDelta: extraction.confidenceDelta,
    warnings: extraction.warnings,
    disclaimer: extraction.disclaimer,
    sources: extraction.sources,
    diagnostics: extraction.diagnostics,
    planType: extraction.planType,
    planTypeWarning: extraction.planTypeWarning,
    coherenceWarnings: extraction.coherenceWarnings,
  );
}

bool _isStrictEmptyLppRegulationExtraction(ExtractionResult extraction) {
  return extraction.fields.isEmpty &&
      extraction.overallConfidence == 0 &&
      extraction.confidenceDelta == 0 &&
      extraction.warnings.isEmpty &&
      extraction.disclaimer.isEmpty &&
      extraction.sources.isEmpty &&
      extraction.diagnostics.isEmpty &&
      extraction.planType == null &&
      extraction.planTypeWarning == null &&
      extraction.coherenceWarnings.isEmpty;
}

/// In-memory boundary for domain data used by the scan route sequence.
///
/// Route locations carry only [scanSessionId]. A cold deep link or process
/// restart intentionally resolves to the existing recovery state instead of
/// trying to reconstruct an unconfirmed OCR result from navigation payloads.
class ScanSessionProvider extends ChangeNotifier {
  ScanSessionProvider({SessionEpoch? sessionEpoch})
      : _sessionEpoch = sessionEpoch ?? SessionEpoch();

  static const maxRetainedSessions = 5;
  final SessionEpoch _sessionEpoch;
  final Map<String, ScanSessionPayload> _sessions = {};
  int _nextId = 0;

  @visibleForTesting
  int get retainedSessionCount => _sessions.length;

  String retainExtraction(
    ExtractionResult extraction, {
    LppExtractionCandidate? lppCandidate,
    LppAcquisitionAuthorization? lppAuthorization,
    LppRegulationAcquisitionCandidate? lppRegulationCandidate,
    ManualPartnerAccountabilityContext? manualPartnerAccountability,
    TaxExtractionCandidate? taxCandidate,
  }) {
    final guard = _sessionEpoch.capture();
    final hasLppCandidate = lppCandidate != null;
    final hasLppAuthorization = lppAuthorization != null;
    final isLppRegulation = extraction.documentType == DocumentType.lppPlan;
    final hasLppRegulationCandidate = lppRegulationCandidate != null;
    if (isLppRegulation != hasLppRegulationCandidate ||
        (hasLppRegulationCandidate &&
            (!_isStrictEmptyLppRegulationExtraction(extraction) ||
                hasLppCandidate ||
                hasLppAuthorization ||
                manualPartnerAccountability != null ||
                taxCandidate != null))) {
      throw ArgumentError(
        'LPP regulation requires one isolated zero-fact acquisition candidate',
      );
    }
    final requiresPartnerAccountability =
        lppAuthorization?.subject == LppEvidenceOwnerKind.manualPartner;
    if (hasLppCandidate != hasLppAuthorization ||
        (hasLppCandidate &&
            (extraction.documentType != DocumentType.lppCertificate ||
                !lppAuthorization!.isValidAt(DateTime.now().toUtc()))) ||
        (requiresPartnerAccountability &&
            (lppAuthorization?.receiptId == null ||
                lppAuthorization?.manualPartnerOwnerId == null ||
                manualPartnerAccountability == null ||
                !manualPartnerAccountability.isActiveAt(
                  DateTime.now().toUtc(),
                ) ||
                !manualPartnerAccountability.matchesAuthorization(
                  receiptId: lppAuthorization?.receiptId,
                  ownerId: lppAuthorization?.manualPartnerOwnerId,
                ))) ||
        (!requiresPartnerAccountability &&
            manualPartnerAccountability != null)) {
      throw ArgumentError(
        'LPP candidate and complete volatile authorization are required together',
      );
    }
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
    _sessions[id] = ScanSessionPayload(
      extraction: extraction,
      lppCandidate: lppCandidate,
      lppAuthorization: lppAuthorization,
      lppRegulationCandidate: lppRegulationCandidate,
      manualPartnerAccountability: manualPartnerAccountability,
      taxCandidate: taxCandidate,
    );
    while (_sessions.length > maxRetainedSessions) {
      _sessions.remove(_sessions.keys.first);
    }
    guard.assertCurrent();
    notifyListeners();
    return id;
  }

  ScanSessionPayload? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    return _sessions[id];
  }

  bool retainImpact(
    String id, {
    required ExtractionResult extraction,
    required int previousConfidence,
  }) {
    final guard = _sessionEpoch.capture();
    final current = _sessions[id];
    if (current == null) return false;
    if (current.lppRegulationCandidate != null) return false;
    _sessions[id] = current.withImpact(
      extraction: extraction,
      previousConfidence: previousConfidence,
    );
    guard.assertCurrent();
    notifyListeners();
    return true;
  }

  void discard(String id) {
    final guard = _sessionEpoch.capture();
    if (_sessions.remove(id) != null) {
      guard.assertCurrent();
      notifyListeners();
    }
  }

  /// Drops volatile extraction candidates and authorizations on session exit.
  void clearSessionMemoryAfterPurge() {
    _sessions.clear();
    _nextId = 0;
    notifyListeners();
  }
}
