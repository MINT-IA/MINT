import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

Future<void> _pumpFrames(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _routerPath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

MintUserState _stateWithStaleBudgetSnapshot() {
  return MintUserState(
    profile: CoachProfile(
      birthYear: 1977,
      canton: 'ZH',
      salaireBrutMensuel: 10000,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042),
        label: 'Retraite',
      ),
    ),
    lifecyclePhase: LifecyclePhase.construction,
    archetype: FinancialArchetype.swissNative,
    budgetSnapshot: const BudgetSnapshot(
      present: PresentBudget(
        monthlyNet: 7410,
        monthlyHousing: 1600,
        monthlyTax: 900,
        monthlyHealth: 500,
        monthlyCharges: 3000,
        monthlySavings: 0,
        monthlyFree: 4410,
      ),
      capImpacts: [],
      stage: BudgetStage.presentOnly,
      confidenceScore: 64,
    ),
    confidenceScore: 64,
    capMemory: const CapMemory(),
    computedAt: DateTime.utc(2026, 6),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockSecureStorage = <String, String>{};

  setUp(() {
    mockSecureStorage.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _secureStorageChannel,
      (call) async {
        final key = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) {
              mockSecureStorage[key] = value;
            }
            return null;
          case 'read':
            return key == null ? null : mockSecureStorage[key];
          case 'delete':
            if (key != null) mockSecureStorage.remove(key);
            return null;
          case 'deleteAll':
            mockSecureStorage.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets('/rapport loads persisted budget answers without state.extra',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1988,
      'q_canton': 'VD',
      'q_civil_status': 'single',
      'q_children': '0',
      'q_net_income_period_chf': 5000.0,
      'q_pay_frequency': 'monthly',
      'q_housing_cost_period_chf': 2200.0,
      'q_debt_payments_period_chf': 0.0,
      'q_tax_provision_monthly_chf': 458.0,
      'q_lamal_premium_monthly_chf': 420.0,
      'q_other_fixed_costs_monthly_chf': 0.0,
      'q_emergency_fund': 'yes_3months',
      'q_employment_status': 'employee',
    });
    await ReportPersistenceService.setCompleted(true);

    final router = GoRouter(
      initialLocation: '/rapport',
      routes: [
        GoRoute(
          path: '/rapport',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            if (extra.isNotEmpty) {
              return FinancialReportScreenV2(wizardAnswers: extra);
            }
            return FutureBuilder<Map<String, dynamic>>(
              future: ReportPersistenceService.loadAnswers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return FinancialReportScreenV2(
                  wizardAnswers: snapshot.data ?? {},
                );
              },
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pump();
    await _pumpFrames(tester, frames: 20);

    expect(find.textContaining('Ton Bilan Flash'), findsWidgets);
    expect(find.textContaining('Ton Budget'), findsNothing);
    expect(find.textContaining('Charges fixes totales'), findsNothing);
    expect(find.textContaining("5'000"), findsNothing);
    expect(find.textContaining("3'078"), findsNothing);
    expect(find.textContaining("1'922"), findsNothing);
    expect(find.textContaining('Logement'), findsNothing);
    expect(find.textContaining('Primes LAMal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/rapport back falls back to Mon argent for direct entry',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/rapport',
      routes: [
        GoRoute(
          path: '/rapport',
          builder: (context, state) => const FinancialReportScreenV2(
            wizardAnswers: {
              'q_birth_year': 1988,
              'q_canton': 'VD',
              'q_civil_status': 'single',
              'q_children': '0',
              'q_net_income_period_chf': 5000.0,
              'q_pay_frequency': 'monthly',
              'q_employment_status': 'employee',
            },
          ),
        ),
        GoRoute(
          path: '/mon-argent',
          builder: (context, state) => const Scaffold(body: Text('Mon argent')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(_routerPath(router), '/mon-argent');
    expect(find.text('Mon argent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/rapport back pops to previous human route when available',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/mon-argent',
      routes: [
        GoRoute(
          path: '/mon-argent',
          builder: (context, state) => Scaffold(
            body: ElevatedButton(
              onPressed: () => context.push('/rapport'),
              child: const Text('Open report'),
            ),
          ),
        ),
        GoRoute(
          path: '/rapport',
          builder: (context, state) => const FinancialReportScreenV2(
            wizardAnswers: {
              'q_birth_year': 1988,
              'q_canton': 'VD',
              'q_civil_status': 'single',
              'q_children': '0',
              'q_net_income_period_chf': 5000.0,
              'q_pay_frequency': 'monthly',
              'q_employment_status': 'employee',
            },
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
    expect(find.byType(FinancialReportScreenV2), findsOneWidget);
    expect(find.text('Open report'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('Open report'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/rapport accepts budget provider when wizard answers are empty',
      (tester) async {
    final budgetProvider = BudgetProvider();
    await budgetProvider.setInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 7410,
        housingCost: 2200,
        debtPayments: 0,
        taxProvision: 850,
        healthInsurance: 420,
        otherFixedCosts: 0,
      ),
    );
    budgetProvider.updateOverride('future', 588);

    await tester.pumpWidget(
      ChangeNotifierProvider<BudgetProvider>.value(
        value: budgetProvider,
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: FinancialReportScreenV2(wizardAnswers: {}),
        ),
      ),
    );
    await tester.pump();
    await _pumpFrames(tester, frames: 20);

    expect(find.textContaining('Ton Bilan Flash'), findsWidgets);
    expect(find.textContaining('Ton Budget'), findsNothing);
    expect(find.textContaining("3'352"), findsNothing);
    expect(find.textContaining("7'410"), findsNothing);
    expect(find.textContaining("3'470"), findsNothing);
    expect(find.textContaining('Logement'), findsNothing);
    expect(find.textContaining('Primes LAMal'), findsNothing);
    expect(find.textContaining('Configurer mes enveloppes'), findsNothing);
    expect(find.textContaining("Ton bilan financier"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/rapport does not render fresh or stale budget figures',
      (tester) async {
    final budgetProvider = BudgetProvider();
    await budgetProvider.setInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 7410,
        housingCost: 2200,
        debtPayments: 0,
        taxProvision: 850,
        healthInsurance: 420,
        otherFixedCosts: 0,
      ),
    );
    budgetProvider.updateOverride('future', 588);

    final mintStateProvider = MintStateProvider()
      ..injectStateForTest(_stateWithStaleBudgetSnapshot());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<MintStateProvider>.value(
            value: mintStateProvider,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: FinancialReportScreenV2(wizardAnswers: {}),
        ),
      ),
    );
    await tester.pump();
    await _pumpFrames(tester, frames: 20);

    expect(find.textContaining('Ton Bilan Flash'), findsWidgets);
    expect(find.textContaining('Ton Budget'), findsNothing);
    expect(find.textContaining("3'352"), findsNothing);
    expect(find.textContaining("3'470"), findsNothing);
    expect(find.textContaining("4'410"), findsNothing);
    expect(find.textContaining("3'000"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '/rapport keeps explicit wizard budget out of stale fallback view',
      (tester) async {
    final mintStateProvider = MintStateProvider()
      ..injectStateForTest(_stateWithStaleBudgetSnapshot());

    await tester.pumpWidget(
      ChangeNotifierProvider<MintStateProvider>.value(
        value: mintStateProvider,
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: FinancialReportScreenV2(
            wizardAnswers: {
              'q_birth_year': 1988,
              'q_canton': 'ZH',
              'q_civil_status': 'single',
              'q_children': '0',
              'q_net_income_period_chf': 7410.0,
              'q_pay_frequency': 'monthly',
              'q_housing_cost_period_chf': 2200.0,
              'q_tax_provision_monthly_chf': 850.0,
              'q_lamal_premium_monthly_chf': 420.0,
              'q_employment_status': 'employee',
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await _pumpFrames(tester, frames: 20);

    expect(find.textContaining('Ton Bilan Flash'), findsWidgets);
    expect(find.textContaining('Ton Budget'), findsNothing);
    expect(find.textContaining("3'470"), findsNothing);
    expect(find.textContaining("4'410"), findsNothing);
    expect(find.textContaining("3'000"), findsNothing);
    expect(find.textContaining('Logement'), findsNothing);
    expect(find.textContaining('Primes LAMal'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
