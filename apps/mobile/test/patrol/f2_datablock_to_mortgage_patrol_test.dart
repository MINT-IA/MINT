import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
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
    'F-2 revenue and property blocks feed mortgage without duplicate facts',
    ($) async {
      final provider = CoachProfileProvider();
      final router = GoRouter(
        initialLocation: '/data-block/revenu',
        routes: [
          GoRoute(
            path: '/data-block/:type',
            builder: (_, state) => DataBlockEnrichmentScreen(
              blockType: state.pathParameters['type'] ?? 'revenu',
              initialInputKey: state.uri.queryParameters['inputKey'],
            ),
          ),
          GoRoute(
            path: '/hypotheque',
            builder: (_, __) => const AffordabilityScreen(),
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
      expect($('Préciser mon revenu'), findsNothing);

      await $(#canton_input).enterText('GE');
      await $(#salary_input).enterText('96000');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester.ensureVisible(find.byKey(const Key('salary_save_cta')));
      await $(#salary_save_cta).tap();
      await $.pumpAndSettle();

      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['q_gross_salary_annual'], 96000);
      expect(answers['q_canton'], 'GE');
      expect(
        answers.keys.where((key) => key.startsWith('q_')).toSet(),
        {'q_gross_salary_annual', 'q_canton'},
      );
      expect(answers.containsKey('q_net_income_period_chf'), isFalse);
      expect(answers.containsKey('q_monthly_gross_salary_chf'), isFalse);
      expect(provider.profile!.revenuBrutAnnuel, 96000);
      expect(provider.profile!.canton, 'GE');
      expect(
        provider.profile!.dataSources['salaireBrutMensuel'],
        ProfileDataSource.userInput,
      );
      expect(
        provider.profile!.dataSources['canton'],
        ProfileDataSource.userInput,
      );

      router.go('/data-block/patrimoine');
      await $.pumpAndSettle();

      expect($(#savings_input), findsOneWidget);
      expect($(#target_property_input), findsOneWidget);
      expect($(#salary_input), findsNothing);
      expect($(#canton_input), findsNothing);

      await $(#savings_input).enterText('250000');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester
          .ensureVisible(find.byKey(const Key('target_property_input')));
      await $(#target_property_input).enterText('950000');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester
          .ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
      await $(#patrimoine_save_cta).tap();
      await $.pumpAndSettle();

      final enrichedAnswers = await ReportPersistenceService.loadAnswers();
      expect(enrichedAnswers['q_cash_total'], 250000);
      expect(enrichedAnswers['q_target_property_value'], 950000);
      expect(enrichedAnswers.containsKey('q_property_market_value'), isFalse);
      expect(
        enrichedAnswers.keys.where((key) => key.startsWith('q_')).toSet(),
        {
          'q_gross_salary_annual',
          'q_canton',
          'q_cash_total',
          'q_target_property_value',
        },
      );
      expect(provider.profile!.patrimoine.epargneLiquide, 250000);
      expect(provider.profile!.patrimoine.targetPropertyValue, 950000);
      expect(provider.profile!.patrimoine.propertyMarketValue, isNull);

      router.go('/hypotheque');
      await $.pumpAndSettle();

      expect($(#mortgage_data_quest_contract), findsOneWidget);
      final dataQuestRuntimeProof = $.tester.getSemantics(
        find.bySemanticsIdentifier('mortgage_data_quest_runtime_proof'),
      );
      expect(dataQuestRuntimeProof.value, 'mobile-f2-patrol');
      expect($(find.bySemanticsIdentifier('mortgage_data_quest_next_ask')),
          findsOneWidget);
      final dataQuestNextAsk = $.tester.getSemantics(
        find.bySemanticsIdentifier('mortgage_data_quest_next_ask'),
      );
      expect(dataQuestNextAsk.value, 'householdType');
      final dataQuestMode = $.tester.getSemantics(
        find.bySemanticsIdentifier('mortgage_data_quest_mode'),
      );
      expect(dataQuestMode.value, 'collect');
      final dataQuestStage = $.tester.getSemantics(
        find.bySemanticsIdentifier('mortgage_data_quest_stage'),
      );
      expect(dataQuestStage.value, 'guard');
      expect($(#mortgage_data_quest_next_question), findsOneWidget);
      expect($(find.text('Composition du ménage')), findsOneWidget);
      expect($(#mortgage_data_quest_next_question_cta), findsOneWidget);

      await $(#mortgage_data_quest_next_question_cta).tap();
      await $.pumpAndSettle();

      expect($(#household_type_cohabiting), findsOneWidget);
      await $(#household_type_cohabiting).tap();
      await $.pumpAndSettle();
      await $.tester.ensureVisible(find.byKey(const Key('household_save_cta')));
      await $(#household_save_cta).tap();
      await $.pumpAndSettle();

      final householdAnswers = await ReportPersistenceService.loadAnswers();
      expect(householdAnswers['q_civil_status'], 'cohabiting');
      expect(
        householdAnswers.keys.where((key) => key.startsWith('q_')).toSet(),
        {
          'q_gross_salary_annual',
          'q_canton',
          'q_cash_total',
          'q_target_property_value',
          'q_civil_status',
        },
      );
      expect(householdAnswers.containsKey('q_household_type'), isFalse);
      expect(provider.profile!.etatCivil, CoachCivilStatus.concubinage);

      router.go('/hypotheque');
      await $.pumpAndSettle();

      final advancedNextAsk = $.tester.getSemantics(
        find.bySemanticsIdentifier('mortgage_data_quest_next_ask'),
      );
      expect(advancedNextAsk.value, 'patrimoine.mortgageRate');
      expect($(#mortgage_data_quest_next_question_cta), findsOneWidget);

      await $(#mortgage_data_quest_next_question_cta).tap();
      await $.pumpAndSettle();

      expect($(#mortgage_rate_input), findsOneWidget);
      await $(#mortgage_rate_input).enterText('1.8');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester
          .ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
      await $(#patrimoine_save_cta).tap();
      await $.pumpAndSettle();

      final mortgageRateAnswers = await ReportPersistenceService.loadAnswers();
      expect(mortgageRateAnswers['q_mortgage_rate'], 0.018);
      expect(
        mortgageRateAnswers.keys.where((key) => key.startsWith('q_')).toSet(),
        {
          'q_gross_salary_annual',
          'q_canton',
          'q_cash_total',
          'q_target_property_value',
          'q_civil_status',
          'q_mortgage_rate',
        },
      );
      expect(mortgageRateAnswers.containsKey('q_mortgage_rate_percent'),
          isFalse);
      expect(provider.profile!.patrimoine.mortgageRate, 0.018);

      router.go('/hypotheque');
      await $.pumpAndSettle();

      final satisfiedNextAsk = $.tester.getSemantics(
        find.bySemanticsIdentifier('mortgage_data_quest_next_ask'),
      );
      expect(satisfiedNextAsk.value, 'satisfied');

      expect($(find.bySemanticsIdentifier('mortgage_afford_result')),
          findsOneWidget);
      final resultSemantics = $.tester.getSemantics(
        find.bySemanticsIdentifier('mortgage_afford_result'),
      );
      expect(resultSemantics.value, contains("96'000"));
      expect(resultSemantics.value, contains('GE'));
      expect(resultSemantics.value, contains("250'000"));
      expect(resultSemantics.value, contains("950'000"));
    },
  );

  patrolTest(
    'F-2 missing canton opens only the canton revenue ask',
    ($) async {
      final provider = CoachProfileProvider();
      await provider.mergeAnswers({
        'q_gross_salary_annual': 96000,
        'q_cash_total': 250000,
        'q_target_property_value': 950000,
        'q_civil_status': 'cohabiting',
      });
      final router = GoRouter(
        initialLocation: '/hypotheque',
        routes: [
          GoRoute(
            path: '/data-block/:type',
            builder: (_, state) => DataBlockEnrichmentScreen(
              blockType: state.pathParameters['type'] ?? 'revenu',
              initialInputKey: state.uri.queryParameters['inputKey'],
            ),
          ),
          GoRoute(
            path: '/hypotheque',
            builder: (_, __) => const AffordabilityScreen(),
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

      final nextAsk = $.tester.getSemantics(
        find.bySemanticsIdentifier('mortgage_data_quest_next_ask'),
      );
      expect(nextAsk.value, 'canton');

      await $(#mortgage_data_quest_next_question_cta).tap();
      await $.pumpAndSettle();

      expect($(#canton_input), findsOneWidget);
      expect($(#salary_input), findsNothing);
      await $(#canton_input).enterText('VD');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester.ensureVisible(find.byKey(const Key('salary_save_cta')));
      await $(#salary_save_cta).tap();
      await $.pumpAndSettle();

      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['q_canton'], 'VD');
      expect(answers.containsKey('canton'), isFalse);
      expect(provider.profile!.canton, 'VD');
    },
  );

  patrolTest(
    'F-2 missing liquid assets opens only the savings ask',
    ($) async {
      final provider = CoachProfileProvider();
      await provider.mergeAnswers({
        'q_gross_salary_annual': 96000,
        'q_canton': 'GE',
        'q_target_property_value': 950000,
        'q_civil_status': 'cohabiting',
      });
      final router = GoRouter(
        initialLocation: '/hypotheque',
        routes: [
          GoRoute(
            path: '/data-block/:type',
            builder: (_, state) => DataBlockEnrichmentScreen(
              blockType: state.pathParameters['type'] ?? 'revenu',
              initialInputKey: state.uri.queryParameters['inputKey'],
            ),
          ),
          GoRoute(
            path: '/hypotheque',
            builder: (_, __) => const AffordabilityScreen(),
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

      final nextAsk = $.tester.getSemantics(
        find.bySemanticsIdentifier('mortgage_data_quest_next_ask'),
      );
      expect(nextAsk.value, 'patrimoine.epargneLiquide');

      await $(#mortgage_data_quest_next_question_cta).tap();
      await $.pumpAndSettle();

      expect($(#savings_input), findsOneWidget);
      expect($(#target_property_input), findsNothing);
      expect($(#salary_input), findsNothing);
      expect($(#canton_input), findsNothing);
      await $(#savings_input).enterText('250000');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester
          .ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
      await $(#patrimoine_save_cta).tap();
      await $.pumpAndSettle();

      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['q_cash_total'], 250000);
      expect(answers['q_target_property_value'], 950000);
      expect(answers.containsKey('patrimoine.epargneLiquide'), isFalse);
      expect(provider.profile!.patrimoine.epargneLiquide, 250000);
      expect(provider.profile!.patrimoine.targetPropertyValue, 950000);
    },
  );

  patrolTest(
    'F-2 missing target property value opens only the target price ask',
    ($) async {
      final provider = CoachProfileProvider();
      await provider.mergeAnswers({
        'q_gross_salary_annual': 96000,
        'q_canton': 'GE',
        'q_cash_total': 250000,
        'q_civil_status': 'cohabiting',
      });
      final router = GoRouter(
        initialLocation: '/hypotheque',
        routes: [
          GoRoute(
            path: '/data-block/:type',
            builder: (_, state) => DataBlockEnrichmentScreen(
              blockType: state.pathParameters['type'] ?? 'revenu',
              initialInputKey: state.uri.queryParameters['inputKey'],
            ),
          ),
          GoRoute(
            path: '/hypotheque',
            builder: (_, __) => const AffordabilityScreen(),
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

      final nextAsk = $.tester.getSemantics(
        find.bySemanticsIdentifier('mortgage_data_quest_next_ask'),
      );
      expect(nextAsk.value, 'targetPropertyValue');

      await $(#mortgage_data_quest_next_question_cta).tap();
      await $.pumpAndSettle();

      expect($(#target_property_input), findsOneWidget);
      expect($(#savings_input), findsNothing);
      expect($(#salary_input), findsNothing);
      expect($(#canton_input), findsNothing);
      await $(#target_property_input).enterText('950000');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      await $.tester
          .ensureVisible(find.byKey(const Key('patrimoine_save_cta')));
      await $(#patrimoine_save_cta).tap();
      await $.pumpAndSettle();

      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['q_target_property_value'], 950000);
      expect(answers['q_cash_total'], 250000);
      expect(answers.containsKey('targetPropertyValue'), isFalse);
      expect(provider.profile!.patrimoine.targetPropertyValue, 950000);
      expect(provider.profile!.patrimoine.epargneLiquide, 250000);
    },
  );
}
