// test/services/navigation/readiness_gate_custom_gates_test.dart
//
// Unit tests for the 5 fine-grained Swiss-critical custom gates.
//
// Coverage:
//   gateInvalidite         — /invalidite
//   gateRachatLppDeep      — /lpp-deep/rachat
//   gateFrontalier         — /segments/frontalier
//   gateBudgetSousTension  — /debt/ratio
//   gateRenteVsCapital     — /rente-vs-capital
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

GoalA _goal() => GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042),
      label: 'Retraite',
    );

/// Empty profile — no salary, no canton, no employmentStatus override.
CoachProfile _emptyProfile() => CoachProfile(
      birthYear: 1985,
      canton: '',
      salaireBrutMensuel: 0,
      goalA: _goal(),
    );

/// Golden couple — Julien (swiss_native, salarie, all LPP data).
CoachProfile _julienProfile() => CoachProfile(
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
      depenses: const DepensesProfile(loyer: 2200, assuranceMaladie: 320),
      goalA: _goal(),
    );

/// Golden couple — Lauren (expat_us, salarie, LPP data).
CoachProfile _laurenProfile() => CoachProfile(
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
      depenses: const DepensesProfile(loyer: 1800, assuranceMaladie: 280),
      goalA: _goal(),
    );

/// Partial profile — salary + canton + age but no LPP data.
CoachProfile _partialProfile() => CoachProfile(
      birthYear: 1980,
      canton: 'BE',
      salaireBrutMensuel: 6000,
      employmentStatus: 'salarie',
      goalA: _goal(),
    );

/// Independent profile — no LPP.
CoachProfile _independantProfile() => CoachProfile(
      birthYear: 1978,
      canton: 'GE',
      salaireBrutMensuel: 8500,
      employmentStatus: 'independant',
      goalA: _goal(),
    );

/// Frontalier profile — permis G.
CoachProfile _frontalierPermitGProfile() => CoachProfile(
      birthYear: 1985,
      canton: 'GE',
      salaireBrutMensuel: 7000,
      employmentStatus: 'salarie',
      residencePermit: 'G',
      goalA: _goal(),
    );

/// Frontalier profile — employmentStatus 'frontalier'.
CoachProfile _frontalierStatusProfile() => CoachProfile(
      birthYear: 1985,
      canton: 'GE',
      salaireBrutMensuel: 7000,
      employmentStatus: 'frontalier',
      goalA: _goal(),
    );

/// Profile with income but no charges.
CoachProfile _incomeNoChargesProfile() => CoachProfile(
      birthYear: 1980,
      canton: 'ZH',
      salaireBrutMensuel: 5000,
      employmentStatus: 'salarie',
      goalA: _goal(),
    );

/// Profile with income AND charges.
CoachProfile _incomeWithChargesProfile() => CoachProfile(
      birthYear: 1980,
      canton: 'ZH',
      salaireBrutMensuel: 5000,
      employmentStatus: 'salarie',
      depenses: const DepensesProfile(loyer: 1500, assuranceMaladie: 300),
      goalA: _goal(),
    );

/// Profile with salary and age but no LPP.
CoachProfile _salaryAgeNoLppProfile() => CoachProfile(
      birthYear: 1975,
      canton: 'ZH',
      salaireBrutMensuel: 7200,
      employmentStatus: 'salarie',
      goalA: _goal(),
    );

/// Profile with salary, age, and only avoirLpp (no rachatMaximum).
CoachProfile _salaryAgeOnlyAvoirProfile() => CoachProfile(
      birthYear: 1975,
      canton: 'ZH',
      salaireBrutMensuel: 7200,
      employmentStatus: 'salarie',
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 80000,
        // rachatMaximum deliberately absent
      ),
      goalA: _goal(),
    );

// ════════════════════════════════════════════════════════════════
//  TESTS
// ════════════════════════════════════════════════════════════════

void main() {
  // ── gateInvalidite (/invalidite) ─────────────────────────────

  group('gateInvalidite — /invalidite', () {
    late ScreenEntry entry;

    setUpAll(() {
      entry = MintScreenRegistry.findByIntentStatic('disability_gap')!;
    });

    test('Julien (salarie + salary) → ready', () {
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, ReadinessLevel.ready);
    });

    test('Lauren (salarie + salary) → ready', () {
      final result = ReadinessGate.check(entry, _laurenProfile());
      expect(result.level, ReadinessLevel.ready);
    });

    test('empty profile (default salarie employment, no salary) → blocked on '
        'salaireBrut only (employment defaults to "salarie")', () {
      final result = ReadinessGate.check(entry, _emptyProfile());
      expect(result.level, ReadinessLevel.blocked);
      // employmentStatus defaults to 'salarie' so only salary is missing
      expect(result.missingCritical, contains('salaireBrut'));
    });

    test('profile with employment but no salary → blocked on salaireBrut', () {
      final profile = CoachProfile(
        birthYear: 1980,
        canton: 'ZH',
        salaireBrutMensuel: 0,
        employmentStatus: 'salarie',
        goalA: _goal(),
      );
      final result = ReadinessGate.check(entry, profile);
      expect(result.level, ReadinessLevel.blocked);
      expect(result.missingCritical, contains('salaireBrut'));
      expect(result.missingCritical, isNot(contains('employmentStatus')));
    });

    test('independent (independant) + salary → ready (route stays ready, '
        'RoutePlanner handles archetype redirect externally)', () {
      final result = ReadinessGate.check(entry, _independantProfile());
      expect(result.level, ReadinessLevel.ready);
    });

    test('profile with salary but no employment → blocked on employmentStatus',
        () {
      final profile = CoachProfile(
        birthYear: 1980,
        canton: 'ZH',
        salaireBrutMensuel: 6000,
        employmentStatus: '',
        goalA: _goal(),
      );
      final result = ReadinessGate.check(entry, profile);
      expect(result.level, ReadinessLevel.blocked);
      expect(result.missingCritical, contains('employmentStatus'));
    });

    test('customGate is wired (entry has non-null customGate)', () {
      expect(entry.customGate, isNotNull);
    });
  });

  // ── gateRachatLppDeep (/lpp-deep/rachat) ─────────────────────

  group('gateRachatLppDeep — /lpp-deep/rachat', () {
    late ScreenEntry entry;

    setUpAll(() {
      entry = MintScreenRegistry.findByIntentStatic('lpp_deep_rachat')!;
    });

    test('entry is registered', () {
      expect(entry, isNotNull);
      expect(entry.route, '/lpp-deep/rachat');
      expect(entry.fallbackRoute, '/scan');
    });

    test('Julien (avoir + rachat present) → ready', () {
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, ReadinessLevel.ready);
    });

    test('Lauren (avoir + rachat present) → ready', () {
      final result = ReadinessGate.check(entry, _laurenProfile());
      expect(result.level, ReadinessLevel.ready);
    });

    test('empty profile (no LPP at all) → blocked with scan suggestion', () {
      final result = ReadinessGate.check(entry, _emptyProfile());
      expect(result.level, ReadinessLevel.blocked);
      expect(result.missingCritical,
          containsAll(['avoirLpp', 'rachatMaximum']));
    });

    test('partial profile (no LPP data) → blocked', () {
      final result = ReadinessGate.check(entry, _partialProfile());
      expect(result.level, ReadinessLevel.blocked);
    });

    test('only avoir (no rachatMaximum) → partial', () {
      final result = ReadinessGate.check(entry, _salaryAgeOnlyAvoirProfile());
      expect(result.level, ReadinessLevel.partial);
      expect(result.missingFields, contains('rachatMaximum'));
      expect(result.missingCritical, isEmpty);
    });

    test('only rachatMaximum (no avoir) → partial', () {
      final profile = CoachProfile(
        birthYear: 1975,
        canton: 'ZH',
        salaireBrutMensuel: 7200,
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          // avoirLppTotal deliberately absent
          rachatMaximum: 120000,
        ),
        goalA: _goal(),
      );
      final result = ReadinessGate.check(entry, profile);
      expect(result.level, ReadinessLevel.partial);
      expect(result.missingFields, contains('avoirLpp'));
    });

    test('customGate is wired', () {
      expect(entry.customGate, isNotNull);
    });
  });

  // ── gateFrontalier (/segments/frontalier) ─────────────────────

  group('gateFrontalier — /segments/frontalier', () {
    late ScreenEntry entry;

    setUpAll(() {
      entry = MintScreenRegistry.findByIntentStatic('cross_border')!;
    });

    test('permis G → ready', () {
      final result = ReadinessGate.check(entry, _frontalierPermitGProfile());
      expect(result.level, ReadinessLevel.ready);
    });

    test('employmentStatus=frontalier → ready', () {
      final result = ReadinessGate.check(entry, _frontalierStatusProfile());
      expect(result.level, ReadinessLevel.ready);
    });

    test('Julien (swiss_native, salarie) → blocked (not a frontalier)', () {
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, ReadinessLevel.blocked);
    });

    test('Lauren (expat_us, salarie) → blocked (not a frontalier)', () {
      final result = ReadinessGate.check(entry, _laurenProfile());
      expect(result.level, ReadinessLevel.blocked);
    });

    test('empty profile (no permit, default employment) → blocked', () {
      final result = ReadinessGate.check(entry, _emptyProfile());
      expect(result.level, ReadinessLevel.blocked);
    });

    test('independant (no permis G) → blocked', () {
      final result = ReadinessGate.check(entry, _independantProfile());
      expect(result.level, ReadinessLevel.blocked);
    });

    test('missingCritical contains employmentStatus when blocked', () {
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.missingCritical, contains('employmentStatus'));
    });

    test('customGate is wired', () {
      expect(entry.customGate, isNotNull);
    });
  });

  // ── gateBudgetSousTension (/debt/ratio) ───────────────────────

  group('gateBudgetSousTension — /debt/ratio', () {
    late ScreenEntry entry;

    setUpAll(() {
      entry = MintScreenRegistry.findByIntentStatic('debt_ratio')!;
    });

    test('Julien (income + charges) → ready', () {
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, ReadinessLevel.ready);
    });

    test('Lauren (income + charges) → ready', () {
      final result = ReadinessGate.check(entry, _laurenProfile());
      expect(result.level, ReadinessLevel.ready);
    });

    test('empty profile (no income) → blocked', () {
      final result = ReadinessGate.check(entry, _emptyProfile());
      expect(result.level, ReadinessLevel.blocked);
      expect(result.missingCritical, contains('netIncome'));
    });

    test('income present but no charges → partial (enrichment CTA)', () {
      final result = ReadinessGate.check(entry, _incomeNoChargesProfile());
      expect(result.level, ReadinessLevel.partial);
      expect(result.missingFields, contains('totalCharges'));
      expect(result.missingCritical, isEmpty);
    });

    test('income + charges present → ready', () {
      final result = ReadinessGate.check(entry, _incomeWithChargesProfile());
      expect(result.level, ReadinessLevel.ready);
    });

    test('partial profile (salary but no depenses) → partial', () {
      final result = ReadinessGate.check(entry, _partialProfile());
      expect(result.level, ReadinessLevel.partial);
    });

    test('customGate is wired', () {
      expect(entry.customGate, isNotNull);
    });
  });

  // ── gateRenteVsCapital (/rente-vs-capital) ───────────────────

  group('gateRenteVsCapital — /rente-vs-capital', () {
    late ScreenEntry entry;

    setUpAll(() {
      entry = MintScreenRegistry.findByIntentStatic('retirement_choice')!;
    });

    test('Julien (salary + age + LPP data) → ready', () {
      final result = ReadinessGate.check(entry, _julienProfile());
      expect(result.level, ReadinessLevel.ready);
    });

    test('Lauren (salary + age + LPP data) → ready', () {
      final result = ReadinessGate.check(entry, _laurenProfile());
      expect(result.level, ReadinessLevel.ready);
    });

    test('empty profile (no salary) → blocked on salaireBrut '
        '(gate early-exits on salary before checking age)', () {
      final result = ReadinessGate.check(entry, _emptyProfile());
      expect(result.level, ReadinessLevel.blocked);
      // Gate short-circuits on missing salary: only salaireBrut in critical
      expect(result.missingCritical, contains('salaireBrut'));
    });

    test('salary present but age=0 → blocked on age', () {
      final profile = CoachProfile(
        birthYear: DateTime.now().year, // age = 0
        canton: 'ZH',
        salaireBrutMensuel: 6000,
        goalA: _goal(),
      );
      final result = ReadinessGate.check(entry, profile);
      expect(result.level, ReadinessLevel.blocked);
      expect(result.missingCritical, contains('age'));
    });

    test('salary present, age ok, no LPP at all → partial (salary-derived '
        'estimation mode)', () {
      final result = ReadinessGate.check(entry, _salaryAgeNoLppProfile());
      expect(result.level, ReadinessLevel.partial);
      expect(result.missingFields, containsAll(['avoirLpp', 'rachatMaximum']));
      expect(result.missingCritical, isEmpty);
    });

    test('salary + age + only avoir (no rachat) → partial (low quality)', () {
      final result =
          ReadinessGate.check(entry, _salaryAgeOnlyAvoirProfile());
      expect(result.level, ReadinessLevel.partial);
      expect(result.missingFields, contains('rachatMaximum'));
      expect(result.missingCritical, isEmpty);
    });

    test('salary only, no age in constructor (empty canton too) → blocked', () {
      final profile = _emptyProfile();
      final result = ReadinessGate.check(entry, profile);
      expect(result.level, ReadinessLevel.blocked);
    });

    test('partial profile (salary + age, no LPP) → partial not blocked', () {
      final result = ReadinessGate.check(entry, _partialProfile());
      expect(result.level, ReadinessLevel.partial);
      expect(result.missingCritical, isEmpty);
    });

    test('customGate is wired', () {
      expect(entry.customGate, isNotNull);
    });
  });

  // ── Registry integrity ────────────────────────────────────────

  group('Registry integrity after custom gate additions', () {
    test('lpp_deep_rachat is in the entries list', () {
      final entry =
          MintScreenRegistry.findByIntentStatic('lpp_deep_rachat');
      expect(entry, isNotNull);
      expect(entry!.route, '/lpp-deep/rachat');
    });

    test('all 5 custom-gate entries have non-null customGate', () {
      const customGateIntents = {
        'disability_gap',
        'lpp_deep_rachat',
        'cross_border',
        'debt_ratio',
        'retirement_choice',
      };
      for (final intent in customGateIntents) {
        final entry = MintScreenRegistry.findByIntentStatic(intent);
        expect(entry, isNotNull, reason: 'Entry $intent not found');
        expect(entry!.customGate, isNotNull,
            reason: 'customGate null on $intent');
      }
    });

    test('non-custom-gate entries have null customGate', () {
      const plainEntries = [
        'retirement_projection',
        'simulator_3a',
        'housing_purchase',
        'life_event_birth',
        'lamal_franchise',
      ];
      for (final intent in plainEntries) {
        final entry = MintScreenRegistry.findByIntentStatic(intent);
        expect(entry, isNotNull, reason: 'Entry $intent not found');
        expect(entry!.customGate, isNull,
            reason: 'customGate unexpectedly set on $intent');
      }
    });

    test('findByRoute works for /lpp-deep/rachat', () {
      final entry =
          MintScreenRegistry.findByRouteStatic('/lpp-deep/rachat');
      expect(entry, isNotNull);
      expect(entry!.intentTag, 'lpp_deep_rachat');
    });
  });
}
