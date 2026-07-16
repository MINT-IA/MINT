import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mandatoryMintDisclaimer =
    'Les résultats présentés sont des estimations à titre indicatif, '
    'basées sur les données fournies et la législation en vigueur. '
    'Ils ne constituent pas un conseil financier personnalisé. '
    'Consultez un·e spécialiste pour votre situation spécifique.';

CoachProfile _profile({
  FinancialLiteracyLevel literacy = FinancialLiteracyLevel.beginner,
}) {
  return CoachProfile(
    birthYear: 1986,
    dateOfBirth: DateTime(1986, 2, 14),
    canton: 'VD',
    salaireBrutMensuel: 8000,
    nombreDeMois: 12,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 150000,
      avoirLppObligatoire: 100000,
      avoirLppSurobligatoire: 50000,
      rendementCaisse: 0,
      totalEpargne3a: 30000,
    ),
    goalA: GoalA(
      type: GoalAType.custom,
      targetDate: DateTime(2051, 2, 1),
      label: 'Objectif synthétique',
    ),
    financialLiteracyLevel: literacy,
    dataSources: const {
      'salaireBrutMensuel': ProfileDataSource.userInput,
      'canton': ProfileDataSource.userInput,
      'dateOfBirth': ProfileDataSource.userInput,
      'prevoyance.avoirLppTotal': ProfileDataSource.userInput,
      'prevoyance.avoirLppObligatoire': ProfileDataSource.userInput,
      'prevoyance.avoirLppSurobligatoire': ProfileDataSource.userInput,
      'prevoyance.rendementCaisse': ProfileDataSource.userInput,
      'prevoyance.totalEpargne3a': ProfileDataSource.userInput,
    },
    dataTimestamps: {
      for (final path in const [
        'salaireBrutMensuel',
        'canton',
        'dateOfBirth',
        'prevoyance.avoirLppTotal',
        'prevoyance.avoirLppObligatoire',
        'prevoyance.avoirLppSurobligatoire',
        'prevoyance.rendementCaisse',
        'prevoyance.totalEpargne3a',
      ])
        path: DateTime(2026, 7, 1),
    },
    inferDataSources: false,
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
  );
}

DateTime _targetInMonths(int months) {
  final now = DateTime.now();
  return DateTime(now.year, now.month + months, now.day);
}

Future<FinancialPlan> _simplePlan() {
  return PlanGenerationService.generate(
    goalDescription: 'Constituer une réserve synthétique',
    goalCategory: 'goal_general',
    targetDate: _targetInMonths(24),
    profile: _profile(),
    goalAmount: 24000,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('G1-BND-06 domain RED — calculator contract', () {
    test('generate fails closed without a user-owned goal amount', () async {
      expect(
        () => PlanGenerationService.generate(
          goalDescription: 'Objectif sans montant',
          goalCategory: 'goal_general',
          targetDate: _targetInMonths(24),
          profile: _profile(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a simple deadline plan has no invented uncertainty band', () async {
      final plan = await _simplePlan();

      expect(
        plan.projectedLow,
        isNull,
        reason: 'Goal divided by remaining months has no ±15% model.',
      );
      expect(
        plan.projectedHigh,
        isNull,
        reason: 'Goal divided by remaining months has no ±15% model.',
      );
    });

    test('a simple deadline plan has no decorative legal citation', () async {
      final plan = await _simplePlan();
      final legalCitation = RegExp(
        r'\b(?:LIFD|LPP|LAVS|OPP2|OPP3|LHID)\b.*\bart\.?\b',
        caseSensitive: false,
      );

      expect(
        plan.sources.where(legalCitation.hasMatch),
        isEmpty,
        reason: 'A pure goal/month calculation applies no Swiss legal rule.',
      );
    });

    test('every generated plan carries the full mandatory MINT disclaimer',
        () async {
      final plan = await _simplePlan();

      expect(plan.disclaimer, _mandatoryMintDisclaimer);
    });

    test('retirement golden keeps capital and time dimensions aligned',
        () async {
      final now = DateTime.now();
      final profile = CoachProfile(
        birthYear: now.year - 40,
        dateOfBirth: DateTime(now.year - 40, now.month, 1),
        canton: 'VD',
        // CHF 12'000/year is below the 2026 LPP entry threshold. The supplied
        // balances remain the only retirement capital in this synthetic case.
        salaireBrutMensuel: 1000,
        nombreDeMois: 12,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 150000,
          avoirLppObligatoire: 100000,
          avoirLppSurobligatoire: 50000,
          rendementCaisse: 0,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: _targetInMonths(300),
          label: 'Retraite synthétique',
        ),
        financialLiteracyLevel: FinancialLiteracyLevel.advanced,
        dataSources: const {
          'salaireBrutMensuel': ProfileDataSource.userInput,
          'dateOfBirth': ProfileDataSource.userInput,
          'prevoyance.avoirLppTotal': ProfileDataSource.userInput,
          'prevoyance.avoirLppObligatoire': ProfileDataSource.userInput,
          'prevoyance.avoirLppSurobligatoire': ProfileDataSource.userInput,
          'prevoyance.rendementCaisse': ProfileDataSource.userInput,
        },
        dataTimestamps: {
          for (final path in const [
            'salaireBrutMensuel',
            'dateOfBirth',
            'prevoyance.avoirLppTotal',
            'prevoyance.avoirLppObligatoire',
            'prevoyance.avoirLppSurobligatoire',
            'prevoyance.rendementCaisse',
          ])
            path: now,
        },
        inferDataSources: false,
      );

      final plan = await PlanGenerationService.generate(
        goalDescription: 'Capital retraite synthétique',
        goalCategory: 'goal_retirement_plan',
        targetDate: _targetInMonths(300),
        profile: profile,
        goalAmount: 300000,
        prospectiveLppReturn: 0.02,
      );

      expect(
        plan.monthlyTarget,
        closeTo((300000 - 150000 * math.pow(1.02, 25)) / 300, 0.01),
        reason: 'The user-selected 2% scenario compounds current LPP capital '
            'over 25 years; only the remaining CHF gap is divided by 300 '
            'months. Capital and time dimensions stay aligned.',
      );
    });

    test('retirement sources name only rules used by capital projection',
        () async {
      final plan = await PlanGenerationService.generate(
        goalDescription: 'Capital retraite synthétique',
        goalCategory: 'goal_retirement_plan',
        targetDate: _targetInMonths(300),
        profile: _profile(),
        goalAmount: 300000,
        prospectiveLppReturn: 0.02,
      );

      final hasLppArticle8 =
          plan.sources.any((source) => source.contains('LPP art. 8'));
      final hasLppArticle15Or16 = plan.sources.any(
        (source) =>
            source.contains('LPP art. 15') || source.contains('LPP art. 16'),
      );
      final hasLifdArticle38 =
          plan.sources.any((source) => source.contains('LIFD art. 38'));
      final hasLppArticle14 =
          plan.sources.any((source) => source.contains('LPP art. 14'));
      const reason = 'This branch projects capital accumulation; it neither '
          'taxes a withdrawal nor converts capital to a pension.';

      expect(hasLppArticle8, isTrue, reason: reason);
      expect(hasLppArticle15Or16, isTrue, reason: reason);
      expect(hasLifdArticle38, isFalse, reason: reason);
      expect(hasLppArticle14, isFalse, reason: reason);
    });

    test('plan confidence equals the canonical EnhancedConfidence score',
        () async {
      final profile = _profile();
      final expected = ConfidenceScorer.scoreEnhanced(profile).combined;

      final plan = await PlanGenerationService.generate(
        goalDescription: 'Objectif synthétique',
        goalCategory: 'goal_general',
        targetDate: _targetInMonths(24),
        profile: profile,
        goalAmount: 24000,
      );

      expect(plan.confidenceLevel, closeTo(expected, 0.000001));
    });

    test('the plan-input fingerprint is explicitly version 2', () {
      expect(
        computeProfileHash(_profile()),
        startsWith('mint-plan-input:v2:sha256:'),
      );
    });

    test('a confidence-relevant mutation also invalidates the fingerprint', () {
      final beginner = _profile();
      final advanced = _profile(literacy: FinancialLiteracyLevel.advanced);

      expect(
        ConfidenceScorer.scoreEnhanced(advanced).combined,
        isNot(ConfidenceScorer.scoreEnhanced(beginner).combined),
        reason: 'Financial literacy changes the canonical understanding axis.',
      );
      expect(
        computeProfileHash(advanced),
        isNot(computeProfileHash(beginner)),
        reason: 'A displayed plan-confidence change must make the plan stale.',
      );
    });

    test('generation is side-effect free and provider alone persists the plan',
        () async {
      final generated = await _simplePlan();

      expect(
        await FinancialPlanService.loadCurrent(),
        isNull,
        reason:
            'PlanGenerationService must not bypass the provider save queue.',
      );

      final provider = FinancialPlanProvider();
      addTearDown(provider.dispose);
      await provider.setPlan(generated);
      expect((await FinancialPlanService.loadCurrent())?.id, generated.id);
    });
  });
}
