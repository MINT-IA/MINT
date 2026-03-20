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

/// Taux de conversion minimum LPP en fraction decimale (0.068 = 6.8%).
/// S'applique UNIQUEMENT a la part obligatoire (LPP art. 14 al. 2).
/// Ne jamais appliquer implicitement sur tout le capital LPP.
const double lppTauxConversionMinDecimal = 0.068;

/// Taux de conversion estime pour la part surobligatoire LPP.
/// Estimation mediane 2025/2026 des caisses suisses (fourchette 4.8%-6.0%).
/// Utilise comme fallback quand le certificat LPP ne precise pas le taux enveloppant.
const double lppTauxConversionSurobligDecimal = 0.054;

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

/// Rente AVS maximale individuelle annuelle (= avsRenteMaxMensuelle x 12).
const double avsRenteMaxAnnuelle = 30240.0;

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
