import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/session_termination_coordinator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async => null;

  @override
  Future<void> cancelAll() async {}
}

FinancialPlan _oldPlan() {
  final generatedAt = DateTime.utc(2026, 7, 16);
  return FinancialPlan(
    id: 'old-session-plan',
    goalDescription: 'Old synthetic goal',
    goalCategory: 'goal_other',
    monthlyTarget: 1234,
    milestones: const [],
    projectedOutcome: 98765,
    targetDate: DateTime.utc(2030, 7, 16),
    generatedAt: generatedAt,
    profileHashAtGeneration: 'old-binding',
    coachNarrative: 'Old synthetic narrative',
    confidenceLevel: 80,
    sources: const [],
    disclaimer: 'Synthetic',
  );
}

Future<
    ({
      AuthProvider auth,
      CoachProfileProvider coach,
      FinancialPlanProvider plans,
    })> _seedOldSession(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
  final auth = context.read<AuthProvider>();
  final coach = context.read<CoachProfileProvider>();
  final plans = context.read<FinancialPlanProvider>();
  await coach.loadFromWizard();
  await coach.mergeAnswers({
    'q_birth_year': 1976,
    'q_canton': 'VD',
    'q_gross_salary_annual': 140000.0,
    'q_main_goal': 'old-session-goal',
  });
  await coach.ensureCanonicalProfileOwner();
  final plan = _oldPlan();
  await FinancialPlanService.save(plan);
  plans.setPlanDirect(plan);
  await AuthService.saveToken(
    'old-access-token',
    'old-user-id',
    'old@example.test',
    refreshToken: 'old-refresh-token',
  );
  expect(coach.profile, isNotNull);
  expect(coach.canonicalProfileOwnerId, isNotNull);
  expect(plans.currentPlan?.monthlyTarget, 1234);
  expect(await FinancialPlanService.loadCurrent(), isNotNull);
  return (auth: auth, coach: coach, plans: plans);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
    FeatureFlags.financialPlanSetupEnabled = true;
    ApiService.debugResetHttpClient();
    ApiService.debugResetSessionTerminationHandler();
  });

  tearDown(() {
    FeatureFlags.financialPlanSetupEnabled = false;
    ApiService.debugResetHttpClient();
    ApiService.debugResetSessionTerminationHandler();
  });

  testWidgets(
      'MintApp explicit logout purges durable authority and provider memory before local mode',
      (tester) async {
    await tester.pumpWidget(const MintApp());
    await tester.pump();
    final old = await _seedOldSession(tester);

    await old.auth.logout();

    expect(old.auth.isLoggedIn, isFalse);
    expect(old.auth.isLocalMode, isFalse);
    expect(old.coach.profile, isNull);
    expect(old.coach.canonicalProfileOwnerId, isNull);
    expect(old.plans.currentPlan, isNull);
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);
    expect(await FinancialPlanService.loadCurrent(), isNull);
    expect(await AuthService.getToken(), isNull);

    await old.auth.enableLocalMode();
    expect(old.auth.isLocalMode, isTrue);
    expect(old.coach.profile, isNull);
    expect(old.plans.currentPlan, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const MintApp());
    await tester.pump();
    final nextContext = tester.element(find.byType(MaterialApp));
    final nextAuth = nextContext.read<AuthProvider>();
    final nextCoach = nextContext.read<CoachProfileProvider>();
    final nextPlans = nextContext.read<FinancialPlanProvider>();
    await nextAuth.checkAuth();
    await nextCoach.loadFromWizard();
    await nextPlans.loadFromPersistence();

    expect(nextAuth.isLoggedIn, isFalse);
    expect(nextAuth.isLocalMode, isTrue);
    expect(nextCoach.profile, isNull);
    expect(nextCoach.canonicalProfileOwnerId, isNull);
    expect(nextPlans.currentPlan, isNull);
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);
    expect(await FinancialPlanService.loadCurrent(), isNull);
  });

  testWidgets(
      'MintApp terminal 401 awaits the same purge before exposing unauthenticated state',
      (tester) async {
    await tester.pumpWidget(const MintApp());
    await tester.pump();
    final old = await _seedOldSession(tester);
    ApiService.debugUseHttpClient(
      MockClient((_) async => http.Response('{}', 401)),
    );

    await expectLater(
      ApiService.get('/synthetic-expired'),
      throwsA(isA<ApiException>()),
    );

    expect(old.auth.isLoggedIn, isFalse);
    expect(old.auth.isLocalMode, isFalse);
    expect(old.auth.isSessionTerminationBlocked, isFalse);
    expect(old.coach.profile, isNull);
    expect(old.coach.canonicalProfileOwnerId, isNull);
    expect(old.plans.currentPlan, isNull);
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);
    expect(await FinancialPlanService.loadCurrent(), isNull);
    expect(await AuthService.getToken(), isNull);
  });

  testWidgets(
      'MintApp resumes a cold termination tombstone before auth hydration',
      (tester) async {
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1976,
      'q_canton': 'VD',
      'q_gross_salary_annual': 140000.0,
    });
    await FinancialPlanService.save(_oldPlan());
    await AuthService.saveToken(
      'cold-old-access-token',
      'cold-old-user-id',
      'cold-old@example.test',
      refreshToken: 'cold-old-refresh-token',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      SessionTerminationCoordinator.terminationPendingKey,
      true,
    );

    await tester.pumpWidget(const MintApp());
    await tester.pump();
    final context = tester.element(find.byType(MaterialApp));
    final auth = context.read<AuthProvider>();
    final coach = context.read<CoachProfileProvider>();
    final plans = context.read<FinancialPlanProvider>();

    // MintApp's AccountSessionBootstrap is the sole production checkAuth
    // caller. Keep secure-storage platform work in the widget-test zone and
    // assert that automatic bootstrap result instead of launching a duplicate.
    expect(
      auth.hasCompletedInitialAuthCheck,
      isTrue,
      reason:
          'blocked=${auth.isSessionTerminationBlocked} loading=${auth.isLoading} error=${auth.error}',
    );
    expect(auth.isLoggedIn, isFalse);
    expect(auth.isLocalMode, isFalse);
    expect(auth.isSessionTerminationBlocked, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(coach.profile, isNull);
    expect(plans.currentPlan, isNull);
    expect(await AuthService.getToken(), isNull);
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);
    expect(await FinancialPlanService.loadCurrent(), isNull);
    expect(
      prefs.getBool(SessionTerminationCoordinator.terminationPendingKey),
      isNull,
    );
  });
}
