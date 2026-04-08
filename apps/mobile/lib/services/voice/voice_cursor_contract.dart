/// VoiceCursorContract — public API.
///
/// Exports the generated enums + constants from `voice_cursor_contract.g.dart`
/// and provides the [resolveLevel] pure function that implements the
/// precedence cascade documented in `tools/contracts/voice_cursor.json`.
///
/// Doctrine (locked, see `visions/MINT_DESIGN_BRIEF_v0.2.3.md` §L1.6):
///
///   1. **sensitivityGuard** — sensitive topics cap at N3 regardless of preference.
///   2. **fragilityCap**     — fragile mode (user-declared) caps at N3.
///   3. **n5WeeklyBudget**   — at most N5_PER_WEEK_MAX N5 messages per week;
///                              once exhausted, N5 candidates downgrade to N4.
///   4. **gravityFloor**     — G3 never below N2 (even under soft preference).
///   5. **preferenceCap**    — soft → N3 cap, direct → N4 implicit, unfiltered → N5 allowed.
///   6. **matrixDefault**    — fall back to the matrix lookup.
///
/// resolveLevel is **pure**: no I/O, no clock, no globals. Caller passes
/// `n5Budget` (remaining N5 messages this week, integer) and `sensitiveFlag`
/// (already-classified topic).
library voice_cursor_contract;

import 'voice_cursor_contract.g.dart';

export 'voice_cursor_contract.g.dart';

/// Resolves the voice intensity level for a single message.
///
/// All parameters are required to keep the function side-effect free and
/// deterministic. Returns one of [VoiceLevel.n1] .. [VoiceLevel.n5].
VoiceLevel resolveLevel({
  required Gravity gravity,
  required Relation relation,
  required VoicePreference preference,
  required bool sensitiveFlag,
  required bool fragileFlag,
  required int n5Budget,
}) {
  // Stage 6 (matrixDefault): start from the matrix.
  VoiceLevel candidate = voiceCursorMatrix[gravity]![relation]![preference]!;

  // Stage 5 (preferenceCap): soft → N3, unfiltered → N5 (no-op since matrix
  // already obeys ≤ N5), direct → no extra cap.
  if (preference == VoicePreference.soft && _ord(candidate) > _ord(VoiceLevel.n3)) {
    candidate = VoiceLevel.n3;
  }

  // Stage 4 (gravityFloor): G3 never below the configured floor (N2).
  if (gravity == Gravity.g3 && _ord(candidate) < _ord(g3FloorLevel)) {
    candidate = g3FloorLevel;
  }

  // Stage 3 (n5WeeklyBudget): downgrade N5 to N4 when budget is exhausted.
  if (candidate == VoiceLevel.n5 && n5Budget <= 0) {
    candidate = VoiceLevel.n4;
  }

  // Stage 2 (fragilityCap): cap at fragileModeCapLevel (N3).
  if (fragileFlag && _ord(candidate) > _ord(fragileModeCapLevel)) {
    candidate = fragileModeCapLevel;
  }

  // Stage 1 (sensitivityGuard): hard cap at sensitiveTopicCapLevel (N3).
  // Anti-shame doctrine: NEVER N4/N5 on deuil/divorce/maladie/etc.
  if (sensitiveFlag && _ord(candidate) > _ord(sensitiveTopicCapLevel)) {
    candidate = sensitiveTopicCapLevel;
  }

  // G3 floor still applies after every cap (the floor is non-negotiable).
  if (gravity == Gravity.g3 && _ord(candidate) < _ord(g3FloorLevel)) {
    candidate = g3FloorLevel;
  }

  return candidate;
}

/// Numeric ordering of voice levels for min/max comparisons.
int _ord(VoiceLevel l) {
  switch (l) {
    case VoiceLevel.n1:
      return 1;
    case VoiceLevel.n2:
      return 2;
    case VoiceLevel.n3:
      return 3;
    case VoiceLevel.n4:
      return 4;
    case VoiceLevel.n5:
      return 5;
  }
}
