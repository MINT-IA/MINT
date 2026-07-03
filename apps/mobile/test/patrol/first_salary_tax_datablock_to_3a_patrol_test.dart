import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
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
      ChangeNotifierProvider<SlmProvider>(
        create: (_) => SlmProvider(),
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
    'first_salary_tax reuses revenue facts for 3a without duplicate answers',
    ($) async {
      final provider = CoachProfileProvider();
      final router = GoRouter(
        initialLocation: '/data-block/revenu',
        routes: [
          GoRoute(
            path: '/data-block/:type',
            builder: (_, state) => DataBlockEnrichmentScreen(
              blockType: state.pathParameters['type'] ?? 'revenu',
            ),
          ),
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

      expect($(#canton_input), findsOneWidget);
      expect($(#salary_input), findsOneWidget);
      expect($(#birth_year_input), findsOneWidget);
      expect($(#has_pension_fund_switch), findsOneWidget);

      await $(#canton_input).enterText('GE');
      await $(#salary_input).enterText('96000');
      await $(#birth_year_input).enterText('2001');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester
          .ensureVisible(find.byKey(const Key('has_pension_fund_switch')));
      await $(#has_pension_fund_switch).tap();
      await $.tester.ensureVisible(find.byKey(const Key('salary_save_cta')));
      await $(#salary_save_cta).tap();
      await $.pumpAndSettle();

      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['q_gross_salary_annual'], 96000);
      expect(answers['q_canton'], 'GE');
      expect(answers['q_birth_year'], 2001);
      expect(answers['q_has_pension_fund'], true);
      expect(
        answers.keys.where((key) => key.startsWith('q_')).toSet(),
        {
          'q_gross_salary_annual',
          'q_canton',
          'q_birth_year',
          'q_has_pension_fund',
        },
      );
      expect(answers.containsKey('q_net_income_period_chf'), isFalse);
      expect(answers.containsKey('q_monthly_gross_salary_chf'), isFalse);
      expect(provider.profile!.revenuBrutAnnuel, 96000);
      expect(provider.profile!.canton, 'GE');
      expect(provider.profile!.birthYear, 2001);

      router.go('/pilier-3a');
      await $.pumpAndSettle();

      expect($(#sim3a_data_quest_contract), findsOneWidget);
      expect($(find.bySemanticsIdentifier('sim3a_data_quest_next_ask')),
          findsOneWidget);
      final dataQuestNextAsk = $.tester.getSemantics(
        find.bySemanticsIdentifier('sim3a_data_quest_next_ask'),
      );
      expect(dataQuestNextAsk.value, 'pillar3aAnnual');
      final dataQuestMode = $.tester.getSemantics(
        find.bySemanticsIdentifier('sim3a_data_quest_mode'),
      );
      expect(dataQuestMode.value, 'collect');
      final dataQuestStage = $.tester.getSemantics(
        find.bySemanticsIdentifier('sim3a_data_quest_stage'),
      );
      expect(dataQuestStage.value, 'useful');

      expect($(#sim3a_profile_basis), findsOneWidget);
      final basisSemantics = $.tester.widget<Semantics>(
        find.byKey(const ValueKey('sim3a_profile_basis')),
      );
      expect(basisSemantics.properties.value, contains("CHF\u00a096'000"));
      expect(basisSemantics.properties.value, contains('canton=GE'));
      expect(
        basisSemantics.properties.value,
        contains('plafond_3a=CHF\u00a07\'258'),
      );
    },
  );
}
