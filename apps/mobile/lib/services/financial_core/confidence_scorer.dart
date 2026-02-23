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

/// Confidence scorer for retirement projections.
///
/// Scores 0-100 based on data completeness per profile.
/// Each missing data point reduces the score and generates
/// an enrichment prompt to guide the user.
///
/// Reference: ADR-20260223-archetype-driven-retirement.md
class ConfidenceScorer {
  ConfidenceScorer._();

  /// Score projection confidence based on profile completeness.
  static ProjectionConfidence score(CoachProfile profile) {
    double total = 0;
    final prompts = <EnrichmentPrompt>[];
    final assumptions = <String>[];

    // --- Salary (15 pts) ---
    if (profile.salaireBrutMensuel > 0) {
      total += 15;
    } else {
      assumptions.add('Salaire non renseigne — estimation impossible');
      prompts.add(const EnrichmentPrompt(
        label: 'Ajoute ton salaire',
        impact: 15,
        category: 'income',
        action: 'Renseigne ton salaire brut mensuel',
      ));
    }

    // --- Age + canton (10 pts) ---
    if (profile.age > 0 && profile.canton.isNotEmpty) {
      total += 10;
    } else {
      assumptions.add('Age ou canton manquant');
    }

    // --- Archetype detectable (5 pts) ---
    // Without FinancialArchetype enum, use proxy signals
    if (_hasArchetypeSignals(profile)) {
      total += 5;
    }

    // --- LPP avoir reel (20 pts) ---
    final lppDeclared = profile.prevoyance.avoirLppTotal;
    if (lppDeclared != null && lppDeclared > 0) {
      // Has declared LPP — but is it real or estimated?
      // If the user manually entered it (vs estimation from salary), give full points.
      // For now, give partial credit since we can't distinguish.
      total += 12;
      prompts.add(const EnrichmentPrompt(
        label: 'Confirme ton solde LPP',
        impact: 8,
        category: 'lpp',
        action: 'Ajoute ton certificat de prevoyance (solde exact)',
      ));
      assumptions.add('LPP estime depuis le salaire — peut varier de +-30%');
    } else if (profile.employmentStatus == 'independant') {
      // Independent without LPP: no penalty
      total += 20;
    } else {
      assumptions.add('Avoir LPP non renseigne — estimation depuis le salaire');
      prompts.add(const EnrichmentPrompt(
        label: 'Ajoute ton solde LPP',
        impact: 20,
        category: 'lpp',
        action: 'Ajoute ton certificat de prevoyance (solde exact)',
      ));
    }

    // --- Taux conversion reel (10 pts) ---
    // Only relevant if user has LPP
    final isIndepSansLpp = profile.employmentStatus == 'independant' &&
        (lppDeclared == null || lppDeclared <= 0);
    if (isIndepSansLpp) {
      total += 10; // Not applicable → full points
    } else {
      final tauxConv = profile.prevoyance.tauxConversion;
      if (tauxConv != 0.068) {
        total += 10;
      } else {
        total += 3;
        prompts.add(const EnrichmentPrompt(
          label: 'Taux de conversion reel',
          impact: 7,
          category: 'lpp',
          action: 'Lis ton certificat de prevoyance (taux enveloppe)',
        ));
        assumptions.add(
            'Taux de conversion LPP: minimum legal 6.8% (reel souvent 5-6%)');
      }
    }

    // --- Extrait AVS (15 pts) ---
    final hasAvsData = profile.prevoyance.anneesContribuees != null;
    if (hasAvsData) {
      total += 15;
    } else {
      total += 5; // Basic AVS estimate from age
      prompts.add(const EnrichmentPrompt(
        label: 'Commande ton extrait AVS',
        impact: 10,
        category: 'avs',
        action: 'Gratuit sur inforegister.ch — annees effectives',
      ));
      assumptions.add('Annees AVS estimees depuis l\'age — lacunes possibles');
    }

    // --- Soldes 3a reels (10 pts) ---
    final has3a = profile.prevoyance.totalEpargne3a > 0;
    if (has3a) {
      total += 10;
    } else {
      total += 2;
      prompts.add(const EnrichmentPrompt(
        label: 'Ajoute tes soldes 3a',
        impact: 8,
        category: '3a',
        action: 'Saisis tes soldes 3e pilier (chaque compte)',
      ));
    }

    // --- Patrimoine detaille (10 pts) ---
    final hasPatrimoine = profile.patrimoine.totalPatrimoine > 0;
    if (hasPatrimoine) {
      total += 10;
    } else {
      total += 2;
      prompts.add(const EnrichmentPrompt(
        label: 'Renseigne ton patrimoine',
        impact: 8,
        category: 'patrimoine',
        action: 'Epargne, investissements, immobilier',
      ));
    }

    // --- Foreign pension (5 pts, only for expats) ---
    final isExpat = profile.arrivalAge != null && profile.arrivalAge! > 21;
    if (isExpat) {
      // Expat: foreign pension data would help
      total += 0;
      prompts.add(const EnrichmentPrompt(
        label: 'Pension etrangere',
        impact: 5,
        category: 'foreign_pension',
        action: 'As-tu des droits a une retraite dans ton pays d\'origine?',
      ));
      assumptions.add('Pension etrangere non modelisee');
    } else {
      total += 5;
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

  /// Check if profile has enough data to determine archetype.
  static bool _hasArchetypeSignals(CoachProfile profile) {
    // Nationality or arrival age or employment status → can detect archetype
    return profile.employmentStatus.isNotEmpty ||
        profile.arrivalAge != null ||
        profile.residencePermit != null;
  }
}
