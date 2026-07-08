import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/data_quest/revenue_data_quest_planner.dart';

CoachProfile _profileFrom(Map<String, dynamic> answers) {
  return CoachProfile.fromWizardAnswers(answers);
}

void main() {
  final now = DateTime(2026, 4, 6);
  final stale = now.subtract(const Duration(days: 900));

  Map<String, dynamic> revenueAnswers({
    Object? salary = 96000,
    Object? annualBonus,
    Object? canton = 'GE',
    Object? birthYear = 1990,
    DateTime? salaryUpdatedAt,
    DateTime? cantonUpdatedAt,
    DateTime? ageUpdatedAt,
  }) {
    return {
      if (salary != null) 'q_gross_salary_annual': salary,
      if (annualBonus != null) 'q_annual_bonus': annualBonus,
      if (canton != null) 'q_canton': canton,
      if (birthYear != null) 'q_birth_year': birthYear,
      '_coach_data_timestamps': {
        if (salaryUpdatedAt != null)
          'salaireBrutMensuel': salaryUpdatedAt.toIso8601String(),
        if (cantonUpdatedAt != null)
          'canton': cantonUpdatedAt.toIso8601String(),
        if (ageUpdatedAt != null) 'age': ageUpdatedAt.toIso8601String(),
      },
    };
  }

  test('stale gross annual salary returns a reconfirm ask with prior value',
      () {
    final answers = revenueAnswers(
      salaryUpdatedAt: stale,
      cantonUpdatedAt: now,
      ageUpdatedAt: now,
    );

    final asks = RevenueDataQuestPlanner.plan(
      profile: _profileFrom(answers),
      answers: answers,
      now: now,
    );

    expect(asks, hasLength(1));
    expect(asks.single.mode, AskMode.reconfirm);
    expect(asks.single.answerKey, 'q_gross_salary_annual');
    expect(asks.single.fieldPath, 'salaireBrutMensuel');
    expect(asks.single.priorValue, 96000);
  });

  test('fresh known revenue fields do not produce asks', () {
    final answers = revenueAnswers(
      salaryUpdatedAt: now,
      cantonUpdatedAt: now,
      ageUpdatedAt: stale,
    );

    final asks = RevenueDataQuestPlanner.plan(
      profile: _profileFrom(answers),
      answers: answers,
      now: now,
    );

    expect(asks, isEmpty);
  });

  test('stale salary without answers uses gross salary, not bonus income', () {
    final answers = revenueAnswers(
      annualBonus: 10000,
      salaryUpdatedAt: stale,
      cantonUpdatedAt: now,
      ageUpdatedAt: now,
    );

    final asks = RevenueDataQuestPlanner.plan(
      profile: _profileFrom(answers),
      now: now,
    );

    expect(asks.single.mode, AskMode.reconfirm);
    expect(asks.single.answerKey, 'q_gross_salary_annual');
    expect(asks.single.priorValue, 96000);
    expect(_profileFrom(answers).revenuBrutAnnuel, 106000);
  });

  test('missing salary returns collect instead of reconfirm', () {
    final answers = revenueAnswers(
      salary: null,
      cantonUpdatedAt: now,
      ageUpdatedAt: now,
    );

    final asks = RevenueDataQuestPlanner.plan(
      profile: _profileFrom(answers),
      answers: answers,
      now: now,
    );

    expect(asks.first.mode, AskMode.collect);
    expect(asks.first.answerKey, 'q_gross_salary_annual');
    expect(asks.first.fieldPath, 'salaireBrutMensuel');
    expect(asks.first.priorValue, isNull);
  });

  test('birth year is static and never produces a reconfirm ask', () {
    final answers = revenueAnswers(
      salaryUpdatedAt: now,
      cantonUpdatedAt: now,
      ageUpdatedAt: stale,
    );

    final asks = RevenueDataQuestPlanner.plan(
      profile: _profileFrom(answers),
      answers: answers,
      now: now,
    );

    expect(
      asks.where(
          (ask) => ask.fieldPath == 'age' && ask.mode == AskMode.reconfirm),
      isEmpty,
    );
  });
}
