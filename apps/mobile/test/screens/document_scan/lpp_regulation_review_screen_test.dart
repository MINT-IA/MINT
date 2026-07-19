import 'dart:io';
import 'dart:ui' show SemanticsAction;

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
const _previousCapitalNoticeId = '66666666-6666-4666-8666-666666666666';
const _acceptedCapitalNoticeId = '77777777-7777-4777-8777-777777777777';

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

LppRegulationAcquisitionCandidate _regulationCandidate({
  String? expectedPreviousReferenceId = _previousReferenceId,
}) {
  try {
    return Function.apply(
      LppRegulationAcquisitionCandidate.new,
      const <Object?>[],
      <Symbol, Object?>{
        if (expectedPreviousReferenceId != null)
          #expectedPreviousReferenceId: expectedPreviousReferenceId,
      },
    ) as LppRegulationAcquisitionCandidate;
  } on NoSuchMethodError {
    // RED compatibility bridge for the removed schema-1 snapshot argument.
    return Function.apply(
      LppRegulationAcquisitionCandidate.new,
      const <Object?>[],
      <Symbol, Object?>{
        #expectedSnapshotId: _snapshotId,
        if (expectedPreviousReferenceId != null)
          #expectedPreviousReferenceId: expectedPreviousReferenceId,
      },
    ) as LppRegulationAcquisitionCandidate;
  }
}

final _candidate = _regulationCandidate();

final _capitalCandidate = LppCapitalNoticeAcquisitionCandidate(
  expectedSnapshotId: _snapshotId,
  expectedPreviousReferenceId: _previousCapitalNoticeId,
);

LppEvidenceSnapshot _snapshot({
  required String snapshotId,
  String? capitalNoticeReferenceId = _previousCapitalNoticeId,
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
    lppCapitalNoticeDeadline: capitalNoticeReferenceId == null
        ? null
        : LppCapitalNoticeDeadline.create(
            referenceId: capitalNoticeReferenceId,
            authorityReferenceId: _acceptedReferenceId,
            sourceDate: DateTime.utc(2026, 2, 3),
            legalYear: 2026,
            confirmedAt: updatedAt,
            deadlineDate: DateTime.utc(2026, 12, 31),
          ),
  );
}

LppRegulationReceipt _regulationReceipt() {
  final named = <Symbol, Object?>{
    #referenceId: _acceptedReferenceId,
    #confirmedAt: DateTime.utc(2026, 7, 18, 10),
  };
  try {
    return Function.apply(
      LppRegulationReceipt.new,
      const <Object?>[],
      named,
    ) as LppRegulationReceipt;
  } on NoSuchMethodError {
    return Function.apply(
      LppRegulationReceipt.new,
      const <Object?>[],
      <Symbol, Object?>{...named, #snapshotId: _snapshotId},
    ) as LppRegulationReceipt;
  }
}

final _capitalReceipt = LppCapitalNoticeReceipt(
  referenceId: _acceptedCapitalNoticeId,
  authorityReferenceId: _acceptedReferenceId,
  snapshotId: _snapshotId,
  confirmedAt: DateTime.utc(2026, 7, 18, 10),
);

ConfirmedDocumentReference _confirmedRegulationReference(
  LppRegulationReceipt receipt,
) {
  final dynamic typedReceipt = receipt;
  String? snapshotId;
  try {
    snapshotId = typedReceipt.snapshotId as String;
  } on NoSuchMethodError {
    snapshotId = null;
  }
  return Function.apply(
    ConfirmedDocumentReference.new,
    const <Object?>[],
    <Symbol, Object?>{
      #referenceId: receipt.referenceId,
      #kind: ConfirmedDocumentReference.lppRegulationKind,
      #snapshotId: snapshotId,
      #ownerKind: receipt.ownerKind,
      #confirmedAt: receipt.confirmedAt,
    },
  ) as ConfirmedDocumentReference;
}

final class _LedgerSpy extends CoachProfileProvider {
  _LedgerSpy({
    required this.events,
    this.failAccept = false,
    this.failCapitalAccept = false,
  });

  final List<String> events;
  bool failAccept;
  bool failCapitalAccept;
  String currentSnapshotId = _snapshotId;
  String currentReferenceId = _previousReferenceId;
  String? currentCapitalNoticeId = _previousCapitalNoticeId;
  int acceptCalls = 0;
  int capitalAcceptCalls = 0;
  final confirmations = <LppRegulationReviewConfirmation>[];
  final capitalConfirmations = <LppCapitalNoticeReviewConfirmation>[];
  final receipt = _regulationReceipt();

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
              capitalNoticeReferenceId: currentCapitalNoticeId,
            )
          : null;

  @override
  Future<LppRegulationReceipt> acceptLppRegulationReference(
    LppRegulationReviewConfirmation confirmation,
  ) async {
    acceptCalls += 1;
    confirmations.add(confirmation);
    events.add('accept');
    final dynamic typedConfirmation = confirmation;
    if (failAccept ||
        typedConfirmation.expectedPreviousReferenceId != currentReferenceId) {
      throw StateError('synthetic regulation accept failure');
    }
    return receipt;
  }

  @override
  Future<LppCapitalNoticeReceipt> acceptLppCapitalNotice(
    LppCapitalNoticeReviewConfirmation confirmation,
  ) async {
    capitalAcceptCalls += 1;
    capitalConfirmations.add(confirmation);
    events.add('accept-capital');
    if (failCapitalAccept ||
        confirmation.expectedSnapshotId != currentSnapshotId ||
        confirmation.expectedPreviousReferenceId != currentCapitalNoticeId ||
        confirmation.authorityReferenceId != receipt.referenceId) {
      throw StateError('synthetic capital accept failure');
    }
    return _capitalReceipt;
  }
}

final class _DocumentSpy extends DocumentProvider {
  _DocumentSpy({
    required this.events,
    this.failRecordCalls = 0,
    this.failCapitalRecordCalls = 0,
    this.afterRegulationRecord,
  });

  final List<String> events;
  int failRecordCalls;
  int failCapitalRecordCalls;
  final void Function()? afterRegulationRecord;
  int recordCalls = 0;
  int capitalRecordCalls = 0;
  final receipts = <LppRegulationReceipt>[];
  final capitalReceipts = <LppCapitalNoticeReceipt>[];

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
    afterRegulationRecord?.call();
    return _confirmedRegulationReference(receipt);
  }

  @override
  Future<ConfirmedDocumentReference> recordLppCapitalNotice(
    LppCapitalNoticeReceipt receipt,
  ) async {
    capitalRecordCalls += 1;
    capitalReceipts.add(receipt);
    events.add('record-capital');
    if (capitalRecordCalls <= failCapitalRecordCalls) {
      throw StateError('synthetic capital record failure');
    }
    return ConfirmedDocumentReference(
      referenceId: receipt.referenceId,
      kind: ConfirmedDocumentReference.lppCapitalNoticeKind,
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
  required LppCapitalNoticeAcquisitionCandidate? capitalCandidate,
  required ScanConfirmationSender sendScanConfirmation,
}) {
  const constructor = ExtractionReviewScreen.new;
  final named = <Symbol, dynamic>{
    #scanSessionId: scanSessionId,
    #result: _planExtraction,
    #lppRegulationCandidate: candidate,
    #lppCapitalNoticeCandidate: capitalCandidate,
    #sendScanConfirmation: sendScanConfirmation,
    #now: () => DateTime.utc(2026, 7, 18, 10),
  };
  try {
    return Function.apply(constructor, const <dynamic>[], named) as Widget;
  } on NoSuchMethodError {
    // RED compatibility bridge: current production has not added the bounded
    // candidate parameter yet. Once it does, the first call above is used.
    named.remove(#lppRegulationCandidate);
    named.remove(#lppCapitalNoticeCandidate);
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
  bool withCapitalCandidate = false,
  bool failAccept = false,
  bool failCapitalAccept = false,
  int failRecordCalls = 0,
  int failCapitalRecordCalls = 0,
  void Function(_LedgerSpy ledger)? afterRegulationRecord,
}) {
  final events = <String>[];
  final ledger = _LedgerSpy(
    events: events,
    failAccept: failAccept,
    failCapitalAccept: failCapitalAccept,
  );
  final documents = _DocumentSpy(
    events: events,
    failRecordCalls: failRecordCalls,
    failCapitalRecordCalls: failCapitalRecordCalls,
    afterRegulationRecord: afterRegulationRecord == null
        ? null
        : () => afterRegulationRecord(ledger),
  );
  final biography = _BiographySpy();
  final sessions = _ScanSessionSpy();
  final syncCalls = <int>[];
  final scanSessionId = withCandidate
      ? sessions.retainExtraction(
          _planExtraction,
          lppRegulationCandidate: _candidate,
          lppCapitalNoticeCandidate:
              withCapitalCandidate ? _capitalCandidate : null,
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
          capitalCandidate:
              withCandidate && withCapitalCandidate ? _capitalCandidate : null,
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

Future<void> _chooseFundRelationship(
  WidgetTester tester, {
  String relationship = 'uncertain',
}) async {
  final choice = find.bySemanticsIdentifier(
    'lpp_regulation_fund_relation_$relationship',
  );
  expect(choice, findsOneWidget);
  await tester.ensureVisible(choice);
  await tester.tap(choice);
  await tester.pump();
}

void _expectFundRelationshipControlsEnabled(
  WidgetTester tester, {
  required bool enabled,
}) {
  for (final relationship in const <String>[
    'current',
    'uncertain',
    'former_or_other',
  ]) {
    final control = find.bySemanticsIdentifier(
      'lpp_regulation_fund_relation_$relationship',
    );
    expect(control, findsOneWidget, reason: relationship);
    expect(
      tester
          .getSemantics(control)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      enabled,
      reason: '$relationship must be ${enabled ? 'editable' : 'frozen'}',
    );
  }
}

Future<void> _enterReviewValues(
  WidgetTester tester, {
  String sourceDate = '2026-02-03',
  String legalYear = '2026',
  String? relationship = 'uncertain',
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
  if (relationship != null) {
    await _chooseFundRelationship(tester, relationship: relationship);
  }
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

Future<void> _enterCapitalDeadline(
  WidgetTester tester,
  String value,
) async {
  final field = find.bySemanticsIdentifier(
    'lpp_capital_notice_deadline_field',
  );
  expect(field, findsOneWidget);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
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
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
  });

  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.documentLppEvidenceEnabled = false;
    FeatureFlags.lppRegulationReferenceEnabled = false;
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
  });

  test('production review route forwards the volatile regulation candidate',
      () {
    final source = File('lib/app.dart').readAsStringSync();
    final reviewStart = source.indexOf("path: '/scan/review'");
    final impactStart = source.indexOf("path: '/scan/impact'", reviewStart);
    final reviewBuilderStart = source.indexOf(
      'Widget _buildScanReviewRoute(BuildContext context, Uri uri)',
    );
    final impactBuilderStart = source.indexOf(
      'Widget _buildScanImpactRoute(BuildContext context, Uri uri)',
      reviewBuilderStart,
    );
    expect(reviewStart, greaterThanOrEqualTo(0));
    expect(impactStart, greaterThan(reviewStart));
    expect(reviewBuilderStart, greaterThanOrEqualTo(0));
    expect(impactBuilderStart, greaterThan(reviewBuilderStart));
    final reviewRoute = source.substring(reviewStart, impactStart);
    final reviewBuilder = source.substring(
      reviewBuilderStart,
      impactBuilderStart,
    );

    expect(
      reviewRoute,
      contains('_buildScanReviewRoute(context, state.uri)'),
    );

    expect(
      reviewBuilder,
      contains(
        'lppRegulationCandidate: session.lppRegulationCandidate',
      ),
    );
    expect(
      reviewBuilder,
      contains(
        'lppCapitalNoticeCandidate: session.lppCapitalNoticeCandidate',
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
    final screenL10n = S.of(
      tester.element(
        find.byKey(const Key('lpp_regulation_review_screen')),
      ),
    )!;
    expect(find.byType(TextFormField), findsNWidgets(2));
    for (final identifier in const <String>[
      'lpp_regulation_review_source_date',
      'lpp_regulation_review_legal_year',
      'lpp_regulation_fund_relation_current',
      'lpp_regulation_fund_relation_uncertain',
      'lpp_regulation_fund_relation_former_or_other',
      'lpp_regulation_review_confirm_cta',
    ]) {
      expect(find.bySemanticsIdentifier(identifier), findsOneWidget);
    }
    expect(find.text(screenL10n.lppRegulationReviewTitle), findsOneWidget);
    expect(
      find.text('D’après toi, de quelle caisse vient ce règlement ?'),
      findsOneWidget,
    );
    for (final choice in const <String>[
      'Ma caisse actuelle',
      'Je ne sais pas',
      'Une ancienne ou autre caisse',
    ]) {
      expect(find.text(choice), findsOneWidget, reason: choice);
    }
    for (final identifier in const <String>[
      'lpp_regulation_fund_relation_current',
      'lpp_regulation_fund_relation_uncertain',
      'lpp_regulation_fund_relation_former_or_other',
    ]) {
      final node = tester.getSemantics(find.bySemanticsIdentifier(identifier));
      expect(
        node.flagsCollection.isChecked.name,
        'isFalse',
        reason: 'no relationship may be selected by default',
      );
    }
    expect(
      find.byKey(const Key('lpp_regulation_fund_name')),
      findsNothing,
      reason: 'G1 records no fund name and performs no automatic matching',
    );
    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .join('\n')
        .toLowerCase();
    expect(rendered, contains('déclaration datée'));
    expect(rendered, contains('non vérifiée'));
    final l10n = lookupS(const Locale('fr'));
    expect(find.text(l10n.extractionReviewConfidence(0)), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.text('0%'), findsNothing);
    _expectNoExternalSideEffects(harness);
  });

  testWidgets('relationship is mandatory and has no inferred default',
      (tester) async {
    final harness = _harness();
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enterReviewValues(tester, relationship: null);
    await _confirmReview(tester);

    expect(
      find.text(
        'Choisis l’une des trois réponses pour enregistrer la déclaration.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('lpp_regulation_fund_relation_required_error'),
      ),
      findsOneWidget,
    );
    expect(harness.ledger.acceptCalls, 0);
    expect(harness.documents.recordCalls, 0);
    expect(harness.sessions.byId(harness.scanSessionId), isNotNull);
    _expectNoExternalSideEffects(harness);
  });

  for (final relationship in const <({String control, String wire})>[
    (control: 'current', wire: 'currentFund'),
    (control: 'uncertain', wire: 'uncertain'),
    (control: 'former_or_other', wire: 'formerOrOther'),
  ]) {
    testWidgets(
        '${relationship.control} writes the exact fund relationship wire value',
        (tester) async {
      final harness = _harness();
      addTearDown(harness.router.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await _enterReviewValues(
        tester,
        relationship: relationship.control,
      );
      await _confirmReview(tester);

      expect(harness.ledger.acceptCalls, 1);
      expect(harness.documents.recordCalls, 1);
      final dynamic confirmation = harness.ledger.confirmations.single;
      expect(confirmation.fundRelationship.wireName, relationship.wire);
      expect(harness.sessions.byId(harness.scanSessionId), isNull);
      _expectNoExternalSideEffects(harness);
    });
  }

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

  testWidgets('numeric snapshot drift does not block regulation acceptance',
      (tester) async {
    final harness = _harness();
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    harness.ledger.currentSnapshotId = _replacementSnapshotId;

    await _enterReviewValues(tester);
    await _confirmReview(tester);

    expect(harness.events, const <String>['accept', 'record']);
    expect(harness.ledger.acceptCalls, 1);
    expect(harness.documents.recordCalls, 1);
    expect(harness.sessions.byId(harness.scanSessionId), isNull);
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/retraite',
    );
    _expectNoExternalSideEffects(harness);
  });

  testWidgets('previous autonomous reference drift blocks before record',
      (tester) async {
    final harness = _harness();
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    harness.ledger.currentReferenceId = _replacementReferenceId;

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
    _expectFundRelationshipControlsEnabled(tester, enabled: true);
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
    _expectFundRelationshipControlsEnabled(tester, enabled: false);
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
    final dynamic retriedReceipt = harness.documents.receipts[1];
    expect(
      () => retriedReceipt.snapshotId,
      throwsA(isA<NoSuchMethodError>()),
      reason: 'regulation receipt must not carry numeric snapshot identity',
    );
    expect(
      harness.documents.receipts[1].confirmedAt,
      DateTime.utc(2026, 7, 18, 10),
    );
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
    final dynamic confirmation = harness.ledger.confirmations.single;
    expect(confirmation.ownerKind, LppEvidenceOwnerKind.self);
    expect(confirmation.sourceDate, DateTime.utc(2026, 2, 3));
    expect(confirmation.legalYear, 2026);
    expect(confirmation.fundRelationship.wireName, 'uncertain');
    expect(
      () => confirmation.expectedSnapshotId,
      throwsA(isA<NoSuchMethodError>()),
      reason: 'confirmation is bound only to the previous regulation reference',
    );
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

  testWidgets(
      'capital question is optional and visible only for declared current fund',
      (tester) async {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final harness = _harness(withCapitalCandidate: true);
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('lpp_capital_notice_deadline_question'),
      findsNothing,
    );
    await _enterReviewValues(tester, relationship: 'uncertain');
    expect(
      find.bySemanticsIdentifier('lpp_capital_notice_deadline_question'),
      findsNothing,
    );
    await _chooseFundRelationship(tester, relationship: 'current');

    for (final identifier in const <String>[
      'lpp_capital_notice_deadline_question',
      'lpp_capital_notice_deadline_field',
      'lpp_capital_notice_deadline_hint',
    ]) {
      expect(find.bySemanticsIdentifier(identifier), findsOneWidget);
    }
    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .join('\n')
        .toLowerCase();
    expect(rendered, contains('non vérifiée'));
    expect(rendered, contains('date civile complète'));
    expect(rendered, contains('délai relatif'));
    expect(rendered, contains('institution'));
    expect(rendered, contains('droit perdu'));
    expect(rendered, contains('option acceptée'));
    expect(rendered, contains('pas un conseil'));
  });

  testWidgets('uncertain or former fund never calls capital writers',
      (tester) async {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    for (final relationship in const <String>['uncertain', 'former_or_other']) {
      final harness = _harness(withCapitalCandidate: true);
      addTearDown(harness.router.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await _enterReviewValues(tester, relationship: relationship);
      expect(
        find.bySemanticsIdentifier('lpp_capital_notice_deadline_field'),
        findsNothing,
      );
      await _confirmReview(tester);

      expect(harness.ledger.capitalAcceptCalls, 0, reason: relationship);
      expect(harness.documents.capitalRecordCalls, 0, reason: relationship);
      expect(harness.events, const <String>['accept', 'record']);
      _expectNoExternalSideEffects(harness);
    }
  });

  testWidgets(
      'exact absolute date writes regulation then authority-bound capital',
      (tester) async {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final harness = _harness(withCapitalCandidate: true);
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enterReviewValues(tester, relationship: 'current');
    await _enterCapitalDeadline(tester, '2026-11-30');
    await _confirmReview(tester);

    expect(
      harness.events,
      const <String>[
        'accept',
        'record',
        'accept-capital',
        'record-capital',
      ],
    );
    expect(harness.ledger.acceptCalls, 1);
    expect(harness.documents.recordCalls, 1);
    expect(harness.ledger.capitalAcceptCalls, 1);
    expect(harness.documents.capitalRecordCalls, 1);
    final confirmation = harness.ledger.capitalConfirmations.single;
    expect(confirmation.ownerKind, LppEvidenceOwnerKind.self);
    expect(confirmation.authorityReferenceId, _acceptedReferenceId);
    expect(confirmation.sourceDate, DateTime.utc(2026, 2, 3));
    expect(confirmation.legalYear, 2026);
    expect(confirmation.deadlineDate, DateTime.utc(2026, 11, 30));
    expect(confirmation.expectedSnapshotId, _snapshotId);
    expect(
      confirmation.expectedPreviousReferenceId,
      _previousCapitalNoticeId,
    );
    expect(
      identical(harness.documents.capitalReceipts.single, _capitalReceipt),
      isTrue,
    );
    expect(harness.sessions.byId(harness.scanSessionId), isNull);
    expect(harness.router.routeInformationProvider.value.uri.path, '/retraite');
    _expectNoExternalSideEffects(harness);
  });

  testWidgets('empty deadline records regulation only', (tester) async {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final harness = _harness(withCapitalCandidate: true);
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enterReviewValues(tester, relationship: 'current');
    await _confirmReview(tester);

    expect(harness.events, const <String>['accept', 'record']);
    expect(harness.ledger.capitalAcceptCalls, 0);
    expect(harness.documents.capitalRecordCalls, 0);
    expect(harness.sessions.byId(harness.scanSessionId), isNull);
    expect(harness.router.routeInformationProvider.value.uri.path, '/retraite');
    _expectNoExternalSideEffects(harness);
  });

  for (final deadline in const <String>[
    'dans 6 mois',
    '30.11.2026',
    '2026/11/30',
    '2026-02-30',
  ]) {
    testWidgets('rejected deadline "$deadline" exposes explicit partial state',
        (tester) async {
      FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
      final harness = _harness(withCapitalCandidate: true);
      addTearDown(harness.router.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await _enterReviewValues(tester, relationship: 'current');
      await _enterCapitalDeadline(tester, deadline);
      await _confirmReview(tester);

      expect(harness.events, const <String>['accept', 'record']);
      expect(harness.ledger.capitalAcceptCalls, 0);
      expect(harness.documents.capitalRecordCalls, 0);
      expect(harness.sessions.byId(harness.scanSessionId), isNotNull);
      expect(harness.router.routeInformationProvider.value.uri.path, '/');
      expect(
        find.byKey(const Key('lpp_capital_notice_partial_state')),
        findsOneWidget,
      );
      final continueCta = find.bySemanticsIdentifier(
        'lpp_capital_notice_continue_without_deadline_cta',
      );
      expect(continueCta, findsOneWidget);

      await tester.ensureVisible(continueCta);
      await tester.pump();
      await tester.tap(continueCta);
      await tester.pumpAndSettle();

      expect(harness.ledger.capitalAcceptCalls, 0);
      expect(harness.documents.capitalRecordCalls, 0);
      expect(harness.sessions.byId(harness.scanSessionId), isNull);
      expect(
          harness.router.routeInformationProvider.value.uri.path, '/retraite');
      _expectNoExternalSideEffects(harness);
    });
  }

  testWidgets('capital flag drift records regulation only without capital UI',
      (tester) async {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
    final harness = _harness(withCapitalCandidate: true);
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enterReviewValues(tester, relationship: 'current');
    expect(
      find.bySemanticsIdentifier('lpp_capital_notice_deadline_field'),
      findsNothing,
    );
    await _confirmReview(tester);

    expect(harness.events, const <String>['accept', 'record']);
    expect(harness.ledger.capitalAcceptCalls, 0);
    expect(harness.documents.capitalRecordCalls, 0);
    _expectNoExternalSideEffects(harness);
  });

  testWidgets(
      'snapshot drift after regulation record exposes explicit partial state',
      (tester) async {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final harness = _harness(
      withCapitalCandidate: true,
      afterRegulationRecord: (ledger) {
        ledger.currentSnapshotId = _replacementSnapshotId;
      },
    );
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enterReviewValues(tester, relationship: 'current');
    await _enterCapitalDeadline(tester, '2026-11-30');
    await _confirmReview(tester);

    expect(harness.events, const <String>['accept', 'record']);
    expect(harness.ledger.capitalAcceptCalls, 0);
    expect(harness.documents.capitalRecordCalls, 0);
    expect(
      find.byKey(const Key('lpp_capital_notice_partial_state')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier(
        'lpp_capital_notice_continue_without_deadline_cta',
      ),
      findsOneWidget,
    );
    expect(harness.sessions.byId(harness.scanSessionId), isNotNull);
    expect(harness.router.routeInformationProvider.value.uri.path, '/');
    _expectNoExternalSideEffects(harness);
  });

  testWidgets('capital accept failure stays partial until explicit continue',
      (tester) async {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final harness = _harness(
      withCapitalCandidate: true,
      failCapitalAccept: true,
    );
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enterReviewValues(tester, relationship: 'current');
    await _enterCapitalDeadline(tester, '2026-11-30');
    await _confirmReview(tester);

    expect(
      harness.events,
      const <String>['accept', 'record', 'accept-capital'],
    );
    expect(harness.ledger.capitalAcceptCalls, 1);
    expect(harness.documents.capitalRecordCalls, 0);
    expect(harness.sessions.byId(harness.scanSessionId), isNotNull);
    final continueCta = find.bySemanticsIdentifier(
      'lpp_capital_notice_continue_without_deadline_cta',
    );
    expect(continueCta, findsOneWidget);

    await tester.ensureVisible(continueCta);
    await tester.pump();
    await tester.tap(continueCta);
    await tester.pumpAndSettle();

    expect(harness.ledger.capitalAcceptCalls, 1);
    expect(harness.documents.capitalRecordCalls, 0);
    expect(harness.sessions.byId(harness.scanSessionId), isNull);
    expect(harness.router.routeInformationProvider.value.uri.path, '/retraite');
    _expectNoExternalSideEffects(harness);
  });

  testWidgets('capital record retry never reaccepts either ledger write',
      (tester) async {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final harness = _harness(
      withCapitalCandidate: true,
      failCapitalRecordCalls: 1,
    );
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enterReviewValues(tester, relationship: 'current');
    await _enterCapitalDeadline(tester, '2026-11-30');
    await _confirmReview(tester);

    expect(harness.ledger.acceptCalls, 1);
    expect(harness.documents.recordCalls, 1);
    expect(harness.ledger.capitalAcceptCalls, 1);
    expect(harness.documents.capitalRecordCalls, 1);
    expect(
      find.byKey(const Key('lpp_capital_notice_record_retry_state')),
      findsOneWidget,
    );
    final retry = find.bySemanticsIdentifier(
      'lpp_capital_notice_record_retry_cta',
    );
    expect(retry, findsOneWidget);
    expect(harness.sessions.byId(harness.scanSessionId), isNotNull);

    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(harness.ledger.acceptCalls, 1);
    expect(harness.documents.recordCalls, 1);
    expect(harness.ledger.capitalAcceptCalls, 1);
    expect(harness.documents.capitalRecordCalls, 2);
    expect(
      harness.documents.capitalReceipts.every(
        (receipt) => identical(receipt, _capitalReceipt),
      ),
      isTrue,
    );
    expect(harness.sessions.byId(harness.scanSessionId), isNull);
    expect(harness.router.routeInformationProvider.value.uri.path, '/retraite');
    _expectNoExternalSideEffects(harness);
  });

  testWidgets('regulation record retry precedes one capital accept',
      (tester) async {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    final harness = _harness(
      withCapitalCandidate: true,
      failRecordCalls: 1,
    );
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _enterReviewValues(tester, relationship: 'current');
    await _enterCapitalDeadline(tester, '2026-11-30');
    await _confirmReview(tester);
    expect(harness.events, const <String>['accept', 'record']);

    await tester.tap(
      find.bySemanticsIdentifier('lpp_regulation_reference_retry_cta'),
    );
    await tester.pumpAndSettle();

    expect(
      harness.events,
      const <String>[
        'accept',
        'record',
        'record',
        'accept-capital',
        'record-capital',
      ],
    );
    expect(harness.ledger.acceptCalls, 1);
    expect(harness.documents.recordCalls, 2);
    expect(harness.ledger.capitalAcceptCalls, 1);
    expect(harness.documents.capitalRecordCalls, 1);
    _expectNoExternalSideEffects(harness);
  });
}
