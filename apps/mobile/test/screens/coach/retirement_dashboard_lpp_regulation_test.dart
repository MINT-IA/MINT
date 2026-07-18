import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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
const _closeId = 'retirement_lpp_regulation_handoff_close';

final class _DashboardLedger extends CoachProfileProvider {
  _DashboardLedger({
    required this.value,
    required this.snapshotId,
    required this.referenceId,
    required this.confirmedAt,
  });

  final CoachProfile? value;
  final String snapshotId;
  final String referenceId;
  final DateTime confirmedAt;

  @override
  CoachProfile? get profile => value;

  @override
  bool get hasProfile => value != null;

  @override
  bool get isLoaded => true;

  @override
  String? currentLppSnapshotId(LppEvidenceOwnerKind ownerKind) =>
      ownerKind == LppEvidenceOwnerKind.self ? snapshotId : null;

  @override
  bool matchesAcceptedLppRegulationReceipt(LppRegulationReceipt receipt) =>
      FeatureFlags.lppRegulationReferenceEnabled &&
      receipt.snapshotId == snapshotId &&
      receipt.referenceId == referenceId &&
      receipt.confirmedAt == confirmedAt;
}

final class _MemoryReferenceStore extends DocumentReferenceStore {
  _MemoryReferenceStore(this.reference);

  final ConfirmedDocumentReference reference;

  @override
  Future<List<ConfirmedDocumentReference>> load() async => [reference];
}

SpecialistReferenceEvidence _candidate() {
  final now = DateTime.now().toUtc();
  return SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': _referenceId,
      'kind': LppRegulationReference.kind,
      'ownerKind': LppEvidenceOwnerKind.self.wireName,
      'source': ProfileDataSource.certificate.name,
      'sourceDate': '2017-02-03',
      'legalYear': 2018,
      'confirmedAt': now.subtract(const Duration(days: 1)).toIso8601String(),
    },
    expectedKind: SpecialistReferenceKind.lppRegulation,
    now: now,
  )!;
}

CoachProfile _profile(SpecialistReferenceEvidence candidate) => CoachProfile(
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

Future<DocumentProvider> _documents({
  required _DashboardLedger ledger,
  String referenceId = _referenceId,
  String? snapshotId,
}) async {
  final documents = DocumentProvider(
    referenceStore: _MemoryReferenceStore(
      ConfirmedDocumentReference(
        referenceId: referenceId,
        kind: LppRegulationReference.kind,
        snapshotId: snapshotId ?? ledger.snapshotId,
        ownerKind: LppEvidenceOwnerKind.self,
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
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: RetirementDashboardScreen(),
    ),
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
      snapshotId: _snapshotId,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
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
    for (final falseStale in <String>[
      'périmé',
      'obsolète',
      'expiré',
      'à renouveler',
    ]) {
      expect(cardText, isNot(contains(falseStale)), reason: falseStale);
    }
  });

  testWidgets('flag, provider, BND identity, snapshot, and profile fail closed',
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
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    final flagLedger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: _snapshotId,
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
      snapshotId: _snapshotId,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    await expectHidden(
      reason: 'DocumentProvider absent',
      ledger: providerlessLedger,
    );

    final mismatchLedger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: _snapshotId,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final mismatchDocuments = await _documents(
      ledger: mismatchLedger,
      referenceId: _mismatchedReferenceId,
    );
    await expectHidden(
      reason: 'BND reference mismatch',
      ledger: mismatchLedger,
      documents: mismatchDocuments,
    );

    final replacedLedger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: _replacementSnapshotId,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final replacedDocuments = await _documents(
      ledger: replacedLedger,
      snapshotId: _snapshotId,
    );
    await expectHidden(
      reason: 'numeric self snapshot replacement',
      ledger: replacedLedger,
      documents: replacedDocuments,
    );

    final noProfileLedger = _DashboardLedger(
      value: null,
      snapshotId: _snapshotId,
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
      mismatchDocuments,
      mismatchLedger,
      replacedDocuments,
      replacedLedger,
      noProfileDocuments,
      noProfileLedger,
    ]) {
      disposable.dispose();
    }
  });

  testWidgets(
      'CTA opens a local safe scrollable metadata-only handoff at 200 percent text scale',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      semantics.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final candidate = _candidate();
    final handoff = LppRegulationSpecialistHandoff.tryFromEvidence(candidate)!;
    final ledger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: _snapshotId,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final documents = await _documents(ledger: ledger);
    addTearDown(documents.dispose);
    addTearDown(ledger.dispose);

    await tester.pumpWidget(_dashboard(ledger: ledger, documents: documents));
    await tester.pump(const Duration(milliseconds: 500));

    final cta = find.bySemanticsIdentifier(_ctaId);
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    final sheet = find.bySemanticsIdentifier(_sheetId);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.byType(SafeArea)),
      findsWidgets,
    );
    expect(
      find.descendant(of: sheet, matching: find.byType(Scrollable)),
      findsWidgets,
    );
    expect(find.bySemanticsIdentifier(_closeId), findsOneWidget);

    for (final topic in handoff.topics) {
      expect(
        find.bySemanticsIdentifier('retirement_lpp_regulation_topic_$topic'),
        findsOneWidget,
      );
    }
    for (final localizedTopic in <String>[
      'Rachats',
      'Conversion de la rente',
      'Retraite flexible',
      'Invalidité',
      'Prestations aux survivants',
      'Divorce',
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(localizedTopic)),
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
