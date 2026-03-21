/// Letter Generation Service — Agent Autonome v1 (S68).
///
/// Pure functions for generating formal letter templates.
/// Letters use [S] i18n for subjects and disclaimers.
/// Body text uses [placeholder] markers — user fills personal data manually.
///
/// COMPLIANCE INVARIANTS:
///   - [GeneratedLetter.requiresValidation] ALWAYS true.
///   - MINT NEVER pre-fills name, address, SSN/AVS, IBAN, employer.
///   - All personal data = [placeholder] markers from [S] localizations.
///   - Letters use formal "vous" for outgoing correspondence.
///   - Disclaimer present on every letter.
///   - No banned terms (garanti, certain, assuré, optimal, etc.).
///
/// References:
///   - LPP art. 86b (obligation d'informer)
///   - LPP art. 79b (rachat LPP)
///   - LPP art. 13/14 (retraite anticipée / taux de conversion)
///   - LAVS art. 30ter (compte individuel)
///   - OPP2 art. 148 (certificat de prévoyance)
///   - LSFin art. 3/8 (information financière)
library;

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';

// ════════════════════════════════════════════════════════════════
//  VALUE OBJECTS
// ════════════════════════════════════════════════════════════════

/// A generated letter template.
///
/// [body] contains [placeholder] markers that the user fills manually.
/// [requiresValidation] is ALWAYS true.
class GeneratedLetter {
  const GeneratedLetter({
    required this.type,
    required this.subject,
    required this.body,
    required this.placeholders,
    required this.disclaimer,
  }) : requiresValidation = true;

  /// Letter type identifier (e.g. "pensionFundRequest", "lppTransfer").
  final String type;

  /// Subject line (i18n string).
  final String subject;

  /// Letter body with [placeholder] markers.
  /// User replaces each marker with actual personal data.
  final String body;

  /// List of placeholder markers contained in [body].
  /// Each must be filled by the user before sending.
  final List<String> placeholders;

  /// Educational disclaimer. Always non-empty.
  final String disclaimer;

  /// ALWAYS true. MINT never transmits anything automatically.
  final bool requiresValidation;
}

// ════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════

/// Pure-function service for generating formal letter templates.
///
/// Letters are models only — user must adapt, sign, and send manually.
/// MINT provides structure and legal references; user provides personal data.
class LetterGenerationService {
  LetterGenerationService._();

  // ─────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────────────────────

  /// Generate a letter to request pension fund information.
  ///
  /// Covers: current certificate, buyback capacity, early retirement simulation.
  /// Caisse name from profile if available.
  ///
  /// References: LPP art. 79b, LPP art. 13, LPP art. 14, OPP2 art. 148.
  static GeneratedLetter generatePensionFundRequest({
    required CoachProfile profile,
    required S l,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final year = effectiveNow.year;
    final caisse =
        profile.prevoyance.nomCaisse ?? '[Nom de la caisse de pension]';
    final placeholderName = l.agentLetterPlaceholderName;
    final placeholderAddress = l.agentLetterPlaceholderAddress;
    final placeholderDate = l.agentLetterPlaceholderDate;
    final subject = l.agentPensionFundSubject;

    final body = '''$placeholderName
$placeholderAddress
[Code postal et ville]

$caisse
[Adresse de la caisse]
[Code postal et ville]

$placeholderDate, le ${effectiveNow.day}.${effectiveNow.month}.$year

Objet\u00a0: $subject

Madame, Monsieur,

Par la présente, je me permets de vous adresser les demandes suivantes concernant mon dossier de prévoyance professionnelle\u00a0:

1. Certificat de prévoyance actualisé $year (avoir de vieillesse, prestations couvertes, taux de conversion applicable)

2. Confirmation de ma capacité de rachat (montant maximal selon l'art.\u00a079b LPP)

3. Simulation de retraite anticipée (projection de l'avoir et de la rente à\u00a063 et 64\u00a0ans, le cas échéant)

Je vous remercie par avance de votre diligence et reste à votre disposition pour tout complément d'information.

Veuillez agréer, Madame, Monsieur, mes salutations distinguées.

$placeholderName
[Numéro de police\u00a0: À compléter]''';

    return GeneratedLetter(
      type: 'pensionFundRequest',
      subject: subject,
      body: body,
      placeholders: [
        placeholderName,
        placeholderAddress,
        placeholderDate,
        '[Code postal et ville]',
        '[Adresse de la caisse]',
        '[Numéro de police\u00a0: À compléter]',
      ],
      disclaimer: l.agentLetterDisclaimer,
    );
  }

  /// Generate a letter for LPP transfer (libre passage).
  ///
  /// For job changes, departure from Switzerland, or cessation of activity.
  /// User fills in personal data and coordinates manually.
  ///
  /// Reference: LPP art. 2 (libre passage), LFLP (loi sur le libre passage).
  static GeneratedLetter generateLppTransfer({
    required CoachProfile profile,
    required S l,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final year = effectiveNow.year;
    final caisseSource =
        profile.prevoyance.nomCaisse ?? '[Caisse de pension actuelle]';
    final placeholderName = l.agentLetterPlaceholderName;
    final placeholderAddress = l.agentLetterPlaceholderAddress;
    final placeholderDate = l.agentLetterPlaceholderDate;
    final subject = l.agentLetterTransferSubject;

    final body = '''$placeholderName
$placeholderAddress
[Code postal et ville]

$caisseSource
[Adresse de la caisse actuelle]
[Code postal et ville]

$placeholderDate, le ${effectiveNow.day}.${effectiveNow.month}.$year

Objet\u00a0: $subject

Madame, Monsieur,

En raison de la cessation de mes rapports de travail / de mon départ de Suisse (biffer la mention inutile), je vous prie de bien vouloir procéder au transfert de mon avoir de libre passage.

Montant à transférer\u00a0: la totalité de mon avoir de libre passage à la date de sortie.

Etablissement de destination\u00a0:
Nom\u00a0: [À compléter]
IBAN ou numéro de compte\u00a0: [À compléter]
Adresse\u00a0: [À compléter]

Date de sortie\u00a0: [À compléter]

Je vous remercie de votre diligence et de me confirmer la bonne exécution de ce transfert.

Veuillez agréer, Madame, Monsieur, mes salutations distinguées.

$placeholderName''';

    return GeneratedLetter(
      type: 'lppTransfer',
      subject: subject,
      body: body,
      placeholders: [
        placeholderName,
        placeholderAddress,
        placeholderDate,
        '[Caisse de pension actuelle]',
        '[Adresse de la caisse actuelle]',
        '[À compléter]',
      ],
      disclaimer: l.agentLetterDisclaimer,
    );
  }

  /// Generate a letter for AVS extract request.
  ///
  /// Used to request the compte individuel (CI) from the caisse de compensation.
  /// No SSN/AVS number pre-filled — user must complete manually.
  ///
  /// Reference: LAVS art. 30ter, RAVS art. 139.
  static GeneratedLetter generateAvsExtractRequest({
    required CoachProfile profile,
    required S l,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final year = effectiveNow.year;
    final placeholderName = l.agentLetterPlaceholderName;
    final placeholderAddress = l.agentLetterPlaceholderAddress;
    final placeholderSsn = l.agentLetterPlaceholderSsn;
    final placeholderDate = l.agentLetterPlaceholderDate;
    final subject = l.agentLetterAvsSubject;

    final body = '''$placeholderName
$placeholderSsn
$placeholderAddress
[Code postal et ville]

Caisse de compensation AVS compétente
[Adresse]
[Code postal et ville]

$placeholderDate, le ${effectiveNow.day}.${effectiveNow.month}.$year

Objet\u00a0: $subject

Madame, Monsieur,

Je vous prie de bien vouloir m'adresser un extrait de mon compte individuel AVS (CI) afin de vérifier l'état de mes cotisations et d'identifier d'éventuelles lacunes.

Je vous remercie par avance de votre diligence.

Veuillez agréer, Madame, Monsieur, mes salutations distinguées.

$placeholderName''';

    return GeneratedLetter(
      type: 'avsExtractRequest',
      subject: subject,
      body: body,
      placeholders: [
        placeholderName,
        placeholderSsn,
        placeholderAddress,
        placeholderDate,
        '[Adresse]',
        '[Code postal et ville]',
      ],
      disclaimer: l.agentLetterDisclaimer,
    );
  }
}
