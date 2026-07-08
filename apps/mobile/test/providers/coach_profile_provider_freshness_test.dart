import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/data_quest/revenue_data_quest_planner.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('confirmFreshness advances timestamp and survives provider reload',
      () async {
    final now = DateTime(2026, 4, 6, 9, 30);
    final stale = now.subtract(const Duration(days: 900));
    final answers = {
      'q_gross_salary_annual': 96000,
      'q_canton': 'GE',
      'q_birth_year': 1990,
      '_coach_data_timestamps': {
        'salaireBrutMensuel': stale.toIso8601String(),
        'canton': now.toIso8601String(),
        'age': stale.toIso8601String(),
      },
    };

    await ReportPersistenceService.saveAnswers(answers);
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    final before = RevenueDataQuestPlanner.plan(
      profile: provider.profile,
      answers: await ReportPersistenceService.loadAnswers(),
      now: now,
    );
    expect(before.single.mode, AskMode.reconfirm);

    await provider.confirmFreshness(
      answerKey: 'q_gross_salary_annual',
      fieldPath: 'salaireBrutMensuel',
      now: now,
    );

    final persisted = await ReportPersistenceService.loadAnswers();
    final timestamps = persisted['_coach_data_timestamps'] as Map;
    expect(timestamps['salaireBrutMensuel'], now.toIso8601String());

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    final after = RevenueDataQuestPlanner.plan(
      profile: reloaded.profile,
      answers: await ReportPersistenceService.loadAnswers(),
      now: now,
    );

    expect(
        after.where((ask) => ask.fieldPath == 'salaireBrutMensuel'), isEmpty);
    expect(reloaded.profile?.revenuBrutAnnuel, 96000);
  });

  test('confirmFreshness does not mutate gross salary when bonus exists',
      () async {
    final now = DateTime(2026, 4, 6, 9, 30);
    final stale = now.subtract(const Duration(days: 900));
    final answers = {
      'q_gross_salary_annual': 96000,
      'q_annual_bonus': 10000,
      'q_canton': 'GE',
      'q_birth_year': 1990,
      '_coach_data_timestamps': {
        'salaireBrutMensuel': stale.toIso8601String(),
        'canton': now.toIso8601String(),
        'age': now.toIso8601String(),
      },
    };

    await ReportPersistenceService.saveAnswers(answers);
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    expect(provider.profile?.revenuBrutAnnuel, 106000);

    await provider.confirmFreshness(
      answerKey: 'q_gross_salary_annual',
      fieldPath: 'salaireBrutMensuel',
      now: now,
    );

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_gross_salary_annual'], 96000);
    expect(persisted['q_annual_bonus'], 10000);

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.profile?.salaireBrutMensuel, 8000);
    expect(reloaded.profile?.revenuBrutAnnuel, 106000);
  });
}
