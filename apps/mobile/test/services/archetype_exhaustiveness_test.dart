/// Tests for R1 enum exhaustiveness — every typed switch over
/// [FinancialArchetype] handles the new [FinancialArchetype.unknown] value
/// explicitly without falling through to swissNative semantics.
///
/// Sub-phase 01.5 Wave 02 Plan 01 Task 2 (R1):
/// - `coach_chat_screen._archetypeToBackendName` (private — verified
///   indirectly through the FinancialArchetypeBackendName extension which
///   has the same exhaustive map).
/// - `lifecycle_phase_service._addArchetypePriorities` — exposed through
///   `LifecyclePhaseService.detect(profile).priorities`. With archetype
///   unknown, NO archetype-specific priority is injected (no FATCA, no
///   AVS gap, no LPP buyback, no source-tax — those are gated to known
///   archetypes only).
///
/// Refs:
/// - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-02-01-PLAN.md Task 2.
/// - REVIEWS.md §R1 (enum exhaustiveness sweep).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';

/// Archetype-specific priority keys injected by `_addArchetypePriorities`.
/// If `archetype == unknown` is handled correctly, NONE of these should
/// appear in the result. (They are still allowed via situational/phase
/// rules, but NOT injected by the archetype block.)
const _archetypeOnlyKeys = <String>{
  'fatca_compliance',
  'avs_gap_analysis',
  'source_tax_optimization',
};

void main() {
  group('R1 — FinancialArchetype.unknown enum exhaustiveness', () {
    test('FinancialArchetypeBackendName handles unknown without throwing',
        () {
      // Statement-form switches on the enum without an `unknown` arm fail
      // compilation. Reaching this assertion means the arm exists.
      expect(FinancialArchetype.unknown.backendName, equals('unknown'));
    });

    test(
        'lifecycle_phase_service_handles_unknown_archetype_no_op — '
        'no archetype-only priorities injected', () {
      // Build a profile that resolves to archetype.unknown: all 4 nullable
      // signals null. Use birthYear that places the user inside the
      // construction band so the phase-level priorities are well-defined.
      final profile = CoachProfile(
        birthYear: DateTime.now().year - 30,
        canton: 'ZH',
        salaireBrutMensuel: 6000,
        // nationality, residencePermit, arrivalAge, usTaxPerson all null.
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(DateTime.now().year + 35),
          label: 'Retraite',
        ),
      );

      // Sanity: this profile MUST be archetype unknown for the test to
      // be meaningful. If this assertion fails, the test setup is wrong
      // and the no-op assertion below would be a false positive.
      expect(profile.archetype, FinancialArchetype.unknown);

      final result = LifecyclePhaseService.detect(profile);
      final priorityKeys = result.priorities.map((p) => p.key).toSet();

      for (final archetypeKey in _archetypeOnlyKeys) {
        expect(
          priorityKeys,
          isNot(contains(archetypeKey)),
          reason:
              'Archetype-only key "$archetypeKey" leaked into priorities '
              'for archetype unknown — R1 exhaustiveness gap.',
        );
      }
    });
  });
}
