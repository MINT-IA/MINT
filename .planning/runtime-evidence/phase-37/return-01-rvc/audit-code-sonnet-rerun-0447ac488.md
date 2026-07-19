---

## Audit Report — codex/g1-capital-native-proof-20260718

**Base ref:** `9baffa8fb` → **HEAD:** `0447ac488`
**Files reviewed:** 10 changed files, 1089 insertions, 12 deletions
**Verdict: PASS**

---

### P0 findings

None.

---

### P1 findings

**P1-1 — Patrol test silently skips without `MINT_PATROL_CLI` dart-define**

- `apps/mobile/test/patrol/g1_return01_rvc_lpp_scan_return_runtime_test.dart:4`
- `apps/mobile/integration_test/g1_return01_rvc_lpp_scan_return_patrol_test.dart:31`

The patrol re-export respects `skip: !_runningFromPatrolCli`. Running `flutter test test/patrol/g1_return01_rvc_lpp_scan_return_runtime_test.dart` without `--dart-define=MINT_PATROL_CLI=true` exits 0 with a SKIP result, not a failure. Any CI step that sweeps `test/patrol/` without the dart-define would report green while the native proof was never collected.

**Concrete reproduction:**
```
cd apps/mobile
flutter test test/patrol/g1_return01_rvc_lpp_scan_return_runtime_test.dart
# → exits 0, "Skip: test skipped"
```

**Mitigating evidence:** This pattern is identical across every other Patrol test in the project (e.g., `g1_scn01_scenario_isolation_patrol_test.dart:16,155`) and reflects a deliberate architectural split between the structural contract gate (`test/runtime/`) and the native runner gate (`tools/simulator/patrol_return01_rvc_lpp_scan_return.sh`). The planning docs record the actual 1/1 pass at SHA `0447ac488b`. Not a defect, but a process-level gap: if the CI configuration ever runs `test/patrol/` without the dart-define, the native evidence claim becomes unverified.

---

**P1-2 — `lppEvidenceIngestionEnabled` gate: confirm it is a composite (resolved)**

- `apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart:287-288`

Integration and unit tests set `typedLppEvidence = true` and `documentLppEvidenceEnabled = true`, not `lppEvidenceIngestionEnabled` directly. Confirmed in `feature_flags.dart:129-130`:

```dart
static bool get lppEvidenceIngestionEnabled =>
    typedLppEvidence && documentLppEvidenceEnabled;
```

Both tests set both constituent flags. Gate is correctly exercised. **Resolved; listed for completeness.**

---

### P2 findings

**P2-1 — Log sanitizer UUID regex over-replaces all UUID-shaped tokens**

`tools/simulator/patrol_return01_rvc_lpp_scan_return.sh` (sanitize\_one\_log, ~line 490):

```python
text = re.sub(
    r"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b",
    "<DEVICE>",
    text,
)
```

Every UUID-shaped string in the log — including `scanSessionId`, `scanReturnId`, any transaction ID — is replaced with `<DEVICE>`. Log correlation is impossible if post-hoc investigation needs to trace a specific session pair. Privacy-safe; no correctness impact. The same pattern exists in `patrol_scn01_scenario_isolation.sh` so this is deliberate project policy.

**P2-2 — `Semantics(container: true)` indentation mismatch in RVC build method**

`apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:698-821`

The `Semantics` wrapper (8-space indent) and its `child: Scaffold(` (also 8-space) have the Scaffold's `body:` parameter at 6-space, which is shallower than the enclosing node. The bracket balance is correct (verified by reading the file), `flutter analyze` passes, and functionality is unaffected. A future reader could misinterpret the depth of the tree.

---

### Positive observations

- **Feature flag teardown is complete.** Lines 40-41 reset both flags in `addTearDown`, paired symmetrically with lines 37-38.
- **All 15 runtime contract anchors verified.** `test/runtime/g1_return01_rvc_lpp_scan_return_runtime_test.dart` anchor checks pass against the actual integration test source.
- **All 15 orchestrator Python test tokens present in the shell script.** Ordering assertion (`wait_for_visual_marker → maestro_with_watchdog.sh → remove_visual_marker`) verified by direct execution: offsets 17906 < 18307 < 19363.
- **Visual marker path equivalence is correct.** Flutter `Directory.systemTemp` on iOS Simulator maps to `NSTemporaryDirectory()` = `<data_container>/tmp/`, which is exactly `$app_container/tmp/` as computed by `xcrun simctl get_app_container ... data`. This mechanism is already proven by the GREEN `G1-SCN-01` runtime at accepted SHA `464d5c56b1`.
- **All Maestro YAML structural constraints satisfied.** `appId`, `takeScreenshot`, and absence of all six forbidden commands confirmed.
- **Shell script security controls are sound.** UDID format validation, bundle ID allowlist, exact-SHA HEAD check, symlink traversal protection with Python `resolve(strict=True)`, build isolation via external-root symlink, `umask 077`, and log sanitization with post-sanitization forbidden-string verification are all present and correctly implemented.
- **`lppEvidenceIngestionEnabled` gate verified as composite** — both constituent flags are set and torn down.
- **Unstaged diff is planning-only.** Three modified files are `.planning/` markdown documents recording the native proof outcome; no production or test code is modified outside the committed diff.

---

**PASS**
