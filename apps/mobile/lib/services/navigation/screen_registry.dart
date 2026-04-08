/// ScreenRegistry — central map of all MINT surfaces.
///
/// See docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §4
///
/// Every surface that the Coach may route to (preferFromChat == true) MUST be
/// registered here with:
///  - an intent tag (snake_case, unique)
///  - a behavior (A/B/C/D/E)
///  - the minimum CoachProfile fields required to open the screen usefully
///
/// Pure data — no Flutter/widget imports. Safe to use in tests and services.
library;

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/navigation/readiness_result.dart';

// ════════════════════════════════════════════════════════════════
//  SCREEN BEHAVIOR
// ════════════════════════════════════════════════════════════════

/// The orchestration behavior class of a MINT surface.
///
/// Every surface belongs to exactly one behavior — this determines
/// whether the RoutePlanner opens it, responds inline, or asks first.
enum ScreenBehavior {
  /// A — Direct Answer: coach responds inline with a widget. No screen opened.
  directAnswer,

  /// B — Decision Canvas: simulation / arbitrage screen. Requires readiness check.
  decisionCanvas,

  /// C — Roadmap Flow: life event flow / checklist. May have no required fields.
  roadmapFlow,

  /// D — Capture / Utility: data entry, document scan, profile completion.
  captureUtility,

  /// E — Conversation pure: no dedicated surface. Coach responds in text.
  conversationPure,
}

// ════════════════════════════════════════════════════════════════
//  SCREEN ENTRY
// ════════════════════════════════════════════════════════════════

/// A single entry in the ScreenRegistry.
///
/// Declares the route, semantic intent tag, behavior class, and the
/// data requirements the ReadinessGate checks before opening.
class ScreenEntry {
  /// Canonical GoRouter route string. Example: '/rente-vs-capital'.
  final String route;

  /// Semantic tag used by the LLM's IntentResolver.
  /// Must be unique across the registry.
  /// Example: 'retirement_choice', 'life_event_divorce', 'budget_overview'.
  final String intentTag;

  /// Orchestration behavior class (A–E).
  final ScreenBehavior behavior;

  /// CoachProfile field paths that MUST be present for this screen to open.
  ///
  /// Keys use the same dotted-path convention as CoachProfile.dataSources.
  /// The ReadinessGate checks whether these are non-null / non-empty.
  /// Example: ['salaireBrut', 'age', 'canton']
  final List<String> requiredFields;

  /// CoachProfile field paths that improve the experience but are not blocking.
  ///
  /// When missing, the screen opens in estimation mode (bandeau d'avertissement).
  final List<String> optionalFields;

  /// If readiness is Blocked, redirect here instead of opening the surface.
  ///
  /// Format: GoRouter route string, optionally with query params.
  /// Null means the RoutePlanner will emit [RouteAction.askFirst].
  final String? fallbackRoute;

  /// Whether the Coach is allowed to open this screen from the chat.
  ///
  /// false for admin screens, landing, auth flows, achievements, shell tabs.
  final bool preferFromChat;

  /// Whether the screen should be pre-filled from CoachProfile data.
  final bool prefillFromProfile;

  /// Optional fine-grained gate for Swiss-critical surfaces.
  ///
  /// When non-null, [ReadinessGate] calls this function instead of the
  /// generic field-checking heuristic. Use for surfaces that require
  /// archetype-aware or composite-condition logic beyond field presence.
  ///
  /// Must be a top-level or static function — not a closure — so that
  /// entries can be declared as `static final` with stable references.
  final ReadinessResult Function(CoachProfile profile)? customGate;

  const ScreenEntry({
    required this.route,
    required this.intentTag,
    required this.behavior,
    this.requiredFields = const [],
    this.optionalFields = const [],
    this.fallbackRoute,
    this.preferFromChat = true,
    this.prefillFromProfile = false,
    this.customGate,
  });
}

// ════════════════════════════════════════════════════════════════
//  SCREEN REGISTRY INTERFACE
// ════════════════════════════════════════════════════════════════

/// Registry of all routable MINT surfaces.
///
/// The canonical implementation is [MintScreenRegistry].
/// Use [InMemoryScreenRegistry] for lightweight test fixtures.
abstract class ScreenRegistry {
  const ScreenRegistry();

  /// Look up a [ScreenEntry] by its [intentTag].
  ///
  /// Returns null if the tag is not registered (unknown intent).
  ScreenEntry? findByIntent(String intentTag);

  /// Look up a [ScreenEntry] by its canonical [route].
  ///
  /// Returns null if the route is not registered.
  ScreenEntry? findByRoute(String route);

  /// All registered entries, for introspection and tests.
  List<ScreenEntry> get all;
}

// ════════════════════════════════════════════════════════════════
//  IN-MEMORY REGISTRY (lightweight fixture for tests)
// ════════════════════════════════════════════════════════════════

/// Minimal in-memory [ScreenRegistry] backed by a fixed list of entries.
///
/// Use this in tests with a hand-crafted entry list.
/// For production use [MintScreenRegistry].
class InMemoryScreenRegistry extends ScreenRegistry {
  final List<ScreenEntry> _entries;

  const InMemoryScreenRegistry(this._entries);

  @override
  ScreenEntry? findByIntent(String intentTag) {
    for (final e in _entries) {
      if (e.intentTag == intentTag) return e;
    }
    return null;
  }

  @override
  ScreenEntry? findByRoute(String route) {
    for (final e in _entries) {
      if (e.route == route) return e;
    }
    return null;
  }

  @override
  List<ScreenEntry> get all => List.unmodifiable(_entries);
}

// ════════════════════════════════════════════════════════════════
//  CUSTOM GATE FUNCTIONS — fine-grained Swiss-critical readiness
// ════════════════════════════════════════════════════════════════
//
// Each function is top-level so it can be stored as a const-like
// static reference in ScreenEntry.customGate.
//
// Naming convention: _gate<SurfaceName>(CoachProfile) → ReadinessResult

/// Gate: /invalidite — disability gap calculator.
///
/// Requires both [employmentStatus] AND [salaireBrut].
/// If the user is independent (employmentStatus == 'independant'), the
/// dedicated self-employed flow takes precedence (different pillars / IJM).
ReadinessResult gateInvalidite(CoachProfile profile) {
  final hasEmployment = profile.employmentStatus.isNotEmpty;
  final hasSalary = profile.salaireBrutMensuel > 0;

  if (!hasEmployment && !hasSalary) {
    return const ReadinessResult.blocked(
      ['employmentStatus', 'salaireBrut'],
      ['employmentStatus', 'salaireBrut'],
    );
  }
  if (!hasEmployment) {
    return const ReadinessResult.blocked(
      ['employmentStatus'],
      ['employmentStatus'],
    );
  }
  if (!hasSalary) {
    return const ReadinessResult.blocked(
      ['salaireBrut'],
      ['salaireBrut'],
    );
  }
  // Both present — if independent, route to dedicated screen (still ready
  // here; RoutePlanner redirects via profile.archetype externally).
  return const ReadinessResult.ready();
}

/// Gate: /lpp-deep/rachat — LPP buy-back simulator.
///
/// Requires [avoirLpp] OR [rachatMaximum]. Without either, the screen has
/// no meaningful content and the user should scan their LPP certificate.
ReadinessResult gateRachatLppDeep(CoachProfile profile) {
  final hasAvoir = profile.prevoyance.avoirLppTotal != null &&
      profile.prevoyance.avoirLppTotal! > 0;
  final hasRachat = profile.prevoyance.rachatMaximum != null &&
      profile.prevoyance.rachatMaximum! > 0;

  if (!hasAvoir && !hasRachat) {
    // Blocked — suggest document scan (fallbackRoute handles the CTA)
    return const ReadinessResult.blocked(
      ['avoirLpp', 'rachatMaximum'],
      ['avoirLpp', 'rachatMaximum'],
    );
  }
  if (!hasAvoir || !hasRachat) {
    // One of the two is present — partial (estimation mode)
    final missing = <String>[
      if (!hasAvoir) 'avoirLpp',
      if (!hasRachat) 'rachatMaximum',
    ];
    return ReadinessResult.partial(missing);
  }
  return const ReadinessResult.ready();
}

/// Gate: /segments/frontalier — cross-border worker hub.
///
/// Should only be surfaced for frontaliers (permis G) or users who have
/// declared employmentStatus as 'frontalier'. Non-frontaliers are blocked.
ReadinessResult gateFrontalier(CoachProfile profile) {
  final isPermitG = profile.residencePermit == 'G';
  final isFrontalierStatus = profile.employmentStatus == 'frontalier';

  if (!isPermitG && !isFrontalierStatus) {
    return const ReadinessResult.blocked(
      ['employmentStatus'],
      ['employmentStatus'],
    );
  }
  return const ReadinessResult.ready();
}

/// Gate: /debt/ratio — budget sous tension / debt ratio calculator.
///
/// Requires [netIncome] AND at least one charge entered (totalMensuel > 0).
/// If no charges have been entered, open in partial mode with enrichment CTA.
ReadinessResult gateBudgetSousTension(CoachProfile profile) {
  final hasIncome = profile.salaireBrutMensuel > 0;
  final hasCharges = profile.depenses.totalMensuel > 0;

  if (!hasIncome) {
    return const ReadinessResult.blocked(
      ['netIncome'],
      ['netIncome'],
    );
  }
  if (!hasCharges) {
    // Income present but no charges — open in partial mode
    return const ReadinessResult.partial(['totalCharges']);
  }
  return const ReadinessResult.ready();
}

/// Gate: /rente-vs-capital — the most critical retirement decision.
///
/// Hard minimum: [salaireBrut] + [age].
/// Quality tiers:
///   - Both LPP fields present → ready (high quality).
///   - Only one LPP field present → partial (estimation mode).
///   - Neither LPP field → partial (projection will use salary-derived estimate).
///   - Missing salary or age → blocked.
ReadinessResult gateRenteVsCapital(CoachProfile profile) {
  final hasSalary = profile.salaireBrutMensuel > 0;
  final hasAge = profile.age > 0;

  // Blocking: no salary or age
  if (!hasSalary && !hasAge) {
    return const ReadinessResult.blocked(
      ['salaireBrut', 'age'],
      ['salaireBrut', 'age'],
    );
  }
  if (!hasSalary) {
    return const ReadinessResult.blocked(
      ['salaireBrut'],
      ['salaireBrut'],
    );
  }
  if (!hasAge) {
    return const ReadinessResult.blocked(
      ['age'],
      ['age'],
    );
  }

  // Salary + age present — check LPP quality
  final hasAvoir = profile.prevoyance.avoirLppTotal != null &&
      profile.prevoyance.avoirLppTotal! > 0;
  final hasRachat = profile.prevoyance.rachatMaximum != null &&
      profile.prevoyance.rachatMaximum! > 0;

  if (!hasAvoir && !hasRachat) {
    // Both missing — partial (screen works with estimates)
    return const ReadinessResult.partial(['avoirLpp', 'rachatMaximum']);
  }
  if (!hasAvoir || !hasRachat) {
    // One missing — partial (low quality but operable)
    final missing = <String>[
      if (!hasAvoir) 'avoirLpp',
      if (!hasRachat) 'rachatMaximum',
    ];
    return ReadinessResult.partial(missing);
  }
  return const ReadinessResult.ready();
}

// ════════════════════════════════════════════════════════════════
//  MINT SCREEN REGISTRY — canonical, all surfaces
// ════════════════════════════════════════════════════════════════

/// Production registry with all MINT surfaces.
///
/// Usage (static API — no instance required):
/// ```dart
/// final entry   = MintScreenRegistry.findByIntent('retirement_choice');
/// final canvases = MintScreenRegistry.findByBehavior(ScreenBehavior.decisionCanvas);
/// final routable = MintScreenRegistry.chatRoutable();
/// ```
class MintScreenRegistry extends ScreenRegistry {
  const MintScreenRegistry();

  // ── A — Direct Answer ─────────────────────────────────────────
  // Resolved inline in the chat; these entries inform the RoutePlanner
  // that no screen needs to be opened.

  static const ScreenEntry _budgetOverview = ScreenEntry(
    route: '/budget',
    intentTag: 'budget_overview',
    behavior: ScreenBehavior.directAnswer,
    requiredFields: ['netIncome'],
    optionalFields: ['depenses'],
    fallbackRoute: '/onboarding/quick',
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _cantonalBenchmark = ScreenEntry(
    route: '/cantonal-benchmark',
    intentTag: 'cantonal_comparison',
    behavior: ScreenBehavior.directAnswer,
    requiredFields: ['canton', 'netIncome'],
    optionalFields: ['salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  // ── B — Decision Canvas ───────────────────────────────────────

  // customGate overrides generic field-check → must be static final
  // ignore: prefer_const_constructors
  static final ScreenEntry _renteVsCapital = ScreenEntry(
    route: '/rente-vs-capital',
    intentTag: 'retirement_choice',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'age'],
    optionalFields: ['canton', 'avoirLpp', 'rachatMaximum'],
    fallbackRoute: '/coach/chat?prompt=retraite',
    preferFromChat: true,
    prefillFromProfile: true,
    customGate: gateRenteVsCapital,
  );

  static const ScreenEntry _retraite = ScreenEntry(
    route: '/retraite',
    intentTag: 'retirement_projection',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'age', 'canton'],
    optionalFields: ['avoirLpp', 'rachatMaximum', 'civilStatus'],
    fallbackRoute: '/coach/chat?prompt=retraite',
    preferFromChat: true,
    prefillFromProfile: true,
  );

  // FIX-172: preretraite_complete must exist in registry for LLM to suggest it.
  // This is the flagship 11-step journey for pre-retirees (53-64 cohort).
  static const ScreenEntry _preretraiteComplete = ScreenEntry(
    route: '/retraite?mode=preretraite',
    intentTag: 'preretraite_complete',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'age', 'canton'],
    optionalFields: ['avoirLpp', 'rachatMaximum'],
    fallbackRoute: '/coach/chat?prompt=retraite',
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _pilier3a = ScreenEntry(
    route: '/pilier-3a',
    intentTag: 'simulator_3a',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'canton'],
    optionalFields: ['age', 'employmentStatus'],
    fallbackRoute: '/coach/chat?prompt=3a',
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _staggeredWithdrawal = ScreenEntry(
    route: '/3a-deep/staggered-withdrawal',
    intentTag: 'tax_optimization_3a',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['age', 'canton'],
    optionalFields: ['salaireBrut'],
    fallbackRoute: '/coach/chat?prompt=3a',
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _fiscal = ScreenEntry(
    route: '/fiscal',
    intentTag: 'cantonal_fiscal_comparator',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['canton', 'netIncome'],
    optionalFields: ['civilStatus', 'nombreEnfants'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _rachatLpp = ScreenEntry(
    route: '/rachat-lpp',
    intentTag: 'lpp_buyback',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'age', 'canton'],
    optionalFields: ['rachatMaximum', 'avoirLpp'],
    fallbackRoute: '/coach/chat?prompt=rachat+lpp',
    preferFromChat: true,
    prefillFromProfile: true,
  );

  // customGate overrides generic field-check → must be static final
  // ignore: prefer_const_constructors
  static final ScreenEntry _lppDeepRachat = ScreenEntry(
    route: '/lpp-deep/rachat',
    intentTag: 'lpp_deep_rachat',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['avoirLpp', 'rachatMaximum'],
    fallbackRoute: '/scan',
    preferFromChat: true,
    prefillFromProfile: true,
    customGate: gateRachatLppDeep,
  );

  static const ScreenEntry _epl = ScreenEntry(
    route: '/epl',
    intentTag: 'early_pension_withdrawal',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'age', 'canton'],
    optionalFields: ['avoirLpp'],
    fallbackRoute: '/coach/chat?prompt=epl',
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _affordability = ScreenEntry(
    route: '/hypotheque',
    intentTag: 'housing_purchase',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'canton'],
    optionalFields: ['avoirLpp', 'epargne'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  // customGate overrides generic field-check → must be static final
  // ignore: prefer_const_constructors
  static final ScreenEntry _invalidite = ScreenEntry(
    route: '/invalidite',
    intentTag: 'disability_gap',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['employmentStatus', 'salaireBrut'],
    optionalFields: ['age'],
    preferFromChat: true,
    prefillFromProfile: true,
    customGate: gateInvalidite,
  );

  static const ScreenEntry _jobComparison = ScreenEntry(
    route: '/simulator/job-comparison',
    intentTag: 'job_comparison',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'canton'],
    optionalFields: ['employmentStatus'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _lamalFranchise = ScreenEntry(
    route: '/assurances/lamal',
    intentTag: 'lamal_franchise',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['age', 'canton'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _decaissement = ScreenEntry(
    route: '/decaissement',
    intentTag: 'withdrawal_sequencing',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'age', 'canton'],
    optionalFields: ['avoirLpp', 'epargne3a'],
    fallbackRoute: '/coach/chat?prompt=decaissement',
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _amortization = ScreenEntry(
    route: '/mortgage/amortization',
    intentTag: 'mortgage_amortization',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['salaireBrut', 'canton'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _saronVsFixed = ScreenEntry(
    route: '/mortgage/saron-vs-fixed',
    intentTag: 'saron_vs_fixed',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _eplCombined = ScreenEntry(
    route: '/mortgage/epl-combined',
    intentTag: 'epl_combined',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'age', 'canton'],
    optionalFields: ['avoirLpp'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _dividendeVsSalaire = ScreenEntry(
    route: '/independants/dividende-salaire',
    intentTag: 'dividende_vs_salaire',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['employmentStatus'],
    optionalFields: ['salaireBrut', 'canton'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _providerComparator = ScreenEntry(
    route: '/3a-deep/comparator',
    intentTag: 'provider_comparator_3a',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['age', 'salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _realReturn = ScreenEntry(
    route: '/3a-deep/real-return',
    intentTag: 'real_return_3a',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['age'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _retroactif3a = ScreenEntry(
    route: '/3a-retroactif',
    intentTag: 'retroactive_3a',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'age', 'canton'],
    optionalFields: ['employmentStatus'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _locationVsPropriete = ScreenEntry(
    route: '/arbitrage/location-vs-propriete',
    intentTag: 'rent_vs_buy',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'canton'],
    optionalFields: ['epargne'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _succession = ScreenEntry(
    route: '/succession',
    intentTag: 'succession_patrimoine',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['civilStatus', 'nombreEnfants'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _librePassage = ScreenEntry(
    route: '/libre-passage',
    intentTag: 'libre_passage',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['employmentStatus'],
    optionalFields: ['avoirLpp'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _allocationAnnuelle = ScreenEntry(
    route: '/arbitrage/allocation-annuelle',
    intentTag: 'annual_allocation',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'canton'],
    optionalFields: ['age', 'riskTolerance'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _coverageCheck = ScreenEntry(
    route: '/assurances/coverage',
    intentTag: 'coverage_check',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['canton'],
    optionalFields: ['salaireBrut', 'age', 'employmentStatus'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _genderGap = ScreenEntry(
    route: '/segments/gender-gap',
    intentTag: 'gender_gap',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'age'],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _disabilitySelfEmployed = ScreenEntry(
    route: '/disability/self-employed',
    intentTag: 'disability_self_employed',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['employmentStatus'],
    optionalFields: ['salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _avsCotisations = ScreenEntry(
    route: '/independants/avs',
    intentTag: 'avs_cotisations_independant',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['employmentStatus'],
    optionalFields: ['salaireBrut', 'age'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _ijm = ScreenEntry(
    route: '/independants/ijm',
    intentTag: 'ijm_independant',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['employmentStatus'],
    optionalFields: ['salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _pillar3aIndep = ScreenEntry(
    route: '/independants/3a',
    intentTag: 'pillar_3a_independant',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['employmentStatus'],
    optionalFields: ['salaireBrut', 'canton'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _lppVolontaire = ScreenEntry(
    route: '/independants/lpp-volontaire',
    intentTag: 'lpp_volontaire',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['employmentStatus'],
    optionalFields: ['salaireBrut', 'age'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _simulatorCompound = ScreenEntry(
    route: '/simulator/compound',
    intentTag: 'compound_interest_simulator',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _simulatorLeasing = ScreenEntry(
    route: '/simulator/leasing',
    intentTag: 'leasing_simulator',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _simulatorCredit = ScreenEntry(
    route: '/simulator/credit',
    intentTag: 'consumer_credit_simulator',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  // customGate overrides generic field-check → must be static final
  // ignore: prefer_const_constructors
  static final ScreenEntry _debtRatio = ScreenEntry(
    route: '/debt/ratio',
    intentTag: 'debt_ratio',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['netIncome'],
    optionalFields: ['salaireBrut'],
    fallbackRoute: '/onboarding/quick',
    preferFromChat: true,
    prefillFromProfile: true,
    customGate: gateBudgetSousTension,
  );

  static const ScreenEntry _debtRepayment = ScreenEntry(
    route: '/debt/repayment',
    intentTag: 'debt_repayment',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _debtRiskCheck = ScreenEntry(
    route: '/check/debt',
    intentTag: 'debt_risk_check',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['salaireBrut', 'netIncome'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  /// T3-2: Help resources for debt crisis situations.
  static const ScreenEntry _debtHelp = ScreenEntry(
    route: '/debt/help',
    intentTag: 'debt_help_resources',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    preferFromChat: true,
  );

  static const ScreenEntry _financialReport = ScreenEntry(
    route: '/rapport',
    intentTag: 'financial_report',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'age', 'canton'],
    optionalFields: ['civilStatus', 'avoirLpp', 'epargne3a'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _timeline = ScreenEntry(
    route: '/timeline',
    intentTag: 'life_timeline',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['age'],
    optionalFields: ['salaireBrut', 'canton'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _arbitrageBilan = ScreenEntry(
    route: '/arbitrage/bilan',
    intentTag: 'arbitrage_bilan',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'age', 'canton'],
    optionalFields: ['avoirLpp', 'epargne3a'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _cockpit = ScreenEntry(
    route: '/coach/cockpit',
    intentTag: 'financial_cockpit',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: ['salaireBrut', 'age', 'canton'],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  static const ScreenEntry _imputedRental = ScreenEntry(
    route: '/mortgage/imputed-rental',
    intentTag: 'imputed_rental',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['canton'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  // ── C — Roadmap Flow ──────────────────────────────────────────

  static const ScreenEntry _divorce = ScreenEntry(
    route: '/divorce',
    intentTag: 'life_event_divorce',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: ['salaireBrut', 'conjoint'],
    optionalFields: ['avoirLpp', 'civilStatus'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _naissance = ScreenEntry(
    route: '/naissance',
    intentTag: 'life_event_birth',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: ['salaireBrut', 'canton'],
    optionalFields: ['civilStatus'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _mariage = ScreenEntry(
    route: '/mariage',
    intentTag: 'life_event_marriage',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: ['salaireBrut'],
    optionalFields: ['civilStatus', 'conjoint'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _concubinage = ScreenEntry(
    route: '/concubinage',
    intentTag: 'life_event_concubinage',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: ['salaireBrut'],
    optionalFields: ['civilStatus'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _unemployment = ScreenEntry(
    route: '/unemployment',
    intentTag: 'life_event_job_loss',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: ['salaireBrut', 'age'],
    optionalFields: ['employmentStatus'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _firstJob = ScreenEntry(
    route: '/first-job',
    intentTag: 'life_event_first_job',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: [],
    optionalFields: ['age', 'salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _housingSale = ScreenEntry(
    route: '/life-event/housing-sale',
    intentTag: 'life_event_housing_sale',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: ['canton'],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _donation = ScreenEntry(
    route: '/life-event/donation',
    intentTag: 'life_event_donation',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: ['canton'],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _decesProche = ScreenEntry(
    route: '/life-event/deces-proche',
    intentTag: 'life_event_death_of_relative',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: ['canton'],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _expat = ScreenEntry(
    route: '/expatriation',
    intentTag: 'life_event_country_move',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: ['canton'],
    optionalFields: ['employmentStatus'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  // customGate overrides generic field-check → must be static final
  // ignore: prefer_const_constructors
  static final ScreenEntry _frontalier = ScreenEntry(
    route: '/segments/frontalier',
    intentTag: 'cross_border',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: ['employmentStatus'],
    optionalFields: ['canton'],
    preferFromChat: true,
    prefillFromProfile: false,
    customGate: gateFrontalier,
  );

  static const ScreenEntry _independant = ScreenEntry(
    route: '/segments/independant',
    intentTag: 'self_employment',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: [],
    optionalFields: ['salaireBrut', 'employmentStatus'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _demenagementCantonal = ScreenEntry(
    route: '/life-event/demenagement-cantonal',
    intentTag: 'life_event_canton_move',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: [],
    optionalFields: ['canton', 'salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _disabilityInsurance = ScreenEntry(
    route: '/disability/insurance',
    intentTag: 'disability_insurance_flow',
    behavior: ScreenBehavior.roadmapFlow,
    requiredFields: ['employmentStatus'],
    optionalFields: ['salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  // ── D — Capture / Utility ──────────────────────────────────────

  static const ScreenEntry _documentScan = ScreenEntry(
    route: '/scan',
    intentTag: 'document_scan',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _documents = ScreenEntry(
    route: '/documents',
    intentTag: 'documents_list',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _profile = ScreenEntry(
    route: '/profile',
    intentTag: 'profile_enrichment',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _avsGuide = ScreenEntry(
    route: '/scan/avs-guide',
    intentTag: 'avs_guide',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _household = ScreenEntry(
    route: '/couple',
    intentTag: 'household_couple',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: ['conjoint'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _openBankingHub = ScreenEntry(
    route: '/open-banking',
    intentTag: 'open_banking',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _consent = ScreenEntry(
    route: '/profile/consent',
    intentTag: 'consent_settings',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _byokSettings = ScreenEntry(
    route: '/profile/byok',
    intentTag: 'byok_settings',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _slmSettings = ScreenEntry(
    route: '/profile/slm',
    intentTag: 'slm_settings',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _scanReview = ScreenEntry(
    route: '/scan/review',
    intentTag: 'scan_review',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _scanImpact = ScreenEntry(
    route: '/scan/impact',
    intentTag: 'scan_impact',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _documentDetail = ScreenEntry(
    route: '/documents/:id',
    intentTag: 'document_detail',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _coupleAccept = ScreenEntry(
    route: '/couple/accept',
    intentTag: 'couple_accept_invitation',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _dataBlock = ScreenEntry(
    route: '/data-block/:type',
    intentTag: 'data_block_enrichment',
    behavior: ScreenBehavior.captureUtility,
    preferFromChat: false, // Parameterized route — must not be opened from chat without :type resolution
    requiredFields: [],
    optionalFields: [],
    prefillFromProfile: false,
  );

  static const ScreenEntry _bankImport = ScreenEntry(
    route: '/bank-import',
    intentTag: 'bank_import',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _openBankingTransactions = ScreenEntry(
    route: '/open-banking/transactions',
    intentTag: 'open_banking_transactions',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _openBankingConsents = ScreenEntry(
    route: '/open-banking/consents',
    intentTag: 'open_banking_consents',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _adminObservability = ScreenEntry(
    route: '/profile/admin-observability',
    intentTag: 'admin_observability',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _adminAnalytics = ScreenEntry(
    route: '/profile/admin-analytics',
    intentTag: 'admin_analytics',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  // ── E — Conversation pure / Non-routable from chat ─────────────

  static const ScreenEntry _landing = ScreenEntry(
    route: '/',
    intentTag: 'landing',
    behavior: ScreenBehavior.conversationPure,
    preferFromChat: false,
  );

  static const ScreenEntry _coachChat = ScreenEntry(
    route: '/coach/chat',
    intentTag: 'coach_chat',
    behavior: ScreenBehavior.conversationPure,
    preferFromChat: false,
  );

  static const ScreenEntry _achievements = ScreenEntry(
    route: '/achievements',
    intentTag: 'achievements',
    behavior: ScreenBehavior.conversationPure,
    preferFromChat: false,
  );

  static const ScreenEntry _home = ScreenEntry(
    route: '/home',
    intentTag: 'home_shell',
    behavior: ScreenBehavior.conversationPure,
    preferFromChat: false,
  );

  static const ScreenEntry _authLogin = ScreenEntry(
    route: '/auth/login',
    intentTag: 'auth_login',
    behavior: ScreenBehavior.conversationPure,
    preferFromChat: false,
  );

  static const ScreenEntry _authRegister = ScreenEntry(
    route: '/auth/register',
    intentTag: 'auth_register',
    behavior: ScreenBehavior.conversationPure,
    preferFromChat: false,
  );

  static const ScreenEntry _authForgotPassword = ScreenEntry(
    route: '/auth/forgot-password',
    intentTag: 'auth_forgot_password',
    behavior: ScreenBehavior.conversationPure,
    preferFromChat: false,
  );

  static const ScreenEntry _authVerifyEmail = ScreenEntry(
    route: '/auth/verify-email',
    intentTag: 'auth_verify_email',
    behavior: ScreenBehavior.conversationPure,
    preferFromChat: false,
  );

  static const ScreenEntry _exploreRetraite = ScreenEntry(
    route: '/explore/retraite',
    intentTag: 'explore_hub_retraite',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: ['age', 'salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _exploreFamille = ScreenEntry(
    route: '/explore/famille',
    intentTag: 'explore_hub_famille',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _exploreTravail = ScreenEntry(
    route: '/explore/travail',
    intentTag: 'explore_hub_travail',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: ['employmentStatus'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _exploreLogement = ScreenEntry(
    route: '/explore/logement',
    intentTag: 'explore_hub_logement',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: ['canton'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _exploreFiscalite = ScreenEntry(
    route: '/explore/fiscalite',
    intentTag: 'explore_hub_fiscalite',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: ['canton', 'salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _explorePatrimoine = ScreenEntry(
    route: '/explore/patrimoine',
    intentTag: 'explore_hub_patrimoine',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _exploreSante = ScreenEntry(
    route: '/explore/sante',
    intentTag: 'explore_hub_sante',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _coachCheckin = ScreenEntry(
    route: '/coach/checkin',
    intentTag: 'coach_checkin',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _coachRefresh = ScreenEntry(
    route: '/coach/refresh',
    intentTag: 'coach_annual_refresh',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _coachHistory = ScreenEntry(
    route: '/coach/history',
    intentTag: 'coach_history',
    behavior: ScreenBehavior.conversationPure,
    preferFromChat: false,
  );

  static const ScreenEntry _educationHub = ScreenEntry(
    route: '/education/hub',
    intentTag: 'education_hub',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _educationTheme = ScreenEntry(
    route: '/education/theme/:id',
    intentTag: 'education_theme_detail',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _portfolio = ScreenEntry(
    route: '/portfolio',
    intentTag: 'portfolio_overview',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['salaireBrut', 'epargne'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  static const ScreenEntry _scoreReveal = ScreenEntry(
    route: '/score-reveal',
    intentTag: 'score_reveal',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _onboardingQuick = ScreenEntry(
    route: '/onboarding/quick',
    intentTag: 'onboarding_quick',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _onboardingPremierEclairage = ScreenEntry(
    route: '/onboarding/premier-eclairage',
    intentTag: 'onboarding_premier_eclairage',
    behavior: ScreenBehavior.captureUtility,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: false,
    prefillFromProfile: false,
  );

  static const ScreenEntry _askMint = ScreenEntry(
    route: '/ask-mint',
    intentTag: 'ask_mint',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: [],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  // ── Surface deduplication (S52) ──────────────────────────────

  /// Financial Summary — canonical view of the user's balance sheet.
  ///
  /// Behavior B: opens /profile/bilan as a decision canvas. Preferred from
  /// chat so the Coach can surface a full patrimoine overview on request.
  static const ScreenEntry _financialSummary = ScreenEntry(
    route: '/profile/bilan',
    intentTag: 'financial_summary',
    behavior: ScreenBehavior.decisionCanvas,
    requiredFields: [],
    optionalFields: ['salaireBrut', 'age', 'canton'],
    preferFromChat: true,
    prefillFromProfile: true,
  );

  /// Confidence Dashboard — displays the 4-axis EnhancedConfidence score.
  ///
  /// Behavior A: can be shown inline in chat as a widget. Also routable as
  /// a full-screen view. preferFromChat true so the Coach can open it.
  static const ScreenEntry _confidenceDashboard = ScreenEntry(
    route: '/confidence',
    intentTag: 'confidence_dashboard',
    behavior: ScreenBehavior.directAnswer,
    requiredFields: [],
    optionalFields: ['salaireBrut', 'age', 'canton'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  // ── S65 — Expert Tier ────────────────────────────────────────

  /// Opens the coach chat with a consult-specialist intent pre-loaded.
  ///
  /// Behavior E: no dedicated screen — the coach narrates and suggests
  /// the relevant AdvisorSpecialization based on profile.
  static const ScreenEntry _consultSpecialist = ScreenEntry(
    route: '/coach/chat?prompt=specialist',
    intentTag: 'consult_specialist',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: ['age', 'canton', 'salaireBrut'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  // ── S68 — Agent Autonome ─────────────────────────────────────

  /// Agent autonome: coach walks the user through tax declaration prep.
  static const ScreenEntry _prepareTaxForm = ScreenEntry(
    route: '/coach/chat?prompt=tax_declaration',
    intentTag: 'prepare_tax_form',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: ['salaireBrut', 'canton', 'employmentStatus'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  /// Agent autonome: coach generates the AVS extract request letter.
  static const ScreenEntry _prepareAvsLetter = ScreenEntry(
    route: '/coach/chat?prompt=avs_extract',
    intentTag: 'prepare_avs_letter',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: ['age', 'canton'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  /// Agent autonome: coach generates the LPP transfer letter.
  static const ScreenEntry _prepareLppTransfer = ScreenEntry(
    route: '/coach/chat?prompt=lpp_transfer',
    intentTag: 'prepare_lpp_transfer',
    behavior: ScreenBehavior.conversationPure,
    requiredFields: [],
    optionalFields: ['avoirLpp'],
    preferFromChat: true,
    prefillFromProfile: false,
  );

  // ════════════════════════════════════════════════════════════════
  //  MASTER LIST — all surfaces
  // ════════════════════════════════════════════════════════════════

  /// Canonical list of all MINT surfaces.
  ///
  /// Every intent tag MUST be unique.
  /// Every route MUST start with '/'.
  /// Routes MUST match exactly the GoRouter declarations in app.dart.
  // static final because some entries use customGate (non-const function refs)
  static final List<ScreenEntry> entries = [
    // A — Direct Answer
    _budgetOverview,
    _cantonalBenchmark,
    // B — Decision Canvas
    _renteVsCapital,
    _retraite,
    _preretraiteComplete,
    _pilier3a,
    _staggeredWithdrawal,
    _fiscal,
    _rachatLpp,
    _lppDeepRachat,
    _epl,
    _affordability,
    _invalidite,
    _jobComparison,
    _lamalFranchise,
    _decaissement,
    _amortization,
    _saronVsFixed,
    _eplCombined,
    _dividendeVsSalaire,
    _providerComparator,
    _realReturn,
    _retroactif3a,
    _locationVsPropriete,
    _succession,
    _librePassage,
    _allocationAnnuelle,
    _coverageCheck,
    _genderGap,
    _disabilitySelfEmployed,
    _avsCotisations,
    _ijm,
    _pillar3aIndep,
    _lppVolontaire,
    _simulatorCompound,
    _simulatorLeasing,
    _simulatorCredit,
    _debtRatio,
    _debtRepayment,
    _debtRiskCheck,
    _debtHelp,
    _financialReport,
    _timeline,
    _arbitrageBilan,
    _cockpit,
    _imputedRental,
    // C — Roadmap Flow
    _divorce,
    _naissance,
    _mariage,
    _concubinage,
    _unemployment,
    _firstJob,
    _housingSale,
    _donation,
    _decesProche,
    _expat,
    _frontalier,
    _independant,
    _demenagementCantonal,
    _disabilityInsurance,
    // D — Capture / Utility
    _documentScan,
    _documents,
    _profile,
    _avsGuide,
    _household,
    _openBankingHub,
    _consent,
    _byokSettings,
    _slmSettings,
    _scanReview,
    _scanImpact,
    _documentDetail,
    _coupleAccept,
    _dataBlock,
    _bankImport,
    _openBankingTransactions,
    _openBankingConsents,
    _adminObservability,
    _adminAnalytics,
    _coachRefresh,
    _onboardingQuick,
    _onboardingPremierEclairage,
    // E — Conversation pure / non-routable
    _landing,
    _coachChat,
    _achievements,
    _home,
    _authLogin,
    _authRegister,
    _authForgotPassword,
    _authVerifyEmail,
    _exploreRetraite,
    _exploreFamille,
    _exploreTravail,
    _exploreLogement,
    _exploreFiscalite,
    _explorePatrimoine,
    _exploreSante,
    _coachCheckin,
    _coachHistory,
    _educationHub,
    _educationTheme,
    _scoreReveal,
    _askMint,
    // B — Decision Canvas (additional)
    _portfolio,
    // S52 — Surface deduplication
    _financialSummary,
    _confidenceDashboard,
    // S65 — Expert Tier
    _consultSpecialist,
    // S68 — Agent Autonome
    _prepareTaxForm,
    _prepareAvsLetter,
    _prepareLppTransfer,
  ];

  // ════════════════════════════════════════════════════════════════
  //  INSTANCE METHODS (satisfy abstract ScreenRegistry contract)
  // ════════════════════════════════════════════════════════════════

  @override
  ScreenEntry? findByIntent(String intentTag) =>
      MintScreenRegistry.findByIntentStatic(intentTag);

  @override
  ScreenEntry? findByRoute(String route) =>
      MintScreenRegistry.findByRouteStatic(route);

  @override
  List<ScreenEntry> get all => entries;

  // ════════════════════════════════════════════════════════════════
  //  STATIC CONVENIENCE API
  // ════════════════════════════════════════════════════════════════

  /// Returns the [ScreenEntry] with [intentTag], or null.
  static ScreenEntry? findByIntentStatic(String intentTag) {
    for (final e in entries) {
      if (e.intentTag == intentTag) return e;
    }
    return null;
  }

  /// Returns the [ScreenEntry] with canonical [route], or null.
  static ScreenEntry? findByRouteStatic(String route) {
    for (final e in entries) {
      if (e.route == route) return e;
    }
    return null;
  }

  /// Returns all entries with the given [behavior].
  static List<ScreenEntry> findByBehavior(ScreenBehavior behavior) =>
      entries.where((e) => e.behavior == behavior).toList();

  /// Returns all entries where [preferFromChat] is true.
  /// These are the surfaces the Coach AI is allowed to open directly.
  static List<ScreenEntry> chatRoutable() =>
      entries.where((e) => e.preferFromChat).toList();
}
