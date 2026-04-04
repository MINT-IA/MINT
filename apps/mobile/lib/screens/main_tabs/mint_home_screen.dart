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
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/services/session_snapshot_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// The new Tab 0 — "Aujourd'hui".
///
/// Reads reactively from [MintStateProvider] via `context.watch`.
/// When [MintUserState] is null (loading), shows a centered spinner.
class MintHomeScreen extends StatelessWidget {
  /// Callback to switch the parent [MainNavigationShell] to the coach tab.
  /// Receives the [CoachEntryPayload] to pass as context.
  final void Function(CoachEntryPayload? payload)? onSwitchToCoach;

  const MintHomeScreen({super.key, this.onSwitchToCoach});

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
                  const SizedBox(height: MintSpacing.lg),

                  // ── Section 1: Chiffre Vivant GPS Card ──
                  _ChiffreVivantCard(
                    mintState: mintState,
                    onTap: () => onSwitchToCoach?.call(
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
                        onTalk: () => onSwitchToCoach?.call(
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

                  // ── Section 3: Signal Proactif ──
                  if (_hasSignal(mintState))
                    Padding(
                      padding: const EdgeInsets.only(bottom: MintSpacing.xl),
                      child: _SignalProactifCard(
                        mintState: mintState,
                        onTap: () => onSwitchToCoach?.call(
                          CoachEntryPayload(
                            source: CoachEntrySource.signal,
                            topic: mintState.pendingTrigger?.intentTag ??
                                (mintState.activeNudges.isNotEmpty
                                    ? mintState.activeNudges.first.intentTag
                                    : null),
                          ),
                        ),
                      ),
                    ),

                  // ── Section 4: Coach Input Bar ──
                  _CoachInputBar(
                    onSwitchToCoach: onSwitchToCoach,
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
                      '/mois',
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
    final sign = delta.retirementIncomeDelta >= 0 ? '+' : '';
    final deltaText = '$sign${delta.retirementIncomeDelta.round()} CHF/mois';

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
