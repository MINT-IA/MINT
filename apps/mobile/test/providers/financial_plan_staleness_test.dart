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
import 'package:mint_mobile/services/financial_plan_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/plan_preview_card.dart';
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';
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
const _monthsPath = 'nombreDeMois';

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
  _TestLedger(this._testProfile);

  CoachProfile _testProfile;
  int addListenerCalls = 0;
  int removeListenerCalls = 0;

  @override
  CoachProfile? get profile => _testProfile;

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
    notifyListeners();
  }
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
  );
}

CoachProfileProvider _ledger(CoachProfile profile) {
  return _TestLedger(profile);
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

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
        matches(RegExp(r'^mint-plan-input:v1:sha256:[0-9a-f]{64}$')),
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

    test('covers every retirement calculation input omitted by the legacy hash',
        () {
      final baseline = computeProfileHash(_profile());
      final changed = <String, CoachProfile>{
        'nombreDeMois': _profile(months: 13.5),
        'avoirLppObligatoire': _profile(lppMandatory: 140000),
        'avoirLppSurobligatoire': _profile(lppExtraMandatory: 100000),
        'rendementCaisse': _profile(lppReturn: 0.025),
      };

      for (final entry in changed.entries) {
        expect(
          computeProfileHash(entry.value),
          isNot(baseline),
          reason: '${entry.key} changes a generated retirement plan',
        );
      }
    });

    test('retains total LPP and 3a as live invalidation controls', () {
      final baseline = computeProfileHash(_profile());
      expect(computeProfileHash(_profile(lppTotal: 250000)), isNot(baseline));
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
        _monthsPath: true,
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
        contains(
          'ChangeNotifierProxyProvider<CoachProfileProvider, FinancialPlanProvider>',
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
    testWidgets('stale cached figures are suppressed from WidgetRenderer',
        (tester) async {
      final currentProfile = _profile();
      final staleProfile = _profile(salary: 7000);
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
      final currentProfile = _profile();
      final staleProfile = _profile(salary: 7000);
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
        plans.currentPlan!.generatedAt,
        greaterThan(DateTime.utc(2026, 7, 1)),
      );
      expect(plans.currentPlan?.monthlyTarget, isNot(12345));
      expect(plans.currentPlan?.monthlyTarget, isNot(99999));
      expect(plans.currentPlan?.goalCategory, 'goal_retirement_plan');
      expect(plans.currentPlan?.targetDate, DateTime.utc(2045, 6, 1));
      expect(plans.currentPlan?.milestones.last.targetAmount, 500000);
      expect(find.byType(PlanPreviewCard), findsOneWidget);
    });
  });
}
