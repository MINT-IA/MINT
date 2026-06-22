# Plan 02 Summary: Runtime Fresh Reset Relaunch Proof

## Result

PASS.

The Plan 02 runtime gate passed locally on the required simulator and produced
redacted evidence under:

`.planning/runtime-evidence/mint-runtime-debug-tooling-20260622T194729Z/`

The evidence directory is intentionally local-only because
`.planning/runtime-evidence/` is gitignored.

## Runtime Target

- Worktree: `/Users/julienbattaglia/Desktop/MINT.debug-spine.nosync`
- Branch: `feature/S09-mint2-runtime-quality-gate`
- HEAD at gate run: `89447d081`
- Simulator: `MINT iPhone 13 mini RvC`
- Simulator UDID: redacted from evidence artifacts
- Simulator UDID SHA-256: `38017273cd77812a56479f75f91f481ce31253127742949944bb457f4580ffa0`
- API base URL: `https://mint-staging.up.railway.app/api/v1`

## Commands

- `xcrun simctl keychain <redacted-udid> reset`
- `PATROL_ANALYTICS_ENABLED=false patrol test -d "MINT iPhone 13 mini RvC" -t test/patrol/mint_runtime_debug_gate_test.dart ... --dart-define=MINT_RUNTIME_DEBUG_LEG=reset`
- `xcrun simctl terminate <redacted-udid> ch.mint.app`
- `PATROL_ANALYTICS_ENABLED=false patrol test -d "MINT iPhone 13 mini RvC" -t test/patrol/mint_runtime_debug_gate_test.dart ... --dart-define=MINT_RUNTIME_DEBUG_LEG=relaunch`
- `Vision OCR final-reset-state.png`
- `idb ui describe-all --udid <redacted-udid> --json`
- `tools/checks/mint_runtime_debug_tooling_gate.sh --artifact-scan-only .planning/runtime-evidence/mint-runtime-debug-tooling-20260622T194729Z`

## Evidence

- `debug-spine-before_reset.json`
- `debug-spine-after_reset.json`
- `debug-spine-after_relaunch.json`
- `final-reset-state.png`
- `final-reset-state.ocr.txt`
- `ui-tree.json`
- `ui-tree.txt`
- `artifact-scan.log`
- `run.log`
- `run-summary.txt`

The final `after_relaunch` Debug Spine JSON reports:

- wizard answers absent;
- budget inputs absent;
- budget overrides absent;
- anonymous message count `0`;
- anonymous conversation count `0`;
- current-user conversation count `0`;
- account handoff choice `none`;
- local data owner absent;
- migrated/sync-pending local-data flags `0`;
- sync-off local account mode absent;
- held anonymous diagnostic absent;
- corrupt wizard/budget state absent;
- network summary recording with forbidden match count `0`;
- Keychain observable status marked as reset by the gate.

## Notes

- The first simulator leg is true-fresh: simulator shutdown/boot, keychain reset, and app uninstall happen before Patrol launches the app.
- The relaunch proof is a second Patrol process after `simctl terminate`, so it re-reads persisted Debug Spine state after cold app/test relaunch.
- The fixture covers `keep_local`, `restart_clean`, local data owner, local data migrated/sync-pending flags, and `auth_local_mode`.
- The gate resets generated Patrol iOS build state (`build/ios_integ`, `.dart_tool/flutter_build`) and applies the xattr scrub path before build. Earlier diagnostics showed local `xcodebuild 65` failures caused by `Flutter.framework` provenance/resource-fork metadata; the final run passed without retry.
- Evidence artifacts redact the raw simulator UDID and scan text artifacts plus screenshot OCR text. UI-tree text is still captured as secondary state evidence, not as image OCR coverage.
- This closes the simulator reset/relaunch bug class. It does not claim physical iPhone, TestFlight, iCloud restore, or real Apple credential behavior.
