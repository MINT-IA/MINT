# 34-CI-HOTFIX — Proof of read receipt

## Context
PR #383 (Phase 34 + 34.1) CI revealed `Re-run lefthook on PR range` step 2 fails
with `lefthook: command not found`. Root cause: step 1 silently 404s on
`curl -sSLf https://raw.githubusercontent.com/evilmartians/lefthook/v2.1.6/install.sh`.

## Files read to diagnose
- `.github/workflows/lefthook-ci.yml` — full file, 81 lines, confirmed install
  step uses the 404ing URL.
- GitHub Actions log for run 24832143631 (install step output) — confirmed
  `curl: (22) The requested URL returned error: 404`.
- `.planning/phases/34-agent-guardrails-m-caniques/audits/final/10-PR-SPLIT-READINESS.md` §11 point 4
  — matches anticipated "Phase 34 self-enforcement risk on PR #2".

## Fix
Replace curl-install.sh with `npm install -g lefthook@2.1.6`. npm publishes
the pinned binary and fails loudly if version missing. Pre-installed on
ubuntu-latest runners. No other changes needed.
