// Coach fallback messages — localized strings for the offline/no-LLM path.
//
// Why this exists instead of ARB lookup:
// `CoachOrchestrator` is a pure static service with no `BuildContext`,
// so `AppLocalizations.of(context)` is unreachable. Callers already
// thread a `language` code (ISO 639-1) through `generateChat`, so we
// dispatch on that here. Keep in sync with any future ARB keys that
// mirror these strings.
//
// Anti-shame doctrine: MINT is the subject of the unavailability —
// never the user. Framing: "le coach n'est pas disponible", not
// "tu ne peux pas utiliser le coach".
//
// Resolves KNOWN_GAPS_v2.2.md Cat 7 (P2 — coach fallback FR-only).
class CoachFallbackMessages {
  CoachFallbackMessages._();

  /// Returns the localized offline-fallback message for the coach chat.
  ///
  /// [languageCode] is an ISO 639-1 code (`fr`, `en`, `de`, `es`, `it`, `pt`).
  /// Falls back to French when the code is unknown, matching the app's
  /// default locale in `LocaleProvider`.
  ///
  /// [disclaimer] is appended, italicized, matching the pre-i18n format.
  static String chatUnavailable(String languageCode, String disclaimer) {
    final body = _bodies[languageCode] ?? _bodies['fr']!;
    return '$body\n\n_${disclaimer}_';
  }

  static const Map<String, String> _bodies = {
    'fr': 'Le coach IA n\'est pas disponible pour le moment.\n\n'
        'En attendant, tu peux\u00a0:\n'
        '• Explorer tes outils (budget, simulateurs, dossier)\n'
        '• Consulter les fiches éducatives\n'
        '• Enrichir ton profil pour des projections plus précises',
    'en': 'The AI coach is unavailable right now.\n\n'
        'In the meantime, you can:\n'
        '• Explore your tools (budget, simulators, dossier)\n'
        '• Read the educational fact sheets\n'
        '• Enrich your profile for more accurate projections',
    'de': 'Der KI-Coach ist im Moment nicht verfügbar.\n\n'
        'In der Zwischenzeit kannst du:\n'
        '• Deine Werkzeuge erkunden (Budget, Simulatoren, Dossier)\n'
        '• Die Lerninhalte durchlesen\n'
        '• Dein Profil ergänzen für genauere Projektionen',
    'es': 'El coach de IA no está disponible en este momento.\n\n'
        'Mientras tanto, puedes:\n'
        '• Explorar tus herramientas (presupuesto, simuladores, expediente)\n'
        '• Consultar las fichas educativas\n'
        '• Completar tu perfil para proyecciones más precisas',
    'it': 'Il coach IA non è disponibile al momento.\n\n'
        'Nel frattempo, puoi:\n'
        '• Esplorare i tuoi strumenti (budget, simulatori, dossier)\n'
        '• Consultare le schede educative\n'
        '• Arricchire il tuo profilo per proiezioni più precise',
    'pt': 'O coach de IA não está disponível neste momento.\n\n'
        'Entretanto, podes:\n'
        '• Explorar as tuas ferramentas (orçamento, simuladores, dossier)\n'
        '• Consultar as fichas educativas\n'
        '• Enriquecer o teu perfil para projeções mais precisas',
  };

  /// Sub-phase 01.5 W02-T03 Task 5 — orchestrator-level refusal copy
  /// used when the user's archetype is outside the calibrated set
  /// (defense-in-depth secondary gate, hit only when the route gate
  /// is bypassed). Anti-shame framing: MINT is « pas encore calibré »,
  /// the user is never the subject of the unavailability.
  static String archetypeNotCalibrated(String languageCode) {
    return _archetypeNotCalibratedBodies[languageCode] ??
        _archetypeNotCalibratedBodies['fr']!;
  }

  static const Map<String, String> _archetypeNotCalibratedBodies = {
    'fr': 'MINT n\'est pas encore calibré pour ton profil. '
        'On te tient au courant dès qu\'on ouvre à ton parcours.',
    'en': 'MINT is not yet calibrated for your profile. '
        'We will let you know as soon as we open the experience for your journey.',
    'de': 'MINT ist für dein Profil noch nicht ausgelegt. '
        'Wir melden uns, sobald wir die Erfahrung für deinen Weg öffnen.',
    'es': 'MINT aún no está adaptado a tu perfil. '
        'Te avisaremos en cuanto abramos la experiencia para tu trayectoria.',
    'it': 'MINT non è ancora calibrato per il tuo profilo. '
        'Ti faremo sapere appena apriremo l\'esperienza al tuo percorso.',
    'pt': 'MINT ainda não está calibrado para o teu perfil. '
        'Avisamos-te assim que abrirmos a experiência ao teu percurso.',
  };
}
