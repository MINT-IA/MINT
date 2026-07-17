import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/coach_profile_owner.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/screens/aujourdhui/aujourdhui_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/coach/plan_preview_card.dart';
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';
import 'package:mint_mobile/widgets/home/financial_plan_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _salaryPath = 'salaireBrutMensuel';
const _cantonPath = 'canton';
const _dateOfBirthPath = 'dateOfBirth';
const _genderPath = 'gender';
const _lppTotalPath = 'prevoyance.avoirLppTotal';
const _lppMandatoryPath = 'prevoyance.avoirLppObligatoire';
const _lppExtraMandatoryPath = 'prevoyance.avoirLppSurobligatoire';
const _lppReturnPath = 'prevoyance.rendementCaisse';
const _pillar3aPath = 'prevoyance.totalEpargne3a';
const _hasPensionFundPath = 'prevoyance.hasPensionFund';
const _profileOwnerId = '11111111-1111-4111-8111-111111111111';

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async => null;
}

class _DormantTimer implements Timer {
  var _active = true;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

class _CountingRevision extends ValueNotifier<int> {
  _CountingRevision(super.value);

  int addCalls = 0;
  int removeCalls = 0;

  @override
  void addListener(VoidCallback listener) {
    addCalls += 1;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeCalls += 1;
    super.removeListener(listener);
  }
}

/// Minimal observable ledger for provider-contract tests.
///
/// The production provider persists and invalidates several unrelated caches
/// on every update. Those side effects are covered elsewhere and would make
/// this RED contract depend on asynchronous storage races instead of plan
/// staleness.
class _TestLedger extends CoachProfileProvider {
  _TestLedger(this._testProfile, {bool isLoaded = true})
      : _testIsLoaded = isLoaded;

  CoachProfile? _testProfile;
  bool _testIsLoaded;
  Completer<Map<String, dynamic>>? _reportAnswersCompleter;
  int waitForReportAnswersCalls = 0;
  int addListenerCalls = 0;
  int removeListenerCalls = 0;

  @override
  CoachProfile? get profile => _testProfile;

  @override
  bool get isLoaded => _testIsLoaded;

  @override
  String get canonicalProfileOwnerId => _profileOwnerId;

  @override
  Future<String> ensureCanonicalProfileOwner() async => _profileOwnerId;

  @override
  Future<String> previewCanonicalProfileOwner() async => _profileOwnerId;

  @override
  Future<String> commitStagedCanonicalProfileOwner(String ownerId) async {
    if (ownerId != _profileOwnerId) throw StateError('synthetic owner drift');
    return _profileOwnerId;
  }

  @override
  LppEvidenceSnapshot? currentLppSnapshot(
    LppEvidenceOwnerKind ownerKind,
  ) {
    final profile = _testProfile;
    final total = profile?.prevoyance.avoirLppTotal;
    final updatedAt = profile?.dataTimestamps[_lppTotalPath];
    final source = profile?.dataSources[_lppTotalPath];
    if (ownerKind != LppEvidenceOwnerKind.self ||
        profile == null ||
        total == null ||
        updatedAt == null ||
        source == null) {
      return null;
    }
    return LppEvidenceSnapshot(
      snapshotId: '22222222-2222-4222-8222-222222222222',
      facts: {
        LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
          value: total,
          unit: LppEvidenceUnit.chf,
          profileOwnerId: _profileOwnerId,
          actorProfileOwnerId: _profileOwnerId,
          source: source.name,
          sourceDate: profile.dataSourceDates[_lppTotalPath],
          updatedAt: updatedAt,
        ),
      },
    );
  }

  @override
  Future<Map<String, dynamic>> waitForReportAnswers({
    Duration timeout = const Duration(seconds: 8),
  }) {
    if (_testIsLoaded) return Future.value(const <String, dynamic>{});
    waitForReportAnswersCalls++;
    return (_reportAnswersCompleter ??= Completer<Map<String, dynamic>>())
        .future;
  }

  @override
  void addListener(VoidCallback listener) {
    addListenerCalls++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeListenerCalls++;
    super.removeListener(listener);
  }

  @override
  void updateProfile(CoachProfile updated) {
    _testProfile = updated;
    _testIsLoaded = true;
    notifyListeners();
  }

  void replaceProfileSilently(CoachProfile profile) {
    _testProfile = profile;
    _testIsLoaded = true;
  }

  void beginLedgerSwitch({CoachProfile? retainedProfile}) {
    _testProfile = retainedProfile;
    _testIsLoaded = false;
    notifyListeners();
  }

  void completeLedgerSwitch(CoachProfile? profile) {
    _testProfile = profile;
    _testIsLoaded = true;
    final reportAnswersCompleter = _reportAnswersCompleter;
    if (reportAnswersCompleter != null && !reportAnswersCompleter.isCompleted) {
      reportAnswersCompleter.complete(const <String, dynamic>{});
    }
    notifyListeners();
  }
}

class _DeferredLoadPlanProvider extends FinancialPlanProvider {
  final Completer<void> _loadCompleter = Completer<void>();
  int loadCalls = 0;
  int generatedPlanWrites = 0;

  @override
  Future<void> loadFromPersistence() {
    loadCalls++;
    return _loadCompleter.future;
  }

  @override
  Future<void> setPlan(FinancialPlan plan) async {
    generatedPlanWrites++;
    setPlanDirect(plan);
  }

  void completeLoadWith(FinancialPlan plan) {
    setPlanDirect(plan);
    _loadCompleter.complete();
  }

  void completeEmptyLoad() {
    _loadCompleter.complete();
  }
}

class _CountingPlanProvider extends FinancialPlanProvider {
  _CountingPlanProvider() : super(timerFactory: (_, __) => _DormantTimer());

  int setPlanCalls = 0;

  @override
  Future<void> setPlan(FinancialPlan plan) {
    setPlanCalls++;
    return super.setPlan(plan);
  }
}

class _EmptyTimelineProvider extends TimelineProvider {
  @override
  bool get isLoading => false;

  @override
  bool get isEmpty => true;

  @override
  Future<void> refresh({bool includeAuthenticatedNetwork = true}) async {}
}

CoachProfile _profile({
  String firstName = 'Synthetic',
  int birthYear = 1985,
  bool useDateOfBirth = true,
  int dateOfBirthDay = 12,
  String gender = 'M',
  String canton = 'VD',
  double salary = 8000,
  double months = 13,
  double? lppTotal = 240000,
  double? lppMandatory = 150000,
  double? lppExtraMandatory = 90000,
  double lppReturn = 0.02,
  bool lppReturnKnown = true,
  double pillar3a = 42000,
  Map<String, ProfileDataSource> sources = const {},
  Map<String, DateTime> timestamps = const {},
  Map<String, DateTime?> sourceDates = const {},
  String goalLabel = 'Objectif synthétique',
  DateTime? goalTargetDate,
  DateTime? updatedAt,
}) {
  return CoachProfile(
    firstName: firstName,
    birthYear: birthYear,
    dateOfBirth: useDateOfBirth ? DateTime.utc(1985, 4, dateOfBirthDay) : null,
    gender: gender,
    canton: canton,
    salaireBrutMensuel: salary,
    nombreDeMois: months,
    prevoyance: PrevoyanceProfile(
      hasPensionFund: true,
      avoirLppTotal: lppTotal,
      avoirLppObligatoire: lppMandatory,
      avoirLppSurobligatoire: lppExtraMandatory,
      rendementCaisse: lppReturn,
      rendementCaisseConnu: lppReturnKnown,
      totalEpargne3a: pillar3a,
    ),
    dataSources: sources,
    dataTimestamps: timestamps,
    dataSourceDates: sourceDates,
    inferDataSources: false,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: goalTargetDate ?? DateTime.utc(2045, 6, 1),
      label: goalLabel,
    ),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: updatedAt ?? DateTime.utc(2026, 7, 1),
  );
}

CoachProfile _projectionReadyProfile({double salary = 8000}) {
  final stamp = DateTime.utc(2026, 7, 1);
  const paths = <String>[
    _salaryPath,
    _cantonPath,
    _dateOfBirthPath,
    _genderPath,
    _lppTotalPath,
    _lppMandatoryPath,
    _lppExtraMandatoryPath,
    _lppReturnPath,
    _pillar3aPath,
    _hasPensionFundPath,
  ];
  return _profile(
    salary: salary,
    sources: {
      for (final path in paths)
        path: path == _lppTotalPath
            ? ProfileDataSource.certificate
            : ProfileDataSource.userInput,
    },
    timestamps: {for (final path in paths) path: stamp},
    sourceDates: {for (final path in paths) path: stamp},
  );
}

FinancialPlan _planFor(
  CoachProfile profile, {
  String id = 'synthetic-plan',
  String? profileHash,
  double monthlyTarget = 12345,
}) {
  return FinancialPlan(
    id: id,
    goalDescription: 'Objectif synthétique',
    goalCategory: 'goal_retirement_plan',
    monthlyTarget: monthlyTarget,
    milestones: [
      PlanMilestone(
        targetDate: DateTime.utc(2045, 6, 1),
        targetAmount: 500000,
        description: 'Jalon synthétique',
      ),
    ],
    projectedOutcome: 500000,
    projectedLow: 400000,
    projectedHigh: 600000,
    targetDate: DateTime.utc(2045, 6, 1),
    generatedAt: DateTime.utc(2026, 7, 1),
    profileHashAtGeneration: profileHash ??
        'mint-plan-dependency:v3:sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    coachNarrative: 'Narration synthétique.',
    confidenceLevel: 80,
    sources: const ['LPP art. 14'],
    disclaimer: 'Outil éducatif.',
    goalAmount: 500000,
    projectionAssumptions: FinancialPlanProjectionAssumptions(
      caisseReturnBase: 0.02,
      caisseReturnLow: 0.01,
      caisseReturnHigh: 0.03,
      supplementalMonthlySavingsReturn: 0,
      salaryBasis: const FinancialPlanSalaryBasis(
        kind: 'monthlySalaryTimesTwelve',
        annualChf: 96000,
      ),
      bonificationBasis: const FinancialPlanBonificationBasis(
        kind: 'legalAgeSchedule',
      ),
      projectionAsOf: DateTime.utc(2026, 7, 1),
    ),
  );
}

Future<FinancialPlan> _validRetirementPlanFor(
  CoachProfile profile, {
  required DateTime now,
}) async {
  final ledger = _TestLedger(profile);
  try {
    final draft = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_retirement_plan',
      targetDate: DateTime.utc(2045, 6, 1),
      profile: profile,
      profileOwnerId: _profileOwnerId,
      selfLppSnapshot: ledger.currentLppSnapshot(
        LppEvidenceOwnerKind.self,
      ),
      goalAmount: 500000,
      prospectiveLppReturn: 0.02,
      now: now,
    );
    return draft.copyWith(confirmedAt: now);
  } finally {
    ledger.dispose();
  }
}

CoachProfileProvider _ledger(
  CoachProfile? profile, {
  bool isLoaded = true,
}) {
  return _TestLedger(profile, isLoaded: isLoaded);
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

bool _visibleTextContainsDigits(WidgetTester tester, String digits) {
  return tester.widgetList<Text>(find.byType(Text)).any((text) {
    final normalized = (text.data ?? '').replaceAll(RegExp(r'\D'), '');
    return normalized.contains(digits);
  });
}

Widget _planToolHarness({
  required CoachProfileProvider ledger,
  required FinancialPlanProvider plans,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
      ChangeNotifierProvider<FinancialPlanProvider>.value(value: plans),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr')],
      home: Scaffold(
        body: Builder(
          builder: (context) => WidgetRenderer.build(
            context,
            const RagToolCall(
              name: 'generate_financial_plan',
              input: {
                'goal': 'Objectif synthétique',
                'monthly_amount': 99999.0,
                'narrative': 'Narration synthétique.',
              },
            ),
          )!,
        ),
      ),
    ),
  );
}

Widget _localizedHarness(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    home: Scaffold(body: child),
  );
}

Widget _aujourdhuiHarness({
  required CoachProfileProvider ledger,
  required FinancialPlanProvider plans,
  required TimelineProvider timeline,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
      ChangeNotifierProvider<FinancialPlanProvider>.value(value: plans),
      ChangeNotifierProvider<TimelineProvider>.value(value: timeline),
      ChangeNotifierProvider<MintStateProvider>(
        create: (_) => MintStateProvider(),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('fr')],
      home: AujourdhuiScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
    FeatureFlags.financialPlanSetupEnabled = true;
    RegulatorySyncService.clearCache();
  });

  tearDown(() {
    FeatureFlags.financialPlanSetupEnabled = false;
    RegulatorySyncService.clearCache();
  });

  group('fail-closed production plan consumer', () {
    testWidgets('unloaded ledger never exposes persisted plan figures',
        (tester) async {
      final profile = _profile();
      final ledger = _ledger(null, isLoaded: false);
      addTearDown(ledger.dispose);
      final plans = FinancialPlanProvider()
        ..setPlanDirect(
          _planFor(profile, id: 'unknown-plan', monthlyTarget: 12345),
        );
      addTearDown(plans.dispose);
      plans.attachProfileProvider(ledger);

      await tester.pumpWidget(_planToolHarness(ledger: ledger, plans: plans));
      await tester.pump();

      expect(plans.isPlanStale, isTrue);
      expect(find.byType(PlanPreviewCard), findsNothing);
      expect(
        find.bySemanticsIdentifier('financial_plan_stale_state'),
        findsOneWidget,
      );
      for (final forbiddenDigits in [
        '12345',
        '400000',
        '500000',
        '600000',
        '99999',
      ]) {
        expect(_visibleTextContainsDigits(tester, forbiddenDigits), isFalse);
      }
    });

    testWidgets(
        'pending renderer awaits persistence before considering generation',
        (tester) async {
      final profile = _profile();
      final cachedPlan = _planFor(
        profile,
        id: 'hydrated-before-generation',
        monthlyTarget: 4321,
      );
      final ledger = _ledger(profile);
      addTearDown(ledger.dispose);
      final plans = _DeferredLoadPlanProvider();
      addTearDown(plans.dispose);

      await tester.pumpWidget(_planToolHarness(ledger: ledger, plans: plans));
      await _pumpFrames(tester, frames: 10);
      final loadCallsBeforeCompletion = plans.loadCalls;
      final writesBeforeCompletion = plans.generatedPlanWrites;

      plans.completeLoadWith(cachedPlan);
      await _pumpFrames(tester, frames: 10);

      expect(loadCallsBeforeCompletion, 1);
      expect(
        writesBeforeCompletion,
        0,
        reason: 'generation must not race a pending persisted-plan read',
      );
      expect(plans.currentPlan?.id, 'hydrated-before-generation');
      expect(plans.generatedPlanWrites, 0);
      expect(find.byType(PlanPreviewCard), findsOneWidget);
    });

    for (final retainsCachedProfile in [false, true]) {
      testWidgets(
          'empty plan hydration opens setup without writing a plan '
          '(cached profile: $retainsCachedProfile)', (tester) async {
        final profile = _profile();
        final ledger = _ledger(
          retainsCachedProfile ? profile : null,
          isLoaded: false,
        ) as _TestLedger;
        addTearDown(ledger.dispose);
        final plans = _DeferredLoadPlanProvider();
        addTearDown(plans.dispose);

        await tester.pumpWidget(_planToolHarness(ledger: ledger, plans: plans));
        await _pumpFrames(tester, frames: 5);
        final writesBeforePlanHydration = plans.generatedPlanWrites;

        plans.completeEmptyLoad();
        await _pumpFrames(tester, frames: 5);
        final writesBeforeLedgerHydration = plans.generatedPlanWrites;
        final ledgerWaitCalls = ledger.waitForReportAnswersCalls;

        ledger.completeLedgerSwitch(profile);
        await _pumpFrames(tester, frames: 20);

        expect(plans.loadCalls, 1);
        expect(
          writesBeforePlanHydration,
          0,
          reason: 'generation must await the persisted-plan read',
        );
        expect(ledgerWaitCalls, 0);
        expect(
          writesBeforeLedgerHydration,
          0,
          reason: 'unloaded ledger facts are not authoritative',
        );
        expect(plans.generatedPlanWrites, 0);
        expect(plans.currentPlan, isNull);
        expect(
          find.bySemanticsIdentifier('financial_plan_setup'),
          findsOneWidget,
          reason: 'An intent-only tool opens the user-owned setup after empty '
              'hydration; missing scenario inputs are not a generation error.',
        );
      });
    }

    testWidgets('stale cached figures are suppressed from WidgetRenderer',
        (tester) async {
      final currentProfile = _projectionReadyProfile();
      final staleProfile = _projectionReadyProfile(salary: 7000);
      final ledger = _ledger(currentProfile);
      addTearDown(ledger.dispose);
      final plans = FinancialPlanProvider()
        ..setPlanDirect(
          _planFor(staleProfile, id: 'stale-plan', monthlyTarget: 12345),
        )
        ..markStale();
      addTearDown(plans.dispose);

      await tester.pumpWidget(_planToolHarness(ledger: ledger, plans: plans));
      await tester.pump();

      expect(find.byType(PlanPreviewCard), findsNothing);
      expect(
        find.bySemanticsIdentifier('financial_plan_stale_state'),
        findsOneWidget,
      );
      for (final forbiddenDigits in [
        '12345',
        '400000',
        '500000',
        '600000',
        '99999',
      ]) {
        expect(
          _visibleTextContainsDigits(tester, forbiddenDigits),
          isFalse,
          reason: 'stale and LLM-provided figures must be fail-closed',
        );
      }
    });

    testWidgets('Coach stale recovery opens standard review without writing',
        (tester) async {
      final currentProfile = _projectionReadyProfile();
      final staleProfile = _projectionReadyProfile(salary: 7000);
      final ledger = _ledger(currentProfile);
      addTearDown(ledger.dispose);
      final plans = _CountingPlanProvider()
        ..setPlanDirect(
          _planFor(staleProfile, id: 'stale-plan', monthlyTarget: 12345),
        )
        ..markStale();
      addTearDown(plans.dispose);

      await tester.pumpWidget(_planToolHarness(ledger: ledger, plans: plans));
      await tester.pump();

      final finder = find.bySemanticsIdentifier(
        'financial_plan_stale_recalculate',
      );
      expect(finder, findsOneWidget);
      expect(
        tester.getSemantics(finder).getSemanticsData().hasAction(
              SemanticsAction.tap,
            ),
        isTrue,
      );

      await tester.tap(finder);
      await _pumpFrames(tester, frames: 10);

      expect(plans.setPlanCalls, 0);
      expect(plans.currentPlan?.id, 'stale-plan');
      expect(plans.isPlanStale, isTrue);
      expect(
        find.bySemanticsIdentifier('financial_plan_setup'),
        findsOneWidget,
      );
    });

    testWidgets('app resume rechecks a silently changed ledger',
        (tester) async {
      final now = DateTime.utc(2026, 7, 16, 12);
      final profile = _projectionReadyProfile();
      final ledger = _ledger(profile) as _TestLedger;
      final plan = await _validRetirementPlanFor(profile, now: now);
      final plans = FinancialPlanProvider(
        clock: () => now,
        timerFactory: (_, __) => _DormantTimer(),
      )
        ..setPlanDirect(plan)
        ..attachProfileProvider(ledger);
      addTearDown(ledger.dispose);
      addTearDown(plans.dispose);
      expect(plans.isPlanStale, isFalse);

      ledger.replaceProfileSilently(_projectionReadyProfile(salary: 9000));
      expect(plans.isPlanStale, isFalse);
      plans.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();

      expect(plans.isPlanStale, isTrue);
    });

    test('canonical AVS gender drift makes an LPP plan stale', () async {
      final now = DateTime.utc(2026, 7, 16, 12);
      final profile = _projectionReadyProfile();
      final ledger = _ledger(profile) as _TestLedger;
      final plan = await _validRetirementPlanFor(profile, now: now);
      final plans = FinancialPlanProvider(
        clock: () => now,
        timerFactory: (_, __) => _DormantTimer(),
      )
        ..setPlanDirect(plan)
        ..attachProfileProvider(ledger);
      addTearDown(ledger.dispose);
      addTearDown(plans.dispose);
      expect(plans.isPlanStale, isFalse);

      ledger.updateProfile(_projectionReadyProfile().copyWith(gender: 'F'));

      expect(plans.isPlanStale, isTrue);
    });

    test('regulatory revisions reconcile selectively without regeneration',
        () async {
      final now = DateTime.utc(2026, 7, 16, 12);
      final profile = _projectionReadyProfile();
      final ledger = _ledger(profile) as _TestLedger;
      final plan = await _validRetirementPlanFor(profile, now: now);
      var saveCalls = 0;
      final plans = FinancialPlanProvider(
        clock: () => now,
        timerFactory: (_, __) => _DormantTimer(),
        saveAction: (_) async => saveCalls++,
      )
        ..setPlanDirect(plan)
        ..attachProfileProvider(ledger)
        ..attachRegulatoryRevision(
          RegulatorySyncService.revisionListenable,
        );
      addTearDown(ledger.dispose);
      addTearDown(plans.dispose);
      expect(plans.isPlanStale, isFalse);

      RegulatorySyncService.setMockCache({
        'pillar3a.max_with_lpp': 9999,
      });
      expect(
        plans.isPlanStale,
        isFalse,
        reason: 'an unconsumed constant must not stale this plan',
      );

      RegulatorySyncService.setMockCache({
        'lpp.entry_threshold': 23000,
      });
      expect(plans.isPlanStale, isTrue);
      expect(plans.currentPlan, same(plan));
      expect(saveCalls, 0, reason: 'invalidation must never auto-regenerate');
    });

    test('regulatory attachment is idempotent and disposal is safe', () {
      final revision = _CountingRevision(0);
      final plans = FinancialPlanProvider()
        ..attachRegulatoryRevision(revision)
        ..attachRegulatoryRevision(revision);

      expect(revision.addCalls, 1);
      plans.dispose();
      expect(revision.removeCalls, 1);
      expect(() => revision.value = 1, returnsNormally);
    });

    testWidgets('dispose cancels a queued post-frame stale notification',
        (tester) async {
      final now = DateTime.utc(2026, 7, 16, 12);
      final profile = _projectionReadyProfile();
      final ledger = _ledger(profile) as _TestLedger;
      final plan = await _validRetirementPlanFor(profile, now: now);
      final plans = FinancialPlanProvider(
        clock: () => now,
        timerFactory: (_, __) => _DormantTimer(),
      )
        ..setPlanDirect(plan)
        ..attachProfileProvider(ledger);
      addTearDown(ledger.dispose);
      var notifications = 0;
      plans.addListener(() => notifications++);

      ledger.updateProfile(_projectionReadyProfile(salary: 9000));
      expect(plans.isPlanStale, isTrue);
      plans.dispose();
      await tester.pump();

      expect(notifications, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('first-class cold financial plan surface', () {
    testWidgets(
        'real MintApp wiring invalidates a persisted v3 plan and masks its figures',
        (tester) async {
      final inputAsOf = DateTime.now().toUtc().subtract(
            const Duration(seconds: 1),
          );
      final targetDate = DateTime.utc(inputAsOf.year + 25, 7, 16);
      final dateOfBirth = DateTime.utc(inputAsOf.year - 40, 1, 1);
      final answers = <String, dynamic>{
        'q_firstname': 'MintApp',
        'q_birth_year': inputAsOf.year - 40,
        'q_date_of_birth': '${dateOfBirth.year.toString().padLeft(4, '0')}-'
            '${dateOfBirth.month.toString().padLeft(2, '0')}-'
            '${dateOfBirth.day.toString().padLeft(2, '0')}',
        'q_canton': 'VD',
        'q_gross_salary_annual': 96000.0,
        'q_nombre_mois': 12.0,
        'q_has_pension_fund': false,
        '_coach_updated_at': inputAsOf.toIso8601String(),
        coachProfileOwnerRootKey:
            const CoachProfileOwnerRoot(_profileOwnerId).toJsonString(),
        '__provenance': {
          _dateOfBirthPath: {
            'source': ProfileDataSource.userInput.name,
            'updatedAt': inputAsOf.toIso8601String(),
            'sourceDate': null,
          },
          _hasPensionFundPath: {
            'source': ProfileDataSource.userInput.name,
            'updatedAt': inputAsOf.toIso8601String(),
            'sourceDate': null,
          },
        },
      };
      await ReportPersistenceService.saveAnswers(answers);
      await ReportPersistenceService.setCompleted(true);
      final persistedAnswers = await ReportPersistenceService.loadAnswers();
      final seededProfile = CoachProfile.fromWizardAnswers(persistedAnswers);
      expect(seededProfile.prevoyance.hasPensionFund, isFalse);
      expect(
        seededProfile.dataSources[_hasPensionFundPath],
        ProfileDataSource.userInput,
      );
      final draft = await PlanGenerationService.generate(
        goalDescription: 'Montant sentinelle MintApp',
        goalCategory: 'goal_retirement_plan',
        targetDate: targetDate,
        profile: seededProfile,
        profileOwnerId: _profileOwnerId,
        selfLppSnapshot: null,
        goalAmount: 3333333,
        prospectiveLppReturn: null,
        now: inputAsOf,
      );
      final plan = draft.copyWith(confirmedAt: inputAsOf);
      await FinancialPlanService.save(plan);

      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(const MintApp());
      await _pumpFrames(tester, frames: 40);

      final appContext = tester.element(find.byType(MaterialApp));
      final ledger = appContext.read<CoachProfileProvider>();
      final plans = appContext.read<FinancialPlanProvider>();
      expect(ledger.canonicalProfileOwnerId, _profileOwnerId);
      expect(plans.currentPlan?.id, plan.id);
      expect(plans.isPlanStale, isFalse);
      final routedContext = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routedContext).go('/home');
      await _pumpFrames(tester, frames: 30);
      expect(find.byType(FinancialPlanCard), findsOneWidget);
      final monthlyDigits = plan.monthlyTarget.round().toString();
      expect(_visibleTextContainsDigits(tester, monthlyDigits), isTrue);

      await ledger.mergeAnswers({'q_has_pension_fund': true});
      await _pumpFrames(tester, frames: 20);

      expect(plans.isPlanStale, isTrue);
      expect(
        find.bySemanticsIdentifier('financial_plan_stale_state'),
        findsOneWidget,
      );
      expect(_visibleTextContainsDigits(tester, monthlyDigits), isFalse);
      expect(_visibleTextContainsDigits(tester, '3333333'), isFalse);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('false kill switch keeps real MintApp plan storage dormant',
        (tester) async {
      FeatureFlags.financialPlanSetupEnabled = false;
      final legacy = _planFor(
        _projectionReadyProfile(salary: 7000),
        id: 'flagged-off-legacy-plan',
      );
      final raw = jsonEncode([legacy.toJson()]);
      SharedPreferences.setMockInitialValues({'financial_plan_v1': raw});
      FlutterSecureStorage.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(const MintApp());
      await _pumpFrames(tester, frames: 24);

      final appContext = tester.element(find.byType(MaterialApp));
      final plans = appContext.read<FinancialPlanProvider>();
      expect(plans.debugHasRegulatoryRevisionListener, isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(plans.currentPlan, isNull);
      expect(preferences.getString('financial_plan_v1'), raw);
      expect(
        find.bySemanticsIdentifier('financial_plan_stale_recalculate'),
        findsNothing,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('false kill switch hides Today plan surfaces defensively',
        (tester) async {
      FeatureFlags.financialPlanSetupEnabled = false;
      final ledger = _ledger(_projectionReadyProfile());
      final plans = FinancialPlanProvider()
        ..setPlanDirect(
          _planFor(
            _projectionReadyProfile(salary: 7000),
            id: 'flagged-off-today-plan',
          ),
        )
        ..markStale();
      final timeline = _EmptyTimelineProvider();
      addTearDown(ledger.dispose);
      addTearDown(plans.dispose);
      addTearDown(timeline.dispose);

      await tester.pumpWidget(
        _aujourdhuiHarness(
          ledger: ledger,
          plans: plans,
          timeline: timeline,
        ),
      );
      await tester.pump();

      expect(find.byType(FinancialPlanCard), findsNothing);
      expect(
        find.bySemanticsIdentifier('financial_plan_stale_recalculate'),
        findsNothing,
      );
    });

    testWidgets(
        'FinancialPlanCard masks every stale figure and exposes recovery ids',
        (tester) async {
      final profile = _profile();
      final plan = _planFor(
        profile,
        id: 'home-stale-plan',
        monthlyTarget: 12345,
      ).copyWith(
        milestones: [
          PlanMilestone(
            targetDate: DateTime.utc(2044, 3, 1),
            targetAmount: 777777,
            description: 'Jalon sentinelle 888888',
          ),
        ],
        projectedLow: 400000,
        projectedOutcome: 500000,
        projectedHigh: 600000,
        targetDate: DateTime.utc(2045, 6, 1),
        coachNarrative: 'Narration sentinelle confidentielle.',
      );
      var stale = false;
      late StateSetter rebuildCard;

      await tester.pumpWidget(
        _localizedHarness(
          StatefulBuilder(
            builder: (context, setState) {
              rebuildCard = setState;
              return FinancialPlanCard(
                plan: plan,
                isStale: stale,
                onRecalculate: (_) {},
              );
            },
          ),
        ),
      );
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(_visibleTextContainsDigits(tester, '777777'), isTrue);

      rebuildCard(() => stale = true);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('financial_plan_stale_state'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('financial_plan_stale_recalculate'),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(
              find.bySemanticsIdentifier('financial_plan_stale_recalculate'),
            )
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      for (final forbiddenDigits in [
        '12345',
        '400000',
        '500000',
        '600000',
        '777777',
        '888888',
        '2044',
        '2045',
      ]) {
        expect(
          _visibleTextContainsDigits(tester, forbiddenDigits),
          isFalse,
          reason: 'stale home plan must hide sentinel $forbiddenDigits',
        );
      }
      expect(
        find.textContaining('Narration sentinelle confidentielle'),
        findsNothing,
      );
    });

    testWidgets(
        'Aujourdhui stale recovery opens standard review without writing',
        (tester) async {
      final currentProfile = _projectionReadyProfile();
      await FinancialPlanService.save(
        _planFor(
          _projectionReadyProfile(salary: 7000),
          id: 'cold-home-plan',
          monthlyTarget: 12345,
        ),
      );
      final ledger = _ledger(currentProfile);
      addTearDown(ledger.dispose);
      final plans = _CountingPlanProvider();
      addTearDown(plans.dispose);
      plans.attachProfileProvider(ledger);
      await plans.loadFromPersistence();
      final timeline = _EmptyTimelineProvider();
      addTearDown(timeline.dispose);

      await tester.pumpWidget(
        _aujourdhuiHarness(
          ledger: ledger,
          plans: plans,
          timeline: timeline,
        ),
      );
      await tester.pump();

      expect(plans.currentPlan?.id, 'cold-home-plan');
      expect(plans.isPlanStale, isTrue);
      expect(find.byType(FinancialPlanCard), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('financial_plan_stale_state'),
        findsOneWidget,
      );
      expect(_visibleTextContainsDigits(tester, '12345'), isFalse);

      final recovery = find.bySemanticsIdentifier(
        'financial_plan_stale_recalculate',
      );
      expect(recovery, findsOneWidget);
      expect(
        tester
            .getSemantics(recovery)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );

      await tester.tap(recovery);
      await _pumpFrames(tester, frames: 10);

      expect(plans.setPlanCalls, 0);
      expect(plans.currentPlan?.id, 'cold-home-plan');
      expect(plans.isPlanStale, isTrue);
      expect(
        find.bySemanticsIdentifier('financial_plan_setup'),
        findsOneWidget,
      );
      expect(_visibleTextContainsDigits(tester, '99999'), isFalse);
    });
  });
}
