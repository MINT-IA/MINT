import 'dart:convert';
import 'dart:developer' as dev;
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
  static Future<void> saveCheckIns(
      List<Map<String, dynamic>> checkIns) async {
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

  /// Efface tout (Logout / Reset)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wizardKey);
    await prefs.remove(_completedKey);
    await prefs.remove(_miniOnboardingKey);
    await prefs.remove(_lettersKey);
    await prefs.remove(_contributionsKey);
    await prefs.remove(_checkInsKey);
    await prefs.remove(_lastScoreKey);
    await prefs.remove(_lastScoreMonthKey);
    await prefs.remove(_scoreHistoryKey);
    await prefs.remove(_exploredSimulatorsKey);
  }
}
