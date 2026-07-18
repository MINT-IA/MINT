import 'dart:async';
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
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:provider/provider.dart';

const _contractId = '11111111-1111-4111-8111-111111111111';
const _previousReferenceId = '22222222-2222-4222-8222-222222222222';
const _authorityId = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> _exactAuthorityJson() => <String, dynamic>{
      'schemaVersion': 1,
      'documentAuthorityId': _authorityId,
      'documentKind': 'confirmationInstitutionnelle',
      'sourceDate': '2026-07-18',
      'legalYear': 2026,
      'institutionAttested': true,
      'contractScoped': true,
      'temporalBasis': <String, dynamic>{
        'kind': 'exactDates',
        'designationEffectiveDate': '2026-01-15',
        'lastAssignmentModificationDate': null,
      },
      'needsReview': true,
    };

Map<String, dynamic> _copyJson(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

Map<String, dynamic> _mutatedAuthority(
  void Function(Map<String, dynamic> value) mutate,
) {
  final value = _copyJson(_exactAuthorityJson());
  mutate(value);
  return value;
}

Map<String, Map<String, dynamic>> _invalidAuthorityResponses() =>
    <String, Map<String, dynamic>>{
      'generic 3a attestation balance': <String, dynamic>{
        'documentType': 'pillar_3a_attestation',
        'overallConfidence': 0.99,
        'extractedFields': <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldName': 'pillar3aBalance',
            'value': 42000,
            'confidence': 'high',
            'sourceText': 'Solde 3a CHF 42 000',
          },
        ],
      },
      'blank designation form': _mutatedAuthority(
        (value) => value['documentKind'] = 'blankForm',
      ),
      'testament': _mutatedAuthority(
        (value) => value['documentKind'] = 'testament',
      ),
      'raw OCR only': <String, dynamic>{
        'rawText': 'Beneficiaire selon OPP 3',
        'confidence': 1,
      },
      'wrong response type': _mutatedAuthority(
        (value) => value['documentType'] = 'pillar_3a_attestation',
      ),
      'inexact confidence payload': _mutatedAuthority(
        (value) => value['confidence'] = 0.99,
      ),
      'wrong schema version': _mutatedAuthority(
        (value) => value['schemaVersion'] = 2,
      ),
      'non UUIDv4 authority': _mutatedAuthority(
        (value) => value['documentAuthorityId'] = 'authority-from-ocr',
      ),
      'institution did not attest': _mutatedAuthority(
        (value) => value['institutionAttested'] = false,
      ),
      'not contract scoped': _mutatedAuthority(
        (value) => value['contractScoped'] = false,
      ),
      'not review-only': _mutatedAuthority(
        (value) => value['needsReview'] = false,
      ),
      'missing legal year': _mutatedAuthority(
        (value) => value.remove('legalYear'),
      ),
      'invalid legal year': _mutatedAuthority(
        (value) => value['legalYear'] = 1899,
      ),
      'source date cannot infer regime': _mutatedAuthority((value) {
        value['temporalBasis'] = <String, dynamic>{
          'kind': 'attestedRegime',
          'regime': null,
        };
      }),
      'both temporal unions': _mutatedAuthority((value) {
        final temporal = value['temporalBasis'] as Map<String, dynamic>;
        temporal['regime'] = 'post20270601';
      }),
    };

final class _StaticCoachProvider extends CoachProfileProvider {
  @override
  CoachProfile get profile => CoachProfile.defaults();

  @override
  bool get hasProfile => true;

  @override
  bool get isLoaded => true;
}

final class _Counters {
  int consent = 0;
  int picker = 0;
  int bytes = 0;
  int vision = 0;
  int contractReferenceFactories = 0;
  final consentPurposes = <List<ConsentPurpose>>[];
  final visionDocumentTypes = <String>[];
  final transmittedBase64 = <String>[];
}

final class _Harness {
  const _Harness({
    required this.widget,
    required this.router,
    required this.sessions,
    required this.counters,
  });

  final Widget widget;
  final GoRouter router;
  final ScanSessionProvider sessions;
  final _Counters counters;
}

_Harness _harness({
  Map<String, dynamic>? response,
  Object? visionError,
  bool replacement = false,
}) {
  final counters = _Counters();
  final sessions = ScanSessionProvider();
  final coach = _StaticCoachProvider();
  final byok = ByokProvider();
  late final GoRouter router;
  router = GoRouter(
    initialLocation: '/scan?type=pillar3aBeneficiaryClause',
    routes: <RouteBase>[
      GoRoute(
        path: '/scan',
        builder: (_, state) {
          final requestedType = state.uri.queryParameters['type'];
          final initialType = DocumentType.values
              .where((type) => type.name == requestedType)
              .firstOrNull;
          final extra = state.extra;
          return DocumentScanScreen(
            initialType: initialType,
            pillar3aBeneficiaryScanContext:
                extra is Pillar3aBeneficiaryScanContext ? extra : null,
            pillar3aContractReferenceIdFactory: () {
              counters.contractReferenceFactories += 1;
              return _contractId;
            },
            requireConsent: (_, purposes) async {
              counters.consent += 1;
              counters.consentPurposes.add(List<ConsentPurpose>.of(purposes));
              return true;
            },
            pickFile: () async {
              counters.picker += 1;
              return PlatformFile(
                name: 'beneficiary-clause.jpg',
                path: '/synthetic/beneficiary-clause.jpg',
                size: 4,
              );
            },
            readFileBytes: (_) async {
              counters.bytes += 1;
              return Uint8List.fromList(const <int>[0xff, 0xd8, 0xff, 0xd9]);
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
              counters.visionDocumentTypes.add(documentType);
              counters.transmittedBase64.add(imageBase64);
              if (visionError != null) throw visionError;
              return response ?? _exactAuthorityJson();
            },
          );
        },
      ),
      GoRoute(
        path: '/scan/review',
        builder: (_, state) => Scaffold(
          key: const Key('pillar3a_acquisition_review_destination'),
          body: Text(state.uri.queryParameters['scanSessionId'] ?? ''),
        ),
      ),
    ],
  );
  if (replacement) {
    router.go(
      '/scan?type=pillar3aBeneficiaryClause',
      extra: Pillar3aBeneficiaryScanContext.replacement(
        contractReferenceId: _contractId,
        expectedPreviousReferenceId: _previousReferenceId,
      ),
    );
  }
  return _Harness(
    router: router,
    sessions: sessions,
    counters: counters,
    widget: MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: coach),
        ChangeNotifierProvider<ScanSessionProvider>.value(value: sessions),
        ChangeNotifierProvider<ByokProvider>.value(value: byok),
      ],
      child: MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
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

Future<void> _tapGallery(WidgetTester tester) async {
  final gallery = find.byKey(const Key('document_scan_gallery_cta'));
  expect(gallery, findsOneWidget);
  await tester.ensureVisible(gallery);
  await tester.tap(gallery);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
    FeatureFlags.typedLppEvidence = false;
  });

  test('strict typed parser accepts only the top-level backend candidate', () {
    final candidate = Pillar3aBeneficiaryAuthorityCandidateV1.tryFromVisionJson(
      _exactAuthorityJson(),
    );

    expect(candidate, isNotNull);
    expect(candidate!.schemaVersion, 1);
    expect(candidate.documentAuthorityId, _authorityId);
    expect(
      candidate.documentKind,
      Pillar3aBeneficiaryAuthorityDocumentKind.confirmationInstitutionnelle,
    );
    expect(candidate.sourceDate, DateTime.utc(2026, 7, 18));
    expect(candidate.legalYear, 2026);
    expect(candidate.institutionAttested, isTrue);
    expect(candidate.contractScoped, isTrue);
    expect(candidate.needsReview, isTrue);
    expect(
      candidate.temporalBasis.toJson(),
      <String, Object?>{
        'kind': 'exactDates',
        'designationEffectiveDate': '2026-01-15',
        'lastAssignmentModificationDate': null,
      },
    );
    for (final documentKind in <String>[
      'confirmationInstitutionnelle',
      'avenantAccuse',
      'formulaireDesignationAccuse',
    ]) {
      expect(
        Pillar3aBeneficiaryAuthorityCandidateV1.tryFromVisionJson(
          _mutatedAuthority(
            (value) => value['documentKind'] = documentKind,
          ),
        ),
        isNotNull,
        reason: documentKind,
      );
    }
    final attestedRegime =
        Pillar3aBeneficiaryAuthorityCandidateV1.tryFromVisionJson(
      _mutatedAuthority((value) {
        value['sourceDate'] = '2027-07-18';
        value['legalYear'] = 2027;
        value['temporalBasis'] = <String, dynamic>{
          'kind': 'attestedRegime',
          'regime': 'post20270601',
        };
      }),
    );
    expect(
      attestedRegime?.temporalBasis.toJson(),
      <String, Object?>{
        'kind': 'attestedRegime',
        'regime': 'post20270601',
      },
    );
    for (final invalid in _invalidAuthorityResponses().entries) {
      expect(
        Pillar3aBeneficiaryAuthorityCandidateV1.tryFromVisionJson(
          invalid.value,
        ),
        isNull,
        reason: invalid.key,
      );
    }
  });

  testWidgets('default-off route hides exact type and performs zero I/O',
      (tester) async {
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
    final harness = _harness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier(
        'document_scan_pillar3a_beneficiary_clause_type_selector',
      ),
      findsNothing,
    );
    expect(harness.counters.consent, 0);
    expect(harness.counters.picker, 0);
    expect(harness.counters.bytes, 0);
    expect(harness.counters.vision, 0);
    expect(harness.counters.contractReferenceFactories, 0);
    expect(harness.sessions.retainedSessionCount, 0);
  });

  testWidgets('flag-on initializes one stable local insertion contract UUID',
      (tester) async {
    final harness = _harness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier(
        'document_scan_pillar3a_beneficiary_clause_type_selector',
      ),
      findsOneWidget,
    );
    expect(harness.counters.contractReferenceFactories, 1);
    expect(harness.counters.vision, 0);
    expect(harness.sessions.retainedSessionCount, 0);
  });

  testWidgets(
      'real scan sends exact type and retains exact local-contract candidate',
      (tester) async {
    final harness = _harness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier(
        'document_scan_pillar3a_beneficiary_clause_type_selector',
      ),
      findsOneWidget,
    );

    await _tapGallery(tester);

    expect(harness.counters.consent, 1);
    expect(
      harness.counters.consentPurposes.single,
      <ConsentPurpose>[
        ConsentPurpose.visionExtraction,
        ConsentPurpose.persistence365d,
        ConsentPurpose.transferUsAnthropic,
      ],
    );
    expect(harness.counters.picker, 1);
    expect(harness.counters.bytes, greaterThanOrEqualTo(1));
    expect(harness.counters.vision, 1);
    expect(
      harness.counters.visionDocumentTypes,
      <String>['pillar_3a_beneficiary_clause'],
    );
    expect(
      base64Decode(harness.counters.transmittedBase64.single),
      Uint8List.fromList(const <int>[0xff, 0xd8, 0xff, 0xd9]),
    );
    expect(
      find.byKey(const Key('pillar3a_acquisition_review_destination')),
      findsOneWidget,
    );

    final uri = harness.router.routeInformationProvider.value.uri;
    expect(uri.path, '/scan/review');
    expect(uri.queryParameters.keys, <String>['scanSessionId']);
    expect(uri.toString(), isNot(contains(_contractId)));
    expect(uri.toString(), isNot(contains(_authorityId)));
    final payload = harness.sessions.byId(uri.queryParameters['scanSessionId']);
    expect(payload, isNotNull);
    expect(payload!.extraction.documentType,
        DocumentType.pillar3aBeneficiaryClause);
    expect(payload.extraction.fields, isEmpty);
    expect(payload.extraction.sources, isEmpty);
    final candidate = payload.pillar3aBeneficiaryCandidate!;
    expect(candidate.contractReferenceId, _contractId);
    expect(candidate.expectedPreviousReferenceId, isNull);
    expect(candidate.authority.documentAuthorityId, _authorityId);
    expect(
      candidate.authority.documentAuthorityId,
      isNot(candidate.contractReferenceId),
    );
    expect(candidate.authority.legalYear, 2026);
    expect(harness.counters.contractReferenceFactories, 1);
  });

  testWidgets('typed route extra supplies exact replacement contract and CAS',
      (tester) async {
    final harness = _harness(replacement: true);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _tapGallery(tester);

    final uri = harness.router.routeInformationProvider.value.uri;
    final payload = harness.sessions.byId(uri.queryParameters['scanSessionId']);
    final candidate = payload!.pillar3aBeneficiaryCandidate!;
    expect(candidate.contractReferenceId, _contractId);
    expect(candidate.expectedPreviousReferenceId, _previousReferenceId);
    expect(candidate.authority.documentAuthorityId, _authorityId);
    expect(harness.counters.contractReferenceFactories, 0);
  });

  testWidgets('generic 3a response fails closed without volatile handoff',
      (tester) async {
    final harness = _harness(
      response: _invalidAuthorityResponses()['generic 3a attestation balance'],
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _tapGallery(tester);

    expect(harness.counters.vision, 1);
    expect(harness.sessions.retainedSessionCount, 0);
    expect(harness.router.routeInformationProvider.value.uri.path, '/scan');
    expect(
      find.byKey(const Key('pillar3a_acquisition_review_destination')),
      findsNothing,
    );
  });

  testWidgets('timeout is stable and never falls back to OCR authority',
      (tester) async {
    final harness = _harness(
      visionError: TimeoutException('synthetic beneficiary timeout'),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _tapGallery(tester);

    expect(harness.counters.vision, 1);
    expect(harness.sessions.retainedSessionCount, 0);
    expect(harness.router.routeInformationProvider.value.uri.path, '/scan');
    expect(
      find.byKey(const Key('pillar3a_acquisition_review_destination')),
      findsNothing,
    );
  });

  test('production /scan uses typed replacement extra and never query IDs', () {
    final source = File('lib/app.dart').readAsStringSync();
    final scanStart = source.indexOf("path: '/scan'");
    final avsGuideStart = source.indexOf("path: '/scan/avs-guide'", scanStart);
    expect(scanStart, greaterThanOrEqualTo(0));
    expect(avsGuideStart, greaterThan(scanStart));
    final scanRoute = source.substring(scanStart, avsGuideStart);

    expect(
        scanRoute, contains('state.extra is Pillar3aBeneficiaryScanContext'));
    expect(scanRoute, contains('pillar3aBeneficiaryScanContext:'));
    expect(
      scanRoute,
      isNot(contains("queryParameters['contractReferenceId']")),
    );
    expect(
      scanRoute,
      isNot(contains("queryParameters['expectedPreviousReferenceId']")),
    );
    expect(scanRoute, isNot(contains('documentAuthorityId')));
  });
}
