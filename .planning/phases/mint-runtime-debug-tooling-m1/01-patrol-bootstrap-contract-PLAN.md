---
phase: mint-runtime-debug-tooling-m1
plan: 01-patrol-bootstrap-contract
type: tdd
wave: 1
depends_on: [00-orchestration]
files_modified:
  - apps/mobile/pubspec.yaml
  - apps/mobile/ios/**
  - apps/mobile/test/patrol/**
  - apps/mobile/lib/services/debug/**
  - apps/mobile/test/services/debug/**
  - apps/mobile/test/screens/admin/**
  - .github/workflows/patrol.md
autonomous: false
requirements: [patrol-bootstrap, redacted-evidence-contract, no-release-debug-tools]
must_haves:
  truths:
    - "Patrol is installable from the repo instructions, not assumed from PATH"
    - "Debug Spine assertions use redacted Dart JSON, not only UI text or screenshots"
    - "No release/debug leakage is introduced by Patrol bootstrap"
  artifacts:
    - path: "apps/mobile/pubspec.yaml"
      provides: "Patrol dependency and configuration"
      contains: "patrol"
    - path: "apps/mobile/test/patrol/mint_runtime_debug_gate_test.dart"
      provides: "First Patrol debug-spine launch test"
      contains: "MintDebugSpine"
    - path: "apps/mobile/lib/services/debug/mint_debug_spine_service.dart"
      provides: "Versioned redacted evidence export"
      contains: "schemaVersion"
  key_links:
    - from: "Patrol test"
      to: "Debug Spine JSON"
      via: "redacted export"
      pattern: "loadSnapshot"
---

<objective>
Install the smallest viable Patrol path for Mint and harden the Debug Spine
evidence contract before any runtime flow is trusted. The output of this plan is
not a user journey proof; it is the harness and redacted state contract that
Plan 02 will use.
</objective>

<execution_context>
@.planning/phases/mint-runtime-debug-tooling-m1/CONTEXT.md
@.planning/phases/mint-runtime-debug-tooling-m1/VERIFICATION.md
@.github/workflows/patrol.md
@apps/mobile/pubspec.yaml
@apps/mobile/lib/main.dart
@apps/mobile/lib/app.dart
@apps/mobile/lib/screens/admin/mint_debug_tools_gate.dart
@apps/mobile/lib/services/debug/mint_debug_spine_service.dart
@tools/checks/mint_debug_spine_gate.sh
</execution_context>

<context>
Current repo policy says Patrol is a manual gate under `apps/mobile/test/patrol/`.
The first draft incorrectly assumed `patrol test` without installing
`patrol_cli`, omitted `apps/mobile/ios/**`, and did not choose between
production startup and a test bootstrap. This plan must make that choice
explicit.
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Prove current Patrol prerequisite failure</name>
  <files>apps/mobile/pubspec.yaml, .github/workflows/patrol.md</files>
  <action>Write a short setup note or failing check in the plan summary showing the current state: no `patrol` dev dependency/config in pubspec, whether `patrol` CLI is present, and whether iOS UITest bootstrap exists. Do not add product code yet. This prevents a false RED caused by a missing tool.</action>
  <verify>
    <automated>cd apps/mobile && (command -v patrol || true) && rg -n "^[[:space:]]*patrol:" pubspec.yaml .github/workflows/patrol.md || true</automated>
  </verify>
  <done>The executor records the exact missing prerequisites before installing anything.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add repo-local Patrol configuration</name>
  <files>apps/mobile/pubspec.yaml, apps/mobile/ios/**, .github/workflows/patrol.md</files>
  <action>Add `patrol` as a dev dependency and a `patrol:` config with the Mint iOS bundle id and `test_directory: test/patrol`. Install or document `patrol_cli` through the gate script instead of assuming it is globally available. The setup check must fail closed when `patrol`/`patrol_cli` is missing after installation instructions have run; a missing CLI may be recorded only as a NO-GO prerequisite, never as passing setup. Run the official iOS bootstrap step and verify no new production entitlement or release capability is added. Update `.github/workflows/patrol.md` if the command changes from legacy `flutter test` to `patrol test`.</action>
  <verify>
    <automated>cd apps/mobile && flutter pub get && command -v patrol && dart pub global list | grep -q "patrol_cli"</automated>
    <automated>git diff -- apps/mobile/ios | rg -n "com.apple.developer|aps-environment|keychain-access-groups" && exit 1 || true</automated>
  </verify>
  <done>Patrol can be invoked from documented local prerequisites, and iOS bootstrap does not add production entitlements.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Add redacted Debug Spine export</name>
  <files>apps/mobile/lib/services/debug/mint_debug_spine_service.dart, apps/mobile/test/services/debug/mint_debug_spine_service_test.dart</files>
  <behavior>
    - Export has a schema version.
    - Export contains only counts, booleans, enum-like labels, and corruption flags.
    - Export includes all residue classes: wizard answers, budget inputs, budget overrides, anonymous messages, anonymous conversations, current-user conversations, owned secure purge pending, install secure purge pending, Keychain residue status if observable, and network summary placeholder.
    - Export never contains raw answers, raw financial values, email, token, device id, or chat body.
  </behavior>
  <action>Add a JSON export method or DTO to the existing Debug Spine service. Tests seed synthetic sentinel values and assert the export contains only redacted fields and cannot leak sentinel strings.</action>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/debug/mint_debug_spine_service_test.dart</automated>
  </verify>
  <done>Debug Spine evidence is machine-readable and privacy-safe before Patrol uses it.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 4: Add first Patrol launch test against debug state</name>
  <files>apps/mobile/test/patrol/mint_runtime_debug_gate_test.dart, apps/mobile/lib/main.dart, apps/mobile/lib/app.dart</files>
  <action>Create the smallest Patrol test that launches Mint with production startup unless a test bootstrap is strictly needed. If a bootstrap is needed, extract only common initialization required for tests and document the difference from production startup. Pass the actual Mint2 flags used by `tools/simulator/mint2_quality_gate.sh`: `API_BASE_URL`, `MINT_DISABLE_BETA_MODAL=true`, `MINT_E2E_MINT2_FIRST_EXPERIENCE=true`, `MINT_E2E_PROOF_ANCHORS=true`, plus `ENABLE_ADMIN=1` and `ENABLE_DEBUG_TOOLS=1`.</action>
  <verify>
    <automated>cd apps/mobile && command -v patrol && patrol test -t test/patrol/mint_runtime_debug_gate_test.dart --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 --dart-define=MINT_DISABLE_BETA_MODAL=true --dart-define=MINT_E2E_MINT2_FIRST_EXPERIENCE=true --dart-define=MINT_E2E_PROOF_ANCHORS=true --dart-define=ENABLE_ADMIN=1 --dart-define=ENABLE_DEBUG_TOOLS=1</automated>
  </verify>
  <done>Patrol can launch the app and assert the redacted Debug Spine state without relying on screen text as the source of truth.</done>
</task>

</tasks>

<verification>
- `gsd-sdk query verify.plan-structure .planning/phases/mint-runtime-debug-tooling-m1/01-patrol-bootstrap-contract-PLAN.md`
- `cd apps/mobile && flutter test test/services/debug/mint_debug_spine_service_test.dart`
- Local Patrol command above exits 0, or missing Patrol prerequisites are recorded as NO-GO without claiming runtime proof.
</verification>

<success_criteria>
Patrol setup is real, documented, and tied to Mint's actual flags. Debug Spine
exports redacted JSON. The phase has not yet claimed fresh/reset/relaunch proof.
</success_criteria>

<output>
Create `01-patrol-bootstrap-contract-SUMMARY.md` with prerequisites, exact
commands, diffs, and explicit remaining NO-GO items for Plan 02.
</output>
