# Handoff — Mint Runtime Debug Tooling M1 Plan 01

Date: 2026-06-22
Worktree: `/Users/julienbattaglia/Desktop/MINT.debug-spine.nosync`
Branch: `feature/S09-mint2-runtime-quality-gate`
Current HEAD before execution: `a895ff173 docs(planning): plan runtime debug tooling m1`

## Mission

Execute only Plan 01 of Mint Runtime Debug Tooling M1:

`/.planning/phases/mint-runtime-debug-tooling-m1/01-patrol-bootstrap-contract-PLAN.md`

Goal: install the smallest viable Patrol path for Mint and harden the Debug
Spine redacted JSON evidence contract. Do not implement the full fresh/reset/
relaunch runtime proof yet; that belongs to Plan 02.

## Non-Negotiable Boundaries

- Work only in `/Users/julienbattaglia/Desktop/MINT.debug-spine.nosync`.
- Do not mutate `/Users/julienbattaglia/Desktop/MINT.nosync`.
- Do not push unless Julien explicitly asks.
- Do not start Plan 02 or Plan 03.
- Do not add product behavior, routes, calculations, onboarding changes, coach
  behavior, or user-visible financial claims.
- Keep commits atomic and revertable.
- Use explicit staging only; no `git add .`.

## Required Preflight

Run and report:

```bash
cd /Users/julienbattaglia/Desktop/MINT.debug-spine.nosync
git rev-parse --show-toplevel
git branch --show-current
git status --short
git rev-parse --short HEAD
git log -1 --oneline
```

Expected:

```text
worktree = /Users/julienbattaglia/Desktop/MINT.debug-spine.nosync
branch   = feature/S09-mint2-runtime-quality-gate
HEAD     = a895ff173 docs(planning): plan runtime debug tooling m1
status   = clean
```

If branch/worktree/HEAD differ or status is dirty, STOP and report.

## Read First

Read these before editing:

- `AGENTS.md`
- `CLAUDE.md`
- `docs/MINT_AGENT_WORKFLOW.md`
- `docs/data-flow.md`
- `.planning/phases/mint-runtime-debug-tooling-m1/CONTEXT.md`
- `.planning/phases/mint-runtime-debug-tooling-m1/VERIFICATION.md`
- `.planning/phases/mint-runtime-debug-tooling-m1/PLAN.md`
- `.planning/phases/mint-runtime-debug-tooling-m1/01-patrol-bootstrap-contract-PLAN.md`
- `.planning/phases/mint-runtime-debug-tooling-m1/REVIEW_CONVERGENCE.md`
- `.github/workflows/patrol.md`
- `apps/mobile/pubspec.yaml`
- `apps/mobile/lib/main.dart`
- `apps/mobile/lib/app.dart`
- `apps/mobile/lib/screens/admin/mint_debug_tools_gate.dart`
- `apps/mobile/lib/services/debug/mint_debug_spine_service.dart`
- `tools/checks/mint_debug_spine_gate.sh`

## Execute Plan 01 Tasks

1. Prove and record current Patrol prerequisite state.
   - Is `patrol` CLI installed?
   - Is `patrol_cli` listed?
   - Is `patrol` configured in `pubspec.yaml`?
   - Does iOS bootstrap already exist?
   - Record this in `01-patrol-bootstrap-contract-SUMMARY.md`.

2. Add repo-local Patrol configuration.
   - Add `patrol` dev dependency/config.
   - Add required iOS bootstrap only if needed.
   - Fail closed if `patrol` / `patrol_cli` is missing after setup.
   - Verify no production entitlement or release capability drift.

3. Add redacted Debug Spine JSON export.
   - Must include `schemaVersion`.
   - Allowed: counts, booleans, enum-like labels, corruption flags.
   - Must include residue classes listed in Plan 01.
   - Must not contain raw answers, financial values, email, token, device id, or
     chat body.
   - Add tests with synthetic sentinel values and assert the export does not
     leak them.

4. Add first minimal Patrol launch test.
   - Launch with the same Mint2 flags used by `tools/simulator/mint2_quality_gate.sh`.
   - Include `ENABLE_ADMIN=1` and `ENABLE_DEBUG_TOOLS=1`.
   - Assert Debug Spine JSON rather than relying on UI text as the truth source.

## Required Verification

At minimum:

```bash
gsd-sdk query verify.plan-structure .planning/phases/mint-runtime-debug-tooling-m1/01-patrol-bootstrap-contract-PLAN.md
cd apps/mobile && flutter test test/services/debug/mint_debug_spine_service_test.dart
cd apps/mobile && flutter analyze
tools/checks/mint_debug_spine_gate.sh
git diff --check
git diff --cached --check
```

If Patrol is installable locally, also run:

```bash
cd apps/mobile && command -v patrol && patrol test -t test/patrol/mint_runtime_debug_gate_test.dart \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=MINT_DISABLE_BETA_MODAL=true \
  --dart-define=MINT_E2E_MINT2_FIRST_EXPERIENCE=true \
  --dart-define=MINT_E2E_PROOF_ANCHORS=true \
  --dart-define=ENABLE_ADMIN=1 \
  --dart-define=ENABLE_DEBUG_TOOLS=1
```

If Patrol cannot run because of a missing local prerequisite, mark Plan 01
NO-GO in the summary and do not claim runtime proof.

## Review Requirement

Before commit:

- Review Agent or code-reviewer for diff scope.
- Flutter expert for Patrol/iOS bootstrap.
- Security/privacy reviewer for Debug Spine redaction and release leakage.
- Claude Max targeted only if the diff touches bootstrap, debug evidence, or
  security-sensitive logging.

Fix every HIGH blocker before commit.

## Expected Output

Create:

`.planning/phases/mint-runtime-debug-tooling-m1/01-patrol-bootstrap-contract-SUMMARY.md`

The summary must include:

- prerequisite state;
- exact commands run;
- exit statuses;
- files changed;
- Patrol runnable or NO-GO prerequisite;
- proof that Debug Spine JSON is redacted;
- explicit statement that Plan 02 has not been executed.

## Prompt For New Session

```text
Tu reprends Mint Runtime Debug Tooling M1.

Worktree obligatoire:
/Users/julienbattaglia/Desktop/MINT.debug-spine.nosync

Branche obligatoire:
feature/S09-mint2-runtime-quality-gate

Point de départ attendu:
a895ff173 docs(planning): plan runtime debug tooling m1

Lis et suis strictement:
.planning/handoffs/mint-runtime-debug-tooling-m1-plan01-2026-06-22/PROMPT.md

Objectif unique:
exécuter uniquement Plan 01:
.planning/phases/mint-runtime-debug-tooling-m1/01-patrol-bootstrap-contract-PLAN.md

Ne pas faire Plan 02/03.
Ne pas pousser.
Ne pas muter /Users/julienbattaglia/Desktop/MINT.nosync.
Avant toute mutation, vérifie worktree, branch, HEAD, status. Si ce n’est pas clean ou pas au bon endroit, STOP et reporte.
```
