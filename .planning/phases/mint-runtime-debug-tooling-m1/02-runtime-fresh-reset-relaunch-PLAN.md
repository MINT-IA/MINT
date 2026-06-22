---
phase: mint-runtime-debug-tooling-m1
plan: 02-runtime-fresh-reset-relaunch
type: tdd
wave: 2
depends_on: [01-patrol-bootstrap-contract]
files_modified:
  - apps/mobile/test/patrol/**
  - apps/mobile/lib/services/debug/**
  - apps/mobile/lib/services/observability/**
  - apps/mobile/test/services/debug/**
  - tools/checks/mint_runtime_debug_tooling_gate.sh
  - .planning/runtime-evidence/**
autonomous: false
requirements: [fresh-state, reset-relaunch, network-proof, screenshot-privacy]
must_haves:
  truths:
    - "True-fresh iOS simulator state resets Keychain, not only app data"
    - "Network evidence records endpoint/method/status/count only"
    - "Screenshots are secondary evidence and must pass text extraction or fail closed"
  artifacts:
    - path: "tools/checks/mint_runtime_debug_tooling_gate.sh"
      provides: "One-command local runtime gate"
      contains: "simctl keychain"
    - path: ".planning/runtime-evidence/"
      provides: "Redacted local runtime evidence"
      contains: "debug-spine"
  key_links:
    - from: "runtime gate"
      to: "Debug Spine JSON"
      via: "redacted evidence export"
      pattern: "schemaVersion"
---

<objective>
Create the first decisive local runtime proof: true-fresh iOS simulator,
seeded synthetic residue, Patrol navigation, reset, relaunch, redacted Debug
Spine state, screenshot text scan, and network non-sync assertion.
</objective>

<execution_context>
@.planning/phases/mint-runtime-debug-tooling-m1/CONTEXT.md
@.planning/phases/mint-runtime-debug-tooling-m1/01-patrol-bootstrap-contract-SUMMARY.md
@docs/data-flow.md
@tools/simulator/mint2_quality_gate.sh
@apps/mobile/lib/services/install_lifecycle_service.dart
@apps/mobile/lib/providers/auth_provider.dart
@apps/mobile/lib/providers/coach_profile_provider.dart
@apps/mobile/lib/services/observability/mint_http_client.dart
@apps/mobile/lib/services/debug/mint_debug_spine_service.dart
</execution_context>

<context>
This plan owns the bug class that manual TestFlight screenshots failed to make
efficient: stale local data, unclear reset/delete behavior, ghost financial
values, and unauthorized sync. It does not close physical iPhone/iCloud restore.
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Define true-fresh and seeded-residue fixtures</name>
  <files>tools/checks/mint_runtime_debug_tooling_gate.sh, apps/mobile/test/patrol/mint_runtime_debug_gate_test.dart</files>
  <behavior>
    - True-fresh simulator state uses `xcrun simctl shutdown`, boot target simulator, `xcrun simctl keychain <UDID> reset`, and app uninstall before launch.
    - In-app reset/relaunch leg uses product/debug reset without erasing the simulator, so persistence bugs can surface.
    - Seeded residue uses synthetic sentinel strings that are impossible to confuse with real data.
  </behavior>
  <action>Implement the shell preflight and test fixture seed contract. The gate must fail if it cannot reset Keychain or resolve exactly one target simulator. Add a Debug Spine row/field that proves owned secure purge pending and install secure purge pending status after reset.</action>
  <verify>
    <automated>tools/checks/mint_runtime_debug_tooling_gate.sh --dry-run</automated>
  </verify>
  <done>Fresh state and seeded residue are explicit and cannot be confused with reinstall-only state.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add redacted network recorder</name>
  <files>apps/mobile/lib/services/observability/mint_http_client.dart, apps/mobile/lib/services/debug/mint_debug_spine_service.dart, apps/mobile/test/services/debug/mint_debug_spine_service_test.dart</files>
	  <behavior>
	    - Recorder stores method, normalized endpoint path, status class, and count only.
	    - Recorder never stores headers, bodies, query params, tokens, device ids, request payloads, or response payloads.
	    - Forbidden call matchers include `/sync/claim-local-data`, profile writes, coach sync, snapshot endpoints, `claimLocalData`, and `_syncToBackend`-origin pushes.
	    - Existing debug HTTP body logging is disabled or redacted during the Patrol gate; runtime evidence must not include `BODY:` request/response logs.
	    - Recording is attached at the central `MintHttpClient.shared` layer. An `ApiService.setHttpClientForTesting` hook alone is insufficient unless the executor proves every forbidden endpoint bypass is covered by callsite tests.
	  </behavior>
	  <action>Add a debug/test-only network summary hook around `MintHttpClient.shared`. Prefer a client-side allowlisted recorder over proxy logs. Wire its summary into Debug Spine JSON. Tests assert redaction, forbidden-call detection, and suppression of existing body logs in gate mode.</action>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/debug/mint_debug_spine_service_test.dart</automated>
  </verify>
  <done>Network proof is deterministic and cannot leak auth or body data.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Implement Patrol fresh-reset-relaunch proof</name>
  <files>apps/mobile/test/patrol/mint_runtime_debug_gate_test.dart, tools/checks/mint_runtime_debug_tooling_gate.sh</files>
  <action>Drive the first-experience path with Patrol, then export Debug Spine JSON before reset, after reset, and after relaunch. Add one synthetic account-handoff leg without real Apple credentials: seed guest residue, enter the debug/test account lifecycle states needed to cover `keep_local`, `restart_clean`, `local_data_migrated_*`, and sync-off account behavior, and prove guest data is not silently claimed unless the explicit claim path is exercised. Assertions must check every residue class from CONTEXT: local profile, wizard answers, budget inputs, budget overrides, anonymous message count, anonymous conversation namespace, current-user namespace, owned secure purge pending, install secure purge pending, Keychain residue status if observable, account lifecycle residue, and network summary.</action>
  <verify>
    <automated>tools/checks/mint_runtime_debug_tooling_gate.sh</automated>
  </verify>
  <done>The runtime gate fails on stale residue and passes only when every residue class is clean or explicitly explained by a pending secure purge flag.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 4: Add screenshot and UI-tree privacy gate</name>
  <files>tools/checks/mint_runtime_debug_tooling_gate.sh, apps/mobile/test/patrol/mint_runtime_debug_gate_test.dart</files>
  <action>Capture screenshots only from constrained final/reset Debug Spine states. Export UI-tree text or OCR text for each required screenshot. Scan extracted text and JSON/log artifacts for forbidden sentinel values, email/JWT patterns, raw chat text, and value-bearing CHF patterns. Bare `CHF` alone is not a failure; `CHF` adjacent to digits is. Fail closed if text extraction is unavailable.</action>
  <verify>
    <automated>tools/checks/mint_runtime_debug_tooling_gate.sh --artifact-scan-only .planning/runtime-evidence/<latest></automated>
  </verify>
  <done>Screenshot evidence cannot silently contain raw private or financial text.</done>
</task>

</tasks>

<verification>
- `tools/checks/mint_runtime_debug_tooling_gate.sh --dry-run`
- `tools/checks/mint_runtime_debug_tooling_gate.sh`
- Evidence includes redacted JSON, network summary, screenshots, extracted UI/OCR text, and artifact scan log.
</verification>

<success_criteria>
The gate proves the simulator class of reset/relaunch bugs with true-fresh
Keychain handling and state-backed assertions. It explicitly does not close
physical iPhone/TestFlight/iCloud restore. It also proves the simulator account
handoff state classes listed above, without claiming real Apple/iCloud behavior.
</success_criteria>

<output>
Create `02-runtime-fresh-reset-relaunch-SUMMARY.md` with exact simulator UDID,
commands, exit statuses, evidence path, and any remaining physical-device gap.
</output>
