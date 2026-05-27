import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStorage = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            if (value != null) secureStorage[key] = value;
            return null;
          case 'read':
            final key = call.arguments['key'] as String;
            return secureStorage[key];
          case 'delete':
            final key = call.arguments['key'] as String;
            secureStorage.remove(key);
            return null;
          case 'deleteAll':
            secureStorage.clear();
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

  test('open banking budget and investment values survive restart', () async {
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1988,
      'q_canton': 'VD',
      'q_net_income_period_chf': 8000.0,
      'q_pay_frequency': 'monthly',
    });
    await ReportPersistenceService.setCompleted(true);

    final provider = CoachProfileProvider();
    provider.updateProfile(
      CoachProfile(
        birthYear: 1988,
        canton: 'VD',
        salaireBrutMensuel: 10000,
        goalA: GoalA(
          type: GoalAType.achatImmo,
          targetDate: DateTime(2032),
          label: 'Logement',
        ),
      ),
    );

    await provider.updateFromOpenBanking(
      accounts: const [
        {'accountType': 'checking', 'balance': 18000.0},
        {'accountType': 'securities', 'balance': 52000.0},
      ],
      categoryTotals: const {
        'logement': 2400.0,
        'assurances': 450.0,
        'transport': 180.0,
      },
    );

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_cash_total'], 18000.0);
    expect(answers['q_investments_total'], 52000.0);
    expect(answers['q_housing_cost_period_chf'], 2400.0);
    expect(answers['q_lamal_premium_monthly_chf'], 450.0);
    expect(answers['_coach_depenses_transport'], 180.0);
    expect(answers.containsKey('_coach_investissements'), isFalse);
    expect(answers.containsKey('_coach_depenses_loyer'), isFalse);
    expect(answers.containsKey('_coach_depenses_assurance'), isFalse);

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();

    expect(reloaded.profile!.patrimoine.epargneLiquide, 18000.0);
    expect(reloaded.profile!.patrimoine.investissements, 52000.0);
    expect(reloaded.profile!.depenses.loyer, 2400.0);
    expect(reloaded.profile!.depenses.assuranceMaladie, 450.0);
    expect(reloaded.profile!.depenses.transport, 180.0);
  });
}
