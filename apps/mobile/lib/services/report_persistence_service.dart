import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class ReportPersistenceService {
  static const String _wizardKey = 'wizard_answers_v2';
  static const String _completedKey = 'wizard_completed';

  /// Sauvegarde les réponses du wizard (incremental off)
  static Future<void> saveAnswers(Map<String, dynamic> answers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(answers);
    await prefs.setString(_wizardKey, jsonString);
  }

  /// Charge les réponses existantes
  static Future<Map<String, dynamic>> loadAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_wizardKey);

    if (jsonString == null) return {};

    try {
      return Map<String, dynamic>.from(json.decode(jsonString));
    } catch (e, stack) {
      dev.log('Failed to decode wizard answers',
          error: e, stackTrace: stack, name: 'Persistence');
      return {};
    }
  }

  /// Marque le wizard comme complété (pour ne pas le relancer au reboot)
  static Future<void> setCompleted(bool isCompleted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, isCompleted);
  }

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  // ═══════════════════════════════════════════════════════════
  //  MINI-ONBOARDING PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  static const String _miniOnboardingKey = 'mini_onboarding_completed';
  static const String _miniOnboardingVariantKey = 'mini_onboarding_variant_v1';
  static const String _miniOnboardingExposureTrackedKey =
      'mini_onboarding_exposure_tracked_v1';
  static const String _onboardingMetricsControlKey =
      'mini_onboarding_metrics_control_v1';
  static const String _onboardingMetricsChallengeKey =
      'mini_onboarding_metrics_challenge_v1';
  static const String _onboardingCohortMetricsKey =
      'mini_onboarding_cohort_metrics_v1';

  /// Marque le mini-onboarding comme complété (3 questions essentielles)
  static Future<void> setMiniOnboardingCompleted(bool isCompleted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_miniOnboardingKey, isCompleted);
  }

  /// Vérifie si le mini-onboarding a été complété
  static Future<bool> isMiniOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_miniOnboardingKey) ?? false;
  }

  /// Retourne une variante A/B persistente pour le mini-onboarding.
  /// Valeurs possibles: 'control' ou 'challenge'.
  static Future<String> getOrCreateMiniOnboardingVariant() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_miniOnboardingVariantKey);
    if (existing == 'control' || existing == 'challenge') {
      return existing!;
    }
    final variant = Random().nextBool() ? 'control' : 'challenge';
    await prefs.setString(_miniOnboardingVariantKey, variant);
    return variant;
  }

  /// Indique si l'exposition a l'experience onboarding a deja ete trackee.
  static Future<bool> isMiniOnboardingExposureTracked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_miniOnboardingExposureTrackedKey) ?? false;
  }

  /// Marque l'exposition a l'experience onboarding comme trackee.
  static Future<void> setMiniOnboardingExposureTracked(bool tracked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_miniOnboardingExposureTrackedKey, tracked);
  }

  static String _metricsKeyForVariant(String variant) {
    return variant == 'challenge'
        ? _onboardingMetricsChallengeKey
        : _onboardingMetricsControlKey;
  }

  static Map<String, int> _defaultOnboardingMetrics() {
    return const {
      'started': 0,
      'completed': 0,
      'abandoned': 0,
      'step_1': 0,
      'step_2': 0,
      'step_3': 0,
      'step_4': 0,
      'exit_prompt_shown': 0,
      'exit_prompt_stay': 0,
      'exit_prompt_leave': 0,
      'step2_aha_shown': 0,
      'step2_to_step3_after_aha': 0,
      'quick_pick_birth_year': 0,
      'quick_pick_income': 0,
      'duration_step_1_sum': 0,
      'duration_step_1_count': 0,
      'duration_step_2_sum': 0,
      'duration_step_2_count': 0,
      'duration_step_3_sum': 0,
      'duration_step_3_count': 0,
      'duration_step_4_sum': 0,
      'duration_step_4_count': 0,
    };
  }

  /// Charge les metriques onboarding d'une variante.
  static Future<Map<String, int>> loadMiniOnboardingMetrics(
    String variant,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _metricsKeyForVariant(variant);
    final jsonString = prefs.getString(key);
    if (jsonString == null) {
      return _defaultOnboardingMetrics();
    }
    try {
      final decoded = Map<String, dynamic>.from(json.decode(jsonString));
      final defaults = _defaultOnboardingMetrics();
      final merged = <String, int>{};
      for (final entry in defaults.entries) {
        final value = decoded[entry.key];
        merged[entry.key] = value is num ? value.toInt() : entry.value;
      }
      return merged;
    } catch (e, stack) {
      dev.log('Failed to decode onboarding metrics',
          error: e, stackTrace: stack, name: 'Persistence');
      return _defaultOnboardingMetrics();
    }
  }

  /// Incremente un compteur onboarding pour une variante.
  static Future<void> incrementMiniOnboardingMetric(
    String variant,
    String metricKey, {
    int by = 1,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _metricsKeyForVariant(variant);
    final current = Map<String, int>.from(
      await loadMiniOnboardingMetrics(variant),
    );
    current[metricKey] = (current[metricKey] ?? 0) + by;
    await prefs.setString(key, json.encode(current));
  }

  /// Efface les metriques onboarding (control + challenge).
  static Future<void> clearMiniOnboardingMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingMetricsControlKey);
    await prefs.remove(_onboardingMetricsChallengeKey);
    await prefs.remove(_onboardingCohortMetricsKey);
  }

  /// Charge les metriques cohortes onboarding.
  ///
  /// Structure:
  /// {
  ///   "control": {
  ///     "stress_budget|emp_employee|inc_mid": {"started": 3, "completed": 2}
  ///   },
  ///   "challenge": {...}
  /// }
  static Future<Map<String, dynamic>> loadMiniOnboardingCohortMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_onboardingCohortMetricsKey);
    if (jsonString == null) return {};
    try {
      return Map<String, dynamic>.from(json.decode(jsonString));
    } catch (e, stack) {
      dev.log('Failed to decode onboarding cohort metrics',
          error: e, stackTrace: stack, name: 'Persistence');
      return {};
    }
  }

  /// Incremente un metric de cohorte onboarding (started/completed/etc).
  static Future<void> incrementMiniOnboardingCohortMetric(
    String variant,
    String profileBucket,
    String metricKey, {
    int by = 1,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final root = Map<String, dynamic>.from(
      await loadMiniOnboardingCohortMetrics(),
    );

    final variantMap = Map<String, dynamic>.from(
      (root[variant] as Map?) ?? const {},
    );
    final bucketMap = Map<String, dynamic>.from(
      (variantMap[profileBucket] as Map?) ?? const {},
    );
    final current = (bucketMap[metricKey] as num?)?.toInt() ?? 0;
    bucketMap[metricKey] = current + by;
    variantMap[profileBucket] = bucketMap;
    root[variant] = variantMap;

    await prefs.setString(_onboardingCohortMetricsKey, json.encode(root));
  }

  /// Export CSV des cohortes A/B avec completion par profil.
  static Future<String> exportMiniOnboardingCohortCsv() async {
    final root = await loadMiniOnboardingCohortMetrics();
    final buffer = StringBuffer();
    buffer.writeln(
      'variant,profile_bucket,started,completed,completion_rate_pct',
    );

    for (final variantEntry in root.entries) {
      final variant = variantEntry.key;
      final variantMap = variantEntry.value;
      if (variantMap is! Map) continue;
      for (final bucketEntry in variantMap.entries) {
        final bucket = bucketEntry.key;
        final bucketMap = bucketEntry.value;
        if (bucketMap is! Map) continue;
        final started = (bucketMap['started'] as num?)?.toInt() ?? 0;
        final completed = (bucketMap['completed'] as num?)?.toInt() ?? 0;
        final rate = started <= 0 ? 0.0 : (completed / started) * 100;
        buffer.writeln(
          '$variant,$bucket,$started,$completed,${rate.toStringAsFixed(1)}',
        );
      }
    }

    return buffer.toString();
  }

  static const String _lettersKey = 'generated_letters_history';

  static Future<void> saveLettersHistory(
      List<Map<String, dynamic>> letters) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(letters);
    await prefs.setString(_lettersKey, jsonString);
  }

  static Future<List<Map<String, dynamic>>> loadLettersHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_lettersKey);
    if (jsonString == null) return [];
    try {
      return List<Map<String, dynamic>>.from(json.decode(jsonString));
    } catch (e, stack) {
      dev.log('Failed to decode letters history',
          error: e, stackTrace: stack, name: 'Persistence');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  PLANNED CONTRIBUTIONS PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  static const String _contributionsKey = 'planned_contributions_v1';

  /// Sauvegarde les versements planifiés (JSON list)
  static Future<void> saveContributions(
      List<Map<String, dynamic>> contributions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contributionsKey, json.encode(contributions));
  }

  /// Charge les versements planifiés
  static Future<List<Map<String, dynamic>>> loadContributions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_contributionsKey);
    if (jsonString == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (json.decode(jsonString) as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    } catch (e, stack) {
      dev.log('Failed to decode contributions',
          error: e, stackTrace: stack, name: 'Persistence');
      return [];
    }
  }

  /// Vérifie si des contributions ont été personnalisées
  static Future<bool> hasCustomContributions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_contributionsKey);
  }

  // ═══════════════════════════════════════════════════════════
  //  CHECK-INS PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  static const String _checkInsKey = 'monthly_checkins_v1';

  /// Sauvegarde l'historique des check-ins (JSON list)
  static Future<void> saveCheckIns(List<Map<String, dynamic>> checkIns) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_checkInsKey, json.encode(checkIns));
  }

  /// Charge l'historique des check-ins
  static Future<List<Map<String, dynamic>>> loadCheckIns() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_checkInsKey);
    if (jsonString == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (json.decode(jsonString) as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    } catch (e, stack) {
      dev.log('Failed to decode check-ins',
          error: e, stackTrace: stack, name: 'Persistence');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SCORE HISTORY PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  static const String _lastScoreKey = 'last_fitness_score_v1';
  static const String _lastScoreMonthKey = 'last_fitness_score_month_v1';
  static const String _scoreHistoryKey = 'score_history_v1';

  /// Sauvegarde le score du mois en cours pour comparer au suivant.
  /// Ajoute egalement le score a l'historique mensuel.
  static Future<void> saveLastScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    await prefs.setInt(_lastScoreKey, score);
    await prefs.setString(_lastScoreMonthKey, monthKey);
    // Ajouter automatiquement a l'historique
    await saveScoreToHistory(score);
  }

  /// Charge le dernier score enregistre (null si premier mois).
  static Future<int?> loadLastScore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMonth = prefs.getString(_lastScoreMonthKey);
    if (savedMonth == null) return null;
    return prefs.getInt(_lastScoreKey);
  }

  /// Ajoute un score a l'historique mensuel.
  /// Stocke au max 24 entrees (supprime les plus anciennes si > 24).
  /// Format: [{"month": "2026-02", "score": 72}, ...]
  static Future<void> saveScoreToHistory(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // Charger l'historique existant
    List<Map<String, dynamic>> history = await loadScoreHistory();

    // Remplacer l'entree du mois en cours si elle existe deja
    final existingIndex =
        history.indexWhere((entry) => entry['month'] == monthKey);
    if (existingIndex >= 0) {
      history[existingIndex] = {'month': monthKey, 'score': score};
    } else {
      history.add({'month': monthKey, 'score': score});
    }

    // Limiter a 24 entrees (supprimer les plus anciennes)
    while (history.length > 24) {
      history.removeAt(0);
    }

    await prefs.setString(_scoreHistoryKey, json.encode(history));
  }

  /// Charge l'historique des scores mensuels.
  /// Retourne une liste de maps {"month": "2026-02", "score": 72}.
  static Future<List<Map<String, dynamic>>> loadScoreHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_scoreHistoryKey);
    if (jsonString == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (json.decode(jsonString) as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    } catch (e, stack) {
      dev.log('Failed to decode score history',
          error: e, stackTrace: stack, name: 'Persistence');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  EXPLORED SIMULATORS PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  static const String _exploredSimulatorsKey = 'explored_simulators_v1';
  static const String _onboarding30PlanKey = 'onboarding_30_day_plan_v1';

  /// Marque un simulateur comme exploré (pour le suivi de progression)
  static Future<void> markSimulatorExplored(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_exploredSimulatorsKey) ?? [];
    if (!existing.contains(id)) {
      existing.add(id);
      await prefs.setStringList(_exploredSimulatorsKey, existing);
    }
  }

  /// Charge la liste des simulateurs explorés
  static Future<Set<String>> loadExploredSimulators() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_exploredSimulatorsKey) ?? [];
    return list.toSet();
  }

  // ═══════════════════════════════════════════════════════════
  //  ONBOARDING 30 DAYS PLAN PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  /// Loads the persisted onboarding 30-day plan state.
  /// Returned map keys:
  /// - started_at (ISO string)
  /// - completed (bool)
  /// - completed_at (ISO string)
  /// - stress_choice (string)
  /// - main_goal (string)
  /// - last_route (string)
  /// - opened_routes (List<String>)
  static Future<Map<String, dynamic>> loadOnboarding30PlanState() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_onboarding30PlanKey);
    if (jsonString == null) return {};
    try {
      final decoded = Map<String, dynamic>.from(json.decode(jsonString));
      final opened = decoded['opened_routes'];
      if (opened is List) {
        decoded['opened_routes'] = opened.map((e) => e.toString()).toList();
      } else {
        decoded['opened_routes'] = <String>[];
      }
      decoded['completed'] = decoded['completed'] == true;
      return decoded;
    } catch (e, stack) {
      dev.log('Failed to decode onboarding 30-day plan state',
          error: e, stackTrace: stack, name: 'Persistence');
      return {};
    }
  }

  static Future<void> _saveOnboarding30PlanState(
    Map<String, dynamic> state,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_onboarding30PlanKey, json.encode(state));
  }

  /// Marks the onboarding 30-day plan as started (idempotent).
  static Future<void> markOnboarding30PlanStarted({
    String? stressChoice,
    String? mainGoal,
  }) async {
    final state = await loadOnboarding30PlanState();
    state.putIfAbsent('started_at', () => DateTime.now().toIso8601String());
    state['completed'] = state['completed'] == true;
    state.putIfAbsent('opened_routes', () => <String>[]);
    if (stressChoice != null && stressChoice.isNotEmpty) {
      state['stress_choice'] = stressChoice;
    }
    if (mainGoal != null && mainGoal.isNotEmpty) {
      state['main_goal'] = mainGoal;
    }
    await _saveOnboarding30PlanState(state);
  }

  /// Stores the last opened route and appends it to opened_routes if missing.
  static Future<void> markOnboarding30PlanRouteOpened(String route) async {
    final state = await loadOnboarding30PlanState();
    final opened =
        List<String>.from((state['opened_routes'] as List?) ?? const []);
    if (!opened.contains(route)) {
      opened.add(route);
    }
    state['opened_routes'] = opened;
    state['last_route'] = route;
    await _saveOnboarding30PlanState(state);
  }

  /// Sets completion flag for onboarding 30-day plan.
  static Future<void> setOnboarding30PlanCompleted(bool completed) async {
    final state = await loadOnboarding30PlanState();
    state['completed'] = completed;
    if (completed) {
      state['completed_at'] = DateTime.now().toIso8601String();
    } else {
      state.remove('completed_at');
    }
    await _saveOnboarding30PlanState(state);
  }

  /// Clears onboarding 30-day plan local state.
  static Future<void> clearOnboarding30PlanState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboarding30PlanKey);
  }

  /// Efface tout (Logout / Reset)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await clearDiagnostic();
    await clearCoachHistory();
    await prefs.remove(_lettersKey);
  }

  /// Efface uniquement l'historique coach:
  /// - check-ins mensuels
  /// - score du mois + historique des scores
  /// - progression "simulateurs explorés"
  static Future<void> clearCoachHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_checkInsKey);
    await prefs.remove(_lastScoreKey);
    await prefs.remove(_lastScoreMonthKey);
    await prefs.remove(_scoreHistoryKey);
    await prefs.remove(_exploredSimulatorsKey);
  }

  /// Efface le diagnostic/profil financier:
  /// - réponses wizard/mini-onboarding
  /// - flags de complétion
  /// - contributions planifiées liées au profil
  static Future<void> clearDiagnostic() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wizardKey);
    await prefs.remove(_completedKey);
    await prefs.remove(_miniOnboardingKey);
    await prefs.remove(_miniOnboardingVariantKey);
    await prefs.remove(_miniOnboardingExposureTrackedKey);
    await prefs.remove(_onboardingMetricsControlKey);
    await prefs.remove(_onboardingMetricsChallengeKey);
    await prefs.remove(_contributionsKey);
    await prefs.remove(_onboarding30PlanKey);
  }
}
