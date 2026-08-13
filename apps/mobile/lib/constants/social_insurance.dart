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

/// Taux d'intérêt minimal LPP en RATIO (beads -b6k) — la clé registre
/// `lpp.min_interest_rate` et le fallback [lppTauxInteretMin] sont en
/// POURCENT (1.25) : la conversion /100 vit ici, une seule fois, pour
/// que cache et fallback rendent le même 0.0125.
double lppMinInterestRatio() =>
    reg('lpp.min_interest_rate', lppTauxInteretMin) / 100;

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

/// Rente AVS maximale individuelle annuelle, base 12 mois.
///
/// Derived from [avsRenteMaxMensuelle] so the 12m and 13m caps cannot drift
/// out of sync with the monthly figure. Ne contient PAS la 13eme rente —
/// utiliser [avsRenteMaxAnnuelle13m] ou [avsMaxAnnualRenteForYear] pour une
/// projection year-aware.
const double avsRenteMaxAnnuelle = avsRenteMaxMensuelle * 12;

/// Rente AVS maximale individuelle annuelle avec 13eme rente.
///
/// Derived from [avsRenteMaxMensuelle]; active a partir de
/// [avs13emeRenteAnneeDebut] (decembre 2026, LAVS art. 34 nouveau).
const double avsRenteMaxAnnuelle13m = avsRenteMaxMensuelle * 13;

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

/// Seuil de revenu sous lequel la cotisation minimale FIXE s'applique
/// (LAVS art. 8 al. 2). Le bareme degressif RAVS art. 21 commence ici.
const double avsSeuilRevenuMinIndependant = 10100.0;

/// Bonus par annee d'ajournement de la rente AVS (LAVS art. 39).
// Mémento OFAS 3.04 « Flexibilisation de la retraite » (audit -zaw).
const Map<int, double> avsDeferralBonus = {
  1: 0.052, // +5.2%
  2: 0.108, // +10.8%
  3: 0.171, // +17.1%
  4: 0.240, // +24.0%
  5: 0.315, // +31.5%
};

/// RAMD minimum pour rente minimale (LAVS art. 34, echelle 44).
const double avsRAMDMin = 15120.0;

/// RAMD maximum pour rente maximale (LAVS art. 34, echelle 44).
const double avsRAMDMax = 90720.0;

/// Échelle 44 complète — fallback quand le backend est injoignable.
/// Format : [[RAMD « jusqu'à », rente mensuelle], ...]. 51 paliers, pas 1'512.
/// Source : OFAS doc 318.117.011 « Tables des rentes 2025 » p. 20, valable dès
/// 1.1.2025 et inchangé en 2026 (audit -zaw 2026-07-23 : l'ancienne table
/// mélangeait des bornes RAMD 2023/24 avec les rentes 2025 — écarts jusqu'à
/// 102 fr./mois, ex. RAMD 52'920 rendait 1'914 au lieu de 2'016).
const List<List<double>> avsEchelle44 = [
  [15120, 1260],
  [16632, 1293],
  [18144, 1326],
  [19656, 1358],
  [21168, 1391],
  [22680, 1424],
  [24192, 1457],
  [25704, 1489],
  [27216, 1522],
  [28728, 1555],
  [30240, 1588],
  [31752, 1620],
  [33264, 1653],
  [34776, 1686],
  [36288, 1719],
  [37800, 1751],
  [39312, 1784],
  [40824, 1817],
  [42336, 1850],
  [43848, 1882],
  [45360, 1915],
  [46872, 1935],
  [48384, 1956],
  [49896, 1976],
  [51408, 1996],
  [52920, 2016],
  [54432, 2036],
  [55944, 2056],
  [57456, 2076],
  [58968, 2097],
  [60480, 2117],
  [61992, 2137],
  [63504, 2157],
  [65016, 2177],
  [66528, 2197],
  [68040, 2218],
  [69552, 2238],
  [71064, 2258],
  [72576, 2278],
  [74088, 2298],
  [75600, 2318],
  [77112, 2339],
  [78624, 2359],
  [80136, 2379],
  [81648, 2399],
  [83160, 2419],
  [84672, 2439],
  [86184, 2460],
  [87696, 2480],
  [89208, 2500],
  [90720, 2520],
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
const double avsVolontaireCotisationMin = 530.0;

/// Cotisation annuelle maximale AVS volontaire.
const double avsVolontaireCotisationMax = 26500.0;

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

/// Cotisation de solidarite AC part salarie: 0% depuis le 1.1.2023 (pour-cent
/// de solidarite aboli, fonds AC > 2,5 Mrd CHF fin 2022 -> LACI art. 90c al. 4).
const double acCotisationSolidariteSalarie = 0.0;

/// Taux d'indemnite chomage standard: 70%.
const double acIndemniteTaux = 0.70;

/// Taux d'indemnite chomage avec charges de famille: 80%.
const double acIndemniteTauxChargeFamille = 0.80;

/// Durée maximale des indemnités de chômage — barème OFFICIEL LACI art. 27.
///
/// Audit -zaw / beads MINT_nosync-4za : l'ancien bloc était sémantiquement
/// faux de bout en bout (200 attribué à « < 22 mois », 260 à « 18-21 mois »,
/// 400 à « >= 22 mois ») et avait induit un mapping mois→jours erroné dans
/// unemployment_service (18 mois servaient 260 jours au lieu de 400).
/// Barème réel (LACI art. 27, Directive LACI IC SECO) :
///   12 mois de cotisation  → 260 jours (al. 2 let. a)
///   18 mois de cotisation  → 400 jours (al. 2 let. b)
///   22 mois ET (âge >= 55 OU invalidité >= 40 %) → 520 jours (al. 2 let. c)
///   < 25 ans SANS obligation d'entretien → plafond 200 jours (al. 5bis)

/// Plafond jeunes : < 25 ans sans obligation d'entretien (LACI art. 27).
const int acJoursPlafondJeunes = 200;

/// 12 mois de cotisation → 260 jours (LACI art. 27 al. 2 let. a).
const int acJours12MoisCotisation = 260;

/// 18 mois de cotisation → 400 jours (LACI art. 27 al. 2 let. b).
const int acJours18MoisCotisation = 400;

/// 22 mois de cotisation ET (âge >= 55 OU invalidité >= 40 %) → 520 jours
/// (LACI art. 27 al. 2 let. c).
const int acJours22MoisSenior = 520;

/// Âge charnière pour les 520 jours : 55 ans (LACI art. 27 al. 2 let. c).
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
  'ZH': 0.065,
  'BE': 0.075,
  'LU': 0.055,
  'UR': 0.050,
  'SZ': 0.040,
  'OW': 0.045,
  'NW': 0.040,
  'GL': 0.055,
  'ZG': 0.035,
  'FR': 0.070,
  'SO': 0.065,
  'BS': 0.075,
  'BL': 0.065,
  'SH': 0.060,
  'AR': 0.055,
  'AI': 0.045,
  'SG': 0.060,
  'GR': 0.055,
  'AG': 0.060,
  'TG': 0.055,
  'TI': 0.065,
  'VD': 0.080,
  'VS': 0.060,
  'NE': 0.070,
  'GE': 0.075,
  'JU': 0.065,
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

/// Impôt capital MARIÉ : le rabais forfaitaire par canton (inventé) a été
/// SUPPRIMÉ (triage AnnAssign #1095). La part cantonale mariée est désormais
/// interpolée sur l'étalon ESTV `cantonalCapitalTaxMarriedChf`
/// (financial_core/income_tax_model_v2.dart), miroir du backend
/// `CANTONAL_CAPITAL_TAX_MARRIED_CHF` — comme le célibataire, plus de
/// coefficient plat.

/// Noms complets des 26 cantons suisses en francais.
const Map<String, String> cantonFullNames = {
  'AG': 'Argovie', 'AI': 'Appenzell RI', 'AR': 'Appenzell RE', // lint-ignore
  'BE': 'Berne', 'BL': 'Bâle-Campagne', 'BS': 'Bâle-Ville', // lint-ignore
  'FR': 'Fribourg', 'GE': 'Genève', 'GL': 'Glaris', // lint-ignore
  'GR': 'Grisons', 'JU': 'Jura', 'LU': 'Lucerne', // lint-ignore
  'NE': 'Neuchâtel', 'NW': 'Nidwald', 'OW': 'Obwald', // lint-ignore
  'SG': 'Saint-Gall', 'SH': 'Schaffhouse', 'SO': 'Soleure', // lint-ignore
  'SZ': 'Schwyz', 'TG': 'Thurgovie', 'TI': 'Tessin', // lint-ignore
  'UR': 'Uri', 'VD': 'Vaud', 'VS': 'Valais', // lint-ignore
  'ZG': 'Zoug', 'ZH': 'Zurich', // lint-ignore
};

/// Codes des 26 cantons tries alphabetiquement.
/// Nom du canton précédé de sa préposition française. « Canton de Argovie »
/// est la faute qui trahit une phrase assemblée par une machine ; le français
/// demande « d'Argovie », « du Valais », « des Grisons ».
const Map<String, String> cantonWithArticle = {
  'AG': "d'Argovie", 'AI': "d'Appenzell Rhodes-Intérieures", // lint-ignore
  'AR': "d'Appenzell Rhodes-Extérieures", 'BE': 'de Berne', // lint-ignore
  'BL': 'de Bâle-Campagne', 'BS': 'de Bâle-Ville',  // lint-ignore
  'FR': 'de Fribourg', // lint-ignore
  'GE': 'de Genève', 'GL': 'de Glaris', 'GR': 'des Grisons',  // lint-ignore
  'JU': 'du Jura', // lint-ignore
  'LU': 'de Lucerne', 'NE': 'de Neuchâtel', 'NW': 'de Nidwald', // lint-ignore
  'OW': "d'Obwald", 'SG': 'de Saint-Gall',  // lint-ignore
  'SH': 'de Schaffhouse', // lint-ignore
  'SO': 'de Soleure', 'SZ': 'de Schwytz', 'TG': 'de Thurgovie', // lint-ignore
  'TI': 'du Tessin', 'UR': "d'Uri", 'VD': 'de Vaud',  // lint-ignore
  'VS': 'du Valais', // lint-ignore
  'ZG': 'de Zoug', 'ZH': 'de Zurich', // lint-ignore
};

const List<String> sortedCantonCodes = [
  'AG',
  'AI',
  'AR',
  'BE',
  'BL',
  'BS',
  'FR',
  'GE',
  'GL',
  'GR',
  'JU',
  'LU',
  'NE',
  'NW',
  'OW',
  'SG',
  'SH',
  'SO',
  'SZ',
  'TG',
  'TI',
  'UR',
  'VD',
  'VS',
  'ZG',
  'ZH',
];

/// Fallback canton code utilisé quand l'utilisateur n'a pas encore
/// renseigné le sien. Exposé pour que les consommateurs puissent
/// afficher un badge « donnée estimée — canton par défaut » à l'UI
/// (protection-first : ne pas mentir sur la source).
const String cantonFallbackDefault = 'ZH';

/// Résultat de [resolveCanton] : le code normalisé et une indication
/// de sa provenance.
class ResolvedCanton {
  final String code;
  final bool isResolved;
  final String? rawInput;

  const ResolvedCanton({
    required this.code,
    required this.isResolved,
    this.rawInput,
  });

  /// `true` quand le canton vient de l'utilisateur et est valide.
  /// Les consommateurs DOIVENT afficher un disclaimer quand
  /// `isResolved` est `false` (CLAUDE.md §6 information obligations).
  bool get isFallback => !isResolved;
}

/// Normalise un canton et valide contre les 26 cantons suisses.
///
/// Wave 7 edge-case audit C1 (2026-04-18) : chaque simulateur
/// retombait indépendamment sur 'ZH' quand `canton` était null, vide
/// ou invalide, sans jamais le signaler à l'UI. Un utilisateur VS
/// voyait silencieusement une fiscalité ZH (rates ZG 0.70 vs VS 0.81
/// = écart ~15 %, ZH 0.73 = écart ~10 %). Cette version :
///
/// 1. Uppercase + trim le code.
/// 2. Refuse codes vides ou non-listés → retombe sur le fallback.
/// 3. Exposé la provenance via `ResolvedCanton.isFallback` pour que
///    l'UI et le coach puissent router vers une enrichment prompt
///    "quel canton ?" au lieu d'afficher une projection inexacte.
/// 4. Log un avertissement en debug mode pour faire remonter les
///    sites d'appel qui devraient toujours avoir un canton valide.
ResolvedCanton resolveCanton(String? raw) {
  if (raw == null) {
    assert(() {
      // ignore: avoid_print
      print('[resolveCanton] null canton — falling back to '
          '$cantonFallbackDefault. Caller should pass profile.canton.');
      return true;
    }());
    return const ResolvedCanton(
      code: cantonFallbackDefault,
      isResolved: false,
    );
  }
  final trimmed = raw.trim().toUpperCase();
  if (trimmed.isEmpty) {
    return ResolvedCanton(
      code: cantonFallbackDefault,
      isResolved: false,
      rawInput: raw,
    );
  }
  if (!sortedCantonCodes.contains(trimmed)) {
    assert(() {
      // ignore: avoid_print
      print('[resolveCanton] unknown canton "$raw" — falling back to '
          '$cantonFallbackDefault. Expected one of $sortedCantonCodes.');
      return true;
    }());
    return ResolvedCanton(
      code: cantonFallbackDefault,
      isResolved: false,
      rawInput: raw,
    );
  }
  return ResolvedCanton(code: trimmed, isResolved: true, rawInput: raw);
}

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
// Pilier 3a — Rattrapage rétroactif (OPP3 art. 7a)
// Base légale : OPP3 art. 7a nouveau, RO 2024 687, entrée en vigueur 01.01.2025.
// swiss-brain ruling 2026-04-18 Q1 :
//   * SEULES les lacunes postérieures au 31.12.2024 sont rachetables.
//   * Les plafonds 2016-2024 NE SONT JAMAIS rachetables — pas de table
//     historique stockée côté client (elle induit en erreur).
//   * Le nombre d'années rachetables en année N = min(10, N - 2024).
//     En 2026 : 2 ans max (2025 + 2026 partiel). En 2035+ : 10 permanent.
//   * Le plafond appliqué au rachat est celui de L'ANNÉE DU RACHAT
//     (art. 7a al. 2), pas de l'année manquée.
// ══════════════════════════════════════════════════════════════════════════════

/// Plafond 3a salarié avec LPP — déjà défini plus haut (7258 CHF en 2026).
/// C'est ce plafond (de l'année du rachat) qui s'applique à chaque année
/// rachetée, PAS un plafond historique.
///
/// Map conservée pour compat code mais réduite aux années 2025+ (seules
/// rachetables). Les valeurs 2025 et 2026 sont identiques par design
/// fédéral (le plafond suit l'indexation OFAS mais n'a pas changé sur
/// la courte fenêtre). À jour au 06.11.2024.
const Map<int, double> pilier3aHistoricalLimits = {
  2025: 7258.0,
  2026: 7258.0,
};

/// Nombre maximum d'années rachetables dans le futur (cap légal à 10 ans
/// d'historique atteint en 2035). En attendant, la fenêtre effective
/// est calculée dynamiquement par `retroactive_3a_calculator.dart` en
/// `referenceYear - 2024`.
const int pilier3aMaxRetroactiveYears = 10;

/// Première année fiscale éligible au rachat rétroactif (entrée en vigueur
/// OPP3 art. 7a, RO 2024 687).
const int pilier3aRetroactiveFirstEligibleYear = 2025;

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

// ══════════════════════════════════════════════════════════════════════════════
// OFS — Statistique suisse des salaires (ESS)
// Repères descriptifs du marché du travail (PAS des valeurs fiscales/légales).
// ══════════════════════════════════════════════════════════════════════════════

/// Salaire mensuel brut médian suisse, équivalent plein temps, tous secteurs.
/// Source: OFS/ESS 2022, publiée 2024, secteurs privé et public confondus.
/// Repère descriptif de l'ensemble de la population active — ce n'est PAS un
/// salaire d'entrée. À dater à l'écran (millésime visible, D11).
const double ofsSalaireMedianMensuelBrut = 6788.0;
