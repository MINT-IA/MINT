/// Phase 01.5 W02-T03 Task 4 — coach-entry archetype guard tests.
///
/// 5 behaviors covered:
///   1. expat_us (usTaxPerson=true) → redirect to /waitlist with slug
///   2. unknown (all signals null) → redirect to /waitlist with null slug
///   3. swiss_native (nationality CH) → no redirect
///   4. swiss_native + isCouple → no redirect (CONTEXT §0 resolved-blocker:
///      read isCouple flag, do not extend enum)
///   5. independent_no_lpp → redirect to /waitlist with slug
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

    test(
        'unknown archetype (all signals null) → block with null slug',
        () {
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
      final profile =
          CoachProfile.defaults().copyWith(nationality: 'CH');
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
        'independent_no_lpp (independant, avoirLpp=0) → block with slug independent_no_lpp',
        () {
      final profile = CoachProfile.defaults().copyWith(
        nationality: 'CH',
        employmentStatus: 'independant',
      );
      final verdict = evaluateCoachArchetypeGate(profile);
      expect(verdict.shouldBlock, isTrue);
      expect(verdict.archetypeSlug, 'independent_no_lpp');
    });
  });
}
