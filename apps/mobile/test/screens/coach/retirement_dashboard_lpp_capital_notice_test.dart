import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/swiss_civil_time.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';
const _replacementSnapshotId = '22222222-2222-4222-8222-222222222222';
const _referenceId = '33333333-3333-4333-8333-333333333333';
const _mismatchedReferenceId = '44444444-4444-4444-8444-444444444444';
const _authorityReferenceId = '55555555-5555-4555-8555-555555555555';
const _bannerId = 'retirement_lpp_capital_notice_deadline_education';

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
  bool matchesAcceptedLppCapitalNoticeReceipt(
    LppCapitalNoticeReceipt receipt,
  ) =>
      FeatureFlags.lppCapitalNoticeDeadlineEnabled &&
      receipt.snapshotId == snapshotId &&
      receipt.referenceId == referenceId &&
      receipt.confirmedAt == confirmedAt;

  @override
  bool matchesCurrentLppCapitalNoticeReference({
    required String referenceId,
    required String snapshotId,
    required DateTime confirmedAt,
  }) =>
      FeatureFlags.lppCapitalNoticeDeadlineEnabled &&
      FeatureFlags.lppRegulationReferenceEnabled &&
      snapshotId == this.snapshotId &&
      referenceId == this.referenceId &&
      confirmedAt == this.confirmedAt;

  @override
  bool matchesAcceptedLppRegulationReceipt(LppRegulationReceipt receipt) =>
      FeatureFlags.lppRegulationReferenceEnabled &&
      receipt.referenceId == _authorityReferenceId &&
      receipt.confirmedAt == confirmedAt;
}

final class _MemoryReferenceStore extends DocumentReferenceStore {
  _MemoryReferenceStore(this.references);

  final List<ConfirmedDocumentReference> references;

  @override
  Future<List<ConfirmedDocumentReference>> load() async => references;
}

String _civilDate(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

SpecialistReferenceEvidence _candidate({required DateTime deadline}) {
  final now = DateTime.now().toUtc();
  return SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': _referenceId,
      'kind': LppCapitalNoticeDeadline.kind,
      'ownerKind': LppEvidenceOwnerKind.self.wireName,
      'source': ProfileDataSource.certificate.name,
      'sourceDate': '2026-01-15',
      'legalYear': 2026,
      'confirmedAt':
          now.subtract(const Duration(days: 1)).toUtc().toIso8601String(),
      'deadlineDate': _civilDate(deadline),
    },
    expectedKind: SpecialistReferenceKind.lppCapitalNotice,
    now: now,
  )!;
}

SpecialistReferenceEvidence _regulationCandidate(DateTime confirmedAt) =>
    SpecialistReferenceEvidence.tryFromJson(
      <String, dynamic>{
        'referenceId': _authorityReferenceId,
        'kind': LppRegulationReference.kind,
        'ownerKind': LppEvidenceOwnerKind.self.wireName,
        'source': ProfileDataSource.certificate.name,
        'sourceDate': '2026-01-15',
        'legalYear': 2026,
        'confirmedAt': confirmedAt.toUtc().toIso8601String(),
        'fundRelationship': LppFundRelationship.currentFund.wireName,
      },
      expectedKind: SpecialistReferenceKind.lppRegulation,
      now: confirmedAt.add(const Duration(seconds: 1)),
    )!;

CoachProfile _profile(SpecialistReferenceEvidence candidate) => CoachProfile(
      firstName: 'Julien',
      birthYear: 1985,
      canton: 'VD',
      salaireBrutMensuel: 8000,
      lppCapitalNoticeDeadline: candidate,
      lppRegulationReference: _regulationCandidate(candidate.confirmedAt),
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
    referenceStore: _MemoryReferenceStore([
      ConfirmedDocumentReference(
        referenceId: referenceId,
        kind: LppCapitalNoticeDeadline.kind,
        snapshotId: snapshotId ?? ledger.snapshotId,
        ownerKind: LppEvidenceOwnerKind.self,
        confirmedAt: ledger.confirmedAt,
      ),
      ConfirmedDocumentReference(
        referenceId: _authorityReferenceId,
        kind: ConfirmedDocumentReference.lppRegulationKind,
        ownerKind: LppEvidenceOwnerKind.self,
        confirmedAt: ledger.confirmedAt,
      ),
    ]),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
    FeatureFlags.lppRegulationReferenceEnabled = true;
  });

  tearDown(() {
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
    FeatureFlags.lppRegulationReferenceEnabled = false;
  });

  testWidgets(
      'exact known BND renders education on deadline day without changing the AVS state or CTA',
      (tester) async {
    final today = SwissCivilTime.civilDate(DateTime.now());
    final candidate = _candidate(deadline: today);
    final ledger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: _snapshotId,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final documents = await _documents(ledger: ledger);
    addTearDown(ledger.dispose);
    addTearDown(documents.dispose);

    await tester.pumpWidget(_dashboard(ledger: ledger, documents: documents));
    await tester.pump(const Duration(milliseconds: 500));

    final banner = find.bySemanticsIdentifier(_bannerId);
    expect(banner, findsOneWidget);
    expect(
      find.byKey(const Key('${_bannerId}_known')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('${_bannerId}_stale')), findsNothing);
    expect(
        find.byKey(const Key('retirement_missing_avs_state')), findsOneWidget);
    expect(
        find.byKey(const Key('retirement_avs_document_cta')), findsOneWidget);
    expect(
      find.descendant(of: banner, matching: find.byType(ButtonStyleButton)),
      findsNothing,
      reason: 'the deadline surface is education, not an advice-shaped CTA',
    );
  });

  testWidgets('the next Zurich civil day renders the exact notice as stale',
      (tester) async {
    final today = SwissCivilTime.civilDate(DateTime.now());
    final candidate = _candidate(
      deadline: today.subtract(const Duration(days: 1)),
    );
    final ledger = _DashboardLedger(
      value: _profile(candidate),
      snapshotId: _snapshotId,
      referenceId: candidate.referenceId,
      confirmedAt: candidate.confirmedAt,
    );
    final documents = await _documents(ledger: ledger);
    addTearDown(ledger.dispose);
    addTearDown(documents.dispose);

    await tester.pumpWidget(_dashboard(ledger: ledger, documents: documents));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsIdentifier(_bannerId), findsOneWidget);
    expect(find.byKey(const Key('${_bannerId}_stale')), findsOneWidget);
    expect(find.byKey(const Key('${_bannerId}_known')), findsNothing);
    expect(
        find.byKey(const Key('retirement_missing_avs_state')), findsOneWidget);
  });

  testWidgets(
      'flag, BND identity, snapshot replacement, provider, and profile all fail closed',
      (tester) async {
    final today = SwissCivilTime.civilDate(DateTime.now());
    final candidate = _candidate(deadline: today);

    Future<void> expectHidden({
      required String reason,
      required _DashboardLedger ledger,
      DocumentProvider? documents,
    }) async {
      await tester.pumpWidget(_dashboard(ledger: ledger, documents: documents));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.bySemanticsIdentifier(_bannerId),
        findsNothing,
        reason: reason,
      );
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
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
    await expectHidden(
      reason: 'flag off',
      ledger: flagLedger,
      documents: flagDocuments,
    );
    FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;

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
      flagLedger,
      flagDocuments,
      mismatchLedger,
      mismatchDocuments,
      replacedLedger,
      replacedDocuments,
      providerlessLedger,
      noProfileLedger,
      noProfileDocuments,
    ]) {
      disposable.dispose();
    }
  });
}
