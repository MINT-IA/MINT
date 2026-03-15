import 'dart:math' as math;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
  ///
  /// Pass [s] (from `S.of(context)!`) to get localized user-facing text.
  /// When [s] is null, hardcoded French fallbacks are used (for service callers
  /// without BuildContext that only need numeric scores).
  static ProjectionConfidence score(CoachProfile profile, {S? s}) {
    double total = 0;
    final prompts = <EnrichmentPrompt>[];
    final assumptions = <String>[];

    // --- Salaire (12 pts) ---
    if (profile.salaireBrutMensuel > 0) {
      total += _wSalaire;
    } else {
      assumptions.add(s?.confidenceScorerAssumptionSalaireMissing ?? 'Salaire non renseigné\u00a0— estimation impossible');
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptSalaireLabel ?? 'Ajoute ton salaire',
        impact: _wSalaire,
        category: 'income',
        action: s?.confidenceScorerPromptSalaireAction ?? 'Renseigne ton salaire brut mensuel',
      ));
    }

    // --- Age + canton (8 pts) ---
    if (profile.age > 0 && profile.canton.isNotEmpty) {
      total += _wAgeCanton;
    } else {
      assumptions.add(s?.confidenceScorerAssumptionAgeCantonMissing ?? 'Âge ou canton manquant');
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
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptObjectifLabel ?? 'Fixe un objectif retraite',
        impact: 7,
        category: 'objectif_retraite',
        action: s?.confidenceScorerPromptObjectifAction ?? 'À quel âge souhaites-tu prendre ta retraite\u00a0? (58-70)',
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
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptFamilleLabel ?? 'Indique ta situation familiale',
        impact: 10,
        category: 'menage',
        action: s?.confidenceScorerPromptFamilleAction ?? 'Célibataire, en couple, marié·e\u00a0? Impact sur AVS et impôts.',
      ));
    } else if (profile.conjoint == null) {
      // Coupled but no partner data at all
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptPartenaireAddLabel ?? 'Ajoute les infos de ton·ta partenaire',
        impact: _wMenage,
        category: 'menage',
        action: s?.confidenceScorerPromptPartenaireAddActionCouple ?? 'Revenu et âge de ton·ta partenaire pour des projections couple',
      ));
    } else {
      final hasRevenu = profile.conjoint!.salaireBrutMensuel != null &&
          profile.conjoint!.salaireBrutMensuel! > 0;
      final hasAge = profile.conjoint!.birthYear != null;
      if (hasRevenu && hasAge) {
        total += _wMenage;
      } else if (hasRevenu || hasAge) {
        total += 8;
        prompts.add(EnrichmentPrompt(
          label: s?.confidenceScorerPromptPartenaireCompleteLabel ?? 'Complète le profil partenaire',
          impact: 7,
          category: 'menage',
          action: s?.confidenceScorerPromptPartenaireCompleteAction ?? 'Ajoute le revenu et l\'âge de ton·ta partenaire',
        ));
      } else {
        prompts.add(EnrichmentPrompt(
          label: s?.confidenceScorerPromptPartenaireAddLabel ?? 'Ajoute les infos de ton·ta partenaire',
          impact: _wMenage,
          category: 'menage',
          action: s?.confidenceScorerPromptPartenaireAddActionFiable ?? 'Revenu et âge pour des projections couple fiables',
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
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptLppConfirmLabel ?? 'Confirme ton solde LPP',
        impact: 7,
        category: 'lpp',
        action: s?.confidenceScorerPromptLppConfirmAction ?? 'Ajoute ton certificat de prévoyance (solde exact)',
      ));
      assumptions.add(s?.confidenceScorerAssumptionLppEstimated ?? 'LPP estimé depuis le salaire\u00a0— peut varier de +-30\u00a0%');
    } else if (isIndepSansLpp) {
      // Independent without LPP: not applicable
      total += _wLpp;
    } else {
      assumptions.add(s?.confidenceScorerAssumptionLppMissing ?? 'Avoir LPP non renseigné\u00a0— estimation depuis le salaire');
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptLppAddLabel ?? 'Ajoute ton solde LPP',
        impact: _wLpp,
        category: 'lpp',
        action: s?.confidenceScorerPromptLppConfirmAction ?? 'Ajoute ton certificat de prévoyance (solde exact)',
      ));
    }

    // --- Taux conversion reel (5 pts) — LPP art. 14 ---
    if (isIndepSansLpp) {
      total += _wTauxConversion; // Not applicable
    } else {
      final tauxConv = profile.prevoyance.tauxConversion;
      if (tauxConv != lppTauxConversionMinDecimal) {
        total += _wTauxConversion;
      } else {
        total += 1;
        prompts.add(EnrichmentPrompt(
          label: s?.confidenceScorerPromptTauxConversionLabel ?? 'Taux de conversion réel',
          impact: 4,
          category: 'lpp',
          action: s?.confidenceScorerPromptTauxConversionAction ?? 'Lis ton certificat de prévoyance (taux enveloppe)',
        ));
        assumptions.add(
            s?.confidenceScorerAssumptionTauxConversion ?? 'Taux de conversion LPP\u00a0: minimum légal 6.8\u00a0% (réel souvent 5-6\u00a0%)');
      }
    }

    // --- Extrait AVS (10 pts) — LAVS art. 29 ---
    final hasAvsData = profile.prevoyance.anneesContribuees != null;
    if (hasAvsData) {
      total += _wAvs;
    } else {
      total += 3; // Basic AVS estimate from age
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptAvsLabel ?? 'Commande ton extrait AVS',
        impact: 7,
        category: 'avs',
        action: s?.confidenceScorerPromptAvsAction ?? 'Gratuit sur inforegister.ch\u00a0— années effectives',
      ));
      assumptions.add(s?.confidenceScorerAssumptionAvsEstimated ?? 'Années AVS estimées depuis l\'âge\u00a0— lacunes possibles');
    }

    // --- Soldes 3a reels (8 pts) — OPP3 art. 7 ---
    final has3a = profile.prevoyance.totalEpargne3a > 0;
    if (has3a) {
      total += _w3a;
    } else {
      total += 1;
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptSoldes3aLabel ?? 'Ajoute tes soldes 3a',
        impact: 7,
        category: '3a',
        action: s?.confidenceScorerPromptSoldes3aAction ?? 'Saisis tes soldes 3e pilier (chaque compte)',
      ));
    }

    // --- Patrimoine detaille (7 pts) ---
    final hasPatrimoine = profile.patrimoine.totalPatrimoine > 0;
    if (hasPatrimoine) {
      total += _wPatrimoine;
    } else {
      total += 1;
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptPatrimoineLabel ?? 'Renseigne ton patrimoine',
        impact: 6,
        category: 'patrimoine',
        action: s?.confidenceScorerPromptPatrimoineAction ?? 'Épargne, investissements, immobilier',
      ));
    }

    // --- Fiscalite (enrichment prompts, no weight impact) ---
    if (profile.commune == null || profile.commune!.isEmpty) {
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptCommuneLabel ?? 'Ajoute ta commune',
        impact: 4,
        category: 'fiscalite',
        action: s?.confidenceScorerPromptCommuneAction ?? 'Le coefficient communal impacte ton taux d\'imposition de 60\u00a0% à 130\u00a0%',
      ));
    }
    final ds = profile.dataSources;
    if (ds['tauxMarginal'] != ProfileDataSource.certificate) {
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptFiscalLabel ?? 'Scanne ta déclaration fiscale',
        impact: 8,
        category: 'fiscalite',
        action: s?.confidenceScorerPromptFiscalAction ?? 'Taux marginal réel + revenu imposable + fortune (LIFD art.\u00a038)',
      ));
    }

    // --- Foreign pension (2 pts, only for expats) ---
    final isExpat = profile.arrivalAge != null && profile.arrivalAge! > 21;
    if (isExpat) {
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptForeignPensionLabel ?? 'Pension étrangère',
        impact: _wForeignPension,
        category: 'foreign_pension',
        action: s?.confidenceScorerPromptForeignPensionAction ?? 'As-tu des droits à une retraite dans ton pays d\'origine\u00a0?',
      ));
      assumptions.add(s?.confidenceScorerAssumptionForeignPension ?? 'Pension étrangère non modélisée');
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
          profile.prevoyance.tauxConversion == lppTauxConversionMinDecimal) {
        total -= 3; // Default taux: extra -3
      }

      // Retirement urgency enrichment prompt
      prompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerPromptUrgencyLabel(yearsLeft) ?? 'Plus que $yearsLeft ans avant ta retraite',
        impact: yearsLeft <= 5 ? 15 : 10,
        category: 'retirement_urgency',
        action: urgencyLabel == 'URGENT'
            ? (s?.confidenceScorerPromptUrgencyActionUrgent ?? 'Chaque mois compte\u00a0— confirme tes données de prévoyance')
            : (s?.confidenceScorerPromptUrgencyActionNormal ?? 'Affine tes projections pour une vision claire'),
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
  static Map<String, BlockScore> scoreAsBlocs(CoachProfile profile, {S? s}) {
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
    } else if (profile.prevoyance.tauxConversion != lppTauxConversionMinDecimal) {
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
          profile.prevoyance.tauxConversion == lppTauxConversionMinDecimal) {
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

  /// Combined call: returns both bloc scores AND projection confidence
  /// in a single profile traversal (avoids double scoring).
  static ({Map<String, BlockScore> blocs, ProjectionConfidence confidence}) scoreWithBlocs(CoachProfile profile, {S? s}) {
    return (
      blocs: scoreAsBlocs(profile, s: s),
      confidence: score(profile, s: s),
    );
  }

  /// Check if profile has enough data to determine archetype.
  static bool _hasArchetypeSignals(CoachProfile profile) {
    // Nationality or arrival age or employment status → can detect archetype
    return profile.employmentStatus.isNotEmpty ||
        profile.arrivalAge != null ||
        profile.residencePermit != null;
  }

  // ════════════════════════════════════════════════════════════════
  //  S46 — ENHANCED 3-AXIS SCORING
  //  completeness × accuracy × freshness → combined confidence
  // ════════════════════════════════════════════════════════════════

  /// Accuracy weight per [ProfileDataSource] — higher = more trustworthy.
  /// Range: 0.25 (system estimate) to 1.00 (live banking data).
  static const Map<ProfileDataSource, double> _accuracyWeights = {
    ProfileDataSource.estimated: 0.25,
    ProfileDataSource.userInput: 0.60,
    ProfileDataSource.crossValidated: 0.70,
    ProfileDataSource.certificate: 0.95,
    ProfileDataSource.openBanking: 1.00,
  };

  /// Key fields tracked for accuracy/freshness scoring.
  /// Each maps to its weight in the completeness score.
  /// Covers the same fields as V2 scorer for symmetric axes.
  static const Map<String, int> _trackedFields = {
    'salaireBrutMensuel': _wSalaire,
    'age': 4,          // split from _wAgeCanton (8 → 4+4)
    'canton': 4,       // split from _wAgeCanton (8 → 4+4)
    'etatCivil': _wMenage,
    'prevoyance.avoirLppTotal': _wLpp,
    'prevoyance.tauxConversion': _wTauxConversion,
    'prevoyance.anneesContribuees': _wAvs,
    'prevoyance.totalEpargne3a': _w3a,
    'patrimoine.epargneLiquide': _wPatrimoine,
  };

  /// Freshness decay: score 1.0 if updated < 6 months ago,
  /// linear decay to 0.5 at 24 months, floor at 0.3 beyond 36 months.
  /// Financial data changes yearly (salary, LPP, 3a contributions),
  /// so stale data is materially less reliable.
  static double _freshnessScore(DateTime? fieldUpdatedAt, DateTime now) {
    if (fieldUpdatedAt == null) return 0.5; // unknown → moderate penalty
    final monthsOld = now.difference(fieldUpdatedAt).inDays / 30.44;
    if (monthsOld <= 6) return 1.0;
    if (monthsOld <= 24) return 1.0 - (monthsOld - 6) / 36; // linear to ~0.5
    if (monthsOld <= 36) return 0.5 - (monthsOld - 24) / 60; // linear to ~0.3
    return 0.3; // floor
  }

  /// Enhanced 3-axis confidence scoring.
  ///
  /// Returns an [EnhancedConfidence] with:
  /// - completeness (0-100): existing V2 score
  /// - accuracy (0-100): weighted average of source quality per field
  /// - freshness (0-100): weighted average of data age per field
  /// - combined (0-100): geometric mean of the three axes
  ///
  /// The geometric mean ensures a zero on any axis pulls the whole score
  /// down — a complete but stale + estimated profile scores poorly.
  /// Default French labels for field paths (used when no [labels] provided).
  static const Map<String, String> _defaultFieldLabels = {
    'salaireBrutMensuel': 'Salaire brut',
    'age': '\u00c2ge',
    'canton': 'Canton',
    'etatCivil': 'Situation du m\u00e9nage',
    'prevoyance.avoirLppTotal': 'Avoir LPP',
    'prevoyance.tauxConversion': 'Taux de conversion',
    'prevoyance.anneesContribuees': 'Ann\u00e9es AVS',
    'prevoyance.totalEpargne3a': '\u00c9pargne 3a',
    'patrimoine.epargneLiquide': 'Patrimoine',
  };

  /// Default French prompt templates (used when no [promptLabels] provided).
  static const Map<String, String> _defaultPromptLabels = {
    'freshnessPrefix': 'Actualise\u00a0: ',
    'freshnessStale': 'Donn\u00e9e datant de {months} mois \u2014 rescanne ton certificat',
    'freshnessConfirm': 'Confirme que cette valeur est toujours actuelle',
    'accuracyPrefix': 'Confirme\u00a0: ',
    'accuracyEstimated': 'Saisis ta valeur r\u00e9elle',
    'accuracyCertificate': 'Scanne ton certificat pour confirmer',
  };

  static EnhancedConfidence scoreEnhanced(CoachProfile profile, {
    DateTime? now,
    Map<String, String>? labels,
    Map<String, String>? promptLabels,
    S? s,
  }) {
    final fieldLabels = labels ?? _fieldLabelsFromS(s);
    final prompts = promptLabels ?? _promptLabelsFromS(s);
    now ??= DateTime.now();
    final baseResult = score(profile, s: s);
    final completeness = baseResult.score;

    // ── Accuracy axis ─────────────────────────────────────────
    double accuracyWeightedSum = 0;
    double accuracyTotalWeight = 0;

    for (final entry in _trackedFields.entries) {
      final fieldPath = entry.key;
      final weight = entry.value.toDouble();
      final source = profile.dataSources[fieldPath];
      if (source != null) {
        accuracyWeightedSum += (_accuracyWeights[source] ?? 0.25) * weight;
      } else {
        // No source declared → system estimate
        accuracyWeightedSum += 0.25 * weight;
      }
      accuracyTotalWeight += weight;
    }
    final accuracy = accuracyTotalWeight > 0
        ? (accuracyWeightedSum / accuracyTotalWeight * 100).clamp(0.0, 100.0)
        : 25.0;

    // ── Freshness axis ────────────────────────────────────────
    double freshnessWeightedSum = 0;
    double freshnessTotalWeight = 0;

    for (final entry in _trackedFields.entries) {
      final fieldPath = entry.key;
      final weight = entry.value.toDouble();
      final timestamp = profile.dataTimestamps[fieldPath];
      freshnessWeightedSum += _freshnessScore(timestamp, now) * weight;
      freshnessTotalWeight += weight;
    }
    final freshness = freshnessTotalWeight > 0
        ? (freshnessWeightedSum / freshnessTotalWeight * 100).clamp(0.0, 100.0)
        : 50.0;

    // ── Understanding axis ────────────────────────────────────
    // Measures the user's engagement with financial education.
    // Sources (normalized to sum = 1.0):
    //   - financialLiteracyLevel (50%): onboarding calibration (dominant source)
    //   - coachSessionCount (30%): number of coach interactions
    //   - educationViewCount (20%): education inserts viewed (future)
    //
    // Beginner=30, intermediate=55, advanced=85 (base from calibration).
    // Each coach session adds ~2 pts (diminishing returns, cap at 40 pts).
    // Each education view adds ~1.5 pts (cap at 30 pts, placeholder 0 for now).
    //
    // Max achievable today (no educationBonus): 85*0.50 + 40*0.30 = 54.5
    // Max with all 3 sources: 85*0.50 + 40*0.30 + 30*0.20 = 60.5
    // → understanding is intentionally softer than other axes (education
    //   is a long-term journey, not a checkbox to max out).
    final literacyBase = switch (profile.financialLiteracyLevel) {
      FinancialLiteracyLevel.beginner => 30.0,
      FinancialLiteracyLevel.intermediate => 55.0,
      FinancialLiteracyLevel.advanced => 85.0,
    };
    final sessionCount = profile.checkIns.length;
    final sessionBonus = (sessionCount * 2.0).clamp(0.0, 40.0);
    // educationViewCount not yet tracked — placeholder for future wiring
    const educationBonus = 0.0;
    final understanding =
        (literacyBase * 0.50 + sessionBonus * 0.30 + educationBonus * 0.20)
        .clamp(0.0, 100.0);

    // ── Combined: geometric mean of 4 axes ──────────────────
    // Adding small epsilon (1.0) to avoid zero-multiplication collapse.
    final c = (completeness + 1.0) / 101.0;
    final a = (accuracy + 1.0) / 101.0;
    final f = (freshness + 1.0) / 101.0;
    final u = (understanding + 1.0) / 101.0;
    final geoMean = _pow(c * a * f * u, 1.0 / 4.0);
    final combined = (geoMean * 101.0 - 1.0).clamp(0.0, 100.0);

    // ── Axis-specific enrichment prompts ──────────────────────
    final axisPrompts = <EnrichmentPrompt>[];

    // Freshness prompts: flag stale fields
    for (final entry in _trackedFields.entries) {
      final fieldPath = entry.key;
      final timestamp = profile.dataTimestamps[fieldPath];
      final decay = _freshnessScore(timestamp, now);
      if (decay < 0.7 && profile.dataSources.containsKey(fieldPath)) {
        final monthsOld = timestamp != null
            ? (now.difference(timestamp).inDays / 30.44).round()
            : 0;
        final label = fieldLabels[fieldPath] ?? fieldPath;
        final staleAction = monthsOld > 0
            ? (s != null
                ? s.confidenceScorerFreshnessStale(monthsOld)
                : (prompts['freshnessStale'] ?? 'Donnée datant de {months} mois')
                    .replaceAll('{months}', '$monthsOld'))
            : prompts['freshnessConfirm'] ?? 'Confirme que cette valeur est toujours actuelle';
        axisPrompts.add(EnrichmentPrompt(
          label: '${prompts['freshnessPrefix'] ?? 'Actualise\u00a0: '}$label',
          impact: (entry.value * (1.0 - decay)).round().clamp(1, 15),
          category: 'freshness',
          action: staleAction,
        ));
      }
    }

    // Accuracy prompts: flag estimated fields
    for (final entry in _trackedFields.entries) {
      final fieldPath = entry.key;
      final source = profile.dataSources[fieldPath] ?? ProfileDataSource.estimated;
      if (source == ProfileDataSource.estimated ||
          source == ProfileDataSource.userInput) {
        final upgradeAction = source == ProfileDataSource.estimated
            ? prompts['accuracyEstimated'] ?? 'Saisis ta valeur r\u00e9elle'
            : prompts['accuracyCertificate'] ?? 'Scanne ton certificat pour confirmer';
        final label = fieldLabels[fieldPath] ?? fieldPath;
        axisPrompts.add(EnrichmentPrompt(
          label: '${prompts['accuracyPrefix'] ?? 'Confirme\u00a0: '}$label',
          impact: (entry.value * (1.0 - (_accuracyWeights[source] ?? 0.25))).round().clamp(1, 15),
          category: 'accuracy',
          action: upgradeAction,
        ));
      }
    }

    // Understanding prompts: suggest education engagement
    if (understanding < 40) {
      axisPrompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerUnderstandingExploreLabel ?? 'Explore les fiches éducatives',
        impact: 10,
        category: 'understanding',
        action: s?.confidenceScorerUnderstandingExploreAction ?? 'Lis les fiches sur tes thèmes clés (LPP, AVS, fiscalité)',
      ));
    }
    if (sessionCount < 3) {
      axisPrompts.add(EnrichmentPrompt(
        label: s?.confidenceScorerUnderstandingCoachLabel ?? 'Pose une question au coach',
        impact: 5,
        category: 'understanding',
        action: s?.confidenceScorerUnderstandingCoachAction ?? 'Chaque interaction affine ta compréhension financière',
      ));
    }

    // Sort by impact descending
    axisPrompts.sort((a, b) => b.impact.compareTo(a.impact));

    return EnhancedConfidence(
      completeness: completeness,
      accuracy: accuracy,
      freshness: freshness,
      understanding: understanding,
      combined: combined,
      level: baseResult.level,
      baseResult: baseResult,
      axisPrompts: axisPrompts,
    );
  }

  /// Build field labels map from [S] localizations, falling back to defaults.
  static Map<String, String> _fieldLabelsFromS(S? s) {
    if (s == null) return _defaultFieldLabels;
    return {
      'salaireBrutMensuel': s.confidenceScorerFieldSalaire,
      'age': s.confidenceScorerFieldAge,
      'canton': s.confidenceScorerFieldCanton,
      'etatCivil': s.confidenceScorerFieldEtatCivil,
      'prevoyance.avoirLppTotal': s.confidenceScorerFieldAvoirLpp,
      'prevoyance.tauxConversion': s.confidenceScorerFieldTauxConversion,
      'prevoyance.anneesContribuees': s.confidenceScorerFieldAnneesAvs,
      'prevoyance.totalEpargne3a': s.confidenceScorerFieldEpargne3a,
      'patrimoine.epargneLiquide': s.confidenceScorerFieldPatrimoine,
    };
  }

  /// Build prompt label templates from [S] localizations, falling back to defaults.
  ///
  /// Note: 'freshnessStale' is handled directly in scoreEnhanced() via
  /// `s.confidenceScorerFreshnessStale(months)` to avoid template hacks.
  static Map<String, String> _promptLabelsFromS(S? s) {
    if (s == null) return _defaultPromptLabels;
    return {
      'freshnessPrefix': s.confidenceScorerFreshnessPrefix,
      'freshnessConfirm': s.confidenceScorerFreshnessConfirm,
      'accuracyPrefix': s.confidenceScorerAccuracyPrefix,
      'accuracyEstimated': s.confidenceScorerAccuracyEstimated,
      'accuracyCertificate': s.confidenceScorerAccuracyCertificate,
    };
  }

  /// Cube root via exp/log (dart:math pow returns num, not double).
  static double _pow(double base, double exponent) {
    if (base <= 0 || !base.isFinite) return 0;
    return math.exp(exponent * math.log(base));
  }

}

/// Enhanced 4-axis confidence result (S46 + Phase 2).
///
/// Axes: completeness × accuracy × freshness × understanding.
/// Combined score = geometric mean of all 4 axes (0-100).
///
/// Understanding axis measures financial literacy engagement:
/// beginner(30) / intermediate(55) / advanced(85) base +
/// coach session bonus (capped 40) + education views (future).
/// For new users (beginner, no sessions): understanding ≈ 15.
class EnhancedConfidence {
  /// Completeness axis: 0-100 (how much data is present).
  final double completeness;

  /// Accuracy axis: 0-100 (quality of data sources).
  final double accuracy;

  /// Freshness axis: 0-100 (how recent is the data).
  final double freshness;

  /// Understanding axis: 0-100 (financial literacy engagement).
  /// Combines onboarding calibration + education interactions.
  final double understanding;

  /// Combined score: geometric mean of 4 axes (0-100).
  final double combined;

  /// Level derived from completeness (backward compat): 'low'/'medium'/'high'.
  final String level;

  /// Full V2 base result (for backward compatibility with existing consumers).
  final ProjectionConfidence baseResult;

  /// Axis-specific enrichment prompts (freshness + accuracy + understanding).
  final List<EnrichmentPrompt> axisPrompts;

  const EnhancedConfidence({
    required this.completeness,
    required this.accuracy,
    required this.freshness,
    required this.understanding,
    required this.combined,
    required this.level,
    required this.baseResult,
    this.axisPrompts = const [],
  });
}
