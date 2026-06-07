/// Phase 01.5 W02-T03 Task 4 — coach-entry archetype guard tests.
///
/// 5 behaviors covered:
///   1. expat_us (usTaxPerson=true) → redirect to /waitlist with slug
///   2. unknown (all signals null) → redirect to /waitlist with null slug
///   3. swiss_native (nationality CH) → no redirect
///   4. swiss_native + isCouple → no redirect (CONTEXT §0 resolved-blocker:
///      read isCouple flag, do not extend enum)
///   5. independent_no_lpp → no route redirect; orchestrator remains
///      safe-local-only for the audited no-LPP 3a topic
///   6. independent_with_lpp → still gated; the no-LPP local fallback must
///      never be widened to a different pension situation
///
/// Strategy: the gate decision is extracted into a pure helper
/// `evaluateCoachArchetypeGate(profile)` returning a CoachArchetypeGate
/// verdict. Widget integration (calling `context.go('/waitlist')` in a
/// post-frame callback inside coach_chat_screen.dart) is grep-validated
/// by the acceptance criteria — the pure helper carries the decision
/// logic and is testable without widget tree.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/screens/coach/coach_archetype_guard.dart';

void main() {
  group('evaluateCoachArchetypeGate', () {
    test('expat_us (usTaxPerson=true) → block with slug expat_us', () {
      final profile = CoachProfile.defaults().copyWith(usTaxPerson: true);
      final verdict = evaluateCoachArchetypeGate(profile);
      expect(verdict.shouldBlock, isTrue);
      expect(verdict.archetypeSlug, 'expat_us');
    });

    test('unknown archetype (all signals null) → block with null slug', () {
      // CoachProfile.defaults() leaves usTaxPerson, nationality,
      // residencePermit, arrivalAge null → archetype.unknown per plan 01.
      final profile = CoachProfile.defaults();
      final verdict = evaluateCoachArchetypeGate(profile);
      expect(verdict.shouldBlock, isTrue);
      expect(verdict.archetypeSlug, isNull,
          reason:
              'unknown carries a null slug in WaitlistArgs so the consent payload coerces to "other"');
    });

    test('swiss_native (nationality=CH) → no redirect', () {
      final profile = CoachProfile.defaults().copyWith(nationality: 'CH');
      final verdict = evaluateCoachArchetypeGate(profile);
      expect(verdict.shouldBlock, isFalse);
      expect(verdict.archetypeSlug, isNull);
    });

    test(
        'swiss_native + isCouple → no redirect (read isCouple at gate site, do NOT extend enum)',
        () {
      // CONTEXT §0 resolved-blocker: swissNativeCouple = nationality CH
      // AND isCouple==true; the calibrated set is {swissNative} regardless
      // of isCouple (orchestrator level handles couple-aware tips via
      // life-event keys, not via a new archetype enum value).
      final profile = CoachProfile.defaults().copyWith(
        nationality: 'CH',
        etatCivil: CoachCivilStatus.marie,
      );
      // Verify the fixture actually represents a couple.
      expect(profile.isCouple, isTrue);
      final verdict = evaluateCoachArchetypeGate(profile);
      expect(verdict.shouldBlock, isFalse);
    });

    test(
        'independent_no_lpp (independant, avoirLpp=0) → route reachable; orchestrator keeps safe-local-only scope',
        () {
      final profile = CoachProfile.defaults().copyWith(
        nationality: 'CH',
        employmentStatus: 'independant',
      );
      final verdict = evaluateCoachArchetypeGate(profile);
      expect(verdict.shouldBlock, isFalse);
      expect(verdict.archetypeSlug, 'independent_no_lpp',
          reason:
              'The slug is preserved for telemetry/context, but the route layer must let the safe local fallback path build a real CoachContext.');
    });

    test(
        'independent_with_lpp (independant, avoirLpp>0) → still gated at route layer',
        () {
      final profile = CoachProfile.defaults().copyWith(
        nationality: 'CH',
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 50000),
      );
      expect(profile.archetype, FinancialArchetype.independentWithLpp,
          reason:
              'fixture sanity: LPP coverage must route to the distinct independent_with_lpp archetype');

      final verdict = evaluateCoachArchetypeGate(profile);
      expect(verdict.shouldBlock, isTrue,
          reason:
              'the audited local fallback is scoped to independent_no_lpp only');
      expect(verdict.archetypeSlug, 'independent_with_lpp');
    });
  });

  // ══════════════════════════════════════════════════════════════════
  //  SALVAGE-01 — freshly-onboarded round-trip through the WIZARD path.
  //
  //  These exercise CoachProfile.fromWizardAnswers (the actual wedge
  //  flush output), not copyWith — proving the q_nationality the wedge
  //  now writes survives into the archetype and reaches the coach.
  // ══════════════════════════════════════════════════════════════════
  group('SALVAGE-01 fresh-onboarding archetype reachability', () {
    test(
        'fresh CH user (q_nationality=CH, q_birth_year set) → swissNative → '
        'coach reachable (shouldBlock=false)', () {
      final profile = CoachProfile.fromWizardAnswers(<String, dynamic>{
        'q_birth_year': 1996,
        'q_nationality': 'CH',
        'q_canton': 'VD',
        'q_employment_status': 'salarie',
        'q_has_pension_fund': true,
      });
      expect(profile.nationality, 'CH',
          reason: 'q_nationality must round-trip into the model field');
      expect(profile.archetype, FinancialArchetype.swissNative);
      final verdict = evaluateCoachArchetypeGate(profile);
      expect(verdict.shouldBlock, isFalse,
          reason: 'a freshly-onboarded CH user must reach the coach');
    });

    test(
        'fresh user with NO q_nationality → NOT swissNative → still gated '
        '(no silent CH fallback — regression guard, closed 2026-05-22)', () {
      final profile = CoachProfile.fromWizardAnswers(<String, dynamic>{
        'q_birth_year': 1996,
        'q_canton': 'VD',
        'q_employment_status': 'salarie',
        'q_has_pension_fund': true,
      });
      expect(profile.nationality, isNull,
          reason: 'absent q_nationality must NOT coerce to CH');
      expect(profile.archetype, isNot(FinancialArchetype.swissNative));
      final verdict = evaluateCoachArchetypeGate(profile);
      expect(verdict.shouldBlock, isTrue,
          reason: 'null nationality stays gated, never silent swissNative');
    });
  });
}
