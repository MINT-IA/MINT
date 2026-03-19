import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/annual_refresh_service.dart';

void main() {
  // ── RefreshQuestion data class ──────────────────────────────────

  group('RefreshQuestion', () {
    test('constructs with required fields only', () {
      const q = RefreshQuestion(
        key: 'test',
        label: 'Test label',
        type: RefreshQuestionType.text,
      );
      expect(q.key, 'test');
      expect(q.label, 'Test label');
      expect(q.type, RefreshQuestionType.text);
      expect(q.currentValue, isNull);
      expect(q.options, isEmpty);
      expect(q.helpText, isNull);
      expect(q.sliderMin, isNull);
    });

    test('constructs with all optional fields', () {
      const q = RefreshQuestion(
        key: 'salary',
        label: 'Salaire',
        type: RefreshQuestionType.slider,
        helpText: 'Aide',
        currentValue: '5000',
        options: ['a', 'b'],
        sliderMin: 0,
        sliderMax: 30000,
        sliderDivisions: 300,
      );
      expect(q.helpText, 'Aide');
      expect(q.currentValue, '5000');
      expect(q.options, ['a', 'b']);
      expect(q.sliderMin, 0);
      expect(q.sliderMax, 30000);
      expect(q.sliderDivisions, 300);
    });
  });

  // ── AnnualRefreshResult data class ──────────────────────────────

  group('AnnualRefreshResult', () {
    test('contains disclaimer and sources', () {
      const result = AnnualRefreshResult(
        refreshNeeded: true,
        monthsSinceUpdate: 14,
        questions: [],
        disclaimer: 'Test disclaimer',
        sources: ['LPP art. 8'],
      );
      expect(result.refreshNeeded, isTrue);
      expect(result.monthsSinceUpdate, 14);
      expect(result.disclaimer, 'Test disclaimer');
      expect(result.sources, contains('LPP art. 8'));
    });
  });

  // ── generateRefreshQuestions ─────────────────────────────────────

  group('generateRefreshQuestions', () {
    test('generates exactly 7 questions', () {
      final result = AnnualRefreshService.generateRefreshQuestions();
      expect(result.questions.length, 7);
    });

    test('returns refreshNeeded=true when lastMajorUpdate is null (defaults to >400 days ago)',
        () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        lastMajorUpdate: null,
      );
      expect(result.refreshNeeded, isTrue);
    });

    test('returns refreshNeeded=false when updated recently', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        lastMajorUpdate: DateTime.now().subtract(const Duration(days: 30)),
      );
      expect(result.refreshNeeded, isFalse);
    });

    test('returns refreshNeeded=true when updated > 335 days ago', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        lastMajorUpdate: DateTime.now().subtract(const Duration(days: 400)),
      );
      expect(result.refreshNeeded, isTrue);
    });

    test('pre-fills salary question with currentSalary', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        currentSalary: 8500,
      );
      final salaryQ = result.questions.firstWhere((q) => q.key == 'salary');
      expect(salaryQ.currentValue, '8500');
      expect(salaryQ.type, RefreshQuestionType.slider);
      expect(salaryQ.sliderMin, 0);
      expect(salaryQ.sliderMax, 30000);
    });

    test('pre-fills LPP question with currentLpp', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        currentLpp: 70377,
      );
      final lppQ =
          result.questions.firstWhere((q) => q.key == 'lpp_balance');
      expect(lppQ.currentValue, '70377');
      expect(lppQ.type, RefreshQuestionType.text);
    });

    test('pre-fills 3a question with current3a', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        current3a: 32000,
      );
      final q3a =
          result.questions.firstWhere((q) => q.key == 'three_a_balance');
      expect(q3a.currentValue, '32000');
    });

    test('pre-fills risk tolerance question with riskProfile', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        riskProfile: 'dynamique',
      );
      final riskQ =
          result.questions.firstWhere((q) => q.key == 'risk_tolerance');
      expect(riskQ.currentValue, 'dynamique');
      expect(riskQ.options, contains('dynamique'));
    });

    test('family_change question has 4 options including aucun', () {
      final result = AnnualRefreshService.generateRefreshQuestions();
      final famQ =
          result.questions.firstWhere((q) => q.key == 'family_change');
      expect(famQ.type, RefreshQuestionType.select);
      expect(famQ.options, ['aucun', 'mariage', 'naissance', 'divorce']);
      expect(famQ.currentValue, 'aucun');
    });

    test('disclaimer mentions LSFin and educatif', () {
      final result = AnnualRefreshService.generateRefreshQuestions();
      expect(result.disclaimer, contains('educatif'));
      expect(result.disclaimer, contains('LSFin'));
    });

    test('sources reference LPP, LAVS, OPP3', () {
      final result = AnnualRefreshService.generateRefreshQuestions();
      expect(result.sources.any((s) => s.contains('LPP')), isTrue);
      expect(result.sources.any((s) => s.contains('LAVS')), isTrue);
      expect(result.sources.any((s) => s.contains('OPP3')), isTrue);
    });

    test('golden profile Julien — salary 122207/12 monthly, LPP 70377, 3a 32000',
        () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        currentSalary: 122207 / 12,
        currentLpp: 70377,
        current3a: 32000,
        riskProfile: 'modere',
      );
      expect(result.questions.length, 7);
      final salaryQ = result.questions.firstWhere((q) => q.key == 'salary');
      expect(salaryQ.currentValue, '10184'); // 122207/12 truncated
    });

    test('all question keys are unique', () {
      final result = AnnualRefreshService.generateRefreshQuestions();
      final keys = result.questions.map((q) => q.key).toSet();
      expect(keys.length, result.questions.length);
    });

    test('monthsSinceUpdate is positive for past dates', () {
      final result = AnnualRefreshService.generateRefreshQuestions(
        lastMajorUpdate: DateTime.now().subtract(const Duration(days: 730)),
      );
      expect(result.monthsSinceUpdate, greaterThanOrEqualTo(23));
    });
  });

  // ── checkRefreshNeeded ──────────────────────────────────────────

  group('checkRefreshNeeded', () {
    test('returns false for today', () {
      expect(AnnualRefreshService.checkRefreshNeeded(DateTime.now()), isFalse);
    });

    test('returns false at exactly 335 days', () {
      final date = DateTime.now().subtract(const Duration(days: 335));
      expect(AnnualRefreshService.checkRefreshNeeded(date), isFalse);
    });

    test('returns true at 336 days', () {
      final date = DateTime.now().subtract(const Duration(days: 336));
      expect(AnnualRefreshService.checkRefreshNeeded(date), isTrue);
    });
  });

  // ── monthsSince ─────────────────────────────────────────────────

  group('monthsSince', () {
    test('returns 0 for current month', () {
      expect(AnnualRefreshService.monthsSince(DateTime.now()), 0);
    });

    test('returns 12 for exactly one year ago', () {
      final oneYearAgo = DateTime(
        DateTime.now().year - 1,
        DateTime.now().month,
        DateTime.now().day,
      );
      expect(AnnualRefreshService.monthsSince(oneYearAgo), 12);
    });
  });
}
