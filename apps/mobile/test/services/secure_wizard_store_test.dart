import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureWizardStore', () {
    test('treats gross salary ledger keys as sensitive', () {
      expect(SecureWizardStore.isSensitive('q_gross_salary'), isTrue);
      expect(SecureWizardStore.isSensitive('q_gross_salary_annual'), isTrue);
    });

    test('does not treat public profile keys as sensitive', () {
      expect(SecureWizardStore.isSensitive('q_canton'), isFalse);
      expect(SecureWizardStore.isSensitive('q_birth_year'), isFalse);
    });

    test('does not rewrite secure placeholders', () async {
      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_gross_salary_annual': '__secure__',
      });

      expect(cleaned['q_gross_salary_annual'], '__secure__');
    });
  });
}
