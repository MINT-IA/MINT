import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;

// ============================================================================
// Mortgage Service — Sprint S17 (Hypotheque + Achat immobilier)
//
// Cinq calculateurs pedagogiques pour l'immobilier suisse :
//   A. AffordabilityCalculator   — capacite d'achat (prix max, fonds propres)
//   B. SaronVsFixedCalculator    — comparateur SARON vs taux fixe
//   C. ImputedRentalCalculator   — valeur locative et impact fiscal
//   D. AmortizationCalculator    — amortissement direct vs indirect
//   E. EplCombinedCalculator     — financement EPL multi-sources
//
// Base legale : CO art. 793ss (hypotheques), LIFD, LPP art. 30c (EPL)
// ============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// A. Affordability Calculator — Capacite d'achat
// ─────────────────────────────────────────────────────────────────────────────

/// Resultat du calcul de capacite d'achat
class AffordabilityResult {
  final double prixMaxAccessible;
  final double hypothequeMax;
  final double fondsPropresTotal;
  final double fondsPropresRequis;
  final double chargesTheoriquesMensuelles;
  final double ratioCharges;
  final bool capaciteOk;
  final bool fondsPropresOk;
  final double manqueFondsPropres;
  final String chiffreChocTexte;
  final bool chiffreChocPositif;
  final String disclaimer;

  const AffordabilityResult({
    required this.prixMaxAccessible,
    required this.hypothequeMax,
    required this.fondsPropresTotal,
    required this.fondsPropresRequis,
    required this.chargesTheoriquesMensuelles,
    required this.ratioCharges,
    required this.capaciteOk,
    required this.fondsPropresOk,
    required this.manqueFondsPropres,
    required this.chiffreChocTexte,
    required this.chiffreChocPositif,
    required this.disclaimer,
  });
}

class AffordabilityCalculator {
  /// Calcule la capacite d'achat immobilier.
  ///
  /// Regle du 33% : charges hypothecaires max = 33% du revenu brut annuel.
  /// Charges theoriques = hypotheque x (5% interet theorique + 1% amortissement + 1% frais).
  /// Fonds propres : min 20% du prix, dont max 10% du prix via LPP.
  ///
  /// Base legale : pratique bancaire suisse, directive ASB.
  static AffordabilityResult calculate({
    required double revenuBrutAnnuel,
    required double epargneDispo,
    required double avoir3a,
    required double avoirLpp,
    required double prixAchat,
    required String canton,
  }) {
    // Clamp inputs
    final revenu = revenuBrutAnnuel.clamp(0.0, 1000000.0);
    final epargne = epargneDispo.clamp(0.0, 5000000.0);
    final a3a = avoir3a.clamp(0.0, 1000000.0);
    final lpp = avoirLpp.clamp(0.0, 2000000.0);
    final prix = prixAchat.clamp(0.0, 10000000.0);

    // Prix max basee sur la regle du 1/3 :
    // Charges theoriques = hypotheque x 6% + prix x 1%
    //                    = (prix - FP) x 6% + prix x 1% = prix x 7% - FP x 6%
    // Charges max = revenu x 1/3
    // => prix <= (revenu x 1/3 + FP x 6%) / 7%
    // Aussi : prix <= FP / 20% (contrainte fonds propres)
    final fondsPropresTotal = epargne + a3a + (prix > 0 ? min(lpp, prix * hypothequePart2ePilierMax) : 0.0);
    const tauxChargesSansAccessoires = hypothequeTauxTheorique + hypothequeTauxAmortissement;
    final prixMaxRevenu = revenu > 0
        ? (revenu * hypothequeRatioChargesMax + fondsPropresTotal * tauxChargesSansAccessoires) / hypothequeTauxChargesTotal
        : 0.0;
    final prixMaxEquity = fondsPropresTotal / hypothequeFondsPropresMin;
    final prixMaxAccessible = min(prixMaxRevenu, prixMaxEquity);
    final hypothequeMax = prixMaxAccessible * (1.0 - hypothequeFondsPropresMin);

    // Fonds propres pour le prix demande
    final fondsPropresRequis = prix * hypothequeFondsPropresMin;
    final manqueFondsPropres =
        fondsPropresRequis > fondsPropresTotal
            ? fondsPropresRequis - fondsPropresTotal
            : 0.0;

    // Charges theoriques pour le prix demande
    // interets + amortissement sur hypotheque (6%), frais accessoires sur prix (1%)
    final hypotheque = max(0.0, prix - fondsPropresTotal);
    final chargesAnnuelles = hypotheque * tauxChargesSansAccessoires + prix * hypothequeTauxFraisAccessoires;
    final chargesTheoriquesMensuelles = chargesAnnuelles / 12;
    final ratioCharges =
        revenu > 0 ? chargesAnnuelles / revenu : 1.0;

    final capaciteOk = ratioCharges <= hypothequeRatioChargesMax;
    final fondsPropresOk = fondsPropresTotal >= fondsPropresRequis;

    // Chiffre choc
    String chiffreChocTexte;
    bool chiffreChocPositif;

    if (capaciteOk && fondsPropresOk) {
      chiffreChocTexte =
          'Tu peux acheter jusqu\'a environ CHF ${formatChf(prixMaxAccessible)}';
      chiffreChocPositif = true;
    } else if (!fondsPropresOk) {
      chiffreChocTexte =
          'Il te manque environ CHF ${formatChf(manqueFondsPropres)} de fonds propres';
      chiffreChocPositif = false;
    } else {
      chiffreChocTexte =
          'Tes charges depasseraient ${(ratioCharges * 100).toStringAsFixed(1)}% de ton revenu';
      chiffreChocPositif = false;
    }

    return AffordabilityResult(
      prixMaxAccessible: prixMaxAccessible,
      hypothequeMax: hypothequeMax,
      fondsPropresTotal: fondsPropresTotal,
      fondsPropresRequis: fondsPropresRequis,
      chargesTheoriquesMensuelles: chargesTheoriquesMensuelles,
      ratioCharges: ratioCharges,
      capaciteOk: capaciteOk,
      fondsPropresOk: fondsPropresOk,
      manqueFondsPropres: manqueFondsPropres,
      chiffreChocTexte: chiffreChocTexte,
      chiffreChocPositif: chiffreChocPositif,
      disclaimer:
          'Simulation pédagogique à titre indicatif. La capacité d\'achat '
          'réelle dépend de la politique de crédit de chaque établissement. '
          'Le taux théorique de 5\u00a0% est utilisé pour le calcul de tenue '
          '(pratique ASB), pas le taux réel du marché. '
          'Base légale\u00a0: directive ASB sur le crédit hypothécaire. '
          'Consulte un·e spécialiste avant toute décision.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// B. SARON vs Fixed Calculator — Comparateur hypothecaire
// ─────────────────────────────────────────────────────────────────────────────

/// Point de donnee annuel pour un scenario hypothecaire
class MortgageYearPoint {
  final int annee;
  final double coutAnnuel;
  final double coutCumule;

  const MortgageYearPoint({
    required this.annee,
    required this.coutAnnuel,
    required this.coutCumule,
  });
}

/// Resultat d'une option hypothecaire (fixe ou SARON scenario)
class MortgageOption {
  final String label;
  final double tauxInitial;
  final double coutTotal;
  final List<MortgageYearPoint> annualData;

  const MortgageOption({
    required this.label,
    required this.tauxInitial,
    required this.coutTotal,
    required this.annualData,
  });
}

/// Resultat global du comparateur SARON vs Fixe
class SaronVsFixedResult {
  final MortgageOption fixe;
  final MortgageOption saronStable;
  final MortgageOption saronHausse;
  final double economieSaronStable;
  final String chiffreChocTexte;
  final String disclaimer;

  const SaronVsFixedResult({
    required this.fixe,
    required this.saronStable,
    required this.saronHausse,
    required this.economieSaronStable,
    required this.chiffreChocTexte,
    required this.disclaimer,
  });
}

class SaronVsFixedCalculator {
  /// Taux indicatifs 2026 (moyennes du marche)
  static const Map<int, double> _tauxFixeParDuree = {
    5: 0.0220,
    7: 0.0235,
    10: 0.0250,
    15: 0.0270,
  };

  static const double _tauxSaronBase = 0.0205; // SARON + marge

  /// Compare le cout total d'une hypotheque fixe vs SARON sur [dureeAns].
  ///
  /// Trois scenarios :
  ///   - Fixe : taux constant sur la duree
  ///   - SARON stable : taux SARON constant (optimiste)
  ///   - SARON hausse : taux SARON + 0.25%/an les 3 premieres annees, puis stable
  static SaronVsFixedResult compare({
    required double montantHypothecaire,
    required int dureeAns,
  }) {
    final montant = montantHypothecaire.clamp(100000.0, 5000000.0);
    final duree = dureeAns.clamp(5, 15);
    final tauxFixe = _tauxFixeParDuree[duree] ?? _tauxFixeParDuree[10]!;

    // --- Fixe ---
    final fixeData = <MortgageYearPoint>[];
    double fixeCumule = 0;
    for (int i = 1; i <= duree; i++) {
      final coutAnnuel = montant * tauxFixe;
      fixeCumule += coutAnnuel;
      fixeData.add(MortgageYearPoint(
        annee: i,
        coutAnnuel: coutAnnuel,
        coutCumule: fixeCumule,
      ));
    }

    // --- SARON stable ---
    final saronStableData = <MortgageYearPoint>[];
    double saronStableCumule = 0;
    for (int i = 1; i <= duree; i++) {
      final coutAnnuel = montant * _tauxSaronBase;
      saronStableCumule += coutAnnuel;
      saronStableData.add(MortgageYearPoint(
        annee: i,
        coutAnnuel: coutAnnuel,
        coutCumule: saronStableCumule,
      ));
    }

    // --- SARON hausse (+0.25% / an lineaire, identique au backend) ---
    final saronHausseData = <MortgageYearPoint>[];
    double saronHausseCumule = 0;
    for (int i = 1; i <= duree; i++) {
      final hausseOffset = 0.0025 * (i - 1);
      final taux = _tauxSaronBase + hausseOffset;
      final coutAnnuel = montant * taux;
      saronHausseCumule += coutAnnuel;
      saronHausseData.add(MortgageYearPoint(
        annee: i,
        coutAnnuel: coutAnnuel,
        coutCumule: saronHausseCumule,
      ));
    }

    final economieSaronStable = fixeCumule - saronStableCumule;

    return SaronVsFixedResult(
      fixe: MortgageOption(
        label: 'Fixe $duree ans',
        tauxInitial: tauxFixe,
        coutTotal: fixeCumule,
        annualData: fixeData,
      ),
      saronStable: MortgageOption(
        label: 'SARON stable',
        tauxInitial: _tauxSaronBase,
        coutTotal: saronStableCumule,
        annualData: saronStableData,
      ),
      saronHausse: MortgageOption(
        label: 'SARON hausse',
        tauxInitial: _tauxSaronBase,
        coutTotal: saronHausseCumule,
        annualData: saronHausseData,
      ),
      economieSaronStable: economieSaronStable,
      chiffreChocTexte: economieSaronStable > 0
          ? 'Le SARON stable t\'economise environ CHF ${formatChf(economieSaronStable)} sur $duree ans vs taux fixe'
          : 'Le fixe revient environ CHF ${formatChf(-economieSaronStable)} moins cher sur $duree ans',
      disclaimer:
          'Simulation a titre educatif. Le SARON peut varier a la hausse '
          'comme a la baisse. L\'historique ne garantit pas l\'avenir. '
          'Les taux indicatifs 2026 sont des moyennes de marche et varient '
          'selon les etablissements et le profil emprunteur. '
          'Ne constitue pas un conseil hypothecaire.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// C. Imputed Rental Calculator — Valeur locative
// ─────────────────────────────────────────────────────────────────────────────

/// Resultat du calcul de valeur locative
class ImputedRentalResult {
  final double valeurLocative;
  final double deductionInterets;
  final double deductionFraisEntretien;
  final double deductionAssurance;
  final double totalDeductions;
  final double impactNet;
  final double impotSupplementaire;
  final String chiffreChocTexte;
  final bool chiffreChocPositif;
  final String disclaimer;

  const ImputedRentalResult({
    required this.valeurLocative,
    required this.deductionInterets,
    required this.deductionFraisEntretien,
    required this.deductionAssurance,
    required this.totalDeductions,
    required this.impactNet,
    required this.impotSupplementaire,
    required this.chiffreChocTexte,
    required this.chiffreChocPositif,
    required this.disclaimer,
  });
}

class ImputedRentalCalculator {
  /// Taux de valeur locative par canton (IDENTIQUES au backend).
  /// Pourcentage de la valeur venale utilise pour calculer la valeur locative imposable.
  static const Map<String, double> _tauxValeurLocative = {
    'ZH': 0.035,
    'BE': 0.038,
    'VD': 0.040,
    'GE': 0.045,
    'LU': 0.033,
    'AG': 0.036,
    'SG': 0.034,
    'BS': 0.042,
    'TI': 0.037,
    'VS': 0.035,
    'FR': 0.038,
    'NE': 0.040,
    'JU': 0.039,
    'SO': 0.036,
    'BL': 0.037,
    'GR': 0.034,
    'TG': 0.033,
    'SZ': 0.030,
    'ZG': 0.028,
    'NW': 0.031,
    'OW': 0.032,
    'UR': 0.033,
    'SH': 0.035,
    'AR': 0.034,
    'AI': 0.032,
    'GL': 0.033,
  };

  /// Liste des cantons ordonnes alphabetiquement.
  static List<String> get cantons {
    final list = _tauxValeurLocative.keys.toList();
    list.sort();
    return list;
  }

  /// Calcule l'impact fiscal de la valeur locative.
  ///
  /// valeurLocative = valeurVenale x taux canton
  /// deductions = interets + frais entretien + assurance
  /// impactNet = (valeurLocative - deductions) x tauxMarginal
  ///
  /// Base legale : LIFD art. 21 al. 1 let. b (valeur locative)
  static ImputedRentalResult calculate({
    required double valeurVenale,
    required double interetsAnnuels,
    required double fraisEntretien,
    required String canton,
    required bool bienAncien,
    required double tauxMarginal,
  }) {
    final valeur = valeurVenale.clamp(0.0, 10000000.0);
    final interets = interetsAnnuels.clamp(0.0, 200000.0);
    final taux = _tauxValeurLocative[canton.toUpperCase()] ?? 0.035;
    final marginal = tauxMarginal.clamp(0.15, 0.45);

    // Valeur locative
    final valeurLocative = valeur * taux;

    // Deduction frais d'entretien :
    // Forfait 10% de la valeur locative si bien < 10 ans, 20% si >= 10 ans
    // Ou frais effectifs si plus eleves (LIFD art. 32)
    final forfaitPct = bienAncien ? 0.20 : 0.10;
    final forfaitEntretien = valeurLocative * forfaitPct;
    // On prend le max entre forfait et frais effectifs
    final deductionEntretien = max(forfaitEntretien, fraisEntretien);

    // Assurance batiment (estimation forfaitaire 0.1% de la valeur venale)
    final deductionAssurance = valeur * 0.001;

    // Total deductions
    final totalDeductions =
        interets + deductionEntretien + deductionAssurance;

    // Impact net sur le revenu imposable
    final impactNet = valeurLocative - totalDeductions;

    // Impact fiscal
    final impotSupplementaire = impactNet * marginal;

    // Chiffre choc
    String chiffreChocTexte;
    bool chiffreChocPositif;

    if (impactNet > 0) {
      chiffreChocTexte =
          'La valeur locative te coute environ CHF ${formatChf(impotSupplementaire)}/an d\'impot supplementaire';
      chiffreChocPositif = false;
    } else {
      chiffreChocTexte =
          'Tes deductions compensent : economie nette estimee de CHF ${formatChf(-impotSupplementaire)}/an';
      chiffreChocPositif = true;
    }

    return ImputedRentalResult(
      valeurLocative: valeurLocative,
      deductionInterets: interets,
      deductionFraisEntretien: deductionEntretien,
      deductionAssurance: deductionAssurance,
      totalDeductions: totalDeductions,
      impactNet: impactNet,
      impotSupplementaire: impotSupplementaire,
      chiffreChocTexte: chiffreChocTexte,
      chiffreChocPositif: chiffreChocPositif,
      disclaimer:
          'Simulation pédagogique à titre indicatif. La valeur locative '
          'réelle est fixée par l\'autorité fiscale cantonale et peut '
          'différer significativement de cette estimation. Les déductions '
          'dépendent de la situation personnelle. '
          'Base légale\u00a0: LIFD art. 21 al. 1 let. b, art. 32 (déductions). '
          'Consulte un·e spécialiste en fiscalité.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// D. Amortization Calculator — Direct vs Indirect
// ─────────────────────────────────────────────────────────────────────────────

/// Point annuel pour la simulation d'amortissement
class AmortizationYearPoint {
  final int annee;
  final double detteRestante;
  final double interetsPayes;
  final double capital3a;
  final double coutNet;

  const AmortizationYearPoint({
    required this.annee,
    required this.detteRestante,
    required this.interetsPayes,
    required this.capital3a,
    required this.coutNet,
  });
}

/// Resultat de la comparaison direct vs indirect
class AmortizationResult {
  final double coutNetDirect;
  final double coutNetIndirect;
  final double economieIndirect;
  final double totalInteretsDirect;
  final double totalInteretsIndirect;
  final double capital3aFinal;
  final List<AmortizationYearPoint> directPlan;
  final List<AmortizationYearPoint> indirectPlan;
  final String chiffreChocTexte;
  final bool chiffreChocPositif;
  final String disclaimer;

  const AmortizationResult({
    required this.coutNetDirect,
    required this.coutNetIndirect,
    required this.economieIndirect,
    required this.totalInteretsDirect,
    required this.totalInteretsIndirect,
    required this.capital3aFinal,
    required this.directPlan,
    required this.indirectPlan,
    required this.chiffreChocTexte,
    required this.chiffreChocPositif,
    required this.disclaimer,
  });
}

class AmortizationCalculator {
  // Montant max 3a salarie: uses pilier3aPlafondAvecLpp from social_insurance.dart

  /// Compare l'amortissement direct vs indirect sur [dureeAns].
  ///
  /// Direct : versement annuel reduit la dette, interets diminuent.
  /// Indirect : versement dans un 3a nanti, dette constante, double deduction fiscale.
  ///
  /// Base legale : OPP3 (versements 3a), pratique hypothecaire suisse.
  static AmortizationResult compare({
    required double montantHypothecaire,
    required double tauxInteret,
    required int dureeAns,
    required double tauxMarginal,
    double rendement3a = 0.02,
  }) {
    final montant = montantHypothecaire.clamp(100000.0, 5000000.0);
    final taux = tauxInteret.clamp(0.005, 0.08);
    final duree = dureeAns.clamp(1, 30);
    final marginal = tauxMarginal.clamp(0.15, 0.45);
    final rend3a = rendement3a.clamp(0.0, 0.08);

    // Default : 1% de l'hypotheque, plafonne au max 3a (identique au backend)
    final amortissementAnnuel = min(montant * hypothequeTauxAmortissement, pilier3aPlafondAvecLpp);

    // --- Direct : amortissement annuel reduit la dette ---
    final directPlan = <AmortizationYearPoint>[];
    double detteDirect = montant;
    double totalInteretsDirect = 0;
    double coutNetDirect = 0;

    for (int i = 1; i <= duree; i++) {
      final interets = detteDirect * taux;
      totalInteretsDirect += interets;
      // Deduction fiscale : seulement les interets
      final deductionDirect = interets * marginal;
      detteDirect -= amortissementAnnuel;
      if (detteDirect < 0) detteDirect = 0;
      final coutAnnuel = interets + amortissementAnnuel - deductionDirect;
      coutNetDirect += coutAnnuel;

      directPlan.add(AmortizationYearPoint(
        annee: i,
        detteRestante: detteDirect,
        interetsPayes: interets,
        capital3a: 0,
        coutNet: coutAnnuel,
      ));
    }

    // --- Indirect : dette constante, versement dans 3a ---
    final indirectPlan = <AmortizationYearPoint>[];
    double capital3a = 0;
    double totalInteretsIndirect = 0;
    double coutNetIndirect = 0;

    for (int i = 1; i <= duree; i++) {
      final interets = montant * taux;
      totalInteretsIndirect += interets;
      capital3a = (capital3a + amortissementAnnuel) * (1 + rend3a);
      // Double deduction : interets + versement 3a
      final deductionIndirect =
          (interets + amortissementAnnuel) * marginal;
      final coutAnnuel =
          interets + amortissementAnnuel - deductionIndirect;
      coutNetIndirect += coutAnnuel;

      indirectPlan.add(AmortizationYearPoint(
        annee: i,
        detteRestante: montant,
        interetsPayes: interets,
        capital3a: capital3a,
        coutNet: coutAnnuel,
      ));
    }

    final economie = coutNetDirect - coutNetIndirect;

    return AmortizationResult(
      coutNetDirect: coutNetDirect,
      coutNetIndirect: coutNetIndirect,
      economieIndirect: economie,
      totalInteretsDirect: totalInteretsDirect,
      totalInteretsIndirect: totalInteretsIndirect,
      capital3aFinal: capital3a,
      directPlan: directPlan,
      indirectPlan: indirectPlan,
      chiffreChocTexte: economie > 0
          ? 'L\'amortissement indirect t\'economise environ CHF ${formatChf(economie)} sur $duree ans'
          : 'L\'amortissement direct est environ CHF ${formatChf(-economie)} moins cher sur $duree ans',
      chiffreChocPositif: economie > 0,
      disclaimer:
          'Simulation pédagogique à titre indicatif. L\'avantage de '
          'l\'amortissement indirect dépend du taux marginal effectif, '
          'du rendement 3a et des conditions hypothécaires. '
          'Le nantissement du 3a doit être accepté par le prêteur. '
          'Base légale\u00a0: OPP3, pratique hypothécaire suisse. '
          'Consulte un·e spécialiste avant toute décision.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// E. EPL Combined Calculator — Financement multi-sources
// ─────────────────────────────────────────────────────────────────────────────

/// Source de fonds propres
class FundingSource {
  final String label;
  final double montant;
  final double pourcentageDuPrix;
  final double impotEstime;
  final double montantNet;
  final String? alerte;

  const FundingSource({
    required this.label,
    required this.montant,
    required this.pourcentageDuPrix,
    required this.impotEstime,
    required this.montantNet,
    this.alerte,
  });
}

/// Resultat du calcul EPL multi-sources
class EplCombinedResult {
  final double fondsPropresTotal;
  final double fondsPropresRequis;
  final double pourcentageCouvert;
  final List<FundingSource> sources;
  final double totalImpots;
  final double montantNetTotal;
  final bool objectifAtteint;
  final String chiffreChocTexte;
  final bool chiffreChocPositif;
  final List<String> alertes;
  final String disclaimer;

  const EplCombinedResult({
    required this.fondsPropresTotal,
    required this.fondsPropresRequis,
    required this.pourcentageCouvert,
    required this.sources,
    required this.totalImpots,
    required this.montantNetTotal,
    required this.objectifAtteint,
    required this.chiffreChocTexte,
    required this.chiffreChocPositif,
    required this.alertes,
    required this.disclaimer,
  });
}

class EplCombinedCalculator {
  /// Liste des cantons ordonnes alphabetiquement.
  static List<String> get cantons => sortedCantonCodes;

  /// Calcule le plan de financement EPL multi-sources.
  ///
  /// Ordre recommande : 1) Cash 2) 3a 3) LPP
  /// LPP : max 10% du prix pour les fonds propres (regle bancaire).
  /// Impot marginal par tranches sur les retraits 3a et LPP.
  ///
  /// Base legale : LPP art. 30c (EPL), OPP3, LIFD art. 38.
  static EplCombinedResult calculate({
    required double epargneCash,
    required double avoir3a,
    required double avoirLpp,
    required double prixCible,
    required String canton,
  }) {
    final cash = epargneCash.clamp(0.0, 5000000.0);
    final a3a = avoir3a.clamp(0.0, 1000000.0);
    final lpp = avoirLpp.clamp(0.0, 2000000.0);
    final prix = prixCible.clamp(0.0, 10000000.0);

    final tauxBase = tauxImpotRetraitCapital[canton.toUpperCase()] ?? 0.065;
    final fondsPropresRequis = prix * hypothequeFondsPropresMin;
    final lppMax = prix * hypothequePart2ePilierMax; // Max 10% du prix en LPP

    // Allocation dans l'ordre recommande : Cash > 3a > LPP
    double restant = fondsPropresRequis;

    // 1) Cash (pas d'impot)
    final cashUtilise = min(cash, restant);
    restant -= cashUtilise;

    // 2) 3a (impot sur retrait)
    final a3aUtilise = min(a3a, restant);
    restant -= a3aUtilise;
    final impot3a = _calculerImpotRetrait(a3aUtilise, tauxBase);

    // 3) LPP (impot sur retrait, max 10% du prix)
    final lppUtilisable = min(lpp, lppMax);
    final lppUtilise = min(lppUtilisable, restant);
    restant -= lppUtilise;
    final impotLpp = _calculerImpotRetrait(lppUtilise, tauxBase);

    final fondsPropresTotal = cashUtilise + a3aUtilise + lppUtilise;
    final totalImpots = impot3a + impotLpp;
    final montantNetTotal = fondsPropresTotal - totalImpots;
    final pourcentageCouvert =
        prix > 0 ? (montantNetTotal / prix) * 100 : 0.0;
    final objectifAtteint = montantNetTotal >= fondsPropresRequis;

    // Sources
    final sources = <FundingSource>[];

    if (cashUtilise > 0) {
      sources.add(FundingSource(
        label: 'Epargne cash',
        montant: cashUtilise,
        pourcentageDuPrix: prix > 0 ? (cashUtilise / prix) * 100 : 0,
        impotEstime: 0,
        montantNet: cashUtilise,
      ));
    }

    if (a3aUtilise > 0) {
      sources.add(FundingSource(
        label: 'Retrait 3a',
        montant: a3aUtilise,
        pourcentageDuPrix: prix > 0 ? (a3aUtilise / prix) * 100 : 0,
        impotEstime: impot3a,
        montantNet: a3aUtilise - impot3a,
        alerte: 'Impot estime sur le retrait 3a : CHF ${formatChf(impot3a)}',
      ));
    }

    if (lppUtilise > 0) {
      sources.add(FundingSource(
        label: 'Retrait LPP (EPL)',
        montant: lppUtilise,
        pourcentageDuPrix: prix > 0 ? (lppUtilise / prix) * 100 : 0,
        impotEstime: impotLpp,
        montantNet: lppUtilise - impotLpp,
        alerte:
            'Le retrait LPP reduit tes prestations de risque (invalidite, deces). '
            'Impot estime : CHF ${formatChf(impotLpp)}.',
      ));
    }

    // Alertes
    final alertes = <String>[];
    if (lppUtilise > 0) {
      alertes.add(
        'Le retrait EPL (LPP) reduit proportionnellement tes prestations '
        'd\'invalidite et de deces. Verifie aupres de ta caisse de pension '
        'les possibilites d\'assurance complementaire.',
      );
    }
    if (a3aUtilise > 0 && lppUtilise > 0) {
      alertes.add(
        'Le retrait combine 3a + LPP dans la meme annee fiscale augmente '
        'la progressivite de l\'impot. Envisagez d\'etaler sur 2 annees.',
      );
    }
    if (!objectifAtteint) {
      alertes.add(
        'Tes fonds propres couvrent ${pourcentageCouvert.toStringAsFixed(1)}% du prix. '
        'Il manque environ CHF ${formatChf(restant)} pour atteindre les 20% requis.',
      );
    }
    if (lppUtilise >= lppMax && lpp > lppMax) {
      alertes.add(
        'Utilisation LPP limitee a 10% du prix d\'achat '
        '(CHF ${formatChf(lppMax)}). Ton avoir LPP restant n\'est pas '
        'utilisable comme fonds propres.',
      );
    }

    return EplCombinedResult(
      fondsPropresTotal: fondsPropresTotal,
      fondsPropresRequis: fondsPropresRequis,
      pourcentageCouvert: pourcentageCouvert,
      sources: sources,
      totalImpots: totalImpots,
      montantNetTotal: montantNetTotal,
      objectifAtteint: objectifAtteint,
      chiffreChocTexte:
          'Tes fonds propres couvrent ${pourcentageCouvert.toStringAsFixed(1)}% du prix',
      chiffreChocPositif: objectifAtteint,
      alertes: alertes,
      disclaimer:
          'Simulation pédagogique à titre indicatif. Les montants réels '
          'dépendent de la caisse de pension, de la fiscalité cantonale '
          'et communale, et de la situation personnelle. '
          'Le retrait LPP est soumis à l\'accord du conjoint (si marié). '
          'Base légale\u00a0: LPP art. 30c (EPL), OPP3, LIFD art. 38. '
          'Consulte un·e spécialiste avant toute décision.',
    );
  }

  /// Impot sur le retrait en capital (progressif marginal).
  /// Delegue a RetirementTaxCalculator.progressiveTax (financial_core).
  static double _calculerImpotRetrait(double montant, double tauxBase) =>
      RetirementTaxCalculator.progressiveTax(montant, tauxBase);
}
