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
}
