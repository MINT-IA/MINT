# MINT Active Context

This file is the session router. If another document disagrees with it, this
file and `.planning/ACTIVE_CONTEXT.json` win until the disagreement is fixed.

## Active Now

- Active milestone: `mint-2-0-first-experience-rente-capital`
- Active context: `.planning/phases/mint-2-0-first-experience-rente-capital/CONTEXT.md`
- Active spec: `.planning/phases/mint-2-0-first-experience-rente-capital/SPEC.md`
- Active integration branch: `dev`
- Next product phase: `.planning/phases/mint-2-0-first-experience-rente-capital/CONTEXT.md`
  self-references the active context as a placeholder; no successor product
  phase is queued yet.
- Temporary hotfix branch: `codex/account-lifecycle-gate-20260624` is
  authorized only for the account lifecycle/onboarding gate hotfix.
- Temporary runtime-proof branch: `codex/jos001-seeded-auth-runtime-20260626`
  is authorized only for the JOS-001 account lifecycle seeded-auth runtime
  proof and any directly required gate fix.
- Temporary workflow branch: `codex/dynamic-pr-size-rule-20260626` is
  authorized only for the PR-size-budget doctrine correction.
- Temporary runtime-proof branch: `codex/jos002-money-truth-spine-20260626`
  is authorized only for the Money truth spine Journey OS vertical.
- Temporary hotfix branch: `codex/jos002a-onboarding-persistence-20260627`
  is authorized only for the JOS-002A onboarding persistence gate needed before
  the downstream Money truth spine proof.
- Temporary runtime-proof branch: `codex/jos002b-money-truth-runtime-20260627`
  is authorized only for the JOS-002B Money truth runtime proof harness and any
  directly required SEC-10-preserving simulator fixture fix.
- Temporary Journey OS branch: `codex/jos003-next-journey-vertical-20260627`
  is authorized only for selecting and executing the next scoped Journey OS
  vertical from clean `origin/dev`.
- Temporary Journey OS branch: `codex/jos004-profile-privacy-control-20260627`
  is authorized only for the Profile Privacy Control Journey OS vertical from
  clean `origin/dev`.
- Temporary Journey OS branch: `codex/jos005-coach-advice-turn-20260627`
  is authorized only for the Coach Advice Turn Journey OS vertical from clean
  `origin/dev`.
- Temporary hotfix branch: `codex/jos004-coach-advice-fix-20260627` is
  authorized only for the JOS-004 Coach advice turn regulatory freshness fix
  from clean `origin/dev`.
- Temporary hotfix branch: `codex/jos004-coach-empty-answer-fix-20260627` is
  authorized only for the JOS-004 authenticated Coach empty-answer fix, the
  directly required runtime-proof harness update, and evidence from clean
  `origin/dev`.
- Temporary hotfix branch: `codex/jos004-regulatory-floor-20260627` is
  authorized only for the JOS-004 closed regulatory 3a/LPP deterministic
  runtime floor and evidence from clean `origin/dev`.
- Temporary hotfix branch: `codex/jos004-regulatory-floor-close-loop-20260627`
  is authorized only for closing the JOS-004 3a/LPP regulatory tool loop
  deterministically before a fallback response can overwrite it.
- Temporary runtime-proof branch:
  `codex/jos004-maestro-first-experience-proof-20260627` is authorized only
  for the JOS-004 Coach advice turn Maestro runtime proof harness update from
  clean `origin/dev`; no product code changes.

## Required Session Start

Every Mint session must read these files before product or code work:

1. `AGENTS.md`
2. `CLAUDE.md`
3. `docs/MINT_AGENT_WORKFLOW.md`
4. `.planning/ACTIVE_CONTEXT.md`
5. `.planning/STATE.md`

Then run:

```bash
python3 tools/checks/active_context_guard.py
python3 tools/checks/phase_contract_guard.py
python3 tools/checks/mint_rules_guard.py
git status --short --branch
```

## Not Active

These phase directories are historical receipts or quarantine references. They
may be cited as evidence, but they are not active routing authority:

- `mint-prod-ready-core-journey-truth-20260601`
- `mint-illogism-fixes`
- `mint-grounded-coach-m1`
- `mint-onboarding-auth-reset-restore-integration`
- `mint-diagnostic-onboarding-v1`
- `mint-profile-clear-conversation-purge`
- `mint-anonymous-chat-restore-control`
- `mint-account-entry-apple-primary`
- `mint-onboarding-lifecycle-reset`
- `money-trust-contract-v1-03-onboarding-3a-number-gate`
- `money-trust-contract-v1-33-3a-onboarding-tax-copy-guard`
- `mint-karpathy-rules-infra-20260614`

The canonical checkout is `/Users/julienbattaglia/Desktop/MINT.nosync` on
`dev`. Historical local copies and deleted worktrees were moved into
`/Users/julienbattaglia/Desktop/MINT-cleanup-archive-20260624T074611Z`.

## Archive Policy

Do not move dozens of old phase directories as part of feature work. That would
create a large mechanical diff and break historical references without improving
the user experience.

Instead:

- keep old phases visible as receipts;
- forbid them from becoming active via `tools/checks/active_context_guard.py`;
- archive later only through a dedicated cleanup dry-run, with a reviewable PR
  and redirect/index updates.

## Promotion Rule

When the next successor phase is queued, update these files in the same commit:

- `.planning/ACTIVE_CONTEXT.json`
- `.planning/ACTIVE_CONTEXT.md`
- `.planning/STATE.md`
- `.planning/ROADMAP.md`

Then run `python3 tools/checks/active_context_guard.py`.

## Spec -> Verifier -> Environment

Mint uses this operating model for AI-assisted work:

- **Spec:** the active phase contract lives in `SPEC.md`.
- **Verifier:** `VERIFICATION.md` lists exact commands and evidence before any
  completion claim.
- **Environment:** `rules.md`, `AGENTS.md`, `docs/MINT_AGENT_WORKFLOW.md`,
  hooks, CI, and Engram define the workspace boundaries.

Run these guards before phase execution:

```bash
python3 tools/checks/active_context_guard.py
python3 tools/checks/phase_contract_guard.py
python3 tools/checks/mint_rules_guard.py
python3 tools/checks/agent_reference_guard.py
python3 tools/checks/claude_hooks_guard.py
```
