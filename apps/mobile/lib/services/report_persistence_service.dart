import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReportPersistenceService {
  static const String _wizardKey = 'wizard_answers_v2';
  static const String _completedKey = 'wizard_completed';

  /// Sauvegarde les réponses du wizard (incremental off)
  static Future<void> saveAnswers(Map<String, dynamic> answers) async {
    final prefs = await SharedPreferences.getInstance();
    // On serialize tout le map en JSON string
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
    } catch (e) {
      print('Erreur lecture cache wizard: $e');
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
      return [];
    }
  }

  /// Efface tout (Logout / Reset)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wizardKey);
    await prefs.remove(_completedKey);
    await prefs.remove(_lettersKey);
    await prefs.remove(_contributionsKey);
    await prefs.remove(_checkInsKey);
  }
}
