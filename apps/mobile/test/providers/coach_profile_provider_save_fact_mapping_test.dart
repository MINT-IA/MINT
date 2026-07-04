import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/property_transmission_calculator.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockSecureStorage = <String, String>{};

  setUp(() {
    mockSecureStorage.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            if (value != null) mockSecureStorage[key] = value;
            return null;
          case 'read':
            final key = call.arguments['key'] as String;
            return mockSecureStorage[key];
          case 'delete':
            final key = call.arguments['key'] as String;
            mockSecureStorage.remove(key);
            return null;
          case 'deleteAll':
            mockSecureStorage.clear();
            return null;
          default:
            return null;
        }
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

  test('applySaveFact maps allowlist facts into live CoachProfile fields',
      () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('birthYear', 1970), isTrue);
    expect(await provider.applySaveFact('incomeGrossYearly', 120000), isTrue);
    expect(await provider.applySaveFact('nationality', 'us'), isTrue);
    expect(provider.profile!.nationality, 'US');
    expect(provider.profile!.canContribute3a, isFalse);

    expect(await provider.applySaveFact('pillar3aBalance', 12345), isTrue);
    expect(provider.profile!.prevoyance.totalEpargne3a, 12345);

    expect(await provider.applySaveFact('totalSavings', 25000), isTrue);
    expect(provider.profile!.patrimoine.epargneLiquide, 25000);

    expect(await provider.applySaveFact('wealthEstimate', 100000), isTrue);
    expect(provider.profile!.patrimoine.epargneLiquide, 25000);
    expect(provider.profile!.patrimoine.investissements, 75000);
    expect(provider.profile!.patrimoine.totalPatrimoine, 100000);

    expect(await provider.applySaveFact('mortgageBalance', 420000), isTrue);
    expect(provider.profile!.patrimoine.mortgageBalance, 420000);

    expect(await provider.applySaveFact('mortgageRate', 1.75), isTrue);
    expect(provider.profile!.patrimoine.mortgageRate, 1.75);

    expect(await provider.applySaveFact('goal', 'house'), isTrue);
    expect(provider.profile!.goalA.type, GoalAType.achatImmo);

    expect(await provider.applySaveFact('hasDebt', true), isTrue);
    expect(provider.answersSnapshot['q_has_consumer_debt'], isTrue);
    expect(provider.profile!.dettes.hasDette, isFalse);

    expect(await provider.applySaveFact('totalDebt', 15000), isTrue);
    expect(provider.profile!.dettes.totalDettes, 15000);
    expect(provider.profile!.dettes.nonVentilee, 15000);
    expect(
      provider.answersSnapshot.containsKey('_coach_dettes_autres'),
      isFalse,
    );

    expect(await provider.applySaveFact('avsContributionYears', 32), isTrue);
    expect(provider.profile!.prevoyance.anneesContribuees, 32);

    expect(await provider.applySaveFact('hasAvsGaps', true), isTrue);
    expect(provider.profile!.prevoyance.lacunesAVS, greaterThan(0));

    expect(
        await provider.applySaveFact('selfEmployedNetIncome', 90000), isTrue);
    expect(provider.profile!.employmentStatus, 'independant');
    expect(provider.profile!.salaireBrutMensuel, greaterThan(0));

    expect(await provider.applySaveFact('has2ndPillar', false), isTrue);
    expect(provider.profile!.prevoyance.avoirLppTotal, 0);

    expect(await provider.applySaveFact('hasVoluntaryLpp', true), isTrue);
    expect(provider.profile!.prevoyance.avoirLppTotal, greaterThan(0));

    expect(await provider.applySaveFact('spouseBirthYear', 1984), isTrue);
    expect(
        await provider.applySaveFact('spouseIncomeNetMonthly', 5000), isTrue);
    expect(provider.profile!.conjoint?.birthYear, 1984);
    expect(
        provider.profile!.conjoint?.salaireBrutMensuel, closeTo(5747.13, 0.01));

    expect(
        await provider.applySaveFact('spouseAvsContributionYears', 20), isTrue);
    expect(provider.profile!.conjoint?.prevoyance?.anneesContribuees, 20);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_nationality'], 'US');
    expect(answers.containsKey('q_is_fatca_resident'), isFalse);
    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(restored.nationality, 'US');
    expect(restored.canContribute3a, isFalse);
  });

  test('applySaveFact records source date provenance and restores it',
      () async {
    final provider = CoachProfileProvider();
    final sourceDate = DateTime.utc(2026, 1, 31);

    expect(
      await provider.applySaveFact(
        'canton',
        'VD',
        source: ProfileDataSource.certificate,
        sourceDate: sourceDate,
      ),
      isTrue,
    );

    expect(
        provider.profile!.dataSources['canton'], ProfileDataSource.certificate);
    expect(provider.profile!.dataSourceDates['canton'], sourceDate);
    expect(provider.profile!.dataTimestamps['canton'], isNotNull);

    expect(
      await provider.applySaveFact(
        'parentAnnualLivingCosts',
        72000,
        source: ProfileDataSource.userInput,
        sourceDate: sourceDate,
      ),
      isTrue,
    );
    expect(
      provider.profile!.dataSources['parentAnnualLivingCosts'],
      ProfileDataSource.userInput,
    );
    expect(
      provider.profile!.dataSourceDates['parentAnnualLivingCosts'],
      sourceDate,
    );

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_parent_annual_living_costs'], 72000);
    final restored = CoachProfile.fromWizardAnswers(answers);

    expect(restored.dataSources['canton'], ProfileDataSource.certificate);
    expect(restored.dataSourceDates['canton'], sourceDate);
    expect(
      restored.dataSources['parentAnnualLivingCosts'],
      ProfileDataSource.userInput,
    );
    expect(restored.dataSourceDates['parentAnnualLivingCosts'], sourceDate);
  });

  test('householdType couple and family do not fall back to single', () async {
    final couple = CoachProfile.fromWizardAnswers({
      'q_civil_status': 'couple',
      'q_net_income_period_chf': 5000,
    });
    final family = CoachProfile.fromWizardAnswers({
      'q_civil_status': 'family',
      'q_children': 2,
      'q_net_income_period_chf': 5000,
    });

    expect(couple.etatCivil, CoachCivilStatus.concubinage);
    expect(family.etatCivil, CoachCivilStatus.concubinage);
    expect(family.nombreEnfants, 2);
  });

  test('mergeAnswers accepts fp payloads and persists field provenance',
      () async {
    final provider = CoachProfileProvider();
    final sourceDate = DateTime.utc(2026, 2, 15);

    await provider.mergeAnswers(
      {
        'fp:patrimoine.propertyMarketValue': 1200000,
        'fp:patrimoine.targetPropertyValue': 950000,
        'fp:patrimoine.mortgageBalance': 420000,
        'fp:depenses.loyer': 2100,
        'fp:savingsMonthly': 750,
        'fp:nombreEnfants': 2,
      },
      source: ProfileDataSource.crossValidated,
      sourceDate: sourceDate,
    );

    final profile = provider.profile!;
    expect(profile.patrimoine.propertyMarketValue, 1200000);
    expect(profile.patrimoine.targetPropertyValue, 950000);
    expect(profile.patrimoine.mortgageBalance, 420000);
    expect(profile.depenses.loyer, 2100);
    expect(profile.nombreEnfants, 2);

    expect(
      profile.dataSources['patrimoine.propertyMarketValue'],
      ProfileDataSource.crossValidated,
    );
    expect(
      profile.dataSources['patrimoine.targetPropertyValue'],
      ProfileDataSource.crossValidated,
    );
    expect(
        profile.dataSourceDates['patrimoine.propertyMarketValue'], sourceDate);
    expect(
        profile.dataSourceDates['patrimoine.targetPropertyValue'], sourceDate);
    expect(profile.dataTimestamps['patrimoine.propertyMarketValue'], isNotNull);
    expect(profile.dataSources['depenses.loyer'],
        ProfileDataSource.crossValidated);
    expect(
        profile.dataSources['nombreEnfants'], ProfileDataSource.crossValidated);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_property_market_value'], 1200000);
    expect(answers['q_target_property_value'], 950000);
    expect(answers['q_mortgage_balance'], 420000);
    expect(answers['q_housing_cost_period_chf'], 2100);
    expect(answers['q_savings_monthly'], 750);
    expect(answers['q_children'], 2);

    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(restored.patrimoine.propertyMarketValue, 1200000);
    expect(restored.patrimoine.targetPropertyValue, 950000);
    expect(restored.patrimoine.mortgageBalance, 420000);
    expect(restored.depenses.loyer, 2100);
    expect(restored.nombreEnfants, 2);
    expect(
      restored.dataSources['patrimoine.propertyMarketValue'],
      ProfileDataSource.crossValidated,
    );
    expect(
        restored.dataSourceDates['patrimoine.propertyMarketValue'], sourceDate);
  });

  test('mergeAnswers persists mortgage computed field paths as estimates',
      () async {
    final provider = CoachProfileProvider();

    await provider.mergeAnswers(
      const {
        'fp:patrimoine.mortgageCapacity': 880000,
        'fp:patrimoine.estimatedMonthlyPayment': 3600,
      },
      source: ProfileDataSource.estimated,
    );

    final profile = provider.profile!;
    expect(profile.patrimoine.mortgageCapacity, 880000);
    expect(profile.patrimoine.estimatedMonthlyPayment, 3600);
    expect(
      profile.dataSources['patrimoine.mortgageCapacity'],
      ProfileDataSource.estimated,
    );
    expect(
      profile.dataSources['patrimoine.estimatedMonthlyPayment'],
      ProfileDataSource.estimated,
    );

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['_coach_mortgage_capacity'], 880000);
    expect(answers['_coach_estimated_monthly_payment'], 3600);

    final restored = CoachProfile.fromWizardAnswers(answers);
    expect(restored.patrimoine.mortgageCapacity, 880000);
    expect(restored.patrimoine.estimatedMonthlyPayment, 3600);
    expect(
      restored.dataSources['patrimoine.mortgageCapacity'],
      ProfileDataSource.estimated,
    );
  });

  test('mergeAnswers persists a stable local profile owner id', () async {
    final provider = CoachProfileProvider();

    await provider.mergeAnswers(const {
      'q_canton': 'VD',
      'q_gross_salary_annual': 96000,
    });
    final ownerId = provider.runtimeProfileOwnerId;

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['_coach_created_at'], isA<String>());
    expect(answers['_coach_profile_owner_id'], ownerId);

    final reloadedProvider = CoachProfileProvider();
    await reloadedProvider.loadFromWizard();

    expect(reloadedProvider.runtimeProfileOwnerId, ownerId);

    SharedPreferences.setMockInitialValues({});
    final afterReinstallProvider = CoachProfileProvider();
    await afterReinstallProvider.mergeAnswers(const {
      'q_canton': 'GE',
      'q_gross_salary_annual': 97000,
    });

    expect(afterReinstallProvider.runtimeProfileOwnerId, ownerId);
    final afterReinstallAnswers = await ReportPersistenceService.loadAnswers();
    expect(afterReinstallAnswers['_coach_profile_owner_id'], ownerId);
  });

  test('mergeAnswers stamps transmit property composed inputs', () async {
    final provider = CoachProfileProvider();
    final sourceDate = DateTime.utc(2026, 7, 1);

    await provider.mergeAnswers(
      const {
        'q_children': 2,
        'fp:patrimoine.propertyMarketValue': 1200000,
        'fp:patrimoine.mortgageBalance': 420000,
        'fp:patrimoine.epargneLiquide': 120000,
        '_coach_avs_rente_estimee': 6333.333333333333,
        'q_housing_cost_period_chf': 6600,
        'q_lamal_premium_monthly_chf': 400,
        '_transmit_property_cash_paid_by_recipient': 50000,
        '_transmit_property_mortgage_assumed_by_recipient': 420000,
        '_transmit_property_recipient_relationship': 'descendant',
        '_transmit_property_retained_right': 'habitation',
        '_transmit_property_avancement_hoirie': true,
      },
      source: ProfileDataSource.userInput,
      sourceDate: sourceDate,
    );

    final profile = provider.profile!;
    expect(profile.nombreEnfants, 2);
    expect(profile.patrimoine.propertyMarketValue, 1200000);
    expect(profile.patrimoine.mortgageBalance, 420000);
    expect(profile.patrimoine.epargneLiquide, 120000);
    expect(profile.prevoyance.renteAVSEstimeeMensuelle,
        closeTo(6333.333333333333, 0.001));
    expect(profile.depenses.totalMensuel, 7000);
    final annualRetirementIncome =
        (profile.prevoyance.renteAVSEstimeeMensuelle! * 12) +
            (profile.prevoyance.projectedRenteLpp ?? 0);
    expect(annualRetirementIncome, closeTo(76000, 0.01));

    final scenario = PropertyTransmissionCalculator.compute(
      PropertyTransmissionInputs(
        canton: profile.canton,
        propertyMarketValue: profile.patrimoine.propertyMarketValue,
        mortgageBalance: profile.patrimoine.mortgageBalance,
        cashPaidByRecipient:
            provider.transmitPropertyScenarioAssumptions['cashPaidByRecipient']
                as double?,
        mortgageAssumedByRecipient:
            provider.transmitPropertyScenarioAssumptions[
                'mortgageAssumedByRecipient'] as double?,
        parentLiquidAssets: profile.patrimoine.epargneLiquide,
        parentAnnualRetirementIncome: annualRetirementIncome,
        parentAnnualLivingCosts: profile.depenses.totalMensuel * 12,
        heirsCount: profile.nombreEnfants,
        retainedRight:
            provider.transmitPropertyScenarioAssumptions['retainedRight']
                    as String? ??
                'none',
        avancementHoirie:
            provider.transmitPropertyScenarioAssumptions['avancementHoirie']
                    as bool? ??
                true,
      ),
    );
    expect(scenario.requiresInputCompletion, isFalse);
    expect(scenario.computed.annualRetirementMargin, -8000);

    expect(
      profile.dataSources['prevoyance.renteAVSEstimeeMensuelle'],
      ProfileDataSource.userInput,
    );
    expect(
      profile.dataSourceDates['prevoyance.renteAVSEstimeeMensuelle'],
      sourceDate,
    );
    expect(
      profile.dataSourceDates['patrimoine.mortgageBalance'],
      sourceDate,
    );
    expect(profile.dataSourceDates['patrimoine.epargneLiquide'], sourceDate);
    expect(profile.dataSourceDates['depenses.loyer'], sourceDate);
    expect(profile.dataSourceDates['depenses.assuranceMaladie'], sourceDate);

    expect(provider.transmitPropertyScenarioAssumptions, {
      'cashPaidByRecipient': 50000.0,
      'mortgageAssumedByRecipient': 420000.0,
      'recipientRelationship': 'descendant',
      'retainedRight': 'habitation',
      'avancementHoirie': true,
    });
  });

  test('property value wizard alias reloads into canonical field path',
      () async {
    final profile = CoachProfile.fromWizardAnswers({
      'q_property_value': 950000,
      'q_mortgage_balance': 300000,
      'q_net_income_period_chf': 5000,
    });

    expect(profile.patrimoine.propertyMarketValue, 950000);
    expect(profile.patrimoine.mortgageBalance, 300000);
  });

  test('updateProfile persists keys that fromWizardAnswers can reload',
      () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile(
      birthYear: 1975,
      canton: 'VD',
      salaireBrutMensuel: 8000,
      employmentStatus: 'salarie',
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2040),
        label: 'Retraite',
      ),
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 100000,
        nombre3a: 2,
        totalEpargne3a: 30000,
      ),
      patrimoine: const PatrimoineProfile(
        epargneLiquide: 20000,
        investissements: 40000,
      ),
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_gross_salary_annual'], 96000);
    expect(answers['_coach_avoir_lpp'], 100000);
    expect(answers['q_3a_accounts_count'], 2);
    expect(answers['q_3a_total'], 30000);
    expect(answers['q_cash_total'], 20000);
    expect(answers['q_investments_total'], 40000);

    expect(answers.containsKey('q_salaire'), isFalse);
    expect(answers.containsKey('q_avoir_lpp'), isFalse);
    expect(answers.containsKey('q_nombre_3a'), isFalse);
    expect(answers.containsKey('q_investissements'), isFalse);
  });
}
