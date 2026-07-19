---

## Audit Report — G1-SCN-01 Capital Native Proof

**Branch:** `codex/g1-capital-native-proof-20260718`
**Base ref:** `bcf3a067c`
**Files reviewed:** 4 new files, 1 661 lines
**Test run:** 25/25 orchestrator tests pass (19 s, clean)

---

### Verdict

**PASS**

---

### P0 — Blocking

None.

---

### P1 — Critical

None.

Every code path I probed was sound:

| Scenario | Correctness |
|---|---|
| Build failure (`PATROL_EXIT≠0`) | `remove_generated_bundle` + `restore_build_isolation` + sanitize + metadata(`failed`) → `exit $runtime_status` ✓ |
| xcodebuild failure (`XCODE_EXIT≠0`) | `xcode_killed_for_handshake=false`, `xcode_status≠0` → `runtime_status=$xcode_status`, screenshot discarded, metadata(`failed`) ✓ |
| Screenshot fails / marker removal succeeds | `screenshot_status=2`, xcodebuild runs to natural exit, `visual_wait_status=0 \|\| screenshot_status≠0` → `runtime_status=2` ✓ |
| Screenshot fails / marker removal also fails | `xcode_killed_for_handshake=true` → `runtime_status=2` regardless of `xcode_status` ✓ |
| Invalid marker payload | `validate_visual_marker` fails, `wait_for_visual_marker` returns 2, xcodebuild killed, `cleanup_visual_marker` removes without payload re-check ✓ |
| SIGTERM during patrol build | `handle_signal 143` kills patrol, `EXIT` trap restores build + bundle ✓ |
| `restore_build_isolation` idempotence | `build_isolation_armed` flag prevents double-restore in `cleanup()` ✓ |
| Artifacts path traversal | Python validates `candidate.parent == expected_parent` after `resolve(strict=False)`, then name matches `runtime-<sha10>-<UTC>` ✓ |
| Log sanitization | Replacements sorted longest-first, device UUID also caught by UUID regex fallback, post-condition loop confirms no raw value survives ✓ |
| `screenshotSha256` on failure paths | `write_metadata 'failed' "$log_hash"` (no 3rd arg) → `screenshot_hash or None` → JSON `null` ✓ |

Signal handler clears `patrol_pid` correctly; the xcodebuild is `wait()`-ed even after `kill -TERM` so there is no zombie. `handle_signal` exits, then the `EXIT` trap fires — trap ordering `trap - HUP INT TERM` inside `handle_signal` prevents double-entry.

---

### P2 — Non-blocking observations

**P2-1 · Implicit `.dart_tool` gitignore dependency**
`prepare_build_isolation` (line 351) unconditionally creates `$mobile/.dart_tool/`. `verify_runtime_sources_clean` checks `git ls-files --others --exclude-standard -- apps/mobile`. If `.dart_tool` were not gitignored, the second `verify_runtime_sources_clean` call would fail even on a passing run. Confirmed: `apps/mobile/.gitignore:36` contains `.dart_tool/`, so this is safe in the current repo, but the runner carries a silent dependency on it. No action required; a defensive comment or an explicit early check would be cheap insurance.

**P2-2 · Fake-git `ls-files --others` stub under-models reality**
`test_g1_scn01_scenario_isolation_runtime_orchestrator.py` — the fake git only emits `test_bundle.dart` for untracked-files queries; it does not simulate `.dart_tool` appearing as untracked. Tests pass unconditionally on that branch. If `.dart_tool` ever stopped being gitignored the orchestrator tests would still pass while the real runner would fail. Low risk given P2-1.

**P2-3 · Screenshot silently discarded on test failure**
When xcodebuild exits non-zero, a screenshot may already have been taken into `private_dir` but is never promoted to `final_screenshot` (the `runtime_status≠0` path exits before `install`). This is correct per-design (failed evidence ≠ valid evidence), but an operator expecting to retrieve a failure screenshot would find nothing. Document-level note only.

**P2-4 · `resolve_app_container` part-count guard is `< 10` not `< 11`**
`patrol_scn01_scenario_isolation.sh` line 195: `len(parts) < 10` with a 9-element expected tuple. A path with exactly 10 parts would pass the length check but fail the tuple comparison anyway (parts[-10] would be `/`). No exploitable gap — just a minor off-by-one in the defensive comment of the guard.

---

### Privacy / Compliance

- `metadata.json` emits `"device": "<redacted>"` — device UDID never persists. ✓
- Log sanitizer replaces repo, home, TMPDIR, private temp dir, and the literal device UDID in longest-first order, then sweeps any residual UUID-shaped token. Post-condition loop verifies no raw value survives. ✓
- Screenshot bytes are checked for the same forbidden strings before install. ✓
- Synthetic profile in the Dart test (`birthYear: 1976`, `canton: 'VD'`, etc.) is clearly fabricated, not real user data. Session UUID is `55555555-5555-4555-8555-555555555555`. ✓
- `umask 077` at script top and `chmod 700` / `chmod 600` on all artifact files prevent group/world read. ✓

---

### Routing / Facade-without-wiring

- The Dart test is gated by `skip: !_runningFromPatrolCli` where `_runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI')` — a compile-time constant. Normal `flutter test` skips the body; only the `patrol build --dart-define=MINT_PATROL_CLI=true` compilation activates it. No risk of a silent skip under CI. ✓
- The wrapper (`test/patrol/g1_scn01_scenario_isolation_runtime_test.dart`) re-exports `integration_test/...main()` — the single source of truth is the integration test file. No drift surface. ✓
- The shell runner verifies three tracked-file contracts (`ls-files --error-unmatch`) and diffs them against `$expected_sha` before any build action. ✓
- `patrol_scn01_scenario_isolation.sh` is itself in `tracked_files`, so the runner refuses to execute if it has been modified since the requested SHA. ✓
