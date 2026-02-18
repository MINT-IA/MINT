/// Constantes d'assurances sociales suisses — source unique de verite (Flutter).
///
/// Valeurs en vigueur: 2025
/// Derniere mise a jour: 2025-01-01
///
/// IMPORTANT: Ce fichier est le miroir exact de:
///   services/backend/app/constants/social_insurance.py
///
/// Procedure de mise a jour annuelle:
/// 1. Mettre a jour le fichier Python (source de verite backend)
/// 2. Reporter les memes valeurs ici
/// 3. Lancer les tests Flutter: flutter test
library;

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
double getLppBonificationRate(int age) {
  if (age >= 55) return 0.18;
  if (age >= 45) return 0.15;
  if (age >= 35) return 0.10;
  if (age >= 25) return 0.07;
  return 0.0;
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

/// Reduction par annee d'anticipation de la rente AVS: 6.8%.
const double avsReductionAnticipation = 0.068;

/// Franchise AVS pour retraites actifs, mensuelle.
const double avsFranchiseRetraiteMensuelle = 1400.0;

/// Facteur rente de survivant (80% de la rente du defunt).
const double avsSurvivorFactor = 0.80;

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

/// Total cotisations sociales part salarie (hors LPP): 7.35%.
const double cotisationsSalarieTotal =
    avsCotisationSalarie + aiCotisationSalarie + apgCotisationSalarie + acCotisationSalarie;

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
