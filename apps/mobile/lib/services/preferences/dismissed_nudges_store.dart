// Phase 91 Plan 91-02 — CoachInterruptBanner UI Wire (VIVANT-03).
//
// Thin façade around [NudgePersistence] for the [CoachInterruptBanner]
// dismissal flow on the Coach chat screen. The plan asked for a brand-new
// `DismissedNudgesStore` with a uniform 7-day TTL, but the codebase already
// owns the canonical dismiss/cooldown infrastructure in
// `services/nudge/nudge_persistence.dart` (per-trigger cooldown days,
// ISO8601 timestamps, hermetic test helpers). Re-creating it would
// duplicate the source of truth and split the test surface (CLAUDE.md
// NEVER #6 « code without reading existing code »).
//
// This store therefore delegates to [NudgePersistence] and only exposes
// the two methods the chat screen needs:
//   - [isDismissed(nudgeId)] — true when the nudge id is still inside its
//     cooldown window.
//   - [dismiss(nudge)] — record a dismissal so the same nudge does not
//     re-surface above the message list for [Nudge.trigger]'s cooldown
//     window (already 7 days for `taxDeadlineApproach`, `pillar3aDeadline`,
//     `goalProgress` ; longer for milestone-style triggers, shorter for
//     `noActivityWeek`).
//
// Karpathy #3 (surgical changes) — no new SharedPreferences keyspace,
// no parallel TTL logic, no mock-clock seam invented for this plan.

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/nudge/nudge_engine.dart';
import 'package:mint_mobile/services/nudge/nudge_persistence.dart';

/// Coach-chat banner dismissal store.
///
/// Reads and writes through [NudgePersistence] so the same dismiss state
/// also suppresses the nudge from the Pulse dashboard list (single source
/// of truth for « is this nudge currently dismissed »).
class DismissedNudgesStore {
  const DismissedNudgesStore();

  /// Returns true when [nudgeId] is currently inside its cooldown window.
  ///
  /// [now] is injectable so widget tests can advance the clock past the
  /// cooldown and assert the entry is auto-purged.
  Future<bool> isDismissed(String nudgeId, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = await NudgePersistence.getDismissedIds(prefs, now: now);
    return dismissed.contains(nudgeId);
  }

  /// Mark [nudge] as dismissed. The persisted entry expires after the
  /// trigger's per-type cooldown (see [NudgePersistence.cooldownDays]).
  ///
  /// Side effect: the next [MintStateProvider.forceRecompute] will exclude
  /// this nudge from `state.activeNudges` because [NudgeEngine.evaluate]
  /// reads the same dismissed list.
  Future<void> dismiss(Nudge nudge, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    await NudgePersistence.dismiss(
      nudge.id,
      nudge.trigger,
      prefs,
      now: now,
    );
  }
}
