/// Global archetype redirect gate — plan mint-illogism-fixes-08 W2 Task 1.
///
/// Closes oracle expat_us-1 (ILLOGICAL_FOR_ARCHETYPE): before this plan the
/// only FATCA/archetype gate lived at the coach entry
/// (`coach_chat_screen.dart` → `evaluateCoachArchetypeGate`). The GLOBAL
/// GoRouter redirect (`app.dart`) gated ONLY on auth scope, so an `expatUs`
/// profile reaching `/home`, `/mon-argent`, `/profile/bilan` or `/explore/*`
/// rendered prévoyance content it must never see (FATCA: Swiss 3a providers
/// refuse US persons — CLAUDE.md NEVER #7).
///
/// This is a PURE decision helper, deliberately separated from the redirect
/// so it can be unit-tested without pumping the full `MaterialApp.router`.
/// The redirect in `app.dart` calls [archetypeRedirectTarget] and returns its
/// result. It REUSES `evaluateCoachArchetypeGate` (no duplicated verdict
/// logic) and the `FeatureFlags.enableCoachHardGate` kill switch — so the
/// global gate honours the same rollback contract as the coach gate.
///
/// Defense in depth: the coach-entry point-defense gate
/// (`coach_chat_screen.dart`) is INTENTIONALLY kept (T-ILF-08-01 mitigation).
library;

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/routes/legacy_onboarding_entry.dart';
import 'package:mint_mobile/screens/coach/coach_archetype_guard.dart';
import 'package:mint_mobile/services/feature_flags.dart';

/// Route prefixes that must stay reachable EVEN for a gated archetype, so the
/// user can correct their FATCA status (re-onboarding / scan / settings /
/// auth) or land on the waitlist itself without an infinite redirect loop.
///
/// These mirror the `public` / `onboarding` scoped routes in `app.dart`. The
/// gate only ever fires on the `authenticated`-scope prévoyance surfaces
/// (`/home`, `/mon-argent`, `/profile/*`, `/explore/*`, `/coach/*`, `/scan/impact`
/// is reachable as it lives under `/scan`).
final List<String> _gateExemptPrefixes = <String>[
  '/waitlist',
  ...LegacyOnboardingEntry.legacyPathPrefixes,
  '/scan',
  '/settings',
  '/auth',
  '/anonymous',
  '/', // landing (exact match handled below)
];

bool _isGateExempt(String path) {
  if (path == '/') return true;
  for (final prefix in _gateExemptPrefixes) {
    if (prefix == '/') continue;
    if (path == prefix || path.startsWith('$prefix/')) return true;
  }
  return false;
}

/// Returns the redirect target (`/waitlist`) when [profile] is a hydrated,
/// positively-identified gated archetype reaching a prévoyance surface;
/// returns `null` otherwise (no redirect).
///
/// Gating conditions (ALL must hold):
///   * [FeatureFlags.enableCoachHardGate] is true (rollback contract).
///   * [profile] is non-null (hydrated). A null profile means the archetype
///     is unknown at boot — gating would flash-block legitimate non-US users.
///   * The archetype is a POSITIVE signal (not `unknown`). `unknown` is the
///     boot/ambiguous state; correction happens via re-onboarding, not via a
///     global redirect (plan must-have: « ne pas gater tant que l'archétype
///     est inconnu »).
///   * `evaluateCoachArchetypeGate` says block for this archetype.
///   * [path] is not an exempt correction/public surface.
String? archetypeRedirectTarget({
  required CoachProfile? profile,
  required String path,
}) {
  if (!FeatureFlags.enableCoachHardGate) return null;
  if (profile == null) return null;

  // Boot / ambiguous profiles carry an `unknown` archetype. Never gate them
  // globally — that would bounce every not-yet-hydrated user to /waitlist.
  if (profile.archetype == FinancialArchetype.unknown) return null;

  // Exempt routes (correction surfaces + /waitlist itself + landing) are
  // always reachable, so the user can fix their status without a loop.
  if (_isGateExempt(path)) return null;

  final verdict = evaluateCoachArchetypeGate(profile);
  if (!verdict.shouldBlock) return null;

  return '/waitlist';
}
