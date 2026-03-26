/// Mobile confidence: 3 axes (completeness, accuracy, freshness), weighted average.
/// Used for UI display when backend is unavailable (offline fallback).
///
/// NOTE: Three confidence systems coexist (V9-5):
///   1. enhanced_confidence_service.py (backend) — 4-axis geometric mean, authoritative
///   2. This file (mobile) — 3-axis weighted average, offline fallback for UI display
///   3. confidence_scorer.dart (financial_core) — project-level scoring with bloc breakdown
///
/// TODO: Unify to single 4-axis model matching backend (SOT §3)
///
/// Weights: completeness 40% + accuracy 35% + freshness 25% = overall
///
/// References:
/// - DATA_ACQUISITION_STRATEGY.md, "Confidence Scoring Evolution"
/// - ADR-20260223-unified-financial-engine.md
library;

// ────────────────────────────────────────────────────────────
//  DATA SOURCE ENUM
// ────────────────────────────────────────────────────────────

/// How a profile field was acquired — drives accuracy scoring.
enum DataSource {
  /// MINT computed default (lowest confidence).
  systemEstimate,

  /// User typed a value without validation.
  userEntry,

  /// User typed a value that passed cross-validation checks.
  userEntryCrossValidated,

  /// Value extracted from a scanned document (not yet confirmed).
  documentScan,

  /// Value extracted from a scanned document AND user-confirmed.
  documentScanVerified,

  /// Live feed from Open Banking (bLink / SFTI).
  openBanking,

  /// Direct feed from institutional API (caisse de pension, AFC).
  institutionalApi,
}

// ────────────────────────────────────────────────────────────
//  FIELD SOURCE — tracks provenance of a single profile field
// ────────────────────────────────────────────────────────────

/// Metadata for a single profile field: its value, where it came from,
/// and when it was last updated.
class FieldSource {
  final String fieldName;
  final DataSource source;
  final DateTime updatedAt;
  final dynamic value;

  const FieldSource({
    required this.fieldName,
    required this.source,
    required this.updatedAt,
    required this.value,
  });
}

// ────────────────────────────────────────────────────────────
//  CONFIDENCE BREAKDOWN — 3-axis score
// ────────────────────────────────────────────────────────────

/// Three-dimensional confidence score.
///
/// - **completeness** (0-100): how many expected fields are filled
/// - **accuracy** (0-100): weighted quality of data sources
/// - **freshness** (0-100): how recent the data is
/// - **overall**: weighted 40/35/25
class ConfidenceBreakdown {
  final double completeness;
  final double accuracy;
  final double freshness;

  /// Weighted combination: 40% completeness + 35% accuracy + 25% freshness.
  double get overall =>
      (completeness * 0.40 + accuracy * 0.35 + freshness * 0.25)
          .clamp(0.0, 100.0);

  const ConfidenceBreakdown({
    required this.completeness,
    required this.accuracy,
    required this.freshness,
  });
}

// ────────────────────────────────────────────────────────────
//  ENRICHMENT PROMPT — actionable step to improve confidence
// ────────────────────────────────────────────────────────────

/// Suggested user action to improve confidence score.
class EnrichmentPrompt {
  /// Profile field that would be improved.
  final String fieldName;

  /// Human-readable action description (FR).
  final String action;

  /// How many confidence points this action would add.
  final int impactPoints;

  /// Acquisition method (e.g. 'documentScan', 'manualEntry', 'openBanking').
  final String method;

  /// Priority rank (1 = highest).
  final int priority;

  const EnrichmentPrompt({
    required this.fieldName,
    required this.action,
    required this.impactPoints,
    required this.method,
    required this.priority,
  });
}

// ────────────────────────────────────────────────────────────
//  FEATURE GATE — what's unlocked at each confidence level
// ────────────────────────────────────────────────────────────

/// A feature that requires a minimum confidence to unlock.
class FeatureGate {
  final String gateName;
  final bool unlocked;
  final double minConfidence;

  const FeatureGate({
    required this.gateName,
    required this.unlocked,
    required this.minConfidence,
  });
}

// ────────────────────────────────────────────────────────────
//  CONFIDENCE RESULT — complete output
// ────────────────────────────────────────────────────────────

/// Complete enhanced confidence result.
class ConfidenceResult {
  final ConfidenceBreakdown breakdown;
  final List<EnrichmentPrompt> enrichmentPrompts;
  final List<FeatureGate> featureGates;
  final String disclaimer;
  final List<String> sources;

  const ConfidenceResult({
    required this.breakdown,
    required this.enrichmentPrompts,
    required this.featureGates,
    required this.disclaimer,
    required this.sources,
  });
}

// ────────────────────────────────────────────────────────────
//  ENHANCED CONFIDENCE SERVICE — static, pure functions
// ────────────────────────────────────────────────────────────

/// Enhanced confidence scorer with 3 axes: completeness, accuracy, freshness.
///
/// All methods are static and deterministic. This service mirrors the backend
/// enhanced confidence scoring logic.
class EnhancedConfidenceService {
  EnhancedConfidenceService._();

  // ── Accuracy weights per DataSource (backend-aligned) ──────

  static const Map<DataSource, double> _accuracyWeights = {
    DataSource.openBanking: 1.00,
    DataSource.institutionalApi: 0.95,
    DataSource.documentScanVerified: 0.95,
    DataSource.documentScan: 0.85,
    DataSource.userEntryCrossValidated: 0.70,
    DataSource.userEntry: 0.50,
    DataSource.systemEstimate: 0.25,
  };

  // Backend-aligned field importance weights.
  static const Map<String, double> _profileFieldWeights = {
    'age': 1.0,
    'canton': 0.8,
    'salaire_brut': 1.0,
    'salaire_net': 0.6,
    'lpp_total': 1.0,
    'lpp_obligatoire': 1.0,
    'lpp_surobligatoire': 0.8,
    'lpp_insured_salary': 0.7,
    'conversion_rate_oblig': 0.9,
    'conversion_rate_suroblig': 0.7,
    'buyback_potential': 0.6,
    'employee_lpp_contribution': 0.5,
    'avs_contribution_years': 0.9,
    'avs_ramd': 0.9,
    'pillar_3a_balance': 0.7,
    'taux_marginal': 0.9,
    'taxable_income': 0.7,
    'taxable_wealth': 0.5,
    'mortgage_remaining': 0.5,
    'mortgage_rate': 0.4,
    'property_value': 0.4,
    'is_married': 0.5,
    'nb_children': 0.4,
    'monthly_expenses': 0.6,
    'is_independant': 0.6,
    'has_lpp': 0.7,
  };

  // ────────────────────────────────────────────────────────────
  //  1. COMPLETENESS (0-100)
  // ────────────────────────────────────────────────────────────

  /// Scores how many of the expected profile fields are filled.
  ///
  /// Each field has an importance weight; the score is the weighted
  /// sum of filled fields normalized to 0-100.
  static double scoreCompleteness(Map<String, dynamic> profile) {
    final totalWeight =
        _profileFieldWeights.values.fold(0.0, (sum, w) => sum + w);

    double scored = 0;
    for (final entry in _profileFieldWeights.entries) {
      final val = profile[entry.key];
      if (_isFilled(val)) {
        scored += entry.value;
      }
    }

    return ((scored / totalWeight) * 100).clamp(0.0, 100.0);
  }

  // ────────────────────────────────────────────────────────────
  //  2. ACCURACY (0-100)
  // ────────────────────────────────────────────────────────────

  /// Scores the weighted average quality of data sources.
  ///
  /// Fields without a [FieldSource] entry are assumed to be `systemEstimate`.
  static double scoreAccuracy(List<FieldSource> fieldSources) {
    if (fieldSources.isEmpty) return 0;

    double weightedSum = 0;
    double totalWeight = 0;

    for (final fs in fieldSources) {
      final sourceAccuracy = _accuracyWeights[fs.source] ?? 0.25;
      final fieldWeight = _profileFieldWeights[fs.fieldName] ?? 0.5;
      weightedSum += sourceAccuracy * fieldWeight;
      totalWeight += fieldWeight;
    }

    if (totalWeight == 0) return 0;
    return ((weightedSum / totalWeight) * 100).clamp(0.0, 100.0);
  }

  // ────────────────────────────────────────────────────────────
  //  3. FRESHNESS (0-100)
  // ────────────────────────────────────────────────────────────

  /// Scores the average freshness of field data.
  ///
  /// Freshness decay:
  /// - < 1 month: 1.00
  /// - 1-3 months: 0.90
  /// - 3-6 months: 0.75
  /// - 6-12 months: 0.50
  /// - > 12 months: 0.25
  static double scoreFreshness(List<FieldSource> fieldSources) {
    if (fieldSources.isEmpty) return 0;

    final now = DateTime.now();
    double weightedFreshness = 0;
    double totalWeight = 0;

    for (final fs in fieldSources) {
      final age = now.difference(fs.updatedAt);
      final fieldWeight = _profileFieldWeights[fs.fieldName] ?? 0.5;
      weightedFreshness += _freshnessForAge(age) * fieldWeight;
      totalWeight += fieldWeight;
    }

    if (totalWeight == 0) return 0;
    return ((weightedFreshness / totalWeight) * 100).clamp(0.0, 100.0);
  }

  /// Returns freshness score (0.0 - 1.0) for a given data age.
  static double _freshnessForAge(Duration age) {
    final days = age.inDays;
    if (days < 30) return 1.00;
    if (days < 90) return 0.90;
    if (days < 180) return 0.75;
    if (days < 365) return 0.50;
    return 0.25;
  }

  // ────────────────────────────────────────────────────────────
  //  4. COMPUTE CONFIDENCE (full result)
  // ────────────────────────────────────────────────────────────

  /// Computes the full enhanced confidence result.
  ///
  /// [profile] — key-value map of the user's profile fields.
  /// [fieldSources] — provenance metadata per field.
  static ConfidenceResult computeConfidence(
    Map<String, dynamic> profile,
    List<FieldSource> fieldSources,
  ) {
    final completeness = scoreCompleteness(profile);
    final accuracy = scoreAccuracy(fieldSources);
    final freshness = scoreFreshness(fieldSources);

    final breakdown = ConfidenceBreakdown(
      completeness: completeness,
      accuracy: accuracy,
      freshness: freshness,
    );

    final prompts = rankEnrichmentPrompts(profile, fieldSources);
    final gates = _computeFeatureGates(breakdown.overall);

    return ConfidenceResult(
      breakdown: breakdown,
      enrichmentPrompts: prompts,
      featureGates: gates,
      disclaimer:
          'Outil educatif — ne constitue pas un conseil financier (LSFin). '
          'Le score de confiance reflete la qualite des donnees fournies, '
          'pas la fiabilite du systeme.',
      sources: const [
        'DATA_ACQUISITION_STRATEGY.md',
        'LPP art. 7-16',
        'LAVS art. 21-40',
        'LIFD art. 38',
        'OPP3 art. 7',
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  5. RANK ENRICHMENT PROMPTS
  // ────────────────────────────────────────────────────────────

  /// Returns enrichment prompts ranked by impact on overall confidence.
  ///
  /// Prompts are generated for missing or low-quality fields and sorted
  /// by descending impact.
  static List<EnrichmentPrompt> rankEnrichmentPrompts(
    Map<String, dynamic> profile,
    List<FieldSource> fieldSources,
  ) {
    final prompts = <EnrichmentPrompt>[];
    final sourceMap = <String, FieldSource>{};
    for (final fs in fieldSources) {
      sourceMap[fs.fieldName] = fs;
    }

    int priority = 1;

    // --- LPP certificate (highest impact) ---
    if (!_isFilled(profile['lpp_obligatoire'])) {
      prompts.add(EnrichmentPrompt(
        fieldName: 'lpp_obligatoire',
        action: 'Scanne ton certificat de prevoyance LPP',
        impactPoints: 27,
        method: 'documentScan',
        priority: priority++,
      ));
    } else {
      final source = sourceMap['lpp_obligatoire'];
      if (source != null && _isLowQuality(source)) {
        prompts.add(EnrichmentPrompt(
          fieldName: 'lpp_obligatoire',
          action: 'Confirme ta part obligatoire LPP avec ton certificat',
          impactPoints: 15,
          method: 'documentScanVerified',
          priority: priority++,
        ));
      }
    }

    // --- LPP total ---
    if (!_isFilled(profile['lpp_total'])) {
      prompts.add(EnrichmentPrompt(
        fieldName: 'lpp_total',
        action: 'Ajoute ton avoir LPP total',
        impactPoints: 20,
        method: 'documentScan',
        priority: priority++,
      ));
    }

    // --- AVS extract ---
    if (!_isFilled(profile['avs_contribution_years'])) {
      prompts.add(EnrichmentPrompt(
        fieldName: 'avs_contribution_years',
        action: 'Commande ton extrait AVS (gratuit sur inforegister.ch)',
        impactPoints: 18,
        method: 'documentScan',
        priority: priority++,
      ));
    }

    // --- Taux marginal (tax declaration) ---
    if (!_isFilled(profile['taux_marginal'])) {
      prompts.add(EnrichmentPrompt(
        fieldName: 'taux_marginal',
        action: 'Scanne ton avis de taxation pour le taux marginal',
        impactPoints: 15,
        method: 'documentScan',
        priority: priority++,
      ));
    } else {
      final source = sourceMap['taux_marginal'];
      if (source != null && _isLowQuality(source)) {
        prompts.add(EnrichmentPrompt(
          fieldName: 'taux_marginal',
          action: 'Verifie ton taux marginal avec ton avis de taxation',
          impactPoints: 10,
          method: 'documentScanVerified',
          priority: priority++,
        ));
      }
    }

    // --- Pillar 3a ---
    if (!_isFilled(profile['pillar_3a_balance'])) {
      prompts.add(EnrichmentPrompt(
        fieldName: 'pillar_3a_balance',
        action: 'Renseigne tes soldes 3a (attestation ou e-banking)',
        impactPoints: 10,
        method: 'manualEntry',
        priority: priority++,
      ));
    }

    // --- Patrimoine ---
    if (!_isFilled(profile['patrimoine_total'])) {
      prompts.add(EnrichmentPrompt(
        fieldName: 'patrimoine_total',
        action: 'Ajoute ton patrimoine (epargne, investissements)',
        impactPoints: 8,
        method: 'manualEntry',
        priority: priority++,
      ));
    }

    // --- Salary ---
    if (!_isFilled(profile['salaire_brut'])) {
      prompts.add(EnrichmentPrompt(
        fieldName: 'salaire_brut',
        action: 'Renseigne ton salaire brut mensuel',
        impactPoints: 12,
        method: 'manualEntry',
        priority: priority++,
      ));
    }

    // --- Open Banking opportunity ---
    final hasOb = fieldSources.any((fs) => fs.source == DataSource.openBanking);
    if (!hasOb) {
      prompts.add(EnrichmentPrompt(
        fieldName: 'open_banking',
        action: 'Connecte ton compte bancaire (bLink)',
        impactPoints: 22,
        method: 'openBanking',
        priority: priority++,
      ));
    }

    // Sort by impact descending
    prompts.sort((a, b) => b.impactPoints.compareTo(a.impactPoints));

    // Re-assign priority after sort
    for (int i = 0; i < prompts.length; i++) {
      prompts[i] = EnrichmentPrompt(
        fieldName: prompts[i].fieldName,
        action: prompts[i].action,
        impactPoints: prompts[i].impactPoints,
        method: prompts[i].method,
        priority: i + 1,
      );
    }

    return prompts;
  }

  // ────────────────────────────────────────────────────────────
  //  FEATURE GATES
  // ────────────────────────────────────────────────────────────

  /// Computes which features are unlocked at the current confidence level.
  ///
  /// Gates (from DATA_ACQUISITION_STRATEGY.md):
  /// - < 30%: basic only
  /// - 30-50%: standard projections
  /// - 50-70%: arbitrage with uncertainty bands
  /// - 70-85%: precise arbitrage + FRI
  /// - > 85%: full precision + longitudinal
  static List<FeatureGate> _computeFeatureGates(double overall) {
    return [
      FeatureGate(
        gateName: 'Chiffre choc de base',
        unlocked: overall >= 0,
        minConfidence: 0,
      ),
      FeatureGate(
        gateName: 'Projections standard (3 scenarios)',
        unlocked: overall >= 30,
        minConfidence: 30,
      ),
      FeatureGate(
        gateName: 'Arbitrage avec bandes d\'incertitude',
        unlocked: overall >= 50,
        minConfidence: 50,
      ),
      FeatureGate(
        gateName: 'Arbitrage precis + score FRI',
        unlocked: overall >= 70,
        minConfidence: 70,
      ),
      FeatureGate(
        gateName: 'Suivi longitudinal',
        unlocked: overall >= 85,
        minConfidence: 85,
      ),
    ];
  }

  // ────────────────────────────────────────────────────────────
  //  PRIVATE HELPERS
  // ────────────────────────────────────────────────────────────

  /// Returns true if a profile field value is considered "filled".
  static bool _isFilled(dynamic val) {
    if (val == null) return false;
    if (val is num) {
      if (val is double && val.isNaN) return false;
      return true;
    }
    if (val is String) return val.isNotEmpty;
    return true;
  }

  /// Returns true if a field source is low quality (estimate or raw entry).
  static bool _isLowQuality(FieldSource fs) {
    return fs.source == DataSource.systemEstimate ||
        fs.source == DataSource.userEntry;
  }
}
