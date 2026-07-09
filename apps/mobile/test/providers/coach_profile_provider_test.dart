import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageValues = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorage, (call) async {
    final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    final key = args['key'] as String?;
    if (call.method == 'write' && key != null) {
      secureStorageValues[key] = args['value'] as String;
      return null;
    }
    if (call.method == 'read' && key != null) return secureStorageValues[key];
    if (call.method == 'readAll') return secureStorageValues;
    if (call.method == 'delete' && key != null) {
      secureStorageValues.remove(key);
      return null;
    }
    if (call.method == 'deleteAll') {
      secureStorageValues.clear();
      return null;
    }
    return null;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorageValues.clear();
  });

  test('updateProfile persists liquid savings on the readable cash key',
      () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      patrimoine: const PatrimoineProfile(epargneLiquide: 88000),
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_cash_total', 88000));
    expect(answers.containsKey('q_epargne_liquide'), isFalse);
    expect(CoachProfile.fromWizardAnswers(answers).patrimoine.epargneLiquide,
        88000);
  });

  test('updateProfile persists 3a balance on the readable 3a total key',
      () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      prevoyance: const PrevoyanceProfile(totalEpargne3a: 42000),
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_3a_total', 42000));
    expect(answers.containsKey('q_total_3a'), isFalse);
    expect(CoachProfile.fromWizardAnswers(answers).prevoyance.totalEpargne3a,
        42000);
  });

  test('save_fact wealthEstimate writes its own readable estimate key',
      () async {
    final provider = CoachProfileProvider();

    final applied = await provider.applySaveFact('wealthEstimate', 350000);

    expect(applied, isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_wealth_estimate', 350000));
    expect(answers.containsKey('q_epargne_liquide'), isFalse);
    expect(provider.profile?.patrimoine.wealthEstimate, 350000);
    expect(provider.profile?.patrimoine.totalPatrimoine, 350000);
  });

  test('save_fact pillar3aBalance writes the readable 3a total key', () async {
    final provider = CoachProfileProvider();

    final applied = await provider.applySaveFact('pillar3aBalance', 42000);

    expect(applied, isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_3a_total', 42000));
    expect(answers.containsKey('q_total_3a'), isFalse);
    expect(provider.profile?.prevoyance.totalEpargne3a, 42000);
  });
}
