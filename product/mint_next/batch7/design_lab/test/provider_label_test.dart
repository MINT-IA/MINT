import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/provider_label.dart';

void main() {
  test('normalizes a provider label without persisting an identifier', () {
    expect(normalizeProviderLabel('  ViAc  '), 'viac');
    expect(normalizeProviderLabel('Banque   Cantonale'), 'banque cantonale');
  });

  test('accepts a human-readable provider brand', () {
    for (final value in ['VIAC', 'PostFinance', 'Banque Cantonale Vaudoise']) {
      expect(providerLabelIsSafe(value), isTrue, reason: value);
    }
  });

  test('rejects account policy AVS and IBAN-like identifiers', () {
    for (final value in [
      'CH93 0076 2011 6238 5295 7',
      '756.1234.5678.97',
      'Police POL-12345678',
      'Compte 123456789012',
      '1234567890',
    ]) {
      expect(providerLabelIsSafe(value), isFalse, reason: value);
    }
  });

  test('rejects empty and overlong labels', () {
    expect(providerLabelIsSafe('  '), isFalse);
    expect(providerLabelIsSafe(List.filled(33, 'a').join()), isFalse);
  });
}
