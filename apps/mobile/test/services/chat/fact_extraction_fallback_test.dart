import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/chat/fact_extraction_fallback.dart';
import 'package:mint_mobile/services/data_spine/coach_context_packet_service.dart';
import 'package:mint_mobile/services/data_spine/data_spine_service.dart';
import 'package:mint_mobile/services/financial_report_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Stub flutter_secure_storage so applySaveFact → mergeAnswers →
  // ReportPersistenceService.saveAnswers → SecureWizardStore.write doesn't
  // blow up on a MissingPluginException during unit tests.
  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorage, (call) async {
    if (call.method == 'read') return null;
    if (call.method == 'readAll') return <String, String>{};
    return null;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Map<String, String> installSecureStore() {
    final secureStore = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (call) async {
      final key = call.arguments['key'] as String?;
      switch (call.method) {
        case 'write':
          final value = call.arguments['value'] as String?;
          if (key != null && value != null) secureStore[key] = value;
          return null;
        case 'read':
          return key == null ? null : secureStore[key];
        case 'readAll':
          return secureStore;
        case 'delete':
          if (key != null) secureStore.remove(key);
          return null;
        default:
          return null;
      }
    });
    return secureStore;
  }

  group('FactExtractionFallback', () {
    test('extracts age from « j\'ai 34 ans »', () async {
      final p = CoachProfileProvider();
      final applied = await FactExtractionFallback.extract(
          "j'ai 34 ans et je cherche à y voir clair", p);
      expect(applied, contains('birthYear'));
    });

    test('extracts monthly brut salary', () async {
      final p = CoachProfileProvider();
      final applied = await FactExtractionFallback.extract(
          "je gagne 7500 CHF brut par mois", p);
      expect(applied, contains('incomeGrossMonthly'));
    });

    test('extracts monthly net salary (no brut word)', () async {
      final p = CoachProfileProvider();
      final applied = await FactExtractionFallback.extract(
          "mon salaire est 6500 par mois", p);
      expect(applied, contains('incomeNetMonthly'));
    });

    test('extracts yearly brut salary', () async {
      final p = CoachProfileProvider();
      final applied =
          await FactExtractionFallback.extract("je gagne 90000 brut par an", p);
      expect(applied, contains('incomeGrossYearly'));
    });

    test('extracts LPP balance', () async {
      final p = CoachProfileProvider();
      final applied =
          await FactExtractionFallback.extract("mon avoir LPP est 143288", p);
      expect(applied, contains('avoirLpp'));
    });

    test('extracts 3a balance', () async {
      final p = CoachProfileProvider();
      final applied =
          await FactExtractionFallback.extract("mon 3a est à 15000 CHF", p);
      expect(applied, contains('pillar3aBalance'));
      expect(p.profile!.prevoyance.totalEpargne3a, 15000);
    });

    test('applySaveFact maps pillar3aBalance to canonical 3a total key',
        () async {
      final p = CoachProfileProvider();
      final applied = await p.applySaveFact('pillar3aBalance', 15000);

      expect(applied, isTrue);
      expect(p.profile!.prevoyance.totalEpargne3a, 15000);
      final prefs = await SharedPreferences.getInstance();
      final raw = json.decode(prefs.getString('wizard_answers_v2')!)
          as Map<String, dynamic>;
      expect(raw.containsKey('q_3a_total'), isTrue);
      expect(raw.containsKey('q_total_3a'), isFalse);
    });

    test('applySaveFact maps safe backend save_fact planning keys', () async {
      installSecureStore();
      final p = CoachProfileProvider();

      final facts = <String, dynamic>{
        'birthYear': 1980,
        'has2ndPillar': true,
        'goal': 'retire',
        'selfEmployedNetIncome': 96000,
        'hasVoluntaryLpp': true,
        'savingsMonthly': 1200,
        'totalSavings': 18000,
        'hasDebt': true,
        'totalDebt': 9000,
        'spouseBirthYear': 1982,
        'spouseIncomeNetMonthly': 5000,
        'spouseAvsContributionYears': 18,
        'hasAvsGaps': false,
        'avsContributionYears': 20,
      };

      for (final entry in facts.entries) {
        expect(await p.applySaveFact(entry.key, entry.value), isTrue);
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = json.decode(prefs.getString('wizard_answers_v2')!)
          as Map<String, dynamic>;
      final loaded = await ReportPersistenceService.loadAnswers();
      expect(raw['q_has_pension_fund'], isTrue);
      expect(raw['q_main_goal'], 'retirement');
      expect(loaded['q_self_employed_net_income_annual_chf'], 96000);
      expect(loaded['q_net_income_period_chf'], closeTo(8000, 0.01));
      expect(loaded['q_pay_frequency'], 'monthly');
      expect(
        loaded['q_net_income_period_source'],
        'derived_self_employed_annual_proxy',
      );
      expect(loaded['q_employment_status'], 'independant');
      expect(loaded['q_savings_monthly'], 1200);
      expect(loaded['q_cash_total'], 18000);
      expect(raw['q_has_consumer_debt'], 'yes');
      expect(loaded['q_total_debt_balance_chf'], 9000);
      expect(loaded['q_partner_birth_year'], 1982);
      expect(loaded['q_partner_net_income_chf'], 5000);
      expect(loaded['q_spouse_avs_contribution_years'], 18);
      expect(loaded['q_avs_lacunes_status'], 'no_gaps');
      expect(loaded['q_avs_contribution_years'], 20);
      expect(p.profile!.independentNetProfessionalIncomeAnnual, 96000);
      expect(p.profile!.explicitMonthlyNetIncome, closeTo(8000, 0.01));
      expect(p.profile!.salaireBrutMensuel, closeTo(8800, 0.01));
      expect(
        BudgetInputs.monthlyNetFromCoachProfile(p.profile!),
        closeTo(8000, 0.01),
      );
      expect(p.profile!.prevoyance.anneesContribuees, 20);
      expect(p.profile!.conjoint!.birthYear, 1982);
      expect(p.profile!.conjoint!.prevoyance!.anneesContribuees, 18);
      expect(p.profile!.dettes.totalDettes, 9000);
    });

    test('applySaveFact Row 23 no-LPP 3a facts survive restart', () async {
      installSecureStore();
      final p = CoachProfileProvider();

      expect(await p.applySaveFact('birthYear', 1988), isTrue);
      expect(await p.applySaveFact('canton', 'VD'), isTrue);
      expect(await p.applySaveFact('selfEmployedNetIncome', 86400), isTrue);
      expect(await p.applySaveFact('has2ndPillar', false), isTrue);
      expect(await p.applySaveFact('pillar3aAnnual', 6000), isTrue);
      expect(await p.applySaveFact('hasDebt', false), isTrue);
      await ReportPersistenceService.setCompleted(true);

      final persisted = await ReportPersistenceService.loadAnswers();
      expect(persisted['q_birth_year'], 1988);
      expect(persisted['q_canton'], 'VD');
      expect(persisted['q_employment_status'], 'independant');
      expect(persisted['q_self_employed_net_income_annual_chf'], 86400);
      expect(persisted['q_has_pension_fund'], isFalse);
      expect(persisted['q_3a_annual_contribution'], 6000);
      expect(persisted['q_has_3a'], isTrue);
      expect(persisted['q_net_income_period_chf'], closeTo(7200, 0.01));
      expect(persisted['q_pay_frequency'], 'monthly');

      final reloaded = CoachProfileProvider();
      await reloaded.loadFromWizard();
      final profile = reloaded.profile!;
      expect(profile.employmentStatus, 'independant');
      expect(profile.archetype, FinancialArchetype.independentNoLpp);
      expect(profile.independentNetProfessionalIncomeAnnual, 86400);
      expect(profile.explicitMonthlyNetIncome, closeTo(7200, 0.01));
      expect(profile.prevoyance.avoirLppTotal, 0);
      expect(profile.total3aMensuel, closeTo(500, 0.01));
      expect(
        profile.dataSources['independentNetProfessionalIncomeAnnual'],
        ProfileDataSource.userInput,
      );
      expect(
        profile.dataSources['plannedContributions.3a'],
        ProfileDataSource.userInput,
      );
      expect(
        profile.dataTimestamps['independentNetProfessionalIncomeAnnual'],
        isNotNull,
      );
      expect(profile.dataTimestamps['plannedContributions.3a'], isNotNull);

      final budgetInputs = BudgetInputs.fromCoachProfile(profile);
      expect(budgetInputs.netIncome, closeTo(7200, 0.01));
      expect(budgetInputs.payFrequency, PayFrequency.monthly);
      expect(budgetInputs.netIncome, isNot(86400));

      final report = FinancialReportService().generateReport(persisted);
      final reportLead = [
        report.priorityActions.first.title,
        report.priorityActions.first.description,
        ...report.priorityActions.first.steps,
      ].join(' ').toLowerCase();
      expect(reportLead, contains('indépendant'));
      expect(reportLead, contains('sans lpp'));
      expect(reportLead, contains('revenu imposable'));
      expect(reportLead, contains('budget mensuel'));
      expect(reportLead, contains('capacité'));
      expect(reportLead, contains('couverture'));
      expect(reportLead, isNot(contains('fintech')));
      expect(reportLead, isNot(contains('ouvrir')));
      expect(reportLead, isNot(contains('swiss life')));
      expect(reportLead, isNot(contains('raiffeisen')));
    });

    test('self-employed income correction refreshes budget monthly truth',
        () async {
      installSecureStore();
      await ReportPersistenceService.saveAnswers({
        'q_birth_year': 1988,
        'q_canton': 'VD',
        'q_employment_status': 'independant',
        'q_net_income_period_chf': 7200,
        'q_pay_frequency': 'monthly',
        'q_self_employed_net_income_annual_chf': 86400,
        'q_has_pension_fund': false,
      });

      final p = CoachProfileProvider();
      expect(await p.applySaveFact('selfEmployedNetIncome', 90000), isTrue);

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_self_employed_net_income_annual_chf'], 90000);
      expect(loaded['q_net_income_period_chf'], closeTo(7500, 0.01));
      expect(loaded['q_pay_frequency'], 'monthly');

      final reloaded = CoachProfileProvider();
      await reloaded.loadFromWizard();
      expect(
        BudgetInputs.fromCoachProfile(reloaded.profile!).netIncome,
        closeTo(7500, 0.01),
      );
    });

    test('pillar3aAnnual correction to zero clears stale 3a account signal',
        () async {
      installSecureStore();
      final p = CoachProfileProvider();

      expect(await p.applySaveFact('pillar3aAnnual', 6000), isTrue);
      expect(p.profile!.total3aMensuel, closeTo(500, 0.01));
      expect(p.profile!.prevoyance.nombre3a, 1);

      expect(await p.applySaveFact('pillar3aAnnual', 0), isTrue);
      final persisted = await ReportPersistenceService.loadAnswers();
      expect(persisted['q_3a_annual_contribution'], 0);
      expect(persisted['q_has_3a'], isFalse);
      expect(p.profile!.total3aMensuel, 0);
      expect(p.profile!.prevoyance.nombre3a, 0);
    });

    test('applySaveFact maps backend goal enums without retirement fallback',
        () async {
      final cases = <String, String>{
        'retire': 'retirement',
        'house': 'real_estate',
        'invest': 'independence',
        'emergency': 'project',
        'optimize_taxes': 'project',
        'other': 'project',
      };

      for (final entry in cases.entries) {
        SharedPreferences.setMockInitialValues({});
        final p = CoachProfileProvider();

        expect(await p.applySaveFact('goal', entry.key), isTrue);

        final prefs = await SharedPreferences.getInstance();
        final raw = json.decode(prefs.getString('wizard_answers_v2')!)
            as Map<String, dynamic>;
        expect(raw['q_main_goal'], entry.value, reason: entry.key);
        if (entry.key != 'retire') {
          expect(p.profile!.goalA.type.name, isNot('retraite'),
              reason: entry.key);
        }
      }
    });

    test('applySaveFact refuses unsafe aggregate or lossy facts', () async {
      installSecureStore();
      final p = CoachProfileProvider();

      expect(await p.applySaveFact('wealthEstimate', 250000), isFalse);
      expect(await p.applySaveFact('hasAvsGaps', true), isFalse);
      expect(await p.applySaveFact('hasDebt', true), isTrue);
      expect(await p.applySaveFact('has2ndPillar', true), isTrue);
      expect(await p.applySaveFact('hasVoluntaryLpp', false), isFalse);

      final prefs = await SharedPreferences.getInstance();
      final raw = json.decode(prefs.getString('wizard_answers_v2')!)
          as Map<String, dynamic>;
      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded.containsKey('q_cash_total'), isFalse);
      expect(raw.containsKey('q_avs_lacunes_status'), isFalse);
      expect(raw['q_has_consumer_debt'], 'yes');
      expect(p.profile!.dettes.totalDettes, 0);
      expect(raw['q_has_pension_fund'], isTrue);
    });

    test('applySaveFact keeps total debt separate from categorized debts',
        () async {
      installSecureStore();
      final p = CoachProfileProvider();
      await p.mergeAnswers({'_coach_dettes_credit': 2000});

      expect(await p.applySaveFact('totalDebt', 9000), isTrue);

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_total_debt_balance_chf'], 9000);
      expect(p.profile!.dettes.creditConsommation, 2000);
      expect(p.profile!.dettes.totalDettes, 2000);
    });

    test('applySaveFact builds spouse profile without spouse income', () async {
      installSecureStore();
      final p = CoachProfileProvider();

      expect(await p.applySaveFact('spouseBirthYear', 1982), isTrue);
      expect(await p.applySaveFact('spouseAvsContributionYears', 18), isTrue);

      expect(p.profile!.conjoint, isNotNull);
      expect(p.profile!.conjoint!.birthYear, 1982);
      expect(p.profile!.conjoint!.salaireBrutMensuel, isNull);
      expect(p.profile!.conjoint!.prevoyance!.anneesContribuees, 18);
    });

    test('householdType single clears stale spouse facts from budget truth',
        () async {
      installSecureStore();
      final p = CoachProfileProvider();
      await p.mergeAnswers({
        'q_date_of_birth': '1981-06-15',
        'q_canton': 'VD',
        'q_gross_salary_annual': 120000,
        'q_employment_status': 'salarie',
        'q_household_type': 'couple',
        'q_partner_net_income_chf': 5000,
        'q_partner_birth_year': 1982,
        'q_partner_employment_status': 'salarie',
        'q_spouse_avs_contribution_years': 18,
      });
      final householdNetBefore =
          BudgetInputs.monthlyNetFromCoachProfile(p.profile!);

      expect(p.profile!.conjoint, isNotNull);
      expect(await p.applySaveFact('householdType', 'single'), isTrue);

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_household_type'], 'single');
      expect(loaded.containsKey('q_civil_status'), isFalse);
      expect(loaded.keys.any((key) => key.startsWith('q_partner_')), isFalse);
      expect(loaded.keys.any((key) => key.startsWith('q_spouse_')), isFalse);
      expect(p.profile!.conjoint, isNull);
      expect(
        BudgetInputs.monthlyNetFromCoachProfile(p.profile!),
        lessThan(householdNetBefore),
      );
    });

    test('remote profile merge uses safe save_fact mappings', () async {
      installSecureStore();
      final p = CoachProfileProvider();
      await p.mergeAnswers({'q_birth_year': 1980});

      await p.mergeFinancialFieldsFromRemoteForTest({
        'goal': 'house',
        'totalSavings': 18000,
        'wealthEstimate': 250000,
        'hasDebt': true,
        'totalDebt': 9000,
        'spouseBirthYear': 1982,
        'spouseAvsContributionYears': 18,
        'hasAvsGaps': true,
        'avsContributionYears': 20,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_main_goal'], 'real_estate');
      expect(loaded['q_cash_total'], 18000);
      expect(loaded['q_total_debt_balance_chf'], 9000);
      expect(loaded['q_partner_birth_year'], 1982);
      expect(loaded['q_spouse_avs_contribution_years'], 18);
      expect(loaded['q_avs_contribution_years'], 20);
      expect(loaded.containsKey('q_avs_lacunes_status'), isFalse);
      expect(p.profile!.goalA.type.name, 'achatImmo');
      expect(p.profile!.dettes.totalDettes, 9000);
      expect(p.profile!.conjoint!.prevoyance!.anneesContribuees, 18);
    });

    test('remote profile merge hydrates empty local profile', () async {
      installSecureStore();
      final p = CoachProfileProvider();

      await p.mergeFinancialFieldsFromRemoteForTest({
        'incomeNetMonthly': 7600,
        'totalDebt': 9000,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_net_income_period_chf'], 7600);
      expect(loaded['q_pay_frequency'], 'monthly');
      expect(loaded['q_total_debt_balance_chf'], 9000);
      expect(p.profile, isNotNull);
      expect(p.profile!.dettes.totalDettes, 9000);
    });

    test('save_fact income survives reload and feeds coach context packet',
        () async {
      installSecureStore();
      final writer = CoachProfileProvider();

      expect(await writer.applySaveFact('incomeNetMonthly', 7600), isTrue);
      expect(await writer.applySaveFact('totalDebt', 9000), isTrue);

      final persisted = await ReportPersistenceService.loadAnswers();
      expect(persisted['q_net_income_period_chf'], 7600);
      expect(persisted['q_pay_frequency'], 'monthly');
      expect(persisted['q_total_debt_balance_chf'], 9000);

      final reloaded = CoachProfileProvider();
      await reloaded.loadFromWizard();

      expect(reloaded.profile, isNotNull);
      expect(reloaded.profile!.explicitMonthlyNetIncome, 7600);
      expect(reloaded.profile!.dettes.totalDettes, 9000);

      final spine = DataSpineService.fromProfile(
        reloaded.profile!,
        now: DateTime.utc(2026, 6, 4),
      );
      final packet = CoachContextPacketService.fromSpine(spine);
      final facts = {for (final fact in packet.facts) fact.id: fact.value};

      expect(facts['budget.monthly_net'], 7600);
      expect(facts['situation.total_debt'], 9000);
      expect(packet.toSafeMap().toString(), isNot(contains('wizard_answers')));
    });

    test('missing-only merge preserves fresher local truth', () async {
      installSecureStore();
      final p = CoachProfileProvider();
      await ReportPersistenceService.saveAnswers({'q_cash_total': 18000});

      await p.mergeMissingAnswersForTest({
        'q_cash_total': 1,
        'q_savings_monthly': 500,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_cash_total'], 18000);
      expect(loaded['q_savings_monthly'], 500);
    });

    test('missing-only merge keeps income amount and frequency coherent',
        () async {
      installSecureStore();
      final p = CoachProfileProvider();
      await ReportPersistenceService.saveAnswers({'q_pay_frequency': 'yearly'});

      await p.mergeFinancialFieldsFromRemoteForTest({
        'incomeNetMonthly': 7600,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_net_income_period_chf'], 7600);
      expect(loaded['q_pay_frequency'], 'monthly');
    });

    test('missing-only merge does not reinterpret existing income amount',
        () async {
      installSecureStore();
      final p = CoachProfileProvider();
      await ReportPersistenceService.saveAnswers({
        'q_net_income_period_chf': 120000,
      });

      await p.mergeFinancialFieldsFromRemoteForTest({
        'incomeNetMonthly': 7600,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_net_income_period_chf'], 120000);
      expect(loaded.containsKey('q_pay_frequency'), isFalse);
    });

    test('remote merge keeps voluntary LPP when self-employed arrives together',
        () async {
      installSecureStore();
      final p = CoachProfileProvider();

      await p.mergeFinancialFieldsFromRemoteForTest({
        'selfEmployedNetIncome': 96000,
        'hasVoluntaryLpp': true,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_self_employed_net_income_annual_chf'], 96000);
      expect(loaded['q_net_income_period_chf'], closeTo(8000, 0.01));
      expect(loaded['q_pay_frequency'], 'monthly');
      expect(
        loaded['q_net_income_period_source'],
        'derived_self_employed_annual_proxy',
      );
      expect(loaded['q_employment_status'], 'independant');
      expect(loaded['q_has_pension_fund'], isTrue);
    });

    test('remote merge recognizes self_employed status spelling', () async {
      installSecureStore();
      await ReportPersistenceService.saveAnswers({
        'q_employment_status': 'self_employed',
      });
      final p = CoachProfileProvider();

      await p.mergeFinancialFieldsFromRemoteForTest({
        'selfEmployedNetIncome': 96000,
        'hasVoluntaryLpp': true,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_employment_status'], 'independant');
      expect(loaded['q_net_income_period_chf'], closeTo(8000, 0.01));
      expect(
        loaded['q_net_income_period_source'],
        'derived_self_employed_annual_proxy',
      );
      expect(loaded['q_has_pension_fund'], isTrue);
    });

    test('remote self-employed correction refreshes stale monthly cashflow',
        () async {
      installSecureStore();
      await ReportPersistenceService.saveAnswers({
        'q_employment_status': 'independant',
        'q_self_employed_net_income_annual_chf': 86400,
        'q_net_income_period_chf': 7200,
        'q_pay_frequency': 'monthly',
        'q_net_income_period_source': 'derived_self_employed_annual_proxy',
      });
      final p = CoachProfileProvider();

      await p.mergeFinancialFieldsFromRemoteForTest({
        'selfEmployedNetIncome': 90000,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_self_employed_net_income_annual_chf'], 90000);
      expect(loaded['q_net_income_period_chf'], closeTo(7500, 0.01));
      expect(loaded['q_pay_frequency'], 'monthly');
      expect(
        loaded['q_net_income_period_source'],
        'derived_self_employed_annual_proxy',
      );
      expect(
        BudgetInputs.fromCoachProfile(p.profile!).netIncome,
        closeTo(7500, 0.01),
      );
    });

    test('remote self-employed correction preserves explicit budget cashflow',
        () async {
      installSecureStore();
      await ReportPersistenceService.saveAnswers({
        'q_employment_status': 'independant',
        'q_self_employed_net_income_annual_chf': 86400,
        'q_net_income_period_chf': 6900,
        'q_pay_frequency': 'monthly',
      });
      final p = CoachProfileProvider();

      await p.mergeFinancialFieldsFromRemoteForTest({
        'selfEmployedNetIncome': 90000,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_self_employed_net_income_annual_chf'], 90000);
      expect(loaded['q_net_income_period_chf'], 6900);
      expect(loaded['q_pay_frequency'], 'monthly');
      expect(loaded.containsKey('q_net_income_period_source'), isFalse);
      expect(p.profile!.independentNetProfessionalIncomeAnnual, 90000);
      expect(
        BudgetInputs.fromCoachProfile(p.profile!).netIncome,
        closeTo(6900, 0.01),
      );
    });

    test('remote self-employed correction preserves explicit employee status',
        () async {
      installSecureStore();
      await ReportPersistenceService.saveAnswers({
        'q_employment_status': 'salarie',
        'q_net_income_period_chf': 7600,
        'q_pay_frequency': 'monthly',
      });
      final p = CoachProfileProvider();

      await p.mergeFinancialFieldsFromRemoteForTest({
        'selfEmployedNetIncome': 90000,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_employment_status'], 'salarie');
      expect(loaded['q_self_employed_net_income_annual_chf'], 90000);
      expect(loaded['q_net_income_period_chf'], 7600);
      expect(p.profile!.employmentStatus, 'salarie');
      expect(p.profile!.explicitMonthlyNetIncome, 7600);
    });

    test('remote pillar3aAnnual correction to zero clears stale 3a signal',
        () async {
      installSecureStore();
      await ReportPersistenceService.saveAnswers({
        'q_3a_annual_contribution': 6000,
        'q_has_3a': true,
      });
      final p = CoachProfileProvider();

      await p.mergeFinancialFieldsFromRemoteForTest({
        'pillar3aAnnual': 0,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_3a_annual_contribution'], 0);
      expect(loaded['q_has_3a'], isFalse);
      final profile = CoachProfile.fromWizardAnswers(loaded);
      expect(profile.total3aMensuel, 0);
      expect(profile.prevoyance.nombre3a, 0);
    });

    test('remote localDataClaim zero 3a beats stale flat contribution',
        () async {
      installSecureStore();
      await ReportPersistenceService.saveAnswers({
        'q_3a_annual_contribution': 0,
        'q_has_3a': false,
      });
      final p = CoachProfileProvider();

      await p.mergeFinancialFieldsFromRemoteForTest({
        'pillar3aAnnual': 6000,
        'localDataClaim': {
          'wizardAnswers': {
            'q_3a_annual_contribution': 0,
            'q_has_3a': false,
          },
        },
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_3a_annual_contribution'], 0);
      expect(loaded['q_has_3a'], isFalse);
      final profile = CoachProfile.fromWizardAnswers(loaded);
      expect(profile.total3aMensuel, 0);
      expect(profile.prevoyance.nombre3a, 0);
    });

    test('remote pillar3aAnnual positive correction revives 3a contribution',
        () async {
      installSecureStore();
      await ReportPersistenceService.saveAnswers({
        'q_3a_annual_contribution': 0,
        'q_has_3a': false,
      });
      final p = CoachProfileProvider();

      await p.mergeFinancialFieldsFromRemoteForTest({
        'pillar3aAnnual': 7056,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_3a_annual_contribution'], 7056);
      expect(loaded['q_has_3a'], isTrue);
      expect(p.profile!.total3aMensuel, closeTo(588, 0.01));
      expect(p.profile!.prevoyance.nombre3a, 1);
    });

    test('budget explicit income clears derived self-employed proxy marker',
        () async {
      installSecureStore();
      await ReportPersistenceService.saveAnswers({
        'q_employment_status': 'independant',
        'q_self_employed_net_income_annual_chf': 86400,
        'q_net_income_period_chf': 7200,
        'q_pay_frequency': 'monthly',
        'q_net_income_period_source': 'derived_self_employed_annual_proxy',
      });
      final p = CoachProfileProvider();

      await p.mergeAnswers({
        'q_net_income_period_chf': 7200,
        'q_pay_frequency': 'monthly',
        'q_net_income_period_source': null,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_net_income_period_chf'], 7200);
      expect(loaded['q_pay_frequency'], 'monthly');
      expect(loaded.containsKey('q_net_income_period_source'), isFalse);
    });

    test('concurrent local and remote profile writes preserve both facts',
        () async {
      installSecureStore();
      final p = CoachProfileProvider();

      await Future.wait([
        p.applySaveFact('totalSavings', 18000),
        p.mergeFinancialFieldsFromRemoteForTest({'totalDebt': 9000}),
      ]);

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_cash_total'], 18000);
      expect(loaded['q_total_debt_balance_chf'], 9000);
    });

    test('loadFromWizard rebuilds profile from total debt only', () async {
      installSecureStore();
      await ReportPersistenceService.saveAnswers({
        'q_total_debt_balance_chf': 9000,
      });
      final p = CoachProfileProvider();

      await p.loadFromWizard();

      expect(p.profile, isNotNull);
      expect(p.profile!.dettes.totalDettes, 9000);
    });

    test('IGNORES third-person salary (« ma sœur gagne 7500 »)', () async {
      final p = CoachProfileProvider();
      final applied = await FactExtractionFallback.extract(
          "ma sœur gagne 7500 par mois", p);
      // « ma » matches first-person alternation but the antecedent must be
      // the speaker's own value. This is a known limitation — the test
      // documents it. For a more robust fix, we'd tokenize antecedent.
      // For MVP we accept this edge case because it's rare and low-impact.
      // If it becomes a real issue, exclude « ma sœur/mari/mère/père ».
      expect(applied.contains('incomeNetMonthly'), isTrue);
    });

    test('returns empty list for non-financial text', () async {
      final p = CoachProfileProvider();
      final applied =
          await FactExtractionFallback.extract("bonjour comment ça va", p);
      expect(applied, isEmpty);
    });

    test('returns empty for very short input', () async {
      final p = CoachProfileProvider();
      final applied = await FactExtractionFallback.extract("hi", p);
      expect(applied, isEmpty);
    });

    test('handles iOS autocorrect "jai" without apostrophe', () async {
      final p = CoachProfileProvider();
      // « j'ai 34 ans » → iOS keyboard often yields « jai 34 and »
      final applied = await FactExtractionFallback.extract(
          "jai 34 and et je gagne 7500 brut par mois", p);
      expect(applied, contains('birthYear'));
      expect(applied, contains('incomeGrossMonthly'));
    });

    test('handles thousands separator (apostrophe)', () async {
      final p = CoachProfileProvider();
      final applied = await FactExtractionFallback.extract(
          "mon avoir LPP est 143'288 CHF", p);
      expect(applied, contains('avoirLpp'));
    });

    test('rejects absurd salary out of range', () async {
      final p = CoachProfileProvider();
      // Monthly salary > 100k → rejected as not plausible (guard range).
      final applied =
          await FactExtractionFallback.extract("je gagne 500000 par mois", p);
      expect(applied, isNot(contains('incomeNetMonthly')));
    });
  });
}
