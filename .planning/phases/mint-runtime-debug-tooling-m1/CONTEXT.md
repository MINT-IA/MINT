---
phase: mint-runtime-debug-tooling-m1
status: ready-for-planning
created: 2026-06-22
source: GSD compact phase from Reddit/tooling research and Mint Debug Spine M0
---

# Mint Runtime Debug Tooling M1 — Context

Mint Runtime Debug Tooling M1 turns the current debug-spine work into a
repeatable runtime proof loop. It does not change product behavior. It gives
agents and humans a way to prove what the app did on device before shipping
another account, profile, coach, or financial-surface change.

## Phase Boundary

This phase delivers one vertical proof path split across three execution plans:

1. fresh iPhone simulator state;
2. launch Mint with debug tools enabled only in non-release builds;
3. exercise one critical first-experience/account/profile path with Patrol
   using Mint's actual E2E flags from `tools/simulator/mint2_quality_gate.sh`;
4. collect redacted Debug Spine state before and after reset/relaunch;
5. assert no forbidden financial residue, no cloud sync without explicit auth
   consent, and no stale anonymous conversation resurrection;
6. save local evidence under `.planning/runtime-evidence/`.

The phase may add tests, scripts, docs, and dev-only instrumentation behind
existing debug gates. It must not add a new product route, calculation engine,
onboarding surface, coach behavior, or user-visible financial claim.

This is not the active routed product phase. `.planning/ACTIVE_CONTEXT.*` stays
on `mint-2-0-first-experience-rente-capital` unless Julien explicitly promotes
this tooling phase. Active-context guards remain required to prove the incumbent
router is coherent, not to claim this phase is active.

## Locked Decisions

### Tooling Stack

- Patrol is the primary runtime E2E tool for this phase because Mint's recent
  failures involved Flutter/iOS semantics, native lifecycle, relaunch, and
  state persistence where Maestro has been brittle.
- Maestro remains a smoke-test tool. It is not the decisive gate for this
  phase's critical flow.
- Mint Debug Spine is the local state oracle. Patrol drives the app; Debug
  Spine explains what state remains.
- Quern or a mobile MCP server is a follow-up spike, not a dependency for M1.
  M1 must work with repo-local scripts and Patrol first.
- Langfuse is a follow-up for coach/LLM traces. M1 may define its boundary, but
  it must not instrument real user prompts or financial values.

### Privacy Boundary

- Evidence must be synthetic and redacted.
- No JWT, Apple credential, device identifier, email, raw wizard answers, raw
  financial values, or real user text may be printed, logged, screenshotted, or
  committed.
- The Debug Spine may expose booleans, counts, corrupt-state flags, route names,
  and redacted class names.
- Release builds must not expose the Debug Spine or debug-only routes.
- Fresh anonymous state must produce zero `/sync/claim-local-data`, profile
  writes, coach sync, snapshots, or local-data claim calls.
- Network evidence must be endpoint/method/status-class/count only. It must not
  store headers, bodies, query parameters, tokens, device identifiers, request
  payloads, or response payloads.
- Runtime network recording must be central at `MintHttpClient.shared`, and
  existing debug HTTP body logs must be suppressed or redacted during the gate.
- Screenshot evidence is allowed only from constrained Debug Spine/reset states.
  Every screenshot must have UI-tree text or OCR text extracted and scanned.
  If text extraction is unavailable, the evidence gate fails closed.
- Production workflows and compiled release/profile artifacts must be scanned
  for debug-tool leakage. Source-level `!kReleaseMode` checks alone are not
  enough for closeout. Scans must reject both accepted enabling spellings,
  `ENABLE_ADMIN=(1|true)` and `ENABLE_DEBUG_TOOLS=(1|true)`, including
  direct `--dart-define`, environment-wrapped build args, and
  dart-define-from-file inputs.

### Product Boundary

- A value visible to the user remains forbidden unless it carries value/range,
  unit, assumptions, sources, readiness/confidence, missing inputs, and
  calculation or constant version.
- This phase verifies that boundary; it does not weaken it with UI hiding.
- Reset/delete proof must cover local profile, wizard answers, budget inputs,
  budget overrides, anonymous message count, anonymous conversation namespace,
  current-user conversation namespace, owned secure purge flags, install secure
  purge flags, true-fresh Keychain status where observable, account lifecycle
  residue classes (`keep_local`, `restart_clean`, `local_data_migrated_*`,
  sync-off account behavior), and relaunch.

## Canonical References

Agents planning or implementing this phase must read:

- `AGENTS.md` — Scenario Spine doctrine and preflight rules.
- `CLAUDE.md` — 0-Trust, financial-core boundary, i18n and privacy constraints.
- `docs/MINT_AGENT_WORKFLOW.md` — runtime proof, agent review, and GSD
  lifecycle.
- `docs/data-flow.md` — storage keys and write/read ownership for wizard,
  budget, coach, backend mirror, and local handoff data.
- `.planning/phases/mint-2-0-first-experience-rente-capital/CONTEXT.md` —
  active Mint 2.0 product boundary.
- `.planning/phases/mint-2-0-first-experience-rente-capital/SPEC.md` —
  forbidden outputs and acceptance criteria for first experience.
- `apps/mobile/lib/screens/admin/mint_debug_spine_screen.dart` — current
  dev-only inspector UI.
- `apps/mobile/lib/services/debug/mint_debug_spine_service.dart` — current
  redacted state snapshot.
- `tools/checks/mint_debug_spine_gate.sh` — current compile-time gate for admin
  and debug-tool flags.
- `.github/workflows/ci.yml` — current CI integration point for the debug spine
  gate.
- `REVIEW_CONVERGENCE.md` — reviewer blockers, fixes, and final GO verdicts.

## Research Summary

Reddit and official docs point to a practical pattern:

- Flutter teams use Patrol when native interactions, system lifecycle, and
  integration-test limits matter.
- Maestro is easy to write and useful for smoke flows, but Flutter semantics
  targeting can be unreliable in exactly the class of issues Mint saw.
- General "AI testing" tools are not a substitute for deterministic assertions.
  The useful AI role is reading structured evidence, generating test cases, and
  reviewing failures.
- Mobile MCP/debug servers such as Quern are promising for a later step because
  they can expose logs, network, screenshots, UI state, and device control to an
  agent through one local interface.
- Langfuse self-hosting fits later coach observability because it supports LLM
  traces and evals while keeping deployment/privacy under our control.

## Non-Goals

- No broad testing platform migration.
- No paid device farm decision.
- No real Apple account automation.
- No production telemetry or session replay activation.
- No new financial calculations.
- No attempt to close physical iPhone/TestFlight restore proof with simulator
  evidence.

## Execution Order

1. `01-patrol-bootstrap-contract-PLAN.md` — install/check Patrol and redacted
   Debug Spine JSON contract.
2. `02-runtime-fresh-reset-relaunch-PLAN.md` — true-fresh simulator, seeded
   residue, network recorder, screenshot/UI-tree gate, reset/relaunch proof.
3. `03-ci-release-closeout-PLAN.md` — CI static mode, release artifact scan,
   expert/Claude reviews, honest closeout.

## Success Definition

The phase is successful when a clean checkout can run one command that:

1. builds or launches the app in the supported local debug configuration;
2. executes the Patrol first-experience/reset/relaunch path;
3. captures redacted evidence;
4. fails on forbidden financial residue or network sync;
5. leaves no dependency on manual phone screenshots for this simulator-proven
   class of bug.

Physical iPhone/TestFlight/iCloud restore remains a separate gate. M1 may reduce
the number of manual phone screenshots needed, but it cannot close device-only
Keychain/iCloud behavior with simulator evidence.
