import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/gift_tax_confirmation.dart';

void main() {
  test('gift tax confirmation state exposes no computed tariff', () {
    expect(GiftTaxConfirmation.noComputedRate, 0.0);
    expect(GiftTaxConfirmation.noComputedAmount, 0.0);
  });
}
