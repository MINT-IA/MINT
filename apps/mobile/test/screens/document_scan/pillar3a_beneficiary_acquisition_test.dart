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
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/data.dart';

const _contractId = '11111111-1111-4111-8111-111111111111';
const _authorityId = '33333333-3333-4333-8333-333333333333';
const _referenceId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _scanContextId = '22222222-2222-4222-8222-222222222222';
const _syntheticImageMetadata = 'MINT_SYNTHETIC_GPS=46.5197,6.6323';

Uint8List _pngWithSyntheticMetadata() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAKXRFWHRDb21tZW50AE1JTlRfU1lOVEhFVElDX0dQUz00Ni41MTk3LDYuNjMyMy1UPUEAAAATSURBVHicY/z//z8DDDDBWXg5AJZuAwXtmMfUAAAAAElFTkSuQmCC',
  );
}

Uint8List _pngWithoutSyntheticMetadata() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAE0lEQVR4nGP8//8/AwwwwVl4OQCWbgMF7ZjH1AAAAABJRU5ErkJggg==',
    );

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
  int referencePreallocations = 0;
  final consentPurposes = <List<ConsentPurpose>>[];
  final visionDocumentTypes = <String>[];
  final transmittedBase64 = <String>[];
  final advertisedExtensions = <String>[];
}

final class _SequenceUuid extends Uuid {
  _SequenceUuid(this.values);

  final List<String> values;
  int index = 0;

  @override
  String v4({Map<String, dynamic>? options, V4Options? config}) =>
      values[index++];
}

final class _DocumentPreallocatorSpy extends DocumentProvider {
  _DocumentPreallocatorSpy(this.counters);

  final _Counters counters;

  @override
  String preallocatePillar3aBeneficiaryReferenceId({
    required String contractReferenceId,
    required String documentAuthorityId,
  }) {
    counters.referencePreallocations += 1;
    if (contractReferenceId != _contractId ||
        documentAuthorityId != _authorityId) {
      throw StateError('synthetic preallocation identity mismatch');
    }
    return _referenceId;
  }
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
  Uint8List? imageBytes,
  PlatformFile? pickedFile,
  DocumentScanImageSanitizer? imageSanitizer,
}) {
  final counters = _Counters();
  final sessions = ScanSessionProvider(
    uuid: _SequenceUuid(<String>[_scanContextId, _contractId]),
  );
  final scanContextId = sessions.retainPillar3aBeneficiaryScanIntent(
    kind: Pillar3aBeneficiaryScanIntentKind.insertion,
    returnUri: '/retraite',
  );
  final coach = _StaticCoachProvider();
  final byok = ByokProvider();
  final documents = _DocumentPreallocatorSpy(counters);
  late final GoRouter router;
  router = GoRouter(
    initialLocation: Uri(
      path: '/scan',
      queryParameters: <String, String>{
        'scanContextId': scanContextId,
        'returnUri': '/retraite',
      },
    ).toString(),
    routes: <RouteBase>[
      GoRoute(
        path: '/scan',
        builder: (_, state) {
          return DocumentScanScreen(
            initialType: DocumentType.pillar3aBeneficiaryClause,
            scanContextId: state.uri.queryParameters['scanContextId'],
            returnUri: state.uri.queryParameters['returnUri'],
            now: () => DateTime.utc(2026, 7, 19, 10),
            onPickerAllowedExtensions: (extensions) {
              counters.advertisedExtensions
                ..clear()
                ..addAll(extensions);
            },
            pillar3aImageSanitizer:
                imageSanitizer ?? (_) async => _pngWithoutSyntheticMetadata(),
            requireConsent: (_, purposes) async {
              counters.consent += 1;
              counters.consentPurposes.add(List<ConsentPurpose>.of(purposes));
              return true;
            },
            pickFile: () async {
              counters.picker += 1;
              return pickedFile ??
                  PlatformFile(
                    name: 'beneficiary-clause.png',
                    path: '/synthetic/beneficiary-clause.png',
                    size: _pngWithSyntheticMetadata().length,
                  );
            },
            readFileBytes: (_) async {
              counters.bytes += 1;
              return imageBytes ?? _pngWithSyntheticMetadata();
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
  return _Harness(
    router: router,
    sessions: sessions,
    counters: counters,
    widget: MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: coach),
        ChangeNotifierProvider<DocumentProvider>.value(value: documents),
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

  testWidgets('dart ui sanitizer removes exact 3a image metadata',
      (tester) async {
    final raw = _pngWithSyntheticMetadata();
    final sanitized = await tester.runAsync(
      () => sanitizePillar3aImageForVision(raw),
    );

    expect(sanitized, isNotNull);
    expect(latin1.decode(raw), contains(_syntheticImageMetadata));
    expect(
      latin1.decode(sanitized!),
      isNot(contains(_syntheticImageMetadata)),
    );
    expect(sanitized, isNot(equals(raw)));
  });

  test('acquisition contract identity cannot alias document authority', () {
    final authority = Pillar3aBeneficiaryAuthorityCandidateV1.tryFromVisionJson(
      _exactAuthorityJson(),
    )!;
    expect(
      () => Pillar3aBeneficiaryAcquisitionCandidate(
        contractReferenceId: _authorityId,
        referenceId: _referenceId,
        authority: authority,
      ),
      throwsArgumentError,
    );
    for (final aliasedReferenceId in <String>[_contractId, _authorityId]) {
      expect(
        () => Pillar3aBeneficiaryAcquisitionCandidate(
          contractReferenceId: _contractId,
          referenceId: aliasedReferenceId,
          authority: authority,
        ),
        throwsArgumentError,
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
    expect(harness.counters.referencePreallocations, 0);
    expect(harness.sessions.retainedSessionCount, 0);
  });

  testWidgets('production scan route requires the exact opaque intent query',
      (tester) async {
    final sessions = ScanSessionProvider();
    final scanContextId = sessions.retainPillar3aBeneficiaryScanIntent(
      kind: Pillar3aBeneficiaryScanIntentKind.insertion,
      returnUri: '/retraite',
    );
    addTearDown(sessions.dispose);
    Widget route(Uri uri) => MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<ScanSessionProvider>.value(value: sessions),
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: _StaticCoachProvider(),
            ),
            ChangeNotifierProvider<DocumentProvider>(
              create: (_) => DocumentProvider(),
            ),
            ChangeNotifierProvider<ByokProvider>(
              create: (_) => ByokProvider(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: testOnlyBuildScanRoute(uri),
          ),
        );

    await tester.pumpWidget(route(Uri(
      path: '/scan',
      queryParameters: <String, String>{
        'scanContextId': scanContextId,
        'returnUri': '/retraite',
      },
    )));
    await tester.pump();
    expect(find.byType(DocumentScanScreen), findsOneWidget);
    expect(find.byType(ChoiceChip), findsOneWidget);

    await tester.pumpWidget(route(Uri(
      path: '/scan',
      queryParameters: <String, String>{
        'scanContextId': scanContextId,
        'returnUri': '/retraite',
        'type': DocumentType.pillar3aBeneficiaryClause.name,
      },
    )));
    await tester.pump();
    expect(find.byType(DocumentScanScreen), findsNothing);
    expect(find.byKey(const Key('scan_review_recovery_cta')), findsOneWidget);

    Future<void> expectRecovery(Uri uri) async {
      await tester.pumpWidget(route(uri));
      await tester.pump();
      expect(find.byType(DocumentScanScreen), findsNothing);
      expect(
        find.byKey(const Key('scan_review_recovery_cta')),
        findsOneWidget,
      );
    }

    await expectRecovery(Uri(
      path: '/scan',
      queryParameters: const <String, String>{'returnUri': '/retraite'},
    ));
    await expectRecovery(Uri(
      path: '/scan',
      queryParameters: const <String, String>{
        'scanContextId': '99999999-9999-4999-8999-999999999999',
        'returnUri': '/retraite',
      },
    ));
    final invalidReturnContext = sessions.retainPillar3aBeneficiaryScanIntent(
      kind: Pillar3aBeneficiaryScanIntentKind.insertion,
      returnUri: '/retraite',
    );
    await expectRecovery(Uri(
      path: '/scan',
      queryParameters: <String, String>{
        'scanContextId': invalidReturnContext,
        'returnUri': '/home',
      },
    ));

    for (final flag in <String>['typed', 'document', 'reference']) {
      final contextId = sessions.retainPillar3aBeneficiaryScanIntent(
        kind: Pillar3aBeneficiaryScanIntentKind.insertion,
        returnUri: '/retraite',
      );
      switch (flag) {
        case 'typed':
          FeatureFlags.typedLppEvidence = false;
          break;
        case 'document':
          FeatureFlags.documentLppEvidenceEnabled = false;
          break;
        case 'reference':
          FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
          break;
      }
      await expectRecovery(Uri(
        path: '/scan',
        queryParameters: <String, String>{
          'scanContextId': contextId,
          'returnUri': '/retraite',
        },
      ));
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
    }
  });

  testWidgets('flag-on resolves one stable registry insertion contract UUID',
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
    expect(harness.counters.vision, 0);
    expect(harness.counters.referencePreallocations, 0);
    expect(harness.sessions.retainedSessionCount, 0);
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -1400),
      1800,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('backend MINT puis temporairement transmis'),
      findsOneWidget,
    );
    expect(find.textContaining('Anthropic'), findsOneWidget);
    expect(
      find.textContaining('métadonnées locales de référence sans contenu brut'),
      findsOneWidget,
    );
    expect(find.textContaining('MINT ne collecte'), findsNothing);
  });

  testWidgets(
      'real scan strips image metadata and retains exact local-contract candidate',
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
        ConsentPurpose.transferUsAnthropic,
      ],
    );
    expect(harness.counters.picker, 1);
    expect(
      harness.counters.advertisedExtensions,
      <String>['jpg', 'jpeg', 'png', 'heic', 'pdf'],
    );
    expect(harness.counters.advertisedExtensions, isNot(contains('txt')));
    expect(harness.counters.bytes, greaterThanOrEqualTo(1));
    expect(harness.counters.vision, 1);
    expect(
      harness.counters.visionDocumentTypes,
      <String>['pillar_3a_beneficiary_clause'],
    );
    final transmitted = base64Decode(harness.counters.transmittedBase64.single);
    expect(latin1.decode(_pngWithSyntheticMetadata()),
        contains(_syntheticImageMetadata));
    expect(
        latin1.decode(transmitted), isNot(contains(_syntheticImageMetadata)));
    expect(transmitted, isNot(equals(_pngWithSyntheticMetadata())));
    expect(
      find.byKey(const Key('pillar3a_acquisition_review_destination')),
      findsOneWidget,
    );

    final uri = harness.router.routeInformationProvider.value.uri;
    expect(uri.path, '/scan/review');
    expect(
      uri.queryParameters.keys.toSet(),
      <String>{'scanSessionId', 'returnUri'},
    );
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
    expect(candidate.referenceId, _referenceId);
    expect(candidate.authority.documentAuthorityId, _authorityId);
    expect(
      candidate.authority.documentAuthorityId,
      isNot(candidate.contractReferenceId),
    );
    expect(candidate.authority.legalYear, 2026);
    expect(harness.counters.referencePreallocations, 1);
  });

  testWidgets('invalid exact 3a image fails closed before Vision or review',
      (tester) async {
    final harness = _harness(
      imageBytes: Uint8List.fromList(const <int>[0xff, 0xd8, 0xff, 0xd9]),
      imageSanitizer: (_) async =>
          throw const FormatException('synthetic invalid image'),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _tapGallery(tester);

    expect(harness.counters.vision, 0);
    expect(harness.sessions.retainedSessionCount, 0);
    expect(harness.router.routeInformationProvider.value.uri.path, '/scan');
  });

  testWidgets('future source date fails closed before volatile review',
      (tester) async {
    final harness = _harness(
      response: _mutatedAuthority((value) {
        value['sourceDate'] = '2026-07-20';
      }),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _tapGallery(tester);

    expect(harness.counters.vision, 1);
    expect(harness.sessions.retainedSessionCount, 0);
    expect(harness.router.routeInformationProvider.value.uri.path, '/scan');
  });

  testWidgets('exact 3a PDF recovery never offers Paste OCR', (tester) async {
    final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.7 synthetic'));
    final harness = _harness(
      response: _invalidAuthorityResponses()['generic 3a attestation balance'],
      imageBytes: pdfBytes,
      pickedFile: PlatformFile(
        name: 'beneficiary-clause.pdf',
        path: '/synthetic/beneficiary-clause.pdf',
        size: pdfBytes.length,
      ),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _tapGallery(tester);

    expect(
      harness.counters.consentPurposes.single,
      <ConsentPurpose>[
        ConsentPurpose.visionExtraction,
        ConsentPurpose.transferUsAnthropic,
      ],
    );
    expect(find.text('Coller le texte OCR'), findsNothing);
    expect(harness.sessions.retainedSessionCount, 0);
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

  test('production /scan is insertion-only with no Pillar3a domain state', () {
    final source = File('lib/app.dart').readAsStringSync();
    final scanStart = source.indexOf("path: '/scan'");
    final avsGuideStart = source.indexOf("path: '/scan/avs-guide'", scanStart);
    expect(scanStart, greaterThanOrEqualTo(0));
    expect(avsGuideStart, greaterThan(scanStart));
    final scanRoute = source.substring(scanStart, avsGuideStart);

    expect(scanRoute, isNot(contains('state.extra')));
    expect(scanRoute, isNot(contains('Pillar3aBeneficiaryScanContext')));
    expect(scanRoute, isNot(contains('pillar3aBeneficiaryScanContext')));
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
