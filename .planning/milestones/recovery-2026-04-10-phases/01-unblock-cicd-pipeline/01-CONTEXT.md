# Phase 1: Unblock CI/CD Pipeline - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning
**Source:** Deep audit (War Room A) + git state analysis

<domain>
## Phase Boundary

This phase unblocks the entire delivery pipeline. Nothing can ship until CI is green and TestFlight builds.

**Current state:**
- Branch `feature/cso-security-fixes` has 9 CI credential fix commits NOT yet merged to dev
- These commits fix Fastlane Match credential helpers for TestFlight builds
- dev and staging are red on GitHub (credential issue blocks TestFlight)
- staging and dev are 674 commits ahead of main (sync-branches workflow uses FF-only with soft-fail)
- There are 39 uncommitted file changes (safePop additions) on the current branch that should be handled separately

**End state:**
- dev CI green
- staging CI green
- TestFlight build succeeds from staging
- main synced with staging (or PR created)

</domain>

<decisions>
## Implementation Decisions

### Branch Merge Strategy
- Merge feature/cso-security-fixes → dev via PR (squash merge per branch flow rules)
- Verify dev CI passes before merging to staging
- Create PR dev → staging only after dev is green
- For main sync: create PR staging → main (resolve 674-commit divergence)

### Uncommitted Changes
- The 39 uncommitted safePop files on current branch should NOT be included in the CI fix merge
- They are Phase 5/6 work (navigation fixes) — stash or commit separately
- Clean working tree before creating PR

### CI Verification
- Must verify: flutter analyze (0 errors), flutter test, pytest
- Check TestFlight workflow triggers on staging push
- Verify backend deploy (Railway auto-deploy on staging merge)

### Claude's Discretion
- Order of operations for the merge sequence
- Whether to squash the 9 CI commits or merge as-is
- How to handle merge conflicts if any exist between feature branch and dev

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### CI/CD Architecture
- `docs/CICD_ARCHITECTURE.md` — Full CI/CD pipeline reference
- `.github/workflows/ci.yml` — Main CI gate (7 stages)
- `.github/workflows/testflight.yml` — iOS TestFlight builds
- `.github/workflows/sync-branches.yml` — Branch synchronization
- `.github/workflows/deploy-backend.yml` — Railway backend deployments

### Branch Flow
- `rules.md` — Branch flow rules (feature/* → dev → staging → main)
- `CLAUDE.md` §4 — Dev rules, branch protocol

</canonical_refs>

<specifics>
## Specific Ideas

- The 9 CI commits are all `fix(ci):` prefixed — they're a coherent unit
- The last commit (`e039698f`) removed MATCH_GIT_BASIC_AUTHORIZATION entirely
- The credential fix uses `~/.git-credentials` credential store approach
- TestFlight workflow uses `workflow_dispatch` + auto on staging/main push

</specifics>

<deferred>
## Deferred Ideas

- sync-branches workflow improvement (FF-only → proper merge) — separate concern
- Backend Railway deploy verification — covered by existing auto-deploy

</deferred>

---

*Phase: 01-unblock-cicd-pipeline*
*Context gathered: 2026-04-10 via deep audit*
