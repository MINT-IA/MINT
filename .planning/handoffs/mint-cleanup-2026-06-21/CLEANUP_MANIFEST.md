---
description: "Manifest for the 2026-06-21 MINT planning/repo/review hygiene cleanup before account lifecycle work resumes."
status: inventory-manifest
date: 2026-06-21
scope: planning-hygiene
---

# Mint Cleanup Manifest — 2026-06-21

## Purpose

Close the planning/repo/review hygiene loop before resuming Mint 2.0 account
lifecycle work. This manifest is not a new product matrix. It is the bounded
ledger for what may be classified, patched, reviewed, and later committed.

No product code change is proposed by this cleanup pass.

## Preflight State

| Check | Observed |
|---|---|
| `pwd` | `/Users/julienbattaglia/Desktop/MINT.nosync` |
| `git rev-parse --show-toplevel` | `/Users/julienbattaglia/Desktop/MINT.nosync` |
| Expected worktree | matched |
| `git symbolic-ref --short HEAD` | `qa/runtime-navigation-spine-20260602` |
| Expected branch | matched |
| `git rev-parse HEAD` | `3d289b6b04256eb9cc9f0bad723b2ac85ad823ba` |
| Expected base | matched exactly |
| `git merge-base --is-ancestor BASE HEAD` | exit `0` |
| `git diff --shortstat` | `43 files changed, 3679 insertions(+), 2322 deletions(-)` |
| Repo size | `16G .`, `505M .git`, `5.8G .claude`, `5.8G .claude/worktrees`, `817M .planning`, `4.8G apps`, `3.6G services`, `87M tools` |

Known warning: `git diff --shortstat` reports CRLF/LF replacement warnings for
generated Flutter localization files. This is pre-existing in the handoff and
is not a cleanup target here.

Handshake gap: `memory/MEMORY.md` is absent in this worktree. Engram MCP was
available and used instead.

## Engram Context Loaded

| Observation | Title | Cleanup relevance |
|---|---|---|
| `#2238` | Mint first experience lifecycle matrix reviewed | Matrix exists, expert-agent review incorporated, Claude Max produced no substantive verdict. |
| `#2241` | Mint account lifecycle Slice 0 | Prompt listed this ID as matrix-reviewed, but Engram returns Slice 0. Treat prompt ID mapping as stale. |
| `#2243` | Mint lifecycle routing Slice A | Lifecycle routing slice exists historically; local proof still required before classification. |
| `#2245` | Mint planning and Claude review hygiene audit | Confirms repo size, stale `STATE.md`, phase/worktree sprawl, and bounded Claude review policy. |
| `#2247` | Cleanup should run in fresh session | Confirms this cleanup should be strict, atomic, and non-destructive. |

## Active Matrix Ledger

| Item | Classification | Evidence | Remaining gates |
|---|---|---|---|
| `mint-first-experience-account-lifecycle` | `active/partial` | Matrix frontmatter status is `agent-reviewed-claude-timeout-ready-for-slice-0` at `.planning/phases/mint-first-experience-account-lifecycle/EXECUTABLE_MATRIX.md:1`; review gate records Claude Max no-verdict at lines 28-40. | Runtime gates G1-G10 remain open at lines 296-315. Deferred slices remain at lines 430-443. |
| Slice 0 | `implemented-historically, verify-before-final-classification` | Engram `#2241`; matrix Slice 0 contract at lines 363-394. Backend Apple forged-token test exists as untracked `services/backend/tests/test_auth_apple.py`; local auth verification code exists at `services/backend/app/api/v1/endpoints/auth.py:1248`. | Current-session tests not rerun in this cleanup. Do not mark phase executed from history alone. |
| Slice A | `partial/local-proof-present` | Engram `#2243`; lifecycle enum/value object at `apps/mobile/lib/models/auth_lifecycle_state.dart:3`; main-nav/public-entry tests at `apps/mobile/test/navigation/home_gate_contract_test.dart:1` and `apps/mobile/test/navigation/account_lifecycle_public_entry_redirect_test.dart:1`; router uses lifecycle at `apps/mobile/lib/app.dart:230`. | No runtime relaunch/update proof in this cleanup. Boot barrier/hydration split remains later work per Engram `#2243`. |
| Apple auth hardening | `partial/product-blocked-before-lifecycle-exit` | Backend verifies Apple JWS/JWKS, RS256, `aud`, `iss`, required `exp/iat/iss/aud/sub`, and nonce at `services/backend/app/api/v1/endpoints/auth.py:1248-1302`. | Before any account-lifecycle product commit exits Slice 0, Apple lookup must bind primarily by stable `sub`, not email/fallback; authorization-code revoke proof must be explicit; the relevant tests, including `services/backend/tests/test_auth_apple.py`, must be committed with the auth endpoint change. |
| Claude Max validation | `gap-documented` | `.planning/phases/mint-first-experience-account-lifecycle/CLAUDE_MAX_REVIEW.md:5-10` says both attempts produced no substantive model output. | Routine review must use bounded `tools/claude_review.sh`; Opus/xhigh is reserved for clean PR-level review. |

## Dirty Diff Lots

| Lot | Files | Tracked diff | Classification |
|---|---:|---:|---|
| Mobile lifecycle/auth routing | 4 tracked + 2 untracked relevant files | `262 insertions`, `176 deletions` | Product code from lifecycle work. Do not touch in cleanup. |
| Backend Apple auth | 2 tracked + 1 untracked test | `63 insertions`, `48 deletions` | Product/security code from lifecycle work. Do not touch in cleanup. Future auth commit must include the untracked test file and fix `sub`-primary binding before account lifecycle exits Slice 0. |
| Planning handoff/current phase docs | `.planning/ROADMAP.md`, `.planning/config.json`, untracked handoff and phase dirs | tracked `43 insertions`, `1 deletion`; many untracked docs | Cleanup may add manifest and later update `STATE.md`; no archive movement without proof. |
| Flutter l10n/generated | 13 tracked files | `150 insertions` | Product support/generated output. Do not touch in cleanup unless product code is explicitly resumed later. |
| Anonymous/chat/auth UI and tests | 16 tracked files | `3080 insertions`, `2077 deletions` | Pre-existing product work. Do not touch in cleanup. |
| Tooling/config/agent docs | 6 tracked + 2 untracked tool files | `81 insertions`, `20 deletions` tracked | Do not normalize in cleanup except bounded review docs if needed. |

Untracked files/directories include:

- `.planning/handoffs/mint-cleanup-2026-06-21/PROMPT.md`
- `.planning/phases/mint-first-experience-account-lifecycle/`
- `.planning/phases/mint-2-0-first-experience-rente-capital/`
- `.planning/phases/mint-account-entry-apple-primary/`
- `.planning/phases/mint-anonymous-chat-restore-control/`
- `.planning/phases/mint-diagnostic-onboarding-v1/`
- `.planning/phases/mint-onboarding-lifecycle-reset/`
- `.planning/phases/mint-profile-clear-conversation-purge/`
- `apps/mobile/lib/models/auth_lifecycle_state.dart`
- `apps/mobile/test/navigation/account_lifecycle_public_entry_redirect_test.dart`
- `docs/MINT_AGENT_WORKFLOW.md`
- `services/backend/tests/test_auth_apple.py`
- `tools/checks/mint_variable_dictionary_lint.py`
- `tools/checks/tests/test_mint_variable_dictionary_lint.py`

## Worktree Classification

| Path | Branch | Head | Size | Lock | Dirty entries | Classification |
|---|---|---:|---:|---|---:|---|
| `/Users/julienbattaglia/Desktop/MINT.nosync` | `qa/runtime-navigation-spine-20260602` | `3d289b6b0` | `16G` | active root | dirty | current worktree |
| `/Users/julienbattaglia/Desktop/MINT.brand-refondation.nosync` | `feat/mint-v2-refondation` | `6053a6920` | not measured | none in porcelain | not checked | external known worktree; do not touch |
| `/Users/julienbattaglia/Desktop/MINT.bump.nosync` | `staging` | `287c8ae07` | not measured | none in porcelain | not checked | external known worktree; do not touch |
| `/Users/julienbattaglia/Desktop/MINT.foundation-clean.nosync` | `feature/S11-mint2-profile-value-ledger` | `de17ecf39` | not measured | none in porcelain | not checked | external known recent Mint2 worktree; do not touch |
| `.claude/worktrees/agent-a02a8ae53f6475bb3` | `worktree-agent-a02a8ae53f6475bb3` | `22b127fed` | `407M` | locked pid `18242` | `0` | expected locked agent worktree |
| `.claude/worktrees/agent-a36c33cda66f755e5` | `worktree-agent-a36c33cda66f755e5` | `10699dd8b` | `404M` | locked pid `18242` | `0` | expected locked agent worktree |
| `.claude/worktrees/agent-a7c8747f5175fb884` | `worktree-agent-a7c8747f5175fb884` | `4bc6e05da` | `405M` | locked pid `18242` | `0` | expected locked agent worktree |
| `.claude/worktrees/agent-a7fdf7eecb8e77ed7` | `worktree-agent-a7fdf7eecb8e77ed7` | `208b91eef` | `363M` | locked pid `18242` | `0` | expected locked agent worktree |
| `.claude/worktrees/agent-a9de1300a388ae195` | `worktree-agent-a9de1300a388ae195` | `05f7dd23a` | `406M` | locked pid `18242` | `0` | expected locked agent worktree |
| `.claude/worktrees/agent-a9e19139d37c54945` | `worktree-01.5-03-02` | `dc5b7c032` | `316M` | locked pid `18242` | `0` | expected locked agent worktree |
| `.claude/worktrees/agent-ab3c0c431fe4c2cdd` | `worktree-01.5-03-01` | `a150bbd4f` | `316M` | locked pid `18242` | `0` | expected locked agent worktree |
| `.claude/worktrees/agent-abd158274e3229876` | `worktree-agent-abd158274e3229876` | `acc7a6134` | `338M` | locked pid `18242` | `0` | expected locked agent worktree |
| `.claude/worktrees/agent-ac0f4187efe51f8d3` | `worktree-agent-ac0f4187efe51f8d3` | `fc4b0ac9d` | `410M` | locked pid `18242` | `0` | expected locked agent worktree |
| `.claude/worktrees/agent-ad20c9b62c2e7bdae` | `worktree-agent-ad20c9b62c2e7bdae` | `aa15cc09d` | `407M` | locked pid `18242` | `0` | expected locked agent worktree |
| `.claude/worktrees/codex-mint-diagnostic-onboarding-v1-route` | `codex/mint-account-entry-apple-primary` | `9f15eedd2` | `2.1G` | unlocked | `0` | expected large Codex worktree, no cleanup without explicit GO |

Delta vs handoff wording: handoff said "11 worktrees locked"; current porcelain
shows 10 locked agent worktrees plus one unlocked Codex worktree under
`.claude/worktrees`. All `.claude/worktrees/*` entries have `dirty_entries=0`.
No worktree cleanup is proposed in this pass.

## Phase Classification Table

Classification is conservative. `historical-summary-present/no-move` means a
summary exists according to the inventory command, but this manifest does not
authorize archive movement or claim final phase closure. Any future archive
candidate needs a separate review with file/line proof.

| Phase directory | Evidence markers | Classification | Action now |
|---|---|---|---|
| `mint-first-experience-account-lifecycle` | `EXECUTABLE_MATRIX.md`, no summary | `active/partial` | Keep active. |
| `mint-2-0-first-experience-rente-capital` | summary + plan + context, untracked | `active-on-hold` | Do not touch until hygiene cleanup ends. |
| `mint-account-entry-apple-primary` | 4 summaries, untracked | `superseded-reference` | Keep as source evidence for lifecycle matrix; no move. |
| `mint-anonymous-chat-restore-control` | summary + runtime audit, untracked | `superseded-reference` | Keep as source evidence; no move. |
| `mint-diagnostic-onboarding-v1` | plan + reviews, untracked | `superseded-reference/unknown` | Keep as source evidence; no move. |
| `mint-onboarding-lifecycle-reset` | 4 summaries, untracked | `superseded-reference` | Keep as source evidence; no move. |
| `mint-profile-clear-conversation-purge` | 2 summaries, untracked | `superseded-reference` | Keep as source evidence; no move. |
| `mint-prod-ready-core-journey-truth-20260601` | matrix + review synthesis says active | `historical-active-stale-router` | Update `STATE.md` only after review; no move. |
| `mint-illogism-fixes` | 17 summaries + validation | `historical-summary-present/no-move` | No move in this pass. |
| `mint-calc-engine-v1` | 22 summaries + validation + matrix | `historical-summary-present/no-move` | No move in this pass. |
| `mint-data-spine-plan-vivant-v1` | 70 summaries | `historical-summary-present/no-move` | No move in this pass. |
| `mon-argent-budget-cleanup-v2` | 69 summaries | `historical-summary-present/no-move` | No move in this pass. |
| `money-trust-contract-v1-04` through `money-trust-contract-v1-40` | per-plan summaries present | `historical-summary-present/no-move` | No move in this pass. |
| `mint-grounded-coach-m1` | 8 summaries | `historical-summary-present/no-move` | No move in this pass. |
| `01.1-walkthrough-first-grounding` | 2 summaries + preconditions/observations | `historical-summary-present/no-move` | No move in this pass. |
| `01.5-archetype-hard-gate-fatca` | 10 summaries | `historical-summary-present/no-move` | No move in this pass. |
| `96-mvp-chat-as-verb` | 3 summaries + draft validation with pending markers | `unknown/pending` | No move. |
| `wave-1a-backend-tools-refactor` | 9 summaries + validation | `historical-summary-present/no-move` | No move in this pass. |
| `wave-1b-citation-chips` | 10 summaries + validation | `historical-summary-present/no-move` | No move in this pass. |
| `wave-1c-coach-tool-dispatch-rca` | plans/context, no summary | `unknown/pending` | No move. |
| `mint-data-architecture-v1-01-calc-engine-canonical` | 5 summaries + verification | `historical-summary-present/no-move` | No move in this pass. |
| `mint-data-architecture-v1-02-event-log-projection` | 4 summaries + validation | `historical-summary-present/no-move` | No move in this pass. |
| `mint-data-architecture-v1-02-deploy` | validation + plans, no summary | `unknown/pending` | No move. |
| `mint-account-entry-apple-primary` predecessors listed in matrix | matrix lines 18-26 | `superseded-reference` | No move. |
| `01-mint-production-readiness-audit-identify-top-blockers-to-fir` | validation/context, no summary | `unknown` | No move. |
| `01.4-coach-runtime-stale-data` | 3 files, no summary/context | `unknown` | No move. |
| `92.5-mvp-calc-rigor-foundations` | summary + plans/context | `historical-summary-present/no-move` | No move in this pass. |
| `97-mvp-parfait-maestro-full-power-maestro-driven-on-device-grou` | context, no summary | `unknown` | No move. |
| `97.5-product-completeness-for-ship` | plan, no summary | `unknown/pending` | No move. |
| `mint-etat-des-lieux-20260612` | 6 files, no summary/context | `unknown` | No move. |
| `mint-sense-making` | empty | `unknown/empty` | No move. |
| `mon-argent-compact-selector-v1` | summary + plan | `historical-summary-present/no-move` | No move in this pass. |
| `mon-argent-money-map-v1` | plan + context, no summary | `unknown/pending` | No move. |
| `money-trust-contract-v1-00-figure-audit` | one file, no summary/plan | `unknown` | No move. |
| `money-trust-contract-v1-01-spine-trust-chip` | plan only | `unknown/pending` | No move. |
| `money-trust-contract-v1-02-coach-number-gate` | plan only | `unknown/pending` | No move. |
| `money-trust-contract-v1-03-onboarding-3a-number-gate` | plan only | `unknown/pending` | No move. |
| `salvage-SALVAGE-00` | 2 summaries | `historical-summary-present/no-move` | No move in this pass. |
| `salvage-SALVAGE-01` | empty | `unknown/empty` | No move. |

For compactness, the per-plan `money-trust-contract-v1-04` to
`money-trust-contract-v1-40` sequence is grouped above because the inventory
shows the same shape for each: one summary, one plan, three files, except:

- `money-trust-contract-v1-20` and `money-trust-contract-v1-37` have five files.
- `money-trust-contract-v1-40` has seven files.

No directory in this grouped sequence is moved in this pass.

## Proposed Atomic Commits

No commit may be made without explicit user GO after review.

| Commit | Purpose | Explicit allowed files |
|---|---|---|
| `planning cleanup manifest` | Record preflight, inventory, classifications, and stop conditions. | `.planning/handoffs/mint-cleanup-2026-06-21/PROMPT.md`; `.planning/handoffs/mint-cleanup-2026-06-21/CLEANUP_MANIFEST.md`. |
| `planning active state hygiene` | Update stale `.planning/STATE.md` to point at cleanup/account lifecycle instead of Core Journey Truth. | `.planning/STATE.md`; this manifest. |
| `planning registry scaffold` | Optional registry page if review asks for it. | `.planning/PHASE_REGISTRY.md`; this manifest only if updated. |

Explicitly forbidden in these commits:

- Product code under `apps/` or `services/`.
- Generated localization files.
- `.claude/worktrees` deletion or movement.
- Bulk phase archive movement.
- `git add .`.
- Reset, stash, pull, rebase, clean, push, merge.

## Review Plan

Before any commit:

1. Run Review Agent on the scope below:
   - `.planning/STATE.md`
   - `.planning/handoffs/mint-cleanup-2026-06-21/*`
   - any phase registry/archive manifest touched in this cleanup
2. Run targeted Claude review if `tools/claude_review.sh` exists:

```bash
MINT_CLAUDE_MODEL=sonnet MINT_CLAUDE_TIMEOUT=900 MINT_CLAUDE_MAX_BYTES=12000 tools/claude_review.sh -- .planning/handoffs/mint-cleanup-2026-06-21 .planning/STATE.md
```

3. Run:

```bash
git diff --check
git status --short
```

No product tests are required unless product code is touched by mistake. If that
happens, stop and report before continuing.

Product diffs referenced by this manifest, including Apple auth, anonymous chat,
auth UI, lifecycle routing, generated localization files, and mobile tests, are
outside this cleanup commit. They require their own targeted review and test
gate before any product commit.

## Risks And STOP Conditions

Stop before state edits or archive movement if any of these occur:

- New dirty files appear outside `.planning/handoffs/mint-cleanup-2026-06-21/`
  or `.planning/STATE.md`.
- Any phase classification requires inference without local file evidence or
  Engram evidence.
- A review asks to inspect product code beyond the cleanup scope.
- Claude review widens scope or times out after being invoked with the bounded
  command.
- Any command suggests reset/stash/pull/rebase/clean/push/merge.
- A worktree becomes dirty or lock state changes during the cleanup.

Current cleanup diff is intentionally limited to:

- `.planning/handoffs/mint-cleanup-2026-06-21/CLEANUP_MANIFEST.md`
- `.planning/handoffs/mint-cleanup-2026-06-21/PROMPT.md`
- `.planning/STATE.md`

If Review Agent or targeted Claude review objects, fix only those planning
files and rerun the same bounded checks.
