I've traced the diff against the actual production wiring. Here's my assessment.

## Scope

The diff is **additive test + tooling only** — no production `lib/` code changes:
- `integration_test/g1_scn01_scenario_isolation_patrol_test.dart` — Patrol runtime proof
- `test/patrol/..._runtime_test.dart` — Patrol CLI wrapper
- `tools/simulator/patrol_scn01_scenario_isolation.sh` — simulator runner producing sanitized evidence
- `tools/checks/tests/..._orchestrator.py` — pytest suite exercising the runner against fakes

## Wiring verification (not a facade)

The property under test is genuinely wired to shipping code:
- The `rvc_scenario_unavailable` key exists in the real screen (`rente_vs_capital_screen.dart:822`) and is gated by `_scenarioUnavailable` (`:718`), which is seeded from `ScenarioSessionProvider.enabled` (`:200-201`) and confirmed via `renteCapitalFactsReady` in `_initializeScenario` (`:301-311`).
- `renteCapitalFactsReady` fails closed on stale timestamps (`scenario_session_provider.dart:58-64`), and `open(..., factsReady: false)` returns `null` **before touching the store/cache** (`:148`). This is exactly what the test asserts: `sessionFor` null, `cache.readCount/writeCount/clearCount == 0`.
- The identical privacy property already has a green base-branch widget test (`test/screens/rente_vs_capital_scenario_session_test.dart:120-208`), which confirms the `context.read<ScenarioSessionProvider?>()` nullable-provider lookup resolves and the unavailable branch renders. The new Patrol test is an on-device re-proof + screenshot handshake, not a stub.
- Constructor signatures used by the new test match source (`ScenarioSessionStore({cache, idFactory, clock})` at `scenario_session_store.dart:39-45`); patrol dep and `test_directory: test/patrol` are present (`pubspec.yaml:64,70`).
- The runner is genuinely covered by the pytest orchestrator (build isolation/restore, signal handling, fail-closed on missing/ambiguous products, log/screenshot sanitization redacting repo/home/device/tmp + UUID regex, device redaction in metadata).

## Findings

**P0:** none.

**P1:** none.

**P2 (non-blocking):**
- The "native proof" evidence artifacts (`.planning/runtime-evidence/phase-37/scn-01/...`) are not in the diff; the orchestrator proves the *harness* against fake `patrol`/`xcrun`/`xcodebuild`, not that the app was actually exercised on a device. Reviewers should not read this as a captured device run. To prove a real run, execute `tools/simulator/patrol_scn01_scenario_isolation.sh` against a booted simulator and inspect the generated `metadata.json` (`result: passed`, populated `screenshotSha256`).
- Assertion drift: the Patrol test uses `find.byType(TextField)` (patrol_test.dart:95) while the base widget test uses `TextFormField` (`rente_vs_capital_scenario_session_test.dart:170`). Both are absence assertions so neither is wrong, but the inputs are `TextFormField`s — the Patrol test would not catch a bare `TextField` regression the widget test also misses; harmless here since the unavailable branch renders neither.
- The runtime Patrol test substantially duplicates the existing widget test's assertions. Acceptable (runtime vs. widget layer), noted only so it isn't mistaken for new logical coverage.

No correctness, privacy, routing, or compliance regression found; the tooling fails closed and sanitizes outputs.

## Verdict

**PASS**
