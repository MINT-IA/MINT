import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/document_parser/document_parser_utils.dart';

void main() {
  group('parseSwissNumber', () {
    test('parses apostrophe format: 143\'287.50', () {
      expect(parseSwissNumber("143'287.50"), closeTo(143287.50, 0.01));
    });

    test('parses with CHF prefix', () {
      expect(parseSwissNumber("CHF 7'083.35"), closeTo(7083.35, 0.01));
    });

    test('parses with Fr. prefix', () {
      expect(parseSwissNumber("Fr. 7'083.35"), closeTo(7083.35, 0.01));
    });

    test('parses NBSP as thousand separator in number', () {
      // Non-breaking space is explicitly handled
      expect(parseSwissNumber("143\u00A0287"), closeTo(143287, 0.01));
    });

    test('parses comma as decimal (Swiss German): 7083,35', () {
      expect(parseSwissNumber("7083,35"), closeTo(7083.35, 0.01));
    });

    test('parses German thousands-dot + decimal-comma: 7.083,35', () {
      expect(parseSwissNumber("7.083,35"), closeTo(7083.35, 0.01));
    });

    test('parses English thousands-comma + decimal-dot: 7,083.35', () {
      expect(parseSwissNumber("7,083.35"), closeTo(7083.35, 0.01));
    });

    test('parses right single quote as thousand sep', () {
      expect(parseSwissNumber("143\u2019287.50"), closeTo(143287.50, 0.01));
    });

    test('parses NBSP as thousand sep', () {
      expect(parseSwissNumber("143\u00A0287.50"), closeTo(143287.50, 0.01));
    });

    test('parses negative number: -523.40', () {
      expect(parseSwissNumber("-523.40"), closeTo(-523.40, 0.01));
    });

    test('returns null for empty string', () {
      expect(parseSwissNumber(""), isNull);
    });

    test('returns null for non-numeric text', () {
      expect(parseSwissNumber("abc"), isNull);
    });

    test('parses plain integer', () {
      expect(parseSwissNumber("50000"), closeTo(50000, 0.01));
    });

    test('large German format: 1.234.567,89', () {
      expect(parseSwissNumber("1.234.567,89"), closeTo(1234567.89, 0.01));
    });
  });

  group('parsePercentage', () {
    test('parses 80%', () {
      expect(parsePercentage("80%"), closeTo(80, 0.1));
    });

    test('parses 6.8', () {
      expect(parsePercentage("6.8"), closeTo(6.8, 0.1));
    });

    test('parses 0.80 as 80%', () {
      expect(parsePercentage("0.80"), closeTo(80, 0.1));
    });

    test('parses 1.0 as 100% (decimal form)', () {
      expect(parsePercentage("1.0"), closeTo(100, 0.1));
    });

    test('parses 100 as 100%', () {
      expect(parsePercentage("100"), closeTo(100, 0.1));
    });

    test('returns null for empty string', () {
      expect(parsePercentage(""), isNull);
    });

    test('parses comma decimal: 6,80 %', () {
      expect(parsePercentage("6,80 %"), closeTo(6.80, 0.1));
    });
  });
}
