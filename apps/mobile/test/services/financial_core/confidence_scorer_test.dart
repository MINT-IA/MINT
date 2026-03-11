import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

void main() {
  group('ConfidenceScorer.score', () {
    test('complete profile → high confidence (>= 70)', () {
      final profile = _buildProfile(
        age: 45,
        salary: 8000,
        canton: 'ZH',
        avoirLpp: 300000,
        epargne3a: 50000,
        patrimoine: 100000,
        employmentStatus: 'salarie',
        tauxConversion: 0.054,
        anneesContribuees: 25,
      );
      final confidence = ConfidenceScorer.score(profile);
      expect(confidence.score, greaterThanOrEqualTo(70));
      expect(confidence.level, equals('high'));
    });

    test('minimal profile → low confidence (< 40)', () {
      final profile = _buildProfile(
        age: 30,
        salary: 0,
        canton: '',
      );
      final confidence = ConfidenceScorer.score(profile);
      expect(confidence.score, lessThan(40));
      expect(confidence.level, equals('low'));
      expect(confidence.prompts, isNotEmpty);
    });

    test('expat without foreign pension → penalty + prompt', () {
      final profile = _buildProfile(
        age: 45,
        salary: 8000,
        canton: 'ZH',
        arrivalAge: 35,
        employmentStatus: 'salarie',
      );
      final confidence = ConfidenceScorer.score(profile);
      final foreignPrompt = confidence.prompts
          .where((p) => p.category == 'foreign_pension')
          .toList();
      expect(foreignPrompt, isNotEmpty);
      expect(
        confidence.assumptions,
        contains(contains('etrangere')),
      );
    });

    test('independent without LPP → no LPP penalty', () {
      final profile = _buildProfile(
        age: 40,
        salary: 6000,
        canton: 'VD',
        employmentStatus: 'independant',
        avoirLpp: null,
      );
      final confidence = ConfidenceScorer.score(profile);
      // Independent without LPP should not lose points for missing LPP
      final lppPrompts =
          confidence.prompts.where((p) => p.category == 'lpp').toList();
      expect(lppPrompts, isEmpty);
    });

    test('prompts ranked by Bayesian EVI (with bayesianResult)', () {
      final profile = _buildProfile(
        age: 30,
        salary: 5000,
        canton: 'ZH',
      );
      final confidence = ConfidenceScorer.score(profile);
      // Prompts should be non-empty and re-ranked by EVI
      expect(confidence.prompts, isNotEmpty);
      // Bayesian result should be attached
      expect(confidence.bayesianResult, isNotNull);
      // Bayesian EVI prompts should also be ranked descending
      final eviPrompts = confidence.bayesianResult!.rankedPrompts;
      for (int i = 0; i < eviPrompts.length - 1; i++) {
        expect(
          eviPrompts[i].evi,
          greaterThanOrEqualTo(eviPrompts[i + 1].evi),
        );
      }
    });

    test('assumptions list populated for missing data', () {
      final profile = _buildProfile(
        age: 35,
        salary: 6000,
        canton: 'GE',
      );
      final confidence = ConfidenceScorer.score(profile);
      expect(confidence.assumptions, isNotEmpty);
      expect(
        confidence.assumptions,
        contains(contains('LPP')),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  S46 — ENHANCED 3-AXIS SCORING
  // ═══════════════════════════════════════════════════════════════

  group('ConfidenceScorer.scoreEnhanced', () {
    test('complete profile with certificates → high accuracy', () {
      final profile = _buildProfile(
        age: 45,
        salary: 8000,
        canton: 'ZH',
        avoirLpp: 300000,
        epargne3a: 50000,
        patrimoine: 100000,
        employmentStatus: 'salarie',
        tauxConversion: 0.054,
        anneesContribuees: 25,
        dataSources: {
          'salaireBrutMensuel': ProfileDataSource.certificate,
          'prevoyance.avoirLppTotal': ProfileDataSource.certificate,
          'prevoyance.tauxConversion': ProfileDataSource.certificate,
          'prevoyance.anneesContribuees': ProfileDataSource.certificate,
          'prevoyance.totalEpargne3a': ProfileDataSource.userInput,
          'patrimoine.epargneLiquide': ProfileDataSource.userInput,
        },
      );
      final now = DateTime(2026, 3, 9);
      final result = ConfidenceScorer.scoreEnhanced(profile, now: now);
      expect(result.completeness, greaterThanOrEqualTo(70));
      expect(result.accuracy, greaterThan(60)); // mix of certificate + userInput
      expect(result.combined, greaterThan(0));
      expect(result.combined, lessThanOrEqualTo(100));
    });

    test('all estimated sources → low accuracy (~25)', () {
      final profile = _buildProfile(
        age: 30,
        salary: 5000,
        canton: 'GE',
      );
      final result = ConfidenceScorer.scoreEnhanced(profile);
      expect(result.accuracy, equals(25)); // all defaults = estimated (0.25)
    });

    test('fresh data → high freshness', () {
      final now = DateTime(2026, 3, 9);
      final profile = _buildProfile(
        age: 45,
        salary: 8000,
        canton: 'ZH',
        avoirLpp: 300000,
        dataTimestamps: {
          'salaireBrutMensuel': now.subtract(const Duration(days: 30)),
          'age': now.subtract(const Duration(days: 30)),
          'canton': now.subtract(const Duration(days: 30)),
          'etatCivil': now.subtract(const Duration(days: 30)),
          'prevoyance.avoirLppTotal': now.subtract(const Duration(days: 60)),
          'prevoyance.tauxConversion': now.subtract(const Duration(days: 60)),
          'prevoyance.anneesContribuees': now.subtract(const Duration(days: 90)),
          'prevoyance.totalEpargne3a': now.subtract(const Duration(days: 30)),
          'patrimoine.epargneLiquide': now.subtract(const Duration(days: 15)),
        },
      );
      final result = ConfidenceScorer.scoreEnhanced(profile, now: now);
      expect(result.freshness, greaterThanOrEqualTo(90)); // all < 6 months
    });

    test('stale data (2+ years) → low freshness', () {
      final now = DateTime(2026, 3, 9);
      final twoYearsAgo = now.subtract(const Duration(days: 730));
      final profile = _buildProfile(
        age: 50,
        salary: 8000,
        canton: 'VD',
        avoirLpp: 200000,
        dataTimestamps: {
          'salaireBrutMensuel': twoYearsAgo,
          'age': twoYearsAgo,
          'canton': twoYearsAgo,
          'etatCivil': twoYearsAgo,
          'prevoyance.avoirLppTotal': twoYearsAgo,
          'prevoyance.tauxConversion': twoYearsAgo,
          'prevoyance.anneesContribuees': twoYearsAgo,
          'prevoyance.totalEpargne3a': twoYearsAgo,
          'patrimoine.epargneLiquide': twoYearsAgo,
        },
      );
      final result = ConfidenceScorer.scoreEnhanced(profile, now: now);
      expect(result.freshness, lessThan(60)); // significant decay
    });

    test('no timestamps → moderate freshness (default 0.5)', () {
      final profile = _buildProfile(
        age: 40,
        salary: 6000,
        canton: 'BE',
      );
      final result = ConfidenceScorer.scoreEnhanced(profile);
      expect(result.freshness, equals(50)); // 0.5 default → 50%
    });

    test('combined = geometric mean of 3 axes', () {
      final profile = _buildProfile(
        age: 45,
        salary: 8000,
        canton: 'ZH',
        avoirLpp: 300000,
        epargne3a: 50000,
        patrimoine: 100000,
        employmentStatus: 'salarie',
        tauxConversion: 0.054,
        anneesContribuees: 25,
      );
      final result = ConfidenceScorer.scoreEnhanced(profile);
      // Combined should be between min and max of the 3 axes
      final minAxis = [result.completeness, result.accuracy, result.freshness]
          .reduce((a, b) => a < b ? a : b);
      final maxAxis = [result.completeness, result.accuracy, result.freshness]
          .reduce((a, b) => a > b ? a : b);
      expect(result.combined, greaterThanOrEqualTo(minAxis - 1));
      expect(result.combined, lessThanOrEqualTo(maxAxis + 1));
    });

    test('axis prompts include freshness + accuracy categories', () {
      final now = DateTime(2026, 3, 9);
      // 800 days → ~26 months → decay < 0.7 → triggers freshness prompt
      final profile = _buildProfile(
        age: 50,
        salary: 8000,
        canton: 'VD',
        avoirLpp: 200000,
        dataSources: {
          'prevoyance.avoirLppTotal': ProfileDataSource.userInput,
        },
        dataTimestamps: {
          'prevoyance.avoirLppTotal': now.subtract(const Duration(days: 800)),
        },
      );
      final result = ConfidenceScorer.scoreEnhanced(profile, now: now);
      final categories = result.axisPrompts.map((p) => p.category).toSet();
      expect(categories, contains('accuracy'));
      expect(categories, contains('freshness'));
    });

    test('axisPrompts sorted by impact descending', () {
      final profile = _buildProfile(
        age: 35,
        salary: 5000,
        canton: 'GE',
      );
      final result = ConfidenceScorer.scoreEnhanced(profile);
      for (int i = 0; i < result.axisPrompts.length - 1; i++) {
        expect(
          result.axisPrompts[i].impact,
          greaterThanOrEqualTo(result.axisPrompts[i + 1].impact),
        );
      }
    });

    test('baseResult preserves backward-compatible V2 scoring', () {
      final profile = _buildProfile(
        age: 45,
        salary: 8000,
        canton: 'ZH',
        avoirLpp: 300000,
      );
      final enhanced = ConfidenceScorer.scoreEnhanced(profile);
      final v2 = ConfidenceScorer.score(profile);
      expect(enhanced.baseResult.score, equals(v2.score));
      expect(enhanced.baseResult.level, equals(v2.level));
      expect(enhanced.completeness, equals(v2.score));
    });
  });

  group('S47: dataTimestamps wiring', () {
    test('fromWizardAnswers stamps initial fields with base timestamp', () {
      final answers = <String, dynamic>{
        'q_birth_year': 1977,
        'q_canton': 'VS',
        'q_net_income_period_chf': 7500.0,
        'q_has_pension_fund': true,
        'q_has_3a': true,
        'q_3a_annual_contribution': 7258.0,
        'q_cash_total': 50000.0,
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      // Core fields should have timestamps
      expect(profile.dataTimestamps, contains('salaireBrutMensuel'));
      expect(profile.dataTimestamps, contains('canton'));
      expect(profile.dataTimestamps, contains('age'));
      expect(profile.dataTimestamps, contains('etatCivil'));
      expect(profile.dataTimestamps, contains('patrimoine.epargneLiquide'));
      // All timestamps should be recent (within last minute)
      final now = DateTime.now();
      for (final ts in profile.dataTimestamps.values) {
        expect(now.difference(ts).inSeconds, lessThan(60));
      }
    });

    test('fromWizardAnswers restores persisted timestamps', () {
      final oldDate = DateTime(2025, 6, 15);
      final answers = <String, dynamic>{
        'q_birth_year': 1977,
        'q_canton': 'VS',
        'q_net_income_period_chf': 7500.0,
        '_coach_data_timestamps': {
          'prevoyance.avoirLppTotal': oldDate.toIso8601String(),
          'patrimoine.epargneLiquide': oldDate.toIso8601String(),
        },
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      // Persisted timestamps should override base timestamp
      expect(
        profile.dataTimestamps['prevoyance.avoirLppTotal'],
        equals(oldDate),
      );
      expect(
        profile.dataTimestamps['patrimoine.epargneLiquide'],
        equals(oldDate),
      );
      // Non-persisted fields should have fresh timestamps
      expect(
        profile.dataTimestamps['salaireBrutMensuel']!.isAfter(oldDate),
        isTrue,
      );
    });

    test('fresh timestamps → high freshness score', () {
      final now = DateTime(2026, 3, 9);
      final profile = _buildProfile(
        age: 50,
        salary: 10000,
        canton: 'VD',
        avoirLpp: 300000,
        epargne3a: 50000,
        patrimoine: 80000,
        tauxConversion: 0.054,
        anneesContribuees: 25,
        dataSources: {
          'salaireBrutMensuel': ProfileDataSource.certificate,
          'prevoyance.avoirLppTotal': ProfileDataSource.certificate,
        },
        dataTimestamps: {
          'salaireBrutMensuel': now.subtract(const Duration(days: 30)),
          'prevoyance.avoirLppTotal': now.subtract(const Duration(days: 60)),
          'patrimoine.epargneLiquide': now.subtract(const Duration(days: 15)),
        },
      );
      final result = ConfidenceScorer.scoreEnhanced(profile, now: now);
      // All data is < 6 months old → freshness should be decent
      // (weighted average includes fields without timestamps → default 0.5)
      expect(result.freshness, greaterThanOrEqualTo(60));
    });

    test('stale timestamps → low freshness score + prompts', () {
      final now = DateTime(2026, 3, 9);
      final profile = _buildProfile(
        age: 50,
        salary: 10000,
        canton: 'VD',
        avoirLpp: 300000,
        dataSources: {
          'salaireBrutMensuel': ProfileDataSource.userInput,
          'prevoyance.avoirLppTotal': ProfileDataSource.userInput,
        },
        dataTimestamps: {
          'salaireBrutMensuel': now.subtract(const Duration(days: 900)),
          'prevoyance.avoirLppTotal': now.subtract(const Duration(days: 900)),
        },
      );
      final result = ConfidenceScorer.scoreEnhanced(profile, now: now);
      // Data is ~30 months old → freshness should be low
      expect(result.freshness, lessThan(50));
      // Should have freshness prompts
      final freshnessPrompts =
          result.axisPrompts.where((p) => p.category == 'freshness');
      expect(freshnessPrompts, isNotEmpty);
    });

    test('mixed timestamps → freshness reflects weighted average', () {
      final now = DateTime(2026, 3, 9);
      final profile = _buildProfile(
        age: 50,
        salary: 10000,
        canton: 'VD',
        avoirLpp: 300000,
        epargne3a: 50000,
        patrimoine: 80000,
        dataSources: {
          'salaireBrutMensuel': ProfileDataSource.certificate,
          'prevoyance.avoirLppTotal': ProfileDataSource.certificate,
        },
        dataTimestamps: {
          // Salary fresh, LPP stale
          'salaireBrutMensuel': now.subtract(const Duration(days: 30)),
          'prevoyance.avoirLppTotal': now.subtract(const Duration(days: 800)),
        },
      );
      final result = ConfidenceScorer.scoreEnhanced(profile, now: now);
      // Freshness should be moderate (mix of fresh and stale)
      expect(result.freshness, greaterThan(30));
      expect(result.freshness, lessThan(90));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SCORE AS BLOCS (P8 Phase 3)
  // ════════════════════════════════════════════════════════════

  group('ConfidenceScorer.scoreAsBlocs', () {
    test('returns all expected bloc keys', () {
      final profile = _buildProfile(age: 45, salary: 8000, canton: 'VD');
      final blocs = ConfidenceScorer.scoreAsBlocs(profile);
      expect(blocs.keys, containsAll([
        'revenu',
        'age_canton',
        'archetype',
        'objectifRetraite',
        'compositionMenage',
        'lpp',
        'taux_conversion',
        'avs',
        '3a',
        'patrimoine',
        'foreign_pension',
      ]));
    });

    test('total maxScore sums to 115 (100 core + 15 fiscalite)', () {
      final profile = _buildProfile(age: 45, salary: 8000, canton: 'VD');
      final blocs = ConfidenceScorer.scoreAsBlocs(profile);
      final totalMax = blocs.values.fold(0.0, (s, b) => s + b.maxScore);
      // 100 pts for core blocs + 15 pts for fiscalite virtual bloc
      expect(totalMax, 115.0);
    });

    test('score <= maxScore for all blocs', () {
      final profile = _buildProfile(
        age: 45,
        salary: 8000,
        canton: 'VD',
        avoirLpp: 150000,
        epargne3a: 40000,
        patrimoine: 100000,
      );
      final blocs = ConfidenceScorer.scoreAsBlocs(profile);
      for (final entry in blocs.entries) {
        expect(
          entry.value.score,
          lessThanOrEqualTo(entry.value.maxScore),
          reason: '${entry.key}: score ${entry.value.score} > max ${entry.value.maxScore}',
        );
      }
    });

    test('complete profile has all blocs complete or partial', () {
      final profile = _buildProfile(
        age: 45,
        salary: 8000,
        canton: 'VD',
        avoirLpp: 150000,
        epargne3a: 40000,
        patrimoine: 100000,
        anneesContribuees: 20,
      );
      final blocs = ConfidenceScorer.scoreAsBlocs(profile);
      // Core blocs should not be 'missing'
      expect(blocs['revenu']!.status, 'complete');
      expect(blocs['age_canton']!.status, 'complete');
      expect(blocs['lpp']!.status, isNot('missing'));
    });

    test('objectifRetraite is partial when no explicit retirement age', () {
      final profile = _buildProfile(age: 45, salary: 8000, canton: 'VD');
      final blocs = ConfidenceScorer.scoreAsBlocs(profile);
      expect(blocs['objectifRetraite']!.status, 'partial');
      expect(blocs['objectifRetraite']!.score, 3.0); // default partial score
    });

    test('compositionMenage is complete for single person', () {
      final profile = _buildProfile(age: 45, salary: 8000, canton: 'VD');
      final blocs = ConfidenceScorer.scoreAsBlocs(profile);
      // celibataire → complete
      expect(blocs['compositionMenage']!.status, 'complete');
      expect(blocs['compositionMenage']!.score, blocs['compositionMenage']!.maxScore);
    });

    test('empty profile has zero score for missing blocs', () {
      final profile = _buildProfile(age: 0, salary: 0, canton: '');
      final blocs = ConfidenceScorer.scoreAsBlocs(profile);
      expect(blocs['revenu']!.score, 0);
      expect(blocs['age_canton']!.score, 0);
      expect(blocs['revenu']!.status, 'missing');
    });

    test('lpp bloc is partial when avoir declared', () {
      final profile = _buildProfile(
        age: 45,
        salary: 8000,
        canton: 'VD',
        avoirLpp: 150000,
      );
      final blocs = ConfidenceScorer.scoreAsBlocs(profile);
      expect(blocs['lpp']!.status, 'partial');
      expect(blocs['lpp']!.score, 11.0);
    });

    test('lpp bloc is complete for independant sans LPP', () {
      final profile = _buildProfile(
        age: 45,
        salary: 8000,
        canton: 'VD',
        employmentStatus: 'independant',
      );
      final blocs = ConfidenceScorer.scoreAsBlocs(profile);
      expect(blocs['lpp']!.status, 'complete');
      expect(blocs['lpp']!.score, blocs['lpp']!.maxScore);
    });
  });
}

/// Helper to build a CoachProfile for testing.
CoachProfile _buildProfile({
  required int age,
  required double salary,
  required String canton,
  double? avoirLpp,
  double epargne3a = 0,
  double patrimoine = 0,
  String employmentStatus = 'salarie',
  double tauxConversion = 0.068,
  int? anneesContribuees,
  int? arrivalAge,
  String? residencePermit,
  Map<String, ProfileDataSource> dataSources = const {},
  Map<String, DateTime> dataTimestamps = const {},
}) {
  return CoachProfile(
    firstName: 'Test',
    birthYear: DateTime.now().year - age,
    salaireBrutMensuel: salary,
    canton: canton,
    etatCivil: CoachCivilStatus.celibataire,
    employmentStatus: employmentStatus,
    arrivalAge: arrivalAge,
    residencePermit: residencePermit,
    dataSources: dataSources,
    dataTimestamps: dataTimestamps,
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLpp,
      tauxConversion: tauxConversion,
      totalEpargne3a: epargne3a,
      anneesContribuees: anneesContribuees,
    ),
    patrimoine: PatrimoineProfile(
      epargneLiquide: patrimoine,
    ),
    depenses: const DepensesProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
  );
}
