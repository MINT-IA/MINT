import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageValues = <String, String>{};
  var failWrites = false;
  var hangWrites = false;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorage, (call) async {
    final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    final key = args['key'] as String?;
    if (call.method == 'write' && key != null) {
      if (failWrites) throw PlatformException(code: '-34018');
      if (hangWrites) return Completer<Object?>().future;
      secureStorageValues[key] = args['value'] as String;
      return null;
    }
    if (call.method == 'read' && key != null) return secureStorageValues[key];
    if (call.method == 'delete' && key != null) {
      secureStorageValues.remove(key);
      return null;
    }
    return null;
  });

  setUp(() {
    secureStorageValues.clear();
    failWrites = false;
    hangWrites = false;
  });

  group('SecureWizardStore', () {
    test('treats gross salary ledger keys as sensitive', () {
      expect(SecureWizardStore.isSensitive('q_gross_salary'), isTrue);
      expect(SecureWizardStore.isSensitive('q_gross_salary_annual'), isTrue);
      expect(SecureWizardStore.isSensitive('q_self_employed_income'), isTrue);
      expect(
        SecureWizardStore.isSensitive('q_company_profit_annual_chf'),
        isTrue,
      );
      expect(SecureWizardStore.isSensitive('q_net_income_period_chf'), isTrue);
    });

    test('treats broad wealth estimate as sensitive', () {
      expect(SecureWizardStore.isSensitive('q_wealth_estimate'), isTrue);
      expect(SecureWizardStore.isSensitive('q_cash_total'), isTrue);
    });

    test('treats partner income as sensitive but not partner birth year', () {
      expect(SecureWizardStore.isSensitive('q_partner_net_income_chf'), isTrue);
      expect(SecureWizardStore.isSensitive('q_partner_birth_year'), isFalse);
    });

    test('treats debt ledger keys as sensitive', () {
      expect(SecureWizardStore.isSensitive('q_has_consumer_debt'), isTrue);
      expect(SecureWizardStore.isSensitive('_coach_dettes_hypotheque'), isTrue);
      expect(SecureWizardStore.isSensitive('_coach_dettes_credit'), isTrue);
      expect(SecureWizardStore.isSensitive('_coach_dettes_leasing'), isTrue);
      expect(SecureWizardStore.isSensitive('_coach_dettes_autres'), isTrue);
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

    test('round-trips debt presence as a bool', () async {
      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_has_consumer_debt': true,
      });

      final restored = await SecureWizardStore.restoreSensitiveKeys(cleaned);

      expect(cleaned['q_has_consumer_debt'], '__secure__');
      expect(restored['q_has_consumer_debt'], true);
    });

    test('does not restore stale secure values absent from answers', () async {
      await SecureWizardStore.secureSensitiveKeys({
        'q_cash_total': 36000,
      });

      final restored = await SecureWizardStore.restoreSensitiveKeys({
        'q_self_employed_income': 144000,
      });

      expect(restored, containsPair('q_self_employed_income', 144000));
      expect(restored.containsKey('q_cash_total'), isFalse);
    });

    test('keeps local dev value when secure write throws', () async {
      failWrites = true;

      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_net_income_period_chf': 144000,
      });

      expect(cleaned['q_net_income_period_chf'], 144000);
      expect(secureStorageValues, isEmpty);
    });

    test('keeps local dev value when secure write times out', () async {
      hangWrites = true;

      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_net_income_period_chf': 144000,
      });

      expect(cleaned['q_net_income_period_chf'], 144000);
      expect(secureStorageValues, isEmpty);
    });

    test('deletes stale secure debt amount when value is null', () async {
      await SecureWizardStore.secureSensitiveKeys({
        '_coach_dettes_autres': 25000,
      });

      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        '_coach_dettes_autres': null,
      });
      final restored = await SecureWizardStore.restoreSensitiveKeys(cleaned);

      expect(cleaned.containsKey('_coach_dettes_autres'), isFalse);
      expect(restored['_coach_dettes_autres'], isNull);
    });
  });
}
