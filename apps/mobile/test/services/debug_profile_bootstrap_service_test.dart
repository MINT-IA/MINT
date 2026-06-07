import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/debug_profile_bootstrap_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStorage = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
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
        case 'deleteAll':
          secureStorage.clear();
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  test('persists and updates independent no-LPP answers through the real store',
      () async {
    final result = await DebugProfileBootstrapService.persistFixture(
      slug: 'independent_no_lpp_income_reality',
      selfEmployedNetIncomeAnnual: 86400,
      annual3aContribution: 6000,
    );

    expect(result.ok, isTrue);
    expect(result.slug, 'independent_no_lpp_income_reality');
    expect(result.storageMode, 'secureSeal');
    expect(result.selfEmployedNetIncomeAnnual, 86400);
    expect(result.annual3aContribution, 6000);
    expect(await ReportPersistenceService.isCompleted(), isTrue);

    final update = await DebugProfileBootstrapService.persistFixture(
      slug: 'independent_no_lpp_income_reality',
      mode: DebugProfileBootstrapMode.updateIncome,
      selfEmployedNetIncomeAnnual: 96000,
      annual3aContribution: 6000,
    );

    expect(update.ok, isTrue);
    expect(update.mode, DebugProfileBootstrapMode.updateIncome);
    expect(update.storageMode, 'secureSeal');
    expect(update.selfEmployedNetIncomeAnnual, 96000);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_firstname'], 'Nadia');
    expect(answers['q_employment_status'], 'independant');
    expect(answers['q_has_pension_fund'], isFalse);
    expect(answers['q_self_employed_net_income_annual_chf'], 96000);
    expect(answers['q_3a_annual_contribution'], 6000);

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    expect(provider.profile, isNotNull);
    expect(provider.isPartialProfile, isFalse);
    expect(provider.profile!.employmentStatus, 'independant');
    expect(provider.profile!.explicitMonthlyNetIncome, 8000);
    expect(provider.profile!.independentNetProfessionalIncomeAnnual, 96000);
    expect(provider.profile!.prevoyance.avoirLppTotal, 0);
    expect(provider.profile!.prevoyance.nombre3a, 1);
    expect(
      provider.profile!.plannedContributions.any(
        (c) => c.category == '3a' && c.amount == 500,
      ),
      isTrue,
    );
  });

  test('uses debug simulator fallback when secure seal is unavailable',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
      if (call.method == 'write') {
        throw PlatformException(
          code: '-34018',
          message: 'Missing iOS simulator keychain entitlement',
        );
      }
      return null;
    });

    final result = await DebugProfileBootstrapService.persistFixture(
      slug: 'independent_no_lpp_income_reality',
      selfEmployedNetIncomeAnnual: 96000,
      annual3aContribution: 6000,
    );

    expect(result.ok, isTrue);
    expect(result.storageMode, 'debugPlainFallback');
    expect(await ReportPersistenceService.isCompleted(), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_self_employed_net_income_annual_chf'], 96000);
    expect(answers['q_net_income_period_chf'], 8000);
    expect(answers['q_3a_annual_contribution'], 6000);

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    expect(provider.profile!.employmentStatus, 'independant');
    expect(provider.profile!.independentNetProfessionalIncomeAnnual, 96000);
    expect(provider.profile!.explicitMonthlyNetIncome, 8000);
    expect(provider.profile!.prevoyance.avoirLppTotal, 0);
  });

  test('rejects unknown fixture slugs without writing profile state', () async {
    final result = await DebugProfileBootstrapService.persistFixture(
      slug: 'unknown_fixture',
    );

    expect(result.ok, isFalse);
    expect(result.error, contains('Unknown debug fixture'));
    expect(result.storageMode, 'unavailable');
    expect(await ReportPersistenceService.isCompleted(), isFalse);
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);
  });
}
