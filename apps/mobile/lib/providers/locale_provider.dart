import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/locale_helper.dart';

/// Manages the app's active locale with SharedPreferences persistence.
///
/// On first launch, defaults to French (the primary MINT language).
/// User selection via the language selector is persisted across restarts.
class LocaleProvider extends ChangeNotifier {
  static const String _prefKey = 'mint_locale';

  Locale _locale = const Locale('fr');

  Locale get locale => _locale;

  /// Load persisted locale from SharedPreferences.
  /// Call once at app startup (before MaterialApp builds).
  Future<void> load() async {
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
