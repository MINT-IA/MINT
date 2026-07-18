import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/consent/partner_accountability_service.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:provider/provider.dart';

final class _StaticCoachProvider extends CoachProfileProvider {
  _StaticCoachProvider(this.value);

  final CoachProfile value;

  @override
  CoachProfile get profile => value;

  @override
  bool get hasProfile => true;
}

final class _ScanSessionSpy extends ScanSessionProvider {
  final retainedAuthorizations = <LppAcquisitionAuthorization>[];
  final retainedRegulationCandidates = <LppRegulationAcquisitionCandidate>[];
  final retainedRegulationExtractions = <ExtractionResult>[];

  @override
  String retainExtraction(
    ExtractionResult extraction, {
    LppExtractionCandidate? lppCandidate,
    LppAcquisitionAuthorization? lppAuthorization,
    LppRegulationAcquisitionCandidate? lppRegulationCandidate,
    ManualPartnerAccountabilityContext? manualPartnerAccountability,
    TaxExtractionCandidate? taxCandidate,
  }) {
    if (lppAuthorization != null) {
      retainedAuthorizations.add(lppAuthorization);
    }
    final id = super.retainExtraction(
      extraction,
      lppCandidate: lppCandidate,
      lppAuthorization: lppAuthorization,
      lppRegulationCandidate: lppRegulationCandidate,
      manualPartnerAccountability: manualPartnerAccountability,
      taxCandidate: taxCandidate,
    );
    if (lppRegulationCandidate != null) {
      retainedRegulationCandidates.add(lppRegulationCandidate);
      retainedRegulationExtractions.add(extraction);
    }
    return id;
  }
}

final class _Counters {
  int consent = 0;
  int picker = 0;
  int bytes = 0;
  int hash = 0;
  int network = 0;
  int erases = 0;
  int receiptCreates = 0;
  final events = <String>[];
  final transmittedPayloads = <Uint8List>[];
  final readPaths = <String>[];
  final consentPurposes = <List<ConsentPurpose>>[];
}

final class _LppPlanCounters {
  int consent = 0;
  int picker = 0;
  int bytes = 0;
  int upload = 0;
  int vision = 0;
  final consentPurposes = <List<ConsentPurpose>>[];
  final uploadedPaths = <String>[];
  final uploadedTypes = <VaultDocumentType>[];
}

final class _MutableLppPlanCoachProvider extends CoachProfileProvider {
  _MutableLppPlanCoachProvider(
    this.snapshot, {
    this.manualPartnerSnapshot,
    this.regulationReference,
  });

  LppEvidenceSnapshot? snapshot;
  final LppEvidenceSnapshot? manualPartnerSnapshot;
  SpecialistReferenceEvidence? regulationReference;
  int snapshotReads = 0;

  @override
  CoachProfile get profile => CoachProfile.defaults().copyWith(
        lppRegulationReference: regulationReference,
      );

  @override
  bool get hasProfile => true;

  @override
  bool get isLoaded => true;

  @override
  LppEvidenceSnapshot? currentLppSnapshot(LppEvidenceOwnerKind ownerKind) {
    snapshotReads += 1;
    return switch (ownerKind) {
      LppEvidenceOwnerKind.self => snapshot,
      LppEvidenceOwnerKind.manualPartner => manualPartnerSnapshot,
    };
  }
}

const _lppPlanSnapshotId = '33333333-3333-4333-8333-333333333333';
const _replacementSnapshotId = '44444444-4444-4444-8444-444444444444';
const _lppPlanReferenceId = '55555555-5555-4555-8555-555555555555';
const _replacementReferenceId = '66666666-6666-4666-8666-666666666666';
const _backendDocumentId = 'backend-document-id-must-not-survive';

SpecialistReferenceEvidence _lppPlanSpecialistReference(String referenceId) {
  final now = DateTime.utc(2026, 7, 18, 10);
  final strict = SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': referenceId,
      'kind': 'lppRegulation',
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-01-01',
      'legalYear': 2026,
      'confirmedAt': now.toIso8601String(),
      'fundRelationship': 'uncertain',
    },
    expectedKind: SpecialistReferenceKind.lppRegulation,
    now: now,
  );
  if (strict != null) return strict;

  // RED compatibility bridge for the schema-1 specialist projection.
  return SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': referenceId,
      'kind': 'lppRegulation',
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-01-01',
      'legalYear': 2026,
      'confirmedAt': now.toIso8601String(),
    },
    expectedKind: SpecialistReferenceKind.lppRegulation,
    now: now,
  )!;
}

LppEvidenceSnapshot _lppPlanSnapshot({
  String snapshotId = _lppPlanSnapshotId,
}) {
  final sourceDate = DateTime.utc(2026, 1, 1);
  final confirmedAt = DateTime.utc(2026, 7, 1, 8);
  return LppEvidenceSnapshot(
    snapshotId: snapshotId,
    facts: <LppEvidenceFactKey, LppEvidenceFact>{
      LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
        value: 84000,
        unit: LppEvidenceUnit.chf,
        profileOwnerId: 'self',
        actorProfileOwnerId: 'self',
        source: 'certificate',
        sourceDate: sourceDate,
        updatedAt: confirmedAt,
      ),
    },
  );
}

Map<String, dynamic> _exactLppPlanUploadJson() => <String, dynamic>{
      'id': _backendDocumentId,
      'document_type': 'lpp_plan',
      'extracted_fields': <String, dynamic>{},
      'confidence': 0,
      'fields_found': 0,
      'fields_total': 0,
      'warnings': <String>[],
      'rag_indexed': false,
    };

DocumentUploadResult _exactLppPlanUpload() =>
    DocumentUploadResult.fromJson(_exactLppPlanUploadJson());

Map<String, DocumentUploadResult> _nonExactLppPlanUploads() {
  final exact = _exactLppPlanUploadJson();
  Map<String, dynamic> mutated(Map<String, dynamic> values) =>
      <String, dynamic>{...exact, ...values};

  final missingRag = <String, dynamic>{...exact}..remove('rag_indexed');
  return <String, DocumentUploadResult>{
    'wrong document type': DocumentUploadResult.fromJson(
      mutated(<String, dynamic>{'document_type': 'lpp_certificate'}),
    ),
    'extracted payload': DocumentUploadResult.fromJson(
      mutated(<String, dynamic>{
        'extracted_fields': <String, dynamic>{'raw': 'forbidden'},
      }),
    ),
    'non-zero confidence': DocumentUploadResult.fromJson(
      mutated(<String, dynamic>{'confidence': 0.01}),
    ),
    'non-zero counters': DocumentUploadResult.fromJson(
      mutated(<String, dynamic>{'fields_found': 1, 'fields_total': 1}),
    ),
    'RAG indexed': DocumentUploadResult.fromJson(
      mutated(<String, dynamic>{'rag_indexed': true}),
    ),
    'missing exact-shape key': DocumentUploadResult.fromJson(missingRag),
  };
}

const _receiptId = '11111111-1111-4111-8111-111111111111';
const _ownerId = '22222222-2222-4222-8222-222222222222';
final _frL10n = lookupS(const Locale('fr'));

final class _PartnerBindingPersistence
    implements PartnerAccountabilityBindingPersistence {
  String? value;
  int writes = 0;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    writes += 1;
    this.value = value;
  }
}

final class _PartnerApi implements PartnerAccountabilityApi {
  _PartnerApi(
    this.counters, {
    this.afterReceiptCreated,
    this.createErrors = const <Object>[],
  });

  final _Counters counters;
  final void Function()? afterReceiptCreated;
  final List<Object> createErrors;

  @override
  Future<void> delete(String endpoint) async {
    counters.erases += 1;
    counters.events.add('erase');
  }

  @override
  Future<Map<String, dynamic>> get(String endpoint) async =>
      throw StateError('unexpected status');

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    counters.receiptCreates += 1;
    counters.events.add('receipt-create');
    if (counters.receiptCreates <= createErrors.length) {
      throw createErrors[counters.receiptCreates - 1];
    }
    afterReceiptCreated?.call();
    return <String, dynamic>{
      'receiptId': body['receiptId'],
      'status': 'active',
      'noticeVersion': body['noticeVersion'],
      'policyVersion': body['policyVersion'],
      'declaredAt': '2026-07-15T09:00:00.000Z',
      'expiresAt': '2027-07-15T09:00:00.000Z',
    };
  }
}

final _partnerGate = PartnerAccountabilityExternalGate(
  noticeVersion: 'notice-v1',
  policyVersion: 'policy-v1',
  effectiveAt: DateTime.utc(2026, 7, 1),
  expiresAt: DateTime.utc(2027, 7, 15),
  controllerIdentity: 'MINT Test Controller',
  privacyContact: 'privacy@example.test',
  recipient: 'Anthropic Test Recipient',
  processingRegions: 'Suisse et États-Unis',
  transferMechanism: 'Synthetic SCC',
  retentionContract: '0 jour après extraction',
  rightsChannel: 'https://example.test/rights',
  aipdDecision: 'Synthetic AIPD accepted',
);

({
  Widget widget,
  _ScanSessionSpy sessions,
  GoRouter router,
  PartnerAccountabilityBindingStore bindingStore,
  _PartnerBindingPersistence bindingPersistence,
}) _harness({
  required CoachProfile profile,
  required _Counters counters,
  bool consentGranted = true,
  List<String>? acquisitionIds,
  DocumentScanDocumentHasher? documentHasher,
  Future<bool> Function()? consentAction,
  void Function()? pickerAction,
  PlatformFile Function(Uint8List bytes)? platformFile,
  Map<String, dynamic>? visionResponse,
  PartnerAccountabilityExternalGate? Function()? partnerGateResolver,
  void Function()? afterReceiptCreated,
  Uint8List? selectedBytes,
  List<Object> receiptCreateErrors = const <Object>[],
  DocumentScanReviewNavigator? navigateToReview,
  DocumentScanTempFileWriter? writeOwnedTempFile,
}) {
  final sessions = _ScanSessionSpy();
  final ids = acquisitionIds ??
      <String>[
        '123e4567-e89b-42d3-a456-426614174000',
        '123e4567-e89b-42d3-a456-426614174001',
      ];
  var nextId = 0;
  final bytes = selectedBytes ?? Uint8List.fromList(const [0, 1, 2, 255]);
  final bindingPersistence = _PartnerBindingPersistence();
  final partnerBindingStore = PartnerAccountabilityBindingStore(
    persistence: bindingPersistence,
  );
  late final GoRouter router;
  router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => DocumentScanScreen(
          initialType: DocumentType.lppCertificate,
          partnerBindingStore: partnerBindingStore,
          partnerAccountabilityService: PartnerAccountabilityService(
            api: _PartnerApi(
              counters,
              afterReceiptCreated: afterReceiptCreated,
              createErrors: receiptCreateErrors,
            ),
          ),
          partnerExternalGate: _partnerGate,
          partnerExternalGateResolver: partnerGateResolver,
          isAuthenticated: () async => true,
          partnerOwnerIdFactory: () => _ownerId,
          partnerReceiptIdFactory: () => _receiptId,
          navigateToReview: navigateToReview,
          writeOwnedTempFile: writeOwnedTempFile,
          lppAcquisitionIdFactory: () => ids[nextId++],
          now: () => DateTime.utc(2026, 7, 15, 9),
          hashDocumentBytes: (transmittedBytes) {
            counters.hash += 1;
            counters.events.add('hash');
            return documentHasher?.call(transmittedBytes) ??
                LppAcquisitionAuthorization.sha256Hex(transmittedBytes);
          },
          requireConsent: (_, purposes) async {
            counters.consent += 1;
            counters.events.add('consent');
            counters.consentPurposes.add(List.of(purposes));
            expect(purposes, isNot(contains(ConsentPurpose.coupleProjection)));
            return consentAction == null
                ? consentGranted
                : await consentAction();
          },
          pickFile: () async {
            counters.picker += 1;
            counters.events.add('picker');
            pickerAction?.call();
            return platformFile?.call(bytes) ??
                PlatformFile(
                  name: 'synthetic-certificate.jpg',
                  path: '/synthetic/certificate.jpg',
                  size: bytes.length,
                );
          },
          readFileBytes: (path) async {
            counters.bytes += 1;
            counters.events.add('bytes');
            counters.readPaths.add(path);
            return bytes;
          },
          visionExtractor: ({
            required imageBase64,
            required documentType,
            canton,
            languageHint,
            subjectKind,
            receiptId,
          }) async {
            counters.network += 1;
            counters.events.add('network');
            counters.transmittedPayloads.add(base64Decode(imageBase64));
            expect(counters.hash, counters.network);
            expect(
              counters.events.lastIndexOf('hash'),
              lessThan(counters.events.lastIndexOf('network')),
            );
            return visionResponse ??
                <String, dynamic>{
                  'overallConfidence': 0.99,
                  'extractedFields': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'fieldName': 'avoirLppTotal',
                      'value': 84000,
                      'confidence': 'high',
                      'sourceText': 'raw-must-not-survive',
                    },
                  ],
                };
          },
        ),
      ),
      GoRoute(
        path: '/scan/review',
        builder: (_, __) => const Scaffold(
          key: Key('lpp_review_destination'),
          body: SizedBox.shrink(),
        ),
      ),
    ],
  );
  return (
    sessions: sessions,
    router: router,
    bindingStore: partnerBindingStore,
    bindingPersistence: bindingPersistence,
    widget: MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(
          value: _StaticCoachProvider(profile),
        ),
        ChangeNotifierProvider<ScanSessionProvider>.value(value: sessions),
      ],
      child: MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
}

({
  Widget widget,
  _ScanSessionSpy sessions,
  GoRouter router,
  _MutableLppPlanCoachProvider coach,
  _LppPlanCounters counters,
}) _lppPlanHarness({
  bool hasSnapshot = true,
  LppEvidenceSnapshot? snapshot,
  LppEvidenceSnapshot? manualPartnerSnapshot,
  String? existingReferenceId,
  String extension = 'pdf',
  DocumentUploadResult? uploadResult,
  void Function(_MutableLppPlanCoachProvider coach)? afterUpload,
}) {
  final counters = _LppPlanCounters();
  final sessions = _ScanSessionSpy();
  final coach = _MutableLppPlanCoachProvider(
    hasSnapshot ? snapshot ?? _lppPlanSnapshot() : null,
    manualPartnerSnapshot: manualPartnerSnapshot,
    regulationReference: existingReferenceId == null
        ? null
        : _lppPlanSpecialistReference(existingReferenceId),
  );
  late final GoRouter router;
  router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => DocumentScanScreen(
          initialType: DocumentType.lppPlan,
          requireConsent: (_, purposes) async {
            counters.consent += 1;
            counters.consentPurposes.add(List.of(purposes));
            return true;
          },
          pickFile: () async {
            counters.picker += 1;
            return PlatformFile(
              name: 'regulation.$extension',
              path: '/synthetic/regulation.$extension',
              size: 4,
            );
          },
          readFileBytes: (_) async {
            counters.bytes += 1;
            return Uint8List.fromList(const [37, 80, 68, 70]);
          },
          uploadDocument: (file, {required type}) async {
            counters.upload += 1;
            counters.uploadedPaths.add(file.path);
            counters.uploadedTypes.add(type);
            afterUpload?.call(coach);
            return uploadResult ?? _exactLppPlanUpload();
          },
          visionExtractor: ({
            required imageBase64,
            required documentType,
            canton,
            languageHint,
            subjectKind,
            receiptId,
          }) async {
            counters.vision += 1;
            throw StateError('LPP plan must never enter Vision');
          },
        ),
      ),
      GoRoute(
        path: '/scan/review',
        builder: (_, state) => Scaffold(
          key: const Key('lpp_plan_review_destination'),
          body: Text(state.uri.queryParameters['scanSessionId'] ?? ''),
        ),
      ),
    ],
  );
  return (
    sessions: sessions,
    router: router,
    coach: coach,
    counters: counters,
    widget: MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: coach),
        ChangeNotifierProvider<ScanSessionProvider>.value(value: sessions),
      ],
      child: MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
}

Future<void> _openLppPlanImport(WidgetTester tester) async {
  await tester.drag(
    find.byType(CustomScrollView),
    const Offset(0, -500),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
  await tester.pumpAndSettle();
}

void _expectNoLppPlanIo(
  _LppPlanCounters counters,
  _ScanSessionSpy sessions,
) {
  expect(counters.consent, 0);
  expect(counters.picker, 0);
  expect(counters.bytes, 0);
  expect(counters.upload, 0);
  expect(counters.vision, 0);
  expect(sessions.retainedSessionCount, 0);
}

Future<void> _openGalleryGate(WidgetTester tester) async {
  await tester.drag(
    find.byType(CustomScrollView),
    const Offset(0, -500),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
  await tester.pumpAndSettle();
}

Future<void> _chooseManualPartner(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('lpp_acquisition_owner_manual_partner')),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('lpp_partner_notice_gate')), findsOneWidget);
  await tester.tap(find.byKey(const Key('lpp_partner_notice_continue')));
  await tester.pumpAndSettle();
}

Future<void> _confirmPartnerDeclaration(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('lpp_partner_authorization_declaration')),
  );
  await tester.pump();
  await tester.tap(
    find.byKey(const Key('lpp_partner_authorization_continue')),
  );
  await tester.pumpAndSettle();
}

void _expectZeroAfterGate(_Counters counters, _ScanSessionSpy sessions) {
  expect(counters.consent, 0);
  expect(counters.picker, 0);
  expect(counters.bytes, 0);
  expect(counters.hash, 0);
  expect(counters.network, 0);
  expect(sessions.retainedAuthorizations, isEmpty);
}

void main() {
  test('LPP acquisition gate has no linked-account or reusable-consent input',
      () {
    final screen = File(
      'lib/screens/document_scan/document_scan_screen.dart',
    ).readAsStringSync();
    final authorization = File(
      'lib/models/lpp_evidence.dart',
    ).readAsStringSync();

    for (final forbidden in const [
      'HouseholdProvider',
      'hasPartnerContext',
      'invitationLevel',
      'ConsentPurpose.coupleProjection',
    ]) {
      expect(screen, isNot(contains(forbidden)), reason: forbidden);
    }
    final volatileAuthorization = authorization.substring(
      authorization.indexOf('class LppAcquisitionAuthorization'),
      authorization.indexOf('class LppReviewConfirmation'),
    );
    expect(volatileAuthorization, isNot(contains('toJson')));
    expect(volatileAuthorization, isNot(contains('fromJson')));
  });

  test('debug LPP sample is explicitly synthetic and contains no identity', () {
    const sample = LppCertificateParser.sampleOcrText;
    expect(sample, contains('EXEMPLE SYNTHETIQUE SANS DONNEES PERSONNELLES'));
    expect(sample, contains('exemple anonyme'));
    for (final forbidden in const [
      'Dupont',
      'Nom:',
      'Date de naissance:',
      'No. assure:',
      '12345-678',
    ]) {
      expect(sample, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('review navigation and owned temp writing are visible test seams', () {
    final screen = File(
      'lib/screens/document_scan/document_scan_screen.dart',
    ).readAsStringSync();

    for (final declaration in const [
      'final DocumentScanReviewNavigator? navigateToReview;',
      'final DocumentScanTempFileWriter? writeOwnedTempFile;',
    ]) {
      final declarationIndex = screen.indexOf(declaration);
      expect(declarationIndex, greaterThanOrEqualTo(0), reason: declaration);
      final annotationIndex = screen.lastIndexOf(
        '@visibleForTesting',
        declarationIndex,
      );
      expect(annotationIndex, greaterThanOrEqualTo(0), reason: declaration);
      expect(
        screen.substring(annotationIndex, declarationIndex),
        isNot(contains('final ')),
        reason: declaration,
      );
    }
  });

  setUp(() {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    FeatureFlags.lppRegulationReferenceEnabled = false;
    FeatureFlags.partnerLppAccountabilityEnabled = true;
  });
  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
    FeatureFlags.lppRegulationReferenceEnabled = false;
    FeatureFlags.partnerLppAccountabilityEnabled = false;
  });

  testWidgets(
      'regulation-only PDF opens review without a numeric self snapshot',
      (tester) async {
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final harness = _lppPlanHarness(hasSnapshot: false);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('document_scan_lpp_plan_type_selector')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('document_scan_capture_cta')), findsNothing);
    expect(
      find.widgetWithIcon(TextButton, Icons.text_snippet_outlined),
      findsNothing,
    );
    expect(
      find.widgetWithIcon(OutlinedButton, Icons.science_outlined),
      findsNothing,
    );

    await _openLppPlanImport(tester);

    expect(find.byKey(const Key('lpp_acquisition_self_gate')), findsNothing);
    expect(harness.counters.consent, 1);
    expect(
      harness.counters.consentPurposes.single,
      const <ConsentPurpose>[ConsentPurpose.visionExtraction],
    );
    expect(
      harness.counters.consentPurposes.single,
      isNot(contains(ConsentPurpose.transferUsAnthropic)),
    );
    expect(harness.counters.picker, 1);
    expect(harness.counters.bytes, 0);
    expect(harness.counters.upload, 1);
    expect(
      harness.counters.uploadedTypes,
      const <VaultDocumentType>[VaultDocumentType.lppPlan],
    );
    expect(
      harness.counters.uploadedPaths.single,
      '/synthetic/regulation.pdf',
    );
    expect(harness.counters.vision, 0);
    expect(
      harness.coach.snapshotReads,
      0,
      reason: 'regulation authority must not consult numeric snapshot state',
    );
    expect(harness.sessions.retainedRegulationCandidates, hasLength(1));
    expect(harness.sessions.retainedRegulationExtractions, hasLength(1));

    final dynamic candidate =
        harness.sessions.retainedRegulationCandidates.single;
    expect(candidate.expectedPreviousReferenceId, isNull);
    expect(
      () => candidate.expectedSnapshotId,
      throwsA(isA<NoSuchMethodError>()),
      reason: 'the volatile regulation candidate is snapshotless',
    );
    final extraction = harness.sessions.retainedRegulationExtractions.single;
    expect(extraction.documentType, DocumentType.lppPlan);
    expect(extraction.fields, isEmpty);
    expect(extraction.overallConfidence, 0);
    expect(extraction.confidenceDelta, 0);
    expect(extraction.warnings, isEmpty);
    expect(extraction.disclaimer, isEmpty);
    expect(extraction.sources, isEmpty);
    expect(extraction.diagnostics, isEmpty);
    expect(extraction.planType, isNull);
    expect(extraction.planTypeWarning, isNull);
    expect(extraction.coherenceWarnings, isEmpty);

    final uri = harness.router.routeInformationProvider.value.uri;
    final scanSessionId = uri.queryParameters['scanSessionId'];
    expect(uri.path, '/scan/review');
    expect(uri.queryParameters.keys.toSet(), const <String>{'scanSessionId'});
    expect(scanSessionId, isNotNull);
    expect(
      uri.toString(),
      '/scan/review?scanSessionId=${Uri.encodeQueryComponent(scanSessionId!)}',
    );
    expect(uri.toString(), isNot(contains(_backendDocumentId)));
    expect(scanSessionId, isNot(contains(_backendDocumentId)));
  });

  for (final disabledFlag in const <String>[
    'typedLppEvidence',
    'documentLppEvidenceEnabled',
    'lppRegulationReferenceEnabled',
  ]) {
    testWidgets('LPP plan stops before I/O when $disabledFlag is false',
        (tester) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      FeatureFlags.lppRegulationReferenceEnabled = true;
      switch (disabledFlag) {
        case 'typedLppEvidence':
          FeatureFlags.typedLppEvidence = false;
        case 'documentLppEvidenceEnabled':
          FeatureFlags.documentLppEvidenceEnabled = false;
        case 'lppRegulationReferenceEnabled':
          FeatureFlags.lppRegulationReferenceEnabled = false;
      }
      final harness = _lppPlanHarness();
      addTearDown(harness.router.dispose);

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('document_scan_lpp_plan_type_selector')),
        findsNothing,
      );
      _expectNoLppPlanIo(harness.counters, harness.sessions);
    });
  }

  testWidgets(
      'numeric snapshot replacement during upload does not block regulation',
      (tester) async {
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final harness = _lppPlanHarness(
      snapshot: _lppPlanSnapshot(),
      afterUpload: (coach) {
        coach.snapshot = _lppPlanSnapshot(
          snapshotId: _replacementSnapshotId,
        );
      },
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _openLppPlanImport(tester);

    expect(harness.counters.upload, 1);
    expect(harness.sessions.retainedRegulationCandidates, hasLength(1));
    final dynamic candidate =
        harness.sessions.retainedRegulationCandidates.single;
    expect(candidate.expectedPreviousReferenceId, isNull);
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/scan/review',
    );
  });

  testWidgets(
      'previous autonomous reference drift blocks after upload without snapshot coupling',
      (tester) async {
    FeatureFlags.lppRegulationReferenceEnabled = true;
    final harness = _lppPlanHarness(
      snapshot: _lppPlanSnapshot(),
      existingReferenceId: _lppPlanReferenceId,
      afterUpload: (coach) {
        coach.regulationReference =
            _lppPlanSpecialistReference(_replacementReferenceId);
      },
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _openLppPlanImport(tester);

    expect(harness.counters.upload, 1);
    expect(
      harness.sessions.retainedSessionCount,
      0,
      reason: 'the exact previous regulation authority changed during upload',
    );
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/',
    );
  });

  for (final extension in const <String>['jpg', 'png', 'txt']) {
    testWidgets('LPP plan rejects .$extension without OCR upload or Vision',
        (tester) async {
      FeatureFlags.lppRegulationReferenceEnabled = true;
      final harness = _lppPlanHarness(extension: extension);
      addTearDown(harness.router.dispose);

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('document_scan_lpp_plan_type_selector')),
        findsOneWidget,
      );

      await _openLppPlanImport(tester);

      expect(find.byKey(const Key('lpp_acquisition_self_gate')), findsNothing);
      expect(harness.counters.consent, 1);
      expect(
        harness.counters.consentPurposes.single,
        const <ConsentPurpose>[ConsentPurpose.visionExtraction],
      );
      expect(harness.counters.picker, 1);
      expect(harness.counters.bytes, 0);
      expect(harness.counters.upload, 0);
      expect(harness.counters.vision, 0);
      expect(harness.sessions.retainedSessionCount, 0);
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/',
      );
    });
  }

  for (final invalidUpload in _nonExactLppPlanUploads().entries) {
    testWidgets('LPP plan rejects non-exact zero-fact ${invalidUpload.key}',
        (tester) async {
      FeatureFlags.lppRegulationReferenceEnabled = true;
      expect(invalidUpload.value.isExactLppPlanAuthority, isFalse);
      final harness = _lppPlanHarness(uploadResult: invalidUpload.value);
      addTearDown(harness.router.dispose);

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('document_scan_lpp_plan_type_selector')),
        findsOneWidget,
      );

      await _openLppPlanImport(tester);

      expect(harness.counters.consent, 1);
      expect(harness.counters.picker, 1);
      expect(harness.counters.upload, 1);
      expect(harness.counters.bytes, 0);
      expect(harness.counters.vision, 0);
      expect(harness.sessions.retainedSessionCount, 0);
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/',
      );
    });
  }

  testWidgets('single user sees self-only gate and cancellation does nothing',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults(),
      counters: counters,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);

    expect(find.byKey(const Key('lpp_acquisition_self_gate')), findsOneWidget);
    expect(
      find.byKey(const Key('lpp_acquisition_owner_manual_partner')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('lpp_acquisition_partner_attestation')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('lpp_acquisition_cancel')));
    await tester.pumpAndSettle();
    _expectZeroAfterGate(counters, harness.sessions);
  });

  testWidgets('direct LPP paste is not an acquisition surface', (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults(),
      counters: counters,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.text_snippet_outlined), findsNothing);
    _expectZeroAfterGate(counters, harness.sessions);
  });

  testWidgets('local declared partner is available without a linked account',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(
          birthYear: 1982,
          invitationLevel: 'declared',
        ),
      ),
      counters: counters,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);

    expect(find.byKey(const Key('lpp_acquisition_owner_gate')), findsOneWidget);
    expect(
      find.byKey(const Key('lpp_acquisition_owner_manual_partner')),
      findsOneWidget,
    );
    await _chooseManualPartner(tester);
    expect(
      find.byKey(const Key('lpp_acquisition_partner_attestation')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('lpp_acquisition_cancel')));
    await tester.pumpAndSettle();
    _expectZeroAfterGate(counters, harness.sessions);
  });

  testWidgets('partner notice names real gate facts before explicit checkbox',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(birthYear: 1982),
      ),
      counters: counters,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_owner_manual_partner')),
    );
    await tester.pumpAndSettle();

    for (final fact in const <String>[
      'MINT Test Controller',
      'privacy@example.test',
      'Anthropic Test Recipient',
      'Suisse et États-Unis',
      'Synthetic SCC',
      '0 jour après extraction',
      'notice-v1',
      '2026-07-01',
    ]) {
      expect(find.textContaining(fact), findsOneWidget, reason: fact);
    }
    _expectZeroAfterGate(counters, harness.sessions);
    expect(
      find.byKey(const Key('lpp_acquisition_partner_attestation')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('lpp_partner_notice_continue')));
    await tester.pumpAndSettle();
    final continueFinder = find.byKey(
      const Key('lpp_partner_authorization_continue'),
    );
    expect(tester.widget<FilledButton>(continueFinder).onPressed, isNull);
    expect(find.textContaining('notice-v1'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('lpp_partner_authorization_declaration')),
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(continueFinder).onPressed, isNotNull);
  });

  testWidgets('owner cancellation stops before consent and acquisition id',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(birthYear: 1982),
      ),
      counters: counters,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await tester.tap(find.byKey(const Key('lpp_acquisition_cancel')));
    await tester.pumpAndSettle();

    _expectZeroAfterGate(counters, harness.sessions);
  });

  testWidgets('consent refusal after partner attestation stops before picker',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(birthYear: 1982),
      ),
      counters: counters,
      consentGranted: false,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await _chooseManualPartner(tester);
    await _confirmPartnerDeclaration(tester);

    expect(counters.consent, 1);
    expect(counters.picker, 0);
    expect(counters.bytes, 0);
    expect(counters.hash, 0);
    expect(counters.network, 0);
    expect(counters.receiptCreates, 0);
    expect(counters.erases, 0);
    expect(
      counters.consentPurposes.single,
      const [ConsentPurpose.visionExtraction],
    );
    expect((await harness.bindingStore.load()).pending, isNull);
    expect(harness.sessions.retainedAuthorizations, isEmpty);
  });

  testWidgets('partner upload hashes exact bytes before network and session',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(
          birthYear: 1982,
          invitationLevel: 'declared',
        ),
      ),
      counters: counters,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await _chooseManualPartner(tester);
    await _confirmPartnerDeclaration(tester);

    expect(find.byKey(const Key('lpp_review_destination')), findsOneWidget);
    expect(counters.consent, 1);
    expect(counters.picker, 1);
    expect(counters.bytes, greaterThanOrEqualTo(1));
    expect(counters.hash, 1);
    expect(counters.network, 1);
    expect(
      counters.consentPurposes.single,
      const [ConsentPurpose.visionExtraction],
    );
    expect(
      harness.sessions.retainedAuthorizations,
      hasLength(1),
      reason:
          'events=${counters.events} paths=${counters.readPaths} payloads=${counters.transmittedPayloads.length}',
    );
    final authorization = harness.sessions.retainedAuthorizations.single;
    final acceptedBinding = (await harness.bindingStore.load()).pending!;
    expect(acceptedBinding.noticeVersion, 'notice-v1');
    expect(acceptedBinding.privacyContact, 'privacy@example.test');
    expect(
      acceptedBinding.rightsChannel,
      'https://example.test/rights',
    );
    expect(authorization.subject, LppEvidenceOwnerKind.manualPartner);
    expect(authorization.partnerAttested, isTrue);
    expect(
      authorization.documentSha256,
      '3d1f57c984978ef98a18378c8166c1cb8ede02c03eeb6aee7e2f121dfeee3e56',
    );
    expect(counters.transmittedPayloads, hasLength(1));
    expect(
      authorization.documentSha256,
      LppAcquisitionAuthorization.sha256Hex(
        counters.transmittedPayloads.single,
      ),
    );
  });

  testWidgets(
      'navigation failure after partner review handoff cleans receipt binding session and temp',
      (tester) async {
    final counters = _Counters();
    var navigationAttempts = 0;
    String? ownedTempPath;
    late ({
      Widget widget,
      _ScanSessionSpy sessions,
      GoRouter router,
      PartnerAccountabilityBindingStore bindingStore,
      _PartnerBindingPersistence bindingPersistence,
    }) harness;
    harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(birthYear: 1982),
      ),
      counters: counters,
      platformFile: (bytes) => PlatformFile(
        name: 'bytes-only-certificate.pdf',
        size: bytes.length,
        bytes: bytes,
      ),
      navigateToReview: (_, scanSessionId) async {
        navigationAttempts += 1;
        expect(harness.sessions.byId(scanSessionId), isNotNull);
        expect((await harness.bindingStore.load()).pending, isNotNull);
        throw StateError('synthetic navigation failure after handoff');
      },
      writeOwnedTempFile: (file, bytes) async {
        ownedTempPath = file.path;
        file.writeAsBytesSync(bytes, flush: true);
      },
    );
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await _chooseManualPartner(tester);
    await _confirmPartnerDeclaration(tester);

    final bindingAfterFailure = await harness.bindingStore.load();
    expect(
      navigationAttempts,
      1,
      reason: 'events=${counters.events} erases=${counters.erases} '
          'pending=${bindingAfterFailure.pending?.toJson()}',
    );
    expect(counters.receiptCreates, 1);
    expect(counters.network, 1);
    expect(counters.erases, 1);
    expect(harness.bindingPersistence.writes, 3);
    expect(harness.sessions.retainedSessionCount, 0);
    expect(bindingAfterFailure.effective, isNull);
    expect(find.byKey(const Key('lpp_review_destination')), findsNothing);
    expect(counters.readPaths, isNotEmpty);
    final readTempPath = counters.readPaths.single;
    expect(readTempPath, ownedTempPath);
    expect(File(readTempPath).existsSync(), isFalse);
  });

  testWidgets('terminal receipt creation error never offers retry',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(birthYear: 1982),
      ),
      counters: counters,
      receiptCreateErrors: const <PartnerAccountabilityException>[
        PartnerAccountabilityException(
          PartnerAccountabilityReceiptStatus.stale,
        ),
      ],
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await _chooseManualPartner(tester);
    await _confirmPartnerDeclaration(tester);

    expect(
      find.byKey(const Key('lpp_partner_receipt_retry')),
      findsNothing,
    );
    expect(find.text(_frL10n.lppPartnerReceiptFailed), findsOneWidget);
    expect(counters.receiptCreates, 1);
    expect(counters.erases, 0);
    expect(counters.bytes, 0);
    expect(counters.hash, 0);
    expect(counters.network, 0);
    expect((await harness.bindingStore.load()).effective, isNull);
    expect(harness.sessions.retainedSessionCount, 0);
  });

  testWidgets('unexpected receipt creation error never offers retry',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(birthYear: 1982),
      ),
      counters: counters,
      receiptCreateErrors: <Object>[
        StateError('synthetic unexpected receipt failure'),
      ],
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await _chooseManualPartner(tester);
    await _confirmPartnerDeclaration(tester);

    expect(
      find.byKey(const Key('lpp_partner_receipt_retry')),
      findsNothing,
    );
    expect(find.text(_frL10n.lppPartnerReceiptFailed), findsOneWidget);
    expect(counters.receiptCreates, 1);
    expect(counters.erases, 0);
    expect(counters.bytes, 0);
    expect(counters.hash, 0);
    expect(counters.network, 0);
    expect((await harness.bindingStore.load()).effective, isNull);
    expect(harness.sessions.retainedSessionCount, 0);
  });

  testWidgets('retryable receipt creation error retries only after user action',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(birthYear: 1982),
      ),
      counters: counters,
      receiptCreateErrors: const <PartnerAccountabilityException>[
        PartnerAccountabilityException(
          PartnerAccountabilityReceiptStatus.offline,
          retryable: true,
        ),
      ],
    );
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await _chooseManualPartner(tester);
    await _confirmPartnerDeclaration(tester);

    expect(counters.receiptCreates, 1);
    expect(
      find.byKey(const Key('lpp_partner_receipt_retry')),
      findsOneWidget,
    );
    expect(find.text(_frL10n.lppPartnerReceiptRetryTitle), findsOneWidget);
    expect(find.text(_frL10n.lppPartnerNoticeTitle), findsNothing);
    expect(find.text(_frL10n.lppPartnerReceiptRetryable), findsOneWidget);
    expect(find.text(_frL10n.lppPartnerReceiptFailed), findsNothing);
    await tester.tap(
      find.byKey(const Key('lpp_partner_receipt_pending')),
    );
    await tester.pumpAndSettle();

    expect(counters.receiptCreates, 2);
    expect(counters.erases, 0);
    expect(counters.network, 1);
    expect(find.byKey(const Key('lpp_review_destination')), findsOneWidget);
    expect((await harness.bindingStore.load()).pending, isNotNull);
  });

  for (final drift in <String>['notice changes', 'gate expires']) {
    testWidgets(
        'partner $drift after receipt but before bytes deletes once and closes',
        (tester) async {
      var currentGate = _partnerGate;
      final counters = _Counters();
      final harness = _harness(
        profile: CoachProfile.defaults().copyWith(
          conjoint: const ConjointProfile(birthYear: 1982),
        ),
        counters: counters,
        partnerGateResolver: () => currentGate,
        afterReceiptCreated: () {
          currentGate = PartnerAccountabilityExternalGate(
            noticeVersion:
                drift == 'notice changes' ? 'notice-v2' : 'notice-v1',
            policyVersion: 'policy-v1',
            effectiveAt: DateTime.utc(2026, 7, 1),
            expiresAt: drift == 'gate expires'
                ? DateTime.utc(2026, 7, 15, 8)
                : DateTime.utc(2027, 7, 15),
            controllerIdentity: 'MINT Test Controller',
            privacyContact: 'privacy@example.test',
            recipient: 'Anthropic Test Recipient',
            processingRegions: 'Suisse et États-Unis',
            transferMechanism: 'Synthetic SCC',
            retentionContract: '0 jour après extraction',
            rightsChannel: 'https://example.test/rights',
            aipdDecision: 'Synthetic AIPD accepted',
          );
        },
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await _openGalleryGate(tester);
      await _chooseManualPartner(tester);
      await _confirmPartnerDeclaration(tester);

      expect(counters.receiptCreates, 1);
      expect(counters.erases, 1);
      expect(counters.bytes, 0);
      expect(counters.hash, 0);
      expect(counters.network, 0);
      expect(harness.sessions.retainedAuthorizations, isEmpty);
      expect(find.byKey(const Key('lpp_review_destination')), findsNothing);
      expect(
        find.byKey(const Key('lpp_recovery_manual_text_cta')),
        findsNothing,
      );
      expect(find.byType(TextField), findsNothing);
      expect((await harness.bindingStore.load()).effective, isNull);
      final terminalCounters = (
        bytes: counters.bytes,
        hash: counters.hash,
        network: counters.network,
        erases: counters.erases,
      );
      await tester.pumpAndSettle();
      expect(
        (
          bytes: counters.bytes,
          hash: counters.hash,
          network: counters.network,
          erases: counters.erases,
        ),
        terminalCounters,
      );
    });
  }

  testWidgets(
      'partner gate change after bytes but before transmission deletes once',
      (tester) async {
    var currentGate = _partnerGate;
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(birthYear: 1982),
      ),
      counters: counters,
      partnerGateResolver: () => currentGate,
      documentHasher: (bytes) {
        currentGate = PartnerAccountabilityExternalGate(
          noticeVersion: 'notice-v2',
          policyVersion: 'policy-v1',
          effectiveAt: DateTime.utc(2026, 7, 1),
          expiresAt: DateTime.utc(2027, 7, 15),
          controllerIdentity: 'MINT Test Controller',
          privacyContact: 'privacy@example.test',
          recipient: 'Anthropic Test Recipient',
          processingRegions: 'Suisse et États-Unis',
          transferMechanism: 'Synthetic SCC',
          retentionContract: '0 jour après extraction',
          rightsChannel: 'https://example.test/rights',
          aipdDecision: 'Synthetic AIPD accepted',
        );
        return LppAcquisitionAuthorization.sha256Hex(bytes);
      },
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await _chooseManualPartner(tester);
    await _confirmPartnerDeclaration(tester);

    expect(counters.receiptCreates, 1);
    expect(counters.bytes, greaterThanOrEqualTo(1));
    expect(counters.hash, 1);
    expect(counters.network, 0);
    expect(counters.erases, 1);
    expect(harness.sessions.retainedAuthorizations, isEmpty);
    expect(find.byKey(const Key('lpp_review_destination')), findsNothing);
    expect(
      find.byKey(const Key('lpp_recovery_manual_text_cta')),
      findsNothing,
    );
    expect(find.byType(TextField), findsNothing);
    expect((await harness.bindingStore.load()).effective, isNull);
    final terminalCounters = (
      bytes: counters.bytes,
      hash: counters.hash,
      network: counters.network,
      erases: counters.erases,
    );
    await tester.pumpAndSettle();
    expect(
      (
        bytes: counters.bytes,
        hash: counters.hash,
        network: counters.network,
        erases: counters.erases,
      ),
      terminalCounters,
    );
  });

  testWidgets('missing exact secure pending terminalizes before document bytes',
      (tester) async {
    late ({
      Widget widget,
      _ScanSessionSpy sessions,
      GoRouter router,
      PartnerAccountabilityBindingStore bindingStore,
      _PartnerBindingPersistence bindingPersistence,
    }) harness;
    final counters = _Counters();
    harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(birthYear: 1982),
      ),
      counters: counters,
      partnerGateResolver: () {
        if (counters.receiptCreates == 1) {
          harness.bindingPersistence.value = null;
        }
        return _partnerGate;
      },
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await _chooseManualPartner(tester);
    await _confirmPartnerDeclaration(tester);

    expect(counters.receiptCreates, 1);
    expect(counters.bytes, 0);
    expect(counters.hash, 0);
    expect(counters.network, 0);
    expect(counters.erases, 1);
    expect(find.byType(TextField), findsNothing);
    expect(
      find.byKey(const Key('lpp_recovery_manual_text_cta')),
      findsNothing,
    );
    expect(find.byKey(const Key('lpp_review_destination')), findsNothing);
    expect(harness.sessions.retainedAuthorizations, isEmpty);
    expect((await harness.bindingStore.load()).effective, isNull);
  });

  for (final recognized in <bool>[false, true]) {
    testWidgets(
        'partner drift after txt hash terminalizes before '
        '${recognized ? 'public review' : 'manual parser fallback'}',
        (tester) async {
      var currentGate = _partnerGate;
      final counters = _Counters();
      final selectedBytes = Uint8List.fromList(utf8.encode(
        recognized
            ? LppCertificateParser.sampleOcrText
            : 'aucun champ de certificat reconnu',
      ));
      final harness = _harness(
        profile: CoachProfile.defaults().copyWith(
          conjoint: const ConjointProfile(birthYear: 1982),
        ),
        counters: counters,
        selectedBytes: selectedBytes,
        platformFile: (bytes) => PlatformFile(
          name: 'synthetic-certificate.txt',
          path: '/synthetic/certificate.txt',
          size: bytes.length,
        ),
        partnerGateResolver: () => currentGate,
        documentHasher: (bytes) {
          currentGate = PartnerAccountabilityExternalGate(
            noticeVersion: 'notice-v2',
            policyVersion: 'policy-v1',
            effectiveAt: DateTime.utc(2026, 7, 1),
            expiresAt: DateTime.utc(2027, 7, 15),
            controllerIdentity: 'MINT Test Controller',
            privacyContact: 'privacy@example.test',
            recipient: 'Anthropic Test Recipient',
            processingRegions: 'Suisse et États-Unis',
            transferMechanism: 'Synthetic SCC',
            retentionContract: '0 jour après extraction',
            rightsChannel: 'https://example.test/rights',
            aipdDecision: 'Synthetic AIPD accepted',
          );
          return LppAcquisitionAuthorization.sha256Hex(bytes);
        },
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await _openGalleryGate(tester);
      await _chooseManualPartner(tester);
      await _confirmPartnerDeclaration(tester);

      expect(counters.receiptCreates, 1);
      expect(counters.bytes, 1);
      expect(counters.hash, 1);
      expect(counters.network, 0);
      expect(counters.erases, 1);
      expect(find.byType(TextField), findsNothing);
      expect(
        find.byKey(const Key('lpp_recovery_manual_text_cta')),
        findsNothing,
      );
      expect(find.byKey(const Key('lpp_review_destination')), findsNothing);
      expect(harness.sessions.retainedAuthorizations, isEmpty);
      expect((await harness.bindingStore.load()).effective, isNull);

      final countersAfterTerminal = (
        bytes: counters.bytes,
        hash: counters.hash,
        network: counters.network,
        erases: counters.erases,
      );
      await tester.pumpAndSettle();
      expect(
        (
          bytes: counters.bytes,
          hash: counters.hash,
          network: counters.network,
          erases: counters.erases,
        ),
        countersAfterTerminal,
      );
    });
  }

  testWidgets('PDF hashes transmitted base64 and preserves selected user file',
      (tester) async {
    final selectedDirectory = Directory.systemTemp.createTempSync(
      'mint_selected_pdf_',
    );
    final selectedPdf = File('${selectedDirectory.path}/mint_upload_user.pdf')
      ..writeAsBytesSync(const [9, 8, 7, 6]);
    addTearDown(() {
      if (selectedDirectory.existsSync()) {
        selectedDirectory.deleteSync(recursive: true);
      }
    });
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults(),
      counters: counters,
      platformFile: (_) => PlatformFile(
        name: selectedPdf.uri.pathSegments.last,
        path: selectedPdf.path,
        size: selectedPdf.lengthSync(),
      ),
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_self_continue')),
    );
    await tester.pumpAndSettle();

    expect(
      harness.sessions.retainedAuthorizations,
      hasLength(1),
      reason:
          'events=${counters.events} paths=${counters.readPaths} payloads=${counters.transmittedPayloads.length}',
    );
    expect(counters.transmittedPayloads, hasLength(1));
    expect(
      counters.consentPurposes.single,
      const [
        ConsentPurpose.visionExtraction,
        ConsentPurpose.transferUsAnthropic,
      ],
    );
    final authorization = harness.sessions.retainedAuthorizations.single;
    expect(
      authorization.documentSha256,
      LppAcquisitionAuthorization.sha256Hex(
        counters.transmittedPayloads.single,
      ),
    );
    expect(counters.readPaths, contains(selectedPdf.path));
    expect(selectedPdf.existsSync(), isTrue);
  });

  testWidgets(
      'terminal partner PDF failure erases attempt before manual recovery',
      (tester) async {
    final selectedDirectory = Directory.systemTemp.createTempSync(
      'mint_selected_failed_pdf_',
    );
    final selectedPdf = File('${selectedDirectory.path}/partner.pdf')
      ..writeAsBytesSync(const [37, 80, 68, 70]);
    addTearDown(() {
      if (selectedDirectory.existsSync()) {
        selectedDirectory.deleteSync(recursive: true);
      }
    });
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(
          birthYear: 1982,
          invitationLevel: 'declared',
        ),
      ),
      counters: counters,
      platformFile: (_) => PlatformFile(
        name: selectedPdf.uri.pathSegments.last,
        path: selectedPdf.path,
        size: selectedPdf.lengthSync(),
      ),
      visionResponse: const <String, dynamic>{},
    );
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await _chooseManualPartner(tester);
    await _confirmPartnerDeclaration(tester);

    final manualRecovery = find.widgetWithIcon(
      OutlinedButton,
      Icons.text_snippet_outlined,
    );
    expect(manualRecovery, findsNothing);
    expect(find.byKey(const Key('lpp_review_destination')), findsNothing);
    expect(counters.erases, 1);
    expect(counters.consent, 1);
    expect(counters.picker, 1);
    expect(counters.network, 1);
    expect(counters.hash, 1);
    expect(harness.sessions.retainedAuthorizations, isEmpty);
    expect(selectedPdf.existsSync(), isTrue);
  });

  testWidgets(
      'cleanup contract owns camera temp but never a selected user file',
      (tester) async {
    final source = File(
      'lib/screens/document_scan/document_scan_screen.dart',
    ).readAsStringSync();

    expect(source, contains('final Set<String> _ownedTempPaths'));
    expect(source, contains('_ownedTempPaths.add(path)'));
    expect(source, contains('_ownedTempPaths.add(tempFile.path)'));
    expect(source, contains("if (!_ownedTempPaths.remove(path)) return;"));
    expect(source, contains('_cleanupTempFile(localPath);'));
    expect(source, isNot(contains("path.contains('mint_upload_')")));

    final oversizedBranch = source.substring(
      source.indexOf('if (fileSize > _maxFileSizeBytes)'),
      source.indexOf("final ext = file.path.split('.')"),
    );
    expect(oversizedBranch, contains('_cleanupTempFile(file.path);'));
    final wrongFormatStart =
        source.indexOf('if (!_acceptedExtensions.contains(ext))');
    final wrongFormatBranch = source.substring(
      wrongFormatStart,
      source.indexOf('// Phase 28-03', wrongFormatStart),
    );
    expect(wrongFormatBranch, contains('_cleanupTempFile(file.path);'));

    final cameraMaterialization = source.substring(
      source.indexOf('Future<XFile> _materializeBytesAsXFile'),
      source.indexOf('Future<void> _onGalleryPressed'),
    );
    expect(
      cameraMaterialization.indexOf('_ownedTempPaths.add(path);'),
      lessThan(cameraMaterialization.indexOf('await File(path).writeAsBytes')),
    );
    expect(
      cameraMaterialization,
      contains('_cleanupTempFile(path);'),
    );

    final bytesOnlyResolution = source.substring(
      source.indexOf('Future<String?> _resolveLocalPath'),
      source.indexOf('/// Deletes only exact paths'),
    );
    expect(
      bytesOnlyResolution.indexOf('_ownedTempPaths.add(tempFile.path);'),
      lessThan(bytesOnlyResolution.indexOf('await tempFile.writeAsBytes')),
    );
    expect(
      bytesOnlyResolution,
      contains('_cleanupTempFile(tempFile.path);'),
    );
  });

  testWidgets('flag disabled during consent stops before picker',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults(),
      counters: counters,
      consentAction: () async {
        FeatureFlags.documentLppEvidenceEnabled = false;
        return true;
      },
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_self_continue')),
    );
    await tester.pumpAndSettle();

    expect(counters.consent, 1);
    expect(counters.picker, 0);
    expect(counters.bytes, 0);
    expect(counters.hash, 0);
    expect(counters.network, 0);
    expect(harness.sessions.retainedAuthorizations, isEmpty);
  });

  testWidgets('flag disabled when owner dialog closes stops before consent',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults(),
      counters: counters,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    FeatureFlags.documentLppEvidenceEnabled = false;
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_self_continue')),
    );
    await tester.pumpAndSettle();

    _expectZeroAfterGate(counters, harness.sessions);
  });

  testWidgets('flag disabled at attestation closes before consent',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(birthYear: 1982),
      ),
      counters: counters,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await _chooseManualPartner(tester);
    FeatureFlags.documentLppEvidenceEnabled = false;
    await _confirmPartnerDeclaration(tester);

    _expectZeroAfterGate(counters, harness.sessions);
  });

  testWidgets('flag disabled by picker stops before reading bytes',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults(),
      counters: counters,
      pickerAction: () {
        FeatureFlags.documentLppEvidenceEnabled = false;
      },
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_self_continue')),
    );
    await tester.pumpAndSettle();

    expect(counters.consent, 1);
    expect(counters.picker, 1);
    expect(counters.bytes, 0);
    expect(counters.hash, 0);
    expect(counters.network, 0);
    expect(harness.sessions.retainedAuthorizations, isEmpty);
  });

  testWidgets('flag disabled by hasher stops immediately before network',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults(),
      counters: counters,
      documentHasher: (bytes) {
        FeatureFlags.documentLppEvidenceEnabled = false;
        return LppAcquisitionAuthorization.sha256Hex(bytes);
      },
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_self_continue')),
    );
    await tester.pumpAndSettle();

    expect(counters.consent, 1);
    expect(counters.picker, 1);
    expect(counters.hash, 1);
    expect(counters.network, 0);
    expect(harness.sessions.retainedAuthorizations, isEmpty);
  });

  testWidgets('synthetic local partner copy promises no Anthropic transfer',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults().copyWith(
        conjoint: const ConjointProfile(birthYear: 1982),
      ),
      counters: counters,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier('document_scan_lpp_example_cta'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('document_scan_lpp_example_cta')),
    );
    await tester.pumpAndSettle();
    await _chooseManualPartner(tester);

    final dialogText = tester
        .widgetList<Text>(find.descendant(
          of: find.byKey(const Key('lpp_acquisition_partner_attestation')),
          matching: find.byType(Text),
        ))
        .map((widget) => widget.data ?? '')
        .join(' ');
    expect(dialogText, isNot(contains('Anthropic')));
    expect(dialogText, isNot(contains('États-Unis')));
    expect(dialogText, contains('synthétique'));
    expect(counters.consent, 0);
    expect(counters.network, 0);
  });

  testWidgets('manual LPP recovery reuses the gated acquisition decision',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults(),
      counters: counters,
      visionResponse: const <String, dynamic>{},
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_self_continue')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('lpp_recovery_manual_text_cta')),
    );
    await tester.pumpAndSettle();

    expect(counters.consent, 1);
    expect(find.byKey(const Key('lpp_acquisition_self_gate')), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(counters.hash, 1);
    expect(harness.sessions.retainedAuthorizations, isEmpty);
  });

  testWidgets('each acquisition creates a new authorization', (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults(),
      counters: counters,
    );
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 2; attempt += 1) {
      if (attempt > 0) {
        harness.router.pop();
        await tester.pumpAndSettle();
      }
      await _openGalleryGate(tester);
      await tester.tap(
        find.byKey(const Key('lpp_acquisition_self_continue')),
      );
      await tester.pumpAndSettle();
    }

    expect(harness.sessions.retainedAuthorizations, hasLength(2));
    expect(
      harness.sessions.retainedAuthorizations
          .map((authorization) => authorization.acquisitionId)
          .toSet(),
      hasLength(2),
    );
    expect(counters.consent, 2);
    expect(counters.network, 2);
  });

  testWidgets('camera fallback reuses owner and consent gates once',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults(),
      counters: counters,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_capture_cta')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_self_continue')),
    );
    await tester.pumpAndSettle();

    expect(counters.consent, 1);
    expect(counters.picker, 1);
    expect(counters.network, 1);
    expect(harness.sessions.retainedAuthorizations, hasLength(1));
    expect(find.byKey(const Key('lpp_acquisition_self_gate')), findsNothing);
  });

  testWidgets('invalid acquisition id stops before consent or picker',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults(),
      counters: counters,
      acquisitionIds: const ['not-a-uuid'],
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_self_continue')),
    );
    await tester.pumpAndSettle();

    _expectZeroAfterGate(counters, harness.sessions);
  });

  testWidgets('invalid document hash blocks network and session',
      (tester) async {
    final counters = _Counters();
    final harness = _harness(
      profile: CoachProfile.defaults(),
      counters: counters,
      documentHasher: (_) => List.filled(64, '0').join(),
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _openGalleryGate(tester);
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_self_continue')),
    );
    await tester.pumpAndSettle();

    expect(counters.consent, 1);
    expect(counters.picker, 1);
    expect(counters.bytes, greaterThanOrEqualTo(1));
    expect(counters.hash, 1);
    expect(counters.network, 0);
    expect(harness.sessions.retainedAuthorizations, isEmpty);
  });
}
