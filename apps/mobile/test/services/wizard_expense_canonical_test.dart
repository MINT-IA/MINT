import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/wizard_questions_v2.dart';
import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:mint_mobile/services/wizard_service.dart';
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

  test('saveAnswers normalizes legacy fixed-charge keys before storage',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 2100,
      'q_lamal_premium_monthly_chf': 390,
    });

    final loaded = await ReportPersistenceService.loadAnswers();

    expect(loaded['_coach_depenses_loyer'], 2100);
    expect(loaded['_coach_depenses_assurance'], 390);
    expect(loaded.containsKey('q_housing_cost_period_chf'), isFalse);
    expect(loaded.containsKey('q_lamal_premium_monthly_chf'), isFalse);

    final prefs = await SharedPreferences.getInstance();
    final rawAnswers = prefs.getString('wizard_answers_v2');
    expect(rawAnswers, contains('_coach_depenses_loyer'));
    expect(rawAnswers, contains('_coach_depenses_assurance'));
    expect(rawAnswers, isNot(contains('q_housing_cost_period_chf')));
    expect(rawAnswers, isNot(contains('q_lamal_premium_monthly_chf')));
    expect(mockSecureStorage['_coach_depenses_loyer'], '2100');
    expect(mockSecureStorage['_coach_depenses_assurance'], '390');
    expect(mockSecureStorage.containsKey('q_housing_cost_period_chf'), isFalse);
    expect(
      mockSecureStorage.containsKey('q_lamal_premium_monthly_chf'),
      isFalse,
    );
  });

  test('savings allocation condition reads canonical fixed charges first', () {
    final savingsAllocation = WizardQuestionsV2.questions
        .firstWhere((q) => q.id == 'q_savings_allocation');

    final shouldShow = savingsAllocation.shouldShow({
      'q_net_income_period_chf': 5000,
      '_coach_depenses_loyer': 4500,
      '_coach_depenses_assurance': 600,
      'q_debt_payments_period_chf': 0,
      'q_tax_provision_monthly_chf': 0,
      'q_other_fixed_costs_monthly_chf': 0,
    });

    expect(shouldShow, isFalse);
  });

  test('completion score counts canonical fixed-charge aliases', () {
    const questions = [
      WizardQuestion(
        id: 'q_housing_cost_period_chf',
        type: QuestionType.number,
        title: 'Housing cost',
      ),
    ];

    final legacyScore = WizardService.calculateCompletionScore(
      {'q_housing_cost_period_chf': 2100},
      questions,
    );
    final canonicalScore = WizardService.calculateCompletionScore(
      {'_coach_depenses_loyer': 2100},
      questions,
    );

    expect(legacyScore, 100);
    expect(canonicalScore, legacyScore);
  });

  test('fixed-charge values are sensitive persistence keys', () {
    expect(SecureWizardStore.isSensitive('_coach_depenses_loyer'), isTrue);
    expect(SecureWizardStore.isSensitive('_coach_depenses_assurance'), isTrue);
    expect(SecureWizardStore.isSensitive('q_housing_cost_period_chf'), isTrue);
    expect(
      SecureWizardStore.isSensitive('q_lamal_premium_monthly_chf'),
      isTrue,
    );
  });
}
