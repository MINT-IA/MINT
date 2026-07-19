## MINT Code Audit — Scenario↔Sequence Bridge

**Scope:** Diff from base `42e19549` wiring bounded G1 scenario sessions into guided sequences (`sequence_run`, `sequence_template`, `sequence_coordinator`, `sequence_chat_handler`, `sequence_store`, `scenario_session_provider`, `coach_chat_screen`) + new `scenario_sequence_bridge_test.dart`.

**Verification performed:**
- `flutter test` on the new bridge test + regressed handler test → **45/45 passed**.
- `flutter analyze` on all 5 changed lib trees → **No issues found**.
- Traced end-to-end wiring (not a facade): emitter `epl_screen.dart:135-155` produces the `scenarioId`+`runId`+`stepId`+`eventId` return → `ScreenCompletionTracker` → `coach_chat_screen.dart:411` injects `provider.validatesCompleted` → handler → coordinator → store-backed validation. Provider is registered eagerly (`app.dart:1948-1954`, `lazy: false`).

### Findings

**P0 — none.**

**P1 — none.**

**P2 (advisory, non-blocking)**
1. **Feature-flag coupling can dead-end a sequence.** Scenario validation is gated on `FeatureFlags.scenarioSessionCacheEnabled` (`scenario_session_provider.dart:236`, `validatesCompleted` returns `false` when disabled), while sequences are gated on the independent `enableGuidedSequences` (`feature_flags.dart:69`). If guided sequences are enabled but the scenario cache is not, steps `housing_02_epl` / `ret_02_choice` / `pre_03_choice` can never validate → permanent `PauseAction` loop with no completion path (`sequence_coordinator.dart` `_handleCompleted`, scenario branch). Both flags default `false`, so no current production impact; rollout must enable them together. *Proof: with `scenarioSessionCacheEnabled=false`, the test `disabled provider ... fail closed` (line 351) shows `validatesCompleted → false`, which the coordinator maps to Pause.*
2. **Behavioral change on stale cross-run events for scenario steps.** For a scenario-backed active step carrying a `scenarioId`, the legacy early-ignore guards are intentionally skipped (`sequence_chat_handler.dart`, the two guard blocks), so a delayed event from a *different* run now drives the current run to `PauseAction` instead of being silently ignored. This is recoverable (`canResume: true`) and covered by the "wrong run"/"wrong step" cases (test line 410-411), but it is a semantics shift worth noting for the coach UX.

### Invariants confirmed
- **Privacy boundary holds:** `ScenarioStepReference` serializes only opaque UUIDv4 + `completed` status (`sequence_run.dart` `toJson`/`fromJson`); scenario steps have `stepOutputs` stripped (`completeScenarioStep` `..remove(stepId)`); legacy financial outputs on the three step IDs are purged on cold load (`sequence_store.dart:24-33`); `CompleteAction.allOutputs` and the coach context strings expose keys only. Test "serialization contains only opaque ID and status" (line 637) enforces no lever/`CHF` leakage.
- **Double-gated completion:** structural candidacy (`isScenarioCompletionCandidate` — outcome, status, opaque id, run/step identity, eventId, registry route match, not-already-processed) **plus** encrypted store-backed `validatesCompleted` (kind + terminal status). Forging in the coordinator alone yields Pause (test line 243).
- **Fail-closed** on disabled flag, malformed/missing/wrong-kind/wrong-route/absent ID, and store read failure (tests lines 399-453).
- **Anti-replay** survives invalidation and cold reload via `processedScenarioIds` (bounded FIFO 20, kept out of `invalidateSteps`), and legitimate re-runs are not bricked because completed sessions force a fresh UUID (tests lines 574, 609).

---

## Verdict: **PASS**
