import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;

// ============================================================================
// Pillar 3a Deep Service — Sprint S16 (3a Deep)
//
// Trois simulateurs pedagogiques pour le pilier 3a approfondi :
//   A. StaggeredWithdrawalSimulator — retrait echelonne multi-comptes
//   B. RealReturnCalculator         — rendement reel avec taux marginal
//   C. ProviderComparator           — comparateur fintech/banque/assurance
//
// Base legale : OPP3, LIFD art. 38 (imposition retrait capital prevoyance)
// ============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// A. Retrait echelonne multi-comptes 3a
// ─────────────────────────────────────────────────────────────────────────────

/// Plan annuel de retrait echelonne
class WithdrawalYearPlan {
  final int annee;
  final int ageRetrait;
  final double montantRetire;
  final double impotEstime;
  final double montantNet;

  const WithdrawalYearPlan({
    required this.annee,
    required this.ageRetrait,
    required this.montantRetire,
    required this.impotEstime,
    required this.montantNet,
  });
}

/// Resultat du chiffre choc pour le retrait echelonne
class ChiffreChoc {
  final double montant;
  final String texte;
  final bool isPositive;

  const ChiffreChoc({
    required this.montant,
    required this.texte,
    required this.isPositive,
  });
}

/// Resultat global de la simulation retrait echelonne
class StaggeredWithdrawalResult {
  final double impotBloc;
  final double impotEchelonne;
  final double economie;
  final int nbComptesOptimal;
  final List<WithdrawalYearPlan> planAnnuel;
  final ChiffreChoc chiffreChoc;
  final String disclaimer;

  const StaggeredWithdrawalResult({
    required this.impotBloc,
    required this.impotEchelonne,
    required this.economie,
    required this.nbComptesOptimal,
    required this.planAnnuel,
    required this.chiffreChoc,
    required this.disclaimer,
  });
}

class StaggeredWithdrawalSimulator {
  /// Taux d'imposition retrait capital par canton (26 cantons).
  /// Taux effectifs moyens (federal + cantonal + communal) pour un retrait
  /// d'environ 200'000 CHF. Source : AFC, estimation pedagogique.
  /// IDENTIQUES au backend.
  static const Map<String, double> _tauxRetraitCapital = {
    'ZH': 0.065,
    'BE': 0.070,
    'VD': 0.080,
    'GE': 0.075,
    'LU': 0.050,
    'AG': 0.060,
    'SG': 0.065,
    'BS': 0.075,
    'TI': 0.070,
    'VS': 0.060,
    'FR': 0.075,
    'NE': 0.080,
    'JU': 0.080,
    'SO': 0.065,
    'BL': 0.065,
    'GR': 0.060,
    'TG': 0.055,
    'SZ': 0.040,
    'ZG': 0.035,
    'NW': 0.040,
    'OW': 0.045,
    'UR': 0.050,
    'SH': 0.060,
    'AR': 0.055,
    'AI': 0.045,
    'GL': 0.055,
  };

  /// Liste des cantons ordonnee alphabetiquement
  static List<String> get cantons {
    final list = _tauxRetraitCapital.keys.toList();
    list.sort();
    return list;
  }

  /// Simule le retrait echelonne vs bloc.
  ///
  /// [avoirTotal]        — avoir 3a total (CHF)
  /// [nbComptes]         — nombre de comptes 3a (1-5)
  /// [canton]            — code canton (ZH, VD, GE, ...)
  /// [revenuImposable]   — revenu imposable annuel (CHF)
  /// [ageRetraitDebut]   — age de debut des retraits
  /// [ageRetraitFin]     — age de fin (retraite)
  static StaggeredWithdrawalResult simulate({
    required double avoirTotal,
    required int nbComptes,
    required String canton,
    required double revenuImposable,
    required int ageRetraitDebut,
    required int ageRetraitFin,
  }) {
    // Clamp inputs
    final clampedComptes = nbComptes.clamp(1, 5);
    final clampedAvoir = avoirTotal.clamp(0.0, 1000000.0);
    final clampedDebut = ageRetraitDebut.clamp(59, 65);
    final clampedFin = ageRetraitFin.clamp(clampedDebut, 65);

    final tauxBase = _tauxRetraitCapital[canton.toUpperCase()] ?? 0.065;

    // --- Retrait en bloc ---
    final impotBloc = _calculerImpotRetrait(clampedAvoir, tauxBase);

    // --- Retrait echelonne ---
    final dureeEchelonnement = (clampedFin - clampedDebut + 1).clamp(1, 7);
    final comptesEffectifs = min(clampedComptes, dureeEchelonnement);
    final montantParRetrait = clampedAvoir / comptesEffectifs;

    double totalImpotEchelonne = 0;
    final List<WithdrawalYearPlan> plan = [];

    for (int i = 0; i < comptesEffectifs; i++) {
      final impot = _calculerImpotRetrait(montantParRetrait, tauxBase);
      totalImpotEchelonne += impot;

      plan.add(WithdrawalYearPlan(
        annee: i + 1,
        ageRetrait: clampedDebut + i,
        montantRetire: montantParRetrait,
        impotEstime: impot,
        montantNet: montantParRetrait - impot,
      ));
    }

    final economie = impotBloc - totalImpotEchelonne;

    // Nombre optimal de comptes (maximise l'economie)
    int optimalComptes = 1;
    double meilleurEconomie = 0;
    for (int n = 1; n <= 5; n++) {
      if (n > dureeEchelonnement) break;
      final montant = clampedAvoir / n;
      double impotN = 0;
      for (int j = 0; j < n; j++) {
        impotN += _calculerImpotRetrait(montant, tauxBase);
      }
      final ecoN = impotBloc - impotN;
      if (ecoN > meilleurEconomie) {
        meilleurEconomie = ecoN;
        optimalComptes = n;
      }
    }

    return StaggeredWithdrawalResult(
      impotBloc: impotBloc,
      impotEchelonne: totalImpotEchelonne,
      economie: economie,
      nbComptesOptimal: optimalComptes,
      planAnnuel: plan,
      chiffreChoc: ChiffreChoc(
        montant: economie,
        texte: 'Economie : CHF ${formatChf(economie)}',
        isPositive: economie > 0,
      ),
      disclaimer:
          'Simulation pedagogique a titre indicatif. L\'impot sur le retrait '
          'en capital depend du canton, de la commune, de la situation '
          'personnelle et du montant total retire dans l\'annee fiscale. '
          'Les taux utilises sont des moyennes cantonales simplifiees. '
          'Base legale : OPP3, LIFD art. 38. '
          'Consultez un ou une specialiste en prevoyance avant toute decision.',
    );
  }

  /// Impot sur le retrait en capital (progressif marginal).
  /// Chaque tranche du montant est taxee a un taux different.
  /// Identique au backend (multi_account_service.py).
  static double _calculerImpotRetrait(double montant, double tauxBase) {
    if (montant <= 0) return 0;
    // Brackets marginaux : [seuil_bas, seuil_haut, multiplicateur]
    const brackets = [
      [0,       100000,  1.0],    // 0-100k : taux de base
      [100000,  200000,  1.15],   // 100k-200k : +15%
      [200000,  500000,  1.30],   // 200k-500k : +30%
      [500000,  1000000, 1.50],   // 500k-1M : +50%
    ];
    const lastMultiplier = 1.70;   // >1M : +70%

    double impot = 0;
    double remaining = montant;

    for (final bracket in brackets) {
      final low = bracket[0];
      final high = bracket[1];
      final mult = bracket[2];
      final trancheSize = high - low;
      final taxable = remaining.clamp(0.0, trancheSize);
      impot += taxable * tauxBase * mult;
      remaining -= taxable;
      if (remaining <= 0) break;
    }
    // Remaining above 1M
    if (remaining > 0) {
      impot += remaining * tauxBase * lastMultiplier;
    }
    return impot;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// B. Rendement reel avec taux marginal
// ─────────────────────────────────────────────────────────────────────────────

/// Resultat du calcul de rendement reel
class RealReturnResult {
  final double capitalFinal3a;
  final double capitalFinalEpargne;
  final double totalVersements;
  final double rendementNominal;
  final double rendementReel;
  final double rendementEpargne;
  final double economieFiscaleTotale;
  final double gainVsEpargne;
  final ChiffreChoc chiffreChoc;
  final String disclaimer;

  const RealReturnResult({
    required this.capitalFinal3a,
    required this.capitalFinalEpargne,
    required this.totalVersements,
    required this.rendementNominal,
    required this.rendementReel,
    required this.rendementEpargne,
    required this.economieFiscaleTotale,
    required this.gainVsEpargne,
    required this.chiffreChoc,
    required this.disclaimer,
  });
}

class RealReturnCalculator {
  /// Calcule le rendement reel du 3a en tenant compte de l'economie fiscale.
  ///
  /// [versementAnnuel]   — versement annuel 3a (CHF)
  /// [tauxMarginal]      — taux marginal d'imposition (0.10 - 0.45)
  /// [rendementBrut]     — rendement brut annuel du 3a (ex: 0.045)
  /// [fraisGestion]      — frais de gestion annuels (ex: 0.0039)
  /// [dureeAnnees]       — duree de placement (annees)
  /// [inflation]         — taux d'inflation annuel (ex: 0.01)
  static RealReturnResult calculate({
    required double versementAnnuel,
    required double tauxMarginal,
    required double rendementBrut,
    required double fraisGestion,
    required int dureeAnnees,
    double inflation = 0.01,
  }) {
    final clampedTaux = tauxMarginal.clamp(0.10, 0.45);
    final clampedRendement = rendementBrut.clamp(0.0, 0.10);
    final clampedFrais = fraisGestion.clamp(0.0, 0.03);
    final clampedDuree = dureeAnnees.clamp(1, 45);
    final clampedVersement = versementAnnuel.clamp(0.0, pilier3aPlafondSansLpp);
    // Rendement net de frais et d'inflation (identique au backend)
    final clampedInflation = inflation.clamp(0.0, 0.05);
    final rendementNet = max(0.0, clampedRendement - clampedFrais - clampedInflation);

    // Capital final 3a (rendement compose)
    double capital3a = 0;
    double totalEconomieFiscale = 0;
    for (int i = 0; i < clampedDuree; i++) {
      capital3a = (capital3a + clampedVersement) * (1 + rendementNet);
      totalEconomieFiscale += clampedVersement * clampedTaux;
    }

    // Capital final epargne classique (1.5% brut, pas de deduction fiscale)
    const tauxEpargne = 0.015;
    double capitalEpargne = 0;
    for (int i = 0; i < clampedDuree; i++) {
      capitalEpargne = (capitalEpargne + clampedVersement) * (1 + tauxEpargne);
    }

    final totalVersements = clampedVersement * clampedDuree;
    final gainVsEpargne =
        (capital3a + totalEconomieFiscale) - capitalEpargne;

    // Rendement nominal annualise
    final rendNominal = totalVersements > 0 && clampedDuree > 0
        ? (pow(capital3a / totalVersements, 1.0 / clampedDuree) - 1) * 100
        : 0.0;
    // Rendement reel (avec economie fiscale)
    final capitalAvecFiscal = capital3a + totalEconomieFiscale;
    final rendReelPct = totalVersements > 0 && clampedDuree > 0
        ? (pow(capitalAvecFiscal / totalVersements, 1.0 / clampedDuree) - 1) *
            100
        : 0.0;
    // Rendement epargne classique annualise
    final rendEpargne = totalVersements > 0 && clampedDuree > 0
        ? (pow(capitalEpargne / totalVersements, 1.0 / clampedDuree) - 1) * 100
        : 0.0;

    return RealReturnResult(
      capitalFinal3a: capital3a,
      capitalFinalEpargne: capitalEpargne,
      totalVersements: totalVersements,
      rendementNominal: rendNominal.toDouble(),
      rendementReel: rendReelPct.toDouble(),
      rendementEpargne: rendEpargne.toDouble(),
      economieFiscaleTotale: totalEconomieFiscale,
      gainVsEpargne: gainVsEpargne,
      chiffreChoc: ChiffreChoc(
        montant: gainVsEpargne,
        texte:
            'Rendement reel : ${rendReelPct.toStringAsFixed(1)}% vs '
            '${rendEpargne.toStringAsFixed(1)}% sans avantage fiscal',
        isPositive: gainVsEpargne > 0,
      ),
      disclaimer:
          'Simulation pedagogique basee sur des hypotheses de rendement '
          'constant. Les rendements passes ne prejugent pas des rendements '
          'futurs. Les frais et rendements varient selon le prestataire. '
          'L\'economie fiscale depend de ton taux marginal reel. '
          'Base legale : OPP3, LIFD art. 33 al. 1 let. e. '
          'Consultez un ou une specialiste avant toute decision.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// C. Comparateur Providers 3a
// ─────────────────────────────────────────────────────────────────────────────

enum ProfilRisque { prudent, equilibre, dynamique }

/// Donnees d'un provider 3a
class Provider3a {
  final String nom;
  final String type; // fintech, banque, assurance
  final Map<ProfilRisque, double> rendementParProfil;
  final double fraisGestion;
  final String description;
  final int? engagementAnnees;

  const Provider3a({
    required this.nom,
    required this.type,
    required this.rendementParProfil,
    required this.fraisGestion,
    required this.description,
    this.engagementAnnees,
  });

  double rendementPour(ProfilRisque profil) => rendementParProfil[profil] ?? 0;
}

/// Resultat d'un provider dans la comparaison
class ProviderResult {
  final Provider3a provider;
  final double capitalFinal;
  final double totalFrais;
  final double rendementNet;
  final String? badge;
  final bool hasWarning;
  final String? warningMessage;

  const ProviderResult({
    required this.provider,
    required this.capitalFinal,
    required this.totalFrais,
    required this.rendementNet,
    this.badge,
    this.hasWarning = false,
    this.warningMessage,
  });
}

/// Resultat global de la comparaison
class ProviderComparisonResult {
  final List<ProviderResult> providers;
  final double differenceMax;
  final ChiffreChoc chiffreChoc;
  final String disclaimer;

  const ProviderComparisonResult({
    required this.providers,
    required this.differenceMax,
    required this.chiffreChoc,
    required this.disclaimer,
  });
}

class ProviderComparator {
  /// Les 5 providers de reference — rendements explicites par profil.
  /// IDENTIQUES au backend (provider_comparator_service.py).
  static const List<Provider3a> _providers = [
    Provider3a(
      nom: 'VIAC',
      type: 'fintech',
      rendementParProfil: {
        ProfilRisque.prudent: 0.025,
        ProfilRisque.equilibre: 0.035,
        ProfilRisque.dynamique: 0.045,
      },
      fraisGestion: 0.0052,
      description: 'App mobile, strategies passives indexees, gestion automatisee',
    ),
    Provider3a(
      nom: 'Finpension',
      type: 'fintech',
      rendementParProfil: {
        ProfilRisque.prudent: 0.030,
        ProfilRisque.equilibre: 0.040,
        ProfilRisque.dynamique: 0.055,
      },
      fraisGestion: 0.0039,
      description: 'Frais parmi les plus bas, strategies globales, flexibilite',
    ),
    Provider3a(
      nom: 'Frankly (ZKB)',
      type: 'fintech',
      rendementParProfil: {
        ProfilRisque.prudent: 0.020,
        ProfilRisque.equilibre: 0.030,
        ProfilRisque.dynamique: 0.040,
      },
      fraisGestion: 0.0044,
      description: 'Solution digitale de la Zurcher Kantonalbank',
    ),
    Provider3a(
      nom: 'Banque classique (compte 3a)',
      type: 'banque',
      rendementParProfil: {
        ProfilRisque.prudent: 0.015,
        ProfilRisque.equilibre: 0.015,
        ProfilRisque.dynamique: 0.015,
      },
      fraisGestion: 0.0,
      description: 'Taux fixe, pas de risque de marche, rendement limite',
    ),
    Provider3a(
      nom: 'Assurance 3a (mixte)',
      type: 'assurance',
      rendementParProfil: {
        ProfilRisque.prudent: 0.005,
        ProfilRisque.equilibre: 0.008,
        ProfilRisque.dynamique: 0.010,
      },
      fraisGestion: 0.0175,
      description: 'Combine epargne et couverture risque (deces, invalidite). '
          'Frais eleves, duree d\'engagement longue.',
      engagementAnnees: 10,
    ),
  ];

  /// Compare les providers 3a.
  ///
  /// [age]             — age actuel
  /// [versementAnnuel] — versement annuel (CHF)
  /// [duree]           — nombre d'annees
  /// [profilRisque]    — profil de risque
  static ProviderComparisonResult compare({
    required int age,
    required double versementAnnuel,
    required int duree,
    required ProfilRisque profilRisque,
  }) {
    final clampedAge = age.clamp(18, 70);
    final clampedDuree = duree.clamp(1, 50);
    final clampedVersement = versementAnnuel.clamp(0.0, pilier3aPlafondSansLpp);

    final List<ProviderResult> results = [];
    double maxCapital = 0;
    double minCapital = double.infinity;
    String? bestRendementNom;
    String? bestFraisNom;
    double lowestFrais = double.infinity;

    for (final provider in _providers) {
      final rendement = provider.rendementPour(profilRisque);
      final rendementNet = rendement - provider.fraisGestion;

      // Capital final compose
      double capital = 0;
      double totalFrais = 0;
      for (int i = 0; i < clampedDuree; i++) {
        capital = (capital + clampedVersement) * (1 + rendementNet);
        totalFrais += capital * provider.fraisGestion;
      }

      if (capital > maxCapital) {
        maxCapital = capital;
        bestRendementNom = provider.nom;
      }
      if (capital < minCapital) {
        minCapital = capital;
      }
      if (provider.fraisGestion < lowestFrais && provider.fraisGestion > 0) {
        lowestFrais = provider.fraisGestion;
        bestFraisNom = provider.nom;
      }

      // Warning assurance si < 35 ans
      bool hasWarning = false;
      String? warningMsg;
      if (provider.type == 'assurance' && clampedAge < 35) {
        hasWarning = true;
        // Compare vs Finpension (meilleur fintech) au meme profil de risque
        final fintechRendement =
            _providers[1].rendementPour(profilRisque); // Finpension
        final capitalFintech = _futureValue(
          clampedVersement,
          fintechRendement - 0.0039,
          clampedDuree,
        );
        final perte = capitalFintech - capital;
        warningMsg =
            'A $clampedAge ans, une assurance 3a te coute environ '
            'CHF ${formatChf(perte)} de rendement perdu sur $clampedDuree ans '
            'par rapport a une fintech. Frais eleves et flexibilite reduite.';
      }

      results.add(ProviderResult(
        provider: provider,
        capitalFinal: capital,
        totalFrais: totalFrais,
        rendementNet: rendementNet * 100,
        hasWarning: hasWarning,
        warningMessage: warningMsg,
      ));
    }

    // Attribuer les badges
    final badgedResults = results.map((r) {
      String? badge;
      if (r.provider.nom == bestRendementNom) badge = 'Meilleur rendement net';
      if (r.provider.nom == bestFraisNom) {
        badge = badge != null ? '$badge + Plus bas frais' : 'Plus bas frais';
      }
      if (r.provider.type == 'assurance') badge = 'WARNING';
      return ProviderResult(
        provider: r.provider,
        capitalFinal: r.capitalFinal,
        totalFrais: r.totalFrais,
        rendementNet: r.rendementNet,
        badge: badge,
        hasWarning: r.hasWarning,
        warningMessage: r.warningMessage,
      );
    }).toList();

    final difference = maxCapital - minCapital;

    return ProviderComparisonResult(
      providers: badgedResults,
      differenceMax: difference,
      chiffreChoc: ChiffreChoc(
        montant: difference,
        texte:
            'Difference sur $clampedDuree ans : CHF ${formatChf(difference)}',
        isPositive: true,
      ),
      disclaimer:
          'Rendements passes ne prejugent pas des rendements futurs. '
          'Les frais et rendements moyens sont bases sur des donnees '
          'historiques simplifiees a titre pedagogique. '
          'Le choix d\'un prestataire 3a depend de ta situation personnelle, '
          'de ton profil de risque et de ton horizon de placement. '
          'MINT n\'est pas un intermediaire financier et ne fournit aucun '
          'conseil en placement. Consultez un ou une specialiste.',
    );
  }

  static double _futureValue(double annualPayment, double rate, int years) {
    if (rate <= 0 || years <= 0) return annualPayment * years;
    double capital = 0;
    for (int i = 0; i < years; i++) {
      capital = (capital + annualPayment) * (1 + rate);
    }
    return capital;
  }
}
