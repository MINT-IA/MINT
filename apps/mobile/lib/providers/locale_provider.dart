import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/locale_helper.dart';

/// Manages the app's active locale with SharedPreferences persistence.
///
/// On first launch, defaults to French (the primary MINT language).
/// User selection via the language selector is persisted across restarts.
///
/// SIMQ-07 (v2.12 Phase 86) — supports a build-time `APP_LOCALE`
/// dart-define so the walker can force a cold-start locale per
/// archetype × language matrix run (Phase 88 cross-language walker).
/// The dart-define short-circuits in [kReleaseMode] so production
/// binaries never read it.
class LocaleProvider extends ChangeNotifier {
  static const String _prefKey = 'mint_locale';

  /// SIMQ-07 — walker-injected locale override. Empty in release builds.
  static const String _walkerLocaleDefine = String.fromEnvironment(
    'APP_LOCALE',
    defaultValue: '',
  );

  Locale _locale = const Locale('fr');

  Locale get locale => _locale;

  /// Load persisted locale from SharedPreferences (or walker dart-define
  /// in profile/test builds).
  /// Call once at app startup (before MaterialApp builds).
  Future<void> load() async {
    // SIMQ-07 — walker dart-define takes precedence for cold-start locale.
    // Skipped in release mode so production binaries are never affected.
    if (!kReleaseMode && _walkerLocaleDefine.isNotEmpty) {
      final code = _walkerLocaleDefine.trim().toLowerCase();
      if (MintLocales.isSupported(code)) {
        _locale = MintLocales.localeFor(code);
        notifyListeners();
        return; // walker override wins ; do not consult SharedPreferences
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey);
    if (code != null && MintLocales.isSupported(code)) {
      _locale = MintLocales.localeFor(code);
      notifyListeners();
    }
  }

  /// Change locale, persist, and rebuild the widget tree.
  Future<void> setLocale(Locale newLocale) async {
    if (newLocale == _locale) return;
    if (!MintLocales.isSupported(newLocale.languageCode)) return;

    _locale = newLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, newLocale.languageCode);
    notifyListeners();
  }
}
