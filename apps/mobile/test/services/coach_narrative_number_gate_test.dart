import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/fallback_templates.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

CoachProfile _profileWithOpen3aMargin({
  String canton = 'VD',
  double salaireBrutMensuel = 7000,
  String employmentStatus = 'salarie',
  double monthly3a = 300,
  double? avoirLppTotal = 80000,
}) {
  return CoachProfile(
    firstName: 'Julien',
    birthYear: 1990,
    canton: canton,
    salaireBrutMensuel: salaireBrutMensuel,
    employmentStatus: employmentStatus,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055, 12, 31),
      label: 'Retraite a 65 ans',
    ),
    prevoyance: PrevoyanceProfile(
      nombre3a: 1,
      totalEpargne3a: 15000,
      avoirLppTotal: avoirLppTotal,
    ),
    depenses: const DepensesProfile(
      loyer: 1500,
      assuranceMaladie: 400,
    ),
    plannedContributions: [
      PlannedMonthlyContribution(
        id: '3a_user',
        label: '3a Julien',
        amount: monthly3a,
        category: '3a',
      ),
    ],
  );
}

void main() {
  group('CoachNarrativeService number gate', () {
    test('3a deadline alert exposes structured tax-impact assumptions', () {
      final profile = _profileWithOpen3aMargin();
      final remaining = RetirementTaxCalculator.estimate3aTaxImpact(
            grossAnnualSalary: profile.revenuBrutAnnuel,
            canton: profile.canton,
            contribution: null,
          ).deductibleContribution -
          profile.total3aMensuel * 12;
      final expectedImpact = RetirementTaxCalculator.estimate3aTaxImpact(
        grossAnnualSalary: profile.revenuBrutAnnuel,
        canton: profile.canton,
        contribution: remaining,
      );
      expect(
        expectedImpact.deductibleContribution,
        isNot(expectedImpact.estimatedTaxSaving),
      );
      expect(
        formatChfWithPrefix(expectedImpact.deductibleContribution),
        isNot(formatChfWithPrefix(expectedImpact.estimatedTaxSaving)),
      );

      final alert = CoachNarrativeService.build3aDeadlineAlertForTest(
        profile: profile,
        now: DateTime(2026, 12),
      );

      expect(alert, isNotNull);
      expect(alert, contains('3a'));
      expect(
        alert,
        contains(
          'Il te reste 30 jours pour verser '
          '${formatChfWithPrefix(expectedImpact.deductibleContribution)} '
          'en 3a.',
        ),
      );
      expect(
        alert,
        isNot(
          contains(
            'verser ${formatChfWithPrefix(expectedImpact.estimatedTaxSaving)} '
            'en 3a',
          ),
        ),
      );
      expect(
        alert,
        contains(
          'Impact fiscal indicatif: '
          '~${formatChfWithPrefix(expectedImpact.estimatedTaxSaving)}',
        ),
      );
      expect(
        alert,
        contains(formatChfWithPrefix(expectedImpact.deductibleContribution)),
      );
      expect(
        alert,
        contains(formatChfWithPrefix(expectedImpact.estimatedTaxSaving)),
      );
      expect(alert, contains('taux marginal estimé'));
      expect(alert, contains('canton VD'));
      expect(alert, contains('OPP3'));
      expect(alert, isNot(contains('economiser')));
      expect(alert, isNot(contains("d'impots")));
      expect(alert, isNot(contains('gain fiscal')));
      expect(alert, isNot(contains('tu économises')));
      expect(alert, isNot(contains('tu economises')));
      expect(alert, isNot(contains('tu gagnes')));
      expect(alert, isNot(contains('rendement fiscal')));
      expect(alert, isNot(contains('économie d’impôt en jeu')));
      expect(alert, isNot(contains("économie d'impôt en jeu")));
      expect(
        alert,
        isNot(
          contains(
            '${formatChfWithPrefix(expectedImpact.deductibleContribution)} '
            'd’économie',
          ),
        ),
      );
      expect(
        alert,
        isNot(
          contains(
            '${formatChfWithPrefix(expectedImpact.deductibleContribution)} '
            "d'économie",
          ),
        ),
      );
    });

    test('3a deadline alert is suppressed when assumptions are incomplete', () {
      for (final canton in ['', 'CH', 'ZZ']) {
        expect(
          CoachNarrativeService.build3aDeadlineAlertForTest(
            profile: _profileWithOpen3aMargin(canton: canton),
            now: DateTime(2026, 12),
          ),
          isNull,
        );
      }
      expect(
        CoachNarrativeService.build3aDeadlineAlertForTest(
          profile: _profileWithOpen3aMargin(salaireBrutMensuel: 0),
          now: DateTime(2026, 12),
        ),
        isNull,
      );
    });

    test('no-LPP remaining 3a margin subtracts already-paid contributions', () {
      final profile = _profileWithOpen3aMargin(
        salaireBrutMensuel: 50000 / 12,
        employmentStatus: 'independant',
        monthly3a: 8000 / 12,
        avoirLppTotal: null,
      );

      final alert = CoachNarrativeService.build3aDeadlineAlertForTest(
        profile: profile,
        now: DateTime(2026, 12),
      );

      expect(alert, isNotNull);
      expect(alert, contains(formatChfWithPrefix(2000)));
      expect(alert, isNot(contains(formatChfWithPrefix(10000))));
    });

    test('system prompt grounds 3a ceiling from profile archetype', () {
      final prompt = CoachNarrativeService.buildSystemPromptForTest(
        profile: _profileWithOpen3aMargin(
          salaireBrutMensuel: 300000 / 12,
          employmentStatus: 'independant',
          avoirLppTotal: null,
        ),
      );

      expect(prompt, contains('Plafond 3a applicable au profil'));
      expect(prompt, contains(formatChfWithPrefix(36288)));
      expect(prompt, isNot(contains('Plafond 3a salarie : 7')));
    });

    test('fallback tax tip states canton and estimated-rate assumption', () {
      final text = FallbackTemplates.tipNarrative(
        const CoachContext(
          firstName: 'Julien',
          canton: 'VD',
          knownValues: {'tax_saving': 2500},
        ),
      );

      expect(text, contains('3a'));
      expect(text, contains("2'500"));
      expect(text, contains('taux marginal estimé'));
      expect(text, contains('canton VD'));
    });

    test('fallback tax tip is not used without a valid canton assumption', () {
      for (final canton in ['', 'CH', 'ZZ']) {
        final text = FallbackTemplates.tipNarrative(
          CoachContext(
            firstName: 'Julien',
            canton: canton,
            knownValues: const {'tax_saving': 2500},
          ),
        );

        expect(text, isNot(contains("2'500")));
        expect(text, isNot(contains('réduire ton impôt')));
      }
    });
  });
}
