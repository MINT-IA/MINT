/// Tests for [CoachProfile.ageOrNull] — Wave B-minimal B6.
///
/// Contract: returns `null` when birthYear/dateOfBirth is missing or out of
/// valid range (future date, impossible old age). Returns a valid `int`
/// otherwise. Consumers (CapEngine, simulators) rely on null to skip
/// age-dependent logic rather than silently compute with `age=0`.
///
/// Refs:
/// - Panel 7 Perfection Gap finding #7
/// - Panel archi review 2026-04-18 (30+ call-sites)
/// - Panel adversaire BUG 4 (CapEngine 10 call-sites)
/// - `.planning/wave-b-home-orchestrateur/PLAN.md` B6-minimal
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CoachProfile.ageOrNull — B6-minimal contract', () {
    final currentYear = DateTime.now().year;

    test('birthYear=0 (default/unset) returns null', () {
      final profile = _buildProfile(birthYear: 0);
      expect(profile.ageOrNull, isNull);
      // Legacy `age` getter still returns 0 for back-compat.
      expect(profile.age, equals(0));
    });

    test('birthYear in the future returns null', () {
      final profile = _buildProfile(birthYear: currentYear + 5);
      expect(profile.ageOrNull, isNull);
      expect(profile.age, equals(0));
    });

    test('birthYear far in the past (before 1900) returns null', () {
      final profile = _buildProfile(birthYear: 1800);
      expect(profile.ageOrNull, isNull);
    });

    test('birthYear valid working-age returns correct age', () {
      final profile = _buildProfile(birthYear: 1977);
      expect(profile.ageOrNull, equals(currentYear - 1977));
      expect(profile.age, equals(currentYear - 1977));
    });

    test('birthYear valid child (loose max bound) returns positive age', () {
      // Newborns or very young users (custodial accounts): age can be 0-9.
      // The helper allows [1900, currentYear+1] — a birthYear of
      // currentYear returns 0 which is a valid age (just born).
      final profile = _buildProfile(birthYear: currentYear);
      expect(profile.ageOrNull, equals(0));
    });

    test('dateOfBirth in the future returns null', () {
      final profile = _buildProfile(
        birthYear: 0,
        dateOfBirth: DateTime(currentYear + 2, 1, 1),
      );
      expect(profile.ageOrNull, isNull);
    });

    test('dateOfBirth impossibly old (>150) returns null', () {
      final profile = _buildProfile(
        birthYear: 0,
        dateOfBirth: DateTime(currentYear - 200, 1, 1),
      );
      expect(profile.ageOrNull, isNull);
    });

    test('dateOfBirth valid returns correct age', () {
      final profile = _buildProfile(
        birthYear: 0,
        dateOfBirth: DateTime(1977, 1, 12),
      );
      final expected = currentYear -
          1977 -
          (DateTime.now().isBefore(DateTime(currentYear, 1, 12)) ? 1 : 0);
      expect(profile.ageOrNull, equals(expected));
    });

    test('dateOfBirth takes precedence over birthYear', () {
      // When both are set, dateOfBirth wins (more precise).
      final profile = _buildProfile(
        birthYear: 1980,
        dateOfBirth: DateTime(1977, 6, 15),
      );
      // Expected age ~ currentYear - 1977 (roughly).
      final age = profile.ageOrNull;
      expect(age, isNotNull);
      expect(age, closeTo(currentYear - 1977, 1));
    });

    test(
      'legacy contract: age getter preserves 0-sentinel for back-compat',
      () {
        // Readiness gates still read `profile.age == 0` as "missing" per
        // the CHAOS-3 convention. B6-minimal documents this but does not
        // remove it (that is Wave E systemic migration).
        final empty = _buildProfile(birthYear: 0);
        expect(empty.age, equals(0));
        // New callers should prefer ageOrNull == null check.
        expect(empty.ageOrNull, isNull);
      },
    );
  });

  // SALVAGE-01-02 / math-02: the retirement-horizon getter must return
  // null (NOT a fabricated 65) when age is unknown, mirroring the
  // already-correct PrevoyanceProfile.anneesAvantRetraite twin.
  group('CoachProfile.anneesAvantRetraite — math-02 null-skip', () {
    final currentYear = DateTime.now().year;

    test('birthYear=0 (unset) returns null, not a fabricated 65', () {
      final profile = _buildProfile(birthYear: 0);
      expect(profile.anneesAvantRetraite, isNull);
    });

    test('valid birthYear returns (effectiveRetirementAge - age).clamp', () {
      final profile = _buildProfile(birthYear: 1996);
      final age = currentYear - 1996;
      final expected = (profile.effectiveRetirementAge - age).clamp(0, 99);
      expect(profile.anneesAvantRetraite, equals(expected));
    });
  });

  group('CoachProfile.fromWizardAnswers — date of birth truth', () {
    test('DOB-only wizard answers derive birthYear and retirement target', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_date_of_birth': '1977-06-15',
        'q_canton': 'VD',
        'q_main_goal': 'retirement',
        'q_target_retirement_age': 63,
      });

      expect(profile.birthYear, 1977);
      expect(profile.dateOfBirth, DateTime(1977, 6, 15));
      expect(profile.ageOrNull, isNotNull);
      expect(profile.goalA.targetDate, DateTime(2040, 12, 31));
    });

    test('DOB wins over stale birthYear in wizard answers', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1980,
        'q_date_of_birth': '1977-06-15',
        'q_canton': 'VD',
      });

      expect(profile.birthYear, 1977);
      expect(profile.ageOrNull, closeTo(DateTime.now().year - 1977, 1));
    });

    test('loadFromWizard preserves DOB-only profile after persistence reload',
        () async {
      final secureStorage = <String, String>{};
      const secureStorageChannel =
          MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (call) async {
        final key = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) secureStorage[key] = value;
            return null;
          case 'read':
            return key == null ? null : secureStorage[key];
          case 'delete':
            if (key != null) secureStorage.remove(key);
            return null;
          default:
            return null;
        }
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureStorageChannel, null);
      });
      SharedPreferences.setMockInitialValues({});
      await ReportPersistenceService.saveAnswers({
        'q_date_of_birth': '1977-06-15',
        'q_canton': 'VD',
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);

      final provider = CoachProfileProvider();
      await provider.loadFromWizard();

      expect(provider.profile, isNotNull);
      expect(provider.profile!.birthYear, 1977);
      expect(provider.profile!.dateOfBirth, DateTime(1977, 6, 15));
      expect(provider.profile!.ageOrNull, isNotNull);
    });
  });

  group('CoachProfile.hasMaterialData', () {
    test('empty wizard answers are not material despite expense defaults', () {
      final profile = CoachProfile.fromWizardAnswers({});

      expect(profile.hasMaterialData, isFalse);
      expect(profile.depenses.loyer, greaterThan(0));
      expect(profile.depenses.assuranceMaladie, greaterThan(0));
    });

    test('identity-only DOB/canton profile is not material', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_date_of_birth': '1977-06-15',
        'q_canton': 'VD',
      });

      expect(profile.ageOrNull, isNotNull);
      expect(profile.canton, 'VD');
      expect(profile.hasMaterialData, isFalse);
    });

    test('present but empty/zero answers are not material', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_canton': '',
        'q_date_of_birth': '',
        'q_housing_cost_period_chf': 0,
        'q_lamal_premium_monthly_chf': 0,
        'q_net_income_period_chf': 0,
        'q_debt_payments_period_chf': 0,
      });

      expect(profile.userProvidedFields, isNotEmpty);
      expect(profile.hasMaterialData, isFalse);
    });

    test('expense-only answers are not material financial summary data', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_housing_cost_period_chf': 2100,
        'q_lamal_premium_monthly_chf': 390,
      });

      expect(profile.depenses.loyer, 2100);
      expect(profile.depenses.assuranceMaladie, 390);
      expect(profile.hasMaterialData, isFalse);
    });

    test('financial assets, retirement assets, or debt are material', () {
      final lppProfile = CoachProfile.fromWizardAnswers({
        '_coach_avoir_lpp': 42000,
      });
      final pillar3aProfile = CoachProfile.fromWizardAnswers({
        'q_3a_total': 12000,
      });
      final debtProfile = CoachProfile.fromWizardAnswers({
        'q_debt_payments_period_chf': 450,
      });

      expect(lppProfile.hasMaterialData, isTrue);
      expect(pillar3aProfile.hasMaterialData, isTrue);
      expect(debtProfile.hasMaterialData, isTrue);
    });

    test('salary answers are material', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_net_income_period_chf': 7000,
      });

      expect(profile.hasMaterialData, isTrue);
    });
  });
}

/// Helper that builds a minimal [CoachProfile] with only the fields
/// required to test age resolution. Fills the required constructor
/// parameters with safe neutral defaults so each test stays readable.
CoachProfile _buildProfile({
  required int birthYear,
  DateTime? dateOfBirth,
}) {
  return CoachProfile(
    birthYear: birthYear,
    dateOfBirth: dateOfBirth,
    canton: 'VS',
    salaireBrutMensuel: 0,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2040),
      label: '',
    ),
  );
}
