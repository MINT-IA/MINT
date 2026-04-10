# Phase 9 — L1.5 MintAlertObject (S5)

**Branch:** `feature/v2.2-p0a-code-unblockers`
**Requirements:** ALERT-01..10, ACCESS-05
**Depends on:** Phase 2 (VoiceCursorContract generated + Profile fragile/preference fields), Phase 4 (MTC patterns optional), Phase 8c (Polish Pass 1 deferred items on S5).

## Goal (outcome-shaped)

S5 renders via a **typed, rule-fed, compiler-enforced alert primitive** (`MintAlertObject`) that imports `voice_cursor_contract.g.dart`, forbids LLM-sourced content at build time, and passes AAA a11y (TalkBack 13 sweep + live-region announce on G2→G3).

## Locked decisions (NON-NEGOTIABLE)

- **D-01 — Gravity enum source:** reuse `Gravity` from `voice_cursor_contract.g.dart` (already has `g1/g2/g3`). NO local enum. `MintAlertObject` imports `package:mint_mobile/services/voice/voice_cursor_contract.dart` directly.
- **D-02 — Field naming:** constructor is exactly `MintAlertObject({required Gravity gravity, required String fact, required String cause, required String nextMoment})`. No optional `message`, no `title`, no `subtitle`. Grammar is compiler-enforced.
- **D-03 — MINT-as-subject ARB lint:** extend existing `tools/checks/sentence_subject_arb_lint.py` with a new rule scope (`mintAlert*` keys); it already exists for S0-S5 lints — reuse, do not fork.
- **D-04 — N-level routing:** `MintAlertObject` internally calls `resolveLevel()` from `voice_cursor_contract.dart` with `gravity`, `relation` (from `BiographyProvider.currentRelation`), `preference` (from `CoachProfile.voiceCursorPreference`), `sensitiveFlag` (from topic classifier on `fact`), `fragileFlag` (from `CoachProfile.fragileModeEnteredAt != null`), `n5Budget` (from `CoachProfile.n5IssuedThisWeek`). Zero hardcoded mapping.
- **D-05 — card_ranking_service.dart does not exist yet.** Create it at `apps/mobile/lib/services/contextual/card_ranking_service.dart` as a new pure-function tiebreaker that `contextual_card_provider.dart` calls. G3 `MintAlertObject` cards float to index 0; stable sort otherwise. The 1-line wire-in happens in `contextual_card_provider.dart`.
- **D-06 — G3 ack persistence:** use `BiographyRepository.recordFact(BiographyFact.alertAcknowledged(alertId, timestamp))`. Reuse existing biography layer — do not introduce a new store. `MintAlertObject` takes an `alertId` parameter (content hash of `gravity|fact|cause`) and skips render if ack fact already exists for that id.
- **D-07 — no_llm_alert.py grep gate scope:** scans `apps/mobile/lib/**/*.dart`. For any file that (a) imports any `claude_*_service.dart` AND (b) contains `MintAlertObject(`, fail the build. Exclusion list: test files (`_test.dart`) may reference both for regression tests. Wired into CI via `.github/workflows/*` alongside other `tools/checks/*.py` gates.
- **D-08 — debt_alert_banner.dart migration:** the existing `debt_alert_banner.dart` is a S5 legacy stand-in. Phase 9 **deletes it** and replaces all 2 call sites (grep confirms 2 usages in financial report screen) with `MintAlertObject(gravity: Gravity.g3, fact: ..., cause: ..., nextMoment: ...)` fed by `AnticipationProvider.debtCrisisAlert`. No backward-compat shim.
- **D-09 — Feeder wiring:** `AnticipationProvider`, `NudgeEngine`, `ProactiveTriggerService` each expose a `Stream<MintAlertSignal>` (plain data class with `{gravity, factKey, causeKey, nextMomentKey, topicTag, alertId}` — ARB keys, not strings). S5 host widget subscribes to a merged stream and maps signals to `MintAlertObject` widgets. LLM pipelines (`claude_coach_service`) MUST NOT emit these signals.
- **D-10 — Patrol tests:** live in existing `apps/mobile/integration_test/` directory (infra already proven — `persona_lea_test.dart`, `onboarding_patrol_test.dart`). New file: `integration_test/mint_alert_object_patrol_test.dart` with 6 golden states matrix (G2/G3 × soft/direct/unfiltered) + sensitive-topic guard + fragile-mode guard = 8 cases.
- **D-11 — SemanticsService.announce:** fires on the **transition** G2 → G3 only (not on first G3 render, not on G3 → G3 update). Requires tracking previous gravity per `alertId` in a `ValueNotifier<Map<String, Gravity>>` local to the S5 host. `liveRegion: true` on the outer `Semantics` wrapper.
- **D-12 — G3 politique:** component docstring explicitly states "information-only by default". Constructor accepts optional `externalAction: ExternalActionStub?` which is defined but whose `execute()` throws `UnimplementedError('Partner routing not signed — see PHASE_12.md')`. The ARG is wired so Phase 12+ can flip it without breaking the API.
- **D-13 — TalkBack 13 sweep scope:** ACCESS-05 applies to **S5 only** in this phase (not all S0-S5). Other surfaces are covered by Phase 8b. Specific targets on S5: CustomPaint in the alert icon → `semanticsBuilder`; any `IconButton` in MintAlertObject → `tooltip`; `InkWell` → `InkResponse`; `AnimatedSwitcher` for G2↔G3 → keyed + `Semantics`.

## Deferred (NOT in this phase)

- External partner action routing (stub only — Phase 12+ unlocks).
- ARB sentence-subject lint extension to non-alert keys (already covered Phase 8b).
- TalkBack sweep on S0-S4 (Phase 8b).
- Reverse Krippendorff alpha testing on alert phrasings (Phase 11).

## Discretion (Claude decides)

- Rendering details: exact `TextStyle` tokens for G2 vs G3 (calm register vs grammatical break), animation curve for G2→G3 transition, icon selection. Must use `MintColors.*` tokens (no hardcoded hex) and `MintTextStyles.*`.
- Internal structure of `MintAlertSignal` data class (keep it minimal — ARB keys + metadata).

## Interface contracts (embedded for executors)

From `apps/mobile/lib/services/voice/voice_cursor_contract.g.dart`:
```dart
enum VoiceLevel { n1, n2, n3, n4, n5 }
enum Gravity { g1, g2, g3 }
enum Relation { relNew, established, intimate }
enum VoicePreference { soft, direct, unfiltered }
```

From `apps/mobile/lib/services/voice/voice_cursor_contract.dart`:
```dart
VoiceLevel resolveLevel({
  required Gravity gravity,
  required Relation relation,
  required VoicePreference preference,
  required bool sensitiveFlag,
  required bool fragileFlag,
  required int n5Budget,
});
```

From `apps/mobile/lib/services/biography/biography_repository.dart`:
```dart
Future<void> recordFact(BiographyFact fact);
Future<List<BiographyFact>> factsByTag(String tag);
```

## Plans

- **09-01-PLAN.md** — MintAlertObject typed API + Gravity wiring + G2/G3 rendering (ALERT-01, ALERT-02, ALERT-03, ALERT-06)
- **09-02-PLAN.md** — Feeder wiring (AnticipationProvider/NudgeEngine/ProactiveTriggerService) + debt_alert_banner migration + card_ranking_service.dart + G3 priority float (ALERT-04, ALERT-07, ALERT-10)
- **09-03-PLAN.md** — CI guards: `no_llm_alert.py` grep gate + sentence_subject_arb_lint extension (ALERT-07 enforcement, ALERT-02 enforcement)
- **09-04-PLAN.md** — Patrol integration tests (8 cases) + TalkBack 13 sweep on S5 + G3 biography ack persistence + SemanticsService.announce on G2→G3 (ALERT-05, ALERT-08, ALERT-09, ACCESS-05)
