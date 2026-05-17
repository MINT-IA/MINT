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

Wave 1b citation chips ship to dev+staging but **don't render in practice**. The 3-agent RCA's tool_choice hypothesis was falsified by experiment. Real bug isolated 2026-05-15 17:38 CEST via captured payload + bisection: **the narrator grammar teaches citation FORMAT but NOT tool INVOCATION**. The LLM emits `{cite:tool_retirement_projection}` placeholder in prose AND refuses (`stop_reason=end_turn`), without ever calling `tool_use`. Fix path = reorder the narrator grammar instruction so it MANDATES tool invocation BEFORE the citation placeholder. See `## Update 2026-05-15 17:38 CEST` section below for the captured evidence.

The instrumentation PR chain (#627 → #628 → #630 → #629 → #631 → #632 → #633) is COMPLETE. Staging is live with router.py instrumentation. The captured payload + first bisection run are committed. Next session can skip steps 1-9 of the original runbook and jump straight to writing the targeted fix.

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

---

## Update 2026-05-15 17:38 CEST — captured payload + first bisect run

PR #631, #632, #633 all landed during the session (post the section above). Staging is live with router.py instrumentation on commit `e78699aa`. A smoke probe (retirement question) was fired, the `WAVE1C_PAYLOAD` log line was captured, hydrated with full tool schemas from `tools.json`, and `bisect.py` ran against it.

### Captured payload — key facts

- `model`: `claude-sonnet-4-5-20250929`
- `tool_choice`: `{"type": "auto", "disable_parallel_tool_use": false}`
- **`tools`: 3 only** (filtered down from the 26-tool registry by the bundle compiler): `get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`. So `get_retirement_projection` IS advertised — the LLM has the tool but doesn't use it.
- `system`: 44,416 chars (RÈGLES DE CONFORMITÉ + LSFin doctrine + bundle fragments)
- `messages`: 1 (user role only, no conversation history) — content begins with a RAG injection prefix `"Contexte de la base de connaissances MINT :\n..."` followed by the actual user question. RAG is inlined into the USER MESSAGE, not the system prompt.

Files:
- `.planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload.json` (raw)
- `.planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload_hydrated.json` (with full tool schemas from `tools.json` lookup — what bisect.py actually consumed)
- `.planning/phases/wave-1c-coach-tool-dispatch-rca/bisect_results.json` (the bisection verdict)

### Bisection verdict — all 5 drops FAILED

| Layer dropped | stop_reason | tool_use count | system_len (chars) |
|---|---|---|---|
| baseline (full payload) | `end_turn` | 0 | 44,416 |
| `drop_history` | `end_turn` | 0 | 44,416 |
| `drop_bundles` | `end_turn` | 0 | 44,416 |
| `drop_profile_ctx` | `end_turn` | 0 | 44,416 |
| `drop_rag` | `end_turn` | 0 | 44,416 |
| `drop_legacy_doctrine` | `end_turn` | 0 | 44,416 |

The `system_len` stayed at 44,416 across all drops, meaning my regex-based markers (`# === bundle:`, `<profile_context>`, `<retrieval>`, etc.) **didn't match** the actual format of the staging system prompt. The bisection's `drop_*` transforms were effectively no-ops. The text-only refusal that came back was the same baseline behavior 5 times in a row.

**Next session must update bisect.py's regexes** to match the actual staging system-prompt format. Open `.planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload.json`, read the `system` field, identify the real block delimiters (likely `RÈGLES DE CONFORMITÉ`, `## ` headers, or some other marker), then re-run.

### Smoking gun discovered in the bisect output

Across MULTIPLE drop variants, the LLM emitted citation placeholders **in its prose response without ever calling `tool_use`**. Examples from the bisect results:

- `drop_history` text: `"calculer ta projection {cite:tool_retirement_projection}"`
- `drop_legacy_doctrine` text: `"sans connaître ta situation {cite:tool_retirement_projection}"`
- `drop_bundles` text: `"calculer ta rente AVS ni ta rente LPP {cite:lavs_age_reference_2026}"`

The LLM KNOWS the tool exists. It even **cites the tool by name in the citation grammar**. But it interprets `{{cite:tool_<name>}}` as a **citation FORMAT to follow**, not as a **mandate to actually INVOKE the tool first**. The narrator grammar teaches the LLM how to CITE without teaching it that the underlying tool must be CALLED before the citation is emitted.

This is the doctrine-level root cause. The Wave 1b plan-03 grammar fragment in `services/backend/app/services/coach/citation_grammar.py:146` reads (paraphrased):

> "L'outil `get_budget_status` renvoie un surplus mensuel de … "

That's an EXAMPLE of how to format a citation. Sonnet 4.5 follows the FORMAT pattern in its prose without invoking the tool — because the prompt never says "MANDATORILY call `get_budget_status` BEFORE emitting any `{{cite:tool_<name>}}` placeholder".

### Targeted fix path for Wave 1c (~15-25 lines)

The fix lives in `services/backend/app/services/coach/citation_grammar.py`. Reorder + harden the doctrine block:

1. **Before** showing how to FORMAT a citation, MANDATE that the corresponding tool MUST have been invoked via `tool_use` in this same turn.
2. Add an explicit example of the WRONG pattern (citation without prior tool_use) and the RIGHT pattern (tool_use → tool_result → cite the result).
3. Wire a compensating gate in `services/backend/app/api/v1/endpoints/coach_chat.py` (the existing `_citation_gate` or a sibling) that REJECTS any narrator response containing `{{cite:tool_<name>}}` placeholders if there was no corresponding `tool_use` block in the agent loop. Per memory `project_coach_forced_tool_invocation`, this is the "trust collapse" tripwire that should have been there all along.

This is the doctrine rewrite hypothesis — and it explains EVERYTHING the bisection showed:
- Token count delta (44k staging vs 6.8k minimal local) was a red herring; my minimal prompt didn't have the citation grammar fragment, so the LLM had no template to imitate and defaulted to actual tool_use.
- Tool advertisement is fine (3 tools incl. `get_retirement_projection`).
- `tool_choice=auto` is fine (the LLM is capable of choosing tool_use, it just doesn't because the prompt teaches it to fake citations instead).

### Recommended fix-PR shape

```
services/backend/app/services/coach/citation_grammar.py
  + add MANDATE paragraph at top of get_grammar() output:
    "AVANT d'émettre tout placeholder {{cite:tool_<name>}} dans ta réponse,
     tu DOIS appeler l'outil correspondant via le mécanisme tool_use.
     UNE citation = UN appel tool_use préalable. Aucune exception."
  + reorder existing format examples to come AFTER the mandate.

services/backend/app/api/v1/endpoints/coach_chat.py (or a new module)
  + new function: _enforce_tool_use_for_citations(answer_text, tool_calls)
    - parse `{{cite:tool_<name>}}` placeholders from answer_text
    - for each placeholder name, assert at least one matching tool_use block in tool_calls
    - if mismatch, REJECT → re-prompt with the missing tool_use mandate inlined
  + wire into _run_narrator_with_gate alongside _citation_gate (line ~4230)
  + Sentry breadcrumb on REJECT with category="coach.citation.tool_use_missing"
    (sister to coach.citation_gate, lets us measure the rate over time)

services/backend/tests/test_coach_citation/test_tool_use_mandate.py (NEW)
  + assert: prompt with {cite:tool_X} produces tool_use:X in response stack
  + assert: gate REJECTS when LLM emits placeholder without prior tool_use
  + assert: re-prompt restores correct behavior on retry
```

After the fix PR + qa-expert regression-test floor lands, tear down the WAVE1C instrumentation per the teardown checklist above. Wave 1b status flips from `PENDING G2 — RUNTIME GAP` to `SHIPPED` once the next probe returns `citationChips: [{toolName: ...}, ...]` non-null from staging.

### Updated PR + engram audit trail (post 17:38 CEST)

- PR #631 (router.py instrumentation): MERGED `d9964422`
- PR #632 (HANDOFF + bisect.py): MERGED `1e9e4ed9`
- PR #633 (second dev→staging): MERGED, merge commit `e78699aa`
- Railway staging deploy: `5408475b` SUCCESS, commit `e78699aa`
- Engram obs id 75 (`obs-bab7b74851fff6a9`): session handoff (this doc).
- Smoking-gun insight (this section) is NOT yet saved to engram — the next session should save it as a new `discovery` observation that supersedes the "context bloat" hypothesis from obs id 74.
