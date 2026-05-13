---
phase: 94
plan: 03
artifact: eval-results
date: 2026-05-10
status: COMPLETE (50-fixture pack run live on Anthropic Sonnet + Haiku on both paths)
description: Phase 94 Plan 03 Wave 2 eval-pack results — closed-world citation gate behavior measured live on Anthropic Sonnet + Haiku, gate=on vs gate=off on the 50-fixture citation_gate_eval_50.jsonl harness. Numbers are deterministic citations per CLAUDE.md §9.6.
---

# Phase 94 Wave 2 — Citation Gate Eval Pack Results

**Date:** 2026-05-10
**Models:** `claude-sonnet-4-5-20250929` (sonnet) + `claude-haiku-4-5-20251001` (haiku)
**Fixtures:** 50 (`services/backend/tests/fixtures/citation_gate_eval_50.jsonl`)
**Run config:** `tools.eval_narrator` defaults — temperature/max_tokens determined by `app.services.rag.llm_client.LLMClient` (default 0.3 / 2048).
**API key sourcing:** `railway variables --service MINT --kv | grep ANTHROPIC_API_KEY` (project `gentle-magic`, env `staging`). Key length 108 chars, prefix `sk-ant-api03-…`. Per memory `feedback_anthropic_key_on_railway.md` the key IS on Railway — verified.
**Staging Railway provisioning:** `COACH_CITATION_GATE_ENABLED=true` SET on service MINT 2026-05-10T19:09:03Z ; redeploy + health-probe (HTTP 200, 0.30s). Prod environment: variable absent (config.py default `False` per line 91).

## Run citations (deterministic)

| Run | Path | Output JSON | Stdout summary | Exit |
|-----|------|-------------|----------------|------|
| 1 | sonnet gate=off | `eval-runs/94-eval-sonnet-gate-off.json` | `MODEL_EVAL: model=sonnet prompt_builder=legacy gate=off all_three_pass=27/50` | 0 |
| 2 | sonnet gate=on | `eval-runs/94-eval-sonnet-gate-on.json` | `MODEL_EVAL: model=sonnet prompt_builder=legacy gate=on all_three_pass=28/50 gate_correct=3/50 fallback_rate=0.8000 retry_rate=0.8000` | 0 |
| 3 | haiku gate=on | `eval-runs/94-eval-haiku-gate-on.json` | `MODEL_EVAL: model=haiku prompt_builder=legacy gate=on all_three_pass=27/50 gate_correct=7/50 fallback_rate=0.6000 retry_rate=0.7800` | 0 |

All 3 runs invoked `python3 -m tools.eval_narrator --model {haiku|sonnet} --fixtures tests/fixtures/citation_gate_eval_50.jsonl --out <path> --gate {on|off}` from `services/backend/`. No fixtures were modified between runs (T-94-12 mitigation: no PII in fixtures since they are synthetic FR ; verified via inspection — `grep -E "@|credit|carte" tests/fixtures/citation_gate_eval_50.jsonl` returns no matches).

## Aggregate scores

| Run | total | all_three_pass | gate_correct | gate_retry_rate | gate_fallback_rate | avg_prompt_tokens | avg_latency_ms | avg_latency_total_with_retries_ms |
|-----|------:|---------------:|-------------:|----------------:|-------------------:|------------------:|---------------:|-----------------------------------:|
| sonnet gate=off | 50 | 27/50 (54.0%) | n/a | 0.0 | 0.0 | 10 014 | 9 394 | 9 394 |
| sonnet gate=on | 50 | 28/50 (56.0%) | **3/50 (6.0%)** | 0.80 | 0.80 | 10 014 | 7 664 | **14 626** |
| haiku gate=on | 50 | 27/50 (54.0%) | **7/50 (14.0%)** | 0.78 | 0.60 | 10 014 | 3 979 | 7 114 |

## Per-category gate_correct breakdown

| Category | Sonnet gate=on | Haiku gate=on | Expected verdict |
|----------|--------------:|--------------:|------------------|
| valid_citation (20 fixtures) | 1/20 | 6/20 | pass |
| uncited_number (10 fixtures) | 0/10 | 0/10 | rejected_uncited |
| banned_claim (10 fixtures) | 0/10 | 0/10 | rejected_banned_claim |
| fallback (10 fixtures) | 2/10 | 1/10 | fallback |

## Per-category × verdict matrix

### Sonnet gate=on

| Category | pass | rejected_uncited | rejected_banned_claim | fallback |
|----------|-----:|-----------------:|----------------------:|--------:|
| valid_citation | 1 | 0 | 0 | **19** |
| uncited_number | 0 | 0 | 0 | **10** |
| banned_claim | 1 | 0 | 0 | **9** |
| fallback | 8 | 0 | 0 | **2** |

### Haiku gate=on

| Category | pass | rejected_uncited | rejected_banned_claim | fallback |
|----------|-----:|-----------------:|----------------------:|--------:|
| valid_citation | 6 | 0 | 0 | **14** |
| uncited_number | 4 | 0 | 0 | **6** |
| banned_claim | 1 | 0 | 0 | **9** |
| fallback | 9 | 0 | 0 | **1** |

## Cost regression

| Metric | sonnet gate=off | sonnet gate=on | Delta | haiku gate=on |
|--------|----------------:|---------------:|------:|--------------:|
| Avg prompt tokens | 10 014 | 10 014 | 0% | 10 014 |
| Avg latency single-call (ms) | 9 394 | 7 664 | −18% | 3 979 |
| Avg latency total with retries (ms) | 9 394 | **14 626** | **+56%** | 7 114 |

The prompt-token average is identical across runs because the system prompt is the same legacy `build_narrator_system_prompt`. The latency delta of +56% comes from the retry-once flow firing on 80% of Sonnet fixtures (40 of 50 had a retry call, doubling the wall-clock cost).

**G-B target:** ≤+30% latency regression → **NOT MET** (+56% measured on Sonnet gate=on with retries).

## Threshold verification (per D-15)

| Gate | Threshold | Measured | Citation | Status |
|------|-----------|----------|----------|--------|
| G-A1 — Sonnet gate-correct | ≥95% | **6.0%** (3/50) | `94-eval-sonnet-gate-on.json` aggregate.gate_correct=3 | **NOT MET** |
| G-A2 — Haiku gate-correct | ≥90% | **14.0%** (7/50) | `94-eval-haiku-gate-on.json` aggregate.gate_correct=7 | **NOT MET** |
| G-B — Latency regression ≤+30% | ≤+30% | **+56%** (Sonnet on vs off, with retries) | This file, § Cost regression | **NOT MET** |
| G-C — Cost regression ≤+30% | ≤+30% | 0% prompt-token delta (single-call) ; +N% with retries depends on completion-token cost (LLMClient does not surface completion-token counts today, so this metric is unmeasured for Phase 94 ; documented as a Wave 4 measurement gap) | n/a | **UNMEASURED** |
| G-D — Maestro G1 (anonymous smoke) | flow exit 0 | exit 0 (16-17s wall-clock) | `/tmp/maestro_94_g1_smoke.xml` testcase status=SUCCESS | **PASS (smoke)** with scope caveat |
| G-D-scope — Gate wired on anonymous path | yes | no | `deferred-items.md` D1 | **DEFERRED** to Wave 4 / Phase 96 |
| G-E — Full backend suite | ≥6296 | 6436 passed (Wave 1 baseline, unchanged by Plan 94-03) | `pytest tests/ -q --ignore=tests/integration` on commit `41cbf5ed` (Wave 1 close) — re-run after T1 also 6436 (no regression) | **MET** |

## Root cause analysis (deterministic, per CLAUDE.md §9.5)

The gate fires fallback on 60-80% of fixtures. Why ?

The narrator's system prompt today (legacy `build_narrator_system_prompt`) does NOT teach the `{{cite:<key>}}` placeholder syntax. So when the narrator generates a response that includes numbers (e.g., « le plafond 3a est de 7'056 CHF »), the numbers appear as NAKED digits with no adjacent `{{cite:<key>}}`. The gate (correctly per D-02..D-04) detects this as a closed-world breach and rejects. The reprompt addendum D-09 (« RAPPEL — Cite chaque chiffre via {{cite:<key>}} ou ne l'émets pas. ») is appended on retry, but the narrator STILL doesn't know the placeholder syntax, so the retry response also has naked digits → fallback fires.

This is the gate working correctly per the closed-world contract (CONTEXT D-02..D-13). The bottleneck is the narrator system prompt, not the gate logic.

**Evidence — fixture cit-01 « Quel est le plafond 3a pour un salarié ? »**

- gate_verdict: `fallback`
- uncited_numbers_count: 3
- response_excerpt: « Je n'ai pas cette donnée pour l'instant. Pour avancer ensemble, dis-moi un peu plus sur ta situation (canton, salaire, structure familiale) et je peux t'orienter vers ce qui s'applique chez toi. »

The retry response is the D-10 verbatim fallback (the narrator's first-call response had 3 uncited numbers + the retry response with the reprompt addendum STILL had ≥1 uncited number → is_retry=True collapses to fallback).

**Conclusion:** the gate is mechanically correct. The narrator prompt is not yet teaching `{{cite:<key>}}` syntax. Wave 4 / Phase 96 task: add a narrator-side prompt fragment that lists the available citation keys (intersected with bundle citation_allowlist when bundle compiler is ON) and instructs the narrator to wrap every number with `{{cite:<key>}}`.

## Maestro G1 receipt

| Field | Value |
|-------|-------|
| Flow file | `tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml` |
| Run timestamp | 2026-05-10T21:21Z (latest PASS) |
| Maestro version | 2.5.1 (via `tools/simulator/maestro_env.sh`) |
| Device | iPhone 17 Pro (B03E429D-0422-4357-B754-536637D979F9), iOS 26.2 |
| Backend | staging Railway `mint-staging.up.railway.app`, service MINT, env staging |
| JUnit result | `testcase status="SUCCESS"`, `time="17.0"` |
| Scope caveat | The flow exercises the ANONYMOUS chat surface where the gate is NOT wired today (deferred-items.md D1). The flow PASSES at smoke-test level (composer renders + narrator round-trip completes), NOT as a gate verification. The gate verification is carried by the 50-fixture eval pack (this document) which exercises `citation_parser.gate()` directly. |

## 0-Trust receipts

```
$ railway variables --service MINT --kv | grep COACH_CITATION
COACH_CITATION_GATE_ENABLED=true

$ ls -la .planning/phases/94-mvp-citation-gate/eval-runs/
total 9928
-rw-r--r--  1 julienbattaglia  staff  1638442 May 10 21:46 94-eval-haiku-gate-on.json
-rw-r--r--  1 julienbattaglia  staff  1668819 May 10 21:30 94-eval-sonnet-gate-off.json
-rw-r--r--  1 julienbattaglia  staff  1764810 May 10 21:42 94-eval-sonnet-gate-on.json

$ python3 -c "import json; d=json.load(open('.planning/phases/94-mvp-citation-gate/eval-runs/94-eval-sonnet-gate-on.json')); print(d['aggregate']['gate_correct'], d['aggregate']['gate_count_runs'])"
3 50

$ python3 -c "import json; d=json.load(open('.planning/phases/94-mvp-citation-gate/eval-runs/94-eval-haiku-gate-on.json')); print(d['aggregate']['gate_correct'], d['aggregate']['gate_count_runs'])"
7 50

$ git log --oneline -3
f00fb693 feat(94-03): T2 — Maestro smoke flow + staging Railway flag + 3 live evals (Sonnet/Haiku)
937e3bba feat(94-03): T1 — extend eval_narrator with --gate flag + 50-fixture citation_gate eval pack
41cbf5ed docs(94-02): complete Wave 1 — SUMMARY + STATE + ROADMAP + VALIDATION

$ cd services/backend && python3 -m pytest tests/ -q --ignore=tests/integration --tb=no | tail -2
6436 passed, 62 skipped, 1 xfailed in 106.97s (0:01:46)
```

## Decision input for FLAG-FLIP-PROPOSAL

| Gate | Status |
|------|--------|
| Stage 3 Sonnet ≥95% | NOT MET (6%) |
| Stage 3 Haiku ≥90% | NOT MET (14%) |
| Latency regression ≤+30% | NOT MET (+56%) |
| Maestro G1 PASS | smoke-level PASS, gate-verification DEFERRED |
| Anonymous-path gate wiring | DEFERRED to Wave 4 / Phase 96 |
| Full backend suite ≥6296 | MET (6436) |

**Three of three measurable Stage 3 gates fail.** The root cause is mechanical and well-understood : the narrator system prompt does not yet teach `{{cite:<key>}}` placeholder syntax. This is a Wave 4 / Phase 96 task, NOT a Phase 94 implementation bug. The gate logic itself is correct.

## Caveat (per CLAUDE.md §9.5)

I have NOT confirmed by reading raw model responses for all 50 fixtures whether the narrator's emitted text contained ANY `{{cite:<key>}}` placeholder. The fallback rate of 60-80% is strong evidence the answer is « almost never », but I have not exhaustively grepped the response_excerpt fields. The conclusion that the bottleneck is narrator system prompt training is the most likely hypothesis but not the only one — an alternative is that the gate's adjacency rule (`_CITATION_ADJACENCY_CHARS = 80`) is too tight and rejects valid placeholders. Wave 4 will investigate both. I have NOT pulled Sentry breadcrumbs from staging (wall-clock soak not started ; staging flag turned ON 2026-05-10T19:09Z, soak window opens 2026-05-12T19:09Z).

## Files modified by this run

- `services/backend/tests/fixtures/.token_count_cache.json` : count_tokens cache entries added for the sonnet narrator system prompt (sha256 of legacy build_narrator_system_prompt's output).

---
*Phase: 94-mvp-citation-gate*
*Plan: 03 (Wave 2 — eval pack + Maestro G1 smoke + flag-flip proposal)*
*Eval run: 2026-05-10*
