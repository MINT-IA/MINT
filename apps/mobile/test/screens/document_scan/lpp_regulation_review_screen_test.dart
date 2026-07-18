import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:provider/provider.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _replacementSnapshotId = '22222222-2222-4222-8222-222222222222';
const _previousReferenceId = '33333333-3333-4333-8333-333333333333';
const _replacementReferenceId = '44444444-4444-4444-8444-444444444444';
const _acceptedReferenceId = '55555555-5555-4555-8555-555555555555';

const _planExtraction = ExtractionResult(
  documentType: DocumentType.lppPlan,
  fields: <ExtractedField>[],
  overallConfidence: 0,
  confidenceDelta: 0,
  warnings: <String>[],
  disclaimer: '',
  sources: <String>[],
  diagnostics: <ExtractionDiagnostic>[],
  coherenceWarnings: <String>[],
);

final _candidate = LppRegulationAcquisitionCandidate(
  expectedSnapshotId: _snapshotId,
  expectedPreviousReferenceId: _previousReferenceId,
);

LppEvidenceSnapshot _snapshot({
  required String snapshotId,
  required String referenceId,
}) {
  final sourceDate = DateTime.utc(2026, 1, 1);
  final updatedAt = DateTime.utc(2026, 7, 1, 8);
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
        updatedAt: updatedAt,
      ),
    },
    lppRegulationReference: LppRegulationReference.create(
      referenceId: referenceId,
      sourceDate: sourceDate,
      legalYear: 2026,
      confirmedAt: updatedAt,
    ),
  );
}

final class _LedgerSpy extends CoachProfileProvider {
  _LedgerSpy({
    required this.events,
    this.failAccept = false,
  });

  final List<String> events;
  bool failAccept;
  String currentSnapshotId = _snapshotId;
  String currentReferenceId = _previousReferenceId;
  int acceptCalls = 0;
  final confirmations = <LppRegulationReviewConfirmation>[];
  final receipt = LppRegulationReceipt(
    referenceId: _acceptedReferenceId,
    snapshotId: _snapshotId,
    confirmedAt: DateTime.utc(2026, 7, 18, 10),
  );

  @override
  CoachProfile get profile => CoachProfile.defaults();

  @override
  bool get hasProfile => true;

  @override
  bool get isLoaded => true;

  @override
  LppEvidenceSnapshot? currentLppSnapshot(LppEvidenceOwnerKind ownerKind) =>
      ownerKind == LppEvidenceOwnerKind.self
          ? _snapshot(
              snapshotId: currentSnapshotId,
              referenceId: currentReferenceId,
            )
          : null;

  @override
  Future<LppRegulationReceipt> acceptLppRegulationReference(
    LppRegulationReviewConfirmation confirmation,
  ) async {
    acceptCalls += 1;
    confirmations.add(confirmation);
    events.add('accept');
    if (failAccept ||
        confirmation.expectedSnapshotId != currentSnapshotId ||
        confirmation.expectedPreviousReferenceId != currentReferenceId) {
      throw StateError('synthetic regulation accept failure');
    }
    return receipt;
  }
}

final class _DocumentSpy extends DocumentProvider {
  _DocumentSpy({
    required this.events,
    this.failRecordCalls = 0,
  });

  final List<String> events;
  int failRecordCalls;
  int recordCalls = 0;
  final receipts = <LppRegulationReceipt>[];

  @override
  Future<ConfirmedDocumentReference> recordLppRegulation(
    LppRegulationReceipt receipt,
  ) async {
    recordCalls += 1;
    receipts.add(receipt);
    events.add('record');
    if (recordCalls <= failRecordCalls) {
      throw StateError('synthetic regulation record failure');
    }
    return ConfirmedDocumentReference(
      referenceId: receipt.referenceId,
      kind: ConfirmedDocumentReference.lppRegulationKind,
      snapshotId: receipt.snapshotId,
      ownerKind: receipt.ownerKind,
      confirmedAt: receipt.confirmedAt,
    );
  }
}

final class _BiographySpy extends BiographyProvider {
  int writes = 0;

  @override
  Future<void> addFact(BiographyFact fact) async {
    writes += 1;
  }
}

final class _ScanSessionSpy extends ScanSessionProvider {
  int impactCalls = 0;
  int discardCalls = 0;

  @override
  bool retainImpact(
    String id, {
    required ExtractionResult extraction,
    required int previousConfidence,
  }) {
    impactCalls += 1;
    return super.retainImpact(
      id,
      extraction: extraction,
      previousConfidence: previousConfidence,
    );
  }

  @override
  void discard(String id) {
    discardCalls += 1;
    super.discard(id);
  }
}

Widget _buildReviewScreen({
  required String scanSessionId,
  required LppRegulationAcquisitionCandidate? candidate,
  required ScanConfirmationSender sendScanConfirmation,
}) {
  const constructor = ExtractionReviewScreen.new;
  final named = <Symbol, dynamic>{
    #scanSessionId: scanSessionId,
    #result: _planExtraction,
    #lppRegulationCandidate: candidate,
    #sendScanConfirmation: sendScanConfirmation,
    #now: () => DateTime.utc(2026, 7, 18, 10),
  };
  try {
    return Function.apply(constructor, const <dynamic>[], named) as Widget;
  } on NoSuchMethodError {
    // RED compatibility bridge: current production has not added the bounded
    // candidate parameter yet. Once it does, the first call above is used.
    named.remove(#lppRegulationCandidate);
    return Function.apply(constructor, const <dynamic>[], named) as Widget;
  }
}

final class _Harness {
  const _Harness({
    required this.widget,
    required this.router,
    required this.sessions,
    required this.scanSessionId,
    required this.ledger,
    required this.documents,
    required this.biography,
    required this.syncCalls,
    required this.events,
  });

  final Widget widget;
  final GoRouter router;
  final _ScanSessionSpy sessions;
  final String scanSessionId;
  final _LedgerSpy ledger;
  final _DocumentSpy documents;
  final _BiographySpy biography;
  final List<int> syncCalls;
  final List<String> events;
}

_Harness _harness({
  bool withCandidate = true,
  bool failAccept = false,
  int failRecordCalls = 0,
}) {
  final events = <String>[];
  final ledger = _LedgerSpy(events: events, failAccept: failAccept);
  final documents = _DocumentSpy(
    events: events,
    failRecordCalls: failRecordCalls,
  );
  final biography = _BiographySpy();
  final sessions = _ScanSessionSpy();
  final syncCalls = <int>[];
  final scanSessionId = withCandidate
      ? sessions.retainExtraction(
          _planExtraction,
          lppRegulationCandidate: _candidate,
        )
      : 'missing-regulation-session';
  late final GoRouter router;
  router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, __) => _buildReviewScreen(
          scanSessionId: scanSessionId,
          candidate: withCandidate ? _candidate : null,
          sendScanConfirmation: ({
            required documentType,
            required confirmedFields,
            required overallConfidence,
          }) async {
            syncCalls.add(1);
          },
        ),
      ),
      GoRoute(
        path: '/retraite',
        builder: (_, __) => const Scaffold(
          key: Key('lpp_regulation_retirement_destination'),
        ),
      ),
      GoRoute(
        path: '/scan/impact',
        builder: (_, __) => const Scaffold(
          key: Key('lpp_regulation_forbidden_impact_destination'),
        ),
      ),
    ],
  );
  return _Harness(
    router: router,
    sessions: sessions,
    scanSessionId: scanSessionId,
    ledger: ledger,
    documents: documents,
    biography: biography,
    syncCalls: syncCalls,
    events: events,
    widget: MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
        ChangeNotifierProvider<DocumentProvider>.value(value: documents),
        ChangeNotifierProvider<BiographyProvider>.value(value: biography),
        ChangeNotifierProvider<ScanSessionProvider>.value(value: sessions),
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

Future<void> _enterReviewValues(
  WidgetTester tester, {
  String sourceDate = '2026-02-03',
  String legalYear = '2026',
}) async {
  final date = find.byKey(
    const Key('lpp_regulation_review_source_date'),
  );
  final year = find.byKey(
    const Key('lpp_regulation_review_legal_year'),
  );
  expect(date, findsOneWidget);
  expect(year, findsOneWidget);
  await tester.ensureVisible(date);
  await tester.enterText(date, sourceDate);
  await tester.enterText(year, legalYear);
  await tester.pump();
}

Future<void> _confirmReview(WidgetTester tester) async {
  final confirm = find.byKey(
    const Key('lpp_regulation_review_confirm_cta'),
  );
  expect(confirm, findsOneWidget);
  await tester.ensureVisible(confirm);
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

void _expectNoExternalSideEffects(_Harness harness) {
  expect(harness.biography.writes, 0);
  expect(harness.syncCalls, isEmpty);
  expect(harness.sessions.impactCalls, 0);
  expect(
    find.byKey(const Key('lpp_regulation_forbidden_impact_destination')),
    findsNothing,
  );
}

void main() {
  setUp(() {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.documentLppEvidenceEnabled = true;
    FeatureFlags.lppRegulationReferenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
    FeatureFlags.lppRegulationReferenceEnabled = false;
  });

  test('production review route forwards the volatile regulation candidate',
      () {
    final source = File('lib/app.dart').readAsStringSync();
    final reviewStart = source.indexOf("path: '/scan/review'");
    final impactStart = source.indexOf("path: '/scan/impact'", reviewStart);
    expect(reviewStart, greaterThanOrEqualTo(0));
    expect(impactStart, greaterThan(reviewStart));
    final reviewRoute = source.substring(reviewStart, impactStart);

    expect(
      reviewRoute,
      contains(
        'lppRegulationCandidate: session.lppRegulationCandidate',
      ),
    );
  });

  testWidgets('flag-off LPP plan review recovers without writer calls',
      (tester) async {
    FeatureFlags.lppRegulationReferenceEnabled = false;
    final harness = _harness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('lpp_regulation_review_disabled_recovery')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('lpp_regulation_review_recovery_cta'),
      findsOneWidget,
    );
    expect(harness.ledger.acceptCalls, 0);
    expect(harness.documents.recordCalls, 0);
    _expectNoExternalSideEffects(harness);
  });

  testWidgets('candidate-less LPP plan review recovers without writer calls',
      (tester) async {
    final harness = _harness(withCandidate: false);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const Key('lpp_regulation_review_missing_candidate_recovery'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('lpp_regulation_review_recovery_cta'),
      findsOneWidget,
    );
    expect(harness.ledger.acceptCalls, 0);
    expect(harness.documents.recordCalls, 0);
    _expectNoExternalSideEffects(harness);
  });

  testWidgets('exact LPP plan review exposes only two human metadata inputs',
      (tester) async {
    final harness = _harness();
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('lpp_regulation_review_screen')),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNWidgets(2));
    for (final identifier in const <String>[
      'lpp_regulation_review_source_date',
      'lpp_regulation_review_legal_year',
      'lpp_regulation_review_confirm_cta',
    ]) {
      expect(find.bySemanticsIdentifier(identifier), findsOneWidget);
    }
    final l10n = lookupS(const Locale('fr'));
    expect(find.text(l10n.extractionReviewConfidence(0)), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.text('0%'), findsNothing);
    _expectNoExternalSideEffects(harness);
  });

  final invalidInputs = <({String name, String date, String year, String key})>[
    (
      name: 'invalid date',
      date: '2026-02-30',
      year: '2026',
      key: 'lpp_regulation_review_source_date_error',
    ),
    (
      name: 'non-canonical date',
      date: '2026/02/03',
      year: '2026',
      key: 'lpp_regulation_review_source_date_error',
    ),
    (
      name: 'future date',
      date: '2026-07-19',
      year: '2026',
      key: 'lpp_regulation_review_source_date_error',
    ),
    (
      name: 'legal year below range',
      date: '2026-02-03',
      year: '1899',
      key: 'lpp_regulation_review_legal_year_error',
    ),
    (
      name: 'legal year above range',
      date: '2026-02-03',
      year: '10000',
      key: 'lpp_regulation_review_legal_year_error',
    ),
  ];
  for (final invalid in invalidInputs) {
    testWidgets('${invalid.name} blocks regulation writers', (tester) async {
      final harness = _harness();
      addTearDown(harness.router.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await _enterReviewValues(
        tester,
        sourceDate: invalid.date,
        legalYear: invalid.year,
      );
      await _confirmReview(tester);

      expect(find.byKey(Key(invalid.key)), findsOneWidget);
      expect(harness.ledger.acceptCalls, 0);
      expect(harness.documents.recordCalls, 0);
      expect(harness.sessions.byId(harness.scanSessionId), isNotNull);
      _expectNoExternalSideEffects(harness);
    });
  }

  final drifts = <String, void Function(_LedgerSpy ledger)>{
    'snapshot drift': (ledger) =>
        ledger.currentSnapshotId = _replacementSnapshotId,
    'reference drift': (ledger) =>
        ledger.currentReferenceId = _replacementReferenceId,
  };
  for (final drift in drifts.entries) {
    testWidgets('${drift.key} blocks before regulation record', (tester) async {
      final harness = _harness();
      addTearDown(harness.router.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();
      drift.value(harness.ledger);

      await _enterReviewValues(tester);
      await _confirmReview(tester);

      expect(harness.ledger.acceptCalls, 1);
      expect(harness.documents.recordCalls, 0);
      expect(harness.sessions.byId(harness.scanSessionId), isNotNull);
      expect(
        find.byKey(const Key('lpp_regulation_review_accept_error')),
        findsOneWidget,
      );
      _expectNoExternalSideEffects(harness);
    });
  }

  testWidgets('accept failure keeps fields editable and never records',
      (tester) async {
    final harness = _harness(failAccept: true);
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enterReviewValues(tester);
    await _confirmReview(tester);

    expect(harness.ledger.acceptCalls, 1);
    expect(harness.documents.recordCalls, 0);
    expect(
      find.byKey(const Key('lpp_regulation_review_accept_error')),
      findsOneWidget,
    );
    for (final key in const <String>[
      'lpp_regulation_review_source_date',
      'lpp_regulation_review_legal_year',
    ]) {
      expect(
          tester.widget<TextFormField>(find.byKey(Key(key))).enabled, isTrue);
    }
    expect(harness.sessions.byId(harness.scanSessionId), isNotNull);
    _expectNoExternalSideEffects(harness);
  });

  testWidgets('record retry reuses the accepted receipt without reaccepting',
      (tester) async {
    final harness = _harness(failRecordCalls: 1);
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enterReviewValues(tester);
    await _confirmReview(tester);

    expect(harness.ledger.acceptCalls, 1);
    expect(harness.documents.recordCalls, 1);
    expect(harness.documents.receipts, hasLength(1));
    expect(
      identical(harness.documents.receipts.single, harness.ledger.receipt),
      isTrue,
    );
    expect(
      find.byKey(const Key('lpp_regulation_reference_retry_state')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('lpp_regulation_reference_retry_cta'),
      findsOneWidget,
    );
    for (final key in const <String>[
      'lpp_regulation_review_source_date',
      'lpp_regulation_review_legal_year',
    ]) {
      expect(
        tester.widget<TextFormField>(find.byKey(Key(key))).enabled,
        isFalse,
      );
    }
    expect(harness.sessions.byId(harness.scanSessionId), isNotNull);

    await tester.tap(
      find.bySemanticsIdentifier('lpp_regulation_reference_retry_cta'),
    );
    await tester.pumpAndSettle();

    expect(harness.ledger.acceptCalls, 1);
    expect(harness.documents.recordCalls, 2);
    expect(
      harness.documents.receipts.every(
        (receipt) => identical(receipt, harness.ledger.receipt),
      ),
      isTrue,
    );
    expect(harness.documents.receipts[1].referenceId, _acceptedReferenceId);
    expect(harness.documents.receipts[1].snapshotId, _snapshotId);
    expect(harness.documents.receipts[1].confirmedAt,
        DateTime.utc(2026, 7, 18, 10));
    expect(harness.sessions.byId(harness.scanSessionId), isNull);
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/retraite',
    );
    _expectNoExternalSideEffects(harness);
  });

  testWidgets(
      'successful review accepts then records and returns to retirement',
      (tester) async {
    final harness = _harness();
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enterReviewValues(tester);
    await _confirmReview(tester);

    expect(harness.events, const <String>['accept', 'record']);
    expect(harness.ledger.acceptCalls, 1);
    expect(harness.documents.recordCalls, 1);
    expect(
      identical(harness.documents.receipts.single, harness.ledger.receipt),
      isTrue,
    );
    final confirmation = harness.ledger.confirmations.single;
    expect(confirmation.ownerKind, LppEvidenceOwnerKind.self);
    expect(confirmation.sourceDate, DateTime.utc(2026, 2, 3));
    expect(confirmation.legalYear, 2026);
    expect(confirmation.expectedSnapshotId, _snapshotId);
    expect(confirmation.expectedPreviousReferenceId, _previousReferenceId);
    expect(harness.sessions.byId(harness.scanSessionId), isNull);
    expect(harness.sessions.discardCalls, greaterThanOrEqualTo(1));
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/retraite',
    );
    expect(
      find.byKey(const Key('lpp_regulation_retirement_destination')),
      findsOneWidget,
    );
    _expectNoExternalSideEffects(harness);
  });
}
