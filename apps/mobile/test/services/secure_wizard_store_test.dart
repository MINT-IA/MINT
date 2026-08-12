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
    // Reproduce the REAL unsigned-sim keychain error. flutter_secure_storage
    // iOS (SwiftFlutterSecureStoragePlugin) surfaces every OSStatus as
    // `code: "Unexpected security result code"` with the numeric status in
    // `details` (-34018 = errSecMissingEntitlement) and echoed in `message` —
    // NOT `code: "-34018"`. Using the real shape is what makes this test able to
    // catch a matcher that only checks `code` (the 2026-07-31 runtime miss).
    // Reads return null WITHOUT throwing (the real sim / secure_failure shape).
    void mockMissingEntitlement() {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'write') {
          throw PlatformException(
            code: 'Unexpected security result code',
            message:
                'Code: -34018, Message: A required entitlement is missing.',
            details: -34018,
          );
        }
        return null; // read/delete return null (no throw)
      });
    }

    tearDown(SecureWizardStore.resetSealFallbackForTest);

    test(
        'DISABLED by default: -34018 still drops the sensitive value '
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

    test(
        'ENABLED: sealSensitiveKeys reports allSensitiveSealed = true '
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

    test(
        'ENABLED: deleteAll purges even when the override is flipped off first',
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

    test('ENABLED: a NON-(-34018) keychain status still fails closed',
        () async {
      // iOS uses the SAME generic code ("Unexpected security result code") for
      // every keychain error — only the status differs. A different status
      // (-25300 errSecItemNotFound) must NOT be masked by the -34018 fallback.
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'write') {
          throw PlatformException(
            code: 'Unexpected security result code',
            message: 'Code: -25300, Message: The item cannot be found.',
            details: -25300,
          );
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
    test('classifies every canonical housing fact key as sensitive', () {
      const keys = {
        'q_housing_status',
        'q_housing_mortgage_status',
        'q_housing_mortgage_statement_availability',
        'q_housing_mortgage_statement_year',
        'q_housing_mortgage_annual_interest_cents',
        'q_housing_mortgage_debt_balance_cents',
        'q_housing_fact_asserted_at',
        'q_housing_fact_source',
        'q_housing_fact_schema_version',
        'q_housing_fact_needs_confirmation',
      };
      for (final key in keys) {
        expect(SecureWizardStore.isSensitive(key), isTrue, reason: key);
      }
    });

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

    test('deleteKeys deletes only requested sensitive wizard keys', () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'keep-me',
        'q_housing_status': 'owner_occupier',
        'q_housing_fact_source': 'housing_flow',
        'q_net_income_period_chf': '7000',
      });

      final deleted = await SecureWizardStore.deleteKeys({
        'q_housing_status',
        'q_housing_fact_source',
        'auth_token',
      });

      expect(deleted, isTrue);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'q_housing_status'), isNull);
      expect(await storage.read(key: 'q_housing_fact_source'), isNull);
      expect(await storage.read(key: 'q_net_income_period_chf'), '7000');
      expect(await storage.read(key: 'auth_token'), 'keep-me');
    });

    test('journal tracks absent members and is idempotent until finalized',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        'q_housing_status': 'owner_occupier',
      });

      final keys = {'q_housing_status', 'q_housing_fact_source'};
      expect(await SecureWizardStore.prepareDeleteTransaction(keys), isTrue);
      expect(await SecureWizardStore.prepareDeleteTransaction(keys), isTrue);
      expect(await SecureWizardStore.deleteKeys(keys), isTrue);
      expect(
          await SecureWizardStore.read('q_housing_status'), 'owner_occupier');
      expect(await SecureWizardStore.read('q_housing_fact_source'), isNull);

      expect(await SecureWizardStore.commitDeleteTransaction(), isTrue);
      final tombstone = await const FlutterSecureStorage()
          .read(key: '_mint_wizard_delete_journal_v2');
      expect(tombstone, contains('"state":"committed"'));
      expect(tombstone, isNot(contains('owner_occupier')));
      expect(tombstone, isNot(contains('"values"')));
      expect(await SecureWizardStore.read('q_housing_status'), isNull);
      expect(await SecureWizardStore.finalizeDeleteTransaction(), isTrue);
      expect(
        await const FlutterSecureStorage()
            .read(key: '_mint_wizard_delete_journal_v2'),
        isNull,
      );
    });

    test('deleteAll purges an open encrypted deletion journal', () async {
      FlutterSecureStorage.setMockInitialValues({
        'q_housing_status': 'owner_occupier',
      });
      expect(
        await SecureWizardStore.prepareDeleteTransaction({'q_housing_status'}),
        isTrue,
      );

      expect(await SecureWizardStore.deleteAll(), isTrue);
      expect(await SecureWizardStore.read('q_housing_status'), isNull);
      expect(
        await const FlutterSecureStorage()
            .read(key: '_mint_wizard_delete_journal_v2'),
        isNull,
      );
    });
  });
}
