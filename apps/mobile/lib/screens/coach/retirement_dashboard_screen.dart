import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/age_band_policy.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/dashboard_curator_service.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/reengagement_engine.dart';
import 'package:mint_mobile/services/temporal_priority_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/coach/coach_briefing_card.dart';
import 'package:mint_mobile/widgets/coach/confidence_bar.dart';
import 'package:mint_mobile/widgets/coach/confidence_blocks_bar.dart';
import 'package:mint_mobile/widgets/coach/indicatif_banner.dart';
import 'package:mint_mobile/widgets/coach/explore_hub.dart';
import 'package:mint_mobile/widgets/coach/hero_retirement_card.dart';
import 'package:mint_mobile/widgets/coach/monte_carlo_toggle_section.dart';
import 'package:mint_mobile/widgets/coach/temporal_strip.dart';
import 'package:mint_mobile/widgets/coach/hero_couple_card.dart';
import 'package:mint_mobile/widgets/dashboard/document_scan_cta.dart';
import 'package:mint_mobile/services/slm/slm_auto_prompt_service.dart';
import 'package:mint_mobile/widgets/coach/patrimoine_snapshot_card.dart';

// ────────────────────────────────────────────────────────────
//  RETIREMENT DASHBOARD SCREEN — P5 / Dashboard Assembly
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
  AgeBand? _ageBand;
  FinancialFitnessScore? _score;
  ProjectionResult? _projection;
  double _confidenceScore = 0;
  ProjectionConfidence? _confidence;
  Map<String, BlockScore> _confidenceBlocs = const {};

  // ── Coach narrative state (P3) ──────────────────────────
  CoachNarrative? _narrative;
  int _narrativeGeneration = 0;
  String? _scoreHistorySignature;
  List<CuratedCard> _curatedCards = const [];
  List<TemporalItem> _temporalItems = const [];

  // ── P5: Snapshot persistence ──────────────────────────────
  bool _snapshotPersisted = false; // WARN-2: guard against re-entry loop
  bool _slmPromptChecked = false;

  // ────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ────────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // SLM auto-prompt: trigger once on first dashboard visit (native only).
    if (!_slmPromptChecked) {
      _slmPromptChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) SlmAutoPromptService.checkAndPrompt(context);
      });
    }

    final provider = context.watch<CoachProfileProvider>();
    final newScoreHistorySignature =
        _computeScoreHistorySignature(provider.scoreHistory);
    if (!provider.hasProfile) {
      _profile = null;
      _projection = null;
      _confidence = null;
      _confidenceScore = 0;
      _confidenceBlocs = const {};
      _scoreHistorySignature = null;
      // Invalidate any in-flight narrative generation to prevent
      // stale personal content from overwriting null after profile loss.
      _narrativeGeneration++;
      _narrative = null;
      _curatedCards = const [];
      _temporalItems = const [];
      return;
    }

    final newProfile = provider.profile!;
    if (_profile != null && _profile == newProfile) {
      // Profile object unchanged, but score history can evolve independently
      // via saveCurrentScore(). Regenerate narrative trend when it changes.
      if (_scoreHistorySignature == newScoreHistorySignature) return;
      _scoreHistorySignature = newScoreHistorySignature;
      final tips = _buildCoachingTips(newProfile);
      unawaited(_generateNarrative(tips, provider.scoreHistory));
      return;
    }

    _profile = newProfile;
    _scoreHistorySignature = newScoreHistorySignature;
    try {
      _score = FinancialFitnessService.calculate(
        profile: _profile!,
        previousScore: provider.previousScore,
      );
      _projection = ForecasterService.project(profile: _profile!);
      _confidence = ConfidenceScorer.score(_profile!);
      _confidenceScore = _confidence!.score;
      _confidenceBlocs = ConfidenceScorer.scoreAsBlocs(_profile!);

      // ── P3: Compute tips once, share across curation + narrative ──
      final tips = _buildCoachingTips(_profile!);

      // ── P3: Curate cards + temporal items ──────────────
      _curateDashboardContent(tips);

      // ── P5: Persist initial snapshot (side effect) ──
      _persistInitialSnapshot(_profile!);

      // ── P3: Generate narrative (async, non-blocking) ───
      unawaited(_generateNarrative(tips, provider.scoreHistory));
    } catch (e) {
      debugPrint('RetirementDashboard: projection error: $e');
      _projection = null;
      _confidence = null;
      _confidenceScore = 0;
      _confidenceBlocs = const {};
      // Invalidate in-flight narrative generation before clearing state,
      // so any pending async result is discarded on completion.
      _narrativeGeneration++;
      _narrative = null;
      _curatedCards = const [];
      _temporalItems = const [];
    }
  }

  // ────────────────────────────────────────────────────────────
  //  P3: NARRATIVE GENERATION
  // ────────────────────────────────────────────────────────────

  Future<void> _generateNarrative(
    List<CoachingTip> tips,
    List<Map<String, dynamic>> scoreHistory,
  ) async {
    final gen = ++_narrativeGeneration;
    final profile = _profile;
    if (profile == null) {
      if (mounted) setState(() => _narrative = null);
      return;
    }

    try {
      // Read BYOK config from provider (opt-in cloud LLM)
      LlmConfig? byokConfig;
      if (mounted) {
        final byok = context.read<ByokProvider>();
        if (byok.isConfigured && byok.apiKey != null && byok.provider != null) {
          final provider = switch (byok.provider) {
            'claude' => LlmProvider.anthropic,
            'mistral' => LlmProvider.mistral,
            'openai' => LlmProvider.openai,
            _ => null, // Unknown provider — skip BYOK
          };
          if (provider != null) {
            byokConfig = LlmConfig(
              apiKey: byok.apiKey!,
              provider: provider,
            );
          }
        }
      }

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
        byokConfig: byokConfig,
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

  String _computeScoreHistorySignature(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return 'empty';
    final buffer = StringBuffer('${history.length}|');
    for (final entry in history) {
      buffer
        ..write(entry['month'] ?? '')
        ..write(':')
        ..write(entry['score'] ?? '')
        ..write(';');
    }
    return buffer.toString();
  }

  // ────────────────────────────────────────────────────────────
  //  P3: DASHBOARD CONTENT CURATION
  // ────────────────────────────────────────────────────────────

  void _curateDashboardContent(List<CoachingTip> tips) {
    final profile = _profile;
    if (profile == null) return;

    // Compute AgeBand from profile age — drives primary signal selection.
    _ageBand = AgeBandPolicy.forAge(profile.age).band;

    // Reengagement messages
    final taxSaving3a = profile.salaireBrutMensuel > 0
        ? pilier3aPlafondAvecLpp *
            RetirementTaxCalculator.estimateMarginalRate(
                profile.salaireBrutMensuel * 12, profile.canton)
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

    // Temporal items — filter out categories already covered by curated cards
    final rawTemporalItems = TemporalPriorityService.prioritize(
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      taxSaving3a: taxSaving3a,
      friTotal: friScore,
      friDelta: friDelta,
    );
    // Remove fiscal temporal items when curated cards already show tax_deadline
    final hasTaxCard = _curatedCards.any((c) {
      final src = c.source;
      return src is CoachingTip && src.id == 'tax_deadline';
    });
    _temporalItems = hasTaxCard
        ? rawTemporalItems
            .where((t) =>
                !t.title.toLowerCase().contains('fiscal') &&
                !t.title.toLowerCase().contains('déclaration'))
            .toList()
        : rawTemporalItems;
  }

  // ────────────────────────────────────────────────────────────
  //  P5: SNAPSHOT PERSISTENCE (side effect — saves initial projection)
  // ────────────────────────────────────────────────────────────

  void _persistInitialSnapshot(CoachProfile profile) {
    // WARN-2 fix: guard against re-entry loop. updateProfile() triggers
    // didChangeDependencies → full recomputation cycle. Without this
    // flag, loop runs twice (2nd pass exits because snapshot is non-null).
    if (_snapshotPersisted) return;

    if (profile.initialProjectionSnapshot == null && _projection != null) {
      // First time: save snapshot to profile.
      // Deferred to post-frame to avoid setState() during build phase.
      _snapshotPersisted = true;
      final snapshotJson = _projection!.toJson();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final provider = context.read<CoachProfileProvider>();
        provider.updateProfile(
          profile.copyWith(initialProjectionSnapshot: snapshotJson),
        );
      });
    }
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

    // Revenu mensuel base scenario
    final monthlyIncome = proj.base.revenuAnnuelRetraite / 12;
    final monthlyPrudent = proj.prudent.revenuAnnuelRetraite / 12;
    final monthlyOptimiste = proj.optimiste.revenuAnnuelRetraite / 12;

    // Decomposition par pilier (pour couple hero card)
    final decoBase = proj.base.decomposition;

    // Couple hero card
    final isCouple = profile.isCouple && profile.conjoint?.birthYear != null;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(profile.firstName),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Indicatif Banner (hidden when >= 70%) ──
                IndicatifBanner(
                  confidenceScore: _confidenceScore,
                  topEnrichmentCategory: _confidence?.prompts.isNotEmpty == true
                      ? _confidence!.prompts.first.category
                      : null,
                ),

                // ── P3: Coach Briefing Card ──────────────
                CoachBriefingCard(
                  narrative: _narrative,
                  topCard:
                      _curatedCards.isNotEmpty ? _curatedCards.first : null,
                  confidenceScore: _confidenceScore,
                  isLlmGenerated: _narrative?.isLlmGenerated ?? false,
                  onEnrich: () => context.push('/profile/bilan'),
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

                // ── AgeBand signal primaire ───────────────
                _buildAgeBandSection(),
                const SizedBox(height: 16),

                // ── P5: Patrimoine Snapshot ──────────────
                PatrimoineSnapshotCard(
                  lppCapital: profile.prevoyance.avoirLppTotal ?? 0,
                  lppCapitalConjoint: profile.conjoint?.prevoyance?.avoirLppTotal ?? 0,
                  threeACapital: profile.prevoyance.totalEpargne3a,
                  epargne: profile.patrimoine.epargneLiquide + profile.patrimoine.investissements + profile.prevoyance.totalLibrePassage,
                  immobilier: profile.patrimoine.immobilier ?? 0,
                ),
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
                const SizedBox(height: 8),

                // ── Link to cockpit d\u00e9taill\u00e9 ──
                _buildCockpitLink(),
                const SizedBox(height: 8),

                // ── Link to profile/data ──
                _buildProfileLink(),
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
  //  STATE B — Profil partiel (40-69% confiance)
  // ────────────────────────────────────────────────────────────

  Widget _buildStateB() {
    final proj = _projection!;
    final profile = _profile!;

    final monthlyPrudent = proj.prudent.revenuAnnuelRetraite / 12;
    final monthlyOptimiste = proj.optimiste.revenuAnnuelRetraite / 12;

    // Couple hero card
    final isCouple = profile.isCouple && profile.conjoint?.birthYear != null;
    final decoBase = proj.base.decomposition;

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
                // ── Indicatif Banner (visible when < 70%) ──
                IndicatifBanner(
                  confidenceScore: _confidenceScore,
                  topEnrichmentCategory: _confidence?.prompts.isNotEmpty == true
                      ? _confidence!.prompts.first.category
                      : null,
                ),

                // ── P3: Coach Briefing Card ──────────────
                CoachBriefingCard(
                  narrative: _narrative,
                  topCard:
                      _curatedCards.isNotEmpty ? _curatedCards.first : null,
                  confidenceScore: _confidenceScore,
                  isLlmGenerated: _narrative?.isLlmGenerated ?? false,
                  onEnrich: () => context.push('/profile/bilan'),
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

                // ── AgeBand signal primaire ───────────────
                _buildAgeBandSection(),
                const SizedBox(height: 16),

                // ── Hero card: couple or single ──
                if (isCouple) ...[
                  _buildCoupleHeroCard(profile, decoBase, proj),
                ] else ...[
                  HeroRetirementCard(
                    mode: HeroCardMode.range,
                    rangeMin: monthlyPrudent,
                    rangeMax: monthlyOptimiste,
                  ),
                ],
                const SizedBox(height: 8),

                // ── Confidence Blocks Bar (per-category progress) ──
                if (_confidenceBlocs.isNotEmpty) ...[
                  ConfidenceBlocksBar(blocs: _confidenceBlocs),
                  const SizedBox(height: 16),
                ],

                // Document Scan CTA (prominent in State B)
                DocumentScanCta(
                  currentConfidence: _confidenceScore,
                  estimatedConfidenceAfterScan: estimatedAfterScan,
                ),
                const SizedBox(height: 16),

                // ── P4: Monte Carlo Teaser (State B, non personnalisé) ──
                MonteCarloTeaser(
                  onEnrich: () => context.push('/data-block/lpp'),
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

                // ── Link to cockpit d\u00e9taill\u00e9 ──
                _buildCockpitLink(),
                const SizedBox(height: 8),

                // ── Link to profile/data ──
                _buildProfileLink(),
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
                // ── AgeBand signal primaire (State C — 65+ voit décaissement/succession) ───
                if (_ageBand != null) ...[
                  _buildAgeBandSection(),
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
  //  APPBAR
  // ────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(String? firstName) {
    // AppBar shows a short stable title — narrative greeting lives in CoachBriefingCard only.
    final title = firstName != null && firstName.isNotEmpty
        ? 'Retraite \u00b7 $firstName'
        : 'Mon tableau de bord';

    return SliverAppBar(
      expandedHeight: 80,
      floating: true,
      snap: true,
      backgroundColor: MintColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title,
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
          icon: const Icon(Icons.edit_note_outlined,
              color: MintColors.textSecondary),
          onPressed: () => context.push('/profile/bilan'),
          tooltip: 'Mes donn\u00e9es',
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
  // ────────────────────────────────────────────────────────────
  //  NAVIGATION LINKS (cockpit + profile)
  // ────────────────────────────────────────────────────────────

  Widget _buildCockpitLink() {
    return GestureDetector(
      onTap: () => context.push('/coach/cockpit'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            Icon(Icons.dashboard_outlined, size: 18, color: MintColors.primary),
            const SizedBox(width: 8),
            Text(
              'Cockpit d\u00e9taill\u00e9',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MintColors.primary,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: MintColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileLink() {
    return GestureDetector(
      onTap: () => context.push('/profile/bilan'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MintColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note_outlined, size: 18, color: MintColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Mes donn\u00e9es',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MintColors.textSecondary,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: MintColors.textMuted),
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

  // ────────────────────────────────────────────────────────────
  //  AgeBand section — signal primaire adapté au stade de vie
  // ────────────────────────────────────────────────────────────

  Widget _buildAgeBandSection() {
    if (_ageBand == null) return const SizedBox.shrink();
    final band = _ageBand!;
    switch (band) {
      case AgeBand.youngProfessional:
        return _AgeBandCard(
          icon: Icons.savings_outlined,
          title: 'Ton levier principal : le 3a',
          subtitle:
              'Chaque franc versé maintenant travaille 40 ans. Ouvrir ton 3a coûte 15 minutes.',
          cta: 'Simuler mon 3a',
          route: '/simulator/3a',
          color: const Color(0xFF2E7D5E),
        );
      case AgeBand.stabilization:
        return _AgeBandCard(
          icon: Icons.home_outlined,
          title: '3a + protection famille',
          subtitle:
              'Logement, couverture décès/invalidité : c\'est maintenant que l\'architecture se construit.',
          cta: 'Voir les simulateurs',
          route: '/simulator/3a',
          color: const Color(0xFF1565C0),
        );
      case AgeBand.peakEarnings:
        return _AgeBandCard(
          icon: Icons.trending_up,
          title: 'Rachat LPP + optimisation fiscale',
          subtitle:
              'Tes revenus sont au pic — c\'est la fenêtre pour réduire l\'écart de retraite.',
          cta: 'Simuler un rachat',
          route: '/lpp-deep/rachat',
          color: const Color(0xFF6A1B9A),
        );
      case AgeBand.preRetirement:
        return _AgeBandCard(
          icon: Icons.timeline,
          title: 'Ton gap retraite en CHF/mois',
          subtitle:
              'Rente vs capital, retraite anticipée, rachat échelonné : les décisions se rapprochent.',
          cta: 'Rente vs Capital',
          route: '/arbitrage/rente-vs-capital',
          color: const Color(0xFFE65100),
        );
      case AgeBand.retirement:
        return Column(
          children: [
            _AgeBandCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Ordre de retrait 3a',
              subtitle:
                  'Échelonner tes retraits 3a sur 3–5 ans réduit l\'impôt de manière significative selon le canton.',
              cta: 'Planifier mes retraits',
              route: '/coach/decaissement',
              color: const Color(0xFF00695C),
            ),
            const SizedBox(height: 12),
            _AgeBandCard(
              icon: Icons.family_restroom,
              title: 'Succession & transmission',
              subtitle:
                  'Testament, donation du vivant, bénéficiaires LPP : protéger ceux que tu aimes.',
              cta: 'Explorer',
              route: '/coach/succession',
              color: const Color(0xFF37474F),
            ),
          ],
        );
    }
  }
}

// ────────────────────────────────────────────────────────────
//  _AgeBandCard — carte signal primaire par stade de vie
// ────────────────────────────────────────────────────────────

class _AgeBandCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;
  final String route;
  final Color color;

  const _AgeBandCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.route,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => context.push(route),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cta,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14, color: color),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
