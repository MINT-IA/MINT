import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/confidence/confidence_history_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D5 wiring proof: hydrating a material profile records a dated confidence
/// point (the socle that makes « Ton histoire »'s confidence curve possible),
/// and the reset contract erases it.
///
/// Deterministic by construction: the material profile is seeded by persisting
/// answers directly (no scan/check-in that would fire a competing record), so
/// hydration's awaited `profile_load` record is the only write.
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

  test('hydrating a material profile records an origin confidence point',
      () async {
    // Seed a material profile by persisting answers directly — no enrichment
    // event fires a competing history write.
    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_firstname': 'Test',
      'q_birth_year': 1985,
      'q_canton': 'VD',
      'q_net_income_period_chf': 8000,
      'q_pay_frequency': 'monthly',
      'q_employment_status': 'salarie',
      'q_civil_status': 'celibataire',
    });

    // Fresh hydration path: _mergePersistedData awaits the confidence record.
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    expect(provider.profile, isNotNull);

    final history = await ConfidenceHistoryService.load();
    expect(history, isNotEmpty,
        reason: 'profile hydration should record an origin point');
    final latest = history.last;
    expect(latest.combined, greaterThan(0));
    expect(latest.trigger, 'profile_load');

    // Reset contract erases the confidence history.
    await ReportPersistenceService.clearCoachHistory();
    expect(await ConfidenceHistoryService.load(), isEmpty);
  });
}
