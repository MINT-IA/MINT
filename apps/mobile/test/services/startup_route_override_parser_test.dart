import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';
import 'package:mint_mobile/services/startup_route_override.dart';
import 'package:mint_mobile/services/startup_route_override_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseMintTestInitialRoute', () {
    test('reads a safe internal route from environment', () {
      expect(
        parseMintTestInitialRoute(
          arguments: const [],
          environment: const {mintTestInitialRouteKey: '/succession'},
        ),
        '/succession',
      );
    });

    test('reads iOS-style separate launch arguments', () {
      expect(
        parseMintTestInitialRoute(
          arguments: const ['-$mintTestInitialRouteKey', '/succession'],
          environment: const {},
        ),
        '/succession',
      );
    });

    test('reads inline launch arguments', () {
      expect(
        parseMintTestInitialRoute(
          arguments: const ['--$mintTestInitialRouteKey=/succession?case=p0'],
          environment: const {},
        ),
        '/succession?case=p0',
      );
    });

    test('rejects external URLs and malformed paths', () {
      for (final raw in const [
        'https://example.com',
        'mint://succession',
        '//succession',
        'succession',
        '/succession bad',
      ]) {
        expect(
          parseMintTestInitialRoute(
            arguments: [raw],
            environment: {mintTestInitialRouteKey: raw},
          ),
          isNull,
        );
      }
    });
  });

  group('parseMintTestPropertyValue', () {
    test('reads a positive integer from environment', () {
      expect(
        parseMintTestPropertyValue(
          arguments: const [],
          environment: const {mintTestPropertyValueKey: '1200000'},
        ),
        1200000,
      );
    });

    test('reads iOS-style separate launch arguments', () {
      expect(
        parseMintTestPropertyValue(
          arguments: const ['-$mintTestPropertyValueKey', '1200000'],
          environment: const {},
        ),
        1200000,
      );
    });

    test('rejects non-positive, non-numeric, and excessive values', () {
      for (final raw in const [
        '0',
        '-1',
        '12.5',
        'abc',
        '1000000001',
      ]) {
        expect(
          parseMintTestPropertyValue(
            arguments: [raw],
            environment: {mintTestPropertyValueKey: raw},
          ),
          isNull,
        );
      }
    });
  });

  group('parseMintTestRevenueAnnual', () {
    test('reads a positive annual revenue from environment', () {
      expect(
        parseMintTestRevenueAnnual(
          arguments: const [],
          environment: const {mintTestRevenueAnnualKey: '96000'},
        ),
        96000,
      );
    });

    test('reads iOS-style separate launch arguments', () {
      expect(
        parseMintTestRevenueAnnual(
          arguments: const ['-$mintTestRevenueAnnualKey', '96000'],
          environment: const {},
        ),
        96000,
      );
    });

    test('rejects non-positive, non-numeric, decimal, and excessive values',
        () {
      for (final raw in const [
        '0',
        '-1',
        '96000.50',
        'abc',
        '10000001',
      ]) {
        expect(
          parseMintTestRevenueAnnual(
            arguments: [raw],
            environment: {mintTestRevenueAnnualKey: raw},
          ),
          isNull,
        );
      }
    });
  });

  group('parseMintTestCanton', () {
    test('reads and normalizes a valid Swiss canton', () {
      expect(
        parseMintTestCanton(
          arguments: const [],
          environment: const {mintTestCantonKey: 'ge'},
        ),
        'GE',
      );
    });

    test('reads iOS-style separate launch arguments', () {
      expect(
        parseMintTestCanton(
          arguments: const ['-$mintTestCantonKey', 'VD'],
          environment: const {},
        ),
        'VD',
      );
    });

    test('rejects unknown or malformed canton values', () {
      for (final raw in const [
        '',
        'ZZ',
        'Geneva',
        'G3',
        'G E',
        '../GE',
      ]) {
        expect(
          parseMintTestCanton(
            arguments: [raw],
            environment: {mintTestCantonKey: raw},
          ),
          isNull,
        );
      }
    });
  });

  group('parseMintTestPropertyStale', () {
    test('reads true-like values from environment and launch arguments', () {
      for (final raw in const ['true', '1', 'yes', 'on']) {
        expect(
          parseMintTestPropertyStale(
            arguments: const [],
            environment: {mintTestPropertyStaleKey: raw},
          ),
          isTrue,
        );
      }

      expect(
        parseMintTestPropertyStale(
          arguments: const ['-$mintTestPropertyStaleKey', 'true'],
          environment: const {},
        ),
        isTrue,
      );
    });

    test('rejects absent and false-like values', () {
      for (final raw in const ['false', '0', 'no', 'off', '']) {
        expect(
          parseMintTestPropertyStale(
            arguments: [raw],
            environment: {mintTestPropertyStaleKey: raw},
          ),
          isFalse,
        );
      }
      expect(
        parseMintTestPropertyStale(
          arguments: const [],
          environment: const {},
        ),
        isFalse,
      );
    });
  });

  group('mintRuntimeProofStalePropertyValueDate', () {
    test('makes propertyMarketValue stale enough to require refresh', () {
      final now = DateTime.utc(2026, 7, 4);
      final staleDate = mintRuntimeProofStalePropertyValueDate(now);
      final category = FreshnessDecayService
          .kFieldFreshnessCategory['patrimoine.propertyMarketValue'];
      final fact = BiographyFact(
        id: 'runtime-proof:propertyMarketValue',
        factType: FactType.salary,
        fieldPath: 'patrimoine.propertyMarketValue',
        value: '1200000',
        source: FactSource.userInput,
        sourceDate: staleDate,
        createdAt: staleDate,
        updatedAt: staleDate,
        freshnessCategory: category!,
      );

      expect(category, 'annual');
      expect(staleDate.isBefore(now.subtract(const Duration(days: 13 * 30))),
          isTrue);
      expect(fact.fieldPath, 'patrimoine.propertyMarketValue');
      expect(fact.sourceDate, staleDate);
      expect(FreshnessDecayService.needsRefresh(fact, now), isTrue);
    });
  });

  group('parseMintTestTransmitPropertyFixture', () {
    test('reads a safe fixture name from environment and launch arguments', () {
      expect(
        parseMintTestTransmitPropertyFixture(
          arguments: const [],
          environment: const {
            mintTestTransmitPropertyFixtureKey: 'raiffeisen_status',
          },
        ),
        'raiffeisen_status',
      );
      expect(
        parseMintTestTransmitPropertyFixture(
          arguments: const [
            '-$mintTestTransmitPropertyFixtureKey',
            'article:raiffeisen-status',
          ],
          environment: const {},
        ),
        'article:raiffeisen-status',
      );
    });

    test('rejects empty or unsafe fixture names', () {
      for (final raw in const [
        '',
        '../fixture',
        'fixture name',
        'fixture.json',
      ]) {
        expect(
          parseMintTestTransmitPropertyFixture(
            arguments: [raw],
            environment: {mintTestTransmitPropertyFixtureKey: raw},
          ),
          isNull,
        );
      }
    });
  });

  group('parseMintTestReportFixture', () {
    test('reads a safe report fixture name from environment and launch args',
        () {
      expect(
        parseMintTestReportFixture(
          arguments: const [],
          environment: const {
            mintTestReportFixtureKey: 'first_salary_tax_vd',
          },
        ),
        'first_salary_tax_vd',
      );
      expect(
        parseMintTestReportFixture(
          arguments: const [
            '-$mintTestReportFixtureKey',
            'case:first-salary-tax',
          ],
          environment: const {},
        ),
        'case:first-salary-tax',
      );
    });

    test('rejects empty or unsafe report fixture names', () {
      for (final raw in const [
        '',
        '../fixture',
        'fixture name',
        'fixture.json',
      ]) {
        expect(
          parseMintTestReportFixture(
            arguments: [raw],
            environment: {mintTestReportFixtureKey: raw},
          ),
          isNull,
        );
      }
    });
  });

  group('parseMintRuntimeProofSemanticsEnabled', () {
    test('reads true-like values from environment and launch arguments', () {
      for (final raw in const ['true', '1', 'yes', 'on']) {
        expect(
          parseMintRuntimeProofSemanticsEnabled(
            arguments: const [],
            environment: {mintRuntimeProofSemanticsKey: raw},
          ),
          isTrue,
        );
      }

      expect(
        parseMintRuntimeProofSemanticsEnabled(
          arguments: const ['--$mintRuntimeProofSemanticsKey=true'],
          environment: const {},
        ),
        isTrue,
      );
      expect(
        parseMintRuntimeProofSemanticsEnabled(
          arguments: const ['-$mintRuntimeProofSemanticsKey', 'true'],
          environment: const {},
        ),
        isTrue,
      );
    });

    test('rejects absent or false-like values', () {
      for (final raw in const ['false', '0', 'no', 'off', '']) {
        expect(
          parseMintRuntimeProofSemanticsEnabled(
            arguments: [raw],
            environment: {mintRuntimeProofSemanticsKey: raw},
          ),
          isFalse,
        );
      }
      expect(
        parseMintRuntimeProofSemanticsEnabled(
          arguments: const [],
          environment: const {},
        ),
        isFalse,
      );
    });
  });

  group('runtime proof input gate', () {
    test('does not enable seed inputs without an explicit runtime flag',
        () async {
      expect(await mintRuntimeProofInputsEnabledForTest(), isFalse);
    });
  });
}
