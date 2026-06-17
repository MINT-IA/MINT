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
