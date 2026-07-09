---
name: mint-operating-gates
description: Mandatory MINT stabilization gates before user-facing, auth, privacy, runtime-proof, or financial-product work.
compatibility: Works across the MINT repo.
metadata:
  author: mint-team
  version: "1.0"
---

# MINT Operating Gates

Use this skill before any change that touches a user flow, authentication,
privacy, persisted profile data, runtime proof, or Swiss financial scenario.

## First Reads

Read, in order:

1. `CLAUDE.md`
2. `AGENTS.md`
3. `docs/MINT_AGENT_WORKFLOW.md` when present
4. the docs named by the relevant `AGENTS.md` pre-flight row
5. `.planning/ACTIVE_CONTEXT.md` and `.planning/ACTIVE_CONTEXT.json` when present

If a required file is missing, record it as a workflow gap and continue only
when the task can still be verified from checked-in code and tests.

## Checked-In Gates

Run the smallest relevant set:

```bash
python3 tools/checks/arb_parity.py
./tools/mint-routes reconcile
lefthook run pre-commit --file <touched-file>
```

For external Claude review, use the checked-in wrapper instead of raw
`claude -p` commands:

```bash
tools/checks/claude_external_audit.sh code <base-ref>
tools/checks/claude_external_audit.sh specs
tools/checks/claude_external_audit.sh architecture
```

The wrapper is deliberately bounded: Opus high by default, strict empty MCP,
no session persistence, `--setting-sources user`, no dynamic-system-prompt
sections, and no `--effort max` unless `CLAUDE_AUDIT_ALLOW_MAX=1` is explicitly
set for a named final-release or unresolved P0/P1 dispute. Project/local setting
sources are rejected by default because they can load repo hooks; override only
with `CLAUDE_AUDIT_ALLOW_PROJECT_SETTINGS=1` for a named debug run. Code audits
reject large diff prompts by default
(`CLAUDE_AUDIT_MAX_DIFF_LINES`, default 2500) so oversized branches are split
before review. Repeated same-gate re-audits should use Sonnet high first via
`CLAUDE_AUDIT_RERUN=1`, then one Opus high final. The wrapper rejects
non-Sonnet reruns unless `CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1` is explicitly set for a
final confirmation or P0 dispute.

For `docs/codex/` contract work, run the contract tests that exist in this
checkout:

```bash
python3 -m pytest tools/checks/tests/test_data_quest_goal_aware_ranking_contract.py -q
python3 -m pytest tools/checks/tests/test_screen_contracts_route_contract.py -q
```

## Roadmap Gates Not Installed At G0

These names may appear in older plans, but they are not checked-in gates until
the files exist in this checkout:

- `tools/checks/active_context_guard.py`
- `tools/checks/phase_contract_guard.py`
- `tools/checks/mint_rules_guard.py`
- `tools/checks/verify_phase_acceptance.py`

Missing guard scripts are workflow gaps, not silent passes.

## Stop-The-Bleeding Rules

- One real user flow, one clean runtime proof, one reviewable diff.
- No route without renderer and degraded state.
- No service without a caller or tested consumer.
- No financial result without source, confidence/freshness, missing-value
  behavior, and a targeted test.
- No new LLM path without golden input/output evals.
- Every new P0 path needs a feature flag or explicit kill switch.

## Acceptance

A touched user flow is acceptable only when the smallest relevant gate passes:

- spec/static parity for documented contracts
- backend or Flutter targeted tests
- runtime proof for the touched surface, usually Maestro on mobile
- evidence recorded under `.planning/runtime-evidence/`

Unresolved critical/high external-audit findings block acceptance.
