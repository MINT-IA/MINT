import 'dart:math';

import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;

// ============================================================================
// Debt Prevention Service — Sprint S16 (Prevention de la dette)
//
// Trois modules pedagogiques :
//   A. DebtRatioCalculator   — diagnostic ratio dette / revenus
//   B. RepaymentPlanner      — plan de remboursement avalanche vs boule de neige
//   C. DebtHelpResources     — ressources d'aide cantonales
//
// Base legale : LP art. 93 (minimum vital), LCC (loi sur le credit a la consommation)
// ============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// A. Calculateur ratio d'endettement
// ─────────────────────────────────────────────────────────────────────────────

enum DebtRiskLevel { vert, orange, rouge }

/// Resultat du premier éclairage
class DebtPremierEclairage {
  final double montant;
  final String texte;
  final DebtRiskLevel niveau;

  const DebtPremierEclairage({
    required this.montant,
    required this.texte,
    required this.niveau,
  });
}

/// Resultat du diagnostic ratio dette
class DebtRatioResult {
  final double ratio;
  final DebtRiskLevel niveau;
  final double minimumVital;
  final double margeDisponible;
  final bool minimumVitalMenace;
  final DebtPremierEclairage premierEclairage;
  final List<String> recommandations;
  final String disclaimer;

  const DebtRatioResult({
    required this.ratio,
    required this.niveau,
    required this.minimumVital,
    required this.margeDisponible,
    required this.minimumVitalMenace,
    required this.premierEclairage,
    required this.recommandations,
    required this.disclaimer,
  });
}

class DebtRatioCalculator {
  /// Minimum vital selon LP art. 93.
  /// Montants mensuels de base.
  static const double _minimumVitalCelibataire = 1200.0;
  static const double _minimumVitalCouple = 1750.0;
  static const double _supplementEnfant = 400.0;

  /// Calcule le ratio d'endettement et le diagnostic.
  ///
  /// [revenusMensuels]           — revenus nets mensuels (CHF)
  /// [chargesDetteMensuelles]    — charges de dette mensuelles (credits, leasing, ...)
  /// [loyer]                     — loyer mensuel (CHF)
  /// [autresChargesFixes]        — autres charges fixes mensuelles (CHF)
  /// [estCelibataire]            — true si celibataire
  /// [nombreEnfants]             — nombre d'enfants
  static DebtRatioResult calculate({
    required double revenusMensuels,
    required double chargesDetteMensuelles,
    required double loyer,
    double autresChargesFixes = 0,
    bool estCelibataire = true,
    int nombreEnfants = 0,
  }) {
    final clampedRevenus = revenusMensuels.clamp(0.0, 100000.0);
    final clampedDettes = chargesDetteMensuelles.clamp(0.0, 100000.0);
    final clampedLoyer = loyer.clamp(0.0, 20000.0);
    final clampedAutres = autresChargesFixes.clamp(0.0, 50000.0);

    // Ratio d'endettement : charges de dette / revenus
    final ratio = clampedRevenus > 0
        ? (clampedDettes / clampedRevenus * 100)
        : 0.0;

    // Niveau de risque
    final DebtRiskLevel niveau;
    if (ratio < 15) {
      niveau = DebtRiskLevel.vert;
    } else if (ratio < 30) {
      niveau = DebtRiskLevel.orange;
    } else {
      niveau = DebtRiskLevel.rouge;
    }

    // Minimum vital (LP art. 93)
    final minVitalBase = estCelibataire
        ? _minimumVitalCelibataire
        : _minimumVitalCouple;
    final minimumVital =
        minVitalBase + (nombreEnfants * _supplementEnfant);

    // Marge disponible apres charges
    final totalCharges = clampedDettes + clampedLoyer + clampedAutres;
    final margeDisponible = clampedRevenus - totalCharges;
    final minimumVitalMenace = margeDisponible < minimumVital;

    // Recommandations
    final recommandations = <String>[];
    if (niveau == DebtRiskLevel.vert) {
      recommandations.add(
        'Ton ratio d\'endettement est sain. Continue a maintenir '
        'tes dettes sous controle.',
      );
      recommandations.add(
        'Constituez un fonds d\'urgence de 3 a 6 mois de charges fixes.',
      );
    } else if (niveau == DebtRiskLevel.orange) {
      recommandations.add(
        'Ton ratio d\'endettement est modere mais merite attention. '
        'Evite de contracter de nouvelles dettes.',
      );
      recommandations.add(
        'Priorisez le remboursement des dettes au taux le plus eleve.',
      );
      recommandations.add(
        'Etablissez un budget strict pour reduire progressivement '
        'tes charges de dette.',
      );
    } else {
      recommandations.add(
        'Ton ratio d\'endettement depasse le seuil critique de 30%. '
        'Une aide professionnelle est recommandee.',
      );
      recommandations.add(
        'Contactez un service de conseil en dettes gratuit '
        '(Dettes Conseils Suisse ou Caritas).',
      );
      recommandations.add(
        'Ne contractez aucune nouvelle dette et cherchez a '
        'renégocier les conditions existantes.',
      );
    }

    if (minimumVitalMenace) {
      recommandations.insert(
        0,
        'ALERTE : Ta marge residuelle est inferieure au minimum vital '
        '(LP art. 93 : CHF ${formatChf(minimumVital)}/mois). '
        'Contactez immediatement un service d\'aide.',
      );
    }

    return DebtRatioResult(
      ratio: ratio,
      niveau: niveau,
      minimumVital: minimumVital,
      margeDisponible: margeDisponible,
      minimumVitalMenace: minimumVitalMenace,
      premierEclairage: DebtPremierEclairage(
        montant: ratio,
        texte: 'Ratio dette : ${ratio.toStringAsFixed(1)}%',
        niveau: niveau,
      ),
      recommandations: recommandations,
      disclaimer:
          'Ce diagnostic est pedagogique et ne constitue pas un avis juridique '
          'ou financier. Le minimum vital (LP art. 93) varie selon la situation '
          'personnelle et le canton. Pour une analyse personnalisee, '
          'consultez un service de conseil en dettes agree.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// B. Planificateur de remboursement
// ─────────────────────────────────────────────────────────────────────────────

enum RepaymentStrategy { avalanche, bouleDeNeige }

/// Une dette individuelle
class Debt {
  final String nom;
  final double montant;
  final double tauxAnnuel; // ex: 0.12 pour 12%
  final double mensualiteMin;

  const Debt({
    required this.nom,
    required this.montant,
    required this.tauxAnnuel,
    required this.mensualiteMin,
  });
}

/// Etat mensuel d'une dette dans le plan
class DebtMonthState {
  final String nomDette;
  final double soldeDebut;
  final double paiement;
  final double interets;
  final double soldeFin;
  final bool estSolde;

  const DebtMonthState({
    required this.nomDette,
    required this.soldeDebut,
    required this.paiement,
    required this.interets,
    required this.soldeFin,
    required this.estSolde,
  });
}

/// Un mois dans le plan de remboursement
class RepaymentMonth {
  final int mois;
  final List<DebtMonthState> dettes;
  final double paiementTotal;
  final double soldeTotal;

  const RepaymentMonth({
    required this.mois,
    required this.dettes,
    required this.paiementTotal,
    required this.soldeTotal,
  });
}

/// Resultat d'un plan de remboursement pour une strategie
class RepaymentPlanResult {
  final RepaymentStrategy strategie;
  final int moisJusquaLiberation;
  final double interetsTotaux;
  final double totalPaye;
  final List<RepaymentMonth> timeline;

  const RepaymentPlanResult({
    required this.strategie,
    required this.moisJusquaLiberation,
    required this.interetsTotaux,
    required this.totalPaye,
    required this.timeline,
  });
}

/// Resultat comparatif des deux strategies
class RepaymentComparisonResult {
  final RepaymentPlanResult avalanche;
  final RepaymentPlanResult bouleDeNeige;
  final double economieMois;
  final double economieInterets;
  final DebtPremierEclairage premierEclairage;
  final String disclaimer;

  const RepaymentComparisonResult({
    required this.avalanche,
    required this.bouleDeNeige,
    required this.economieMois,
    required this.economieInterets,
    required this.premierEclairage,
    required this.disclaimer,
  });
}

class RepaymentPlanner {
  /// Planifie et compare les deux strategies de remboursement.
  ///
  /// [dettes]                      — liste des dettes
  /// [budgetMensuelRemboursement]  — budget mensuel total pour le remboursement
  static RepaymentComparisonResult plan({
    required List<Debt> dettes,
    required double budgetMensuelRemboursement,
  }) {
    final avalanche = _simulate(
      dettes: dettes,
      budget: budgetMensuelRemboursement,
      strategie: RepaymentStrategy.avalanche,
    );

    final bouleDeNeige = _simulate(
      dettes: dettes,
      budget: budgetMensuelRemboursement,
      strategie: RepaymentStrategy.bouleDeNeige,
    );

    final economieMois =
        (bouleDeNeige.moisJusquaLiberation - avalanche.moisJusquaLiberation)
            .toDouble();
    final economieInterets =
        bouleDeNeige.interetsTotaux - avalanche.interetsTotaux;

    // Le meilleur scenario (avalanche est generalement meilleur)
    final meilleur = avalanche.interetsTotaux <= bouleDeNeige.interetsTotaux
        ? avalanche
        : bouleDeNeige;

    return RepaymentComparisonResult(
      avalanche: avalanche,
      bouleDeNeige: bouleDeNeige,
      economieMois: economieMois.abs(),
      economieInterets: economieInterets.abs(),
      premierEclairage: DebtPremierEclairage(
        montant: meilleur.moisJusquaLiberation.toDouble(),
        texte:
            'Libere dans ${meilleur.moisJusquaLiberation} mois — '
            'CHF ${formatChf(economieInterets.abs())} d\'interets economises',
        niveau: meilleur.moisJusquaLiberation <= 24
            ? DebtRiskLevel.vert
            : meilleur.moisJusquaLiberation <= 60
                ? DebtRiskLevel.orange
                : DebtRiskLevel.rouge,
      ),
      disclaimer:
          'Cette simulation est pedagogique et ne prend pas en compte '
          'les eventuelles penalites de remboursement anticipe, '
          'les frais annexes ou les variations de taux. '
          'La methode avalanche minimise les interets totaux, '
          'la methode boule de neige maximise la motivation par des '
          'victoires rapides. Consultez un·e spécialiste en dettes '
          'pour un plan adapte a ta situation.',
    );
  }

  /// Simule un plan de remboursement selon la strategie choisie.
  static RepaymentPlanResult _simulate({
    required List<Debt> dettes,
    required double budget,
    required RepaymentStrategy strategie,
  }) {
    if (dettes.isEmpty) {
      return RepaymentPlanResult(
        strategie: strategie,
        moisJusquaLiberation: 0,
        interetsTotaux: 0,
        totalPaye: 0,
        timeline: const [],
      );
    }

    // Copie mutable des soldes
    final soldes = List<double>.from(dettes.map((d) => d.montant));
    final timeline = <RepaymentMonth>[];
    double totalInterets = 0;
    double totalPaye = 0;
    int mois = 0;
    const maxMois = 600; // Securite : 50 ans max

    // Verifier que le budget couvre au moins les mensualites min
    final sumMin = dettes.fold<double>(0, (s, d) => s + d.mensualiteMin);
    final budgetEffectif = max(budget, sumMin);

    while (mois < maxMois) {
      // Verifier si toutes les dettes sont soldees
      if (soldes.every((s) => s <= 0.01)) break;
      mois++;

      // Calculer les interets mensuels
      final interetsMensuels = <double>[];
      for (int i = 0; i < dettes.length; i++) {
        final interet = soldes[i] > 0
            ? soldes[i] * (dettes[i].tauxAnnuel / 12)
            : 0.0;
        interetsMensuels.add(interet);
        totalInterets += interet;
      }

      // Appliquer les interets
      for (int i = 0; i < soldes.length; i++) {
        if (soldes[i] > 0) {
          soldes[i] += interetsMensuels[i];
        }
      }

      // Payer les mensualites minimales d'abord
      double budgetRestant = budgetEffectif;
      final paiements = List<double>.filled(dettes.length, 0);

      for (int i = 0; i < dettes.length; i++) {
        if (soldes[i] <= 0.01) continue;
        final minPaiement = min(dettes[i].mensualiteMin, soldes[i]);
        paiements[i] = minPaiement;
        budgetRestant -= minPaiement;
      }

      // Repartir l'excedent selon la strategie
      if (budgetRestant > 0) {
        final ordre = _ordrePriorite(dettes, soldes, strategie);
        for (final idx in ordre) {
          if (budgetRestant <= 0) break;
          if (soldes[idx] <= paiements[idx]) continue;
          final resteSolde = soldes[idx] - paiements[idx];
          final paiementExtra = min(budgetRestant, resteSolde);
          paiements[idx] += paiementExtra;
          budgetRestant -= paiementExtra;
        }
      }

      // Appliquer les paiements
      final monthStates = <DebtMonthState>[];
      double soldeTotal = 0;
      double paiementTotal = 0;

      for (int i = 0; i < dettes.length; i++) {
        final soldeDebut = soldes[i];
        soldes[i] = max(0, soldes[i] - paiements[i]);
        totalPaye += paiements[i];
        paiementTotal += paiements[i];
        soldeTotal += soldes[i];

        monthStates.add(DebtMonthState(
          nomDette: dettes[i].nom,
          soldeDebut: soldeDebut,
          paiement: paiements[i],
          interets: interetsMensuels[i],
          soldeFin: soldes[i],
          estSolde: soldes[i] <= 0.01,
        ));
      }

      timeline.add(RepaymentMonth(
        mois: mois,
        dettes: monthStates,
        paiementTotal: paiementTotal,
        soldeTotal: soldeTotal,
      ));
    }

    return RepaymentPlanResult(
      strategie: strategie,
      moisJusquaLiberation: mois,
      interetsTotaux: totalInterets,
      totalPaye: totalPaye,
      timeline: timeline,
    );
  }

  /// Retourne l'ordre de priorite des dettes selon la strategie.
  static List<int> _ordrePriorite(
    List<Debt> dettes,
    List<double> soldes,
    RepaymentStrategy strategie,
  ) {
    final indices = List.generate(dettes.length, (i) => i)
      ..removeWhere((i) => soldes[i] <= 0.01);

    switch (strategie) {
      case RepaymentStrategy.avalanche:
        // Taux le plus eleve d'abord
        indices.sort((a, b) => dettes[b].tauxAnnuel.compareTo(dettes[a].tauxAnnuel));
      case RepaymentStrategy.bouleDeNeige:
        // Plus petit solde d'abord
        indices.sort((a, b) => soldes[a].compareTo(soldes[b]));
    }
    return indices;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// C. Ressources d'aide en cas de dette
// ─────────────────────────────────────────────────────────────────────────────

/// Une ressource d'aide
class HelpResource {
  final String nom;
  final String description;
  final String url;
  final String? telephone;
  final bool isNational;

  const HelpResource({
    required this.nom,
    required this.description,
    required this.url,
    this.telephone,
    this.isNational = false,
  });
}

class DebtHelpResources {
  /// Ressources nationales
  static const List<HelpResource> _national = [
    HelpResource(
      nom: 'Dettes Conseils Suisse',
      description:
          'Federation faitiere des services de conseil en dettes en Suisse. '
          'Conseil gratuit, confidentiel et professionnel.',
      url: 'https://www.dettes.ch',
      telephone: '0800 40 40 40',
      isNational: true,
    ),
    HelpResource(
      nom: 'Caritas — Conseil en dettes',
      description:
          'Service d\'aide de Caritas Suisse pour les personnes en situation '
          'd\'endettement. Aide au desendettement et negociation avec creanciers.',
      url: 'https://www.caritas.ch/dettes',
      telephone: '0800 708 708',
      isNational: true,
    ),
  ];

  /// Services cantonaux — URL specifique par canton
  static const Map<String, HelpResource> _cantonal = {
    'ZH': HelpResource(
      nom: 'Schuldenberatung Kanton Zurich',
      description: 'Service de conseil en dettes du canton de Zurich.',
      url: 'https://www.schuldeninfo.ch',
    ),
    'BE': HelpResource(
      nom: 'Berner Schuldenberatung',
      description: 'Conseil en dettes pour le canton de Berne.',
      url: 'https://www.schuldenberatung-be.ch',
    ),
    'LU': HelpResource(
      nom: 'Schuldenberatung Luzern',
      description: 'Conseil en dettes pour le canton de Lucerne.',
      url: 'https://www.schuldenberatung-lu.ch',
    ),
    'UR': HelpResource(
      nom: 'Sozialdienst Uri',
      description: 'Service social du canton d\'Uri.',
      url: 'https://www.ur.ch/sozialdienst',
    ),
    'SZ': HelpResource(
      nom: 'Sozialdienst Schwyz',
      description: 'Service social du canton de Schwyz.',
      url: 'https://www.sz.ch/sozialdienst',
    ),
    'OW': HelpResource(
      nom: 'Sozialdienst Obwalden',
      description: 'Service social du canton d\'Obwald.',
      url: 'https://www.ow.ch/sozialdienst',
    ),
    'NW': HelpResource(
      nom: 'Sozialdienst Nidwalden',
      description: 'Service social du canton de Nidwald.',
      url: 'https://www.nw.ch/sozialdienst',
    ),
    'GL': HelpResource(
      nom: 'Sozialdienst Glarus',
      description: 'Service social du canton de Glaris.',
      url: 'https://www.gl.ch/sozialdienst',
    ),
    'ZG': HelpResource(
      nom: 'Schuldenberatung Zug',
      description: 'Conseil en dettes pour le canton de Zoug.',
      url: 'https://www.budgetberatung-zg.ch',
    ),
    'FR': HelpResource(
      nom: 'Centre Social Protestant Fribourg',
      description: 'Service de conseil en dettes pour le canton de Fribourg.',
      url: 'https://www.csp-fr.ch',
    ),
    'SO': HelpResource(
      nom: 'Schuldenberatung Solothurn',
      description: 'Conseil en dettes pour le canton de Soleure.',
      url: 'https://www.schuldenberatung-so.ch',
    ),
    'BS': HelpResource(
      nom: 'Plusminus Basel',
      description: 'Conseil en dettes pour le canton de Bale-Ville.',
      url: 'https://www.plusminus.ch',
    ),
    'BL': HelpResource(
      nom: 'Schuldenberatung Baselland',
      description: 'Conseil en dettes pour le canton de Bale-Campagne.',
      url: 'https://www.schuldenberatung-bl.ch',
    ),
    'SH': HelpResource(
      nom: 'Schuldenberatung Schaffhausen',
      description: 'Conseil en dettes pour le canton de Schaffhouse.',
      url: 'https://www.schuldenberatung-sh.ch',
    ),
    'AR': HelpResource(
      nom: 'Sozialdienst Appenzell AR',
      description: 'Service social du canton d\'Appenzell Rhodes-Exterieures.',
      url: 'https://www.ar.ch/sozialdienst',
    ),
    'AI': HelpResource(
      nom: 'Sozialdienst Appenzell AI',
      description: 'Service social du canton d\'Appenzell Rhodes-Interieures.',
      url: 'https://www.ai.ch/sozialdienst',
    ),
    'SG': HelpResource(
      nom: 'Schuldenberatung St. Gallen',
      description: 'Conseil en dettes pour le canton de Saint-Gall.',
      url: 'https://www.schuldenberatung-sg.ch',
    ),
    'GR': HelpResource(
      nom: 'Schuldenberatung Graubunden',
      description: 'Conseil en dettes pour le canton des Grisons.',
      url: 'https://www.schuldenberatung-gr.ch',
    ),
    'AG': HelpResource(
      nom: 'Schuldenberatung Aargau',
      description: 'Conseil en dettes pour le canton d\'Argovie.',
      url: 'https://www.schuldenberatung-ag.ch',
    ),
    'TG': HelpResource(
      nom: 'Schuldenberatung Thurgau',
      description: 'Conseil en dettes pour le canton de Thurgovie.',
      url: 'https://www.schuldenberatung-tg.ch',
    ),
    'TI': HelpResource(
      nom: 'ACLI Ticino — Servizio debiti',
      description: 'Service de conseil en dettes pour le canton du Tessin.',
      url: 'https://www.acli.ch',
    ),
    'VD': HelpResource(
      nom: 'Centre Social Protestant Vaud',
      description: 'Service de conseil en dettes pour le canton de Vaud.',
      url: 'https://www.csp-vd.ch',
    ),
    'VS': HelpResource(
      nom: 'Centre Mediation et Aide aux Dettes Valais',
      description: 'Service de mediation et aide aux dettes du Valais.',
      url: 'https://www.cms-smz-vs.ch',
    ),
    'NE': HelpResource(
      nom: 'Caritas Neuchatel',
      description: 'Conseil en dettes pour le canton de Neuchatel.',
      url: 'https://www.caritas-ne.ch',
    ),
    'GE': HelpResource(
      nom: 'Centre Social Protestant Geneve',
      description: 'Service de conseil en dettes pour le canton de Geneve.',
      url: 'https://www.csp-ge.ch',
    ),
    'JU': HelpResource(
      nom: 'Caritas Jura',
      description: 'Conseil en dettes pour le canton du Jura.',
      url: 'https://www.caritas-jura.ch',
    ),
  };

  /// Liste des cantons disponibles
  static List<String> get cantons {
    final list = _cantonal.keys.toList();
    list.sort();
    return list;
  }

  /// Retourne les ressources nationales + cantonale.
  static List<HelpResource> getResources({String? canton}) {
    final result = <HelpResource>[..._national];
    if (canton != null && _cantonal.containsKey(canton.toUpperCase())) {
      result.add(_cantonal[canton.toUpperCase()]!);
    }
    return result;
  }

  /// Retourne uniquement la ressource cantonale.
  static HelpResource? getCantonalResource(String canton) {
    return _cantonal[canton.toUpperCase()];
  }
}
