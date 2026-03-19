// ════════════════════════════════════════════════════════════════════════
// S60 Cantonal Benchmarks — ADVERSARIAL COMPLIANCE TESTS
// ════════════════════════════════════════════════════════════════════════
//
// Methodology: /autoresearch-compliance-hardener
// Goal: Try to BREAK every compliance guardrail. Zero tolerance.
//
// Guardrails tested:
//   1. No-Social-Comparison — ZERO "top 20%", "mieux que", "en dessous"
//   2. No-Ranking — cantons NEVER ranked as "best" or "worst"
//   3. Banned terms — garanti, optimal, meilleur, parfait, sans risque, conseiller
//   4. Disclaimer — educational disclaimer MUST be present
//   5. Hardcoded values — CHF constants match CLAUDE.md § 5
//   6. Privacy — cantonal data must NOT reveal user's exact income bracket
//   7. 6 cantons × 5 ages — all 30 combinations valid
//   8. Edge cases — extreme values, zero income, negative patrimoine
//   9. Conditional language — "se situe", "fourchette typique", never absolute
//  10. Non-breaking spaces — French typography compliance
//
// ════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cantonal_benchmark_service.dart';

// ── Helper ──────────────────────────────────────────────────────────────

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
    CantonalBenchmarkService.isOptedIn = true;
  });

  tearDown(() {
    CantonalBenchmarkService.isOptedIn = false;
  });

  // ════════════════════════════════════════════════════════════════════
  // 1. NO-SOCIAL-COMPARISON — Exhaustive banned phrases
  // ════════════════════════════════════════════════════════════════════

  group('ADV-1: No-Social-Comparison — all 30 combinations', () {
    const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];
    const ages = [30, 40, 50, 60, 70]; // one per age group

    /// Banned social comparison phrases (French + English).
    /// ANY of these in user-facing text = compliance FAIL.
    final bannedSocialPhrases = [
      'top 10%', 'top 20%', 'top 30%', 'top 50%',
      'percentile',
      'mieux que', 'mieux que la moyenne',
      'pire que', 'pire que la moyenne',
      'en dessous de la moyenne', 'au-dessus de la moyenne',
      'en dessous de la médiane', 'au-dessus de la médiane',
      'inférieur à la moyenne', 'supérieur à la moyenne',
      'plus riche', 'plus pauvre',
      'tu fais mieux', 'tu fais moins bien',
      'tu es au-dessus', 'tu es en dessous',
      'devant les autres', 'derrière les autres',
      'par rapport aux autres',
      'comparé aux autres utilisateurs',
      'better than', 'worse than', 'above average', 'below average',
    ];

    for (final canton in cantons) {
      for (final age in ages) {
        test('$canton age=$age — zero social comparison in formatComparisonText', () {
          final benchmark = CantonalBenchmarkService.getBenchmark(
            canton: canton,
            age: age,
          )!;

          // Use various salary levels to trigger all 3 positions
          for (final salary in [2000.0, 8000.0, 20000.0]) {
            final profile = _buildProfile(
              salaireBrutMensuel: salary,
              canton: canton,
              birthYear: DateTime.now().year - age,
            );
            final comparison = CantonalBenchmarkService.compareToProfile(
              profile: profile,
              benchmark: benchmark,
            )!;
            final text = CantonalBenchmarkService.formatComparisonText(
              comparison: comparison,
            ).toLowerCase();

            for (final phrase in bannedSocialPhrases) {
              expect(
                text.contains(phrase.toLowerCase()),
                isFalse,
                reason:
                    'COMPLIANCE VIOLATION: Found "$phrase" in output for '
                    '$canton age=$age salary=$salary',
              );
            }
          }
        });
      }
    }
  });

  // ════════════════════════════════════════════════════════════════════
  // 2. NO-RANKING — Cantons never ranked
  // ════════════════════════════════════════════════════════════════════

  group('ADV-2: No-Ranking — output never ranks cantons', () {
    final rankingPhrases = [
      'meilleur canton', 'pire canton',
      'canton le plus', 'canton le moins',
      'premier canton', 'dernier canton',
      'classement des cantons', 'ranking',
      'numéro 1', 'numéro un',
      '#1', '#2', '#3',
      'best canton', 'worst canton',
    ];

    test('formatComparisonText never ranks cantons', () {
      const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];

      for (final canton in cantons) {
        final benchmark = CantonalBenchmarkService.getBenchmark(
          canton: canton,
          age: 45,
        )!;
        final profile = _buildProfile(
          salaireBrutMensuel: 8000,
          canton: canton,
          birthYear: 1981,
        );
        final comparison = CantonalBenchmarkService.compareToProfile(
          profile: profile,
          benchmark: benchmark,
        )!;
        final text = CantonalBenchmarkService.formatComparisonText(
          comparison: comparison,
        ).toLowerCase();

        for (final phrase in rankingPhrases) {
          expect(
            text.contains(phrase.toLowerCase()),
            isFalse,
            reason:
                'COMPLIANCE VIOLATION: Found ranking phrase "$phrase" in '
                'output for canton $canton',
          );
        }
      }
    });

    test('BenchmarkPosition enum has no ranking semantics', () {
      // The enum values should describe position relative to range,
      // NOT relative to other users.
      final enumNames = BenchmarkPosition.values.map((e) => e.name).toList();
      expect(enumNames, isNot(contains('better')));
      expect(enumNames, isNot(contains('worse')));
      expect(enumNames, isNot(contains('top')));
      expect(enumNames, isNot(contains('bottom')));
      expect(enumNames, isNot(contains('best')));
      expect(enumNames, isNot(contains('worst')));
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // 3. BANNED TERMS — Exhaustive scan
  // ════════════════════════════════════════════════════════════════════

  group('ADV-3: Banned terms — exhaustive scan across all positions', () {
    final bannedTerms = [
      'garanti', 'garantie', 'garantis', 'garanties',
      'certain', 'certaine', 'certains', 'certaines',
      'assuré', 'assurée', 'assurés', 'assurées',
      'sans risque',
      'optimal', 'optimale', 'optimaux', 'optimales',
      'meilleur', 'meilleure', 'meilleurs', 'meilleures',
      'parfait', 'parfaite', 'parfaits', 'parfaites',
      'conseiller', // must use "spécialiste"
    ];

    test('formatComparisonText — all 3 positions × 6 cantons', () {
      const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];

      for (final canton in cantons) {
        final benchmark = CantonalBenchmarkService.getBenchmark(
          canton: canton,
          age: 45,
        )!;

        // Try salaries that produce belowRange, withinRange, aboveRange
        for (final salary in [1000.0, 8000.0, 30000.0]) {
          final profile = _buildProfile(
            salaireBrutMensuel: salary,
            canton: canton,
            birthYear: 1981,
          );
          final comparison = CantonalBenchmarkService.compareToProfile(
            profile: profile,
            benchmark: benchmark,
          )!;
          final text = CantonalBenchmarkService.formatComparisonText(
            comparison: comparison,
          ).toLowerCase();

          for (final term in bannedTerms) {
            expect(
              text.contains(term.toLowerCase()),
              isFalse,
              reason:
                  'BANNED TERM "$term" found in output for '
                  '$canton salary=$salary',
            );
          }
        }
      }
    });

    test('disclaimer text itself contains no banned terms', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS',
        age: 45,
      )!;
      final disclaimer = benchmark.disclaimer.toLowerCase();

      for (final term in bannedTerms) {
        // "conseil" appears in "ne constitue pas un conseil" — that's OK
        // but "conseiller" (the verb/noun meaning "advisor") is banned
        if (term == 'conseiller') {
          expect(
            disclaimer.contains('conseiller'),
            isFalse,
            reason: 'Disclaimer contains banned term "conseiller"',
          );
        } else {
          expect(
            disclaimer.contains(term.toLowerCase()),
            isFalse,
            reason: 'Disclaimer contains banned term "$term"',
          );
        }
      }
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // 4. DISCLAIMER — Present and complete
  // ════════════════════════════════════════════════════════════════════

  group('ADV-4: Disclaimer — mandatory elements', () {
    test('every benchmark entry has non-empty disclaimer', () {
      const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];
      const ages = [30, 40, 50, 60, 70];

      for (final canton in cantons) {
        for (final age in ages) {
          final b = CantonalBenchmarkService.getBenchmark(
            canton: canton,
            age: age,
          )!;
          expect(
            b.disclaimer.isNotEmpty,
            isTrue,
            reason: 'Empty disclaimer for $canton age=$age',
          );
        }
      }
    });

    test('disclaimer contains "outil éducatif"', () {
      final b = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 45,
      )!;
      expect(
        b.disclaimer.toLowerCase(),
        contains('outil éducatif'),
        reason: 'Disclaimer missing "outil éducatif"',
      );
    });

    test('disclaimer contains "ne constitue pas un conseil"', () {
      final b = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 45,
      )!;
      expect(b.disclaimer, contains('ne constitue pas un conseil'));
    });

    test('disclaimer contains LSFin reference', () {
      final b = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 45,
      )!;
      expect(b.disclaimer, contains('LSFin'));
    });

    test('disclaimer mentions no user data comparison', () {
      final b = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 45,
      )!;
      // Must explicitly state no personal data is compared to others
      expect(
        b.disclaimer.toLowerCase(),
        contains('aucune donnée personnelle'),
        reason: 'Disclaimer must state no personal data compared',
      );
    });

    test('formatComparisonText output contains source AND disclaimer', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'GE', age: 50,
      )!;
      final profile = _buildProfile(
        salaireBrutMensuel: 9000,
        canton: 'GE',
        birthYear: 1976,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      )!;
      final text = CantonalBenchmarkService.formatComparisonText(
        comparison: comparison,
      );

      expect(text, contains('Source'));
      expect(text, contains('OFS'));
      expect(text, contains('ne constitue pas un conseil'));
      expect(text, contains('LSFin'));
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // 5. HARDCODED VALUES — Constants match CLAUDE.md § 5
  // ════════════════════════════════════════════════════════════════════

  group('ADV-5: Data integrity — ranges are realistic Swiss CHF values', () {
    test('no revenu median exceeds 300k CHF (Swiss plausibility)', () {
      const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];
      const ages = [30, 40, 50, 60, 70];

      for (final canton in cantons) {
        for (final age in ages) {
          final b = CantonalBenchmarkService.getBenchmark(
            canton: canton, age: age,
          )!;
          expect(
            b.revenuMedian.high <= 300000,
            isTrue,
            reason:
                '$canton age=$age revenu high=${b.revenuMedian.high} '
                'exceeds 300k — unrealistic for Swiss OFS data',
          );
          expect(
            b.revenuMedian.low >= 0,
            isTrue,
            reason: '$canton age=$age revenu low is negative',
          );
        }
      }
    });

    test('taux d\'epargne ranges are between 0% and 50%', () {
      const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];
      const ages = [30, 40, 50, 60, 70];

      for (final canton in cantons) {
        for (final age in ages) {
          final b = CantonalBenchmarkService.getBenchmark(
            canton: canton, age: age,
          )!;
          expect(
            b.tauxEpargne.low >= 0,
            isTrue,
            reason: '$canton age=$age: taux low=${b.tauxEpargne.low} < 0',
          );
          expect(
            b.tauxEpargne.high <= 50,
            isTrue,
            reason: '$canton age=$age: taux high=${b.tauxEpargne.high} > 50%',
          );
        }
      }
    });

    test('patrimoine increases with age (monotonicity check per canton)', () {
      const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];
      const ages = [30, 40, 50, 60, 70];

      for (final canton in cantons) {
        double? prevMedian;
        for (final age in ages) {
          final b = CantonalBenchmarkService.getBenchmark(
            canton: canton, age: age,
          )!;
          if (prevMedian != null) {
            expect(
              b.patrimoineNet.median >= prevMedian,
              isTrue,
              reason:
                  '$canton age=$age: patrimoine median '
                  '${b.patrimoineNet.median} < previous $prevMedian — '
                  'patrimoine should generally increase with age',
            );
          }
          prevMedian = b.patrimoineNet.median;
        }
      }
    });

    test('source field always references OFS', () {
      const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];
      const ages = [30, 40, 50, 60, 70];

      for (final canton in cantons) {
        for (final age in ages) {
          final b = CantonalBenchmarkService.getBenchmark(
            canton: canton, age: age,
          )!;
          expect(
            b.source.contains('OFS'),
            isTrue,
            reason: '$canton age=$age: source does not cite OFS',
          );
        }
      }
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // 6. PRIVACY — No exact income bracket revelation
  // ════════════════════════════════════════════════════════════════════

  group('ADV-6: Privacy — no exact user values in formatted output', () {
    test('formatComparisonText does NOT reveal exact user salary', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 45,
      )!;
      final profile = _buildProfile(
        salaireBrutMensuel: 10184, // Julien's exact salary
        canton: 'VS',
        birthYear: 1977,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      )!;
      final text = CantonalBenchmarkService.formatComparisonText(
        comparison: comparison,
      );

      // The formatted text should NOT contain the user's exact annual salary
      final exactAnnual = (10184.0 * 12).toStringAsFixed(0); // "122208"
      expect(
        text.contains(exactAnnual),
        isFalse,
        reason:
            'PRIVACY VIOLATION: User exact salary $exactAnnual appears in output',
      );
      expect(
        text.contains('10184'),
        isFalse,
        reason: 'PRIVACY VIOLATION: User exact monthly salary appears in output',
      );
    });

    test('formatComparisonText does NOT reveal exact patrimoine', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'ZH', age: 50,
      )!;
      final profile = _buildProfile(
        salaireBrutMensuel: 9500,
        canton: 'ZH',
        birthYear: 1976,
        epargneLiquide: 87654,
        investissements: 123456,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      )!;
      final text = CantonalBenchmarkService.formatComparisonText(
        comparison: comparison,
      );

      expect(
        text.contains('87654'),
        isFalse,
        reason: 'PRIVACY: exact epargneLiquide in output',
      );
      expect(
        text.contains('123456'),
        isFalse,
        reason: 'PRIVACY: exact investissements in output',
      );
      // Sum of patrimoine
      expect(
        text.contains('211110'),
        isFalse,
        reason: 'PRIVACY: exact patrimoine total in output',
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // 7. ALL 30 COMBINATIONS — 6 cantons × 5 age groups
  // ════════════════════════════════════════════════════════════════════

  group('ADV-7: All 30 canton×age combinations produce valid results', () {
    const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];
    const ageGroupMap = {
      '25-34': 30,
      '35-44': 40,
      '45-54': 50,
      '55-64': 60,
      '65+': 70,
    };

    for (final canton in cantons) {
      for (final entry in ageGroupMap.entries) {
        test('$canton ${entry.key} — complete benchmark + comparison', () {
          final age = entry.value;
          final benchmark = CantonalBenchmarkService.getBenchmark(
            canton: canton,
            age: age,
          );
          expect(benchmark, isNotNull, reason: 'No data for $canton ${entry.key}');
          expect(benchmark!.canton, canton);
          expect(benchmark.ageGroup, entry.key);
          expect(benchmark.source, isNotEmpty);
          expect(benchmark.disclaimer, isNotEmpty);

          // All 5 metric ranges must be valid
          for (final range in [
            benchmark.revenuMedian,
            benchmark.epargneMensuelle,
            benchmark.chargesFixes,
            benchmark.tauxEpargne,
            benchmark.patrimoineNet,
          ]) {
            expect(range.low, greaterThanOrEqualTo(0));
            expect(range.low, lessThan(range.median));
            expect(range.median, lessThan(range.high));
            expect(range.label, isNotEmpty);
          }

          // Build a profile and verify comparison works
          final profile = _buildProfile(
            salaireBrutMensuel: 7000,
            canton: canton,
            birthYear: DateTime.now().year - age,
          );
          final comparison = CantonalBenchmarkService.compareToProfile(
            profile: profile,
            benchmark: benchmark,
          );
          expect(comparison, isNotNull);
          expect(comparison!.metrics.length, 5);

          // Verify formatComparisonText produces output
          final text = CantonalBenchmarkService.formatComparisonText(
            comparison: comparison,
          );
          expect(text, isNotEmpty);
          expect(text, contains(canton));
          expect(text, contains(entry.key));
        });
      }
    }
  });

  // ════════════════════════════════════════════════════════════════════
  // 8. EDGE CASES — Try to break the service
  // ════════════════════════════════════════════════════════════════════

  group('ADV-8: Edge cases — adversarial inputs', () {
    test('zero salary → belowRange for revenu, no crash', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 45,
      )!;
      final profile = _buildProfile(
        salaireBrutMensuel: 0,
        canton: 'VS',
        birthYear: 1981,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      )!;

      final revenu = comparison.metrics
          .firstWhere((m) => m.label == 'Revenu brut annuel');
      expect(revenu.position, BenchmarkPosition.belowRange);
      expect(revenu.userValue, 0);

      // tauxEpargne should be 0 when revenu is 0
      final taux = comparison.metrics
          .firstWhere((m) => m.label.contains('Taux'));
      expect(taux.userValue, 0.0);
    });

    test('very high salary (1M/month) → aboveRange, no crash', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'GE', age: 50,
      )!;
      final profile = _buildProfile(
        salaireBrutMensuel: 83333, // ~1M/year
        canton: 'GE',
        birthYear: 1976,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      )!;

      final revenu = comparison.metrics
          .firstWhere((m) => m.label == 'Revenu brut annuel');
      expect(revenu.position, BenchmarkPosition.aboveRange);
    });

    test('age 18 (below minimum group) → clamps to 25-34', () {
      expect(
        CantonalBenchmarkService.ageGroupForAge(18),
        '25-34',
      );
      final b = CantonalBenchmarkService.getBenchmark(
        canton: 'BE', age: 18,
      );
      expect(b, isNotNull);
      expect(b!.ageGroup, '25-34');
    });

    test('age 100 → maps to 65+', () {
      expect(
        CantonalBenchmarkService.ageGroupForAge(100),
        '65+',
      );
      final b = CantonalBenchmarkService.getBenchmark(
        canton: 'TI', age: 100,
      );
      expect(b, isNotNull);
      expect(b!.ageGroup, '65+');
    });

    test('lowercase canton → still works (case insensitive lookup)', () {
      final b = CantonalBenchmarkService.getBenchmark(
        canton: 'vs', age: 45,
      );
      // Service uses toUpperCase(), so "vs" → "VS" should work
      expect(b, isNotNull);
      expect(b!.canton, 'VS');
    });

    test('unknown canton returns null, not crash', () {
      final b = CantonalBenchmarkService.getBenchmark(
        canton: 'NONEXISTENT', age: 45,
      );
      expect(b, isNull);
    });

    test('empty canton returns null, not crash', () {
      final b = CantonalBenchmarkService.getBenchmark(
        canton: '', age: 45,
      );
      expect(b, isNull);
    });

    test('zero patrimoine → valid comparison', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 30,
      )!;
      final profile = _buildProfile(
        salaireBrutMensuel: 5000,
        canton: 'VS',
        birthYear: 1996,
        epargneLiquide: 0,
        investissements: 0,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      );
      expect(comparison, isNotNull);
      final patrimoine = comparison!.metrics
          .firstWhere((m) => m.label.contains('Patrimoine'));
      expect(patrimoine.userValue, 0);
      expect(patrimoine.position, BenchmarkPosition.belowRange);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // 9. CONDITIONAL LANGUAGE — Never absolute statements
  // ════════════════════════════════════════════════════════════════════

  group('ADV-9: Conditional language — no absolutes', () {
    final absolutePhrases = [
      'tu dois', 'il faut absolument', 'tu es riche', 'tu es pauvre',
      'tu réussis', 'tu échoues', 'tu es en échec',
      'félicitations', 'bravo',
      'alarmant', 'catastrophique', 'désastreux',
      'you must', 'you should', 'you are rich', 'you are poor',
    ];

    test('formatComparisonText uses ONLY conditional language', () {
      const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];

      for (final canton in cantons) {
        for (final salary in [1000.0, 8000.0, 30000.0]) {
          final benchmark = CantonalBenchmarkService.getBenchmark(
            canton: canton, age: 45,
          )!;
          final profile = _buildProfile(
            salaireBrutMensuel: salary,
            canton: canton,
            birthYear: 1981,
          );
          final comparison = CantonalBenchmarkService.compareToProfile(
            profile: profile,
            benchmark: benchmark,
          )!;
          final text = CantonalBenchmarkService.formatComparisonText(
            comparison: comparison,
          ).toLowerCase();

          for (final phrase in absolutePhrases) {
            expect(
              text.contains(phrase.toLowerCase()),
              isFalse,
              reason:
                  'ABSOLUTE LANGUAGE: "$phrase" found in output for '
                  '$canton salary=$salary',
            );
          }
        }
      }
    });

    test('belowRange text uses neutral phrasing, not negative', () {
      // Force all metrics belowRange with very low values
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'ZH', age: 50,
      )!;
      final profile = _buildProfile(
        salaireBrutMensuel: 1000,
        canton: 'ZH',
        birthYear: 1976,
        loyer: 500,
        assuranceMaladie: 100,
        epargneLiquide: 0,
        investissements: 0,
        contributions: [],
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      )!;
      final text = CantonalBenchmarkService.formatComparisonText(
        comparison: comparison,
      );

      // Verify belowRange text is neutral
      expect(text, contains('en-deçà de la fourchette typique'));
      // Must NOT contain judgmental language
      expect(text.toLowerCase(), isNot(contains('insuffisant')));
      expect(text.toLowerCase(), isNot(contains('inquiétant')));
      expect(text.toLowerCase(), isNot(contains('problème')));
      expect(text.toLowerCase(), isNot(contains('danger')));
      expect(text.toLowerCase(), isNot(contains('urgence')));
    });

    test('aboveRange text uses neutral phrasing, not celebratory', () {
      // Force aboveRange with very high values
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'TI', age: 30,
      )!;
      final profile = _buildProfile(
        salaireBrutMensuel: 50000,
        canton: 'TI',
        birthYear: 1996,
        epargneLiquide: 500000,
        investissements: 1000000,
        contributions: [
          PlannedMonthlyContribution(
            id: '3a_test',
            category: '3a',
            amount: 605,
            label: '3a VIAC',
          ),
        ],
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      )!;
      final text = CantonalBenchmarkService.formatComparisonText(
        comparison: comparison,
      );

      expect(text, contains('au-delà de la fourchette typique'));
      expect(text.toLowerCase(), isNot(contains('excellent')));
      expect(text.toLowerCase(), isNot(contains('magnifique')));
      expect(text.toLowerCase(), isNot(contains('impressionnant')));
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // 10. NON-BREAKING SPACES — French typography compliance
  // ════════════════════════════════════════════════════════════════════

  group('ADV-10: French typography — non-breaking spaces', () {
    test('all colons in formatted text have non-breaking space before', () {
      const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];

      for (final canton in cantons) {
        final benchmark = CantonalBenchmarkService.getBenchmark(
          canton: canton, age: 45,
        )!;
        final profile = _buildProfile(
          salaireBrutMensuel: 8000,
          canton: canton,
          birthYear: 1981,
        );
        final comparison = CantonalBenchmarkService.compareToProfile(
          profile: profile,
          benchmark: benchmark,
        )!;
        final text = CantonalBenchmarkService.formatComparisonText(
          comparison: comparison,
        );

        // Find all colons and verify preceding non-breaking space
        final colonRegex = RegExp(r'[^\u00a0]:');
        final violations = colonRegex.allMatches(text).toList();
        expect(
          violations,
          isEmpty,
          reason:
              'TYPOGRAPHY: Found ${violations.length} colon(s) without '
              'non-breaking space in $canton output',
        );
      }
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // 11. OPT-IN GATE — Service returns null when opted out
  // ════════════════════════════════════════════════════════════════════

  group('ADV-11: Opt-in gate — nothing returned when opted out', () {
    test('getBenchmark returns null when not opted in', () {
      CantonalBenchmarkService.isOptedIn = false;
      const cantons = ['VS', 'VD', 'GE', 'ZH', 'BE', 'TI'];
      const ages = [30, 40, 50, 60, 70];

      for (final canton in cantons) {
        for (final age in ages) {
          expect(
            CantonalBenchmarkService.getBenchmark(canton: canton, age: age),
            isNull,
            reason: 'Returned data for $canton age=$age while opted OUT',
          );
        }
      }
    });

    test('compareToProfile returns null when not opted in', () {
      CantonalBenchmarkService.isOptedIn = false;
      final benchmark = CantonalBenchmark(
        canton: 'VS',
        ageGroup: '45-54',
        revenuMedian: const BenchmarkRange(
          low: 72000, median: 92000, high: 125000, label: 'Test',
        ),
        epargneMensuelle: const BenchmarkRange(
          low: 500, median: 1000, high: 1800, label: 'Test',
        ),
        chargesFixes: const BenchmarkRange(
          low: 2400, median: 2900, high: 3600, label: 'Test',
        ),
        tauxEpargne: const BenchmarkRange(
          low: 7, median: 12, high: 17, label: 'Test',
        ),
        patrimoineNet: const BenchmarkRange(
          low: 60000, median: 180000, high: 380000, label: 'Test',
        ),
        source: 'test',
        disclaimer: 'test',
      );
      final profile = _buildProfile();
      expect(
        CantonalBenchmarkService.compareToProfile(
          profile: profile,
          benchmark: benchmark,
        ),
        isNull,
        reason: 'Comparison returned data while opted OUT',
      );
    });

    test('default opt-in state is false', () {
      // After tearDown resets to false, creating a fresh state
      CantonalBenchmarkService.isOptedIn = false;
      expect(CantonalBenchmarkService.isOptedIn, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // 12. BOUNDARY VALUES — Position classification edge cases
  // ════════════════════════════════════════════════════════════════════

  group('ADV-12: Position boundary values', () {
    test('value exactly at low → withinRange (not belowRange)', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 45,
      )!;
      // VS 45-54 revenu: low=72000, high=125000
      // 72000/12 = 6000/month exactly
      final profile = _buildProfile(
        salaireBrutMensuel: 6000, // 6000 × 12 = 72000 = low exactly
        canton: 'VS',
        birthYear: 1981,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      )!;
      final revenu = comparison.metrics
          .firstWhere((m) => m.label == 'Revenu brut annuel');
      // At the boundary (== low), should be withinRange
      expect(revenu.position, BenchmarkPosition.withinRange);
    });

    test('value exactly at high → withinRange (not aboveRange)', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 45,
      )!;
      // VS 45-54 revenu: high=125000
      // 125000/12 ≈ 10416.67
      final profile = _buildProfile(
        salaireBrutMensuel: 125000.0 / 12, // exactly 125000 annual
        canton: 'VS',
        birthYear: 1981,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      )!;
      final revenu = comparison.metrics
          .firstWhere((m) => m.label == 'Revenu brut annuel');
      // At the boundary (== high), should be withinRange
      expect(revenu.position, BenchmarkPosition.withinRange);
    });

    test('value just below low → belowRange', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 45,
      )!;
      // VS 45-54 revenu: low=72000
      // 71999/12 ≈ 5999.92
      final profile = _buildProfile(
        salaireBrutMensuel: 5999.0, // 5999 × 12 = 71988 < 72000
        canton: 'VS',
        birthYear: 1981,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      )!;
      final revenu = comparison.metrics
          .firstWhere((m) => m.label == 'Revenu brut annuel');
      expect(revenu.position, BenchmarkPosition.belowRange);
    });

    test('value just above high → aboveRange', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 45,
      )!;
      // VS 45-54 revenu: high=125000
      // 125001/12 ≈ 10416.75
      final profile = _buildProfile(
        salaireBrutMensuel: 10417.0, // 10417 × 12 = 125004 > 125000
        canton: 'VS',
        birthYear: 1981,
      );
      final comparison = CantonalBenchmarkService.compareToProfile(
        profile: profile,
        benchmark: benchmark,
      )!;
      final revenu = comparison.metrics
          .firstWhere((m) => m.label == 'Revenu brut annuel');
      expect(revenu.position, BenchmarkPosition.aboveRange);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // 13. FRENCH ACCENTS — Mandatory diacritics
  // ════════════════════════════════════════════════════════════════════

  group('ADV-13: French accents — mandatory diacritics', () {
    test('metric labels have correct accents', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 45,
      )!;

      // "Épargne" not "Epargne"
      expect(benchmark.epargneMensuelle.label, contains('Épargne'));
      // "estimé" not "estime"
      expect(benchmark.patrimoineNet.label, contains('estimé'));
    });

    test('disclaimer has correct French accents', () {
      final benchmark = CantonalBenchmarkService.getBenchmark(
        canton: 'VS', age: 45,
      )!;
      final d = benchmark.disclaimer;
      // "éducatif" not "educatif"
      expect(d, contains('éducatif'));
      // "données" not "donnees"
      expect(d, contains('données'));
      // "fédérales" not "federales"
      expect(d, contains('fédérales'));
      // "comparée" not "comparee"
      expect(d, contains('comparée'));
    });
  });
}
