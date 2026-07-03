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
import 'package:mint_mobile/screens/coach/succession_patrimoine_screen.dart';
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

String? _semanticsValue(WidgetTester tester, String identifier) {
  final semantics = tester.widget<Semantics>(
    find.bySemanticsIdentifier(identifier),
  );
  return semantics.properties.value;
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 30; i++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(scrollable, const Offset(0, -350));
    await tester.pump(const Duration(milliseconds: 80));
  }
  expect(target, findsOneWidget);
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
    'transmit property collects owned property value before modelling',
    ($) async {
      final provider = CoachProfileProvider();
      final router = GoRouter(
        initialLocation: '/succession',
        routes: [
          GoRoute(
            path: '/succession',
            builder: (_, __) => const SuccessionPatrimoineScreen(),
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

      expect($(#succession_parents_note), findsOneWidget);
      expect($(find.bySemanticsIdentifier('succession_data_quest_next_ask')),
          findsOneWidget);
      expect(
        _semanticsValue($.tester, 'succession_data_quest_next_ask'),
        'propertyMarketValue',
      );

      final input = find.byKey(const Key('property_value_input'));
      await $.tester.ensureVisible(input);
      await $.pumpAndSettle();
      await $(input).enterText('1200000');
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.pumpAndSettle();
      for (var i = 0; i < 20; i++) {
        if (provider.profile?.dataSources['patrimoine.propertyMarketValue'] ==
            ProfileDataSource.userInput) {
          break;
        }
        await $.tester.pump(const Duration(milliseconds: 50));
      }

      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['q_property_market_value'], 1200000);
      expect(answers.containsKey('q_target_property_value'), isFalse);
      expect(provider.profile!.patrimoine.propertyMarketValue, 1200000);
      expect(provider.profile!.patrimoine.targetPropertyValue, isNull);
      expect(
        provider.profile!.dataSources['patrimoine.propertyMarketValue'],
        ProfileDataSource.userInput,
      );

      expect(
        _semanticsValue($.tester, 'succession_data_quest_next_ask'),
        'targetRetirementAge',
      );
      expect($(find.textContaining('next_ask:')), findsNothing);
      await $.tester.ensureVisible(
        find.bySemanticsIdentifier('succession_scenario_preview'),
      );
      await $.pumpAndSettle();
      expect($(find.bySemanticsIdentifier('succession_scenario_preview')),
          findsOneWidget);
      expect(
        $(find.bySemanticsIdentifier('succession_scenario_retirement_status')),
        findsOneWidget,
      );
      expect(
        $(find
            .bySemanticsIdentifier('succession_scenario_equalization_status')),
        findsOneWidget,
      );
      expect($(#succession_scenario_confidence), findsOneWidget);
    },
  );

  patrolTest(
    'transmit property reuses collected facts for Raiffeisen values',
    ($) async {
      final provider = CoachProfileProvider();
      await provider.mergeAnswers(
        const {
          'q_canton': 'VD',
          'q_target_retirement_age': 64,
          '_coach_avoir_lpp': 650000,
          'q_3a_total': 180000,
          'q_cash_total': 120000,
          'q_property_market_value': 1200000,
          'q_mortgage_balance': 420000,
          'q_children': 2,
          '_coach_avs_rente_estimee': 4000,
          '_coach_projected_rente_lpp': 28000,
          'q_pay_frequency': 'monthly',
          'q_housing_cost_period_chf': 6600,
          'q_lamal_premium_monthly_chf': 400,
          '_transmit_property_cash_paid_by_recipient': 50000,
          '_transmit_property_mortgage_assumed_by_recipient': 420000,
          '_transmit_property_recipient_relationship': 'descendant',
          '_transmit_property_retained_right': 'habitation',
          '_transmit_property_avancement_hoirie': true,
        },
        source: ProfileDataSource.userInput,
      );
      final router = GoRouter(
        initialLocation: '/succession',
        routes: [
          GoRoute(
            path: '/succession',
            builder: (_, __) => const SuccessionPatrimoineScreen(),
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

      await _scrollUntilVisible(
        $.tester,
        find.byKey(const ValueKey('succession_scenario_retirement_status')),
      );
      expect($(find.textContaining("CHF -8'000")), findsOneWidget);
      await _scrollUntilVisible(
        $.tester,
        find.byKey(const ValueKey('succession_scenario_equalization_status')),
      );
      expect($(find.textContaining("CHF 195'000")), findsOneWidget);
      await _scrollUntilVisible(
        $.tester,
        find.bySemanticsIdentifier('succession_runtime_scenario_statuses'),
      );

      expect(
        $(find.textContaining(
          "scenario_statuses: needs_review | CHF -8'000 | at_risk | CHF 195'000",
        )),
        findsOneWidget,
      );
      expect(
        $(find.textContaining('scenario_confidence: medium')),
        findsOneWidget,
      );
    },
  );
}
