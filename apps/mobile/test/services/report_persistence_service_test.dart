import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive unit tests for ReportPersistenceService
///
/// Tests cover:
/// - Wizard answers serialization/deserialization (save/load)
/// - Wizard completion flag management
/// - Letters history persistence
/// - Clear/reset functionality
/// - Edge cases: empty data, null fields, corrupted JSON
/// - Storage key isolation (no cross-contamination)
void main() {
  // Reset SharedPreferences before each test to ensure isolation
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Wizard Answers — Save & Load
  // ═══════════════════════════════════════════════════════════════════════

  group('ReportPersistenceService.saveAnswers / loadAnswers', () {
    test('saves and loads a simple answers map', () async {
      final answers = <String, dynamic>{
        'q_canton': 'VD',
        'q_birth_year': 1990,
        'q_has_3a': 'yes',
      };

      await ReportPersistenceService.saveAnswers(answers);
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded, equals(answers));
      expect(loaded['q_canton'], 'VD');
      expect(loaded['q_birth_year'], 1990);
      expect(loaded['q_has_3a'], 'yes');
    });

    test('returns empty map when nothing has been saved', () async {
      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded, isEmpty);
    });

    test('overwrites previous answers on re-save', () async {
      await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
      await ReportPersistenceService.saveAnswers(
          {'q_canton': 'GE', 'q_birth_year': 1985});

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded['q_canton'], 'GE');
      expect(loaded['q_birth_year'], 1985);
      expect(loaded.length, 2);
    });

    test('handles empty answers map', () async {
      await ReportPersistenceService.saveAnswers({});
      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded, isEmpty);
    });

    test('handles answers with null values', () async {
      final answers = <String, dynamic>{
        'q_canton': null,
        'q_birth_year': 1990,
      };

      await ReportPersistenceService.saveAnswers(answers);
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded.containsKey('q_canton'), true);
      expect(loaded['q_canton'], isNull);
      expect(loaded['q_birth_year'], 1990);
    });

    test('handles answers with nested map values', () async {
      final answers = <String, dynamic>{
        'q_canton': 'VD',
        'q_nested': {'sub_key': 'sub_value', 'amount': 1234.56},
      };

      await ReportPersistenceService.saveAnswers(answers);
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded['q_nested'], isA<Map>());
      expect((loaded['q_nested'] as Map)['sub_key'], 'sub_value');
      expect((loaded['q_nested'] as Map)['amount'], 1234.56);
    });

    test('handles answers with list values', () async {
      final answers = <String, dynamic>{
        'q_3a_providers': ['bank', 'fintech'],
        'q_canton': 'ZH',
      };

      await ReportPersistenceService.saveAnswers(answers);
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded['q_3a_providers'], isA<List>());
      expect((loaded['q_3a_providers'] as List).length, 2);
      expect((loaded['q_3a_providers'] as List).first, 'bank');
    });

    test('handles numeric string values correctly', () async {
      final answers = <String, dynamic>{
        'q_net_income_period_chf': 5000.50,
        'q_birth_year': 1990,
        'q_savings_monthly': 0,
      };

      await ReportPersistenceService.saveAnswers(answers);
      final loaded = await ReportPersistenceService.loadAnswers();

      expect(loaded['q_net_income_period_chf'], 5000.50);
      expect(loaded['q_birth_year'], 1990);
      expect(loaded['q_savings_monthly'], 0);
    });

    test('returns empty map when stored JSON is corrupted', () async {
      // Manually inject invalid JSON into SharedPreferences
      SharedPreferences.setMockInitialValues({
        'wizard_answers_v2': 'this is not valid json{{{',
      });

      final loaded = await ReportPersistenceService.loadAnswers();
      expect(loaded, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Wizard Completion Flag
  // ═══════════════════════════════════════════════════════════════════════

  group('ReportPersistenceService.setCompleted / isCompleted', () {
    test('defaults to false when not set', () async {
      final completed = await ReportPersistenceService.isCompleted();
      expect(completed, false);
    });

    test('returns true after setting completed to true', () async {
      await ReportPersistenceService.setCompleted(true);
      final completed = await ReportPersistenceService.isCompleted();
      expect(completed, true);
    });

    test('returns false after setting completed to false', () async {
      await ReportPersistenceService.setCompleted(true);
      await ReportPersistenceService.setCompleted(false);
      final completed = await ReportPersistenceService.isCompleted();
      expect(completed, false);
    });

    test('toggle completed flag multiple times', () async {
      await ReportPersistenceService.setCompleted(true);
      expect(await ReportPersistenceService.isCompleted(), true);

      await ReportPersistenceService.setCompleted(false);
      expect(await ReportPersistenceService.isCompleted(), false);

      await ReportPersistenceService.setCompleted(true);
      expect(await ReportPersistenceService.isCompleted(), true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Mini-Onboarding Experiment Persistence
  // ═══════════════════════════════════════════════════════════════════════

  group('Mini-onboarding experiment persistence', () {
    test('getOrCreateMiniOnboardingVariant returns a valid variant', () async {
      final variant =
          await ReportPersistenceService.getOrCreateMiniOnboardingVariant();
      expect(['control', 'challenge'], contains(variant));
    });

    test('getOrCreateMiniOnboardingVariant persists the same variant',
        () async {
      final variant1 =
          await ReportPersistenceService.getOrCreateMiniOnboardingVariant();
      final variant2 =
          await ReportPersistenceService.getOrCreateMiniOnboardingVariant();
      expect(variant2, equals(variant1));
    });

    test('mini-onboarding exposure tracked defaults to false', () async {
      expect(
        await ReportPersistenceService.isMiniOnboardingExposureTracked(),
        isFalse,
      );
    });

    test('mini-onboarding exposure tracking flag can be set', () async {
      await ReportPersistenceService.setMiniOnboardingExposureTracked(true);
      expect(
        await ReportPersistenceService.isMiniOnboardingExposureTracked(),
        isTrue,
      );
    });

    test('mini-onboarding metrics default values are loaded', () async {
      final metrics =
          await ReportPersistenceService.loadMiniOnboardingMetrics('control');
      expect(metrics['started'], 0);
      expect(metrics['completed'], 0);
      expect(metrics['step_1'], 0);
    });

    test('mini-onboarding metrics can be incremented per variant', () async {
      await ReportPersistenceService.incrementMiniOnboardingMetric(
        'challenge',
        'started',
      );
      await ReportPersistenceService.incrementMiniOnboardingMetric(
        'challenge',
        'started',
      );
      await ReportPersistenceService.incrementMiniOnboardingMetric(
        'challenge',
        'completed',
      );
      final metrics =
          await ReportPersistenceService.loadMiniOnboardingMetrics('challenge');
      expect(metrics['started'], 2);
      expect(metrics['completed'], 1);

      final control =
          await ReportPersistenceService.loadMiniOnboardingMetrics('control');
      expect(control['started'], 0);
    });

    test('mini-onboarding metrics clear resets counters', () async {
      await ReportPersistenceService.incrementMiniOnboardingMetric(
        'control',
        'started',
      );
      await ReportPersistenceService.clearMiniOnboardingMetrics();
      final metrics =
          await ReportPersistenceService.loadMiniOnboardingMetrics('control');
      expect(metrics['started'], 0);
    });

    test('cohort metrics can be incremented and exported to CSV', () async {
      await ReportPersistenceService.incrementMiniOnboardingCohortMetric(
        'control',
        'stress_budget|emp_employee|inc_mid',
        'started',
      );
      await ReportPersistenceService.incrementMiniOnboardingCohortMetric(
        'control',
        'stress_budget|emp_employee|inc_mid',
        'completed',
      );
      await ReportPersistenceService.incrementMiniOnboardingCohortMetric(
        'challenge',
        'stress_tax|emp_independent|inc_high',
        'started',
        by: 2,
      );

      final cohorts =
          await ReportPersistenceService.loadMiniOnboardingCohortMetrics();
      expect(cohorts['control'], isNotNull);
      expect(
        cohorts['control']['stress_budget|emp_employee|inc_mid']['started'],
        1,
      );
      expect(
        cohorts['control']['stress_budget|emp_employee|inc_mid']['completed'],
        1,
      );
      expect(
        cohorts['challenge']['stress_tax|emp_independent|inc_high']['started'],
        2,
      );

      final csv =
          await ReportPersistenceService.exportMiniOnboardingCohortCsv();
      expect(csv, contains('variant,profile_bucket,started,completed'));
      expect(csv, contains('control,stress_budget|emp_employee|inc_mid,1,1'));
      expect(
          csv, contains('challenge,stress_tax|emp_independent|inc_high,2,0'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Onboarding 30-Day Plan Persistence
  // ═══════════════════════════════════════════════════════════════════════

  group('Onboarding 30-day plan persistence', () {
    test('starts empty then marks started with context', () async {
      final before = await ReportPersistenceService.loadOnboarding30PlanState();
      expect(before, isEmpty);

      await ReportPersistenceService.markOnboarding30PlanStarted(
        stressChoice: 'budget',
        mainGoal: 'retirement',
      );

      final state = await ReportPersistenceService.loadOnboarding30PlanState();
      expect(state['started_at'], isNotNull);
      expect(state['stress_choice'], 'budget');
      expect(state['main_goal'], 'retirement');
      expect(state['completed'], false);
      expect(state['opened_routes'], isA<List>());
    });

    test('marks routes opened and keeps uniqueness + last route', () async {
      await ReportPersistenceService.markOnboarding30PlanStarted();
      await ReportPersistenceService.markOnboarding30PlanRouteOpened('/budget');
      await ReportPersistenceService.markOnboarding30PlanRouteOpened('/budget');
      await ReportPersistenceService.markOnboarding30PlanRouteOpened(
          '/coach/agir');

      final state = await ReportPersistenceService.loadOnboarding30PlanState();
      final opened = List<String>.from(state['opened_routes'] as List);
      expect(opened.length, 2);
      expect(opened, contains('/budget'));
      expect(opened, contains('/coach/agir'));
      expect(state['last_route'], '/coach/agir');
    });

    test('completion flag is persisted and can be unset', () async {
      await ReportPersistenceService.markOnboarding30PlanStarted();
      await ReportPersistenceService.setOnboarding30PlanCompleted(true);
      var state = await ReportPersistenceService.loadOnboarding30PlanState();
      expect(state['completed'], true);
      expect(state['completed_at'], isNotNull);

      await ReportPersistenceService.setOnboarding30PlanCompleted(false);
      state = await ReportPersistenceService.loadOnboarding30PlanState();
      expect(state['completed'], false);
      expect(state.containsKey('completed_at'), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Letters History
  // ═══════════════════════════════════════════════════════════════════════

  group('ReportPersistenceService.saveLettersHistory / loadLettersHistory', () {
    test('saves and loads letters history', () async {
      final letters = [
        {'title': 'Rachat LPP', 'date': '2025-01-15', 'type': 'LPP_BUYBACK'},
        {'title': 'Demande 3a', 'date': '2025-02-01', 'type': '3A_OPEN'},
      ];

      await ReportPersistenceService.saveLettersHistory(letters);
      final loaded = await ReportPersistenceService.loadLettersHistory();

      expect(loaded.length, 2);
      expect(loaded[0]['title'], 'Rachat LPP');
      expect(loaded[1]['type'], '3A_OPEN');
    });

    test('returns empty list when nothing saved', () async {
      final loaded = await ReportPersistenceService.loadLettersHistory();
      expect(loaded, isEmpty);
    });

    test('handles empty letters list', () async {
      await ReportPersistenceService.saveLettersHistory([]);
      final loaded = await ReportPersistenceService.loadLettersHistory();
      expect(loaded, isEmpty);
    });

    test('returns empty list when stored JSON is corrupted', () async {
      SharedPreferences.setMockInitialValues({
        'generated_letters_history': '<<<corrupted>>>',
      });

      final loaded = await ReportPersistenceService.loadLettersHistory();
      expect(loaded, isEmpty);
    });

    test('preserves letter entries with compliance fields', () async {
      final letters = [
        {
          'title': 'Demande rachat LPP',
          'date': '2025-03-01',
          'type': 'LPP_BUYBACK',
          'disclaimer': 'Outil educatif - ne constitue pas un conseil',
          'sources': ['LPP art. 79b'],
        },
      ];

      await ReportPersistenceService.saveLettersHistory(letters);
      final loaded = await ReportPersistenceService.loadLettersHistory();

      expect(loaded[0]['disclaimer'], contains('educatif'));
      expect(loaded[0]['sources'], isA<List>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Clear / Reset
  // ═══════════════════════════════════════════════════════════════════════

  group('ReportPersistenceService.clear', () {
    test('clears all stored data', () async {
      // Populate all data
      await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
      await ReportPersistenceService.setCompleted(true);
      await ReportPersistenceService.saveLettersHistory([
        {'title': 'Test'}
      ]);

      // Verify data exists
      expect(await ReportPersistenceService.loadAnswers(), isNotEmpty);
      expect(await ReportPersistenceService.isCompleted(), true);
      expect(await ReportPersistenceService.loadLettersHistory(), isNotEmpty);

      // Clear all
      await ReportPersistenceService.clear();

      // Verify everything is cleared
      expect(await ReportPersistenceService.loadAnswers(), isEmpty);
      expect(await ReportPersistenceService.isCompleted(), false);
      expect(await ReportPersistenceService.loadLettersHistory(), isEmpty);
    });

    test('clear is idempotent (calling twice does not throw)', () async {
      await ReportPersistenceService.clear();
      await ReportPersistenceService.clear();

      expect(await ReportPersistenceService.loadAnswers(), isEmpty);
      expect(await ReportPersistenceService.isCompleted(), false);
    });

    test('clearDiagnostic resets mini-onboarding experiment keys', () async {
      await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await ReportPersistenceService.getOrCreateMiniOnboardingVariant();
      await ReportPersistenceService.setMiniOnboardingExposureTracked(true);
      await ReportPersistenceService.markOnboarding30PlanStarted();
      await ReportPersistenceService.markOnboarding30PlanRouteOpened('/budget');

      await ReportPersistenceService.clearDiagnostic();

      expect(await ReportPersistenceService.loadAnswers(), isEmpty);
      expect(
          await ReportPersistenceService.isMiniOnboardingCompleted(), isFalse);
      expect(
        await ReportPersistenceService.isMiniOnboardingExposureTracked(),
        isFalse,
      );
      final variant =
          await ReportPersistenceService.getOrCreateMiniOnboardingVariant();
      expect(['control', 'challenge'], contains(variant));
      final planState =
          await ReportPersistenceService.loadOnboarding30PlanState();
      expect(planState, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Storage Key Isolation
  // ═══════════════════════════════════════════════════════════════════════

  group('Storage key isolation', () {
    test('answers and letters use separate storage keys', () async {
      await ReportPersistenceService.saveAnswers({
        'q_canton': 'VD',
      });
      await ReportPersistenceService.saveLettersHistory([
        {'title': 'Lettre A'},
      ]);

      final answers = await ReportPersistenceService.loadAnswers();
      final letters = await ReportPersistenceService.loadLettersHistory();

      // Answers should not contain letters data
      expect(answers.containsKey('title'), false);
      expect(answers['q_canton'], 'VD');

      // Letters should not contain answers data
      expect(letters.length, 1);
      expect(letters[0]['title'], 'Lettre A');
    });

    test('completion flag is independent of answers', () async {
      await ReportPersistenceService.saveAnswers({'q_canton': 'GE'});
      // Completion flag should still default to false
      expect(await ReportPersistenceService.isCompleted(), false);

      await ReportPersistenceService.setCompleted(true);
      // Answers should still be intact
      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['q_canton'], 'GE');
    });
  });
}
