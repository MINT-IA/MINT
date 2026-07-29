# Cassure #4 evidence — backend works, client doesn't propagate `messagesRemaining: 0`

Date: 2026-05-13T17:15Z
Method: Direct curl to Railway staging `/api/v1/anonymous/chat` with a fresh X-Anonymous-Session UUID.

## Backend response shape (4 sequential POSTs, same session ID)

| Message | HTTP | messagesRemaining | Notes |
|---|---|---|---|
| 1 | 200 | **2** | Real LLM response + LSFin disclaimers |
| 2 | 200 | **1** | Real response + Eclairage card schema |
| 3 | 200 | **0** | Real response + disclaimers |
| 4 | 429 | — | « Limite atteinte. Cree un compte pour continuer. » |

**Conclusion** : the backend correctly caps at 3 messages and returns `messagesRemaining: 0` on the 3rd response.

## Client behaviour (Maestro runs 7/8/9/10 on staging-build sim)

- 3 messages sent
- 3 coach responses rendered visibly
- Auth-gate modal `AuthGateBottomSheet` does NOT surface
- Conversion prompt « Je peux garder tout ça en mémoire pour toi » NOT added to chat messages

Per `anonymous_chat_screen.dart:269-289`, the conversion-prompt-add + `_showAuthGate()` is gated on `messagesRemaining == 0`. The client receives the responses (responses render) but does NOT trigger the auth-gate path.

## Hypotheses to test next

H4a — `messagesRemaining` not in the actual app's parsed response (parser issue / response shape mismatch)
H4b — `messagesRemaining` extracted but compared as String not int → `int? as int? != 0`
H4c — Race condition : the 3rd response's `_isLoading=false` setState fires AFTER `messagesRemaining == 0` check skipped
H4d — Staging returns different response shape to authenticated header (X-Anonymous-Session) vs my curl test

Next diagnostic : iOS log dump (`xcrun simctl spawn UDID log show --predicate "subsystem == 'ch.mint.app'"`) to read what `messagesRemaining` the client actually received.
