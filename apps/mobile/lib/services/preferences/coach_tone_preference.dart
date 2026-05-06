// Phase 91 Plan 91-01 — Persona toggle Settings migration (VIVANT-04).
//
// Persisted user-facing voice tone for the Coach chat. Replaces the inline
// chips that previously lived in [CoachChatScreen] (line ~2340-2400). Now
// surfaced from `/settings/coach-tone` and fed to the backend on every
// `/coach/chat` request via the `tone` field.
//
// Default: [CoachTonePreference.calm]. The plan deliberately renamed
// "soft" → "calm" so the user-facing label matches the Settings copy
// ("Calme") even though the underlying [VoicePreference] enum still uses
// "soft" in coach_profile.dart (out of scope for this plan).
//
// Storage: legacy `SharedPreferences.getInstance()` (matches the rest of
// `apps/mobile/lib/services/`). The plan called for `SharedPreferencesAsync`
// but the codebase has not migrated yet — staying on the established API
// keeps this PR surgical (CLAUDE.md NEVER #6).

import 'package:shared_preferences/shared_preferences.dart';

/// User-selected coach voice tone. Persisted across app launches.
///
/// Maps onto the backend `_TONE_INTENSITY_BLOCK` slots (cash_level 1/3/5)
/// in `services/backend/app/services/coach/claude_coach_service.py`.
enum CoachTonePreference {
  /// Calm, no shame for choosing it. Backend = INTENSITY_MAP[1] (Tranquille).
  calm,

  /// Default. Backend = INTENSITY_MAP[3] (Direct, the standard MINT tone).
  direct,

  /// No politeness filter. Backend = INTENSITY_MAP[5] (Brut).
  sansFilter,
}

/// SharedPreferences key — namespaced to avoid collision with the legacy
/// `mint_coach_cash_level` int (still read by [CoachChatScreen] for the
/// in-chat « plus cash / plus doux » regex commands).
const String coachTonePreferenceKey = 'coach_tone_preference';

/// Async helpers for [CoachTonePreference].
///
/// Keep the API tiny and pure — load/save round-trip + the canonical
/// `wireName` we ship to the backend in the request body.
class CoachTonePreferenceStore {
  const CoachTonePreferenceStore();

  /// Load the persisted preference. Returns [CoachTonePreference.calm]
  /// when the key is missing OR contains an unrecognised string (forward
  /// compatibility with future enum additions).
  Future<CoachTonePreference> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(coachTonePreferenceKey);
      return _decode(raw);
    } catch (_) {
      // Best-effort. Default applies on any storage failure.
      return CoachTonePreference.calm;
    }
  }

  /// Persist [value]. Returns `true` on success, `false` on storage error.
  Future<bool> save(CoachTonePreference value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.setString(coachTonePreferenceKey, value.name);
    } catch (_) {
      return false;
    }
  }
}

/// Decode a stored string into a [CoachTonePreference]. Public for tests.
CoachTonePreference decodeCoachTone(String? raw) => _decode(raw);

CoachTonePreference _decode(String? raw) {
  if (raw == null || raw.isEmpty) return CoachTonePreference.calm;
  for (final value in CoachTonePreference.values) {
    if (value.name == raw) return value;
  }
  return CoachTonePreference.calm;
}

/// Wire name sent to the backend `/coach/chat` request body in the `tone`
/// field. Same as [CoachTonePreference.name] but kept as an explicit getter
/// so a future rename of the enum can preserve the wire format without
/// breaking the backend contract.
extension CoachTonePreferenceWire on CoachTonePreference {
  String get wireName => name;
}
