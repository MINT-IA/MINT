## MINT External Audit — G1 Scenario Session Wiring

**Scope:** `feat(g1): wire scenario sessions to pension callers` (+ store, model, provider) vs base `d1276b753`. 14 files, +2631/−166.

### Verification performed
- Ran the 4 new/changed suites (**36 pass**) plus sequence + `screen_return` regression suites (**123 pass**) on Flutter 3.41.6. Real-caller widget tests drive the actual `EplScreen`/`RenteVsCapitalScreen`, not mocks.
- Traced the wiring end-to-end: provider registration, `SessionTerminationCoordinator`, `AccountSessionBootstrap`, feature flag scope, and the secure-storage purge path.

### What holds up
- **Fail-closed & not backend-reachable.** `scenarioSessionCacheEnabled` is a compile-time `MINT_TEST_G1_SCENARIO_SESSIONS` env flag, default `false`, and absent from `applyFromMap` (`feature_flags.dart:75`, confirmed `applyFromMap` body at :187–216). Backend config cannot flip it. Disabled path actively purges the cache in `load()` (`scenario_session_provider.dart:87`).
- **Fact isolation is real.** `ScreenReturn` carries only an opaque UUIDv4 + `ScenarioStatus`; `ScreenCompletionTracker` rejects malformed/half-populated identity on both write and read (`screen_completion_tracker.dart:_hasValidScenarioIdentity`, `lastReturn` guard). Cache persists levers/overrides but no certified facts, provenance, or derived outputs (isolation test asserts absence of `avoirLppTotal`/`dataSources`/`sourceDate`/`stepOutputs`/`result`). The old raw `stepOutputs: {montant_epl, impact_rente, decision_mixte}` emission is removed from both screens.
- **Cross-account purge is covered.** `purgeSessionPersistence()` is *not* explicitly wired, but session termination sweeps all non-credential secure-storage keys (`session_termination_coordinator.dart:208–215`); `g1_scenario_sessions_v1` is not in `AuthService._sessionCredentialKeys` (`auth_service.dart:43`), so it is deleted on logout/switch. No persistent cross-account leak.
- **`factsReady` gating fail-closed** via `FreshnessDecayService` (stale certified facts → EPL shows `epl_scenario_unavailable`, no default figures; test proves it).
- **Store integrity:** bounded to 8, dedup IDs, monotonic `updatedAt`, terminal-lifecycle enforced (no resurrection), UUIDv4 opacity checks, `SessionEpoch`-guarded persistence. Concurrency test proves lever-save serializes before terminal transition.

### Findings

**P0 — none.**

**P1 — none.**

**P2**
1. **Facade-without-wiring (benign): `ScenarioSessionProvider.purgeSessionPersistence()` has no caller.** Durable purge relies implicitly on the broad secure-storage sweep rather than explicit coordinator wiring, unlike coach/budget which are in `purgeDurableSessionData` (`app.dart:2137`). Correct today, but untested and brittle — if the sweep's preserved-set logic changes, the scenario cache purge fails silently. Wire `scenarios.purgeSessionPersistence` explicitly.
2. **Sequence pre-fill contract emptied for these two screens.** EPL/rente-capital now return only an opaque `scenarioId` to the (dormant) `SequenceCoordinator`; the domain `stepOutputs` that fed the next step are gone. Intentional privacy hardening, no regression today (both `enableGuidedSequences` and the cache flag are off), but must be re-designed before guided sequences ship.
3. **UX inconsistency:** `rente_vs_capital` with feature enabled + stale/missing facts renders inputs but silently never computes (`_matchesScenarioRequest` nulls the result), with no "unavailable" affordance like EPL. Fail-closed, behind the disabled flag.

### Verdict

**PASS** — The change is a correctly isolated, fail-closed, dormant feature. Wiring resolves (nullable-provider read pattern is established here), the privacy boundary holds (opaque identity out, secure-storage sweep purges the cache), and the real callers are exercised by passing tests. P2 items are hardening/UX follow-ups for when the flag is eventually enabled and do not block.
