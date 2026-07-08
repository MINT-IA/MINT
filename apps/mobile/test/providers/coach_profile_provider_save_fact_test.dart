import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockSecureStorage = <String, String>{};
  final secureReadFailures = <String>{};

  setUp(() {
    mockSecureStorage.clear();
    secureReadFailures.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        final key = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) mockSecureStorage[key] = value;
            return null;
          case 'read':
            if (key != null && secureReadFailures.contains(key)) return null;
            return key == null ? null : mockSecureStorage[key];
          case 'delete':
            if (key != null) mockSecureStorage.remove(key);
            return null;
          case 'deleteAll':
            mockSecureStorage.clear();
            return null;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  Future<CoachProfile> profileAfterSaveFacts(
    List<MapEntry<String, dynamic>> facts,
  ) async {
    final provider = CoachProfileProvider();
    for (final fact in facts) {
      expect(
        await provider.applySaveFact(fact.key, fact.value),
        isTrue,
        reason: '${fact.key} should be mapped by applySaveFact',
      );
    }
    expect(provider.profile, isNotNull);
    expect(await ReportPersistenceService.loadAnswers(), isNotEmpty);
    return provider.profile!;
  }

  test(
      'save_fact identity, revenue, goals, and self-employment hydrate profile',
      () async {
    final profile = await profileAfterSaveFacts([
      const MapEntry('birthYear', 1985),
      const MapEntry('canton', 'VD'),
      const MapEntry('commune', 'Lausanne'),
      const MapEntry('gender', 'F'),
      const MapEntry('incomeGrossYearly', 120000.0),
      const MapEntry('employmentRate', 80.0),
      const MapEntry('annualBonus', 12000.0),
      const MapEntry('goal', 'house'),
      const MapEntry('selfEmployedNetIncome', 90000.0),
    ]);

    final json = profile.toJson();
    expect(profile.commune, 'Lausanne');
    expect(profile.gender, 'F');
    expect(json['employmentRate'], 80.0);
    expect(json['annualBonus'], 12000.0);
    expect(profile.goalA.type, GoalAType.achatImmo);
    expect(profile.employmentStatus, 'independant');
    expect(json['selfEmployedNetIncome'], 90000.0);
  });

  test('save_fact LPP, debt, and AVS keys hydrate profile', () async {
    final profile = await profileAfterSaveFacts([
      const MapEntry('birthYear', 1980),
      const MapEntry('has2ndPillar', false),
      const MapEntry('hasVoluntaryLpp', true),
      const MapEntry('hasDebt', true),
      const MapEntry('totalDebt', 24000.0),
      const MapEntry('hasAvsGaps', true),
      const MapEntry('avsContributionYears', 20),
    ]);

    expect(profile.prevoyance.avoirLppTotal, 0);
    expect(profile.prevoyance.toJson()['hasVoluntaryLpp'], true);
    expect(profile.dettes.hasDette, isTrue);
    expect(profile.dettes.totalDettes, 24000.0);
    expect(profile.dettes.toJson()['declaredTotalDebt'], 24000.0);
    expect(profile.prevoyance.lacunesAVS, greaterThan(0));
    expect(profile.prevoyance.anneesContribuees, 20);
  });

  test('save_fact spouse keys hydrate conjoint profile', () async {
    final profile = await profileAfterSaveFacts([
      const MapEntry('birthYear', 1980),
      const MapEntry('householdType', 'married'),
      const MapEntry('spouseIncomeNetMonthly', 5500.0),
      const MapEntry('spouseBirthYear', 1982),
      const MapEntry('spouseAvsContributionYears', 22),
    ]);

    expect(profile.conjoint, isNotNull);
    expect(profile.conjoint!.birthYear, 1982);
    expect(profile.conjoint!.salaireBrutMensuel, closeTo(6321.84, 0.01));
    expect(profile.conjoint!.prevoyance!.anneesContribuees, 22);
  });

  test('save_fact coupled wizard statuses hydrate conjoint profile', () async {
    const statuses = {
      'couple': CoachCivilStatus.marie,
      'concubine': CoachCivilStatus.concubinage,
      'family': CoachCivilStatus.concubinage,
      'cohabiting': CoachCivilStatus.concubinage,
      'registered_partner': CoachCivilStatus.marie,
    };

    for (final entry in statuses.entries) {
      SharedPreferences.setMockInitialValues({});
      mockSecureStorage.clear();

      final profile = await profileAfterSaveFacts([
        const MapEntry('birthYear', 1980),
        MapEntry('householdType', entry.key),
        const MapEntry('spouseBirthYear', 1982),
      ]);

      expect(profile.etatCivil, entry.value, reason: entry.key);
      expect(profile.conjoint, isNotNull, reason: entry.key);
      expect(profile.conjoint!.birthYear, 1982, reason: entry.key);
    }
  });

  test('save_fact spouse income is stored only in secure storage', () async {
    await profileAfterSaveFacts([
      const MapEntry('birthYear', 1980),
      const MapEntry('spouseIncomeNetMonthly', 5500.0),
    ]);

    final prefs = await SharedPreferences.getInstance();
    final rawAnswers = prefs.getString('wizard_answers_v2');

    expect(rawAnswers, contains('"q_partner_net_income_chf":"__secure__"'));
    expect(rawAnswers, isNot(contains('5500')));
    expect(mockSecureStorage['q_partner_net_income_chf'], '5500.0');
  });

  test('divorce profile update purges stale spouse answers and secure values',
      () async {
    final provider = CoachProfileProvider();
    expect(await provider.applySaveFact('birthYear', 1980), isTrue);
    expect(
        await provider.applySaveFact('spouseIncomeNetMonthly', 5500.0), isTrue);
    expect(await provider.applySaveFact('spouseBirthYear', 1982), isTrue);
    expect(
        await provider.applySaveFact('spouseAvsContributionYears', 22), isTrue);
    mockSecureStorage['q_partner_salary'] = '9999';

    await provider.updateProfile(
      provider.profile!.copyWith(etatCivil: CoachCivilStatus.divorce),
    );

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_civil_status'], 'divorce');
    expect(persisted['q_partner_net_income_chf'], isNull);
    expect(persisted.containsKey('q_partner_birth_year'), isFalse);
    expect(persisted.containsKey('q_spouse_avs_contribution_years'), isFalse);
    expect(mockSecureStorage.containsKey('q_partner_net_income_chf'), isFalse);
    expect(mockSecureStorage.containsKey('q_partner_salary'), isFalse);

    await ReportPersistenceService.setMiniOnboardingCompleted(true);
    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();

    expect(reloaded.profile, isNotNull);
    expect(reloaded.profile!.etatCivil, CoachCivilStatus.divorce);
    expect(reloaded.profile!.conjoint, isNull);
  });

  test('save_fact divorce purges stale spouse answers and secure values',
      () async {
    final provider = CoachProfileProvider();
    expect(await provider.applySaveFact('birthYear', 1980), isTrue);
    expect(await provider.applySaveFact('householdType', 'married'), isTrue);
    expect(
        await provider.applySaveFact('spouseIncomeNetMonthly', 5500.0), isTrue);
    expect(await provider.applySaveFact('spouseBirthYear', 1982), isTrue);
    expect(
        await provider.applySaveFact('spouseAvsContributionYears', 22), isTrue);
    final prefs = await SharedPreferences.getInstance();
    final rawAnswers = prefs.getString('wizard_answers_v2')!;
    final answersWithoutSecurePlaceholder =
        Map<String, dynamic>.from(jsonDecode(rawAnswers) as Map)
          ..remove('q_partner_net_income_chf');
    await prefs.setString(
      'wizard_answers_v2',
      jsonEncode(answersWithoutSecurePlaceholder),
    );
    expect(mockSecureStorage['q_partner_net_income_chf'], '5500.0');
    secureReadFailures.add('q_partner_net_income_chf');
    mockSecureStorage['q_partner_salary'] = '9999';

    expect(await provider.applySaveFact('householdType', 'divorced'), isTrue);
    secureReadFailures.clear();

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_civil_status'], 'divorced');
    expect(persisted['q_partner_net_income_chf'], isNull);
    expect(persisted.containsKey('q_partner_birth_year'), isFalse);
    expect(persisted.containsKey('q_spouse_avs_contribution_years'), isFalse);
    expect(mockSecureStorage.containsKey('q_partner_net_income_chf'), isFalse);
    expect(mockSecureStorage.containsKey('q_partner_salary'), isFalse);
    expect(provider.profile!.etatCivil, CoachCivilStatus.divorce);
    expect(provider.profile!.conjoint, isNull);

    await ReportPersistenceService.setMiniOnboardingCompleted(true);
    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();

    expect(reloaded.profile, isNotNull);
    expect(reloaded.profile!.etatCivil, CoachCivilStatus.divorce);
    expect(reloaded.profile!.conjoint, isNull);
  });

  test('save_fact spouse identity and AVS keys hydrate without spouse income',
      () async {
    final profile = await profileAfterSaveFacts([
      const MapEntry('birthYear', 1980),
      const MapEntry('householdType', 'married'),
      const MapEntry('spouseBirthYear', 1982),
      const MapEntry('spouseAvsContributionYears', 22),
    ]);

    expect(profile.conjoint, isNotNull);
    expect(profile.conjoint!.birthYear, 1982);
    expect(profile.conjoint!.salaireBrutMensuel, 0);
    expect(profile.conjoint!.prevoyance!.anneesContribuees, 22);
  });

  test('save_fact backend goal values do not collapse to retirement', () async {
    final cases = {
      'house': GoalAType.achatImmo,
      'retire': GoalAType.retraite,
      'emergency': GoalAType.custom,
      'invest': GoalAType.independance,
      'optimize_taxes': GoalAType.custom,
      'other': GoalAType.custom,
    };

    for (final entry in cases.entries) {
      final profile = await profileAfterSaveFacts([
        const MapEntry('birthYear', 1985),
        MapEntry('goal', entry.key),
      ]);
      expect(profile.goalA.type, entry.value, reason: entry.key);
    }
  });

  test(
      'save_fact self-employed income clears stale gross salary only when safe',
      () async {
    final independent = await profileAfterSaveFacts([
      const MapEntry('birthYear', 1985),
      const MapEntry('incomeGrossYearly', 120000.0),
      const MapEntry('selfEmployedNetIncome', 90000.0),
    ]);

    expect(independent.employmentStatus, 'independant');
    expect(independent.selfEmployedNetIncome, 90000.0);
    expect(independent.salaireBrutMensuel, closeTo(8620.69, 0.01));

    mockSecureStorage.clear();
    SharedPreferences.setMockInitialValues({});
    final provider = CoachProfileProvider();
    expect(await provider.applySaveFact('birthYear', 1985), isTrue);
    expect(await provider.applySaveFact('incomeGrossYearly', 60000.0), isTrue);
    expect(await provider.applySaveFact('employmentStatus', 'mixed'), isTrue);
    expect(
      await provider.applySaveFact('selfEmployedNetIncome', 96000.0),
      isTrue,
    );

    expect(provider.profile!.employmentStatus, 'mixte');
    expect(provider.profile!.selfEmployedNetIncome, 96000.0);
  });

  test('save_fact savings, wealth, and 3a keys stay distinct', () async {
    final profile = await profileAfterSaveFacts([
      const MapEntry('birthYear', 1985),
      const MapEntry('pillar3aBalance', 42000.0),
      const MapEntry('totalSavings', 30000.0),
      const MapEntry('wealthEstimate', 250000.0),
    ]);

    final patrimoineJson = profile.patrimoine.toJson();
    expect(profile.prevoyance.totalEpargne3a, 42000.0);
    expect(profile.patrimoine.epargneLiquide, 30000.0);
    expect(patrimoineJson['wealthEstimate'], 250000.0);
    expect(profile.patrimoine.totalPatrimoine, 250000.0);
  });

  test('wealth estimate is gross estimate, not a cap on detailed components',
      () async {
    final profile = CoachProfile.fromWizardAnswers({
      'q_birth_year': 1985,
      'q_wealth_estimate': 250000.0,
      'q_cash_total': 30000.0,
      'q_investments_total': 300000.0,
    });

    expect(profile.patrimoine.wealthEstimate, 250000.0);
    expect(profile.patrimoine.totalPatrimoine, 330000.0);
  });
}
