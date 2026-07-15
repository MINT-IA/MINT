import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/screens/document_scan/document_impact_screen.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';

const _rawSentinel = 'RAW-OCR-PII-MUST-NEVER-PERSIST';

final class _MemoryLppPersistence implements LppProfilePersistence {
  _MemoryLppPersistence({this.failSave = false});

  final bool failSave;
  Map<String, dynamic> answers = <String, dynamic>{};
  int saveCalls = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() async => _copy(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveCalls += 1;
    if (failSave) throw StateError('synthetic strict-secure failure');
    answers = _copy(next);
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}

final class _BiographySpy extends BiographyProvider {
  int addFactCalls = 0;

  @override
  Future<void> addFact(BiographyFact fact) async {
    addFactCalls += 1;
  }
}

final class _CoachProfileSpy extends CoachProfileProvider {
  _CoachProfileSpy({required LppProfilePersistence persistence})
      : super(lppProfilePersistence: persistence);

  int acceptLppReviewCalls = 0;

  @override
  Future<void> acceptLppReview(LppReviewConfirmation confirmation) async {
    acceptLppReviewCalls += 1;
    await super.acceptLppReview(confirmation);
  }
}

final class _ExternalSyncSpy {
  int calls = 0;

  Future<void> call({
    required String documentType,
    required List<Map<String, dynamic>> confirmedFields,
    required double overallConfidence,
  }) async {
    calls += 1;
  }
}

final class _ConfiguredByokProvider extends ByokProvider {
  @override
  bool get isConfigured => true;

  @override
  String? get apiKey => 'synthetic-test-key';

  @override
  String? get provider => 'claude';
}

Widget _scanHarness() => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider(create: (_) => ScanSessionProvider()),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: DocumentScanScreen(initialType: DocumentType.lppCertificate),
      ),
    );

ExtractionResult _lppExtraction({
  List<ExtractedField>? fields,
}) =>
    ExtractionResult(
      documentType: DocumentType.lppCertificate,
      fields: fields ??
          const [
            ExtractedField(
              fieldName: 'lpp_total',
              label: 'fixture-label-must-not-persist',
              value: 125000.0,
              confidence: 0.99,
              sourceText: _rawSentinel,
              needsReview: false,
              profileField: 'avoirLppTotal',
            ),
          ],
      overallConfidence: 0.99,
      confidenceDelta: 27,
      warnings: const [_rawSentinel],
      disclaimer: _rawSentinel,
      sources: const [_rawSentinel],
      diagnostics: const [ExtractionDiagnostic.percentUnit(99)],
    );

final class _ReviewHarness {
  const _ReviewHarness({
    required this.widget,
    required this.router,
    required this.persistence,
    required this.biography,
    required this.externalSync,
    required this.coach,
    required this.scanSessions,
    required this.scanSessionId,
  });

  final Widget widget;
  final GoRouter router;
  final _MemoryLppPersistence persistence;
  final _BiographySpy biography;
  final _ExternalSyncSpy externalSync;
  final _CoachProfileSpy coach;
  final ScanSessionProvider scanSessions;
  final String scanSessionId;
}

final class _ProductionScanHarness {
  const _ProductionScanHarness({
    required this.widget,
    required this.router,
    required this.sessions,
  });

  final Widget widget;
  final GoRouter router;
  final ScanSessionProvider sessions;
}

_ProductionScanHarness _productionScanHarness({
  DocumentType initialType = DocumentType.lppCertificate,
  Future<PlatformFile?> Function()? pickFile,
  Future<Uint8List> Function(String path)? readFileBytes,
  Future<bool> Function(BuildContext, List<ConsentPurpose>)? requireConsent,
  Future<Map<String, dynamic>?> Function({
    required String imageBase64,
    required String documentType,
    String? canton,
    String? languageHint,
  })? visionExtractor,
  Future<DocumentUploadResult> Function(
    File file, {
    required VaultDocumentType type,
  })? uploadDocument,
  ByokProvider? byokProvider,
}) {
  final sessions = ScanSessionProvider();
  late final GoRouter router;
  router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => DocumentScanScreen(
          initialType: initialType,
          pickFile: pickFile,
          readFileBytes: readFileBytes,
          requireConsent: requireConsent,
          visionExtractor: visionExtractor,
          uploadDocument: uploadDocument,
        ),
      ),
      GoRoute(
        path: '/scan/review',
        builder: (_, state) => Scaffold(
          key: const Key('production_lpp_review_destination'),
          body: Text(state.uri.queryParameters['scanSessionId'] ?? ''),
        ),
      ),
    ],
  );
  final widget = MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
      ChangeNotifierProvider<ByokProvider>.value(
        value: byokProvider ?? ByokProvider(),
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
  );
  return _ProductionScanHarness(
    widget: widget,
    router: router,
    sessions: sessions,
  );
}

_ReviewHarness _reviewHarness({
  required ExtractionResult extraction,
  DateTime? sourceDate,
  bool failSave = false,
}) {
  final persistence = _MemoryLppPersistence(failSave: failSave);
  final coach = _CoachProfileSpy(persistence: persistence);
  final biography = _BiographySpy();
  final externalSync = _ExternalSyncSpy();
  final sessions = ScanSessionProvider();
  final candidate = LppExtractionAdapter.adapt(
    source: LppAcquisitionSource.localParser,
    sourceOverallConfidence: extraction.overallConfidence,
    fields: extraction.fields,
    sourceDate: sourceDate,
  ).candidate;
  final reviewExtraction = candidate == null
      ? extraction
      : ExtractionResult(
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
          confidenceDelta: extraction.confidenceDelta,
          warnings: const [],
          disclaimer: '',
          sources: const [],
        );
  final scanSessionId = sessions.retainExtraction(
    reviewExtraction,
    lppCandidate: candidate,
  );
  late final GoRouter router;
  router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ExtractionReviewScreen(
          scanSessionId: scanSessionId,
          result: reviewExtraction,
          lppCandidate: candidate,
          sendScanConfirmation: externalSync.call,
          confidenceScorer: (_) => 42,
        ),
      ),
      GoRoute(
        path: '/scan/impact',
        builder: (_, __) => const Scaffold(
          key: Key('lpp_impact_destination'),
          body: SizedBox.shrink(),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(
          key: Key('lpp_recovery_destination'),
          body: SizedBox.shrink(),
        ),
      ),
    ],
  );
  final widget = MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: coach),
      ChangeNotifierProvider<BiographyProvider>.value(value: biography),
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
  );
  return _ReviewHarness(
    widget: widget,
    router: router,
    persistence: persistence,
    biography: biography,
    externalSync: externalSync,
    coach: coach,
    scanSessions: sessions,
    scanSessionId: scanSessionId,
  );
}

Map<String, dynamic> _strictRoot(_MemoryLppPersistence persistence) {
  final encoded = persistence.answers['_coach_lpp_evidence_v1'];
  expect(encoded, isA<String>());
  return Map<String, dynamic>.from(jsonDecode(encoded as String) as Map);
}

Future<void> _tapConfirmAndChoose(
  WidgetTester tester, {
  required bool manualPartner,
}) async {
  final confirm = find.byKey(const Key('lpp_review_confirm_cta'));
  await tester.scrollUntilVisible(
    confirm,
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.drag(
    find.byType(Scrollable).first,
    const Offset(0, -100),
  );
  await tester.pumpAndSettle();
  await tester.tap(confirm);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(manualPartner
      ? 'lpp_review_subject_manual_partner'
      : 'lpp_review_subject_self')));
  await tester.pumpAndSettle();
}

Future<void> _enterLppSourceDate(
  WidgetTester tester,
  String value,
) async {
  final field = find.byKey(const Key('lpp_review_source_date'));
  await tester.scrollUntilVisible(
    field,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
  });

  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
  });

  test('LPP document flags are double-default-off and never backend hydrated',
      () {
    expect(FeatureFlags.lppEvidenceIngestionEnabled, isFalse);

    FeatureFlags.applyFromMap(const {
      'typedLppEvidence': true,
      'documentLppEvidenceEnabled': true,
      'lppEvidenceIngestionEnabled': true,
    });

    expect(FeatureFlags.typedLppEvidence, isFalse);
    expect(FeatureFlags.documentLppEvidenceEnabled, isFalse);
    expect(FeatureFlags.lppEvidenceIngestionEnabled, isFalse);
  });

  test('review source contains no legacy LPP writer fallback', () {
    final reviewSource = File(
      'lib/screens/document_scan/extraction_review_screen.dart',
    ).readAsStringSync();
    final providerSource = File(
      'lib/providers/coach_profile_provider.dart',
    ).readAsStringSync();

    expect(reviewSource, isNot(contains('updateFromLppExtraction(')));
    expect(reviewSource, isNot(contains('updateFromPartnerLppExtraction(')));
    expect(providerSource, isNot(contains('updateFromLppExtraction(')));
    expect(
      providerSource,
      isNot(contains('updateFromPartnerLppExtraction(')),
    );
  });

  test('mobile exposes no dead fused document facade', () {
    final serviceSource = File(
      'lib/services/document_service.dart',
    ).readAsStringSync();
    const fusedFacadeFiles = <String>[
      'lib/services/document_progressive_state.dart',
      'lib/services/document_understanding_result.dart',
      'lib/services/document/render_mode_handler.dart',
      'lib/services/document/third_party_flow.dart',
      'lib/widgets/document/document_result_view.dart',
      'lib/widgets/document/ask_question_bubble.dart',
      'lib/widgets/document/batch_validation_bubble.dart',
      'lib/widgets/document/confirm_extraction_bubble.dart',
      'lib/widgets/document/extraction_review_sheet.dart',
      'lib/widgets/document/field_correction_sheet.dart',
      'lib/widgets/document/narrative_bubble.dart',
      'lib/widgets/document/reject_bubble.dart',
      'lib/widgets/document/third_party_chip.dart',
      'lib/widgets/document/third_party_declaration_sheet.dart',
    ];

    expect(serviceSource, isNot(contains('understandDocumentStream')));
    for (final path in fusedFacadeFiles) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
  });

  test('LPP has no BYOK acquisition vocabulary or review caller', () {
    final screenSource = File(
      'lib/screens/document_scan/document_scan_screen.dart',
    ).readAsStringSync();
    final adapterSource = File(
      'lib/services/document_parser/lpp_extraction_adapter.dart',
    ).readAsStringSync();

    expect(screenSource, isNot(contains('LppAcquisitionSource.byokVision')));
    expect(adapterSource, isNot(contains('byokVision')));
    expect(adapterSource, isNot(contains('avoir_vieillesse_total')));
  });

  for (final flags in const [
    (typed: false, document: false),
    (typed: true, document: false),
    (typed: false, document: true),
  ]) {
    testWidgets(
        'scan hides LPP before acquisition when typed=${flags.typed} document=${flags.document}',
        (tester) async {
      FeatureFlags.typedLppEvidence = flags.typed;
      FeatureFlags.documentLppEvidenceEnabled = flags.document;
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_scanHarness());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('document_scan_lpp_type_selector')),
        findsNothing,
      );
      expect(find.text('Certificat de prévoyance LPP'), findsNothing);
      expect(find.text('Extrait de compte AVS'), findsWidgets);
      expect(
          find.byKey(const Key('document_scan_capture_cta')), findsOneWidget);
    });
  }

  testWidgets('production local example retains a typed raw-free LPP candidate',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = _productionScanHarness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_lpp_example_cta')));
    await tester.pumpAndSettle();

    final destination = find.byKey(
      const Key('production_lpp_review_destination'),
    );
    expect(destination, findsOneWidget);
    final sessionId = tester
        .widget<Text>(
            find.descendant(of: destination, matching: find.byType(Text)))
        .data!;
    final payload = harness.sessions.byId(sessionId)!;
    expect(payload.lppCandidate!.source, LppAcquisitionSource.localParser);
    expect(
      payload.lppCandidate!
          .factFor(LppEvidenceFactKey.mandatoryConversionRateRatio)!
          .value,
      closeTo(0.068, 1e-12),
    );
    expect(
      payload.extraction.fields.every(
        (field) =>
            LppEvidenceFactKey.fromWireName(field.fieldName) != null &&
            field.sourceText.isEmpty,
      ),
      isTrue,
    );
    expect(
      payload.extraction.fields.map((field) => field.label),
      isNot(contains('Taux de conversion (obligatoire)')),
    );
  });

  testWidgets('LPP recovery never exposes or calls BYOK Vision',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final image = File(
      '${Directory.systemTemp.path}/mint_lpp_byok_disabled_${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsBytesSync(const [1, 2, 3, 4]);
    addTearDown(() {
      if (image.existsSync()) image.deleteSync();
    });
    var backendVisionCalls = 0;
    final harness = _productionScanHarness(
      byokProvider: _ConfiguredByokProvider(),
      pickFile: () async => PlatformFile(
        name: 'lpp.jpg',
        path: image.path,
        size: image.lengthSync(),
      ),
      readFileBytes: (_) async => Uint8List.fromList(const [1, 2, 3, 4]),
      requireConsent: (_, __) async => true,
      visionExtractor: ({
        required imageBase64,
        required documentType,
        canton,
        languageHint,
      }) async {
        backendVisionCalls += 1;
        return null;
      },
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(backendVisionCalls, 1);
    expect(find.text('Texte non détecté'), findsOneWidget);
    expect(find.text('Analyser via Vision IA'), findsNothing);
    expect(
      find.byKey(const Key('production_lpp_review_destination')),
      findsNothing,
    );
  });

  testWidgets('production backend Vision maps only safe camelCase LPP facts',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final image = File(
      '${Directory.systemTemp.path}/mint_lpp_vision_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    image.writeAsBytesSync(const [1, 2, 3, 4]);
    addTearDown(() {
      if (image.existsSync()) image.deleteSync();
    });
    List<ConsentPurpose>? requestedPurposes;
    final harness = _productionScanHarness(
      pickFile: () async => PlatformFile(
        name: 'lpp.jpg',
        path: image.path,
        size: image.lengthSync(),
      ),
      readFileBytes: (_) async => Uint8List.fromList(const [1, 2, 3, 4]),
      requireConsent: (_, purposes) async {
        requestedPurposes = List.of(purposes);
        return true;
      },
      visionExtractor: ({
        required imageBase64,
        required documentType,
        canton,
        languageHint,
      }) async =>
          {
        'extractedFields': [
          {
            'fieldName': 'avoirLppTotal',
            'value': 125000.0,
            'confidence': 'high',
            'sourceText': _rawSentinel,
          },
          {
            'fieldName': 'tauxConversion',
            'value': 0.068,
            'confidence': 'high',
            'sourceText': _rawSentinel,
          },
        ],
        'overallConfidence': 0.61,
      },
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final destination = find.byKey(
      const Key('production_lpp_review_destination'),
    );
    expect(destination, findsOneWidget);
    final sessionId = tester
        .widget<Text>(
            find.descendant(of: destination, matching: find.byType(Text)))
        .data!;
    final payload = harness.sessions.byId(sessionId)!;
    expect(payload.lppCandidate!.source, LppAcquisitionSource.backendVision);
    expect(payload.lppCandidate!.facts, hasLength(1));
    expect(payload.extraction.overallConfidence, 0.61);
    expect(payload.lppCandidate!.overallConfidence, 0.61);
    expect(payload.extraction.fields.single.confidence, 0.95);
    expect(payload.extraction.fields.single.needsReview, isFalse);
    expect(
      payload.lppCandidate!
          .factFor(LppEvidenceFactKey.vestedBenefitsCapitalChf)!
          .value,
      125000,
    );
    expect(
      payload.lppCandidate!
          .factFor(LppEvidenceFactKey.mandatoryConversionRateRatio),
      isNull,
    );
    expect(requestedPurposes, isNot(contains(ConsentPurpose.persistence365d)));
    final retainedPayload = jsonEncode({
      'overallConfidence': payload.extraction.overallConfidence,
      'fields': [
        for (final field in payload.extraction.fields)
          {
            'fieldName': field.fieldName,
            'label': field.label,
            'value': field.value,
            'confidence': field.confidence,
            'sourceText': field.sourceText,
            'needsReview': field.needsReview,
            'profileField': field.profileField,
          },
      ],
      'warnings': payload.extraction.warnings,
      'disclaimer': payload.extraction.disclaimer,
      'sources': payload.extraction.sources,
      'canonicalFacts': [
        for (final fact in payload.lppCandidate!.facts.values)
          {
            'key': fact.key.wireName,
            'value': fact.value,
            'confidence': fact.confidence,
            'needsReview': fact.needsReview,
            'derived': fact.derived,
          },
      ],
    });
    expect(retainedPayload, isNot(contains(_rawSentinel)));
  });

  testWidgets('production backend incoherent balances open no LPP review',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final image = File(
      '${Directory.systemTemp.path}/mint_lpp_incoherent_${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsBytesSync(const [1, 2, 3, 4]);
    addTearDown(() {
      if (image.existsSync()) image.deleteSync();
    });
    final harness = _productionScanHarness(
      pickFile: () async => PlatformFile(
        name: 'lpp.jpg',
        path: image.path,
        size: image.lengthSync(),
      ),
      readFileBytes: (_) async => Uint8List.fromList(const [1, 2, 3, 4]),
      requireConsent: (_, __) async => true,
      visionExtractor: ({
        required imageBase64,
        required documentType,
        canton,
        languageHint,
      }) async =>
          <String, dynamic>{
        'extractedFields': [
          for (final entry in const <String, double>{
            'avoirLppTotal': 100000,
            'avoirLppObligatoire': 60000,
            'avoirLppSurobligatoire': 39998,
          }.entries)
            <String, dynamic>{
              'fieldName': entry.key,
              'value': entry.value,
              'confidence': 'high',
              'sourceText': _rawSentinel,
            },
        ],
        'overallConfidence': 0.95,
      },
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const Key('production_lpp_review_destination')),
      findsNothing,
    );
    expect(find.text('Aucun champ reconnu automatiquement'), findsOneWidget);
  });

  testWidgets('production Plan Base and Bonus text opens no LPP review',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final textFile = File(
      '${Directory.systemTemp.path}/mint_lpp_plan_${DateTime.now().microsecondsSinceEpoch}.txt',
    )..writeAsStringSync('''
PLAN BASE ET BONUS — CERTIFICAT DE PRÉVOYANCE
Avoir de vieillesse total: CHF 125'000
Salaire assuré: CHF 92'000
''');
    addTearDown(() {
      if (textFile.existsSync()) textFile.deleteSync();
    });
    var pickerCalls = 0;
    final harness = _productionScanHarness(
      pickFile: () async {
        pickerCalls += 1;
        return PlatformFile(
          name: 'plan.txt',
          size: textFile.lengthSync(),
          bytes: Uint8List.fromList(textFile.readAsBytesSync()),
        );
      },
      requireConsent: (_, __) async => true,
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const Key('production_lpp_review_destination')),
      findsNothing,
    );
    expect(pickerCalls, 1);
    expect(find.byType(TextField), findsOneWidget);
  });

  for (final confidenceCase in <({
    String label,
    bool includeFieldConfidence,
    Object? fieldConfidence,
    bool includeOverallConfidence,
    Object? overallConfidence,
  })>[
    (
      label: 'missing field confidence',
      includeFieldConfidence: false,
      fieldConfidence: null,
      includeOverallConfidence: true,
      overallConfidence: 0.95,
    ),
    (
      label: 'invalid field confidence',
      includeFieldConfidence: true,
      fieldConfidence: 'certain',
      includeOverallConfidence: true,
      overallConfidence: 0.95,
    ),
    (
      label: 'missing overall confidence',
      includeFieldConfidence: true,
      fieldConfidence: 'high',
      includeOverallConfidence: false,
      overallConfidence: null,
    ),
    (
      label: 'invalid overall confidence',
      includeFieldConfidence: true,
      fieldConfidence: 'high',
      includeOverallConfidence: true,
      overallConfidence: 1.01,
    ),
  ]) {
    testWidgets('selected LPP rejects ${confidenceCase.label}', (tester) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final image = File(
        '${Directory.systemTemp.path}/mint_lpp_confidence_${DateTime.now().microsecondsSinceEpoch}.jpg',
      )..writeAsBytesSync(const [1, 2, 3, 4]);
      addTearDown(() {
        if (image.existsSync()) image.deleteSync();
      });
      final harness = _productionScanHarness(
        pickFile: () async => PlatformFile(
          name: 'lpp.jpg',
          path: image.path,
          size: image.lengthSync(),
        ),
        readFileBytes: (_) async => Uint8List.fromList(const [1, 2, 3, 4]),
        requireConsent: (_, __) async => true,
        visionExtractor: ({
          required imageBase64,
          required documentType,
          canton,
          languageHint,
        }) async =>
            <String, dynamic>{
          'extractedFields': [
            <String, dynamic>{
              'fieldName': 'avoirLppTotal',
              'value': 125000.0,
              if (confidenceCase.includeFieldConfidence)
                'confidence': confidenceCase.fieldConfidence,
              'sourceText': _rawSentinel,
            },
          ],
          if (confidenceCase.includeOverallConfidence)
            'overallConfidence': confidenceCase.overallConfidence,
        },
      );
      addTearDown(harness.router.dispose);

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byKey(const Key('production_lpp_review_destination')),
        findsNothing,
      );
    });
  }

  testWidgets('non-LPP Vision keeps legacy missing-confidence fallbacks',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final image = File(
      '${Directory.systemTemp.path}/mint_avs_confidence_${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsBytesSync(const [1, 2, 3, 4]);
    addTearDown(() {
      if (image.existsSync()) image.deleteSync();
    });
    final harness = _productionScanHarness(
      initialType: DocumentType.avsExtract,
      pickFile: () async => PlatformFile(
        name: 'avs.jpg',
        path: image.path,
        size: image.lengthSync(),
      ),
      readFileBytes: (_) async => Uint8List.fromList(const [1, 2, 3, 4]),
      requireConsent: (_, __) async => true,
      visionExtractor: ({
        required imageBase64,
        required documentType,
        canton,
        languageHint,
      }) async =>
          <String, dynamic>{
        'extractedFields': [
          <String, dynamic>{
            'fieldName': 'avsAnnualIncome',
            'value': 92000.0,
            'sourceText': _rawSentinel,
          },
        ],
      },
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const Key('production_lpp_review_destination')),
      findsOneWidget,
    );
  });

  testWidgets('LPP image 422 uses personal-certificate recovery wording',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final image = File(
      '${Directory.systemTemp.path}/mint_lpp_kind_${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsBytesSync(const [1, 2, 3, 4]);
    addTearDown(() {
      if (image.existsSync()) image.deleteSync();
    });
    final harness = _productionScanHarness(
      pickFile: () async => PlatformFile(
        name: 'lpp.jpg',
        path: image.path,
        size: image.lengthSync(),
      ),
      readFileBytes: (_) async => Uint8List.fromList(const [1, 2, 3, 4]),
      requireConsent: (_, __) async => true,
      visionExtractor: ({
        required imageBase64,
        required documentType,
        canton,
        languageHint,
      }) async =>
          throw const DocumentServiceException(
        code: 'not_financial',
        message: 'synthetic kind rejection',
      ),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text(
        'Ce document n’a pas pu être vérifié comme ton certificat LPP personnel.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Utilise ton certificat individuel de prévoyance.'),
      findsOneWidget,
    );
    expect(
      find.text('Ce document ne semble pas être un document financier suisse.'),
      findsNothing,
    );
    expect(
      find.byKey(const Key('production_lpp_review_destination')),
      findsNothing,
    );
  });

  testWidgets('non-LPP image 422 keeps the financial-document wording',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final image = File(
      '${Directory.systemTemp.path}/mint_avs_kind_${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsBytesSync(const [1, 2, 3, 4]);
    addTearDown(() {
      if (image.existsSync()) image.deleteSync();
    });
    final harness = _productionScanHarness(
      initialType: DocumentType.avsExtract,
      pickFile: () async => PlatformFile(
        name: 'avs.jpg',
        path: image.path,
        size: image.lengthSync(),
      ),
      readFileBytes: (_) async => Uint8List.fromList(const [1, 2, 3, 4]),
      requireConsent: (_, __) async => true,
      visionExtractor: ({
        required imageBase64,
        required documentType,
        canton,
        languageHint,
      }) async =>
          throw const DocumentServiceException(
        code: 'not_financial',
        message: 'synthetic kind rejection',
      ),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Ce document ne semble pas être un document financier suisse.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Ce document n’a pas pu être vérifié comme ton certificat LPP personnel.',
      ),
      findsNothing,
    );
  });

  testWidgets('LPP PDF 422 keeps the same neutral recovery wording',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pdf = File(
      '${Directory.systemTemp.path}/mint_lpp_kind_${DateTime.now().microsecondsSinceEpoch}.pdf',
    )..writeAsBytesSync(const [37, 80, 68, 70]);
    addTearDown(() {
      if (pdf.existsSync()) pdf.deleteSync();
    });
    final harness = _productionScanHarness(
      pickFile: () async => PlatformFile(
        name: 'lpp.pdf',
        path: pdf.path,
        size: pdf.lengthSync(),
      ),
      readFileBytes: (_) async => Uint8List.fromList(const [37, 80, 68, 70]),
      requireConsent: (_, __) async => true,
      visionExtractor: ({
        required imageBase64,
        required documentType,
        canton,
        languageHint,
      }) async =>
          throw const DocumentServiceException(
        code: 'not_financial',
        message: 'synthetic kind rejection',
      ),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text(
        'Ce document n’a pas pu être vérifié comme ton certificat LPP personnel.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Utilise ton certificat individuel de prévoyance.'),
      findsOneWidget,
    );
    expect(find.text('Analyse PDF indisponible'), findsNothing);
    expect(
      find.byKey(const Key('production_lpp_review_destination')),
      findsNothing,
    );
  });

  testWidgets('LPP PDF retry clears stale 422 before generic recovery',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pdf = File(
      '${Directory.systemTemp.path}/mint_lpp_retry_${DateTime.now().microsecondsSinceEpoch}.pdf',
    )..writeAsBytesSync(const [37, 80, 68, 70]);
    addTearDown(() {
      if (pdf.existsSync()) pdf.deleteSync();
    });
    var visionCalls = 0;
    final harness = _productionScanHarness(
      pickFile: () async => PlatformFile(
        name: 'lpp.pdf',
        path: pdf.path,
        size: pdf.lengthSync(),
      ),
      readFileBytes: (_) async => Uint8List.fromList(const [37, 80, 68, 70]),
      requireConsent: (_, __) async => true,
      visionExtractor: ({
        required imageBase64,
        required documentType,
        canton,
        languageHint,
      }) async {
        visionCalls += 1;
        if (visionCalls == 1) {
          throw const DocumentServiceException(
            code: 'not_financial',
            message: 'synthetic first-attempt kind rejection',
          );
        }
        return null;
      },
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text(
        'Ce document n’a pas pu être vérifié comme ton certificat LPP personnel.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
    await tester.pump(const Duration(seconds: 1));

    expect(visionCalls, 2);
    expect(find.text('Analyse PDF indisponible'), findsOneWidget);
    expect(
      find.text(
        'Ce document n’a pas pu être vérifié comme ton certificat LPP personnel.',
      ),
      findsNothing,
    );
  });

  testWidgets('enabled LPP PDF skips persistent upload and uses Vision only',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pdf = File(
      '${Directory.systemTemp.path}/mint_lpp_candidate_${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    pdf.writeAsBytesSync(const [37, 80, 68, 70]);
    addTearDown(() {
      if (pdf.existsSync()) pdf.deleteSync();
    });
    var uploadCalls = 0;
    var visionCalls = 0;
    final harness = _productionScanHarness(
      pickFile: () async => PlatformFile(
        name: 'lpp.pdf',
        path: pdf.path,
        size: pdf.lengthSync(),
      ),
      readFileBytes: (_) async => Uint8List.fromList(const [37, 80, 68, 70]),
      requireConsent: (_, __) async => true,
      uploadDocument: (file, {required type}) async {
        uploadCalls += 1;
        throw StateError('persistent upload must be unreachable for LPP');
      },
      visionExtractor: ({
        required imageBase64,
        required documentType,
        canton,
        languageHint,
      }) async {
        visionCalls += 1;
        return {
          'extractedFields': [
            {
              'fieldName': 'avoirLppTotal',
              'value': 125000.0,
              'confidence': 'high',
            },
          ],
          'overallConfidence': 0.95,
        };
      },
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(uploadCalls, 0);
    expect(visionCalls, 1);
    expect(
      find.byKey(const Key('production_lpp_review_destination')),
      findsOneWidget,
    );
  });

  testWidgets('non-LPP gallery keeps persistence consent', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final image = File(
      '${Directory.systemTemp.path}/mint_avs_vision_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    image.writeAsBytesSync(const [1, 2, 3, 4]);
    addTearDown(() {
      if (image.existsSync()) image.deleteSync();
    });
    List<ConsentPurpose>? requestedPurposes;
    final harness = _productionScanHarness(
      initialType: DocumentType.avsExtract,
      pickFile: () async => PlatformFile(
        name: 'avs.jpg',
        path: image.path,
        size: image.lengthSync(),
      ),
      requireConsent: (_, purposes) async {
        requestedPurposes = List.of(purposes);
        return false;
      },
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document_scan_gallery_cta')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(requestedPurposes, contains(ConsentPurpose.persistence365d));
  });

  testWidgets('stale LPP review is recoverable and exposes no writer CTA',
      (tester) async {
    final harness = _reviewHarness(extraction: _lppExtraction());
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('lpp_review_disabled_recovery')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('lpp_review_confirm_cta')), findsNothing);
    await tester.tap(find.byKey(const Key('lpp_review_recovery_cta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lpp_recovery_destination')), findsOneWidget);
    expect(harness.scanSessions.byId(harness.scanSessionId), isNull);
    expect(harness.persistence.saveCalls, 0);
    expect(harness.coach.acceptLppReviewCalls, 0);
    expect(harness.biography.addFactCalls, 0);
    expect(harness.externalSync.calls, 0);
  });

  testWidgets('pre-confirmation LPP review keeps honest 71% confidence',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(
      extraction: _lppExtraction(
        fields: const [
          ExtractedField(
            fieldName: 'lpp_total',
            label: 'raw-label',
            value: 125000.0,
            confidence: 0.71,
            sourceText: _rawSentinel,
            needsReview: true,
          ),
        ],
      ),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(find.text('71%'), findsWidgets);
    expect(find.text('100%'), findsNothing);
    expect(find.textContaining(_rawSentinel), findsNothing);
  });

  testWidgets(
      'pre-confirmation review keeps lower source overall and explicit review flag',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(
      extraction: const ExtractionResult(
        documentType: DocumentType.lppCertificate,
        fields: [
          ExtractedField(
            fieldName: 'lpp_total',
            label: 'raw-label',
            value: 125000.0,
            confidence: 0.99,
            sourceText: _rawSentinel,
            needsReview: true,
          ),
        ],
        overallConfidence: 0.61,
        confidenceDelta: 27,
        warnings: [_rawSentinel],
        disclaimer: _rawSentinel,
        sources: [_rawSentinel],
      ),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    final overall = find.textContaining('Confiance extraction');
    expect(overall, findsOneWidget);
    expect(tester.widget<Text>(overall).data, contains('61'));
    expect(find.textContaining('1 à vérifier'), findsOneWidget);
    expect(find.textContaining('99%'), findsWidgets);
    expect(find.textContaining(_rawSentinel), findsNothing);
  });

  testWidgets(
      'self review maps every canonical fact once, converts percentages once, and keeps zero',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final extraction = _lppExtraction(fields: const [
      ExtractedField(
          fieldName: 'lpp_total',
          label: 'x',
          value: 125000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
      ExtractedField(
          fieldName: 'lpp_obligatoire',
          label: 'x',
          value: 75000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
      ExtractedField(
          fieldName: 'lpp_surobligatoire',
          label: 'x',
          value: 50000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
      ExtractedField(
          fieldName: 'lpp_insured_salary',
          label: 'x',
          value: 92000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
      ExtractedField(
          fieldName: 'buyback_potential',
          label: 'x',
          value: 0.0,
          confidence: 1,
          sourceText: '$_rawSentinel Rachat possible: CHF 0.00',
          needsReview: false),
      ExtractedField(
          fieldName: 'conversion_rate_oblig',
          label: 'x',
          value: 6.8,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
      ExtractedField(
          fieldName: 'conversion_rate_suroblig',
          label: 'x',
          value: 5.1,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
      ExtractedField(
          fieldName: 'remuneration_rate',
          label: 'x',
          value: 1.25,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
      ExtractedField(
          fieldName: 'projected_rente',
          label: 'x',
          value: 31450.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
      ExtractedField(
          fieldName: 'projected_capital_65',
          label: 'x',
          value: 480000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
      ExtractedField(
          fieldName: 'disability_coverage',
          label: 'x',
          value: 26000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
      ExtractedField(
          fieldName: 'disability_capital',
          label: 'x',
          value: 175000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
      ExtractedField(
          fieldName: 'death_coverage',
          label: 'x',
          value: 210000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
      ExtractedField(
          fieldName: 'unknown_ambiguous_benefit',
          label: 'x',
          value: 999999.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false),
    ]);
    final harness = _reviewHarness(
      extraction: extraction,
      sourceDate: DateTime.utc(2026, 6, 30),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _tapConfirmAndChoose(tester, manualPartner: false);

    expect(harness.persistence.saveCalls, 1);
    expect(harness.coach.acceptLppReviewCalls, 1);
    final root = _strictRoot(harness.persistence);
    final facts = Map<String, dynamic>.from(root['self']['facts'] as Map);
    expect(facts.length, 13);
    expect(facts['vestedBenefitsCapitalChf']['value'], 125000.0);
    expect(facts['maximumBuybackCapitalChf']['value'], 0.0);
    expect(
        facts['mandatoryConversionRateRatio']['value'], closeTo(0.068, 1e-12));
    expect(facts['extraMandatoryConversionRateRatio']['value'],
        closeTo(0.051, 1e-12));
    expect(facts['fundReturnRateRatio']['value'], closeTo(0.0125, 1e-12));
    expect(facts['retirementPensionAnnualChf']['unit'], 'CHF/year');
    expect(facts['retirementCapitalLumpSumChf']['unit'], 'CHF/lump-sum');
    expect(facts['disabilityPensionAnnualChf']['unit'], 'CHF/year');
    expect(facts['disabilityCapitalLumpSumChf']['unit'], 'CHF/lump-sum');
    expect(facts['deathCapitalLumpSumChf']['unit'], 'CHF/lump-sum');
    expect(
        facts.values
            .every((fact) => fact['provenance']['source'] == 'certificate'),
        isTrue);
    expect(
        facts.values
            .every((fact) => fact['provenance']['sourceDate'] == '2026-06-30'),
        isTrue);
    expect(
        jsonEncode(harness.persistence.answers), isNot(contains(_rawSentinel)));
    expect(
      jsonEncode(ReportPersistenceService.backendSafeAnswers(
          harness.persistence.answers)),
      isNot(contains(_rawSentinel)),
    );
    expect(harness.biography.addFactCalls, 0);
    expect(harness.externalSync.calls, 0);
    final retained = harness.scanSessions.byId(harness.scanSessionId)!;
    expect(retained.lppCandidate, isNull);
    expect(
        retained.extraction.fields.every((f) => f.sourceText.isEmpty), isTrue);
    expect(retained.extraction.diagnostics, isEmpty);
    expect(retained.extraction.warnings, isEmpty);
    expect(retained.extraction.disclaimer, isEmpty);
    expect(retained.extraction.sources, isEmpty);
    expect(
      retained.extraction.fields
          .map((f) => '${f.fieldName}|${f.label}|${f.sourceText}')
          .join('|'),
      isNot(contains(_rawSentinel)),
    );
    expect(find.byKey(const Key('lpp_impact_destination')), findsOneWidget);
  });

  testWidgets(
      'edited manual-partner fact becomes userInput with null sourceDate',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(
      extraction: _lppExtraction(),
      sourceDate: DateTime.utc(2026, 6, 30),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      const Key('lpp_review_field_edit_vestedBenefitsCapitalChf'),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '126000',
    );
    await tester.tap(find.byKey(const Key('lpp_review_edit_validate')));
    await tester.pumpAndSettle();
    await _tapConfirmAndChoose(tester, manualPartner: true);

    expect(harness.persistence.saveCalls, 1);
    expect(harness.coach.acceptLppReviewCalls, 1);
    final root = _strictRoot(harness.persistence);
    expect(root['self'], isNull);
    final fact = root['manualPartner']['facts']['vestedBenefitsCapitalChf'];
    expect(fact['value'], 126000.0);
    expect(fact['owner']['kind'], 'manualPartner');
    expect(fact['authorization'],
        {'mode': 'manualPartnerDeclaration', 'grantId': null});
    expect(fact['provenance']['source'], 'userInput');
    expect(fact['provenance']['sourceDate'], isNull);
    expect(harness.biography.addFactCalls, 0);
    expect(harness.externalSync.calls, 0);
  });

  testWidgets(
      'edited incoherent LPP balances fail recoverably before owner or save',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(
      extraction: _lppExtraction(fields: const [
        ExtractedField(
          fieldName: 'lpp_total',
          label: 'total',
          value: 125000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false,
        ),
        ExtractedField(
          fieldName: 'lpp_obligatoire',
          label: 'mandatory',
          value: 75000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false,
        ),
        ExtractedField(
          fieldName: 'lpp_surobligatoire',
          label: 'extra',
          value: 50000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false,
        ),
      ]),
      sourceDate: DateTime.utc(2026, 6, 30),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      const Key('lpp_review_field_edit_vestedBenefitsCapitalChf'),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '70000',
    );
    await tester.tap(find.byKey(const Key('lpp_review_edit_validate')));
    await tester.pumpAndSettle();

    final confirm = find.byKey(const Key('lpp_review_confirm_cta'));
    await tester.scrollUntilVisible(
      confirm,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lpp_review_balance_error')), findsOneWidget);
    expect(find.text(S.of(tester.element(confirm))!.lppReviewBalanceIncoherent),
        findsOneWidget);
    expect(find.byKey(const Key('lpp_review_subject_self')), findsNothing);
    expect(harness.persistence.saveCalls, 0);
    expect(harness.coach.acceptLppReviewCalls, 0);
    expect(find.byKey(const Key('lpp_impact_destination')), findsNothing);

    final correctionEdit = find.byKey(
      const Key('lpp_review_field_edit_vestedBenefitsCapitalChf'),
    );
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    await tester.tap(correctionEdit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '125000',
    );
    await tester.tap(find.byKey(const Key('lpp_review_edit_validate')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lpp_review_balance_error')), findsNothing);
    await _tapConfirmAndChoose(tester, manualPartner: false);
    expect(harness.persistence.saveCalls, 1);
    expect(harness.coach.acceptLppReviewCalls, 1);
    expect(find.byKey(const Key('lpp_impact_destination')), findsOneWidget);
  });

  testWidgets('untouched LPP fact without effective date performs no write',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(extraction: _lppExtraction());
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('lpp_review_confirm_cta'));
    await tester.scrollUntilVisible(
      confirm,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lpp_review_source_date')), findsOneWidget);
    expect(
        find.byKey(const Key('lpp_review_source_date_error')), findsOneWidget);
    expect(find.byKey(const Key('lpp_review_subject_self')), findsNothing);
    expect(harness.persistence.saveCalls, 0);
    expect(harness.coach.acceptLppReviewCalls, 0);
    expect(find.byKey(const Key('lpp_impact_destination')), findsNothing);
  });

  testWidgets('entered effective date persists untouched fact as certificate',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(extraction: _lppExtraction());
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _enterLppSourceDate(tester, '2026-06-30');
    await _tapConfirmAndChoose(tester, manualPartner: false);

    expect(harness.persistence.saveCalls, 1);
    final fact = _strictRoot(harness.persistence)['self']['facts']
        ['vestedBenefitsCapitalChf'];
    expect(fact['provenance']['source'], 'certificate');
    expect(fact['provenance']['sourceDate'], '2026-06-30');
    expect(find.byKey(const Key('lpp_impact_destination')), findsOneWidget);
  });

  testWidgets(
      'mixed corrected and untouched facts date only certificate provenance',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(
      extraction: _lppExtraction(fields: const [
        ExtractedField(
          fieldName: 'lpp_total',
          label: 'total',
          value: 125000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false,
        ),
        ExtractedField(
          fieldName: 'lpp_obligatoire',
          label: 'mandatory',
          value: 75000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false,
        ),
      ]),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      const Key('lpp_review_field_edit_vestedBenefitsCapitalChf'),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '126000',
    );
    await tester.tap(find.byKey(const Key('lpp_review_edit_validate')));
    await tester.pumpAndSettle();
    await _enterLppSourceDate(tester, '2026-06-30');
    await _tapConfirmAndChoose(tester, manualPartner: false);

    final facts = _strictRoot(harness.persistence)['self']['facts'];
    expect(
        facts['vestedBenefitsCapitalChf']['provenance']['source'], 'userInput');
    expect(
        facts['vestedBenefitsCapitalChf']['provenance']['sourceDate'], isNull);
    expect(
      facts['mandatoryVestedBenefitsCapitalChf']['provenance']['source'],
      'certificate',
    );
    expect(
      facts['mandatoryVestedBenefitsCapitalChf']['provenance']['sourceDate'],
      '2026-06-30',
    );
  });

  testWidgets('future LPP effective date performs no write', (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(extraction: _lppExtraction());
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _enterLppSourceDate(tester, '2099-01-01');
    final confirm = find.byKey(const Key('lpp_review_confirm_cta'));
    await tester.scrollUntilVisible(
      confirm,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('lpp_review_source_date_error')), findsOneWidget);
    expect(find.byKey(const Key('lpp_review_subject_self')), findsNothing);
    expect(harness.persistence.saveCalls, 0);
    expect(harness.coach.acceptLppReviewCalls, 0);
    expect(find.byKey(const Key('lpp_impact_destination')), findsNothing);
  });

  testWidgets(
      'validating an unchanged fact keeps certificate provenance and date',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final sourceDate = DateTime.utc(2026, 6, 30);
    final harness = _reviewHarness(
      extraction: _lppExtraction(),
      sourceDate: sourceDate,
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      const Key('lpp_review_field_edit_vestedBenefitsCapitalChf'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lpp_review_edit_validate')));
    await tester.pumpAndSettle();
    await _tapConfirmAndChoose(tester, manualPartner: false);

    expect(harness.persistence.saveCalls, 1);
    expect(harness.coach.acceptLppReviewCalls, 1);
    final fact = _strictRoot(harness.persistence)['self']['facts']
        ['vestedBenefitsCapitalChf'];
    expect(fact['value'], 125000.0);
    expect(fact['provenance']['source'], 'certificate');
    expect(fact['provenance']['sourceDate'], '2026-06-30');
  });

  testWidgets('uncorrected parser-derived LPP fact is rejected',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(
      extraction: _lppExtraction(fields: const [
        ExtractedField(
          fieldName: 'lpp_surobligatoire',
          label: 'Part surobligatoire (déduit)',
          value: 25000.0,
          confidence: 0.70,
          sourceText: 'Calculé: total - obligatoire',
          needsReview: true,
        ),
      ]),
      sourceDate: DateTime.utc(2026, 6, 30),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _tapConfirmAndChoose(tester, manualPartner: false);

    expect(harness.persistence.saveCalls, 0);
    expect(harness.coach.acceptLppReviewCalls, 0);
    expect(find.byKey(const Key('lpp_review_confirm_cta')), findsOneWidget);
    expect(find.byKey(const Key('lpp_impact_destination')), findsNothing);
  });

  testWidgets('corrected parser-derived LPP fact persists only as userInput',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(
      extraction: _lppExtraction(fields: const [
        ExtractedField(
          fieldName: 'lpp_surobligatoire',
          label: 'Part surobligatoire (déduit)',
          value: 25000.0,
          confidence: 0.70,
          sourceText: 'Calculé: total - obligatoire',
          needsReview: true,
        ),
      ]),
      sourceDate: DateTime.utc(2026, 6, 30),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key(
        'lpp_review_field_edit_extraMandatoryVestedBenefitsCapitalChf',
      )),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '26000',
    );
    await tester.tap(find.byKey(const Key('lpp_review_edit_validate')));
    await tester.pumpAndSettle();
    await _tapConfirmAndChoose(tester, manualPartner: false);

    expect(harness.persistence.saveCalls, 1);
    expect(harness.coach.acceptLppReviewCalls, 1);
    final fact = _strictRoot(harness.persistence)['self']['facts']
        ['extraMandatoryVestedBenefitsCapitalChf'];
    expect(fact['value'], 26000.0);
    expect(fact['provenance']['source'], 'userInput');
    expect(fact['provenance']['sourceDate'], isNull);
  });

  testWidgets('conflicting duplicate canonical facts fail closed',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(
      extraction: _lppExtraction(fields: const [
        ExtractedField(
          fieldName: 'lpp_total',
          label: 'first',
          value: 125000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false,
        ),
        ExtractedField(
          fieldName: 'lpp_total',
          label: 'conflicting duplicate',
          value: 126000.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false,
        ),
      ]),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(harness.persistence.saveCalls, 0);
    expect(harness.coach.acceptLppReviewCalls, 0);
    expect(
      find.byKey(const Key('lpp_review_missing_candidate_recovery')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('lpp_review_confirm_cta')), findsNothing);
    expect(find.byKey(const Key('lpp_impact_destination')), findsNothing);
  });

  testWidgets('unit-invalid canonical fact fails closed', (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(
      extraction: _lppExtraction(fields: const [
        ExtractedField(
          fieldName: 'conversion_rate_oblig',
          label: 'invalid percent unit',
          value: 101.0,
          confidence: 1,
          sourceText: _rawSentinel,
          needsReview: false,
        ),
      ]),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(harness.persistence.saveCalls, 0);
    expect(harness.coach.acceptLppReviewCalls, 0);
    expect(
      find.byKey(const Key('lpp_review_missing_candidate_recovery')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('lpp_review_confirm_cta')), findsNothing);
  });

  testWidgets('LPP impact never crosses generic backend or event boundaries',
      (tester) async {
    var fetchCalls = 0;
    var eventCalls = 0;
    final sessions = ScanSessionProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<ScanSessionProvider>.value(
        value: sessions,
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: DocumentImpactScreen(
            scanSessionId: 'stale-lpp-impact',
            result: _lppExtraction(),
            previousConfidence: 42,
            fetchPremierEclairage: ({
              required documentType,
              required extractedFields,
              required overallConfidence,
              planType,
              planTypeWarning,
              canton,
            }) async {
              fetchCalls += 1;
              return const <String, dynamic>{};
            },
            saveScanEvent: (topic, summary) async {
              eventCalls += 1;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(fetchCalls, 0);
    expect(eventCalls, 0);
  });

  testWidgets('ownership cancel performs no write and re-enables confirmation',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(
      extraction: _lppExtraction(),
      sourceDate: DateTime.utc(2026, 6, 30),
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('lpp_review_confirm_cta'));
    await tester.scrollUntilVisible(
      confirm,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lpp_review_subject_cancel')));
    await tester.pumpAndSettle();

    expect(harness.persistence.saveCalls, 0);
    expect(harness.coach.acceptLppReviewCalls, 0);
    expect(find.byKey(const Key('lpp_impact_destination')), findsNothing);
    final button = tester.widget<FilledButton>(confirm);
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
      'real LPP impact renders canonical ratio once and semantic benefit labels',
      (tester) async {
    var fetchCalls = 0;
    var eventCalls = 0;
    final sessions = ScanSessionProvider();
    const result = ExtractionResult(
      documentType: DocumentType.lppCertificate,
      fields: [
        ExtractedField(
          fieldName: 'mandatoryConversionRateRatio',
          label: 'mandatoryConversionRateRatio',
          value: 0.068,
          confidence: 1,
          sourceText: '',
          needsReview: false,
        ),
        ExtractedField(
          fieldName: 'retirementPensionAnnualChf',
          label: 'retirementPensionAnnualChf',
          value: 31450.0,
          confidence: 1,
          sourceText: '',
          needsReview: false,
        ),
        ExtractedField(
          fieldName: 'retirementCapitalLumpSumChf',
          label: 'retirementCapitalLumpSumChf',
          value: 480000.0,
          confidence: 1,
          sourceText: '',
          needsReview: false,
        ),
        ExtractedField(
          fieldName: 'disabilityPensionAnnualChf',
          label: 'disabilityPensionAnnualChf',
          value: 26000.0,
          confidence: 1,
          sourceText: '',
          needsReview: false,
        ),
        ExtractedField(
          fieldName: 'disabilityCapitalLumpSumChf',
          label: 'disabilityCapitalLumpSumChf',
          value: 175000.0,
          confidence: 1,
          sourceText: '',
          needsReview: false,
        ),
        ExtractedField(
          fieldName: 'deathCapitalLumpSumChf',
          label: 'deathCapitalLumpSumChf',
          value: 210000.0,
          confidence: 1,
          sourceText: '',
          needsReview: false,
        ),
      ],
      overallConfidence: 1,
      confidenceDelta: 0,
      warnings: [],
      disclaimer: '',
      sources: [],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ScanSessionProvider>.value(
        value: sessions,
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: DocumentImpactScreen(
            scanSessionId: 'typed-lpp-impact',
            result: result,
            previousConfidence: 42,
            fetchPremierEclairage: ({
              required documentType,
              required extractedFields,
              required overallConfidence,
              planType,
              planTypeWarning,
              canton,
            }) async {
              fetchCalls += 1;
              return const <String, dynamic>{};
            },
            saveScanEvent: (topic, summary) async {
              eventCalls += 1;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('6.8%'), findsWidgets);
    expect(find.text('0.1%'), findsNothing);
    expect(find.text('Rente de retraite annuelle'), findsWidgets);
    expect(find.text('Capital retraite versé en une fois'), findsWidgets);
    expect(find.text("Rente d'invalidité annuelle"), findsWidgets);
    expect(find.text("Capital d'invalidité versé en une fois"), findsWidgets);
    expect(find.text('Capital-décès'), findsWidgets);
    expect(fetchCalls, 0);
    expect(eventCalls, 0);
  });

  testWidgets('strict save failure stays on review with no fallback or success',
      (tester) async {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    final harness = _reviewHarness(
      extraction: _lppExtraction(),
      sourceDate: DateTime.utc(2026, 6, 30),
      failSave: true,
    );
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _tapConfirmAndChoose(tester, manualPartner: false);

    expect(harness.persistence.saveCalls, 1);
    expect(harness.coach.acceptLppReviewCalls, 1);
    expect(harness.persistence.answers, isEmpty);
    expect(find.byKey(const Key('lpp_review_confirm_cta')), findsOneWidget);
    expect(find.byKey(const Key('lpp_impact_destination')), findsNothing);
    expect(harness.biography.addFactCalls, 0);
    expect(harness.externalSync.calls, 0);
  });
}
