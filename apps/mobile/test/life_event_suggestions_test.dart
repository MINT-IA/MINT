import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';

void main() {
  final s = SFr();

  group('buildLifeEventSuggestions', () {
    // Test 1: Young single person gets firstJob and marriage suggestions
    test('young single person gets firstJob and marriage suggestions', () {
      final suggestions = buildLifeEventSuggestions(
        age: 24,
        civilStatus: 'single',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 4500,
        canton: 'ZH',
        s: s,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(s.lifeEventSugMariage));
      expect(titles, contains(s.lifeEventSugPremierEmploi));
    });

    // Test 2: Married couple with no children gets birth suggestion
    test('married couple with no children gets birth suggestion', () {
      final suggestions = buildLifeEventSuggestions(
        age: 32,
        civilStatus: 'married',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 6000,
        canton: 'ZH',
        s: s,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(s.lifeEventSugNaissance));
    });

    // Test 3: High-income person gets housingPurchase suggestion
    test('high-income person gets housingPurchase suggestion', () {
      final suggestions = buildLifeEventSuggestions(
        age: 35,
        civilStatus: 'married',
        childrenCount: 1,
        employmentStatus: 'employee',
        monthlyNetIncome: 8000,
        canton: 'ZH',
        s: s,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(s.lifeEventSugAchatImmo));
    });

    // Test 4: Person in Geneva (high tax) gets cantonMove suggestion
    test('person in Geneva gets cantonMove suggestion', () {
      final suggestions = buildLifeEventSuggestions(
        age: 35,
        civilStatus: 'married',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 6000,
        canton: 'GE',
        s: s,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(s.lifeEventSugDemenagement));
    });

    // Test 5: Person age 55+ gets retirement suggestion
    test('person age 55+ gets retirement suggestion', () {
      final suggestions = buildLifeEventSuggestions(
        age: 57,
        civilStatus: 'married',
        childrenCount: 2,
        employmentStatus: 'employee',
        monthlyNetIncome: 7000,
        canton: 'ZH',
        s: s,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(s.lifeEventSugRetraite));
    });

    // Test 6: Concubinage status gets concubinage warning
    test('concubinage status gets concubinage warning', () {
      final suggestions = buildLifeEventSuggestions(
        age: 30,
        civilStatus: 'concubinage',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 5000,
        canton: 'ZH',
        s: s,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(s.lifeEventSugConcubinage));
      // Concubinage also qualifies for marriage suggestion
      expect(titles, contains(s.lifeEventSugMariage));
    });

    // Test 7: Independent employment gets selfEmployment tools
    test('independent employment gets selfEmployment tools', () {
      final suggestions = buildLifeEventSuggestions(
        age: 35,
        civilStatus: 'single',
        childrenCount: 0,
        employmentStatus: 'independent',
        monthlyNetIncome: 7000,
        canton: 'ZH',
        s: s,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(s.lifeEventSugOutilsIndependant));
    });

    // Test 8: Max 5 suggestions returned
    test('max 5 suggestions returned', () {
      final suggestions = buildLifeEventSuggestions(
        age: 27,
        civilStatus: 'concubinage',
        childrenCount: 1,
        employmentStatus: 'independent',
        monthlyNetIncome: 8000,
        canton: 'GE',
        s: s,
      );

      expect(suggestions.length, lessThanOrEqualTo(5));
    });

    // Test 9: Person age 50+ with children gets succession planning
    test('person age 50+ with children gets succession planning', () {
      final suggestions = buildLifeEventSuggestions(
        age: 52,
        civilStatus: 'married',
        childrenCount: 2,
        employmentStatus: 'employee',
        monthlyNetIncome: 6000,
        canton: 'ZH',
        s: s,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(s.lifeEventSugSuccession));
    });

    // Test 10: Children or high income gets disability suggestion
    test('children or high income gets disability suggestion', () {
      // With children
      final suggestionsWithKids = buildLifeEventSuggestions(
        age: 35,
        civilStatus: 'married',
        childrenCount: 2,
        employmentStatus: 'employee',
        monthlyNetIncome: 4000,
        canton: 'ZH',
        s: s,
      );
      final titlesWithKids =
          suggestionsWithKids.map((s) => s.title).toList();
      expect(titlesWithKids, contains(s.lifeEventSugInvalidite));

      // Without children but high income
      final suggestionsHighIncome = buildLifeEventSuggestions(
        age: 35,
        civilStatus: 'single',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 7000,
        canton: 'ZH',
        s: s,
      );
      final titlesHighIncome =
          suggestionsHighIncome.map((s) => s.title).toList();
      expect(titlesHighIncome, contains(s.lifeEventSugInvalidite));
    });
  });
}
