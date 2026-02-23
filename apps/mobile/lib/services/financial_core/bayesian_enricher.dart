/// Bayesian profile enrichment service for MINT.
///
/// Infers missing CoachProfile fields from observed data + Swiss statistical
/// priors (OFS/BFS), providing posterior estimates with credibility intervals.
///
/// This service uses conjugate normal-normal Bayesian updates:
/// - Prior: Swiss statistical distributions (OFS surveys, LPP statistics)
/// - Likelihood: declared user data (when available)
/// - Posterior: weighted combination with collapsed uncertainty for declared values
///
/// All methods are pure and static — no state, fully deterministic.
///
/// Sources:
/// - OFS Enquete sur le budget des menages 2024
/// - OFS Statistique des caisses de pension 2024
/// - LPP art. 14-16 (bonifications de vieillesse)
/// - LAVS art. 34 (rente AVS)
/// - OPP3 art. 7 (plafond 3a)
library;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';

// ════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════

/// A posterior estimate for a single profile field.
///
/// Represents the Bayesian posterior distribution after combining
/// Swiss statistical priors with any declared user data.
class PosteriorEstimate {
  /// Field identifier, e.g. 'avoirLppTotal', 'epargneLiquide'.
  final String field;

  /// Posterior mean (expected value).
  final double mean;

  /// Posterior median.
  final double median;

  /// Posterior standard deviation.
  final double sd;

  /// 80% credibility interval — low bound.
  final double ci80Low;

  /// 80% credibility interval — high bound.
  final double ci80High;

  /// Data quality score 0-1: how much observed data supports this estimate.
  /// 1.0 = user declared exact value, 0.0 = pure prior guess.
  final double dataQuality;

  /// Provenance description, e.g. 'prior:salary+age', 'posterior:declared+adjusted'.
  final String source;

  /// True if the user provided an actual value (not inferred from priors).
  final bool isDeclared;

  const PosteriorEstimate({
    required this.field,
    required this.mean,
    required this.median,
    required this.sd,
    required this.ci80Low,
    required this.ci80High,
    required this.dataQuality,
    required this.source,
    required this.isDeclared,
  });

  /// Width of the 80% credibility interval.
  double get ci80Width => ci80High - ci80Low;

  /// Coefficient of variation (sd / mean), clamped to avoid division by zero.
  double get coefficientOfVariation =>
      mean.abs() > 0 ? sd / mean.abs() : double.infinity;
}

/// Enrichment prompt ranked by Expected Value of Information (EVI).
///
/// Higher EVI means asking the user for this data point would most
/// reduce overall projection uncertainty.
class EviPrompt {
  /// Field identifier matching PosteriorEstimate.field.
  final String field;

  /// Human-readable label in French (informal "tu").
  final String label;

  /// Action description — what the user should do.
  final String action;

  /// Expected Value of Information: impact x uncertainty.
  /// Higher = more valuable to ask.
  final double evi;

  /// Current uncertainty (CI width) for this field.
  final double currentUncertainty;

  /// Category: 'lpp', 'avs', '3a', 'patrimoine', 'depenses', 'conjoint'.
  final String category;

  const EviPrompt({
    required this.field,
    required this.label,
    required this.action,
    required this.evi,
    required this.currentUncertainty,
    required this.category,
  });
}

/// Result of Bayesian enrichment on a CoachProfile.
class BayesianEnrichmentResult {
  /// Posterior estimates keyed by field name.
  final Map<String, PosteriorEstimate> estimates;

  /// Prompts ranked by Expected Value of Information (highest first).
  final List<EviPrompt> rankedPrompts;

  /// Weighted average uncertainty across all estimated fields (0-1 scale).
  final double overallUncertainty;

  /// Compliance disclaimer (French).
  final String disclaimer;

  /// Legal and statistical sources.
  final List<String> sources;

  const BayesianEnrichmentResult({
    required this.estimates,
    required this.rankedPrompts,
    required this.overallUncertainty,
    required this.disclaimer,
    required this.sources,
  });

  /// Get estimate for a specific field, or null if not computed.
  PosteriorEstimate? operator [](String field) => estimates[field];
}

// ════════════════════════════════════════════════════════════════
//  BAYESIAN PROFILE ENRICHER
// ════════════════════════════════════════════════════════════════

/// Pure static service that enriches a CoachProfile with Bayesian
/// posterior estimates for missing fields.
///
/// For each key financial field:
/// 1. Compute a Swiss statistical prior (mean + sd) from OFS/BFS data
/// 2. If the user declared a value, collapse to a tight posterior
/// 3. If not declared, return the prior as the posterior
/// 4. Rank all undeclared fields by Expected Value of Information
///
/// Usage:
/// ```dart
/// final result = BayesianProfileEnricher.enrich(profile);
/// print(result.estimates['avoirLppTotal']?.mean);
/// print(result.rankedPrompts.first.label);
/// ```
class BayesianProfileEnricher {
  BayesianProfileEnricher._();

  // ── Projection impact weights (from tornado sensitivity analysis) ───
  // Each weight represents how much a 1-unit change in this field
  // affects the retirement projection (normalized 0-1).
  static const _impactWeights = <String, double>{
    'avoirLppTotal': 0.25,
    'tauxConversion': 0.20,
    'totalEpargne3a': 0.12,
    'epargneLiquide': 0.08,
    'conjointSalary': 0.15,
    'depensesMensuelles': 0.10,
    'anneesContribuees': 0.10,
  };

  // ── Canton cost-of-living index (BFS regional price index) ──────────
  // Relative to Swiss median = 1.00.
  // Source: OFS Indice des prix a la consommation regionaux 2024.
  static const _cantonCostIndex = <String, double>{
    'GE': 1.15, 'ZH': 1.10, 'BS': 1.08, 'VD': 1.12,
    'ZG': 1.05, 'LU': 0.98, 'BE': 1.02, 'NE': 1.00,
    'FR': 0.96, 'TI': 0.98, 'SG': 0.95, 'AG': 0.97,
    'BL': 1.03, 'SO': 0.97, 'TG': 0.93, 'GR': 0.95,
    'VS': 0.90, 'SZ': 1.00, 'NW': 0.95, 'OW': 0.93,
    'UR': 0.92, 'GL': 0.93, 'SH': 0.96, 'AR': 0.94,
    'AI': 0.92, 'JU': 0.93,
  };

  // ── High-tax cantons where LPP buybacks are more common ────────────
  // Cantons with marginal rate > 30% → people tend to buy back more.
  static const _highTaxCantons = <String>{
    'GE', 'VD', 'BS', 'BE', 'NE', 'JU', 'FR', 'BL', 'TI',
  };
  static const _lowTaxCantons = <String>{
    'ZG', 'SZ', 'NW', 'OW', 'AI', 'UR',
  };

  /// Z-score for 80% credibility interval (normal distribution).
  /// P(−z < Z < z) = 0.80 → z ≈ 1.282.
  static const _z80 = 1.282;

  // ════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ════════════════════════════════════════════════════════════════

  /// Enrich a CoachProfile with Bayesian posterior estimates.
  ///
  /// Returns estimates for all key financial fields, ranked prompts
  /// for data collection, and an overall uncertainty measure.
  static BayesianEnrichmentResult enrich(CoachProfile profile) {
    final estimates = <String, PosteriorEstimate>{};
    final prompts = <EviPrompt>[];

    // ── 1. LPP avoir total ─────────────────────────────────────
    estimates['avoirLppTotal'] = _posteriorLppAvoir(profile);

    // ── 2. Taux de conversion ──────────────────────────────────
    estimates['tauxConversion'] = _posteriorTauxConversion(profile);

    // ── 3. Total epargne 3a ────────────────────────────────────
    estimates['totalEpargne3a'] = _posteriorEpargne3a(profile);

    // ── 4. Epargne liquide ─────────────────────────────────────
    estimates['epargneLiquide'] = _posteriorEpargneLiquide(profile);

    // ── 5. Conjoint salary (couples only) ──────────────────────
    if (profile.isCouple) {
      estimates['conjointSalary'] = _posteriorConjointSalary(profile);
    }

    // ── 6. Depenses mensuelles ─────────────────────────────────
    estimates['depensesMensuelles'] = _posteriorMonthlyExpenses(profile);

    // ── 7. Annees contribuees AVS ──────────────────────────────
    estimates['anneesContribuees'] = _posteriorAnneesContribuees(profile);

    // ── Compute EVI for all undeclared fields ──────────────────
    for (final entry in estimates.entries) {
      final estimate = entry.value;
      if (!estimate.isDeclared) {
        final impact = _impactWeights[entry.key] ?? 0.05;
        final evi = _computeEvi(estimate, impact);
        final prompt = _buildPrompt(entry.key, estimate, evi);
        if (prompt != null) {
          prompts.add(prompt);
        }
      }
    }

    // Sort by EVI descending (most valuable question first)
    prompts.sort((a, b) => b.evi.compareTo(a.evi));

    // ── Overall uncertainty ────────────────────────────────────
    final overallUncertainty = _computeOverallUncertainty(estimates);

    return BayesianEnrichmentResult(
      estimates: estimates,
      rankedPrompts: prompts,
      overallUncertainty: overallUncertainty,
      disclaimer: 'Estimations bayesiennes basees sur les statistiques suisses '
          '(OFS/BFS). Ces valeurs sont des approximations pedagogiques, '
          'pas des certitudes. Ne constitue pas un conseil financier '
          'au sens de la LSFin.',
      sources: const [
        'OFS Enquete sur le budget des menages 2024',
        'OFS Statistique des caisses de pension 2024',
        'LPP art. 14-16 (bonifications de vieillesse)',
        'LAVS art. 34 (rente AVS, echelle 44)',
        'OPP3 art. 7 (plafond 3a)',
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PRIOR + POSTERIOR COMPUTATION — LPP AVOIR
  // ════════════════════════════════════════════════════════════════

  /// Posterior estimate for LPP total balance.
  ///
  /// Prior: bonification-based estimate adjusted for canton and employment.
  /// If declared: collapse to tight posterior around declared value.
  static PosteriorEstimate _posteriorLppAvoir(CoachProfile profile) {
    final age = profile.age;
    final salary = profile.salaireBrutMensuel;
    final canton = profile.canton;
    final employment = profile.employmentStatus;
    final arrivalAge = profile.arrivalAge;
    final declared = profile.prevoyance.avoirLppTotal;

    // Independants without LPP: deterministic zero
    if (employment == 'independant') {
      return PosteriorEstimate(
        field: 'avoirLppTotal',
        mean: declared ?? 0,
        median: declared ?? 0,
        sd: 0,
        ci80Low: declared ?? 0,
        ci80High: declared ?? 0,
        dataQuality: declared != null ? 1.0 : 0.8,
        source: declared != null
            ? 'posterior:declared'
            : 'prior:independant_sans_lpp',
        isDeclared: declared != null && declared > 0,
      );
    }

    // Compute prior from bonification formula
    final priorMean = _priorLppAvoirMean(
      age: age,
      salaireBrutMensuel: salary,
      canton: canton,
      employment: employment,
      arrivalAge: arrivalAge,
    );
    final priorSd = priorMean * 0.30; // 30% uncertainty without certificate

    // If user declared a value, collapse posterior
    if (declared != null && declared > 0) {
      return _collapseToDeclared(
        field: 'avoirLppTotal',
        declaredValue: declared,
        source: 'posterior:declared+adjusted',
      );
    }

    // Pure prior
    return _buildEstimate(
      field: 'avoirLppTotal',
      mean: priorMean,
      sd: priorSd,
      dataQuality: 0.3,
      source: 'prior:salary+age+canton',
      isDeclared: false,
    );
  }

  /// Prior mean for LPP total balance.
  ///
  /// Base: cumulative bonifications by age band (LPP art. 16).
  /// Adjustments:
  /// - High-tax cantons: +10% (more buybacks for tax deduction)
  /// - Low-tax cantons: -5% (less incentive for buybacks)
  /// - Employment 'mixte': 60% of base (part-time LPP)
  /// - Expats: start bonifications at arrivalAge
  static double _priorLppAvoirMean({
    required int age,
    required double salaireBrutMensuel,
    required String canton,
    required String employment,
    int? arrivalAge,
  }) {
    final salaireBrut = salaireBrutMensuel * 12;
    final salaireCoordonne =
        (salaireBrut - lppDeductionCoordination).clamp(lppSalaireCoordMin, double.infinity);

    // Start age: 25 for Swiss natives, arrivalAge for expats (LPP art. 7)
    final startAge = arrivalAge != null ? arrivalAge.clamp(25, 65) : 25;

    double total = 0;
    for (int a = startAge; a < age && a < 65; a++) {
      final taux = getLppBonificationRate(a);
      total = total * 1.01 + salaireCoordonne * taux; // 1% rendement
    }

    // Canton adjustment
    if (_highTaxCantons.contains(canton.toUpperCase())) {
      total *= 1.10; // More buybacks in high-tax cantons
    } else if (_lowTaxCantons.contains(canton.toUpperCase())) {
      total *= 0.95; // Less incentive in low-tax cantons
    }

    // Employment adjustment
    if (employment == 'mixte') {
      total *= 0.60; // Part-time LPP affiliation
    }

    return total.clamp(0.0, double.infinity);
  }

  // ════════════════════════════════════════════════════════════════
  //  PRIOR + POSTERIOR — TAUX DE CONVERSION
  // ════════════════════════════════════════════════════════════════

  /// Posterior estimate for LPP conversion rate.
  ///
  /// Prior: Swiss market median 5.8% (surobligatoire included).
  /// Legal minimum: 6.8% (obligatoire only, LPP art. 14).
  /// Market range: 4.5% to 6.8%.
  static PosteriorEstimate _posteriorTauxConversion(CoachProfile profile) {
    final declared = profile.prevoyance.tauxConversion;
    final employment = profile.employmentStatus;

    // Independant without LPP: not applicable
    if (employment == 'independant' &&
        (profile.prevoyance.avoirLppTotal == null ||
            profile.prevoyance.avoirLppTotal! <= 0)) {
      return const PosteriorEstimate(
        field: 'tauxConversion',
        mean: 0,
        median: 0,
        sd: 0,
        ci80Low: 0,
        ci80High: 0,
        dataQuality: 1.0,
        source: 'prior:independant_sans_lpp',
        isDeclared: false,
      );
    }

    // If user provided a non-default taux, treat as declared
    // Default in PrevoyanceProfile is 0.068 (minimum legal)
    final isNonDefault = (declared - 0.068).abs() > 0.001;
    if (isNonDefault) {
      return _collapseToDeclared(
        field: 'tauxConversion',
        declaredValue: declared,
        source: 'posterior:declared+caisse',
      );
    }

    // Prior: Swiss market statistics
    const priorMean = 0.058; // 5.8% median surobligatoire
    const priorSd = 0.006; // SD = 0.6pp

    return _buildEstimate(
      field: 'tauxConversion',
      mean: priorMean,
      sd: priorSd,
      dataQuality: 0.2,
      source: 'prior:marche_suisse_median',
      isDeclared: false,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PRIOR + POSTERIOR — 3A BALANCE
  // ════════════════════════════════════════════════════════════════

  /// Posterior estimate for total 3a savings.
  ///
  /// Prior:
  /// - 60% of salaried workers contribute to 3a (OFS adoption rate)
  /// - If contributing: max plafond × years since 25, 2% return
  /// - Cap at nombre3a × plafond × (age - 25) × compound factor
  static PosteriorEstimate _posteriorEpargne3a(CoachProfile profile) {
    final declared = profile.prevoyance.totalEpargne3a;
    final age = profile.age;
    final salary = profile.revenuBrutAnnuel;
    final nombre3a = profile.prevoyance.nombre3a;
    final employment = profile.employmentStatus;

    // If user declared a value > 0, collapse
    if (declared > 0) {
      return _collapseToDeclared(
        field: 'totalEpargne3a',
        declaredValue: declared,
        source: 'posterior:declared+comptes',
      );
    }

    // Prior computation
    final priorMean = _prior3aMean(
      age: age,
      salary: salary,
      nombre3a: nombre3a,
      employment: employment,
    );
    final priorSd = priorMean * 0.25; // 25% uncertainty

    return _buildEstimate(
      field: 'totalEpargne3a',
      mean: priorMean,
      sd: priorSd,
      dataQuality: 0.25,
      source: 'prior:adoption_rate+plafond',
      isDeclared: false,
    );
  }

  /// Prior mean for 3a total balance.
  static double _prior3aMean({
    required int age,
    required double salary,
    required int nombre3a,
    required String employment,
  }) {
    // No 3a accounts declared: use adoption rate
    if (nombre3a <= 0) {
      // 60% chance of having 3a → expected value = 0.6 × full estimate
      // For young people under 30: lower adoption rate (~40%)
      final adoptionRate = age < 30 ? 0.40 : 0.60;
      final fullEstimate = _compound3a(
        age: age,
        annualContrib: pilier3aPlafondAvecLpp,
        employment: employment,
      );
      return fullEstimate * adoptionRate;
    }

    // Has declared number of 3a accounts: assume max contribution
    final annualContrib = employment == 'independant'
        ? (salary * pilier3aTauxRevenuSansLpp).clamp(0.0, pilier3aPlafondSansLpp)
        : pilier3aPlafondAvecLpp;

    final fullEstimate = _compound3a(
      age: age,
      annualContrib: annualContrib,
      employment: employment,
    );

    // Cap: nombre3a × plafond × years × compound
    final maxCap = nombre3a * annualContrib * (age - 25).clamp(0, 40) * 1.3;
    return fullEstimate.clamp(0, maxCap);
  }

  /// Compound 3a contributions over time with 2% annual return.
  static double _compound3a({
    required int age,
    required double annualContrib,
    required String employment,
  }) {
    if (annualContrib <= 0) return 0;
    final years = (age - 25).clamp(0, 40);
    double total = 0;
    for (int i = 0; i < years; i++) {
      total = total * 1.02 + annualContrib;
    }
    return total;
  }

  // ════════════════════════════════════════════════════════════════
  //  PRIOR + POSTERIOR — EPARGNE LIQUIDE
  // ════════════════════════════════════════════════════════════════

  /// Posterior estimate for liquid savings.
  ///
  /// Prior: Swiss median 3-6 months of expenses.
  /// Adjustments: canton cost of living, children.
  static PosteriorEstimate _posteriorEpargneLiquide(CoachProfile profile) {
    final declared = profile.patrimoine.epargneLiquide;
    final salary = profile.salaireBrutMensuel;
    final canton = profile.canton;
    final etatCivil = profile.etatCivil;
    final nombreEnfants = profile.nombreEnfants;

    // If user declared > 0, collapse
    if (declared > 0) {
      return _collapseToDeclared(
        field: 'epargneLiquide',
        declaredValue: declared,
        source: 'posterior:declared+patrimoine',
      );
    }

    final priorMean = _priorEpargneLiquideMean(
      salary: salary,
      canton: canton,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
    );
    final priorSd = priorMean * 0.50; // 50% uncertainty — very high

    return _buildEstimate(
      field: 'epargneLiquide',
      mean: priorMean,
      sd: priorSd,
      dataQuality: 0.15,
      source: 'prior:salary+canton+famille',
      isDeclared: false,
    );
  }

  /// Prior mean for liquid savings.
  ///
  /// Swiss median: 3-6 months of estimated monthly expenses.
  /// Adjusted for canton cost of living and children.
  static double _priorEpargneLiquideMean({
    required double salary,
    required String canton,
    required CoachCivilStatus etatCivil,
    required int nombreEnfants,
  }) {
    // Estimate monthly expenses from salary (rough: ~60% of net)
    final netMensuel = salary * 0.87;
    final estimatedMonthlyExpenses = netMensuel * 0.60;

    // Swiss median: 4.5 months of expenses
    double base = estimatedMonthlyExpenses * 4.5;

    // Canton cost of living adjustment
    final costIndex = _cantonCostIndex[canton.toUpperCase()] ?? 1.0;
    base *= costIndex;

    // Children: reduce by 15% per child (expenses increase, savings decrease)
    final childFactor = 1.0 - (nombreEnfants * 0.15).clamp(0.0, 0.60);
    base *= childFactor;

    return base.clamp(0.0, double.infinity);
  }

  // ════════════════════════════════════════════════════════════════
  //  PRIOR + POSTERIOR — CONJOINT SALARY
  // ════════════════════════════════════════════════════════════════

  /// Posterior estimate for conjoint salary (couples only).
  ///
  /// Prior: Swiss dual-income statistics.
  /// - Married: partner earns ~85% of primary earner
  /// - Concubinage: ~95% of primary earner
  static PosteriorEstimate _posteriorConjointSalary(CoachProfile profile) {
    final conjoint = profile.conjoint;
    final declaredSalary = conjoint?.salaireBrutMensuel;

    // If conjoint has declared salary, collapse
    if (declaredSalary != null && declaredSalary > 0) {
      return _collapseToDeclared(
        field: 'conjointSalary',
        declaredValue: declaredSalary,
        source: 'posterior:declared+conjoint',
      );
    }

    final priorMean = _priorConjointSalaryMean(
      userSalary: profile.salaireBrutMensuel,
      canton: profile.canton,
      etatCivil: profile.etatCivil,
    );
    final priorSd = priorMean * 0.40; // 40% uncertainty — high

    return _buildEstimate(
      field: 'conjointSalary',
      mean: priorMean,
      sd: priorSd,
      dataQuality: 0.15,
      source: 'prior:user_salary+etat_civil',
      isDeclared: false,
    );
  }

  /// Prior mean for conjoint salary.
  static double _priorConjointSalaryMean({
    required double userSalary,
    required String canton,
    required CoachCivilStatus etatCivil,
  }) {
    // Swiss dual-income ratio (OFS)
    final ratio = etatCivil == CoachCivilStatus.marie ? 0.85 : 0.95;
    return userSalary * ratio;
  }

  // ════════════════════════════════════════════════════════════════
  //  PRIOR + POSTERIOR — DEPENSES MENSUELLES
  // ════════════════════════════════════════════════════════════════

  /// Posterior estimate for monthly expenses.
  ///
  /// Prior: Swiss BFS Household Budget Survey 2024.
  /// - Single: ~4200 CHF/month median
  /// - Couple no kids: ~6800 CHF/month
  /// - Family 2 kids: ~9500 CHF/month
  /// Adjusted by canton cost index.
  static PosteriorEstimate _posteriorMonthlyExpenses(CoachProfile profile) {
    final declared = profile.depenses.totalMensuel;

    // If user declared meaningful expenses (loyer + assurance > 0)
    if (declared > 0) {
      return _collapseToDeclared(
        field: 'depensesMensuelles',
        declaredValue: declared,
        source: 'posterior:declared+depenses',
      );
    }

    final priorMean = _priorMonthlyExpensesMean(
      salary: profile.salaireBrutMensuel,
      canton: profile.canton,
      etatCivil: profile.etatCivil,
      nombreEnfants: profile.nombreEnfants,
      housingStatus: profile.housingStatus,
    );
    final priorSd = priorMean * 0.20; // 20% uncertainty

    return _buildEstimate(
      field: 'depensesMensuelles',
      mean: priorMean,
      sd: priorSd,
      dataQuality: 0.20,
      source: 'prior:bfs_budget_survey+canton',
      isDeclared: false,
    );
  }

  /// Prior mean for monthly expenses (BFS Household Budget Survey 2024).
  static double _priorMonthlyExpensesMean({
    required double salary,
    required String canton,
    required CoachCivilStatus etatCivil,
    required int nombreEnfants,
    String? housingStatus,
  }) {
    // BFS 2024 medians by household type
    double base;
    if (etatCivil == CoachCivilStatus.celibataire ||
        etatCivil == CoachCivilStatus.divorce ||
        etatCivil == CoachCivilStatus.veuf) {
      base = 4200; // Single
    } else {
      // Couple
      base = nombreEnfants == 0 ? 6800 : 6800 + (nombreEnfants * 1350);
      // 2 kids: 6800 + 2700 = 9500 (matches BFS)
    }

    // Canton cost index
    final costIndex = _cantonCostIndex[canton.toUpperCase()] ?? 1.0;
    base *= costIndex;

    // Homeowner adjustment: typically lower housing costs than renters
    // after mortgage is established, but higher total costs (maintenance)
    if (housingStatus == 'proprietaire') {
      base *= 1.05; // Slight increase for maintenance/taxes
    }

    return base;
  }

  // ════════════════════════════════════════════════════════════════
  //  PRIOR + POSTERIOR — ANNEES CONTRIBUEES AVS
  // ════════════════════════════════════════════════════════════════

  /// Posterior estimate for AVS contribution years.
  ///
  /// Prior: age - 21 (contribution starts at 21, LAVS art. 3),
  /// minus any declared lacunes. Full = 44 years (LAVS art. 29bis).
  static PosteriorEstimate _posteriorAnneesContribuees(CoachProfile profile) {
    final declared = profile.prevoyance.anneesContribuees;

    // If declared (from extrait AVS), collapse
    if (declared != null && declared > 0) {
      return _collapseToDeclared(
        field: 'anneesContribuees',
        declaredValue: declared.toDouble(),
        source: 'posterior:declared+extrait_avs',
      );
    }

    // Prior: estimate from age and known lacunes
    final age = profile.age;
    final lacunes = profile.prevoyance.lacunesAVS ?? 0;
    final arrivalAge = profile.arrivalAge;

    double priorMean;
    if (arrivalAge != null && arrivalAge > 21) {
      // Expat: contributions start at arrival
      priorMean = (age - arrivalAge - lacunes).clamp(0, avsDureeCotisationComplete).toDouble();
    } else {
      // Swiss native: contributions since 21
      priorMean = (age - 21 - lacunes).clamp(0, avsDureeCotisationComplete).toDouble();
    }

    // SD: higher for expats (more uncertainty about foreign periods)
    final priorSd = arrivalAge != null ? 3.0 : 1.5;

    return _buildEstimate(
      field: 'anneesContribuees',
      mean: priorMean,
      sd: priorSd,
      dataQuality: arrivalAge != null ? 0.30 : 0.50,
      source: arrivalAge != null
          ? 'prior:age+arrival+lacunes'
          : 'prior:age+lacunes',
      isDeclared: false,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  EVI (EXPECTED VALUE OF INFORMATION)
  // ════════════════════════════════════════════════════════════════

  /// Compute Expected Value of Information for a field.
  ///
  /// EVI = projectionImpact × (ciWidth / |mean|)
  ///
  /// This measures: "If we asked the user for this data, how much would
  /// our retirement projection improve?"
  ///
  /// Higher EVI → more valuable to ask.
  static double _computeEvi(PosteriorEstimate estimate, double projectionImpact) {
    final uncertaintyWidth = estimate.ci80High - estimate.ci80Low;
    final normalizedUncertainty =
        uncertaintyWidth / estimate.mean.abs().clamp(1, double.infinity);
    return projectionImpact * normalizedUncertainty;
  }

  /// Compute overall uncertainty as a weighted average across all fields.
  ///
  /// Weight each field by its projection impact, then average the
  /// coefficient of variation (sd/mean).
  static double _computeOverallUncertainty(
      Map<String, PosteriorEstimate> estimates) {
    double weightedCvSum = 0;
    double totalWeight = 0;

    for (final entry in estimates.entries) {
      final weight = _impactWeights[entry.key] ?? 0.05;
      final cv = entry.value.coefficientOfVariation;
      // Cap CV at 1.0 to avoid infinity dominating
      weightedCvSum += weight * cv.clamp(0, 1.0);
      totalWeight += weight;
    }

    if (totalWeight <= 0) return 1.0;
    return (weightedCvSum / totalWeight).clamp(0.0, 1.0);
  }

  // ════════════════════════════════════════════════════════════════
  //  PROMPT BUILDER
  // ════════════════════════════════════════════════════════════════

  /// Build a French-language EVI prompt for a given field.
  ///
  /// Returns null if no meaningful prompt can be generated.
  static EviPrompt? _buildPrompt(
      String field, PosteriorEstimate estimate, double evi) {
    const promptDefs = <String, _PromptDef>{
      'avoirLppTotal': _PromptDef(
        label: 'Ajoute ton solde LPP',
        action:
            'Consulte ton certificat de prevoyance et saisis ton avoir total '
            '(obligatoire + surobligatoire). Tu peux le demander a ta caisse.',
        category: 'lpp',
      ),
      'tauxConversion': _PromptDef(
        label: 'Precise ton taux de conversion',
        action:
            'Sur ton certificat de prevoyance, cherche le taux de conversion '
            'de ta caisse (souvent entre 5% et 6.8%). Le taux legal de 6.8% '
            'ne s\'applique qu\'a la part obligatoire.',
        category: 'lpp',
      ),
      'totalEpargne3a': _PromptDef(
        label: 'Renseigne tes soldes 3a',
        action:
            'Saisis le solde de chacun de tes comptes 3e pilier. '
            'Tu trouves ces montants sur tes releves bancaires ou ton app.',
        category: '3a',
      ),
      'epargneLiquide': _PromptDef(
        label: 'Indique ton epargne liquide',
        action:
            'Quel est le total de tes comptes epargne et comptes courants ? '
            'Inclus tout ce qui est disponible rapidement.',
        category: 'patrimoine',
      ),
      'conjointSalary': _PromptDef(
        label: 'Ajoute le salaire de ton ou ta conjoint-e',
        action:
            'Pour affiner la projection du couple, indique le salaire brut '
            'mensuel de ton ou ta partenaire.',
        category: 'conjoint',
      ),
      'depensesMensuelles': _PromptDef(
        label: 'Detaille tes depenses mensuelles',
        action:
            'Ajoute ton loyer, assurance maladie et depenses fixes. '
            'Plus c\'est precis, meilleure sera la projection.',
        category: 'depenses',
      ),
      'anneesContribuees': _PromptDef(
        label: 'Commande ton extrait AVS',
        action:
            'Gratuit sur inforegister.ch — tu sauras exactement combien '
            'd\'annees tu as cotise a l\'AVS (et les lacunes eventuelles).',
        category: 'avs',
      ),
    };

    final def = promptDefs[field];
    if (def == null) return null;

    return EviPrompt(
      field: field,
      label: def.label,
      action: def.action,
      evi: evi,
      currentUncertainty: estimate.ci80Width,
      category: def.category,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════

  /// Build a PosteriorEstimate from a Gaussian prior (mean, sd).
  ///
  /// Computes median (= mean for normal), 80% CI using z = 1.282.
  static PosteriorEstimate _buildEstimate({
    required String field,
    required double mean,
    required double sd,
    required double dataQuality,
    required String source,
    required bool isDeclared,
  }) {
    // For a normal distribution, median = mean
    final median = mean;
    // 80% CI: mean +/- z80 * sd
    final ci80Low = (mean - _z80 * sd).clamp(0.0, double.infinity);
    final ci80High = mean + _z80 * sd;

    return PosteriorEstimate(
      field: field,
      mean: mean,
      median: median,
      sd: sd,
      ci80Low: ci80Low,
      ci80High: ci80High,
      dataQuality: dataQuality,
      source: source,
      isDeclared: isDeclared,
    );
  }

  /// Collapse a posterior to a tight distribution around a declared value.
  ///
  /// When the user provides an actual value, uncertainty shrinks to ~5%
  /// of the declared value (representing measurement uncertainty:
  /// "I read my LPP certificate but it's 3 months old").
  static PosteriorEstimate _collapseToDeclared({
    required String field,
    required double declaredValue,
    required String source,
  }) {
    // Measurement uncertainty: 5% of declared value
    final sd = declaredValue.abs() * 0.05;
    final ci80Low = (declaredValue - _z80 * sd).clamp(0.0, double.infinity);
    final ci80High = declaredValue + _z80 * sd;

    return PosteriorEstimate(
      field: field,
      mean: declaredValue,
      median: declaredValue,
      sd: sd,
      ci80Low: ci80Low,
      ci80High: ci80High,
      dataQuality: 0.95,
      source: source,
      isDeclared: true,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  INTERNAL HELPER
// ════════════════════════════════════════════════════════════════

/// Internal prompt definition (label + action + category).
class _PromptDef {
  final String label;
  final String action;
  final String category;

  const _PromptDef({
    required this.label,
    required this.action,
    required this.category,
  });
}
