import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/lpp_regulation_specialist_handoff.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _replacementSnapshotId = '22222222-2222-4222-8222-222222222222';
const _referenceId = '33333333-3333-4333-8333-333333333333';
const _mismatchedReferenceId = '44444444-4444-4444-8444-444444444444';
const _cardId = 'retirement_lpp_regulation_reference_education';
const _ctaId = 'retirement_lpp_regulation_handoff_cta';
const _sheetId = 'retirement_lpp_regulation_handoff_sheet';
const _sheetTitleId = 'retirement_lpp_regulation_handoff_title';
const _sheetPrivacyId = 'retirement_lpp_regulation_handoff_privacy';
const _closeId = 'retirement_lpp_regulation_handoff_close';
const _recoveryId = 'retirement_lpp_regulation_reference_recovery';
const _reconfirmCtaId = 'retirement_lpp_regulation_reconfirm_cta';
const _recoveryTitleFr = 'Déclaration d’origine à reconfirmer';
const _recoveryCtaFr = 'Reconfirmer la déclaration';
const _legacyRecoveryBodyFr =
    'Une déclaration non vérifiée ne précise pas l’origine de ce règlement. '
    'Reconfirme-la à partir du document. MINT n’en déduit ni l’origine, ni '
    'l’institution concernée, ni l’application du règlement à ta situation, '
    'ni tes droits ni aucun montant.';
const _missingRecoveryBodyFr =
    'Une déclaration non vérifiée existe, mais sa référence locale manque. '
    'Reconfirme-la à partir du document. MINT n’en déduit ni l’origine, ni '
    'l’institution concernée, ni l’application du règlement à ta situation, '
    'ni tes droits ni aucun montant.';
const _mismatchRecoveryBodyFr =
    'Une déclaration non vérifiée ne correspond pas à sa référence locale et '
    'est masquée. Reconfirme-la à partir du document. MINT n’en déduit ni '
    'l’origine, ni l’institution concernée, ni l’application du règlement à '
    'ta situation, ni tes droits ni aucun montant.';

final class _DashboardLedger extends CoachProfileProvider {
  _DashboardLedger({
    required this.value,
    required this.snapshotId,
    required this.referenceId,
    required this.confirmedAt,
    this.recoveryReason,
  });

  final CoachProfile? value;
  String? snapshotId;
  final String referenceId;
  final DateTime confirmedAt;
  final LppRegulationRecoveryReason? recoveryReason;

  @override
  CoachProfile? get profile => value;

  @override
  bool get hasProfile => value != null;

  @override
  bool get isLoaded => true;

  @override
  LppRegulationRecoveryReason? get lppRegulationRecoveryReason =>
      FeatureFlags.lppRegulationReferenceEnabled ? recoveryReason : null;

  @override
  String? currentLppSnapshotId(LppEvidenceOwnerKind ownerKind) =>
      ownerKind == LppEvidenceOwnerKind.self ? snapshotId : null;

  @override
  bool matchesAcceptedLppRegulationReceipt(LppRegulationReceipt receipt) =>
      FeatureFlags.lppRegulationReferenceEnabled &&
      receipt.referenceId == referenceId &&
      receipt.confirmedAt == confirmedAt;
}

final class _MemoryReferenceStore extends DocumentReferenceStore {
  _MemoryReferenceStore(this.reference);

  final ConfirmedDocumentReference reference;

  @override
  Future<List<ConfirmedDocumentReference>> load() async => [reference];
}

SpecialistReferenceEvidence _candidate({
  String fundRelationship = 'currentFund',
}) {
  final now = DateTime.now().toUtc();
  final json = <String, dynamic>{
    'referenceId': _referenceId,
    'kind': LppRegulationReference.kind,
    'ownerKind': LppEvidenceOwnerKind.self.wireName,
    'source': ProfileDataSource.certificate.name,
    'sourceDate': '2017-02-03',
    'legalYear': 2018,
    'confirmedAt': now.subtract(const Duration(days: 1)).toIso8601String(),
    'fundRelationship': fundRelationship,
  };
  final strict = SpecialistReferenceEvidence.tryFromJson(
    json,
    expectedKind: SpecialistReferenceKind.lppRegulation,
    now: now,
  );
  if (strict != null) return strict;

  // RED compatibility bridge for the schema-1 specialist projection.
  json.remove('fundRelationship');
  return SpecialistReferenceEvidence.tryFromJson(
    json,
    expectedKind: SpecialistReferenceKind.lppRegulation,
    now: now,
  )!;
}

CoachProfile _profile(SpecialistReferenceEvidence? candidate) => CoachProfile(
      firstName: 'Julien',
      birthYear: 1985,
      canton: 'VD',
      salaireBrutMensuel: 8000,
      lppRegulationReference: candidate,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 120000,
        totalEpargne3a: 20000,
      ),
      patrimoine: const PatrimoineProfile(
        epargneLiquide: 15000,
        investissements: 50000,
      ),
      initialProjectionSnapshot: const <String, dynamic>{},
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2050),
        label: 'Retraite',
      ),
    );

ConfirmedDocumentReference _confirmedRegulationReference({
  required String referenceId,
  required DateTime confirmedAt,
}) {
  final named = <Symbol, Object?>{
    #referenceId: referenceId,
    #kind: LppRegulationReference.kind,
    #ownerKind: LppEvidenceOwnerKind.self,
    #confirmedAt: confirmedAt,
  };
  try {
    return Function.apply(
      ConfirmedDocumentReference.new,
      const <Object?>[],
      named,
    ) as ConfirmedDocumentReference;
  } on NoSuchMethodError {
    return Function.apply(
      ConfirmedDocumentReference.new,
      const <Object?>[],
      <Symbol, Object?>{...named, #snapshotId: _snapshotId},
    ) as ConfirmedDocumentReference;
  }
}

final class _EmptyReferenceStore extends DocumentReferenceStore {
  @override
  Future<List<ConfirmedDocumentReference>> load() async => const [];
}

final class _FailingReferenceStore extends DocumentReferenceStore {
  @override
  Future<List<ConfirmedDocumentReference>> load() async =>
      throw const FormatException('synthetic BND hydration failure');
}

final class _LoadingReferenceStore extends DocumentReferenceStore {
  final gate = Completer<void>();

  @override
  Future<List<ConfirmedDocumentReference>> load() async {
    await gate.future;
    return const [];
  }
}

Future<DocumentProvider> _documents({
  required _DashboardLedger ledger,
  String referenceId = _referenceId,
}) async {
  final documents = DocumentProvider(
    referenceStore: _MemoryReferenceStore(
      _confirmedRegulationReference(
        referenceId: referenceId,
        confirmedAt: ledger.confirmedAt,
      ),
    ),
  );
  documents.bindLedger(ledger);
  await documents.hydrateReferences();
  return documents;
}

Widget _dashboard({
  required CoachProfileProvider ledger,
  DocumentProvider? documents,
  RetirementProjectionBuilder? projectionBuilder,
}) {
  final providers = <SingleChildWidget>[
    ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
    if (documents != null)
      ChangeNotifierProvider<DocumentProvider>.value(value: documents),
    ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
    ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
  ];
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: RetirementDashboardScreen(
        projectionBuilder: projectionBuilder,
      ),
    ),
  );
}

({Widget widget, GoRouter router}) _dashboardRouter({
  required CoachProfileProvider ledger,
  required DocumentProvider documents,
}) {
  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, __) => const RetirementDashboardScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (_, state) => Scaffold(
          key: const Key('lpp_regulation_reconfirm_destination'),
          body: Text(state.uri.toString()),
        ),
      ),
    ],
  );
  return (
    router: router,
    widget: MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
        ChangeNotifierProvider<DocumentProvider>.value(value: documents),
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

ProjectionResult _loadedProjection({required bool complete}) {
  ProjectionScenario scenario(String label, double? retirementIncome) =>
      ProjectionScenario(
        label: label,
        points: const [],
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
    missingFields: const <String>[],
    milestones: const [],
    disclaimer: 'test',
    sources: const [],
  );
}

String _textUnder(WidgetTester tester, Finder root) => tester
    .widgetList<Text>(find.descendant(of: root, matching: find.byType(Text)))
    .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
    .join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.lppRegulationReferenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.lppRegulationReferenceEnabled = false;
    FeatureFlags.typedLppEvidence = false;
  });

  testWidgets(
      'exact cold tuple renders regulation education and CTA without TTL stale state',
      (tester) async {
    final candidate = _candidate();
    final ledger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: null,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
      recoveryReason: LppRegulationRecoveryReason.legacyMissingFundRelationship,
    );
    final documents = await _documents(ledger: ledger);
    addTearDown(documents.dispose);
    addTearDown(ledger.dispose);

    await tester.pumpWidget(_dashboard(ledger: ledger, documents: documents));
    await tester.pump(const Duration(milliseconds: 500));

    final card = find.bySemanticsIdentifier(_cardId);
    expect(card, findsOneWidget);
    expect(find.bySemanticsIdentifier(_ctaId), findsOneWidget);
    expect(
      find.bySemanticsIdentifier(_recoveryId),
      findsNothing,
      reason: 'The exact current tuple wins over a defensive stale marker.',
    );
    expect(
      find.byKey(const Key('retirement_missing_avs_state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('retirement_avs_document_cta')),
      findsOneWidget,
      reason: 'regulation education must not replace the separate AVS ask',
    );

    final cardText = _textUnder(tester, card).toLowerCase();
    expect(cardText, contains('3 février 2017'));
    expect(cardText, contains('2018'));
    expect(
      find.bySemanticsIdentifier(
        'retirement_lpp_regulation_fund_relation',
      ),
      findsOneWidget,
    );
    expect(cardText, contains('ma caisse actuelle'));
    expect(cardText, contains('déclarée'));
    expect(cardText, contains('non vérifiée'));
    expect(cardText, isNot(contains('caisse confirmée')));
    for (final falseStale in <String>[
      'périmé',
      'obsolète',
      'expiré',
      'à renouveler',
    ]) {
      expect(cardText, isNot(contains(falseStale)), reason: falseStale);
    }
  });

  for (final branch in <({String name, ProjectionResult projection})>[
    (
      name: 'complete dashboard',
      projection: _loadedProjection(complete: true),
    ),
    (
      name: 'unavailable projection without AVS missing fields',
      projection: _loadedProjection(complete: false),
    ),
  ]) {
    testWidgets('exact cold tuple renders regulation handoff on ${branch.name}',
        (tester) async {
      // Ahem's fixed-width glyphs overstate this legacy hero row in widget
      // tests; this branch test targets wiring, not typography.
      tester.platformDispatcher.textScaleFactorTestValue = 0.4;
      addTearDown(
        tester.platformDispatcher.clearTextScaleFactorTestValue,
      );
      final candidate = _candidate();
      final ledger = _DashboardLedger(
        value: _profile(candidate),
        snapshotId: null,
        referenceId: candidate.referenceId,
        confirmedAt: candidate.confirmedAt,
      );
      final documents = await _documents(ledger: ledger);
      addTearDown(documents.dispose);
      addTearDown(ledger.dispose);

      await tester.pumpWidget(
        _dashboard(
          ledger: ledger,
          documents: documents,
          projectionBuilder: (_) => branch.projection,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final cardKey = find.byKey(const Key(_cardId));
      await tester.scrollUntilVisible(cardKey, 400);
      await tester.pumpAndSettle();

      expect(
        <int>[
          find.bySemanticsIdentifier(_cardId).evaluate().length,
          find.bySemanticsIdentifier(_ctaId).evaluate().length,
        ],
        const <int>[1, 1],
        reason: '${branch.name} must expose the regulation card and CTA',
      );
      expect(
        find.byKey(const Key('retirement_missing_avs_state')),
        findsNothing,
      );
    });
  }

  testWidgets(
      'reference-only card survives numeric snapshot addition and replacement',
      (tester) async {
    final candidate = _candidate(fundRelationship: 'uncertain');
    final ledger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: null,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final documents = await _documents(ledger: ledger);
    addTearDown(documents.dispose);
    addTearDown(ledger.dispose);

    await tester.pumpWidget(_dashboard(ledger: ledger, documents: documents));
    await tester.pump(const Duration(milliseconds: 500));
    expect(ledger.currentLppSnapshotId(LppEvidenceOwnerKind.self), isNull);
    expect(find.bySemanticsIdentifier(_cardId), findsOneWidget);

    ledger.snapshotId = _snapshotId;
    ledger.notifyListeners();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.bySemanticsIdentifier(_cardId), findsOneWidget);

    ledger.snapshotId = _replacementSnapshotId;
    ledger.notifyListeners();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.bySemanticsIdentifier(_cardId), findsOneWidget);
    expect(find.bySemanticsIdentifier(_ctaId), findsOneWidget);
  });

  testWidgets(
      'accepted root authority with missing ready BND renders neutral reconfirmation recovery',
      (tester) async {
    final candidate = _candidate(fundRelationship: 'formerOrOther');
    final ledger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: null,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final documents = DocumentProvider(referenceStore: _EmptyReferenceStore())
      ..bindLedger(ledger);
    await documents.hydrateReferences();
    expect(documents.referencesHydrated, isTrue);
    addTearDown(documents.dispose);
    addTearDown(ledger.dispose);
    final harness = _dashboardRouter(ledger: ledger, documents: documents);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsIdentifier(_cardId), findsNothing);
    final recovery = find.bySemanticsIdentifier(_recoveryId);
    expect(recovery, findsOneWidget);
    final recoveryText = _textUnder(tester, recovery);
    expect(recoveryText, contains(_recoveryTitleFr));
    expect(recoveryText, contains(_recoveryCtaFr));
    expect(recoveryText, contains(_missingRecoveryBodyFr));
    expect(recoveryText, isNot(contains(_referenceId)));
    expect(recoveryText, isNot(contains('2018')));
    expect(recoveryText.toLowerCase(), isNot(contains('règlement confirmé')));

    final cta = find.bySemanticsIdentifier(_reconfirmCtaId);
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(
      harness.router.routeInformationProvider.value.uri.toString(),
      '/scan?type=lppPlan',
    );
    expect(
      find.byKey(const Key('lpp_regulation_reconfirm_destination')),
      findsOneWidget,
    );
  });

  testWidgets(
      'legacy recovery marker renders neutral document reconfirmation without stale tuple data',
      (tester) async {
    final candidate = _candidate();
    final ledger = _DashboardLedger(
      value: _profile(null),
      snapshotId: null,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
      recoveryReason: LppRegulationRecoveryReason.legacyMissingFundRelationship,
    );
    final documents = DocumentProvider(referenceStore: _EmptyReferenceStore())
      ..bindLedger(ledger);
    await documents.hydrateReferences();
    addTearDown(documents.dispose);
    addTearDown(ledger.dispose);
    final harness = _dashboardRouter(ledger: ledger, documents: documents);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsIdentifier(_cardId), findsNothing);
    final recovery = find.bySemanticsIdentifier(_recoveryId);
    expect(recovery, findsOneWidget);
    final recoveryText = _textUnder(tester, recovery);
    expect(recoveryText, contains(_recoveryTitleFr));
    expect(recoveryText, contains(_recoveryCtaFr));
    expect(recoveryText, contains(_legacyRecoveryBodyFr));
    expect(recoveryText, isNot(contains(_referenceId)));
    expect(recoveryText, isNot(contains('2018')));

    final cta = find.bySemanticsIdentifier(_reconfirmCtaId);
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(
      harness.router.routeInformationProvider.value.uri.toString(),
      '/scan?type=lppPlan',
    );
  });

  testWidgets(
      'mismatched ready BND renders masked declaration recovery instead of stale education',
      (tester) async {
    final candidate = _candidate(fundRelationship: 'currentFund');
    final ledger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: null,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final documents = await _documents(
      ledger: ledger,
      referenceId: _mismatchedReferenceId,
    );
    addTearDown(documents.dispose);
    addTearDown(ledger.dispose);
    final harness = _dashboardRouter(ledger: ledger, documents: documents);
    addTearDown(harness.router.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsIdentifier(_cardId), findsNothing);
    final recovery = find.bySemanticsIdentifier(_recoveryId);
    expect(recovery, findsOneWidget);
    final recoveryText = _textUnder(tester, recovery);
    expect(recoveryText, contains(_recoveryTitleFr));
    expect(recoveryText, contains(_recoveryCtaFr));
    expect(recoveryText, contains(_mismatchRecoveryBodyFr));
    expect(recoveryText, isNot(contains(_referenceId)));
    expect(recoveryText, isNot(contains(_mismatchedReferenceId)));
    expect(recoveryText, isNot(contains('ma caisse actuelle')));

    final cta = find.bySemanticsIdentifier(_reconfirmCtaId);
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(
      harness.router.routeInformationProvider.value.uri.toString(),
      '/scan?type=lppPlan',
    );
  });

  testWidgets('failed BND hydration remains hidden and never claims recovery',
      (tester) async {
    final candidate = _candidate();
    final ledger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: null,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final documents = DocumentProvider(referenceStore: _FailingReferenceStore())
      ..bindLedger(ledger);
    await expectLater(documents.hydrateReferences(), throwsFormatException);
    expect(
      documents.referenceHydrationState,
      DocumentReferenceHydrationState.failed,
    );
    addTearDown(documents.dispose);
    addTearDown(ledger.dispose);

    await tester.pumpWidget(_dashboard(ledger: ledger, documents: documents));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsIdentifier(_cardId), findsNothing);
    expect(
      find.bySemanticsIdentifier(
        'retirement_lpp_regulation_reference_recovery',
      ),
      findsNothing,
    );
    expect(
      find.bySemanticsIdentifier(
        'retirement_lpp_regulation_reconfirm_cta',
      ),
      findsNothing,
    );
  });

  testWidgets('flag, provider, hydration, unavailable ledger, and profile hide',
      (tester) async {
    final candidate = _candidate();

    Future<void> expectHidden({
      required String reason,
      required _DashboardLedger ledger,
      DocumentProvider? documents,
    }) async {
      await tester.pumpWidget(_dashboard(ledger: ledger, documents: documents));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.bySemanticsIdentifier(_cardId), findsNothing, reason: reason);
      expect(find.bySemanticsIdentifier(_ctaId), findsNothing, reason: reason);
      expect(
        find.bySemanticsIdentifier(_recoveryId),
        findsNothing,
        reason: reason,
      );
      expect(
        find.bySemanticsIdentifier(_reconfirmCtaId),
        findsNothing,
        reason: reason,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    final flagLedger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: null,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final flagDocuments = await _documents(ledger: flagLedger);
    FeatureFlags.lppRegulationReferenceEnabled = false;
    await expectHidden(
      reason: 'flag off',
      ledger: flagLedger,
      documents: flagDocuments,
    );
    FeatureFlags.lppRegulationReferenceEnabled = true;

    final providerlessLedger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: null,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    await expectHidden(
      reason: 'DocumentProvider absent',
      ledger: providerlessLedger,
    );

    final idleLedger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: null,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final idleDocuments = DocumentProvider(
      referenceStore: _EmptyReferenceStore(),
    )..bindLedger(idleLedger);
    await expectHidden(
      reason: 'BND hydration idle',
      ledger: idleLedger,
      documents: idleDocuments,
    );

    final loadingLedger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: null,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final loadingStore = _LoadingReferenceStore();
    final loadingDocuments = DocumentProvider(referenceStore: loadingStore)
      ..bindLedger(loadingLedger);
    final loading = loadingDocuments.hydrateReferences();
    expect(
      loadingDocuments.referenceHydrationState,
      DocumentReferenceHydrationState.loading,
    );
    await expectHidden(
      reason: 'BND hydration loading',
      ledger: loadingLedger,
      documents: loadingDocuments,
    );
    loadingStore.gate.complete();
    await loading;

    final unavailableLedger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: null,
      referenceId: _mismatchedReferenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final unavailableDocuments = DocumentProvider(
      referenceStore: _EmptyReferenceStore(),
    )..bindLedger(unavailableLedger);
    await unavailableDocuments.hydrateReferences();
    await expectHidden(
      reason: 'ledger candidate unavailable',
      ledger: unavailableLedger,
      documents: unavailableDocuments,
    );

    final noProfileLedger = _DashboardLedger(
      value: null,
      snapshotId: null,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final noProfileDocuments = await _documents(ledger: noProfileLedger);
    await expectHidden(
      reason: 'profile absent',
      ledger: noProfileLedger,
      documents: noProfileDocuments,
    );

    for (final disposable in <ChangeNotifier>[
      flagDocuments,
      flagLedger,
      providerlessLedger,
      idleDocuments,
      idleLedger,
      loadingDocuments,
      loadingLedger,
      unavailableDocuments,
      unavailableLedger,
      noProfileDocuments,
      noProfileLedger,
    ]) {
      disposable.dispose();
    }
  });

  testWidgets(
      'CTA opens a local safe scrollable metadata-only handoff at 200 percent text scale',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final candidate = _candidate();
    final dynamic handoff =
        LppRegulationSpecialistHandoff.tryFromEvidence(candidate)!;
    final ledger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: null,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final documents = await _documents(ledger: ledger);
    addTearDown(documents.dispose);
    addTearDown(ledger.dispose);

    await tester.pumpWidget(_dashboard(ledger: ledger, documents: documents));
    await tester.pump(const Duration(milliseconds: 500));

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
      description: 'vertical retirement dashboard Scrollable',
    );
    expect(verticalScrollable, findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key(_ctaId)),
      400,
      scrollable: verticalScrollable,
    );
    final cta = find.bySemanticsIdentifier(_ctaId);
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();

    final sheet = find.bySemanticsIdentifier(_sheetId);
    expect(sheet, findsOneWidget);
    final l10n = S.of(tester.element(sheet))!;
    expect(
      find.descendant(of: sheet, matching: find.byType(SafeArea)),
      findsWidgets,
    );
    expect(
      find.descendant(of: sheet, matching: find.byType(Scrollable)),
      findsWidgets,
    );
    expect(find.bySemanticsIdentifier(_closeId), findsOneWidget);

    final title = find.bySemanticsIdentifier(_sheetTitleId);
    expect(title, findsOneWidget);
    expect(tester.getSemantics(title).flagsCollection.isHeader, isTrue);
    expect(find.bySemanticsIdentifier(_sheetPrivacyId), findsOneWidget);
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(l10n.retirementLppRegulationHandoffPrivacy),
      ),
      findsOneWidget,
    );

    expect(handoff.applicabilityQuestion, 'applicability');
    expect(handoff.topics, const <String>[
      'buyback',
      'conversion',
      'flexibleRetirement',
      'disability',
      'survivors',
      'divorce',
    ]);
    final applicability = find.bySemanticsIdentifier(
      'retirement_lpp_regulation_applicability_question',
    );
    expect(applicability, findsOneWidget);
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(
          'Ce règlement s’applique-t-il à ma situation ? Si oui, pour quelle '
          'période et selon quelle version ou quelles dispositions ?',
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(applicability).dy,
      lessThan(
        tester
            .getTopLeft(
              find.bySemanticsIdentifier(
                'retirement_lpp_regulation_topic_buyback',
              ),
            )
            .dy,
      ),
      reason: 'applicability is one distinct unanswered question before topics',
    );
    for (final forbiddenAnswer in const <String>[
      'retirement_lpp_regulation_applicability_yes',
      'retirement_lpp_regulation_applicability_no',
      'retirement_lpp_regulation_applicability_answer',
    ]) {
      expect(find.bySemanticsIdentifier(forbiddenAnswer), findsNothing);
    }

    for (final topic in handoff.topics) {
      expect(
        find.bySemanticsIdentifier('retirement_lpp_regulation_topic_$topic'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(
          'retirement_lpp_regulation_question_$topic',
        ),
        findsOneWidget,
      );
    }
    for (final localizedTopic in <String>[
      l10n.retirementLppRegulationQuestionBuyback,
      l10n.retirementLppRegulationQuestionConversion,
      l10n.retirementLppRegulationQuestionFlexibleRetirement,
      l10n.retirementLppRegulationQuestionDisability,
      l10n.retirementLppRegulationQuestionSurvivors,
      l10n.retirementLppRegulationQuestionDivorce,
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(localizedTopic)),
        findsOneWidget,
      );
    }
    for (final question in <String>[
      l10n.retirementLppRegulationQuestionBuybackBody,
      l10n.retirementLppRegulationQuestionConversionBody,
      l10n.retirementLppRegulationQuestionFlexibleRetirementBody,
      l10n.retirementLppRegulationQuestionDisabilityBody,
      l10n.retirementLppRegulationQuestionSurvivorsBody,
      l10n.retirementLppRegulationQuestionDivorceBody,
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(question)),
        findsOneWidget,
      );
    }

    final sourceDate = DateFormat.yMMMMd('fr').format(handoff.sourceDate);
    final confirmedAt = DateFormat.yMMMMd('fr').format(handoff.confirmedAt);
    final sheetText = _textUnder(tester, sheet);
    expect(sheetText, contains(sourceDate));
    expect(sheetText, contains('${handoff.legalYear}'));
    expect(sheetText, contains(confirmedAt));
    expect(
      sheetText,
      contains('MINT ne recommande aucune option'),
    );

    final lowered = sheetText.toLowerCase();
    expect(sheetText, isNot(contains(_referenceId)));
    for (final forbidden in <String>[
      'certificat',
      'chf',
      '%',
      'raw',
      'share',
      'route',
      'network',
    ]) {
      expect(lowered, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsIdentifier(_closeId));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier(_sheetId), findsNothing);
  });
}
