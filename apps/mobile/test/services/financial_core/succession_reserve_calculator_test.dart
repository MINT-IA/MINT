import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/succession_reserve_calculator.dart';

void main() {
  group('SuccessionReserveCalculator', () {
    test('2023 law removes parent compulsory portion', () {
      expect(
        SuccessionReserveCalculator.compulsoryPortionFractions['parent'],
        0.0,
      );
    });

    test('single donor with children reserves half of the estate reference',
        () {
      final result = SuccessionReserveCalculator.estimate(
        estateReference: 1000000,
        civilStatus: 'celibataire',
        childrenCount: 2,
      );

      expect(result.hasReservedSpouse, isFalse);
      expect(result.hasChildren, isTrue);
      expect(result.reserveHereditaireTotale, 500000);
      expect(result.quotiteDisponible, 500000);
    });

    test('married donor with children reserves spouse and children shares', () {
      final result = SuccessionReserveCalculator.estimate(
        estateReference: 1000000,
        civilStatus: 'marie',
        childrenCount: 2,
      );

      expect(result.hasReservedSpouse, isTrue);
      expect(result.reserveHereditaireTotale, 500000);
      expect(result.quotiteDisponible, 500000);
    });

    test('single donor without children has no compulsory portion estimate',
        () {
      final result = SuccessionReserveCalculator.estimate(
        estateReference: 800000,
        civilStatus: 'celibataire',
        childrenCount: 0,
      );

      expect(result.reserveHereditaireTotale, 0);
      expect(result.quotiteDisponible, 800000);
    });

    test('married donor without children uses spouse plus parentela context',
        () {
      final result = SuccessionReserveCalculator.estimate(
        estateReference: 800000,
        civilStatus: 'marie',
        childrenCount: 0,
      );

      expect(result.reserveHereditaireTotale, 300000);
      expect(result.quotiteDisponible, 500000);
    });

    test('large donation threshold is centralized in financial_core', () {
      expect(
        SuccessionReserveCalculator.isLargeDonation(
          donationAmount: 600000,
          estateReference: 1000000,
        ),
        isTrue,
      );
      expect(
        SuccessionReserveCalculator.isLargeDonation(
          donationAmount: 500000,
          estateReference: 1000000,
        ),
        isFalse,
      );
    });

    test('real-estate gift value is net of declared mortgage balance', () {
      expect(
        SuccessionReserveCalculator.netRealEstateGiftValue(
          marketValue: 900000,
          mortgageBalance: 250000,
        ),
        650000,
      );
      expect(
        SuccessionReserveCalculator.netRealEstateGiftValue(
          marketValue: 900000,
          mortgageBalance: 950000,
        ),
        0,
      );
    });
  });
}
