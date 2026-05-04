import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/income_converter.dart';

void main() {
  group('IncomeConverter.netMonthlyToGrossAnnual', () {
    test('salaried factor applied: 7600 net → 106 704 brut annuel', () {
      final gross = IncomeConverter.netMonthlyToGrossAnnual(7600);
      expect(gross, closeTo(7600 * 12 * 1.17, 0.01));
      expect(gross, closeTo(106704, 0.01));
    });

    test('self-employed factor applied: 6000 net → 79 200 brut annuel', () {
      final gross = IncomeConverter.netMonthlyToGrossAnnual(
        6000,
        isSalaried: false,
      );
      expect(gross, closeTo(6000 * 12 * 1.10, 0.01));
      expect(gross, closeTo(79200, 0.01));
    });

    test('zero net yields zero brut', () {
      expect(IncomeConverter.netMonthlyToGrossAnnual(0), equals(0));
    });
  });

  group('IncomeConverter.netMonthlyRangeToGrossAnnual', () {
    test('propagates range preserving order low < high', () {
      final range = IncomeConverter.netMonthlyRangeToGrossAnnual(
        (low: 7500, high: 8000),
      );
      expect(range.lowGrossAnnual, closeTo(7500 * 12 * 1.17, 0.01));
      expect(range.highGrossAnnual, closeTo(8000 * 12 * 1.17, 0.01));
      expect(range.lowGrossAnnual, lessThan(range.highGrossAnnual));
    });

    test('self-employed range uses 1.10 factor', () {
      final range = IncomeConverter.netMonthlyRangeToGrossAnnual(
        (low: 5000, high: 6000),
        isSalaried: false,
      );
      expect(range.lowGrossAnnual, closeTo(5000 * 12 * 1.10, 0.01));
      expect(range.highGrossAnnual, closeTo(6000 * 12 * 1.10, 0.01));
    });
  });

  group('IncomeConverter.factorFor', () {
    test('exposes salaried factor 1.17 and self-employed 1.10', () {
      expect(IncomeConverter.factorFor(isSalaried: true), closeTo(1.17, 0.001));
      expect(IncomeConverter.factorFor(isSalaried: false), closeTo(1.10, 0.001));
    });
  });
}
