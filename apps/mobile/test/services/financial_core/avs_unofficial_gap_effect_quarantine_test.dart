import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/circle_score.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/circle_scoring_service.dart';
import 'package:mint_mobile/services/expat_service.dart';

CoachProfile _profileWithCertifiedGapYears(
  Map<String, dynamic> answers,
  int years,
) {
  final base = CoachProfile.fromWizardAnswers(answers);
  return base.copyWith(
    prevoyance: base.prevoyance.copyWith(lacunesAVS: years),
    dataSources: {
      ...base.dataSources,
      AvsGapEvidence.selfFieldPath: ProfileDataSource.certificate,
    },
  );
}

String _source(String path) => File(path).readAsStringSync();

void main() {
  group('G1-AVS-03 mobile quarantine', () {
    test('gap-only public pricing helpers and the raw Expat percent are gone',
        () {
      final calculator = _source('lib/services/financial_core/avs_calculator.dart');
      final expat = _source('lib/services/expat_service.dart');

      for (final symbol in <String>[
        'computeMonthlyRente',
        'rawContributionDurationGapPercent',
        'reductionPercentageFromGap',
        'monthlyLossFromGap',
        'reductionPerMissingYear',
      ]) {
        expect(calculator, isNot(contains(symbol)),
            reason: '$symbol prices or proportions a gap without a caisse result');
      }
      expect(expat, isNot(contains('rawContributionDurationGapPercent')));
      expect(expat, isNot(contains('AvsCalculator.')));

      // G1-AVS-03 does not ban the official, scale-aware AVS-01 contract.
      expect(calculator, contains('computeCouplePensions'));
      expect(calculator, contains('contributionScale'));
      expect(calculator, contains('pensionPercentage'));
    });

    test('Expat orientation keeps null and zero distinct and returns counts only',
        () {
      for (final years in <int?>[null, 0, 2, 4, 9]) {
        final result = ExpatService.assessAvsGapOrientation(
          scenarioStarted: true,
          yearsAbroad: 7,
          ciObservedMissingContributionYears: years,
        )!;

        expect(result.yearsAbroadDeclared, 7);
        expect(result.ciObservedMissingContributionYears, years);
      }

      final contract = _source('lib/services/expat_service.dart');
      for (final forbiddenOutput in <String>[
        'rawContributionDurationGapPercent',
        'estimatedRente',
        'monthlyLoss',
        'annualLoss',
        'reductionPercent',
        'scoreTier',
      ]) {
        expect(contract, isNot(contains(forbiddenOutput)),
            reason: '$forbiddenOutput is not a count-only output');
      }
    });

    test('CI year count never changes an AVS score tier or total', () {
      final answers = <String, dynamic>{
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 7258.0,
        'q_employment_status': 'employee',
        'q_lpp_buyback_available': 0.0,
        'q_has_investments': 'no',
        'q_housing_status': 'renter',
      };
      final service = CircleScoringService();
      final percentages = <double>[];

      final baseline = service.calculateScore(
        answers,
        profile: CoachProfile.fromWizardAnswers(answers),
      );
      percentages.add(baseline.circle2Prevoyance.percentage);

      for (final years in <int>[0, 2, 4, 9]) {
        final score = service.calculateScore(
          answers,
          profile: _profileWithCertifiedGapYears(answers, years),
        );
        final avs = score.circle2Prevoyance.items
            .firstWhere((item) => item.label == 'AVS');
        expect(avs.status, ItemStatus.unknown);
        expect(avs.detail, contains('$years'));
        percentages.add(score.circle2Prevoyance.percentage);
      }

      expect(percentages.toSet(), hasLength(1));
      final circle = _source('lib/services/circle_scoring_service.dart');
      final start = circle.indexOf('final avsGapEvidence');
      final end = circle.indexOf('final percentage', start);
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final avsBlock = circle.substring(start, end);
      for (final forbidden in <String>[
        'ItemStatus.perfect',
        'ItemStatus.good',
        'ItemStatus.warning',
        'reductionPercentageFromGap',
        'scoreValue',
        'totalWeight +=',
        'totalScore +=',
      ]) {
        expect(avsBlock, isNot(contains(forbidden)),
            reason: 'a CI count cannot classify AVS readiness via $forbidden');
      }
    });

    test('known unsafe mobile surfaces contain no gap-priced personal claim',
        () {
      final forbiddenByFile = <String, List<String>>{
        'lib/data/education_content.dart': <String>[
          "premierEclairage: '2.3%'",
          'Reduction de ta rente AVS',
          'année manquante = rente réduite à vie',
          'Une seule année manquante la réduit définitivement',
        ],
        'lib/data/wizard_questions_v2.dart': <String>[
          'Chaque année manquante = −2.3% de rente à vie',
          'Chaque année manquante = -2.3',
          'Impact direct sur la rente AVS de couple',
          'Les années avant ton arrivée sont des lacunes AVS',
          'chaque année sans cotisation CH compte',
          'final expectedYears =',
        ],
        'lib/screens/expat_screen.dart': <String>[
          'Lacunes AVS → rente réduite',
          'Chaque année manquante réduit ta rente AVS de ~2.3%',
          '10 ans = −23% à vie',
        ],
        'lib/services/coach/local_fallback_service.dart': <String>[
          "réduit la rente d'environ 1/44e",
        ],
        'lib/services/coach_narrative_service.dart': <String>[
          'manquante reduit la rente de 1/44',
        ],
        'lib/services/financial_report_service.dart': <String>[
          "38'000 CHF de rente à vie",
        ],
        'lib/services/financial_fitness_service.dart': <String>[
          "id: 'avs_gaps'",
          'pointsForAvsGaps',
        ],
      };

      for (final entry in forbiddenByFile.entries) {
        final source = _source(entry.key);
        for (final forbidden in entry.value) {
          expect(source, isNot(contains(forbidden)),
              reason: '${entry.key} reintroduced ${jsonEncode(forbidden)}');
        }
      }
    });

    test('orphan pricing facades are deleted instead of left uncallable', () {
      expect(
        File('lib/widgets/visualizations/pension_completeness_ring.dart')
            .existsSync(),
        isFalse,
      );
      expect(
        _source('lib/data/financial_explanations.dart'),
        isNot(contains('avsGapExplanation')),
      );
    });

    test('all six ARB sources expose count-only CI and action copy', () {
      for (final locale in <String>['fr', 'en', 'de', 'es', 'it', 'pt']) {
        final arbFile = File('lib/l10n/app_$locale.arb');
        final arb = jsonDecode(arbFile.readAsStringSync())
            as Map<String, dynamic>;

        expect(arb, isNot(contains('expatAvsCiRawDurationBenchmark')));
        expect(arb, contains('expatAvsCiObservedMissingYearsBody'));
        final copy = <String>[
          arb['expatAvsCiObservedMissingYearsBody'] as String,
          arb['dataBlockAvsDesc'] as String,
          arb['pulseNavExpatGapsDetail'] as String,
          arb['reportActionDescAvsCheck'] as String,
        ].join(' ').toLowerCase();
        for (final forbidden in <String>[
          '2.3%',
          '2,3 %',
          '1/44',
          '38’000',
          '38 000',
          '38.000',
        ]) {
          expect(copy, isNot(contains(forbidden)),
              reason: 'app_$locale.arb reintroduced $forbidden');
        }
      }
    });
  });
}
