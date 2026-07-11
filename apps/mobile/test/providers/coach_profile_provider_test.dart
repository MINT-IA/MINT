import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageValues = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorage, (call) async {
    final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    final key = args['key'] as String?;
    if (call.method == 'write' && key != null) {
      secureStorageValues[key] = args['value'] as String;
      return null;
    }
    if (call.method == 'read' && key != null) return secureStorageValues[key];
    if (call.method == 'readAll') return secureStorageValues;
    if (call.method == 'delete' && key != null) {
      secureStorageValues.remove(key);
      return null;
    }
    if (call.method == 'deleteAll') {
      secureStorageValues.clear();
      return null;
    }
    return null;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorageValues.clear();
  });

  test('updateProfile persists liquid savings on the readable cash key',
      () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      patrimoine: const PatrimoineProfile(epargneLiquide: 88000),
      userProvidedFields: const {
        'liquidSavings',
        'liquidSavingsAmount',
      },
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_cash_total', 88000));
    expect(answers.containsKey('q_epargne_liquide'), isFalse);
    expect(CoachProfile.fromWizardAnswers(answers).patrimoine.epargneLiquide,
        88000);
  });

  test('updateProfile does not persist emergency-fund heuristic as cash',
      () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({
      'q_emergency_fund': 'yes_6months',
      'q_housing_cost_period_chf': 2200,
      'q_lamal_premium_monthly_chf': 420,
    });

    final heuristicProfile = provider.profile!;
    expect(heuristicProfile.patrimoine.epargneLiquide, 15720);
    expect(heuristicProfile.userProvidedFields, contains('liquidSavings'));
    expect(
      heuristicProfile.userProvidedFields,
      isNot(contains('liquidSavingsAmount')),
    );

    provider.updateProfile(heuristicProfile.copyWith(canton: 'GE'));
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('q_cash_total'), isFalse);
    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(restored.patrimoine.epargneLiquide, 15720);
    expect(
      restored.userProvidedFields,
      isNot(contains('liquidSavingsAmount')),
    );
  });

  test('smart flow does not persist estimated savings as explicit cash',
      () async {
    final provider = CoachProfileProvider();

    await provider.updateFromSmartFlow(
      age: 40,
      grossSalary: 100000,
      canton: 'VD',
    );

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('q_cash_total'), isFalse);
    expect(
      provider.profile?.userProvidedFields,
      isNot(contains('liquidSavingsAmount')),
    );
    expect(
      CoachProfile.fromWizardAnswers(answers).userProvidedFields,
      isNot(contains('liquidSavingsAmount')),
    );
  });

  test('updateProfile does not rewrite cash when stored cash key is null',
      () async {
    SharedPreferences.setMockInitialValues({
      'wizard_answers_v2': json.encode({
        'q_emergency_fund': 'yes_6months',
        'q_housing_cost_period_chf': 2200,
        'q_lamal_premium_monthly_chf': 420,
        'q_cash_total': null,
      }),
    });
    final provider = CoachProfileProvider();
    final heuristicProfile = CoachProfile.fromWizardAnswers({
      'q_emergency_fund': 'yes_6months',
      'q_housing_cost_period_chf': 2200,
      'q_lamal_premium_monthly_chf': 420,
    });

    provider.updateProfile(heuristicProfile.copyWith(canton: 'GE'));
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('q_cash_total'), isFalse);
    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(restored.patrimoine.epargneLiquide, 15720);
    expect(
      restored.userProvidedFields,
      isNot(contains('liquidSavingsAmount')),
    );
  });

  test(
      'loadAnswers quarantines legacy cash copied from emergency-fund heuristic',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_emergency_fund': 'yes_6months',
      'q_housing_cost_period_chf': 2200,
      'q_lamal_premium_monthly_chf': 420,
      'q_cash_total': 15720,
    });

    final answers = await ReportPersistenceService.loadAnswers();

    expect(answers.containsKey('q_cash_total'), isFalse);
    expect(secureStorageValues.containsKey('q_cash_total'), isFalse);
    expect(answers, containsPair('q_cash_total_unconfirmed_legacy', 15720));
    expect(
      secureStorageValues.containsKey('q_cash_total_unconfirmed_legacy'),
      isTrue,
    );
    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(restored.patrimoine.epargneLiquide, 15720);
    expect(
      restored.userProvidedFields,
      isNot(contains('liquidSavingsAmount')),
    );
  });

  test('loadAnswers quarantines yearly-housing legacy emergency cash',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_emergency_fund': 'yes_3months',
      'q_housing_cost_period_chf': 24000,
      'q_housing_pay_frequency': 'yearly',
      'q_lamal_premium_monthly_chf': 500,
      'q_cash_total': 7500,
    });

    final answers = await ReportPersistenceService.loadAnswers();

    expect(answers.containsKey('q_cash_total'), isFalse);
    expect(answers, containsPair('q_cash_total_unconfirmed_legacy', 7500));
    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(
      restored.userProvidedFields,
      isNot(contains('liquidSavingsAmount')),
    );
  });

  test('loadAnswers keeps legacy cash when edited expenses no longer match',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_emergency_fund': 'yes_6months',
      'q_housing_cost_period_chf': 1800,
      'q_lamal_premium_monthly_chf': 450,
      'q_cash_total': 15720,
    });

    final answers = await ReportPersistenceService.loadAnswers();

    expect(answers, containsPair('q_cash_total', 15720));
    expect(answers.containsKey('q_cash_total_unconfirmed_legacy'), isFalse);
    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(restored.userProvidedFields, contains('liquidSavingsAmount'));
  });

  test('loadAnswers quarantines legacy smart-flow estimated cash', () async {
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': DateTime.now().year - 40,
      'q_gross_salary_annual': 100000,
      'q_cash_total': 75000,
    });

    final answers = await ReportPersistenceService.loadAnswers();

    expect(answers.containsKey('q_cash_total'), isFalse);
    expect(answers, containsPair('q_cash_total_unconfirmed_legacy', 75000));
    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(
      restored.userProvidedFields,
      isNot(contains('liquidSavingsAmount')),
    );
  });

  test('mergeAnswers keeps user cash after legacy emergency quarantine',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_emergency_fund': 'yes_6months',
      'q_housing_cost_period_chf': 1800,
      'q_lamal_premium_monthly_chf': 450,
      'q_cash_total_unconfirmed_legacy': 15720,
    });

    final provider = CoachProfileProvider();
    await provider.mergeAnswers({'q_cash_total': 42000});

    final answers = await ReportPersistenceService.loadAnswers();

    expect(answers, containsPair('q_cash_total', 42000));
    expect(answers.containsKey('q_cash_total_unconfirmed_legacy'), isFalse);
    expect(
      answers,
      containsPair(
          '_coach_cash_total_source', ProfileDataSource.userInput.name),
    );
    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(restored.patrimoine.epargneLiquide, 42000);
    expect(restored.userProvidedFields, contains('liquidSavingsAmount'));
  });

  test('loadAnswers keeps exact heuristic cash when source is explicit',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_emergency_fund': 'yes_6months',
      'q_housing_cost_period_chf': 2200,
      'q_lamal_premium_monthly_chf': 420,
      'q_cash_total': 15720,
      '_coach_cash_total_source': ProfileDataSource.userInput.name,
    });

    final answers = await ReportPersistenceService.loadAnswers();

    expect(answers, containsPair('q_cash_total', 15720));
    expect(answers.containsKey('q_cash_total_unconfirmed_legacy'), isFalse);
    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(restored.patrimoine.epargneLiquide, 15720);
    expect(restored.userProvidedFields, contains('liquidSavingsAmount'));
  });

  test('loadAnswers keeps explicit zero cash even with emergency-fund answer',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_emergency_fund': 'yes_6months',
      'q_housing_cost_period_chf': 2200,
      'q_lamal_premium_monthly_chf': 420,
      'q_cash_total': 0,
    });

    final answers = await ReportPersistenceService.loadAnswers();

    expect(answers, containsPair('q_cash_total', 0));
    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(restored.patrimoine.epargneLiquide, 0);
    expect(restored.userProvidedFields, contains('liquidSavingsAmount'));
  });

  test('loadAnswers keeps explicit sourced cash that is not the heuristic',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_emergency_fund': 'yes_6months',
      'q_housing_cost_period_chf': 2200,
      'q_lamal_premium_monthly_chf': 420,
      'q_cash_total': 44000,
      '_coach_cash_total_source': ProfileDataSource.userInput.name,
    });

    final answers = await ReportPersistenceService.loadAnswers();

    expect(answers, containsPair('q_cash_total', 44000));
    expect(answers.containsKey('q_cash_total_unconfirmed_legacy'), isFalse);
    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(restored.patrimoine.epargneLiquide, 44000);
    expect(restored.userProvidedFields, contains('liquidSavingsAmount'));
  });

  test('updateProfile persists cash when provenance is explicit', () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      patrimoine: const PatrimoineProfile(epargneLiquide: 44000),
      dataSources: const {
        'patrimoine.epargneLiquide': ProfileDataSource.userInput,
      },
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    expect(
        provider.profile?.userProvidedFields, contains('liquidSavingsAmount'));
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_cash_total', 44000));
    expect(
        answers,
        containsPair(
            '_coach_cash_total_source', ProfileDataSource.userInput.name));
    expect(CoachProfile.fromWizardAnswers(answers).userProvidedFields,
        contains('liquidSavingsAmount'));
  });

  test('updateProfile does not persist unprovenanced copyWith cash', () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      patrimoine: const PatrimoineProfile(epargneLiquide: 44000),
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('q_cash_total'), isFalse);
    expect(CoachProfile.fromWizardAnswers(answers).userProvidedFields,
        isNot(contains('liquidSavingsAmount')));
  });

  test('updateInline treats zero cash as an explicit fact', () async {
    final provider = CoachProfileProvider();
    provider.updateProfile(CoachProfile.defaults());
    await Future<void>.delayed(Duration.zero);

    await provider.updateInline(epargneLiquide: 0);

    expect(provider.profile?.patrimoine.epargneLiquide, 0);
    expect(
        provider.profile?.userProvidedFields, contains('liquidSavingsAmount'));
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_cash_total', 0));
    expect(
      answers,
      containsPair(
          '_coach_cash_total_source', ProfileDataSource.userInput.name),
    );
    expect(CoachProfile.fromWizardAnswers(answers).userProvidedFields,
        contains('liquidSavingsAmount'));
  });

  test('open banking treats a zero-balance cash account as explicit cash',
      () async {
    final provider = CoachProfileProvider();
    provider.updateProfile(CoachProfile.defaults());
    await Future<void>.delayed(Duration.zero);

    await provider.updateFromOpenBanking(
      accounts: const [
        {
          'accountType': 'checking',
          'balance': 0,
        },
      ],
      categoryTotals: const {},
    );

    expect(provider.profile?.patrimoine.epargneLiquide, 0);
    expect(provider.profile?.dataSources['patrimoine.epargneLiquide'],
        ProfileDataSource.openBanking);
    expect(
        provider.profile?.userProvidedFields, contains('liquidSavingsAmount'));
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_cash_total', 0));
    expect(
      answers,
      containsPair(
        '_coach_cash_total_source',
        ProfileDataSource.openBanking.name,
      ),
    );
    expect(CoachProfile.fromWizardAnswers(answers).userProvidedFields,
        contains('liquidSavingsAmount'));
  });

  test('updateProfile persists 3a balance on the readable 3a total key',
      () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      prevoyance: const PrevoyanceProfile(totalEpargne3a: 42000),
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_3a_total', 42000));
    expect(answers.containsKey('q_total_3a'), isFalse);
    expect(CoachProfile.fromWizardAnswers(answers).prevoyance.totalEpargne3a,
        42000);
  });

  test('save_fact wealthEstimate writes its own readable estimate key',
      () async {
    final provider = CoachProfileProvider();

    final applied = await provider.applySaveFact('wealthEstimate', 350000);

    expect(applied, isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_wealth_estimate', 350000));
    expect(answers.containsKey('q_epargne_liquide'), isFalse);
    expect(provider.profile?.patrimoine.wealthEstimate, 350000);
    expect(provider.profile?.patrimoine.totalPatrimoine, 350000);
  });

  test('save_fact pillar3aBalance writes the readable 3a total key', () async {
    final provider = CoachProfileProvider();

    final applied = await provider.applySaveFact('pillar3aBalance', 42000);

    expect(applied, isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_3a_total', 42000));
    expect(answers.containsKey('q_total_3a'), isFalse);
    expect(provider.profile?.prevoyance.totalEpargne3a, 42000);
  });

  test('save_fact commune and gender hydrate readable identity keys', () async {
    final provider = CoachProfileProvider();

    final communeApplied = await provider.applySaveFact('commune', 'Lausanne');
    final genderApplied = await provider.applySaveFact('gender', 'F');

    expect(communeApplied, isTrue);
    expect(genderApplied, isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_commune', 'Lausanne'));
    expect(answers, containsPair('q_gender', 'F'));
    expect(provider.profile?.commune, 'Lausanne');
    expect(provider.profile?.gender, 'F');
  });

  test('updateProfile persists commune and gender on readable identity keys',
      () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      commune: 'Lausanne',
      gender: 'F',
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_commune', 'Lausanne'));
    expect(answers, containsPair('q_gender', 'F'));
    final rehydrated = CoachProfile.fromWizardAnswers(answers);
    expect(rehydrated.commune, 'Lausanne');
    expect(rehydrated.gender, 'F');
  });

  test('save_fact employmentRate and annualBonus hydrate income keys',
      () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('incomeGrossYearly', 120000), isTrue);
    expect(await provider.applySaveFact('employmentRate', 80), isTrue);
    expect(await provider.applySaveFact('annualBonus', 12000), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_employment_rate', 80));
    expect(answers, containsPair('q_annual_bonus', 12000));
    expect(provider.profile?.employmentRate, 80);
    expect(provider.profile?.bonusPourcentage, closeTo(10, 0.001));
    expect(provider.profile?.revenuBrutAnnuel, closeTo(132000, 0.001));
    expect(provider.profile?.toCoachingProfile().tauxActivite, 80);
  });

  test('updateProfile preserves 13-month salary, rate, and bonus shape',
      () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      salaireBrutMensuel: 10000,
      nombreDeMois: 13,
      bonusPourcentage: 5,
      employmentRate: 80,
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_nombre_mois', 13));
    expect(answers, containsPair('q_gross_salary_annual', 130000));
    expect(answers, containsPair('q_employment_rate', 80));
    expect(answers, containsPair('q_annual_bonus', 6500));
    final rehydrated = CoachProfile.fromWizardAnswers(answers);
    expect(rehydrated.salaireBrutMensuel, closeTo(10000, 0.001));
    expect(rehydrated.nombreDeMois, 13);
    expect(rehydrated.employmentRate, 80);
    expect(rehydrated.bonusPourcentage, closeTo(5, 0.001));
    expect(rehydrated.revenuBrutAnnuel, closeTo(136500, 0.001));
  });

  test('updateProfile clears stale employment rate and annual bonus keys',
      () async {
    final provider = CoachProfileProvider();
    final partTimeWithBonus = CoachProfile.defaults().copyWith(
      salaireBrutMensuel: 10000,
      nombreDeMois: 12,
      bonusPourcentage: 10,
      employmentRate: 80,
    );
    final fullTimeWithoutBonus = CoachProfile.defaults().copyWith(
      salaireBrutMensuel: 0,
      nombreDeMois: 12,
      employmentRate: 100,
    );

    provider.updateProfile(partTimeWithBonus);
    await Future<void>.delayed(Duration.zero);
    provider.updateProfile(fullTimeWithoutBonus);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('q_employment_rate'), isFalse);
    expect(answers.containsKey('q_annual_bonus'), isFalse);
    expect(answers, containsPair('q_gross_salary_annual', 0));
    final rehydrated = CoachProfile.fromWizardAnswers(answers);
    expect(rehydrated.employmentRate, 100);
    expect(rehydrated.bonusPourcentage, isNull);
    expect(rehydrated.revenuBrutAnnuel, 0);
    expect(rehydrated.toCoachingProfile().tauxActivite, 100);
  });

  test('save_fact AVS gaps and contribution years hydrate AVS keys', () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('birthYear', 1970), isTrue);
    expect(await provider.applySaveFact('avsContributionYears', 30), isTrue);
    expect(await provider.applySaveFact('hasAvsGaps', true), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_avs_contribution_years', 30));
    expect(answers, containsPair('q_avs_lacunes_status', 'unknown'));
    expect(provider.profile?.prevoyance.anneesContribuees, 30);
    expect(provider.profile?.prevoyance.lacunesAVS, 2);
  });

  test('save_fact hasAvsGaps false clears AVS gap status', () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('birthYear', 1970), isTrue);
    expect(await provider.applySaveFact('hasAvsGaps', true), isTrue);
    expect(await provider.applySaveFact('hasAvsGaps', false), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_avs_lacunes_status', 'no_gaps'));
    expect(provider.profile?.prevoyance.lacunesAVS, isNull);
  });

  test('save_fact hasAvsGaps true preserves precise AVS status', () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({
      'q_birth_year': 1970,
      'q_avs_lacunes_status': 'lived_abroad',
      'q_avs_years_abroad': 4,
    });

    expect(await provider.applySaveFact('hasAvsGaps', true), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_avs_lacunes_status', 'lived_abroad'));
    expect(provider.profile?.prevoyance.lacunesAVS, 4);
  });

  test('save_fact hasAvsGaps true preserves arrived-late AVS status', () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({
      'q_birth_year': 1975,
      'q_avs_lacunes_status': 'arrived_late',
      'q_avs_arrival_year': 2005,
    });

    expect(await provider.applySaveFact('hasAvsGaps', true), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_avs_lacunes_status', 'arrived_late'));
    expect(answers, containsPair('q_avs_arrival_year', 2005));
    expect(provider.profile?.prevoyance.lacunesAVS, 9);
  });

  test('save_fact spouse facts hydrate readable conjoint keys', () async {
    final provider = CoachProfileProvider();
    provider.updateProfile(CoachProfile.defaults().copyWith(
      etatCivil: CoachCivilStatus.marie,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(
        await provider.applySaveFact('spouseIncomeNetMonthly', 7000), isTrue);
    expect(await provider.applySaveFact('spouseBirthYear', 1988), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_partner_net_income_chf', 7000));
    expect(answers, containsPair('q_partner_birth_year', 1988));
    expect(provider.profile?.conjoint?.birthYear, 1988);
    expect(
      provider.profile?.conjoint?.salaireBrutMensuel,
      closeTo(7000 / 0.87, 0.001),
    );
  });

  test('save_fact spouse birth year alone hydrates conjoint', () async {
    final provider = CoachProfileProvider();
    provider.updateProfile(CoachProfile.defaults().copyWith(
      etatCivil: CoachCivilStatus.marie,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(await provider.applySaveFact('spouseBirthYear', 1988), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_partner_birth_year', 1988));
    expect(answers['q_partner_net_income_chf'], isNull);
    expect(provider.profile?.conjoint?.birthYear, 1988);
    expect(provider.profile?.conjoint?.salaireBrutMensuel, isNull);
  });

  test('save_fact spouse facts are ignored for non-coupled profiles', () async {
    final provider = CoachProfileProvider();
    provider.updateProfile(CoachProfile.defaults());
    await Future<void>.delayed(Duration.zero);

    expect(provider.profile?.etatCivil, CoachCivilStatus.celibataire);
    expect(
        await provider.applySaveFact('spouseIncomeNetMonthly', 7000), isFalse);
    expect(await provider.applySaveFact('spouseBirthYear', 1988), isFalse);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_partner_net_income_chf'], isNull);
    expect(answers['q_partner_birth_year'], isNull);
    expect(secureStorageValues['q_partner_net_income_chf'], isNull);
    expect(provider.profile?.conjoint, isNull);
  });

  test('save_fact householdType single clears stale spouse answers', () async {
    final provider = CoachProfileProvider();
    provider.updateProfile(CoachProfile.defaults().copyWith(
      etatCivil: CoachCivilStatus.marie,
    ));
    await Future<void>.delayed(Duration.zero);
    expect(await provider.applySaveFact('spouseBirthYear', 1988), isTrue);
    expect(
        await provider.applySaveFact('spouseIncomeNetMonthly', 7000), isTrue);
    expect(provider.profile?.conjoint, isNotNull);
    expect(secureStorageValues['q_partner_net_income_chf'], isNotNull);

    expect(await provider.applySaveFact('householdType', 'single'), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(provider.profile?.etatCivil, CoachCivilStatus.celibataire);
    expect(provider.profile?.conjoint, isNull);
    expect(answers['q_partner_birth_year'], isNull);
    expect(answers['q_partner_net_income_chf'], isNull);
    expect(secureStorageValues['q_partner_net_income_chf'], isNull);
  });

  test('save_fact spouse birth year rejects impossible values when coupled',
      () async {
    final provider = CoachProfileProvider();
    provider.updateProfile(CoachProfile.defaults().copyWith(
      etatCivil: CoachCivilStatus.marie,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(await provider.applySaveFact('spouseBirthYear', 2200), isFalse);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_partner_birth_year'], isNull);
    expect(provider.profile?.conjoint, isNull);
  });

  test('save_fact spouse AVS contribution years hydrates conjoint prevoyance',
      () async {
    final provider = CoachProfileProvider();
    provider.updateProfile(
      CoachProfile.defaults().copyWith(etatCivil: CoachCivilStatus.marie),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
        await provider.applySaveFact('spouseAvsContributionYears', 35), isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_spouse_avs_contribution_years', 35));
    expect(provider.profile?.conjoint?.prevoyance?.anneesContribuees, 35);
  });

  test('updateProfile preserves spouse income through readable keys', () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      etatCivil: CoachCivilStatus.marie,
      conjoint: const ConjointProfile(
        birthYear: 1988,
        salaireBrutMensuel: 8000,
      ),
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_partner_birth_year', 1988));
    expect(answers['q_partner_net_income_chf'], closeTo(8000 * 0.87, 0.001));
    final rehydrated = CoachProfile.fromWizardAnswers(answers);
    expect(rehydrated.conjoint?.birthYear, 1988);
    expect(rehydrated.conjoint?.salaireBrutMensuel, closeTo(8000, 0.001));
  });

  test('updateProfile clears spouse answers and secure income when single',
      () async {
    final provider = CoachProfileProvider();
    final married = CoachProfile.defaults().copyWith(
      etatCivil: CoachCivilStatus.marie,
      conjoint: const ConjointProfile(
        birthYear: 1988,
        salaireBrutMensuel: 8000,
      ),
    );

    provider.updateProfile(married);
    await Future<void>.delayed(Duration.zero);
    var answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_partner_birth_year', 1988));
    expect(answers['q_partner_net_income_chf'], closeTo(8000 * 0.87, 0.001));
    expect(secureStorageValues['q_partner_net_income_chf'], isNotNull);
    secureStorageValues['q_partner_salary'] = 'legacy-secret';

    provider.updateProfile(married.copyWith(
      etatCivil: CoachCivilStatus.celibataire,
    ));
    await Future<void>.delayed(Duration.zero);

    answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_partner_birth_year'], isNull);
    expect(answers['q_partner_net_income_chf'], isNull);
    expect(secureStorageValues['q_partner_net_income_chf'], isNull);
    expect(secureStorageValues['q_partner_salary'], isNull);
    expect(CoachProfile.fromWizardAnswers(answers).conjoint, isNull);
  });

  test('updateProfile ignores non-null spouse on non-coupled profile',
      () async {
    final provider = CoachProfileProvider();
    final inconsistentSingle = CoachProfile.defaults().copyWith(
      conjoint: const ConjointProfile(
        birthYear: 1988,
        salaireBrutMensuel: 8000,
      ),
    );

    expect(inconsistentSingle.etatCivil, CoachCivilStatus.celibataire);
    expect(inconsistentSingle.conjoint, isNotNull);

    provider.updateProfile(inconsistentSingle);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_partner_birth_year'], isNull);
    expect(answers['q_partner_net_income_chf'], isNull);
    expect(secureStorageValues['q_partner_net_income_chf'], isNull);
    expect(CoachProfile.fromWizardAnswers(answers).conjoint, isNull);
  });

  test('save_fact debt facts hydrate readable debt keys', () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('totalDebt', 25000), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_has_consumer_debt', 'yes'));
    expect(answers, containsPair('_coach_dettes_autres', 25000));
    expect(provider.profile?.dettes.autresDettes, 25000);
    expect(provider.profile?.dettes.totalDettes, 25000);
  });

  test('save_fact totalDebt clamps negative values to no debt', () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('totalDebt', -500), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_has_consumer_debt', 'no'));
    expect(answers, containsPair('_coach_dettes_autres', 0));
    expect(provider.profile?.dettes.totalDettes, 0);
  });

  test('save_fact hasDebt false clears generic debt amount', () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('totalDebt', 25000), isTrue);
    expect(await provider.applySaveFact('hasDebt', false), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_has_consumer_debt', 'no'));
    expect(answers, containsPair('_coach_dettes_credit', 0));
    expect(answers, containsPair('_coach_dettes_leasing', 0));
    expect(answers, containsPair('_coach_dettes_autres', 0));
    expect(provider.profile?.dettes.totalDettes, 0);
  });

  test('save_fact hasDebt true re-enables debt fallback after false', () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('incomeGrossYearly', 120000), isTrue);
    expect(await provider.applySaveFact('totalDebt', 25000), isTrue);
    expect(await provider.applySaveFact('hasDebt', false), isTrue);
    expect(await provider.applySaveFact('hasDebt', true), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_has_consumer_debt', 'yes'));
    expect(answers['_coach_dettes_credit'], isNull);
    expect(answers['_coach_dettes_leasing'], isNull);
    expect(answers['_coach_dettes_autres'], isNull);
    expect(provider.profile?.dettes.creditConsommation, 6000);
    expect(provider.profile?.dettes.totalDettes, 6000);
  });

  test(
      'wizard debt ratio facts mark debt, housing, and monthly payments as provided',
      () {
    final profile = CoachProfile.fromWizardAnswers(const {
      'q_gross_salary_annual': 96000,
      'q_housing_cost_period_chf': 1800,
      'q_debt_payments_period_chf': 650,
      'q_has_consumer_debt': 'yes',
      'q_civil_status': 'celibataire',
      'q_children': 0,
    });

    expect(profile.depenses.loyer, 1800);
    expect(profile.dettes.totalMensualite, 650);
    expect(profile.dettes.creditConsommation, 650 * 24);
    expect(profile.userProvidedFields, contains('housingCost'));
    expect(profile.userProvidedFields, contains('monthlyDebtPayments'));
    expect(profile.userProvidedFields, contains('hasDebt'));
    expect(profile.userProvidedFields, contains('civilStatus'));
    expect(profile.userProvidedFields, contains('children'));
  });

  test('budget bridge excludes mortgage from debt payments', () {
    final profile = CoachProfile.fromWizardAnswers(const {
      'q_gross_salary_annual': 96000,
      'q_housing_cost_period_chf': 2200,
      'q_debt_payments_period_chf': 650,
      'q_has_consumer_debt': 'yes',
    });
    final withMortgage = profile.copyWith(
      dettes: profile.dettes.copyWith(mensualiteHypotheque: 2200),
    );

    final inputs = withMortgage.toBudgetInputs();

    expect(inputs.housingCost, 2200);
    expect(inputs.debtPayments, 650);
  });

  test('legacy leasing monthly is captured as a debt payment fact', () {
    final profile = CoachProfile.fromWizardAnswers(const {
      'q_gross_salary_annual': 96000,
      'q_has_leasing': 'yes',
      'q_leasing_monthly': 420,
    });

    expect(profile.dettes.mensualiteLeasing, 420);
    expect(profile.dettes.totalMensualite, 420);
    expect(profile.dettes.leasing, 420 * 24);
    expect(profile.userProvidedFields, contains('monthlyDebtPayments'));
    expect(profile.userProvidedFields, contains('hasDebt'));
  });

  test('save_fact goal writes the readable main goal key', () async {
    final provider = CoachProfileProvider();
    expect(await provider.applySaveFact('goal', 'house'), isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_main_goal', 'house'));
    expect(provider.profile?.goalA.type, GoalAType.achatImmo);
  });

  test('save_fact selfEmployedNetIncome hydrates independent income', () async {
    final provider = CoachProfileProvider();
    expect(
        await provider.applySaveFact('selfEmployedNetIncome', 120000), isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_self_employed_income', 120000));
    expect(answers, containsPair('q_net_income_period_chf', 120000));
    expect(answers, containsPair('q_pay_frequency', 'yearly'));
    expect(answers, containsPair('q_employment_status', 'independant'));
    expect(provider.profile?.employmentStatus, 'independant');
    expect(provider.profile?.toJson()['selfEmployedNetIncome'], 120000);
    final restored = CoachProfile.fromJson(provider.profile!.toJson());
    expect(restored.toJson()['selfEmployedNetIncome'], 120000);
  });

  test('save_fact companyProfitAnnual hydrates SA/Sarl profit envelope',
      () async {
    final provider = CoachProfileProvider();
    expect(await provider.applySaveFact('companyProfitAnnual', 200000), isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_company_profit_annual_chf', 200000));
    expect(answers.containsKey('q_self_employed_income'), isFalse);
    expect(provider.profile?.companyProfitAnnual, 200000);
    expect(
      provider.profile?.userProvidedFields,
      contains('companyProfitAnnual'),
    );
    final restored = CoachProfile.fromJson(provider.profile!.toJson());
    expect(restored.companyProfitAnnual, 200000);
  });

  test('save_fact has2ndPillar false disables LPP estimation', () async {
    final provider = CoachProfileProvider();
    expect(await provider.applySaveFact('birthYear', 1980), isTrue);
    expect(await provider.applySaveFact('incomeGrossYearly', 120000), isTrue);
    expect(await provider.applySaveFact('has2ndPillar', false), isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_has_pension_fund', 'no'));
    expect(provider.profile?.prevoyance.avoirLppTotal, 0);
  });

  test('save_fact hasVoluntaryLpp false preserves salaried LPP', () async {
    final provider = CoachProfileProvider();
    expect(await provider.applySaveFact('incomeGrossYearly', 120000), isTrue);
    expect(await provider.applySaveFact('has2ndPillar', true), isTrue);
    expect(await provider.applySaveFact('hasVoluntaryLpp', false), isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_has_voluntary_lpp', 'no'));
    expect(answers, containsPair('q_has_pension_fund', 'yes'));
  });

  test('save_fact hasVoluntaryLpp true hydrates pension fund cold-start',
      () async {
    final provider = CoachProfileProvider();
    expect(await provider.applySaveFact('hasVoluntaryLpp', true), isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_has_voluntary_lpp', 'yes'));
    expect(answers, containsPair('q_has_pension_fund', 'yes'));
    expect(provider.profile?.prevoyance.toJson()['hasVoluntaryLpp'], true);
  });

  test('save_fact hasVoluntaryLpp enables independent LPP path', () async {
    final provider = CoachProfileProvider();
    expect(await provider.applySaveFact('birthYear', 1980), isTrue);
    expect(await provider.applySaveFact('incomeGrossYearly', 120000), isTrue);
    expect(await provider.applySaveFact('employmentStatus', 'independant'),
        isTrue);
    expect(await provider.applySaveFact('hasVoluntaryLpp', true), isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_has_voluntary_lpp', 'yes'));
    expect(answers, containsPair('q_has_pension_fund', 'yes'));
    expect(provider.profile?.prevoyance.toJson()['hasVoluntaryLpp'], true);
    final restored = CoachProfile.fromJson(provider.profile!.toJson());
    expect(restored.prevoyance.toJson()['hasVoluntaryLpp'], true);
    expect(provider.profile?.prevoyance.avoirLppTotal, greaterThan(0));
  });
}
