---
phase: mint-runtime-debug-tooling-m1
plan: 00-orchestration
type: plan
wave: 0
depends_on: [mint-debug-spine-m0, mint-2-0-first-experience-rente-capital]
files_modified:
  - .planning/phases/mint-runtime-debug-tooling-m1/01-patrol-bootstrap-contract-PLAN.md
  - .planning/phases/mint-runtime-debug-tooling-m1/02-runtime-fresh-reset-relaunch-PLAN.md
  - .planning/phases/mint-runtime-debug-tooling-m1/03-ci-release-closeout-PLAN.md
autonomous: false
requirements: [runtime-proof, privacy-redaction, no-financial-residue, no-release-debug-tools]
must_haves:
  truths:
    - "M1 is a tooling phase, not the active Mint 2.0 product router"
    - "The execution is split into three bounded plans, not one broad patch"
    - "Patrol is decisive only when backed by Debug Spine JSON and redacted network evidence"
  artifacts:
    - path: ".planning/phases/mint-runtime-debug-tooling-m1/01-patrol-bootstrap-contract-PLAN.md"
      provides: "Patrol/bootstrap and evidence contract setup"
      contains: "patrol"
    - path: ".planning/phases/mint-runtime-debug-tooling-m1/02-runtime-fresh-reset-relaunch-PLAN.md"
      provides: "Fresh/reset/relaunch runtime gate"
      contains: "xcrun simctl keychain"
    - path: ".planning/phases/mint-runtime-debug-tooling-m1/03-ci-release-closeout-PLAN.md"
      provides: "CI static gate, release scan, review closeout"
      contains: "release binary"
  key_links:
    - from: "CONTEXT.md"
      to: "three bounded execution plans"
      via: "PLAN.md"
      pattern: "Execution Order"
---

<objective>
Turn the Reddit-informed debug-tooling direction into three executable GSD
plans. This is not product work and it does not promote the active context.
The active product phase remains `mint-2-0-first-experience-rente-capital`;
M1 is a tooling follow-up that must be explicitly selected before execution.
</objective>

<execution_context>
@.planning/phases/mint-runtime-debug-tooling-m1/CONTEXT.md
@.planning/phases/mint-runtime-debug-tooling-m1/RESEARCH.md
@.planning/phases/mint-runtime-debug-tooling-m1/VERIFICATION.md
@AGENTS.md
@CLAUDE.md
@docs/MINT_AGENT_WORKFLOW.md
</execution_context>

<context>
Reviewers rejected the first draft because it was too broad, not mechanically
GSD-structured, and underspecified for Patrol bootstrap, fresh iOS Keychain
state, network evidence, screenshots, and release leakage. This orchestration
plan splits the work into bounded plans and makes those blockers explicit.
</context>

<tasks>

<task type="manual">
  <name>Task 1: Execute Plan 01 first</name>
  <files>.planning/phases/mint-runtime-debug-tooling-m1/01-patrol-bootstrap-contract-PLAN.md</files>
  <action>Run the Patrol bootstrap/evidence-contract plan first. Do not start the runtime flow until Patrol can launch the app and Debug Spine can export redacted JSON without relying on screen scraping.</action>
  <verify>
    <automated>gsd-sdk query verify.plan-structure .planning/phases/mint-runtime-debug-tooling-m1/01-patrol-bootstrap-contract-PLAN.md</automated>
  </verify>
  <done>Plan 01 is structurally valid and becomes the first execution unit.</done>
</task>

<task type="manual">
  <name>Task 2: Execute Plan 02 only after Plan 01</name>
  <files>.planning/phases/mint-runtime-debug-tooling-m1/02-runtime-fresh-reset-relaunch-PLAN.md</files>
  <action>Run the runtime proof only after Plan 01 has installed Patrol and the redacted evidence/network contracts. This plan owns the iOS fresh-state primitive, seeded residue, reset, relaunch, screenshots, UI-tree/OCR scan, and fail-closed evidence checks.</action>
  <verify>
    <automated>gsd-sdk query verify.plan-structure .planning/phases/mint-runtime-debug-tooling-m1/02-runtime-fresh-reset-relaunch-PLAN.md</automated>
  </verify>
  <done>Plan 02 is structurally valid and depends on Plan 01 outputs.</done>
</task>

<task type="manual">
  <name>Task 3: Execute Plan 03 last</name>
  <files>.planning/phases/mint-runtime-debug-tooling-m1/03-ci-release-closeout-PLAN.md</files>
  <action>Run CI/static/release closeout after Plan 02 produces local iOS evidence. This plan owns Linux-safe CI, release binary scans, reviewer closeout, and honest NO-GO if the iOS runtime proof is missing.</action>
  <verify>
    <automated>gsd-sdk query verify.plan-structure .planning/phases/mint-runtime-debug-tooling-m1/03-ci-release-closeout-PLAN.md</automated>
  </verify>
  <done>Plan 03 is structurally valid and gated on Plan 02 evidence.</done>
</task>

</tasks>

<verification>
Run:
`gsd-sdk query verify.plan-structure` on PLAN.md and all three numbered
plans, `git diff --check`, `python3 tools/checks/wiki_lint.py lint`, and the
active context guards. This phase cannot close on orchestration alone; closeout
belongs to Plan 03 after actual runtime evidence exists.
</verification>

<success_criteria>
The phase has three bounded, mechanically checkable plans. No execution unit
spans Patrol setup, runtime proof, CI, and closeout at once. Every plan has a
clear NO-GO condition and no claim that simulator evidence closes physical
iPhone/TestFlight restore.
</success_criteria>

<output>
Commit only planning artifacts after plan-check, QA, Flutter, security, and
Claude Max targeted reviews return GO or every blocker is addressed.
</output>
