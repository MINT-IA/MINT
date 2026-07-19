## Product/domain verdict: PASS

This change is infrastructure/privacy plumbing for the guided-sequence engine: it converts three specialist-heavy steps (EPL / versement anticipé LPP, and rente-vs-capital at retirement) from "persist raw financial outputs in SharedPreferences" to "hold only an opaque scenario UUID + terminal status, backed by the encrypted scenario store." I traced it end-to-end against the live repo and it is real wiring, not a facade, and it is domain-coherent. No Swiss constants, formulas, or advice language are introduced by this diff.

### Verification performed (why this is not a facade)
- **Routes exist and match**: `screen_registry.dart:390` (`/rente-vs-capital` ↔ `retirement_choice`) and `:475` (`/epl` ↔ `early_pension_withdrawal`). The coordinator's `isScenarioCompletionCandidate` requires `registered.route == stepReturn.route` (`sequence_coordinator.dart:180`).
- **Screens emit the proof**: `epl_screen.dart:129-155` and `rente_vs_capital_screen.dart:161-187` mark the session terminal via `provider.markTerminal(...)` and emit a `ScreenReturn.completed` carrying `scenarioId`, `runId`, `stepId`, and a non-empty `eventId` (`epl_screen.dart:135-137`).
- **Provider is registered** in the composition root (`app.dart:1948-1954`, `enabled: FeatureFlags.scenarioSessionCacheEnabled`) so `context.read<ScenarioSessionProvider?>()` resolves; the coach passes `validatesCompleted` into `handleRealtimeReturn` (`coach_chat_screen.dart:391-397`).
- **Kind is enforced**: `validatesCompleted(id, expectedKind)` checks `session?.kind == expectedKind && status == completed` (`scenario_session_provider.dart`), and the handler passes `activeStep.scenarioKind!`. A rente-capital ID cannot satisfy an EPL step (test `scenario_sequence_bridge_test.dart:419` "wrong kind" → Pause). Domain-correct.
- **Fail-closed + anti-replay**: scenario steps Pause (never silently complete) on missing/malformed/wrong-run/wrong-step/wrong-route/wrong-status/absent proof; `processedScenarioIds` survives `invalidateSteps` and cold reload, so a re-opened step forces a NEW computation (tests at `:399-473`, `:574-607`).
- **No orphaned consumers**: `montant_epl`, `impact_rente`, `decision_mixte` are gone everywhere except doc strings (grep confirms). The only reader of `allOutputs` is a coach context line printing keys (`coach_chat_screen.dart:444`), so removing these keys breaks nothing.

### P0 findings
None.

### P1 findings
None.

### P2 findings
- **Scenario→dossier data flow is deliberately severed at the sequence layer** (`sequence_run.dart:20-27`, `CompleteAction.allOutputs` = `stepOutputs` only, `sequence_coordinator.dart:215`). For the two most specialist-relevant decisions (EPL, rente-vs-capital), the sequence completion now carries only an opaque ID — no amount, no assumptions, no caveats — into the coach summary/dossier context. This is a justified privacy tradeoff (levers remain in the encrypted store keyed by `scenarioId`), but any future specialist-ready PDF must read the encrypted store via the retained `scenarioReferences` id; nothing in-tree does that yet. Confirm the dossier assembler is planned to consume it.
- **`validatesCompleted` re-reads the store but does not re-assert freshness** (`scenario_session_provider.dart`). Freshness (`eplFactsReady`/`renteCapitalFactsReady`) is enforced at `open`/`saveLevers` time; a completion validated on facts that later decay by time (without a `changedInputs` event) can still advance. Bounded by the run lifetime; low risk.
- **Legacy-run purge discards the entire in-progress run** if any of the three scenario steps holds pre-migration outputs (`sequence_store.dart` `hasLegacyScenarioOutputs`). Privacy-safe default, but silently drops sequence progress on upgrade. Acceptable; worth a one-line UX note.
- **Cross-run scenario event pauses the active run** rather than being ignored (`sequence_chat_handler.dart`: for scenario steps with `scenarioId != null`, the wrong-run/wrong-step guards do not fire, so it falls through to Pause; test `:410` "wrong run" → Pause). Only one run is active at a time and Pause is `canResume: true`, so worst case is a spurious resumable pause — not harmful, but a behavior divergence from legacy ignore semantics.

### Swiss domain review
- **LPP / EPL (versement anticipé, art. 30c LPP)**: Only the completion *gating* changed — computation lives in `epl_screen`, untouched here. No withdrawal thresholds, buyback-blocking rules, or tax-on-withdrawal constants are asserted in this diff, so no stale-constant risk is introduced. The lever model correctly captures buyback recency (`recentBuybackOverride`, `yearsSinceBuybackOverride`) needed for the 3-year buyback/withdrawal interaction — good, but its correctness is out of this diff's scope.
- **Rente vs capital**: Levers capture the decision-relevant Swiss variables (conversion rates split obligatoire/surobligatoire, marital status, canton, life expectancy) — coherent inputs for the arbitrage. Actual conversion-rate/tax logic is not in this diff.
- **AVS / 3a / mortgage / tax / insurance / succession**: Not affected by this change (3a, budget, LAMal, succession steps keep their `requiredOutputKeys` output path).
- Freshness gating requires *current* canonical `birthYear`, `canton`, `avoirLppTotal`, income, `etatCivil`, `targetRetirementAge` before a scenario can open — consistent with "no computing on stale facts."

### Mint product logic review
This moves Mint **toward** the ledger → DataQuest → scenario → dossier spine and removes a real source-of-truth violation: financial levers for EPL and rente-capital are no longer duplicated into SharedPreferences `stepOutputs`; canonical facts stay in the ledger, what-if levers stay in the bounded encrypted scenario store, and the sequence retains only an opaque proof. The `scenario` node of the spine is now properly isolated. The one incomplete link is `scenario → dossier`: the opaque reference is dossier-ready by design but no consumer yet assembles facts/assumptions/caveats from it (P2 above). Net direction is correct and privacy-positive.
