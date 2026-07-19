# MINT External Audit — `codex/g1-capital-native-proof-20260718`

**Audit mode:** code · **Base ref:** `bcf3a067c` · **Diff:** 2 files, +247 (test-only)

## Scope
The diff adds one Patrol integration test (`g1_scn01_scenario_isolation_patrol_test.dart`) plus a `test/patrol/` re-export runtime shim. Both commits on this branch (`16740e594`, `35425decc`) advertise a "scenario isolation **runtime proof**." I verified the underlying production wiring and whether the "proof" actually executes.

## Production behavior — sound
The feature the test targets is genuinely wired and fail-closed:
- `ScenarioSessionProvider.open()` returns `null` when `!factsReady` before any store write (`scenario_session_provider.dart:148`).
- `renteCapitalFactsReady` fails closed on stale/missing fields (`scenario_session_provider.dart:58-64`).
- The screen gates all financial UI behind `_scenarioUnavailable`, set true whenever the scenario boundary is required (`rente_vs_capital_screen.dart:199-203`, `718-720`).

So there is **no P0**: stale facts do not leak figures or persist a session in production.

## Findings

### P1 — The "runtime proof" does not execute in any flow (facade-without-wiring)
The headline deliverable of this branch is a runtime proof that never runs:

1. **Skipped under `flutter test`.** The body is gated `skip: !_runningFromPatrolCli` where `_runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI')` (`g1_scn01_scenario_isolation_patrol_test.dart:16,80`). In CI/unit runs `MINT_PATROL_CLI` is undefined → the test is registered but its assertions never execute.
   - Repro: `cd apps/mobile && flutter test test/patrol/g1_scn01_scenario_isolation_runtime_test.dart` → reports skipped, 0 assertions run.

2. **No orchestrator to run it under Patrol CLI.** Every other native-gated Patrol test has a driver (`tools/simulator/patrol_front01_*.sh`, `patrol_coach01_inline_amount.sh`, etc.) plus a `tools/checks/tests/test_*_runtime_orchestrator.py`. For scn01 there is **none**:
   - `grep -rl 'scn01\|scenario_isolation' tools/ .github/` → only the `test/patrol` re-export file, nothing else.

3. **Even a manual Patrol run cannot pass.** The test copies front01's visual-marker handshake: it writes a temp marker and `fail('Timed out waiting for visual evidence acknowledgement')` after 90s unless an external process deletes it (`g1_scn01_..._patrol_test.dart:204-219`). front01's pass depends on its orchestrator calling `remove_visual_marker` (`patrol_front01_frontier_jurisdiction.sh:234-249,585`). With no scn01 orchestrator, a hand-run `patrol test … --dart-define=MINT_PATROL_CLI=true` blocks and fails at the handshake.

Net: the branch ships a proof that is skipped in CI and unrunnable manually → false assurance that scenario isolation is covered at runtime. Fix: add a `tools/simulator/patrol_scn01_*.sh` orchestrator (+ its guard test) mirroring front01, **or** drop the visual handshake and `skip` gate so it runs as a real widget test under `flutter test`.

### P2 — Vacuous assertion overstates coverage
`g1_scn01_scenario_isolation_patrol_test.dart:99-102` asserts `find.byType(TextFormField) findsNothing`. The screen never uses `TextFormField`; its inputs are `TextField` (`rente_vs_capital_screen.dart:1279`). The assertion is trivially true whether or not the form renders, so it proves nothing about input suppression. It reads as if it guards "no input fields present." Should target `TextField`. (The sibling `find.byType(Slider) findsNothing` and the raw-default-text checks *are* meaningful — `Slider` is rendered via `hypothesis_editor_widget.dart:104`, and the digit strings are the controller defaults.)

## Evidence that would strengthen/close P1
- A `tools/simulator/patrol_scn01_scenario_isolation.sh` + matching `tools/checks/tests/test_*` orchestrator, or a CI job invoking it with `--dart-define=MINT_PATROL_CLI=true` and driving the marker handshake.

---

## Verdict: **NO-GO**

Production code is correct, but the branch's stated deliverable — a *scenario-isolation runtime proof* — is a facade: skipped in CI, no orchestrator, and unrunnable by hand due to an unhandled visual-marker handshake (P1), plus a vacuous `TextFormField` assertion (P2). Wire an orchestrator (or convert it to an executable widget test) and fix the assertion before merge.
