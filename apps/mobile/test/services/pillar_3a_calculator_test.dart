import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/services/pillar_3a_calculator.dart';

/// Unit tests for Pillar3aCalculator
///
/// Tests the Swiss pillar 3a contribution limit calculations across
/// different employment statuses, years, and edge cases.
/// Legal basis: OPP3 art. 7
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Pillar3aCalculator.loadLimits();
  });

  tearDown(() {
    Pillar3aCalculator.clearCache();
  });

  group('Employee with LPP (fixed limit)', () {
    test('returns 7258 CHF for 2025', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );
      expect(result.limit, 7258.0);
      expect(result.isFixed, true);
      expect(result.canContribute, true);
    });

    test('returns 7258 CHF for 2026', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2026,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );
      expect(result.limit, 7258.0);
      expect(result.calculationType, 'fixed');
    });

    test('returns 7056 CHF for 2024', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2024,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );
      expect(result.limit, 7056.0);
    });

    test('returns 6883 CHF for 2023', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2023,
        employmentStatus: 'employee',
        has2ndPillar: true,
      );
      expect(result.limit, 6883.0);
    });

    test('limits increase year over year (2023 to 2026)', () {
      final r23 = Pillar3aCalculator.calculateLimit(
        year: 2023, employmentStatus: 'employee', has2ndPillar: true,
      );
      final r24 = Pillar3aCalculator.calculateLimit(
        year: 2024, employmentStatus: 'employee', has2ndPillar: true,
      );
      final r25 = Pillar3aCalculator.calculateLimit(
        year: 2025, employmentStatus: 'employee', has2ndPillar: true,
      );
      final r26 = Pillar3aCalculator.calculateLimit(
        year: 2026, employmentStatus: 'employee', has2ndPillar: true,
      );
      expect(r24.limit, greaterThan(r23.limit));
      expect(r25.limit, greaterThan(r24.limit));
      expect(r26.limit, greaterThanOrEqualTo(r25.limit));
    });
  });

  group('Self-employed without LPP (percentage-based)', () {
    test('calculates 20% of income below cap', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 80000,
      );
      // 20% of 80000 = 16000
      expect(result.limit, 16000.0);
      expect(result.isPercentageBased, true);
    });

    test('caps at 36288 CHF for high income (2025)', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 250000,
      );
      expect(result.limit, 36288.0);
    });

    test('boundary value: income exactly at cap threshold', () {
      // 36288 / 0.20 = 181440
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 181440,
      );
      expect(result.limit, 36288.0);
    });

    test('boundary value: income just below cap threshold', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 181439,
      );
      // 20% of 181439 = 36287.8
      expect(result.limit, closeTo(36287.8, 0.1));
      expect(result.limit, lessThan(36288.0));
    });

    test('returns max limit when income is null', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: null,
      );
      expect(result.limit, 36288.0);
    });

    test('returns max limit when income is zero', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 0,
      );
      expect(result.limit, 36288.0);
    });

    test('small income gives proportional limit', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 10000,
      );
      // 20% of 10000 = 2000
      expect(result.limit, 2000.0);
    });

    test('2024 has different cap (35280 CHF)', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2024,
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        netIncomeAVS: 250000,
      );
      expect(result.limit, 35280.0);
    });
  });

  group('Special statuses (student, retired, other)', () {
    test('student cannot contribute (limit = 0)', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'student',
        has2ndPillar: null,
      );
      expect(result.limit, 0.0);
      expect(result.canContribute, false);
    });

    test('retired cannot contribute (limit = 0)', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'retired',
        has2ndPillar: null,
      );
      expect(result.limit, 0.0);
      expect(result.canContribute, false);
    });

    test('other status has limit = 0', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'other',
        has2ndPillar: null,
      );
      expect(result.limit, 0.0);
      expect(result.canContribute, false);
    });

    test('student explanation mentions student status', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'student',
        has2ndPillar: null,
      );
      expect(result.explanation.toLowerCase(), contains('étudiant'));
    });

    test('retired explanation mentions retired status', () {
      final result = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: 'retired',
        has2ndPillar: null,
      );
      expect(result.explanation.toLowerCase(), contains('retraité'));
    });
  });

  group('Validation and error handling', () {
    test('throws Pillar3aException for unsupported year', () {
      expect(
        () => Pillar3aCalculator.calculateLimit(
          year: 2020,
          employmentStatus: 'employee',
          has2ndPillar: true,
        ),
        throwsA(isA<Pillar3aException>().having(
          (e) => e.type,
          'type',
          Pillar3aExceptionType.invalidYear,
        )),
      );
    });

    test('throws Pillar3aException for invalid status', () {
      expect(
        () => Pillar3aCalculator.calculateLimit(
          year: 2025,
          employmentStatus: 'freelancer',
          has2ndPillar: true,
        ),
        throwsA(isA<Pillar3aException>().having(
          (e) => e.type,
          'type',
          Pillar3aExceptionType.invalidStatus,
        )),
      );
    });

    test('Pillar3aException toString includes message', () {
      final exception = Pillar3aException(
        'test message',
        type: Pillar3aExceptionType.invalidYear,
      );
      expect(exception.toString(), contains('test message'));
      expect(exception.toString(), contains('invalidYear'));
    });
  });

  group('Cache behavior', () {
    test('cached result is identical reference', () {
      final r1 = Pillar3aCalculator.calculateLimit(
        year: 2025, employmentStatus: 'employee', has2ndPillar: true,
      );
      final r2 = Pillar3aCalculator.calculateLimit(
        year: 2025, employmentStatus: 'employee', has2ndPillar: true,
      );
      expect(identical(r1, r2), true);
    });

    test('useCache=false bypasses cache', () {
      final r1 = Pillar3aCalculator.calculateLimit(
        year: 2025, employmentStatus: 'employee', has2ndPillar: true,
      );
      final r2 = Pillar3aCalculator.calculateLimit(
        year: 2025, employmentStatus: 'employee', has2ndPillar: true,
        useCache: false,
      );
      expect(identical(r1, r2), false);
      expect(r1.limit, r2.limit);
    });

    test('different parameters produce different cache entries', () {
      final r1 = Pillar3aCalculator.calculateLimit(
        year: 2025, employmentStatus: 'employee', has2ndPillar: true,
      );
      final r2 = Pillar3aCalculator.calculateLimit(
        year: 2025, employmentStatus: 'employee', has2ndPillar: false,
        netIncomeAVS: 50000,
      );
      expect(r1.limit, isNot(equals(r2.limit)));
    });
  });

  group('getDynamic3aSubtitle', () {
    test('employee with LPP includes amount and year', () {
      final subtitle = Pillar3aCalculator.getDynamic3aSubtitle(
        employmentStatus: 'employee',
        has2ndPillar: true,
        year: 2025,
      );
      expect(subtitle, contains("7'258"));
      expect(subtitle, contains('2025'));
    });

    test('self-employed without LPP includes percentage', () {
      final subtitle = Pillar3aCalculator.getDynamic3aSubtitle(
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        year: 2025,
      );
      expect(subtitle, contains('20%'));
    });
  });

  group('getDetailedExplanation', () {
    test('contains profile section', () {
      final explanation = Pillar3aCalculator.getDetailedExplanation(
        employmentStatus: 'employee',
        has2ndPillar: true,
        year: 2025,
      );
      expect(explanation, contains('Ton profil'));
      expect(explanation, contains('Salarié'));
    });

    test('contains calculation section', () {
      final explanation = Pillar3aCalculator.getDetailedExplanation(
        employmentStatus: 'self_employed',
        has2ndPillar: false,
        year: 2025,
        netIncomeAVS: 80000,
      );
      expect(explanation, contains('Calcul'));
      expect(explanation, contains('20%'));
    });

    test('contains advice section for eligible profiles', () {
      final explanation = Pillar3aCalculator.getDetailedExplanation(
        employmentStatus: 'employee',
        has2ndPillar: true,
        year: 2025,
      );
      expect(explanation, contains('Conseil'));
    });
  });
}
