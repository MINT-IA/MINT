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
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorage, (call) async {
    if (call.method == 'read') return null;
    if (call.method == 'readAll') return <String, String>{};
    return null;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
}
