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
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';
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

  @override
  String retainExtraction(
    ExtractionResult extraction, {
    LppExtractionCandidate? lppCandidate,
    LppAcquisitionAuthorization? lppAuthorization,
    TaxExtractionCandidate? taxCandidate,
  }) {
    if (lppAuthorization != null) {
      retainedAuthorizations.add(lppAuthorization);
    }
    return super.retainExtraction(
      extraction,
      lppCandidate: lppCandidate,
      lppAuthorization: lppAuthorization,
      taxCandidate: taxCandidate,
    );
  }
}

final class _Counters {
  int consent = 0;
  int picker = 0;
  int bytes = 0;
  int hash = 0;
  int network = 0;
  final events = <String>[];
  final transmittedPayloads = <Uint8List>[];
  final readPaths = <String>[];
}

({Widget widget, _ScanSessionSpy sessions, GoRouter router}) _harness({
  required CoachProfile profile,
  required _Counters counters,
  bool consentGranted = true,
  List<String>? acquisitionIds,
  DocumentScanDocumentHasher? documentHasher,
  Future<bool> Function()? consentAction,
  void Function()? pickerAction,
  PlatformFile Function(Uint8List bytes)? platformFile,
  Map<String, dynamic>? visionResponse,
}) {
  final sessions = _ScanSessionSpy();
  final ids = acquisitionIds ??
      <String>[
        '123e4567-e89b-42d3-a456-426614174000',
        '123e4567-e89b-42d3-a456-426614174001',
      ];
  var nextId = 0;
  final bytes = Uint8List.fromList(const [0, 1, 2, 255]);
  late final GoRouter router;
  router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => DocumentScanScreen(
          initialType: DocumentType.lppCertificate,
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
            expect(
              purposes,
              const [
                ConsentPurpose.visionExtraction,
                ConsentPurpose.transferUsAnthropic,
              ],
            );
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

  setUp(() {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
  });
  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
  });

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
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_partner_attest_confirm')),
    );
    await tester.pumpAndSettle();

    expect(counters.consent, 1);
    expect(counters.picker, 0);
    expect(counters.bytes, 0);
    expect(counters.hash, 0);
    expect(counters.network, 0);
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
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_partner_attest_confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lpp_review_destination')), findsOneWidget);
    expect(counters.consent, 1);
    expect(counters.picker, 1);
    expect(counters.bytes, greaterThanOrEqualTo(1));
    expect(counters.hash, 1);
    expect(counters.network, 1);
    expect(
      harness.sessions.retainedAuthorizations,
      hasLength(1),
      reason:
          'events=${counters.events} paths=${counters.readPaths} payloads=${counters.transmittedPayloads.length}',
    );
    final authorization = harness.sessions.retainedAuthorizations.single;
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
      'failed partner PDF reuses its gated decision for manual recovery',
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
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_partner_attest_confirm')),
    );
    await tester.pumpAndSettle();

    final manualRecovery = find.widgetWithIcon(
      OutlinedButton,
      Icons.text_snippet_outlined,
    );
    expect(manualRecovery, findsOneWidget);
    await tester.tap(manualRecovery);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const Key('lpp_acquisition_owner_gate')), findsNothing);
    await tester.enterText(
      find.byType(TextField),
      LppCertificateParser.sampleOcrText,
    );
    await tester.tap(
      find.byKey(const Key('document_scan_manual_analyze_cta')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lpp_review_destination')), findsOneWidget);
    expect(counters.consent, 1);
    expect(counters.picker, 1);
    expect(counters.network, 1);
    expect(counters.hash, 2);
    expect(harness.sessions.retainedAuthorizations, hasLength(1));
    final authorization = harness.sessions.retainedAuthorizations.single;
    expect(
      authorization.acquisitionId,
      '123e4567-e89b-42d3-a456-426614174000',
    );
    expect(authorization.subject, LppEvidenceOwnerKind.manualPartner);
    expect(authorization.partnerAttested, isTrue);
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
    await tester.tap(
      find.byKey(const Key('lpp_acquisition_partner_attest_confirm')),
    );
    await tester.pumpAndSettle();

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
