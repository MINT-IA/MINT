import 'package:mint_mobile/models/coach_profile.dart';

// ────────────────────────────────────────────────────────────
//  CHAT DATA CAPTURE HANDLER — CHAT-04 (Phase 3)
//
//  Pure utility class: parses profile data from free-text chat
//  responses. No state, no widget, no Flutter dependency.
//
//  T-03-04: Validates parsed values — age 0-150, salary >= 0,
//  canton against known Swiss canton list.
// ────────────────────────────────────────────────────────────

/// Fields that can be captured via chat conversation.
enum CaptureField { age, canton, salary }

/// Handles parsing of profile data from free-text chat responses.
///
/// All methods are static and pure — no I/O, no state.
/// The coach_chat_screen uses this to parse user responses during
/// data-capture mode.
class ChatDataCaptureHandler {
  ChatDataCaptureHandler._();

  /// Swiss cantons — abbreviation to full name.
  static const _cantons = <String, String>{
    'AG': 'Argovie',
    'AI': 'Appenzell Rhodes-Int\u00e9rieures',
    'AR': 'Appenzell Rhodes-Ext\u00e9rieures',
    'BE': 'Berne',
    'BL': 'B\u00e2le-Campagne',
    'BS': 'B\u00e2le-Ville',
    'FR': 'Fribourg',
    'GE': 'Gen\u00e8ve',
    'GL': 'Glaris',
    'GR': 'Grisons',
    'JU': 'Jura',
    'LU': 'Lucerne',
    'NE': 'Neuch\u00e2tel',
    'NW': 'Nidwald',
    'OW': 'Obwald',
    'SG': 'Saint-Gall',
    'SH': 'Schaffhouse',
    'SO': 'Soleure',
    'SZ': 'Schwytz',
    'TG': 'Thurgovie',
    'TI': 'Tessin',
    'UR': 'Uri',
    'VD': 'Vaud',
    'VS': 'Valais',
    'ZG': 'Zoug',
    'ZH': 'Zurich',
  };

  /// Parses an age from user text. Returns null if unparseable.
  ///
  /// T-03-04: Validates range 16-120 (working age to plausible max).
  static int? parseAge(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
    final age = int.tryParse(cleaned);
    if (age == null || age < 16 || age > 120) return null;
    return age;
  }

  /// Resolves canton from user text (accepts abbreviation or full name).
  ///
  /// T-03-04: Validates against known Swiss canton list.
  /// Returns the 2-letter abbreviation or null.
  static String? parseCanton(String input) {
    final trimmed = input.trim();

    // Try exact abbreviation match (case-insensitive)
    final upper = trimmed.toUpperCase();
    if (_cantons.containsKey(upper)) return upper;

    // Try full name match (case-insensitive, accent-insensitive)
    final lower = trimmed.toLowerCase();
    for (final entry in _cantons.entries) {
      if (entry.value.toLowerCase() == lower) return entry.key;
      // Also match without accents for convenience
      if (_removeAccents(entry.value.toLowerCase()) ==
          _removeAccents(lower)) {
        return entry.key;
      }
    }

    // Try partial match (e.g., "zurich" → ZH)
    for (final entry in _cantons.entries) {
      if (_removeAccents(entry.value.toLowerCase())
          .contains(_removeAccents(lower))) {
        return entry.key;
      }
    }

    return null;
  }

  /// Parses annual salary from user text.
  ///
  /// Handles Swiss formatting: 120'000, 120000, 120 000.
  /// T-03-04: Rejects negative values.
  static double? parseSalary(String input) {
    // Remove Swiss thousands separator ('), spaces, and "CHF" prefix
    final cleaned = input
        .replaceAll(RegExp(r'[cC][hH][fF]'), '')
        .replaceAll("'", '')
        .replaceAll('\u2019', '') // curly apostrophe
        .replaceAll(' ', '')
        .replaceAll('\u00a0', '') // non-breaking space
        .trim();

    final salary = double.tryParse(cleaned);
    if (salary == null || salary < 0) return null;
    return salary;
  }

  /// Returns list of profile fields still missing from the given CoachProfile.
  ///
  /// Respects pre-fill rule: only returns fields that are truly unknown.
  static List<CaptureField> missingFields(CoachProfile? profile) {
    if (profile == null) {
      return [CaptureField.age, CaptureField.canton, CaptureField.salary];
    }

    final missing = <CaptureField>[];

    // Age: check if birthYear is meaningful (not a placeholder)
    final age = profile.age;
    if (age <= 0 || age > 120) {
      missing.add(CaptureField.age);
    }

    // Canton: check if it's set and not a default placeholder
    final canton = profile.canton;
    if (canton.isEmpty || !_cantons.containsKey(canton.toUpperCase())) {
      missing.add(CaptureField.canton);
    }

    // Salary: check if it's meaningfully set (> 0)
    if (profile.salaireBrutMensuel <= 0) {
      missing.add(CaptureField.salary);
    }

    return missing;
  }

  /// Returns the French question for a given capture field.
  static String questionFor(CaptureField field) {
    switch (field) {
      case CaptureField.age:
        return 'Quel \u00e2ge as-tu\u00a0?';
      case CaptureField.canton:
        return 'Tu habites dans quel canton\u00a0?';
      case CaptureField.salary:
        return 'Ton revenu annuel brut, c\u2019est environ combien\u00a0?';
    }
  }

  /// Returns the gentle re-ask message for invalid input.
  static String reaskFor(CaptureField field) {
    switch (field) {
      case CaptureField.age:
        return 'Hmm, je n\u2019ai pas compris. Tu peux me donner ton \u00e2ge en chiffres\u00a0?';
      case CaptureField.canton:
        return 'Je n\u2019ai pas reconnu ce canton. Essaie avec l\u2019abr\u00e9viation (VD, GE, ZH...)\u00a0?';
      case CaptureField.salary:
        return 'Hmm, je n\u2019ai pas compris. Tu peux me donner un montant en CHF\u00a0?';
    }
  }

  static String _removeAccents(String input) {
    return input
        .replaceAll('\u00e9', 'e')
        .replaceAll('\u00e8', 'e')
        .replaceAll('\u00ea', 'e')
        .replaceAll('\u00eb', 'e')
        .replaceAll('\u00e0', 'a')
        .replaceAll('\u00e2', 'a')
        .replaceAll('\u00f4', 'o')
        .replaceAll('\u00f9', 'u')
        .replaceAll('\u00fb', 'u')
        .replaceAll('\u00ee', 'i')
        .replaceAll('\u00ef', 'i')
        .replaceAll('\u00e7', 'c');
  }
}
