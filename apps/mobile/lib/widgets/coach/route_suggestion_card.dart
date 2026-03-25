/// RouteSuggestionCard — coach-originated navigation proposal card.
///
/// Rendered when Claude returns a `route_to_screen` tool_use block and the
/// [RoutePlanner] resolves to [RouteAction.openScreen] or
/// [RouteAction.openWithWarning].
///
/// Design contract (MINT_UX_GRAAL_MASTERPLAN.md):
/// - The coach PROPOSES, the user DECIDES. No automatic push.
/// - Single CTA button — user must tap to navigate.
/// - Warning banner shown when readiness is partial.
/// - All text via AppLocalizations (zero hardcoded strings).
/// - MintColors, MintTextStyles, MintSpacing only — no hardcoded hex.
///
/// ReturnContract V2 (S58):
/// - [onReturn] receives a [ScreenOutcome] distinguishing completed /
///   abandoned / changedInputs so the parent chat can react differently.
/// - Outcome detection heuristic: time-on-screen < 5 s → abandoned;
///   profile hash changed → changedInputs; otherwise → completed.
///
/// See docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §7
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/models/screen_return.dart' show ScreenOutcome;
import 'package:mint_mobile/widgets/coach/chat_card_entrance.dart';
export 'package:mint_mobile/models/screen_return.dart' show ScreenOutcome;

// ════════════════════════════════════════════════════════════════
//  ROUTE SUGGESTION CARD
// ════════════════════════════════════════════════════════════════

/// A card rendered in the coach chat when Claude suggests navigating to a
/// screen.
///
/// Parameters:
/// - [contextMessage]  — the coach's explanation from the LLM response.
/// - [route]           — the GoRouter route to push on CTA tap.
/// - [isPartial]       — when true, shows the "incomplete data" warning banner.
/// - [onReturn]        — called after the user returns from the target screen,
///                       with a [ScreenOutcome] value (ReturnContract V2).
/// - [profileHashFn]   — optional function returning a hash/stamp of the
///                       current profile state; used to detect [changedInputs].
///                       Defaults to null (no change detection).
///
/// Usage:
/// ```dart
/// RouteSuggestionCard(
///   contextMessage: 'Voici ton simulateur rente vs capital.',
///   route: '/rente-vs-capital',
///   isPartial: true,
///   onReturn: (outcome) { /* react to outcome */ },
///   profileHashFn: () => profileProvider.profile.hashCode.toString(),
/// )
/// ```
class RouteSuggestionCard extends StatelessWidget {
  /// The coach's narrative message explaining why this screen is relevant.
  final String contextMessage;

  /// The canonical GoRouter route to navigate to on CTA tap.
  final String route;

  /// When true, renders a yellow warning banner ("Estimation — données
  /// incomplètes") to inform the user that some data is missing.
  final bool isPartial;

  /// Prefill values extracted from the user's profile by [RoutePlanner].
  ///
  /// Passed to the target screen via GoRouter `extra` so the screen can
  /// pre-populate fields with known data instead of showing defaults.
  /// Screens opt in by reading `GoRouterState.of(context).extra`.
  final Map<String, dynamic>? prefill;

  /// Called after [context.push(route)] completes (i.e. user comes back).
  ///
  /// Receives a [ScreenOutcome] so the parent can react differently to
  /// completed / abandoned / changedInputs (ReturnContract V2).
  final void Function(ScreenOutcome outcome)? onReturn;

  /// Optional function returning a snapshot of the current profile state.
  ///
  /// When provided, the card captures the value before navigation and
  /// compares it on return to decide between [ScreenOutcome.completed] and
  /// [ScreenOutcome.changedInputs].
  final String Function()? profileHashFn;

  const RouteSuggestionCard({
    super.key,
    required this.contextMessage,
    required this.route,
    this.isPartial = false,
    this.prefill,
    this.onReturn,
    this.profileHashFn,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return ChatCardEntrance(
      child: Container(
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.coachAccent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Partial-readiness warning banner ─────────────────────
          if (isPartial) _PartialWarningBanner(label: s.routeSuggestionPartialWarning),

          // ── Context message ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MintSpacing.md,
              MintSpacing.md,
              MintSpacing.md,
              MintSpacing.sm,
            ),
            child: Text(
              contextMessage,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
          ),

          // ── CTA row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MintSpacing.md,
              0,
              MintSpacing.md,
              MintSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: _CtaButton(
                label: s.routeSuggestionCta,
                onTap: () => _navigateAndReturn(context),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _navigateAndReturn(BuildContext context) async {
    // Snapshot profile state and wall-clock time before navigation.
    final hashBefore = profileHashFn?.call();
    final entryTime = DateTime.now();

    // Derive a screen ID from the route by stripping leading slash and
    // replacing non-alphanumeric characters with underscores.
    final screenId =
        route.replaceAll(RegExp(r'^/'), '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    // Navigate — context.push awaited synchronously. Any async work involving
    // ScreenCompletionTracker happens after the mounted check below so that
    // context is never accessed across an async gap.
    // Pass prefill data via `extra` so the target screen can pre-populate
    // fields with known profile values (screens opt in by reading extra).
    final extra = prefill != null ? {'prefill': prefill} : null;
    await context.push(route, extra: extra); // ignore: use_build_context_synchronously — guarded by mounted check immediately below

    if (!context.mounted) return;

    final elapsed = DateTime.now().difference(entryTime);
    final hashAfter = profileHashFn?.call();

    // Resolve heuristic outcome first.
    ScreenOutcome outcome = resolveOutcome(
      elapsed: elapsed,
      hashBefore: hashBefore,
      hashAfter: hashAfter,
    );

    // Enrich: if the screen explicitly reported a completion via
    // ScreenCompletionTracker, prefer that signal over the heuristic —
    // but only when the heuristic did not already detect changedInputs
    // (explicit input changes take priority over a generic "completed").
    if (outcome != ScreenOutcome.changedInputs) {
      final tracked = await ScreenCompletionTracker.lastOutcome(screenId);
      if (tracked != null) {
        outcome = tracked;
      }
    }

    onReturn?.call(outcome);
  }

  /// Determine the [ScreenOutcome] from elapsed time and profile hash delta.
  ///
  /// Rules (ReturnContract V2):
  /// - < 5 s on screen → [ScreenOutcome.abandoned] (quick bounce)
  /// - ≥ 5 s + profile hash changed → [ScreenOutcome.changedInputs]
  /// - ≥ 5 s + no change (or no hash fn) → [ScreenOutcome.completed]
  ///
  /// Exposed as public static for unit-testing the resolution logic in
  /// isolation (widget tests cannot advance `DateTime.now()`).
  static ScreenOutcome resolveOutcome({
    required Duration elapsed,
    required String? hashBefore,
    required String? hashAfter,
  }) {
    const abandonThreshold = Duration(seconds: 5);
    if (elapsed < abandonThreshold) return ScreenOutcome.abandoned;
    if (hashBefore != null && hashAfter != null && hashBefore != hashAfter) {
      return ScreenOutcome.changedInputs;
    }
    return ScreenOutcome.completed;
  }
}

// ════════════════════════════════════════════════════════════════
//  PRIVATE HELPERS
// ════════════════════════════════════════════════════════════════

/// Yellow warning banner shown when readiness is partial.
class _PartialWarningBanner extends StatelessWidget {
  final String label;
  const _PartialWarningBanner({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.md,
        vertical: MintSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: MintColors.warningBgWarm,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: MintColors.warning.withValues(alpha: 0.9),
          ),
          const SizedBox(width: MintSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.labelSmall(
                color: MintColors.warning.withValues(alpha: 0.9),
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filled CTA button for the navigation action.
class _CtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CtaButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: MintColors.coachAccent,
        foregroundColor: MintColors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.md,
          vertical: MintSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        textStyle: MintTextStyles.labelSmall(color: MintColors.white)
            .copyWith(fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.arrow_forward, size: 16),
      label: Text(label),
    );
  }
}
