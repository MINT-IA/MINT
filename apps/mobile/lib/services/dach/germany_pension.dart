import 'country_pension_service.dart';

// ────────────────────────────────────────────────────────────
//  GERMANY PENSION DATA — S75+ / Phase 4 "La Référence"
// ────────────────────────────────────────────────────────────
//
// Educational data about the German pension system.
// Constants sourced from SGB VI, EStG, AltZertG (2025/2026).
//
// Read-only, no advice. All text in French (app is French-first).
// ────────────────────────────────────────────────────────────

/// German pension system constants and pillar definitions.
///
/// Sources:
/// - SGB VI (Sozialgesetzbuch, Sechstes Buch) — retraite légale
/// - EStG (Einkommensteuergesetz) — fiscalité Riester/Rürup
/// - AltZertG (Altersvorsorgeverträge-Zertifizierungsgesetz) — Riester
class GermanyPension {
  GermanyPension._();

  // ── Constants (2025/2026) ─────────────────────────────────

  /// Standard retirement age (Regelaltersgrenze).
  /// SGB VI § 35: 67 ans pour les personnes nées après 1964.
  static const int retirementAge = 67;

  /// Early retirement age (with deductions).
  /// SGB VI § 36: possible dès 63 ans (avec abattements de 0.3%/mois).
  static const int earlyRetirementAge = 63;

  /// Beitragsbemessungsgrenze (plafond de cotisation) — Ouest, EUR/an.
  /// Source: Sozialversicherungs-Rechengrößenverordnung 2025.
  static const double beitragsbemessungsgrenze = 90600;

  /// Beitragssatz (taux de cotisation GRV) — total en %.
  /// Partagé 50/50 entre salarié et employeur.
  static const double beitragssatz = 18.6;

  /// Riester — cotisation maximale éligible aux subventions (EUR/an).
  /// EStG § 10a: 4% du revenu brut, max 2\u00a0100 EUR.
  static const double riesterMaxBeitrag = 2100;

  /// Riester — subvention de base (Grundzulage, EUR/an).
  /// EStG § 84: 175 EUR/an.
  static const double riesterGrundzulage = 175;

  /// Riester — subvention enfant né après 2008 (Kinderzulage, EUR/an).
  /// EStG § 85: 300 EUR/an par enfant.
  static const double riesterKinderzulage = 300;

  /// Rürup (Basis-Rente) — montant maximal déductible (EUR/an, 2025).
  /// EStG § 10 Abs. 3: plafond Rürup pour les indépendants.
  static const double ruerupMaxAbzug = 27566;

  /// Rürup (Basis-Rente) — montant maximal déductible pour couple marié (EUR/an, 2025).
  /// EStG § 10 Abs. 3: double du plafond individuel pour les couples.
  static const double ruerupMaxAbzugMarried = 55132;

  /// bAV — plafond d'exonération fiscale (Betriebliche Altersvorsorge).
  /// EStG § 3 Nr. 63: 8% de la BBG (2025).
  static const double bavSteuerfreiMax = 7248; // 8% × 90.600

  // ── Pillar definitions ────────────────────────────────────

  /// Pilier 1: Gesetzliche Rentenversicherung (GRV).
  static const grv = PensionPillar(
    number: 1,
    name: 'GRV',
    localName: 'Gesetzliche Rentenversicherung',
    description:
        'Assurance pension légale allemande (1er pilier). '
        'Financée par les cotisations salariales et patronales '
        '($beitragssatz\u00a0% au total). '
        'Rente calculée selon les points de retraite accumulés.',
    legalReference: 'SGB VI',
  );

  /// Pilier 2: Betriebliche Altersvorsorge (bAV).
  static const bav = PensionPillar(
    number: 2,
    name: 'bAV',
    localName: 'Betriebliche Altersvorsorge',
    description:
        'Prévoyance professionnelle allemande (2e pilier). '
        'Financée par l\'employeur et/ou le salarié. '
        'Plusieurs formes possibles\u00a0: Direktversicherung, Pensionskasse, etc.',
    legalReference: 'BetrAVG',
  );

  /// Pilier 3a: Riester-Rente (subventionnée par l'État).
  static const riester = PensionPillar(
    number: 3,
    name: 'Riester',
    localName: 'Riester-Rente',
    description:
        'Prévoyance individuelle subventionnée (3e pilier). '
        'Subvention de base de $riesterGrundzulage\u00a0EUR/an '
        'plus allocations pour enfants. '
        'Cotisation maximale\u00a0: $riesterMaxBeitrag\u00a0EUR/an.',
    maxContribution: riesterMaxBeitrag,
    legalReference: 'EStG § 10a, AltZertG',
  );

  /// Pilier 3b: Rürup / Basis-Rente (déductible fiscalement).
  static const ruerup = PensionPillar(
    number: 3,
    name: 'Rürup',
    localName: 'Rürup (Basis-Rente)',
    description:
        'Prévoyance individuelle déductible fiscalement (3e pilier). '
        'Conçue pour les indépendants et professions libérales. '
        'Cotisations déductibles jusqu\'à $ruerupMaxAbzug\u00a0EUR/an '
        '(célibataire) ou $ruerupMaxAbzugMarried\u00a0EUR/an (couple marié).',
    maxContribution: ruerupMaxAbzug,
    legalReference: 'EStG § 10 Abs. 3',
  );

  // ── Full system ───────────────────────────────────────────

  /// All pillars of the German pension system.
  static const pillars = [grv, bav, riester, ruerup];

  /// Complete German pension system.
  static const system = CountryPensionSystem(
    country: DachCountry.germany,
    name: 'Système de prévoyance allemand',
    pillars: pillars,
    retirementAge: retirementAge,
    earlyRetirementAge: earlyRetirementAge,
    currencyCode: 'EUR',
    taxSystem: 'EStG',
    disclaimer:
        'Outil éducatif\u00a0: ne constitue pas un conseil en prévoyance. '
        'Les valeurs sont indicatives (2025). '
        'Consultez un·e spécialiste pour votre situation personnelle.',
  );
}
