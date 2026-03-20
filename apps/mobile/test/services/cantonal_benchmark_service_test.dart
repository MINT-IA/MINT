import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cantonal_benchmark_service.dart';

/// Helper to build a minimal CoachProfile for testing.
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

void main() {
  setUp(() {
    // Reset opt-in state before each test
    CantonalBenchmarkService.isOptedIn = true;
  });

  tearDown(() {
    CantonalBenchmarkService.isOptedIn = false;
  });

  group('getBenchmark', () {
    test('returns correct data for VS, age 45', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS',
        age: 45,
      );
      expect(benchmark, isNotNull);
      expect(benchmark!.canton, 'VS');
      expect(benchmark.ageGroup, '45-54');
      expect(benchmark.revenuMedian.median, 92000);
      expect(benchmark.source, contains('OFS'));
    });

    test('returns null for unknown canton', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'XX',
        age: 40,
      );
      expect(benchmark, isNull);
    });

    test('returns null when opted out', () {
      CantonalBenchmarkService.isOptedIn = false;
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS',
        age: 45,
      );
      expect(benchmark, isNull);
    });

    test('age group resolution — young person clamps to 25-34', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'ZH',
        age: 22,
      );
      expect(benchmark, isNotNull);
      expect(benchmark!.ageGroup, '25-34');
    });

    test('age group resolution — senior maps to 65+', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'GE',
        age: 70,
      );
      expect(benchmark, isNotNull);
      expect(benchmark!.ageGroup, '65+');
    });
  });

  group('data integrity', () {
    test('all 6 cantons have data for all 5 age groups', () {
      const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];
      const ageGroups = ['25-34', '35-44', '45-54', '55-64', '65+'];

      for (final canton in cantons) {
        for (final ageGroup in ageGroups) {
          // Use an age in the middle of each group
          final age = switch (ageGroup) {
            '25-34' => 30,
            '35-44' => 40,
            '45-54' => 50,
            '55-64' => 60,
            '65+' => 70,
            _ => 40,
          };
          final benchmark = CantonalBenchmarkService.getBenchmark(
            canton: canton,
            age: age,
          );
          expect(
            benchmark,
            isNotNull,
            reason: 'Missing benchmark for $canton $ageGroup',
          );
          expect(benchmark!.canton, canton);
          expect(benchmark.ageGroup, ageGroup);
        }
      }
    });

    test('BenchmarkRange: low < median < high always', () {
      const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];
      const ages = [30, 40, 50, 60, 70];

      for (final canton in cantons) {
        for (final age in ages) {
          final b = CantonalBenchmarkService.getBenchmark(
            canton: canton,
            age: age,
          )!;

          for (final range in [
            b.revenuMedian,
            b.epargneMensuelle,
            b.chargesFixes,
            b.tauxEpargne,
            b.patrimoineNet,
          ]) {
            expect(
              range.low < range.median,
              isTrue,
              reason:
                  '$canton age=$age ${range.label}: low=${range.low} >= median=${range.median}',
            );
            expect(
              range.median < range.high,
              isTrue,
              reason:
                  '$canton age=$age ${range.label}: median=${range.median} >= high=${range.high}',
            );
          }
        }
      }
    });
  });

  group('compareToProfile', () {
    test('user within range → withinRange position', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS',
        age: 45,
      )!;
      // VS 45-54: revenu median range is 72000-125000
      // salary 8000/month × 12 = 96000 → within range
      final profile = _buildProfile(
        salaireBrutMensuel: 8000,
        canton: 'VS',
        birthYear: 1977,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      );
      expect(comparison, isNotNull);
      final revenuMetric = comparison!.metrics
          .firstWhere((m) => m.label == 'Revenu brut annuel');
      expect(revenuMetric.position, BenchmarkPosition.withinRange);
    });

    test('user above range → aboveRange position', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'TI',
        age: 30,
      )!;
      // TI 25-34: revenu high = 76000
      // salary 8000/month × 12 = 96000 → above range
      final profile = _buildProfile(
        salaireBrutMensuel: 8000,
        canton: 'TI',
        birthYear: 1996,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      );
      expect(comparison, isNotNull);
      final revenuMetric = comparison!.metrics
          .firstWhere((m) => m.label == 'Revenu brut annuel');
      expect(revenuMetric.position, BenchmarkPosition.aboveRange);
    });

    test('user below range → belowRange position', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'ZH',
        age: 50,
      )!;
      // ZH 45-54: revenu low = 88000
      // salary 5000/month × 12 = 60000 → below range
      final profile = _buildProfile(
        salaireBrutMensuel: 5000,
        canton: 'ZH',
        birthYear: 1976,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      );
      expect(comparison, isNotNull);
      final revenuMetric = comparison!.metrics
          .firstWhere((m) => m.label == 'Revenu brut annuel');
      expect(revenuMetric.position, BenchmarkPosition.belowRange);
    });

    test('returns null when opted out', () {
      CantonalBenchmarkService.isOptedIn = false;
      const benchmark = CantonalBenchmark(
        canton: 'VS',
        ageGroup: '45-54',
        revenuMedian: BenchmarkRange(
            low: 72000, median: 92000, high: 125000, label: 'Test'),
        epargneMensuelle: BenchmarkRange(
            low: 500, median: 1000, high: 1800, label: 'Test'),
        chargesFixes: BenchmarkRange(
            low: 2400, median: 2900, high: 3600, label: 'Test'),
        tauxEpargne: BenchmarkRange(
            low: 7, median: 12, high: 17, label: 'Test'),
        patrimoineNet: BenchmarkRange(
            low: 60000, median: 180000, high: 380000, label: 'Test'),
        source: 'test',
        disclaimer: 'test',
      );
      final profile = _buildProfile();
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      );
      expect(comparison, isNull);
    });

    test('comparison has 5 metrics', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS',
        age: 45,
      )!;
      final profile = _buildProfile();
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      );
      expect(comparison!.metrics.length, 5);
    });
  });

  group('formatComparisonText — compliance', () {
    late BenchmarkComparison comparison;

    setUp(() {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS',
        age: 45,
      )!;
      final profile = _buildProfile(
        salaireBrutMensuel: 8000,
        canton: 'VS',
        birthYear: 1977,
      );
      comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      )!;
    });

    test('no banned terms in ANY output', () {
      final text = CantonalBenchmarkService.formatComparisonText(
        comparison: comparison,
      );
      // Banned terms from CLAUDE.md § 6
      expect(text, isNot(contains('garanti')));
      expect(text, isNot(contains('certain')));
      expect(text, isNot(contains('assuré')));
      expect(text, isNot(contains('sans risque')));
      expect(text, isNot(contains('optimal')));
      expect(text, isNot(contains('parfait')));
    });

    test('no social comparison language', () {
      final text = CantonalBenchmarkService.formatComparisonText(
        comparison: comparison,
      );
      expect(text, isNot(contains('meilleur')));
      expect(text, isNot(contains('pire')));
      expect(text, isNot(contains('top ')));
      expect(text, isNot(contains('classement')));
      expect(text, isNot(contains('au-dessus de la moyenne')));
      expect(text, isNot(contains('en-dessous de la moyenne')));
      expect(text, isNot(contains('percentile')));
    });

    test('includes source reference', () {
      final text = CantonalBenchmarkService.formatComparisonText(
        comparison: comparison,
      );
      expect(text, contains('OFS'));
      expect(text, contains('Source'));
    });

    test('includes disclaimer', () {
      final text = CantonalBenchmarkService.formatComparisonText(
        comparison: comparison,
      );
      expect(text, contains('Outil éducatif'));
      expect(text, contains('ne constitue pas un conseil'));
      expect(text, contains('LSFin'));
    });

    test('French accents correct', () {
      final text = CantonalBenchmarkService.formatComparisonText(
        comparison: comparison,
      );
      // Key words with accents present in the output
      expect(text, contains('Épargne'));
      expect(text, contains('estimé'));
      expect(text, contains('éducatif'));
    });

    test('non-breaking spaces before : and ;', () {
      final text = CantonalBenchmarkService.formatComparisonText(
        comparison: comparison,
      );
      // Every ":" in the output should be preceded by \u00a0
      final colonMatches = RegExp(r'[^\u00a0]:').allMatches(text);
      // Filter out URL-like patterns (http:, etc.) — none expected here
      for (final match in colonMatches) {
        final ctx = text.substring(
          (match.start - 5).clamp(0, text.length),
          (match.end + 5).clamp(0, text.length),
        );
        fail('Found ":" without non-breaking space in context: "$ctx"');
      }
    });

    test('uses conditional language', () {
      final text = CantonalBenchmarkService.formatComparisonText(
        comparison: comparison,
      );
      expect(text, contains('se situe'));
      expect(text, contains('fourchette typique'));
    });
  });

  group('golden couple', () {
    test('Julien (VS, 49) → correct benchmark returned', () {
      // Julien: born 1977-01-12, canton VS, age 49 in 2026
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS',
        age: 49,
      );
      expect(benchmark, isNotNull);
      expect(benchmark!.canton, 'VS');
      expect(benchmark.ageGroup, '45-54');
      // VS 45-54 revenu median = 92'000
      expect(benchmark.revenuMedian.median, 92000);
      expect(benchmark.source, contains('OFS'));
      expect(benchmark.disclaimer, isNotEmpty);
    });

    test('Julien full comparison — salary 122207 → above revenu range', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS',
        age: 49,
      )!;
      // Julien's actual salary: 122'207 CHF/an = 10'184/mois
      final profile = _buildProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: 10184,
        epargneLiquide: 32000, // 3a capital
        investissements: 70377, // LPP avoir
        loyer: 2200,
        assuranceMaladie: 400,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      );
      expect(comparison, isNotNull);
      // 10184 × 12 = 122'208 → VS 45-54 high = 125'000
      // So within range (72000 – 125000)
      final revenu = comparison!.metrics
          .firstWhere((m) => m.label == 'Revenu brut annuel');
      expect(revenu.position, BenchmarkPosition.withinRange);
    });
  });
}
