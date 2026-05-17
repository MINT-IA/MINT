---
phase: wave-1c-coach-tool-dispatch-rca
wave: C
depends_on:
  - wave-1c-B-PLAN.md
  - human_checkpoint_g2_julien_screenshot   # Wave B merged + dev→staging merged + Julien G2 sim screenshot in chat
autonomous: false
files_modified:
  - services/backend/app/services/rag/llm_client.py
  - services/backend/app/services/llm/router.py
wave1c_decisions_addressed: [D-06, D-08, D-09, D-10, D-12]
branch: feature/wave-1c-instrumentation-teardown
target_branch: dev
must_haves:
  truths:
    - "PR #628 instrumentation block in services/backend/app/services/rag/llm_client.py is reverted (the wrong-call-site WAVE1C_PAYLOAD logger)."
    - "PR #631 instrumentation block in services/backend/app/services/llm/router.py _call_anthropic is reverted (the correct-call-site WAVE1C_PAYLOAD logger)."
    - "Railway env var WAVE1C_INSTRUMENT_ENABLED is deleted from staging environment."
    - "Bisect test users claude-wave1c-bisect-*@example.com are deleted from staging DB (OR documented as left-in-place + not real users per CONTEXT D-06.4)."
    - "Phase 1b VERIFICATION-REPORT.html status flipped from PENDING G2 — RUNTIME GAP to SHIPPED, with the G2 sim screenshot embedded (downstream consumer per CONTEXT D-07 — done by Julien but Claude provides the evidence + the patch diff)."
    - "Full pytest suite exits 0 after both reverts (no instrumentation symbol leftover)."
    - "All G1-G5 gates from CONTEXT D-10 are mechanically green at phase close-out."
  artifacts:
    - path: services/backend/app/services/rag/llm_client.py
      provides: "Reverted to pre-PR-#628 state (no WAVE1C_PAYLOAD logger block in llm_client.py)"
      forbids: "Any reference to WAVE1C_PAYLOAD, WAVE1C_INSTRUMENT_ENABLED, claude-wave1c"
    - path: services/backend/app/services/llm/router.py
      provides: "Reverted to pre-PR-#631 state (no WAVE1C_PAYLOAD logger block in _call_anthropic)"
      forbids: "Any reference to WAVE1C_PAYLOAD, WAVE1C_INSTRUMENT_ENABLED, claude-wave1c"
  key_links:
    - from: "git revert of PR #628 + PR #631"
      to: "services/backend/app/services/rag/llm_client.py + services/backend/app/services/llm/router.py"
      pattern: "git diff origin/dev~10..HEAD --name-only includes both files with NET-ZERO additions from PR #628/#631"
    - from: "railway variable delete WAVE1C_INSTRUMENT_ENABLED"
      to: "Railway staging environment"
      pattern: "railway variables --service MINT --environment staging | grep -v WAVE1C_INSTRUMENT_ENABLED"
---

<objective>
Tear down all Wave 1c diagnostic instrumentation. The bug is fixed (Wave A), the regression floor is in place (Wave B), and Julien has cited the G2 sim screenshot. Now the WAVE1C_PAYLOAD logger blocks + the Railway env var + the bisect test users get cleaned up.

Purpose: Diagnostic instrumentation leaks Anthropic request payloads to Railway logs. It served its purpose (the smoking gun was found via this telemetry) but now is dead-weight + privacy risk + cost overhead. The 4 cleanup items are independent and atomic.

Output: 1 PR on new branch `feature/wave-1c-instrumentation-teardown` targeting `dev`, with the 2 reverts in atomic commits + the Railway env var deletion documented in the PR body + the test users delete-or-left-in-place documented + the Wave 1b VERIFICATION-REPORT.html flip patch provided as a separate artifact (per CONTEXT D-07: Julien commits the flip, Claude provides the diff).
</objective>

<execution_context>
**Human checkpoint at task C.0** (blocker — must resolve before any teardown step): verify Julien has posted a G2 sim screenshot showing the chip render flow working end-to-end on staging.

This wave touches code that was already merged on `dev` + `staging`. The reverts SHOULD be clean `git revert` operations of PR #628 + PR #631 squash commits, but the executor must verify that no other PR has touched those lines in the meantime. If a divergence is detected, do a manual surgical revert instead of `git revert`.
</execution_context>

<context>
@CLAUDE.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/HANDOFF.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A-PLAN.md
@.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-B-PLAN.md
@services/backend/app/services/rag/llm_client.py
@services/backend/app/services/llm/router.py
@.planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html

<interfaces>
<!-- The 2 PRs to revert -->
<!-- PR #628 squash sha: 9c336c95 — instrumentation in services/backend/app/services/rag/llm_client.py:232-258 (WRONG call site, kept for legacy path only) -->
<!-- PR #631 squash sha: d9964422 — instrumentation in services/backend/app/services/llm/router.py:_call_anthropic (CORRECT narrator call site) -->

<!-- The WAVE1C_PAYLOAD log line shape (from HANDOFF.md) -->
<!-- It logs the request payload as JSON after "WAVE1C_PAYLOAD " — gated by os.environ.get("WAVE1C_INSTRUMENT_ENABLED") == "true" -->

<!-- Railway commands -->
<!-- railway variables --service MINT --environment staging  → shows current env vars -->
<!-- railway variable delete --service MINT --environment staging WAVE1C_INSTRUMENT_ENABLED -->
<!-- railway redeploy --service MINT --yes -->
</interfaces>
</context>

<tasks>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task C.0 — HUMAN CHECKPOINT: Julien's G2 sim screenshot</name>
  <what-built>
    Wave B regression test floor is merged to dev. dev→staging PR opened (and either merged or pending). Julien needs to run the Maestro flow `coach_tool_dispatch_all_6_smoke.yaml` (OR a manual chat flow) on his iPhone-17-Pro sim against staging and confirm the chips render.
  </what-built>
  <how-to-verify>
    Julien posts in chat one of:
    1. A screenshot of the iPhone-17-Pro sim showing the chat response with ≥5 of 6 chips visible (cite the screenshot path; if a temporary path, copy it to `.planning/phases/wave-1c-coach-tool-dispatch-rca/g2-evidence/julien-g2-<timestamp>.png`).
    2. The verbatim output of `~/.maestro/bin/maestro test tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml` showing « Flow Passed ».
    3. A confirmation message « G2 OK — chips render » with a chat-history pointer.

    On any of the above, record the evidence verbatim (file path OR maestro stdout OR chat quote) in this task's output before proceeding.

    If Julien is unavailable AND a sim+build is available to Claude: Claude can run the Maestro flow itself, capture the output + a screenshot via `xcrun simctl io booted screenshot`, paste both into the task output, and this counts as G2-by-Maestro per memory `feedback_device_gates`. The evidence MUST be cited (Maestro stdout + screenshot path).

    DO NOT proceed without one of the above. Per CLAUDE.md §9.5, « PR merged » ≠ « works ». G2 evidence is the « works » signal.
  </how-to-verify>
  <resume-signal>
    Paste Julien's screenshot path / Maestro PASS line / chat quote — OR a Claude-run G2 evidence pair (Maestro stdout + screenshot). « G2 OK » with cited evidence unblocks C.1+.
  </resume-signal>
</task>

<task type="auto" tdd="false">
  <name>Task C.1 — Revert PR #628 instrumentation block (services/backend/app/services/rag/llm_client.py)</name>
  <files>services/backend/app/services/rag/llm_client.py</files>
  <read_first>
    - services/backend/app/services/rag/llm_client.py lines 220-270 (verify the current state of the WAVE1C_PAYLOAD block)
    - `gh pr view 628 --json mergeCommit,files` (verify PR #628 squash sha + files modified)
    - `git log --oneline 9c336c95 -1` (verify PR #628 commit message)
    - `git diff 9c336c95~1 9c336c95 -- services/backend/app/services/rag/llm_client.py` (the exact diff PR #628 introduced)
    - CONTEXT D-06.2 (verbatim spec)
  </read_first>
  <behavior>
    - After this task: `grep -nE "WAVE1C_PAYLOAD|WAVE1C_INSTRUMENT_ENABLED" services/backend/app/services/rag/llm_client.py | wc -l` returns 0.
    - The revert preserves the legacy `llm_client.py` non-instrumentation code paths (the function that hosted the block remains, only the WAVE1C_* block is removed).
    - `python3 -m pytest tests/test_rag/ -q` (or whatever test path covers llm_client) exits 0.
  </behavior>
  <action>
    1. **Branch off origin/dev**:
       ```bash
       cd /Users/julienbattaglia/Desktop/MINT.nosync
       git fetch origin
       git checkout -b feature/wave-1c-instrumentation-teardown origin/dev
       ```

    2. **Verify PR #628 squash sha + that no subsequent PR has touched the instrumentation block lines** :
       ```bash
       gh pr view 628 --json mergeCommit --jq '.mergeCommit.oid'   # should print 9c336c95 (or full sha)
       git log --oneline -- services/backend/app/services/rag/llm_client.py | head -10
       # Check if any commit AFTER 9c336c95 touches lines 220-270 of llm_client.py:
       git log --oneline 9c336c95.. -- services/backend/app/services/rag/llm_client.py
       ```
       - If the second `git log` is empty → safe to `git revert 9c336c95`.
       - If non-empty → manual surgical revert is required (see step 3b).

    3a. **Clean revert (preferred)**:
       ```bash
       git revert 9c336c95 --no-edit
       # If the revert touches files OTHER than llm_client.py (PR #628 also touched docs / tests / lint baselines), KEEP llm_client.py revert + UNDO other reverts via:
       # git restore --source=HEAD~1 <other-file-paths>
       # git commit --amend --no-edit
       # Goal: this revert commit modifies ONLY llm_client.py (or only llm_client.py + the test file that tested the instrumentation if PR #628 added one).
       ```

    3b. **Surgical revert (if step 2 detected divergence)**:
       Read the current state of `services/backend/app/services/rag/llm_client.py` lines 220-270. Identify the WAVE1C_PAYLOAD block (the `if os.environ.get("WAVE1C_INSTRUMENT_ENABLED") == "true": logger.info("WAVE1C_PAYLOAD %s", json.dumps(...))` lines). Delete ONLY those lines. Verify the surrounding code still makes sense (the function signature + the actual Anthropic call remain).
       ```bash
       # After manual edit:
       git add services/backend/app/services/rag/llm_client.py
       git commit -m "revert(wave-1c): remove WAVE1C_PAYLOAD instrumentation in llm_client.py (PR #628 reversal)"
       ```

    4. **Verify the revert is clean**:
       ```bash
       grep -nE "WAVE1C_PAYLOAD|WAVE1C_INSTRUMENT_ENABLED|claude-wave1c" services/backend/app/services/rag/llm_client.py
       # Expected: empty output (exit 1 is fine here — that means no matches)
       ```

    5. **Run targeted tests**:
       ```bash
       cd services/backend && python3 -m pytest tests/test_rag/ -q
       cd services/backend && python3 -m pytest tests/ -q | tail -3   # full suite for safety
       ```
  </action>
  <acceptance_criteria>
    - `grep -nE "WAVE1C_PAYLOAD|WAVE1C_INSTRUMENT_ENABLED|claude-wave1c" services/backend/app/services/rag/llm_client.py` returns 0 matches (exit 1 from grep).
    - `git log --oneline HEAD~1..HEAD -- services/backend/app/services/rag/llm_client.py` shows the revert commit with title prefix `revert(wave-1c)`.
    - `cd services/backend && python3 -m pytest tests/ -q` exits 0.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/rag/llm_client.py` exits 0.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && grep -c "WAVE1C_PAYLOAD" services/backend/app/services/rag/llm_client.py; cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <done>
    WAVE1C_PAYLOAD block removed from llm_client.py. Tests pass. Revert commit on the branch.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task C.2 — Revert PR #631 instrumentation block (services/backend/app/services/llm/router.py:_call_anthropic)</name>
  <files>services/backend/app/services/llm/router.py</files>
  <read_first>
    - services/backend/app/services/llm/router.py — grep for `_call_anthropic` + `WAVE1C_PAYLOAD`
    - `gh pr view 631 --json mergeCommit,files` (verify PR #631 squash sha + files modified)
    - `git diff d9964422~1 d9964422 -- services/backend/app/services/llm/router.py` (the exact diff PR #631 introduced)
    - CONTEXT D-06.3 (verbatim spec)
    - Also note the « pragma fix » from PR #630 (squash sha 78668e36) which touched the same area — distinguish the pragma-no-cover line (KEEP) from the WAVE1C_PAYLOAD block (REMOVE).
  </read_first>
  <behavior>
    - After this task: `grep -nE "WAVE1C_PAYLOAD|WAVE1C_INSTRUMENT_ENABLED" services/backend/app/services/llm/router.py | wc -l` returns 0.
    - The `_call_anthropic` function signature + Anthropic call are preserved.
    - `python3 -m pytest tests/test_llm/ tests/test_coach_chat/ -q` exits 0 (or the equivalent test paths covering router.py).
  </behavior>
  <action>
    1. **Verify PR #631 squash sha + that no subsequent PR has touched the same lines** :
       ```bash
       gh pr view 631 --json mergeCommit --jq '.mergeCommit.oid'   # should print d9964422 (or full sha)
       git log --oneline d9964422.. -- services/backend/app/services/llm/router.py
       # NOTE: PR #630 (sha 78668e36, "pragma no cover fix") touched the same file post-#631.
       # The pragma fix is a 1-line comment — leave it alone. Only remove the WAVE1C_PAYLOAD block.
       ```

    2. **Surgical revert (manual edit recommended due to PR #630 overlap)**:
       Read `services/backend/app/services/llm/router.py` around `_call_anthropic`. Identify the WAVE1C_PAYLOAD instrumentation block (the `if os.environ.get("WAVE1C_INSTRUMENT_ENABLED") == "true": logger.info("WAVE1C_PAYLOAD %s", json.dumps(<request_payload>))` lines). Delete ONLY those lines AND keep the « pragma no cover » line from PR #630 (which is a separate concern — it's a coverage exemption for an unrelated function).

       ```bash
       # After manual edit:
       git add services/backend/app/services/llm/router.py
       git commit -m "revert(wave-1c): remove WAVE1C_PAYLOAD instrumentation in router._call_anthropic (PR #631 reversal)"
       ```

       **CAVEAT** : if `_call_anthropic` ended up with an empty `if WAVE1C_INSTRUMENT_ENABLED == "true":` block after the deletion, REMOVE the empty if-block entirely. Verify with `python3 -c "import ast; ast.parse(open('services/backend/app/services/llm/router.py').read())"` (exit 0).

    3. **Verify the revert is clean**:
       ```bash
       grep -nE "WAVE1C_PAYLOAD|WAVE1C_INSTRUMENT_ENABLED|claude-wave1c" services/backend/app/services/llm/router.py
       # Expected: empty
       ```

    4. **Run targeted tests**:
       ```bash
       cd services/backend && python3 -m pytest tests/ -q | tail -3
       ```
  </action>
  <acceptance_criteria>
    - `grep -nE "WAVE1C_PAYLOAD|WAVE1C_INSTRUMENT_ENABLED|claude-wave1c" services/backend/app/services/llm/router.py` returns 0 matches (exit 1).
    - `git log --oneline HEAD~1..HEAD -- services/backend/app/services/llm/router.py` shows the revert commit.
    - `python3 -c "import ast; ast.parse(open('services/backend/app/services/llm/router.py').read())"` exits 0 (syntax-valid Python).
    - `cd services/backend && python3 -m pytest tests/ -q` exits 0.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/llm/router.py` exits 0.
  </acceptance_criteria>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && grep -c "WAVE1C_PAYLOAD" services/backend/app/services/llm/router.py; python3 -c "import ast; ast.parse(open('services/backend/app/services/llm/router.py').read())"; cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <done>
    WAVE1C_PAYLOAD block removed from router.py. PR #630 pragma fix preserved. Tests pass.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task C.3 — Push + open PR + merge → dev (atomic 2-commit teardown PR)</name>
  <files></files>
  <read_first>
    - The 2 revert commits from C.1 + C.2
    - CLAUDE.md §9 + memory `feedback_pre_push_checklist` + memory `feedback_public_repo_discipline`
  </read_first>
  <behavior>
    - Pre-push sanity: full pytest exit 0, banned-terms + accent-lint exit 0.
    - PR opened on `feature/wave-1c-instrumentation-teardown` → dev.
    - CI green; PR merged with squash.
  </behavior>
  <action>
    1. **Pre-push checklist**:
       ```bash
       cd /Users/julienbattaglia/Desktop/MINT.nosync
       cd services/backend && python3 -m pytest tests/ -q | tail -3   # full backend exit 0
       cd /Users/julienbattaglia/Desktop/MINT.nosync
       python3 tools/checks/banned_terms_python.py services/backend/app/services/rag/llm_client.py services/backend/app/services/llm/router.py
       python3 tools/checks/accent_lint_fr.py services/backend/app/services/rag/llm_client.py services/backend/app/services/llm/router.py
       git log --oneline origin/dev..HEAD   # confirm 2 revert commits present
       ```

    2. **Push + open PR**:
       ```bash
       git push -u origin feature/wave-1c-instrumentation-teardown
       gh pr create --base dev --head feature/wave-1c-instrumentation-teardown \
         --title "revert(wave-1c): teardown WAVE1C_PAYLOAD instrumentation (PRs #628 + #631)" \
         --body "$(cat <<'EOF'
       ## What

       Wave 1c instrumentation teardown (CONTEXT D-06).

       The WAVE1C_PAYLOAD logger blocks served their purpose: they captured the staging Anthropic request payload, enabled the bisection runbook, and the bisection's smoking gun named the doctrine-level root cause (Wave A's fix). With Wave A merged + the live probe + Julien's G2 sim screenshot cited, the diagnostic instrumentation is dead weight.

       This PR reverts:
       - PR #628 squash sha `9c336c95` — `services/backend/app/services/rag/llm_client.py` (WRONG call site, kept for legacy path only).
       - PR #631 squash sha `d9964422` — `services/backend/app/services/llm/router.py` `_call_anthropic` (CORRECT narrator call site).

       PR #630's « pragma no cover » fix is preserved (independent of the WAVE1C_PAYLOAD block).

       ## Out-of-PR ops (manual)

       After merge + dev→staging merge + Railway redeploy:

       1. `railway variable delete --service MINT --environment staging WAVE1C_INSTRUMENT_ENABLED`
       2. `railway redeploy --service MINT --yes`
       3. Bisect test users (`claude-wave1c-bisect-*@example.com`) — left in place per CONTEXT D-06.4 (not flagged as real users). If we want to delete: `DELETE FROM users WHERE email LIKE 'claude-wave1c-bisect-%'` via Railway SSH + psql.

       ## Mechanical gates (pre-push)

       - Full backend pytest exits 0.
       - Both touched files pass `banned_terms_python.py` and `accent_lint_fr.py`.
       - `grep -nE "WAVE1C_PAYLOAD|WAVE1C_INSTRUMENT_ENABLED" services/backend/app/services/rag/llm_client.py services/backend/app/services/llm/router.py` returns 0 matches.

       ## What this PR does NOT do

       - Does NOT delete the bisect.py + experiment.py + captured_staging_payload_*.json files under `.planning/phases/wave-1c-coach-tool-dispatch-rca/` — those are audit-trail artifacts and stay (per CONTEXT D-06 + section §Deferred Ideas).
       - Does NOT delete the orphan Railway env vars `COACH_TOOL_SERVER_SIDE_BUDGET_STATUS` etc. — separate optional cleanup per CONTEXT §Deferred Ideas.
       - Does NOT flip Wave 1b VERIFICATION-REPORT.html — that's a manual operator commit per CONTEXT D-07, handled in Task C.5.

       Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
       EOF
       )"
       ```

    3. **Monitor CI inline + merge on green**:
       ```bash
       PR_NUM=$(gh pr list --head feature/wave-1c-instrumentation-teardown --json number --jq '.[0].number')
       until ! gh pr checks $PR_NUM 2>&1 | grep -q pending; do sleep 30; done
       gh pr checks $PR_NUM
       gh pr merge $PR_NUM --squash --delete-branch
       MERGE_SHA=$(gh pr view $PR_NUM --json mergeCommit --jq '.mergeCommit.oid')
       ```

    4. **Open dev→staging bundle PR**:
       ```bash
       gh pr create --base staging --head dev \
         --title "ship: dev → staging — wave-1c instrumentation teardown" \
         --body "Bundles Wave C teardown (PR #$PR_NUM) into staging. After this merges + Railway redeploys, run the Railway env-var deletion + redeploy from Task C.4 to complete the teardown.
       Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
       ```
  </action>
  <acceptance_criteria>
    - PR opened on `feature/wave-1c-instrumentation-teardown` → `dev`.
    - `gh pr checks <N>` shows ALL jobs pass.
    - PR merged with squash, branch deleted.
    - dev→staging bundle PR opened.
    - `git log --oneline origin/dev | head -3` shows the squash commit with title prefix `revert(wave-1c)`.
  </acceptance_criteria>
  <verify>
    <automated>gh pr list --state merged --search 'revert(wave-1c) base:dev' --json number,mergedAt --jq '.[0]' 2>&1 | head -5</automated>
  </verify>
  <done>
    Wave C teardown PR merged to dev with non-null mergedAt.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task C.4 — Railway env var deletion + redeploy + bisect-user cleanup decision</name>
  <files></files>
  <read_first>
    - HANDOFF.md §Teardown checklist + §Open questions/gotchas (« railway restart alone does NOT pick up new env vars »)
    - Engram memory `reference_infra_access` (Railway access verified)
    - CONTEXT D-06.1 + D-06.4
    - The Task C.3 merge sha
  </read_first>
  <behavior>
    - After this task: `railway variables --service MINT --environment staging | grep -i WAVE1C_INSTRUMENT_ENABLED` returns 0 matches.
    - Railway has redeployed onto the post-Wave-C-merge commit.
    - The bisect test users decision (delete vs leave) is documented in the task output.
  </behavior>
  <action>
    1. **Verify Wave C dev→staging PR is merged + Railway has redeployed** :
       ```bash
       railway status --json | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['environments']['edges'][0]['node']['serviceInstances']['edges'][0]['node']['latestDeployment'])"
       # Expected: status=SUCCESS, commit matches the staging HEAD post-merge
       git fetch origin && git log --oneline origin/staging | head -3
       ```

    2. **Delete the env var + force redeploy** :
       ```bash
       railway variables --service MINT --environment staging | grep WAVE1C_INSTRUMENT_ENABLED
       # Confirm the var exists before delete
       railway variable delete --service MINT --environment staging WAVE1C_INSTRUMENT_ENABLED
       # Per HANDOFF gotcha: `railway restart` does NOT pick up new env vars — must redeploy:
       railway redeploy --service MINT --yes
       # Wait for SUCCESS:
       until railway status --json | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['environments']['edges'][0]['node']['serviceInstances']['edges'][0]['node']['latestDeployment']['status'])" | grep -q SUCCESS; do sleep 20; done
       ```

    3. **Verify the var is gone on the running pod**:
       ```bash
       railway ssh --service MINT --environment staging -- env | grep WAVE1C_INSTRUMENT_ENABLED
       # Expected: empty (exit 1 from grep — no matches)
       ```

    4. **Bisect-user cleanup decision** :
       Per CONTEXT D-06.4 — « leave them — they're not flagged as real users ». Default decision: LEAVE in place. Document in task output:
       « Bisect test users `claude-wave1c-bisect-*@example.com` left in place per CONTEXT D-06.4 (non-real users, no privacy concern, deletion is optional cleanup). To delete if desired: `railway ssh --service MINT --environment staging -- psql $DATABASE_URL -c "DELETE FROM users WHERE email LIKE 'claude-wave1c-bisect-%'"`. »

       (If Julien asks for deletion in chat, run the SQL. Otherwise, leave + document.)

    5. **Optional cleanup of the 5 orphan Railway env vars** (per CONTEXT §Out of scope, optional, separate cleanup):
       `COACH_TOOL_SERVER_SIDE_BUDGET_STATUS`, `_CAP_STATUS`, `_COUPLE_OPTIMIZATION`, `_CROSS_PILLAR_ANALYSIS`, `_RETIREMENT_PROJECTION`. These are pure orphans (no code references). Default decision: LEAVE; document for separate cleanup. If Julien wants them deleted in this session, run:
       ```bash
       for VAR in COACH_TOOL_SERVER_SIDE_BUDGET_STATUS COACH_TOOL_SERVER_SIDE_CAP_STATUS COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ANALYSIS COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION; do
         railway variable delete --service MINT --environment staging "$VAR"
       done
       railway redeploy --service MINT --yes
       ```
  </action>
  <acceptance_criteria>
    - `railway ssh --service MINT --environment staging -- env | grep WAVE1C_INSTRUMENT_ENABLED` returns 0 matches (exit 1).
    - `railway status --json` shows latest deployment status=SUCCESS on the post-merge commit.
    - Bisect-user decision documented in task output (leave OR delete with citation).
    - Orphan env vars decision documented (leave OR delete with citation).
  </acceptance_criteria>
  <verify>
    <automated>railway ssh --service MINT --environment staging -- env 2>&1 | grep -c WAVE1C_INSTRUMENT_ENABLED</automated>
  </verify>
  <done>
    WAVE1C_INSTRUMENT_ENABLED removed from Railway staging. Redeploy SUCCESS. Bisect-user decision documented. Orphan env-var decision documented.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task C.5 — Provide the Wave 1b VERIFICATION-REPORT.html flip patch (Julien commits, Claude provides the diff)</name>
  <files>.planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html</files>
  <read_first>
    - .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html (read full file; find the line « Status: <strong class="pending">PENDING G2 — RUNTIME GAP</strong> » around line 20)
    - The G2 evidence from Task C.0 (Julien's screenshot or Maestro PASS)
    - The Wave A live probe output from Wave A's verification block
    - CONTEXT D-07 (downstream consumer: this flip is Julien's manual commit, NOT a Claude-side commit)
  </read_first>
  <behavior>
    - A draft patch is provided in the task output (verbatim search/replace) for Julien to apply manually.
    - The patch flips the status from `PENDING G2 — RUNTIME GAP` to `SHIPPED 2026-05-XX (Wave 1c fix landed; tool_use mandate enforced)`.
    - The patch embeds the G2 evidence (screenshot path or Maestro PASS line + Wave A live probe curl JSON snippet).
  </behavior>
  <action>
    Per CONTEXT D-07, the actual commit is Julien's, not Claude's. Claude provides the DIFF.

    1. **Read the file** to locate the exact line to replace:
       ```bash
       grep -n "PENDING G2\|RUNTIME GAP" .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html
       ```

    2. **Produce the patch** (verbatim search/replace for Julien) — output this in the task result:
       ```
       File: .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html

       Search:
           Status: <strong class="pending">PENDING G2 — RUNTIME GAP</strong>

       Replace:
           Status: <strong class="shipped">SHIPPED 2026-05-XX (Wave 1c fix landed; tool_use mandate enforced)</strong>

       AND insert a new evidence block somewhere near the top, after the existing G2 section:

           <h3>G2 Closure — Wave 1c fix (2026-05-XX)</h3>
           <p>Wave 1c smoking-gun fix landed in PRs #<wave-A-PR>, #<wave-B-PR>, #<wave-C-PR>. Live staging probe + Julien G2 sim screenshot confirm chip render.</p>
           <ul>
             <li><strong>Wave A merge sha</strong>: <code><wave-A-merge-sha></code> — citation grammar MANDATE + _enforce_tool_use_for_citations gate + Sentry breadcrumb.</li>
             <li><strong>Wave B merge sha</strong>: <code><wave-B-merge-sha></code> — 5-artifact regression test floor.</li>
             <li><strong>Wave C merge sha</strong>: <code><wave-C-merge-sha></code> — WAVE1C_PAYLOAD instrumentation teardown + Railway env-var delete.</li>
             <li><strong>Live probe evidence</strong>: <code><curl JSON snippet from Wave A live probe — pasted verbatim></code></li>
             <li><strong>G2 sim evidence</strong>: <code>.planning/phases/wave-1c-coach-tool-dispatch-rca/g2-evidence/julien-g2-&lt;timestamp&gt;.png</code> (or Maestro Flow Passed line: <code>&lt;maestro-stdout&gt;</code>)</li>
           </ul>
       ```

       Substitute the actual PR numbers + merge shas + curl JSON + G2 evidence path from the task outputs of Tasks A.4, B.5, C.0, C.3.

    3. **Save the patch as an artifact** for Julien:
       ```bash
       cat > .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1b-flip-patch.md <<'EOF'
       # Wave 1b status flip patch — APPLY MANUALLY (per CONTEXT D-07)

       After Wave 1c is complete (Wave A + B + C merged + Railway env var deleted + G2 sim by Julien),
       apply the following patch to .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html
       and commit with message « docs(wave-1b): flip status to SHIPPED post-wave-1c fix ».

       ## Search / Replace

       [Insert the search/replace from step 2 above with actual values substituted.]

       ## After commit

       Run `python3 tools/checks/wiki_lint.py` (per CLAUDE.md §8) to verify the wiki index regenerates cleanly.
       EOF
       ```

    4. **Do NOT commit the flip yourself**. The artifact at `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1b-flip-patch.md` is what Julien applies. Per CONTEXT D-07: « That flip happens via a manual edit-and-commit by Julien after Claude provides the probe evidence in chat, NOT as part of this phase's plans. »

       NOTE: Creating the `wave-1b-flip-patch.md` file IS allowed (it's documentation, not a flip). Just don't touch `wave-1b-VERIFICATION-REPORT.html` itself.
  </action>
  <acceptance_criteria>
    - File `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1b-flip-patch.md` exists with the verbatim search/replace + all actual PR numbers + merge shas + curl JSON + G2 evidence path substituted.
    - File `.planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` IS UNCHANGED in git (no edit by Claude — per CONTEXT D-07).
    - The task output includes the verbatim patch text for Julien to copy-paste.
  </acceptance_criteria>
  <verify>
    <automated>test -f /Users/julienbattaglia/Desktop/MINT.nosync/.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1b-flip-patch.md && cd /Users/julienbattaglia/Desktop/MINT.nosync && git diff --stat .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html</automated>
  </verify>
  <done>
    Flip patch artifact created at `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1b-flip-patch.md`. Wave 1b VERIFICATION-REPORT.html UNCHANGED in this PR. Julien knows what to do.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task C.6 — Engram mem_save: Wave C close-out finding + phase close-out</name>
  <files></files>
  <read_first>
    - Task C.3 + C.4 outputs (merge sha, Railway redeploy success, env-var deletion confirmation)
    - Wave A + B engram observations (topic_keys for prior_finding_refs)
    - The G2 evidence from Task C.0
  </read_first>
  <behavior>
    - 1 successful `mem_save` with `topic_key: coach:citation:tool_use_mandate:wave_c:teardown_complete` + `prior_finding_refs` to Wave A + B + obs ids 65, 66, 69, 74, 75.
    - 1 additional `mem_save` for the phase-close: `topic_key: coach:citation:tool_use_mandate:phase_closed` with cumulative summary + 5-gate close-out evidence.
  </behavior>
  <action>
    Two `mem_save` invocations:

    **Call 1** — Wave C close-out:
    - `topic_key`: `coach:citation:tool_use_mandate:wave_c:teardown_complete`
    - `observation_type`: `discovery`
    - `prior_finding_refs`: [`coach:citation:tool_use_mandate:wave_a:shipped`, `coach:citation:tool_use_mandate:wave_b:regression_floor_landed`, `65`, `66`, `69`, `74`, `75`]
    - `content`: « Wave 1c Wave C teardown merged to dev (PR #<N>, squash sha <sha>). Two reverts: services/backend/app/services/rag/llm_client.py (PR #628 reversal) + services/backend/app/services/llm/router.py (PR #631 reversal; PR #630 pragma fix preserved). Railway env var WAVE1C_INSTRUMENT_ENABLED deleted from staging + redeploy SUCCESS. Bisect test users left in place per CONTEXT D-06.4 (non-real). 5 orphan COACH_TOOL_SERVER_SIDE_* env vars left in place for separate cleanup. Audit-trail files (.planning/phases/wave-1c-coach-tool-dispatch-rca/bisect.py + experiment.py + captured_staging_payload_*.json) retained. »

    **Call 2** — Phase close-out:
    - `topic_key`: `coach:citation:tool_use_mandate:phase_closed`
    - `observation_type`: `decision`
    - `prior_finding_refs`: [`coach:citation:tool_use_mandate:wave_a:shipped`, `coach:citation:tool_use_mandate:wave_b:regression_floor_landed`, `coach:citation:tool_use_mandate:wave_c:teardown_complete`, `65`, `66`, `69`, `74`, `75`]
    - `content`: « Wave 1c phase CLOSED 2026-05-XX. The doctrine-level tool_use mandate is shipped (Wave A), regression-protected (Wave B 51+ tests + Maestro flow), and diagnostic instrumentation is torn down (Wave C). All 5 G1-G5 gates from CONTEXT D-10 mechanically green: G1 Maestro PASS (cited); G2 Julien sim screenshot (cited); G3 dev CI green per PR checks (PRs #A,#B,#C); G4 pytest 6957+ passing; G5 banned_terms + accent_lint + arb parity green. Wave 1b VERIFICATION-REPORT.html flip patch provided at .planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1b-flip-patch.md for Julien to apply. Bug-class taxonomy: this was a "doctrine teaches FORMAT not INVOCATION" failure mode — useful pattern for future LLM-doctrine work. The new gate `_enforce_tool_use_for_citations` becomes the runtime tripwire for any future regression. Cost note: gate runs only when COACH_CITATION_GATE_ENABLED=true (Phase 94 master switch) so Phase 94 byte-identity is preserved when the flag is off. »

    Handle `judgment_required` per the conflict-surfacing rule for both calls.
  </action>
  <acceptance_criteria>
    - 2 `mem_save` calls with the exact `topic_key` values above.
    - `prior_finding_refs` chains correctly (Wave C refs Wave A + B; phase-close refs all 3 waves).
    - Any `judgment_required` resolved or surfaced.
  </acceptance_criteria>
  <verify>
    <automated>echo "mem_save verification is via tool response envelope"</automated>
  </verify>
  <done>
    Two engram observations saved. Wave 1c is closed in agent memory.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| git revert → live code on dev | The reverts modify production-tracked code. The 2 reverts are surgical (lines 220-270 of llm_client.py + the _call_anthropic block of router.py) and are protected by the full pytest gate. |
| Railway env-var delete → live staging deploy | After deletion + redeploy, the WAVE1C_INSTRUMENT_ENABLED env var is gone from the running pod. The grep verification in Task C.4 confirms. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-wave-1c-C-01 | Tampering | git revert may miss other PRs touching the same lines | mitigate | Task C.1 + C.2 step 2 explicitly checks for divergence via `git log 9c336c95.. -- <file>` and `git log d9964422.. -- <file>` before clean-revert; if divergence, do surgical edit instead. |
| T-wave-1c-C-02 | Denial of service | Railway redeploy could fail | mitigate | Task C.4 polls `railway status --json` until SUCCESS before declaring the var deleted. If FAIL, diagnose via `railway logs --service MINT --environment staging`. |
| T-wave-1c-C-03 | Information disclosure | Bisect test users left in staging DB | accept | Per CONTEXT D-06.4. Emails are `claude-wave1c-bisect-*@example.com` which is a public RFC-2606 reserved domain — no real-user PII. Optional deletion documented in Task C.4. |
| T-wave-1c-C-04 | Repudiation | Wave 1b VERIFICATION-REPORT.html flip is Julien's commit, not Claude's | accept | Per CONTEXT D-07. Claude provides the diff (Task C.5 artifact at `wave-1b-flip-patch.md`); audit trail is the PR + the engram observation chain. |
</threat_model>

<verification>
## Phase close-out (5-gate exit contract per CONTEXT D-10)

- G1 (Maestro/sim) — `tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml` PASS line cited in Wave B + the live probe curl JSON cited in Wave A.
- G2 (Julien sim) — Task C.0 evidence cited (screenshot path + Maestro PASS line OR Julien's chat quote).
- G3 (dev CI green) — `gh pr checks` cited for all 3 PRs (Wave A + Wave B + Wave C).
- G4 (regression suite) — `cd services/backend && python3 -m pytest tests/ -q` exits 0 with count = baseline + 69 (recorded in Wave B + Wave C close-outs).
- G5 (LSFin + accent lint) — `banned_terms_python.py` + `accent_lint_fr.py` exit 0 on all touched files; `validate_arb_parity()` not applicable (backend-only changes).

## Operational tripwire (post-deploy monitoring)

The Sentry breadcrumb category `coach.citation.tool_use_missing` is the post-deploy alarm. The Sentry alarm rule is deployed by **Wave A Task A.6** (Option A autonomous via Sentry API, OR Option B manual-deploy artifact at `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-sentry-rule-manual.md` for Julien). Verify post-Wave-C close-out that the rule is live:
- Trigger: rate of `coach.citation.tool_use_missing` events ≥10 per hour (Sentry EventFrequencyCondition `interval=1h` `value=10` per Task A.6's POST payload). Tune the threshold once the post-deploy baseline rate is observed.
- Action: notify Julien (email member action per the Task A.6 payload).
- Rationale: if the new gate REJECTS at >10/h rate post-deploy, the LLM is still confused about tool_use → narrator prompt iter 2 (CONTEXT §Deferred Phase 94.2) becomes critical path.
- Evidence of live rule: cite the rule URL + GET response from `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-sentry-rule.md` in the phase close-out SUMMARY.
</verification>

<success_criteria>
- C.0 checkpoint resolved (G2 sim screenshot or Maestro PASS cited).
- 2 reverts committed (llm_client.py + router.py).
- Wave C PR merged to dev.
- Railway WAVE1C_INSTRUMENT_ENABLED deleted + redeploy SUCCESS.
- Bisect-user + orphan-env-var decisions documented.
- `wave-1b-flip-patch.md` artifact provided.
- 2 engram `mem_save` calls persisted (Wave C close-out + phase close-out).
- All 5 G1-G5 gates from CONTEXT D-10 mechanically green.
</success_criteria>

<output>
After Wave C completes, this phase is CLOSED. Produce a single `wave-1c-SUMMARY.md` summarizing all 3 waves + the cumulative 5-gate evidence + the post-deploy Sentry alarm recommendation. Save at `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-SUMMARY.md`.

The Wave 1b VERIFICATION-REPORT.html flip is Julien's to apply (artifact at `wave-1b-flip-patch.md`). After Julien commits the flip, Wave 1b becomes SHIPPED, the citation-chips feature is end-to-end verified, and the Chat-as-Verb pivot's Phase 94 prod-flip path can re-enter the planning queue (CONTEXT §Deferred Phase 94.2).
</output>
