import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/check_in_amount_parser.dart';

void main() {
  group('CheckInAmountParser.parseAmount', () {
    test('returns 500.0 for plain integer "500"', () {
      expect(CheckInAmountParser.parseAmount('500'), 500.0);
    });

    test('returns 500.0 for natural language "j\'ai verse 500"', () {
      expect(CheckInAmountParser.parseAmount("j'ai verse 500"), 500.0);
    });

    test('returns 1500.50 for Swiss apostrophe format "1\'500.50"', () {
      expect(CheckInAmountParser.parseAmount("1'500.50"), 1500.50);
    });

    test('returns 1500.0 for "CHF 1500"', () {
      expect(CheckInAmountParser.parseAmount('CHF 1500'), 1500.0);
    });

    test('returns 1500.0 for space separator "1 500"', () {
      expect(CheckInAmountParser.parseAmount('1 500'), 1500.0);
    });

    test('returns 1.50 for comma decimal "1,50"', () {
      expect(CheckInAmountParser.parseAmount('1,50'), 1.50);
    });

    test('returns null for "rien"', () {
      expect(CheckInAmountParser.parseAmount('rien'), isNull);
    });

    test('returns null for empty string', () {
      expect(CheckInAmountParser.parseAmount(''), isNull);
    });

    test('returns null for negative amount (clamped)', () {
      expect(CheckInAmountParser.parseAmount('-100'), isNull);
    });

    test('returns 999999.99 for max boundary', () {
      expect(CheckInAmountParser.parseAmount('999999.99'), 999999.99);
    });

    test('returns null for over-max amount "1000001"', () {
      expect(CheckInAmountParser.parseAmount('1000001'), isNull);
    });
  });
}
