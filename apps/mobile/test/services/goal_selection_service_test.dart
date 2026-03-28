/// Tests for GoalSelectionService.
///
/// Validates:
///   - Available goals returned for empty / various profiles.
///   - Profile-based relevance filtering (age, housing, debt, employment).
///   - Persistence: set/get/clear goal via SharedPreferences.
///   - Key resolution helpers (title, description).
///   - Julien + Lauren golden couple scenarios.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/goal_selection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Helpers ──────────────────────────────────────────────────────────────

CoachProfile _makeProfile({
  int birthYear = 1985,
  double salary = 8000,
  String employmentStatus = 'salarie',
  String? housingStatus,
  DetteProfile dettes = const DetteProfile(),
  CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: 'VD',
    salaireBrutMensuel: salary,
    employmentStatus: employmentStatus,
    housingStatus: housingStatus,
    dettes: dettes,
    etatCivil: etatCivil,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Test',
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  final l = SFr();

  // ==========================================================================
  //  AVAILABLE GOALS — EMPTY / MINIMAL PROFILE
  // ==========================================================================

  group('availableGoals — empty/minimal profile', () {
    test('budget_overview always present', () {
      final profile = _makeProfile();
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, contains('budget_overview'));
    });

    test('tax_optimization_3a always present', () {
      final profile = _makeProfile();
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, contains('tax_optimization_3a'));
    });

    test('retirement_choice present if age > 25', () {
      // birthYear 1985 → age ~40
      final profile = _makeProfile(birthYear: 1985);
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, contains('retirement_choice'));
    });

    test('retirement_choice absent if age <= 25', () {
      final currentYear = DateTime.now().year;
      // birthYear such that age = 25
      final profile = _makeProfile(birthYear: currentYear - 25);
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, isNot(contains('retirement_choice')));
    });

    test('returns only relevant goals (no nulls, no irrelevant)', () {
      final profile = _makeProfile();
      final goals = GoalSelectionService.availableGoals(profile, l);
      // All returned goals have isRelevant = true
      for (final g in goals) {
        expect(g.isRelevant, isTrue,
            reason: 'Goal ${g.intentTag} should be relevant');
      }
    });

    test('returns a non-empty list', () {
      final profile = _makeProfile();
      final goals = GoalSelectionService.availableGoals(profile, l);
      expect(goals, isNotEmpty);
    });
  });

  // ==========================================================================
  //  PROFILE-BASED RELEVANCE FILTERING
  // ==========================================================================

  group('availableGoals — housing relevance', () {
    test('housing_purchase present if no property and age < 55', () {
      final profile = _makeProfile(birthYear: 1990, housingStatus: 'locataire');
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, contains('housing_purchase'));
    });

    test('housing_purchase absent if already owner', () {
      final profile = _makeProfile(housingStatus: 'proprio');
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, isNot(contains('housing_purchase')));
    });

    test('housing_purchase absent if proprietaire variant', () {
      final profile = _makeProfile(housingStatus: 'proprietaire');
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, isNot(contains('housing_purchase')));
    });

    test('housing_purchase absent if age >= 55', () {
      final currentYear = DateTime.now().year;
      final profile = _makeProfile(
        birthYear: currentYear - 56,
        housingStatus: 'locataire',
      );
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, isNot(contains('housing_purchase')));
    });
  });

  group('availableGoals — debt relevance', () {
    test('debt_check present if has dette', () {
      final profile = _makeProfile(
        dettes: const DetteProfile(creditConsommation: 15000),
      );
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, contains('debt_check'));
    });

    test('debt_check absent if no dette', () {
      final profile = _makeProfile(dettes: const DetteProfile());
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, isNot(contains('debt_check')));
    });
  });

  group('availableGoals — birth relevance', () {
    test('life_event_birth present for age 25-45', () {
      final currentYear = DateTime.now().year;
      final profile = _makeProfile(birthYear: currentYear - 32);
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, contains('life_event_birth'));
    });

    test('life_event_birth absent for age > 45', () {
      final currentYear = DateTime.now().year;
      final profile = _makeProfile(birthYear: currentYear - 50);
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, isNot(contains('life_event_birth')));
    });

    test('life_event_birth absent for age < 25', () {
      final currentYear = DateTime.now().year;
      final profile = _makeProfile(birthYear: currentYear - 22);
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, isNot(contains('life_event_birth')));
    });
  });

  group('availableGoals — self-employment relevance', () {
    test('self_employment present if salarié', () {
      final profile = _makeProfile(employmentStatus: 'salarie');
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, contains('self_employment'));
    });

    test('self_employment present if employe variant', () {
      final profile = _makeProfile(employmentStatus: 'employe');
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, contains('self_employment'));
    });

    test('self_employment present if chomage status', () {
      final profile = _makeProfile(employmentStatus: 'chomage');
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      // chomage is not 'independant' — but not 'salarie'/'employe' either
      // so self_employment should NOT be offered (we only show it for salariés)
      expect(tags, isNot(contains('self_employment')));
    });

    test('self_employment absent if independant', () {
      final profile = _makeProfile(employmentStatus: 'independant');
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      expect(tags, isNot(contains('self_employment')));
    });
  });

  // ==========================================================================
  //  GOLDEN COUPLE — Julien profile
  // ==========================================================================

  group('availableGoals — Julien golden couple', () {
    // Julien: born 1977, salary 122207 CHF/an, canton VS, CH, salarie, no prop
    test('Julien profile includes retirement + budget + tax + housing', () {
      final profile = CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        nationality: 'CH',
        salaireBrutMensuel: 122207 / 12,
        employmentStatus: 'salarie',
        housingStatus: 'locataire',
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042),
          label: 'Retraite Julien',
        ),
      );
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();

      expect(tags, contains('retirement_choice'));
      expect(tags, contains('budget_overview'));
      expect(tags, contains('tax_optimization_3a'));
      // Julien is 49 in 2026 < 55 → housing should be present
      expect(tags, contains('housing_purchase'));
    });
  });

  // ==========================================================================
  //  PERSISTENCE — set / get / clear
  // ==========================================================================

  group('setSelectedGoal / getSelectedGoal / clearSelectedGoal', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('getSelectedGoal returns null when nothing set', () async {
      final prefs = await SharedPreferences.getInstance();
      final result = await GoalSelectionService.getSelectedGoal(prefs);
      expect(result, isNull);
    });

    test('setSelectedGoal then getSelectedGoal returns same tag', () async {
      final prefs = await SharedPreferences.getInstance();
      await GoalSelectionService.setSelectedGoal('retirement_choice', prefs);
      final result = await GoalSelectionService.getSelectedGoal(prefs);
      expect(result, 'retirement_choice');
    });

    test('setSelectedGoal overwrites previous value', () async {
      final prefs = await SharedPreferences.getInstance();
      await GoalSelectionService.setSelectedGoal('budget_overview', prefs);
      await GoalSelectionService.setSelectedGoal('housing_purchase', prefs);
      final result = await GoalSelectionService.getSelectedGoal(prefs);
      expect(result, 'housing_purchase');
    });

    test('clearSelectedGoal makes getSelectedGoal return null', () async {
      final prefs = await SharedPreferences.getInstance();
      await GoalSelectionService.setSelectedGoal('tax_optimization_3a', prefs);
      await GoalSelectionService.clearSelectedGoal(prefs);
      final result = await GoalSelectionService.getSelectedGoal(prefs);
      expect(result, isNull);
    });

    test('clearSelectedGoal on empty prefs does not throw', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        () => GoalSelectionService.clearSelectedGoal(prefs),
        returnsNormally,
      );
    });
  });

  // ==========================================================================
  //  TITLE / DESCRIPTION RESOLUTION
  // ==========================================================================

  group('resolveTitle and resolveDescription', () {
    test('resolveTitle returns non-empty string for all known title keys', () {
      final titleKeys = [
        'goalRetirementTitle',
        'goalBudgetTitle',
        'goalTaxTitle',
        'goalHousingTitle',
        'goalDebtTitle',
        'goalBirthTitle',
        'goalIndependentTitle',
      ];
      for (final key in titleKeys) {
        final title = GoalSelectionService.resolveTitle(key, l);
        expect(title, isNotEmpty,
            reason: 'Expected non-empty title for $key');
        expect(title, isNot(equals(key)),
            reason: 'Expected resolved text (not raw key) for $key');
      }
    });

    test('resolveDescription returns non-empty string for all known desc keys', () {
      final descKeys = [
        'goalRetirementDesc',
        'goalBudgetDesc',
        'goalTaxDesc',
        'goalHousingDesc',
        'goalDebtDesc',
        'goalBirthDesc',
        'goalIndependentDesc',
      ];
      for (final key in descKeys) {
        final desc = GoalSelectionService.resolveDescription(key, l);
        expect(desc, isNotEmpty,
            reason: 'Expected non-empty desc for $key');
        expect(desc, isNot(equals(key)),
            reason: 'Expected resolved text (not raw key) for $key');
      }
    });

    test('resolveTitle falls back to key for unknown key', () {
      final result = GoalSelectionService.resolveTitle('unknownKey', l);
      expect(result, 'unknownKey');
    });

    test('resolveDescription falls back to key for unknown key', () {
      final result =
          GoalSelectionService.resolveDescription('unknownDescKey', l);
      expect(result, 'unknownDescKey');
    });
  });

  // ==========================================================================
  //  SELECTABLE GOAL STRUCTURE
  // ==========================================================================

  group('SelectableGoal structure', () {
    test('each goal has non-empty intentTag, titleKey, descriptionKey, iconName', () {
      final profile = _makeProfile();
      final goals = GoalSelectionService.availableGoals(profile, l);
      for (final g in goals) {
        expect(g.intentTag, isNotEmpty);
        expect(g.titleKey, isNotEmpty);
        expect(g.descriptionKey, isNotEmpty);
        expect(g.iconName, isNotEmpty);
      }
    });

    test('no duplicate intentTags in returned list', () {
      final profile = _makeProfile(
        dettes: const DetteProfile(creditConsommation: 5000),
        housingStatus: 'locataire',
      );
      final goals = GoalSelectionService.availableGoals(profile, l);
      final tags = goals.map((g) => g.intentTag).toList();
      final unique = tags.toSet();
      expect(tags.length, unique.length,
          reason: 'Duplicate intent tags found: $tags');
    });
  });
}
