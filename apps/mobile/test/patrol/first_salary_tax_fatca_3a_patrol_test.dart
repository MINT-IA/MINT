import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/screens/simulator_3a_screen.dart';
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
      ChangeNotifierProvider<ProfileProvider>(
        create: (_) => ProfileProvider(),
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
    'first_salary_tax FATCA derives 3a block from nationality without duplicate answers',
    ($) async {
      final provider = CoachProfileProvider();

      expect(await provider.applySaveFact('incomeGrossYearly', 96000), isTrue);
      expect(await provider.applySaveFact('canton', 'GE'), isTrue);
      expect(await provider.applySaveFact('birthYear', 2001), isTrue);
      expect(await provider.applySaveFact('has2ndPillar', true), isTrue);
      expect(await provider.applySaveFact('nationality', 'US'), isTrue);
      expect(provider.profile!.nationality, 'US');
      expect(provider.profile!.canContribute3a, isFalse);

      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['q_gross_salary_annual'], 96000);
      expect(answers['q_canton'], 'GE');
      expect(answers['q_birth_year'], 2001);
      expect(answers['q_has_pension_fund'], true);
      expect(answers['q_nationality'], 'US');
      expect(answers.containsKey('q_is_fatca_resident'), isFalse);
      expect(answers.containsKey('isFatcaResident'), isFalse);
      expect(
        answers.keys.where((key) => key.startsWith('q_')).toSet(),
        {
          'q_gross_salary_annual',
          'q_canton',
          'q_birth_year',
          'q_has_pension_fund',
          'q_nationality',
        },
      );

      final router = GoRouter(
        initialLocation: '/pilier-3a',
        routes: [
          GoRoute(
            path: '/pilier-3a',
            builder: (_, __) => const Simulator3aScreen(),
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

      expect($(#sim3a_profile_basis), findsOneWidget);
      final basisSemantics = $.tester.widget<Semantics>(
        find.byKey(const ValueKey('sim3a_profile_basis')),
      );
      expect(basisSemantics.properties.value, contains("CHF\u00a096'000"));
      expect(basisSemantics.properties.value, contains('canton=GE'));
      expect(
        basisSemantics.properties.value,
        contains('can_contribute_3a=false'),
      );
      expect(
        basisSemantics.properties.value,
        contains('plafond_3a=CHF\u00a00'),
      );
      expect($(#sim3a_non_contributable_state), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );
}
