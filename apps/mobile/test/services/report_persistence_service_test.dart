import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive unit tests for ReportPersistenceService
///
/// Tests cover:
/// - Wizard answers serialization/deserialization (save/load)
/// - Wizard completion flag management
/// - Letters history persistence
/// - Clear/reset functionality
/// - Edge cases: empty data, null fields, corrupted JSON
/// - Storage key isolation (no cross-contamination)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockSecureStorage = {};

  // Reset SharedPreferences and secure storage before each test
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
            if (value != null) {
              mockSecureStorage[key] = value;
            }
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

  // ═══════════════════════════════════════════════════════════════════════
  // Wizard Answers — Save & Load
  // ═══════════════════════════════════════════════════════════════════════

  group('ReportPersistenceService.saveAnswers / loadAnswers', () {
    test('saves and loads a simple answers map', () async {
      final answers = <String, dynamic>{
        'q_canton': 'VD',
        'q_birth_year': 1990,
        'q_has_3a': 'yes',
      };

      await ReportPersistenceService.saveAnswers(answers);
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded, equals(answers));
      expect(loaded['q_canton'], 'VD');
      expect(loaded['q_birth_year'], 1990);
      expect(loaded['q_has_3a'], 'yes');
    });

    test('drops unresolved secure placeholders on load', () async {
      SharedPreferences.setMockInitialValues({
        'wizard_answers_v2': json.encode({
          'q_canton': 'VD',
          'q_net_income_period_chf': '__secure__',
        }),
      });

      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded['q_canton'], 'VD');
      expect(loaded['q_net_income_period_chf'], isNull);
      expect(loaded.containsValue('__secure__'), isFalse);
    });

    test('secure read failure preserves non-sensitive answers', () async {
      SharedPreferences.setMockInitialValues({
        'wizard_answers_v2': json.encode({
          'q_canton': 'VD',
          'q_net_income_period_chf': '__secure__',
        }),
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          if (call.method == 'read') {
            throw PlatformException(
              code: '-34018',
              message: 'errSecMissingEntitlement',
            );
          }
          return null;
        },
      );

      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded['q_canton'], 'VD');
      expect(loaded['q_net_income_period_chf'], isNull);
      expect(loaded.containsValue('__secure__'), isFalse);
    });

    test('secure write failure keeps previous persisted truth', () async {
      await ReportPersistenceService.saveAnswers({
        'q_canton': 'VD',
        'q_net_income_period_chf': 7000,
      });
      expect(await ReportPersistenceService.loadAnswers(),
          containsPair('q_canton', 'VD'));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          if (call.method == 'write') {
            throw PlatformException(
              code: '-34018',
              message: 'errSecMissingEntitlement',
            );
          }
          if (call.method == 'read') {
            final key = call.arguments['key'] as String;
            return mockSecureStorage[key];
          }
          return null;
        },
      );

      final saved = await ReportPersistenceService.saveAnswers({
        'q_canton': 'GE',
        'q_net_income_period_chf': 9000,
      });
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(saved, isFalse);
      expect(loaded['q_canton'], 'VD');
      expect(loaded['q_net_income_period_chf'], 7000);
    });

    test('partial secure write failure rolls back touched secure keys',
        () async {
      await ReportPersistenceService.saveAnswers({
        'q_canton': 'VD',
        'q_net_income_period_chf': 7000,
        '_coach_avoir_lpp': 100000,
      });
      expect(mockSecureStorage['q_net_income_period_chf'], '7000');
      expect(mockSecureStorage['_coach_avoir_lpp'], '100000');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          final key = call.arguments['key'] as String;
          switch (call.method) {
            case 'write':
              if (key == '_coach_avoir_lpp') {
                throw PlatformException(
                  code: '-34018',
                  message: 'errSecMissingEntitlement',
                );
              }
              final value = call.arguments['value'] as String?;
              if (value != null) {
                mockSecureStorage[key] = value;
              }
              return null;
            case 'read':
              return mockSecureStorage[key];
            case 'delete':
              mockSecureStorage.remove(key);
              return null;
            default:
              return null;
          }
        },
      );

      final saved = await ReportPersistenceService.saveAnswers({
        'q_canton': 'GE',
        'q_net_income_period_chf': 9000,
        '_coach_avoir_lpp': 200000,
      });
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(saved, isFalse);
      expect(loaded['q_canton'], 'VD');
      expect(loaded['q_net_income_period_chf'], 7000);
      expect(loaded['_coach_avoir_lpp'], 100000);
      expect(mockSecureStorage['q_net_income_period_chf'], '7000');
      expect(mockSecureStorage['_coach_avoir_lpp'], '100000');
    });

    test('stores identity keys only in secure storage', () async {
      final saved = await ReportPersistenceService.saveAnswers({
        'q_canton': 'VD',
        'q_firstname': 'Julien',
        'q_date_of_birth': '1981-06-15',
        'q_birth_year': 1981,
        'q_civil_status': 'marie',
        'q_civil_status_choice': 'married',
        'q_household_type': 'marie',
        'q_commune': 'Lausanne',
        'q_gender': 'male',
        'q_us_tax_person': false,
        'q_employment_status': 'salarie',
      });

      final prefs = await SharedPreferences.getInstance();
      final raw = json.decode(prefs.getString('wizard_answers_v2')!)
          as Map<String, dynamic>;
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(saved, isTrue);
      expect(raw['q_canton'], 'VD');
      for (final key in <String>[
        'q_firstname',
        'q_date_of_birth',
        'q_birth_year',
        'q_civil_status',
        'q_civil_status_choice',
        'q_household_type',
        'q_commune',
        'q_gender',
        'q_us_tax_person',
        'q_employment_status',
      ]) {
        expect(raw[key], '__secure__', reason: key);
        expect(mockSecureStorage[key], isNotNull, reason: key);
      }
      expect(raw.containsValue('Julien'), isFalse);
      expect(raw.containsValue('1981-06-15'), isFalse);
      expect(raw.containsValue(1981), isFalse);
      expect(raw.containsValue('marie'), isFalse);
      expect(raw.containsValue('Lausanne'), isFalse);
      expect(raw.containsValue('male'), isFalse);
      expect(raw.containsValue(false), isFalse);
      expect(raw.containsValue('salarie'), isFalse);
      expect(loaded['q_firstname'], 'Julien');
      expect(loaded['q_date_of_birth'], '1981-06-15');
      expect(loaded['q_birth_year'], 1981);
      expect(loaded['q_civil_status'], 'marie');
      expect(loaded['q_civil_status_choice'], 'married');
      expect(loaded['q_household_type'], 'marie');
      expect(loaded['q_commune'], 'Lausanne');
      expect(loaded['q_gender'], 'male');
      expect(loaded['q_us_tax_person'], isFalse);
      expect(loaded['q_employment_status'], 'salarie');
    });

    test('stores canonical financial keys only in secure storage', () async {
      await ReportPersistenceService.saveAnswers({
        'q_canton': 'VD',
        'q_gross_salary_annual': 120000,
        'q_annual_bonus': 12000,
        'q_avs_contribution_years': 42,
        'q_net_income_period_chf': 7000,
        '_coach_avoir_lpp': 143288,
        '_coach_avoir_lpp_oblig': 100000,
        '_coach_salaire_assure': 64260,
        '_coach_rachat_maximum': 22000,
        '_coach_rendement_caisse': 0.021,
        'q_3a_total': 15000,
        'q_total_3a': 50000,
        'q_3a_accounts_count': 2,
        'q_3a_annual_contribution': 7258,
        'q_savings_monthly': 1200,
        'q_epargne_liquide': 30000,
        'q_investissements': 45000,
        'q_cash_total': 31000,
        'q_investments_total': 46000,
        'q_property_value': 1000000,
        'q_property_market_value': 1100000,
        'q_mortgage_balance': 600000,
        'q_monthly_rent': 2400,
        'q_housing_cost_period_chf': 2400,
        'q_lamal_premium_monthly_chf': 450,
        'q_tax_provision_monthly_chf': 1800,
        'q_other_fixed_costs_monthly_chf': 900,
        'q_debt_payments_period_chf': 1200,
        'q_total_debt_balance_chf': 9000,
        'q_bonus_percentage': 10,
        '_coach_depenses_electricite': 95,
        '_coach_depenses_transport': 180,
        '_coach_depenses_telecom': 80,
        '_coach_depenses_frais_medicaux': 120,
        '_coach_depenses_autres': 300,
        '_coach_dettes_hypotheque': 600000,
        'q_partner_net_income_chf': 5000,
        'q_partner_birth_year': 1988,
        'q_partner_employment_status': 'employed',
        'q_partner_firstname': 'Alex',
        'q_partner_gender': 'female',
        'q_partner_nationality': 'CH',
        'q_partner_canton': 'GE',
        'q_partner_enfants': 1,
        'q_spouse_avs_contribution_years': 18,
        '_coach_conjoint_avoir_lpp': 45000,
        '_coach_conjoint_taux_conversion': 0.061,
        '_coach_avs_lacunes': 2,
        '_coach_avs_rente_estimee': 2200,
        '_coach_avs_ramd': 0.85,
        '_coach_tax_revenu_imposable': 104000,
        '_coach_tax_fortune_imposable': 250000,
        '_coach_tax_deductions': 12000,
        '_coach_tax_impot_cantonal': 14000,
        '_coach_tax_impot_federal': 5200,
        '_coach_tax_taux_marginal': 0.31,
        '_coach_tax_source': 'document_scan',
      });

      final prefs = await SharedPreferences.getInstance();
      final raw = json.decode(prefs.getString('wizard_answers_v2')!)
          as Map<String, dynamic>;

      expect(raw['q_canton'], 'VD');
      for (final key in <String>[
        'q_gross_salary_annual',
        'q_annual_bonus',
        'q_avs_contribution_years',
        'q_net_income_period_chf',
        '_coach_avoir_lpp',
        '_coach_avoir_lpp_oblig',
        '_coach_salaire_assure',
        '_coach_rachat_maximum',
        '_coach_rendement_caisse',
        'q_3a_total',
        'q_total_3a',
        'q_3a_accounts_count',
        'q_3a_annual_contribution',
        'q_savings_monthly',
        'q_epargne_liquide',
        'q_investissements',
        'q_cash_total',
        'q_investments_total',
        'q_property_value',
        'q_property_market_value',
        'q_mortgage_balance',
        'q_monthly_rent',
        'q_housing_cost_period_chf',
        'q_lamal_premium_monthly_chf',
        'q_tax_provision_monthly_chf',
        'q_other_fixed_costs_monthly_chf',
        'q_debt_payments_period_chf',
        'q_total_debt_balance_chf',
        'q_bonus_percentage',
        '_coach_depenses_electricite',
        '_coach_depenses_transport',
        '_coach_depenses_telecom',
        '_coach_depenses_frais_medicaux',
        '_coach_depenses_autres',
        '_coach_dettes_hypotheque',
        'q_partner_net_income_chf',
        'q_partner_birth_year',
        'q_partner_employment_status',
        'q_partner_firstname',
        'q_partner_gender',
        'q_partner_nationality',
        'q_partner_canton',
        'q_partner_enfants',
        'q_spouse_avs_contribution_years',
        '_coach_conjoint_avoir_lpp',
        '_coach_conjoint_taux_conversion',
        '_coach_avs_lacunes',
        '_coach_avs_rente_estimee',
        '_coach_avs_ramd',
        '_coach_tax_revenu_imposable',
        '_coach_tax_fortune_imposable',
        '_coach_tax_deductions',
        '_coach_tax_impot_cantonal',
        '_coach_tax_impot_federal',
        '_coach_tax_taux_marginal',
      ]) {
        expect(raw[key], '__secure__', reason: key);
        expect(mockSecureStorage[key], isNotNull, reason: key);
      }
      expect(raw['_coach_tax_source'], 'document_scan');
      expect(raw.containsValue(120000), isFalse);
      expect(raw.containsValue(12000), isFalse);
      expect(raw.containsValue(143288), isFalse);
      expect(raw.containsValue(15000), isFalse);
      expect(raw.containsValue(5000), isFalse);
      expect(raw.containsValue(45000), isFalse);
      expect(raw.containsValue(1988), isFalse);
      expect(raw.containsValue('Alex'), isFalse);
      expect(raw.containsValue('female'), isFalse);
      expect(raw.containsValue('CH'), isFalse);
      expect(raw.containsValue('GE'), isFalse);
      expect(raw.containsValue(18), isFalse);
      expect(raw.containsValue(31000), isFalse);
      expect(raw.containsValue(2400), isFalse);
      expect(raw.containsValue(104000), isFalse);
      expect(raw.containsValue(600000), isFalse);
      expect(raw.containsValue(1000000), isFalse);
      expect(raw.containsValue(1100000), isFalse);
      expect(raw.containsValue(10), isFalse);
    });

    test('extended financial keys are sealed or dropped', () async {
      final saved = await ReportPersistenceService.saveAnswers({
        'q_canton': 'VD',
        'q_mortgage_balance': 600000,
        'q_property_value': 1000000,
        'q_property_market_value': 1100000,
        'q_monthly_rent': 2400,
        'q_total_3a': 50000,
        'q_bonus_percentage': 10,
      });

      final prefs = await SharedPreferences.getInstance();
      final raw = json.decode(prefs.getString('wizard_answers_v2')!)
          as Map<String, dynamic>;

      expect(saved, isTrue);
      expect(raw['q_canton'], 'VD');
      for (final key in <String>[
        'q_mortgage_balance',
        'q_property_value',
        'q_property_market_value',
        'q_monthly_rent',
        'q_total_3a',
        'q_bonus_percentage',
      ]) {
        expect(raw[key], '__secure__', reason: key);
        expect(mockSecureStorage[key], isNotNull, reason: key);
      }
      expect(raw.containsValue(600000), isFalse);
      expect(raw.containsValue(1000000), isFalse);
      expect(raw.containsValue(1100000), isFalse);
      expect(raw.containsValue(2400), isFalse);
      expect(raw.containsValue(50000), isFalse);
      expect(raw.containsValue(10), isFalse);
    });

    test('secure write failure without existing answers writes nothing',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          if (call.method == 'write') {
            throw PlatformException(
              code: '-34018',
              message: 'errSecMissingEntitlement',
            );
          }
          return null;
        },
      );

      final saved = await ReportPersistenceService.saveAnswers({
        'q_canton': 'VD',
        'q_net_income_period_chf': 7000,
        'q_mortgage_balance': 600000,
        'q_property_value': 1000000,
        'q_total_3a': 50000,
        'q_bonus_percentage': 10,
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      final prefs = await SharedPreferences.getInstance();

      expect(saved, isFalse);
      expect(loaded, isEmpty);
      expect(prefs.getString('wizard_answers_v2'), isNull);
    });

    test('secure write failure scrubs legacy plaintext sensitive answers',
        () async {
      SharedPreferences.setMockInitialValues({
        'wizard_answers_v2': json.encode({
          'q_canton': 'VD',
          'q_date_of_birth': '1981-06-15',
          'q_birth_year': 1981,
          'q_net_income_period_chf': 7000,
          'q_civil_status': 'marie',
        }),
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          if (call.method == 'write') {
            throw PlatformException(
              code: '-34018',
              message: 'errSecMissingEntitlement',
            );
          }
          return null;
        },
      );

      final saved = await ReportPersistenceService.saveAnswers({
        'q_canton': 'GE',
        'q_date_of_birth': '1982-07-16',
      });
      final prefs = await SharedPreferences.getInstance();
      final raw = json.decode(prefs.getString('wizard_answers_v2')!)
          as Map<String, dynamic>;
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(saved, isFalse);
      expect(raw, {'q_canton': 'VD'});
      expect(loaded, {'q_canton': 'VD'});
    });

    test('returns empty map when nothing has been saved', () async {
      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded, isEmpty);
    });

    test('overwrites previous answers on re-save', () async {
      await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
      await ReportPersistenceService.saveAnswers(
          {'q_canton': 'GE', 'q_birth_year': 1985});

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_canton'], 'GE');
      expect(loaded['q_birth_year'], 1985);
      expect(loaded.length, 2);
    });

    test('handles empty answers map', () async {
      await ReportPersistenceService.saveAnswers({});
      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded, isEmpty);
    });

    test('handles answers with null values', () async {
      final answers = <String, dynamic>{
        'q_canton': null,
        'q_birth_year': 1990,
      };

      await ReportPersistenceService.saveAnswers(answers);
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded.containsKey('q_canton'), true);
      expect(loaded['q_canton'], isNull);
      expect(loaded['q_birth_year'], 1990);
    });

    test('handles answers with nested map values', () async {
      final answers = <String, dynamic>{
        'q_canton': 'VD',
        'q_nested': {'sub_key': 'sub_value', 'amount': 1234.56},
      };

      await ReportPersistenceService.saveAnswers(answers);
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded['q_nested'], isA<Map>());
      expect((loaded['q_nested'] as Map)['sub_key'], 'sub_value');
      expect((loaded['q_nested'] as Map)['amount'], 1234.56);
    });

    test('handles answers with list values', () async {
      final answers = <String, dynamic>{
        'q_3a_providers': ['bank', 'fintech'],
        'q_canton': 'ZH',
      };

      await ReportPersistenceService.saveAnswers(answers);
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded['q_3a_providers'], isA<List>());
      expect((loaded['q_3a_providers'] as List).length, 2);
      expect((loaded['q_3a_providers'] as List).first, 'bank');
    });

    test('handles numeric string values correctly', () async {
      final answers = <String, dynamic>{
        'q_net_income_period_chf': 5000.50,
        'q_birth_year': 1990,
        'q_savings_monthly': 0,
      };

      await ReportPersistenceService.saveAnswers(answers);
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded['q_net_income_period_chf'], 5000.50);
      expect(loaded['q_birth_year'], 1990);
      expect(loaded['q_savings_monthly'], 0);
    });

    test('persists mini-onboarding draft fields', () async {
      final answers = <String, dynamic>{
        'q_canton': 'VD',
        'mini_draft_birth_year': '199',
        'mini_draft_income': '6200',
        'mini_draft_tax_provision': '900',
      };

      await ReportPersistenceService.saveAnswers(answers);
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded['mini_draft_birth_year'], '199');
      expect(loaded['mini_draft_income'], '6200');
      expect(loaded['mini_draft_tax_provision'], '900');
    });

    test('returns empty map when stored JSON is corrupted', () async {
      // Manually inject invalid JSON into SharedPreferences
      SharedPreferences.setMockInitialValues({
        'wizard_answers_v2': 'this is not valid json{{{',
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Wizard Completion Flag
  // ═══════════════════════════════════════════════════════════════════════

  group('ReportPersistenceService.setCompleted / isCompleted', () {
    test('defaults to false when not set', () async {
      final completed = await ReportPersistenceService.isCompleted();
      expect(completed, false);
    });

    test('returns true after setting completed to true', () async {
      await ReportPersistenceService.setCompleted(true);
      final completed = await ReportPersistenceService.isCompleted();
      expect(completed, true);
    });

    test('returns false after setting completed to false', () async {
      await ReportPersistenceService.setCompleted(true);
      await ReportPersistenceService.setCompleted(false);
      final completed = await ReportPersistenceService.isCompleted();
      expect(completed, false);
    });

    test('toggle completed flag multiple times', () async {
      await ReportPersistenceService.setCompleted(true);
      expect(await ReportPersistenceService.isCompleted(), true);

      await ReportPersistenceService.setCompleted(false);
      expect(await ReportPersistenceService.isCompleted(), false);

      await ReportPersistenceService.setCompleted(true);
      expect(await ReportPersistenceService.isCompleted(), true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Mini-Onboarding Experiment Persistence
  // ═══════════════════════════════════════════════════════════════════════

  group('Mini-onboarding experiment persistence', () {
    test('getOrCreateMiniOnboardingVariant returns a valid variant', () async {
      final variant =
          await ReportPersistenceService.getOrCreateMiniOnboardingVariant();
      expect(['control', 'challenge'], contains(variant));
    });

    test('getOrCreateMiniOnboardingVariant persists the same variant',
        () async {
      final variant1 =
          await ReportPersistenceService.getOrCreateMiniOnboardingVariant();
      final variant2 =
          await ReportPersistenceService.getOrCreateMiniOnboardingVariant();
      expect(variant2, equals(variant1));
    });

    test('mini-onboarding exposure tracked defaults to false', () async {
      expect(
        await ReportPersistenceService.isMiniOnboardingExposureTracked(),
        isFalse,
      );
    });

    test('mini-onboarding exposure tracking flag can be set', () async {
      await ReportPersistenceService.setMiniOnboardingExposureTracked(true);
      expect(
        await ReportPersistenceService.isMiniOnboardingExposureTracked(),
        isTrue,
      );
    });

    test('mini-onboarding metrics default values are loaded', () async {
      final metrics =
          await ReportPersistenceService.loadMiniOnboardingMetrics('control');
      expect(metrics['started'], 0);
      expect(metrics['completed'], 0);
      expect(metrics['step_1'], 0);
    });

    test('mini-onboarding metrics can be incremented per variant', () async {
      await ReportPersistenceService.incrementMiniOnboardingMetric(
        'challenge',
        'started',
      );
      await ReportPersistenceService.incrementMiniOnboardingMetric(
        'challenge',
        'started',
      );
      await ReportPersistenceService.incrementMiniOnboardingMetric(
        'challenge',
        'completed',
      );
      final metrics =
          await ReportPersistenceService.loadMiniOnboardingMetrics('challenge');
      expect(metrics['started'], 2);
      expect(metrics['completed'], 1);

      final control =
          await ReportPersistenceService.loadMiniOnboardingMetrics('control');
      expect(control['started'], 0);
    });

    test('mini-onboarding metrics clear resets counters', () async {
      await ReportPersistenceService.incrementMiniOnboardingMetric(
        'control',
        'started',
      );
      await ReportPersistenceService.clearMiniOnboardingMetrics();
      final metrics =
          await ReportPersistenceService.loadMiniOnboardingMetrics('control');
      expect(metrics['started'], 0);
    });

    test('cohort metrics can be incremented and exported to CSV', () async {
      await ReportPersistenceService.incrementMiniOnboardingCohortMetric(
        'control',
        'stress_budget|emp_employee|inc_mid',
        'started',
      );
      await ReportPersistenceService.incrementMiniOnboardingCohortMetric(
        'control',
        'stress_budget|emp_employee|inc_mid',
        'completed',
      );
      await ReportPersistenceService.incrementMiniOnboardingCohortMetric(
        'challenge',
        'stress_tax|emp_independent|inc_high',
        'started',
        by: 2,
      );

      final cohorts =
          await ReportPersistenceService.loadMiniOnboardingCohortMetrics();
      expect(cohorts['control'], isNotNull);
      expect(
        cohorts['control']['stress_budget|emp_employee|inc_mid']['started'],
        1,
      );
      expect(
        cohorts['control']['stress_budget|emp_employee|inc_mid']['completed'],
        1,
      );
      expect(
        cohorts['challenge']['stress_tax|emp_independent|inc_high']['started'],
        2,
      );

      final csv =
          await ReportPersistenceService.exportMiniOnboardingCohortCsv();
      expect(csv, contains('variant,profile_bucket,started,completed'));
      expect(csv, contains('control,stress_budget|emp_employee|inc_mid,1,1'));
      expect(
          csv, contains('challenge,stress_tax|emp_independent|inc_high,2,0'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Onboarding 30-Day Plan Persistence
  // ═══════════════════════════════════════════════════════════════════════

  group('Onboarding 30-day plan persistence', () {
    test('starts empty then marks started with context', () async {
      final before = await ReportPersistenceService.loadOnboarding30PlanState();
      expect(before, isEmpty);

      await ReportPersistenceService.markOnboarding30PlanStarted(
        stressChoice: 'budget',
        mainGoal: 'retirement',
      );

      final state = await ReportPersistenceService.loadOnboarding30PlanState();
      expect(state['started_at'], isNotNull);
      expect(state['stress_choice'], 'budget');
      expect(state['main_goal'], 'retirement');
      expect(state['completed'], false);
      expect(state['opened_routes'], isA<List>());
    });

    test('marks routes opened and keeps uniqueness + last route', () async {
      await ReportPersistenceService.markOnboarding30PlanStarted();
      await ReportPersistenceService.markOnboarding30PlanRouteOpened('/budget');
      await ReportPersistenceService.markOnboarding30PlanRouteOpened('/budget');
      await ReportPersistenceService.markOnboarding30PlanRouteOpened(
          '/coach/agir');

      final state = await ReportPersistenceService.loadOnboarding30PlanState();
      final opened = List<String>.from(state['opened_routes'] as List);
      expect(opened.length, 2);
      expect(opened, contains('/budget'));
      expect(opened, contains('/coach/agir'));
      expect(state['last_route'], '/coach/agir');
    });

    test('completion flag is persisted and can be unset', () async {
      await ReportPersistenceService.markOnboarding30PlanStarted();
      await ReportPersistenceService.setOnboarding30PlanCompleted(true);
      var state = await ReportPersistenceService.loadOnboarding30PlanState();
      expect(state['completed'], true);
      expect(state['completed_at'], isNotNull);

      await ReportPersistenceService.setOnboarding30PlanCompleted(false);
      state = await ReportPersistenceService.loadOnboarding30PlanState();
      expect(state['completed'], false);
      expect(state.containsKey('completed_at'), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Letters History
  // ═══════════════════════════════════════════════════════════════════════

  group('ReportPersistenceService.saveLettersHistory / loadLettersHistory', () {
    test('saves and loads letters history', () async {
      final letters = [
        {'title': 'Rachat LPP', 'date': '2025-01-15', 'type': 'LPP_BUYBACK'},
        {'title': 'Demande 3a', 'date': '2025-02-01', 'type': '3A_OPEN'},
      ];

      await ReportPersistenceService.saveLettersHistory(letters);
      final loaded = await ReportPersistenceService.loadLettersHistory();

      expect(loaded.length, 2);
      expect(loaded[0]['title'], 'Rachat LPP');
      expect(loaded[1]['type'], '3A_OPEN');
    });

    test('returns empty list when nothing saved', () async {
      final loaded = await ReportPersistenceService.loadLettersHistory();
      expect(loaded, isEmpty);
    });

    test('handles empty letters list', () async {
      await ReportPersistenceService.saveLettersHistory([]);
      final loaded = await ReportPersistenceService.loadLettersHistory();
      expect(loaded, isEmpty);
    });

    test('returns empty list when stored JSON is corrupted', () async {
      SharedPreferences.setMockInitialValues({
        'generated_letters_history': '<<<corrupted>>>',
      });

      final loaded = await ReportPersistenceService.loadLettersHistory();
      expect(loaded, isEmpty);
    });

    test('preserves letter entries with compliance fields', () async {
      final letters = [
        {
          'title': 'Demande rachat LPP',
          'date': '2025-03-01',
          'type': 'LPP_BUYBACK',
          'disclaimer': 'Outil educatif - ne constitue pas un conseil',
          'sources': ['LPP art. 79b'],
        },
      ];

      await ReportPersistenceService.saveLettersHistory(letters);
      final loaded = await ReportPersistenceService.loadLettersHistory();

      expect(loaded[0]['disclaimer'], contains('educatif'));
      expect(loaded[0]['sources'], isA<List>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Clear / Reset
  // ═══════════════════════════════════════════════════════════════════════

  group('ReportPersistenceService.clear', () {
    test('clears all stored data', () async {
      // Populate all data
      await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
      await ReportPersistenceService.setCompleted(true);
      await ReportPersistenceService.saveLettersHistory([
        {'title': 'Test'}
      ]);

      // Verify data exists
      expect(await ReportPersistenceService.loadAnswers(), isNotEmpty);
      expect(await ReportPersistenceService.isCompleted(), true);
      expect(await ReportPersistenceService.loadLettersHistory(), isNotEmpty);

      // Clear all
      await ReportPersistenceService.clear();

      // Verify everything is cleared
      expect(await ReportPersistenceService.loadAnswers(), isEmpty);
      expect(await ReportPersistenceService.isCompleted(), false);
      expect(await ReportPersistenceService.loadLettersHistory(), isEmpty);
    });

    test('clears diagnostic companion stores for a fresh local restart',
        () async {
      final conversationStore = ConversationStore();
      final message = ChatMessage(
        role: 'user',
        content: 'Je veux repartir de zero',
        timestamp: DateTime(2026, 6, 13, 14),
      );

      await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
      await AnonymousSessionService.updateFromResponse(0);
      await BudgetLocalStore().saveInputs(const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 8000,
        housingCost: 2200,
        debtPayments: 0,
      ));
      await BudgetLocalStore().saveOverride('future', 500);

      ConversationStore.setCurrentUserId('user-42');
      await conversationStore.saveConversation('user-conv', [message]);
      ConversationStore.setCurrentUserId(null);
      await conversationStore.saveConversation('anon-conv', [message]);

      ConversationStore.setCurrentUserId('user-42');
      await ReportPersistenceService.clear(conversationUserId: 'user-42');

      expect(await ReportPersistenceService.loadAnswers(), isEmpty);
      expect(await AnonymousSessionService.getMessageCount(), 0);
      expect(await BudgetLocalStore().loadInputs(), isNull);
      expect(await BudgetLocalStore().getOverride('future'), isNull);
      expect(await conversationStore.listConversations(), isEmpty);

      ConversationStore.setCurrentUserId(null);
      expect(
        (await conversationStore.listConversations()).map((meta) => meta.id),
        contains('anon-conv'),
      );
    });

    test('clear is idempotent (calling twice does not throw)', () async {
      await ReportPersistenceService.clear();
      await ReportPersistenceService.clear();

      expect(await ReportPersistenceService.loadAnswers(), isEmpty);
      expect(await ReportPersistenceService.isCompleted(), false);
    });

    test('clearDiagnostic resets mini-onboarding experiment keys', () async {
      await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await ReportPersistenceService.getOrCreateMiniOnboardingVariant();
      await ReportPersistenceService.setMiniOnboardingExposureTracked(true);
      await ReportPersistenceService.markOnboarding30PlanStarted();
      await ReportPersistenceService.markOnboarding30PlanRouteOpened('/budget');

      await ReportPersistenceService.clearDiagnostic();

      expect(await ReportPersistenceService.loadAnswers(), isEmpty);
      expect(
          await ReportPersistenceService.isMiniOnboardingCompleted(), isFalse);
      expect(
        await ReportPersistenceService.isMiniOnboardingExposureTracked(),
        isFalse,
      );
      final variant =
          await ReportPersistenceService.getOrCreateMiniOnboardingVariant();
      expect(['control', 'challenge'], contains(variant));
      final planState =
          await ReportPersistenceService.loadOnboarding30PlanState();
      expect(planState, isEmpty);
    });

    test('clearDiagnostic removes sealed sensitive wizard values', () async {
      await ReportPersistenceService.saveAnswers({
        'q_canton': 'VD',
        'q_net_income_period_chf': 7000,
      });
      expect(mockSecureStorage['q_net_income_period_chf'], '7000');

      await ReportPersistenceService.clearDiagnostic();

      expect(mockSecureStorage.containsKey('q_net_income_period_chf'), isFalse);
      expect(await ReportPersistenceService.loadAnswers(), isEmpty);
    });

    test('holdActiveDiagnosticForAnonymous moves active answers aside',
        () async {
      await ReportPersistenceService.saveAnswers({
        'q_canton': 'VD',
        'q_net_income_period_chf': 7000,
      });
      expect(mockSecureStorage['q_net_income_period_chf'], '7000');

      await ReportPersistenceService.holdActiveDiagnosticForAnonymous();

      expect(await ReportPersistenceService.loadAnswers(), isEmpty);
      expect(await ReportPersistenceService.loadHeldAnonymousAnswers(), {
        'q_canton': 'VD',
        'q_net_income_period_chf': '7000',
      });
      expect(
        mockSecureStorage[
            '_mint_held_anonymous_wizard_q_net_income_period_chf'],
        '7000',
      );
      expect(mockSecureStorage.containsKey('q_net_income_period_chf'), isFalse);
    });

    test('clearDiagnostic marks pending secure deletion on delete failure',
        () async {
      await ReportPersistenceService.saveAnswers({
        'q_canton': 'VD',
        'q_net_income_period_chf': 7000,
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          if (call.method == 'delete' || call.method == 'deleteAll') {
            throw PlatformException(
              code: '-34018',
              message: 'errSecMissingEntitlement',
            );
          }
          return null;
        },
      );

      await ReportPersistenceService.clearDiagnostic();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('secure_delete_pending_v1'), isTrue);
    });

    test('loadAnswers retries pending secure deletion and clears marker',
        () async {
      await ReportPersistenceService.saveAnswers({
        'q_canton': 'VD',
        'q_net_income_period_chf': 7000,
      });
      expect(mockSecureStorage['q_net_income_period_chf'], '7000');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          if (call.method == 'delete' || call.method == 'deleteAll') {
            throw PlatformException(
              code: '-34018',
              message: 'errSecMissingEntitlement',
            );
          }
          return null;
        },
      );
      await ReportPersistenceService.clearDiagnostic();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          switch (call.method) {
            case 'deleteAll':
              mockSecureStorage.clear();
              return null;
            case 'delete':
              final key = call.arguments['key'] as String;
              mockSecureStorage.remove(key);
              return null;
            default:
              return null;
          }
        },
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('secure_delete_pending_v1'), isTrue);
      expect(mockSecureStorage['q_net_income_period_chf'], '7000');

      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded, isEmpty);
      expect(mockSecureStorage.containsKey('q_net_income_period_chf'), isFalse);
      expect(prefs.getBool('secure_delete_pending_v1'), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Coach History — clearCoachHistory
  // ═══════════════════════════════════════════════════════════════════════

  group('ReportPersistenceService.clearCoachHistory', () {
    test('clears check-ins, scores, and explored simulators', () async {
      // Populate coach history data
      await ReportPersistenceService.saveCheckIns([
        {'date': '2026-01', 'score': 72},
      ]);
      await ReportPersistenceService.saveLastScore(85);
      await ReportPersistenceService.markSimulatorExplored('3a');
      await ReportPersistenceService.markSimulatorExplored('lpp');

      // Verify data exists
      expect(await ReportPersistenceService.loadCheckIns(), isNotEmpty);
      expect(await ReportPersistenceService.loadLastScore(), isNotNull);
      expect(await ReportPersistenceService.loadScoreHistory(), isNotEmpty);
      expect(
          await ReportPersistenceService.loadExploredSimulators(), isNotEmpty);

      // Clear coach history
      await ReportPersistenceService.clearCoachHistory();

      // Verify everything is cleared
      expect(await ReportPersistenceService.loadCheckIns(), isEmpty);
      expect(await ReportPersistenceService.loadLastScore(), isNull);
      expect(await ReportPersistenceService.loadScoreHistory(), isEmpty);
      expect(await ReportPersistenceService.loadExploredSimulators(), isEmpty);
    });

    test('clearCoachHistory does not affect diagnostic data', () async {
      // Populate both
      await ReportPersistenceService.saveAnswers({'q_canton': 'GE'});
      await ReportPersistenceService.setCompleted(true);
      await ReportPersistenceService.saveCheckIns([
        {'date': '2026-01', 'score': 72},
      ]);

      await ReportPersistenceService.clearCoachHistory();

      // Diagnostic data should remain
      expect(await ReportPersistenceService.loadAnswers(), isNotEmpty);
      expect(await ReportPersistenceService.isCompleted(), true);
      // Coach history should be gone
      expect(await ReportPersistenceService.loadCheckIns(), isEmpty);
    });

    test('clearCoachHistory is idempotent', () async {
      await ReportPersistenceService.clearCoachHistory();
      await ReportPersistenceService.clearCoachHistory();
      expect(await ReportPersistenceService.loadCheckIns(), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Coach Data Persistence (check-ins, scores, simulators, contributions)
  // ═══════════════════════════════════════════════════════════════════════

  group('ReportPersistenceService coach data persistence', () {
    test('saveCheckIns and loadCheckIns roundtrip', () async {
      final checkIns = [
        {'date': '2026-01', 'score': 72, 'savings': 500},
        {'date': '2026-02', 'score': 78, 'savings': 600},
      ];
      await ReportPersistenceService.saveCheckIns(checkIns);
      final loaded = await ReportPersistenceService.loadCheckIns();
      expect(loaded.length, 2);
      expect(loaded[0]['date'], '2026-01');
      expect(loaded[1]['score'], 78);
    });

    test('saveLastScore and loadLastScore roundtrip', () async {
      await ReportPersistenceService.saveLastScore(91);
      final score = await ReportPersistenceService.loadLastScore();
      expect(score, 91);
    });

    test('loadLastScore returns null when empty', () async {
      final score = await ReportPersistenceService.loadLastScore();
      expect(score, isNull);
    });

    test('saveScoreToHistory adds entry for current month', () async {
      await ReportPersistenceService.saveScoreToHistory(80);
      await ReportPersistenceService.saveScoreToHistory(85);
      final history = await ReportPersistenceService.loadScoreHistory();
      // Both calls use the same month (DateTime.now()), so the second
      // replaces the first — only 1 entry should exist.
      expect(history.length, 1);
      expect(history[0]['score'], 85);
    });

    test('saveScoreToHistory limits to 24 entries', () async {
      // Directly inject 30 entries via saveCheckIns-style approach
      // Since saveScoreToHistory auto-dedupes by current month, we
      // pre-populate the score_history_v1 key with 30 entries directly
      // and then call saveScoreToHistory to trigger the trim.
      final prefs = await SharedPreferences.getInstance();
      final fakeHistory = List.generate(
        30,
        (i) => {
          'month':
              '${2022 + i ~/ 12}-${(i % 12 + 1).toString().padLeft(2, '0')}',
          'score': 50 + i,
        },
      );
      await prefs.setString('score_history_v1', json.encode(fakeHistory));

      // Trigger trim by adding a score for the current month
      await ReportPersistenceService.saveScoreToHistory(99);

      final history = await ReportPersistenceService.loadScoreHistory();
      expect(history.length, lessThanOrEqualTo(24));
    });

    test('markSimulatorExplored and loadExploredSimulators', () async {
      await ReportPersistenceService.markSimulatorExplored('3a');
      await ReportPersistenceService.markSimulatorExplored('lpp');
      await ReportPersistenceService.markSimulatorExplored('3a'); // duplicate
      final explored = await ReportPersistenceService.loadExploredSimulators();
      expect(explored, contains('3a'));
      expect(explored, contains('lpp'));
      // Set should deduplicate
      expect(explored.length, 2);
    });

    test('contributions save and load roundtrip', () async {
      final contributions = [
        {'name': '3a', 'amount': 7258.0, 'frequency': 'annual'},
      ];
      await ReportPersistenceService.saveContributions(contributions);
      final loaded = await ReportPersistenceService.loadContributions();
      expect(loaded.length, 1);
      expect(loaded[0]['amount'], 7258.0);
    });

    test('hasCustomContributions returns false when empty', () async {
      final has = await ReportPersistenceService.hasCustomContributions();
      expect(has, isFalse);
    });

    test('hasCustomContributions returns true after save', () async {
      await ReportPersistenceService.saveContributions([
        {'name': '3a', 'amount': 7258.0},
      ]);
      final has = await ReportPersistenceService.hasCustomContributions();
      expect(has, isTrue);
    });

    test('score attribution save/load roundtrip', () async {
      await ReportPersistenceService.saveLastScoreAttribution(
        reason: 'Hausse principale: versements confirmes',
        delta: 3,
      );
      final attribution =
          await ReportPersistenceService.loadLastScoreAttribution();
      expect(attribution, isNotNull);
      expect(attribution!['reason'], contains('Hausse principale'));
      expect(attribution['delta'], 3);
    });

    test('coach narrative mode persists and defaults to detailed', () async {
      final defaultMode =
          await ReportPersistenceService.loadCoachNarrativeMode();
      expect(defaultMode, 'detailed');

      await ReportPersistenceService.saveCoachNarrativeMode('concise');
      final loaded = await ReportPersistenceService.loadCoachNarrativeMode();
      expect(loaded, 'concise');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Full clear covers coach history + diagnostic + letters
  // ═══════════════════════════════════════════════════════════════════════

  group('ReportPersistenceService.clear covers coach history', () {
    test('clear removes coach history + diagnostic + letters', () async {
      // Populate everything
      await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
      await ReportPersistenceService.setCompleted(true);
      await ReportPersistenceService.saveLettersHistory([
        {'title': 'Test'}
      ]);
      await ReportPersistenceService.saveCheckIns([
        {'date': '2026-01', 'score': 72},
      ]);
      await ReportPersistenceService.saveLastScore(85);
      await ReportPersistenceService.markSimulatorExplored('3a');

      await ReportPersistenceService.clear();

      // Everything should be gone
      expect(await ReportPersistenceService.loadAnswers(), isEmpty);
      expect(await ReportPersistenceService.isCompleted(), false);
      expect(await ReportPersistenceService.loadLettersHistory(), isEmpty);
      expect(await ReportPersistenceService.loadCheckIns(), isEmpty);
      expect(await ReportPersistenceService.loadLastScore(), isNull);
      expect(await ReportPersistenceService.loadScoreHistory(), isEmpty);
      expect(await ReportPersistenceService.loadExploredSimulators(), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Storage Key Isolation
  // ═══════════════════════════════════════════════════════════════════════

  group('Storage key isolation', () {
    test('answers and letters use separate storage keys', () async {
      await ReportPersistenceService.saveAnswers({
        'q_canton': 'VD',
      });
      await ReportPersistenceService.saveLettersHistory([
        {'title': 'Lettre A'},
      ]);

      final answers = await ReportPersistenceService.loadAnswers();
      final letters = await ReportPersistenceService.loadLettersHistory();

      // Answers should not contain letters data
      expect(answers.containsKey('title'), false);
      expect(answers['q_canton'], 'VD');

      // Letters should not contain answers data
      expect(letters.length, 1);
      expect(letters[0]['title'], 'Lettre A');
    });

    test('completion flag is independent of answers', () async {
      await ReportPersistenceService.saveAnswers({'q_canton': 'GE'});
      // Completion flag should still default to false
      expect(await ReportPersistenceService.isCompleted(), false);

      await ReportPersistenceService.setCompleted(true);
      // Answers should still be intact
      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['q_canton'], 'GE');
    });
  });
}
