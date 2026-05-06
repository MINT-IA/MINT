# Phase 91: Vivant Proactive Primitives — Context

**Gathered:** 2026-05-06
**Status:** Ready for planning
**Mode:** Auto-generated from milestone synthesis (no fresh discuss — context derives from `.planning/MILESTONE-MVP-PERIMETER.md` + facade-vs-cablage audit + Cleo benchmark)

<domain>
## Phase Boundary

MINT « se sent vivant » per Cleo benchmark. Today the proactive primitives exist in code but are not wired :
- `ProactiveTriggerService.evaluate()` returns 8 trigger types but ONLY fires when user opens Coach tab. No push notifications. (architecture audit #1)
- `ConversationMemoryService` persists chat history but the opener doesn't reference it — chat opens cold every time. Cleo 3.0 parity gap.
- `CoachInterruptBanner` widget exists with 0 call sites in production code. JITAI nudges → no UI surface (facade audit #2).
- Persona toggle « Calme / Direct / Sans filtre » chips visible without explanation, no tap feedback, not persisted to Settings.

Phase boundary : 4 mobile + backend changes that turn dead façades into live UX. NO new product features (bank linking deferred to v2.15).

</domain>

<decisions>
## Implementation Decisions

### VIVANT-01 — Proactive push notifications

- **Tech:** `flutter_local_notifications` (already in pubspec via `notification_service.dart`)
- **Schedule policy:** background-fetch task triggers `ProactiveTriggerService.evaluate(profile)` daily at 09:00 user-local. If trigger returns non-null, schedule notification for the next reasonable timing (paie day from profile, JITAI fiscal date, etc.).
- **Trigger types wired (6 of 8):** `paieDay`, `documentUploadCompleted`, `confidenceImproved`, `jitaiFiscalDate`, `lifecyclePhaseChanged`, `inactivityReturn7d`. Skip `weeklyRecap` (deleted Phase 2b per facade audit) and `goalMilestoneReached` (depends on `GoalTrackerService` activation, defer).
- **Deep link:** notification tap → `/coach/chat?intent=<trigger_type>&prefill=<one-liner from trigger>` so coach opens with context, not blank.
- **Permission:** request iOS notification permission on first onboarding screen (not on first launch — too aggressive).
- **Quiet hours:** suppress 22:00-08:00 user-local + suppress on weekends unless `confidenceImproved` (positive only).

### VIVANT-02 — Cross-session opener (Cleo 3.0 parity)

- **Read sources:** `CapMemoryStore.lastOutcome` (last action user took) + `ConversationMemoryService.getSummary(maxTokens=200)` (last summary) + `coach_profile.lastUpdate` (data freshness).
- **Render:** prepend a single coach bubble at top of `CoachChatScreen` empty state when `_messages.isEmpty && hasSeenPremierEclairage`. Format : « Re. La dernière fois, on parlait de {topic from memory}. {action_suggestion}. » (per MVP-PLAN-2026-04-21:75-83).
- **Fallback:** if no memory or summary, fallback to original 4-chip opener (already shipped).
- **No silent prefetch:** memory load happens on screen mount, not in background — UX feedback if it takes >500ms.

### VIVANT-03 — CoachInterruptBanner real UI

- **Listen target:** `MintStateProvider.state.activeNudges` (`NudgeEngine.evaluate` already populates this list).
- **Render position:** top of `CoachChatScreen` message list, ABOVE the first message bubble. Dismissible by swipe-down or tap-X.
- **Throttle:** show at most 1 banner per session ; persist dismissed nudge IDs in SharedPreferences for 7 days (don't re-show the same nudge for a week).
- **A11y:** Semantics(label: nudge.label, button: true, identifier: 'coach-interrupt-banner-<nudge_id>') so Maestro can target it for E2E flow assertions.

### VIVANT-04 — Persona toggle Settings migration

- **Current:** chips in `coach_chat_screen.dart:2340` (Calme/Direct/Sans filtre) without persistence.
- **Target:** move to `/settings/coach-tone` route + persist to `SharedPreferences['coach_tone_preference']` via new `CoachTonePreference` enum (`calm`, `direct`, `sansFilter`). Default `calm`.
- **Backend wire:** read preference in `coach_chat_screen.dart` on every chat call ; pass as `tone:` field in `/coach/chat` request body. Backend `claude_coach_service.py` injects matching `_TONE_INTENSITY_BLOCK` block.
- **No new ARB keys:** reuse existing chip labels ; just relocate the UI.

### Claude's discretion

- iOS notification scheduling timezone (use user's device timezone, no canton-cantonal logic).
- Maestro flow naming for E2E coverage : `walkthrough_proactive_push.yaml`, `walkthrough_cross_session_opener.yaml`, `walkthrough_interrupt_banner.yaml`, `walkthrough_persona_toggle.yaml`.
- Phase 91 ships in 1 atomic PR (per « each phase shippable on its own » constraint from milestone roadmap).

</decisions>

<code_context>
## Existing Code Insights

### Reusable assets (no need to rebuild)

- `apps/mobile/lib/services/notification_service.dart:441-754` — already schedules 3a deadlines + tax + streak notifications via `flutter_local_notifications`. Add 6 new trigger paths same pattern.
- `apps/mobile/lib/services/coach/proactive_trigger_service.dart:158-204` — `evaluate(profile)` returns nullable `ProactiveTrigger`. 7 trigger types defined. Just needs background scheduling.
- `apps/mobile/lib/widgets/coach/coach_interrupt_banner.dart` — widget exists, 0 call sites today. Wire from `coach_chat_screen.dart` around line 710.
- `apps/mobile/lib/services/cap_memory_store.dart` — `lastOutcome` getter exists.
- `apps/mobile/lib/services/conversation_memory_service.dart` — `getSummary()` exists.
- `apps/mobile/lib/services/mint_state_engine.dart:218-234` — `state.activeNudges` populated by `NudgeEngine.evaluate`.

### Established patterns

- All notifications use `NotificationService._scheduleNotification(payload, scheduledAt)`. Factor a `scheduleProactiveTriggerCheck()` helper.
- All Settings screens are in `apps/mobile/lib/screens/settings/`. New `coach_tone_screen.dart` follows pattern.
- All persistence uses `SharedPreferencesAsync` (post Flutter 3.13).

### Integration points

- `app.dart` — add new route `/settings/coach-tone`.
- `coach_chat_screen.dart` — wire 4 things : (a) read tone preference + send to backend, (b) prepend cross-session opener bubble, (c) render `CoachInterruptBanner`, (d) handle deep-link intent from notification.
- `notifications_wiring_service.dart:31` — call new `scheduleProactiveTriggerCheck()` on app start + on profile change.
- `claude_coach_service.py` — read `tone:` field from request, inject corresponding `_TONE_INTENSITY_BLOCK` (already exists, currently driven by intensity 1-5).

</code_context>

<specifics>
## Specific Ideas

- Audit panel finding (architecture #1, 2, 4) drives this phase entirely — fix the 3 deepest façades + complete persona persistence.
- « Vivant » test (per MILESTONE-MVP-PERIMETER.md §1) requires : (a) push fires in absence (Maestro can't test, document manual test), (b) opener references prior conversation (Maestro asserts opener bubble contains a token from prior turn), (c) banner renders when nudge is fired (Maestro flow forces a nudge via debug menu, asserts banner visible), (d) tone toggle persists across kill/restart (Maestro asserts tone ≠ default after re-launch).

</specifics>

<deferred>
## Deferred Ideas

- Voice persona « calme suisse » Apple-grade audio (VOICE-01 v2 deferred — STT/TTS provider integration is 30h, not MVP)
- Background bank tx-delta detection (BANK-01 v2 deferred — Open Banking aggregator 80h, not MVP)
- `weeklyRecap` resurrection (deleted in Phase 2b per facade audit) — defer to v3.x
- `goalMilestoneReached` notification (depends on `GoalTrackerService` reactivation) — defer

</deferred>
