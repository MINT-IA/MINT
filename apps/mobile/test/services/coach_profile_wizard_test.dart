import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

/// Tests du pipeline wizard → CoachProfile — Sprint 1 "Fix the Pipes"
void main() {
  // ════════════════════════════════════════════════════════════
  //  HELPER: answers de base pour un profil valide
  // ════════════════════════════════════════════════════════════

  Map<String, dynamic> baseAnswers({
    double netIncome = 6000,
    String? mainGoal,
    String? emergencyFund,
    String? hasDebt,
    String? housingStatus,
    String? riskTolerance,
    String? realEstateProject,
    List<String>? providers3a,
  }) {
    return {
      'q_firstname': 'TestUser',
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_civil_status': 'celibataire',
      'q_children': 0,
      'q_pay_frequency': 'monthly',
      'q_net_income_period_chf': netIncome,
      'q_employment_status': 'employee',
      'q_housing_cost_period_chf': 1500,
      'q_has_pension_fund': 'yes',
      'q_has_3a': 'yes',
      'q_3a_annual_contribution': 7258,
      'q_3a_accounts_count': 2,
      'q_savings_monthly': 500,
      'q_has_investments': 'yes',
      if (mainGoal != null) 'q_main_goal': mainGoal,
      if (emergencyFund != null) 'q_emergency_fund': emergencyFund,
      if (hasDebt != null) 'q_has_consumer_debt': hasDebt,
      if (housingStatus != null) 'q_housing_status': housingStatus,
      if (riskTolerance != null) 'q_risk_tolerance': riskTolerance,
      if (realEstateProject != null) 'q_real_estate_project': realEstateProject,
      if (providers3a != null) 'q_3a_providers': providers3a,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  1. _parseBool accepte 'yes', 'no', 'true', 'oui'
  // ════════════════════════════════════════════════════════════

  group('_parseBool via fromWizardAnswers', () {
    test('accepts "yes" for boolean fields', () {
      final answers = baseAnswers(hasDebt: 'yes');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.dettes.hasDette, true);
    });

    test('accepts "oui" for boolean fields', () {
      final answers = baseAnswers(hasDebt: 'oui');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.dettes.hasDette, true);
    });

    test('accepts "true" for boolean fields', () {
      final answers = baseAnswers(hasDebt: 'true');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.dettes.hasDette, true);
    });

    test('rejects "no" for boolean fields', () {
      final answers = baseAnswers(hasDebt: 'no');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.dettes.hasDette, false);
    });

    test('rejects "false" for boolean fields', () {
      final answers = baseAnswers(hasDebt: 'false');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.dettes.hasDette, false);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  2. Emergency fund mapping
  // ════════════════════════════════════════════════════════════

  group('Emergency fund mapping', () {
    test('"yes_6months" produit une epargne liquide > 0', () {
      final answers = baseAnswers(emergencyFund: 'yes_6months');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.patrimoine.epargneLiquide, greaterThan(0));
      // Doit etre environ 6 x (loyer + assurance maladie)
      expect(profile.patrimoine.epargneLiquide, greaterThan(5000));
    });

    test('"yes_3months" produit une epargne intermediaire', () {
      final answers = baseAnswers(emergencyFund: 'yes_3months');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.patrimoine.epargneLiquide, greaterThan(0));
    });

    test('"no" produit une epargne minimale', () {
      final answers = baseAnswers(emergencyFund: 'no');
      final profile = CoachProfile.fromWizardAnswers(answers);
      // Avec savingsMonthly=500, epargneLiquide = 500 * 1 = 500
      expect(profile.patrimoine.epargneLiquide, equals(500));
    });

    test('"yes_6months" > "yes_3months" > "no"', () {
      final p6 = CoachProfile.fromWizardAnswers(
        baseAnswers(emergencyFund: 'yes_6months'),
      );
      final p3 = CoachProfile.fromWizardAnswers(
        baseAnswers(emergencyFund: 'yes_3months'),
      );
      final pNo = CoachProfile.fromWizardAnswers(
        baseAnswers(emergencyFund: 'no'),
      );
      expect(p6.patrimoine.epargneLiquide,
          greaterThan(p3.patrimoine.epargneLiquide));
      expect(p3.patrimoine.epargneLiquide,
          greaterThan(pNo.patrimoine.epargneLiquide));
    });

    test('valeur numerique directe est acceptee', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_emergency_fund'] = 25000.0;
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.patrimoine.epargneLiquide, equals(25000));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  3. Main goal parsing — wizard values
  // ════════════════════════════════════════════════════════════

  group('Main goal parsing', () {
    test('"retirement" → GoalAType.retraite', () {
      final answers = baseAnswers(mainGoal: 'retirement');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.retraite);
      expect(profile.goalA.label, contains('Retraite'));
    });

    test('"real_estate" → GoalAType.achatImmo', () {
      final answers = baseAnswers(mainGoal: 'real_estate');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.achatImmo);
      expect(profile.goalA.label, contains('immobilier'));
    });

    test('"independence" → GoalAType.independance', () {
      final answers = baseAnswers(mainGoal: 'independence');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.independance);
      expect(profile.goalA.label, contains('Independance'));
    });

    test('"inheritance" → GoalAType.retraite avec label retraite', () {
      final answers = baseAnswers(mainGoal: 'inheritance');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.retraite);
      // inheritance maps to retirement goal with retirement label
      expect(profile.goalA.label, contains('Retraite'));
    });

    test('"project" → GoalAType.custom', () {
      final answers = baseAnswers(mainGoal: 'project');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.custom);
      expect(profile.goalA.label, contains('Projet'));
    });

    test('ancien format "house" reste compatible', () {
      final answers = baseAnswers(mainGoal: 'house');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.achatImmo);
    });

    test('ancien format "invest" reste compatible', () {
      final answers = baseAnswers(mainGoal: 'invest');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.independance);
    });

    test('valeur inconnue → retraite par defaut', () {
      final answers = baseAnswers(mainGoal: 'something_unknown');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.retraite);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  4. Debt estimate scales with income
  // ════════════════════════════════════════════════════════════

  group('Debt estimate scales with income', () {
    test('dette plus elevee avec salaire plus eleve', () {
      final profileHigh = CoachProfile.fromWizardAnswers(
        baseAnswers(netIncome: 10000, hasDebt: 'yes'),
      );
      final profileLow = CoachProfile.fromWizardAnswers(
        baseAnswers(netIncome: 5000, hasDebt: 'yes'),
      );
      expect(
        profileHigh.dettes.creditConsommation,
        greaterThan(profileLow.dettes.creditConsommation!),
      );
    });

    test('dette est ~5% du salaire brut annuel', () {
      final profile = CoachProfile.fromWizardAnswers(
        baseAnswers(netIncome: 6000, hasDebt: 'yes'),
      );
      // salaireBrutMensuel ~ 6000 / (1 - 0.13) ≈ 6897
      // dette = 6897 * 12 * 0.05 ≈ 4138
      expect(profile.dettes.creditConsommation, greaterThan(3000));
      expect(profile.dettes.creditConsommation, lessThan(6000));
    });

    test('pas de dette quand hasDebt=no', () {
      final profile = CoachProfile.fromWizardAnswers(
        baseAnswers(hasDebt: 'no'),
      );
      expect(profile.dettes.hasDette, false);
      expect(profile.dettes.totalDettes, 0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  5. Nouveaux champs (housingStatus, riskTolerance, etc.)
  // ════════════════════════════════════════════════════════════

  group('Nouveaux champs depuis wizard', () {
    test('housingStatus est peuple', () {
      final answers = baseAnswers(housingStatus: 'renter');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.housingStatus, 'renter');
    });

    test('riskTolerance est peuple', () {
      final answers = baseAnswers(riskTolerance: 'balanced');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.riskTolerance, 'balanced');
    });

    test('realEstateProject est peuple', () {
      final answers = baseAnswers(realEstateProject: 'yes_main');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.realEstateProject, 'yes_main');
    });

    test('unemploymentContributionMonths est borne entre 0 et 24', () {
      final answersHigh = baseAnswers()
        ..['q_unemployment_contribution_months'] = 99;
      final answersLow = baseAnswers()
        ..['q_unemployment_contribution_months'] = -3;

      expect(
        CoachProfile.fromWizardAnswers(answersHigh)
            .unemploymentContributionMonths,
        24,
      );
      expect(
        CoachProfile.fromWizardAnswers(answersLow)
            .unemploymentContributionMonths,
        0,
      );
    });

    test('distingue revenu brut explicite et revenu net estime', () {
      final netOnly =
          CoachProfile.fromWizardAnswers(baseAnswers(netIncome: 6000));
      final gross = CoachProfile.fromWizardAnswers({
        ...baseAnswers(netIncome: 6000),
        'q_gross_salary_annual': 96000,
      });

      expect(netOnly.userProvidedFields, contains('salary'));
      expect(netOnly.userProvidedFields, contains('netIncome'));
      expect(netOnly.userProvidedFields, isNot(contains('grossSalaryAnnual')));
      expect(netOnly.monthlyNetIncomeDeclared, 6000);
      expect(gross.userProvidedFields, contains('grossSalaryAnnual'));
      expect(gross.monthlyNetIncomeDeclared, 6000);
    });

    test('providers3a est peuple depuis une liste', () {
      final answers = baseAnswers(providers3a: ['bank', 'fintech']);
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.providers3a, ['bank', 'fintech']);
    });

    test('providers3a est vide par defaut', () {
      final answers = baseAnswers();
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.providers3a, isEmpty);
    });

    test('champs null quand non fournis', () {
      final answers = baseAnswers();
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.housingStatus, isNull);
      expect(profile.riskTolerance, isNull);
      expect(profile.realEstateProject, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  6. Full wizard answers → valid CoachProfile
  // ════════════════════════════════════════════════════════════

  group('fromWizardAnswers — profil complet', () {
    test('marque les facts profil utilisés par les parcours ledger-first', () {
      final profile = CoachProfile.fromWizardAnswers({
        ...baseAnswers(housingStatus: 'owner'),
        'q_employment_status': 'self_employed',
        'q_children': 2,
      });

      expect(profile.employmentStatus, 'independant');
      expect(profile.nombreEnfants, 2);
      expect(profile.housingStatus, 'owner');
      expect(profile.userProvidedFields, contains('employmentStatus'));
      expect(profile.userProvidedFields, contains('children'));
      expect(profile.userProvidedFields, contains('housingStatus'));
      expect(profile.userProvidedFields, contains('has3a'));
    });

    test('marque le solde hypothécaire quand il est fourni', () {
      final profile = CoachProfile.fromWizardAnswers({
        ...baseAnswers(housingStatus: 'owner'),
        '_coach_dettes_hypotheque': 0,
      });

      expect(profile.dettes.hypotheque, 0);
      expect(profile.userProvidedFields, contains('mortgageBalance'));
    });

    test('marque employmentStatus quand le revenu indépendant le déduit', () {
      final answers = {...baseAnswers(), 'q_self_employed_income': 84000}
        ..remove('q_employment_status');
      final profile = CoachProfile.fromWizardAnswers(answers);

      expect(profile.employmentStatus, 'independant');
      expect(profile.userProvidedFields, contains('employmentStatus'));
      expect(profile.userProvidedFields, contains('selfEmployedNetIncome'));
    });

    test('produit un CoachProfile valide avec toutes les reponses', () {
      final answers = {
        'q_firstname': 'Marie',
        'q_birth_year': 1988,
        'q_canton': 'GE',
        'q_civil_status': 'marie',
        'q_children': 2,
        'q_pay_frequency': 'monthly',
        'q_net_income_period_chf': 8000,
        'q_employment_status': 'employee',
        'q_housing_cost_period_chf': 2200,
        'q_has_pension_fund': 'yes',
        'q_lpp_buyback_available': 50000,
        'q_has_3a': 'yes',
        'q_3a_annual_contribution': 7258,
        'q_3a_accounts_count': 3,
        'q_avs_lacunes_status': 'no_gaps',
        'q_savings_monthly': 1000,
        'q_has_investments': 'yes',
        'q_emergency_fund': 'yes_6months',
        'q_has_consumer_debt': 'no',
        'q_main_goal': 'retirement',
        'q_housing_status': 'renter',
        'q_risk_tolerance': 'balanced',
        'q_real_estate_project': 'yes_main',
        'q_3a_providers': ['bank', 'insurance'],
      };

      final profile = CoachProfile.fromWizardAnswers(answers);

      expect(profile.firstName, 'Marie');
      expect(profile.birthYear, 1988);
      expect(profile.canton, 'GE');
      expect(profile.etatCivil, CoachCivilStatus.marie);
      expect(profile.nombreEnfants, 2);
      expect(profile.salaireBrutMensuel, greaterThan(8000));
      expect(profile.employmentStatus, 'salarie');
      expect(profile.depenses.loyer, 2200);
      expect(profile.depenses.assuranceMaladie, greaterThan(0));
      expect(profile.prevoyance.nombre3a, 3);
      expect(profile.prevoyance.avoirLppTotal, greaterThan(0));
      expect(profile.patrimoine.epargneLiquide, greaterThan(0));
      expect(profile.patrimoine.investissements, 16000.0);
      expect(profile.dettes.hasDette, false);
      expect(profile.goalA.type, GoalAType.retraite);
      expect(profile.pillar3aAnnualContribution, 7258);
      expect(profile.monthlySavingsContribution, 1000);
      expect(profile.hasPillar3a, isTrue);
      expect(profile.plannedContributions, isEmpty);
      expect(profile.housingStatus, 'renter');
      expect(profile.riskTolerance, 'balanced');
      expect(profile.realEstateProject, 'yes_main');
      expect(profile.providers3a, ['bank', 'insurance']);
    });

    test('q_has_3a masque le nombre de comptes sans le detruire', () {
      final answers = {
        ...baseAnswers(),
        'q_has_3a': 'no',
        'q_3a_accounts_count': 3,
      };

      expect(CoachProfile.fromWizardAnswers(answers).prevoyance.nombre3a, 0);

      final restored = {
        ...answers,
        'q_has_3a': 'yes',
      };
      expect(CoachProfile.fromWizardAnswers(restored).prevoyance.nombre3a, 3);
    });

    test('profil minimal fonctionne avec valeurs par defaut', () {
      final answers = <String, dynamic>{
        'q_net_income_period_chf': 5000,
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      // CHAOS-78: birthYear no longer defaults to 1990 — stays 0 if unknown
      expect(profile.birthYear, 0);
      expect(profile.canton, 'ZH');
      expect(profile.salaireBrutMensuel, greaterThan(0));
      expect(profile.goalA.type, GoalAType.retraite);
    });

    test('profil complet conserve AVS no_gaps comme declaration', () {
      final answers = baseAnswers();
      answers['q_avs_lacunes_status'] = 'no_gaps';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.avsGapStatus, AvsGapStatus.noGaps);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  7. AVS lacunes status parsing (LAVS art. 29ter)
  // ════════════════════════════════════════════════════════════

  group('AVS lacunes status parsing', () {
    test(
        'declarations AVS du conjoint restent non certifiees et gardent l arrivee',
        () {
      final cases = <Map<String, Object?>>[
        {
          'status': 'arrived_late',
          'arrivalYear': 2018,
          'yearsAbroad': null,
          'expectedArrivalAge': 28,
        },
        {
          'status': 'lived_abroad',
          'arrivalYear': null,
          'yearsAbroad': 8,
          'expectedArrivalAge': null,
        },
        {
          'status': 'unknown',
          'arrivalYear': null,
          'yearsAbroad': null,
          'expectedArrivalAge': null,
        },
      ];

      for (final testCase in cases) {
        final answers = Map<String, dynamic>.from(baseAnswers())
          ..['q_partner_birth_year'] = 1990
          ..['q_spouse_avs_lacunes_status'] = testCase['status'];
        if (testCase['arrivalYear'] case final int arrivalYear) {
          answers['q_spouse_avs_arrival_year'] = arrivalYear;
        }
        if (testCase['yearsAbroad'] case final int yearsAbroad) {
          answers['q_spouse_avs_years_abroad'] = yearsAbroad;
        }

        final conjoint = CoachProfile.fromWizardAnswers(answers).conjoint;

        expect(conjoint, isNotNull, reason: testCase['status'] as String);
        expect(
          conjoint!.prevoyance?.lacunesAVS,
          isNull,
          reason: testCase['status'] as String,
        );
        expect(
          conjoint.arrivalAge,
          testCase['expectedArrivalAge'],
          reason: testCase['status'] as String,
        );
      }
    });

    test('"no_gaps" reste declare sans certifier zero annee', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_avs_lacunes_status'] = 'no_gaps';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.avsGapStatus, AvsGapStatus.noGaps);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });

    test('"arrived_late" sans arrival_year reste inconnu', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_avs_lacunes_status'] = 'arrived_late';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });

    test('"arrived_late" garde l age d arrivee sans certifier de lacune', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_birth_year'] = 1990;
      answers['q_avs_lacunes_status'] = 'arrived_late';
      answers['q_avs_arrival_year'] =
          2018; // Arrive a 28 ans → 28-21 = 7 ans de lacune
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.avsGapStatus, AvsGapStatus.arrivedLate);
      expect(profile.arrivalAge, 28);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });

    test('"arrived_late" precoce ne certifie pas zero lacune', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_birth_year'] = 1990;
      answers['q_avs_lacunes_status'] = 'arrived_late';
      answers['q_avs_arrival_year'] =
          2010; // Arrive a 20 ans → 2010-(1990+21)=-1 → clamp 0
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.arrivalAge, 20);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });

    test('"lived_abroad" sans years_abroad reste inconnu', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_avs_lacunes_status'] = 'lived_abroad';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });

    test('"lived_abroad" garde years_abroad declaratif seulement', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_avs_lacunes_status'] = 'lived_abroad';
      answers['q_avs_years_abroad'] = 8;
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(answers['q_avs_years_abroad'], 8);
      expect(profile.avsGapStatus, AvsGapStatus.livedAbroad);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });

    test('"unknown" ne fabrique aucun nombre d annees', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_avs_lacunes_status'] = 'unknown';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });

    test('null (pas de reponse) → aucune lacune', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      // q_avs_lacunes_status absent
      answers.remove('q_avs_lacunes_status');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });

    test('declarations AVS divergentes restent hors des annees certifiees', () {
      final noGaps = Map<String, dynamic>.from(baseAnswers());
      noGaps['q_avs_lacunes_status'] = 'no_gaps';
      final profileNoGaps = CoachProfile.fromWizardAnswers(noGaps);

      final withGaps = Map<String, dynamic>.from(baseAnswers());
      withGaps['q_avs_lacunes_status'] = 'lived_abroad';
      withGaps['q_avs_years_abroad'] = 10;
      final profileWithGaps = CoachProfile.fromWizardAnswers(withGaps);

      expect(profileNoGaps.avsGapStatus, AvsGapStatus.noGaps);
      expect(profileWithGaps.avsGapStatus, AvsGapStatus.livedAbroad);
      expect(profileNoGaps.prevoyance.lacunesAVS, isNull);
      expect(profileWithGaps.prevoyance.lacunesAVS, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  8. JSON round-trip
  // ════════════════════════════════════════════════════════════

  group('JSON round-trip', () {
    test('JSON round-trip preserve les nouveaux champs', () {
      final answers = baseAnswers(
        housingStatus: 'owner',
        riskTolerance: 'aggressive',
        realEstateProject: 'no',
        providers3a: ['fintech', 'mixed'],
      );
      final profile = CoachProfile.fromWizardAnswers(answers);
      final json = profile.toJson();
      final restored = CoachProfile.fromJson(json);

      expect(restored.housingStatus, 'owner');
      expect(restored.riskTolerance, 'aggressive');
      expect(restored.realEstateProject, 'no');
      expect(restored.providers3a, ['fintech', 'mixed']);
    });
  });
}
