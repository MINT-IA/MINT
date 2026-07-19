import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_consumer.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

final class _DashboardLedger extends CoachProfileProvider {
  _DashboardLedger(
    this.value, {
    this.ledgerState = Pillar3aBeneficiaryLedgerState.missing,
    this.root,
    this.loading = false,
  });

  final CoachProfile? value;
  final Pillar3aBeneficiaryLedgerState ledgerState;
  Pillar3aBeneficiaryEvidenceRoot? root;
  final bool loading;

  @override
  CoachProfile? get profile => value;

  @override
  bool get hasProfile => value != null;

  @override
  bool get isLoaded => true;

  @override
  bool get isLoading => loading;

  @override
  Pillar3aBeneficiaryLedgerState get pillar3aBeneficiaryLedgerState =>
      ledgerState;

  @override
  Pillar3aBeneficiaryEvidenceRoot? get currentPillar3aBeneficiaryEvidence =>
      root;
}

final class _InteractiveDashboardLedger extends _DashboardLedger {
  _InteractiveDashboardLedger(super.value, {required super.root})
      : super(ledgerState: Pillar3aBeneficiaryLedgerState.valid);

  int relationWrites = 0;
  String? writtenContractReferenceId;
  String? writtenExpectedReferenceId;
  Pillar3aBeneficiaryRelation? writtenRelation;
  Pillar3aBeneficiaryReceipt? acceptedReceipt;

  @override
  Future<Pillar3aBeneficiaryReceipt> reconfirmPillar3aBeneficiaryRelation({
    required String contractReferenceId,
    required String expectedReferenceId,
    required Pillar3aBeneficiaryRelation relation,
  }) async {
    relationWrites += 1;
    writtenContractReferenceId = contractReferenceId;
    writtenExpectedReferenceId = expectedReferenceId;
    writtenRelation = relation;
    final current = root!.contracts.single;
    final updated = Pillar3aBeneficiaryEvidence.create(
      contractReferenceId: current.contractReferenceId,
      referenceId: current.referenceId,
      documentAuthorityId: current.documentAuthorityId,
      documentKind: current.documentKind,
      sourceDate: current.sourceDate,
      legalYear: current.legalYear,
      temporalBasis: current.temporalBasis,
      relation: relation,
      relationConfirmedAt: DateTime.utc(2026, 7, 19, 11),
    );
    root = Pillar3aBeneficiaryEvidenceRoot.fromContracts(
      <Pillar3aBeneficiaryEvidence>[updated],
      now: DateTime.utc(2026, 7, 19, 11),
    );
    acceptedReceipt = Pillar3aBeneficiaryReceipt(
      referenceId: updated.referenceId,
      contractReferenceId: updated.contractReferenceId,
      documentAuthorityId: updated.documentAuthorityId,
      relationConfirmedAt: updated.relationConfirmedAt,
    );
    notifyListeners();
    return acceptedReceipt!;
  }

  @override
  bool matchesAcceptedPillar3aBeneficiaryReceipt(
    Pillar3aBeneficiaryReceipt receipt,
  ) =>
      receipt == acceptedReceipt;
}

final class _InvalidDashboardLedger extends _DashboardLedger {
  _InvalidDashboardLedger(super.value)
      : super(ledgerState: Pillar3aBeneficiaryLedgerState.invalid);

  bool reset = false;
  int resetCalls = 0;

  @override
  Pillar3aBeneficiaryLedgerState get pillar3aBeneficiaryLedgerState => reset
      ? Pillar3aBeneficiaryLedgerState.missing
      : Pillar3aBeneficiaryLedgerState.invalid;

  @override
  Future<bool>
      resetInvalidPillar3aBeneficiaryEvidenceAfterReferencePurge() async {
    resetCalls += 1;
    reset = true;
    notifyListeners();
    return true;
  }
}

final class _MemoryReferenceStore extends DocumentReferenceStore {
  _MemoryReferenceStore(this.references);

  List<ConfirmedDocumentReference> references;
  bool failNextSave = false;

  @override
  Future<List<ConfirmedDocumentReference>> load() async => references;

  @override
  Future<void> save(List<ConfirmedDocumentReference> next) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('synthetic BND save failure');
    }
    references = List<ConfirmedDocumentReference>.of(next);
  }
}

final class _DashboardMemoryPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  _DashboardMemoryPersistence(Map<String, dynamic> initial)
      : answers = _copy(initial);

  Map<String, dynamic> answers;
  bool failNextSave = false;

  @override
  Future<Map<String, dynamic>> loadAnswers() async => _copy(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('synthetic presence recovery failure');
    }
    answers = _copy(next);
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}

const _contract = '11111111-1111-4111-8111-111111111111';
const _reference = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _authority = '33333333-3333-4333-8333-333333333333';
const _contract2 = '22222222-2222-4222-8222-222222222222';
const _reference2 = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _authority2 = '55555555-5555-4555-8555-555555555555';

Pillar3aBeneficiaryEvidenceRoot _root(String relation) {
  final root = Pillar3aBeneficiaryEvidenceRoot.fromJsonString(
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'contracts': <Map<String, Object?>>[
        <String, Object?>{
          'kind': 'pillar3aBeneficiaryClause',
          'ownerKind': 'self',
          'documentSource': 'certificate',
          'contractReferenceId': _contract,
          'referenceId': _reference,
          'documentAuthorityId': _authority,
          'documentKind': 'confirmationInstitutionnelle',
          'sourceDate': '2026-07-18',
          'legalYear': 2026,
          'institutionAttested': true,
          'contractScoped': true,
          'temporalBasis': <String, Object?>{
            'kind': 'exactDates',
            'designationEffectiveDate': '2026-01-15',
            'lastAssignmentModificationDate': null,
          },
          'relation': relation,
          'relationSource': 'userInput',
          'relationConfirmedAt': '2026-07-19T10:00:00.000Z',
        },
      ],
    }),
    now: () => DateTime.utc(2026, 7, 19, 10),
  );
  return root!;
}

Pillar3aBeneficiaryEvidenceRoot _twoContractRoot() {
  final first = _root(
    Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
  ).contracts.single;
  final second = Pillar3aBeneficiaryEvidence.create(
    contractReferenceId: _contract2,
    referenceId: _reference2,
    documentAuthorityId: _authority2,
    documentKind:
        Pillar3aBeneficiaryAuthorityDocumentKind.confirmationInstitutionnelle,
    sourceDate: DateTime.utc(2026, 7, 18),
    legalYear: 2026,
    temporalBasis: first.temporalBasis,
    relation: Pillar3aBeneficiaryRelation.currentActiveUnpaid,
    relationConfirmedAt: DateTime.utc(2026, 7, 19, 10),
  );
  return Pillar3aBeneficiaryEvidenceRoot.fromContracts(
    <Pillar3aBeneficiaryEvidence>[first, second],
    now: DateTime.utc(2026, 7, 19, 10),
  );
}

ConfirmedDocumentReference _bnd({
  String referenceId = _reference,
  String documentAuthorityId = _authority,
  String contractReferenceId = _contract,
}) =>
    ConfirmedDocumentReference(
      referenceId: referenceId,
      kind: Pillar3aBeneficiaryEvidence.kind,
      contractReferenceId: contractReferenceId,
      documentAuthorityId: documentAuthorityId,
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: DateTime.utc(2026, 7, 19, 10),
    );

String _textUnder(WidgetTester tester, Finder root) => tester
    .widgetList<Text>(find.descendant(of: root, matching: find.byType(Text)))
    .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
    .join('\n');

CoachProfile _profile() => CoachProfile(
      firstName: 'Julien',
      birthYear: 1985,
      canton: 'VD',
      salaireBrutMensuel: 8000,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 120000,
        totalEpargne3a: 20000,
      ),
      patrimoine: const PatrimoineProfile(
        epargneLiquide: 15000,
        investissements: 50000,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2050),
        label: 'Retraite',
      ),
    );

ProjectionResult _projection({
  required bool complete,
  required bool missingAvs,
}) {
  ProjectionScenario scenario(String label, double? retirementIncome) =>
      ProjectionScenario(
        label: label,
        points: const <ProjectionPoint>[],
        capitalFinal: 500000,
        revenuAnnuelRetraite: retirementIncome,
        revenuAnnuelRetraiteHorsAvs: 30000,
        revenuAvsIndividuelAnnuel: complete ? 30000 : null,
        decomposition: complete
            ? const <String, double>{'avs': 30000, 'lpp': 30000}
            : const <String, double>{},
        decompositionHorsAvs: const <String, double>{'lpp': 30000},
      );

  return ProjectionResult(
    prudent: scenario('Prudent', complete ? 55000 : null),
    base: scenario('Base', complete ? 60000 : null),
    optimiste: scenario('Optimiste', complete ? 65000 : null),
    tauxRemplacementBase: complete ? 62 : null,
    selfAvsIncluded: complete,
    avsIncluded: complete,
    missingFields: missingAvs
        ? const <String>[ForecasterService.selfAvsPensionFieldPath]
        : const <String>[],
    milestones: const <ProjectionMilestone>[],
    disclaimer: 'test',
    sources: const <String>[],
  );
}

({
  Widget widget,
  GoRouter router,
  ScanSessionProvider scans,
  DocumentProvider documents,
  CoachProfileProvider ledger,
}) _app({
  required CoachProfile? profile,
  ProjectionResult? projection,
  CoachProfileProvider? ledger,
  DocumentProvider? documents,
}) {
  final effectiveLedger = ledger ?? _DashboardLedger(profile);
  final effectiveDocuments =
      documents ?? (DocumentProvider()..bindLedger(effectiveLedger));
  final scans = ScanSessionProvider();
  final router = GoRouter(
    initialLocation: '/retraite',
    routes: <RouteBase>[
      GoRoute(
        path: '/retraite',
        builder: (_, __) => RetirementDashboardScreen(
          projectionBuilder: projection == null ? null : (_) => projection,
        ),
      ),
      GoRoute(
        path: '/scan',
        builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
      ),
    ],
  );
  return (
    router: router,
    scans: scans,
    documents: effectiveDocuments,
    ledger: effectiveLedger,
    widget: MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CoachProfileProvider>.value(
          value: effectiveLedger,
        ),
        ChangeNotifierProvider<DocumentProvider>.value(
          value: effectiveDocuments,
        ),
        ChangeNotifierProvider<ScanSessionProvider>.value(value: scans),
        ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
        ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
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

  for (final branch in <({String name, ProjectionResult projection})>[
    (
      name: 'complete projection',
      projection: _projection(complete: true, missingAvs: false),
    ),
    (
      name: 'missing AVS',
      projection: _projection(complete: false, missingAvs: true),
    ),
    (
      name: 'unavailable projection',
      projection: _projection(complete: false, missingAvs: false),
    ),
  ]) {
    testWidgets('real consumer is wired on loaded ${branch.name}',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 0.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = _app(profile: _profile(), projection: branch.projection);
      addTearDown(app.router.dispose);
      addTearDown(app.documents.dispose);
      addTearDown(app.scans.dispose);
      addTearDown(app.ledger.dispose);

      await tester.pumpWidget(app.widget);
      await tester.pump(const Duration(milliseconds: 500));
      final consumer = find.byKey(
        const Key('retirement_pillar3a_beneficiary_consumer'),
      );
      expect(consumer, findsOneWidget);
      await tester.scrollUntilVisible(consumer, 400);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('empty consumer creates opaque insertion route only',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _app(
      profile: _profile(),
      projection: _projection(complete: true, missingAvs: false),
    );
    addTearDown(app.router.dispose);
    addTearDown(app.documents.dispose);
    addTearDown(app.scans.dispose);
    addTearDown(app.ledger.dispose);
    await tester.pumpWidget(app.widget);
    await tester.pump(const Duration(milliseconds: 500));
    final cta = find.byKey(
      const Key('retirement_pillar3a_beneficiary_insert_cta'),
    );
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.pump();
    await tester.tap(cta);
    await tester.pumpAndSettle();

    final uri = app.router.routerDelegate.currentConfiguration.uri;
    expect(uri.path, '/scan');
    expect(
      uri.queryParameters.keys.toSet(),
      <String>{'scanContextId', 'returnUri'},
    );
    expect(uri.queryParameters['returnUri'], '/retraite');
    expect(app.scans.retainedPillar3aBeneficiaryScanIntentCount, 1);
    final intent = app.scans.pillar3aBeneficiaryScanIntentById(
      uri.queryParameters['scanContextId'],
      returnUri: '/retraite',
    );
    expect(intent?.kind, Pillar3aBeneficiaryScanIntentKind.insertion);
    expect(intent?.lifecycle, Pillar3aBeneficiaryScanIntentLifecycle.created);
    expect(
      intent?.contractReferenceId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(intent?.expectedPreviousReferenceId, isNull);
  });

  for (final scenario in <({
    Pillar3aBeneficiaryConsumerState state,
    String relation,
    List<ConfirmedDocumentReference> references,
    String ctaSemantic,
  })>[
    (
      state: Pillar3aBeneficiaryConsumerState.knownCurrentDeclared,
      relation: Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
      references: <ConfirmedDocumentReference>[_bnd()],
      ctaSemantic: 'retirement_pillar3a_beneficiary_reference_replace_cta',
    ),
    (
      state: Pillar3aBeneficiaryConsumerState.needsConfirmation,
      relation: Pillar3aBeneficiaryRelation.uncertain.name,
      references: <ConfirmedDocumentReference>[_bnd()],
      ctaSemantic: 'retirement_pillar3a_beneficiary_reference_reconfirm_cta',
    ),
    (
      state: Pillar3aBeneficiaryConsumerState.inactive,
      relation: Pillar3aBeneficiaryRelation.paidOrClosed.name,
      references: <ConfirmedDocumentReference>[_bnd()],
      ctaSemantic: 'retirement_pillar3a_beneficiary_reference_review_cta',
    ),
    (
      state: Pillar3aBeneficiaryConsumerState.missingDocumentReference,
      relation: Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
      references: const <ConfirmedDocumentReference>[],
      ctaSemantic: 'retirement_pillar3a_beneficiary_reference_relink_cta',
    ),
    (
      state: Pillar3aBeneficiaryConsumerState.mismatchedDocumentReference,
      relation: Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
      references: <ConfirmedDocumentReference>[
        _bnd(referenceId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
      ],
      ctaSemantic: 'retirement_pillar3a_beneficiary_reference_restart_cta',
    ),
  ]) {
    testWidgets('consumer renders fail-closed ${scenario.state.name}',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 0.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ledger = _DashboardLedger(
        _profile(),
        ledgerState: Pillar3aBeneficiaryLedgerState.valid,
        root: _root(scenario.relation),
      );
      final documents = DocumentProvider(
        referenceStore: _MemoryReferenceStore(scenario.references),
      )..bindLedger(ledger);
      await documents.hydrateReferences();
      final app = _app(
        profile: ledger.value,
        projection: _projection(complete: true, missingAvs: false),
        ledger: ledger,
        documents: documents,
      );
      addTearDown(app.router.dispose);
      addTearDown(app.documents.dispose);
      addTearDown(app.scans.dispose);
      addTearDown(app.ledger.dispose);

      await tester.pumpWidget(app.widget);
      await tester.pump(const Duration(milliseconds: 500));

      final stateCard = find.byKey(
        Key(
          'retirement_pillar3a_beneficiary_consumer_${scenario.state.name}',
        ),
      );
      expect(stateCard, findsOneWidget);
      await tester.ensureVisible(stateCard);
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier(scenario.ctaSemantic),
        findsOneWidget,
      );
      final precise = find.byKey(
        const Key('retirement_pillar3a_beneficiary_precise_metadata'),
      );
      if (scenario.state ==
          Pillar3aBeneficiaryConsumerState.knownCurrentDeclared) {
        expect(precise, findsOneWidget);
        expect(
          find.byKey(
            const Key('retirement_pillar3a_beneficiary_declared_relation'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('retirement_pillar3a_beneficiary_no_advice_boundary'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('retirement_pillar3a_beneficiary_specialist_handoff'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('retirement_pillar3a_beneficiary_replace_cta'),
          ),
          findsOneWidget,
        );
        final visible = _textUnder(
          tester,
          find.byKey(
            const Key(
              'retirement_pillar3a_beneficiary_consumer_knownCurrentDeclared',
            ),
          ),
        );
        for (final expected in <String>[
          'Confirmation de l’institution 3a',
          '18 juillet 2026',
          'Année juridique indiquée dans le document : 2026',
          '15 janvier 2026',
          'Dates attestées par l’institution, non déduites par MINT',
          'Déclaré actif et non versé le 19 juillet 2026',
          'ne prouvent pas qu’aucune désignation plus récente n’existe',
          'Information factuelle uniquement',
          'ne peut pas conclure qui recevra le capital',
          'ni dans quel ordre, ni selon quelle part',
          'À vérifier avec l’institution 3a ou un spécialiste',
        ]) {
          expect(visible, contains(expected), reason: expected);
        }
        for (final opaque in <String>[_contract, _reference, _authority]) {
          expect(visible, isNot(contains(opaque)), reason: opaque);
        }
        final handoffCta = find.byKey(
          const Key('retirement_pillar3a_beneficiary_specialist_handoff'),
        );
        expect(tester.widget(handoffCta), isA<OutlinedButton>());
        await tester.tap(handoffCta);
        await tester.pumpAndSettle();
        final sheet = find.byKey(
          const Key('retirement_pillar3a_beneficiary_specialist_sheet'),
        );
        expect(sheet, findsOneWidget);
        final sheetText = _textUnder(tester, sheet);
        expect(sheetText, contains('désignation enregistrée actuellement'));
        expect(sheetText, contains('date de prise d’effet'));
        expect(
          sheetText,
          contains('ne détermine ni le bénéficiaire, ni l’ordre, ni la part'),
        );
      } else {
        expect(precise, findsNothing);
        expect(find.textContaining('18 juillet 2026'), findsNothing);
      }
    });
  }

  testWidgets(
      'dismissed relation sheet leaves a rendered BND-only receipt retry',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ledger = _InteractiveDashboardLedger(
      _profile(),
      root: _root(Pillar3aBeneficiaryRelation.uncertain.name),
    );
    final store = _MemoryReferenceStore(<ConfirmedDocumentReference>[_bnd()]);
    final documents = DocumentProvider(referenceStore: store)
      ..bindLedger(ledger);
    await documents.hydrateReferences();
    store.failNextSave = true;
    final app = _app(
      profile: ledger.value,
      projection: _projection(complete: true, missingAvs: false),
      ledger: ledger,
      documents: documents,
    );
    addTearDown(app.router.dispose);
    addTearDown(app.documents.dispose);
    addTearDown(app.scans.dispose);
    addTearDown(app.ledger.dispose);
    await tester.pumpWidget(app.widget);
    await tester.pump(const Duration(milliseconds: 500));

    final reconfirmKey = find.byKey(
      const Key('retirement_pillar3a_beneficiary_reconfirm_cta'),
    );
    expect(reconfirmKey, findsOneWidget);
    await tester.ensureVisible(reconfirmKey);
    await tester.pumpAndSettle();
    final reconfirm = find.bySemanticsIdentifier(
      'retirement_pillar3a_beneficiary_reference_reconfirm_cta',
    );
    expect(reconfirm, findsOneWidget);
    await tester.tap(reconfirm);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('retirement_pillar3a_beneficiary_relation_sheet'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const Key('retirement_pillar3a_beneficiary_relation_active_choice'),
      ),
    );
    await tester.pumpAndSettle();

    expect(ledger.relationWrites, 1);
    expect(ledger.writtenContractReferenceId, _contract);
    expect(ledger.writtenExpectedReferenceId, _reference);
    expect(
      ledger.writtenRelation,
      Pillar3aBeneficiaryRelation.currentActiveUnpaid,
    );
    expect(
        app.router.routerDelegate.currentConfiguration.uri.path, '/retraite');
    expect(app.scans.retainedPillar3aBeneficiaryScanIntentCount, 0);
    expect(store.references.single.confirmedAt, DateTime.utc(2026, 7, 19, 10));
    expect(
      find.byKey(
        const Key('retirement_pillar3a_beneficiary_relation_sheet'),
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('retirement_pillar3a_beneficiary_relation_sheet'),
      ),
      findsNothing,
    );
    final renderedState = find.byKey(
      const Key(
        'retirement_pillar3a_beneficiary_consumer_mismatchedDocumentReference',
      ),
    );
    expect(renderedState, findsOneWidget);
    await tester.ensureVisible(renderedState);
    await tester.pumpAndSettle();
    final retry = find.byKey(
      const Key('retirement_pillar3a_beneficiary_relation_bnd_retry_card'),
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(ledger.relationWrites, 1);
    expect(store.references.single.referenceId, _reference);
    expect(store.references.single.contractReferenceId, _contract);
    expect(store.references.single.documentAuthorityId, _authority);
    expect(store.references.single.confirmedAt, DateTime.utc(2026, 7, 19, 11));
  });

  testWidgets('invalid root is distinct and never re-renders old precision',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ledger = _DashboardLedger(
      _profile(),
      ledgerState: Pillar3aBeneficiaryLedgerState.invalid,
    );
    final documents = DocumentProvider()..bindLedger(ledger);
    final app = _app(
      profile: ledger.value,
      projection: _projection(complete: true, missingAvs: false),
      ledger: ledger,
      documents: documents,
    );
    addTearDown(app.router.dispose);
    addTearDown(app.documents.dispose);
    addTearDown(app.scans.dispose);
    addTearDown(app.ledger.dispose);
    await tester.pumpWidget(app.widget);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(
        const Key('retirement_pillar3a_beneficiary_consumer_invalid'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('retirement_pillar3a_beneficiary_precise_metadata'),
      ),
      findsNothing,
    );
  });

  testWidgets(
      'invalid presence provenance recovers without deleting valid authority',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = _root(
      Pillar3aBeneficiaryRelation.currentActiveUnpaid.name,
    );
    final rootJson = root.toJsonString();
    final persistence = _DashboardMemoryPersistence(<String, dynamic>{
      'q_birth_year': 1985,
      'q_canton': 'VD',
      Pillar3aBeneficiaryEvidenceRoot.answerKey: rootJson,
      'q_has_3a': false,
      '__provenance': <String, Object?>{
        'hasPillar3a': <String, Object?>{
          'source': 'userInput',
          'updatedAt': '2026-07-19T13:00:00.000Z',
          'sourceDate': null,
        },
        'siblingFact': <String, Object?>{
          'source': 'userInput',
          'updatedAt': '2026-07-19T09:00:00.000Z',
          'sourceDate': null,
        },
      },
    });
    final ledger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => DateTime.utc(2026, 7, 19, 12),
    );
    await ledger.loadFromWizard();
    final store = _MemoryReferenceStore(<ConfirmedDocumentReference>[_bnd()]);
    final documents = DocumentProvider(referenceStore: store)
      ..bindLedger(ledger);
    await documents.hydrateReferences();
    final app = _app(
      profile: ledger.profile,
      projection: _projection(complete: true, missingAvs: false),
      ledger: ledger,
      documents: documents,
    );
    addTearDown(app.router.dispose);
    addTearDown(app.documents.dispose);
    addTearDown(app.scans.dispose);
    addTearDown(app.ledger.dispose);

    await tester.pumpWidget(app.widget);
    await tester.pump(const Duration(milliseconds: 500));

    final recoveryCard = find.byKey(
      const Key(
        'retirement_pillar3a_beneficiary_consumer_invalidPresenceProvenance',
      ),
    );
    expect(recoveryCard, findsOneWidget);
    await tester.ensureVisible(recoveryCard);
    await tester.pumpAndSettle();
    final recovery = find.byKey(
      const Key('retirement_pillar3a_beneficiary_presence_reset_cta'),
    );
    expect(recovery, findsOneWidget);
    await tester.tap(recovery);
    await tester.pumpAndSettle();

    expect(
      persistence.answers[Pillar3aBeneficiaryEvidenceRoot.answerKey],
      rootJson,
    );
    expect(persistence.answers, isNot(contains('q_has_3a')));
    final provenance = persistence.answers['__provenance'] as Map;
    expect(provenance, isNot(contains('hasPillar3a')));
    expect(provenance, contains('siblingFact'));
    expect(store.references, hasLength(1));
    expect(store.references.single.toJson(), _bnd().toJson());
    expect(ledger.pillar3aBeneficiaryLedgerState,
        Pillar3aBeneficiaryLedgerState.valid);
    expect(
      ledger.currentPillar3aBeneficiaryEvidence?.toJsonString(),
      rootJson,
    );
    expect(
      find.byKey(
        const Key(
          'retirement_pillar3a_beneficiary_consumer_knownCurrentDeclared',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('retirement_pillar3a_beneficiary_insert_cta')),
      findsNothing,
    );
  });

  testWidgets('invalid reset purges BND before enabling a new scan',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ledger = _InvalidDashboardLedger(_profile());
    final unrelated = ConfirmedDocumentReference(
      referenceId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      kind: ConfirmedDocumentReference.lppKind,
      snapshotId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      ownerKind: LppEvidenceOwnerKind.self,
      confirmedAt: DateTime.utc(2026, 7, 19, 9),
    );
    final store = _MemoryReferenceStore(<ConfirmedDocumentReference>[
      _bnd(),
      unrelated,
    ])
      ..failNextSave = true;
    final documents = DocumentProvider(referenceStore: store)
      ..bindLedger(ledger);
    final app = _app(
      profile: ledger.value,
      projection: _projection(complete: true, missingAvs: false),
      ledger: ledger,
      documents: documents,
    );
    addTearDown(app.router.dispose);
    addTearDown(app.documents.dispose);
    addTearDown(app.scans.dispose);
    addTearDown(app.ledger.dispose);
    await tester.pumpWidget(app.widget);
    await tester.pump(const Duration(milliseconds: 500));

    final resetKey = find.byKey(
      const Key('retirement_pillar3a_beneficiary_invalid_reset_cta'),
    );
    expect(resetKey, findsOneWidget);
    await tester.ensureVisible(resetKey);
    await tester.pumpAndSettle();
    final reset = find.bySemanticsIdentifier(
      'retirement_pillar3a_beneficiary_reference_invalid_reset_cta',
    );
    expect(reset, findsOneWidget);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(ledger.resetCalls, 0);
    expect(ledger.pillar3aBeneficiaryLedgerState,
        Pillar3aBeneficiaryLedgerState.invalid);
    expect(app.scans.retainedPillar3aBeneficiaryScanIntentCount, 0);
    expect(
        app.router.routerDelegate.currentConfiguration.uri.path, '/retraite');
    expect(store.references, hasLength(2));

    final retry = find.byKey(
      const Key('retirement_pillar3a_beneficiary_invalid_reset_retry'),
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(ledger.resetCalls, 1);
    expect(store.references, <ConfirmedDocumentReference>[unrelated]);
    expect(
      find.byKey(const Key('retirement_pillar3a_beneficiary_insert_cta')),
      findsOneWidget,
    );
    expect(app.scans.retainedPillar3aBeneficiaryScanIntentCount, 0);
  });

  testWidgets('replacement route keeps CAS only inside volatile registry',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ledger = _DashboardLedger(
      _profile(),
      ledgerState: Pillar3aBeneficiaryLedgerState.valid,
      root: _root(Pillar3aBeneficiaryRelation.currentActiveUnpaid.name),
    );
    final documents = DocumentProvider(
      referenceStore: _MemoryReferenceStore(<ConfirmedDocumentReference>[
        _bnd(),
      ]),
    )..bindLedger(ledger);
    await documents.hydrateReferences();
    final app = _app(
      profile: ledger.value,
      projection: _projection(complete: true, missingAvs: false),
      ledger: ledger,
      documents: documents,
    );
    addTearDown(app.router.dispose);
    addTearDown(app.documents.dispose);
    addTearDown(app.scans.dispose);
    addTearDown(app.ledger.dispose);
    await tester.pumpWidget(app.widget);
    await tester.pump(const Duration(milliseconds: 500));

    final cta = find.byKey(
      const Key('retirement_pillar3a_beneficiary_replace_cta'),
    );
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.pump();
    await tester.tap(cta);
    await tester.pumpAndSettle();

    final uri = app.router.routerDelegate.currentConfiguration.uri;
    expect(uri.path, '/scan');
    expect(
      uri.queryParameters.keys.toSet(),
      <String>{'scanContextId', 'returnUri'},
    );
    expect(uri.toString(), isNot(contains(_contract)));
    expect(uri.toString(), isNot(contains(_reference)));
    final intent = app.scans.pillar3aBeneficiaryScanIntentById(
      uri.queryParameters['scanContextId'],
      returnUri: '/retraite',
    );
    expect(intent?.kind, Pillar3aBeneficiaryScanIntentKind.replacement);
    expect(intent?.contractReferenceId, _contract);
    expect(intent?.expectedPreviousReferenceId, _reference);
  });

  testWidgets('multi-contract CTA retains only the affected entry intent',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ledger = _DashboardLedger(
      _profile(),
      ledgerState: Pillar3aBeneficiaryLedgerState.valid,
      root: _twoContractRoot(),
    );
    final documents = DocumentProvider(
      referenceStore: _MemoryReferenceStore(<ConfirmedDocumentReference>[
        _bnd(),
        _bnd(
          contractReferenceId: _contract2,
          referenceId: '66666666-6666-4666-8666-666666666666',
          documentAuthorityId: _authority2,
        ),
      ]),
    )..bindLedger(ledger);
    await documents.hydrateReferences();
    final app = _app(
      profile: ledger.value,
      projection: _projection(complete: true, missingAvs: false),
      ledger: ledger,
      documents: documents,
    );
    addTearDown(app.router.dispose);
    addTearDown(app.documents.dispose);
    addTearDown(app.scans.dispose);
    addTearDown(app.ledger.dispose);
    await tester.pumpWidget(app.widget);
    await tester.pump(const Duration(milliseconds: 500));

    final affected = find.byKey(
      const Key('retirement_pillar3a_beneficiary_restart_cta_2'),
    );
    expect(affected, findsOneWidget);
    await tester.ensureVisible(affected);
    await tester.tap(affected);
    await tester.pumpAndSettle();

    final uri = app.router.routerDelegate.currentConfiguration.uri;
    expect(uri.path, '/scan');
    final intent = app.scans.pillar3aBeneficiaryScanIntentById(
      uri.queryParameters['scanContextId'],
      returnUri: '/retraite',
    );
    expect(intent?.kind, Pillar3aBeneficiaryScanIntentKind.replacement);
    expect(intent?.contractReferenceId, _contract2);
    expect(intent?.expectedPreviousReferenceId, _reference2);
    expect(uri.toString(), isNot(contains(_contract2)));
    expect(uri.toString(), isNot(contains(_reference2)));
  });

  testWidgets('flag-off and loading states stay hidden', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final mode in <String>['flagOff', 'loading']) {
      final ledger = _DashboardLedger(
        _profile(),
        ledgerState: Pillar3aBeneficiaryLedgerState.valid,
        root: _root(Pillar3aBeneficiaryRelation.currentActiveUnpaid.name),
        loading: mode == 'loading',
      );
      final documents = DocumentProvider(
        referenceStore: _MemoryReferenceStore(<ConfirmedDocumentReference>[
          _bnd(),
        ]),
      )..bindLedger(ledger);
      await documents.hydrateReferences();
      final app = _app(
        profile: ledger.value,
        projection: _projection(complete: true, missingAvs: false),
        ledger: ledger,
        documents: documents,
      );
      if (mode == 'flagOff') {
        FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
      }
      await tester.pumpWidget(app.widget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const Key('retirement_pillar3a_beneficiary_consumer')),
        findsNothing,
        reason: mode,
      );
      FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
      await tester.pumpWidget(const SizedBox.shrink());
      app.router.dispose();
      app.documents.dispose();
      app.scans.dispose();
      app.ledger.dispose();
    }
  });

  testWidgets(
      'consumer stays hidden with zero action when any production flag is off',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final disabledFlag in <String>[
      'typedLppEvidence',
      'documentLppEvidenceEnabled',
      'pillar3aBeneficiaryClauseReferenceEnabled',
    ]) {
      FeatureFlags.typedLppEvidence = disabledFlag != 'typedLppEvidence';
      FeatureFlags.documentLppEvidenceEnabled =
          disabledFlag != 'documentLppEvidenceEnabled';
      FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled =
          disabledFlag != 'pillar3aBeneficiaryClauseReferenceEnabled';
      final ledger = _DashboardLedger(
        _profile(),
        ledgerState: Pillar3aBeneficiaryLedgerState.missing,
      );
      final documents = DocumentProvider()..bindLedger(ledger);
      final app = _app(
        profile: ledger.value,
        projection: _projection(complete: true, missingAvs: false),
        ledger: ledger,
        documents: documents,
      );

      await tester.pumpWidget(app.widget);
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const Key('retirement_pillar3a_beneficiary_consumer')),
        findsNothing,
        reason: disabledFlag,
      );
      expect(app.scans.retainedPillar3aBeneficiaryScanIntentCount, 0);
      expect(
        app.router.routerDelegate.currentConfiguration.uri.path,
        '/retraite',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      app.router.dispose();
      app.documents.dispose();
      app.scans.dispose();
      app.ledger.dispose();
    }
  });

  testWidgets('consumer stays hidden when there is no loaded profile',
      (tester) async {
    final app = _app(profile: null);
    addTearDown(app.router.dispose);
    addTearDown(app.documents.dispose);
    addTearDown(app.scans.dispose);
    addTearDown(app.ledger.dispose);
    await tester.pumpWidget(app.widget);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const Key('retirement_pillar3a_beneficiary_consumer')),
      findsNothing,
    );
  });
}
