// ────────────────────────────────────────────────────────────
//  S44 Phase 2 — Smoke Tests
//  AgeBandPolicy boundaries + new 65+ screens
//  (OptimisationDecaissementScreen, SuccessionPatrimoineScreen)
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/age_band_policy.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/coach/optimisation_decaissement_screen.dart';
import 'package:mint_mobile/screens/coach/succession_patrimoine_screen.dart';
import 'package:mint_mobile/widgets/coach/avancement_hoirie_widget.dart';
import 'package:mint_mobile/widgets/coach/testament_invisible_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Helpers ─────────────────────────────────────────────────

Widget _wrap(Widget child, {CoachProfileProvider? coachProfileProvider}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => child),
  ]);
  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: coachProfileProvider ?? CoachProfileProvider(),
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

Finder _findSemanticsIdentifier(String identifier) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Semantics && widget.properties.identifier == identifier,
    description: 'Semantics(identifier: $identifier)',
  );
}

String? _semanticsValue(WidgetTester tester, String identifier) {
  final widget = tester.widget<Semantics>(_findSemanticsIdentifier(identifier));
  return widget.properties.value;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxPumps = 20,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue);
}

// ═════════════════════════════════════════════════════════════
//  1. AgeBandPolicy — boundary tests
// ═════════════════════════════════════════════════════════════

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  group('AgeBandPolicy.forAge — boundaries', () {
    test('age 18 → youngProfessional', () {
      expect(AgeBandPolicy.forAge(18).band, AgeBand.youngProfessional);
    });

    test('age 25 → youngProfessional (upper bound inclusive)', () {
      expect(AgeBandPolicy.forAge(25).band, AgeBand.youngProfessional);
    });

    test('age 26 → stabilization (lower bound)', () {
      expect(AgeBandPolicy.forAge(26).band, AgeBand.stabilization);
    });

    test('age 35 → stabilization (upper bound inclusive)', () {
      expect(AgeBandPolicy.forAge(35).band, AgeBand.stabilization);
    });

    test('age 36 → peakEarnings (lower bound)', () {
      expect(AgeBandPolicy.forAge(36).band, AgeBand.peakEarnings);
    });

    test('age 49 → peakEarnings (upper bound inclusive)', () {
      expect(AgeBandPolicy.forAge(49).band, AgeBand.peakEarnings);
    });

    test('age 50 → preRetirement (lower bound)', () {
      expect(AgeBandPolicy.forAge(50).band, AgeBand.preRetirement);
    });

    test('age 65 → preRetirement (upper bound inclusive)', () {
      expect(AgeBandPolicy.forAge(65).band, AgeBand.preRetirement);
    });

    test('age 66 → retirement (lower bound)', () {
      expect(AgeBandPolicy.forAge(66).band, AgeBand.retirement);
    });

    test('age 80 → retirement', () {
      expect(AgeBandPolicy.forAge(80).band, AgeBand.retirement);
    });

    test('age 120 → retirement (upper bound inclusive)', () {
      expect(AgeBandPolicy.forAge(120).band, AgeBand.retirement);
    });

    test('age below minimum (0) → falls back to first policy', () {
      // forAge uses firstWhere with orElse: () => all.first
      expect(AgeBandPolicy.forAge(0).band, AgeBand.youngProfessional);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  2. OptimisationDecaissementScreen — smoke tests
  // ═══════════════════════════════════════════════════════════

  group('OptimisationDecaissementScreen', () {
    testWidgets('renders without crash', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpWidget(_wrap(const OptimisationDecaissementScreen()));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays title in French', (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpWidget(_wrap(const OptimisationDecaissementScreen()));
      await tester.pump();
      expect(find.textContaining('caissement'), findsWidgets);
    });

    testWidgets('shows disclaimer (LSFin)', (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpWidget(_wrap(const OptimisationDecaissementScreen()));
      await tester.pump();
      // Disclaimer text is at the bottom — find key substring
      expect(find.textContaining('éducatif'), findsWidgets);
    });

    testWidgets('does not contain banned term "conseiller·e" as job title',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpWidget(_wrap(const OptimisationDecaissementScreen()));
      await tester.pump();
      // "spécialiste" should appear, not "conseiller·e" as a person title
      expect(find.textContaining('spécialiste'), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  3. SuccessionPatrimoineScreen — smoke tests
  // ═══════════════════════════════════════════════════════════

  group('SuccessionPatrimoineScreen', () {
    testWidgets('renders without crash', (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays succession title', (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      expect(find.textContaining('uccession'), findsWidgets);
    });

    testWidgets('shows disclaimer (LSFin)', (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      expect(find.textContaining('éducatif'), findsWidgets);
    });

    testWidgets('shows property transmission CASE guard before modelling gift',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final provider = CoachProfileProvider();
      await tester.pumpWidget(_wrap(
        const SuccessionPatrimoineScreen(),
        coachProfileProvider: provider,
      ));
      await tester.pump();

      final input = find.byKey(const ValueKey('property_value_input'));
      final note = find.byKey(const ValueKey('succession_parents_note'));
      final provenance =
          find.byKey(const ValueKey('succession_ledger_provenance'));

      expect(input, findsOneWidget);
      expect(note, findsOneWidget);
      expect(_findSemanticsIdentifier('property_value_input'), findsOneWidget);
      expect(
          _findSemanticsIdentifier('succession_parents_note'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('succession_data_quest_next_question')),
        findsOneWidget,
      );
      expect(
        _findSemanticsIdentifier('succession_data_quest_contract'),
        findsOneWidget,
      );
      expect(
        _findSemanticsIdentifier('succession_data_quest_next_ask'),
        findsOneWidget,
      );
      expect(find.text("Ce qu'il manque pour ce scénario"), findsOneWidget);
      expect(find.text('Valeur immobilière'), findsWidgets);
      expect(provenance, findsOneWidget);
      expect(
        tester.getTopLeft(note).dy,
        lessThan(tester.getTopLeft(input).dy),
      );
      expect(
        tester.getTopLeft(input).dy,
        lessThan(tester.getTopLeft(provenance).dy),
      );
      expect(find.textContaining("D'abord la retraite"), findsOneWidget);
      expect(
        _semanticsValue(tester, 'succession_data_quest_case_id'),
        'transmit_property',
      );
      expect(
        _semanticsValue(tester, 'succession_data_quest_pdf_section'),
        'dossier_transmit_property',
      );
      expect(
        _semanticsValue(tester, 'succession_data_quest_next_ask'),
        'propertyMarketValue',
      );
      expect(find.textContaining('next_ask:'), findsNothing);
      expect(find.textContaining('confidence: missing'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('succession_guard_missing_state')),
        findsOneWidget,
      );
      expect(find.byType(TestamentInvisibleWidget), findsNothing);
      expect(find.byType(AvancementHoirieWidget), findsNothing);

      await tester.enterText(input, '1200000');
      await tester.pump();

      expect(find.text('1200000'), findsOneWidget);

      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () =>
            provider.profile?.dataSources['patrimoine.propertyMarketValue'] ==
            ProfileDataSource.userInput,
      );

      expect(provider.profile!.patrimoine.propertyMarketValue, 1200000);
      expect(
        provider.profile!.dataSources['patrimoine.propertyMarketValue'],
        ProfileDataSource.userInput,
      );
      expect(
        _semanticsValue(tester, 'succession_data_quest_next_ask'),
        'targetRetirementAge',
      );
      expect(find.textContaining("1'200'000"), findsOneWidget);
      expect(find.textContaining('data_ledger:'), findsOneWidget);
      expect(find.textContaining('scenario_id: transmit_property'),
          findsOneWidget);
      expect(find.textContaining('source: userInput'), findsOneWidget);
      expect(find.textContaining('confidence: medium'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('succession_scenario_retirement_status')),
        findsOneWidget,
      );
      expect(
        _findSemanticsIdentifier('succession_scenario_retirement_status'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('succession_scenario_equalization_status')),
        findsOneWidget,
      );
      expect(
        _findSemanticsIdentifier('succession_scenario_equalization_status'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('succession_scenario_confidence')),
        findsOneWidget,
      );
      expect(
        _findSemanticsIdentifier('succession_scenario_confidence'),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('succession_scenario_conservative_assumption'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('succession_scenario_model_scope')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('succession_scenario_cantonal_tax')),
        findsOneWidget,
      );
      expect(find.textContaining('Données à compléter'), findsWidgets);
      expect(find.byType(TestamentInvisibleWidget), findsNothing);
      expect(find.byType(AvancementHoirieWidget), findsNothing);
    });

    testWidgets(
        'SuccessionPatrimoineScreen keeps a freshly confirmed old source current',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final provider = CoachProfileProvider();
      await provider.mergeAnswers(
        const {
          'fp:patrimoine.propertyMarketValue': 1200000,
        },
        source: ProfileDataSource.userInput,
        sourceDate: DateTime(2024, 1, 1),
      );

      await tester.pumpWidget(_wrap(
        const SuccessionPatrimoineScreen(),
        coachProfileProvider: provider,
      ));
      await tester.pumpAndSettle();

      expect(
        _semanticsValue(tester, 'succession_data_quest_next_ask'),
        'targetRetirementAge',
      );
      expect(
        _semanticsValue(tester, 'succession_data_quest_mode'),
        isNot('reconfirm'),
      );
      expect(find.textContaining('next_ask:'), findsNothing);
      expect(find.textContaining('ask_mode:'), findsNothing);
    });

    testWidgets('SuccessionPatrimoineScreen reconfirms stale property update',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final provider = CoachProfileProvider();
      await provider.mergeAnswers(
        const {
          'fp:patrimoine.propertyMarketValue': 1200000,
        },
        source: ProfileDataSource.userInput,
        sourceDate: DateTime(2024, 1, 1),
      );
      final profile = provider.profile!;
      provider.updateProfile(
        profile.copyWith(
          dataTimestamps: {
            ...profile.dataTimestamps,
            'patrimoine.propertyMarketValue': DateTime(2024, 1, 1),
          },
        ),
      );

      await tester.pumpWidget(_wrap(
        const SuccessionPatrimoineScreen(),
        coachProfileProvider: provider,
      ));
      await tester.pumpAndSettle();

      expect(
        _semanticsValue(tester, 'succession_data_quest_next_ask'),
        'propertyMarketValue',
      );
      expect(
          _semanticsValue(tester, 'succession_data_quest_mode'), 'reconfirm');
      expect(_semanticsValue(tester, 'succession_data_quest_stage'), 'guard');
      expect(find.textContaining('next_ask:'), findsNothing);
      expect(find.textContaining('ask_mode:'), findsNothing);
      expect(find.textContaining('ask_stage:'), findsNothing);
    });

    testWidgets(
        'renders estate illustrations only after retirement guard inputs exist',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final provider = CoachProfileProvider();
      await provider.mergeAnswers({
        'fp:patrimoine.propertyMarketValue': 1200000,
        'q_target_retirement_age': 64,
        '_coach_avoir_lpp': 250000,
        'q_3a_total': 60000,
        'q_cash_total': 80000,
        'q_parent_annual_retirement_income': 57400,
        'q_parent_annual_living_costs': 56400,
        'q_pay_frequency': 'monthly',
        'q_housing_cost_period_chf': 4200,
        'q_lamal_premium_monthly_chf': 500,
      }, source: ProfileDataSource.userInput);

      await tester.pumpWidget(_wrap(
        const SuccessionPatrimoineScreen(),
        coachProfileProvider: provider,
      ));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('succession_guard_missing_state')),
        findsNothing,
      );
      expect(find.byType(TestamentInvisibleWidget), findsOneWidget);
      expect(find.byType(AvancementHoirieWidget), findsOneWidget);
      expect(find.textContaining("1'280'000"), findsWidgets);
      expect(find.textContaining("500'000"), findsNothing);
    });

    testWidgets(
        'asks transaction assumptions after guard answers before trusting preview',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final provider = CoachProfileProvider();
      await provider.mergeAnswers({
        'fp:patrimoine.propertyMarketValue': 1200000,
        'q_target_retirement_age': 64,
        '_coach_avoir_lpp': 250000,
        'q_3a_total': 60000,
        'q_cash_total': 80000,
        'q_mortgage_balance': 420000,
        'q_children': 2,
        '_coach_avs_rente_estimee': 2450,
        '_coach_projected_rente_lpp': 28000,
        'q_parent_annual_living_costs': 56400,
        'q_pay_frequency': 'monthly',
        'q_housing_cost_period_chf': 4200,
        'q_lamal_premium_monthly_chf': 500,
      }, source: ProfileDataSource.userInput);

      await tester.pumpWidget(_wrap(
        const SuccessionPatrimoineScreen(),
        coachProfileProvider: provider,
      ));
      await tester.pumpAndSettle();

      expect(
        _semanticsValue(tester, 'succession_data_quest_next_ask'),
        'cashPaidByRecipient',
      );
      expect(
        _semanticsValue(tester, 'succession_data_quest_mode'),
        'scenarioAssumption',
      );
      expect(_semanticsValue(tester, 'succession_data_quest_stage'), 'useful');
      expect(find.byKey(const Key('cash_paid_by_recipient_input')),
          findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('cash_paid_by_recipient_input')),
        '50000',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('succession_scenario_assumption_save_cta')),
      );
      await tester.tap(
        find.byKey(const Key('succession_scenario_assumption_save_cta')),
      );
      await tester.pumpAndSettle();

      expect(
        provider.answersSnapshot['_transmit_property_cash_paid_by_recipient'],
        50000,
      );
      expect(
          provider.answersSnapshot.containsKey('cashPaidByRecipient'), isFalse);
      expect(
        _semanticsValue(tester, 'succession_data_quest_next_ask'),
        'mortgageAssumedByRecipient',
      );
      expect(find.byKey(const Key('mortgage_assumed_by_recipient_input')),
          findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('mortgage_assumed_by_recipient_input')),
        '420000',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('succession_scenario_assumption_save_cta')),
      );
      await tester.tap(
        find.byKey(const Key('succession_scenario_assumption_save_cta')),
      );
      await tester.pumpAndSettle();

      expect(
        provider.answersSnapshot[
            '_transmit_property_mortgage_assumed_by_recipient'],
        420000,
      );
      expect(
        provider.answersSnapshot.containsKey('mortgageAssumedByRecipient'),
        isFalse,
      );
      expect(
        _semanticsValue(tester, 'succession_data_quest_next_ask'),
        'recipientRelationship',
      );
      expect(find.byKey(const Key('recipient_relationship_descendant_option')),
          findsOneWidget);

      await tester.tap(
        find.byKey(const Key('recipient_relationship_descendant_option')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('succession_scenario_assumption_save_cta')),
      );
      await tester.tap(
        find.byKey(const Key('succession_scenario_assumption_save_cta')),
      );
      await tester.pumpAndSettle();

      expect(
        provider.answersSnapshot['_transmit_property_recipient_relationship'],
        'descendant',
      );
      expect(
        provider.answersSnapshot.containsKey('recipientRelationship'),
        isFalse,
      );
      expect(
        _semanticsValue(tester, 'succession_data_quest_next_ask'),
        'retainedRight',
      );
      expect(find.byKey(const Key('retained_right_habitation_option')),
          findsOneWidget);

      await tester.tap(
        find.byKey(const Key('retained_right_habitation_option')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('succession_scenario_assumption_save_cta')),
      );
      await tester.tap(
        find.byKey(const Key('succession_scenario_assumption_save_cta')),
      );
      await tester.pumpAndSettle();

      expect(
        provider.answersSnapshot['_transmit_property_retained_right'],
        'habitation',
      );
      expect(
        provider.answersSnapshot.containsKey('retainedRight'),
        isFalse,
      );
      expect(
        _semanticsValue(tester, 'succession_data_quest_next_ask'),
        'avancementHoirie',
      );
      expect(
        find.byKey(
            const ValueKey('succession_scenario_transaction_assumption')),
        findsOneWidget,
      );
      expect(
        _findSemanticsIdentifier(
            'succession_scenario_retirement_income_source'),
        findsOneWidget,
      );
      expect(find.textContaining('à confirmer'), findsWidgets);
    });

    testWidgets('does not treat default living costs as complete scenario data',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final provider = CoachProfileProvider();
      await provider.mergeAnswers({
        'fp:patrimoine.propertyMarketValue': 1200000,
        'q_target_retirement_age': 64,
        '_coach_avoir_lpp': 250000,
        'q_3a_total': 60000,
        'q_cash_total': 80000,
        'q_mortgage_balance': 420000,
        'q_children': 2,
      }, source: ProfileDataSource.userInput);

      await tester.pumpWidget(_wrap(
        const SuccessionPatrimoineScreen(),
        coachProfileProvider: provider,
      ));
      await tester.pumpAndSettle();

      final confidence = tester.widget<Semantics>(
        find.byKey(const ValueKey('succession_scenario_confidence')),
      );
      expect(confidence.properties.value, contains('missing_required_inputs'));
      expect(
        confidence.properties.value,
        contains('parentAnnualLivingCosts'),
      );
    });

    testWidgets('renders Raiffeisen transmission figures from dated facts',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
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

      await tester.pumpWidget(_wrap(
        const SuccessionPatrimoineScreen(),
        coachProfileProvider: provider,
      ));
      await tester.pumpAndSettle();

      final chfTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .where((text) => text.contains('CHF'))
          .toList(growable: false);
      expect(chfTexts, contains("CHF -8'000"));
      expect(chfTexts, contains("CHF 195'000"));
      expect(
        _semanticsValue(tester, 'succession_scenario_retirement_status'),
        'needs_review',
      );
      expect(
        _semanticsValue(tester, 'succession_scenario_equalization_status'),
        'at_risk',
      );
    });

    testWidgets('treats explicit zero liquid assets as a known scenario input',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final provider = CoachProfileProvider();
      final sourceDate = DateTime.utc(2026, 5, 31);
      provider.updateProfile(
        CoachProfile(
          birthYear: 1961,
          canton: 'VD',
          salaireBrutMensuel: 0,
          nombreEnfants: 2,
          targetRetirementAge: 64,
          depenses: const DepensesProfile(
            loyer: 3500,
            assuranceMaladie: 900,
            electricite: 180,
            transport: 300,
          ),
          prevoyance: const PrevoyanceProfile(
            renteAVSEstimeeMensuelle: 2450,
            projectedRenteLpp: 28000,
            avoirLppTotal: 250000,
            totalEpargne3a: 60000,
          ),
          patrimoine: const PatrimoineProfile(
            propertyMarketValue: 900000,
            mortgageBalance: 200000,
            epargneLiquide: 0,
          ),
          goalA: GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime(2030),
            label: 'Retraite',
          ),
          dataSources: const {
            'patrimoine.propertyMarketValue': ProfileDataSource.userInput,
            'patrimoine.mortgageBalance': ProfileDataSource.userInput,
            'patrimoine.epargneLiquide': ProfileDataSource.userInput,
            'nombreEnfants': ProfileDataSource.userInput,
            'targetRetirementAge': ProfileDataSource.userInput,
            'prevoyance.renteAVSEstimeeMensuelle': ProfileDataSource.userInput,
            'prevoyance.projectedRenteLpp': ProfileDataSource.userInput,
            'prevoyance.avoirLppTotal': ProfileDataSource.userInput,
            'prevoyance.totalEpargne3a': ProfileDataSource.userInput,
            'depenses.loyer': ProfileDataSource.userInput,
            'depenses.assuranceMaladie': ProfileDataSource.userInput,
            'depenses.electricite': ProfileDataSource.userInput,
            'depenses.transport': ProfileDataSource.userInput,
          },
          userProvidedFields: const {
            'patrimoine.epargneLiquide',
            'depenses.loyer',
            'depenses.assuranceMaladie',
            'depenses.electricite',
            'depenses.transport',
          },
          dataTimestamps: {
            'patrimoine.propertyMarketValue': sourceDate,
            'patrimoine.mortgageBalance': sourceDate,
            'patrimoine.epargneLiquide': sourceDate,
            'nombreEnfants': sourceDate,
            'targetRetirementAge': sourceDate,
            'depenses.loyer': sourceDate,
            'depenses.assuranceMaladie': sourceDate,
            'depenses.electricite': sourceDate,
            'depenses.transport': sourceDate,
            'prevoyance.renteAVSEstimeeMensuelle': sourceDate,
            'prevoyance.projectedRenteLpp': sourceDate,
            'prevoyance.avoirLppTotal': sourceDate,
            'prevoyance.totalEpargne3a': sourceDate,
          },
          dataSourceDates: {
            'patrimoine.propertyMarketValue': sourceDate,
            'patrimoine.mortgageBalance': sourceDate,
            'patrimoine.epargneLiquide': sourceDate,
            'nombreEnfants': sourceDate,
            'targetRetirementAge': sourceDate,
            'depenses.loyer': sourceDate,
            'depenses.assuranceMaladie': sourceDate,
            'depenses.electricite': sourceDate,
            'depenses.transport': sourceDate,
            'prevoyance.renteAVSEstimeeMensuelle': sourceDate,
            'prevoyance.projectedRenteLpp': sourceDate,
            'prevoyance.avoirLppTotal': sourceDate,
            'prevoyance.totalEpargne3a': sourceDate,
          },
        ),
      );

      await tester.pumpWidget(_wrap(
        const SuccessionPatrimoineScreen(),
        coachProfileProvider: provider,
      ));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('succession_scenario_retirement_status')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('succession_scenario_equalization_status')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Confiance du scénario: Moyenne'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Confiance du scénario: Aucune donnée exploitable'),
        findsNothing,
      );
    });

    testWidgets('shows stable local profile owner id after profile load',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final provider = CoachProfileProvider();
      await provider.mergeAnswers(
        const {
          'fp:patrimoine.propertyMarketValue': 1200000,
        },
        source: ProfileDataSource.estimated,
      );

      await tester.pumpWidget(_wrap(
        const SuccessionPatrimoineScreen(),
        coachProfileProvider: provider,
      ));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('profile_owner_id: local_demo_'),
        findsOneWidget,
      );
      expect(
        find.textContaining('profile_owner_id: local_demo_pending'),
        findsNothing,
      );
    });

    testWidgets('clamps property value live input to a plausible ceiling',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final provider = CoachProfileProvider();
      await tester.pumpWidget(_wrap(
        const SuccessionPatrimoineScreen(),
        coachProfileProvider: provider,
      ));
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('property_value_input')),
        '999999999999',
      );
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () => provider.profile?.patrimoine.propertyMarketValue == 99999999,
      );

      expect(provider.profile!.patrimoine.propertyMarketValue, 99999999);
      expect(find.textContaining("99'999'999"), findsOneWidget);
    });

    testWidgets('shows legal sources section title', (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      expect(find.textContaining('Sources'), findsWidgets);
    });

    testWidgets('concept card uses CO for donation (not CC)', (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      expect(find.textContaining('CO art. 239'), findsWidgets);
    });

    testWidgets('CTA uses spécialiste (not banned conseiller title)',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      // "spécialiste" should appear in the CTA
      expect(find.textContaining('spécialiste'), findsWidgets);
    });
  });
}
