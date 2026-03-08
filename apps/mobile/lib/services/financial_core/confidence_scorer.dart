import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/bayesian_enricher.dart';

/// Enrichment action to improve confidence.
class EnrichmentPrompt {
  final String label;
  final int impact; // percentage points of confidence gained
  final String category; // 'lpp', 'avs', '3a', 'patrimoine', 'foreign_pension'
  final String action; // short description of what to do

  const EnrichmentPrompt({
    required this.label,
    required this.impact,
    required this.category,
    required this.action,
  });
}

/// Projection confidence result.
class ProjectionConfidence {
  final double score; // 0-100
  final String level; // 'low', 'medium', 'high'
  final List<EnrichmentPrompt> prompts;
  final List<String> assumptions;

  /// Bayesian enrichment result with posterior estimates, credibility
  /// intervals, and EVI-ranked prompts. Null only on error.
  final BayesianEnrichmentResult? bayesianResult;

  const ProjectionConfidence({
    required this.score,
    required this.level,
    required this.prompts,
    required this.assumptions,
    this.bayesianResult,
  });
}

/// Score for a single data block (used by UI to show per-bloc progress).
class BlockScore {
  final double score;
  final double maxScore;
  final String status; // 'complete', 'partial', 'missing'

  const BlockScore({
    required this.score,
    required this.maxScore,
    required this.status,
  });
}

/// Confidence scorer for retirement projections — V2.
///
/// Scores 0-100 based on data completeness per profile.
/// Each missing data point reduces the score and generates
/// an enrichment prompt to guide the user.
///
/// V2 changes (P8 Phase 3):
/// - Added objectifRetraite (10 pts) — LAVS art. 21 (age legal)
/// - Added compositionMenage (15 pts) — LPP art. 19 (rente survivant)
/// - Redistributed weights: total remains 100
/// - Added scoreAsBlocs() for per-block UI display
///
/// Weight table (V2):
/// | Component          | Max | Source              |
/// |--------------------|-----|---------------------|
/// | Salaire            |  12 | —                   |
/// | Age + Canton       |   8 | —                   |
/// | Archetype          |   5 | —                   |
/// | Objectif retraite  |  10 | LAVS art. 21        |
/// | Menage (couple)    |  15 | LPP art. 19         |
/// | LPP avoir reel     |  18 | LPP art. 15         |
/// | Taux conversion    |   5 | LPP art. 14         |
/// | AVS extrait        |  10 | LAVS art. 29        |
/// | 3a soldes          |   8 | OPP3 art. 7         |
/// | Patrimoine         |   7 | —                   |
/// | Foreign pension    |   2 | —                   |
/// | **Total**          | 100 |                     |
///
/// Reference: ADR-20260223-archetype-driven-retirement.md
class ConfidenceScorer {
  ConfidenceScorer._();

  // ── Component weights (V2) ─────────────────────────────────────
  static const int _wSalaire = 12;
  static const int _wAgeCanton = 8;
  static const int _wArchetype = 5;
  static const int _wObjectifRetraite = 10;
  static const int _wMenage = 15;
  static const int _wLpp = 18;
  static const int _wTauxConversion = 5;
  static const int _wAvs = 10;
  static const int _w3a = 8;
  static const int _wPatrimoine = 7;
  static const int _wForeignPension = 2;

  /// Sum of all weights — invariant = 100.
  static const int totalWeight = _wSalaire +
      _wAgeCanton +
      _wArchetype +
      _wObjectifRetraite +
      _wMenage +
      _wLpp +
      _wTauxConversion +
      _wAvs +
      _w3a +
      _wPatrimoine +
      _wForeignPension;

  /// Minimum confidence score (0-100) to display projections.
  /// Below this threshold, show enrichment prompts instead.
  static const double minConfidenceForProjection = 40.0;

  /// Score projection confidence based on profile completeness.
  static ProjectionConfidence score(CoachProfile profile) {
    double total = 0;
    final prompts = <EnrichmentPrompt>[];
    final assumptions = <String>[];

    // --- Salaire (12 pts) ---
    if (profile.salaireBrutMensuel > 0) {
      total += _wSalaire;
    } else {
      assumptions.add('Salaire non renseigne — estimation impossible');
      prompts.add(const EnrichmentPrompt(
        label: 'Ajoute ton salaire',
        impact: _wSalaire,
        category: 'income',
        action: 'Renseigne ton salaire brut mensuel',
      ));
    }

    // --- Age + canton (8 pts) ---
    if (profile.age > 0 && profile.canton.isNotEmpty) {
      total += _wAgeCanton;
    } else {
      assumptions.add('Age ou canton manquant');
    }

    // --- Archetype detectable (5 pts) ---
    if (_hasArchetypeSignals(profile)) {
      total += _wArchetype;
    }

    // --- Objectif retraite (10 pts) — LAVS art. 21 ---
    // Any explicit choice (including 65) means the user has considered it.
    if (profile.targetRetirementAge != null) {
      total += _wObjectifRetraite;
    } else {
      total += 3;
      prompts.add(const EnrichmentPrompt(
        label: 'Fixe un objectif retraite',
        impact: 7,
        category: 'objectif_retraite',
        action: 'A quel age souhaites-tu prendre ta retraite ? (58-70)',
      ));
    }

    // --- Composition menage (15 pts) — LPP art. 19 ---
    final isCoupled = profile.etatCivil == CoachCivilStatus.marie ||
        profile.etatCivil == CoachCivilStatus.concubinage;
    // Explicitly declared single/divorced/widowed: full points.
    // Default celibataire (never explicitly set): partial points only,
    // since ~50% of Swiss residents are in couples (BFS, 2024).
    final isExplicitlySingle = !isCoupled &&
        (profile.etatCivil == CoachCivilStatus.divorce ||
         profile.etatCivil == CoachCivilStatus.veuf);
    if (isExplicitlySingle) {
      total += _wMenage;
    } else if (!isCoupled) {
      // Default celibataire — not confirmed, give partial credit
      total += 5;
      prompts.add(const EnrichmentPrompt(
        label: 'Indique ta situation familiale',
        impact: 10,
        category: 'menage',
        action: 'Celibataire, en couple, marie·e ? Impact sur AVS et impots.',
      ));
    } else if (profile.conjoint == null) {
      // Coupled but no partner data at all
      prompts.add(const EnrichmentPrompt(
        label: 'Ajoute les infos de ton\u00b7ta partenaire',
        impact: _wMenage,
        category: 'menage',
        action: 'Revenu et age de ton\u00b7ta partenaire pour des projections couple',
      ));
    } else {
      final hasRevenu = profile.conjoint!.salaireBrutMensuel != null &&
          profile.conjoint!.salaireBrutMensuel! > 0;
      final hasAge = profile.conjoint!.birthYear != null;
      if (hasRevenu && hasAge) {
        total += _wMenage;
      } else if (hasRevenu || hasAge) {
        total += 8;
        prompts.add(const EnrichmentPrompt(
          label: 'Complete le profil partenaire',
          impact: 7,
          category: 'menage',
          action: 'Ajoute le revenu et l\'age de ton\u00b7ta partenaire',
        ));
      } else {
        prompts.add(const EnrichmentPrompt(
          label: 'Ajoute les infos de ton\u00b7ta partenaire',
          impact: _wMenage,
          category: 'menage',
          action: 'Revenu et age pour des projections couple fiables',
        ));
      }
    }

    // --- LPP avoir reel (18 pts) — LPP art. 15 ---
    final lppDeclared = profile.prevoyance.avoirLppTotal;
    final isIndepSansLpp = profile.employmentStatus == 'independant' &&
        (lppDeclared == null || lppDeclared <= 0);
    if (lppDeclared != null && lppDeclared > 0) {
      // Declared LPP — partial credit (estimated from salary)
      total += 11;
      prompts.add(const EnrichmentPrompt(
        label: 'Confirme ton solde LPP',
        impact: 7,
        category: 'lpp',
        action: 'Ajoute ton certificat de prevoyance (solde exact)',
      ));
      assumptions.add('LPP estime depuis le salaire — peut varier de +-30%');
    } else if (isIndepSansLpp) {
      // Independent without LPP: not applicable
      total += _wLpp;
    } else {
      assumptions.add('Avoir LPP non renseigne — estimation depuis le salaire');
      prompts.add(const EnrichmentPrompt(
        label: 'Ajoute ton solde LPP',
        impact: _wLpp,
        category: 'lpp',
        action: 'Ajoute ton certificat de prevoyance (solde exact)',
      ));
    }

    // --- Taux conversion reel (5 pts) — LPP art. 14 ---
    if (isIndepSansLpp) {
      total += _wTauxConversion; // Not applicable
    } else {
      final tauxConv = profile.prevoyance.tauxConversion;
      if (tauxConv != 0.068) {
        total += _wTauxConversion;
      } else {
        total += 1;
        prompts.add(const EnrichmentPrompt(
          label: 'Taux de conversion reel',
          impact: 4,
          category: 'lpp',
          action: 'Lis ton certificat de prevoyance (taux enveloppe)',
        ));
        assumptions.add(
            'Taux de conversion LPP: minimum legal 6.8% (reel souvent 5-6%)');
      }
    }

    // --- Extrait AVS (10 pts) — LAVS art. 29 ---
    final hasAvsData = profile.prevoyance.anneesContribuees != null;
    if (hasAvsData) {
      total += _wAvs;
    } else {
      total += 3; // Basic AVS estimate from age
      prompts.add(const EnrichmentPrompt(
        label: 'Commande ton extrait AVS',
        impact: 7,
        category: 'avs',
        action: 'Gratuit sur inforegister.ch — annees effectives',
      ));
      assumptions.add('Annees AVS estimees depuis l\'age — lacunes possibles');
    }

    // --- Soldes 3a reels (8 pts) — OPP3 art. 7 ---
    final has3a = profile.prevoyance.totalEpargne3a > 0;
    if (has3a) {
      total += _w3a;
    } else {
      total += 1;
      prompts.add(const EnrichmentPrompt(
        label: 'Ajoute tes soldes 3a',
        impact: 7,
        category: '3a',
        action: 'Saisis tes soldes 3e pilier (chaque compte)',
      ));
    }

    // --- Patrimoine detaille (7 pts) ---
    final hasPatrimoine = profile.patrimoine.totalPatrimoine > 0;
    if (hasPatrimoine) {
      total += _wPatrimoine;
    } else {
      total += 1;
      prompts.add(const EnrichmentPrompt(
        label: 'Renseigne ton patrimoine',
        impact: 6,
        category: 'patrimoine',
        action: 'Epargne, investissements, immobilier',
      ));
    }

    // --- Fiscalite (enrichment prompts, no weight impact) ---
    if (profile.commune == null || profile.commune!.isEmpty) {
      prompts.add(const EnrichmentPrompt(
        label: 'Ajoute ta commune',
        impact: 4,
        category: 'fiscalite',
        action: 'Le coefficient communal impacte ton taux d\'imposition de 60% a 130%',
      ));
    }
    final ds = profile.dataSources;
    if (ds['tauxMarginal'] != ProfileDataSource.certificate) {
      prompts.add(const EnrichmentPrompt(
        label: 'Scanne ta declaration fiscale',
        impact: 8,
        category: 'fiscalite',
        action: 'Taux marginal reel + revenu imposable + fortune (LIFD art. 38)',
      ));
    }

    // --- Foreign pension (2 pts, only for expats) ---
    final isExpat = profile.arrivalAge != null && profile.arrivalAge! > 21;
    if (isExpat) {
      prompts.add(const EnrichmentPrompt(
        label: 'Pension etrangere',
        impact: _wForeignPension,
        category: 'foreign_pension',
        action: 'As-tu des droits a une retraite dans ton pays d\'origine?',
      ));
      assumptions.add('Pension etrangere non modelisee');
    } else {
      total += _wForeignPension;
    }

    // ── Age-weighted penalties for 50+ ──────────────────────
    // At 50+, retirement-critical data gaps are MORE impactful.
    // Missing LPP/AVS/taux at 58 is CRITICAL — not just "nice to have".
    if (profile.age >= 50) {
      final yearsLeft = profile.effectiveRetirementAge - profile.age;
      final urgencyLabel = yearsLeft <= 5
          ? 'URGENT'
          : yearsLeft <= 10
              ? 'IMPORTANT'
              : 'NORMAL';

      // Extra penalty for missing retirement-critical data
      if (lppDeclared == null || lppDeclared <= 0) {
        if (!isIndepSansLpp) total -= 5; // LPP missing: extra -5
      }
      if (!hasAvsData) {
        total -= 5; // AVS extrait missing: extra -5
      }
      if (!isIndepSansLpp &&
          profile.prevoyance.tauxConversion == 0.068) {
        total -= 3; // Default taux: extra -3
      }

      // Retirement urgency enrichment prompt
      prompts.add(EnrichmentPrompt(
        label: 'Plus que $yearsLeft ans avant ta retraite',
        impact: yearsLeft <= 5 ? 15 : 10,
        category: 'retirement_urgency',
        action: urgencyLabel == 'URGENT'
            ? 'Chaque mois compte — confirme tes donnees de prevoyance'
            : 'Affine tes projections pour une vision claire',
      ));
    }

    // Clamp to 0-100
    total = total.clamp(0, 100);

    // Compute Bayesian enrichment for EVI-ranked prompts
    final bayesianResult = BayesianProfileEnricher.enrich(profile);

    // Re-rank prompts using Bayesian EVI ordering:
    // Map each existing prompt's category to the Bayesian EVI ranking
    final eviOrder = <String, double>{};
    for (final eviPrompt in bayesianResult.rankedPrompts) {
      eviOrder[eviPrompt.category] = eviPrompt.evi;
    }
    prompts.sort((a, b) {
      final eviA = eviOrder[a.category] ?? 0;
      final eviB = eviOrder[b.category] ?? 0;
      if (eviA != eviB) return eviB.compareTo(eviA); // EVI descending
      return b.impact.compareTo(a.impact); // fallback: impact
    });

    // Determine level
    final level = total >= 70
        ? 'high'
        : total >= 40
            ? 'medium'
            : 'low';

    return ProjectionConfidence(
      score: total,
      level: level,
      prompts: prompts,
      assumptions: assumptions,
      bayesianResult: bayesianResult,
    );
  }

  /// Return the score decomposed by data block (for UI display).
  ///
  /// Keys: 'revenu', 'age_canton', 'archetype', 'objectifRetraite',
  ///        'compositionMenage', 'lpp', 'taux_conversion', 'avs',
  ///        '3a', 'patrimoine', 'foreign_pension'.
  static Map<String, BlockScore> scoreAsBlocs(CoachProfile profile) {
    final blocs = <String, BlockScore>{};

    // --- Salaire ---
    final salaire = profile.salaireBrutMensuel > 0
        ? _wSalaire.toDouble()
        : 0.0;
    blocs['revenu'] = BlockScore(
      score: salaire,
      maxScore: _wSalaire.toDouble(),
      status: salaire == _wSalaire ? 'complete' : 'missing',
    );

    // --- Age + Canton ---
    final ageCanton = (profile.age > 0 && profile.canton.isNotEmpty)
        ? _wAgeCanton.toDouble()
        : 0.0;
    blocs['age_canton'] = BlockScore(
      score: ageCanton,
      maxScore: _wAgeCanton.toDouble(),
      status: ageCanton == _wAgeCanton ? 'complete' : 'missing',
    );

    // --- Archetype ---
    final archetype = _hasArchetypeSignals(profile)
        ? _wArchetype.toDouble()
        : 0.0;
    blocs['archetype'] = BlockScore(
      score: archetype,
      maxScore: _wArchetype.toDouble(),
      status: archetype == _wArchetype ? 'complete' : 'missing',
    );

    // --- Objectif retraite ---
    final hasExplicitRetirement = profile.targetRetirementAge != null;
    final objectifScore = hasExplicitRetirement ? _wObjectifRetraite.toDouble() : 3.0;
    blocs['objectifRetraite'] = BlockScore(
      score: objectifScore,
      maxScore: _wObjectifRetraite.toDouble(),
      status: hasExplicitRetirement ? 'complete' : 'partial',
    );

    // --- Composition menage ---
    final isCoupled = profile.etatCivil == CoachCivilStatus.marie ||
        profile.etatCivil == CoachCivilStatus.concubinage;
    double menageScore;
    String menageStatus;
    if (!isCoupled) {
      menageScore = _wMenage.toDouble();
      menageStatus = 'complete';
    } else if (profile.conjoint == null) {
      menageScore = 0;
      menageStatus = 'missing';
    } else {
      final hasRevenu = profile.conjoint!.salaireBrutMensuel != null &&
          profile.conjoint!.salaireBrutMensuel! > 0;
      final hasAge = profile.conjoint!.birthYear != null;
      if (hasRevenu && hasAge) {
        menageScore = _wMenage.toDouble();
        menageStatus = 'complete';
      } else if (hasRevenu || hasAge) {
        menageScore = 8;
        menageStatus = 'partial';
      } else {
        menageScore = 0;
        menageStatus = 'missing';
      }
    }
    blocs['compositionMenage'] = BlockScore(
      score: menageScore,
      maxScore: _wMenage.toDouble(),
      status: menageStatus,
    );

    // --- LPP ---
    final lppDeclared = profile.prevoyance.avoirLppTotal;
    final isIndepSansLpp = profile.employmentStatus == 'independant' &&
        (lppDeclared == null || lppDeclared <= 0);
    double lppScore;
    String lppStatus;
    if (lppDeclared != null && lppDeclared > 0) {
      lppScore = 11;
      lppStatus = 'partial';
    } else if (isIndepSansLpp) {
      lppScore = _wLpp.toDouble();
      lppStatus = 'complete';
    } else {
      lppScore = 0;
      lppStatus = 'missing';
    }
    blocs['lpp'] = BlockScore(
      score: lppScore,
      maxScore: _wLpp.toDouble(),
      status: lppStatus,
    );

    // --- Taux conversion ---
    double tauxScore;
    String tauxStatus;
    if (isIndepSansLpp) {
      tauxScore = _wTauxConversion.toDouble();
      tauxStatus = 'complete';
    } else if (profile.prevoyance.tauxConversion != 0.068) {
      tauxScore = _wTauxConversion.toDouble();
      tauxStatus = 'complete';
    } else {
      tauxScore = 1;
      tauxStatus = 'partial';
    }
    blocs['taux_conversion'] = BlockScore(
      score: tauxScore,
      maxScore: _wTauxConversion.toDouble(),
      status: tauxStatus,
    );

    // --- AVS ---
    final hasAvsData = profile.prevoyance.anneesContribuees != null;
    blocs['avs'] = BlockScore(
      score: hasAvsData ? _wAvs.toDouble() : 3.0,
      maxScore: _wAvs.toDouble(),
      status: hasAvsData ? 'complete' : 'partial',
    );

    // --- 3a ---
    final has3a = profile.prevoyance.totalEpargne3a > 0;
    blocs['3a'] = BlockScore(
      score: has3a ? _w3a.toDouble() : 1.0,
      maxScore: _w3a.toDouble(),
      status: has3a ? 'complete' : 'partial',
    );

    // --- Patrimoine ---
    final hasPatrimoine = profile.patrimoine.totalPatrimoine > 0;
    blocs['patrimoine'] = BlockScore(
      score: hasPatrimoine ? _wPatrimoine.toDouble() : 1.0,
      maxScore: _wPatrimoine.toDouble(),
      status: hasPatrimoine ? 'complete' : 'partial',
    );

    // --- Fiscalite (virtual bloc — synthesized from commune/tax data) ---
    // Max 15 pts (distributed from existing weights, not additive):
    //   Commune connue: +4 (improves tax estimate precision)
    //   Revenu imposable connu: +4 (from tax declaration)
    //   Fortune imposable: +3
    //   Taux marginal reel: +4 (from avis de taxation)
    double fiscalScore = 0;
    const fiscalMax = 15.0;
    if (profile.commune != null && profile.commune!.isNotEmpty) {
      fiscalScore += 4;
    }
    // dataSources tracks whether values were user-provided vs estimated
    final ds = profile.dataSources;
    if (ds['revenuImposable'] == ProfileDataSource.certificate ||
        ds['revenuImposable'] == ProfileDataSource.userInput) {
      fiscalScore += 4;
    }
    if (ds['fortuneImposable'] == ProfileDataSource.certificate ||
        ds['fortuneImposable'] == ProfileDataSource.userInput) {
      fiscalScore += 3;
    }
    if (ds['tauxMarginal'] == ProfileDataSource.certificate) {
      fiscalScore += 4;
    }
    blocs['fiscalite'] = BlockScore(
      score: fiscalScore,
      maxScore: fiscalMax,
      status: fiscalScore >= 11
          ? 'complete'
          : fiscalScore > 0
              ? 'partial'
              : 'missing',
    );

    // --- Foreign pension ---
    final isExpat = profile.arrivalAge != null && profile.arrivalAge! > 21;
    blocs['foreign_pension'] = BlockScore(
      score: isExpat ? 0.0 : _wForeignPension.toDouble(),
      maxScore: _wForeignPension.toDouble(),
      status: isExpat ? 'missing' : 'complete',
    );

    // ── Age-weighted penalties for 50+ (distribute to affected blocs) ──
    // Mirrors score() penalties: -5 LPP, -5 AVS, -3 taux for missing data.
    if (profile.age >= 50) {
      if (lppDeclared == null || lppDeclared <= 0) {
        if (!isIndepSansLpp) {
          final lpp = blocs['lpp']!;
          blocs['lpp'] = BlockScore(
            score: (lpp.score - 5).clamp(0, lpp.maxScore),
            maxScore: lpp.maxScore,
            status: lpp.score - 5 <= 0 ? 'missing' : lpp.status,
          );
        }
      }
      if (!hasAvsData) {
        final avs = blocs['avs']!;
        blocs['avs'] = BlockScore(
          score: (avs.score - 5).clamp(0, avs.maxScore),
          maxScore: avs.maxScore,
          status: avs.score - 5 <= 0 ? 'missing' : avs.status,
        );
      }
      if (!isIndepSansLpp &&
          profile.prevoyance.tauxConversion == 0.068) {
        final taux = blocs['taux_conversion']!;
        blocs['taux_conversion'] = BlockScore(
          score: (taux.score - 3).clamp(0, taux.maxScore),
          maxScore: taux.maxScore,
          status: taux.score - 3 <= 0 ? 'missing' : taux.status,
        );
      }
    }

    return blocs;
  }

  /// Check if profile has enough data to determine archetype.
  static bool _hasArchetypeSignals(CoachProfile profile) {
    // Nationality or arrival age or employment status → can detect archetype
    return profile.employmentStatus.isNotEmpty ||
        profile.arrivalAge != null ||
        profile.residencePermit != null;
  }
}
