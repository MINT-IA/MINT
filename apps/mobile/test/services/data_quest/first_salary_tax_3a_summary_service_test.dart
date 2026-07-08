import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/data_quest/first_salary_tax_3a_summary_service.dart';
import 'package:mint_mobile/services/data_quest/revenue_data_quest_planner.dart';

CoachProfile _profileFrom(Map<String, dynamic> answers) {
  return CoachProfile.fromWizardAnswers(answers);
}

void main() {
  group('FirstSalaryTax3aSummaryService', () {
    final now = DateTime(2026, 4, 6);
    final stale = now.subtract(const Duration(days: 900));

    Map<String, dynamic> answers({
      Object? salary = 96000,
      Object? canton = 'GE',
      Object? birthYear = 2001,
      Object? pillar3aAnnual,
      DateTime? salaryUpdatedAt,
      DateTime? cantonUpdatedAt,
    }) {
      return {
        if (salary != null) 'q_gross_salary_annual': salary,
        if (canton != null) 'q_canton': canton,
        if (birthYear != null) 'q_birth_year': birthYear,
        if (pillar3aAnnual != null) 'q_3a_annual_contribution': pillar3aAnnual,
        '_coach_data_timestamps': {
          if (salaryUpdatedAt != null)
            'salaireBrutMensuel': salaryUpdatedAt.toIso8601String(),
          if (cantonUpdatedAt != null)
            'canton': cantonUpdatedAt.toIso8601String(),
        },
      };
    }

    test(
        'computes from canonical salary facts while keeping missing 3a explicit',
        () {
      final raw = answers();
      final summary = FirstSalaryTax3aSummaryService.build(
        profile: _profileFrom(raw),
        answers: raw,
        now: now,
      );

      expect(summary.canCompute, isTrue);
      expect(summary.salaryStatus, FirstSalaryFactStatus.known);
      expect(summary.cantonStatus, FirstSalaryFactStatus.known);
      expect(summary.ageStatus, FirstSalaryFactStatus.known);
      expect(summary.pillar3aContributionStatus, FirstSalaryFactStatus.missing);
      expect(summary.dataQuestAsks, isEmpty);
      expect(summary.result?.income.grossSalary, 96000);
    });

    test('marks stale salary as reconfirm without blocking partial rendering',
        () {
      final raw = answers(
        salaryUpdatedAt: stale,
        cantonUpdatedAt: now,
      );
      final summary = FirstSalaryTax3aSummaryService.build(
        profile: _profileFrom(raw),
        answers: raw,
        now: now,
      );

      expect(summary.canCompute, isTrue);
      expect(summary.salaryStatus, FirstSalaryFactStatus.stale);
      expect(summary.dataQuestAsks, hasLength(1));
      expect(summary.dataQuestAsks.single.mode, AskMode.reconfirm);
      expect(summary.dataQuestAsks.single.answerKey, 'q_gross_salary_annual');
      expect(summary.result?.income.grossSalary, 96000);
    });

    test('treats explicit 3a contribution as known user data', () {
      final raw = answers(pillar3aAnnual: 3000);
      final profile = _profileFrom(raw);
      final summary = FirstSalaryTax3aSummaryService.build(
        profile: profile,
        answers: raw,
        now: now,
      );

      expect(summary.pillar3aContributionStatus, FirstSalaryFactStatus.known);
      expect(summary.result?.current3aContribution, 3000);
      expect(
        summary.result?.remaining3aRoom,
        lessThan(summary.result!.pillar3aLimit),
      );
    });

    test('uses no-LPP 3a room for low salaries without pension certificate',
        () {
      final raw = answers(salary: 18000, pillar3aAnnual: 0);
      final summary = FirstSalaryTax3aSummaryService.build(
        profile: _profileFrom(raw),
        answers: raw,
        now: now,
      );

      expect(summary.canCompute, isTrue);
      expect(summary.result?.pillar3aLimit, 3600);
    });

    test('parses legacy yes/no pension answer without flipping it', () {
      final raw = answers(pillar3aAnnual: 0)..['q_has_pension_fund'] = 'yes';
      final summary = FirstSalaryTax3aSummaryService.build(
        profile: _profileFrom(raw),
        answers: raw,
        now: now,
      );

      expect(summary.result?.pillar3aLimit, 7258);
    });

    test(
        'uses visible screen values as estimates when canonical facts are empty',
        () {
      final summary = FirstSalaryTax3aSummaryService.build(
        profile: null,
        answers: const {},
        screenValues: const FirstSalaryTax3aScreenValues(
          grossAnnualSalary: 60000,
          canton: 'ZH',
          age: 25,
        ),
        now: now,
      );

      expect(summary.canCompute, isTrue);
      expect(summary.salaryStatus, FirstSalaryFactStatus.stale);
      expect(summary.cantonStatus, FirstSalaryFactStatus.stale);
      expect(summary.ageStatus, FirstSalaryFactStatus.stale);
      expect(summary.needsCoreData, isFalse);
      expect(summary.dataQuestAsks, isNotEmpty);
      expect(summary.result?.income.grossSalary, 60000);
    });
  });
}
