import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:provider/provider.dart';

const _contractId = '11111111-1111-4111-8111-111111111111';
const _previousReferenceId = '22222222-2222-4222-8222-222222222222';
const _authorityId = '33333333-3333-4333-8333-333333333333';
const _acceptedReferenceId = '44444444-4444-4444-8444-444444444444';

const _clauseExtraction = ExtractionResult(
  documentType: DocumentType.pillar3aBeneficiaryClause,
  fields: <ExtractedField>[],
  overallConfidence: 0,
  confidenceDelta: 0,
  warnings: <String>[],
  disclaimer: '',
  sources: <String>[],
);

const _genericBalanceExtraction = ExtractionResult(
  documentType: DocumentType.threeAAttestation,
  fields: <ExtractedField>[
    ExtractedField(
      fieldName: 'pillar3aBalance',
      label: 'Solde',
      value: 42000,
      confidence: 0.99,
      sourceText: '',
      needsReview: false,
      profileField: 'prevoyance.pillar3aTotal',
    ),
  ],
  overallConfidence: 0.99,
  confidenceDelta: 7,
  warnings: <String>[],
  disclaimer: '',
  sources: <String>[],
);

Pillar3aBeneficiaryAuthorityCandidateV1 _authority() =>
    Pillar3aBeneficiaryAuthorityCandidateV1.exactDates(
      schemaVersion: 1,
      documentAuthorityId: _authorityId,
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

Pillar3aBeneficiaryAcquisitionCandidate _candidate() =>
    Pillar3aBeneficiaryAcquisitionCandidate(
      contractReferenceId: _contractId,
      authority: _authority(),
      expectedPreviousReferenceId: _previousReferenceId,
    );

final class _LedgerSpy extends CoachProfileProvider {
  _LedgerSpy({required this.events, this.failAccept = false});

  final List<String> events;
  bool failAccept;
  int acceptCalls = 0;
  final confirmations = <Pillar3aBeneficiaryReviewConfirmation>[];
  final receipt = Pillar3aBeneficiaryReceipt(
    referenceId: _acceptedReferenceId,
    contractReferenceId: _contractId,
    documentAuthorityId: _authorityId,
    confirmedAt: DateTime.utc(2026, 7, 19, 10),
  );

  @override
  CoachProfile get profile => CoachProfile.defaults();

  @override
  bool get hasProfile => true;

  @override
  bool get isLoaded => true;

  @override
  Future<Pillar3aBeneficiaryReceipt> acceptPillar3aBeneficiaryReview(
    Pillar3aBeneficiaryReviewConfirmation confirmation,
  ) async {
    acceptCalls += 1;
    confirmations.add(confirmation);
    events.add('accept');
    if (failAccept ||
        confirmation.contractReferenceId != _contractId ||
        confirmation.documentAuthorityId != _authorityId ||
        confirmation.expectedPreviousReferenceId != _previousReferenceId) {
      throw StateError('synthetic pillar 3a accept failure');
    }
    return receipt;
  }
}

final class _DocumentSpy extends DocumentProvider {
  _DocumentSpy({required this.events, this.failRecordCalls = 0});

  final List<String> events;
  int failRecordCalls;
  int recordCalls = 0;
  final receipts = <Pillar3aBeneficiaryReceipt>[];

  @override
  Future<ConfirmedDocumentReference> recordPillar3aBeneficiaryEvidence(
    Pillar3aBeneficiaryReceipt receipt,
  ) async {
    recordCalls += 1;
    receipts.add(receipt);
    events.add('record');
    if (recordCalls <= failRecordCalls) {
      throw StateError('synthetic pillar 3a BND failure');
    }
    return ConfirmedDocumentReference(
      referenceId: receipt.referenceId,
      kind: Pillar3aBeneficiaryEvidence.kind,
      contractReferenceId: receipt.contractReferenceId,
      documentAuthorityId: receipt.documentAuthorityId,
      ownerKind: LppEvidenceOwnerKind.self,
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
  int discardCalls = 0;

  @override
  void discard(String id) {
    discardCalls += 1;
    super.discard(id);
  }
}

final class _Harness {
  const _Harness({
    required this.widget,
    required this.router,
    required this.ledger,
    required this.documents,
    required this.biography,
    required this.sessions,
    required this.syncCalls,
    required this.events,
  });

  final Widget widget;
  final GoRouter router;
  final _LedgerSpy ledger;
  final _DocumentSpy documents;
  final _BiographySpy biography;
  final _ScanSessionSpy sessions;
  final List<int> syncCalls;
  final List<String> events;
}

_Harness _harness({
  bool withCandidate = true,
  bool genericBalanceOnly = false,
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
  final extraction =
      genericBalanceOnly ? _genericBalanceExtraction : _clauseExtraction;
  final candidate = withCandidate ? _candidate() : null;
  final scanSessionId = withCandidate
      ? sessions.retainExtraction(
          extraction,
          pillar3aBeneficiaryCandidate: candidate,
        )
      : 'missing-pillar3a-session';
  late final GoRouter router;
  router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, __) => ExtractionReviewScreen(
          scanSessionId: scanSessionId,
          result: extraction,
          pillar3aBeneficiaryCandidate: candidate,
          now: () => DateTime.utc(2026, 7, 19, 10),
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
          key: Key('pillar3a_review_destination'),
        ),
      ),
    ],
  );
  return _Harness(
    router: router,
    ledger: ledger,
    documents: documents,
    biography: biography,
    sessions: sessions,
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

Future<void> _chooseRelation(
  WidgetTester tester,
  String relation,
) async {
  final choice = find.bySemanticsIdentifier(
    'pillar3a_beneficiary_relation_$relation',
  );
  expect(choice, findsOneWidget);
  await tester.ensureVisible(choice);
  await tester.tap(choice);
  await tester.pump();
}

Future<void> _confirm(WidgetTester tester) async {
  final cta = find.byKey(const Key('pillar3a_beneficiary_confirm_cta'));
  expect(cta, findsOneWidget);
  await tester.ensureVisible(cta);
  await tester.tap(cta);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
    FeatureFlags.typedLppEvidence = false;
  });

  test('production review route forwards the exact volatile clause candidate',
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
        'pillar3aBeneficiaryCandidate: '
        'session.pillar3aBeneficiaryCandidate',
      ),
    );
  });

  testWidgets(
      'flag-off, generic 3a, and exact-type without authority never expose a writer',
      (tester) async {
    for (final scenario
        in <({bool flagEnabled, bool withCandidate, bool genericBalanceOnly})>[
      (
        flagEnabled: false,
        withCandidate: true,
        genericBalanceOnly: false,
      ),
      (
        flagEnabled: true,
        withCandidate: false,
        genericBalanceOnly: true,
      ),
      (
        flagEnabled: true,
        withCandidate: false,
        genericBalanceOnly: false,
      ),
    ]) {
      FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled =
          scenario.flagEnabled;
      final harness = _harness(
        withCandidate: scenario.withCandidate,
        genericBalanceOnly: scenario.genericBalanceOnly,
      );
      addTearDown(harness.router.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pillar3a_beneficiary_confirm_cta')),
        findsNothing,
      );
      expect(harness.ledger.acceptCalls, 0);
      expect(harness.documents.recordCalls, 0);
      expect(harness.syncCalls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
      'review keeps contract and authority immutable and relation empty',
      (tester) async {
    final harness = _harness();
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(find.text(_contractId), findsNothing);
    expect(find.text(_authorityId), findsNothing);
    expect(
      find.byKey(const Key('pillar3a_beneficiary_contract_reference_field')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('pillar3a_beneficiary_document_authority_field')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('pillar3a_beneficiary_name_field')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('pillar3a_beneficiary_rank_field')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('pillar3a_beneficiary_share_field')),
      findsNothing,
    );
    await _confirm(tester);
    expect(harness.ledger.acceptCalls, 0);
    expect(harness.documents.recordCalls, 0);

    await _chooseRelation(tester, 'current_active_unpaid');
    await _confirm(tester);

    expect(harness.events, <String>['accept', 'record']);
    final confirmation = harness.ledger.confirmations.single;
    expect(confirmation.contractReferenceId, _contractId);
    expect(confirmation.documentAuthorityId, _authorityId);
    expect(confirmation.expectedPreviousReferenceId, _previousReferenceId);
    expect(
      confirmation.relation,
      Pillar3aBeneficiaryRelation.currentActiveUnpaid,
    );
    expect(confirmation.sourceDate, DateTime.utc(2026, 7, 18));
    expect(confirmation.legalYear, 2026);
    expect(
      confirmation.temporalBasis.toJson(),
      <String, Object?>{
        'kind': 'exactDates',
        'designationEffectiveDate': '2026-01-15',
        'lastAssignmentModificationDate': null,
      },
    );
    expect(harness.documents.receipts.single, same(harness.ledger.receipt));
    expect(harness.biography.writes, 0);
    expect(harness.syncCalls, isEmpty);
    expect(
        find.byKey(const Key('pillar3a_review_destination')), findsOneWidget);
  });

  testWidgets('paid or closed confirms no temporal basis then records BND',
      (tester) async {
    final harness = _harness();
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _chooseRelation(tester, 'paid_or_closed');
    await _confirm(tester);

    expect(harness.events, <String>['accept', 'record']);
    final confirmation = harness.ledger.confirmations.single;
    expect(confirmation.relation, Pillar3aBeneficiaryRelation.paidOrClosed);
    expect(confirmation.temporalBasis, isNull);
    expect(confirmation.sourceDate, DateTime.utc(2026, 7, 18));
    expect(confirmation.legalYear, 2026);
    expect(harness.documents.receipts.single, same(harness.ledger.receipt));
    expect(harness.biography.writes, 0);
    expect(harness.syncCalls, isEmpty);
  });

  testWidgets('Swiss no-advice copy gives institution then legal handoff',
      (tester) async {
    final harness = _harness();
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(find.textContaining('Ce document est référencé'), findsOneWidget);
    expect(
      find.textContaining(
        'MINT ne valide ni la portée juridique, ni le rang, ni les quotes-parts',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'votre institution 3a, puis un notaire ou juriste successoral',
      ),
      findsOneWidget,
    );

    await _chooseRelation(tester, 'uncertain');
    expect(
      find.textContaining(
        'demandez une confirmation écrite à votre institution 3a',
      ),
      findsOneWidget,
    );
    expect(harness.ledger.acceptCalls, 0);
    expect(harness.documents.recordCalls, 0);
    expect(harness.biography.writes, 0);
    expect(harness.syncCalls, isEmpty);
  });

  testWidgets('accept failure keeps review editable and never records',
      (tester) async {
    final harness = _harness(failAccept: true);
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _chooseRelation(tester, 'uncertain');
    await _confirm(tester);

    expect(harness.ledger.acceptCalls, 1);
    expect(harness.documents.recordCalls, 0);
    expect(
      find.byKey(const Key('pillar3a_beneficiary_confirm_cta')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('pillar3a_review_destination')), findsNothing);
  });

  testWidgets('BND retry reuses receipt without repeating ledger acceptance',
      (tester) async {
    final harness = _harness(failRecordCalls: 1);
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await _chooseRelation(tester, 'current_active_unpaid');
    await _confirm(tester);

    expect(harness.events, <String>['accept', 'record']);
    final retry = find.byKey(
      const Key('pillar3a_beneficiary_record_retry_cta'),
    );
    expect(retry, findsOneWidget);
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(harness.events, <String>['accept', 'record', 'record']);
    expect(harness.ledger.acceptCalls, 1);
    expect(
        harness.documents.receipts, everyElement(same(harness.ledger.receipt)));
    expect(
        find.byKey(const Key('pillar3a_review_destination')), findsOneWidget);
  });
}
