import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/pulse_hero_engine.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Tests for PulseHeroEngine (Sprint S49).
///
/// Validates priority system (critical > focus > fallback),
/// legacy stress mapping, and age-based fallback.
void main() {
  /// Helper to build a minimal CoachProfile for testing.
  CoachProfile profile0({
    int birthYear = 1980,
    double salaireBrutMensuel = 8000,
    String employmentStatus = 'salarie',
    String? primaryFocus,
    PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
    DetteProfile dettes = const DetteProfile(),
    PatrimoineProfile patrimoine = const PatrimoineProfile(),
    ConjointProfile? conjoint,
    String canton = 'VD',
    int? arrivalAge,
    String? nationality,
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaireBrutMensuel,
      employmentStatus: employmentStatus,
      primaryFocus: primaryFocus,
      prevoyance: prevoyance,
      dettes: dettes,
      patrimoine: patrimoine,
      conjoint: conjoint,
      arrivalAge: arrivalAge,
      nationality: nationality,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2045),
        label: 'Retraite',
      ),
    );
  }

  group('PulseHeroEngine — priority 0: no focus', () {
    test('returns null when primaryFocus is null (show FocusSelector)', () {
      final profile = profile0(primaryFocus: null);
      final hero = PulseHeroEngine.compute(profile);
      expect(hero, isNull);
    });

    test('returns null when primaryFocus is empty string', () {
      final profile = profile0(primaryFocus: '');
      final hero = PulseHeroEngine.compute(profile);
      expect(hero, isNull);
    });
  });

  group('PulseHeroEngine — priority 1: critical alerts', () {
    test('independent with zero LPP triggers critical alert', () {
      final profile = profile0(
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
        primaryFocus: 'proteger_retraite',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.title, 'CHF 0');
      expect(hero.color, MintColors.error);
      expect(hero.ctaRoute, '/independants/lpp-volontaire');
    });

    test('independent with null LPP triggers critical alert', () {
      final profile = profile0(
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: null),
        primaryFocus: 'proteger_retraite',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.title, 'CHF 0');
    });

    test('debt > 10k triggers critical alert over focus', () {
      final profile = profile0(
        dettes: const DetteProfile(creditConsommation: 15000),
        primaryFocus: 'optimiser_fiscal',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/debt/repayment');
      expect(hero.color, MintColors.error);
    });

    test('debt <= 10k does NOT trigger critical alert', () {
      final profile = profile0(
        dettes: const DetteProfile(creditConsommation: 5000),
        primaryFocus: 'optimiser_fiscal',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      // Should fall through to focus-based, not debt alert
      expect(hero!.ctaRoute, isNot('/debt/repayment'));
    });

    test('independant critical alert overrides debt alert', () {
      final profile = profile0(
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
        dettes: const DetteProfile(creditConsommation: 20000),
        primaryFocus: 'proteger_retraite',
      );

      final hero = PulseHeroEngine.compute(profile);

      // Independent with zero LPP is checked first
      expect(hero, isNotNull);
      expect(hero!.title, 'CHF 0');
    });
  });

  group('PulseHeroEngine — priority 2: focus-based', () {
    test('proteger_retraite for age > 55 shows Capital vs Rente', () {
      final profile = profile0(
        birthYear: 1968, // ~58 years old
        primaryFocus: 'proteger_retraite',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.title, contains('Capital'));
      expect(hero.ctaRoute, '/rente-vs-capital');
    });

    test('proteger_retraite for age <= 55 shows replacement rate', () {
      final profile = profile0(
        birthYear: 1985, // ~41 years old
        primaryFocus: 'proteger_retraite',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.subtitle, contains('retraite'));
      expect(hero.ctaRoute, '/retraite');
    });

    test('comprendre_salaire shows deduction amount', () {
      final profile = profile0(
        salaireBrutMensuel: 8000,
        primaryFocus: 'comprendre_salaire',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.title, contains('CHF'));
      expect(hero.ctaRoute, '/profile/bilan');
    });

    test('optimiser_fiscal shows tax saving estimate', () {
      final profile = profile0(primaryFocus: 'optimiser_fiscal');

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.title, contains('CHF'));
      expect(hero.ctaRoute, '/tools');
    });

    test('naviguer_achat with salary shows capacity estimate', () {
      final profile = profile0(
        salaireBrutMensuel: 8000,
        primaryFocus: 'naviguer_achat',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.title, contains('CHF'));
      expect(hero.title, contains('k'));
      expect(hero.ctaRoute, '/hypotheque');
    });

    test('naviguer_achat without salary shows generic message', () {
      final profile = profile0(
        salaireBrutMensuel: 0,
        primaryFocus: 'naviguer_achat',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/hypotheque');
    });

    test('naviguer_expat with arrivalAge shows gap years', () {
      final profile = profile0(
        primaryFocus: 'naviguer_expat',
        arrivalAge: 30,
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      // 30 - 20 = 10 gap years
      expect(hero!.title, contains('10'));
      expect(hero.subtitle, contains('cotisations'));
    });

    test('naviguer_expat without arrivalAge shows generic', () {
      final profile = profile0(
        primaryFocus: 'naviguer_expat',
        arrivalAge: null,
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.title, contains('Nouveau'));
    });

    test('proteger_famille shows conjoint name', () {
      final profile = profile0(
        primaryFocus: 'proteger_famille',
        conjoint: const ConjointProfile(firstName: 'Lauren'),
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.title, contains('Lauren'));
    });

    test('proteger_urgence with debt shows debt amount', () {
      final profile = profile0(
        primaryFocus: 'proteger_urgence',
        dettes: const DetteProfile(creditConsommation: 5000),
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/debt/repayment');
    });

    test('proteger_urgence without debt shows safety net', () {
      final profile = profile0(
        primaryFocus: 'proteger_urgence',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/invalidite');
    });
  });

  group('PulseHeroEngine — legacy stress mapping', () {
    test('stress_retraite maps to proteger_retraite', () {
      final profile = profile0(
        birthYear: 1985,
        primaryFocus: 'stress_retraite',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/retraite');
    });

    test('stress_impots maps to optimiser_fiscal', () {
      final profile = profile0(primaryFocus: 'stress_impots');

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/tools');
    });

    test('stress_budget maps to comprendre_salaire', () {
      final profile = profile0(primaryFocus: 'stress_budget');

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/profile/bilan');
    });

    test('unknown focus falls through to age-based fallback', () {
      final profile = profile0(
        birthYear: 2000, // ~26 years old
        primaryFocus: 'stress_general',
      );

      final hero = PulseHeroEngine.compute(profile);

      // Age < 28 → comprendre_salaire
      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/profile/bilan');
    });
  });

  group('PulseHeroEngine — priority 3: fallback by age', () {
    test('age < 28 falls back to comprendre_salaire', () {
      final profile = profile0(
        birthYear: 2001, // ~25 years old
        primaryFocus: 'unknown_focus',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/profile/bilan');
    });

    test('age 28-34 falls back to naviguer_achat', () {
      final profile = profile0(
        birthYear: 1994, // ~32 years old
        primaryFocus: 'unknown_focus',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/hypotheque');
    });

    test('age 35-44 falls back to optimiser_fiscal', () {
      final profile = profile0(
        birthYear: 1986, // ~40 years old
        primaryFocus: 'unknown_focus',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/tools');
    });

    test('age 45-54 falls back to proteger_retraite', () {
      final profile = profile0(
        birthYear: 1976, // ~50 years old
        primaryFocus: 'unknown_focus',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/retraite');
    });

    test('age >= 55 falls back to capital vs rente', () {
      final profile = profile0(
        birthYear: 1966, // ~60 years old
        primaryFocus: 'unknown_focus',
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.ctaRoute, '/rente-vs-capital');
    });
  });

  group('PulseHeroEngine — output structure', () {
    test('every hero has required fields', () {
      final profile = profile0(primaryFocus: 'comprendre_systeme');

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      expect(hero!.title.isNotEmpty, true);
      expect(hero.subtitle.isNotEmpty, true);
      expect(hero.ctaLabel.isNotEmpty, true);
      expect(hero.ctaRoute.startsWith('/'), true);
      expect(hero.icon, isA<IconData>());
      expect(hero.color, isA<Color>());
    });

    test('optimiser_patrimoine shows total patrimoine', () {
      final profile = profile0(
        primaryFocus: 'optimiser_patrimoine',
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 50000,
          investissements: 100000,
        ),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
          totalEpargne3a: 30000,
        ),
      );

      final hero = PulseHeroEngine.compute(profile);

      expect(hero, isNotNull);
      // 50k + 100k + 200k + 30k = 380k
      expect(hero!.title, contains('380k'));
    });
  });
}
