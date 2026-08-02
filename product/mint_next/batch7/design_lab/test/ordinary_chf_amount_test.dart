import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/ordinary_chf_amount.dart';

void main() {
  group('parseOrdinaryChfAmount', () {
    const accepted = <String, int>{
      '7258': 725800,
      '7258.5': 725850,
      '7258,50': 725850,
      '7 258.50': 725850,
      '7\u00a0258,50': 725850,
      "7'258.50": 725850,
      '7’258,50': 725850,
      '0.29': 29,
      '999999999999.99': 99999999999999,
    };

    for (final entry in accepted.entries) {
      test('parses ${entry.key} exactly', () {
        expect(parseOrdinaryChfAmount(entry.key), entry.value);
      });
    }

    const rejected = <String>[
      '',
      '-1',
      '+1',
      '1e3',
      '1%',
      'NaN',
      'Infinity',
      'CHF 10',
      r'$10',
      '7,258',
      '7.258',
      '1,234.56',
      '1.234,56',
      '1.2345',
      '999999999999.991',
      '1000000000000.00',
      '111111111111111111111111111111111',
    ];

    for (final raw in rejected) {
      test('rejects $raw without approximation', () {
        expect(() => parseOrdinaryChfAmount(raw), throwsFormatException);
      });
    }

    test('uses one grammar in every supported locale', () {
      for (final locale in ['fr', 'en', 'de', 'it', 'es', 'pt']) {
        expect(parseOrdinaryChfAmount('7258,50', locale: locale), 725850);
        expect(
          () => parseOrdinaryChfAmount('7,258', locale: locale),
          throwsFormatException,
        );
      }
    });

    test('keeps zero distinct for the form to reject explicitly', () {
      expect(parseOrdinaryChfAmount('0'), 0);
      expect(parseOrdinaryChfAmount('0.00'), 0);
    });
  });
}
