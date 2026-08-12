/// AujourdhuiScreen — living timeline home for authenticated users.
///
/// Phase 18: Full Living Timeline. CustomScrollView with:
/// - MINT wordmark (pinned)
/// - 3 tension cards from Phase 17 (sticky summary)
/// - Cleo loop indicator
/// - Month-grouped timeline nodes (SliverList.builder for lazy loading)
/// - Collapsible month headers (current month expanded, past collapsed)
/// - "Charger plus" pagination when 50+ nodes exist
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/financial_plan.dart' show computeProfileHash;
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/screens/aujourdhui/home_life_events.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
// Wave B-minimal B1 (2026-04-18): Cap du jour banner pulls the
// highest-priority CapDecision from MintStateProvider and surfaces it
// above the TensionCards. The provider is kept fresh by the
// ChangeNotifierProxyProvider wired in `app.dart`.
import 'package:mint_mobile/widgets/aujourdhui/cap_du_jour_banner.dart';
import 'package:mint_mobile/widgets/aujourdhui/commitments_and_checkins_card.dart';
import 'package:mint_mobile/widgets/aujourdhui/confidence_evolution_card.dart';
import 'package:mint_mobile/widgets/aujourdhui/mint_next_3a_handoff_card.dart';
import 'package:mint_mobile/widgets/aujourdhui/mint_next_housing_card.dart';
// Walker 2026-05-08 / Aujourdhui-wire fix: surface the persistent
// FinancialPlan + ConfidenceScore right after the Cap du jour banner.
// Both widgets existed (lib/widgets/home/) but had ZERO callers — the
// canonical façade-sans-câblage pattern (CLAUDE.md NEVER #6).
import 'package:mint_mobile/widgets/home/confidence_score_card.dart';
import 'package:mint_mobile/widgets/home/financial_plan_card.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';
import 'package:mint_mobile/widgets/tension/cleo_loop_indicator.dart';
import 'package:mint_mobile/widgets/tension/tension_card_widget.dart';
import 'package:mint_mobile/widgets/timeline/month_header_widget.dart';
import 'package:mint_mobile/widgets/timeline/timeline_node_widget.dart';

class AujourdhuiScreen extends StatefulWidget {
  const AujourdhuiScreen({super.key});

  @override
  State<AujourdhuiScreen> createState() => _AujourdhuiScreenState();
}

class _AujourdhuiScreenState extends State<AujourdhuiScreen> {
  final Set<String> _collapsedMonths = {};

  // Memoization for ConfidenceScorer.scoreEnhanced — `now` is captured
  // once per State and the result is keyed on the profile hash so a
  // rebuild without profile change reuses the cached EnhancedConfidence.
  // Without this, scoreEnhanced runs on every build with a fresh
  // DateTime.now(), recomputing the freshness axis on each tick and
  // invalidating MintTrameConfiance's bloom-storm guard.
  late final DateTime _confidenceNow = DateTime.now();
  EnhancedConfidence? _cachedConfidence;
  String? _cachedConfidenceProfileHash;
  bool _initialCollapseSet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimelineProvider>().refresh();
    });
  }

  /// Set initial collapse state: current month expanded, past collapsed.
  void _ensureInitialCollapse(TimelineProvider provider) {
    if (_initialCollapseSet || provider.months.isEmpty) return;
    _initialCollapseSet = true;
    for (final month in provider.months) {
      if (!month.isCurrentMonth) {
        _collapsedMonths.add('${month.year}-${month.month}');
      }
    }
  }

  bool _isCollapsed(int year, int month) {
    return _collapsedMonths.contains('$year-$month');
  }

  void _toggleMonth(int year, int month) {
    setState(() {
      final key = '$year-$month';
      if (_collapsedMonths.contains(key)) {
        _collapsedMonths.remove(key);
      } else {
        _collapsedMonths.add(key);
      }
    });
  }

  /// Build the persistent plan + confidence stack, or null when no plan
  /// exists (caller hides the section entirely — empty state belongs to
  /// the coach CTA further down, not to a stub card).
  ///
  /// Tap on `Recalculer` (FinancialPlanCard stale state) and
  /// `onEnrichmentTap` (ConfidenceScoreCard) both route to `/coach/chat`
  /// — the coach is the canonical channel for plan refresh + data
  /// enrichment in MINT.
  Widget? _buildPlanAndConfidenceSection(BuildContext context) {
    final planProvider = context.watch<FinancialPlanProvider>();
    if (!planProvider.hasPlan) return null;

    final profile = context.watch<CoachProfileProvider>().profile;
    if (profile == null) return null;

    // Memoize ConfidenceScorer.scoreEnhanced by profile hash. Reuse
    // _confidenceNow so the freshness axis is stable across rebuilds.
    final hash = computeProfileHash(profile);
    if (_cachedConfidence == null || _cachedConfidenceProfileHash != hash) {
      _cachedConfidence = ConfidenceScorer.scoreEnhanced(
        profile,
        now: _confidenceNow,
      );
      _cachedConfidenceProfileHash = hash;
    }
    final confidence = _cachedConfidence!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MintSpacing.md,
        0,
        MintSpacing.md,
        MintSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FinancialPlanCard(
            plan: planProvider.currentPlan!,
            isStale: planProvider.isPlanStale,
            // Coach is a shell tab: go switches the tab and keeps bottom
            // navigation state coherent.
            onRecalculate: (_) => context.go('/coach/chat'),
          ),
          const SizedBox(height: MintSpacing.md),
          ConfidenceScoreCard(
            score: confidence.combined,
            confidence: confidence,
            enrichmentPrompts: confidence.axisPrompts,
            // Coach is a shell tab: go switches the tab and keeps bottom
            // navigation state coherent.
            onEnrichmentTap: () => context.go('/coach/chat'),
          ),
        ],
      ),
    );
  }

  /// Life-event suggestion cards for /home, fed by [CoachProfileProvider].
  ///
  /// PR-D (TRANCHE-FIRSTJOB-SPEC §1 T3): surfaces the firstJob entry
  /// (`home-lifeevent-card-firstJob`) for young-active profiles. Returns
  /// null when there is no profile or no eligible suggestion so the caller
  /// renders no section at all — no empty-state dead space (D4).
  Widget? _buildLifeEventSection(BuildContext context) {
    final profile = context.watch<CoachProfileProvider>().profile;
    if (profile == null) return null;
    final suggestions = homeLifeEventSuggestions(profile, S.of(context)!);
    if (suggestions.isEmpty) return null;
    return LifeEventSuggestionsSection(
      suggestions: suggestions,
      cardIdentifier: homeLifeEventCardIdentifier,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Route-root accessibility anchor (`home_route_state`) present in every
    // render state (loading / empty / populated) so the acceptance flow can
    // assert it landed on /home before scrolling to a life-event card. Same
    // screen-root Semantics motif as first_job_screen / mon_argent_screen.
    return Semantics(
      identifier: 'home_route_state',
      container: true,
      explicitChildNodes: true,
      child: _buildHomeBody(context),
    );
  }

  Widget _buildHomeBody(BuildContext context) {
    final provider = context.watch<TimelineProvider>();
    final l10n = S.of(context)!;
    final planSection = _buildPlanAndConfidenceSection(context);
    final lifeEventSection = _buildLifeEventSection(context);

    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: MintColors.warmWhite,
        body: Center(
          child: CircularProgressIndicator(
            color: MintColors.success,
          ),
        ),
      );
    }

    if (provider.isEmpty) {
      // Wave B-minimal B1-fix (2026-04-18): Cap du jour banner surfaces
      // even when the timeline is empty so CapEngine's fallback card
      // ("Parle-moi de toi") is visible on first open.
      //
      // Deep-walk 2026-04-21 crack #11: the tension-empty card below
      // used to always render, repeating "Commence par parler au coach"
      // right under the banner that already says the same thing. Gate
      // it on an actually-cold profile — once the user has any captured
      // facts, CapEngine's real cap carries the conversation and the
      // redundant copy disappears.
      final hasAnyProfileFact =
          context.watch<CoachProfileProvider>().profile != null;
      return Scaffold(
        backgroundColor: MintColors.warmWhite,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: CapDuJourBanner()),
              const SliverToBoxAdapter(child: MintNext3aHandoffCard()),
              const SliverToBoxAdapter(child: MintNextHousingCard()),
              // Walker 2026-05-08: even on an empty timeline, surface the
              // persistent plan if one exists (user can have a plan via
              // coach without a timeline yet).
              if (planSection != null) SliverToBoxAdapter(child: planSection),
              if (!hasAnyProfileFact)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: GestureDetector(
                        // Coach is a shell tab: go switches the tab and keeps
                        // bottom navigation state coherent.
                        onTap: () => context.go('/coach/chat'),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: MintColors.craie,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.tensionEmptyWelcome,
                                style: MintTextStyles.titleMedium(
                                  color: MintColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.tensionEmptySubtitle,
                                style: MintTextStyles.bodyMedium(
                                  color: MintColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              // Fresh firstJob persona (no commitments/landmarks/conversations
              // yet) lands here with an empty timeline. Surface the life-event
              // suggestions so /home is not a void and the firstJob entry is
              // reachable (PR-D). Scrollable so `scrollUntilVisible` resolves
              // the card. Shown only when a profile yields suggestions.
              else if (lifeEventSection != null)
                SliverPadding(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  sliver: SliverToBoxAdapter(child: lifeEventSection),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 1)),
            ],
          ),
        ),
      );
    }

    // Set initial collapse state once provider has data.
    _ensureInitialCollapse(provider);

    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── MINT wordmark ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 32),
                child: Center(
                  child: Text(
                    'MINT',
                    style: MintTextStyles.headlineMedium(
                            color: MintColors.textPrimary)
                        .copyWith(letterSpacing: 4),
                  ),
                ),
              ),
            ),

            // ── Cap du jour (B1, above tension cards) ──────────
            // Wave B-minimal B1: the single highest-priority CapDecision
            // from MintStateProvider. Watches the proxy provider so the
            // banner refreshes automatically whenever CoachProfile
            // changes (save_fact, scan enrichment, wizard load).
            const SliverToBoxAdapter(
              child: CapDuJourBanner(),
            ),

            const SliverToBoxAdapter(
              child: MintNext3aHandoffCard(),
            ),
            const SliverToBoxAdapter(
              child: MintNextHousingCard(),
            ),

            // ── Persistent plan + confidence (Walker 2026-05-08) ──
            // Surfaces FinancialPlan + EnhancedConfidence widgets that
            // existed but were unwired. Hidden when no plan exists —
            // the empty-state CTA further down owns "Parle au coach".
            if (planSection != null) SliverToBoxAdapter(child: planSection),

            // ── Tension cards (Phase 17 header) ────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    TensionCardWidget(card: provider.cards[0]),
                    const SizedBox(height: 12),
                    TensionCardWidget(card: provider.cards[1]),
                    const SizedBox(height: 12),
                    TensionCardWidget(card: provider.cards[2]),
                  ],
                ),
              ),
            ),

            // ── Cleo loop indicator ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: CleoLoopIndicator(position: provider.loopPosition),
                ),
              ),
            ),

            // ── Divider: "Ton histoire" ────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 12),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: MintColors.textMutedAaa.withValues(alpha: 0.2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        l10n.timelineSectionTitle,
                        style: MintTextStyles.labelSmall(
                          color: MintColors.textMutedAaa,
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: MintColors.textMutedAaa.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
            ),

            // ── D5 — lucidity evolution curve (head of « Ton histoire ») ──
            // Self-hides on 0 points (no empty section, D4). Renders the
            // monotone confidence curve « toi d'avant vs toi maintenant ».
            const SliverToBoxAdapter(
              child: ConfidenceEvolutionCard(),
            ),

            // ── Timeline months + nodes ────────────────────────
            ...provider.months.expand((month) => [
                  SliverToBoxAdapter(
                    child: MonthHeaderWidget(
                      month: month,
                      isCollapsed: _isCollapsed(month.year, month.month),
                      onToggle: () => _toggleMonth(month.year, month.month),
                    ),
                  ),
                  if (!_isCollapsed(month.year, month.month))
                    SliverList.builder(
                      itemCount: month.nodes.length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: TimelineNodeWidget(node: month.nodes[i]),
                      ),
                    ),
                ]),

            // ── "Charger plus" button ──────────────────────────
            if (provider.hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: TextButton(
                      // lint-ignore: prefer_mint_cta
                      onPressed: provider.loadMore,
                      child: Text(
                        l10n.timelineLoadMore,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Empty timeline state ───────────────────────────
            if (!provider.hasNodes)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: MintColors.craie,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.timelineEmpty,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

            // ── Life-event suggestions (PR-D, post-timeline) ───
            // TRANCHE-FIRSTJOB-SPEC §1 T3: profile-driven life-event cards
            // (firstJob entry `home-lifeevent-card-firstJob`). Hidden when
            // no profile / no eligible suggestion (D4 — no empty section).
            if (lifeEventSection != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: lifeEventSection,
                ),
              ),

            // ── Phase 53-03 — Mes engagements & check-ins ──────
            // Surfaces previously-silent persistent tools (commitments,
            // monthly check-ins) so the user actually sees what the chat
            // captured. Hides itself when both data sources are empty.
            const SliverToBoxAdapter(
              child: CommitmentsAndCheckinsCard(),
            ),

            // ── Bottom padding ─────────────────────────────────
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }
}
