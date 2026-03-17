import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/precision/precision_service.dart';

// ═══════════════════════════════════════════════════════════════
//  PRECISION SERVICE — Unit tests
// ═══════════════════════════════════════════════════════════════
//
// Tests:
//   1. getFieldHelp returns help for known fields
//   2. getFieldHelp returns null for unknown field
//   3. allFieldHelps contains all 12 registered entries
//   4. crossValidate: no alerts on valid profile
//   5. crossValidate: LPP too low for age/salary
//   6. crossValidate: LPP obligatoire + surobligatoire mismatch
//   7. crossValidate: net/gross ratio too high
//   8. crossValidate: net/gross ratio too low
//   9. crossValidate: AVS years exceed age-based max
//  10. crossValidate: pillar 3a too high for age
//  11. crossValidate: 3a under 18 is an error
//  12. crossValidate: expenses exceed net salary
//  13. crossValidate: marginal tax rate > 50% warning
//  14. crossValidate: marginal tax rate < 5% warning
//  15. crossValidate: empty profile returns no alerts
//  16. smartDefaults: swiss_native archetype
//  17. smartDefaults: expat archetype (later AVS start)
//  18. smartDefaults: independent_no_lpp has lpp_total = 0
//  19. smartDefaults: low-tax canton gives higher net ratio
//  20. smartDefaults: all defaults have positive confidence
//  21. precisionPrompts: rente_vs_capital missing LPP obligatoire
//  22. precisionPrompts: retirement missing AVS years
//  23. precisionPrompts: tax optimization missing marginal rate
//  24. precisionPrompts: complete profile returns fewer prompts
//  25. precisionPrompts: budget context missing expenses
//  26. precisionPrompts: mortgage context missing mortgage
//  27. precisionPrompts: 3a context missing marginal rate
// ═══════════════════════════════════════════════════════════════

void main() {
  // ── 1. Field help ─────────────────────────────────────────────

  group('PrecisionService.getFieldHelp', () {
    test('returns help for known field lpp_total', () {
      final help = PrecisionService.getFieldHelp('lpp_total');
      expect(help, isNotNull);
      expect(help!.fieldName, 'lpp_total');
      expect(help.documentName, contains('LPP'));
      expect(help.germanName, contains('Altersguthaben'));
      expect(help.whereToFind, isNotEmpty);
    });

    test('returns help for salaire_brut with no fallback', () {
      final help = PrecisionService.getFieldHelp('salaire_brut');
      expect(help, isNotNull);
      expect(help!.fallbackEstimation, isNull);
    });

    test('returns null for unknown field', () {
      final help = PrecisionService.getFieldHelp('unknown_field_xyz');
      expect(help, isNull);
    });

    test('allFieldHelps contains all 12 registered entries', () {
      final all = PrecisionService.allFieldHelps;
      expect(all.length, 12);
      final names = all.map((h) => h.fieldName).toSet();
      expect(names, contains('lpp_total'));
      expect(names, contains('salaire_brut'));
      expect(names, contains('pillar_3a_balance'));
      expect(names, contains('mortgage_remaining'));
      expect(names, contains('replacement_ratio'));
      expect(names, contains('tax_saving_3a'));
    });
  });

  // ── 2. Cross-validation ───────────────────────────────────────

  group('PrecisionService.crossValidate', () {
    test('no alerts on valid profile', () {
      final profile = {
        'age': 45.0,
        'salaire_brut': 8000.0, // monthly
        'salaire_net': 6200.0,
        'lpp_total': 200000.0,
        'lpp_obligatoire': 120000.0,
        'lpp_surobligatoire': 80000.0,
        'avs_contribution_years': 25.0,
        'pillar_3a_balance': 80000.0,
        'monthly_expenses': 4500.0,
        'taux_marginal': 0.28,
      };
      final alerts = PrecisionService.crossValidate(profile);
      expect(alerts, isEmpty);
    });

    test('LPP too low for age and salary triggers warning', () {
      final profile = {
        'age': 50.0,
        'salaire_brut': 10000.0,
        'lpp_total': 5000.0, // way too low for 50 yo at 10k/mo
      };
      final alerts = PrecisionService.crossValidate(profile);
      final lppAlerts =
          alerts.where((a) => a.fieldName == 'lpp_total').toList();
      expect(lppAlerts, isNotEmpty);
      expect(lppAlerts.first.severity, 'warning');
      expect(lppAlerts.first.message, contains('bas'));
    });

    test('LPP too high for age and salary triggers warning', () {
      final profile = {
        'age': 30.0,
        'salaire_brut': 5000.0,
        'lpp_total': 2000000.0, // way too high for 30 yo at 5k/mo
      };
      final alerts = PrecisionService.crossValidate(profile);
      final lppAlerts =
          alerts.where((a) => a.fieldName == 'lpp_total').toList();
      expect(lppAlerts, isNotEmpty);
      expect(lppAlerts.first.severity, 'warning');
      expect(lppAlerts.first.message, contains('eleve'));
    });

    test('LPP obligatoire + surobligatoire mismatch triggers error', () {
      final profile = {
        'lpp_total': 100000.0,
        'lpp_obligatoire': 40000.0,
        'lpp_surobligatoire': 70000.0, // 40k+70k=110k != 100k
      };
      final alerts = PrecisionService.crossValidate(profile);
      final mismatch = alerts
          .where((a) =>
              a.fieldName == 'lpp_obligatoire' && a.severity == 'error')
          .toList();
      expect(mismatch, isNotEmpty);
      expect(mismatch.first.message, contains('ne correspond pas'));
    });

    test('net/gross ratio too high (>0.92) triggers warning', () {
      final profile = {
        'salaire_brut': 8000.0,
        'salaire_net': 7800.0, // ratio = 0.975
      };
      final alerts = PrecisionService.crossValidate(profile);
      final netAlerts =
          alerts.where((a) => a.fieldName == 'salaire_net').toList();
      expect(netAlerts, isNotEmpty);
      expect(netAlerts.first.message, contains('proche du brut'));
    });

    test('net/gross ratio too low (<0.55) triggers warning', () {
      final profile = {
        'salaire_brut': 10000.0,
        'salaire_net': 5000.0, // ratio = 0.50
      };
      final alerts = PrecisionService.crossValidate(profile);
      final netAlerts =
          alerts.where((a) => a.fieldName == 'salaire_net').toList();
      expect(netAlerts, isNotEmpty);
      expect(netAlerts.first.message, contains('ecart'));
    });

    test('AVS years exceeding age-based max triggers error', () {
      final profile = {
        'age': 30.0,
        'avs_contribution_years': 15.0, // max = 30-20 = 10
      };
      final alerts = PrecisionService.crossValidate(profile);
      final avsAlerts = alerts
          .where((a) =>
              a.fieldName == 'avs_contribution_years' && a.severity == 'error')
          .toList();
      expect(avsAlerts, isNotEmpty);
      expect(avsAlerts.first.message, contains('pas possibles'));
    });

    test('3a balance for under 18 triggers error', () {
      final profile = {
        'age': 17.0,
        'pillar_3a_balance': 5000.0,
      };
      final alerts = PrecisionService.crossValidate(profile);
      final error3a = alerts
          .where((a) =>
              a.fieldName == 'pillar_3a_balance' && a.severity == 'error')
          .toList();
      expect(error3a, isNotEmpty);
      expect(error3a.first.message, contains('18 ans'));
    });

    test('3a balance too high for age triggers warning', () {
      final profile = {
        'age': 25.0,
        'pillar_3a_balance': 500000.0, // max ~7y * 7258 * 1.4 = ~71k
      };
      final alerts = PrecisionService.crossValidate(profile);
      final alerts3a = alerts
          .where((a) =>
              a.fieldName == 'pillar_3a_balance' && a.severity == 'warning')
          .toList();
      expect(alerts3a, isNotEmpty);
      expect(alerts3a.first.message, contains('eleve'));
    });

    test('monthly expenses exceeding net salary triggers warning', () {
      final profile = {
        'salaire_net': 5000.0,
        'monthly_expenses': 7000.0, // > 1.3 * 5000
      };
      final alerts = PrecisionService.crossValidate(profile);
      final expAlerts =
          alerts.where((a) => a.fieldName == 'monthly_expenses').toList();
      expect(expAlerts, isNotEmpty);
      expect(expAlerts.first.message, contains('depassent'));
    });

    test('marginal tax rate > 50% triggers warning', () {
      final profile = {
        'taux_marginal': 0.55,
      };
      final alerts = PrecisionService.crossValidate(profile);
      final taxAlerts =
          alerts.where((a) => a.fieldName == 'taux_marginal').toList();
      expect(taxAlerts, isNotEmpty);
      expect(taxAlerts.first.message, contains('50'));
    });

    test('marginal tax rate < 5% with salary triggers warning', () {
      final profile = {
        'taux_marginal': 0.03,
        'salaire_brut': 8000.0,
      };
      final alerts = PrecisionService.crossValidate(profile);
      final taxAlerts =
          alerts.where((a) => a.fieldName == 'taux_marginal').toList();
      expect(taxAlerts, isNotEmpty);
      expect(taxAlerts.first.message, contains('bas'));
    });

    test('empty profile returns no alerts', () {
      final alerts = PrecisionService.crossValidate({});
      expect(alerts, isEmpty);
    });

    test('handles string values gracefully (parsed as doubles)', () {
      final profile = {
        'age': '30',
        'salaire_brut': '5000',
        'lpp_total': '20000',
      };
      // Should not throw
      final alerts = PrecisionService.crossValidate(profile);
      expect(alerts, isA<List<CrossValidationAlert>>());
    });
  });

  // ── 3. Smart defaults ─────────────────────────────────────────

  group('PrecisionService.computeSmartDefaults', () {
    test('swiss_native 45yo produces valid defaults', () {
      final defaults = PrecisionService.computeSmartDefaults(
        archetype: 'swiss_native',
        age: 45,
        salary: 8000,
        canton: 'VD',
      );
      expect(defaults, isNotEmpty);

      final lppDefault = defaults.firstWhere((d) => d.fieldName == 'lpp_total');
      expect(lppDefault.value, greaterThan(0));
      expect(lppDefault.confidence, 0.40);
      expect(lppDefault.source, contains('swiss_native'));

      final avsDefault =
          defaults.firstWhere((d) => d.fieldName == 'avs_contribution_years');
      expect(avsDefault.value, 25.0); // 45 - 20 = 25
      expect(avsDefault.confidence, 0.55);
    });

    test('expat archetype has later AVS start and lower confidence', () {
      final defaults = PrecisionService.computeSmartDefaults(
        archetype: 'expat_eu',
        age: 45,
        salary: 8000,
        canton: 'ZH',
      );
      final avsDefault =
          defaults.firstWhere((d) => d.fieldName == 'avs_contribution_years');
      expect(avsDefault.value, 15.0); // 45 - 30 = 15
      expect(avsDefault.confidence, 0.30); // lower than swiss_native

      final lppDefault = defaults.firstWhere((d) => d.fieldName == 'lpp_total');
      expect(lppDefault.confidence, 0.25); // lower for expat
    });

    test('independent_no_lpp has lpp_total = 0 with high confidence', () {
      final defaults = PrecisionService.computeSmartDefaults(
        archetype: 'independent_no_lpp',
        age: 40,
        salary: 6000,
        canton: 'GE',
      );
      final lppDefault = defaults.firstWhere((d) => d.fieldName == 'lpp_total');
      expect(lppDefault.value, 0);
      expect(lppDefault.confidence, 0.90);
      expect(lppDefault.source, contains('Independant sans LPP'));
    });

    test('low-tax canton gives higher net ratio', () {
      final defaultsZG = PrecisionService.computeSmartDefaults(
        archetype: 'swiss_native',
        age: 40,
        salary: 8000,
        canton: 'ZG',
      );
      final defaultsGE = PrecisionService.computeSmartDefaults(
        archetype: 'swiss_native',
        age: 40,
        salary: 8000,
        canton: 'GE',
      );
      final netZG =
          defaultsZG.firstWhere((d) => d.fieldName == 'salaire_net').value;
      final netGE =
          defaultsGE.firstWhere((d) => d.fieldName == 'salaire_net').value;
      expect(netZG, greaterThan(netGE)); // Zug > Geneva
    });

    test('all defaults have positive or zero confidence', () {
      final defaults = PrecisionService.computeSmartDefaults(
        archetype: 'swiss_native',
        age: 50,
        salary: 10000,
        canton: 'BE',
      );
      for (final d in defaults) {
        expect(d.confidence, greaterThanOrEqualTo(0));
        expect(d.confidence, lessThanOrEqualTo(1.0));
      }
    });

    test('defaults include replacement_ratio at 70%', () {
      final defaults = PrecisionService.computeSmartDefaults(
        archetype: 'swiss_native',
        age: 50,
        salary: 10000,
        canton: 'ZH',
      );
      final rrDefault =
          defaults.firstWhere((d) => d.fieldName == 'replacement_ratio');
      expect(rrDefault.value, 70);
      expect(rrDefault.confidence, 0.50);
    });

    test('defaults include tax_saving_3a based on estimated marginal rate', () {
      final defaults = PrecisionService.computeSmartDefaults(
        archetype: 'swiss_native',
        age: 45,
        salary: 10000,
        canton: 'VD',
      );
      final taxSaving =
          defaults.firstWhere((d) => d.fieldName == 'tax_saving_3a');
      expect(taxSaving.value, greaterThan(0));
    });

    test('young person (age 22) has small or zero LPP and 3a', () {
      final defaults = PrecisionService.computeSmartDefaults(
        archetype: 'swiss_native',
        age: 22,
        salary: 4000,
        canton: 'ZH',
      );
      final lpp = defaults.firstWhere((d) => d.fieldName == 'lpp_total');
      expect(lpp.value, 0); // 22 - 25 = clamped to 0 years

      final a3a =
          defaults.firstWhere((d) => d.fieldName == 'pillar_3a_balance');
      expect(a3a.value, 0); // 22 - 25 = clamped to 0 years
    });

    test('cross_border archetype has correct AVS years', () {
      final defaults = PrecisionService.computeSmartDefaults(
        archetype: 'cross_border',
        age: 50,
        salary: 9000,
        canton: 'GE',
      );
      final avs =
          defaults.firstWhere((d) => d.fieldName == 'avs_contribution_years');
      expect(avs.value, 25.0); // 50 - 25 = 25
    });
  });

  // ── 4. Precision prompts ──────────────────────────────────────

  group('PrecisionService.getPrecisionPrompts', () {
    test('rente_vs_capital context: missing LPP obligatoire prompts', () {
      final prompts = PrecisionService.getPrecisionPrompts(
        context: 'rente_vs_capital',
        profile: {'lpp_total': 100000.0},
      );
      final lppObligPrompt =
          prompts.where((p) => p.fieldNeeded == 'lpp_obligatoire').toList();
      expect(lppObligPrompt, isNotEmpty);
      expect(lppObligPrompt.first.impactText, contains('20'));
    });

    test('rente_vs_capital context: missing both LPP fields', () {
      final prompts = PrecisionService.getPrecisionPrompts(
        context: 'rente_vs_capital',
        profile: {},
      );
      final fields = prompts.map((p) => p.fieldNeeded).toSet();
      expect(fields, contains('lpp_obligatoire'));
      expect(fields, contains('lpp_total'));
    });

    test('retirement context: missing AVS years prompts', () {
      final prompts = PrecisionService.getPrecisionPrompts(
        context: 'retirement',
        profile: {'lpp_total': 50000.0, 'lpp_obligatoire': 30000.0},
      );
      final avsPrompt = prompts
          .where((p) => p.fieldNeeded == 'avs_contribution_years')
          .toList();
      expect(avsPrompt, isNotEmpty);
      expect(avsPrompt.first.impactText, contains('200'));
    });

    test('retirement context: missing 3a prompts', () {
      final prompts = PrecisionService.getPrecisionPrompts(
        context: 'retirement',
        profile: {'avs_contribution_years': 25.0},
      );
      final a3aPrompt = prompts
          .where((p) => p.fieldNeeded == 'pillar_3a_balance')
          .toList();
      expect(a3aPrompt, isNotEmpty);
    });

    test('tax_optimization context: missing marginal rate prompts', () {
      final prompts = PrecisionService.getPrecisionPrompts(
        context: 'tax_optimization',
        profile: {},
      );
      final taxPrompt =
          prompts.where((p) => p.fieldNeeded == 'taux_marginal').toList();
      expect(taxPrompt, isNotEmpty);
      expect(taxPrompt.first.impactText, contains('5 points'));
    });

    test('complete profile in rente_vs_capital returns no prompts', () {
      final prompts = PrecisionService.getPrecisionPrompts(
        context: 'rente_vs_capital',
        profile: {
          'lpp_total': 200000.0,
          'lpp_obligatoire': 120000.0,
          'taux_marginal': 0.30,
          'avs_contribution_years': 25.0,
          'pillar_3a_balance': 80000.0,
          'mortgage_remaining': 300000.0,
          'monthly_expenses': 4500.0,
        },
      );
      expect(prompts, isEmpty);
    });

    test('budget context: missing expenses prompts', () {
      final prompts = PrecisionService.getPrecisionPrompts(
        context: 'budget',
        profile: {},
      );
      final expPrompt =
          prompts.where((p) => p.fieldNeeded == 'monthly_expenses').toList();
      expect(expPrompt, isNotEmpty);
      expect(expPrompt.first.impactText, contains('15'));
    });

    test('mortgage context: missing mortgage prompts', () {
      final prompts = PrecisionService.getPrecisionPrompts(
        context: 'mortgage',
        profile: {},
      );
      final mortPrompt = prompts
          .where((p) => p.fieldNeeded == 'mortgage_remaining')
          .toList();
      expect(mortPrompt, isNotEmpty);
    });

    test('3a_deep context: missing marginal rate prompts', () {
      final prompts = PrecisionService.getPrecisionPrompts(
        context: '3a_deep',
        profile: {},
      );
      final taxPrompt =
          prompts.where((p) => p.fieldNeeded == 'taux_marginal').toList();
      expect(taxPrompt, isNotEmpty);
    });

    test('unknown context returns empty list', () {
      final prompts = PrecisionService.getPrecisionPrompts(
        context: 'unknown_screen',
        profile: {},
      );
      expect(prompts, isEmpty);
    });
  });
}
