/// MintHomeScreen — Tab 0 "Aujourd'hui" (Wire Spec V2 + Phase 05).
///
/// Unified 5-card contextual feed powered by [ContextualCardProvider].
/// Card types: Hero (slot 1), Anticipation, Progress, Action, Overflow.
/// Plus: Premier Eclairage, Financial Plan, Plan Reality, Journey Steps,
/// Itineraire Alternatif, Coach Input Bar (all kept from prior versions).
///
/// Design: Hero always slot 1, max 5 cards, overflow expandable.
/// Coach opener: biography-aware, compliance-validated greeting.
///
/// See: CTX-01..06 requirements, docs/WIRE_SPEC_V2.md §3
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/providers/anticipation_provider.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/contextual_card_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/streak_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/coach/animated_progress_bar.dart';
import 'package:mint_mobile/widgets/coach/first_check_in_cta_card.dart';
import 'package:mint_mobile/widgets/coach/plan_reality_card.dart';
import 'package:mint_mobile/widgets/coach/streak_badge.dart';
import 'package:mint_mobile/widgets/home/action_opportunity_card.dart';
import 'package:mint_mobile/widgets/home/anticipation_signal_card.dart';
import 'package:mint_mobile/widgets/home/contextual_overflow.dart';
import 'package:mint_mobile/widgets/home/financial_plan_card.dart';
import 'package:mint_mobile/widgets/home/hero_stat_card.dart';
import 'package:mint_mobile/widgets/home/progress_milestone_card.dart';
import 'package:mint_mobile/widgets/onboarding/premier_eclairage_card.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// The new Tab 0 — "Aujourd'hui".
///
/// Reads reactively from [MintStateProvider] via `context.watch`.
/// When [MintUserState] is null (loading), shows a centered spinner.
///
/// Section 0 (first visit only): [PremierEclairageCard] — shown when the user
/// has selected an intent chip but has not yet seen their premier éclairage.
class MintHomeScreen extends StatefulWidget {
  /// Callback to switch the parent [MainNavigationShell] to the coach tab.
  /// Receives the [CoachEntryPayload] to pass as context.
  final void Function(CoachEntryPayload? payload)? onSwitchToCoach;

  const MintHomeScreen({super.key, this.onSwitchToCoach});

  @override
  State<MintHomeScreen> createState() => _MintHomeScreenState();
}

class _MintHomeScreenState extends State<MintHomeScreen> {
  bool _hasSeenPremierEclairage = true; // optimistic: hidden until loaded
  String? _selectedIntent;
  bool _hasExploredSimulators = false;

  @override
  void initState() {
    super.initState();
    _loadPremierEclairageState();
    // Evaluate anticipation triggers + contextual cards once per session (CTX-02)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = context.read<CoachProfileProvider>().profile;
      final facts = context.read<BiographyProvider>().facts;
      if (profile != null) {
        // Anticipation must evaluate BEFORE contextual cards
        // (anticipation signals feed into contextual ranking)
        final anticipation = context.read<AnticipationProvider>();
        await anticipation.evaluateOnSessionStart(
          profile: profile,
          facts: facts,
        );

        // Now evaluate contextual cards with anticipation results
        if (mounted) {
          context.read<ContextualCardProvider>().evaluateOnSessionStart(
                profile: profile,
                facts: facts,
                anticipationVisible: anticipation.visibleSignals,
                anticipationOverflow: anticipation.overflowSignals,
              );
        }
      }
    });
  }

  Future<void> _loadPremierEclairageState() async {
    final hasSeen = await ReportPersistenceService.hasSeenPremierEclairage();
    final intent = await ReportPersistenceService.getSelectedOnboardingIntent();
    if (mounted) {
      final activityProvider = context.read<UserActivityProvider>();
      setState(() {
        _hasSeenPremierEclairage = hasSeen;
        _selectedIntent = intent;
        _hasExploredSimulators =
            activityProvider.exploredSimulators.isNotEmpty;
      });
    }
  }

  bool get _shouldShowPremierEclairage =>
      !_hasSeenPremierEclairage &&
      _selectedIntent != null &&
      !_hasExploredSimulators;

  @override
  Widget build(BuildContext context) {
    final mintState = context.watch<MintStateProvider>().state;

    if (mintState == null) {
      return const Scaffold(
        backgroundColor: MintColors.background,
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.lg,
                vertical: MintSpacing.md,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: MintSpacing.sm),

                  // ── Profile access button ──
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Scaffold.of(context).openEndDrawer();
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: MintColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MintColors.lightBorder,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          // AESTH-05 per AUDIT_RETRAIT S2 (D-03 swap map)
                          color: MintColors.textSecondaryAaa,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: MintSpacing.md),

                  // ── Coach Opener (biography-aware greeting) ──
                  Builder(
                    builder: (ctx) {
                      final opener =
                          ctx.watch<ContextualCardProvider>().coachOpener;
                      if (opener.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: MintSpacing.xl),
                        child: Text(
                          opener,
                          style: MintTextStyles.headlineLarge(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),

                  // ── Section 0: Premier Éclairage (first visit only) ──
                  if (_shouldShowPremierEclairage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MintSpacing.xl),
                      child: PremierEclairageCard(
                        onDismiss: () async {
                          await ReportPersistenceService.markPremierEclairageSeen();
                          if (mounted) {
                            setState(() => _hasSeenPremierEclairage = true);
                          }
                        },
                        onNavigate: (route) {
                          ReportPersistenceService.markPremierEclairageSeen();
                          if (mounted) {
                            setState(() => _hasSeenPremierEclairage = true);
                            context.go(route);
                          }
                        },
                      ),
                    ),

                  // ── Unified Card Feed (CTX-01..05) ──
                  Builder(
                    builder: (ctx) {
                      final cardProvider =
                          ctx.watch<ContextualCardProvider>();
                      final anticipation =
                          ctx.watch<AnticipationProvider>();
                      final cards = cardProvider.visibleCards;
                      final overflowCard = cardProvider.overflowCard;

                      if (cards.isEmpty && overflowCard == null) {
                        // Empty state
                        final l = S.of(ctx)!;
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: MintSpacing.xl,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(MintSpacing.xl),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.wb_sunny_outlined,
                                    size: 48,
                                    // AESTH-05 per AUDIT_RETRAIT S2 (D-03 swap map)
                                    color: MintColors.textMutedAaa,
                                  ),
                                  const SizedBox(height: MintSpacing.md),
                                  Text(
                                    l.ctxEmptyHeading,
                                    style: MintTextStyles.titleMedium(),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: MintSpacing.sm),
                                  Text(
                                    l.ctxEmptyBody,
                                    style: MintTextStyles.bodyMedium(
                                      // AESTH-05 per AUDIT_RETRAIT S2 R2 (D-03 swap map)
                                      color: MintColors.textSecondaryAaa,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: MintSpacing.md),
                                  TextButton(
                                    onPressed: () =>
                                        ctx.push('/documents/scan'),
                                    child: Text(l.ctxEmptyCta),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          // Render each card by sealed type
                          for (int i = 0; i < cards.length; i++) ...[
                            MintEntrance(
                              delay: Duration(milliseconds: i * 100),
                              child: _buildCardWidget(
                                ctx,
                                cards[i],
                                anticipation,
                              ),
                            ),
                            const SizedBox(height: MintSpacing.xl),
                          ],

                          // Overflow section
                          if (overflowCard != null) ...[
                            ContextualOverflow(card: overflowCard),
                            const SizedBox(height: MintSpacing.xl),
                          ],
                        ],
                      );
                    },
                  ),

                  // ── Section 1b: Financial Plan Card (visible when a plan exists) ──
                  Builder(
                    builder: (ctx) {
                      final planProvider =
                          ctx.watch<FinancialPlanProvider>();
                      if (!planProvider.hasPlan) return const SizedBox.shrink();
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: MintSpacing.xl),
                        child: FinancialPlanCard(
                          plan: planProvider.currentPlan!,
                          isStale: planProvider.isPlanStale,
                          onRecalculate: (recalculatePrompt) {
                            widget.onSwitchToCoach?.call(
                              CoachEntryPayload(
                                source: CoachEntrySource.homeChip,
                                topic: 'recalculatePlan',
                                userMessage: recalculatePrompt,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  // ── Section 1c: Plan Reality + Streak (check-in section) ──
                  Builder(
                    builder: (ctx) {
                      final profileProvider =
                          ctx.watch<CoachProfileProvider>();
                      final profile = profileProvider.profile;
                      if (profile == null) return const SizedBox.shrink();

                      // Empty state: show CTA when user has a plan but no check-ins
                      if (profile.checkIns.isEmpty ||
                          profile.plannedContributions.isEmpty) {
                        final planProvider =
                            ctx.watch<FinancialPlanProvider>();
                        if (!planProvider.hasPlan) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: MintSpacing.xl),
                          child: FirstCheckInCtaCard(
                            onTap: () => widget.onSwitchToCoach?.call(
                              const CoachEntryPayload(
                                source: CoachEntrySource.homeChip,
                                topic: 'monthlyCheckIn',
                              ),
                            ),
                          ),
                        );
                      }

                      // Active state: PlanRealityCard with streak badge INSIDE header
                      final status = PlanTrackingService.evaluate(
                        checkIns: profile.checkIns,
                        contributions: profile.plannedContributions,
                      );
                      final streak = StreakService.compute(profile);
                      final birthYear =
                          profile.birthYear;
                      final monthsToRetirement =
                          ((birthYear + 65) - DateTime.now().year) * 12;
                      final impact = PlanTrackingService.compoundProjectedImpact(
                        status: status,
                        monthsToRetirement:
                            monthsToRetirement > 0 ? monthsToRetirement : 12,
                      );

                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: MintSpacing.xl),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: PlanRealityCard(
                            key: ValueKey(profile.checkIns.length),
                            status: status,
                            compoundImpact: impact,
                            monthsToRetirement:
                                monthsToRetirement > 0
                                    ? monthsToRetirement
                                    : 12,
                            streakBadge: StreakBadgeWidget(streak: streak),
                          ),
                        ),
                      );
                    },
                  ),

                  // -- Section 1d: Journey Steps (active CapSequence) --
                  Builder(
                    builder: (ctx) {
                      final seq = mintState.capSequencePlan;
                      if (seq == null || seq.isComplete || seq.currentStep == null) {
                        return const SizedBox.shrink();
                      }
                      // Only show when at least 1 step is incomplete
                      final hasIncomplete = seq.steps.any(
                        (s) => s.status != CapStepStatus.completed,
                      );
                      if (!hasIncomplete) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: MintSpacing.xl),
                        child: MintEntrance(
                          delay: const Duration(milliseconds: 200),
                          child: _JourneyStepsCard(sequence: seq),
                        ),
                      );
                    },
                  ),

                  // ── Section 2: Itinéraire Alternatif ──
                  if (_shouldShowLever(context, mintState))
                    Padding(
                      padding: const EdgeInsets.only(bottom: MintSpacing.xl),
                      child: _ItineraireAlternatifCard(
                        mintState: mintState,
                        onSimulate: () {
                          final route = mintState.currentCap?.ctaRoute;
                          if (route != null) {
                            GoRouter.of(context).push(route);
                          }
                        },
                        onTalk: () => widget.onSwitchToCoach?.call(
                          CoachEntryPayload(
                            source: CoachEntrySource.homeLever,
                            topic: mintState.currentCap?.id,
                            data: {
                              'capHeadline':
                                  mintState.currentCap?.headline ?? '',
                              'expectedImpact':
                                  mintState.currentCap?.expectedImpact ?? '',
                            },
                          ),
                        ),
                      ),
                    ),

                  // ── Section 4: Coach Input Bar ──
                  _CoachInputBar(
                    onSwitchToCoach: widget.onSwitchToCoach,
                  ),

                  const SizedBox(height: MintSpacing.xxl),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show lever only when user has a cap AND is not on their very first visit.
  bool _shouldShowLever(BuildContext context, MintUserState state) {
    if (!state.hasCap) return false;
    try {
      final activity = context.read<UserActivityProvider>();
      // Proxy for "not first visit": has explored at least 1 simulator or event.
      return activity.exploredSimulators.isNotEmpty ||
          activity.exploredLifeEvents.isNotEmpty;
    } catch (_) {
      // Provider not in tree (tests) — show lever if cap exists.
      return true;
    }
  }

  /// Dispatch a [ContextualCard] to its corresponding widget.
  ///
  /// Uses sealed class exhaustive switch for compile-time safety.
  Widget _buildCardWidget(
    BuildContext ctx,
    ContextualCard card,
    AnticipationProvider anticipation,
  ) {
    return switch (card) {
      ContextualHeroCard hero => HeroStatCard(
          card: hero,
          onTap: () => ctx.push(hero.route),
        ),
      ContextualAnticipationCard antic => AnticipationSignalCard(
          signal: antic.signal,
          onDismiss: () => anticipation.dismissSignal(antic.signal),
          onSnooze: () => anticipation.snoozeSignal(antic.signal),
        ),
      ContextualProgressCard progress => ProgressMilestoneCard(
          card: progress,
          onTap: () => ctx.push(progress.route),
        ),
      ContextualActionCard action => ActionOpportunityCard(
          card: action,
          onTap: () => ctx.push(action.route),
        ),
      ContextualOverflowCard overflow => ContextualOverflow(card: overflow),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SECTION 2 — Itinéraire Alternatif (Lever)
// ═══════════════════════════════════════════════════════════════════════════════

class _ItineraireAlternatifCard extends StatelessWidget {
  final MintUserState mintState;
  final VoidCallback onSimulate;
  final VoidCallback onTalk;

  const _ItineraireAlternatifCard({
    required this.mintState,
    required this.onSimulate,
    required this.onTalk,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final cap = mintState.currentCap!;

    return Container(
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.mintHomeAlternativeRoute,
            // AESTH-05 per AUDIT_RETRAIT S2 R4 (D-03 swap map)
            style: MintTextStyles.labelMedium(color: MintColors.textMutedAaa),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            cap.headline,
            style: MintTextStyles.titleMedium(),
          ),
          if (cap.expectedImpact != null) ...[
            const SizedBox(height: MintSpacing.xs),
            Text(
              cap.expectedImpact!,
              // AESTH-06 per AUDIT_RETRAIT S2 R6 (D-04 one-color-one-meaning:
              // success info-bearing text demoted to textSecondaryAaa)
              style: MintTextStyles.bodyMedium(color: MintColors.textSecondaryAaa),
            ),
          ],
          const SizedBox(height: MintSpacing.md),
          Row(
            children: [
              if (cap.ctaRoute != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSimulate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MintColors.textPrimary,
                      side: const BorderSide(color: MintColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: MintSpacing.sm + 4,
                      ),
                    ),
                    child: Text(
                      l10n.mintHomeSimulate,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              if (cap.ctaRoute != null) const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: onTalk,
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: MintSpacing.sm + 4,
                    ),
                  ),
                  child: Text(
                    l10n.mintHomeTalkAboutIt,
                    style: MintTextStyles.bodySmall(color: MintColors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SECTION 4 — Coach Input Bar
// ═══════════════════════════════════════════════════════════════════════════════

class _CoachInputBar extends StatefulWidget {
  final void Function(CoachEntryPayload? payload)? onSwitchToCoach;

  const _CoachInputBar({required this.onSwitchToCoach});

  @override
  State<_CoachInputBar> createState() => _CoachInputBarState();
}

class _CoachInputBarState extends State<_CoachInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      // Open coach with no specific payload.
      widget.onSwitchToCoach?.call(null);
      return;
    }

    widget.onSwitchToCoach?.call(
      CoachEntryPayload(
        source: CoachEntrySource.homeInput,
        userMessage: text,
      ),
    );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    // Contextual suggestion chips.
    final mintState = context.watch<MintStateProvider>().state;
    final chips = _buildChips(context, mintState, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Accroche phrase ──
        Text(
          l10n.mintHomeWhatscoming,
          // AESTH-05 per AUDIT_RETRAIT S2 R7 (D-03 swap map)
          style: MintTextStyles.titleMedium(color: MintColors.textMutedAaa),
        ),
        const SizedBox(height: MintSpacing.sm),

        // ── Text field ──
        Container(
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  textInputAction: TextInputAction.send,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.mintHomeAskQuestion,
                    hintStyle: MintTextStyles.bodyMedium(
                      // AESTH-05 per AUDIT_RETRAIT S2 (D-03 swap map)
                      color: MintColors.textMutedAaa,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.md,
                      vertical: MintSpacing.sm + 4,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: MintSpacing.sm),
                child: IconButton(
                  onPressed: _submit,
                  icon: const Icon(
                    Icons.arrow_upward_rounded,
                    color: MintColors.primary,
                    size: 22,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: MintColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size(36, 36),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Suggestion chips ──
        if (chips.isNotEmpty) ...[
          const SizedBox(height: MintSpacing.sm),
          Wrap(
            spacing: MintSpacing.sm,
            runSpacing: MintSpacing.xs,
            children: chips,
          ),
        ],
      ],
    );
  }

  /// Build up to 3 contextual suggestion chips based on user state.
  List<Widget> _buildChips(
    BuildContext context,
    MintUserState? state,
    S l10n,
  ) {
    if (state == null) return [];

    final chips = <_SuggestionChip>[];

    // Chip 1: If confidence is low, suggest improving data.
    if (state.confidenceScore < 60) {
      chips.add(_SuggestionChip(
        label: l10n.mintHomeConfidence,
        onTap: () => widget.onSwitchToCoach?.call(
          const CoachEntryPayload(
            source: CoachEntrySource.homeChip,
            topic: 'confidence',
          ),
        ),
      ));
    }

    // Chip 2: If there's a cap, surface its headline.
    if (state.hasCap && chips.length < 3) {
      chips.add(_SuggestionChip(
        label: state.currentCap!.headline,
        onTap: () => widget.onSwitchToCoach?.call(
          CoachEntryPayload(
            source: CoachEntrySource.homeChip,
            topic: state.currentCap!.id,
          ),
        ),
      ));
    }

    // Chip 3: If there's an inaction delta, nudge the user.
    if (state.hasSessionDelta &&
        state.sessionDelta!.cause == 'inaction' &&
        chips.length < 3) {
      chips.add(_SuggestionChip(
        label: l10n.mintHomeNoActionProjection,
        onTap: () => widget.onSwitchToCoach?.call(
          const CoachEntryPayload(
            source: CoachEntrySource.homeChip,
            topic: 'inaction',
          ),
        ),
      ));
    }

    return chips.take(3).toList();
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.sm + 4,
          vertical: MintSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Text(
          label,
          // AESTH-05 per AUDIT_RETRAIT S2 (D-03 swap map)
          style: MintTextStyles.labelMedium(color: MintColors.textSecondaryAaa),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SECTION 1d — Journey Steps Card (active CapSequence)
// ═══════════════════════════════════════════════════════════════════════════════

/// Compact card showing the user's current and next cap sequence step.
///
/// Only shown when [sequence] is not complete and has a current step.
/// Shows:
///   - Header: title + progress fraction + animated progress bar
///   - Current step row: play icon + title + CTA chip (navigates to intentTag)
///   - Next step row (optional): circle icon + muted "Ensuite : title"
class _JourneyStepsCard extends StatelessWidget {
  final CapSequence sequence;

  const _JourneyStepsCard({
    required this.sequence,
  });

  @override
  Widget build(BuildContext context) {
    if (sequence.isComplete || sequence.currentStep == null) {
      return const SizedBox.shrink();
    }

    final l = S.of(context)!;
    final current = sequence.currentStep!;
    final next = sequence.nextStep;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      elevated: false,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: title + fraction ──
          Row(
            children: [
              Expanded(
                child: Text(
                  l.homeJourneyTitle,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${sequence.completedCount}/${sequence.totalCount}',
                style:
                    // AESTH-05 per AUDIT_RETRAIT S2 (D-03 swap map)
                    MintTextStyles.labelSmall(color: MintColors.textSecondaryAaa),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs),

          // ── Progress bar ──
          AnimatedProgressBar(
            progress: sequence.progressPercent,
            color: MintColors.primary,
          ),
          const SizedBox(height: MintSpacing.md),

          // ── Current step row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Play icon
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: MintColors.primary,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 12,
                  color: MintColors.white,
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  _resolveTitle(l, current.titleKey),
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MintSpacing.xs),
              // CTA chip
              GestureDetector(
                onTap: current.intentTag != null
                    ? () => context.go(current.intentTag!)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MintSpacing.sm,
                    vertical: MintSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: MintColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.homeJourneyNextStep,
                    style: MintTextStyles.labelSmall(color: MintColors.white),
                  ),
                ),
              ),
            ],
          ),

          // ── Next step row (muted) ──
          if (next != null) ...[
            const SizedBox(height: MintSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Empty circle icon
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MintColors.border,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${l.homeJourneyUpcoming}\u00a0:\u00a0',
                          style: MintTextStyles.bodySmall(
                            // AESTH-05 per AUDIT_RETRAIT S2 (D-03 swap map)
                            color: MintColors.textMutedAaa,
                          ),
                        ),
                        TextSpan(
                          text: _resolveTitle(l, next.titleKey),
                          style: MintTextStyles.bodySmall(
                            // AESTH-05 per AUDIT_RETRAIT S2 (D-03 swap map)
                            color: MintColors.textMutedAaa,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Resolve an ARB key string to a translated title.
  ///
  /// Covers all cap step title keys from Retirement, Budget, Housing,
  /// FirstJob, and NewJob sequences.
  String _resolveTitle(S l, String key) {
    return switch (key) {
      'capStepRetirement01Title' => l.capStepRetirement01Title,
      'capStepRetirement02Title' => l.capStepRetirement02Title,
      'capStepRetirement03Title' => l.capStepRetirement03Title,
      'capStepRetirement04Title' => l.capStepRetirement04Title,
      'capStepRetirement05Title' => l.capStepRetirement05Title,
      'capStepRetirement06Title' => l.capStepRetirement06Title,
      'capStepRetirement07Title' => l.capStepRetirement07Title,
      'capStepRetirement08Title' => l.capStepRetirement08Title,
      'capStepRetirement09Title' => l.capStepRetirement09Title,
      'capStepRetirement10Title' => l.capStepRetirement10Title,
      'capStepBudget01Title' => l.capStepBudget01Title,
      'capStepBudget02Title' => l.capStepBudget02Title,
      'capStepBudget03Title' => l.capStepBudget03Title,
      'capStepBudget04Title' => l.capStepBudget04Title,
      'capStepBudget05Title' => l.capStepBudget05Title,
      'capStepBudget06Title' => l.capStepBudget06Title,
      'capStepHousing01Title' => l.capStepHousing01Title,
      'capStepHousing02Title' => l.capStepHousing02Title,
      'capStepHousing03Title' => l.capStepHousing03Title,
      'capStepHousing04Title' => l.capStepHousing04Title,
      'capStepHousing05Title' => l.capStepHousing05Title,
      'capStepHousing06Title' => l.capStepHousing06Title,
      'capStepHousing07Title' => l.capStepHousing07Title,
      'capStepFirstJob01Title' => l.capStepFirstJob01Title,
      'capStepFirstJob02Title' => l.capStepFirstJob02Title,
      'capStepFirstJob03Title' => l.capStepFirstJob03Title,
      'capStepFirstJob04Title' => l.capStepFirstJob04Title,
      'capStepFirstJob05Title' => l.capStepFirstJob05Title,
      'capStepNewJob01Title' => l.capStepNewJob01Title,
      'capStepNewJob02Title' => l.capStepNewJob02Title,
      'capStepNewJob03Title' => l.capStepNewJob03Title,
      'capStepNewJob04Title' => l.capStepNewJob04Title,
      'capStepNewJob05Title' => l.capStepNewJob05Title,
      _ => key, // Fallback: show key (should never happen in production)
    };
  }
}

