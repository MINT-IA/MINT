import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';

const _rvcOrigin = '/rente-vs-capital';
const _pillarReturnUri = '/retraite';
const _pillarAuthorityId = '22222222-2222-4222-8222-222222222222';
const _pillarReferenceId = '33333333-3333-4333-8333-333333333333';
const _taxSnapshotId = '44444444-4444-4444-8444-444444444444';

final _lppCandidate = LppExtractionAdapter.adapt(
  source: LppAcquisitionSource.localParser,
  sourceOverallConfidence: 0.99,
  fields: const <ExtractedField>[
    ExtractedField(
      fieldName: 'lpp_total',
      label: 'Avoir de vieillesse',
      value: 350000.0,
      confidence: 0.99,
      sourceText: '',
      needsReview: false,
    ),
  ],
).candidate!;

final _lppAuthorization = LppAcquisitionAuthorization(
  acquisitionId: '123e4567-e89b-42d3-a456-426614174000',
  subject: LppEvidenceOwnerKind.self,
  partnerAttested: false,
  policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
  declaredAt: DateTime.utc(2026, 7, 15, 9),
  documentSha256:
      '3d1f57c984978ef98a18378c8166c1cb8ede02c03eeb6aee7e2f121dfeee3e56',
);

final _lppReviewExtraction = ExtractionResult(
  documentType: DocumentType.lppCertificate,
  fields: <ExtractedField>[
    ExtractedField(
      fieldName: LppEvidenceFactKey.vestedBenefitsCapitalChf.wireName,
      label: 'Avoir de vieillesse',
      value: 350000.0,
      confidence: 0.99,
      sourceText: '',
      needsReview: false,
    ),
  ],
  overallConfidence: 0.99,
  confidenceDelta: 27,
  warnings: <String>[],
  disclaimer: '',
  sources: <String>[],
);

final _lppImpactExtraction = ExtractionResult(
  documentType: DocumentType.lppCertificate,
  fields: <ExtractedField>[
    ExtractedField(
      fieldName: LppEvidenceFactKey.vestedBenefitsCapitalChf.wireName,
      label: 'Avoir de vieillesse',
      value: 350000.0,
      confidence: 0.99,
      sourceText: 'SENSITIVE_SOURCE_SENTINEL',
      needsReview: false,
    ),
  ],
  overallConfidence: 0.99,
  confidenceDelta: 27,
  warnings: <String>[],
  disclaimer: '',
  sources: <String>[],
);

const _wrongDocumentExtraction = ExtractionResult(
  documentType: DocumentType.avsExtract,
  fields: <ExtractedField>[
    ExtractedField(
      fieldName: 'avsContributions',
      label: 'Cotisations AVS',
      value: 100000.0,
      confidence: 0.99,
      sourceText: '',
      needsReview: false,
    ),
  ],
  overallConfidence: 0.99,
  confidenceDelta: 12,
  warnings: <String>[],
  disclaimer: '',
  sources: <String>[],
);

const _taxExtraction = ExtractionResult(
  documentType: DocumentType.taxDeclaration,
  fields: <ExtractedField>[],
  overallConfidence: 0,
  confidenceDelta: 0,
  warnings: <String>[],
  disclaimer: '',
  sources: <String>[],
);

final _taxCandidate = TaxExtractionCandidate.fromExtractionResult(
  _taxExtraction,
  snapshotIdFactory: () => _taxSnapshotId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('RVC LPP intent retains exact typed kind target and UUID identity', () {
    final createdAt = DateTime.utc(2026, 7, 19, 14, 30);
    final provider = ScanSessionProvider(now: () => createdAt);
    addTearDown(provider.dispose);
    final target = parseDataBlockReturnTarget(_rvcOrigin)!;

    final id = provider.retainDataBlockScanReturnIntent(
      kind: DataBlockScanReturnKind.rvcLpp,
      target: target,
    );
    final intent = provider.dataBlockScanReturnIntentById(id)!;

    expect(id, matches(_canonicalUuidV4));
    expect(intent.kind, DataBlockScanReturnKind.rvcLpp);
    expect(intent.target.location, target.location);
    expect(intent.target.location, _rvcOrigin);
    expect(intent.createdAt, createdAt);
    expect(intent.createdAt.isUtc, isTrue);
    expect(intent.lifecycle, DataBlockScanReturnLifecycle.created);
    expect(provider.dataBlockScanReturnIntentById('not-a-uuid'), isNull);
    expect(
      () => provider.retainDataBlockScanReturnIntent(
        kind: DataBlockScanReturnKind.rvcLpp,
        target: DataBlockReturnTarget.home,
      ),
      throwsArgumentError,
    );
  });

  test('RVC lifecycle is one-way CAS without skip back or replay', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final id = _retainRvcIntent(provider);
    final created = provider.dataBlockScanReturnIntentById(id)!;

    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.created,
        to: DataBlockScanReturnLifecycle.created,
      ),
      isFalse,
    );
    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.processing,
        to: DataBlockScanReturnLifecycle.created,
      ),
      isFalse,
    );
    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.created,
        to: DataBlockScanReturnLifecycle.processing,
      ),
      isTrue,
    );
    final processing = provider.dataBlockScanReturnIntentById(id)!;
    expect(processing.lifecycle, DataBlockScanReturnLifecycle.processing);
    expect(processing.kind, created.kind);
    expect(processing.target.location, created.target.location);
    expect(processing.createdAt, created.createdAt);
    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.created,
        to: DataBlockScanReturnLifecycle.processing,
      ),
      isFalse,
    );
    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.processing,
        to: DataBlockScanReturnLifecycle.created,
      ),
      isFalse,
    );
    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.processing,
        to: DataBlockScanReturnLifecycle.processing,
      ),
      isFalse,
    );
    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.processing,
        to: DataBlockScanReturnLifecycle.reviewRetained,
      ),
      isFalse,
    );
    expect(
      provider.advanceDataBlockScanReturnIntent(
        id,
        from: DataBlockScanReturnLifecycle.reviewRetained,
        to: DataBlockScanReturnLifecycle.impactRetained,
      ),
      isFalse,
    );
    expect(
      provider.advanceDataBlockScanReturnIntent(
        '11111111-1111-4111-8111-111111111111',
        from: DataBlockScanReturnLifecycle.created,
        to: DataBlockScanReturnLifecycle.processing,
      ),
      isFalse,
    );
  });

  test('retainExtraction authoritatively links realistic RVC LPP review', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final intentId = _retainProcessingRvcIntent(provider);

    final scanSessionId = _retainRvcReview(provider, intentId);

    final session = provider.byId(scanSessionId)!;
    final intent = provider.dataBlockScanReturnIntentById(intentId)!;
    final candidate = session.lppCandidate!;
    final fact = candidate.facts[LppEvidenceFactKey.vestedBenefitsCapitalChf]!;
    final authorization = session.lppAuthorization!;
    expect(session.dataBlockScanReturnIntentId, intentId);
    expect(
      (
        source: candidate.source,
        sourceDate: candidate.sourceDate,
        confidence: candidate.overallConfidence,
        factCount: candidate.facts.length,
        factKey: fact.key,
        factValue: fact.value,
        factConfidence: fact.confidence,
        factNeedsReview: fact.needsReview,
        factDerived: fact.derived,
      ),
      (
        source: LppAcquisitionSource.localParser,
        sourceDate: null,
        confidence: 0.99,
        factCount: 1,
        factKey: LppEvidenceFactKey.vestedBenefitsCapitalChf,
        factValue: 350000.0,
        factConfidence: 0.99,
        factNeedsReview: false,
        factDerived: false,
      ),
    );
    expect(
      (
        acquisitionId: authorization.acquisitionId,
        subject: authorization.subject,
        partnerAttested: authorization.partnerAttested,
        policyVersion: authorization.policyVersion,
        declaredAt: authorization.declaredAt,
        documentSha256: authorization.documentSha256,
        manualPartnerOwnerId: authorization.manualPartnerOwnerId,
        receiptId: authorization.receiptId,
      ),
      (
        acquisitionId: _lppAuthorization.acquisitionId,
        subject: LppEvidenceOwnerKind.self,
        partnerAttested: false,
        policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
        declaredAt: _lppAuthorization.declaredAt,
        documentSha256: _lppAuthorization.documentSha256,
        manualPartnerOwnerId: null,
        receiptId: null,
      ),
    );
    expect(intent.lifecycle, DataBlockScanReturnLifecycle.reviewRetained);
  });

  test('RVC review rejects unknown intent with zero mutation', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    _expectRvcReviewStateError(
      provider,
      '11111111-1111-4111-8111-111111111111',
      _lppReviewExtraction,
      lppCandidate: _lppCandidate,
      lppAuthorization: _lppAuthorization,
    );
  });

  test('RVC review rejects created lifecycle with zero mutation', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    _expectRvcReviewStateError(
      provider,
      _retainRvcIntent(provider),
      _lppReviewExtraction,
      lppCandidate: _lppCandidate,
      lppAuthorization: _lppAuthorization,
    );
  });

  test('RVC review rejects wrong document with zero mutation', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    _expectRvcReviewArgumentError(
      provider,
      _retainProcessingRvcIntent(provider),
      _wrongDocumentExtraction,
      lppCandidate: _lppCandidate,
      lppAuthorization: _lppAuthorization,
    );
  });

  test('RVC review rejects missing candidate with zero mutation', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    _expectRvcReviewArgumentError(
      provider,
      _retainProcessingRvcIntent(provider),
      _lppReviewExtraction,
      lppAuthorization: _lppAuthorization,
    );
  });

  test('RVC review rejects missing authorization with zero mutation', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    _expectRvcReviewArgumentError(
      provider,
      _retainProcessingRvcIntent(provider),
      _lppReviewExtraction,
      lppCandidate: _lppCandidate,
    );
  });

  test('RVC review rejects a valid tax candidate with zero mutation', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    _expectRvcReviewArgumentError(
      provider,
      _retainProcessingRvcIntent(provider),
      _lppReviewExtraction,
      lppCandidate: _lppCandidate,
      lppAuthorization: _lppAuthorization,
      taxCandidate: _taxCandidate,
    );
  });

  test('RVC review rejects a lone real Pillar3a context with zero mutation',
      () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final pillarContextId = provider.retainPillar3aBeneficiaryScanIntent(
      kind: Pillar3aBeneficiaryScanIntentKind.insertion,
      returnUri: _pillarReturnUri,
    );
    expect(
      provider.advancePillar3aBeneficiaryScanIntent(
        pillarContextId,
        from: Pillar3aBeneficiaryScanIntentLifecycle.created,
        to: Pillar3aBeneficiaryScanIntentLifecycle.processing,
      ),
      isTrue,
    );

    _expectRvcReviewArgumentError(
      provider,
      _retainProcessingRvcIntent(provider),
      _lppReviewExtraction,
      lppCandidate: _lppCandidate,
      lppAuthorization: _lppAuthorization,
      pillar3aScanContextId: pillarContextId,
    );
  });

  test('RVC review rejects a lone Pillar3a return URI with zero mutation', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    _expectRvcReviewArgumentError(
      provider,
      _retainProcessingRvcIntent(provider),
      _lppReviewExtraction,
      lppCandidate: _lppCandidate,
      lppAuthorization: _lppAuthorization,
      pillar3aReturnUri: _pillarReturnUri,
    );
  });

  test('RVC review rejects a valid Pillar3a branch mix with zero mutation', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final rvcIntentId = _retainProcessingRvcIntent(provider);
    final pillarContextId = provider.retainPillar3aBeneficiaryScanIntent(
      kind: Pillar3aBeneficiaryScanIntentKind.insertion,
      returnUri: _pillarReturnUri,
    );
    expect(
      provider.advancePillar3aBeneficiaryScanIntent(
        pillarContextId,
        from: Pillar3aBeneficiaryScanIntentLifecycle.created,
        to: Pillar3aBeneficiaryScanIntentLifecycle.processing,
      ),
      isTrue,
    );
    final pillarIntent = provider.pillar3aBeneficiaryScanIntentById(
      pillarContextId,
      returnUri: _pillarReturnUri,
    )!;
    final candidate = Pillar3aBeneficiaryAcquisitionCandidate(
      contractReferenceId: pillarIntent.contractReferenceId,
      referenceId: _pillarReferenceId,
      authority: _pillarAuthority(),
    );

    _expectRvcReviewArgumentError(
      provider,
      rvcIntentId,
      _pillarExtraction,
      pillar3aBeneficiaryCandidate: candidate,
      pillar3aScanContextId: pillarContextId,
      pillar3aReturnUri: _pillarReturnUri,
    );
  });

  test('retainExtraction replay cannot relink one RVC intent', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final intentId = _retainProcessingRvcIntent(provider);
    final scanSessionId = _retainRvcReview(provider, intentId);
    final before = _providerSnapshot(
      provider,
      intentId: intentId,
      scanSessionId: scanSessionId,
    );
    var notifications = 0;
    void listener() => notifications += 1;
    provider.addListener(listener);
    StateError? error;
    String? replaySessionId;
    try {
      replaySessionId = _retainRvcReview(provider, intentId);
    } on StateError catch (caught) {
      error = caught;
    }
    provider.removeListener(listener);

    expect(
      (
        rejected: error != null,
        replaySessionId: replaySessionId,
        originalSessionPresent: provider.byId(scanSessionId) != null,
        notifications: notifications,
        snapshot: _providerSnapshot(
          provider,
          intentId: intentId,
          scanSessionId: scanSessionId,
        ),
      ),
      (
        rejected: true,
        replaySessionId: null,
        originalSessionPresent: true,
        notifications: 0,
        snapshot: before,
      ),
    );
  });

  test('retainImpact rejects wrong document without changing RVC review', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final intentId = _retainProcessingRvcIntent(provider);
    final scanSessionId = _retainRvcReview(provider, intentId);
    final before = _providerSnapshot(
      provider,
      intentId: intentId,
      scanSessionId: scanSessionId,
    );
    var notifications = 0;
    void listener() => notifications += 1;
    provider.addListener(listener);

    final accepted = provider.retainImpact(
      scanSessionId,
      extraction: _wrongDocumentExtraction,
      previousConfidence: 40,
    );
    provider.removeListener(listener);

    expect(
      (
        accepted: accepted,
        notifications: notifications,
        snapshot: _providerSnapshot(
          provider,
          intentId: intentId,
          scanSessionId: scanSessionId,
        ),
      ),
      (
        accepted: false,
        notifications: 0,
        snapshot: before,
      ),
    );
  });

  test('retainImpact rejects missing session without mutating RVC intent', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final intentId = _retainProcessingRvcIntent(provider);
    final scanSessionId = _retainRvcReview(provider, intentId);
    final before = _providerSnapshot(
      provider,
      intentId: intentId,
      scanSessionId: scanSessionId,
    );
    var notifications = 0;
    void listener() => notifications += 1;
    provider.addListener(listener);

    final accepted = provider.retainImpact(
      'missing-session',
      extraction: _lppImpactExtraction,
      previousConfidence: 40,
    );
    provider.removeListener(listener);

    expect(
      (
        accepted: accepted,
        notifications: notifications,
        snapshot: _providerSnapshot(
          provider,
          intentId: intentId,
          scanSessionId: scanSessionId,
        ),
      ),
      (
        accepted: false,
        notifications: 0,
        snapshot: before,
      ),
    );
  });

  test('retainImpact authoritatively advances linked RVC and scrubs source',
      () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final intentId = _retainProcessingRvcIntent(provider);
    final scanSessionId = _retainRvcReview(provider, intentId);
    expect(
      provider.advanceDataBlockScanReturnIntent(
        intentId,
        from: DataBlockScanReturnLifecycle.reviewRetained,
        to: DataBlockScanReturnLifecycle.impactRetained,
      ),
      isFalse,
    );
    expect(
      provider.retainImpact(
        scanSessionId,
        extraction: _lppImpactExtraction,
        previousConfidence: 40,
      ),
      isTrue,
    );
    final impact = provider.byId(scanSessionId)!;
    expect(impact.previousConfidence, 40);
    expect(impact.extraction.fields.single.sourceText, isEmpty);
    expect(impact.lppCandidate, isNull);
    expect(impact.lppAuthorization, isNull);
    expect(impact.lppRegulationCandidate, isNull);
    expect(impact.lppCapitalNoticeCandidate, isNull);
    expect(impact.manualPartnerAccountability, isNull);
    expect(impact.taxCandidate, isNull);
    expect(impact.pillar3aBeneficiaryCandidate, isNull);
    expect(impact.pillar3aScanContextId, isNull);
    expect(impact.pillar3aReturnUri, isNull);
    expect(impact.dataBlockScanReturnIntentId, intentId);
    expect(
      provider.dataBlockScanReturnIntentById(intentId)?.lifecycle,
      DataBlockScanReturnLifecycle.impactRetained,
    );
  });

  test('retainImpact replay is rejected without a second mutation', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final intentId = _retainProcessingRvcIntent(provider);
    final scanSessionId = _retainRvcReview(provider, intentId);
    expect(
      provider.retainImpact(
        scanSessionId,
        extraction: _lppImpactExtraction,
        previousConfidence: 40,
      ),
      isTrue,
    );
    final before = _providerSnapshot(
      provider,
      intentId: intentId,
      scanSessionId: scanSessionId,
    );
    var notifications = 0;
    void listener() => notifications += 1;
    provider.addListener(listener);

    final replayed = provider.retainImpact(
      scanSessionId,
      extraction: _lppImpactExtraction,
      previousConfidence: 40,
    );
    provider.removeListener(listener);

    expect(
      (
        replayed: replayed,
        notifications: notifications,
        snapshot: _providerSnapshot(
          provider,
          intentId: intentId,
          scanSessionId: scanSessionId,
        ),
      ),
      (
        replayed: false,
        notifications: 0,
        snapshot: before,
      ),
    );
  });

  test('impacting RVC session A cannot mutate linked session B', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final intentA = _retainProcessingRvcIntent(provider);
    final sessionA = _retainRvcReview(provider, intentA);
    final intentB = _retainProcessingRvcIntent(provider);
    final sessionB = _retainRvcReview(provider, intentB);

    expect(
      provider.retainImpact(
        sessionA,
        extraction: _lppImpactExtraction,
        previousConfidence: 40,
      ),
      isTrue,
    );

    expect(
      (
        aLink: provider.byId(sessionA)?.dataBlockScanReturnIntentId,
        aLifecycle: provider.dataBlockScanReturnIntentById(intentA)?.lifecycle,
        bLink: provider.byId(sessionB)?.dataBlockScanReturnIntentId,
        bLifecycle: provider.dataBlockScanReturnIntentById(intentB)?.lifecycle,
        bPreviousConfidence: provider.byId(sessionB)?.previousConfidence,
      ),
      (
        aLink: intentA,
        aLifecycle: DataBlockScanReturnLifecycle.impactRetained,
        bLink: intentB,
        bLifecycle: DataBlockScanReturnLifecycle.reviewRetained,
        bPreviousConfidence: null,
      ),
    );
  });

  test('consume rejects unknown created processing and review lifecycles', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    const unknownIntentId = '55555555-5555-4555-8555-555555555555';
    final createdIntentId = _retainRvcIntent(provider);
    final processingIntentId = _retainProcessingRvcIntent(provider);
    final reviewIntentId = _retainProcessingRvcIntent(provider);
    final reviewSessionId = _retainRvcReview(provider, reviewIntentId);

    _expectConsumeRejected(provider, unknownIntentId);
    _expectConsumeRejected(provider, createdIntentId);
    _expectConsumeRejected(provider, processingIntentId);
    _expectConsumeRejected(
      provider,
      reviewIntentId,
      scanSessionId: reviewSessionId,
    );
  });

  test('consume resolves impact target once and preserves every survivor', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final targetIntentId = _retainProcessingRvcIntent(provider);
    final targetSessionId = _retainRvcReview(provider, targetIntentId);
    expect(
      provider.retainImpact(
        targetSessionId,
        extraction: _lppImpactExtraction,
        previousConfidence: 40,
      ),
      isTrue,
    );
    final expectedTarget =
        provider.dataBlockScanReturnIntentById(targetIntentId)!.target;

    final linkedSurvivorIntentId = _retainProcessingRvcIntent(provider);
    final linkedSurvivorSessionId =
        _retainRvcReview(provider, linkedSurvivorIntentId);
    final linkedSurvivorBefore = _survivorSnapshot(
      provider,
      scanSessionId: linkedSurvivorSessionId,
      intentId: linkedSurvivorIntentId,
    );
    final genericSurvivors = _retainNonLinkedSurvivors(provider);

    var notifications = 0;
    void listener() => notifications += 1;
    provider.addListener(listener);
    final resolved = provider.consumeDataBlockScanReturnIntent(targetIntentId);
    provider.removeListener(listener);

    expect(
      _survivorSnapshot(
        provider,
        scanSessionId: linkedSurvivorSessionId,
        intentId: linkedSurvivorIntentId,
      ),
      linkedSurvivorBefore,
    );
    expect(
      _survivorSnapshot(
        provider,
        scanSessionId: genericSurvivors.scanSessionId,
        intentId: genericSurvivors.intentId,
      ),
      genericSurvivors.snapshot,
    );
    expect(
      (
        target: resolved?.location,
        notifications: notifications,
        intentRemoved:
            provider.dataBlockScanReturnIntentById(targetIntentId) == null,
        sessionRemoved: provider.byId(targetSessionId) == null,
      ),
      (
        target: expectedTarget.location,
        notifications: 1,
        intentRemoved: true,
        sessionRemoved: true,
      ),
    );

    notifications = 0;
    provider.addListener(listener);
    final replayed = provider.consumeDataBlockScanReturnIntent(targetIntentId);
    provider.removeListener(listener);
    expect(
      (target: replayed, notifications: notifications),
      (target: null, notifications: 0),
    );
  });

  test('discarding linked session also discards its RVC intent', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final intentId = _retainProcessingRvcIntent(provider);
    final scanSessionId = _retainRvcReview(provider, intentId);
    final survivors = _retainNonLinkedSurvivors(provider);

    provider.discard(scanSessionId);

    expect(
      _survivorSnapshot(
        provider,
        scanSessionId: survivors.scanSessionId,
        intentId: survivors.intentId,
      ),
      survivors.snapshot,
    );
    expect(provider.byId(scanSessionId), isNull);
    expect(provider.dataBlockScanReturnIntentById(intentId), isNull);
  });

  test('discarding linked RVC intent also discards its session', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final intentId = _retainProcessingRvcIntent(provider);
    final scanSessionId = _retainRvcReview(provider, intentId);
    final survivors = _retainNonLinkedSurvivors(provider);

    expect(provider.discardDataBlockScanReturnIntent(intentId), isTrue);

    expect(
      _survivorSnapshot(
        provider,
        scanSessionId: survivors.scanSessionId,
        intentId: survivors.intentId,
      ),
      survivors.snapshot,
    );
    expect(provider.dataBlockScanReturnIntentById(intentId), isNull);
    expect(provider.byId(scanSessionId), isNull);
  });

  test('RVC intent FIFO eviction purges its linked session', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final intentId = _retainProcessingRvcIntent(provider);
    final scanSessionId = _retainRvcReview(provider, intentId);
    final survivors = _retainNonLinkedSurvivors(provider);
    for (var index = 0;
        index < ScanSessionProvider.maxRetainedDataBlockScanReturnIntents - 1;
        index++) {
      _retainRvcIntent(provider);
    }

    expect(
      _survivorSnapshot(
        provider,
        scanSessionId: survivors.scanSessionId,
        intentId: survivors.intentId,
      ),
      survivors.snapshot,
    );
    expect(provider.dataBlockScanReturnIntentById(intentId), isNull);
    expect(provider.byId(scanSessionId), isNull);
  });

  test('session FIFO eviction purges its linked RVC intent', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final intentId = _retainProcessingRvcIntent(provider);
    final scanSessionId = _retainRvcReview(provider, intentId);
    final survivors = _retainNonLinkedSurvivors(provider);
    for (var index = 0;
        index < ScanSessionProvider.maxRetainedSessions - 1;
        index++) {
      provider.retainExtraction(_wrongDocumentExtraction);
    }

    expect(
      _survivorSnapshot(
        provider,
        scanSessionId: survivors.scanSessionId,
        intentId: survivors.intentId,
      ),
      survivors.snapshot,
    );
    expect(provider.byId(scanSessionId), isNull);
    expect(provider.dataBlockScanReturnIntentById(intentId), isNull);
  });

  test('logout purge clears linked RVC session and intent', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final intentId = _retainProcessingRvcIntent(provider);
    final scanSessionId = _retainRvcReview(provider, intentId);

    provider.clearSessionMemoryAfterPurge();

    expect(provider.byId(scanSessionId), isNull);
    expect(provider.dataBlockScanReturnIntentById(intentId), isNull);
  });

  test('RVC intent registry is FIFO five and logout purge clears all', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final ids = <String>[
      for (var index = 0; index < 6; index++) _retainRvcIntent(provider),
    ];

    expect(provider.retainedDataBlockScanReturnIntentCount, 5);
    expect(provider.dataBlockScanReturnIntentById(ids.first), isNull);
    for (final retainedId in ids.skip(1)) {
      expect(provider.dataBlockScanReturnIntentById(retainedId), isNotNull);
    }

    provider.clearSessionMemoryAfterPurge();

    expect(provider.retainedDataBlockScanReturnIntentCount, 0);
    for (final id in ids) {
      expect(provider.dataBlockScanReturnIntentById(id), isNull);
    }
  });

  test('RVC discard is terminal and idempotent', () {
    final provider = ScanSessionProvider();
    addTearDown(provider.dispose);
    final id = _retainRvcIntent(provider);

    expect(provider.discardDataBlockScanReturnIntent(id), isTrue);
    expect(provider.dataBlockScanReturnIntentById(id), isNull);
    expect(provider.discardDataBlockScanReturnIntent(id), isFalse);
    expect(provider.retainedDataBlockScanReturnIntentCount, 0);
  });
}

String _retainRvcIntent(ScanSessionProvider provider) =>
    provider.retainDataBlockScanReturnIntent(
      kind: DataBlockScanReturnKind.rvcLpp,
      target: parseDataBlockReturnTarget(_rvcOrigin)!,
    );

String _retainProcessingRvcIntent(ScanSessionProvider provider) {
  final id = _retainRvcIntent(provider);
  expect(
    provider.advanceDataBlockScanReturnIntent(
      id,
      from: DataBlockScanReturnLifecycle.created,
      to: DataBlockScanReturnLifecycle.processing,
    ),
    isTrue,
  );
  return id;
}

String _retainRvcReview(ScanSessionProvider provider, String intentId) =>
    provider.retainExtraction(
      _lppReviewExtraction,
      dataBlockScanReturnIntentId: intentId,
      lppCandidate: _lppCandidate,
      lppAuthorization: _lppAuthorization,
    );

({String scanSessionId, String intentId, Object snapshot})
    _retainNonLinkedSurvivors(ScanSessionProvider provider) {
  final scanSessionId = provider.retainExtraction(_wrongDocumentExtraction);
  final intentId = _retainRvcIntent(provider);
  return (
    scanSessionId: scanSessionId,
    intentId: intentId,
    snapshot: _survivorSnapshot(
      provider,
      scanSessionId: scanSessionId,
      intentId: intentId,
    ),
  );
}

Object _survivorSnapshot(
  ScanSessionProvider provider, {
  required String scanSessionId,
  required String intentId,
}) {
  final session = provider.byId(scanSessionId);
  final intent = provider.dataBlockScanReturnIntentById(intentId);
  return (
    session: session == null
        ? null
        : (
            dataBlockScanReturnIntentId: session.dataBlockScanReturnIntentId,
            documentType: session.extraction.documentType,
            fieldCount: session.extraction.fields.length,
            previousConfidence: session.previousConfidence,
          ),
    intent: intent == null
        ? null
        : (
            kind: intent.kind,
            target: intent.target.location,
            createdAt: intent.createdAt,
            lifecycle: intent.lifecycle,
          ),
  );
}

void _expectConsumeRejected(
  ScanSessionProvider provider,
  String intentId, {
  String? scanSessionId,
}) {
  final before = _providerSnapshot(
    provider,
    intentId: intentId,
    scanSessionId: scanSessionId,
  );
  var notifications = 0;
  void listener() => notifications += 1;
  provider.addListener(listener);
  final resolved = provider.consumeDataBlockScanReturnIntent(intentId);
  provider.removeListener(listener);
  expect(
    (
      target: resolved,
      notifications: notifications,
      snapshot: _providerSnapshot(
        provider,
        intentId: intentId,
        scanSessionId: scanSessionId,
      ),
    ),
    (
      target: null,
      notifications: 0,
      snapshot: before,
    ),
  );
}

void _expectRvcReviewStateError(
  ScanSessionProvider provider,
  String intentId,
  ExtractionResult extraction, {
  LppExtractionCandidate? lppCandidate,
  LppAcquisitionAuthorization? lppAuthorization,
  Pillar3aBeneficiaryAcquisitionCandidate? pillar3aBeneficiaryCandidate,
  String? pillar3aScanContextId,
  String? pillar3aReturnUri,
}) {
  final before = _providerSnapshot(
    provider,
    intentId: intentId,
    pillar3aScanContextId: pillar3aScanContextId,
    pillar3aReturnUri: pillar3aReturnUri,
  );
  var notifications = 0;
  void listener() => notifications += 1;
  provider.addListener(listener);
  StateError? rejection;
  String? returnedSessionId;
  try {
    returnedSessionId = provider.retainExtraction(
      extraction,
      dataBlockScanReturnIntentId: intentId,
      lppCandidate: lppCandidate,
      lppAuthorization: lppAuthorization,
      pillar3aBeneficiaryCandidate: pillar3aBeneficiaryCandidate,
      pillar3aScanContextId: pillar3aScanContextId,
      pillar3aReturnUri: pillar3aReturnUri,
    );
  } on StateError catch (caught) {
    rejection = caught;
  }
  provider.removeListener(listener);

  expect(
    (
      rejected: rejection != null,
      returnedSessionId: returnedSessionId,
      returnedSessionPresent:
          returnedSessionId != null && provider.byId(returnedSessionId) != null,
      notifications: notifications,
      snapshot: _providerSnapshot(
        provider,
        intentId: intentId,
        pillar3aScanContextId: pillar3aScanContextId,
        pillar3aReturnUri: pillar3aReturnUri,
      ),
    ),
    (
      rejected: true,
      returnedSessionId: null,
      returnedSessionPresent: false,
      notifications: 0,
      snapshot: before,
    ),
  );
}

void _expectRvcReviewArgumentError(
  ScanSessionProvider provider,
  String intentId,
  ExtractionResult extraction, {
  LppExtractionCandidate? lppCandidate,
  LppAcquisitionAuthorization? lppAuthorization,
  TaxExtractionCandidate? taxCandidate,
  Pillar3aBeneficiaryAcquisitionCandidate? pillar3aBeneficiaryCandidate,
  String? pillar3aScanContextId,
  String? pillar3aReturnUri,
}) {
  final before = _providerSnapshot(
    provider,
    intentId: intentId,
    pillar3aScanContextId: pillar3aScanContextId,
    pillar3aReturnUri: pillar3aReturnUri,
  );
  var notifications = 0;
  void listener() => notifications += 1;
  provider.addListener(listener);
  ArgumentError? rejection;
  String? returnedSessionId;
  try {
    returnedSessionId = provider.retainExtraction(
      extraction,
      dataBlockScanReturnIntentId: intentId,
      lppCandidate: lppCandidate,
      lppAuthorization: lppAuthorization,
      taxCandidate: taxCandidate,
      pillar3aBeneficiaryCandidate: pillar3aBeneficiaryCandidate,
      pillar3aScanContextId: pillar3aScanContextId,
      pillar3aReturnUri: pillar3aReturnUri,
    );
  } on ArgumentError catch (caught) {
    rejection = caught;
  }
  provider.removeListener(listener);

  expect(
    (
      rejected: rejection != null,
      returnedSessionId: returnedSessionId,
      returnedSessionPresent:
          returnedSessionId != null && provider.byId(returnedSessionId) != null,
      notifications: notifications,
      snapshot: _providerSnapshot(
        provider,
        intentId: intentId,
        pillar3aScanContextId: pillar3aScanContextId,
        pillar3aReturnUri: pillar3aReturnUri,
      ),
    ),
    (
      rejected: true,
      returnedSessionId: null,
      returnedSessionPresent: false,
      notifications: 0,
      snapshot: before,
    ),
  );
}

({
  int sessionCount,
  int rvcIntentCount,
  int pillarIntentCount,
  ({
    DataBlockScanReturnKind kind,
    String target,
    DateTime createdAt,
    DataBlockScanReturnLifecycle lifecycle,
  })? rvcIntent,
  ({
    Pillar3aBeneficiaryScanIntentKind kind,
    String returnUri,
    DateTime createdAt,
    Pillar3aBeneficiaryScanIntentLifecycle lifecycle,
    String contractReferenceId,
    String? expectedPreviousReferenceId,
  })? pillarIntent,
  ({
    String? dataBlockScanReturnIntentId,
    DocumentType documentType,
    int fieldCount,
    String sourceText,
    int? previousConfidence,
    bool hasLppCandidate,
    bool hasLppAuthorization,
  })? session,
}) _providerSnapshot(
  ScanSessionProvider provider, {
  required String intentId,
  String? scanSessionId,
  String? pillar3aScanContextId,
  String? pillar3aReturnUri,
}) {
  final intent = provider.dataBlockScanReturnIntentById(intentId);
  final session = provider.byId(scanSessionId);
  final pillarIntent = pillar3aScanContextId == null
      ? null
      : provider.pillar3aBeneficiaryScanIntentById(
          pillar3aScanContextId,
          returnUri: pillar3aReturnUri ?? _pillarReturnUri,
        );
  return (
    sessionCount: provider.retainedSessionCount,
    rvcIntentCount: provider.retainedDataBlockScanReturnIntentCount,
    pillarIntentCount: provider.retainedPillar3aBeneficiaryScanIntentCount,
    rvcIntent: intent == null
        ? null
        : (
            kind: intent.kind,
            target: intent.target.location,
            createdAt: intent.createdAt,
            lifecycle: intent.lifecycle,
          ),
    pillarIntent: pillarIntent == null
        ? null
        : (
            kind: pillarIntent.kind,
            returnUri: pillarIntent.returnUri,
            createdAt: pillarIntent.createdAt,
            lifecycle: pillarIntent.lifecycle,
            contractReferenceId: pillarIntent.contractReferenceId,
            expectedPreviousReferenceId:
                pillarIntent.expectedPreviousReferenceId,
          ),
    session: session == null
        ? null
        : (
            dataBlockScanReturnIntentId: session.dataBlockScanReturnIntentId,
            documentType: session.extraction.documentType,
            fieldCount: session.extraction.fields.length,
            sourceText: session.extraction.fields
                .map((field) => field.sourceText)
                .join('|'),
            previousConfidence: session.previousConfidence,
            hasLppCandidate: session.lppCandidate != null,
            hasLppAuthorization: session.lppAuthorization != null,
          ),
  );
}

const _pillarExtraction = ExtractionResult(
  documentType: DocumentType.pillar3aBeneficiaryClause,
  fields: <ExtractedField>[],
  overallConfidence: 0,
  confidenceDelta: 0,
  warnings: <String>[],
  disclaimer: '',
  sources: <String>[],
);

Pillar3aBeneficiaryAuthorityCandidateV1 _pillarAuthority() =>
    Pillar3aBeneficiaryAuthorityCandidateV1.exactDates(
      schemaVersion: 1,
      documentAuthorityId: _pillarAuthorityId,
      documentKind:
          Pillar3aBeneficiaryAuthorityDocumentKind.confirmationInstitutionnelle,
      sourceDate: DateTime.utc(2026, 7, 18),
      legalYear: 2026,
      institutionAttested: true,
      contractScoped: true,
      needsReview: true,
      designationEffectiveDate: DateTime.utc(2026, 1, 15),
      lastAssignmentModificationDate: null,
    );

final _canonicalUuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
