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

  test('hydrates FATCA hard-gate signal on cold start before full profile',
      () async {
    final saved = await ReportPersistenceService.saveAnswers({
      'q_us_tax_person': true,
    });
    expect(saved, isTrue);

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    expect(provider.profile, isNotNull);
    expect(provider.isPartialProfile, isTrue);
    expect(provider.profile!.usTaxPerson, isTrue);
    expect(provider.profile!.archetype, FinancialArchetype.expatUs);
  });
}
