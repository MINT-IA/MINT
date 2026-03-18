import 'country_pension_service.dart';

// ────────────────────────────────────────────────────────────
//  AUSTRIA PENSION DATA — S75+ / Phase 4 "La Référence"
// ────────────────────────────────────────────────────────────
//
// Educational data about the Austrian pension system.
// Constants sourced from ASVG, EStG-AT, PKG (2025/2026).
//
// Read-only, no advice. All text in French (app is French-first).
// ────────────────────────────────────────────────────────────

/// Austrian pension system constants and pillar definitions.
///
/// Sources:
/// - ASVG (Allgemeines Sozialversicherungsgesetz) — retraite légale
/// - EStG-AT (Einkommensteuergesetz, Autriche) — fiscalité
/// - PKG (Pensionskassengesetz) — caisses de pension
class AustriaPension {
  AustriaPension._();

  // ── Constants (2025/2026) ─────────────────────────────────

  /// Standard retirement age — men.
  /// ASVG § 253: 65 ans.
  static const int retirementAgeMen = 65;

  /// Standard retirement age — women (2025).
  /// ASVG § 253: en transition de 60 à 65 ans (2024-2033).
  /// 2025: ~61 ans. Atteindra 65 ans en 2033.
  static const int retirementAgeWomen2025 = 61;

  /// Target retirement age — women after 2033.
  static const int retirementAgeWomenTarget = 65;

  /// Year when women's retirement age equals men's.
  static const int womenEqualityYear = 2033;

  /// Early retirement age (Korridorpension).
  /// ASVG § 253b: possible dès 62 ans avec 40 années de cotisation.
  static const int earlyRetirementAge = 62;

  /// Höchstbeitragsgrundlage (plafond de cotisation mensuel, EUR).
  /// Source: Aufwertungsfaktor-Verordnung 2025.
  static const double hoechstbeitragsgrundlageMonthly = 6060;

  /// Plafond annuel de cotisation (14 mois en Autriche).
  static const double hoechstbeitragsgrundlageYearly = 84840; // 6060 × 14

  /// Taux de cotisation pension (total salarié + employeur, en %).
  static const double pensionsbeitragssatz = 22.8;

  /// Pensionskonto — compte pension en ligne disponible.
  /// Permet de consulter les droits acquis sur neuespensionskonto.at.
  static const bool pensionskontoAvailable = true;

  /// Zukunftsvorsorge — plafond annuel déductible (EUR, 2025).
  /// Épargne-pension fiscalement avantageuse.
  static const double zukunftsvorsorgeMax = 3066.32;

  // ── Pillar definitions ────────────────────────────────────

  /// Pilier 1: Pensionsversicherung (PV).
  static const pv = PensionPillar(
    number: 1,
    name: 'PV',
    localName: 'Pensionsversicherung',
    description:
        'Assurance pension légale autrichienne (1er pilier). '
        'Système par répartition avec compte individuel (Pensionskonto). '
        'Taux de cotisation total\u00a0: $pensionsbeitragssatz\u00a0%.',
    legalReference: 'ASVG',
  );

  /// Pilier 2: Betriebliche Pensionskasse.
  static const betriebspension = PensionPillar(
    number: 2,
    name: 'Betriebspension',
    localName: 'Betriebliche Pensionskasse',
    description:
        'Prévoyance professionnelle autrichienne (2e pilier). '
        'Non obligatoire en Autriche, mais courante dans les grandes entreprises. '
        'Gérée par des Pensionskassen réglementées.',
    legalReference: 'PKG',
  );

  /// Pilier 3: Zukunftsvorsorge (épargne-pension avantageuse).
  static const zukunftsvorsorge = PensionPillar(
    number: 3,
    name: 'Zukunftsvorsorge',
    localName: 'Prämienbegünstigte Zukunftsvorsorge',
    description:
        'Épargne-pension individuelle avec prime étatique (3e pilier). '
        'Plafond annuel\u00a0: 3\u00a0066\u00a0EUR (2025). '
        'Prime étatique variable selon le taux directeur.',
    maxContribution: zukunftsvorsorgeMax,
    legalReference: 'EStG-AT § 108g',
  );

  // ── Full system ───────────────────────────────────────────

  /// All pillars of the Austrian pension system.
  static const pillars = [pv, betriebspension, zukunftsvorsorge];

  /// Complete Austrian pension system.
  /// Note: retirementAge uses men's age (65) as standard reference.
  static const system = CountryPensionSystem(
    country: DachCountry.austria,
    name: 'Système de prévoyance autrichien',
    pillars: pillars,
    retirementAge: retirementAgeMen,
    earlyRetirementAge: earlyRetirementAge,
    currencyCode: 'EUR',
    taxSystem: 'EStG-AT',
    disclaimer:
        'Outil éducatif\u00a0: ne constitue pas un conseil en prévoyance. '
        'Les valeurs sont indicatives (2025). '
        'Consultez un·e spécialiste pour votre situation personnelle.',
  );

  // ── Helpers ───────────────────────────────────────────────

  /// Get the women's retirement age for a given year.
  ///
  /// Transition from 60 to 65 over 2024-2033.
  /// Returns 65 for years >= 2033.
  static int womenRetirementAgeForYear(int year) {
    if (year >= womenEqualityYear) return 65;
    if (year <= 2023) return 60;
    // Linear transition: +0.5 year per calendar year (2024-2033)
    // 2024: 60.5 → 61, 2025: 61, 2026: 61.5 → 62, etc.
    final yearsIntoTransition = year - 2024;
    final rawAge = 60.0 + (yearsIntoTransition + 1) * 0.5;
    return rawAge.ceil().clamp(60, 65);
  }
}
