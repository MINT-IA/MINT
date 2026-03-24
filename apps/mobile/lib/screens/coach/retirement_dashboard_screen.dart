import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
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
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/services/slm/slm_auto_prompt_service.dart';
import 'package:mint_mobile/widgets/coach/retirement_hero_zone.dart';
import 'package:mint_mobile/widgets/coach/smart_shortcuts.dart';
import 'package:mint_mobile/widgets/collapsible_section.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_signal_row.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_progress_arc.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  RETIREMENT DASHBOARD SCREEN — Hero (Category A)
// ────────────────────────────────────────────────────────────
//
//  Layout (max 2 above fold per DESIGN_SYSTEM §2A):
//
//  ABOVE FOLD:
//    0. UrgentBanner — temporal deadline < 60 days (conditional)
//    1. HeroZone — CHF/mois, replacement rate, pillar bar,
//       sparkline, confidence chip, coach one-liner
//
//  BELOW FOLD (scroll):
//    2. ActionCards — max 2 curated actions with CHF impact
//    3. SmartShortcuts — filtered chips to arbitrage/tools
//    4. Related sections (collapsible hub)
//    5. Footer — disclaimer + sources
//
//  STATE A (confiance >= 70%): Full hero, financial actions
//  STATE B (confiance < 70%): ~prefix, wide band, data enrichment card
//  STATE C (no profile): Onboarding CTA + educational card
//
//  Fallback chain: SLM → Templates → BYOK (privacy-first).
//  Aucun terme banni (garanti, certain, optimal, meilleur...).
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
  double _confidenceScore = 0;
  ProjectionConfidence? _confidence;

  // ── Coach narrative state ──────────────────────────────
  CoachNarrative? _narrative;
  int _narrativeGeneration = 0;
  String? _scoreHistorySignature;
  List<CuratedCard> _curatedCards = const [];
  List<TemporalItem> _temporalItems = const [];

  // ── Snapshot persistence ────────────────────────────────
  bool _snapshotPersisted = false;
  bool _slmPromptChecked = false;

  // ────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ────────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

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
      _scoreHistorySignature = null;
      _narrativeGeneration++;
      _narrative = null;
      _curatedCards = const [];
      _temporalItems = const [];
      return;
    }

    final newProfile = provider.profile!;
    if (_profile != null && _profile == newProfile) {
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

      final tips = _buildCoachingTips(_profile!);
      _curateDashboardContent(tips);
      _persistInitialSnapshot(_profile!);
      unawaited(_generateNarrative(tips, provider.scoreHistory));
    } catch (e) {
      debugPrint('RetirementDashboard: projection error: $e');
      _projection = null;
      _confidence = null;
      _confidenceScore = 0;
      _narrativeGeneration++;
      _narrative = null;
      _curatedCards = const [];
      _temporalItems = const [];
    }
  }

  // ────────────────────────────────────────────────────────────
  //  NARRATIVE GENERATION
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
      LlmConfig? byokConfig;
      if (mounted) {
        final byok = context.read<ByokProvider>();
        if (byok.isConfigured && byok.apiKey != null && byok.provider != null) {
          final provider = switch (byok.provider) {
            'claude' => LlmProvider.anthropic,
            'mistral' => LlmProvider.mistral,
            'openai' => LlmProvider.openai,
            _ => null,
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
  //  DASHBOARD CONTENT CURATION
  // ────────────────────────────────────────────────────────────

  void _curateDashboardContent(List<CoachingTip> tips) {
    final profile = _profile;
    if (profile == null) return;

    final isMarried = profile.etatCivil == CoachCivilStatus.marie;
    final taxSaving3a = profile.salaireBrutMensuel > 0
        ? pilier3aPlafondAvecLpp *
            RetirementTaxCalculator.estimateMarginalRate(
                profile.salaireBrutMensuel * 12, profile.canton,
                isMarried: isMarried, children: profile.nombreEnfants)
        : 0.0;
    final friScore = _score?.global.toDouble() ?? 0.0;
    final friDelta = (_score?.deltaVsPreviousMonth ?? 0).toDouble();

    final reengagementMessages = ReengagementEngine.generateMessages(
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      taxSaving3a: taxSaving3a,
      friTotal: friScore,
      friDelta: friDelta,
    );

    _curatedCards = DashboardCuratorService.curate(
      tips: tips,
      reengagementMessages: reengagementMessages,
    );

    final rawTemporalItems = TemporalPriorityService.prioritize(
      canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
      taxSaving3a: taxSaving3a,
      friTotal: friScore,
      friDelta: friDelta,
    );
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
  //  SNAPSHOT PERSISTENCE
  // ────────────────────────────────────────────────────────────

  void _persistInitialSnapshot(CoachProfile profile) {
    if (_snapshotPersisted) return;
    if (profile.initialProjectionSnapshot == null && _projection != null) {
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
  //  BUILD — 3 STATES
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CoachProfileProvider>();

    if (!provider.hasProfile || _projection == null) {
      return _buildStateC();
    }
    return _buildDashboard();
  }

  // ────────────────────────────────────────────────────────────
  //  UNIFIED DASHBOARD (State A + B — same layout, different emphasis)
  // ────────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    final proj = _projection!;
    final profile = _profile!;
    final isApproximate = _confidenceScore < 70;

    final monthlyBase = proj.base.revenuAnnuelRetraite / 12;
    final monthlyPrudent = proj.prudent.revenuAnnuelRetraite / 12;
    final monthlyOptimiste = proj.optimiste.revenuAnnuelRetraite / 12;

    // Couple combined income
    final isCouple = profile.isCouple && profile.conjoint?.birthYear != null;
    final decoBase = proj.base.decomposition;
    double? partnerMonthly;
    if (isCouple) {
      final avsConj = (decoBase['avs_conjoint'] ?? 0) / 12;
      final lppConj = (decoBase['lpp_conjoint'] ?? 0) / 12;
      partnerMonthly = avsConj + lppConj;
    }

    // Coach one-liner from narrative or template
    final coachOneLiner = _narrative?.greeting ??
        _buildDefaultOneLiner(profile, proj);

    // Urgent temporal item (deadline < 60 days)
    final urgentItem = _temporalItems
        .where((t) => t.daysUntil < 60)
        .toList();

    final l = S.of(context)!;

    // Pillar decomposition for signal rows
    final avs = ((decoBase['avs'] ?? decoBase['avs_user'] ?? 0) +
            (decoBase['avs_conjoint'] ?? 0)) /
        12;
    final lpp = ((decoBase['lpp'] ?? decoBase['lpp_user'] ?? 0) +
            (decoBase['lpp_conjoint'] ?? 0)) /
        12;
    final troisA = (decoBase['3a'] ?? decoBase['pilier3a'] ?? 0) / 12;

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(profile.firstName),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.lg,
              vertical: MintSpacing.md,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── ABOVE FOLD: Banner + Hero (max 2 sections) ──

                // Position 0: Urgent Banner (conditional)
                if (urgentItem.isNotEmpty) ...[
                  _UrgentBanner(item: urgentItem.first),
                  const SizedBox(height: MintSpacing.md),
                ],

                // Position 1: Hero — Replacement rate arc (the single moment hero)
                MintEntrance(child: Center(
                  child: MintProgressArc(
                    value: proj.tauxRemplacementBase,
                    maxValue: 100,
                    label: '${proj.tauxRemplacementBase.round()}\u00a0%',
                    subtitle: l.dashboardMetricReplacementRate,
                    size: 200,
                  ),
                )),
                const SizedBox(height: MintSpacing.md),

                // Position 1b: Hero Zone — monthly income, sparkline, pillar bar
                MintEntrance(delay: const Duration(milliseconds: 100), child: RetirementHeroZone(
                  monthlyIncome: isCouple && partnerMonthly != null
                      ? monthlyBase + partnerMonthly
                      : monthlyBase,
                  replacementRate: proj.tauxRemplacementBase,
                  decomposition: decoBase,
                  monthlyPrudent: monthlyPrudent,
                  monthlyOptimiste: monthlyOptimiste,
                  confidenceScore: _confidenceScore,
                  coachOneLiner: coachOneLiner,
                  deltaSinceLastVisit: _computeDelta(),
                  currentAge: profile.age,
                  retirementAge: profile.effectiveRetirementAge,
                  isApproximate: isApproximate,
                  isCouple: isCouple,
                  partnerName: profile.conjoint?.firstName,
                  partnerMonthlyIncome: partnerMonthly,
                  onConfidenceTap: () => _showEnrichmentSheet(context),
                )),
                const SizedBox(height: MintSpacing.xxl),

                // ── BELOW FOLD ──

                // Position 2: Coach narrative card (cap retraite)
                if (_narrative != null && _narrative!.greeting.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MintSpacing.xl),
                    child: MintNarrativeCard(
                      headline: l.dashboardCockpitTitle,
                      body: coachOneLiner,
                      tone: MintSurfaceTone.sauge,
                      ctaLabel: l.dashboardCockpitCta,
                      onTap: () => context.push('/coach/cockpit'),
                    ),
                  ),

                // Position 2b: Pillar signal rows (AVS/LPP/3a — light, not heavy cards)
                MintEntrance(delay: const Duration(milliseconds: 200), child: MintSurface(
                  tone: MintSurfaceTone.craie,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MintSpacing.lg,
                    vertical: MintSpacing.sm,
                  ),
                  child: Column(
                    children: [
                      MintSignalRow(
                        label: 'AVS',
                        value: 'CHF\u00a0${avs.round()}',
                        valueColor: MintColors.retirementAvs,
                      ),
                      MintSignalRow(
                        label: 'LPP',
                        value: 'CHF\u00a0${lpp.round()}',
                        valueColor: MintColors.retirementLpp,
                      ),
                      if (troisA > 0)
                        MintSignalRow(
                          label: '3a',
                          value: 'CHF\u00a0${troisA.round()}',
                          valueColor: MintColors.retirement3a,
                        ),
                    ],
                  ),
                )),
                const SizedBox(height: MintSpacing.xl),

                // Position 2c: Confidence notice (premium)
                if (isApproximate)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MintSpacing.xl),
                    child: MintConfidenceNotice(
                      percent: _confidenceScore.round(),
                      message: l.dashboardCurrentConfidence(
                          _confidenceScore.round()),
                      ctaLabel: l.dashboardImproveAccuracyTitle,
                      onTap: () => _showEnrichmentSheet(context),
                    ),
                  ),

                // Position 3: Action Cards (max 2)
                ..._buildActionCards(isApproximate, l),

                // Position 4: Smart Shortcuts
                SmartShortcuts(
                  profile: profile,
                  confidenceScore: _confidenceScore,
                ),
                const SizedBox(height: MintSpacing.xxl),

                // Position 5: Related sections (hub)
                _buildRelatedSections(l),
                const SizedBox(height: MintSpacing.xl),

                // Position 6: Footer — disclaimer
                _buildDisclaimer(),
                const SizedBox(height: MintSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  STATE C — No profile / onboarding
  // ────────────────────────────────────────────────────────────

  Widget _buildStateC() {
    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(null),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.lg,
              vertical: MintSpacing.md,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildOnboardingHero(),
                const SizedBox(height: MintSpacing.md),
                _buildEducationalCard(),
                const SizedBox(height: MintSpacing.lg),
                _buildDisclaimer(),
                const SizedBox(height: MintSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  APPBAR — White standard (not Pulse gradient per §4.5)
  // ────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(String? firstName) {
    final title = firstName != null && firstName.isNotEmpty
        ? S.of(context)!.dashboardAppBarWithName(firstName)
        : S.of(context)!.dashboardAppBarDefault;

    return SliverAppBar(
      expandedHeight: 80,
      floating: true,
      snap: true,
      backgroundColor: MintColors.porcelaine,
      surfaceTintColor: MintColors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title,
          style: MintTextStyles.headlineMedium().copyWith(fontSize: 18),
        ),
        titlePadding: const EdgeInsets.only(
          left: MintSpacing.lg,
          bottom: MintSpacing.sm + MintSpacing.xs,
        ),
      ),
      actions: [
        Semantics(
          label: S.of(context)!.dashboardMyData,
          button: true,
          child: IconButton(
            icon: const Icon(Icons.edit_note_outlined,
                color: MintColors.textSecondary),
            onPressed: () => context.push('/profile/bilan'),
            tooltip: S.of(context)!.dashboardMyData,
          ),
        ),
        const SizedBox(width: MintSpacing.xs),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  ACTION CARDS — max 2, with CHF impact
  // ────────────────────────────────────────────────────────────

  List<Widget> _buildActionCards(bool isApproximate, S l) {
    if (_curatedCards.isEmpty) return [];

    // Pick max 2 cards:
    // - Card 1: highest impact financial action
    // - Card 2: if low confidence -> data enrichment, else second action
    final cards = _curatedCards.take(2).toList();

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: MintSpacing.sm),
        child: Text(
          l.dashboardNextActionsTitle,
          style: MintTextStyles.titleMedium(),
        ),
      ),
      ...cards.map((card) => Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
            child: _ActionCard(card: card),
          )),
      // Show data enrichment cards if low confidence (up to 3)
      if (isApproximate && _confidence?.prompts.isNotEmpty == true) ...[
        ..._confidence!.prompts.take(3).map((prompt) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
              child: _DataEnrichmentCard(
                prompt: prompt,
                confidenceScore: _confidenceScore,
              ),
            )),
      ],
      const SizedBox(height: MintSpacing.sm - 2),
    ];
  }

  // ────────────────────────────────────────────────────────────
  //  HELPERS
  // ────────────────────────────────────────────────────────────

  String _buildDefaultOneLiner(CoachProfile profile, ProjectionResult proj) {
    final l = S.of(context)!;
    final rate = proj.tauxRemplacementBase;
    if (rate >= 70) {
      return l.dashboardOneLinerGoodTrack;
    }
    if (rate >= 50) {
      return l.dashboardOneLinerLevers;
    }
    return l.dashboardOneLinerEveryAction;
  }

  double? _computeDelta() {
    // Compare current projection with initial snapshot
    final profile = _profile;
    if (profile == null || _projection == null) return null;
    final snapshot = profile.initialProjectionSnapshot;
    if (snapshot == null) return null;
    try {
      final initial = ProjectionResult.fromJson(snapshot);
      final currentMonthly = _projection!.base.revenuAnnuelRetraite / 12;
      final initialMonthly = initial.base.revenuAnnuelRetraite / 12;
      final delta = currentMonthly - initialMonthly;
      return delta.abs() > 50 ? delta : null;
    } catch (_) {
      return null;
    }
  }

  void _showEnrichmentSheet(BuildContext context) {
    final prompts = _confidence?.prompts ?? [];
    if (prompts.isEmpty) return;

    final l = S.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MintColors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: const BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            Text(
              l.dashboardImproveAccuracyTitle,
              style: MintTextStyles.headlineMedium().copyWith(fontSize: 18),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              l.dashboardCurrentConfidence(_confidenceScore.round()),
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.md),
            ...prompts.take(5).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
                  child: Semantics(
                    label: p.label,
                    button: true,
                    child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/data-block/${p.category}');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: MintSurface(
                      tone: MintSurfaceTone.porcelaine,
                      padding: const EdgeInsets.all(14),
                      radius: 12,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(MintSpacing.sm),
                            decoration: BoxDecoration(
                              color: MintColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _categoryIcon(p.category),
                              size: 16,
                              color: MintColors.primary,
                            ),
                          ),
                          const SizedBox(width: MintSpacing.sm + MintSpacing.xs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.label,
                                  style: MintTextStyles.bodySmall(
                                    color: MintColors.textPrimary,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  l.dashboardPrecisionPtsGain(p.impact),
                                  style: MintTextStyles.labelSmall(
                                    color: MintColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 14, color: MintColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'lpp' => Icons.business_outlined,
      'avs' => Icons.account_balance_outlined,
      '3a' => Icons.savings_outlined,
      'patrimoine' => Icons.account_balance_wallet_outlined,
      'logement' => Icons.home_outlined,
      'depenses' => Icons.receipt_long_outlined,
      'income' => Icons.payments_outlined,
      _ => Icons.add_circle_outline,
    };
  }

  // ────────────────────────────────────────────────────────────
  //  STATE C WIDGETS
  // ────────────────────────────────────────────────────────────

  Widget _buildOnboardingHero() {
    final l = S.of(context)!;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.primary.withValues(alpha: 0.06),
            MintColors.coachAccent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Semantics(
            label: l.dashboardOnboardingHeroTitle,
            child: const Icon(Icons.beach_access_outlined,
                size: 48, color: MintColors.primary),
          ),
          const SizedBox(height: MintSpacing.md),
          Text(
            l.dashboardOnboardingHeroTitle,
            textAlign: TextAlign.center,
            style: MintTextStyles.headlineMedium().copyWith(fontSize: 20),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l.dashboardQuickStartBody,
            textAlign: TextAlign.center,
            style: MintTextStyles.bodyMedium().copyWith(height: 1.5),
          ),
          const SizedBox(height: MintSpacing.lg - MintSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: Semantics(
              button: true,
              label: l.dashboardOnboardingCta,
              child: FilledButton(
                onPressed: () => context.push('/onboarding/quick'),
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l.dashboardOnboardingCta,
                  style: MintTextStyles.titleMedium(color: MintColors.white)
                      .copyWith(fontSize: 15),
                ),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 2),
          Text(
            l.dashboardOnboardingConsent,
            style: MintTextStyles.micro(),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationalCard() {
    final l = S.of(context)!;

    return Semantics(
      label: l.dashboardEducationTitle,
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/education/hub'),
        child: MintSurface(
          tone: MintSurfaceTone.porcelaine,
          padding: const EdgeInsets.all(MintSpacing.md),
          radius: 14,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(MintSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: MintColors.info.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_outlined,
                    size: 20, color: MintColors.info),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.dashboardEducationTitle,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      l.dashboardEducationSubtitle,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: MintColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  RELATED SECTIONS (HUB) — below fold
  // ────────────────────────────────────────────────────────────

  Widget _buildRelatedSections(S l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.dashboardExploreAlsoTitle,
          style: MintTextStyles.titleMedium(),
        ),
        const SizedBox(height: MintSpacing.sm + MintSpacing.xs),
        CollapsibleSection(
          title: l.dashboardCockpitTitle,
          subtitle: l.dashboardCockpitSubtitle,
          icon: Icons.dashboard_outlined,
          child: _buildSectionCta(l.dashboardCockpitCta, '/coach/cockpit'),
        ),
        CollapsibleSection(
          title: l.dashboardRenteVsCapitalTitle,
          subtitle: l.dashboardRenteVsCapitalSubtitle,
          icon: Icons.balance,
          child: _buildSectionCta(
              l.dashboardRenteVsCapitalCta, '/rente-vs-capital'),
        ),
        CollapsibleSection(
          title: l.dashboardRachatLppTitle,
          subtitle: l.dashboardRachatLppSubtitle,
          icon: Icons.add_chart,
          child: _buildSectionCta(l.dashboardRachatLppCta, '/rachat-lpp'),
        ),
      ],
    );
  }

  Widget _buildSectionCta(String label, String route) {
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        button: true,
        label: label,
        child: OutlinedButton(
          onPressed: () => context.push(route),
          child: Text(label),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  DISCLAIMER
  // ────────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Text(
      S.of(context)!.dashboardDisclaimer,
      textAlign: TextAlign.center,
      style: MintTextStyles.micro(),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  URGENT BANNER — Temporal deadline < 60 days
// ────────────────────────────────────────────────────────────

class _UrgentBanner extends StatelessWidget {
  final TemporalItem item;

  const _UrgentBanner({required this.item});

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntil;
    final l = S.of(context)!;

    return Semantics(
      label: l.dashboardBannerDeadline(item.title, days),
      button: true,
      child: GestureDetector(
        onTap: () => context.push(item.deeplink),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: MintSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: MintColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: MintColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: MintColors.warning),
              const SizedBox(width: MintSpacing.sm + 2),
              Expanded(
                child: Text(
                  l.dashboardBannerDeadline(item.title, days),
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 12, color: MintColors.warning),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ACTION CARD — Curated action with CHF impact
// ────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final CuratedCard card;

  const _ActionCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final urgencyColor = switch (card.urgency) {
      AlertUrgency.urgent => MintColors.error,
      AlertUrgency.active => MintColors.warning,
      AlertUrgency.info => MintColors.primary,
    };

    final l = S.of(context)!;

    return Semantics(
      label: card.title,
      button: card.deeplink != null,
      child: GestureDetector(
        onTap:
            card.deeplink != null ? () => context.push(card.deeplink!) : null,
        child: MintSurface(
          padding: const EdgeInsets.all(14),
          radius: 14,
          elevated: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(MintSpacing.sm),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  switch (card.urgency) {
                    AlertUrgency.urgent => Icons.warning_amber_rounded,
                    AlertUrgency.active => Icons.trending_up,
                    AlertUrgency.info => Icons.lightbulb_outline,
                  },
                  size: 16,
                  color: urgencyColor,
                ),
              ),
              const SizedBox(width: MintSpacing.sm + MintSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      card.message,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ).copyWith(fontSize: 12, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (card.impactChf != null && card.impactChf! > 0) ...[
                      const SizedBox(height: MintSpacing.sm - 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: MintSpacing.sm, vertical: MintSpacing.xs),
                        decoration: BoxDecoration(
                          color: MintColors.success.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l.dashboardImpactChf(formatChf(card.impactChf!)),
                          style: MintTextStyles.bodySmall(
                            color: MintColors.success,
                          ).copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (card.deadlineDays != null) ...[
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        l.dashboardDeadlineDays(card.deadlineDays!),
                        style: MintTextStyles.labelSmall(
                          color: urgencyColor,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              if (card.deeplink != null)
                const Icon(Icons.chevron_right,
                    size: 18, color: MintColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  DATA ENRICHMENT CARD — Confidence improvement prompt
// ────────────────────────────────────────────────────────────

class _DataEnrichmentCard extends StatelessWidget {
  final EnrichmentPrompt prompt;
  final double confidenceScore;

  const _DataEnrichmentCard({
    required this.prompt,
    required this.confidenceScore,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Semantics(
      label: prompt.label,
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/data-block/${prompt.category}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: MintColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(MintSpacing.sm),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.document_scanner_outlined,
                    size: 16, color: MintColors.primary),
              ),
              const SizedBox(width: MintSpacing.sm + MintSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompt.label,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      l.dashboardPrecisionGainPercent(prompt.impact),
                      style: MintTextStyles.bodySmall(
                        color: MintColors.success,
                      ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: MintColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
