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

  test('mergeAnswers rebuilds UI state from actually persisted answers',
      () async {
    final provider = CoachProfileProvider();

    await provider.mergeAnswers({
      'q_canton': 'VD',
      'q_net_income_period_chf': 7000,
    });

    final loaded = await ReportPersistenceService.loadAnswers();
    expect(loaded, {'q_canton': 'VD'});
    expect(provider.profile, isNotNull);
    expect(provider.profile!.canton, 'VD');
    expect(provider.profile!.explicitMonthlyNetIncome, isNull);
    expect(provider.profile!.salaireBrutMensuel, isZero);
  });

  test('dateOfBirth save fact completes identity without q_birth_year',
      () async {
    final provider = CoachProfileProvider();

    await provider.mergeAnswers({
      'q_date_of_birth': '1981-06-15',
      'q_canton': 'VD',
    });

    expect(provider.profile, isNotNull);
    expect(provider.profile!.dateOfBirth, DateTime(1981, 6, 15));
    expect(provider.recommendedWizardSection, isNot('identity'));
  });

  test('dateOfBirth save fact also writes q_birth_year compatibility',
      () async {
    final provider = CoachProfileProvider();

    final applied = await provider.applySaveFact('dateOfBirth', '1981-06-15');
    final loaded = await ReportPersistenceService.loadAnswers();

    expect(applied, isTrue);
    expect(loaded['q_date_of_birth'], '1981-06-15');
    expect(loaded['q_birth_year'], 1981);
  });

  test('updateFromSmartFlow does not keep unsealed salary in memory', () async {
    final provider = CoachProfileProvider();
    final birthYear = DateTime.now().year - 40;

    await provider.updateFromSmartFlow(
      age: 40,
      grossSalary: 120000,
      canton: 'VD',
    );

    final loaded = await ReportPersistenceService.loadAnswers();
    expect(loaded['q_birth_year'], birthYear);
    expect(loaded['q_canton'], 'VD');
    expect(loaded.containsKey('q_net_income_period_chf'), isFalse);
    expect(loaded.containsKey('q_gross_salary_annual'), isFalse);
    expect(provider.profile, isNotNull);
    expect(provider.profile!.birthYear, birthYear);
    expect(provider.profile!.canton, 'VD');
    expect(provider.profile!.salaireBrutMensuel, isZero);
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
}
