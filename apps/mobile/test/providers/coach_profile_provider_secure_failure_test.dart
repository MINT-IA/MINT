import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
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
}
