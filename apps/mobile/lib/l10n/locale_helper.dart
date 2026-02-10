import 'package:flutter/material.dart';

/// Centralised locale metadata for the MINT application.
///
/// The six supported locales cover the four Swiss national languages plus
/// Portuguese and Spanish, which are the two most-spoken foreign languages
/// among seasonal and cross-border workers in Switzerland.
class MintLocales {
  MintLocales._();

  // ---------------------------------------------------------------------------
  // Supported locales (order = preference order in the app)
  // ---------------------------------------------------------------------------
  static const List<Locale> supportedLocales = [
    Locale('fr'), // French  (default)
    Locale('de'), // German
    Locale('en'), // English
    Locale('it'), // Italian
    Locale('pt'), // Portuguese
    Locale('es'), // Spanish
  ];

  // ---------------------------------------------------------------------------
  // Display names (used in the language-selector bottom-sheet)
  // ---------------------------------------------------------------------------
  static const Map<String, String> displayNames = {
    'fr': 'Francais',
    'de': 'Deutsch',
    'en': 'English',
    'it': 'Italiano',
    'pt': 'Portugues',
    'es': 'Espanol',
  };

  // ---------------------------------------------------------------------------
  // Country-flag emojis (used next to the display name)
  // ---------------------------------------------------------------------------
  static const Map<String, String> flags = {
    'fr': '\u{1F1E8}\u{1F1ED}', // Switzerland flag (French-speaking)
    'de': '\u{1F1E8}\u{1F1ED}', // Switzerland flag (German-speaking)
    'en': '\u{1F1EC}\u{1F1E7}', // United Kingdom flag
    'it': '\u{1F1E8}\u{1F1ED}', // Switzerland flag (Italian-speaking)
    'pt': '\u{1F1F5}\u{1F1F9}', // Portugal flag
    'es': '\u{1F1EA}\u{1F1F8}', // Spain flag
  };

  /// Returns the display name for a given [languageCode].
  /// Falls back to the language code itself when unknown.
  static String nameOf(String languageCode) =>
      displayNames[languageCode] ?? languageCode;

  /// Returns the flag emoji for a given [languageCode].
  static String flagOf(String languageCode) => flags[languageCode] ?? '';

  /// Returns the [Locale] matching a [languageCode], or French by default.
  static Locale localeFor(String languageCode) {
    return supportedLocales.firstWhere(
      (l) => l.languageCode == languageCode,
      orElse: () => const Locale('fr'),
    );
  }

  /// Whether the given [languageCode] is supported.
  static bool isSupported(String languageCode) =>
      supportedLocales.any((l) => l.languageCode == languageCode);
}
