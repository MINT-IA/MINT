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

  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
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
      // PII in the (plain-SharedPreferences-bound) answer map.
      expect(cleaned['q_net_income_period_chf'], isNot('7000'));
      expect(cleaned['q_net_income_period_chf'], '__secure__');
    });
  });

  group('SecureWizardStore — happy path (provisioned keychain)', () {
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
  });
}
