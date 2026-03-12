import 'dart:math';

// ────────────────────────────────────────────────────────────
//  ASSURANCES SERVICE — Sprint S13 / Chantier 7
// ────────────────────────────────────────────────────────────
//
// Contains 2 service classes for insurance analysis:
//   1. LamalFranchiseService  — LAMal franchise optimiser
//   2. CoverageCheckService   — coverage gap analysis
//
// All logic is local (no backend call). No banned terms
// ("garanti", "assuré" in guarantee sense, "certain") —
// only "peut", "pourrait", "estimation".
// ────────────────────────────────────────────────────────────

// ════════════════════════════════════════════════════════════
//  1. LAMAL FRANCHISE SERVICE
// ════════════════════════════════════════════════════════════

/// Result for a single franchise level comparison.
class FranchiseComparison {
  final int franchiseLevel;
  final double primeAnnuelle;
  final double franchiseEffective;
  final double quotePart;
  final double coutTotal;
  final double economieVs300;
  final bool isOptimal;

  const FranchiseComparison({
    required this.franchiseLevel,
    required this.primeAnnuelle,
    required this.franchiseEffective,
    required this.quotePart,
    required this.coutTotal,
    required this.economieVs300,
    required this.isOptimal,
  });
}

/// Break-even point between two consecutive franchise levels.
class BreakEvenPoint {
  final int franchiseBasse;
  final int franchiseHaute;
  final double seuilDepenses;

  const BreakEvenPoint({
    required this.franchiseBasse,
    required this.franchiseHaute,
    required this.seuilDepenses,
  });
}

/// Full LAMal franchise analysis result.
class LamalFranchiseResult {
  final List<FranchiseComparison> comparaison;
  final int franchiseOptimale;
  final List<BreakEvenPoint> breakEvenPoints;
  final List<String> recommandations;
  final String alerteDelai;
  final String disclaimer;

  const LamalFranchiseResult({
    required this.comparaison,
    required this.franchiseOptimale,
    required this.breakEvenPoints,
    required this.recommandations,
    required this.alerteDelai,
    required this.disclaimer,
  });
}

/// Service for LAMal franchise optimisation.
///
/// Compares all franchise levels and finds the optimal one based
/// on monthly premium and expected annual health expenses.
class LamalFranchiseService {
  // ── Constants ──────────────────────────────────────────────

  /// Adult franchise levels (CHF).
  static const List<int> franchiseLevelsAdults = [300, 500, 1000, 1500, 2000, 2500];

  /// Children franchise levels (CHF).
  static const List<int> franchiseLevelsChildren = [0, 100, 200, 300, 400, 500, 600];

  /// Quote-part rate (10%).
  static const double quotePartRate = 0.10;

  /// Quote-part annual cap for adults (CHF).
  static const double quotePartCapAdults = 700;

  /// Quote-part annual cap for children (CHF).
  static const double quotePartCapChildren = 350;

  /// Premium savings vs franchise 300 (approximate market average).
  static const Map<int, double> premiumSavingsVs300 = {
    300: 0.0,
    500: 0.05,
    1000: 0.13,
    1500: 0.19,
    2000: 0.24,
    2500: 0.28,
  };

  // ── Public API ─────────────────────────────────────────────

  /// Analyse all franchise levels and return optimal choice.
  static LamalFranchiseResult analyzeAllFranchises(
    double primeMensuelleBase,
    double depensesSanteAnnuelles, {
    bool isChild = false,
  }) {
    final levels = isChild ? franchiseLevelsChildren : franchiseLevelsAdults;
    final cap = isChild ? quotePartCapChildren : quotePartCapAdults;

    final comparisons = <FranchiseComparison>[];
    double? minCost;
    int optimalFranchise = levels.first;

    // First pass: compute cost for each franchise level
    for (final level in levels) {
      final savingsRate = premiumSavingsVs300[level] ?? 0.0;
      final primeAnnuelle = primeMensuelleBase * 12 * (1 - savingsRate);
      final franchiseEffective = min(depensesSanteAnnuelles, level.toDouble());
      final excessOverFranchise = max(depensesSanteAnnuelles - level, 0.0);
      final quotePart = min(excessOverFranchise * quotePartRate, cap);
      final coutTotal = primeAnnuelle + franchiseEffective + quotePart;

      if (minCost == null || coutTotal < minCost) {
        minCost = coutTotal;
        optimalFranchise = level;
      }

      comparisons.add(FranchiseComparison(
        franchiseLevel: level,
        primeAnnuelle: primeAnnuelle,
        franchiseEffective: franchiseEffective,
        quotePart: quotePart,
        coutTotal: coutTotal,
        economieVs300: 0, // computed in second pass
        isOptimal: false, // set in second pass
      ));
    }

    // Second pass: compute savings vs 300 and mark optimal
    final coutTotal300 = comparisons.first.coutTotal;
    final finalComparisons = comparisons.map((c) {
      return FranchiseComparison(
        franchiseLevel: c.franchiseLevel,
        primeAnnuelle: c.primeAnnuelle,
        franchiseEffective: c.franchiseEffective,
        quotePart: c.quotePart,
        coutTotal: c.coutTotal,
        economieVs300: coutTotal300 - c.coutTotal,
        isOptimal: c.franchiseLevel == optimalFranchise,
      );
    }).toList();

    // Compute break-even points
    final breakEvenPoints = _computeBreakEvenPoints(
      primeMensuelleBase,
      levels,
      cap,
    );

    // Build recommendations
    final recommandations = _buildRecommandations(
      optimalFranchise,
      depensesSanteAnnuelles,
      finalComparisons,
    );

    return LamalFranchiseResult(
      comparaison: finalComparisons,
      franchiseOptimale: optimalFranchise,
      breakEvenPoints: breakEvenPoints,
      recommandations: recommandations,
      alerteDelai: 'Rappel : modification de franchise possible avant le '
          '30 novembre de chaque année pour l\'année suivante.',
      disclaimer: 'Cette analyse est indicative. Les primes varient selon '
          'l\'assureur, la région et le modèle d\'assurance. Consultez '
          'ta caisse maladie pour des chiffres exacts. '
          'Source : LAMal art. 62-64, OAMal.',
    );
  }

  // ── Private helpers ────────────────────────────────────────

  /// Compute break-even points between consecutive franchise levels.
  static List<BreakEvenPoint> _computeBreakEvenPoints(
    double primeMensuelleBase,
    List<int> levels,
    double cap,
  ) {
    final points = <BreakEvenPoint>[];

    for (int i = 0; i < levels.length - 1; i++) {
      final low = levels[i];
      final high = levels[i + 1];

      final savingsLow = premiumSavingsVs300[low] ?? 0.0;
      final savingsHigh = premiumSavingsVs300[high] ?? 0.0;

      final primeLow = primeMensuelleBase * 12 * (1 - savingsLow);
      final primeHigh = primeMensuelleBase * 12 * (1 - savingsHigh);

      // Premium difference (high franchise has lower premium)
      final premiumDiff = primeLow - primeHigh;

      // Franchise difference (high franchise costs more out of pocket
      // when expenses exceed the low franchise)
      final franchiseDiff = high - low;

      // Break-even: expenses level where higher franchise becomes
      // more expensive than lower franchise.
      // At break-even: premiumDiff = franchiseDiff (simplified)
      // More precise: includes quote-part effects
      if (franchiseDiff > 0 && premiumDiff > 0) {
        // Simplified break-even (ignoring quote-part cap)
        // costLow = primeLow + min(D, low) + min(max(D-low,0)*0.10, cap)
        // costHigh = primeHigh + min(D, high) + min(max(D-high,0)*0.10, cap)
        // At break-even costLow == costHigh
        // When low < D < high:
        // primeLow + low + (D-low)*0.10 = primeHigh + D
        // premiumDiff + low + 0.10*D - 0.10*low = D
        // premiumDiff + 0.90*low = 0.90*D
        // D = (premiumDiff + 0.90 * low) / 0.90
        final seuil = (premiumDiff + 0.90 * low) / 0.90;

        points.add(BreakEvenPoint(
          franchiseBasse: low,
          franchiseHaute: high,
          seuilDepenses: seuil.clamp(0, 50000),
        ));
      }
    }

    return points;
  }

  /// Build recommendations based on analysis.
  static List<String> _buildRecommandations(
    int optimalFranchise,
    double depenses,
    List<FranchiseComparison> comparisons,
  ) {
    final recs = <String>[];

    if (depenses < 500) {
      recs.add(
        'Avec des frais de santé estimés faibles (< CHF\u00A0500/an), '
        'une franchise élevée (CHF\u00A02\'500) pourrait être avantageuse. '
        'Source : LAMal art. 62.',
      );
    } else if (depenses > 3000) {
      recs.add(
        'Avec des frais de santé estimés élevés (> CHF\u00A03\'000/an), '
        'une franchise basse (CHF\u00A0300) pourrait être plus économique. '
        'Source : LAMal art. 62.',
      );
    }

    recs.add(
      'Comparez les primes de différents assureurs sur '
      'priminfo.admin.ch (comparateur officiel). '
      'Les écarts de prime peuvent dépasser CHF\u00A0200/mois '
      'pour des prestations équivalentes. Source : LAMal art. 7.',
    );

    recs.add(
      'Envisagez un modèle d\'assurance alternatif (médecin '
      'de famille, HMO, télémédecine) pour réduire davantage '
      'tes primes. Source : LAMal art. 41a.',
    );

    return recs;
  }

  /// Format CHF with Swiss apostrophe.
  static String formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }
}

// ════════════════════════════════════════════════════════════
//  2. COVERAGE CHECK SERVICE
// ════════════════════════════════════════════════════════════

/// A single coverage checklist item.
class CoverageCheckItem {
  final String id;
  final String title;
  final String description;
  final String urgency; // "critique", "haute", "moyenne", "basse"
  final String status; // "couvert", "non_couvert", "a_verifier"
  final String estimatedCostRange;
  final String source;
  final IconType iconType;

  const CoverageCheckItem({
    required this.id,
    required this.title,
    required this.description,
    required this.urgency,
    required this.status,
    required this.estimatedCostRange,
    required this.source,
    required this.iconType,
  });
}

/// Icon type for coverage items (avoids Flutter dependency in service).
enum IconType {
  shield,
  home,
  gavel,
  flight,
  favorite,
  localHospital,
  warning,
  work,
}

/// Full coverage check result.
class CoverageCheckResult {
  final List<CoverageCheckItem> checklist;
  final int scoreCouverture; // 0-100
  final int lacunesCritiques;
  final List<String> recommandations;
  final String disclaimer;

  const CoverageCheckResult({
    required this.checklist,
    required this.scoreCouverture,
    required this.lacunesCritiques,
    required this.recommandations,
    required this.disclaimer,
  });
}

/// Service for evaluating insurance coverage completeness.
///
/// Checks 8 insurance types against the user's profile
/// and provides urgency-ranked recommendations.
class CoverageCheckService {
  // ── Public API ─────────────────────────────────────────────

  /// Evaluate coverage based on profile and current insurance.
  static CoverageCheckResult evaluateCoverage({
    required String statutProfessionnel, // "salarie", "independant", "sans_emploi"
    required bool aHypotheque,
    required bool aFamille,
    required bool estLocataire,
    required bool voyagesFrequents,
    required bool aIjmCollective,
    required bool aLaa,
    required bool aRcPrivee,
    required bool aMenage,
    required bool aProtectionJuridique,
    required bool aAssuranceVoyage,
    required bool aAssuranceDeces,
    required String canton,
  }) {
    final isIndependant = statutProfessionnel == 'independant';
    final isSalarie = statutProfessionnel == 'salarie';

    final checklist = <CoverageCheckItem>[];

    // 1. RC privee — always recommended
    checklist.add(CoverageCheckItem(
      id: 'rc_privee',
      title: 'RC privée',
      description: 'Responsabilité civile privée — couvre les dommages '
          'causés à des tiers dans la vie privée.',
      urgency: 'haute',
      status: aRcPrivee ? 'couvert' : 'non_couvert',
      estimatedCostRange: '~80-150 CHF/an',
      source: 'CO art. 41',
      iconType: IconType.shield,
    ));

    // 2. Assurance menage
    checklist.add(CoverageCheckItem(
      id: 'menage',
      title: 'Assurance ménage',
      description: 'Couvre le mobilier et les effets personnels '
          'contre le vol, l\'incendie et les dégâts des eaux. '
          'Obligatoire dans les cantons VD, FR, NW, JU.',
      urgency: _menageUrgency(estLocataire, canton),
      status: aMenage ? 'couvert' : 'non_couvert',
      estimatedCostRange: '~100-300 CHF/an',
      source: 'Droit cantonal / Pratique',
      iconType: IconType.home,
    ));

    // 3. Protection juridique
    checklist.add(CoverageCheckItem(
      id: 'juridique',
      title: 'Protection juridique',
      description: 'Couvre les frais d\'avocat et de procédure '
          'en cas de litige (travail, bail, consommation).',
      urgency: estLocataire ? 'moyenne' : 'basse',
      status: aProtectionJuridique ? 'couvert' : 'non_couvert',
      estimatedCostRange: '~200-400 CHF/an',
      source: 'Pratique assurance',
      iconType: IconType.gavel,
    ));

    // 4. Assurance voyage
    checklist.add(CoverageCheckItem(
      id: 'voyage',
      title: 'Assurance voyage',
      description: 'Couvre l\'annulation, les frais médicaux à '
          'l\'étranger et le rapatriement.',
      urgency: voyagesFrequents ? 'moyenne' : 'basse',
      status: aAssuranceVoyage ? 'couvert' : (voyagesFrequents ? 'non_couvert' : 'a_verifier'),
      estimatedCostRange: '~50-150 CHF/an',
      source: 'LAMal art. 34 (couverture limitée à l\'étranger)',
      iconType: IconType.flight,
    ));

    // 5. Assurance deces
    checklist.add(CoverageCheckItem(
      id: 'deces',
      title: 'Assurance décès',
      description: 'Verse un capital aux proches en cas de décès. '
          'Importante si hypothèque ou personnes à charge.',
      urgency: (aHypotheque || aFamille) ? 'haute' : 'basse',
      status: aAssuranceDeces ? 'couvert' : ((aHypotheque || aFamille) ? 'non_couvert' : 'a_verifier'),
      estimatedCostRange: '~100-500 CHF/an',
      source: 'LCA / Pratique bancaire hypothécaire',
      iconType: IconType.favorite,
    ));

    // 6. IJM individuelle
    checklist.add(CoverageCheckItem(
      id: 'ijm',
      title: 'IJM (indemnité journalière maladie)',
      description: 'Couvre 80% du salaire en cas de maladie prolongée. '
          '${isIndependant ? "En tant qu\'indépendant, aucune couverture automatique." : "Vérifie si ton employeur propose une IJM collective."}',
      urgency: _ijmUrgency(isIndependant, isSalarie, aIjmCollective),
      status: _ijmStatus(isIndependant, isSalarie, aIjmCollective),
      estimatedCostRange: '~500-2\'000 CHF/an',
      source: 'CO art. 324a / LAMal',
      iconType: IconType.localHospital,
    ));

    // 7. LAA privee
    checklist.add(CoverageCheckItem(
      id: 'laa',
      title: 'LAA (assurance accident)',
      description: 'Couvre les frais médicaux et la perte de gain '
          'en cas d\'accident. '
          '${isIndependant ? "Non obligatoire pour les indépendants." : "Obligatoire via l\'employeur pour les salariés."}',
      urgency: _laaUrgency(isIndependant, isSalarie, aLaa),
      status: _laaStatus(isIndependant, isSalarie, aLaa),
      estimatedCostRange: '~300-800 CHF/an',
      source: 'LAA art. 4',
      iconType: IconType.warning,
    ));

    // 8. RC professionnelle (independants only)
    if (isIndependant) {
      checklist.add(const CoverageCheckItem(
        id: 'rc_pro',
        title: 'RC professionnelle',
        description: 'Couvre les dommages causés à des tiers dans le '
            'cadre de l\'activité professionnelle.',
        urgency: 'haute',
        status: 'a_verifier',
        estimatedCostRange: 'Variable selon activité',
        source: 'CO art. 41',
        iconType: IconType.work,
      ));
    }

    // Sort by urgency (critique first, then haute, moyenne, basse)
    checklist.sort((a, b) => _urgencyOrder(a.urgency).compareTo(_urgencyOrder(b.urgency)));

    // Compute score
    final scoreCouverture = _computeScore(checklist);

    // Count critical gaps
    final lacunesCritiques = checklist
        .where((item) => item.urgency == 'critique' && item.status != 'couvert')
        .length;

    // Build recommendations
    final recommandations = _buildRecommendations(checklist, isIndependant);

    return CoverageCheckResult(
      checklist: checklist,
      scoreCouverture: scoreCouverture,
      lacunesCritiques: lacunesCritiques,
      recommandations: recommandations,
      disclaimer: 'Cette analyse est indicative et ne constitue pas '
          'un conseil en assurance personnalisé. Les primes varient '
          'selon l\'assureur et ton profil. Consulte un·e spécialiste '
          'en assurances pour une évaluation complète.',
    );
  }

  // ── Private helpers ────────────────────────────────────────

  static String _ijmUrgency(bool isIndependant, bool isSalarie, bool aIjmCollective) {
    if (isIndependant && !aIjmCollective) return 'critique';
    if (isSalarie && aIjmCollective) return 'basse';
    if (isSalarie && !aIjmCollective) return 'moyenne';
    return 'haute';
  }

  static String _ijmStatus(bool isIndependant, bool isSalarie, bool aIjmCollective) {
    if (aIjmCollective) return 'couvert';
    if (isSalarie) return 'a_verifier';
    return 'non_couvert';
  }

  static String _laaUrgency(bool isIndependant, bool isSalarie, bool aLaa) {
    if (isIndependant && !aLaa) return 'critique';
    if (isSalarie) return 'basse'; // obligatoire via employeur
    return 'haute';
  }

  static String _laaStatus(bool isIndependant, bool isSalarie, bool aLaa) {
    if (aLaa) return 'couvert';
    if (isSalarie) return 'a_verifier'; // obligatoire via employeur, mais a verifier
    return 'non_couvert';
  }

  static String _menageUrgency(bool estLocataire, String canton) {
    // Obligatoire dans les cantons VD, FR, NW, JU
    const cantonsMenageObligatoire = ['VD', 'FR', 'NW', 'JU'];
    if (cantonsMenageObligatoire.contains(canton)) return 'haute';
    if (estLocataire) return 'moyenne';
    return 'basse';
  }

  static int _urgencyOrder(String urgency) {
    switch (urgency) {
      case 'critique':
        return 0;
      case 'haute':
        return 1;
      case 'moyenne':
        return 2;
      case 'basse':
        return 3;
      default:
        return 4;
    }
  }

  static int _computeScore(List<CoverageCheckItem> checklist) {
    if (checklist.isEmpty) return 0;

    int covered = 0;
    int total = 0;

    for (final item in checklist) {
      // Weight by urgency
      final weight = switch (item.urgency) {
        'critique' => 3,
        'haute' => 2,
        'moyenne' => 1,
        _ => 1,
      };

      total += weight;
      if (item.status == 'couvert') {
        covered += weight;
      } else if (item.status == 'a_verifier') {
        covered += (weight * 0.5).round();
      }
    }

    return total > 0 ? ((covered / total) * 100).round().clamp(0, 100) : 0;
  }

  static List<String> _buildRecommendations(
    List<CoverageCheckItem> checklist,
    bool isIndependant,
  ) {
    final recs = <String>[];

    // Critical items first
    final critiques = checklist.where(
      (item) => item.urgency == 'critique' && item.status != 'couvert',
    );
    for (final item in critiques) {
      recs.add(
        'PRIORITÉ : ${item.title} — ${item.description} '
        'Coût estimé : ${item.estimatedCostRange}. '
        'Source : ${item.source}.',
      );
    }

    // High urgency items
    final hautes = checklist.where(
      (item) => item.urgency == 'haute' && item.status != 'couvert',
    );
    for (final item in hautes) {
      recs.add(
        '${item.title} — ${item.description} '
        'Coût estimé : ${item.estimatedCostRange}. '
        'Source : ${item.source}.',
      );
    }

    // General recommendation
    recs.add(
      'Demandez plusieurs offres pour comparer les primes et '
      'les conditions. Les écarts peuvent être significatifs '
      'entre assureurs.',
    );

    return recs;
  }
}
