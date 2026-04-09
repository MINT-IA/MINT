import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/fri_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/financial_core/monte_carlo_models.dart';
import 'package:mint_mobile/services/financial_core/monte_carlo_service.dart';
import 'package:mint_mobile/services/financial_core/tornado_sensitivity_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/dashboard_projection_snapshot.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/services/fri_computation_service.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';
import 'package:mint_mobile/theme/colors.dart';

import 'package:mint_mobile/widgets/coach/confidence_blocks_bar.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';
import 'package:mint_mobile/widgets/coach/early_retirement_comparison.dart';
import 'package:mint_mobile/widgets/coach/impact_mint_card.dart';
import 'package:mint_mobile/widgets/coach/mint_score_gauge.dart';
import 'package:mint_mobile/widgets/coach/pillar_decomposition.dart';
import 'package:mint_mobile/widgets/coach/monte_carlo_toggle_section.dart';
import 'package:mint_mobile/widgets/coach/sensitivity_snippet.dart';
import 'package:mint_mobile/widgets/coach/trajectory_card.dart';
import 'package:mint_mobile/widgets/coach/fri_radar_chart.dart';
import 'package:mint_mobile/widgets/coach/trajectory_comparison_card.dart';
import 'package:mint_mobile/widgets/coach/plan_reality_card.dart';
import 'package:mint_mobile/widgets/dashboard/arbitrage_teaser_card.dart';
import 'package:mint_mobile/widgets/dashboard/budget_gap_card.dart';
import 'package:mint_mobile/widgets/dashboard/couple_action_plan.dart';
import 'package:mint_mobile/widgets/dashboard/couple_phase_timeline.dart';
import 'package:mint_mobile/widgets/dashboard/replacement_ratio_badge.dart';
import 'package:mint_mobile/widgets/dashboard/retirement_checklist_card.dart';

// ────────────────────────────────────────────────────────────
//  COCKPIT DETAIL SCREEN
// ────────────────────────────────────────────────────────────
//
//  Ecran de detail du cockpit retraite. Affiche tous les
//  widgets avances qui etaient caches derriere le toggle
//  "Voir le cockpit detaille" sur le dashboard principal.
//
//  Lit le CoachProfile depuis Provider et recalcule toutes
//  les données nécessaires (projection, confidence, FRI,
//  Monte Carlo, etc.) exactement comme le dashboard.
//
//  Accessible via un lien depuis le tableau de bord simplifie.
//
//  Aucun terme banni (garanti, certain, optimal, meilleur...).
// ────────────────────────────────────────────────────────────

class CockpitDetailScreen extends StatefulWidget {
  const CockpitDetailScreen({super.key});

  @override
  State<CockpitDetailScreen> createState() => _CockpitDetailScreenState();
}

class _CockpitDetailScreenState extends State<CockpitDetailScreen> {
  // ── Core state ──────────────────────────────────────────
  CoachProfile? _profile;
  FinancialFitnessScore? _score;
  ProjectionResult? _projection;
  ProjectionResult? _baselineProjection;
  RetirementProjectionResult? _retirementProjection;
  double _confidenceScore = 0;
  ProjectionConfidence? _confidence;
  EnhancedConfidence? _enhancedConfidence;
  Map<String, BlockScore> _confidenceBlocs = const {};
  DashboardProjectionSnapshot? _snapshot;

  // ── Monte Carlo + Tornado state ─────────────────────────
  MonteCarloResult? _monteCarloResult;
  List<TornadoVariable> _tornadoVariables = const [];

  // ── FRI + Plan tracking state ───────────────────────────
  ProjectionResult? _initialProjection;
  PlanStatus? _planStatus;
  double _compoundImpact = 0;
  FriBreakdown? _friBreakdown;

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
      _enhancedConfidence = null;
      _confidenceScore = 0;
      _confidenceBlocs = const {};
      _monteCarloResult = null;
      _tornadoVariables = const [];
      _snapshot = null;
      _friBreakdown = null;
      _planStatus = null;
      return;
    }

    final newProfile = provider.profile!;
    if (_profile != null && _profile == newProfile) return;

    _profile = newProfile;
    try {
      _score = FinancialFitnessService.calculate(
        profile: _profile!,
        previousScore: provider.previousScore,
      );
      _projection = ForecasterService.project(profile: _profile!);
      _snapshot = DashboardProjectionSnapshot.fromProjection(
        projection: _projection!,
        profile: _profile!,
      );
      _confidence = ConfidenceScorer.score(_profile!);
      _confidenceScore = _confidence!.score;
      _enhancedConfidence = ConfidenceScorer.scoreEnhanced(_profile!);
      _confidenceBlocs = ConfidenceScorer.scoreAsBlocs(_profile!);

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

      // Monte Carlo + Tornado (State A only, confidence >= 70%) — async
      _computeMonteCarloAndTornado(_profile!).then((_) {
        if (mounted) setState(() {});
      });

      // FRI + Plan tracking
      _computeFri(_profile!);
      _computePlanTracking(_profile!);
      _loadInitialSnapshot(_profile!);
    } catch (e) {
      debugPrint('CockpitDetail: projection error: $e');
      _projection = null;
      _snapshot = null;
      _confidence = null;
      _enhancedConfidence = null;
      _confidenceScore = 0;
      _confidenceBlocs = const {};
      _monteCarloResult = null;
      _tornadoVariables = const [];
      _friBreakdown = null;
      _planStatus = null;
    }
  }

  // ────────────────────────────────────────────────────────────
  //  MONTE CARLO + TORNADO COMPUTATION
  // ────────────────────────────────────────────────────────────

  Future<void> _computeMonteCarloAndTornado(CoachProfile profile) async {
    // Only compute for confidence >= 70%
    if (_confidenceScore < 70) {
      _monteCarloResult = null;
      _tornadoVariables = const [];
      return;
    }

    try {
      _monteCarloResult = await MonteCarloProjectionService.simulate(
        profile: profile,
        retirementAgeUser: profile.effectiveRetirementAge,
      );
    } catch (e) {
      debugPrint('CockpitDetail: Monte Carlo error: $e');
      _monteCarloResult = null;
    }

    try {
      _tornadoVariables = TornadoSensitivityService.compute(
        profile: profile,
        retirementAgeUser: profile.effectiveRetirementAge,
      );
    } catch (e) {
      debugPrint('CockpitDetail: Tornado error: $e');
      _tornadoVariables = const [];
    }
  }

  // ────────────────────────────────────────────────────────────
  //  FRI + PLAN TRACKING
  // ────────────────────────────────────────────────────────────

  void _computeFri(CoachProfile profile) {
    if (_projection == null) {
      _friBreakdown = null;
      return;
    }
    try {
      _friBreakdown = FriComputationService.compute(
        profile: profile,
        projection: _projection!,
        confidenceScore: _confidenceScore,
      );
    } catch (e) {
      debugPrint('CockpitDetail: FRI computation error: $e');
      _friBreakdown = null;
    }
  }

  void _computePlanTracking(CoachProfile profile) {
    try {
      _planStatus = PlanTrackingService.evaluate(
        checkIns: profile.checkIns,
        contributions: profile.plannedContributions,
      );

      final monthsToRetirement = profile.anneesAvantRetraite * 12;
      _compoundImpact = PlanTrackingService.compoundProjectedImpact(
        status: _planStatus!,
        monthsToRetirement: monthsToRetirement,
      );
    } catch (e) {
      debugPrint('CockpitDetail: PlanTracking error: $e');
      _planStatus = null;
      _compoundImpact = 0;
    }
  }

  void _loadInitialSnapshot(CoachProfile profile) {
    if (profile.initialProjectionSnapshot != null && _projection != null) {
      try {
        _initialProjection =
            ProjectionResult.fromJson(profile.initialProjectionSnapshot!);
      } catch (e) {
        debugPrint('CockpitDetail: snapshot parse error: $e');
        _initialProjection = null;
      }
    } else {
      _initialProjection = null;
    }
  }

  // ────────────────────────────────────────────────────────────
  //  IMPACT DESCRIPTION
  // ────────────────────────────────────────────────────────────

  String _buildImpactDescription() {
    final profile = _profile;
    if (profile == null) {
      return 'gr\u00e2ce \u00e0 tes actions de pr\u00e9voyance';
    }

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

  // ────────────────────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CoachProfileProvider>();

    if (!provider.hasProfile || _projection == null || _profile == null) {
      return _buildEmptyState();
    }

    final proj = _projection!;
    final profile = _profile!;
    final retProj = _retirementProjection;

    // Revenu mensuel base scenario
    final monthlyIncome = proj.base.revenuAnnuelRetraite / 12;

    // Decomposition par pilier (scenario base)
    final decoBase = proj.base.decomposition;
    final avsUserMonthly = ((decoBase['avs_user'] ?? decoBase['avs'] ?? 0)) / 12;
    final avsConjointMonthly = ((decoBase['avs_conjoint'] ?? 0)) / 12;
    final lppUserMonthly = ((decoBase['lpp_user'] ?? 0)) / 12;
    final lppConjointMonthly = ((decoBase['lpp_conjoint'] ?? 0)) / 12;
    final threeAMonthly = ((decoBase['3a'] ?? 0)) / 12;
    final freeMonthly = ((decoBase['libre'] ?? 0)) / 12;

    // ImpactMintCard
    final baselineMonthly = _baselineProjection != null
        ? _baselineProjection!.base.revenuAnnuelRetraite / 12
        : monthlyIncome;
    final impactDescription = _buildImpactDescription();

    // Couple data
    final isCouple = profile.isCouple && profile.conjoint?.birthYear != null;
    final hasPhases = retProj != null && retProj.phases.length >= 2;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── MintTrameConfiance (detail) ─────────────
                // Plan 08a-02 Batch A: MTC replaces the legacy
                // ConfidenceBar. Standalone screen → firstAppearance.
                if (_enhancedConfidence != null) ...[
                  MintTrameConfiance.detail(
                    confidence: _enhancedConfidence!,
                    bloomStrategy: BloomStrategy.firstAppearance,
                    hypotheses: const [],
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Data-block completeness (extraction) ────
                // Sibling of MTC per AUDIT-01: this is an
                // extraction-confidence visualisation, not a
                // calculation-confidence one.
                if (_confidenceBlocs.isNotEmpty) ...[
                  DataBlockConfidenceBar(blocs: _confidenceBlocs),
                  const SizedBox(height: 16),
                ],

                // ── Replacement Ratio Badge ─────────────────
                ReplacementRatioBadge(
                  ratio: proj.tauxRemplacementBase,
                ),
                const SizedBox(height: 16),

                // ── Budget Gap Card ─────────────────────────
                if (retProj != null) ...[
                  BudgetGapCard(budgetGap: retProj.budgetGap),
                  const SizedBox(height: 16),
                ],

                // ── Monte Carlo Toggle Section ──────────────
                MonteCarloToggleSection(
                  monteCarloResult: _monteCarloResult,
                  currentMonthlyIncome:
                      _snapshot?.currentHouseholdNetMonthly ??
                          NetIncomeBreakdown.compute(
                            grossSalary: profile.salaireBrutMensuel * 12,
                            canton: profile.canton,
                            age: profile.age,
                          ).monthlyNetPayslip,
                  monteCarloAvailable: _monteCarloResult != null,
                  scenariosChild: TrajectoryCard(
                    profile: profile,
                    projection: proj,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Sensitivity Snippet (top 3 tornado) ─────
                if (_tornadoVariables.isNotEmpty) ...[
                  SensitivitySnippet(
                    variables: _tornadoVariables,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Trajectory Comparison (day-1 vs current) ─
                if (_initialProjection != null) ...[
                  TrajectoryComparisonCard(
                    initialMonthly:
                        _initialProjection!.base.revenuAnnuelRetraite / 12,
                    currentMonthly: monthlyIncome,
                    initialCapital: _initialProjection!.base.capitalFinal,
                    currentCapital: proj.base.capitalFinal,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── FRI Radar Chart ─────────────────────────
                if (_friBreakdown != null) ...[
                  FriRadarChart(
                    liquidity: _friBreakdown!.liquidite,
                    fiscal: _friBreakdown!.fiscalite,
                    retirement: _friBreakdown!.retraite,
                    structural: _friBreakdown!.risque,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Plan Reality Card ───────────────────────
                if (_planStatus != null) ...[
                  PlanRealityCard(
                    status: _planStatus!,
                    compoundImpact: _compoundImpact,
                    monthsToRetirement: profile.anneesAvantRetraite * 12,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Pillar Decomposition ────────────────────
                PillarDecomposition(
                  avsMonthly: avsUserMonthly,
                  lppMonthly: lppUserMonthly,
                  threeAMonthly: threeAMonthly,
                  freeMonthly: freeMonthly,
                  avsConjointMonthly: avsConjointMonthly,
                  lppConjointMonthly: lppConjointMonthly,
                ),
                const SizedBox(height: 16),

                // ── Arbitrage Teaser (age >= 45) ────────────
                if (profile.age >= 45) ...[
                  ArbitrageTeaserSection(profile: profile),
                  const SizedBox(height: 16),
                ],

                // ── Couple Phase Timeline ────────────────────
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

                // ── Couple Action Plan ──────────────────────
                if (isCouple) ...[
                  CoupleActionPlan(profile: profile),
                  const SizedBox(height: 16),
                ],

                // ── Retirement Checklist ────────────────────
                RetirementChecklistCard(profile: profile),
                const SizedBox(height: 16),

                // ── Impact MINT Card ────────────────────────
                ImpactMintCard(
                  withoutOptimization: baselineMonthly,
                  withOptimization: monthlyIncome,
                  description: impactDescription,
                ),

                // ── Early Retirement Comparison (age >= 45) ─
                if (profile.age >= 45) ...[
                  const SizedBox(height: 16),
                  EarlyRetirementComparison(
                    profile: profile,
                    baseThreeAMonthly: _snapshot?.threeAMonthly ?? 0,
                    baseLibreMonthly: _snapshot?.libreMonthly ?? 0,
                  ),
                ],
                const SizedBox(height: 16),

                // ── Mint Score Gauge ────────────────────────
                if (_score != null) ...[
                  MintScoreGauge(
                    score: _score!.global,
                    budgetScore: _score!.budget.score,
                    prevoyanceScore: _score!.prevoyance.score,
                    patrimoineScore: _score!.patrimoine.score,
                    trend: _score!.trend.name,
                    previousScore: _score!.deltaVsPreviousMonth != null
                        ? _score!.global - (_score!.deltaVsPreviousMonth ?? 0)
                        : null,
                    onTap: null,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Disclaimer ──────────────────────────────
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

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        S.of(context)!.cockpitDetailTitle,
        style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  EMPTY STATE (no profile / no projection)
  // ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(MintSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      size: 48,
                      color: MintColors.textMuted,
                    ),
                    const SizedBox(height: MintSpacing.md),
                    Text(
                      'Compl\u00e8te ton profil pour acc\u00e9der au cockpit d\u00e9taill\u00e9.',
                      textAlign: TextAlign.center,
                      style: MintTextStyles.bodyMedium(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => context.push('/scan'),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(
                        'Enrichir mon profil',
                        style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: MintColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
      style: MintTextStyles.micro(),
    );
  }
}
