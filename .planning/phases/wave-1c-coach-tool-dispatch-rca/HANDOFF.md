---
name: wave-1c-handoff-2026-05-15
description: Session handoff for Wave 1c coach-tool-dispatch RCA — picks up after PR #631 CI completes. Self-contained, no prior context needed.
metadata:
  type: handoff
  phase: wave-1c-coach-tool-dispatch-rca
  date: 2026-05-15
  next_session: pick-up-after-#631-merge
---

# Wave 1c Coach-Tool-Dispatch RCA — Session Handoff (2026-05-15 17:15 CEST)

## TL;DR for next session

Wave 1b citation chips ship to dev+staging but **don't render in practice**. The 3-agent RCA's tool_choice hypothesis was falsified by experiment. Real bug is in the staging context-assembly layer (~9,700-token delta vs local minimal replay). Instrumentation PR chain (#627 → #628 → #630 → #629 → #631) is mid-flight; after PR #631 merges + dev→staging, fire a probe + grep `railway logs` for `WAVE1C_PAYLOAD` + run `bisect.py` to name the culprit context layer. Then ship the fix.

## State of the world

| Artifact | Status | SHA / URL |
|---|---|---|
| `dev` HEAD | `78668e36` (pragma fix from PR #630) | — |
| `staging` HEAD | `1aa9fc7a` (post PR #629 merge, 2026-05-15 14:55:31Z) | — |
| Railway staging deploy | `cd241ad8` SUCCESS, commit `1aa9fc7a`, redeployed 15:11:14Z (post env-var fix) | — |
| Railway env on staging | `WAVE1C_INSTRUMENT_ENABLED=true` (verified via `railway ssh ... env`) | — |
| PR #627 (Wave 1b doc + Maestro fix) | MERGED 14:35:25Z, squash `d1c8b3cd` | https://github.com/MINT-IA/MINT/pull/627 |
| PR #628 (Wave 1c llm_client.py instrumentation — wrong call site) | MERGED 14:35:47Z, squash `9c336c95` | https://github.com/MINT-IA/MINT/pull/628 |
| PR #630 (pragma no-cover fix) | MERGED 14:50:43Z, squash `78668e36` | https://github.com/MINT-IA/MINT/pull/630 |
| PR #629 (dev→staging bundle) | MERGED 14:55:31Z, merge commit `1aa9fc7a` | https://github.com/MINT-IA/MINT/pull/629 |
| **PR #631 (Wave 1c router.py instrumentation — correct call site)** | **OPEN, awaiting Backend tests** | https://github.com/MINT-IA/MINT/pull/631 |
| Wave 1b phase status | `PENDING G2 — RUNTIME GAP` (CLAUDE.md §9 0-trust) | `.planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` |
| Mobile sim build | iPhone-17-Pro `B03E429D-...`, `ch.mint.app` installed, Runner.app at 2026-05-15 15:16:33 | — |

## Why we're here — 3 blockers found in G2 Run #2

1. **Railway 5 orphan flag names — FIXED** (live, not in any PR). Code expects `_BUDGET_ENABLED`, etc.; Railway had `_BUDGET_STATUS`, etc. — pure orphans (no code refs). Added 5 canonical `_ENABLED=true` flags. Orphans left in place (separate cleanup).
2. **Maestro flow `timeout` invalid on `assertVisible`** — FIXED in PR #627. Rewritten to `extendedWaitUntil`.
3. **Coach narrator emits no `tool_use` blocks on staging** — RCA IN PROGRESS. See below.

## Blocker 3 — what we know

7 HTTP probes of `POST /api/v1/coach/chat` on staging with seeded profile + budget returned `citationChips: null` AND `toolCalls: null` for every prompt variant (budget / housing / retirement / source_card-bearing). LLM (claude-sonnet-4-5-20250929) announces tool intent in prose ("Je vais récupérer ton instantané budgétaire") but never emits a `tool_use` content block.

### Hypotheses tried + state

| # | Hypothesis | Status |
|---|---|---|
| H1 (initial) | Empty intents → empty allowed_tools → narrator gets 0 tools | **FALSIFIED** — `LifeEventRouterBundle` is `_ALWAYS_ON`, ships 2 tools; staging hits `else: get_llm_tools()` because `COACH_BUNDLE_COMPILER_ENABLED` default False; full 26 tools advertised. |
| H2 (3-agent RCA) | `tool_choice={"type":"auto"}` lets Sonnet skip tool_use | **FALSIFIED** — `experiment.py` ran 2026-05-15 16:08 CEST: BOTH `auto` AND `any` emit `tool_use: get_retirement_projection({})` with the minimal staging-like prompt. |
| H3 (current) | Staging-specific context bloat (~9,700-token delta vs local minimal replay) suppresses tool_use | **AWAITING PR #631 + bisect** |

### What you can do RIGHT NOW (post-PR #631 merge)

```bash
cd /Users/julienbattaglia/Desktop/MINT.nosync

# 1) Confirm PR #631 state
gh pr view 631 --json mergeStateStatus,state

# 2) If CLEAN and not MERGED yet, merge it
gh pr merge 631 --squash --delete-branch

# 3) Open dev→staging bundle PR if not already open, OR merge an existing one
git fetch origin
git log --oneline origin/staging..origin/dev | head -10
gh pr create --base staging --head dev --title "ship: dev → staging — wave-1c router instrumentation (#631)" --body "Ships router.py narrator-path instrumentation so WAVE1C_PAYLOAD logs actually fire on the real coach_chat code path. See .planning/phases/wave-1c-coach-tool-dispatch-rca/HANDOFF.md for full context."

# 4) Wait for Railway redeploy on the new staging commit
railway status --json | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['environments']['edges'][0]['node']['serviceInstances']['edges'][0]['node']['latestDeployment'])"

# 5) Once SUCCESS — verify env on running pod via SSH
railway ssh --service MINT --environment staging -- env | grep WAVE1C_INSTRUMENT_ENABLED
# (must show "true" — already set on staging from earlier today)

# 6) Register a fresh staging user + seed minimal budget (one-shot, no PII)
EMAIL="claude-wave1c-bisect-$(date +%s)@example.com"
PWD=$(python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(20)))")
REG=$(curl -s -X POST https://mint-staging.up.railway.app/api/v1/auth/register \
  -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"$PWD\"}")
JWT=$(echo "$REG" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")
curl -s -o /dev/null -X PUT https://mint-staging.up.railway.app/api/v1/budget/me \
  -H "Authorization: Bearer $JWT" -H 'Content-Type: application/json' \
  -d '{"income_monthly":7500,"fixed_lines":[{"label":"Loyer","amount":1850,"category":"housing"},{"label":"Caisse maladie","amount":380,"category":"health"}],"variable_target_monthly":1100,"savings_target_monthly":1200}'

# 7) Fire probe v7 (the retirement question per RCA convention)
curl -s -X POST https://mint-staging.up.railway.app/api/v1/coach/chat \
  -H "Authorization: Bearer $JWT" -H 'Content-Type: application/json' \
  -d '{"message":"Quelle sera ma rente AVS et LPP à 65 ans avec mon 3eme pilier actuel ? Donne-moi la projection chiffrée.","language":"fr","cash_level":3,"persistence_consent":false}' > /tmp/probe_resp.json
cat /tmp/probe_resp.json | python3 -c "import sys, json; r=json.load(sys.stdin); print('citationChips:', r.get('citationChips')); print('toolCalls:', r.get('toolCalls')); print('msg head:', r.get('message','')[:100])"

# 8) Grep the staging logs for the WAVE1C_PAYLOAD line. If router.py instrumentation
#    works, this returns exactly one matching line per probe.
railway logs --service MINT --environment staging --lines 500 | grep WAVE1C_PAYLOAD | tail -1 > /tmp/wave1c_log_line.txt
cat /tmp/wave1c_log_line.txt

# 9) Extract the JSON payload from the log line (everything after "WAVE1C_PAYLOAD ")
sed -E 's/.*WAVE1C_PAYLOAD //' /tmp/wave1c_log_line.txt > .planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload.json
python3 -c "import json; d=json.load(open('.planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload.json')); print('keys:', list(d.keys())); print('system len:', len(d.get('system','')))"

# 10) Run the bisection script (script already at bisect.py in same dir)
railway run --service MINT --environment staging -- python3 .planning/phases/wave-1c-coach-tool-dispatch-rca/bisect.py | tee .planning/phases/wave-1c-coach-tool-dispatch-rca/bisect_output.log

# 11) Read the verdict — the script prints WHICH context-layer drop restored tool_use
cat .planning/phases/wave-1c-coach-tool-dispatch-rca/bisect_results.json | python3 -m json.tool | head -40
```

## The bisection script — what it does

`.planning/phases/wave-1c-coach-tool-dispatch-rca/bisect.py` reads the captured payload and replays it against Anthropic API while progressively dropping context layers:

1. `drop_history` — keep only the last user message
2. `drop_bundles` — strip `# === bundle: ... ===` blocks from the system prompt
3. `drop_profile_ctx` — strip `<profile_context>...</profile_context>` blocks
4. `drop_rag` — strip `<retrieval|faq|grounding_pack|rag>...</...>` blocks
5. `drop_legacy_doctrine` — strip the "Ne cite JAMAIS un chiffre que tu ne peux pas sourcer..." line

First drop that restores `stop_reason="tool_use"` names the culprit. If all 5 drops fail to restore tool_use, the bug is in the tools schemas themselves (rare; means we need to inspect tool descriptions).

## After the culprit is named

Ship a focused fix PR. Likely shapes:

- **If culprit = `legacy_doctrine`**: rewrite `services/backend/app/services/coach/claude_coach_service.py:660` to require tool invocation BEFORE refusal. ~10-line PR.
- **If culprit = `profile_context`**: change `_build_system_prompt_with_memory` (coach_chat.py:~1000-1090) to NOT inline null fields, OR to phrase the empty profile as "data missing → invoke tool to fetch" rather than "data missing → refuse". ~30-line PR.
- **If culprit = `rag`**: audit the RAG corpus chunks that get pre-injected — likely a FAQ chunk says "encourage user to enter their data first". Edit the corpus. Larger PR.
- **If culprit = `bundles`**: add MANDATORY-tool-invocation directives in bundle prompt fragments (`life_event_router.py`, `compliance_narrator.py`). Medium PR.
- **If culprit = `history`**: weird (no history on a fresh user) — re-investigate, may be a router-side caching artifact.

## qa-expert regression-test floor (mandatory before fix PR merges)

Per engram obs id 69:

1. `tests/test_coach_citation/test_narrator_emits_tool_use_for_intent.py` — 6 force-keyword fixtures, mock Anthropic, assert `stop_reason=="tool_use"` + correct tool name.
2. `tests/bundles/test_compile_yields_chip_emitter.py` — parameterized 3 messages, asserts `compile_bundles(intents).allowed_tools ∩ CHIP_EMITTERS` is non-empty.
3. `tests/test_coach_citation/test_g2_archetype_matrix.py` — 8 archetypes × 6 tools (swiss_native, expat_eu, expat_us FATCA, cross_border, independent_no_lpp, …). Reuse Wave 1a parity fixture rig.
4. `tools/simulator/flows/maestro-perfect-set/coach_tool_dispatch_all_6_smoke.yaml` — assert chips for ALL 6 tools (not just `budget_snapshot`). Add `runFlow: auth/login.yaml` precondition.
5. Sentry breadcrumb at `coach_chat.py:4181` emitting `{detected_intents, narrator_tool_count, chip_emitter_count}` + alarm rule: `stop_reason==end_turn AND prose matches /Je vais (récupérer|analyser|projeter)/ AND narrator_tool_count ≥ 1` → tripwire.

## Teardown checklist (after fix lands)

1. `railway variable delete --service MINT --environment staging WAVE1C_INSTRUMENT_ENABLED` + `railway restart --service MINT --yes`
2. Revert both instrumentation blocks (PR #628's `llm_client.py:232-258` + PR #631's `router.py:_call_anthropic`) in a final cleanup PR.
3. Delete the `claude-wave1c-bisect-*@example.com` staging test accounts (or leave them — they're not flagged as real users).
4. Flip Wave 1b phase status `PENDING G2 — RUNTIME GAP` → `SHIPPED` in `.planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` after a successful live G2 probe.
5. Delete the 5 orphan Railway env vars (`COACH_TOOL_SERVER_SIDE_BUDGET_STATUS`, `_CAP_STATUS`, `_COUPLE_OPTIMIZATION`, `_CROSS_PILLAR_ANALYSIS`, `_RETIREMENT_PROJECTION`) — separate cleanup, optional.

## Files to be aware of

| Path | Why |
|---|---|
| `.planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` | Wave 1b status doc, G2 Run #2 section has the corrected hypothesis + qa-expert regression test floor |
| `.planning/phases/wave-1b-citation-chips/g2-evidence/` | 7 HTTP probe response JSONs + Maestro debug bundle + JUnit (3.2 MB, all on dev) |
| `.planning/phases/wave-1c-coach-tool-dispatch-rca/experiment.py` | The falsification experiment (already ran) |
| `.planning/phases/wave-1c-coach-tool-dispatch-rca/experiment_results.json` | Verbatim outputs proving H2 falsified |
| `.planning/phases/wave-1c-coach-tool-dispatch-rca/bisect.py` | Bisection harness — run after capturing payload |
| `.planning/phases/wave-1c-coach-tool-dispatch-rca/tools.json` | Cached narrator tools dump (26 tools) |
| `services/backend/app/services/rag/llm_client.py:232-258` | PR #628 instrumentation (wrong call site, kept for legacy path) |
| `services/backend/app/services/llm/router.py:_call_anthropic` | PR #631 instrumentation (the correct narrator call site) |
| `services/backend/app/api/v1/endpoints/coach_chat.py:1000-1090` | `_build_system_prompt_with_memory` — likely culprit area |
| `services/backend/app/services/coach/claude_coach_service.py:660` | Legacy "Ne cite JAMAIS sans sourcer" doctrine — potential culprit |
| `services/backend/app/services/coach/citation_grammar.py:86-89` | Refusal escape hatch — potential culprit |

## Engram observations to cite via `prior_finding_refs`

| obs_id | What |
|---|---|
| 65 | Wave 1b UAT pivot to G2 closure (decision) |
| 66 | Wave 1b G2 Run #2 — 3 blockers (2 fixed, 1 needs RCA) |
| `obs-9da5edde4d023346` (id ~71) | Wave 1b Blocker 3 RCA consensus (FALSIFIED — keep for audit trail but supersede with 74) |
| 73 | Same as above, the supersession entry |
| 74 (`obs-bcb0b41d70a52ae4`) | **Experiment falsifies tool_choice hypothesis — context bloat is the real suppressor** (this is the current truth) |

## Memory shortcuts for next session

- `mem_search` query: `wave-1b blocker 3 tool dispatch` → returns the consensus chain (start from obs 74, walk back)
- `mem_search` query: `wave-1c experiment falsification` → returns obs 74 directly
- The bisect.py script is hermetic — needs only `tools.json` (already on disk) + `captured_staging_payload.json` (you create from `railway logs`) + Anthropic API key (via `railway run`).

## Open questions / gotchas

- **Profile PATCH 422** during my register-seed flow (canton VD, birthYear 1981, etc.) — payload field probably mis-named or enum violation. Not critical (budget seed worked, that's enough for `get_budget_status`). If chasing the LPP/3a chip too, fix the PATCH payload by reading `services/backend/app/schemas/profile.py:ProfileUpdate`.
- **PR #631 may be BLOCKED on Backend tests still running** when next session starts. Just poll `gh pr checks 631` until pass, then merge.
- **`railway restart` alone does NOT pick up new env vars** — must trigger a redeploy (`railway redeploy --service MINT --yes`) or set the variable without `--skip-deploys`. Learned the hard way this session.
- **iPhone-17-Pro sim has the wave-1b Runner.app installed** but is on the anonymous landing screen (no auth session). If you want to do a SIM-side G2 verification post-fix, register via the sim UI or seed an auth token into Keychain.

## Bottom line for the next session

PR #631 is the last instrumentation step. After it lands + dev→staging, the bisection runbook above produces a deterministic answer to "which staging context layer suppresses `tool_use`?" — usually within 5-10 min of polling. Once the culprit is named, the fix PR is small (10-30 lines depending on which layer). Wave 1b ships green after that. Wave 1c becomes "instrumentation teardown + the fix PR + regression test floor".

If anything in this handoff feels wrong, **start from `experiment_results.json`** — that's the deterministic ground truth that anchors everything else.
