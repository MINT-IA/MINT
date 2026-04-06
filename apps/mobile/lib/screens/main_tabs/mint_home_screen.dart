/// MintHomeScreen — Tab 0 "Aujourd'hui" (Wire Spec V2).
///
/// Replaces PulseScreen as the landing tab. Shows:
///   1. Chiffre Vivant GPS — retirement countdown + estimated income + delta
///   2. Itinéraire Alternatif — top cap recommendation (lever)
///   3. Signal Proactif — most important pending signal
///   4. Coach Input Bar — always-visible text entry to coach
///
/// Design: ONE card + ONE lever + ONE signal + ONE input bar.
/// Maximum 4 elements in a vertical scroll. No dashboard layout.
///
/// See: docs/WIRE_SPEC_V2.md §3
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/providers/anticipation_provider.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/session_snapshot_service.dart';
import 'package:mint_mobile/services/streak_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/mint_motion.dart';
import 'package:mint_mobile/widgets/coach/animated_progress_bar.dart';
import 'package:mint_mobile/widgets/coach/first_check_in_cta_card.dart';
import 'package:mint_mobile/widgets/coach/plan_reality_card.dart';
import 'package:mint_mobile/widgets/coach/streak_badge.dart';
import 'package:mint_mobile/widgets/home/anticipation_signal_card.dart';
import 'package:mint_mobile/widgets/home/confidence_score_card.dart';
import 'package:mint_mobile/widgets/home/financial_plan_card.dart';
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
    // Evaluate anticipation triggers once per session (CTX-02)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<CoachProfileProvider>().profile;
      final facts = context.read<BiographyProvider>().facts;
      if (profile != null) {
        context.read<AnticipationProvider>().evaluateOnSessionStart(
              profile: profile,
              facts: facts,
            );
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
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: MintSpacing.md),

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

                  // ── Section 1: Chiffre Vivant GPS Card ──
                  _ChiffreVivantCard(
                    mintState: mintState,
                    onTap: () => widget.onSwitchToCoach?.call(
                      CoachEntryPayload(
                        source: CoachEntrySource.homeChiffre,
                        topic: 'retirementGap',
                        data: {
                          'value':
                              mintState.budgetGap?.totalRevenusMensuel ?? 0,
                          'confidence': mintState.confidenceScore,
                          if (mintState.sessionDelta != null)
                            'delta':
                                mintState.sessionDelta!.retirementIncomeDelta,
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: MintSpacing.xl),

                  // ── Section 1a: Anticipation Signals (max 2 cards) ──
                  Builder(
                    builder: (ctx) {
                      final anticipation =
                          ctx.watch<AnticipationProvider>();
                      if (!anticipation.hasSignals) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          ...anticipation.visibleSignals.map(
                            (signal) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: MintSpacing.md,
                              ),
                              child: MintEntrance(
                                delay: const Duration(milliseconds: 200),
                                child: AnticipationSignalCard(
                                  signal: signal,
                                  onDismiss: () =>
                                      anticipation.dismissSignal(signal),
                                  onSnooze: () =>
                                      anticipation.snoozeSignal(signal),
                                ),
                              ),
                            ),
                          ),
                          if (anticipation.hasOverflow)
                            _AnticipationOverflow(
                              signals: anticipation.overflowSignals,
                              onDismiss: anticipation.dismissSignal,
                              onSnooze: anticipation.snoozeSignal,
                            ),
                          const SizedBox(height: MintSpacing.xl),
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

                  // ── Section 1b2: Confidence Score ──
                  Builder(
                    builder: (ctx) {
                      final profile =
                          ctx.watch<CoachProfileProvider>().profile;
                      if (profile == null) return const SizedBox.shrink();
                      final enhanced =
                          ConfidenceScorer.scoreEnhanced(profile);
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: MintSpacing.xl),
                        child: MintEntrance(
                          delay: const Duration(milliseconds: 150),
                          child: ConfidenceScoreCard(
                            score: enhanced.combined,
                            enrichmentPrompts: enhanced.axisPrompts,
                            onEnrichmentTap: () => context
                                .push('/onboarding/quick?section=profile'),
                          ),
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

                  // ── Section 3: Signal Proactif + Radar (animated swap) ──
                  Builder(
                    builder: (ctx) {
                      final l = S.of(ctx)!;
                      final disableAnimations =
                          MediaQuery.of(ctx).disableAnimations;

                      // Determine current signal card
                      Widget? signalCard;
                      if (_hasSignal(mintState)) {
                        signalCard = _SignalProactifCard(
                          key: const ValueKey('signal_proactif'),
                          mintState: mintState,
                          onTap: () => widget.onSwitchToCoach?.call(
                            CoachEntryPayload(
                              source: CoachEntrySource.signal,
                              topic: mintState.pendingTrigger?.intentTag ??
                                  (mintState.activeNudges.isNotEmpty
                                      ? mintState.activeNudges.first.intentTag
                                      : null),
                            ),
                          ),
                        );
                      } else if (_shouldShowRadar(ctx, mintState)) {
                        signalCard = _RadarAnticipateCard(
                          key: const ValueKey('radar_anticipate'),
                          profile: mintState.profile,
                          onSwitchToCoach: widget.onSwitchToCoach,
                        );
                      }

                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: MintSpacing.xl),
                        child: AnimatedSwitcher(
                          duration: disableAnimations
                              ? Duration.zero
                              : MintMotion.standard,
                          reverseDuration: disableAnimations
                              ? Duration.zero
                              : MintMotion.fast,
                          switchInCurve: MintMotion.curveEnter,
                          switchOutCurve: MintMotion.curveExit,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                          child: signalCard ??
                              _EmptySignalState(
                                key: const ValueKey('empty_signal'),
                                label: l.homeSignalEmptyState,
                              ),
                        ),
                      );
                    },
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

  bool _hasSignal(MintUserState state) {
    return state.hasPendingTrigger || state.hasNudges;
  }

  /// Show radar only for returning users with a valid birth year.
  bool _shouldShowRadar(BuildContext context, MintUserState state) {
    if (state.profile.birthYear <= 0) return false;
    try {
      final activity = context.read<UserActivityProvider>();
      return activity.exploredSimulators.isNotEmpty ||
          activity.exploredLifeEvents.isNotEmpty;
    } catch (_) {
      return true;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  EMPTY SIGNAL STATE — shown when no signal card is active
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptySignalState extends StatelessWidget {
  final String label;

  const _EmptySignalState({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        label,
        style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SECTION 1 — Chiffre Vivant GPS Card
// ═══════════════════════════════════════════════════════════════════════════════

class _ChiffreVivantCard extends StatelessWidget {
  final MintUserState mintState;
  final VoidCallback onTap;

  const _ChiffreVivantCard({
    required this.mintState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final profile = mintState.profile;
    final age = profile.age;
    final retirementAge = profile.effectiveRetirementAge;

    // Compute years/months to retirement.
    // CoachProfile.age returns 0 when birthYear is invalid/missing.
    final yearsToRetirement = (age > 0) ? retirementAge - age : null;
    final monthsRemaining = (yearsToRetirement != null && yearsToRetirement > 0)
        ? (yearsToRetirement * 12) % 12
        : 0;
    final fullYears = yearsToRetirement ?? 0;

    // Progress bar: fraction of life toward retirement.
    final progress =
        (age > 0) ? (age / retirementAge).clamp(0.0, 1.0) : 0.0;

    // Retirement income.
    final monthlyIncome = mintState.budgetGap?.totalRevenusMensuel;

    // Format number Swiss style: 4'216
    String formatChf(double value) {
      final formatter = NumberFormat("#'###", 'fr_CH');
      return formatter.format(value.round());
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: MintColors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Countdown header ──
            if (yearsToRetirement != null && yearsToRetirement > 0) ...[
              Text(
                l10n.mintHomeRetirementIn.toUpperCase(),
                style: MintTextStyles.labelMedium(
                  color: MintColors.textMuted,
                ),
              ),
              const SizedBox(height: MintSpacing.xs),
              Text(
                l10n.mintHomeYearsMonths(
                  fullYears.toString(),
                  monthsRemaining.toString(),
                ),
                style: MintTextStyles.headlineMedium(),
              ),
              const SizedBox(height: MintSpacing.md),

              // ── Progress bar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: MintColors.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    MintColors.ardoise,
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.lg),
            ],

            // ── Estimated monthly income ──
            Text(
              l10n.mintHomeEstimatedIncome,
              style: MintTextStyles.bodyMedium(),
            ),
            const SizedBox(height: MintSpacing.sm),
            if (monthlyIncome != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${formatChf(monthlyIncome)} CHF",
                    style: MintTextStyles.displayLarge(),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.perMonth,
                      style: MintTextStyles.bodyLarge(
                        color: MintColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                '---',
                style: MintTextStyles.displayLarge(
                  color: MintColors.textMuted,
                ),
              ),
            ],

            // ── Delta since last visit ──
            if (mintState.hasSessionDelta) ...[
              const SizedBox(height: MintSpacing.md),
              _DeltaChip(delta: mintState.sessionDelta!),
            ],

            const SizedBox(height: MintSpacing.lg),

            // ── Confidence bar ──
            _ConfidenceBar(score: mintState.confidenceScore, l10n: l10n),
          ],
        ),
      ),
    );
  }
}

// ── Delta Chip ──────────────────────────────────────────────────────────────

class _DeltaChip extends StatelessWidget {
  final SessionDelta delta;

  const _DeltaChip({required this.delta});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final sign = delta.retirementIncomeDelta >= 0 ? '+' : '';
    final deltaText = l10n.deltaChfPerMonth(sign, delta.retirementIncomeDelta.round().toString());

    final causeColor = switch (delta.cause) {
      'user_action' => MintColors.saugeClaire,
      'macro' => MintColors.ardoise,
      _ => MintColors.corailDiscret,
    };

    // Background: lighter version of the cause color.
    final bgColor = switch (delta.cause) {
      'user_action' => MintColors.saugeClaire.withValues(alpha: 0.3),
      'macro' => MintColors.ardoise.withValues(alpha: 0.1),
      _ => MintColors.corailDiscret.withValues(alpha: 0.15),
    };

    // Text color: ensure readability.
    final textColor = switch (delta.cause) {
      'user_action' => MintColors.accent,
      'macro' => MintColors.ardoise,
      _ => MintColors.corailDiscret,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.sm + 4,
        vertical: MintSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: causeColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        deltaText,
        style: MintTextStyles.labelMedium(color: textColor),
      ),
    );
  }
}

// ── Confidence Bar ──────────────────────────────────────────────────────────

class _ConfidenceBar extends StatelessWidget {
  final double score;
  final S l10n;

  const _ConfidenceBar({required this.score, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final percentage = score.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.mintHomeConfidence,
              style: MintTextStyles.labelMedium(),
            ),
            Text(
              '$percentage\u00a0%',
              style: MintTextStyles.labelMedium(
                color: MintColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: MintColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(
              score >= 70
                  ? MintColors.success
                  : score >= 45
                      ? MintColors.warning
                      : MintColors.corailDiscret,
            ),
          ),
        ),
      ],
    );
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
            style: MintTextStyles.labelMedium(color: MintColors.textMuted),
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
              style: MintTextStyles.bodyMedium(color: MintColors.success),
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
//  SECTION 3 — Signal Proactif
// ═══════════════════════════════════════════════════════════════════════════════

class _SignalProactifCard extends StatelessWidget {
  final MintUserState mintState;
  final VoidCallback onTap;

  const _SignalProactifCard({
    super.key,
    required this.mintState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    // Determine title and body from trigger or nudge.
    final trigger = mintState.pendingTrigger;
    final nudge =
        mintState.activeNudges.isNotEmpty ? mintState.activeNudges.first : null;

    // Prefer trigger; fallback to nudge.
    final String title;
    final String? body;

    if (trigger != null) {
      // ProactiveTrigger uses messageKey as ARB key.
      title = trigger.messageKey;
      body = null;
    } else if (nudge != null) {
      title = nudge.titleKey;
      body = nudge.bodyKey;
    } else {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.craie,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: MintColors.pecheDouce.withValues(alpha: 0.5),
          ),
        ),
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: MintColors.pecheDouce.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: MintColors.corailDiscret,
              ),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.mintHomeSignal,
                    style: MintTextStyles.labelMedium(
                      color: MintColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: MintTextStyles.labelSmall(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: MintColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SECTION 3b — Radar Anticipatoire
// ═══════════════════════════════════════════════════════════════════════════════

/// A simple data class for upcoming financial events.
class _UpcomingEvent {
  final String title;
  final String description;
  final int monthsAway;
  final String? route;

  const _UpcomingEvent({
    required this.title,
    required this.description,
    required this.monthsAway,
    this.route,
  });
}

/// Shows the single most imminent financial event computed from profile data.
class _RadarAnticipateCard extends StatelessWidget {
  final CoachProfile profile;
  final void Function(CoachEntryPayload?)? onSwitchToCoach;

  const _RadarAnticipateCard({
    super.key,
    required this.profile,
    this.onSwitchToCoach,
  });

  List<_UpcomingEvent> _computeEvents(S l10n) {
    final events = <_UpcomingEvent>[];
    final now = DateTime.now();
    final age = profile.age;
    if (age <= 0) return events;

    final retirementAge = profile.effectiveRetirementAge;

    // ── Next age milestone ──
    const milestones = [25, 35, 45, 50, 55, 60, 65];
    for (final m in milestones) {
      if (age < m && m <= retirementAge) {
        final yearsUntil = m - age;
        final monthsUntil = yearsUntil * 12 - now.month;
        final description = switch (m) {
          50 => l10n.mintHomeRadarMilestone50,
          55 => l10n.mintHomeRadarMilestone55,
          60 => l10n.mintHomeRadarMilestone60,
          65 => l10n.mintHomeRadarMilestone65,
          _ => '',
        };
        if (description.isNotEmpty) {
          events.add(_UpcomingEvent(
            title: l10n.ageYears(m.toString()),
            description: description,
            monthsAway: monthsUntil.clamp(1, 9999),
            route: m >= 55 ? '/retraite' : null,
          ));
        }
        break; // Only show next milestone
      }
    }

    // ── 3a deadline (Dec 31) ──
    final daysUntil3a = DateTime(now.year, 12, 31).difference(now).inDays;
    if (daysUntil3a > 0 && daysUntil3a < 300) {
      events.add(_UpcomingEvent(
        title: l10n.mintHomeRadar3aDeadline(now.year.toString()),
        description: l10n.mintHomeRadarDaysLeft(daysUntil3a.toString()),
        monthsAway: (daysUntil3a / 30).round().clamp(1, 12),
        route: '/pilier-3a',
      ));
    }

    events.sort((a, b) => a.monthsAway.compareTo(b.monthsAway));
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final events = _computeEvents(l10n);
    if (events.isEmpty) return const SizedBox.shrink();

    // Show only the closest event.
    final event = events.first;

    return Container(
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.radar_rounded,
              size: 20,
              color: MintColors.info,
            ),
          ),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.mintHomeRadarTitle.toUpperCase(),
                  style: MintTextStyles.labelMedium(
                    color: MintColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.title,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.mintHomeRadarIn(event.monthsAway.toString())} — ${event.description}',
                  style: MintTextStyles.labelSmall(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (event.route != null)
            GestureDetector(
              onTap: () {
                if (event.route != null) {
                  GoRouter.of(context).push(event.route!);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.sm + 2,
                  vertical: MintSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MintColors.lightBorder),
                ),
                child: Text(
                  l10n.mintHomeRadarPrepare,
                  style: MintTextStyles.labelMedium(
                    color: MintColors.textSecondary,
                  ),
                ),
              ),
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
          style: MintTextStyles.titleMedium(color: MintColors.textMuted),
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
                      color: MintColors.textMuted,
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
          style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
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
    super.key,
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
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
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
                            color: MintColors.textMuted,
                          ),
                        ),
                        TextSpan(
                          text: _resolveTitle(l, next.titleKey),
                          style: MintTextStyles.bodySmall(
                            color: MintColors.textMuted,
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

// ────────────────────────────────────────────────────────────
//  Anticipation Overflow — expandable section for extra signals
// ────────────────────────────────────────────────────────────

class _AnticipationOverflow extends StatelessWidget {
  final List<AnticipationSignal> signals;
  final void Function(AnticipationSignal) onDismiss;
  final void Function(AnticipationSignal) onSnooze;

  const _AnticipationOverflow({
    required this.signals,
    required this.onDismiss,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(
        l.anticipationOverflowTitle(signals.length.toString()),
        style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
      ),
      children: signals
          .map(
            (signal) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm),
              child: AnticipationSignalCard(
                signal: signal,
                onDismiss: () => onDismiss(signal),
                onSnooze: () => onSnooze(signal),
              ),
            ),
          )
          .toList(),
    );
  }
}
