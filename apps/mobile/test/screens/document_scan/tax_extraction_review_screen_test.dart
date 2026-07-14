import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/screens/document_scan/document_impact_screen.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';

class _CoachProfileSpy extends CoachProfileProvider {
  _CoachProfileSpy({List<Future<void> Function()>? acceptBehaviors})
      : acceptBehaviors = acceptBehaviors ?? [];

  int acceptTaxReviewCalls = 0;
  TaxReviewConfirmation? acceptedConfirmation;
  final List<Future<void> Function()> acceptBehaviors;

  @override
  Future<void> acceptTaxReview(TaxReviewConfirmation confirmation) async {
    acceptTaxReviewCalls += 1;
    acceptedConfirmation = confirmation;
    final behaviorIndex = acceptTaxReviewCalls - 1;
    if (behaviorIndex < acceptBehaviors.length) {
      await acceptBehaviors[behaviorIndex]();
    }
  }
}

class _BiographySpy extends BiographyProvider {
  int addFactCalls = 0;

  @override
  Future<void> addFact(BiographyFact fact) async {
    addFactCalls += 1;
  }
}

class _ExternalSyncSpy {
  int calls = 0;

  Future<void> call({
    required String documentType,
    required List<Map<String, dynamic>> confirmedFields,
    required double overallConfidence,
  }) async {
    calls += 1;
  }
}

class _PremierEclairageSpy {
  int calls = 0;
  List<Map<String, dynamic>>? extractedFields;

  Future<Map<String, dynamic>?> call({
    required String documentType,
    required List<Map<String, dynamic>> extractedFields,
    required double overallConfidence,
    String? planType,
    String? planTypeWarning,
    String? canton,
  }) async {
    calls += 1;
    this.extractedFields = extractedFields;
    return const {'humanTranslation': 'REMOTE-INSIGHT-MUST-NOT-RUN'};
  }
}

class _ScanEventSpy {
  int calls = 0;

  Future<void> call(String topic, String summary) async {
    calls += 1;
  }
}

class _NetworkBoundarySpy extends HttpOverrides {
  int createClientCalls = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    createClientCalls += 1;
    throw StateError('Tax acquisition crossed the network boundary');
  }
}

class _MemoryTaxPersistence implements TaxProfilePersistence {
  _MemoryTaxPersistence(Map<String, dynamic> initial, {this.events})
      : answers = _copy(initial);

  Map<String, dynamic> answers;
  int saveCalls = 0;
  final List<String>? events;

  @override
  Future<Map<String, dynamic>> loadAnswers() async => _copy(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveCalls += 1;
    events?.add('save');
    answers = _copy(next);
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}

class _ScoreSpy {
  _ScoreSpy(this.values, this.events);

  final List<int> values;
  final List<String> events;
  int calls = 0;

  int call(CoachProfile profile) {
    final value = values[calls++];
    events.add('score:$value');
    return value;
  }
}

class _ScanSessionSpy extends ScanSessionProvider {
  int retainExtractionCalls = 0;
  int notifyCalls = 0;

  @override
  String retainExtraction(
    ExtractionResult extraction, {
    TaxExtractionCandidate? taxCandidate,
  }) {
    retainExtractionCalls += 1;
    return super.retainExtraction(
      extraction,
      taxCandidate: taxCandidate,
    );
  }

  @override
  void notifyListeners() {
    notifyCalls += 1;
    super.notifyListeners();
  }
}

ExtractionResult _taxExtraction() => const ExtractionResult(
      documentType: DocumentType.taxDeclaration,
      fields: [
        ExtractedField(
          fieldName: 'revenu_imposable',
          label: 'Revenu imposable à vérifier',
          value: 98000.0,
          confidence: 0.91,
          sourceText: 'PII-NEVER-SEND',
          needsReview: false,
          profileField: '_coach_tax_taux_marginal',
        ),
      ],
      overallConfidence: 0.91,
      confidenceDelta: 0,
      warnings: [],
      disclaimer: 'Fixture synthétique.',
      sources: [],
    );

TaxExtractionCandidate _candidate(ExtractionResult extraction) =>
    TaxExtractionCandidate.fromExtractionResult(
      extraction,
      snapshotIdFactory: () => _snapshotId,
    );

TaxExtractionCandidate _readyCandidate(
  ExtractionResult extraction, {
  int taxYear = 2025,
  DateTime? sourceDate,
}) =>
    TaxExtractionCandidate.fromExtractionResult(
      extraction,
      snapshotIdFactory: () => _snapshotId,
      documentKind: TaxDocumentKind.assessmentNotice,
      assessmentStatus: TaxAssessmentStatus.assessedAppealable,
      taxYear: taxYear,
      sourceDate: sourceDate ?? DateTime.utc(2026, 6, 20),
      subjectScope: TaxSubjectScope.individual,
      cantonCode: 'VD',
      municipalityId: '5586',
      municipalityLabel: 'Lausanne',
      cantonalCommunalTaxableIncomeChf: 98500,
      federalTaxableIncomeChf: 96200,
      cantonalCommunalTaxableWealthChf: 245000,
      cantonalCommunalAssessedTax: AssessedTaxAmount(
        amountChf: 14520,
        authorityScope: TaxAuthorityScope.cantonalCommunalCombined,
        baseScope: TaxBaseScope.incomeAndWealth,
      ),
      federalDirectAssessedTax: AssessedTaxAmount(
        amountChf: 3840,
        authorityScope: TaxAuthorityScope.federalDirect,
        baseScope: TaxBaseScope.incomeOnly,
      ),
      explicitMarginalIncomeTaxRate: 0.325,
      explicitAverageIncomeTaxRate: 0.223,
    );

TaxExtractionCandidate _provisionalCandidate(ExtractionResult extraction) =>
    TaxExtractionCandidate.fromExtractionResult(
      extraction,
      snapshotIdFactory: () => _snapshotId,
      documentKind: TaxDocumentKind.provisionalBill,
      assessmentStatus: TaxAssessmentStatus.provisional,
      taxYear: 2025,
      basedOnTaxYear: 2024,
      sourceDate: DateTime.utc(2026, 2, 5),
      subjectScope: TaxSubjectScope.individual,
      cantonCode: 'VD',
      federalDirectAssessedTax: AssessedTaxAmount(
        amountChf: 4200,
        authorityScope: TaxAuthorityScope.federalDirect,
        baseScope: TaxBaseScope.incomeOnly,
      ),
    );

TaxExtractionCandidate _averageOnlyCandidate(ExtractionResult extraction) =>
    TaxExtractionCandidate.fromExtractionResult(
      extraction,
      snapshotIdFactory: () => _snapshotId,
      documentKind: TaxDocumentKind.assessmentNotice,
      assessmentStatus: TaxAssessmentStatus.assessedAppealable,
      taxYear: 2025,
      sourceDate: DateTime.utc(2026, 6, 20),
      subjectScope: TaxSubjectScope.individual,
      cantonCode: 'VD',
      cantonalCommunalTaxableIncomeChf: 98500,
      explicitAverageIncomeTaxRate: 0.223,
    );

TaxExtractionCandidate _invalidFederalBaseCandidate(
  ExtractionResult extraction,
  TaxBaseScope baseScope,
) =>
    TaxExtractionCandidate.fromExtractionResult(
      extraction,
      snapshotIdFactory: () => _snapshotId,
      documentKind: TaxDocumentKind.assessmentNotice,
      assessmentStatus: TaxAssessmentStatus.assessedAppealable,
      taxYear: 2025,
      sourceDate: DateTime.utc(2026, 6, 20),
      subjectScope: TaxSubjectScope.individual,
      cantonCode: 'VD',
      federalDirectAssessedTax: AssessedTaxAmount(
        amountChf: 3840,
        authorityScope: TaxAuthorityScope.federalDirect,
        baseScope: baseScope,
      ),
    );

class _ReviewHarness {
  const _ReviewHarness({
    required this.widget,
    required this.scanSessionId,
    required this.scanSessions,
    required this.router,
    required this.screenConstructorError,
  });

  final Widget widget;
  final String scanSessionId;
  final ScanSessionProvider scanSessions;
  final GoRouter router;
  final Object? screenConstructorError;
}

class _CountingClock {
  _CountingClock(this.value);

  final DateTime value;
  int calls = 0;

  DateTime call() {
    calls += 1;
    return value;
  }
}

_ReviewHarness _harness({
  required ExtractionResult extraction,
  required TaxExtractionCandidate? candidate,
  required CoachProfileProvider coachProfile,
  required _BiographySpy biography,
  required _ExternalSyncSpy externalSync,
  int Function(CoachProfile)? confidenceScorer,
  DateTime Function()? now,
}) {
  final scanSessions = ScanSessionProvider();
  final scanSessionId = scanSessions.retainExtraction(
    extraction,
    taxCandidate: candidate,
  );
  const Object? screenConstructorError = null;
  final reviewScreen = ExtractionReviewScreen(
    scanSessionId: scanSessionId,
    result: extraction,
    taxCandidate: candidate,
    sendScanConfirmation: externalSync.call,
    confidenceScorer: confidenceScorer,
    now: now,
  );
  final router = GoRouter(
    initialLocation: '/review',
    routes: [
      GoRoute(
        path: '/review',
        builder: (_, __) => reviewScreen,
      ),
      GoRoute(
        path: '/scan/impact',
        builder: (_, __) => const Scaffold(body: Text('impact')),
      ),
    ],
  );

  return _ReviewHarness(
    scanSessionId: scanSessionId,
    scanSessions: scanSessions,
    router: router,
    screenConstructorError: screenConstructorError,
    widget: MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: coachProfile),
        ChangeNotifierProvider<BiographyProvider>.value(value: biography),
        ChangeNotifierProvider<ScanSessionProvider>.value(value: scanSessions),
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

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _choose(
  WidgetTester tester, {
  required String controlKey,
  required String optionKey,
}) async {
  await _tapKey(tester, controlKey);
  final option = find.byKey(Key(optionKey));
  expect(option, findsOneWidget);
  await tester.tap(option, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _enter(
  WidgetTester tester, {
  required String controlKey,
  required String value,
}) async {
  final finder = find.byKey(Key(controlKey));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

void _setView(WidgetTester tester, double height) {
  tester.view.physicalSize = Size(900, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    FeatureFlags.typedTaxProfile = false;
    FeatureFlags.documentTaxAssessmentEnabled = true;
  });

  tearDown(() {
    FeatureFlags.typedTaxProfile = false;
    FeatureFlags.documentTaxAssessmentEnabled = false;
  });

  testWidgets(
      'tax review localizes every typed diagnostic without exposing raw codes',
      (tester) async {
    _setView(tester, 2800);
    FeatureFlags.typedTaxProfile = true;
    const extraction = ExtractionResult(
      documentType: DocumentType.taxDeclaration,
      fields: [
        ExtractedField(
          fieldName: 'fortune_imposable',
          label: 'taxTaxableWealth',
          labelCode: ExtractionFieldLabelCode.taxTaxableWealth,
          value: -25000.0,
          confidence: 0.82,
          sourceText: 'PII-NEVER-RENDER',
          needsReview: false,
          profileField: 'actualTaxableWealth',
        ),
      ],
      overallConfidence: 0.82,
      confidenceDelta: 0,
      warnings: [],
      disclaimer: '',
      sources: [],
      diagnostics: [
        ExtractionDiagnostic.percentUnit(101),
        ExtractionDiagnostic.negativeWealth(-25000),
        ExtractionDiagnostic.averageNotMarginal(20),
      ],
    );
    final harness = _harness(
      extraction: extraction,
      candidate: _readyCandidate(extraction),
      coachProfile: _CoachProfileSpy(),
      biography: _BiographySpy(),
      externalSync: _ExternalSyncSpy(),
    );

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ExtractionReviewScreen));
    final l10n = S.of(context)!;
    expect(
      find.text(l10n.taxParserDiagnosticPercentUnit('101.0')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.taxParserDiagnosticNegativeWealth('-25000')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.taxParserDiagnosticAverageNotMarginal('20.0')),
      findsOneWidget,
    );
    expect(find.text(l10n.taxReviewLocalDisclaimer), findsOneWidget);
    expect(find.text(l10n.taxReviewCantonalWealth), findsOneWidget);
    for (final rawCode in [
      ...ExtractionDiagnosticCode.values.map((code) => code.name),
      ...ExtractionFieldLabelCode.values.map((code) => code.name),
    ]) {
      expect(find.text(rawCode), findsNothing, reason: rawCode);
    }
  });

  testWidgets(
      'production local tax example creates one stable candidate and routes only its session id without network',
      (tester) async {
    _setView(tester, 2200);
    FeatureFlags.typedTaxProfile = true;

    final network = _NetworkBoundarySpy();
    final sessions = _ScanSessionSpy();
    ScanSessionPayload? routedPayload;
    String? routedSessionId;
    Uri? routedUri;
    Set<String>? routedQueryKeys;
    Object? routedExtra;
    var snapshotIdFactoryCalls = 0;
    final router = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(
          path: '/scan',
          builder: (_, __) => DocumentScanScreen(
            initialType: DocumentType.taxDeclaration,
            taxSnapshotIdFactory: () {
              snapshotIdFactoryCalls += 1;
              return _snapshotId;
            },
          ),
        ),
        GoRoute(
          path: '/scan/review',
          builder: (_, state) {
            routedUri = state.uri;
            routedSessionId = state.uri.queryParameters['scanSessionId'];
            routedQueryKeys = state.uri.queryParameters.keys.toSet();
            routedExtra = state.extra;
            routedPayload = sessions.byId(routedSessionId);
            return const Scaffold(
              body: Text(
                'typed tax review route reached',
                key: Key('typed_tax_review_route_reached'),
              ),
            );
          },
        ),
      ],
    );

    await HttpOverrides.runZoned(
      () async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<CoachProfileProvider>(
                create: (_) => CoachProfileProvider(),
              ),
              ChangeNotifierProvider<ByokProvider>(
                create: (_) => ByokProvider(),
              ),
              ChangeNotifierProvider<ScanSessionProvider>.value(
                value: sessions,
              ),
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
        await tester.pumpAndSettle();

        final localExample = find.byKey(
          const Key('document_scan_tax_example_cta'),
        );
        expect(
          find.byKey(const Key('document_scan_tax_type_selector')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('document_scan_tax_type_selector'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('document_scan_tax_example_cta'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          localExample,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(localExample);
        await tester.pumpAndSettle();
      },
      createHttpClient: network.createHttpClient,
    );

    expect(
      find.byKey(const Key('typed_tax_review_route_reached')),
      findsOneWidget,
    );
    expect(routedSessionId, isNotNull);
    expect(routedQueryKeys, {'scanSessionId'});
    expect(routedExtra, isNull);
    expect(routedUri.toString(), isNot(contains('PII-NEVER-SEND')));
    expect(routedUri.toString(), isNot(contains(_snapshotId)));
    expect(routedPayload, isNotNull);
    expect(routedPayload!.extraction.documentType, DocumentType.taxDeclaration);
    final candidate = routedPayload!.taxCandidate;
    expect(candidate, isNotNull);
    expect(candidate!.extraction, same(routedPayload!.extraction));
    expect(candidate.snapshotId, matches(TaxSnapshot.uuidV4Pattern));
    expect(candidate.snapshotId, isNot(routedSessionId));
    expect(candidate.documentKind, TaxDocumentKind.assessmentNotice);
    expect(candidate.assessmentStatus, TaxAssessmentStatus.assessedAppealable);
    expect(candidate.taxYear, 2025);
    expect(candidate.sourceDate, isNull);
    expect(candidate.subjectScope, TaxSubjectScope.unknown);
    expect(candidate.municipalityLabel, 'Lausanne');
    expect(sessions.byId(routedSessionId)!.taxCandidate, same(candidate));
    expect(snapshotIdFactoryCalls, 1);
    expect(sessions.retainExtractionCalls, 1);
    expect(sessions.notifyCalls, 1);
    expect(network.createClientCalls, 0);
  });

  testWidgets(
      'typed-tax flag off hides tax acquisition before UUID session navigation or network',
      (tester) async {
    _setView(tester, 2200);

    final network = _NetworkBoundarySpy();
    final sessions = _ScanSessionSpy();
    var snapshotIdFactoryCalls = 0;
    var reviewBuildCalls = 0;
    final router = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(
          path: '/scan',
          builder: (_, __) => DocumentScanScreen(
            initialType: DocumentType.taxDeclaration,
            taxSnapshotIdFactory: () {
              snapshotIdFactoryCalls += 1;
              return _snapshotId;
            },
          ),
        ),
        GoRoute(
          path: '/scan/review',
          builder: (_, __) {
            reviewBuildCalls += 1;
            return const Scaffold(body: Text('forbidden review'));
          },
        ),
      ],
    );

    await HttpOverrides.runZoned(
      () async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<CoachProfileProvider>(
                create: (_) => CoachProfileProvider(),
              ),
              ChangeNotifierProvider<ByokProvider>(
                create: (_) => ByokProvider(),
              ),
              ChangeNotifierProvider<ScanSessionProvider>.value(
                value: sessions,
              ),
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
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('document_scan_capture_cta'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('document_scan_tax_type_selector'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('document_scan_tax_example_cta'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('document_scan_tax_local_text_cta'),
          findsNothing,
        );
      },
      createHttpClient: network.createHttpClient,
    );

    expect(snapshotIdFactoryCalls, 0);
    expect(sessions.retainExtractionCalls, 0);
    expect(sessions.notifyCalls, 0);
    expect(reviewBuildCalls, 0);
    expect(network.createClientCalls, 0);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/scan');
  });

  testWidgets(
      'typed tax route without the retained candidate fails closed and exposes recovery',
      (tester) async {
    _setView(tester, 1800);
    FeatureFlags.typedTaxProfile = true;

    final extraction = _taxExtraction();
    final coachProfile = _CoachProfileSpy();
    final biography = _BiographySpy();
    final externalSync = _ExternalSyncSpy();
    final harness = _harness(
      extraction: extraction,
      candidate: null,
      coachProfile: coachProfile,
      biography: biography,
      externalSync: externalSync,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('tax_review_missing_candidate_recovery')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('tax_review_confirm_cta')), findsNothing);
    expect(coachProfile.acceptTaxReviewCalls, 0);
    expect(biography.addFactCalls, 0);
    expect(externalSync.calls, 0);
  });

  testWidgets(
      'flag off fails closed for a retained deep-linked tax candidate and cleanup stays local',
      (tester) async {
    _setView(tester, 2200);

    final extraction = _taxExtraction();
    final candidate = _readyCandidate(extraction);
    final coachProfile = _CoachProfileSpy();
    final biography = _BiographySpy();
    final externalSync = _ExternalSyncSpy();
    final harness = _harness(
      extraction: extraction,
      candidate: candidate,
      coachProfile: coachProfile,
      biography: biography,
      externalSync: externalSync,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('tax_review_disabled_recovery')), findsOneWidget);
    expect(find.byKey(const Key('tax_review_confirm_cta')), findsNothing);
    expect(
      find.bySemanticsIdentifier('tax_review_back_cta'),
      findsOneWidget,
    );
    expect(harness.scanSessions.byId(harness.scanSessionId)?.taxCandidate,
        same(candidate));
    expect(coachProfile.acceptTaxReviewCalls, 0);
    expect(biography.addFactCalls, 0);
    expect(externalSync.calls, 0);
    expect(find.text('impact'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(harness.scanSessions.byId(harness.scanSessionId), isNull);
    expect(coachProfile.acceptTaxReviewCalls, 0);
    expect(biography.addFactCalls, 0);
    expect(externalSync.calls, 0);
    expect(find.text('impact'), findsNothing);
  });

  final invalidReviewCases = <({
    String name,
    Future<void> Function(WidgetTester tester) mutate,
  })>[
    (
      name: 'document kind/status pair',
      mutate: (tester) => _choose(
            tester,
            controlKey: 'tax_review_document_kind',
            optionKey: 'tax_review_document_kind_taxpayer_return',
          ),
    ),
    (
      name: 'tax year below the supported range',
      mutate: (tester) => _enter(
            tester,
            controlKey: 'tax_review_tax_year',
            value: '1899',
          ),
    ),
    (
      name: 'tax year above the supported range',
      mutate: (tester) => _enter(
            tester,
            controlKey: 'tax_review_tax_year',
            value: '2101',
          ),
    ),
    for (final year in const ['1899', '2101'])
      (
        name: 'based-on tax year $year outside the supported range',
        mutate: (tester) => _enter(
              tester,
              controlKey: 'tax_review_based_on_tax_year',
              value: year,
            ),
      ),
    (
      name: 'malformed source date',
      mutate: (tester) => _enter(
            tester,
            controlKey: 'tax_review_source_date',
            value: '20/not-a-date/2026',
          ),
    ),
    (
      name: 'non-canonical canton',
      mutate: (tester) => _enter(
            tester,
            controlKey: 'tax_review_canton_code',
            value: 'XX',
          ),
    ),
    (
      name: 'non-finite ICC taxable income',
      mutate: (tester) => _enter(
            tester,
            controlKey: 'tax_review_cantonal_communal_taxable_income_chf',
            value: 'NaN',
          ),
    ),
    (
      name: 'negative taxable wealth',
      mutate: (tester) => _enter(
            tester,
            controlKey: 'tax_review_cantonal_communal_taxable_wealth_chf',
            value: '-1',
          ),
    ),
    (
      name: 'non-finite ICC assessed amount',
      mutate: (tester) => _enter(
            tester,
            controlKey: 'tax_review_cantonal_communal_assessed_tax_chf',
            value: 'Infinity',
          ),
    ),
    (
      name: 'negative IFD assessed amount',
      mutate: (tester) => _enter(
            tester,
            controlKey: 'tax_review_federal_direct_assessed_tax_chf',
            value: '-1',
          ),
    ),
    (
      name: 'federal authority on ICC amount',
      mutate: (tester) => _choose(
            tester,
            controlKey: 'tax_review_cantonal_authority_scope',
            optionKey: 'tax_review_cantonal_authority_scope_federal_direct',
          ),
    ),
    (
      name: 'unknown IFD authority scope',
      mutate: (tester) => _choose(
            tester,
            controlKey: 'tax_review_federal_authority_scope',
            optionKey: 'tax_review_federal_authority_scope_unknown',
          ),
    ),
    (
      name: 'cantonal authority on IFD amount',
      mutate: (tester) => _choose(
            tester,
            controlKey: 'tax_review_federal_authority_scope',
            optionKey: 'tax_review_federal_authority_scope_cantonal_only',
          ),
    ),
    for (final rate in const [
      ('marginal', 'tax_review_explicit_marginal_rate_percent'),
      ('average', 'tax_review_explicit_average_rate_percent'),
    ])
      for (final invalidValue in const ['-0.1', '100.1', 'NaN'])
        (
          name: '${rate.$1} rate $invalidValue percent',
          mutate: (tester) => _enter(
                tester,
                controlKey: rate.$2,
                value: invalidValue,
              ),
        ),
  ];

  for (final invalidCase in invalidReviewCases) {
    testWidgets('isolated invalid ${invalidCase.name} blocks every writer',
        (tester) async {
      _setView(tester, 3000);
      FeatureFlags.typedTaxProfile = true;

      final extraction = _taxExtraction();
      final candidate = _readyCandidate(extraction);
      final coachProfile = _CoachProfileSpy();
      final biography = _BiographySpy();
      final externalSync = _ExternalSyncSpy();
      final harness = _harness(
        extraction: extraction,
        candidate: candidate,
        coachProfile: coachProfile,
        biography: biography,
        externalSync: externalSync,
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await invalidCase.mutate(tester);
      await _tapKey(tester, 'tax_review_confirm_cta');

      expect(coachProfile.acceptTaxReviewCalls, 0);
      expect(biography.addFactCalls, 0);
      expect(externalSync.calls, 0);
      final retained = harness.scanSessions.byId(harness.scanSessionId)!;
      expect(retained.taxCandidate, same(candidate));
      expect(retained.extraction.fields.single.sourceText, 'PII-NEVER-SEND');
    });
  }

  final permittedPartialCases = <({
    String name,
    Future<void> Function(WidgetTester tester) mutate,
    void Function(TaxReviewConfirmation confirmation) verify,
  })>[
    (
      name: 'unknown subject scope',
      mutate: (tester) => _choose(
            tester,
            controlKey: 'tax_review_subject_scope',
            optionKey: 'tax_review_subject_scope_unknown',
          ),
      verify: (confirmation) =>
          expect(confirmation.subjectScope, TaxSubjectScope.unknown),
    ),
    (
      name: 'missing tax year',
      mutate: (tester) => _enter(
            tester,
            controlKey: 'tax_review_tax_year',
            value: '',
          ),
      verify: (confirmation) => expect(confirmation.taxYear, isNull),
    ),
    (
      name: 'missing based-on tax year',
      mutate: (tester) => _enter(
            tester,
            controlKey: 'tax_review_based_on_tax_year',
            value: '',
          ),
      verify: (confirmation) => expect(confirmation.basedOnTaxYear, isNull),
    ),
    (
      name: 'missing source date',
      mutate: (tester) => _enter(
            tester,
            controlKey: 'tax_review_source_date',
            value: '',
          ),
      verify: (confirmation) => expect(confirmation.sourceDate, isNull),
    ),
    (
      name: 'missing canton',
      mutate: (tester) => _enter(
            tester,
            controlKey: 'tax_review_canton_code',
            value: '',
          ),
      verify: (confirmation) => expect(confirmation.cantonCode, isNull),
    ),
    (
      name: 'missing optional municipality',
      mutate: (tester) async {
        await _enter(
          tester,
          controlKey: 'tax_review_municipality_id',
          value: '',
        );
        await _enter(
          tester,
          controlKey: 'tax_review_municipality_label',
          value: '',
        );
      },
      verify: (confirmation) {
        expect(confirmation.municipalityId, isNull);
        expect(confirmation.municipalityLabel, isNull);
      },
    ),
    for (final scope in const [
      (
        'ICC unknown authority',
        false,
        'tax_review_cantonal_authority_scope',
        'tax_review_cantonal_authority_scope_unknown',
        TaxAuthorityScope.unknown,
        TaxBaseScope.incomeAndWealth,
      ),
      (
        'ICC unknown base',
        false,
        'tax_review_cantonal_base_scope',
        'tax_review_cantonal_base_scope_unknown',
        TaxAuthorityScope.cantonalCommunalCombined,
        TaxBaseScope.unknown,
      ),
      (
        'ICC total invoice',
        false,
        'tax_review_cantonal_base_scope',
        'tax_review_cantonal_base_scope_total_invoice',
        TaxAuthorityScope.cantonalCommunalCombined,
        TaxBaseScope.totalInvoice,
      ),
      (
        'IFD unknown base',
        true,
        'tax_review_federal_base_scope',
        'tax_review_federal_base_scope_unknown',
        TaxAuthorityScope.federalDirect,
        TaxBaseScope.unknown,
      ),
    ])
      (
        name: scope.$1,
        mutate: (tester) => _choose(
              tester,
              controlKey: scope.$3,
              optionKey: scope.$4,
            ),
        verify: (confirmation) {
          final amount = scope.$2
              ? confirmation.federalDirectAssessedTax
              : confirmation.cantonalCommunalAssessedTax;
          expect(amount?.amountChf, scope.$2 ? 3840 : 14520);
          expect(amount?.authorityScope, scope.$5);
          expect(amount?.baseScope, scope.$6);
        },
      ),
    for (final income in const [
      (
        'ICC taxable income -1',
        false,
        'tax_review_cantonal_communal_taxable_income_chf',
      ),
      ('IFD taxable income -1', true, 'tax_review_federal_taxable_income_chf'),
    ])
      (
        name: income.$1,
        mutate: (tester) => _enter(
              tester,
              controlKey: income.$3,
              value: '-1',
            ),
        verify: (confirmation) => expect(
              income.$2
                  ? confirmation.federalTaxableIncomeChf
                  : confirmation.cantonalCommunalTaxableIncomeChf,
              -1,
            ),
      ),
  ];

  for (final partialCase in permittedPartialCases) {
    testWidgets('spec permits partial snapshot with ${partialCase.name}',
        (tester) async {
      _setView(tester, 3000);
      FeatureFlags.typedTaxProfile = true;

      final extraction = _taxExtraction();
      final candidate = _readyCandidate(extraction);
      final coachProfile = _CoachProfileSpy();
      final biography = _BiographySpy();
      final externalSync = _ExternalSyncSpy();
      final harness = _harness(
        extraction: extraction,
        candidate: candidate,
        coachProfile: coachProfile,
        biography: biography,
        externalSync: externalSync,
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await partialCase.mutate(tester);
      await _tapKey(tester, 'tax_review_confirm_cta');

      expect(coachProfile.acceptTaxReviewCalls, 1);
      final confirmation = coachProfile.acceptedConfirmation!;
      expect(confirmation.candidate, same(candidate));
      partialCase.verify(confirmation);
      expect(biography.addFactCalls, 0);
      expect(externalSync.calls, 0);
    });
  }

  testWidgets(
      'typed review exposes semantic canonical controls and carries the complete corrected Swiss tax payload once',
      (tester) async {
    _setView(tester, 3400);
    FeatureFlags.typedTaxProfile = true;

    final extraction = _taxExtraction();
    final candidate = _candidate(extraction);
    final coachProfile = _CoachProfileSpy();
    final biography = _BiographySpy();
    final externalSync = _ExternalSyncSpy();
    final harness = _harness(
      extraction: extraction,
      candidate: candidate,
      coachProfile: coachProfile,
      biography: biography,
      externalSync: externalSync,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    const canonicalControlKeys = [
      'tax_review_document_kind',
      'tax_review_assessment_status',
      'tax_review_tax_year',
      'tax_review_based_on_tax_year',
      'tax_review_source_date',
      'tax_review_subject_scope',
      'tax_review_canton_code',
      'tax_review_municipality_id',
      'tax_review_municipality_label',
      'tax_review_cantonal_communal_taxable_income_chf',
      'tax_review_federal_taxable_income_chf',
      'tax_review_cantonal_communal_taxable_wealth_chf',
      'tax_review_cantonal_communal_assessed_tax_chf',
      'tax_review_cantonal_authority_scope',
      'tax_review_cantonal_base_scope',
      'tax_review_federal_direct_assessed_tax_chf',
      'tax_review_federal_authority_scope',
      'tax_review_federal_base_scope',
      'tax_review_explicit_marginal_rate_percent',
      'tax_review_explicit_average_rate_percent',
    ];
    for (final key in canonicalControlKeys) {
      final control = find.byKey(Key(key));
      expect(control, findsOneWidget, reason: 'missing stable control $key');
      expect(find.bySemanticsIdentifier(key), findsOneWidget);
      expect(
        tester.getSemantics(control).label.trim(),
        isNotEmpty,
        reason: '$key must expose a spoken financial meaning',
      );
    }
    expect(find.bySemanticsIdentifier('tax_review_back_cta'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('tax_review_confirm_cta'),
      findsOneWidget,
    );

    await _choose(
      tester,
      controlKey: 'tax_review_document_kind',
      optionKey: 'tax_review_document_kind_assessment_notice',
    );
    await _choose(
      tester,
      controlKey: 'tax_review_assessment_status',
      optionKey: 'tax_review_assessment_status_assessed_appealable',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_tax_year',
      value: '2025',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_source_date',
      value: '2026-06-20',
    );
    await _choose(
      tester,
      controlKey: 'tax_review_subject_scope',
      optionKey: 'tax_review_subject_scope_jointly_assessed_couple',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_canton_code',
      value: 'VD',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_municipality_id',
      value: '5586',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_municipality_label',
      value: 'Lausanne',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_cantonal_communal_taxable_income_chf',
      value: '98500',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_federal_taxable_income_chf',
      value: '96200',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_cantonal_communal_taxable_wealth_chf',
      value: '245000',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_cantonal_communal_assessed_tax_chf',
      value: '14520',
    );
    await _choose(
      tester,
      controlKey: 'tax_review_cantonal_authority_scope',
      optionKey:
          'tax_review_cantonal_authority_scope_cantonal_communal_combined',
    );
    await _choose(
      tester,
      controlKey: 'tax_review_cantonal_base_scope',
      optionKey: 'tax_review_cantonal_base_scope_income_and_wealth',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_federal_direct_assessed_tax_chf',
      value: '3840',
    );
    await _choose(
      tester,
      controlKey: 'tax_review_federal_authority_scope',
      optionKey: 'tax_review_federal_authority_scope_federal_direct',
    );
    await _choose(
      tester,
      controlKey: 'tax_review_federal_base_scope',
      optionKey: 'tax_review_federal_base_scope_income_only',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_explicit_marginal_rate_percent',
      value: '32,5',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_explicit_average_rate_percent',
      value: '22,3',
    );

    await _tapKey(tester, 'tax_review_confirm_cta');

    expect(coachProfile.acceptTaxReviewCalls, 1);
    final confirmation = coachProfile.acceptedConfirmation!;
    expect(confirmation.candidate, same(candidate));
    expect(
      confirmation.candidate.snapshotId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(confirmation.candidate.snapshotId, isNot(harness.scanSessionId));
    expect(confirmation.documentKind, TaxDocumentKind.assessmentNotice);
    expect(
      confirmation.assessmentStatus,
      TaxAssessmentStatus.assessedAppealable,
    );
    expect(confirmation.taxYear, 2025);
    expect(confirmation.basedOnTaxYear, isNull);
    expect(confirmation.sourceDate, DateTime.utc(2026, 6, 20));
    expect(
      confirmation.subjectScope,
      TaxSubjectScope.jointlyAssessedCouple,
    );
    expect(confirmation.cantonCode, 'VD');
    expect(confirmation.municipalityId, '5586');
    expect(confirmation.municipalityLabel, 'Lausanne');
    expect(confirmation.cantonalCommunalTaxableIncomeChf, 98500);
    expect(confirmation.federalTaxableIncomeChf, 96200);
    expect(confirmation.cantonalCommunalTaxableWealthChf, 245000);
    expect(confirmation.cantonalCommunalAssessedTax?.amountChf, 14520);
    expect(
      confirmation.cantonalCommunalAssessedTax?.authorityScope,
      TaxAuthorityScope.cantonalCommunalCombined,
    );
    expect(
      confirmation.cantonalCommunalAssessedTax?.baseScope,
      TaxBaseScope.incomeAndWealth,
    );
    expect(confirmation.federalDirectAssessedTax?.amountChf, 3840);
    expect(
      confirmation.federalDirectAssessedTax?.authorityScope,
      TaxAuthorityScope.federalDirect,
    );
    expect(
      confirmation.federalDirectAssessedTax?.baseScope,
      TaxBaseScope.incomeOnly,
    );
    expect(confirmation.explicitMarginalIncomeTaxRate, 0.325);
    expect(confirmation.explicitAverageIncomeTaxRate, 0.223);
    expect(biography.addFactCalls, 0);
    expect(
      externalSync.calls,
      0,
      reason: 'confirmed tax facts remain local; sourceText is never sent',
    );
    final impactPayload = harness.scanSessions.byId(harness.scanSessionId)!;
    expect(impactPayload.taxCandidate, isNull);
    expect(
      impactPayload.extraction.fields.every(
        (field) => field.sourceText.isEmpty,
      ),
      isTrue,
    );
  });

  testWidgets(
      'provisional bill prefills based-on year and accepts one valid correction',
      (tester) async {
    _setView(tester, 2800);
    FeatureFlags.typedTaxProfile = true;
    final extraction = _taxExtraction();
    final candidate = _provisionalCandidate(extraction);
    final coachProfile = _CoachProfileSpy();
    final harness = _harness(
      extraction: extraction,
      candidate: candidate,
      coachProfile: coachProfile,
      biography: _BiographySpy(),
      externalSync: _ExternalSyncSpy(),
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    final basedOn = find.byKey(const Key('tax_review_based_on_tax_year'));
    expect(tester.widget<TextFormField>(basedOn).controller?.text, '2024');
    await _enter(
      tester,
      controlKey: 'tax_review_based_on_tax_year',
      value: '2023',
    );
    await _tapKey(tester, 'tax_review_confirm_cta');

    final confirmation = coachProfile.acceptedConfirmation!;
    expect(confirmation.documentKind, TaxDocumentKind.provisionalBill);
    expect(confirmation.assessmentStatus, TaxAssessmentStatus.provisional);
    expect(confirmation.taxYear, 2025);
    expect(confirmation.basedOnTaxYear, 2023);
    expect(confirmation.candidate, same(candidate));
  });

  testWidgets('average-only percentage never hydrates the marginal rate',
      (tester) async {
    _setView(tester, 2800);
    FeatureFlags.typedTaxProfile = true;

    final extraction = _taxExtraction();
    final candidate = _averageOnlyCandidate(extraction);
    final coachProfile = _CoachProfileSpy();
    final biography = _BiographySpy();
    final externalSync = _ExternalSyncSpy();
    final harness = _harness(
      extraction: extraction,
      candidate: candidate,
      coachProfile: coachProfile,
      biography: biography,
      externalSync: externalSync,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enter(
      tester,
      controlKey: 'tax_review_explicit_marginal_rate_percent',
      value: '',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_explicit_average_rate_percent',
      value: '22,3',
    );
    await _tapKey(tester, 'tax_review_confirm_cta');

    expect(coachProfile.acceptTaxReviewCalls, 1);
    final confirmation = coachProfile.acceptedConfirmation!;
    expect(confirmation.explicitAverageIncomeTaxRate, 0.223);
    expect(confirmation.explicitMarginalIncomeTaxRate, isNull);
    expect(biography.addFactCalls, 0);
    expect(externalSync.calls, 0);
  });

  testWidgets(
      'injected scorer proves score-save-score order and exact non-zero impact delta',
      (tester) async {
    _setView(tester, 2800);
    FeatureFlags.typedTaxProfile = true;

    final events = <String>[];
    final scorer = _ScoreSpy([63, 82], events);
    final persistence = _MemoryTaxPersistence({
      'q_birth_year': 1985,
      'q_canton': 'VD',
      'q_commune': 'Lausanne',
      'q_net_income_period_chf': 6200,
    }, events: events);
    final realProvider = CoachProfileProvider(
      taxProfilePersistence: persistence,
    );
    await realProvider.loadFromWizard();
    expect(realProvider.profile, isNotNull);

    final extraction = _taxExtraction();
    final candidate = _readyCandidate(extraction);
    final biography = _BiographySpy();
    final externalSync = _ExternalSyncSpy();
    final harness = _harness(
      extraction: extraction,
      candidate: candidate,
      coachProfile: realProvider,
      biography: biography,
      externalSync: externalSync,
      confidenceScorer: scorer.call,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _tapKey(tester, 'tax_review_confirm_cta');

    expect(persistence.saveCalls, 1);
    expect(scorer.calls, 2);
    expect(events, ['score:63', 'save', 'score:82']);
    final impact = harness.scanSessions.byId(harness.scanSessionId)!;
    expect(impact.previousConfidence, 63);
    expect(impact.extraction.confidenceDelta, 19);
    expect(biography.addFactCalls, 0);
    expect(externalSync.calls, 0);
  });

  testWidgets(
      'double tap while the local ledger save is pending accepts exactly once',
      (tester) async {
    _setView(tester, 2200);
    FeatureFlags.typedTaxProfile = true;

    final gate = Completer<void>();
    final extraction = _taxExtraction();
    final candidate = _readyCandidate(extraction);
    final coachProfile = _CoachProfileSpy(
      acceptBehaviors: [() => gate.future],
    );
    final biography = _BiographySpy();
    final externalSync = _ExternalSyncSpy();
    final harness = _harness(
      extraction: extraction,
      candidate: candidate,
      coachProfile: coachProfile,
      biography: biography,
      externalSync: externalSync,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    final confirm = find.byKey(const Key('tax_review_confirm_cta'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.tap(confirm);
    await tester.pump();

    expect(coachProfile.acceptTaxReviewCalls, 1);
    expect(coachProfile.acceptedConfirmation?.candidate, same(candidate));
    expect(biography.addFactCalls, 0);
    expect(externalSync.calls, 0);
    expect(harness.scanSessions.byId(harness.scanSessionId)!.taxCandidate,
        same(candidate));

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('impact'), findsOneWidget);
    expect(coachProfile.acceptTaxReviewCalls, 1);
    expect(
      harness.scanSessions.byId(harness.scanSessionId)!.taxCandidate,
      isNull,
    );
  });

  testWidgets(
      'failed local save keeps the same candidate and one explicit retry accepts it once',
      (tester) async {
    _setView(tester, 2200);
    FeatureFlags.typedTaxProfile = true;

    final extraction = _taxExtraction();
    final candidate = _readyCandidate(extraction);
    final coachProfile = _CoachProfileSpy(
      acceptBehaviors: [
        () async => throw StateError('injected local save failure'),
        () async {},
      ],
    );
    final biography = _BiographySpy();
    final externalSync = _ExternalSyncSpy();
    final harness = _harness(
      extraction: extraction,
      candidate: candidate,
      coachProfile: coachProfile,
      biography: biography,
      externalSync: externalSync,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _tapKey(tester, 'tax_review_confirm_cta');

    expect(coachProfile.acceptTaxReviewCalls, 1);
    expect(find.text('impact'), findsNothing);
    expect(
      harness.scanSessions.byId(harness.scanSessionId)!.taxCandidate,
      same(candidate),
    );
    expect(
      harness.scanSessions
          .byId(harness.scanSessionId)!
          .extraction
          .fields
          .single
          .sourceText,
      'PII-NEVER-SEND',
      reason: 'failed confirmation keeps the in-memory review stable',
    );
    expect(biography.addFactCalls, 0);
    expect(externalSync.calls, 0);

    await _tapKey(tester, 'tax_review_confirm_cta');

    expect(find.text('impact'), findsOneWidget);
    expect(coachProfile.acceptTaxReviewCalls, 2);
    expect(coachProfile.acceptedConfirmation?.candidate, same(candidate));
    expect(
      harness.scanSessions.byId(harness.scanSessionId)!.taxCandidate,
      isNull,
    );
    expect(
      harness.scanSessions
          .byId(harness.scanSessionId)!
          .extraction
          .fields
          .every((field) => field.sourceText.isEmpty),
      isTrue,
    );
  });

  for (final abandonMode in const ['back', 'dispose']) {
    testWidgets(
        '$abandonMode review abandonment discards candidate and raw sourceText without a writer',
        (tester) async {
      _setView(tester, 2200);
      FeatureFlags.typedTaxProfile = true;

      final extraction = _taxExtraction();
      final candidate = _readyCandidate(extraction);
      final coachProfile = _CoachProfileSpy();
      final biography = _BiographySpy();
      final externalSync = _ExternalSyncSpy();
      final harness = _harness(
        extraction: extraction,
        candidate: candidate,
        coachProfile: coachProfile,
        biography: biography,
        externalSync: externalSync,
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();
      expect(
        harness.scanSessions
            .byId(harness.scanSessionId)!
            .extraction
            .fields
            .single
            .sourceText,
        'PII-NEVER-SEND',
      );

      if (abandonMode == 'back') {
        await _tapKey(tester, 'tax_review_back_cta');
      } else {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }

      expect(harness.scanSessions.byId(harness.scanSessionId), isNull);
      expect(coachProfile.acceptTaxReviewCalls, 0);
      expect(biography.addFactCalls, 0);
      expect(externalSync.calls, 0);
    });
  }

  testWidgets(
      'tax impact remains local, never receives sourceText, insight or memory, and discards the session on exit',
      (tester) async {
    _setView(tester, 2200);
    FeatureFlags.typedTaxProfile = true;

    final extraction = _taxExtraction();
    final candidate = _readyCandidate(extraction);
    final sessions = ScanSessionProvider();
    final id = sessions.retainExtraction(
      extraction,
      taxCandidate: candidate,
    );
    expect(
      sessions.retainImpact(
        id,
        extraction: extraction,
        previousConfidence: 0,
      ),
      isTrue,
    );
    final impact = sessions.byId(id)!;
    expect(impact.taxCandidate, isNull);
    expect(
      impact.extraction.fields.every((field) => field.sourceText.isEmpty),
      isTrue,
    );
    final insight = _PremierEclairageSpy();
    final memory = _ScanEventSpy();

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
            scanSessionId: id,
            result: impact.extraction,
            previousConfidence: impact.previousConfidence!,
            fetchPremierEclairage: insight.call,
            saveScanEvent: memory.call,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(insight.calls, 0);
    expect(insight.extractedFields, isNull);
    expect(memory.calls, 0);
    expect(find.text('PII-NEVER-SEND'), findsNothing);
    expect(find.text('REMOTE-INSIGHT-MUST-NOT-RUN'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.bySemanticsIdentifier('document_impact_return_cta'),
      findsOneWidget,
    );
    expect(sessions.byId(id), isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(sessions.byId(id), isNull);
    expect(insight.calls, 0);
    expect(memory.calls, 0);
  });

  testWidgets(
      'confirmed tax impact payload contains only canonical corrected facts, never OCR fields or legacy deductions',
      (tester) async {
    _setView(tester, 2800);
    FeatureFlags.typedTaxProfile = true;
    final extraction = ExtractionResult(
      documentType: DocumentType.taxDeclaration,
      fields: [
        ..._taxExtraction().fields,
        const ExtractedField(
          fieldName: 'deductions_effectuees',
          label: 'Déductions OCR legacy',
          value: 22222.0,
          confidence: 0.95,
          sourceText: 'LEGACY-DEDUCTION-PII',
          needsReview: false,
          profileField: 'actualDeductions',
        ),
      ],
      overallConfidence: 0.93,
      confidenceDelta: 17,
      warnings: const [],
      disclaimer: 'Fixture synthétique.',
      sources: const [],
    );
    final candidate = _readyCandidate(extraction);
    final harness = _harness(
      extraction: extraction,
      candidate: candidate,
      coachProfile: _CoachProfileSpy(),
      biography: _BiographySpy(),
      externalSync: _ExternalSyncSpy(),
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enter(
      tester,
      controlKey: 'tax_review_cantonal_communal_taxable_income_chf',
      value: '123456',
    );
    await _tapKey(tester, 'tax_review_confirm_cta');

    final fields =
        harness.scanSessions.byId(harness.scanSessionId)!.extraction.fields;
    final canonical = <String, dynamic>{
      for (final field in fields) field.fieldName: field.value,
    };
    expect(
      canonical,
      {
        'cantonalCommunalTaxableIncomeChf': 123456.0,
        'federalTaxableIncomeChf': 96200.0,
        'cantonalCommunalTaxableWealthChf': 245000.0,
        'cantonalCommunalAssessedTax.amountChf': 14520.0,
        'federalDirectAssessedTax.amountChf': 3840.0,
        'explicitMarginalIncomeTaxRate': 0.325,
        'explicitAverageIncomeTaxRate': 0.223,
      },
    );
    expect(fields.every((field) => field.sourceText.isEmpty), isTrue);
    expect(fields.every((field) => field.profileField == null), isTrue);
    expect(canonical.values, isNot(contains(98000.0)));
    expect(canonical.values, isNot(contains(22222.0)));
  });

  testWidgets(
      'tax impact CTA emits zero completion stream event, zero write and zero pending return',
      (tester) async {
    _setView(tester, 2200);
    FeatureFlags.typedTaxProfile = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final streamedReturns = <Object>[];
    final subscription = ScreenCompletionTracker.stream.listen(
      streamedReturns.add,
    );
    addTearDown(subscription.cancel);

    final extraction = _taxExtraction();
    final sessions = ScanSessionProvider();
    final id = sessions.retainExtraction(
      extraction,
      taxCandidate: _readyCandidate(extraction),
    );
    expect(
      sessions.retainImpact(
        id,
        extraction: extraction,
        previousConfidence: 60,
      ),
      isTrue,
    );
    final impact = sessions.byId(id)!;
    final router = GoRouter(
      initialLocation: '/impact',
      routes: [
        GoRoute(
          path: '/impact',
          builder: (_, __) => DocumentImpactScreen(
            scanSessionId: id,
            result: impact.extraction,
            previousConfidence: impact.previousConfidence!,
          ),
        ),
        GoRoute(
          path: '/coach/chat',
          builder: (_, __) => const Scaffold(body: Text('coach')),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<ScanSessionProvider>.value(
        value: sessions,
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
    await tester.pumpAndSettle();

    final cta = find.bySemanticsIdentifier('document_impact_return_cta');
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    final pending = await ScreenCompletionTracker.lastReturn(
      'document_scan',
      prefs: prefs,
    );

    expect(
      [
        streamedReturns.length,
        prefs.containsKey('screen_return_document_scan'),
        pending == null,
      ],
      [0, false, true],
    );
  });

  testWidgets(
      'partial tax impact never claims that values were integrated into projections',
      (tester) async {
    _setView(tester, 2200);
    FeatureFlags.typedTaxProfile = true;
    const partial = ExtractionResult(
      documentType: DocumentType.taxDeclaration,
      fields: [],
      overallConfidence: 0,
      confidenceDelta: 0,
      warnings: ['partialAsk'],
      disclaimer: 'Fixture partielle.',
      sources: [],
    );
    final sessions = ScanSessionProvider();
    final id = sessions.retainExtraction(partial);
    expect(
      sessions.retainImpact(
        id,
        extraction: partial,
        previousConfidence: 60,
      ),
      isTrue,
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
            scanSessionId: id,
            result: sessions.byId(id)!.extraction,
            previousConfidence: 60,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('intégrées dans tes projections'),
      findsNothing,
    );
  });

  testWidgets(
      'tax without local OCR hides camera, gallery and PDF picker surfaces before consent',
      (tester) async {
    _setView(tester, 2200);
    FeatureFlags.typedTaxProfile = true;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<ByokProvider>(
            create: (_) => ByokProvider(),
          ),
          ChangeNotifierProvider<ScanSessionProvider>(
            create: (_) => ScanSessionProvider(),
          ),
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
          home: DocumentScanScreen(
            initialType: DocumentType.taxDeclaration,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      [
        find.byKey(const Key('document_scan_capture_cta')).evaluate().length,
        find.byIcon(Icons.photo_library_outlined).evaluate().length,
        find
            .byKey(const Key('document_scan_tax_local_text_cta'))
            .evaluate()
            .length,
      ],
      [0, 0, 1],
    );
  });

  for (final invalidBase in const [
    TaxBaseScope.wealthOnly,
    TaxBaseScope.incomeAndWealth,
  ]) {
    testWidgets(
        'IFD ${invalidBase.name} OCR candidate excludes impossible bases and confirms only unknown locally',
        (tester) async {
      _setView(tester, 2400);
      FeatureFlags.typedTaxProfile = true;
      final extraction = _taxExtraction();
      final candidate = _invalidFederalBaseCandidate(extraction, invalidBase);
      final coach = _CoachProfileSpy();
      final biography = _BiographySpy();
      final externalSync = _ExternalSyncSpy();
      final harness = _harness(
        extraction: extraction,
        candidate: candidate,
        coachProfile: coach,
        biography: biography,
        externalSync: externalSync,
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButtonFormField<TaxBaseScope>>(
        find.byKey(const Key('tax_review_federal_base_scope')),
      );
      final dropdownButton = tester.widget<DropdownButton<TaxBaseScope>>(
        find.descendant(
          of: find.byKey(const Key('tax_review_federal_base_scope')),
          matching: find.byType(DropdownButton<TaxBaseScope>),
        ),
      );
      final offeredBases = dropdownButton.items!
          .map((item) => item.value)
          .whereType<TaxBaseScope>()
          .toSet();
      expect(
        [
          dropdown.initialValue,
          offeredBases.contains(TaxBaseScope.wealthOnly),
          offeredBases.contains(TaxBaseScope.incomeAndWealth),
          find
              .byKey(const Key('tax_review_federal_scope_incoherence'))
              .evaluate()
              .length,
        ],
        [TaxBaseScope.unknown, false, false, 1],
      );

      await _tapKey(tester, 'tax_review_confirm_cta');

      expect(coach.acceptTaxReviewCalls, 1);
      expect(
        coach.acceptedConfirmation?.federalDirectAssessedTax?.baseScope,
        TaxBaseScope.unknown,
      );
      expect(biography.addFactCalls, 0);
      expect(externalSync.calls, 0);
      expect(harness.router.routeInformationProvider.value.uri.path,
          '/scan/impact');
      expect(
        harness.router.routeInformationProvider.value.uri.queryParameters,
        {'scanSessionId': harness.scanSessionId},
      );
    });
  }

  testWidgets(
      'inForce requires a checked secondary attestation before one local write',
      (tester) async {
    _setView(tester, 2600);
    FeatureFlags.typedTaxProfile = true;
    final extraction = _taxExtraction();
    final candidate = _readyCandidate(extraction);
    final coach = _CoachProfileSpy();
    final biography = _BiographySpy();
    final externalSync = _ExternalSyncSpy();
    final harness = _harness(
      extraction: extraction,
      candidate: candidate,
      coachProfile: coach,
      biography: biography,
      externalSync: externalSync,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _choose(
      tester,
      controlKey: 'tax_review_assessment_status',
      optionKey: 'tax_review_assessment_status_in_force',
    );
    final statusDropdown =
        tester.widget<DropdownButtonFormField<TaxAssessmentStatus>>(
      find.byKey(const Key('tax_review_assessment_status')),
    );
    expect(statusDropdown.initialValue, TaxAssessmentStatus.inForce);
    final attestation =
        find.bySemanticsIdentifier('tax_review_in_force_attested');
    expect(attestation, findsOneWidget);
    var attestationSemantics = tester.getSemantics(attestation);
    expect(attestationSemantics.flagsCollection.isChecked.name, 'isFalse');

    await _tapKey(tester, 'tax_review_confirm_cta');

    expect(coach.acceptTaxReviewCalls, 0);
    expect(coach.acceptedConfirmation, isNull);
    expect(
      harness.scanSessions.byId(harness.scanSessionId)?.taxCandidate,
      same(candidate),
    );
    expect(harness.router.routeInformationProvider.value.uri.path, '/review');
    expect(find.text('impact'), findsNothing);
    expect(biography.addFactCalls, 0);
    expect(externalSync.calls, 0);

    await tester.tap(attestation);
    await tester.pumpAndSettle();
    attestationSemantics = tester.getSemantics(attestation);
    expect(attestationSemantics.flagsCollection.isChecked.name, 'isTrue');
    await _tapKey(tester, 'tax_review_confirm_cta');

    expect(coach.acceptTaxReviewCalls, 1);
    expect(
      coach.acceptedConfirmation?.assessmentStatus,
      TaxAssessmentStatus.inForce,
    );
    expect(
      coach.acceptedConfirmation!.inForceAttested,
      isTrue,
    );
    expect(biography.addFactCalls, 0);
    expect(externalSync.calls, 0);
    expect(
        harness.router.routeInformationProvider.value.uri.path, '/scan/impact');
    expect(
      harness.router.routeInformationProvider.value.uri.queryParameters,
      {'scanSessionId': harness.scanSessionId},
    );
  });

  testWidgets('review clock accepts its historical civil today exactly once',
      (tester) async {
    _setView(tester, 2400);
    FeatureFlags.typedTaxProfile = true;
    final clock = _CountingClock(DateTime.utc(2024, 7, 14, 12));
    final extraction = _taxExtraction();
    final coach = _CoachProfileSpy();
    final harness = _harness(
      extraction: extraction,
      candidate: _readyCandidate(
        extraction,
        taxYear: 2023,
        sourceDate: DateTime.utc(2024, 7, 14),
      ),
      coachProfile: coach,
      biography: _BiographySpy(),
      externalSync: _ExternalSyncSpy(),
      now: clock.call,
    );
    expect(
      harness.screenConstructorError,
      isNull,
      reason: 'ExtractionReviewScreen must accept the injected clock',
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _tapKey(tester, 'tax_review_confirm_cta');

    expect(clock.calls, greaterThan(0));
    expect(
      [
        coach.acceptTaxReviewCalls,
        harness.router.routeInformationProvider.value.uri.path,
        find.text('impact').evaluate().length,
      ],
      [1, '/scan/impact', 1],
    );
  });

  testWidgets('review clock rejects its historical civil tomorrow',
      (tester) async {
    _setView(tester, 2400);
    FeatureFlags.typedTaxProfile = true;
    final clock = _CountingClock(DateTime.utc(2024, 7, 14, 12));
    final extraction = _taxExtraction();
    final coach = _CoachProfileSpy();
    final candidate = _readyCandidate(
      extraction,
      taxYear: 2023,
      sourceDate: DateTime.utc(2024, 7, 15),
    );
    final harness = _harness(
      extraction: extraction,
      candidate: candidate,
      coachProfile: coach,
      biography: _BiographySpy(),
      externalSync: _ExternalSyncSpy(),
      now: clock.call,
    );
    expect(
      harness.screenConstructorError,
      isNull,
      reason: 'ExtractionReviewScreen must accept the injected clock',
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _tapKey(tester, 'tax_review_confirm_cta');

    expect(clock.calls, greaterThan(0));
    expect(
      [
        coach.acceptTaxReviewCalls,
        harness.router.routeInformationProvider.value.uri.path,
        find.text('impact').evaluate().length,
      ],
      [0, '/review', 0],
    );
    expect(
      harness.scanSessions.byId(harness.scanSessionId)?.taxCandidate,
      same(candidate),
    );
  });
}
