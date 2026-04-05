/// Provider for onboarding data collected during the first-contact flow.
///
/// Single source of truth for all onboarding data. Screens call typed
/// setters (e.g. [setBirthYear]); SharedPreferences is an internal
/// persistence detail for app-kill survival.
///
/// Consumed by:
///   - InstantChiffreChocScreen (writes choc + emotion)
///   - LandingScreen / Onboarding Hinge (writes birthYear, salary, canton)
///   - ContextInjectorService (reads for coach first-session injection)
///   - CoachProfileProvider (reads to hydrate profile on first login)
///
/// Wire Spec V2 §7 — OnboardingProvider replaces direct SharedPrefs access.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The type of chiffre choc shown during onboarding.
///
/// Must stay in sync with ChiffreChocType in chiffre_choc_selector.dart.
/// We duplicate the enum here to avoid a circular dependency — the selector
/// returns a ChiffreChoc object, this provider stores the type as a string.
enum OnboardingChocType {
  compoundGrowth,
  taxSaving3a,
  retirementGap,
  retirementIncome,
  liquidityAlert,
  hourlyRate,
}

/// Immutable snapshot of onboarding data.
class OnboardingPayload {
  final int? birthYear;
  final double? grossSalary;
  final String? canton;
  final String? anxietyLevel; // 'far' | 'mid' | 'close' (from Hinge prompt 1)
  final OnboardingChocType? chocType;
  final double? chocValue;
  final String? emotion;

  const OnboardingPayload({
    this.birthYear,
    this.grossSalary,
    this.canton,
    this.anxietyLevel,
    this.chocType,
    this.chocValue,
    this.emotion,
  });

  /// True when the 3 core fields are present (enough for chiffre choc calc).
  bool get isComplete =>
      birthYear != null && grossSalary != null && canton != null;

  /// True when the chiffre choc has been shown and emotion captured.
  bool get hasChocData => chocType != null && chocValue != null;

  /// True when the user reacted to the chiffre choc.
  bool get hasEmotion => emotion != null && emotion!.isNotEmpty;
}

/// Provider managing onboarding data with SharedPreferences persistence.
class OnboardingProvider extends ChangeNotifier {
  // ── Keys (private — no other code should use these directly) ────────
  static const _kBirthYear = 'onboarding_birth_year';
  static const _kGrossSalary = 'onboarding_gross_salary';
  static const _kCanton = 'onboarding_canton';
  static const _kAnxietyLevel = 'onboarding_anxiety_level';
  static const _kChocType = 'onboarding_choc_type';
  static const _kChocValue = 'onboarding_choc_value';
  static const _kEmotion = 'onboarding_emotion';

  // ── State ───────────────────────────────────────────────────────────
  int? _birthYear;
  double? _grossSalary;
  String? _canton;
  String? _anxietyLevel;
  OnboardingChocType? _chocType;
  double? _chocValue;
  String? _emotion;
  bool _loaded = false;

  // ── Public getters ──────────────────────────────────────────────────
  int? get birthYear => _birthYear;
  double? get grossSalary => _grossSalary;
  String? get canton => _canton;
  String? get anxietyLevel => _anxietyLevel;
  OnboardingChocType? get chocType => _chocType;
  double? get chocValue => _chocValue;
  String? get emotion => _emotion;
  bool get isLoaded => _loaded;

  /// Immutable snapshot of current state.
  OnboardingPayload get payload => OnboardingPayload(
        birthYear: _birthYear,
        grossSalary: _grossSalary,
        canton: _canton,
        anxietyLevel: _anxietyLevel,
        chocType: _chocType,
        chocValue: _chocValue,
        emotion: _emotion,
      );

  // ── Load from persistence ───────────────────────────────────────────

  /// Load previously saved onboarding data (app-kill recovery).
  /// Called once at app startup from MultiProvider.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _birthYear = prefs.getInt(_kBirthYear);
      _grossSalary = prefs.getDouble(_kGrossSalary);
      _canton = prefs.getString(_kCanton);
      _anxietyLevel = prefs.getString(_kAnxietyLevel);
      final chocStr = prefs.getString(_kChocType);
      _chocType = chocStr != null ? _parseChocType(chocStr) : null;
      _chocValue = prefs.getDouble(_kChocValue);
      _emotion = prefs.getString(_kEmotion);
      _loaded = true;
      notifyListeners();
    } catch (_) {
      _loaded = true;
      // Never crash on persistence failure.
    }
  }

  // ── Typed setters (the ONLY public write API) ────────────────────────

  Future<void> setBirthYear(int value) async {
    _birthYear = value;
    notifyListeners();
    await _persist(_kBirthYear, value);
  }

  Future<void> setGrossSalary(double value) async {
    _grossSalary = value;
    notifyListeners();
    await _persist(_kGrossSalary, value);
  }

  Future<void> setCanton(String value) async {
    _canton = value;
    notifyListeners();
    await _persist(_kCanton, value);
  }

  Future<void> setAnxietyLevel(String value) async {
    _anxietyLevel = value;
    notifyListeners();
    await _persist(_kAnxietyLevel, value);
  }

  Future<void> setChoc(OnboardingChocType type, double value) async {
    _chocType = type;
    _chocValue = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kChocType, type.name);
    await prefs.setDouble(_kChocValue, value);
  }

  Future<void> setEmotion(String value) async {
    _emotion = value;
    notifyListeners();
    await _persist(_kEmotion, value);
  }

  // ── Clear (post-onboarding, after data transferred to CoachProfile) ──

  /// Clear all onboarding data. Called after the data has been transferred
  /// to CoachProfileProvider (first coach session).
  Future<void> clear() async {
    _birthYear = null;
    _grossSalary = null;
    _canton = null;
    _anxietyLevel = null;
    _chocType = null;
    _chocValue = null;
    _emotion = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kBirthYear);
      await prefs.remove(_kGrossSalary);
      await prefs.remove(_kCanton);
      await prefs.remove(_kAnxietyLevel);
      await prefs.remove(_kChocType);
      await prefs.remove(_kChocValue);
      await prefs.remove(_kEmotion);
    } catch (_) {
      // Best effort.
    }
  }

  // ── Internal ─────────────────────────────────────────────────────────

  Future<void> _persist(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (_) {
      // Best effort persistence — never block UI.
    }
  }

  static OnboardingChocType? _parseChocType(String value) {
    for (final type in OnboardingChocType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
