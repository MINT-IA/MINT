// benchmark_comparison_service_test.dart — S60
//
// Tests for BenchmarkComparisonService:
//   - Golden couple: Julien (VS, 122207) and Lauren (VS, 67000)
//   - Unknown canton returns null
//   - COMPLIANCE: no banned terms in output
//   - COMPLIANCE: no ranking language
//   - All insights have valid ARB-format keys
//   - Disclaimer always present

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/benchmark/benchmark_comparison_service.dart';

// ── Test helpers ─────────────────────────────────────────────────────────────

CoachProfile _buildProfile({
  int birthYear = 1977,
  String canton = 'VS',
  double salaireBrutMensuel = 10000,
  double loyer = 2000,
  double assuranceMaladie = 400,
  double epargneLiquide = 50000,
  double investissements = 100000,
  List<PlannedMonthlyContribution> contributions = const [],
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaireBrutMensuel,
    depenses: DepensesProfile(
      loyer: loyer,
      assuranceMaladie: assuranceMaladie,
    ),
    patrimoine: PatrimoineProfile(
      epargneLiquide: epargneLiquide,
      investissements: investissements,
    ),
    plannedContributions: contributions,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 1, 1),
      label: 'Retraite',
    ),
  );
}

// ── ARB key format validator ──────────────────────────────────────────────────

/// Valid ARB key pattern: lowercase + uppercase letters, digits, underscores,
/// starting with a lowercase letter.
final _arbKeyPattern = RegExp(r'^[a-z][a-zA-Z0-9_]*$');

bool _isValidArbKey(String key) => _arbKeyPattern.hasMatch(key);

// ── BANNED terms for compliance check ────────────────────────────────────────

const _bannedTerms = [
  'garanti', 'garantie', 'garantis', 'garanties',
  'assuré', 'assurée', 'assuré',
  'sans risque',
  'optimal', 'optimale', 'optimaux', 'optimales',
  'parfait', 'parfaite', 'parfaits', 'parfaites',
  'conseiller',
];

const _bannedRankingTerms = [
  'top ', 'top\u00a0',
  'mieux que',
  'pire que',
  // 'classement' is allowed in the disclaimer in the negating phrase
  // "pas un classement" — it is NOT banned in disclaimers.
  // Only ban active/promotional ranking language:
  'classement des cantons',
  'dans le classement',
  'percentile',
  'au-dessus de la moyenne',
  'en-dessous de la moyenne',
  'au-dessus de la médiane',
  'en-dessous de la médiane',
  'plus riche',
  'plus pauvre',
];

// ════════════════════════════════════════════════════════════════════════════
//  TESTS
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('golden couple — Julien (VS, 122207)', () {
    late BenchmarkComparison comparison;

    setUp(() {
      // Julien: born 1977, canton VS, salary 122207/year = 10184/month
      final profile = _buildProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 10184,
        epargneLiquide: 32000,
        investissements: 70377,
        loyer: 2200,
        assuranceMaladie: 400,
      );
      comparison = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'VS',
      )!;
    });

    test('compare returns non-null for VS', () {
      expect(comparison, isNotNull);
    });

    test('cantonCode is VS', () {
      expect(comparison.cantonCode, 'VS');
    });

    test('generates 6 insights', () {
      expect(comparison.insights.length, 6);
    });

    test('income insight is present', () {
      final income = comparison.insights
          .where((i) => i.dimension == BenchmarkDimension.income)
          .toList();
      expect(income.length, 1);
      expect(income.first.userValue, closeTo(10184 * 12, 1));
    });

    test('all 6 dimensions are covered', () {
      final dims = comparison.insights.map((i) => i.dimension).toSet();
      expect(dims, containsAll(BenchmarkDimension.values));
    });

    test('disclaimer is non-empty', () {
      expect(comparison.disclaimer, isNotEmpty);
    });

    test('disclaimer contains LSFin reference', () {
      expect(comparison.disclaimer, contains('LSFin'));
    });

    test('disclaimer contains OFS reference', () {
      expect(comparison.disclaimer, contains('OFS'));
    });

    test('disclaimer contains "outil éducatif"', () {
      expect(comparison.disclaimer.toLowerCase(), contains('outil éducatif'));
    });
  });

  group('golden couple — Lauren (VS, 67000)', () {
    late BenchmarkComparison comparison;

    setUp(() {
      // Lauren: born 1982, canton VS, salary 67000/year = 5583/month
      final profile = _buildProfile(
        birthYear: 1982,
        canton: 'VS',
        salaireBrutMensuel: 5583,
        epargneLiquide: 14000,
        investissements: 19620,
        loyer: 1800,
        assuranceMaladie: 350,
      );
      comparison = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'VS',
      )!;
    });

    test('compare returns non-null for VS', () {
      expect(comparison, isNotNull);
    });

    test('income insight has correct user value', () {
      final income = comparison.insights
          .firstWhere((i) => i.dimension == BenchmarkDimension.income);
      expect(income.userValue, closeTo(5583 * 12, 1));
    });

    test('generates 6 insights', () {
      expect(comparison.insights.length, 6);
    });

    test('Lauren income differs from Julien income', () {
      // Lauren's income insight should differ from Julien's
      final income = comparison.insights
          .firstWhere((i) => i.dimension == BenchmarkDimension.income);
      // Lauren salary ~67k vs Julien ~122k — different user values
      expect(income.userValue, lessThan(100000));
    });

    test('disclaimer present and non-empty', () {
      expect(comparison.disclaimer.isNotEmpty, isTrue);
    });
  });

  group('unknown canton returns null', () {
    test('unknown canton code → null', () {
      final profile = _buildProfile();
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'XX',
      );
      expect(result, isNull);
    });

    test('empty canton code → null', () {
      final profile = _buildProfile();
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: '',
      );
      expect(result, isNull);
    });

    test('non-existent canton → null', () {
      final profile = _buildProfile();
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'NONEXISTENT',
      );
      expect(result, isNull);
    });
  });

  group('COMPLIANCE — no banned terms in output', () {
    test('disclaimer contains no banned terms', () {
      final profile = _buildProfile(canton: 'ZH', salaireBrutMensuel: 8000);
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'ZH',
      )!;
      final discLower = result.disclaimer.toLowerCase();

      for (final term in _bannedTerms) {
        // "conseil" in "ne constitue pas un conseil" is allowed
        // only "conseiller" (advisor noun/verb) is banned
        if (term == 'conseiller') {
          expect(discLower.contains('conseiller'), isFalse,
              reason: 'Banned term "conseiller" found in disclaimer');
        } else {
          expect(discLower.contains(term.toLowerCase()), isFalse,
              reason: 'Banned term "$term" found in disclaimer');
        }
      }
    });

    test('insight observationKeys contain no banned terms', () {
      const cantons = ['VS', 'ZH', 'GE', 'ZG', 'TI', 'VD'];
      for (final canton in cantons) {
        final profile = _buildProfile(canton: canton);
        final result = BenchmarkComparisonService.compare(
          profile: profile,
          cantonCode: canton,
        )!;

        for (final insight in result.insights) {
          final keyLower = insight.observationKey.toLowerCase();
          for (final term in _bannedTerms) {
            expect(keyLower.contains(term.toLowerCase()), isFalse,
                reason:
                    'Banned term "$term" in observationKey "${insight.observationKey}" '
                    'for canton $canton');
          }
        }
      }
    });

    test('insight params values contain no banned terms', () {
      final profile = _buildProfile(canton: 'GE', salaireBrutMensuel: 9000);
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'GE',
      )!;

      for (final insight in result.insights) {
        if (insight.params == null) continue;
        for (final val in insight.params!.values) {
          final valLower = val.toLowerCase();
          for (final term in _bannedTerms) {
            expect(valLower.contains(term.toLowerCase()), isFalse,
                reason:
                    'Banned term "$term" in param value "$val" '
                    'for insight ${insight.observationKey}');
          }
        }
      }
    });
  });

  group('COMPLIANCE — no ranking language in output', () {
    test('disclaimer contains no ranking language', () {
      final profile = _buildProfile(canton: 'ZH');
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'ZH',
      )!;
      final discLower = result.disclaimer.toLowerCase();

      for (final term in _bannedRankingTerms) {
        expect(discLower.contains(term.toLowerCase()), isFalse,
            reason: 'Ranking language "$term" found in disclaimer');
      }
    });

    test('observationKeys do not contain ranking language', () {
      const cantons = ['VS', 'ZH', 'GE', 'BE'];
      for (final canton in cantons) {
        final profile = _buildProfile(canton: canton);
        final result = BenchmarkComparisonService.compare(
          profile: profile,
          cantonCode: canton,
        )!;

        for (final insight in result.insights) {
          final keyLower = insight.observationKey.toLowerCase();
          for (final term in _bannedRankingTerms) {
            expect(keyLower.contains(term.toLowerCase()), isFalse,
                reason:
                    'Ranking language "$term" found in key "${insight.observationKey}"');
          }
        }
      }
    });

    test('insight params do not contain ranking language', () {
      final profile = _buildProfile(canton: 'VS', salaireBrutMensuel: 5000);
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'VS',
      )!;

      for (final insight in result.insights) {
        if (insight.params == null) continue;
        for (final val in insight.params!.values) {
          final valLower = val.toLowerCase();
          for (final term in _bannedRankingTerms) {
            expect(valLower.contains(term.toLowerCase()), isFalse,
                reason:
                    'Ranking language "$term" found in param "$val"');
          }
        }
      }
    });
  });

  group('observationKey validity', () {
    test('all observationKeys match ARB key format', () {
      const cantons = ['VS', 'ZH', 'GE', 'ZG', 'TI', 'VD', 'BE', 'NE'];
      for (final canton in cantons) {
        final profile = _buildProfile(canton: canton);
        final result = BenchmarkComparisonService.compare(
          profile: profile,
          cantonCode: canton,
        )!;

        for (final insight in result.insights) {
          expect(
            _isValidArbKey(insight.observationKey),
            isTrue,
            reason:
                'Invalid ARB key format: "${insight.observationKey}" '
                '(canton=$canton)',
          );
        }
      }
    });

    test('each dimension maps to a known ARB key', () {
      final profile = _buildProfile(canton: 'VS');
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'VS',
      )!;

      const expectedKeys = {
        BenchmarkDimension.income: 'benchmarkInsightIncome',
        BenchmarkDimension.savings: 'benchmarkInsightSavings',
        BenchmarkDimension.taxBurden: 'benchmarkInsightTax',
        BenchmarkDimension.housing: 'benchmarkInsightHousing',
        BenchmarkDimension.pillar3a: 'benchmarkInsight3a',
        BenchmarkDimension.lppCoverage: 'benchmarkInsightLpp',
      };

      for (final insight in result.insights) {
        expect(
          insight.observationKey,
          expectedKeys[insight.dimension],
          reason:
              'Wrong ARB key for dimension ${insight.dimension}: '
              'got "${insight.observationKey}", '
              'expected "${expectedKeys[insight.dimension]}"',
        );
      }
    });
  });

  group('tax level classification', () {
    test('ZG (very low tax) produces benchmarkTaxLevelBelow', () {
      final profile = _buildProfile(canton: 'ZG');
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'ZG',
      )!;
      final taxInsight = result.insights
          .firstWhere((i) => i.dimension == BenchmarkDimension.taxBurden);
      expect(taxInsight.params?['level'], 'benchmarkTaxLevelBelow');
    });

    test('GE (high tax) produces benchmarkTaxLevelAbove', () {
      final profile = _buildProfile(canton: 'GE');
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'GE',
      )!;
      final taxInsight = result.insights
          .firstWhere((i) => i.dimension == BenchmarkDimension.taxBurden);
      expect(taxInsight.params?['level'], 'benchmarkTaxLevelAbove');
    });

    test('ZH (average tax ~95) produces benchmarkTaxLevelAverage', () {
      final profile = _buildProfile(canton: 'ZH');
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'ZH',
      )!;
      final taxInsight = result.insights
          .firstWhere((i) => i.dimension == BenchmarkDimension.taxBurden);
      expect(taxInsight.params?['level'], 'benchmarkTaxLevelAverage');
    });
  });

  group('disclaimer always present', () {
    test('disclaimer non-empty for all known cantons', () {
      const cantons = ['VS', 'ZH', 'GE', 'ZG', 'TI', 'VD', 'BE', 'LU',
                       'NE', 'JU', 'FR', 'BS', 'BL', 'SH', 'AG', 'SG'];
      for (final canton in cantons) {
        final profile = _buildProfile(canton: canton);
        final result = BenchmarkComparisonService.compare(
          profile: profile,
          cantonCode: canton,
        );
        expect(result?.disclaimer.isNotEmpty, isTrue,
            reason: 'Disclaimer missing for $canton');
      }
    });
  });

  group('edge cases', () {
    test('zero income — no crash, savings rate is 0', () {
      final profile = _buildProfile(canton: 'VS', salaireBrutMensuel: 0);
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'VS',
      );
      expect(result, isNotNull);
      final savings = result!.insights
          .firstWhere((i) => i.dimension == BenchmarkDimension.savings);
      expect(savings.userValue, 0.0);
    });

    test('very high income — no crash', () {
      final profile = _buildProfile(canton: 'ZH', salaireBrutMensuel: 83333);
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'ZH',
      );
      expect(result, isNotNull);
    });

    test('lowercase canton code works (case-insensitive)', () {
      final profile = _buildProfile(canton: 'vs');
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'vs',
      );
      expect(result, isNotNull);
      expect(result!.cantonCode, 'VS');
    });

    test('difference field is computed correctly for income', () {
      // Julien ~122k vs VS median ~65k → difference ~57k
      final profile = _buildProfile(
        canton: 'VS',
        salaireBrutMensuel: 10184,
      );
      final result = BenchmarkComparisonService.compare(
        profile: profile,
        cantonCode: 'VS',
      )!;
      final income = result.insights
          .firstWhere((i) => i.dimension == BenchmarkDimension.income);
      expect(income.difference, closeTo(income.userValue - income.cantonMedian, 1));
    });
  });
}
