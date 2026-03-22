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
        profile.prevoyance.nomCaisse ?? l.agentLetterCaisseFallback;
    final placeholderName = l.agentLetterPlaceholderName;
    final placeholderAddress = l.agentLetterPlaceholderAddress;
    final placeholderDate = l.agentLetterPlaceholderDate;
    final subject = l.agentPensionFundSubject;

    final postalCity = l.agentLetterPostalCity;
    final caisseAddress = l.agentLetterCaisseAddress;
    final policeNumber = l.agentLetterPoliceNumber;
    final dateFormatted =
        '${effectiveNow.day}.${effectiveNow.month}.$year';

    final body = l.agentLetterPensionFundBody(
      placeholderName,
      placeholderAddress,
      postalCity,
      caisse,
      caisseAddress,
      placeholderDate,
      dateFormatted,
      subject,
      '$year',
      policeNumber,
    );

    return GeneratedLetter(
      type: 'pensionFundRequest',
      subject: subject,
      body: body,
      placeholders: [
        placeholderName,
        placeholderAddress,
        placeholderDate,
        postalCity,
        caisseAddress,
        policeNumber,
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
        profile.prevoyance.nomCaisse ?? l.agentLetterCaisseCurrentName;
    final placeholderName = l.agentLetterPlaceholderName;
    final placeholderAddress = l.agentLetterPlaceholderAddress;
    final placeholderDate = l.agentLetterPlaceholderDate;
    final subject = l.agentLetterTransferSubject;

    final postalCity = l.agentLetterPostalCity;
    final caisseCurrentAddress = l.agentLetterCaisseCurrentAddress;
    final toComplete = l.agentLetterToComplete;
    final dateFormatted =
        '${effectiveNow.day}.${effectiveNow.month}.$year';

    final body = l.agentLetterLppTransferBody(
      placeholderName,
      placeholderAddress,
      postalCity,
      caisseSource,
      caisseCurrentAddress,
      placeholderDate,
      dateFormatted,
      subject,
      toComplete,
    );

    return GeneratedLetter(
      type: 'lppTransfer',
      subject: subject,
      body: body,
      placeholders: [
        placeholderName,
        placeholderAddress,
        placeholderDate,
        l.agentLetterCaisseCurrentName,
        caisseCurrentAddress,
        toComplete,
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

    final postalCity = l.agentLetterPostalCity;
    final avsOrg = l.agentLetterAvsOrg;
    final avsAddress = l.agentLetterAvsAddress;
    final dateFormatted =
        '${effectiveNow.day}.${effectiveNow.month}.$year';

    final body = l.agentLetterAvsExtractBody(
      placeholderName,
      placeholderSsn,
      placeholderAddress,
      postalCity,
      avsOrg,
      avsAddress,
      placeholderDate,
      dateFormatted,
      subject,
    );

    return GeneratedLetter(
      type: 'avsExtractRequest',
      subject: subject,
      body: body,
      placeholders: [
        placeholderName,
        placeholderSsn,
        placeholderAddress,
        placeholderDate,
        avsAddress,
        postalCity,
      ],
      disclaimer: l.agentLetterDisclaimer,
    );
  }
}
