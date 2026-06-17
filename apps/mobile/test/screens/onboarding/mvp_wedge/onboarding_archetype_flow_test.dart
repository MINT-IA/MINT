/// W2 (mint-illogism-fixes-06) — onboarding archetype-flow integration test.
///
/// Verifies the T1-T9 step machine includes the 3 new archetype-truth
/// questions (employment → civilStatus → avsLacunes) in a logical order,
/// consecutively, BEFORE financial-data collection (age), WITHOUT breaking
/// the existing scenes. Also asserts that the terminal flush re-emits the
/// captured q_* keys with the EXACT values CoachProfile.fromWizardAnswers
/// reads — proving the archetype truth hydrates the profile end-to-end.
///
/// References:
/// - lib/screens/onboarding/mvp_wedge/onboarding_provider.dart (OnboardingStep)
/// - lib/models/coach_profile.dart:2668/2702/2802 (parser readers)
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/onboarding_intent.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures the flush map without touching real storage.
class _CapturingCoachProvider extends CoachProfileProvider {
  Map<String, dynamic>? flushedAnswers;
  CoachProfile? _fakeProfile;

  @override
  CoachProfile? get profile => _fakeProfile;

  @override
  bool get hasProfile => _fakeProfile != null;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    flushedAnswers = Map<String, dynamic>.from(partial);
    _fakeProfile = CoachProfile.fromWizardAnswers(partial);
  }

  @override
  void updateFromAnswers(Map<String, dynamic> answers) {
    // Memory-seed fallback path (saveAnswers returned false): mirror the
    // merge so hasProfile flips true and the flush does not throw.
    flushedAnswers = Map<String, dynamic>.from(answers);
    _fakeProfile = CoachProfile.fromWizardAnswers(answers);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('onboarding archetype flow (W2)', () {
    test(
        'enum order: employment → civilStatus → avsLacunes, between '
        'nationality and age', () {
      const order = OnboardingStep.values;
      final iNationality = order.indexOf(OnboardingStep.nationality);
      final iEmployment = order.indexOf(OnboardingStep.employment);
      final iCivil = order.indexOf(OnboardingStep.civilStatus);
      final iAvs = order.indexOf(OnboardingStep.avsLacunes);
      final iAge = order.indexOf(OnboardingStep.age);

      // All present.
      expect(iEmployment, isNonNegative);
      expect(iCivil, isNonNegative);
      expect(iAvs, isNonNegative);

      // Logical order: statut → état civil → lacunes, consecutive.
      expect(iCivil, iEmployment + 1);
      expect(iAvs, iCivil + 1);

      // Placed as archetype signals: after nationality, before financial age.
      expect(iEmployment, greaterThan(iNationality));
      expect(iAge, greaterThan(iAvs));
    });

    test('advance() walks employment → civilStatus → avsLacunes → age', () {
      final provider = OnboardingProvider();
      provider.goToStep(OnboardingStep.employment);

      provider.advance();
      expect(provider.step, OnboardingStep.civilStatus);

      provider.advance();
      expect(provider.step, OnboardingStep.avsLacunes);

      provider.advance();
      expect(provider.step, OnboardingStep.age);
    });

    test(
        'flush re-emits captured archetype q_* keys (independant / divorce / '
        'lived_abroad) parsable by fromWizardAnswers', () async {
      final provider = OnboardingProvider();
      provider.setIntent(OnboardingIntent.values.first, 'test');
      provider.setDateOfBirth(DateTime(1985, 6, 15));
      provider.setNetMonthlyExact(6500);

      // W2 captures.
      provider.setEmploymentStatus('independant');
      provider.setCivilStatus('divorce');
      provider.setAvsLacunes('lived_abroad', yearsAbroad: 4);

      final coach = _CapturingCoachProvider();
      await provider.completeAndFlushToProfile(coach);

      final flushed = coach.flushedAnswers;
      expect(flushed, isNotNull);
      // Exact parser values re-emitted.
      expect(flushed!['q_employment_status'], 'independant');
      expect(flushed['q_civil_status'], 'divorce');
      expect(flushed['q_avs_lacunes_status'], 'lived_abroad');
      expect(flushed['q_avs_years_abroad'], 4);
      // Independant → no presumed 2nd pillar (NEVER #7).
      expect(flushed['q_has_pension_fund'], false);

      // End-to-end: the captured truth hydrates CoachProfile.
      final hydrated = coach.profile;
      expect(hydrated, isNotNull);
      expect(hydrated!.employmentStatus, 'independant');
      expect(hydrated.etatCivil, CoachCivilStatus.divorce);
      expect(hydrated.prevoyance.lacunesAVS, 4);
    });

    test(
        'flush keeps civil status as the canonical onboarding writer and '
        'does not create a household-type second writer', () async {
      final provider = OnboardingProvider();
      provider.setIntent(OnboardingIntent.impots, 'Impôts');
      provider.setDateOfBirth(DateTime(1990, 1, 1));
      provider.setNetMonthlyExact(7600);
      provider.setCivilStatus('marie');

      final coach = _CapturingCoachProvider();
      await provider.completeAndFlushToProfile(coach);

      final flushed = coach.flushedAnswers!;
      expect(flushed['onb_intent'], 'impots');
      expect(flushed['q_civil_status'], 'marie');
      expect(flushed.containsKey('q_household_type'), isFalse);
      expect(flushed['q_net_income_period_chf'], 7600);
      expect(flushed['q_net_income_confidence'], 'high');
      expect(flushed['q_net_income_period_source'], 'onboarding_exact');
      expect(coach.profile!.etatCivil, CoachCivilStatus.marie);
    });

    test(
        'flush preserves income range and marks the effective value as a '
        'range midpoint', () async {
      final provider = OnboardingProvider();
      provider.setIntent(OnboardingIntent.retraite, 'Prévoyance');
      provider.setDateOfBirth(DateTime(1988, 4, 12));
      provider.setNetMonthlyRange(7000, 7500);

      final coach = _CapturingCoachProvider();
      await provider.completeAndFlushToProfile(coach);

      final flushed = coach.flushedAnswers!;
      expect(flushed['q_net_income_period_chf'], 7250);
      expect(flushed['q_net_income_range_low'], 7000);
      expect(flushed['q_net_income_range_high'], 7500);
      expect(flushed['q_net_income_confidence'], 'medium');
      expect(
          flushed['q_net_income_period_source'], 'onboarding_range_midpoint');
    });

    test(
        'flush omits civil/avs keys when not captured (safe defaults '
        'preserved)', () async {
      final provider = OnboardingProvider();
      provider.setIntent(OnboardingIntent.values.first, 'test');
      provider.setDateOfBirth(DateTime(1990, 1, 1));
      provider.setNetMonthlyExact(5000);
      // No W2 captures at all (legacy / skipped path).

      final coach = _CapturingCoachProvider();
      await provider.completeAndFlushToProfile(coach);

      final flushed = coach.flushedAnswers!;
      // Employment defaults to salarie (existing archetype contract).
      expect(flushed['q_employment_status'], 'salarie');
      // PII keys omitted entirely so the parser keeps its safe defaults.
      expect(flushed.containsKey('q_civil_status'), isFalse);
      expect(flushed.containsKey('q_avs_lacunes_status'), isFalse);
    });
  });
}
