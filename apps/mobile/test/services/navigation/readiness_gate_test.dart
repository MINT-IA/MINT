// test/services/navigation/readiness_gate_test.dart
//
// Unit tests for ReadinessGate.check() and ReadinessResult.
// See docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §5
//
// Golden couple (CLAUDE.md §8):
//   Julien: birthYear=1977, salaireBrut=122207 CHF/an, canton=VS, swiss_native
//   Lauren: birthYear=1982, salaireBrut=67000  CHF/an, canton=VS, expat_us

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/navigation/readiness_gate.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';

// ════════════════════════════════════════════════════════════════
//  HELPERS — build test profiles
// ════════════════════════════════════════════════════════════════

/// Empty profile — only required constructor fields.
CoachProfile _emptyProfile() {
  return CoachProfile(
    birthYear: 1985,
    canton: '',
    salaireBrutMensuel: 0,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
  );
}

/// Minimal profile — age + canton but no salary.
CoachProfile _agePlusCantonOnly() {
  return CoachProfile(
    birthYear: 1980,
    canton: 'ZH',
    salaireBrutMensuel: 0,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045),
      label: 'Retraite',
    ),
  );
}

/// Partial profile — age + canton + salary, no LPP / 3a data.
CoachProfile _partialProfile() {
  return CoachProfile(
    birthYear: 1980,
    canton: 'BE',
    salaireBrutMensuel: 6000,
    employmentStatus: 'salarie',
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045),
      label: 'Retraite',
    ),
  );
}

/// Full profile — all commonly required fields populated.
CoachProfile _fullProfile() {
  return CoachProfile(
    birthYear: 1978,
    canton: 'GE',
    salaireBrutMensuel: 9000,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.marie,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 120000,
      rachatMaximum: 80000,
      totalEpargne3a: 32000,
      tauxConversion: 0.068,
    ),
    patrimoine: const PatrimoineProfile(epargneLiquide: 30000),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2043),
      label: 'Retraite',
    ),
  );
}

/// Golden couple — Julien (CLAUDE.md §8).
CoachProfile _julienProfile() {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    nationality: 'CH',
    salaireBrutMensuel: 122207 / 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.marie,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 70377,
      rachatMaximum: 539414,
      totalEpargne3a: 32000,
      tauxConversion: 0.068,
    ),
    patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042),
      label: 'Retraite',
    ),
  );
}

/// Golden couple — Lauren (CLAUDE.md §8).
CoachProfile _laurenProfile() {
  return CoachProfile(
    birthYear: 1982,
    canton: 'VS',
    nationality: 'US',
    salaireBrutMensuel: 67000 / 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.marie,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 19620,
      rachatMaximum: 52949,
      totalEpargne3a: 14000,
      tauxConversion: 0.068,
    ),
    patrimoine: const PatrimoineProfile(epargneLiquide: 20000),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2047),
      label: 'Retraite',
    ),
  );
}

// ════════════════════════════════════════════════════════════════
//  HELPERS — build test screen entries
// ════════════════════════════════════════════════════════════════

ScreenEntry _entryRequiring(List<String> fields) {
  return ScreenEntry(
    route: '/test',
    intentTag: 'test_intent',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: fields,
  );
}

// ════════════════════════════════════════════════════════════════
//  TESTS
// ════════════════════════════════════════════════════════════════

void main() {
  const gate = ReadinessGate();

  // ── ReadinessResult constructors ──────────────────────────────

  group('ReadinessResult constructors', () {
    test('ready() has level=ready and empty lists', () {
      const r = ReadinessResult.ready();
      expect(r.level, ReadinessLevel.ready);
      expect(r.missingFields, isEmpty);
      expect(r.missingCritical, isEmpty);
    });

    test('partial() has level=partial, missing fields, empty critical', () {
      const r = ReadinessResult.partial(['avoirLpp']);
      expect(r.level, ReadinessLevel.partial);
      expect(r.missingFields, equals(['avoirLpp']));
      expect(r.missingCritical, isEmpty);
    });

    test('blocked() has level=blocked and both missing lists', () {
      final r =
          ReadinessResult.blocked(['salaireBrut', 'age'], ['salaireBrut']);
      expect(r.level, ReadinessLevel.blocked);
      expect(r.missingFields, containsAll(['salaireBrut', 'age']));
      expect(r.missingCritical, equals(['salaireBrut']));
    });

    test('toString includes level and lists', () {
      const r = ReadinessResult.partial(['canton']);
      expect(r.toString(), contains('partial'));
      expect(r.toString(), contains('canton'));
    });
  });

  // ── No required fields → always ready ────────────────────────

  group('No required fields', () {
    const entry = ScreenEntry(
      route: '/naissance',
      intentTag: 'life_event_birth',
      behavior: ScreenBehavior.roadmapFlow,
    );

    test('empty profile → ready (no fields needed)', () {
      final result = gate.evaluate(entry, _emptyProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('full profile → ready', () {
      final result = gate.evaluate(entry, _fullProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('static check() matches evaluate()', () {
      final r1 = ReadinessGate.check(entry, _emptyProfile());
      final r2 = gate.evaluate(entry, _emptyProfile());
      expect(r1.level, equals(r2.level));
    });
  });

  // ── Field: salaireBrut / netIncome ────────────────────────────

  group('Field: salaireBrut', () {
    test('salaireBrutMensuel=0 → missing (blocked)', () {
      final result =
          gate.evaluate(_entryRequiring(['salaireBrut']), _emptyProfile());
      expect(result.level, equals(ReadinessLevel.blocked));
      expect(result.missingFields, contains('salaireBrut'));
      expect(result.missingCritical, contains('salaireBrut'));
    });

    test('salaireBrutMensuel > 0 → present (ready)', () {
      final result =
          gate.evaluate(_entryRequiring(['salaireBrut']), _partialProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('netIncome key uses salaireBrut as proxy', () {
      final result =
          gate.evaluate(_entryRequiring(['netIncome']), _partialProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('netIncome missing on empty profile → blocked', () {
      final result =
          gate.evaluate(_entryRequiring(['netIncome']), _emptyProfile());
      expect(result.level, equals(ReadinessLevel.blocked));
    });
  });

  // ── Field: age ────────────────────────────────────────────────

  group('Field: age', () {
    test('birthYear set → age > 0 → present', () {
      final result =
          gate.evaluate(_entryRequiring(['age']), _partialProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('age is a critical field → blocked when missing', () {
      // Create profile with birthYear=0 which would give age ≤ 0
      final profile = CoachProfile(
        birthYear: DateTime.now().year, // age = 0 or negative
        canton: 'ZH',
        salaireBrutMensuel: 0,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );
      final result = gate.evaluate(_entryRequiring(['age']), profile);
      // age == 0 means absent → blocked
      expect(result.level, equals(ReadinessLevel.blocked));
    });
  });

  // ── Field: canton ─────────────────────────────────────────────

  group('Field: canton', () {
    test('canton non-empty → present', () {
      final result =
          gate.evaluate(_entryRequiring(['canton']), _partialProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('canton empty string → missing (blocked)', () {
      final result =
          gate.evaluate(_entryRequiring(['canton']), _emptyProfile());
      expect(result.level, equals(ReadinessLevel.blocked));
    });
  });

  // ── Field: employmentStatus ───────────────────────────────────

  group('Field: employmentStatus', () {
    test('employmentStatus set → present', () {
      final result = gate.evaluate(
        _entryRequiring(['employmentStatus']),
        _partialProfile(),
      );
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('employmentStatus default ("salarie") counts as present', () {
      // CoachProfile default is 'salarie'
      final result = gate.evaluate(
        _entryRequiring(['employmentStatus']),
        _julienProfile(),
      );
      expect(result.level, equals(ReadinessLevel.ready));
    });
  });

  // ── Field: avoirLpp ───────────────────────────────────────────

  group('Field: avoirLpp (non-critical)', () {
    test('avoirLpp missing → partial (not blocked)', () {
      // partialProfile has no LPP data
      final entry = ScreenEntry(
        route: '/rente-vs-capital',
        intentTag: 'retirement_choice',
        behavior: ScreenBehavior.decisionCanvas,
        requiredFields: ['avoirLpp'],
      );
      final result = gate.evaluate(entry, _partialProfile());
      expect(result.level, equals(ReadinessLevel.partial));
      expect(result.missingCritical, isEmpty);
    });

    test('avoirLpp present → ready', () {
      final result =
          gate.evaluate(_entryRequiring(['avoirLpp']), _fullProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });
  });

  // ── Multiple fields — mixed critical / non-critical ───────────

  group('Multiple fields — mixed criticality', () {
    test('all critical missing → blocked', () {
      final entry = _entryRequiring(['salaireBrut', 'age', 'canton']);
      final result = gate.evaluate(entry, _emptyProfile());
      expect(result.level, equals(ReadinessLevel.blocked));
      expect(result.missingCritical, isNotEmpty);
    });

    test('critical present, non-critical missing → partial', () {
      // partialProfile has salaireBrut + canton + age, but no avoirLpp
      final entry = ScreenEntry(
        route: '/rente-vs-capital',
        intentTag: 'retirement_choice',
        behavior: ScreenBehavior.decisionCanvas,
        requiredFields: ['salaireBrut', 'avoirLpp'],
      );
      final result = gate.evaluate(entry, _partialProfile());
      // salaireBrut present, avoirLpp missing → partial (non-critical)
      expect(result.level, equals(ReadinessLevel.partial));
      expect(result.missingFields, contains('avoirLpp'));
      expect(result.missingCritical, isEmpty);
    });

    test('all fields present → ready with empty missing lists', () {
      final entry =
          _entryRequiring(['salaireBrut', 'age', 'canton', 'employmentStatus']);
      final result = gate.evaluate(entry, _partialProfile());
      expect(result.level, equals(ReadinessLevel.ready));
      expect(result.missingFields, isEmpty);
      expect(result.missingCritical, isEmpty);
    });
  });

  // ── Partial profile: age + canton but no salary ───────────────

  group('Partial profile: age + canton only', () {
    test('entry requiring only age + canton → ready', () {
      final result = gate.evaluate(
        _entryRequiring(['age', 'canton']),
        _agePlusCantonOnly(),
      );
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('entry requiring salary → blocked', () {
      final result = gate.evaluate(
        _entryRequiring(['salaireBrut']),
        _agePlusCantonOnly(),
      );
      expect(result.level, equals(ReadinessLevel.blocked));
    });

    test('rente-vs-capital (salary + age) → blocked (no salary)', () {
      final entry = ScreenEntry(
        route: '/rente-vs-capital',
        intentTag: 'retirement_choice',
        behavior: ScreenBehavior.decisionCanvas,
        requiredFields: ['salaireBrut', 'age'],
      );
      final result = gate.evaluate(entry, _agePlusCantonOnly());
      expect(result.level, equals(ReadinessLevel.blocked));
      expect(result.missingCritical, contains('salaireBrut'));
    });

    test('tax_optimization_3a (age + canton) → ready', () {
      final entry = ScreenEntry(
        route: '/3a-deep/staggered-withdrawal',
        intentTag: 'tax_optimization_3a',
        behavior: ScreenBehavior.decisionCanvas,
        requiredFields: ['age', 'canton'],
      );
      final result = gate.evaluate(entry, _agePlusCantonOnly());
      expect(result.level, equals(ReadinessLevel.ready));
    });
  });

  // ── Golden couple — Julien ────────────────────────────────────

  group('Golden couple — Julien (49, VS, 122207 CHF/an)', () {
    test('retirement_choice (salaireBrut + age) → ready', () {
      final entry = MintScreenRegistry.findByIntentStatic('retirement_choice')!;
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('retirement_projection (salaireBrut + age + canton) → ready', () {
      final entry =
          MintScreenRegistry.findByIntentStatic('retirement_projection')!;
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('tax_optimization_3a (age + canton) → ready', () {
      final entry =
          MintScreenRegistry.findByIntentStatic('tax_optimization_3a')!;
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('housing_purchase (salaireBrut + canton) → ready', () {
      final entry =
          MintScreenRegistry.findByIntentStatic('housing_purchase')!;
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('disability_gap (employmentStatus) → ready', () {
      final entry = MintScreenRegistry.findByIntentStatic('disability_gap')!;
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('cantonal_fiscal_comparator (canton + netIncome) → ready', () {
      final entry =
          MintScreenRegistry.findByIntentStatic('cantonal_fiscal_comparator')!;
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('lpp_buyback (salaireBrut + age + canton) → ready', () {
      final entry = MintScreenRegistry.findByIntentStatic('lpp_buyback')!;
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('life_event_birth (no required fields) → ready', () {
      final entry = MintScreenRegistry.findByIntentStatic('life_event_birth')!;
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('life_event_divorce (civilStatus) → ready (Julien is marie)', () {
      final entry =
          MintScreenRegistry.findByIntentStatic('life_event_divorce')!;
      final result = ReadinessGate.check(entry, _julienProfile());
      // civilStatus is always present (non-null enum) → ready
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('simulator_3a (salaireBrut + canton) → ready', () {
      final entry = MintScreenRegistry.findByIntentStatic('simulator_3a')!;
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('withdrawal_sequencing (salaireBrut + age + canton) → ready', () {
      final entry =
          MintScreenRegistry.findByIntentStatic('withdrawal_sequencing')!;
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });
  });

  // ── Golden couple — Lauren ────────────────────────────────────

  group('Golden couple — Lauren (43, VS, 67000 CHF/an, expat_us)', () {
    test('retirement_choice → ready', () {
      final entry = MintScreenRegistry.findByIntentStatic('retirement_choice')!;
      final result = ReadinessGate.check(entry, _laurenProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('simulator_3a → ready (salary + canton)', () {
      final entry = MintScreenRegistry.findByIntentStatic('simulator_3a')!;
      final result = ReadinessGate.check(entry, _laurenProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('housing_purchase → ready (salary + canton)', () {
      final entry =
          MintScreenRegistry.findByIntentStatic('housing_purchase')!;
      final result = ReadinessGate.check(entry, _laurenProfile());
      expect(result.level, equals(ReadinessLevel.ready));
    });
  });

  // ── Empty profile → blocked for most screens ──────────────────

  group('Empty profile → blocked for screens with salary required', () {
    final emptyProfile = _emptyProfile();

    test('retirement_choice → blocked', () {
      final entry = MintScreenRegistry.findByIntentStatic('retirement_choice')!;
      final result = ReadinessGate.check(entry, emptyProfile);
      expect(result.level, equals(ReadinessLevel.blocked));
    });

    test('simulator_3a → blocked (no salary or canton)', () {
      final entry = MintScreenRegistry.findByIntentStatic('simulator_3a')!;
      final result = ReadinessGate.check(entry, emptyProfile);
      expect(result.level, equals(ReadinessLevel.blocked));
    });

    test('lamal_franchise (no required fields) → ready even for empty profile',
        () {
      final entry =
          MintScreenRegistry.findByIntentStatic('lamal_franchise')!;
      final result = ReadinessGate.check(entry, emptyProfile);
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('life_event_birth (no required fields) → ready even for empty profile',
        () {
      final entry = MintScreenRegistry.findByIntentStatic('life_event_birth')!;
      final result = ReadinessGate.check(entry, emptyProfile);
      expect(result.level, equals(ReadinessLevel.ready));
    });

    test('blocked result has non-empty missingCritical', () {
      final entry = MintScreenRegistry.findByIntentStatic('retirement_choice')!;
      final result = ReadinessGate.check(entry, emptyProfile);
      expect(result.missingCritical, isNotEmpty);
    });
  });

  // ── static check() API ────────────────────────────────────────

  group('ReadinessGate.check() static API', () {
    test('check() returns same result as evaluate()', () {
      final entry = MintScreenRegistry.findByIntentStatic('retirement_choice')!;
      final r1 = ReadinessGate.check(entry, _julienProfile());
      final r2 = const ReadinessGate().evaluate(entry, _julienProfile());
      expect(r1.level, equals(r2.level));
      expect(r1.missingFields, equals(r2.missingFields));
      expect(r1.missingCritical, equals(r2.missingCritical));
    });

    test('check() ready for full profile', () {
      final entry = MintScreenRegistry.findByIntentStatic('retirement_choice')!;
      final r = ReadinessGate.check(entry, _fullProfile());
      expect(r.level, equals(ReadinessLevel.ready));
    });

    test('check() blocked for empty profile + salary-required screen', () {
      final entry = MintScreenRegistry.findByIntentStatic('retirement_choice')!;
      final r = ReadinessGate.check(entry, _emptyProfile());
      expect(r.level, equals(ReadinessLevel.blocked));
    });
  });
}
