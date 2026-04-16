import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/anticipation/anticipation_engine.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';

// ────────────────────────────────────────────────────────────
//  ANTICIPATION ENGINE TESTS — Phase 04 / Plan 01
// ────────────────────────────────────────────────────────────

/// Default goal for test profiles.
final _defaultGoal = GoalA(
  type: GoalAType.retraite,
  targetDate: DateTime(2042, 1, 1),
  label: 'Test goal',
);

/// Helper to build a minimal CoachProfile for testing.
CoachProfile _profile({
  int birthYear = 1990,
  String canton = 'VD',
  String? nationality,
  String employmentStatus = 'salarie',
  double salaireBrutMensuel = 8000,
  double? avoirLppTotal,
  double? rachatMaximum,
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    nationality: nationality,
    employmentStatus: employmentStatus,
    salaireBrutMensuel: salaireBrutMensuel,
    goalA: _defaultGoal,
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLppTotal,
      rachatMaximum: rachatMaximum,
    ),
    createdAt: DateTime(2024, 1, 1),
  );
}

/// Helper to build a profile that resolves to independentNoLpp archetype.
CoachProfile _independentNoLppProfile({
  int birthYear = 1990,
  String canton = 'VD',
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    employmentStatus: 'independant',
    salaireBrutMensuel: 8000,
    goalA: _defaultGoal,
    prevoyance: const PrevoyanceProfile(
      // independentNoLpp = no LPP data at all
    ),
    createdAt: DateTime(2024, 1, 1),
  );
}

/// Helper to build a salary BiographyFact.
BiographyFact _salaryFact({
  required String value,
  required DateTime updatedAt,
  FactSource source = FactSource.userInput,
  String id = '',
}) {
  return BiographyFact(
    id: id.isEmpty ? 'fact_${updatedAt.toIso8601String()}' : id,
    factType: FactType.salary,
    value: value,
    source: source,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

void main() {
  // ── 3a Deadline ──────────────────────────────────────────

  group('fiscal3aDeadline', () {
    test('fires in December for salaried user', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: [],
        now: DateTime(2026, 12, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.fiscal3aDeadline,
      );
      expect(match, isNotEmpty);
      expect(match.first.params?['limit'], contains('7'));
    });

    test('uses 36288 plafond for independentNoLpp', () {
      final signals = AnticipationEngine.evaluate(
        profile: _independentNoLppProfile(),
        facts: [],
        now: DateTime(2026, 12, 15),
        dismissedIds: [],
      );
      final match = signals.firstWhere(
        (s) => s.template == AlertTemplate.fiscal3aDeadline,
      );
      expect(match.params?['limit'], contains('36'));
    });

    test('does NOT fire in non-December months', () {
      for (final month in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
        final signals = AnticipationEngine.evaluate(
          profile: _profile(),
          facts: [],
          now: DateTime(2026, month, 15),
          dismissedIds: [],
        );
        final match = signals.where(
          (s) => s.template == AlertTemplate.fiscal3aDeadline,
        );
        expect(match, isEmpty, reason: 'Should not fire in month $month');
      }
    });

    test('includes days remaining and year in params', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: [],
        now: DateTime(2026, 12, 20),
        dismissedIds: [],
      );
      final match = signals.firstWhere(
        (s) => s.template == AlertTemplate.fiscal3aDeadline,
      );
      expect(match.params?['days'], '11');
      expect(match.params?['year'], '2026');
    });

    test('expiresAt is January 1 of next year', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: [],
        now: DateTime(2026, 12, 15),
        dismissedIds: [],
      );
      final match = signals.firstWhere(
        (s) => s.template == AlertTemplate.fiscal3aDeadline,
      );
      expect(match.expiresAt, DateTime(2027, 1, 1));
    });

    test('sourceRef references OPP3', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: [],
        now: DateTime(2026, 12, 15),
        dismissedIds: [],
      );
      final match = signals.firstWhere(
        (s) => s.template == AlertTemplate.fiscal3aDeadline,
      );
      expect(match.sourceRef, contains('OPP3'));
    });
  });

  // ── Cantonal Tax Deadline ────────────────────────────────

  group('cantonalTaxDeadline', () {
    test('fires 45 days before VD deadline (March 31) — now=March 1', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(canton: 'VD'),
        facts: [],
        now: DateTime(2026, 3, 1),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.cantonalTaxDeadline,
      );
      expect(match, isNotEmpty);
    });

    test('does NOT fire for TI on March 1 (TI deadline is April 30)', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(canton: 'TI'),
        facts: [],
        now: DateTime(2026, 3, 1),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.cantonalTaxDeadline,
      );
      expect(match, isEmpty);
    });

    test('fires for TI 45 days before April 30 — now=March 20', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(canton: 'TI'),
        facts: [],
        now: DateTime(2026, 3, 20),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.cantonalTaxDeadline,
      );
      expect(match, isNotEmpty);
    });

    test('does NOT fire after the deadline has passed', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(canton: 'VD'),
        facts: [],
        now: DateTime(2026, 4, 5),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.cantonalTaxDeadline,
      );
      expect(match, isEmpty);
    });

    test('does NOT fire way before the 45-day window', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(canton: 'VD'),
        facts: [],
        now: DateTime(2026, 1, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.cantonalTaxDeadline,
      );
      expect(match, isEmpty);
    });

    test('includes canton and deadline in params', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(canton: 'VD'),
        facts: [],
        now: DateTime(2026, 3, 1),
        dismissedIds: [],
      );
      final match = signals.firstWhere(
        (s) => s.template == AlertTemplate.cantonalTaxDeadline,
      );
      expect(match.params?['canton'], 'VD');
      expect(match.params?['deadline'], isNotNull);
    });

    test('defaults to March 31 for unknown cantons', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(canton: 'XX'),
        facts: [],
        now: DateTime(2026, 3, 1),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.cantonalTaxDeadline,
      );
      expect(match, isNotEmpty);
    });
  });

  // ── LPP Rachat Window ───────────────────────────────────

  group('lppRachatWindow', () {
    test('fires in October (Q4) with LPP capital', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(avoirLppTotal: 50000),
        facts: [],
        now: DateTime(2026, 10, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.lppRachatWindow,
      );
      expect(match, isNotEmpty);
    });

    test('fires in November', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(avoirLppTotal: 50000),
        facts: [],
        now: DateTime(2026, 11, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.lppRachatWindow,
      );
      expect(match, isNotEmpty);
    });

    test('fires in December', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(avoirLppTotal: 50000),
        facts: [],
        now: DateTime(2026, 12, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.lppRachatWindow,
      );
      expect(match, isNotEmpty);
    });

    test('does NOT fire in Q1-Q3', () {
      for (final month in [1, 2, 3, 4, 5, 6, 7, 8, 9]) {
        final signals = AnticipationEngine.evaluate(
          profile: _profile(avoirLppTotal: 50000),
          facts: [],
          now: DateTime(2026, month, 15),
          dismissedIds: [],
        );
        final match = signals.where(
          (s) => s.template == AlertTemplate.lppRachatWindow,
        );
        expect(match, isEmpty, reason: 'Should not fire in month $month');
      }
    });

    test('fires when rachatMax > 0', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(rachatMaximum: 100000),
        facts: [],
        now: DateTime(2026, 10, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.lppRachatWindow,
      );
      expect(match, isNotEmpty);
    });

    test('sourceRef references LPP art. 79b', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(avoirLppTotal: 50000),
        facts: [],
        now: DateTime(2026, 10, 15),
        dismissedIds: [],
      );
      final match = signals.firstWhere(
        (s) => s.template == AlertTemplate.lppRachatWindow,
      );
      expect(match.sourceRef, contains('LPP'));
      expect(match.sourceRef, contains('79b'));
    });
  });

  // ── Salary Increase ─────────────────────────────────────

  group('salaryIncrease3aRecalc', () {
    test('fires on >5% salary increase', () {
      final facts = [
        _salaryFact(
          id: 'old',
          value: '80000',
          updatedAt: DateTime(2025, 1, 1),
        ),
        _salaryFact(
          id: 'new',
          value: '90000',
          updatedAt: DateTime(2026, 3, 1),
        ),
      ];
      final signals = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: facts,
        now: DateTime(2026, 3, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.salaryIncrease3aRecalc,
      );
      expect(match, isNotEmpty);
    });

    test('does NOT fire on <5% increase (and <2000 CHF)', () {
      final facts = [
        _salaryFact(
          id: 'old',
          value: '80000',
          updatedAt: DateTime(2025, 1, 1),
        ),
        _salaryFact(
          id: 'new',
          value: '81500',
          updatedAt: DateTime(2026, 3, 1),
        ),
      ];
      final signals = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: facts,
        now: DateTime(2026, 3, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.salaryIncrease3aRecalc,
      );
      expect(match, isEmpty);
    });

    test('fires on >2000 CHF increase even if <5%', () {
      final facts = [
        _salaryFact(
          id: 'old',
          value: '100000',
          updatedAt: DateTime(2025, 1, 1),
        ),
        _salaryFact(
          id: 'new',
          value: '102500',
          updatedAt: DateTime(2026, 3, 1),
        ),
      ];
      final signals = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: facts,
        now: DateTime(2026, 3, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.salaryIncrease3aRecalc,
      );
      expect(match, isNotEmpty);
    });

    test('ignores userEdit source (correction, not real increase)', () {
      final facts = [
        _salaryFact(
          id: 'old',
          value: '80000',
          updatedAt: DateTime(2025, 1, 1),
        ),
        _salaryFact(
          id: 'new',
          value: '95000',
          updatedAt: DateTime(2026, 3, 1),
          source: FactSource.userEdit,
        ),
      ];
      final signals = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: facts,
        now: DateTime(2026, 3, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.salaryIncrease3aRecalc,
      );
      expect(match, isEmpty);
    });

    test('does NOT fire with only one salary fact', () {
      final facts = [
        _salaryFact(
          id: 'only',
          value: '90000',
          updatedAt: DateTime(2026, 3, 1),
        ),
      ];
      final signals = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: facts,
        now: DateTime(2026, 3, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.salaryIncrease3aRecalc,
      );
      expect(match, isEmpty);
    });

    test('does NOT fire on salary decrease', () {
      final facts = [
        _salaryFact(
          id: 'old',
          value: '90000',
          updatedAt: DateTime(2025, 1, 1),
        ),
        _salaryFact(
          id: 'new',
          value: '80000',
          updatedAt: DateTime(2026, 3, 1),
        ),
      ];
      final signals = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: facts,
        now: DateTime(2026, 3, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.salaryIncrease3aRecalc,
      );
      expect(match, isEmpty);
    });
  });

  // ── Age Milestone ───────────────────────────────────────

  group('ageMilestoneLppBonification', () {
    test('fires at age 35 (crossing 35-44 bracket)', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(birthYear: 1991),
        facts: [],
        now: DateTime(2026, 6, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.ageMilestoneLppBonification,
      );
      expect(match, isNotEmpty);
      expect(match.first.params?['age'], '35');
    });

    test('fires at age 45 (crossing 45-54 bracket)', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(birthYear: 1981),
        facts: [],
        now: DateTime(2026, 6, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.ageMilestoneLppBonification,
      );
      expect(match, isNotEmpty);
      expect(match.first.params?['age'], '45');
    });

    test('fires at age 55 (crossing 55-65 bracket)', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(birthYear: 1971),
        facts: [],
        now: DateTime(2026, 6, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.ageMilestoneLppBonification,
      );
      expect(match, isNotEmpty);
      expect(match.first.params?['age'], '55');
    });

    test('does NOT fire at age 36 (not a bracket boundary)', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(birthYear: 1990),
        facts: [],
        now: DateTime(2026, 6, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.ageMilestoneLppBonification,
      );
      expect(match, isEmpty);
    });

    test('does NOT fire at age 30 (within 25-34, no bracket change)', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(birthYear: 1996),
        facts: [],
        now: DateTime(2026, 6, 15),
        dismissedIds: [],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.ageMilestoneLppBonification,
      );
      expect(match, isEmpty);
    });

    test('includes old and new rates in params', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(birthYear: 1991),
        facts: [],
        now: DateTime(2026, 6, 15),
        dismissedIds: [],
      );
      final match = signals.firstWhere(
        (s) => s.template == AlertTemplate.ageMilestoneLppBonification,
      );
      expect(match.params?['oldRate'], '7');
      expect(match.params?['newRate'], '10');
    });

    test('sourceRef references LPP art. 16', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(birthYear: 1991),
        facts: [],
        now: DateTime(2026, 6, 15),
        dismissedIds: [],
      );
      final match = signals.firstWhere(
        (s) => s.template == AlertTemplate.ageMilestoneLppBonification,
      );
      expect(match.sourceRef, contains('LPP'));
      expect(match.sourceRef, contains('16'));
    });
  });

  // ── Dismissed / Expired ─────────────────────────────────

  group('dismissed and expired signals', () {
    test('dismissed IDs are excluded from results', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: [],
        now: DateTime(2026, 12, 15),
        dismissedIds: ['fiscal3aDeadline_20261215'],
      );
      final match = signals.where(
        (s) => s.template == AlertTemplate.fiscal3aDeadline,
      );
      expect(match, isEmpty);
    });

    test('all returned signals have expiresAt after now', () {
      final signals = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: [],
        now: DateTime(2026, 12, 15),
        dismissedIds: [],
      );
      for (final s in signals) {
        expect(
          s.expiresAt.isAfter(DateTime(2026, 12, 15)),
          isTrue,
          reason: '${s.id} should not be expired',
        );
      }
    });
  });

  // ── Zero Async ──────────────────────────────────────────

  group('purity constraints (ANT-08)', () {
    test('evaluate returns synchronously (not Future)', () {
      final List<AnticipationSignal> result = AnticipationEngine.evaluate(
        profile: _profile(),
        facts: [],
        now: DateTime(2026, 6, 15),
        dismissedIds: [],
      );
      expect(result, isA<List<AnticipationSignal>>());
    });
  });
}
