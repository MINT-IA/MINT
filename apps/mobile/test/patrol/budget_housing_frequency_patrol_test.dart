import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/budget/budget_setup_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(
  GoRouter router, {
  required CoachProfileProvider coachProfileProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(
        value: coachProfileProvider,
      ),
      ChangeNotifierProvider<BudgetProvider>(
        create: (_) => BudgetProvider(),
      ),
    ],
    child: MaterialApp.router(
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
}

void main() {
  final mockSecureStorage = <String, String>{};

  setUp(() {
    mockSecureStorage.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            if (value != null) mockSecureStorage[key] = value;
            return null;
          case 'read':
            final key = call.arguments['key'] as String;
            return mockSecureStorage[key];
          case 'delete':
            final key = call.arguments['key'] as String;
            mockSecureStorage.remove(key);
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
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  patrolTest(
    'budget setup stores housing frequency without changing income frequency',
    ($) async {
      await ReportPersistenceService.saveAnswers(const {
        'q_net_income_period_chf': 120000,
        'q_pay_frequency': 'yearly',
      });

      final provider = CoachProfileProvider();
      final router = GoRouter(
        initialLocation: '/budget/setup',
        routes: [
          GoRoute(
            path: '/budget/setup',
            builder: (_, __) => const BudgetSetupScreen(),
          ),
          GoRoute(
            path: '/budget',
            builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
          ),
        ],
      );
      addTearDown(router.dispose);

      await $.pumpWidgetAndSettle(
        _wrap(
          router,
          coachProfileProvider: provider,
        ),
      );

      expect($(#budget_housing_cost_input), findsOneWidget);
      expect($(#budget_lamal_premium_input), findsOneWidget);
      expect($(#budget_setup_save_cta), findsOneWidget);

      await $(#budget_housing_cost_input).enterText('2000');
      await $(#budget_lamal_premium_input).enterText('400');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $(#budget_setup_save_cta).tap();
      await $.pumpAndSettle();

      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['q_net_income_period_chf'], 120000);
      expect(answers['q_pay_frequency'], 'yearly');
      expect(answers['q_housing_cost_period_chf'], 2000);
      expect(answers['q_housing_cost_frequency'], 'monthly');
      expect(answers['q_lamal_premium_monthly_chf'], 400);
      expect(provider.profile!.depenses.loyer, 2000);
      expect(provider.profile!.depenses.assuranceMaladie, 400);
    },
  );
}
