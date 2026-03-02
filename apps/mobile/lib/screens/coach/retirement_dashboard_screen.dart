import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/dashboard_curator_service.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/monte_carlo_models.dart';
import 'package:mint_mobile/services/financial_core/monte_carlo_service.dart';
import 'package:mint_mobile/services/financial_core/tornado_sensitivity_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';
import 'package:mint_mobile/services/reengagement_engine.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/services/temporal_priority_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/coach/coach_briefing_card.dart';
import 'package:mint_mobile/widgets/coach/confidence_bar.dart';
import 'package:mint_mobile/widgets/coach/data_quality_card.dart';
import 'package:mint_mobile/widgets/coach/early_retirement_comparison.dart';
import 'package:mint_mobile/widgets/coach/explore_hub.dart';
import 'package:mint_mobile/widgets/coach/hero_retirement_card.dart';
import 'package:mint_mobile/widgets/coach/impact_mint_card.dart';
import 'package:mint_mobile/widgets/coach/low_confidence_card.dart';
import 'package:mint_mobile/widgets/coach/mint_score_gauge.dart';
import 'package:mint_mobile/widgets/coach/pillar_decomposition.dart';
import 'package:mint_mobile/widgets/coach/monte_carlo_toggle_section.dart';
import 'package:mint_mobile/widgets/coach/sensitivity_snippet.dart';
import 'package:mint_mobile/widgets/coach/temporal_strip.dart';
import 'package:mint_mobile/widgets/coach/trajectory_card.dart';
import 'package:mint_mobile/widgets/dashboard/arbitrage_teaser_card.dart';
import 'package:mint_mobile/widgets/dashboard/budget_gap_card.dart';
import 'package:mint_mobile/widgets/coach/hero_couple_card.dart';
import 'package:mint_mobile/widgets/dashboard/couple_action_plan.dart';
import 'package:mint_mobile/widgets/dashboard/couple_phase_timeline.dart';
import 'package:mint_mobile/widgets/dashboard/document_scan_cta.dart';
import 'package:mint_mobile/widgets/dashboard/replacement_ratio_badge.dart';
import 'package:mint_mobile/widgets/dashboard/retirement_checklist_card.dart';

// ────────────────────────────────────────────────────────────
//  RETIREMENT DASHBOARD SCREEN — P3 / Coach IA Vivante
// ────────────────────────────────────────────────────────────
//
//  Orchestrateur du tableau de bord retraite a 3 etats.
//  Le dashboard PARLE — CoachNarrativeService genere le briefing,
//  DashboardCuratorService selectionne les cartes (max 3-4),
//  TemporalStrip affiche les echeances urgentes.
//
//  STATE A (confiance >= 70%) — Cockpit complet + briefing coach
//  STATE B (confiance 40-69%) — Projection partielle + enrichissement
//  STATE C (confiance < 40%)  — Educatif + greeting
//
//  Fallback chain: SLM → Templates → BYOK (privacy-first).
//  Si narration indisponible, le dashboard reste fonctionnel.
//
//  Aucun terme banni (garanti, certain, optimal, meilleur…).
// ────────────────────────────────────────────────────────────

class RetirementDashboardScreen extends StatefulWidget {
  const RetirementDashboardScreen({super.key});

  @override
  State<RetirementDashboardScreen> createState() =>
      _RetirementDashboardScreenState();
}

class _RetirementDashboardScreenState extends State<RetirementDashboardScreen> {
  // ── Core state ──────────────────────────────────────────
  CoachProfile? _profile;
  FinancialFitnessScore? _score;
  ProjectionResult? _projection;
  ProjectionResult? _baselineProjection;
  RetirementProjectionResult? _retirementProjection;
  double _confidenceScore = 0;
  ProjectionConfidence? _confidence;

  // ── Coach narrative state (P3) ──────────────────────────
  CoachNarrative? _narrative;
  int _narrativeGeneration = 0;
  List<CuratedCard> _curatedCards = const [];
  List<TemporalItem> _temporalItems = const [];

  // ── P4: Monte Carlo + Tornado state ─────────────────────
  MonteCarloResult? _monteCarloResult;
  List<TornadoVariable> _tornadoVariables = const [];

  // ── Cockpit expand state (P3: 3-4 cards gate) ──────────
  bool _cockpitExpanded = false;

  // ────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ────────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<CoachProfileProvider>();
    if (!provider.hasProfile) {
      _profile = null;
      _projection = null;
      _confidence = null;
      _confidenceScore = 0;
      // Invalidate any in-flight narrative generation to prevent
      // stale personal content from overwriting null after profile loss.
      _narrativeGeneration++;
      _narrative = null;
      _curatedCards = const [];
      _temporalItems = const [];
      _monteCarloResult = null;
      _tornadoVariables = const [];
      return;
    }

    final newProfile = provider.profile!;
    if (identical(_profile, newProfile)) return;

    _profile = newProfile;
    try {
      _score = FinancialFitnessService.calculate(
        profile: _profile!,
        previousScore: provider.previousScore,
      );
      _projection = ForecasterService.project(profile: _profile!);
      _confidence = ConfidenceScorer.score(_profile!);
      _confidenceScore = _confidence!.score;

      // Detailed retirement projection (budget gap, phases, etc.)
      _retirementProjection =
          RetirementProjectionService.project(profile: _profile!);

      // Baseline sans contributions pour calcul delta MINT
      if (_profile!.plannedContributions.isNotEmpty) {
        final profileSans = _profile!.copyWithContributions(const []);
        _baselineProjection = ForecasterService.project(profile: profileSans);
      } else {
        _baselineProjection = null;
      }

      // ── P3: Compute tips once, share across curation + narrative ──
      final tips = _buildCoachingTips(_profile!);

      // ── P3: Curate cards + temporal items ──────────────
      _curateDashboardContent(tips);

      // ── P4: Monte Carlo + Tornado (State A only, conf >= 70%) ──
      _computeMonteCarloAndTornado(_profile!);

      // ── P3: Generate narrative (async, non-blocking) ───
      unawaited(_generateNarrative(tips, provider.scoreHistory));
    } catch (e) {
      debugPrint('RetirementDashboard: projection error: $e');
      _projection = null;
      _confidence = null;
      _confidenceScore = 0;
      // Invalidate in-flight narrative generation before clearing state,
      // so any pending async result is discarded on completion.
      _narrativeGeneration++;
      _narrative = null;
      _curatedCards = const [];
      _temporalItems = const [];
      _monteCarloResult = null;
      _tornadoVariables = const [];
    }
  }

  // ────────────────────────────────────────────────────────────
  //  P3: NARRATIVE GENERATION
  // ────────────────────────────────────────────────────────────

  Future<void> _generateNarrative(
    List<CoachingTip> tips,
    List<Map<String, dynamic>>? scoreHistory,
  ) async {
    final gen = ++_narrativeGeneration;
    final profile = _profile;
    if (profile == null) {
      if (mounted) setState(() => _narrative = null);
      return;
    }

    try {
      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
        byokConfig: null,
      );

      // Only update if this is still the latest generation
      if (mounted && gen == _narrativeGeneration) {
        setState(() => _narrative = narrative);
      }
    } catch (e) {
      debugPrint('RetirementDashboard: narrative error: $e');
      if (mounted && gen == _narrativeGeneration) {
        setState(() => _narrative = null);
      }
    }
  }

  /// Build coaching tips from profile for narrative context.
  List<CoachingTip> _buildCoachingTips(CoachProfile profile) {
    try {
      return CoachingService.generateTips(
        profile: profile.toCoachingProfile(),
      );
    } catch (e) {
      debugPrint('RetirementDashboard: tips error: $e');
      return [];
    }
  }

  // ────────────────────────────────────────────────────────────
  //  P3: DASHBOARD CONTENT CURATION
  // ────────────────────────────────────────────────────────────

  void _curateDashboardContent(List<CoachingTip> tips) {
    final profile = _profile;
    if (profile == null) return;
    final planStatus = PlanTrackingService.evaluate(profile: profile);

    // Reengagement messages
    final taxSaving3a = profile.salaireBrutMensuel > 0
        ? 7258.0 * _estimateMarginalRate(profile)
        : 0.0;
    final friScore = _score?.global.toDouble() ?? 0.0;

    final friDelta = (_score?.deltaVsPreviousMonth ?? 0).toDouble();
    final reengagementMessages = ReengagementEngine.generateMessages(
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      taxSaving3a: taxSaving3a,
      friTotal: friScore,
      friDelta: friDelta,
    );

    // Curate cards (max 3-4)
    _curatedCards = DashboardCuratorService.curate(
      tips: tips,
      reengagementMessages: reengagementMessages,
    );

    // Temporal items
    _temporalItems = TemporalPriorityService.prioritize(
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      taxSaving3a: taxSaving3a,
      friTotal: friScore,
      friDelta: friDelta,
      planStatus: planStatus,
    );
  }

  // ────────────────────────────────────────────────────────────
  //  P4: MONTE CARLO + TORNADO COMPUTATION
  // ────────────────────────────────────────────────────────────

  void _computeMonteCarloAndTornado(CoachProfile profile) {
    // Only compute for State A (confidence >= 70%)
    if (_confidenceScore < 70) {
      _monteCarloResult = null;
      _tornadoVariables = const [];
      return;
    }

    try {
      _monteCarloResult = MonteCarloProjectionService.simulate(
        profile: profile,
        retirementAgeUser: profile.effectiveRetirementAge,
      );
    } catch (e) {
      debugPrint('RetirementDashboard: Monte Carlo error: $e');
      _monteCarloResult = null;
    }

    try {
      _tornadoVariables = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: profile.effectiveRetirementAge,
      );
    } catch (e) {
      debugPrint('RetirementDashboard: Tornado error: $e');
      _tornadoVariables = const [];
    }
  }

  double _estimateMarginalRate(CoachProfile profile) {
    // Simplified marginal rate estimation (full version in FiscalService)
    final gross = profile.salaireBrutMensuel * 12;
    if (gross <= 0) return 0.25;
    if (gross < 50000) return 0.15;
    if (gross < 100000) return 0.25;
    if (gross < 150000) return 0.32;
    return 0.38;
  }

  // ────────────────────────────────────────────────────────────
  //  P5: COUPLE HERO CARD — reads per-partner AVS from
  //  ForecasterService decomposition (single source of truth)
  // ────────────────────────────────────────────────────────────

  Widget _buildCoupleHeroCard(
    CoachProfile profile,
    Map<String, double> decoBase,
    ProjectionResult proj,
  ) {
    final conj = profile.conjoint!;

    // Per-partner AVS directly from ForecasterService decomposition
    // (avs_user / avs_conjoint are annual values, already couple-capped).
    final avsUserMonthly = (decoBase['avs_user'] ?? 0) / 12;
    final avsConjMonthly = (decoBase['avs_conjoint'] ?? 0) / 12;

    // 3a + libre are household totals from ForecasterService.
    // Attribute to user column (conjoint 3a handled separately in
    // CoupleActionPlan). This is consistent with the forecaster
    // model where 3a withdrawal is modelled as user's income.
    return HeroCoupleCard(
      userName: profile.firstName ?? 'Toi',
      conjointName: conj.firstName ?? 'Conjoint\u00b7e',
      userMonthlyIncome: avsUserMonthly +
          (decoBase['lpp_user'] ?? 0) / 12 +
          (decoBase['3a'] ?? 0) / 12 +
          (decoBase['libre'] ?? 0) / 12,
      conjointMonthlyIncome:
          avsConjMonthly + (decoBase['lpp_conjoint'] ?? 0) / 12,
      userReplacementRatio: proj.tauxRemplacementBase,
      conjointReplacementRatio: null,
      userRetirementAge: profile.effectiveRetirementAge,
      conjointRetirementAge: conj.effectiveRetirementAge,
    );
  }

  // ────────────────────────────────────────────────────────────
  //  BUILD — DISPATCH SELON L'ETAT
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CoachProfileProvider>();

    if (!provider.hasProfile || _projection == null) {
      return _buildStateC();
    }

    if (_confidenceScore >= 70 && _score != null) {
      return _buildStateA();
    }
    if (_confidenceScore >= 40 && _score != null) {
      return _buildStateB();
    }
    return _buildStateC();
  }

  // ────────────────────────────────────────────────────────────
  //  STATE A — Profil riche (>= 70% confiance)
  // ────────────────────────────────────────────────────────────

  Widget _buildStateA() {
    final proj = _projection!;
    final profile = _profile!;
    final score = _score!;
    final retProj = _retirementProjection;

    // Revenu mensuel base scenario
    final monthlyIncome = proj.base.revenuAnnuelRetraite / 12;
    final monthlyPrudent = proj.prudent.revenuAnnuelRetraite / 12;
    final monthlyOptimiste = proj.optimiste.revenuAnnuelRetraite / 12;

    // Decomposition par pilier (scenario base)
    final decoBase = proj.base.decomposition;
    final avsMonthly = ((decoBase['avs'] ?? 0)) / 12;
    final lppMonthly =
        (((decoBase['lpp_user'] ?? 0) + (decoBase['lpp_conjoint'] ?? 0))) / 12;
    final threeAMonthly = ((decoBase['3a'] ?? 0)) / 12;
    final freeMonthly = ((decoBase['libre'] ?? 0)) / 12;

    // ImpactMintCard
    final baselineMonthly = _baselineProjection != null
        ? _baselineProjection!.base.revenuAnnuelRetraite / 12
        : monthlyIncome;
    final impactDescription = _buildImpactDescription();

    // Couple phase data
    final isCouple = profile.isCouple && profile.conjoint?.birthYear != null;
    final hasPhases = retProj != null && retProj.phases.length >= 2;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(profile.firstName),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── P3: Coach Briefing Card ──────────────
                CoachBriefingCard(
                  narrative: _narrative,
                  topCard:
                      _curatedCards.isNotEmpty ? _curatedCards.first : null,
                  confidenceScore: _confidenceScore,
                  isLlmGenerated: _narrative?.isLlmGenerated ?? false,
                  onEnrich: () => context.push('/onboarding/smart'),
                ),
                const SizedBox(height: 16),

                // ── P3: Temporal Strip ───────────────────
                if (_temporalItems.isNotEmpty) ...[
                  TemporalStrip(items: _temporalItems),
                  const SizedBox(height: 16),
                ],

                // ── P3: Curated action cards ───────────────
                ..._buildCuratedCards(),

                ConfidenceBar(score: _confidenceScore),
                const SizedBox(height: 16),

                // ── P5: Couple hero card OR single hero ──
                if (isCouple) ...[
                  _buildCoupleHeroCard(profile, decoBase, proj),
                ] else ...[
                  HeroRetirementCard(
                    mode: HeroCardMode.full,
                    monthlyIncome: monthlyIncome,
                    replacementRatio: proj.tauxRemplacementBase,
                    rangeMin: monthlyPrudent,
                    rangeMax: monthlyOptimiste,
                  ),
                ],
                const SizedBox(height: 16),

                // ── Cockpit d\u00e9taill\u00e9 (collapsed by default) ──
                _buildCockpitToggle(),
                if (_cockpitExpanded) ...[
                  const SizedBox(height: 12),

                  ReplacementRatioBadge(
                    ratio: proj.tauxRemplacementBase,
                  ),
                  const SizedBox(height: 16),

                  if (retProj != null) ...[
                    BudgetGapCard(budgetGap: retProj.budgetGap),
                    const SizedBox(height: 16),
                  ],

                  // ── P4: Toggle 3-Scenarios / Monte Carlo ──
                  MonteCarloToggleSection(
                    monteCarloResult: _monteCarloResult,
                    currentMonthlyIncome: profile.salaireBrutMensuel * 0.87,
                    monteCarloAvailable: _monteCarloResult != null,
                    scenariosChild: TrajectoryCard(
                      profile: profile,
                      projection: proj,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── P4: Sensitivity Snippet (top 3) ────────
                  if (_tornadoVariables.isNotEmpty)
                    SensitivitySnippet(
                      variables: _tornadoVariables,
                    ),
                  if (_tornadoVariables.isNotEmpty) const SizedBox(height: 16),

                  PillarDecomposition(
                    avsMonthly: avsMonthly,
                    lppMonthly: lppMonthly,
                    threeAMonthly: threeAMonthly,
                    freeMonthly: freeMonthly,
                  ),
                  const SizedBox(height: 16),

                  if (profile.age >= 45) ...[
                    ArbitrageTeaserSection(profile: profile),
                    const SizedBox(height: 16),
                  ],

                  if (isCouple && hasPhases) ...[
                    CouplePhaseTimeline(
                      userName: profile.firstName ?? 'Toi',
                      conjointName:
                          profile.conjoint!.firstName ?? 'Conjoint\u00b7e',
                      userRetirementYear:
                          profile.birthYear + profile.effectiveRetirementAge,
                      conjointRetirementYear: profile.conjoint!.birthYear! +
                          profile.conjoint!.effectiveRetirementAge,
                      phases: retProj.phases,
                      profile: profile,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── P5: Couple Action Plan ────────────────
                  if (isCouple) CoupleActionPlan(profile: profile),
                  if (isCouple) const SizedBox(height: 16),

                  RetirementChecklistCard(profile: profile),
                  const SizedBox(height: 16),

                  ImpactMintCard(
                    withoutOptimization: baselineMonthly,
                    withOptimization: monthlyIncome,
                    description: impactDescription,
                  ),
                  if (profile.age >= 45) ...[
                    const SizedBox(height: 16),
                    EarlyRetirementComparison(profile: profile),
                  ],
                  const SizedBox(height: 16),

                  MintScoreGauge(
                    score: score.global,
                    budgetScore: score.budget.score,
                    prevoyanceScore: score.prevoyance.score,
                    patrimoineScore: score.patrimoine.score,
                    trend: score.trend.name,
                    previousScore: score.deltaVsPreviousMonth != null
                        ? score.global - (score.deltaVsPreviousMonth ?? 0)
                        : null,
                    onTap: null,
                  ),
                  const SizedBox(height: 16),
                ],

                const ExploreHub(),
                const SizedBox(height: 24),
                _buildDisclaimer(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  STATE B — Profil partiel (40-69% confiance)
  // ────────────────────────────────────────────────────────────

  Widget _buildStateB() {
    final proj = _projection!;
    final profile = _profile!;
    final score = _score!;

    final monthlyPrudent = proj.prudent.revenuAnnuelRetraite / 12;
    final monthlyOptimiste = proj.optimiste.revenuAnnuelRetraite / 12;

    final knownFields = _buildKnownFields(profile);
    final missingFields = _buildMissingFields();
    final totalImpact =
        _confidence?.prompts.take(3).fold<int>(0, (sum, p) => sum + p.impact) ??
            0;

    // Estimate confidence improvement from LPP scan
    final hasLppData = (profile.prevoyance.avoirLppTotal ?? 0) > 0;
    final estimatedAfterScan = hasLppData
        ? (_confidenceScore + 10).clamp(0.0, 95.0)
        : (_confidenceScore + 20).clamp(0.0, 95.0);

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(profile.firstName),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── P3: Coach Briefing Card ──────────────
                CoachBriefingCard(
                  narrative: _narrative,
                  topCard:
                      _curatedCards.isNotEmpty ? _curatedCards.first : null,
                  confidenceScore: _confidenceScore,
                  isLlmGenerated: _narrative?.isLlmGenerated ?? false,
                  onEnrich: () => context.push('/onboarding/smart'),
                ),
                const SizedBox(height: 16),

                // ── P3: Temporal Strip ───────────────────
                if (_temporalItems.isNotEmpty) ...[
                  TemporalStrip(items: _temporalItems),
                  const SizedBox(height: 16),
                ],

                // ── P3: Curated action cards ───────────────
                ..._buildCuratedCards(),

                ConfidenceBar(score: _confidenceScore),
                const SizedBox(height: 16),
                HeroRetirementCard(
                  mode: HeroCardMode.range,
                  rangeMin: monthlyPrudent,
                  rangeMax: monthlyOptimiste,
                ),
                const SizedBox(height: 16),

                // Document Scan CTA (prominent in State B)
                DocumentScanCta(
                  currentConfidence: _confidenceScore,
                  estimatedConfidenceAfterScan: estimatedAfterScan,
                ),
                const SizedBox(height: 16),

                // ── P4: Monte Carlo Teaser (State B, non personnalisé) ──
                MonteCarloTeaser(
                  onEnrich: () => context.push('/onboarding/smart'),
                  missingCategories: _confidence?.prompts
                          .map((p) => p.category)
                          .where((c) => const {
                                'lpp',
                                'avs',
                                '3a',
                                'patrimoine',
                                'logement',
                                'foreign_pension',
                                'depenses',
                              }.contains(c))
                          .toSet()
                          .take(3)
                          .toList() ??
                      const [],
                ),
                const SizedBox(height: 16),

                // ── Cockpit d\u00e9taill\u00e9 (collapsed by default) ──
                _buildCockpitToggle(),
                if (_cockpitExpanded) ...[
                  const SizedBox(height: 12),
                  DataQualityCard(
                    knownFields: knownFields,
                    missingFields: missingFields,
                    enrichImpact: totalImpact > 0
                        ? '+$totalImpact% pr\u00e9cision'
                        : null,
                    onEnrich: () => context.push('/onboarding/smart'),
                  ),
                  const SizedBox(height: 16),
                  LowConfidenceCard(profile: profile),
                  const SizedBox(height: 16),
                  MintScoreGauge(
                    score: score.global,
                    budgetScore: score.budget.score,
                    prevoyanceScore: score.prevoyance.score,
                    patrimoineScore: score.patrimoine.score,
                    trend: score.trend.name,
                    previousScore: score.deltaVsPreviousMonth != null
                        ? score.global - (score.deltaVsPreviousMonth ?? 0)
                        : null,
                    onTap: null,
                  ),
                  const SizedBox(height: 16),
                ],

                const ExploreHub(),
                const SizedBox(height: 24),
                _buildDisclaimer(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  STATE C — Donnees insuffisantes / pas de profil (< 40%)
  // ────────────────────────────────────────────────────────────

  Widget _buildStateC() {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(null),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── P3: Coach Briefing Card (State C) ──
                CoachBriefingCard(
                  narrative: _narrative,
                  confidenceScore: _confidenceScore,
                  onEnrich: () => context.push('/onboarding/smart'),
                ),
                const SizedBox(height: 16),

                HeroRetirementCard(
                  mode: HeroCardMode.educational,
                  onCompleteProfil: () => context.push('/onboarding/smart'),
                ),
                const SizedBox(height: 16),
                _buildEducationalSection(),
                const SizedBox(height: 16),
                const ExploreHub(),
                const SizedBox(height: 24),
                _buildDisclaimer(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  APPBAR
  // ────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(String? firstName) {
    // Use narrative greeting for AppBar title when available
    final greeting = _narrative?.greeting ??
        (firstName != null && firstName.isNotEmpty
            ? 'Retraite \u00b7 $firstName'
            : 'Ma retraite');

    return SliverAppBar(
      expandedHeight: 80,
      floating: true,
      snap: true,
      backgroundColor: MintColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          greeting,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 12),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined,
              color: MintColors.textSecondary),
          onPressed: () => context.push('/onboarding/smart'),
          tooltip: 'Modifier le profil',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  EDUCATIONAL SECTION (STATE C)
  // ────────────────────────────────────────────────────────────

  Widget _buildEducationalSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Le syst\u00e8me de retraite suisse',
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildEducationalPoint(
            icon: Icons.shield_outlined,
            color: MintColors.retirementAvs,
            title: '1er pilier \u2014 AVS',
            text:
                'Base obligatoire pour tous. Financ\u00e9 par tes cotisations (LAVS art. 21).',
          ),
          const SizedBox(height: 8),
          _buildEducationalPoint(
            icon: Icons.account_balance_outlined,
            color: MintColors.retirementLpp,
            title: '2\u00e8me pilier \u2014 LPP',
            text:
                'Pr\u00e9voyance professionnelle via ta caisse de pension (LPP art. 14).',
          ),
          const SizedBox(height: 8),
          _buildEducationalPoint(
            icon: Icons.savings_outlined,
            color: MintColors.retirement3a,
            title: '3\u00e8me pilier \u2014 3a',
            text:
                '\u00c9pargne volontaire avec d\u00e9duction fiscale (OPP3 art. 7).',
          ),
        ],
      ),
    );
  }

  Widget _buildEducationalPoint({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  DISCLAIMER
  // ────────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Text(
      'Outil \u00e9ducatif simplifi\u00e9. Ne constitue pas un conseil financier (LSFin). '
      'Sources\u00a0: LAVS art. 21-29, LPP art. 14, OPP3 art. 7.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textMuted,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  HELPERS
  // ────────────────────────────────────────────────────────────

  /// Description de l'impact MINT (bases sur les contributions planifiees).
  String _buildImpactDescription() {
    final profile = _profile;
    if (profile == null)
      return 'gr\u00e2ce \u00e0 tes actions de pr\u00e9voyance';

    final has3a = profile.total3aMensuel > 0;
    final hasLpp = profile.totalLppBuybackMensuel > 0;

    if (has3a && hasLpp) {
      return 'gr\u00e2ce au 3e pilier et au rachat LPP';
    } else if (has3a) {
      return 'gr\u00e2ce au 3e pilier';
    } else if (hasLpp) {
      return 'gr\u00e2ce au rachat LPP';
    }
    return 'gr\u00e2ce \u00e0 tes contributions planifi\u00e9es';
  }

  /// Champs connus du profil pour DataQualityCard.
  List<String> _buildKnownFields(CoachProfile profile) {
    final fields = <String>[];

    if (profile.salaireBrutMensuel > 0) {
      fields.add(
          'Salaire\u00a0: CHF\u00a0${formatChf(profile.salaireBrutMensuel)}/mois');
    }
    if (profile.canton.isNotEmpty) {
      fields.add('Canton\u00a0: ${profile.canton}');
    }
    if (profile.age > 0) {
      fields.add('Age\u00a0: ${profile.age} ans');
    }
    if ((profile.prevoyance.avoirLppTotal ?? 0) > 0) {
      fields.add(
          'LPP\u00a0: CHF\u00a0${formatChf(profile.prevoyance.avoirLppTotal!)}');
    }
    if (profile.prevoyance.totalEpargne3a > 0) {
      fields.add(
          '3e pilier\u00a0: CHF\u00a0${formatChf(profile.prevoyance.totalEpargne3a)}');
    }

    return fields;
  }

  /// Champs manquants a partir des prompts de confiance.
  List<String> _buildMissingFields() {
    if (_confidence == null) return [];
    return _confidence!.prompts.take(4).map((p) => p.label).toList();
  }

  // ────────────────────────────────────────────────────────────
  //  P3: COCKPIT EXPAND TOGGLE
  // ────────────────────────────────────────────────────────────

  Widget _buildCockpitToggle() {
    return GestureDetector(
      onTap: () => setState(() => _cockpitExpanded = !_cockpitExpanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MintColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _cockpitExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 18,
              color: MintColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              _cockpitExpanded
                  ? 'Masquer le cockpit d\u00e9taill\u00e9'
                  : 'Voir le cockpit d\u00e9taill\u00e9',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  P3: CURATED ACTION CARDS
  // ────────────────────────────────────────────────────────────

  /// Build individual curated action cards (skip first — shown in briefing).
  ///
  /// Shows remaining coaching tips and reengagement messages as compact
  /// action cards. Max 3 additional cards (topCard is in briefing = 4 total).
  List<Widget> _buildCuratedCards() {
    if (_curatedCards.length <= 1) return [];

    final remaining = _curatedCards.skip(1).take(3);
    final widgets = <Widget>[];

    for (final card in remaining) {
      final urgencyColor = switch (card.urgency) {
        AlertUrgency.urgent => MintColors.error,
        AlertUrgency.active => MintColors.warning,
        AlertUrgency.info => MintColors.primary,
      };
      final urgencyIcon = switch (card.urgency) {
        AlertUrgency.urgent => Icons.warning_amber_rounded,
        AlertUrgency.active => Icons.trending_up,
        AlertUrgency.info => Icons.lightbulb_outline,
      };

      widgets.add(
        GestureDetector(
          onTap:
              card.deeplink != null ? () => context.push(card.deeplink!) : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: urgencyColor.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(urgencyIcon, size: 14, color: urgencyColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              card.title,
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: MintColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (card.deadlineDays != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: urgencyColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                DashboardCuratorService.computeDeadlineText(
                                        card.source is CoachingTip
                                            ? card.source as CoachingTip
                                            : null) ??
                                    'J-${card.deadlineDays}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: urgencyColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.message,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (card.impactChf != null && card.impactChf! > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Impact estim\u00e9\u00a0: CHF\u00a0${formatChf(card.impactChf!)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: MintColors.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (card.deeplink != null)
                  Icon(Icons.chevron_right,
                      size: 18, color: MintColors.textMuted),
              ],
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }

    return widgets;
  }
}
