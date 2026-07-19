import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile_owner.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:uuid/uuid.dart';

enum Pillar3aBeneficiaryScanIntentKind { insertion, replacement }

enum DataBlockScanReturnKind { rvcLpp }

enum DataBlockScanReturnLifecycle {
  created,
  processing,
  reviewRetained,
  impactRetained,
}

@immutable
final class DataBlockScanReturnIntent {
  const DataBlockScanReturnIntent._({
    required this.kind,
    required this.target,
    required this.createdAt,
    required this.lifecycle,
  });

  final DataBlockScanReturnKind kind;
  final DataBlockReturnTarget target;
  final DateTime createdAt;
  final DataBlockScanReturnLifecycle lifecycle;

  DataBlockScanReturnIntent _at(DataBlockScanReturnLifecycle next) =>
      DataBlockScanReturnIntent._(
        kind: kind,
        target: target,
        createdAt: createdAt,
        lifecycle: next,
      );
}

enum Pillar3aBeneficiaryScanIntentLifecycle {
  created,
  processing,
  reviewRetained,
  ledgerAcceptedAwaitingBnd,
}

@immutable
class Pillar3aBeneficiaryScanIntent {
  const Pillar3aBeneficiaryScanIntent._({
    required this.kind,
    required this.returnUri,
    required this.createdAt,
    required this.lifecycle,
    required this.contractReferenceId,
    this.expectedPreviousReferenceId,
  });

  final Pillar3aBeneficiaryScanIntentKind kind;
  final String returnUri;
  final DateTime createdAt;
  final Pillar3aBeneficiaryScanIntentLifecycle lifecycle;
  final String contractReferenceId;
  final String? expectedPreviousReferenceId;

  Pillar3aBeneficiaryScanIntent _at(
    Pillar3aBeneficiaryScanIntentLifecycle next,
  ) =>
      Pillar3aBeneficiaryScanIntent._(
        kind: kind,
        returnUri: returnUri,
        createdAt: createdAt,
        lifecycle: next,
        contractReferenceId: contractReferenceId,
        expectedPreviousReferenceId: expectedPreviousReferenceId,
      );
}

@immutable
class ScanSessionPayload {
  final ExtractionResult extraction;
  final String? dataBlockScanReturnIntentId;
  final LppExtractionCandidate? lppCandidate;
  final LppAcquisitionAuthorization? lppAuthorization;
  final LppRegulationAcquisitionCandidate? lppRegulationCandidate;
  final LppCapitalNoticeAcquisitionCandidate? lppCapitalNoticeCandidate;
  final ManualPartnerAccountabilityContext? manualPartnerAccountability;
  final TaxExtractionCandidate? taxCandidate;
  final Pillar3aBeneficiaryAcquisitionCandidate? pillar3aBeneficiaryCandidate;
  final String? pillar3aScanContextId;
  final String? pillar3aReturnUri;
  final int? previousConfidence;

  const ScanSessionPayload({
    required this.extraction,
    this.dataBlockScanReturnIntentId,
    this.lppCandidate,
    this.lppAuthorization,
    this.lppRegulationCandidate,
    this.lppCapitalNoticeCandidate,
    this.manualPartnerAccountability,
    this.taxCandidate,
    this.pillar3aBeneficiaryCandidate,
    this.pillar3aScanContextId,
    this.pillar3aReturnUri,
    this.previousConfidence,
  });

  ScanSessionPayload withImpact({
    required ExtractionResult extraction,
    required int previousConfidence,
  }) {
    return ScanSessionPayload(
      extraction: _withoutSourceText(extraction),
      dataBlockScanReturnIntentId: dataBlockScanReturnIntentId,
      lppCandidate: null,
      lppAuthorization: null,
      lppRegulationCandidate: null,
      lppCapitalNoticeCandidate: null,
      manualPartnerAccountability: null,
      taxCandidate: null,
      pillar3aBeneficiaryCandidate: null,
      pillar3aScanContextId: null,
      pillar3aReturnUri: null,
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
  ScanSessionProvider({
    SessionEpoch? sessionEpoch,
    Uuid? uuid,
    DateTime Function()? now,
  })  : _sessionEpoch = sessionEpoch ?? SessionEpoch(),
        _uuid = uuid ?? const Uuid(),
        _now = now ?? DateTime.now;

  static const maxRetainedSessions = 5;
  static const maxRetainedDataBlockScanReturnIntents = 5;
  static const maxRetainedPillar3aBeneficiaryScanIntents = 5;
  final SessionEpoch _sessionEpoch;
  final Uuid _uuid;
  final DateTime Function() _now;
  final Map<String, ScanSessionPayload> _sessions = {};
  final Map<String, DataBlockScanReturnIntent> _dataBlockScanReturnIntents = {};
  final Map<String, Pillar3aBeneficiaryScanIntent>
      _pillar3aBeneficiaryScanIntents = {};
  int _nextId = 0;

  @visibleForTesting
  int get retainedSessionCount => _sessions.length;

  @visibleForTesting
  int get retainedDataBlockScanReturnIntentCount =>
      _dataBlockScanReturnIntents.length;

  @visibleForTesting
  int get retainedPillar3aBeneficiaryScanIntentCount =>
      _pillar3aBeneficiaryScanIntents.length;

  // The session registry is capped at five, so reverse lookup keeps the
  // session payload as the only intent-link SOT without an unbounded scan.
  String? _scanSessionIdForDataBlockScanReturnIntent(String intentId) {
    for (final entry in _sessions.entries) {
      if (entry.value.dataBlockScanReturnIntentId == intentId) {
        return entry.key;
      }
    }
    return null;
  }

  ScanSessionPayload? _removeScanSession(String id) {
    final removed = _sessions.remove(id);
    if (removed == null) return null;
    final dataBlockIntentId = removed.dataBlockScanReturnIntentId;
    if (dataBlockIntentId != null) {
      _dataBlockScanReturnIntents.remove(dataBlockIntentId);
    }
    final pillar3aContextId = removed.pillar3aScanContextId;
    if (pillar3aContextId != null) {
      _pillar3aBeneficiaryScanIntents.remove(pillar3aContextId);
    }
    return removed;
  }

  String retainDataBlockScanReturnIntent({
    required DataBlockScanReturnKind kind,
    required DataBlockReturnTarget target,
  }) {
    if (kind != DataBlockScanReturnKind.rvcLpp ||
        target.location != '/rente-vs-capital') {
      throw ArgumentError('Invalid DataBlock scan return intent');
    }
    final guard = _sessionEpoch.capture();
    final id = _uuid.v4();
    if (!isCanonicalUuidV4(id)) {
      throw StateError('RVC LPP scan identity failed');
    }
    _dataBlockScanReturnIntents[id] = DataBlockScanReturnIntent._(
      kind: kind,
      target: target,
      createdAt: _now().toUtc(),
      lifecycle: DataBlockScanReturnLifecycle.created,
    );
    while (_dataBlockScanReturnIntents.length >
        maxRetainedDataBlockScanReturnIntents) {
      final evictedIntentId = _dataBlockScanReturnIntents.keys.first;
      final linkedSessionId =
          _scanSessionIdForDataBlockScanReturnIntent(evictedIntentId);
      _dataBlockScanReturnIntents.remove(evictedIntentId);
      if (linkedSessionId != null) {
        _removeScanSession(linkedSessionId);
      }
    }
    guard.assertCurrent();
    notifyListeners();
    return id;
  }

  DataBlockScanReturnIntent? dataBlockScanReturnIntentById(String? id) {
    if (!isCanonicalUuidV4(id)) return null;
    return _dataBlockScanReturnIntents[id];
  }

  bool advanceDataBlockScanReturnIntent(
    String id, {
    required DataBlockScanReturnLifecycle from,
    required DataBlockScanReturnLifecycle to,
  }) {
    final current = _dataBlockScanReturnIntents[id];
    if (current == null ||
        current.lifecycle != from ||
        from != DataBlockScanReturnLifecycle.created ||
        to != DataBlockScanReturnLifecycle.processing) {
      return false;
    }
    final guard = _sessionEpoch.capture();
    _dataBlockScanReturnIntents[id] = current._at(to);
    guard.assertCurrent();
    notifyListeners();
    return true;
  }

  DataBlockReturnTarget? consumeDataBlockScanReturnIntent(String id) {
    final intent = _dataBlockScanReturnIntents[id];
    if (intent?.lifecycle != DataBlockScanReturnLifecycle.impactRetained) {
      return null;
    }
    final linkedSessionId = _scanSessionIdForDataBlockScanReturnIntent(id);
    if (linkedSessionId == null) return null;
    final guard = _sessionEpoch.capture();
    final target = intent!.target;
    _removeScanSession(linkedSessionId);
    guard.assertCurrent();
    notifyListeners();
    return target;
  }

  bool discardDataBlockScanReturnIntent(String id) {
    final guard = _sessionEpoch.capture();
    final linkedSessionId = _scanSessionIdForDataBlockScanReturnIntent(id);
    if (_dataBlockScanReturnIntents.remove(id) == null) return false;
    if (linkedSessionId != null) {
      _removeScanSession(linkedSessionId);
    }
    guard.assertCurrent();
    notifyListeners();
    return true;
  }

  String retainPillar3aBeneficiaryScanIntent({
    required Pillar3aBeneficiaryScanIntentKind kind,
    required String returnUri,
    String? contractReferenceId,
    String? expectedPreviousReferenceId,
  }) {
    if (returnUri != '/retraite') {
      throw ArgumentError.value(returnUri, 'returnUri');
    }
    final isInsertion = kind == Pillar3aBeneficiaryScanIntentKind.insertion;
    final hasCanonicalReplacementIds = isCanonicalUuidV4(contractReferenceId) &&
        isCanonicalUuidV4(expectedPreviousReferenceId) &&
        contractReferenceId != expectedPreviousReferenceId;
    if ((isInsertion &&
            (contractReferenceId != null ||
                expectedPreviousReferenceId != null)) ||
        (!isInsertion && !hasCanonicalReplacementIds)) {
      throw ArgumentError('Invalid pillar 3a beneficiary scan intent');
    }

    final guard = _sessionEpoch.capture();
    final id = _uuid.v4();
    final retainedContractReferenceId =
        isInsertion ? _uuid.v4() : contractReferenceId!;
    if (!isCanonicalUuidV4(id) ||
        !isCanonicalUuidV4(retainedContractReferenceId) ||
        id == retainedContractReferenceId) {
      throw StateError('Pillar 3a beneficiary scan identity failed');
    }
    _pillar3aBeneficiaryScanIntents[id] = Pillar3aBeneficiaryScanIntent._(
      kind: kind,
      returnUri: returnUri,
      createdAt: _now().toUtc(),
      lifecycle: Pillar3aBeneficiaryScanIntentLifecycle.created,
      contractReferenceId: retainedContractReferenceId,
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );
    while (_pillar3aBeneficiaryScanIntents.length >
        maxRetainedPillar3aBeneficiaryScanIntents) {
      final evictedId = _pillar3aBeneficiaryScanIntents.keys.first;
      _pillar3aBeneficiaryScanIntents.remove(evictedId);
      _sessions.removeWhere(
        (_, session) => session.pillar3aScanContextId == evictedId,
      );
    }
    guard.assertCurrent();
    notifyListeners();
    return id;
  }

  Pillar3aBeneficiaryScanIntent? pillar3aBeneficiaryScanIntentById(
    String? id, {
    required String returnUri,
  }) {
    if (id == null || id.isEmpty || returnUri != '/retraite') return null;
    final intent = _pillar3aBeneficiaryScanIntents[id];
    return intent?.returnUri == returnUri ? intent : null;
  }

  bool advancePillar3aBeneficiaryScanIntent(
    String id, {
    required Pillar3aBeneficiaryScanIntentLifecycle from,
    required Pillar3aBeneficiaryScanIntentLifecycle to,
  }) {
    final current = _pillar3aBeneficiaryScanIntents[id];
    if (current == null ||
        current.lifecycle != from ||
        !_isNextPillar3aBeneficiaryScanIntentLifecycle(from, to)) {
      return false;
    }
    final guard = _sessionEpoch.capture();
    _pillar3aBeneficiaryScanIntents[id] = current._at(to);
    guard.assertCurrent();
    notifyListeners();
    return true;
  }

  bool completePillar3aBeneficiaryScanIntent(String id) {
    final current = _pillar3aBeneficiaryScanIntents[id];
    if (current?.lifecycle !=
        Pillar3aBeneficiaryScanIntentLifecycle.ledgerAcceptedAwaitingBnd) {
      return false;
    }
    final guard = _sessionEpoch.capture();
    _pillar3aBeneficiaryScanIntents.remove(id);
    guard.assertCurrent();
    notifyListeners();
    return true;
  }

  bool discardPillar3aBeneficiaryScanIntent(String id) {
    final guard = _sessionEpoch.capture();
    if (_pillar3aBeneficiaryScanIntents.remove(id) == null) return false;
    _sessions.removeWhere(
      (_, session) => session.pillar3aScanContextId == id,
    );
    guard.assertCurrent();
    notifyListeners();
    return true;
  }

  String retainExtraction(
    ExtractionResult extraction, {
    String? dataBlockScanReturnIntentId,
    LppExtractionCandidate? lppCandidate,
    LppAcquisitionAuthorization? lppAuthorization,
    LppRegulationAcquisitionCandidate? lppRegulationCandidate,
    LppCapitalNoticeAcquisitionCandidate? lppCapitalNoticeCandidate,
    ManualPartnerAccountabilityContext? manualPartnerAccountability,
    TaxExtractionCandidate? taxCandidate,
    Pillar3aBeneficiaryAcquisitionCandidate? pillar3aBeneficiaryCandidate,
    String? pillar3aScanContextId,
    String? pillar3aReturnUri,
  }) {
    final guard = _sessionEpoch.capture();
    final hasLppCandidate = lppCandidate != null;
    final hasLppAuthorization = lppAuthorization != null;
    final isLppRegulation = extraction.documentType == DocumentType.lppPlan;
    final hasLppRegulationCandidate = lppRegulationCandidate != null;
    final hasLppCapitalNoticeCandidate = lppCapitalNoticeCandidate != null;
    final isPillar3aBeneficiary =
        extraction.documentType == DocumentType.pillar3aBeneficiaryClause;
    final hasPillar3aBeneficiaryCandidate =
        pillar3aBeneficiaryCandidate != null;
    final hasPillar3aIntentLink =
        pillar3aScanContextId != null && pillar3aReturnUri != null;
    final dataBlockIntent = dataBlockScanReturnIntentId == null
        ? null
        : _dataBlockScanReturnIntents[dataBlockScanReturnIntentId];
    if (dataBlockScanReturnIntentId != null &&
        (dataBlockIntent == null ||
            dataBlockIntent.kind != DataBlockScanReturnKind.rvcLpp ||
            dataBlockIntent.lifecycle !=
                DataBlockScanReturnLifecycle.processing ||
            _scanSessionIdForDataBlockScanReturnIntent(
                  dataBlockScanReturnIntentId,
                ) !=
                null)) {
      throw StateError('RVC scan return intent changed');
    }
    if (dataBlockScanReturnIntentId != null &&
        (extraction.documentType != DocumentType.lppCertificate ||
            !hasLppCandidate ||
            !hasLppAuthorization ||
            hasLppRegulationCandidate ||
            hasLppCapitalNoticeCandidate ||
            taxCandidate != null ||
            hasPillar3aBeneficiaryCandidate ||
            pillar3aScanContextId != null ||
            pillar3aReturnUri != null)) {
      throw ArgumentError(
        'RVC scan return requires one isolated authorized LPP certificate',
      );
    }
    if (isLppRegulation != hasLppRegulationCandidate ||
        (hasLppCapitalNoticeCandidate && !hasLppRegulationCandidate) ||
        (hasLppRegulationCandidate &&
            (!_isStrictEmptyLppRegulationExtraction(extraction) ||
                hasLppCandidate ||
                hasLppAuthorization ||
                manualPartnerAccountability != null ||
                taxCandidate != null ||
                hasPillar3aBeneficiaryCandidate))) {
      throw ArgumentError(
        'LPP regulation requires one isolated zero-fact acquisition candidate',
      );
    }
    if (isPillar3aBeneficiary != hasPillar3aBeneficiaryCandidate ||
        isPillar3aBeneficiary != hasPillar3aIntentLink ||
        (hasPillar3aBeneficiaryCandidate &&
            (!_isStrictEmptyLppRegulationExtraction(extraction) ||
                hasLppCandidate ||
                hasLppAuthorization ||
                hasLppRegulationCandidate ||
                manualPartnerAccountability != null ||
                taxCandidate != null))) {
      throw ArgumentError(
        'Pillar 3a beneficiary review requires one isolated authority candidate',
      );
    }
    final pillar3aIntent = hasPillar3aIntentLink
        ? pillar3aBeneficiaryScanIntentById(
            pillar3aScanContextId,
            returnUri: pillar3aReturnUri,
          )
        : null;
    if (hasPillar3aBeneficiaryCandidate &&
        (pillar3aIntent == null ||
            pillar3aIntent.lifecycle !=
                Pillar3aBeneficiaryScanIntentLifecycle.processing ||
            pillar3aIntent.contractReferenceId !=
                pillar3aBeneficiaryCandidate.contractReferenceId ||
            pillar3aIntent.expectedPreviousReferenceId !=
                pillar3aBeneficiaryCandidate.expectedPreviousReferenceId)) {
      throw StateError('Pillar 3a beneficiary scan intent changed');
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
      dataBlockScanReturnIntentId: dataBlockScanReturnIntentId,
      lppCandidate: lppCandidate,
      lppAuthorization: lppAuthorization,
      lppRegulationCandidate: lppRegulationCandidate,
      lppCapitalNoticeCandidate: lppCapitalNoticeCandidate,
      manualPartnerAccountability: manualPartnerAccountability,
      taxCandidate: taxCandidate,
      pillar3aBeneficiaryCandidate: pillar3aBeneficiaryCandidate,
      pillar3aScanContextId: pillar3aScanContextId,
      pillar3aReturnUri: pillar3aReturnUri,
    );
    if (dataBlockScanReturnIntentId != null) {
      _dataBlockScanReturnIntents[dataBlockScanReturnIntentId] =
          dataBlockIntent!._at(DataBlockScanReturnLifecycle.reviewRetained);
    } else if (hasPillar3aIntentLink &&
        !advancePillar3aBeneficiaryScanIntent(
          pillar3aScanContextId,
          from: Pillar3aBeneficiaryScanIntentLifecycle.processing,
          to: Pillar3aBeneficiaryScanIntentLifecycle.reviewRetained,
        )) {
      _sessions.remove(id);
      throw StateError('Pillar 3a beneficiary review handoff failed');
    }
    while (_sessions.length > maxRetainedSessions) {
      _removeScanSession(_sessions.keys.first);
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
    if (current.lppRegulationCandidate != null ||
        current.pillar3aBeneficiaryCandidate != null) {
      return false;
    }
    final dataBlockIntentId = current.dataBlockScanReturnIntentId;
    final dataBlockIntent = dataBlockIntentId == null
        ? null
        : _dataBlockScanReturnIntents[dataBlockIntentId];
    if (dataBlockIntentId != null &&
        (extraction.documentType != DocumentType.lppCertificate ||
            current.extraction.documentType != DocumentType.lppCertificate ||
            dataBlockIntent == null ||
            dataBlockIntent.kind != DataBlockScanReturnKind.rvcLpp ||
            dataBlockIntent.lifecycle !=
                DataBlockScanReturnLifecycle.reviewRetained ||
            _scanSessionIdForDataBlockScanReturnIntent(dataBlockIntentId) !=
                id)) {
      return false;
    }
    _sessions[id] = current.withImpact(
      extraction: extraction,
      previousConfidence: previousConfidence,
    );
    if (dataBlockIntentId != null) {
      _dataBlockScanReturnIntents[dataBlockIntentId] =
          dataBlockIntent!._at(DataBlockScanReturnLifecycle.impactRetained);
    }
    guard.assertCurrent();
    notifyListeners();
    return true;
  }

  void discard(String id) {
    final guard = _sessionEpoch.capture();
    final removed = _removeScanSession(id);
    if (removed != null) {
      guard.assertCurrent();
      notifyListeners();
    }
  }

  /// Drops volatile extraction candidates and authorizations on session exit.
  void clearSessionMemoryAfterPurge() {
    _sessions.clear();
    _dataBlockScanReturnIntents.clear();
    _pillar3aBeneficiaryScanIntents.clear();
    _nextId = 0;
    notifyListeners();
  }
}

bool _isNextPillar3aBeneficiaryScanIntentLifecycle(
  Pillar3aBeneficiaryScanIntentLifecycle from,
  Pillar3aBeneficiaryScanIntentLifecycle to,
) {
  return switch (from) {
    Pillar3aBeneficiaryScanIntentLifecycle.created =>
      to == Pillar3aBeneficiaryScanIntentLifecycle.processing,
    Pillar3aBeneficiaryScanIntentLifecycle.processing =>
      to == Pillar3aBeneficiaryScanIntentLifecycle.reviewRetained,
    Pillar3aBeneficiaryScanIntentLifecycle.reviewRetained =>
      to == Pillar3aBeneficiaryScanIntentLifecycle.ledgerAcceptedAwaitingBnd,
    Pillar3aBeneficiaryScanIntentLifecycle.ledgerAcceptedAwaitingBnd => false,
  };
}
