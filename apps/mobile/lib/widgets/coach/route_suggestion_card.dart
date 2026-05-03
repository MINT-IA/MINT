/// RouteSuggestionCard — coach-originated navigation proposal card.
///
/// Rendered when Claude returns a `route_to_screen` tool_use block.
///
/// Design contract (MINT_UX_GRAAL_MASTERPLAN.md):
/// - The coach PROPOSES, the user DECIDES. No automatic push.
/// - Single CTA button — user must tap to navigate.
/// - Warning banner shown when readiness is partial.
/// - All text via AppLocalizations (zero hardcoded strings).
/// - MintColors, MintTextStyles, MintSpacing only — no hardcoded hex.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/sequence/sequence_chat_handler.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ════════════════════════════════════════════════════════════════
//  NAV LOCK — Phase 54-02 T-05
// ════════════════════════════════════════════════════════════════

/// Process-wide debounce that swallows duplicate navigation pushes from
/// `RouteSuggestionCard` taps within a 500 ms window.
///
/// Two regression classes are mitigated:
///   1. Rapid double-tap on the same chip (Material's button handles a
///      single press but the user can fire two presses in <50 ms).
///   2. A chip tap racing with an LLM-emitted `route_to_screen` tool path
///      that targets the same surface in the same response burst —
///      e.g. proactive trigger chip and a sequence-handler push that
///      both want `/retraite`.
class RouteSuggestionNavLock {
  RouteSuggestionNavLock._();

  static const Duration window = Duration(milliseconds: 500);

  static DateTime? _lastFiredAt;

  /// Try to acquire the lock. Returns `true` exactly once per [window];
  /// any subsequent call within [window] returns `false` (the caller
  /// must skip its `context.push`).
  static bool tryAcquire({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final last = _lastFiredAt;
    if (last != null && reference.difference(last) < window) {
      return false;
    }
    _lastFiredAt = reference;
    return true;
  }

  /// Test-only reset. Production code never resets the lock.
  @visibleForTesting
  static void resetForTest() {
    _lastFiredAt = null;
  }
}

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
/// - [prefill]         — optional data to pass as GoRouter extra when navigating.
class RouteSuggestionCard extends StatelessWidget {
  final String contextMessage;
  final String route;
  final bool isPartial;
  final Map<String, dynamic>? prefill;

  /// Phase 53-02 — when non-null, the LLM-emitted intent tag for this
  /// route suggestion. If a [SequenceTemplate] is keyed by this intent
  /// (`SequenceTemplate.templateForIntent`), tapping the CTA fires
  /// `SequenceChatHandler.startSequence(intentTag)` BEFORE the route
  /// push so the coach screen-return handler can subsequently dispatch
  /// through `handleRealtimeReturn` to advance the sequence.
  ///
  /// When null, behavior is unchanged: a normal `context.push(route)`
  /// happens with no sequence side-effect.
  final String? intentTag;

  const RouteSuggestionCard({
    super.key,
    required this.contextMessage,
    required this.route,
    this.isPartial = false,
    this.prefill,
    this.intentTag,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(MintSpacing.sm),
        border: Border.all(color: MintColors.border),
      ),
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPartial) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.sm,
                vertical: MintSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: MintColors.warningBg,
                borderRadius: BorderRadius.circular(MintSpacing.xs),
              ),
              child: Text(
                s?.routeSuggestionPartialWarning ??
                    'Donn\u00e9es incompl\u00e8tes \u2014 les r\u00e9sultats seront estim\u00e9s',
                style: MintTextStyles.labelSmall(color: MintColors.warning),
              ),
            ),
            const SizedBox(height: MintSpacing.sm),
          ],
          if (contextMessage.isNotEmpty) ...[
            Text(
              contextMessage,
              style: MintTextStyles.bodyMedium(),
            ),
            const SizedBox(height: MintSpacing.sm),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                // Phase 54-02 T-05 — single 500 ms debounce across all
                // RouteSuggestionCard taps + LLM-emitted route_to_screen
                // dispatch. Drop the duplicate without side-effects so
                // the SequenceStore write (which is idempotent on
                // intentTag) doesn't fire twice either.
                if (!RouteSuggestionNavLock.tryAcquire()) return;
                // Phase 53-02 — if an intentTag is provided AND it maps to
                // a SequenceTemplate, start the sequence before pushing.
                // Fire-and-forget: SequenceStore writes don't block nav,
                // and the screen-return handler reads from the store on
                // its own asynchronous timeline. Failure is silent (no
                // template match returns null with no side-effect).
                if (intentTag != null && intentTag!.isNotEmpty) {
                  unawaited(SequenceChatHandler.startSequence(intentTag!));
                }
                context.push(route, extra: prefill);
              },
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
              ),
              child: Text(
                s?.routeSuggestionCta ?? 'Voir',
                style: MintTextStyles.bodyMedium(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
