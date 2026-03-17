import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/annual_refresh_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // checkRefreshNeeded
  // ---------------------------------------------------------------------------
  group('AnnualRefreshService — checkRefreshNeeded', () {
    test('returns true when > 335 days old', () {
      final staleDate = DateTime.now().subtract(const Duration(days: 400));
      expect(AnnualRefreshService.checkRefreshNeeded(staleDate), isTrue);
    });

    test('returns false when exactly 335 days old', () {
      final borderDate = DateTime.now().subtract(const Duration(days: 335));
      expect(AnnualRefreshService.checkRefreshNeeded(borderDate), isFalse);
    });

    test('returns false when recently updated (30 days)', () {
      final recent = DateTime.now().subtract(const Duration(days: 30));
      expect(AnnualRefreshService.checkRefreshNeeded(recent), isFalse);
    });

    test('returns true when 12 months old (~365 days)', () {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      expect(AnnualRefreshService.checkRefreshNeeded(oneYearAgo), isTrue);
    });

    test('returns false when updated today', () {
      expect(AnnualRefreshService.checkRefreshNeeded(DateTime.now()), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // monthsSince
  // ---------------------------------------------------------------------------
  group('AnnualRefreshService — monthsSince', () {
    test('returns 0 for current month', () {
      final now = DateTime.now();
      expect(AnnualRefreshService.monthsSince(now), 0);
    });

    test('returns 12 for one year ago', () {
      final now = DateTime.now();
      final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
      expect(AnnualRefreshService.monthsSince(oneYearAgo), 12);
    });

    test('returns correct count for 6 months ago', () {
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
      expect(AnnualRefreshService.monthsSince(sixMonthsAgo), 6);
    });
  });

  // ---------------------------------------------------------------------------
  // generateRefreshQuestions
  // ---------------------------------------------------------------------------
  group('AnnualRefreshService — generateRefreshQuestions', () {
    test('generates exactly 7 questions', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        currentSalary: 8000,
        currentLpp: 70000,
        current3a: 32000,
      );
      expect(result.questions.length, 7);
    });

    test('refreshNeeded=true when lastMajorUpdate is null (defaults to 400 days ago)', () {
      final result = AnnualRefreshService.generateRefreshQuestions();
      expect(result.refreshNeeded, isTrue);
    });

    test('refreshNeeded=false when lastMajorUpdate is recent', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        lastMajorUpdate: DateTime.now().subtract(const Duration(days: 30)),
      );
      expect(result.refreshNeeded, isFalse);
    });

    test('pre-fills salary value correctly', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        currentSalary: 9500,
      );
      final salaryQ = result.questions.firstWhere((q) => q.key == 'salary');
      expect(salaryQ.currentValue, '9500');
      expect(salaryQ.type, RefreshQuestionType.slider);
      expect(salaryQ.sliderMin, 0);
      expect(salaryQ.sliderMax, 30000);
    });

    test('pre-fills LPP balance as text input', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        currentLpp: 45000,
      );
      final lppQ = result.questions.firstWhere((q) => q.key == 'lpp_balance');
      expect(lppQ.currentValue, '45000');
      expect(lppQ.type, RefreshQuestionType.text);
    });

    test('pre-fills 3a balance correctly', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        current3a: 14000,
      );
      final q3a =
          result.questions.firstWhere((q) => q.key == 'three_a_balance');
      expect(q3a.currentValue, '14000');
    });

    test('risk_tolerance uses provided profile', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        riskProfile: 'dynamique',
      );
      final riskQ =
          result.questions.firstWhere((q) => q.key == 'risk_tolerance');
      expect(riskQ.currentValue, 'dynamique');
      expect(riskQ.options, contains('conservateur'));
      expect(riskQ.options, contains('modere'));
      expect(riskQ.options, contains('dynamique'));
    });

    test('family_change has correct options', () {
      final result = AnnualRefreshService.generateRefreshQuestions();
      final familyQ =
          result.questions.firstWhere((q) => q.key == 'family_change');
      expect(familyQ.type, RefreshQuestionType.select);
      expect(familyQ.options, ['aucun', 'mariage', 'naissance', 'divorce']);
      expect(familyQ.currentValue, 'aucun');
    });

    test('disclaimer is present and compliant', () {
      final result = AnnualRefreshService.generateRefreshQuestions();
      expect(result.disclaimer, contains('educatif'));
      expect(result.disclaimer, contains('LSFin'));
      expect(result.disclaimer, isNot(contains('garanti')));
    });

    test('sources reference Swiss law articles', () {
      final result = AnnualRefreshService.generateRefreshQuestions();
      expect(result.sources, isNotEmpty);
      expect(result.sources.any((s) => s.contains('LPP')), isTrue);
      expect(result.sources.any((s) => s.contains('LAVS')), isTrue);
      expect(result.sources.any((s) => s.contains('OPP3')), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Question keys uniqueness
  // ---------------------------------------------------------------------------
  group('AnnualRefreshService — question integrity', () {
    test('all 7 questions have unique keys', () {
      final result = AnnualRefreshService.generateRefreshQuestions();
      final keys = result.questions.map((q) => q.key).toSet();
      expect(keys.length, 7);
    });

    test('all questions have non-empty labels', () {
      final result = AnnualRefreshService.generateRefreshQuestions();
      for (final q in result.questions) {
        expect(q.label, isNotEmpty, reason: 'Key ${q.key} has empty label');
      }
    });
  });
}
