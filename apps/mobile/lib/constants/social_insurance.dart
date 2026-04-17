/// Constantes d'assurances sociales suisses — facade Flutter.
///
/// ARCHITECTURE (depuis PR #162):
///   - Backend RegulatoryRegistry = source de verite unique
///   - RegulatorySyncService.fetchConstants() synce au startup
///   - Ce fichier fournit les FALLBACK offline (valeurs hardcodees)
///   - [reg()] lit d'abord le cache sync, puis fallback sur la const
///
/// Valeurs fallback: 2025/2026
/// Derniere mise a jour: 2026-03-26
library;

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';

/// Keys that have already emitted a fallback warning in this process.
///
/// In tests and dev, `RegulatorySyncService._cachedConstants` stays null,
/// so every [reg] call used to spam `debugPrint` — thousands of duplicate
/// lines per test run, overflowing CI log buffers and drowning real output.
/// We now log each missing key at most once per process.
final Set<String> _regFallbackLogged = <String>{};

/// Read a constant from the synced backend cache, falling back to [fallback].
///
/// Usage: `reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp)`
/// Returns the backend-synced value if available, otherwise the local const.
double reg(String key, double fallback) {
  final cached = RegulatorySyncService.getCached(key);
  if (cached != null) return cached;
  // Fallback: backend cache not available for this key.
  // Log once per key per process to avoid flooding CI / dev consoles.
  if (kDebugMode && _regFallbackLogged.add(key)) {
    debugPrint('reg() FALLBACK: $key → $fallback (cache miss, logged once)');
  }
  return fallback;
}

/// Test hook: reset the one-shot fallback log cache.
///
/// Some tests exercise the fallback path intentionally and want to observe
/// the log for a fresh key. Not exported from the library.
@visibleForTesting
void debugResetRegFallbackLog() {
  _regFallbackLogged.clear();
}

// ══════════════════════════════════════════════════════════════════════════════
// LPP — Prevoyance professionnelle (2e pilier)
// Base legale: LPP art. 7, 8, 14, 16 / OPP2
// ══════════════════════════════════════════════════════════════════════════════

/// Salaire annuel minimum pour etre soumis a la LPP (LPP art. 7).
const double lppSeuilEntree = 22680.0;

/// Deduction de coordination (LPP art. 8).
const double lppDeductionCoordination = 26460.0;

/// Salaire coordonne minimum assure (LPP art. 8 al. 2).
const double lppSalaireCoordMin = 3780.0;

/// Salaire coordonne maximum assure.
const double lppSalaireCoordMax = 64260.0;

/// Salaire annuel maximum assure LPP (LPP art. 8 al. 1).
const double lppSalaireMax = 90720.0;

/// Taux de conversion minimum LPP en % (LPP art. 14 al. 2).
const double lppTauxConversionMin = 6.8;

/// Taux de conversion minimum LPP en fraction decimale (0.068 = 6.8%).
/// S'applique UNIQUEMENT a la part obligatoire (LPP art. 14 al. 2).
/// Ne jamais appliquer implicitement sur tout le capital LPP.
const double lppTauxConversionMinDecimal = 0.068;

/// Taux de conversion blended pour la part complementaire LPP.
/// ~60% obligatoire a 6.8% + ~40% surobligatoire a ~4.3% = ~5.8%.
/// Aligne avec backend (source de verite): LPP_CONVERSION_RATE_COMPLEMENTAIRE = 0.058.
const double lppTauxConversionSurobligDecimal = 0.058;

/// Reduction du taux de conversion par annee de retraite anticipee.
/// Pratique standard des caisses suisses: ~0.2 points de % par annee
/// avant l'age de reference (LPP art. 13 al. 2).
///
/// Le taux reel varie significativement par caisse (0.1% a 0.5%/an).
/// Cette valeur est une estimation educative (moyenne observee).
/// Source: CHS PP - Rapport sur la situation financiere des caisses LPP.
/// Note: toujours afficher "confirme avec ta caisse" dans les projections.
const double lppEarlyRetirementRateReduction = 0.002;

/// Taux d'interet minimum LPP en % (fixe par le Conseil federal).
const double lppTauxInteretMin = 1.25;

/// Taux de bonification de vieillesse par tranche d'age (LPP art. 16).
const Map<String, double> lppBonificationsVieillesse = {
  '25-34': 0.07,
  '35-44': 0.10,
  '45-54': 0.15,
  '55-65': 0.18,
};

/// Retourne le taux de bonification LPP pour un age donne (LPP art. 16).
/// Bonifications stop at reference retirement age 65.
double getLppBonificationRate(int age) {
  if (age > 65 || age < 25) return 0.0;
  if (age >= 55) return 0.18;
  if (age >= 45) return 0.15;
  if (age >= 35) return 0.10;
  return 0.07;
}

// ══════════════════════════════════════════════════════════════════════════════
// AVS — Assurance-vieillesse et survivants (1er pilier)
// Base legale: LAVS art. 34-40
// ══════════════════════════════════════════════════════════════════════════════

/// Rente AVS maximale individuelle mensuelle (LAVS art. 34).
const double avsRenteMaxMensuelle = 2520.0;

/// Rente AVS minimale individuelle mensuelle (= 50% de la rente max).
const double avsRenteMinMensuelle = 1260.0;

/// Rente AVS maximale pour un couple mensuelle (= 150% de la rente max).
const double avsRenteCoupleMaxMensuelle = 3780.0;

/// Taux de cotisation AVS part salarie: 5.3%.
const double avsCotisationSalarie = 0.053;

/// Taux de cotisation AVS total (salarie + employeur): 10.6%.
const double avsCotisationTotal = 0.106;

/// Nombre d'annees de cotisation pour une rente complete.
const int avsDureeCotisationComplete = 44;

/// Age de reference AVS hommes.
const int avsAgeReferenceHomme = 65;

/// Age de reference AVS femmes (depuis reforme AVS 21).
const int avsAgeReferenceFemme = 65;

/// AVS21 reference age by gender and birth year (LAVS art. 21 al. 1).
///
/// Women born 1961-1963 have transitional reference ages:
/// - Born 1960 or earlier: 64 (pre-AVS21)
/// - Born 1961: 64 years 3 months (simplified to 64 for annual calc)
/// - Born 1962: 64 years 6 months (simplified to 64 for annual calc)
/// - Born 1963: 64 years 9 months (simplified to 65 for annual calc)
/// - Born 1964+: 65 (full AVS21 alignment)
/// Men: 65 (unchanged).
int avsReferenceAge({required int birthYear, required bool isFemale}) {
  if (!isFemale) return avsAgeReferenceHomme; // 65
  if (birthYear <= 1960) return 64;
  if (birthYear == 1961) return 64; // +3 months (simplified to 64)
  if (birthYear == 1962) return 64; // +6 months (simplified to 64)
  if (birthYear == 1963) return 65; // +9 months (simplified to 65)
  return avsAgeReferenceFemme; // 65
}

/// Reduction par annee d'anticipation de la rente AVS: 6.8%.
const double avsReductionAnticipation = 0.068;

/// Rente AVS maximale individuelle annuelle, base 12 mois (= avsRenteMaxMensuelle x 12).
///
/// Ne contient PAS la 13eme rente. Utiliser [avsRenteMaxAnnuelle13m] ou
/// [avsMaxAnnualRenteForYear] pour une projection year-aware.
const double avsRenteMaxAnnuelle = 30240.0;

/// Rente AVS maximale individuelle annuelle avec 13eme rente (= avsRenteMaxMensuelle x 13).
///
/// Active a partir de [avs13emeRenteAnneeDebut] (decembre 2026, LAVS art. 34 nouveau).
const double avsRenteMaxAnnuelle13m = 32760.0;

/// Return the AVS max annual rente for [year], accounting for the 13th
/// pension that becomes effective from [avs13emeRenteAnneeDebut].
///
/// 2025 and earlier → 30'240 (12 months)
/// 2026 and later  → 32'760 (13 months)
double avsMaxAnnualRenteForYear(int year) {
  if (avs13emeRenteActive && year >= avs13emeRenteAnneeDebut) {
    return avsRenteMaxAnnuelle13m;
  }
  return avsRenteMaxAnnuelle;
}

/// Cotisation AVS minimale annuelle pour independants (LAVS art. 8).
const double avsCotisationMinIndependant = 530.0;

/// Bonus par annee d'ajournement de la rente AVS (LAVS art. 39).
const Map<int, double> avsDeferralBonus = {
  1: 0.052, // +5.2%
  2: 0.106, // +10.6%
  3: 0.164, // +16.4%
  4: 0.227, // +22.7%
  5: 0.315, // +31.5%
};

/// RAMD minimum pour rente minimale (LAVS art. 34, echelle 44).
const double avsRAMDMin = 14700.0;

/// RAMD maximum pour rente maximale (LAVS art. 34, echelle 44).
const double avsRAMDMax = 88200.0;

/// Echelle 44 complete (OFAS 2025) — fallback when backend is unreachable.
/// Format: [[RAMD, rente_mensuelle], ...].
/// Updated every 2 years by Federal Council (mixed index).
/// Source: LAVS art. 34, OFAS tables de rentes 2023/2025.
const List<List<double>> avsEchelle44 = [
  [14700, 1260],
  [17640, 1299],
  [20580, 1338],
  [23520, 1377],
  [26460, 1416],
  [29400, 1470],
  [32340, 1524],
  [35280, 1578],
  [38220, 1632],
  [41160, 1686],
  [44100, 1743],
  [47040, 1800],
  [49980, 1857],
  [52920, 1914],
  [55860, 1971],
  [58800, 2028],
  [61740, 2085],
  [64680, 2142],
  [67620, 2199],
  [70560, 2256],
  [73500, 2313],
  [76440, 2370],
  [79380, 2427],
  [82320, 2462],
  [85260, 2491],
  [88200, 2520],
];

/// Franchise AVS pour retraites actifs, mensuelle.
const double avsFranchiseRetraiteMensuelle = 1400.0;

/// Facteur rente de survivant (80% de la rente du defunt).
const double avsSurvivorFactor = 0.80;

// 13eme rente AVS (initiative populaire adoptee en mars 2024)
// Versement: une fois par an en decembre, a partir de decembre 2026.
// Montant = 1/12 de la somme annuelle des rentes vieillesse versees.
// Uniquement rentes de vieillesse (pas AI, pas survivants, pas enfants).
// Base legale: LAVS art. 34 (nouveau), art. constitutionnel 112 al. 4bis.

/// 13eme rente AVS active. True des 2026 (premier versement decembre 2026).
const bool avs13emeRenteActive = true;

/// Annee du premier versement de la 13eme rente AVS.
const int avs13emeRenteAnneeDebut = 2026;

/// Nombre de rentes mensuelles par an (12 standard + 1 treizieme).
const int avsNombreRentesParAn = 13;

/// Facteur multiplicateur pour convertir la rente annuelle 12 mois en 13 mois.
/// Rente annuelle effective = rente mensuelle x 12 x avs13emeRenteFactor
///                          = rente mensuelle x 13.
const double avs13emeRenteFactor = 13.0 / 12.0;

/// Cotisation annuelle minimale AVS volontaire (expatries).
const double avsVolontaireCotisationMin = 514.0;

/// Cotisation annuelle maximale AVS volontaire.
const double avsVolontaireCotisationMax = 25700.0;

// ══════════════════════════════════════════════════════════════════════════════
// AI — Assurance-invalidite
// ══════════════════════════════════════════════════════════════════════════════

/// Taux de cotisation AI part salarie: 0.7%.
const double aiCotisationSalarie = 0.007;

/// Rente AI entiere mensuelle (= rente AVS max). Degre invalidite >= 70%.
const double aiRenteEntiere = 2520.0;

/// Demi-rente AI mensuelle. Degre invalidite 50-69%.
const double aiRenteDemi = 1260.0;

/// Delai moyen de decision AI depuis depot de la demande (LAI art. 28 + LPGA art. 19).
/// Valeur empirique: 12-18 mois selon le canton; 14 mois en mediane.
const int aiDecisionDelayMonths = 14;

// ══════════════════════════════════════════════════════════════════════════════
// APG — Allocations pour perte de gain
// ══════════════════════════════════════════════════════════════════════════════

/// Taux de cotisation APG part salarie: 0.25%.
const double apgCotisationSalarie = 0.0025;

/// Duree du conge maternite: 98 jours = 14 semaines.
const int apgMaterniteJours = 98;

/// Taux d'indemnite de maternite: 80% du salaire.
const double apgMaterniteTaux = 0.80;

/// Duree du conge paternite: 10 jours.
const int apgPaterniteJours = 10;

// ══════════════════════════════════════════════════════════════════════════════
// AC — Assurance-chomage
// Base legale: LACI
// ══════════════════════════════════════════════════════════════════════════════

/// Plafond du salaire assure AC (LACI art. 3).
const double acPlafondSalaireAssure = 148200.0;

/// Taux de cotisation AC part salarie: 1.1%.
const double acCotisationSalarie = 0.011;

/// Cotisation de solidarite AC part salarie: 0.5% (au-dessus du plafond).
const double acCotisationSolidariteSalarie = 0.005;

/// Taux d'indemnite chomage standard: 70%.
const double acIndemniteTaux = 0.70;

/// Taux d'indemnite chomage avec charges de famille: 80%.
const double acIndemniteTauxChargeFamille = 0.80;

/// Duree maximale des indemnites de chomage (LACI art. 27 al. 2).
///
/// La duree depend de la periode de cotisation ET de l'age.
/// Les valeurs ci-dessous correspondent au cas standard (>= 22 mois de cotisation).
/// Pour des periodes courtes (12-17 mois → 200j, 18-21 mois → 260j).

/// < 22 mois de cotisation (typiquement < 25 ans en debut de carriere).
const int acJoursMinCotisation = 200;

/// 18-21 mois de cotisation (cas intermediaire).
const int acJoursIntermediaireCotisation = 260;

/// >= 22 mois de cotisation, age < 55 ans (LACI art. 27 al. 2 lit. c).
const int acJoursStandard = 400;

/// >= 22 mois de cotisation, age >= 55 ans (LACI art. 27 al. 2 lit. d).
const int acJoursSenior = 520;

/// Age de reference pour le taux senior AC: 55 ans (LACI art. 27 al. 2 lit. d).
const int acAgeSeuillSenior = 55;

// ══════════════════════════════════════════════════════════════════════════════
// Pilier 3a — Prevoyance individuelle liee
// Base legale: OPP3 art. 7
// ══════════════════════════════════════════════════════════════════════════════

/// Plafond annuel 3a pour salaries affilies a la LPP (petit 3a).
const double pilier3aPlafondAvecLpp = 7258.0;

/// Plafond annuel 3a pour independants sans LPP (grand 3a).
const double pilier3aPlafondSansLpp = 36288.0;

/// Part du revenu determinant pour le grand 3a: 20%.
const double pilier3aTauxRevenuSansLpp = 0.20;

// ══════════════════════════════════════════════════════════════════════════════
// Cotisations totales salarie (resume)
// ══════════════════════════════════════════════════════════════════════════════

/// Total cotisations sociales part salarie (hors LPP): 6.4%.
///
/// avsCotisationSalarie (5.3%) = combined AVS (4.35%) + AI (0.70%) + APG (0.25%)
/// — matching OFAS "taux AVS/AI/APG" (10.6% total, 5.3% per side).
/// aiCotisationSalarie & apgCotisationSalarie are kept separately for
/// disability-gap and APG-specific calculations, but must NOT be added again here.
const double cotisationsSalarieTotal =
    avsCotisationSalarie + acCotisationSalarie;

// ══════════════════════════════════════════════════════════════════════════════
// Impot sur retrait de capital (2e/3e pilier) — par canton
// Base legale: LIFD art. 38, legislations fiscales cantonales
// Miroir exact de: services/backend/app/constants/social_insurance.py
// ══════════════════════════════════════════════════════════════════════════════

/// Taux de base de l'impot sur le retrait de capital par canton.
/// Inclut LIFD + impot cantonal + impot communal (chef-lieu).
const Map<String, double> tauxImpotRetraitCapital = {
  'ZH': 0.065, 'BE': 0.075, 'LU': 0.055, 'UR': 0.050,
  'SZ': 0.040, 'OW': 0.045, 'NW': 0.040, 'GL': 0.055,
  'ZG': 0.035, 'FR': 0.070, 'SO': 0.065, 'BS': 0.075,
  'BL': 0.065, 'SH': 0.060, 'AR': 0.055, 'AI': 0.045,
  'SG': 0.060, 'GR': 0.055, 'AG': 0.060, 'TG': 0.055,
  'TI': 0.065, 'VD': 0.080, 'VS': 0.060, 'NE': 0.070,
  'GE': 0.075, 'JU': 0.065,
};

/// Tranches progressives pour l'impot sur retrait de capital.
/// Format: [seuil_bas, seuil_haut, multiplicateur].
const List<List<double>> retraitCapitalTranches = [
  [0, 100000, 1.00],
  [100000, 200000, 1.15],
  [200000, 500000, 1.30],
  [500000, 1000000, 1.50],
  [1000000, double.infinity, 1.70],
];

/// Reduction d'impot pour les couples maries (splitting cantonal).
/// Les maries paient ~15% de moins sur le retrait en capital.
const double marriedCapitalTaxDiscount = 0.85;

/// Noms complets des 26 cantons suisses en francais.
const Map<String, String> cantonFullNames = {
  'AG': 'Argovie', 'AI': 'Appenzell RI', 'AR': 'Appenzell RE',
  'BE': 'Berne', 'BL': 'Bale-Campagne', 'BS': 'Bale-Ville',
  'FR': 'Fribourg', 'GE': 'Geneve', 'GL': 'Glaris',
  'GR': 'Grisons', 'JU': 'Jura', 'LU': 'Lucerne',
  'NE': 'Neuchatel', 'NW': 'Nidwald', 'OW': 'Obwald',
  'SG': 'Saint-Gall', 'SH': 'Schaffhouse', 'SO': 'Soleure',
  'SZ': 'Schwyz', 'TG': 'Thurgovie', 'TI': 'Tessin',
  'UR': 'Uri', 'VD': 'Vaud', 'VS': 'Valais',
  'ZG': 'Zoug', 'ZH': 'Zurich',
};

/// Codes des 26 cantons tries alphabetiquement.
const List<String> sortedCantonCodes = [
  'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
  'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
  'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
];

// ══════════════════════════════════════════════════════════════════════════════
// EPL — Encouragement a la propriete du logement
// Base legale: LPP art. 30c, OPP2 art. 5
// ══════════════════════════════════════════════════════════════════════════════

/// Montant minimum pour un retrait EPL (OPP2 art. 5).
const double eplMontantMinimum = 20000.0;

/// Delai de blocage des rachats LPP apres un retrait EPL (LPP art. 79b al. 3).
const int eplBlocageRachatAnnees = 3;

// ══════════════════════════════════════════════════════════════════════════════
// Hypotheque — Pratique bancaire suisse (ASB / FINMA)
// ══════════════════════════════════════════════════════════════════════════════

/// Taux d'interet theorique pour le calcul de capacite (Tragbarkeitsrechnung).
const double hypothequeTauxTheorique = 0.05;

/// Taux d'amortissement annuel minimum (pratique standard).
const double hypothequeTauxAmortissement = 0.01;

/// Taux de frais accessoires annuels (entretien, assurance).
const double hypothequeTauxFraisAccessoires = 0.01;

/// Taux de charges theoriques combines (interet + amortissement + frais).
/// 5% + 1% + 1% = 7%.
const double hypothequeTauxChargesTotal = 0.07;

/// Ratio maximal des charges par rapport au revenu brut (regle du 1/3).
const double hypothequeRatioChargesMax = 1.0 / 3.0;

/// Part minimale de fonds propres (20% du prix d'achat).
const double hypothequeFondsPropresMin = 0.20;

/// Part maximale du 2e pilier dans les fonds propres (10% du prix d'achat).
const double hypothequePart2ePilierMax = 0.10;

// ══════════════════════════════════════════════════════════════════════════════
// LAMal — Assurance-maladie obligatoire
// Base legale: LAMal art. 64
// ══════════════════════════════════════════════════════════════════════════════

/// Quote-part maximale annuelle LAMal pour adultes (LAMal art. 64 al. 2).
/// Adultes >= 26 ans: 700 CHF/an.
const double lamalQuotePartMax = 700.0;

/// Quote-part maximale annuelle LAMal pour jeunes adultes 19-25 ans.
const double lamalQuotePartMaxJeunesAdultes = 350.0;

// ══════════════════════════════════════════════════════════════════════════════
// Pilier 3a — Rattrapage retroactif (nouveau droit 2026+)
// Base legale: OPP3 art. 7 (amendement 2026), OFAS publications annuelles
// ══════════════════════════════════════════════════════════════════════════════

/// Plafonds historiques 3a (avec LPP) par annee.
/// Utilises pour calculer le montant de rattrapage retroactif.
/// Source: OFAS publications annuelles, OPP3 art. 7.
const Map<int, double> pilier3aHistoricalLimits = {
  2026: 7258.0,
  2025: 7258.0,
  2024: 7056.0,
  2023: 6883.0,
  2022: 6826.0,
  2021: 6826.0,
  2020: 6826.0,
  2019: 6826.0,
  2018: 6826.0,
  2017: 6768.0,
  2016: 6768.0,
};

/// Nombre maximum d'annees de rattrapage retroactif 3a (OPP3 art. 7, amendement 2026).
const int pilier3aMaxRetroactiveYears = 10;

// ══════════════════════════════════════════════════════════════════════════════
// Financial Fitness Score (FRI) — Seuils d'affichage
// Utilises pour la colorisation et les labels dans tous les ecrans.
// ══════════════════════════════════════════════════════════════════════════════

/// FRI >= 80 : Excellent (vert fonce)
const int friThresholdExcellent = 80;

/// FRI >= 60 : Bon (vert)
const int friThresholdBon = 60;

/// FRI >= 40 : Attention (orange)
const int friThresholdAttention = 40;

// ══════════════════════════════════════════════════════════════════════════════
// Echelle 44 — Table officielle OFAS (rentes mensuelles AVS/AI)
// Base legale: LAVS art. 34, Memento 6.01 — Tables des rentes AVS/AI (OFAS 2025)
// ══════════════════════════════════════════════════════════════════════════════

// avsEchelle44 — defined above (line ~169). Do not duplicate.

// ══════════════════════════════════════════════════════════════════════════════
// Projection — Hypothèses par défaut
// Utilisées par RetirementProjectionService et d'autres services de projection.
// ══════════════════════════════════════════════════════════════════════════════

/// Taux d'indexation annuel des rentes AVS (hypothèse éducative).
/// Historiquement ~1% par an (ajustement indice mixte prix/salaires).
const double avsIndexationRate = 0.01;

/// Taux d'inflation annuel par défaut (hypothèse éducative).
/// Moyenne historique suisse longue période ~1-1.5%.
const double defaultInflationRate = 0.015;

/// Espérance de vie par défaut utilisée pour les projections de retraite.
/// OFS 2023: hommes ~82, femmes ~85. Valeur prudente pour planification.
const int defaultLifeExpectancy = 87;

/// Taux de retrait sûr (Safe Withdrawal Rate) par défaut.
/// Règle des 4% — Trinity Study adapté au contexte suisse.
const double defaultSafeWithdrawalRate = 0.04;

/// Gain assuré mensuel maximum AC (LACI art. 3).
/// = acPlafondSalaireAssure / 12.
/// Utilisé par UnemploymentService pour plafonner le gain assuré.
const double acGainAssureMensuelMax = acPlafondSalaireAssure / 12;

/// Seuil de salaire mensuel pour le taux majoré d'indemnités chômage (LACI art. 22).
/// En dessous de ce seuil, taux 80% au lieu de 70%.
const double acSeuilSalaireMajore = 3797.0;
