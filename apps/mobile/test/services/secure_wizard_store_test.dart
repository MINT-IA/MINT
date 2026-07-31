import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';

/// SALVAGE-01-04: regression for the sim-keychain seal-write asymmetry.
///
/// `read()` already swallowed the iOS-simulator `-34018`
/// (errSecMissingEntitlement) PlatformException; `write()` did not, so a
/// fresh onboarding flush on the simulator threw at the seal
/// (`secureSensitiveKeys`) and the user never reached the coach. These
/// tests pin the symmetric guard and the SEC-10 invariant (no PII demoted
/// to plain storage).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('SecureWizardStore.write — sim keychain (-34018) guard', () {
    test('secureSensitiveKeys does NOT throw when the keychain write fails',
        () async {
      // Simulate the iOS-sim missing-entitlement failure on every write.
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'write') {
          throw PlatformException(
            code: '-34018',
            message: 'errSecMissingEntitlement',
          );
        }
        return null;
      });

      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_net_income_period_chf': '7000',
        'q_canton': 'VD', // non-sensitive — must pass through untouched
      });

      // The seal degrades gracefully instead of aborting the flush.
      expect(cleaned['q_canton'], 'VD');
      // SEC-10: the sensitive value is sealed-or-dropped, NEVER left as raw
      // PII or as a dangling secure placeholder in the plain answer map.
      expect(cleaned['q_net_income_period_chf'], isNot('7000'));
      expect(cleaned['q_net_income_period_chf'], isNull);
    });
  });

  // NOTE (ordering): this group MUST be declared BEFORE any group that calls
  // `FlutterSecureStorage.setMockInitialValues()` (e.g. the happy-path group
  // below). That call swaps `FlutterSecureStoragePlatform.instance` to an
  // in-memory impl that BYPASSES the MethodChannel, which would turn the
  // `-34018` channel mock here into a no-op (writes would silently succeed).
  // Declaration order == run order (no test randomization — see
  // apps/mobile/dart_test.yaml), so keeping this group ahead of the
  // setMockInitialValues groups preserves the channel platform. Same
  // clean-platform assumption as the '-34018 guard' group above.
  group('SecureWizardStore — E2E seal fallback (debug/harness-only)', () {
    // Reproduce the unsigned-sim keychain: every write throws -34018, reads
    // return null WITHOUT throwing (the real sim / secure_failure_test shape).
    void mockMissingEntitlement() {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'write') {
          throw PlatformException(
            code: '-34018',
            message: 'errSecMissingEntitlement',
          );
        }
        return null; // read/delete return null (no throw)
      });
    }

    tearDown(SecureWizardStore.resetSealFallbackForTest);

    test('DISABLED by default: -34018 still drops the sensitive value '
        '(release-parity, privacy contract intact)', () async {
      mockMissingEntitlement();

      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_net_income_period_chf': '7000',
        'q_canton': 'VD',
      });

      // Fallback is off (no override, no dart-define) -> genuine seal failure.
      expect(cleaned['q_canton'], 'VD');
      expect(cleaned['q_net_income_period_chf'], isNull);
      final restored = await SecureWizardStore.restoreSensitiveKeys(cleaned);
      expect(restored['q_net_income_period_chf'], isNull);
    });

    test('ENABLED: -34018 seals into the in-memory store and round-trips back',
        () async {
      mockMissingEntitlement();
      SecureWizardStore.debugSealFallbackOverride = true;

      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_net_income_period_chf': '7000',
        'q_canton': 'VD',
      });

      // The seal now SUCCEEDS off-keychain: sensitive key -> placeholder,
      // non-sensitive untouched, raw PII never left in the plain map.
      expect(cleaned['q_net_income_period_chf'], '__secure__');
      expect(cleaned['q_canton'], 'VD');
      expect(cleaned.containsValue('7000'), isFalse);

      // Read-back path (loadAnswers -> restoreSensitiveKeys -> read) recovers
      // the real value from RAM even though the keychain read returns null.
      final restored = await SecureWizardStore.restoreSensitiveKeys(cleaned);
      expect(restored['q_net_income_period_chf'], 7000);
      expect(restored['q_canton'], 'VD');
    });

    test('ENABLED: sealSensitiveKeys reports allSensitiveSealed = true '
        '(so saveAnswers persists and the profile is not cleared)', () async {
      mockMissingEntitlement();
      SecureWizardStore.debugSealFallbackOverride = true;

      final result = await SecureWizardStore.sealSensitiveKeys({
        'q_net_income_period_chf': '7000',
        'q_avoir_lpp': '318000',
        'q_canton': 'VD',
      });

      expect(result.allSensitiveSealed, isTrue);
      expect(result.cleaned['q_net_income_period_chf'], '__secure__');
      expect(result.cleaned['q_avoir_lpp'], '__secure__');
      expect(result.cleaned['q_canton'], 'VD');
    });

    test('ENABLED: deleteAll purges the in-memory fallback (privacy reset)',
        () async {
      mockMissingEntitlement();
      SecureWizardStore.debugSealFallbackOverride = true;

      await SecureWizardStore.write('q_net_income_period_chf', '7000');
      expect(
        await SecureWizardStore.read('q_net_income_period_chf'),
        '7000',
      );

      await SecureWizardStore.deleteAll();

      // Fallback store emptied -> no resident PII after reset.
      expect(
        await SecureWizardStore.read('q_net_income_period_chf'),
        isNull,
      );
    });

    test('ENABLED: deleteAll purges even when the override is flipped off first',
        () async {
      mockMissingEntitlement();
      SecureWizardStore.debugSealFallbackOverride = true;
      await SecureWizardStore.write('q_net_income_period_chf', '7000');

      // Override disabled AFTER the seal landed — deleteAll must still purge
      // (gated on !kReleaseMode, not the E2E flag).
      SecureWizardStore.debugSealFallbackOverride = false;
      await SecureWizardStore.deleteAll();

      SecureWizardStore.debugSealFallbackOverride = true;
      expect(
        await SecureWizardStore.read('q_net_income_period_chf'),
        isNull,
      );
    });

    test('ENABLED: a NON-(-34018) PlatformException still fails closed',
        () async {
      // Any storage defect other than missing-entitlement must NOT be masked.
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'write') {
          throw PlatformException(code: '-25300', message: 'errSecItemNotFound');
        }
        return null;
      });
      SecureWizardStore.debugSealFallbackOverride = true;

      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_net_income_period_chf': '7000',
        'q_canton': 'VD',
      });

      expect(cleaned['q_canton'], 'VD');
      expect(cleaned['q_net_income_period_chf'], isNull);
    });
  });

  group('SecureWizardStore — happy path (provisioned keychain)', () {
    test('classifies PR5 mapped wizard keys outside broad secure prefixes', () {
      const sensitive = {
        'q_employment_rate',
        'q_has_3a',
        'q_has_consumer_debt',
        'q_has_pension_fund',
        'q_net_income_period_source',
        'q_pay_frequency',
        'q_self_employed_net_income_annual_chf',
        'q_target_retirement_age',
      };

      for (final key in sensitive) {
        expect(
          SecureWizardStore.classificationForKey(key),
          WizardStorageClassification.sensitive,
          reason: '$key must not stay in plain SharedPreferences',
        );
        expect(SecureWizardStore.isSensitive(key), isTrue);
      }

      expect(
        SecureWizardStore.classificationForKey('q_canton'),
        WizardStorageClassification.nonSensitive,
      );
      expect(SecureWizardStore.isSensitive('q_canton'), isFalse);
      expect(
        SecureWizardStore.classificationForKey('q_main_goal'),
        WizardStorageClassification.productPreference,
      );
      expect(SecureWizardStore.isSensitive('q_main_goal'), isFalse);
    });

    test('seals a sensitive value and round-trips it back', () async {
      FlutterSecureStorage.setMockInitialValues({});

      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_net_income_period_chf': '7000',
        'q_canton': 'VD',
      });
      expect(cleaned['q_net_income_period_chf'], '__secure__');
      expect(cleaned['q_canton'], 'VD');

      final restored = await SecureWizardStore.restoreSensitiveKeys(cleaned);
      expect(restored['q_net_income_period_chf'], 7000);
      expect(restored['q_canton'], 'VD');
    });

    test('deleteAll deletes only wizard-owned keys', () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'keep-me',
        'q_net_income_period_chf': '7000',
        '_coach_depenses_custom': '120',
      });

      await SecureWizardStore.write('_coach_depenses_custom', '120');

      final deleted = await SecureWizardStore.deleteAll();

      expect(deleted, isTrue);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'auth_token'), 'keep-me');
      expect(await storage.read(key: 'q_net_income_period_chf'), isNull);
      expect(await storage.read(key: '_coach_depenses_custom'), isNull);
    });
  });
}
