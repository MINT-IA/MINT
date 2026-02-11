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
