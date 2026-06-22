---
phase: mint-runtime-debug-tooling-m1
plan: 03-ci-release-closeout
type: tdd
wave: 3
depends_on: [02-runtime-fresh-reset-relaunch]
files_modified:
  - .github/workflows/ci.yml
  - .github/workflows/patrol.md
  - tools/checks/**
  - .planning/phases/mint-runtime-debug-tooling-m1/**
autonomous: false
requirements: [ci-static-gate, release-binary-scan, review-closeout]
must_haves:
  truths:
    - "Linux CI runs only deterministic static parts and does not fake iOS proof"
    - "Release/profile build artifacts are scanned for debug route leakage"
    - "The phase cannot close without Plan 02 runtime evidence"
  artifacts:
    - path: "tools/checks/mint_runtime_debug_tooling_gate.sh"
      provides: "CI-safe static mode and local iOS mode"
      contains: "--ci-static-only"
    - path: ".planning/phases/mint-runtime-debug-tooling-m1/SUMMARY.md"
      provides: "Closeout receipt"
      contains: "GO / NO-GO"
  key_links:
    - from: "CI static gate"
      to: "local iOS runtime gate"
      via: "printed command"
      pattern: "mint_runtime_debug_tooling_gate"
---

<objective>
Wire the non-device parts into CI, add release/profile leakage proof, and close
the phase only after targeted expert reviews and Claude Max agree that the
runtime evidence is sufficient.
</objective>

<execution_context>
@.planning/phases/mint-runtime-debug-tooling-m1/CONTEXT.md
@.planning/phases/mint-runtime-debug-tooling-m1/02-runtime-fresh-reset-relaunch-SUMMARY.md
@.github/workflows/ci.yml
@.github/workflows/testflight.yml
@.github/workflows/play-store.yml
@tools/checks/mint_debug_spine_gate.sh
@tools/checks/mint_runtime_debug_tooling_gate.sh
</execution_context>

<context>
GitHub Linux runners cannot prove iOS Patrol. CI must still prevent silent
regression of static contracts and debug leakage, while local macOS remains the
source of runtime evidence.
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add CI-safe static mode</name>
  <files>tools/checks/mint_runtime_debug_tooling_gate.sh, .github/workflows/ci.yml</files>
  <action>Add `--ci-static-only` to run Debug Spine contract tests, artifact-scan unit tests, route/debug flag checks, and release-workflow dart-define scans. Wire that mode into CI only for mobile/tooling changes. The CI step must print the local macOS iOS command and state that it is not runtime proof.</action>
  <verify>
    <automated>tools/checks/mint_runtime_debug_tooling_gate.sh --ci-static-only</automated>
  </verify>
  <done>CI enforces non-device contracts and cannot be mistaken for iOS runtime proof.</done>
</task>

<task type="auto" tdd="true">
	  <name>Task 2: Add release/profile debug leakage scan</name>
	  <files>tools/checks/mint_runtime_debug_tooling_gate.sh, tools/checks/**</files>
	  <behavior>
	    - Production workflows must not pass any accepted enabling spelling: `ENABLE_ADMIN=(1|true)` or `ENABLE_DEBUG_TOOLS=(1|true)`.
	    - The scan covers direct `--dart-define`, environment-wrapped build args, and dart-define-from-file inputs.
	    - Release/profile build or compiled artifact scan must reject `/admin/debug-spine`, Debug Spine labels, debug snapshot identifiers, and `ENABLE_DEBUG_TOOLS` when present in shipped artifacts.
	  </behavior>
  <action>Add a deterministic scan command. If full release build is too expensive for normal CI, keep it as a local required closeout command and wire the workflow dart-define scan into CI. Do not claim tree-shaking proof without an artifact scan.</action>
  <verify>
    <automated>tools/checks/mint_runtime_debug_tooling_gate.sh --release-scan-only</automated>
  </verify>
  <done>Release/debug leakage has mechanical proof, not just source inspection.</done>
</task>

<task type="manual">
  <name>Task 3: Targeted reviews</name>
  <files>.planning/phases/mint-runtime-debug-tooling-m1/SUMMARY.md</files>
  <action>Run qa-expert, flutter-expert, security-auditor or mobile-security-coder, and Claude Max on the final diff. Scope each review to this phase and evidence artifacts only. Fix every blocker and rerun targeted reviews.</action>
  <verify>
    <manual>Review outputs show GO or each blocker has a linked follow-up commit and repeated targeted GO.</manual>
  </verify>
  <done>Reviewer status is recorded with scores, blockers, and fixes.</done>
</task>

<task type="manual">
  <name>Task 4: Closeout or NO-GO</name>
  <files>.planning/phases/mint-runtime-debug-tooling-m1/SUMMARY.md, .planning/ROADMAP.md, .planning/STATE.md</files>
  <action>Create the closeout summary. If Plan 02 runtime evidence is missing, mark NO-GO and do not close the phase. If all gates passed, record exact commands, exit statuses, evidence path, reviewers, and remaining physical-device/TestFlight gap.</action>
  <verify>
    <automated>git diff --check && python3 tools/checks/wiki_lint.py lint</automated>
  </verify>
  <done>Phase status is honest: GO with evidence, or NO-GO with the missing prerequisite.</done>
</task>

</tasks>

<verification>
- `tools/checks/mint_runtime_debug_tooling_gate.sh --ci-static-only`
- `tools/checks/mint_runtime_debug_tooling_gate.sh --release-scan-only`
- `git diff --check`
- targeted expert reviews and Claude Max on final diff
</verification>

<success_criteria>
CI prevents static/debug regressions, local macOS remains the iOS runtime proof,
release leakage is mechanically scanned, and the phase closes only with complete
evidence.
</success_criteria>

<output>
Create `SUMMARY.md` with GO/NO-GO, commands, exit statuses, evidence path,
review verdicts, and explicit remaining TestFlight/physical-device scope.
</output>
