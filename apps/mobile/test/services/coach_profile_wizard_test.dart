import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

/// Tests du pipeline wizard → CoachProfile — Sprint 1 "Fix the Pipes"
void main() {
  // ════════════════════════════════════════════════════════════
  //  HELPER: answers de base pour un profil valide
  // ════════════════════════════════════════════════════════════

  Map<String, dynamic> _baseAnswers({
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
      final answers = _baseAnswers(hasDebt: 'yes');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.dettes.hasDette, true);
    });

    test('accepts "oui" for boolean fields', () {
      final answers = _baseAnswers(hasDebt: 'oui');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.dettes.hasDette, true);
    });

    test('accepts "true" for boolean fields', () {
      final answers = _baseAnswers(hasDebt: 'true');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.dettes.hasDette, true);
    });

    test('rejects "no" for boolean fields', () {
      final answers = _baseAnswers(hasDebt: 'no');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.dettes.hasDette, false);
    });

    test('rejects "false" for boolean fields', () {
      final answers = _baseAnswers(hasDebt: 'false');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.dettes.hasDette, false);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  2. Emergency fund mapping
  // ════════════════════════════════════════════════════════════

  group('Emergency fund mapping', () {
    test('"yes_6months" produit une epargne liquide > 0', () {
      final answers = _baseAnswers(emergencyFund: 'yes_6months');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.patrimoine.epargneLiquide, greaterThan(0));
      // Doit etre environ 6 x (loyer + assurance maladie)
      expect(profile.patrimoine.epargneLiquide, greaterThan(5000));
    });

    test('"yes_3months" produit une epargne intermediaire', () {
      final answers = _baseAnswers(emergencyFund: 'yes_3months');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.patrimoine.epargneLiquide, greaterThan(0));
    });

    test('"no" produit une epargne minimale', () {
      final answers = _baseAnswers(emergencyFund: 'no');
      final profile = CoachProfile.fromWizardAnswers(answers);
      // Avec savingsMonthly=500, epargneLiquide = 500 * 1 = 500
      expect(profile.patrimoine.epargneLiquide, equals(500));
    });

    test('"yes_6months" > "yes_3months" > "no"', () {
      final p6 = CoachProfile.fromWizardAnswers(
        _baseAnswers(emergencyFund: 'yes_6months'),
      );
      final p3 = CoachProfile.fromWizardAnswers(
        _baseAnswers(emergencyFund: 'yes_3months'),
      );
      final pNo = CoachProfile.fromWizardAnswers(
        _baseAnswers(emergencyFund: 'no'),
      );
      expect(p6.patrimoine.epargneLiquide,
          greaterThan(p3.patrimoine.epargneLiquide));
      expect(p3.patrimoine.epargneLiquide,
          greaterThan(pNo.patrimoine.epargneLiquide));
    });

    test('valeur numerique directe est acceptee', () {
      final answers = Map<String, dynamic>.from(_baseAnswers());
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
      final answers = _baseAnswers(mainGoal: 'retirement');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.retraite);
      expect(profile.goalA.label, contains('Retraite'));
    });

    test('"real_estate" → GoalAType.achatImmo', () {
      final answers = _baseAnswers(mainGoal: 'real_estate');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.achatImmo);
      expect(profile.goalA.label, contains('immobilier'));
    });

    test('"independence" → GoalAType.independance', () {
      final answers = _baseAnswers(mainGoal: 'independence');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.independance);
      expect(profile.goalA.label, contains('Independance'));
    });

    test('"inheritance" → GoalAType.retraite avec label transmission', () {
      final answers = _baseAnswers(mainGoal: 'inheritance');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.retraite);
      expect(profile.goalA.label, contains('Transmission'));
    });

    test('"project" → GoalAType.custom', () {
      final answers = _baseAnswers(mainGoal: 'project');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.custom);
      expect(profile.goalA.label, contains('Projet'));
    });

    test('ancien format "house" reste compatible', () {
      final answers = _baseAnswers(mainGoal: 'house');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.achatImmo);
    });

    test('ancien format "invest" reste compatible', () {
      final answers = _baseAnswers(mainGoal: 'invest');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.goalA.type, GoalAType.independance);
    });

    test('valeur inconnue → retraite par defaut', () {
      final answers = _baseAnswers(mainGoal: 'something_unknown');
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
        _baseAnswers(netIncome: 10000, hasDebt: 'yes'),
      );
      final profileLow = CoachProfile.fromWizardAnswers(
        _baseAnswers(netIncome: 5000, hasDebt: 'yes'),
      );
      expect(
        profileHigh.dettes.creditConsommation,
        greaterThan(profileLow.dettes.creditConsommation!),
      );
    });

    test('dette est ~5% du salaire brut annuel', () {
      final profile = CoachProfile.fromWizardAnswers(
        _baseAnswers(netIncome: 6000, hasDebt: 'yes'),
      );
      // salaireBrutMensuel ~ 6000 / (1 - 0.13) ≈ 6897
      // dette = 6897 * 12 * 0.05 ≈ 4138
      expect(profile.dettes.creditConsommation, greaterThan(3000));
      expect(profile.dettes.creditConsommation, lessThan(6000));
    });

    test('pas de dette quand hasDebt=no', () {
      final profile = CoachProfile.fromWizardAnswers(
        _baseAnswers(hasDebt: 'no'),
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
      final answers = _baseAnswers(housingStatus: 'renter');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.housingStatus, 'renter');
    });

    test('riskTolerance est peuple', () {
      final answers = _baseAnswers(riskTolerance: 'balanced');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.riskTolerance, 'balanced');
    });

    test('realEstateProject est peuple', () {
      final answers = _baseAnswers(realEstateProject: 'yes_main');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.realEstateProject, 'yes_main');
    });

    test('providers3a est peuple depuis une liste', () {
      final answers = _baseAnswers(providers3a: ['bank', 'fintech']);
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.providers3a, ['bank', 'fintech']);
    });

    test('providers3a est vide par defaut', () {
      final answers = _baseAnswers();
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.providers3a, isEmpty);
    });

    test('champs null quand non fournis', () {
      final answers = _baseAnswers();
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
    });

    test('profil minimal fonctionne avec valeurs par defaut', () {
      final answers = <String, dynamic>{
        'q_net_income_period_chf': 5000,
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.birthYear, 1990);
      expect(profile.canton, 'ZH');
      expect(profile.salaireBrutMensuel, greaterThan(0));
      expect(profile.goalA.type, GoalAType.retraite);
    });

    test('profil complet avec AVS no_gaps', () {
      final answers = _baseAnswers();
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
      final answers = Map<String, dynamic>.from(_baseAnswers());
      answers['q_avs_lacunes_status'] = 'no_gaps';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });

    test('"arrived_late" sans arrival_year → default 5 ans de lacune', () {
      final answers = Map<String, dynamic>.from(_baseAnswers());
      answers['q_avs_lacunes_status'] = 'arrived_late';
      // Pas de q_avs_arrival_year → fallback 5
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, 5);
    });

    test('"arrived_late" avec arrival_year → calcul depuis birthYear+21', () {
      final answers = Map<String, dynamic>.from(_baseAnswers());
      answers['q_birth_year'] = 1990;
      answers['q_avs_lacunes_status'] = 'arrived_late';
      answers['q_avs_arrival_year'] = 2018; // Arrive a 28 ans → 28-21 = 7 ans de lacune
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, 7);
    });

    test('"arrived_late" avec arrival_year precoce → clamp a 0', () {
      final answers = Map<String, dynamic>.from(_baseAnswers());
      answers['q_birth_year'] = 1990;
      answers['q_avs_lacunes_status'] = 'arrived_late';
      answers['q_avs_arrival_year'] = 2010; // Arrive a 20 ans → 2010-(1990+21)=-1 → clamp 0
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, isNull); // 0 → null (pas de lacune)
    });

    test('"lived_abroad" sans years_abroad → default 3 ans', () {
      final answers = Map<String, dynamic>.from(_baseAnswers());
      answers['q_avs_lacunes_status'] = 'lived_abroad';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, 3);
    });

    test('"lived_abroad" avec years_abroad → valeur exacte', () {
      final answers = Map<String, dynamic>.from(_baseAnswers());
      answers['q_avs_lacunes_status'] = 'lived_abroad';
      answers['q_avs_years_abroad'] = 8;
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, 8);
    });

    test('"unknown" → estimation conservatrice 2 ans', () {
      final answers = Map<String, dynamic>.from(_baseAnswers());
      answers['q_avs_lacunes_status'] = 'unknown';
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, 2);
    });

    test('null (pas de reponse) → aucune lacune', () {
      final answers = Map<String, dynamic>.from(_baseAnswers());
      // q_avs_lacunes_status absent
      answers.remove('q_avs_lacunes_status');
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.prevoyance.lacunesAVS, isNull);
    });

    test('impact sur rente estimee: lacunes reduisent la rente', () {
      final noGaps = Map<String, dynamic>.from(_baseAnswers());
      noGaps['q_avs_lacunes_status'] = 'no_gaps';
      final profileNoGaps = CoachProfile.fromWizardAnswers(noGaps);

      final withGaps = Map<String, dynamic>.from(_baseAnswers());
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
      final answers = _baseAnswers(
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
