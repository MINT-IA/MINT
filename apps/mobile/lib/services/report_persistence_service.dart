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

  /// Efface tout (Logout / Reset)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wizardKey);
    await prefs.remove(_completedKey);
    await prefs.remove(_lettersKey);
  }
}
