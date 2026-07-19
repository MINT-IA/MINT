# MINT External Audit — `codex/g1-capital-native-proof-20260718`

**Audit mode:** code · **Base ref:** `b447c10d8` · **Diff:** 153 lines (within 2500 budget)

## Scope
The diff hardens the G1 "capital native" scenario boundary on the Rente vs Capital screen:
1. `app.dart` — adds `await scenarios.purgeSessionPersistence();` to the durable purge in `SessionTerminationCoordinator.production`.
2. `rente_vs_capital_screen.dart` — introduces a `_scenarioUnavailable` fail-closed state + `_buildScenarioUnavailable()` widget.
3. Two test files + doc/line-number refreshes.

## Verification performed
- **Privacy / durable purge** — `ScenarioSessionProvider.purgeSessionPersistence()` (`scenario_session_provider.dart:263`) delegates to `_store.clear()` → `_cache.clear()` → `FlutterSecureStorage.delete` (`scenario_session_store.dart:35,171`). Previously the encrypted levers cache was only cleared in-memory on termination; the new line ensures the durable secure-storage entry is wiped. Confirmed by the new isolation test (`+1`).
- **Fail-closed state machine** — `didChangeDependencies` sets `_scenarioUnavailable = _scenarioBoundaryRequired` (screen:201) before the first frame; `_initializeScenario` flips it false only on a successful `open()` and re-asserts true when facts aren't fresh or session creation fails (screen:~... `open` returns null). When unavailable, `_recalculateAsync` early-returns via `_matchesScenarioRequest(null)==false` (screen:494,636) — **no API call, no cache write, no default seed figures rendered**. Verified by the new `stale facts show unavailable on first frame` test asserting no `TextFormField`/`Slider`, no raw defaults (`50/100000/...`), `cache.value == null`, and no active session.
- **Facade-without-wiring** — `_buildScenarioUnavailable()` is actually rendered in the sliver list (`if (_scenarioUnavailable) ... else ...`), not dead code; l10n keys `premierEclairageCardErrorTitle` / `independantLedgerFactsSubtitle` exist in all 6 ARB files; `MintSurface`/`MintSurfaceTone.porcelaine`/`radius`/`padding` params all resolve.
- **Feature-disabled fallback preserved** — when the provider is null/disabled, `_scenarioBoundaryRequired` stays false, `_scenarioUnavailable` stays false, and classic autofill behavior is retained.
- **Tests** — ran both affected files: `15/15 passed`.
- **Docs / routing** — `INTERACTION_COVERAGE_AUDIT.md` and `SCREEN_CONTRACTS.md` are line-number-only refreshes; no route builder or coverage-gate impact.

## Findings

### P0 — None

### P1 — None

### P2 (non-blocking, observation)
- **One-frame "unavailable" flash on the happy path.** `_initializeScenario` runs in a post-frame callback and `await`s secure-storage reads, so a valid session briefly renders `_buildScenarioUnavailable()` ("Calcul non disponible") before flipping to content (`rente_vs_capital_screen.dart:142,201`). No dedicated loading state covers this window. This is an intentional fail-closed tradeoff (never show seed defaults), so it's acceptable, but a neutral "loading" tone would read better than an error-styled surface. No correctness/privacy impact.

## Verdict

**PASS**

The change is small, correctly wired, test-backed, and net-positive for privacy: it closes a durable-persistence gap on session termination and prevents rendering default financial figures when scenario facts are stale/unavailable. No P0/P1 issues.
