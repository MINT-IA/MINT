# Android Runtime Blockers

This file is the mechanical blocker ledger for Mint runtime acceptance claims.

## ANDROID-PHASE1-PHASE2-RUNTIME-PROOF

- status: open
- owner: mint-quality-gate
- blocks: any Android-targeted Phase 3 acceptance claim built on Phase 1 or Phase 2 runtime contracts
- requirement: run the Phase 1 data-ledger contract and Phase 2 data-quest contract on an Android emulator/device, then attach logs to the matching runtime-evidence folder
- current evidence:
  - `flutter devices` on 2026-07-03 found macOS and Chrome only; no Android emulator/device was available locally
  - `flutter emulators` on 2026-07-03 returned no emulator sources
  - `adb devices -l` on 2026-07-03 could not run because `adb` is not on PATH
  - `flutter build apk --debug` on 2026-07-03 failed before Gradle with `No Android SDK found`; evidence:
    `.planning/runtime-evidence/mint-lucidity-android-build-20260703T071219Z-debug/flutter-build-apk-debug.log`
- remediation path:
  - CI owner: `mint-quality-gate`
  - executable workflow: `.github/workflows/android-runtime-patrol.yml`
  - automatic triggers: `pull_request` for `apps/mobile/**`, `tools/checks/mint_lucidity_gate.sh`, and the workflow file itself; `push` on `claude/mint-swiss-coach-eu33i7` for the same paths; `workflow_dispatch` remains for manual reruns
  - target phase: before any Phase 3 or release claim that says "Android" or "cross-platform runtime accepted"
  - infrastructure: GitHub Actions `ubuntu-latest` + `reactivecircus/android-emulator-runner@v2` + API 35 Pixel emulator
  - required commands:
    - `flutter build apk --debug --dart-define=MINT_ENABLE_RUNTIME_PROOF_SEMANTICS=true`
    - `tools/checks/mint_lucidity_gate.sh mobile-p0-patrol emulator-5554`
  - runner support: `run_mobile_patrol_test()` no longer assumes an iOS simulator; it boots through `xcrun simctl` only when the supplied device id is present in `simctl list devices`, otherwise Patrol owns the Android device lifecycle
- allowed meanwhile: iOS-only Phase 2 continuation, provided release notes and scorecards do not claim Android runtime acceptance
