import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WS-D (mint-grounded-coach-m1 Plan 06, Task 3) — the mobile apply leg of the
/// chat→profile split-brain fix.
///
/// The backend appends a forward-safe `fact_saved` echo carrying {key, value}
/// when an internal `save_fact` persisted server-side (Task 2). The chat
/// tool_calls PROCESSING layer routes that echo through
/// [CoachProfileProvider.applyFactSavedEcho], which reuses the existing
/// provider write path ([CoachProfileProvider.applySaveFact] →
/// _mapFactKeyToAnswers → mergeAnswers). This proves the chat-stated age now
/// reaches the local CoachProfile the simulators read (W1 WTF-W1-04).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Stub flutter_secure_storage so the SecureWizardStore write path used by
  // mergeAnswers doesn't throw MissingPluginException in unit tests.
  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  Map<String, String> installSecureStore() {
    final secureStore = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (call) async {
      final key = call.arguments['key'] as String?;
      switch (call.method) {
        case 'write':
          final value = call.arguments['value'] as String?;
          if (key != null && value != null) secureStore[key] = value;
          return null;
        case 'read':
          return key == null ? null : secureStore[key];
        case 'readAll':
          return secureStore;
        case 'delete':
          if (key != null) secureStore.remove(key);
          return null;
        default:
          return null;
      }
    });
    return secureStore;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    installSecureStore();
  });

  group('CoachProfileProvider.applyFactSavedEcho', () {
    test('age echo (birthYear) reaches the local profile — W1 WTF-W1-04',
        () async {
      final p = CoachProfileProvider();
      // Marc tells the coach « j'ai 50 ans » → backend coerces to a birthYear
      // and echoes {key: birthYear, value: <year>}. profile.age must become 50.
      final birthYear = DateTime.now().year - 50;

      final applied = await p.applyFactSavedEcho({
        'key': 'birthYear',
        'value': birthYear,
      });

      expect(applied, isTrue);
      expect(p.profile, isNotNull);
      expect(p.profile!.age, 50);

      // Persisted through the canonical wizard answer key, so it survives
      // restart and feeds the simulators (not a parallel ephemeral store).
      // Read via the restore path — q_birth_year is a sensitive key sealed
      // into secure storage, so the raw prefs value is the '__secure__' sentinel.
      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['q_birth_year'], birthYear);
    });

    test('canton echo reaches the local profile via the provider write path',
        () async {
      final p = CoachProfileProvider();

      final applied = await p.applyFactSavedEcho({'key': 'canton', 'value': 'VD'});

      expect(applied, isTrue);
      expect(p.profile, isNotNull);
      expect(p.profile!.canton, 'VD');
    });

    test('unknown key is a no-op (no crash, profile untouched)', () async {
      final p = CoachProfileProvider();

      final applied =
          await p.applyFactSavedEcho({'key': 'unknownField', 'value': 42});

      expect(applied, isFalse);
      expect(p.profile, isNull);
    });

    test('missing key is a no-op', () async {
      final p = CoachProfileProvider();
      expect(await p.applyFactSavedEcho({'value': 1976}), isFalse);
    });

    test('null value is a no-op', () async {
      final p = CoachProfileProvider();
      expect(
        await p.applyFactSavedEcho({'key': 'birthYear', 'value': null}),
        isFalse,
      );
    });

    test('low-confidence echo is skipped (mirrors backend)', () async {
      final p = CoachProfileProvider();
      final applied = await p.applyFactSavedEcho({
        'key': 'birthYear',
        'value': DateTime.now().year - 40,
        'confidence': 'low',
      });
      expect(applied, isFalse);
      expect(p.profile, isNull);
    });
  });
}
