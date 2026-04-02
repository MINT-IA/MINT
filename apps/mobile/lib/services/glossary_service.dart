import 'package:flutter/widgets.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Glossary service — provides jargon-free explanations for Swiss financial terms.
///
/// Tracks how many times a user has looked up each term. After 3 lookups,
/// [userKnowsTerm] returns true and the UI can hide the underline affordance.
///
/// All explanations are i18n-sourced via ARB files.
class GlossaryService {
  GlossaryService._();

  /// Returns the localized explanation for [termKey], or null if unknown.
  static String? explain(BuildContext context, String termKey) {
    final l = S.of(context)!;
    final map = <String, String>{
      'LPP': l.glossaryLpp,
      'AVS': l.glossaryAvs,
      '3a': l.glossary3a,
      'RAMD': l.glossaryRamd,
      'Taux de conversion': l.glossaryTauxConversion,
      'Rachat LPP': l.glossaryRachat,
      'Lacune': l.glossaryLacune,
      'Taux de remplacement': l.glossaryTauxRemplacement,
      'Rente': l.glossaryRente,
      'Capital': l.glossaryCapital,
      'Coordination': l.glossaryCoordination,
      'Surobligatoire': l.glossarySurobligatoire,
    };
    return map[termKey];
  }

  /// Increments the lookup counter for [term].
  static Future<void> trackLookup(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt('_glossary_${term}_count') ?? 0) + 1;
    await prefs.setInt('_glossary_${term}_count', count);
  }

  /// Returns true when the user has looked up [term] at least 3 times.
  static Future<bool> userKnowsTerm(String term) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('_glossary_${term}_count') ?? 0) >= 3;
  }
}
