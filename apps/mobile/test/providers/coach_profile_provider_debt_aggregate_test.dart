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
    secureStorage.clear();
    SharedPreferences.setMockInitialValues({});
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
          case 'readAll':
            return Map<String, String>.from(secureStorage);
          case 'delete':
            if (key != null) secureStorage.remove(key);
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

  test('totalDebt stays aggregate and never writes autresDettes', () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('totalDebt', 25000), isTrue);
    expect(provider.profile!.dettes.totalDettes, 25000);
    expect(provider.profile!.dettes.nonVentilee, 25000);
    expect(provider.answersSnapshot['q_total_debt_balance_chf'], 25000);
    expect(
      provider.answersSnapshot.containsKey('_coach_dettes_autres'),
      isFalse,
    );

    await provider.updateInline(epargneLiquide: 5000);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_total_debt_balance_chf'], 25000);
    expect(answers.containsKey('_coach_dettes_autres'), isFalse);
  });

  test('partial debt categories preserve declared total as non-ventilated debt',
      () async {
    final provider = CoachProfileProvider();

    await provider.mergeAnswers(const {
      'q_total_debt_balance_chf': 25000,
      'q_has_consumer_debt': true,
      '_coach_dettes_leasing': 10000,
    });

    expect(provider.profile!.dettes.leasing, 10000);
    expect(provider.profile!.dettes.nonVentilee, 15000);
    expect(provider.profile!.dettes.totalDettes, 25000);

    final restored = CoachProfile.fromWizardAnswers(
      await ReportPersistenceService.loadAnswers(),
    );
    expect(restored.dettes.leasing, 10000);
    expect(restored.dettes.nonVentilee, 15000);
    expect(restored.dettes.totalDettes, 25000);
  });

  test('hasDebt alone does not invent a debt balance', () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('hasDebt', true), isTrue);
    expect(provider.answersSnapshot['q_has_consumer_debt'], isTrue);
    expect(provider.profile!.dettes.totalDettes, 0);
    expect(provider.profile!.dettes.hasDette, isFalse);
  });
}
