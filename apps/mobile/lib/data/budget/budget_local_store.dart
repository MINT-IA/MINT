// TODO: Intégrer shared_preferences pour persistance réelle cross-sessions
// import 'package:shared_preferences/shared_preferences.dart';

/// Service responsable de la persistance locale des overrides du budget (sliders).
/// Pour le MVP, si shared_preferences n'est pas dispo, on fait in-memory (perdu au restart).
class BudgetLocalStore {
  // Singleton pattern possible, mais ici simple class injectable

  final Map<String, dynamic> _inMemoryStorage = {};

  Future<void> saveOverride(String key, double value) async {
    // print('BudgetLocalStore: Saving $key = $value');
    _inMemoryStorage[key] = value;
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setDouble(key, value);
  }

  Future<double?> getOverride(String key) async {
    // final prefs = await SharedPreferences.getInstance();
    // return prefs.getDouble(key);
    return _inMemoryStorage[key] as double?;
  }

  Future<void> clear() async {
    _inMemoryStorage.clear();
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.clear();
  }
}
