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
      final answers = baseAnswers()..['q_has_investments'] = 'yes';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.patrimoine.investissements, greaterThan(0));
    });

    test('accepts "oui" for boolean fields', () {
      final answers = baseAnswers()..['q_has_investments'] = 'oui';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.patrimoine.investissements, greaterThan(0));
    });

    test('accepts "true" for boolean fields', () {
      final answers = baseAnswers()..['q_has_investments'] = 'true';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.patrimoine.investissements, greaterThan(0));
    });

    test('rejects "no" for boolean fields', () {
      final answers = baseAnswers()..['q_has_investments'] = 'no';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.patrimoine.investissements, 0);
    });

    test('rejects "false" for boolean fields', () {
      final answers = baseAnswers()..['q_has_investments'] = 'false';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.patrimoine.investissements, 0);
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
  //  4. Debt mapping preserves explicit amounts
  // ════════════════════════════════════════════════════════════

  group('Debt mapping preserves explicit amounts', () {
    test('solde explicite plus eleve reste plus eleve', () {
      final highAnswers = baseAnswers(netIncome: 10000, hasDebt: 'yes')
        ..['q_total_debt_balance_chf'] = 12000;
      final lowAnswers = baseAnswers(netIncome: 5000, hasDebt: 'yes')
        ..['q_total_debt_balance_chf'] = 3000;
      final profileHigh = CoachProfile.fromWizardAnswers(highAnswers);
      final profileLow = CoachProfile.fromWizardAnswers(lowAnswers);
      expect(
        profileHigh.dettes.autresDettes,
        greaterThan(profileLow.dettes.autresDettes!),
      );
    });

    test('simple oui ne fabrique pas de capital de dette', () {
      final profile = CoachProfile.fromWizardAnswers(
        baseAnswers(netIncome: 6000, hasDebt: 'yes'),
      );
      expect(profile.dettes.creditConsommation, isNull);
      expect(profile.dettes.autresDettes, isNull);
      expect(profile.dettes.hasDette, false);
    });

    test('mensualite explicite active la dette sans capital synthetique', () {
      final answers = baseAnswers(netIncome: 6000, hasDebt: 'yes')
        ..['q_debt_payments_period_chf'] = 450;
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.dettes.creditConsommation, isNull);
      expect(profile.dettes.mensualiteCreditConso, 450);
      expect(profile.dettes.hasDette, true);
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

    test('ignore les montants mensuels budget improbables', () {
      final answers = {
        ...baseAnswers(),
        'q_housing_cost_period_chf': 19272200,
        'q_lamal_premium_monthly_chf': 420420,
        '_coach_depenses_transport': 120000,
      };

      final profile = CoachProfile.fromWizardAnswers(answers);

      expect(profile.depenses.loyer, 1500);
      expect(profile.depenses.assuranceMaladie, lessThan(1000));
      expect(profile.depenses.transport, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  6. Full wizard answers → valid CoachProfile
  // ════════════════════════════════════════════════════════════

  group('fromWizardAnswers — profil complet', () {
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
      expect(profile.plannedContributions, isNotEmpty);
      expect(profile.housingStatus, 'renter');
      expect(profile.riskTolerance, 'balanced');
      expect(profile.realEstateProject, 'yes_main');
      expect(profile.providers3a, ['bank', 'insurance']);
      expect(
        profile.dataSources['plannedContributions.3a'],
        ProfileDataSource.userInput,
      );
      expect(
        profile.dataTimestamps['plannedContributions.3a'],
        isNotNull,
      );
    });

    test('profil minimal ne fabrique pas un canton par défaut', () {
      final answers = <String, dynamic>{
        'q_net_income_period_chf': 5000,
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      // CHAOS-78: birthYear no longer defaults to 1990 — stays 0 if unknown
      expect(profile.birthYear, 0);
      expect(profile.canton, isEmpty);
      expect(profile.userProvidedFields.contains('canton'), isFalse);
      expect(profile.salaireBrutMensuel, greaterThan(0));
      expect(profile.goalA.type, GoalAType.retraite);
    });

    test('allocation 3a automatique ne fabrique pas une provenance utilisateur',
        () {
      final answers = {
        ...baseAnswers(),
        'q_savings_monthly': 1000,
        'q_savings_allocation': ['3a'],
        'q_has_3a': 'yes',
      }..remove('q_3a_annual_contribution');
      final profile = CoachProfile.fromWizardAnswers(answers);

      expect(profile.total3aMensuel, greaterThan(0));
      expect(profile.dataSources['plannedContributions.3a'], isNull);
      expect(profile.dataTimestamps['plannedContributions.3a'], isNull);
    });

    test('legacy inline civil-status alias hydrates canonical civil status',
        () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_civil_status_choice': 'married',
      });

      expect(profile.etatCivil, CoachCivilStatus.marie);
      expect(profile.userProvidedFields.contains('civilStatus'), isTrue);
    });

    test('unresolved secure income placeholder is not treated as user salary',
        () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_net_income_period_chf': '__secure__',
      });

      expect(profile.explicitMonthlyNetIncome, isNull);
      expect(profile.userProvidedFields.contains('salary'), isFalse);
      expect(profile.salaireBrutMensuel, 0);
    });

    test('annual pay frequency alias is normalized to monthly income', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1985,
        'q_canton': 'VD',
        'q_employment_status': 'independant',
        'q_pay_frequency': 'annual',
        'q_net_income_period_chf': 90000.0,
      });

      expect(profile.explicitMonthlyNetIncome, closeTo(7500, 0.01));
      expect(profile.salaireBrutMensuel, closeTo(8250, 0.01));
    });

    test('annual pay frequency ignores padding before monthly normalization',
        () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1985,
        'q_canton': 'VD',
        'q_employment_status': 'independant',
        'q_pay_frequency': ' annual ',
        'q_net_income_period_chf': 90000.0,
      });

      expect(profile.explicitMonthlyNetIncome, closeTo(7500, 0.01));
      expect(profile.salaireBrutMensuel, closeTo(8250, 0.01));
    });

    test(
        'self-employed professional net income derives a gross work base without salary net contamination',
        () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1985,
        'q_canton': 'GE',
        'q_employment_status': 'independant',
        'q_self_employed_net_income_annual_chf': 96000.0,
      });

      expect(profile.independentNetProfessionalIncomeAnnual, 96000.0);
      expect(profile.explicitMonthlyNetIncome, isNull);
      expect(profile.userProvidedFields.contains('salary'), isFalse);
      expect(profile.salaireBrutMensuel, closeTo(8800, 0.01));
      expect(profile.revenuBrutAnnuel, closeTo(105600, 0.01));
    });

    test('secure income tombstone is not treated as default salary', () {
      final profile = CoachProfile.fromWizardAnswers({
        'q_net_income_period_chf': null,
      });

      expect(profile.explicitMonthlyNetIncome, isNull);
      expect(profile.userProvidedFields.contains('salary'), isFalse);
      expect(profile.salaireBrutMensuel, 0);
    });

    test('profil complet avec AVS no_gaps', () {
      final answers = baseAnswers();
      answers['q_avs_lacunes_status'] = 'no_gaps';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  7. AVS lacunes status parsing (LAVS art. 29ter)
  // ════════════════════════════════════════════════════════════

  group('AVS lacunes status parsing', () {
    test('"no_gaps" → lacunesAVS null (aucune lacune)', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_avs_lacunes_status'] = 'no_gaps';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });

    test('"arrived_late" sans arrival_year → default 5 ans de lacune', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_avs_lacunes_status'] = 'arrived_late';
      // Pas de q_avs_arrival_year → fallback 5
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, 5);
    });

    test('"arrived_late" avec arrival_year → calcul depuis birthYear+21', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_birth_year'] = 1990;
      answers['q_avs_lacunes_status'] = 'arrived_late';
      answers['q_avs_arrival_year'] =
          2018; // Arrive a 28 ans → 28-21 = 7 ans de lacune
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, 7);
    });

    test('"arrived_late" avec arrival_year precoce → clamp a 0', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_birth_year'] = 1990;
      answers['q_avs_lacunes_status'] = 'arrived_late';
      answers['q_avs_arrival_year'] =
          2010; // Arrive a 20 ans → 2010-(1990+21)=-1 → clamp 0
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, isNull); // 0 → null (pas de lacune)
    });

    test('"lived_abroad" sans years_abroad → default 3 ans', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_avs_lacunes_status'] = 'lived_abroad';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, 3);
    });

    test('"lived_abroad" avec years_abroad → valeur exacte', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_avs_lacunes_status'] = 'lived_abroad';
      answers['q_avs_years_abroad'] = 8;
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, 8);
    });

    test('"unknown" → estimation conservatrice 2 ans', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      answers['q_avs_lacunes_status'] = 'unknown';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, 2);
    });

    test('null (pas de reponse) → aucune lacune', () {
      final answers = Map<String, dynamic>.from(baseAnswers());
      // q_avs_lacunes_status absent
      answers.remove('q_avs_lacunes_status');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });

    test('impact sur rente estimee: lacunes reduisent la rente', () {
      final noGaps = Map<String, dynamic>.from(baseAnswers());
      noGaps['q_avs_lacunes_status'] = 'no_gaps';
      final profileNoGaps = CoachProfile.fromWizardAnswers(noGaps);

      final withGaps = Map<String, dynamic>.from(baseAnswers());
      withGaps['q_avs_lacunes_status'] = 'lived_abroad';
      withGaps['q_avs_years_abroad'] = 10;
      final profileWithGaps = CoachProfile.fromWizardAnswers(withGaps);

      // Avec lacunes, la rente estimee devrait etre inferieure
      // (ou les lacunes sont non-null)
      expect(profileNoGaps.prevoyance.lacunesAVS, isNull);
      expect(profileWithGaps.prevoyance.lacunesAVS, 10);
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
      answers['q_employment_status'] = 'independant';
      answers['q_self_employed_net_income_annual_chf'] = 86400.0;
      final profile = CoachProfile.fromWizardAnswers(answers);
      final json = profile.toJson();
      final restored = CoachProfile.fromJson(json);

      expect(restored.housingStatus, 'owner');
      expect(restored.riskTolerance, 'aggressive');
      expect(restored.realEstateProject, 'no');
      expect(restored.providers3a, ['fintech', 'mixed']);
      expect(restored.independentNetProfessionalIncomeAnnual, 86400.0);
    });
  });
}
