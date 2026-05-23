import 'package:flutter/foundation.dart';

/// Arguments passed via `GoRouterState.extra` when the sub-phase 01.5
/// hard gate routes a user to /waitlist. Constructed at the gate
/// insertion site (apps/mobile/lib/screens/coach/coach_chat_screen.dart,
/// wired in plan 02-03 Task 4) and at the GoRoute registration in
/// app.dart (plan 02-03 Task 3). Consumed by [WaitlistScreen] +
/// [WaitlistProvider].
///
/// Lives in this plan (02-02), NOT plan 02-03, because the WaitlistScreen
/// constructor accepts a WaitlistArgs — keeping the class colocated with
/// the consumer avoids a forward-reference where the screen would depend
/// on a class defined in a downstream plan (B1 fix, 2026-05-22).
@immutable
class WaitlistArgs {
  const WaitlistArgs({
    this.archetype,
    this.source = 'onboarding_hard_gate',
  });

  /// snake_case archetype slug ('expat_us', 'cross_border', etc.) or null
  /// if archetype is `FinancialArchetype.unknown` / not yet computable.
  /// Null falls back to 'other' at submit time.
  final String? archetype;

  /// Source tag for waitlist analytics. Defaults to 'onboarding_hard_gate'.
  final String source;
}
