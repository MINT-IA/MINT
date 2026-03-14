import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';

void main() {
  group('buildLifeEventSuggestions', () {
    late BuildContext testContext;

    Future<void> pumpContext(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          locale: const Locale('fr'),
          home: Builder(
            builder: (context) {
              testContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Test 1: Young single person gets firstJob and marriage suggestions
    testWidgets('young single person gets firstJob and marriage suggestions',
        (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 24,
        civilStatus: 'single',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 4500,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/mariage'));
      expect(routes, contains('/first-job'));
    });

    // Test 2: Married couple with no children gets birth suggestion
    testWidgets('married couple with no children gets birth suggestion',
        (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 32,
        civilStatus: 'married',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 6000,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/naissance'));
    });

    // Test 3: High-income person gets housingPurchase suggestion
    testWidgets('high-income person gets housingPurchase suggestion',
        (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 35,
        civilStatus: 'married',
        childrenCount: 1,
        employmentStatus: 'employee',
        monthlyNetIncome: 8000,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/mortgage/affordability'));
    });

    // Test 4: Person in Geneva (high tax) gets cantonMove suggestion
    testWidgets('person in Geneva gets cantonMove suggestion',
        (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 35,
        civilStatus: 'married',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 6000,
        canton: 'GE',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/fiscal'));
    });

    // Test 5: Person age 55+ gets retirement suggestion
    testWidgets('person age 55+ gets retirement suggestion',
        (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 57,
        civilStatus: 'married',
        childrenCount: 2,
        employmentStatus: 'employee',
        monthlyNetIncome: 7000,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/retirement'));
    });

    // Test 6: Concubinage status gets concubinage warning
    testWidgets('concubinage status gets concubinage warning',
        (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 30,
        civilStatus: 'concubinage',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 5000,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/concubinage'));
      // Concubinage also qualifies for marriage suggestion
      expect(routes, contains('/mariage'));
    });

    // Test 7: Independent employment gets selfEmployment tools
    testWidgets('independent employment gets selfEmployment tools',
        (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 35,
        civilStatus: 'single',
        childrenCount: 0,
        employmentStatus: 'independent',
        monthlyNetIncome: 7000,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/segments/independant'));
    });

    // Test 8: Max 5 suggestions returned
    testWidgets('max 5 suggestions returned', (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 27,
        civilStatus: 'concubinage',
        childrenCount: 1,
        employmentStatus: 'independent',
        monthlyNetIncome: 8000,
        canton: 'GE',
      );

      expect(suggestions.length, lessThanOrEqualTo(5));
    });

    // Test 9: Person age 50+ with children gets succession planning
    testWidgets('person age 50+ with children gets succession planning',
        (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 52,
        civilStatus: 'married',
        childrenCount: 2,
        employmentStatus: 'employee',
        monthlyNetIncome: 6000,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/life-event/succession'));
    });

    // Test 10: Children or high income gets disability suggestion
    testWidgets('children or high income gets disability suggestion',
        (tester) async {
      await pumpContext(tester);
      // With children
      final suggestionsWithKids = buildLifeEventSuggestions(
        context: testContext,
        age: 35,
        civilStatus: 'married',
        childrenCount: 2,
        employmentStatus: 'employee',
        monthlyNetIncome: 4000,
        canton: 'ZH',
      );
      final routesWithKids =
          suggestionsWithKids.map((s) => s.route).toList();
      expect(routesWithKids, contains('/simulator/disability-gap'));

      // Without children but high income
      final suggestionsHighIncome = buildLifeEventSuggestions(
        context: testContext,
        age: 35,
        civilStatus: 'single',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 7000,
        canton: 'ZH',
      );
      final routesHighIncome =
          suggestionsHighIncome.map((s) => s.route).toList();
      expect(routesHighIncome, contains('/simulator/disability-gap'));
    });
  });
}
