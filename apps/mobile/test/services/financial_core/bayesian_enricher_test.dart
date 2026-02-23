import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/bayesian_enricher.dart';

/// Builds a minimal CoachProfile for Bayesian enrichment testing.
///
/// Allows overriding key fields relevant to posterior estimation.
CoachProfile _buildProfile({
  int birthYear = 1985,
  String canton = 'ZH',
  double salaireBrutMensuel = 8000,
  CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
  String employmentStatus = 'salarie',
  int nombre3a = 2,
  double totalEpargne3a = 0,
  double? avoirLppTotal,
  double tauxConversion = 0.068,
  int nombreEnfants = 0,
  int? arrivalAge,
  ConjointProfile? conjoint,
  double epargneLiquide = 0,
  int? anneesContribuees,
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaireBrutMensuel,
    etatCivil: etatCivil,
    employmentStatus: employmentStatus,
    nombreEnfants: nombreEnfants,
    arrivalAge: arrivalAge,
    conjoint: conjoint,
    prevoyance: PrevoyanceProfile(
      nombre3a: nombre3a,
      totalEpargne3a: totalEpargne3a,
      avoirLppTotal: avoirLppTotal,
      tauxConversion: tauxConversion,
      anneesContribuees: anneesContribuees,
    ),
    patrimoine: PatrimoineProfile(
      epargneLiquide: epargneLiquide,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(birthYear + 65, 12, 31),
      label: 'Retraite',
    ),
  );
}

void main() {
  group('BayesianProfileEnricher.enrich', () {
    // ════════════════════════════════════════════════════════════════
    //  Core invariants
    // ════════════════════════════════════════════════════════════════

    test('1. returns estimates for all key fields', () {
      final profile = _buildProfile();
      final result = BayesianProfileEnricher.enrich(profile);

      // Default profile is celibataire — no conjointSalary estimate
      const expectedKeys = [
        'avoirLppTotal',
        'totalEpargne3a',
        'epargneLiquide',
        'tauxConversion',
        'depensesMensuelles',
        'anneesContribuees',
      ];

      for (final key in expectedKeys) {
        expect(
          result.estimates.containsKey(key),
          isTrue,
          reason: 'Missing estimate for key: $key',
        );
      }
    });

    test('2. all CI intervals satisfy ci80Low <= median <= ci80High', () {
      final profile = _buildProfile(
        salaireBrutMensuel: 7500,
        birthYear: 1980,
      );
      final result = BayesianProfileEnricher.enrich(profile);

      for (final entry in result.estimates.entries) {
        final est = entry.value;
        expect(
          est.ci80Low,
          lessThanOrEqualTo(est.median),
          reason: '${entry.key}: ci80Low (${est.ci80Low}) > median (${est.median})',
        );
        expect(
          est.median,
          lessThanOrEqualTo(est.ci80High),
          reason: '${entry.key}: median (${est.median}) > ci80High (${est.ci80High})',
        );
      }
    });

    test('3. all standard deviations are positive', () {
      final profile = _buildProfile();
      final result = BayesianProfileEnricher.enrich(profile);

      for (final entry in result.estimates.entries) {
        final est = entry.value;
        expect(
          est.sd,
          greaterThan(0),
          reason: '${entry.key}: sd (${est.sd}) should be > 0',
        );
      }
    });

    test('4. dataQuality is between 0 and 1 for all estimates', () {
      final profile = _buildProfile();
      final result = BayesianProfileEnricher.enrich(profile);

      for (final entry in result.estimates.entries) {
        final est = entry.value;
        expect(
          est.dataQuality,
          greaterThanOrEqualTo(0),
          reason: '${entry.key}: dataQuality (${est.dataQuality}) < 0',
        );
        expect(
          est.dataQuality,
          lessThanOrEqualTo(1),
          reason: '${entry.key}: dataQuality (${est.dataQuality}) > 1',
        );
      }
    });

    // ════════════════════════════════════════════════════════════════
    //  LPP estimation
    // ════════════════════════════════════════════════════════════════

    test('5. higher salary produces higher LPP posterior mean', () {
      final lowSalary = _buildProfile(
        salaireBrutMensuel: 5000,
        birthYear: 1985,
      );
      final highSalary = _buildProfile(
        salaireBrutMensuel: 12000,
        birthYear: 1985,
      );

      final resultLow = BayesianProfileEnricher.enrich(lowSalary);
      final resultHigh = BayesianProfileEnricher.enrich(highSalary);

      expect(
        resultHigh.estimates['avoirLppTotal']!.mean,
        greaterThan(resultLow.estimates['avoirLppTotal']!.mean),
        reason: 'Higher salary should produce higher LPP posterior mean',
      );
    });

    test('6. older person has higher LPP posterior mean than younger', () {
      final young = _buildProfile(
        birthYear: 2000, // ~26 years old
        salaireBrutMensuel: 7000,
      );
      final older = _buildProfile(
        birthYear: 1975, // ~51 years old
        salaireBrutMensuel: 7000,
      );

      final resultYoung = BayesianProfileEnricher.enrich(young);
      final resultOlder = BayesianProfileEnricher.enrich(older);

      expect(
        resultOlder.estimates['avoirLppTotal']!.mean,
        greaterThan(resultYoung.estimates['avoirLppTotal']!.mean),
        reason: 'Older person should have higher LPP posterior mean',
      );
    });

    test('7. independant without LPP has zero LPP estimate', () {
      final profile = _buildProfile(
        employmentStatus: 'independant',
        avoirLppTotal: null,
      );
      final result = BayesianProfileEnricher.enrich(profile);

      final lppEstimate = result.estimates['avoirLppTotal']!;
      expect(
        lppEstimate.mean,
        equals(0),
        reason: 'Independant sans LPP should have 0 mean LPP estimate',
      );
      expect(
        lppEstimate.median,
        equals(0),
        reason: 'Independant sans LPP should have 0 median LPP estimate',
      );
    });

    test('8. declared LPP value collapses posterior (low SD)', () {
      final estimated = _buildProfile(
        salaireBrutMensuel: 8000,
        birthYear: 1980,
        avoirLppTotal: null,
      );
      final declared = _buildProfile(
        salaireBrutMensuel: 8000,
        birthYear: 1980,
        avoirLppTotal: 250000,
      );

      final resultEstimated = BayesianProfileEnricher.enrich(estimated);
      final resultDeclared = BayesianProfileEnricher.enrich(declared);

      // Declared value should collapse the posterior: much lower SD
      expect(
        resultDeclared.estimates['avoirLppTotal']!.sd,
        lessThan(resultEstimated.estimates['avoirLppTotal']!.sd),
        reason: 'Declared LPP should have lower SD (collapsed posterior)',
      );

      // Declared value should be reflected in the mean
      expect(
        resultDeclared.estimates['avoirLppTotal']!.mean,
        closeTo(250000, 250000 * 0.05), // within 5%
        reason: 'Declared LPP value should dominate the posterior mean',
      );

      // isDeclared should be true
      expect(
        resultDeclared.estimates['avoirLppTotal']!.isDeclared,
        isTrue,
        reason: 'Declared LPP should have isDeclared = true',
      );
    });

    // ════════════════════════════════════════════════════════════════
    //  3a estimation
    // ════════════════════════════════════════════════════════════════

    test('9. person with nombre3a=3 has higher 3a estimate than nombre3a=0', () {
      final noAccounts = _buildProfile(
        nombre3a: 0,
        totalEpargne3a: 0,
        birthYear: 1985,
      );
      final threeAccounts = _buildProfile(
        nombre3a: 3,
        totalEpargne3a: 0, // not declared — enricher should estimate
        birthYear: 1985,
      );

      final resultNone = BayesianProfileEnricher.enrich(noAccounts);
      final resultThree = BayesianProfileEnricher.enrich(threeAccounts);

      expect(
        resultThree.estimates['totalEpargne3a']!.mean,
        greaterThan(resultNone.estimates['totalEpargne3a']!.mean),
        reason: '3 accounts should produce higher 3a posterior mean than 0',
      );
    });

    test('10. declared 3a value is reflected in posterior', () {
      final profile = _buildProfile(
        nombre3a: 2,
        totalEpargne3a: 80000,
        birthYear: 1985,
      );
      final result = BayesianProfileEnricher.enrich(profile);

      final est = result.estimates['totalEpargne3a']!;
      expect(
        est.mean,
        closeTo(80000, 80000 * 0.10), // within 10%
        reason: 'Declared 3a value should be reflected in posterior mean',
      );
      expect(
        est.isDeclared,
        isTrue,
        reason: 'Declared 3a should have isDeclared = true',
      );
    });

    // ════════════════════════════════════════════════════════════════
    //  Canton effects
    // ════════════════════════════════════════════════════════════════

    test('11. GE (high cost) has higher expense estimate than AI (low cost)', () {
      final geneva = _buildProfile(
        canton: 'GE',
        salaireBrutMensuel: 7000,
      );
      final appenzell = _buildProfile(
        canton: 'AI',
        salaireBrutMensuel: 7000,
      );

      final resultGE = BayesianProfileEnricher.enrich(geneva);
      final resultAI = BayesianProfileEnricher.enrich(appenzell);

      expect(
        resultGE.estimates['depensesMensuelles']!.mean,
        greaterThan(resultAI.estimates['depensesMensuelles']!.mean),
        reason: 'Geneva (high cost) should have higher expense estimate than Appenzell (low cost)',
      );
    });

    test('12. high-tax canton has slightly higher LPP estimate (more buybacks)', () {
      // In high-tax cantons, people tend to buy back LPP more aggressively
      // to reduce taxable income, leading to slightly higher LPP averages.
      final highTax = _buildProfile(
        canton: 'GE', // Geneve — high marginal tax
        salaireBrutMensuel: 10000,
        birthYear: 1980,
      );
      final lowTax = _buildProfile(
        canton: 'ZG', // Zoug — low marginal tax
        salaireBrutMensuel: 10000,
        birthYear: 1980,
      );

      final resultHighTax = BayesianProfileEnricher.enrich(highTax);
      final resultLowTax = BayesianProfileEnricher.enrich(lowTax);

      // This is a soft behavioral property: high-tax cantons have a
      // slightly upward prior on LPP due to buyback incentive.
      expect(
        resultHighTax.estimates['avoirLppTotal']!.mean,
        greaterThanOrEqualTo(resultLowTax.estimates['avoirLppTotal']!.mean),
        reason: 'High-tax canton should have >= LPP estimate (buyback incentive)',
      );
    });

    // ════════════════════════════════════════════════════════════════
    //  Couple support
    // ════════════════════════════════════════════════════════════════

    test('13. married profile generates conjointSalary estimate', () {
      final profile = _buildProfile(
        etatCivil: CoachCivilStatus.marie,
        conjoint: const ConjointProfile(
          birthYear: 1987,
          salaireBrutMensuel: 6000,
        ),
      );
      final result = BayesianProfileEnricher.enrich(profile);

      final conjEst = result.estimates['conjointSalary']!;
      expect(
        conjEst.mean,
        greaterThan(0),
        reason: 'Married profile with conjoint should have conjointSalary > 0',
      );
    });

    test('14. single profile has no conjointSalary estimate', () {
      final profile = _buildProfile(
        etatCivil: CoachCivilStatus.celibataire,
      );
      final result = BayesianProfileEnricher.enrich(profile);

      // Single profile: conjointSalary should not be in the estimates map
      expect(
        result.estimates.containsKey('conjointSalary'),
        isFalse,
        reason: 'Single profile should not have conjointSalary estimate',
      );
    });

    // ════════════════════════════════════════════════════════════════
    //  EVI prompts
    // ════════════════════════════════════════════════════════════════

    test('15. prompts are sorted by EVI descending', () {
      final profile = _buildProfile(
        salaireBrutMensuel: 7000,
        birthYear: 1985,
      );
      final result = BayesianProfileEnricher.enrich(profile);

      expect(result.rankedPrompts, isNotEmpty,
          reason: 'Should generate at least one EVI prompt');

      for (int i = 0; i < result.rankedPrompts.length - 1; i++) {
        expect(
          result.rankedPrompts[i].evi,
          greaterThanOrEqualTo(result.rankedPrompts[i + 1].evi),
          reason:
              'Prompt ${result.rankedPrompts[i].field} (EVI=${result.rankedPrompts[i].evi}) '
              'should be >= ${result.rankedPrompts[i + 1].field} (EVI=${result.rankedPrompts[i + 1].evi})',
        );
      }
    });

    test('16. declared fields are NOT in prompts (nothing to ask)', () {
      final profile = _buildProfile(
        avoirLppTotal: 200000,
        totalEpargne3a: 50000,
        nombre3a: 2,
        anneesContribuees: 20,
        epargneLiquide: 30000,
      );
      final result = BayesianProfileEnricher.enrich(profile);

      // Get the fields that appear in prompts
      final promptFields = result.rankedPrompts.map((p) => p.field).toSet();

      // Fields that were explicitly declared should NOT appear in prompts
      expect(
        promptFields.contains('avoirLppTotal'),
        isFalse,
        reason: 'Declared avoirLppTotal should not generate a prompt',
      );
      expect(
        promptFields.contains('totalEpargne3a'),
        isFalse,
        reason: 'Declared totalEpargne3a should not generate a prompt',
      );
    });

    test('17. LPP prompt has high EVI for profiles with estimated LPP', () {
      final profile = _buildProfile(
        salaireBrutMensuel: 10000,
        birthYear: 1975, // ~51 years old — large estimated LPP
        avoirLppTotal: null, // not declared → estimated
      );
      final result = BayesianProfileEnricher.enrich(profile);

      final lppPrompts = result.rankedPrompts
          .where((p) => p.field == 'avoirLppTotal')
          .toList();

      expect(lppPrompts, isNotEmpty,
          reason: 'Should have an LPP prompt for undeclared LPP');

      // LPP should be among the highest EVI prompts for a senior profile
      // with large estimated (uncertain) LPP balance
      if (result.rankedPrompts.length >= 2) {
        final lppRank = result.rankedPrompts.indexOf(lppPrompts.first);
        expect(
          lppRank,
          lessThan(result.rankedPrompts.length ~/ 2),
          reason: 'LPP prompt should rank in the top half of prompts by EVI',
        );
      }
    });

    // ════════════════════════════════════════════════════════════════
    //  Compliance
    // ════════════════════════════════════════════════════════════════

    test('18. disclaimer mentions OFS/BFS and LSFin', () {
      final profile = _buildProfile();
      final result = BayesianProfileEnricher.enrich(profile);

      expect(result.disclaimer, isNotEmpty,
          reason: 'Disclaimer must not be empty');
      expect(
        result.disclaimer.toLowerCase(),
        anyOf(contains('ofs'), contains('bfs')),
        reason: 'Disclaimer should mention OFS (Office federal de la statistique) or BFS',
      );
      expect(
        result.disclaimer.toLowerCase(),
        contains('lsfin'),
        reason: 'Disclaimer should mention LSFin',
      );
    });

    test('19. sources reference LPP and LAVS articles', () {
      final profile = _buildProfile();
      final result = BayesianProfileEnricher.enrich(profile);

      expect(result.sources, isNotEmpty,
          reason: 'Sources list must not be empty');

      final allSources = result.sources.join(' ').toLowerCase();
      expect(
        allSources,
        contains('lpp'),
        reason: 'Sources should reference LPP',
      );
      expect(
        allSources,
        contains('lavs'),
        reason: 'Sources should reference LAVS',
      );
    });

    // ════════════════════════════════════════════════════════════════
    //  Edge cases
    // ════════════════════════════════════════════════════════════════

    test('20. minimal profile (only birthYear+canton) returns valid estimates', () {
      // Profile with minimal data — salary=0, no 3a, no LPP, no patrimoine
      final profile = _buildProfile(
        birthYear: 1990,
        canton: 'BE',
        salaireBrutMensuel: 0,
        nombre3a: 0,
        totalEpargne3a: 0,
        avoirLppTotal: null,
        epargneLiquide: 0,
      );
      final result = BayesianProfileEnricher.enrich(profile);

      // Should return 6 estimate keys (no conjointSalary for celibataire)
      expect(result.estimates.length, greaterThanOrEqualTo(6));

      // All estimates should have valid numeric fields (no NaN, no Inf)
      for (final entry in result.estimates.entries) {
        final est = entry.value;
        expect(est.mean.isFinite, isTrue,
            reason: '${entry.key}: mean should be finite');
        expect(est.median.isFinite, isTrue,
            reason: '${entry.key}: median should be finite');
        expect(est.sd.isFinite, isTrue,
            reason: '${entry.key}: sd should be finite');
        expect(est.ci80Low.isFinite, isTrue,
            reason: '${entry.key}: ci80Low should be finite');
        expect(est.ci80High.isFinite, isTrue,
            reason: '${entry.key}: ci80High should be finite');
      }

      // overallUncertainty should be valid (0-1)
      expect(result.overallUncertainty, greaterThanOrEqualTo(0));
      expect(result.overallUncertainty, lessThanOrEqualTo(1));

      // Minimal profile should have meaningful uncertainty (> 0.1)
      expect(result.overallUncertainty, greaterThan(0.1),
          reason: 'Minimal profile should have meaningful uncertainty');

      // Should still produce prompts (lots to ask)
      expect(result.rankedPrompts, isNotEmpty,
          reason: 'Minimal profile should generate enrichment prompts');

      // Compliance checks
      expect(result.disclaimer, isNotEmpty);
      expect(result.sources, isNotEmpty);
    });
  });
}
