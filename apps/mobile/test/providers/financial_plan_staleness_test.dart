import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/screens/aujourdhui/aujourdhui_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/plan_preview_card.dart';
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';
import 'package:mint_mobile/widgets/home/financial_plan_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _salaryPath = 'salaireBrutMensuel';
const _cantonPath = 'canton';
const _dateOfBirthPath = 'dateOfBirth';
const _birthYearPath = 'birthYear';
const _lppTotalPath = 'prevoyance.avoirLppTotal';
const _lppMandatoryPath = 'prevoyance.avoirLppObligatoire';
const _lppExtraMandatoryPath = 'prevoyance.avoirLppSurobligatoire';
const _lppReturnPath = 'prevoyance.rendementCaisse';
const _pillar3aPath = 'prevoyance.totalEpargne3a';

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async => null;
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

class _EmptyTimelineProvider extends TimelineProvider {
  @override
  bool get isLoading => false;

  @override
  bool get isEmpty => true;

  @override
  Future<void> refresh() async {}
}

CoachProfile _profile({
  String firstName = 'Synthetic',
  int birthYear = 1985,
  bool useDateOfBirth = true,
  int dateOfBirthDay = 12,
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
    canton: canton,
    salaireBrutMensuel: salary,
    nombreDeMois: months,
    prevoyance: PrevoyanceProfile(
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
    _lppTotalPath,
    _lppMandatoryPath,
    _lppExtraMandatoryPath,
    _lppReturnPath,
    _pillar3aPath,
  ];
  return _profile(
    salary: salary,
    sources: {for (final path in paths) path: ProfileDataSource.userInput},
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
    profileHashAtGeneration: profileHash ?? computeProfileHash(profile),
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
  });

  tearDown(() => FeatureFlags.financialPlanSetupEnabled = false);

  group('versioned canonical financial-plan input fingerprint', () {
    test('uses a versioned SHA-256 wire format and ignores map insertion order',
        () {
      final stamp = DateTime.utc(2026, 7, 1, 10);
      final first = _profile(
        sources: const {
          _salaryPath: ProfileDataSource.userInput,
          _cantonPath: ProfileDataSource.certificate,
        },
        timestamps: {
          _salaryPath: stamp,
          _cantonPath: stamp,
        },
      );
      final second = _profile(
        sources: const {
          _cantonPath: ProfileDataSource.certificate,
          _salaryPath: ProfileDataSource.userInput,
        },
        timestamps: {
          _cantonPath: stamp,
          _salaryPath: stamp,
        },
      );

      final firstHash = computeProfileHash(first);
      expect(
        firstHash,
        matches(RegExp(r'^mint-plan-input:v2:sha256:[0-9a-f]{64}$')),
      );
      expect(computeProfileHash(second), firstHash);
    });

    test('salary and canton are live invalidation controls', () {
      final baseline = computeProfileHash(_profile());
      expect(computeProfileHash(_profile(salary: 8100)), isNot(baseline));
      expect(computeProfileHash(_profile(canton: 'GE')), isNot(baseline));
    });

    test('uses dateOfBirth when present and birthYear only as its fallback',
        () {
      final dated = computeProfileHash(_profile(birthYear: 1980));
      expect(computeProfileHash(_profile(birthYear: 1990)), dated);
      expect(
        computeProfileHash(_profile(birthYear: 1980, dateOfBirthDay: 13)),
        isNot(dated),
      );

      final yearOnly = computeProfileHash(
        _profile(useDateOfBirth: false, birthYear: 1980),
      );
      expect(
        computeProfileHash(
          _profile(useDateOfBirth: false, birthYear: 1990),
        ),
        isNot(yearOnly),
      );
    });

    test('covers every durable retirement calculation input in the v2 hash',
        () {
      final baseline = computeProfileHash(_profile());
      final changed = <String, CoachProfile>{
        'coherent LPP components': _profile(
          lppMandatory: 140000,
          lppExtraMandatory: 100000,
        ),
        'rendementCaisse': _profile(lppReturn: 0.025),
        'rendementCaisseConnu': _profile(lppReturnKnown: false),
      };

      for (final entry in changed.entries) {
        expect(
          computeProfileHash(entry.value),
          isNot(baseline),
          reason: '${entry.key} changes a generated retirement plan',
        );
      }
    });

    test('salary payment months are inspection-only and do not stale a plan',
        () {
      expect(
        computeProfileHash(_profile(months: 13.5)),
        computeProfileHash(_profile(months: 12)),
        reason: 'The LPP projection annualizes monthly salary as ×12; a 13th '
            'salary month must not silently change the result or its hash.',
      );
    });

    test('retains total LPP and 3a as live invalidation controls', () {
      final baseline = computeProfileHash(_profile());
      expect(
        computeProfileHash(
          _profile(lppTotal: 250000, lppExtraMandatory: 100000),
        ),
        isNot(baseline),
      );
      expect(computeProfileHash(_profile(pillar3a: 43000)), isNot(baseline));
    });

    test('source, update time, and source date each change the fingerprint',
        () {
      const paths = {
        _salaryPath: true,
        _cantonPath: true,
        _dateOfBirthPath: true,
        _birthYearPath: false,
        _lppTotalPath: true,
        _lppMandatoryPath: true,
        _lppExtraMandatoryPath: true,
        _lppReturnPath: true,
        _pillar3aPath: true,
      };
      for (final entry in paths.entries) {
        final path = entry.key;
        final baseline = computeProfileHash(
          _profile(
            useDateOfBirth: entry.value,
            sources: {path: ProfileDataSource.userInput},
            timestamps: {path: DateTime.utc(2026, 7, 1)},
            sourceDates: {path: DateTime.utc(2026, 6, 30)},
          ),
        );
        final changed = [
          _profile(
            useDateOfBirth: entry.value,
            sources: {path: ProfileDataSource.certificate},
            timestamps: {path: DateTime.utc(2026, 7, 1)},
            sourceDates: {path: DateTime.utc(2026, 6, 30)},
          ),
          _profile(
            useDateOfBirth: entry.value,
            sources: {path: ProfileDataSource.userInput},
            timestamps: {path: DateTime.utc(2026, 7, 2)},
            sourceDates: {path: DateTime.utc(2026, 6, 30)},
          ),
          _profile(
            useDateOfBirth: entry.value,
            sources: {path: ProfileDataSource.userInput},
            timestamps: {path: DateTime.utc(2026, 7, 1)},
            sourceDates: {path: DateTime.utc(2026, 7, 1)},
          ),
        ];

        for (final profile in changed) {
          expect(
            computeProfileHash(profile),
            isNot(baseline),
            reason: '$path provenance and freshness are plan inputs',
          );
        }
      }
    });

    test('keeps unknown LPP distinct from an explicit zero', () {
      expect(
        computeProfileHash(
          _profile(
            lppTotal: null,
            lppMandatory: null,
            lppExtraMandatory: null,
          ),
        ),
        isNot(
          computeProfileHash(
            _profile(
              lppTotal: 0,
              lppMandatory: 0,
              lppExtraMandatory: 0,
            ),
          ),
        ),
      );
    });

    test('display-only profile changes do not invalidate the fingerprint', () {
      expect(
        computeProfileHash(_profile(firstName: 'Synthetic A')),
        computeProfileHash(_profile(firstName: 'Synthetic B')),
      );
      expect(
        computeProfileHash(_profile(goalLabel: 'Objectif A')),
        computeProfileHash(
          _profile(
            goalLabel: 'Objectif B',
            goalTargetDate: DateTime.utc(2050, 1, 1),
          ),
        ),
      );
      expect(
        computeProfileHash(_profile(updatedAt: DateTime.utc(2026, 7, 1))),
        computeProfileHash(_profile(updatedAt: DateTime.utc(2026, 7, 2))),
      );
    });

    test('normalizes negative zero and rejects non-finite financial inputs',
        () {
      expect(
        computeProfileHash(_profile(lppReturn: -0.0)),
        computeProfileHash(_profile(lppReturn: 0.0)),
      );
      expect(
        () => computeProfileHash(_profile(salary: double.nan)),
        throwsArgumentError,
      );
      expect(
        () => computeProfileHash(_profile(lppReturn: double.infinity)),
        throwsArgumentError,
      );
    });
  });

  group('FinancialPlanProvider production lifecycle', () {
    testWidgets('app resume re-evaluates a time-dependent ledger fingerprint',
        (tester) async {
      var now = DateTime.utc(2026, 4, 11, 12);
      final profile = _profile(dateOfBirthDay: 12);
      final ledger = _ledger(profile);
      final plan = _planFor(
        profile,
        profileHash: computeProfileHash(profile, now: now),
      );
      final plans = FinancialPlanProvider(clock: () => now)
        ..setPlanDirect(plan)
        ..attachProfileProvider(ledger);
      addTearDown(ledger.dispose);
      addTearDown(plans.dispose);

      expect(plans.isPlanStale, isFalse);

      now = DateTime.utc(2026, 4, 12, 12);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(
        plans.isPlanStale,
        isTrue,
        reason: 'Age/freshness can cross a hash boundary without a profile '
            'write, so resume must consume the injected clock and reconcile.',
      );
    });

    for (final legacyHash in ['', '154932', 'unknown:v9']) {
      testWidgets(
          'attachment immediately marks "$legacyHash" plan hashes stale',
          (tester) async {
        final profile = _profile();
        final ledger = _ledger(profile);
        addTearDown(ledger.dispose);
        final plans = FinancialPlanProvider()
          ..setPlanDirect(_planFor(profile, profileHash: legacyHash));
        addTearDown(plans.dispose);

        plans.attachProfileProvider(ledger);
        await tester.pump();

        expect(plans.isPlanStale, isTrue);
      });
    }

    testWidgets('rebind detaches the previous ledger listener', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      final first = _ledger(_profile()) as _TestLedger;
      final second = _ledger(_profile()) as _TestLedger;
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final plans = FinancialPlanProvider();
      addTearDown(plans.dispose);
      plans.attachProfileProvider(first);
      plans.attachProfileProvider(second);
      plans.setPlanDirect(_planFor(second.profile!));

      expect(first.removeListenerCalls, 1);
      expect(second.addListenerCalls, 1);

      first.updateProfile(_profile(salary: 9900));
      await tester.pumpWidget(const SizedBox(width: 1));
      expect(plans.isPlanStale, isFalse);

      second.updateProfile(_profile(salary: 8100));
      await tester.pumpWidget(const SizedBox(width: 2));
      await tester.pump(const Duration(milliseconds: 1));
      expect(plans.isPlanStale, isTrue);
    });

    test('repeated binding is idempotent', () {
      final ledger = _ledger(_profile()) as _TestLedger;
      addTearDown(ledger.dispose);
      final plans = FinancialPlanProvider();
      addTearDown(plans.dispose);
      plans.attachProfileProvider(ledger);
      plans.attachProfileProvider(ledger);

      expect(ledger.addListenerCalls, 1);
    });

    test('disposal detaches the bound ledger listener', () {
      final ledger = _ledger(_profile()) as _TestLedger;
      addTearDown(ledger.dispose);
      final plans = FinancialPlanProvider();
      plans.attachProfileProvider(ledger);

      plans.dispose();
      expect(ledger.removeListenerCalls, 1);
    });

    testWidgets('dispose cancels an already-scheduled stale notification',
        (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      final initial = _profile();
      final ledger = _ledger(initial);
      addTearDown(ledger.dispose);
      final plans = FinancialPlanProvider();
      plans.attachProfileProvider(ledger);
      plans.setPlanDirect(_planFor(initial));

      ledger.updateProfile(_profile(salary: 8100));
      plans.dispose();
      await tester.pumpWidget(const SizedBox(width: 1));

      expect(tester.takeException(), isNull);
    });

    testWidgets('cold persistence is reconciled against the bound profile',
        (tester) async {
      final current = _profile();
      await FinancialPlanService.save(
        _planFor(_profile(salary: 7000), id: 'cold-plan'),
      );
      final ledger = _ledger(current);
      addTearDown(ledger.dispose);
      final plans = FinancialPlanProvider();
      addTearDown(plans.dispose);
      plans.attachProfileProvider(ledger);

      await plans.loadFromPersistence();
      await tester.pump();

      expect(plans.hasPlan, isTrue);
      expect(plans.isPlanStale, isTrue);
    });

    for (final retainsCachedProfile in [false, true]) {
      testWidgets(
          'persisted plan is unknown while ledger is unloaded '
          '(cached profile: $retainsCachedProfile)', (tester) async {
        final profile = _profile();
        final ledger = _ledger(
          retainsCachedProfile ? profile : null,
          isLoaded: false,
        );
        addTearDown(ledger.dispose);
        final plans = FinancialPlanProvider()
          ..setPlanDirect(_planFor(profile, id: 'unloaded-ledger-plan'));
        addTearDown(plans.dispose);

        plans.attachProfileProvider(ledger);
        await tester.pump();

        expect(plans.hasPlan, isTrue);
        expect(
          plans.isPlanStale,
          isTrue,
          reason: 'unhydrated ledger authority must fail closed',
        );
      });
    }

    testWidgets('clearing or switching ledger authority invalidates the plan',
        (tester) async {
      final profile = _profile();
      final ledger = _ledger(profile) as _TestLedger;
      addTearDown(ledger.dispose);
      final plans = FinancialPlanProvider()
        ..setPlanDirect(_planFor(profile, id: 'switch-plan'));
      addTearDown(plans.dispose);
      plans.attachProfileProvider(ledger);
      await tester.pump();
      expect(plans.isPlanStale, isFalse);

      ledger.beginLedgerSwitch(retainedProfile: profile);
      await tester.pump();
      expect(plans.isPlanStale, isTrue);

      ledger.completeLedgerSwitch(null);
      await tester.pump();
      expect(plans.isPlanStale, isTrue);
    });

    testWidgets('persistence hydration is idempotent', (tester) async {
      final profile = _profile();
      await FinancialPlanService.save(_planFor(profile));
      final plans = FinancialPlanProvider();
      addTearDown(plans.dispose);
      var notifications = 0;
      plans.addListener(() => notifications++);

      await plans.loadFromPersistence();
      await plans.loadFromPersistence();
      await tester.pump();

      expect(notifications, 1);
    });

    testWidgets('one input mutation emits one stale notification',
        (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      final initial = _profile();
      final ledger = _ledger(initial);
      addTearDown(ledger.dispose);
      final plans = FinancialPlanProvider();
      addTearDown(plans.dispose);
      plans.attachProfileProvider(ledger);
      plans.setPlanDirect(_planFor(initial));
      var notifications = 0;
      plans.addListener(() => notifications++);

      ledger.updateProfile(_profile(salary: 8100));
      await tester.pumpWidget(const SizedBox(width: 1));
      await tester.pump(const Duration(milliseconds: 1));

      expect(plans.isPlanStale, isTrue);
      expect(notifications, 1);
    });

    test('plan lifecycle is read-only over profile facts and provenance', () {
      final profile = _profile(
        sources: const {_salaryPath: ProfileDataSource.certificate},
        timestamps: {_salaryPath: DateTime.utc(2026, 7, 1)},
        sourceDates: {_salaryPath: DateTime.utc(2026, 6, 30)},
      );
      final ledger = _ledger(profile);
      addTearDown(ledger.dispose);
      final plans = FinancialPlanProvider();
      addTearDown(plans.dispose);
      final before = jsonEncode(ledger.profile!.toJson());

      plans.attachProfileProvider(ledger);
      plans.setPlanDirect(_planFor(profile));
      plans.checkStalenessForTest(profile);

      expect(jsonEncode(ledger.profile!.toJson()), before);
      final source =
          File('lib/providers/financial_plan_provider.dart').readAsStringSync();
      expect(source, isNot(contains('.updateProfile(')));
      expect(source, isNot(contains('.mergeAnswers(')));
      expect(source, isNot(contains('.applySaveFact(')));
    });

    test('production registration is an eager ledger proxy', () {
      final source = File('lib/app.dart').readAsStringSync();
      expect(
        source,
        matches(
          RegExp(
            r'ChangeNotifierProxyProvider<\s*CoachProfileProvider,\s*FinancialPlanProvider\s*>',
          ),
        ),
      );
      expect(
          source, contains('provider.attachProfileProvider(profileProvider)'));
      expect(source, contains('provider.loadFromPersistence().ignore()'));
      expect(source, contains('lazy: false'));
    });

    testWidgets('the real MintApp provider tree invalidates after one mutation',
        (tester) async {
      final profile = _profile();
      await FinancialPlanService.save(
        _planFor(profile, id: 'cold-production-plan'),
      );
      final previousNotificationsPlatform =
          FlutterLocalNotificationsPlatform.instance;
      FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
      addTearDown(() {
        FlutterLocalNotificationsPlatform.instance =
            previousNotificationsPlatform;
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(const MintApp());
      await _pumpFrames(tester);

      final appContext = tester.element(find.byType(MaterialApp));
      final ledger = appContext.read<CoachProfileProvider>();
      final plans = appContext.read<FinancialPlanProvider>();
      expect(plans.currentPlan?.id, 'cold-production-plan');

      ledger.updateProfile(profile);
      await _pumpFrames(tester);
      expect(plans.isPlanStale, isFalse);

      ledger.updateProfile(_profile(salary: 8100));
      await _pumpFrames(tester);

      expect(plans.isPlanStale, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpFrames(tester);
      debugDefaultTargetPlatformOverride = null;
    });
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

    testWidgets('stale recovery regenerates and replaces the cached plan',
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
      await _pumpFrames(tester, frames: 40);

      expect(plans.isPlanStale, isFalse);
      expect(plans.currentPlan?.id, isNot('stale-plan'));
      expect(
        plans.currentPlan?.profileHashAtGeneration,
        computeProfileHash(currentProfile),
      );
      expect(plans.currentPlan?.generatedAt, isNotNull);
      expect(
        plans.currentPlan!.generatedAt.isAfter(DateTime.utc(2026, 7, 1)),
        isTrue,
      );
      expect(plans.currentPlan?.monthlyTarget, isNot(12345));
      expect(plans.currentPlan?.monthlyTarget, isNot(99999));
      expect(plans.currentPlan?.goalCategory, 'goal_retirement_plan');
      expect(plans.currentPlan?.targetDate, DateTime.utc(2045, 6, 1));
      expect(plans.currentPlan?.milestones.last.targetAmount, 500000);
      expect(find.byType(PlanPreviewCard), findsOneWidget);
    });
  });

  group('first-class cold financial plan surface', () {
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

    testWidgets('Aujourdhui renders a persisted stale plan after cold load',
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
      final plans = FinancialPlanProvider();
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
      await _pumpFrames(tester, frames: 40);

      expect(plans.currentPlan?.id, isNot('cold-home-plan'));
      expect(
        plans.currentPlan?.profileHashAtGeneration,
        computeProfileHash(currentProfile),
      );
      expect(plans.isPlanStale, isFalse);
      expect(plans.currentPlan?.monthlyTarget, isNot(12345));
      expect(plans.currentPlan?.monthlyTarget, isNot(99999));
      expect(plans.currentPlan?.goalDescription, 'Objectif synthétique');
      expect(plans.currentPlan?.goalCategory, 'goal_retirement_plan');
      expect(plans.currentPlan?.targetDate, DateTime.utc(2045, 6, 1));
      expect(plans.currentPlan?.milestones.last.targetAmount, 500000);
      expect(_visibleTextContainsDigits(tester, '12345'), isFalse);
      expect(_visibleTextContainsDigits(tester, '99999'), isFalse);
    });
  });
}
