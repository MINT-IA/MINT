import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.resetMemoryCacheForTest();
    ApiService.setHttpClientForTesting(null);
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
  });

  tearDown(() {
    ApiService.setHttpClientForTesting(null);
    AuthService.resetMemoryCacheForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  test('backend sync sends Mint2 axis handoff outside wizard answers',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auth_local_mode', false);
    await AuthService.saveToken('sync-token', 'sync-user', 'sync@example.ch');
    await ReportPersistenceService.saveMint2AxisHandoff({
      'onb_axis_v2': 'lpp_rente_capital',
      'onb_axis_schema_version': 2,
      'legacy_onb_intent': 'retraite',
      'onb_signal_axes_v2': ['fiscal_signal'],
    });

    Map<String, dynamic>? claimBody;
    ApiService.setHttpClientForTesting(MintHttpClient(
      MockClient((request) async {
        expect(request.url.path, '/api/v1/sync/claim-local-data');
        claimBody = json.decode(request.body) as Map<String, dynamic>;
        return http.Response('{"status":"ok"}', 200);
      }),
    ));

    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_canton': 'VD',
      'q_employment_status': 'salarie',
    });
    await provider.triggerBackendSync();

    expect(claimBody, isNotNull);
    expect(claimBody!['wizard_answers'], contains('q_canton'));
    expect(claimBody!['wizard_answers'], isNot(contains('onb_axis_v2')));
    expect(
        claimBody!['mint2_axis_handoff']['onb_axis_v2'], 'lpp_rente_capital');
  });

  test('mergeAnswers does not keep partial data after seal failure', () async {
    final provider = CoachProfileProvider();

    await provider.mergeAnswers({
      'q_canton': 'VD',
      'q_net_income_period_chf': 7000,
    });

    final loaded = await ReportPersistenceService.loadAnswers();
    expect(loaded, isEmpty);
    expect(provider.profile, isNull);
  });

  test('dateOfBirth is not demoted to SharedPreferences on seal failure',
      () async {
    final provider = CoachProfileProvider();

    await provider.mergeAnswers({
      'q_date_of_birth': '1981-06-15',
      'q_canton': 'VD',
    });

    final loaded = await ReportPersistenceService.loadAnswers();
    expect(loaded, isEmpty);
    expect(provider.profile, isNull);
  });

  test('session-only onboarding profile survives a later wizard reload',
      () async {
    final provider = CoachProfileProvider();

    provider.updateFromAnswers({
      'q_date_of_birth': '1981-06-15',
      'q_birth_year': 1981,
      'q_canton': 'ZH',
      'q_nationality': 'CH',
      'q_employment_status': 'salarie',
      'q_has_pension_fund': true,
    });
    await provider.loadFromWizard();

    final loaded = await ReportPersistenceService.loadAnswers();
    expect(loaded, isEmpty);
    expect(provider.profile, isNotNull);
    expect(provider.profile!.nationality, 'CH');
  });

  test('dateOfBirth save fact does not persist raw DOB on seal failure',
      () async {
    final provider = CoachProfileProvider();

    final applied = await provider.applySaveFact('dateOfBirth', '1981-06-15');
    final loaded = await ReportPersistenceService.loadAnswers();

    expect(applied, isTrue);
    expect(loaded, isEmpty);
  });

  test('householdType save fact writes household key, not civil status',
      () async {
    final secureStorage = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        final key = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) secureStorage[key] = value;
            return null;
          case 'read':
            return key == null ? null : secureStorage[key];
          case 'delete':
            if (key != null) secureStorage.remove(key);
            return null;
          default:
            return null;
        }
      },
    );
    final provider = CoachProfileProvider();

    final applied = await provider.applySaveFact('householdType', 'concubine');
    final loaded = await ReportPersistenceService.loadAnswers();

    expect(applied, isTrue);
    expect(loaded['q_household_type'], 'concubine');
    expect(loaded.containsKey('q_civil_status'), isFalse);
  });

  test('updateFromSmartFlow does not keep unsealed salary in memory', () async {
    final provider = CoachProfileProvider();

    await provider.updateFromSmartFlow(
      age: 40,
      grossSalary: 120000,
      canton: 'VD',
    );

    final loaded = await ReportPersistenceService.loadAnswers();
    expect(loaded, isEmpty);
    expect(provider.profile, isNull);
  });

  test('updateInline rebuilds profile from sealed persisted truth', () async {
    final provider = CoachProfileProvider();

    await provider.mergeAnswers({'q_canton': 'VD'});
    await provider.updateInline(
      salaireBrutMensuel: 9000,
      avoirLppTotal: 120000,
    );

    final loaded = await ReportPersistenceService.loadAnswers();
    expect(loaded['q_canton'], 'VD');
    expect(loaded.containsKey('q_net_income_period_chf'), isFalse);
    expect(loaded.containsKey('_coach_avoir_lpp'), isFalse);
    expect(provider.profile, isNotNull);
    expect(provider.profile!.canton, 'VD');
    expect(provider.profile!.salaireBrutMensuel, isZero);
    expect(provider.profile!.prevoyance.avoirLppTotal, isNot(120000));
  });

  test('backend-only canonical income hydrates a partial profile', () async {
    final secureStorage = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        final key = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) secureStorage[key] = value;
            return null;
          case 'read':
            return key == null ? null : secureStorage[key];
          case 'delete':
            if (key != null) secureStorage.remove(key);
            return null;
          default:
            return null;
        }
      },
    );
    await ReportPersistenceService.saveAnswers({
      'q_date_of_birth': '1981-06-15',
      'q_canton': 'VD',
      'q_gross_salary_annual': 120000,
    });

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    expect(provider.profile, isNotNull);
    expect(provider.profile!.dateOfBirth, DateTime(1981, 6, 15));
    expect(provider.profile!.canton, 'VD');
    expect(provider.profile!.salaireBrutMensuel, 10000);
  });

  test('self-employed annual income alone hydrates a partial profile',
      () async {
    final secureStorage = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        final key = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) secureStorage[key] = value;
            return null;
          case 'read':
            return key == null ? null : secureStorage[key];
          case 'delete':
            if (key != null) secureStorage.remove(key);
            return null;
          default:
            return null;
        }
      },
    );
    await ReportPersistenceService.saveAnswers({
      'q_self_employed_net_income_annual_chf': 120000,
    });

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    expect(provider.profile, isNotNull);
    expect(provider.isPartialProfile, isTrue);
    expect(provider.profile!.independentNetProfessionalIncomeAnnual, 120000);
  });

  test('backend profile hydration survives cold start from secure prefs',
      () async {
    final secureStorage = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        final key = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) secureStorage[key] = value;
            return null;
          case 'read':
            return key == null ? null : secureStorage[key];
          case 'delete':
            if (key != null) secureStorage.remove(key);
            return null;
          default:
            return null;
        }
      },
    );
    final merged = AuthProvider.mergeBackendProfileDataForTest({}, {
      'dateOfBirth': '1981-06-15',
      'birthYear': 1990,
      'canton': 'VD',
      'incomeGrossYearly': 120000,
      'householdType': 'concubine',
    });

    final saved = await ReportPersistenceService.saveAnswers(merged);
    final prefs = await SharedPreferences.getInstance();
    final raw = json.decode(prefs.getString('wizard_answers_v2')!)
        as Map<String, dynamic>;
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    expect(saved, isTrue);
    expect(merged['q_birth_year'], 1981);
    expect(merged['q_household_type'], 'concubine');
    expect(merged.containsKey('q_civil_status'), isFalse);
    expect(raw['q_canton'], 'VD');
    expect(raw['q_date_of_birth'], '__secure__');
    expect(raw['q_birth_year'], '__secure__');
    expect(raw['q_gross_salary_annual'], '__secure__');
    expect(raw['q_household_type'], '__secure__');
    expect(raw.containsValue('1981-06-15'), isFalse);
    expect(raw.containsValue(120000), isFalse);
    expect(provider.profile, isNotNull);
    expect(provider.profile!.dateOfBirth, DateTime(1981, 6, 15));
    expect(provider.profile!.birthYear, 1981);
    expect(provider.profile!.ageOrNull, isNotNull);
    expect(provider.profile!.canton, 'VD');
    expect(provider.profile!.salaireBrutMensuel, 10000);
    expect(
        provider.profile!.userProvidedFields.contains('civilStatus'), isFalse);
  });

  test('recommended wizard section accepts canonical and legacy civil status',
      () {
    Map<String, dynamic> coupleAnswers(String civilKey) => {
          'q_date_of_birth': '1981-06-15',
          'q_canton': 'VD',
          'q_net_income_period_chf': 7000,
          'q_employment_status': 'salarie',
          'q_household_type': 'couple',
          civilKey: 'married',
          'q_partner_net_income_chf': 5000,
          'q_partner_birth_year': 1982,
          'q_partner_employment_status': 'salarie',
          'q_has_pension_fund': 'yes',
          'q_has_3a': 'yes',
        };

    final canonical = CoachProfileProvider();
    canonical.updateFromAnswers(coupleAnswers('q_civil_status'));

    final legacy = CoachProfileProvider();
    legacy.updateFromAnswers(coupleAnswers('q_civil_status_choice'));

    expect(canonical.recommendedWizardSection, 'property');
    expect(legacy.recommendedWizardSection, 'property');
  });
}
