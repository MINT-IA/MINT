---
phase: 94
plan: 02
subsystem: coach
wave: 1
tags:
  - citation-gate
  - retry-or-fallback
  - banned-claim
  - bundle-integration
  - sentry-hygiene
  - byte-identity
requires:
  - phase-94-01  # gate skeleton + 5 D-02 regex + public meta-helpers + 18-key registry
  - phase-93.5-bundle-compiler  # citation_allowlist contract (D-18)
provides:
  - app/services/coach/citation_parser.py:gate  # FATTENED body — full retry-or-fallback verdict logic
  - app/services/coach/citation_parser.py:REPROMPT_ADDENDUM_UNCITED  # D-09 verbatim FR
  - app/services/coach/citation_parser.py:REPROMPT_ADDENDUM_BANNED_CLAIM  # D-13 verbatim FR
  - app/services/coach/citation_parser.py:FALLBACK_TEMPLATED_TEXT  # D-10 verbatim FR
  - app/services/coach/citation_parser.py:_BANNED_AFFIRMATIVE_VERB_RE  # D-12 v1 regex
  - app/api/v1/endpoints/coach_chat.py:_run_narrator_with_gate  # wrapper inside narrator handler
  - app/api/v1/endpoints/coach_chat.py:_compiled_bundle_None_init  # H1 fix iter 1
  - tests/test_citation_gate/test_retry_flow.py  # D-08/D-09/D-13 verbatim
  - tests/test_citation_gate/test_fallback.py  # D-10 verbatim + no-template-vars
  - tests/test_citation_gate/test_banned_claims.py  # D-12 + M2 false-negatives
  - tests/test_citation_gate/test_bundle_intersect.py  # D-07 + H1 regression
  - tests/test_citation_gate/test_global_registry_fallback.py  # D-07 fallback path
  - tests/test_citation_gate/test_telemetry.py  # D-18 hygiene
  - tests/test_citation_gate/test_gate_performance.py  # H3 fix iter 1 — p95 ≤50ms
affects:
  - tests/test_citation_gate/test_number_detection.py  # +3 D-04#4 strip tests
  - .planning/phases/94-mvp-citation-gate/94-VALIDATION.md  # Wave 1 rows ✅ green
tech-stack:
  added: []
  patterns:
    - "Closure-as-wrapper at handler scope (Karpathy #3 surgical)"
    - "Forward-ref string annotation `_compiled_bundle: \"CompiledBundle | None\"` (H1 fix)"
    - "Sentry breadcrumb fail-open emitter (try/except wrapping)"
    - "Verbatim FR string constants (no template variables — D-10 determinism)"
key-files:
  created:
    - services/backend/tests/test_citation_gate/test_retry_flow.py
    - services/backend/tests/test_citation_gate/test_fallback.py
    - services/backend/tests/test_citation_gate/test_banned_claims.py
    - services/backend/tests/test_citation_gate/test_bundle_intersect.py
    - services/backend/tests/test_citation_gate/test_global_registry_fallback.py
    - services/backend/tests/test_citation_gate/test_telemetry.py
    - services/backend/tests/test_citation_gate/test_gate_performance.py
  modified:
    - services/backend/app/services/coach/citation_parser.py
    - services/backend/app/api/v1/endpoints/coach_chat.py
    - services/backend/tests/test_citation_gate/test_number_detection.py
    - .planning/phases/94-mvp-citation-gate/94-VALIDATION.md
decisions:
  - D-04#4 (M3 fix iter 1) — placeholder-body strip via `_strip_placeholders` runs BEFORE all number-detection regex passes ; original `response_text` preserved for adjacency + substitution.
  - D-07 — flag-ON intersect with `_compiled_bundle.citation_allowlist` ; flag-OFF / `_compiled_bundle is None` → `citation_allowlist=None` → gate falls back to global `CITATION_REGISTRY` keys.
  - D-08 — retry hard-cap=1 enforced by `is_retry: bool` parameter on `gate()` ; second-pass collapses ANY rejection to FALLBACK ; `_run_agent_loop` is called at MOST 2× per request.
  - D-09 / D-10 / D-13 — verbatim FR string constants (UTF-8 with full accents) ; D-10 is a `str` literal with NO template variables (`f"..."`, `.format()`, `%s`, `{var}`) — determinism contract enforced by `test_fallback_no_template_vars`.
  - D-12 (M2 fix iter 1) — v1 regex scope = `(?:vous|tu)\s+(?:ferez|feras|aurez|auras|gagnerez|gagneras)\s+\d` ; 3rd-person, infinitive, and LSFin « garanti » documented as v1 false-negatives ; eval pack measures the rate at Stage 3.
  - D-18 — Sentry breadcrumb payload restricted to 4 non-PII keys (`verdict`, `retries`, `uncited_numbers_count`, `banned_claims_count`) ; emitter is fail-open (try/except wrapping).
  - H1 fix iter 1 — `_compiled_bundle: "CompiledBundle | None" = None` initialized BEFORE the bundle-compiler branch ; the wrapper safely reads `_compiled_bundle is not None` on every code path (flag-OFF, except, elif, else).
  - Karpathy #3 surgical — ZERO edits inside `_run_agent_loop` (lines 1726-2624) ; the wrapper is a closure at handler scope ; diff is 114 insertions / 18 deletions, all concentrated at the wrapper insertion site.
metrics:
  duration: "≈45m"
  completed: 2026-05-10
  tasks_completed: 3
  files_created: 7
  files_modified: 4
  tests_added: "≈64 (Wave 1 — 7 new files + 3 D-04#4 tests appended to test_number_detection.py)"
  full_suite: "6436 passed, 62 skipped, 1 xfailed in 106.60s (Wave 0 baseline 6372 + 64 ≈ 6436 — no regression)"
---

# Phase 94 Plan 02 : MVP-CITATION-GATE Wave 1 (Wiring) Summary

Wave 1 fattens the `gate()` body and wires the closed-world citation gate into the production narrator path behind `COACH_CITATION_GATE_ENABLED` (default OFF). Karpathy #3 surgical contract honored : ZERO edits inside `_run_agent_loop` (lines 1726-2624) ; all changes concentrated at the narrator handler scope (line ~3236 H1 init + ~3268-3370 wrapper). Production narrator output remains BYTE-IDENTICAL to the Phase 93.5 baseline when the flag is OFF — asserted by 6 byte-identity snapshot tests still green.

## Files Created (Wave 1)

- `services/backend/tests/test_citation_gate/test_retry_flow.py` — D-08 retry budget invariant (`is_retry=True` never returns `retry_needed=True`) + D-09 / D-10 / D-13 byte-equality regression for the 3 verbatim FR string constants.
- `services/backend/tests/test_citation_gate/test_fallback.py` — D-10 verbatim regression + no-template-vars source-level lint (greps the assignment block for `{`, `f"`, `%s`, `.format(`) + empty/whitespace inputs → FALLBACK + `is_retry=True` collapses uncited and banned-claim to FALLBACK.
- `services/backend/tests/test_citation_gate/test_banned_claims.py` — 6 verb forms parametric (vous/tu × ferez/feras/aurez/auras/gagnerez/gagneras) + D-13 reprompt KEEPS the `{{cite:...}}` placeholder + M2 fix iter 1 documented v1 false-negatives (3rd-person, infinitive, LSFin « garanti »).
- `services/backend/tests/test_citation_gate/test_bundle_intersect.py` — D-07 flag-ON: source-level grep for `_gate_allowlist = list(_compiled_bundle.citation_allowlist)` AND H1 regression suite (init upstream of `_cb(...)` assignment + except/elif/else paths leave `_compiled_bundle = None` so the wrapper does NOT raise NameError).
- `services/backend/tests/test_citation_gate/test_global_registry_fallback.py` — D-07 flag-OFF: gate verdicts on known/unknown/closed-world-breach keys when `citation_allowlist=None` (falls back to `CITATION_REGISTRY` keys).
- `services/backend/tests/test_citation_gate/test_telemetry.py` — D-18 payload-key whitelist (exactly 4 keys: `verdict`, `retries`, `uncited_numbers_count`, `banned_claims_count`) + no PII suspect keys + fail-open emitter receipt + retry-budget invariant via grep for `is_retry=True` on the second gate call.
- `services/backend/tests/test_citation_gate/test_gate_performance.py` — H3 fix iter 1 : end-to-end `gate()` p95 ≤ 50ms / max ≤ 80ms on 4 kB FR realistic narrative, 100 iterations. Hard-coded fixture (NOT generated). Exercises the production code path (placeholder strip + allowlist intersect + banned-claim scan + legal-article priority + 4 number passes + meta-helpers + adjacency + substitution).

## Files Modified (Wave 1)

- `services/backend/app/services/coach/citation_parser.py` — fattened `gate()` body : empty-text fallback → D-04#4 placeholder strip → D-12 banned-claim scan → legal-article span priority → 4 number passes (currency / % / duration / regulatory) with meta-quote / meta-negation / closed-world-allowlist excuses → verdict computation. 3 verbatim FR string constants (`REPROMPT_ADDENDUM_UNCITED`, `REPROMPT_ADDENDUM_BANNED_CLAIM`, `FALLBACK_TEMPLATED_TEXT`) + 1 D-12 regex (`_BANNED_AFFIRMATIVE_VERB_RE`) added at module-level. Skeleton marker comment removed.
- `services/backend/app/api/v1/endpoints/coach_chat.py` — H1 fix iter 1 : `_compiled_bundle: "CompiledBundle | None" = None` initialized BEFORE the bundle-compiler branch (~line 3236). Inner closure `_run_narrator_with_gate()` inserted between `_compiled_bundle` resolution and the response build (~line 3283-3370). Replaces the single `await asyncio.wait_for(_run_agent_loop(...))` call. Wrapper paths : flag-OFF returns `loop_result` UNCHANGED ; flag-ON runs `gate()` + retry-once-or-fallback. D-18 Sentry breadcrumb emitter wrapped in try/except (fail-open). NO edits inside `_run_agent_loop` body (lines 1726-2624 — Karpathy #3).
- `services/backend/tests/test_citation_gate/test_number_detection.py` — appended 3 D-04#4 tests (M3 fix iter 1) : `test_d04_exception_4_placeholder_body_stripped` (digits inside placeholder bodies are exempt), `test_d04_exception_4_placeholder_strip_does_not_hide_real_uncited` (close adjacency still cited), `test_d04_exception_4_placeholder_strip_isolated_uncited` (far number still rejected when no cite within 80 chars).
- `.planning/phases/94-mvp-citation-gate/94-VALIDATION.md` — frontmatter `wave_1_complete: true` ; per-task verification rows for Wave 0 + Wave 1 flipped to ✅ green ; Wave 0/1 requirement checkboxes flipped to `[x]` ; Wave 2 rows kept ⬜ pending (Plan 94-03 territory).

## Test Counts

- Wave 1 added : ≈ 64 tests across 7 new files + 3 D-04#4 tests appended to `test_number_detection.py`. (`pytest tests/test_citation_gate/ -q` → **170 passed in 0.80s**.)
- Phase 93.5 close-out baseline : 6266.
- Wave 0 close-out : 6372 (baseline + 106 Wave-0 tests).
- Wave 1 close-out : **6436 passed**, 62 skipped, 1 xfailed (Wave 0 + ≈ 64 Wave-1 tests). No regression.

## Wrapper Insertion Shape (Karpathy #3 receipt)

20 LOC around the wrapper invocation in `coach_chat.py` (line ranges drift ; markers stable):

```python
    _compiled_bundle: "CompiledBundle | None" = None  # noqa: F821 — fwd ref
    if settings.COACH_BUNDLE_COMPILER_ENABLED:
        try:
            from app.services.coach.bundle_compiler import (
                compile_bundles as _cb,
            )
            _compiled_bundle = _cb(
                intents=detected_intents or set(),
                ctx=coach_ctx,
                language=body.language,
            )
            ...
        except (KeyError, ValueError):
            _narrator_tools = get_narrator_llm_tools()
    elif settings.COACH_DUAL_LLM_ENABLED:
        _narrator_tools = get_narrator_llm_tools()
    else:
        _narrator_tools = get_llm_tools()
    ...
    _initial_loop_kwargs = dict(orchestrator=orchestrator, ...)
    _gate_allowlist = (
        list(_compiled_bundle.citation_allowlist)
        if (settings.COACH_BUNDLE_COMPILER_ENABLED and _compiled_bundle is not None)
        else None
    )
    async def _run_narrator_with_gate() -> dict:
        loop_result = await asyncio.wait_for(
            _run_agent_loop(question=body.message, **_initial_loop_kwargs),
            timeout=AGENT_LOOP_DEADLINE_SECONDS,
        )
        if not settings.COACH_CITATION_GATE_ENABLED:
            return loop_result   # D-20 byte-identical bypass
        gated = _citation_gate(response_text=loop_result["answer"], ctx=coach_ctx,
                               citation_allowlist=_gate_allowlist, is_retry=False)
        _emit_gate_breadcrumb(gated, retries=0)
        if not gated.retry_needed:
            loop_result["answer"] = gated.gated_text
            return loop_result
        # D-08 retry-once.
        retry_message = body.message + (gated.reprompt_addendum or "")
        retry_result = await asyncio.wait_for(
            _run_agent_loop(question=retry_message, **_initial_loop_kwargs),
            timeout=AGENT_LOOP_DEADLINE_SECONDS,
        )
        retry_gated = _citation_gate(..., is_retry=True)
        _emit_gate_breadcrumb(retry_gated, retries=1)
        retry_result["answer"] = retry_gated.gated_text
        return retry_result
    try:
        loop_result = await _run_narrator_with_gate()
    except asyncio.TimeoutError:
        ...
```

## Bundle Integration Receipt (D-07)

```bash
$ grep -nE "_gate_allowlist\s*=\s*\(" services/backend/app/api/v1/endpoints/coach_chat.py
3308:    _gate_allowlist = (

$ grep -nE "_compiled_bundle\.citation_allowlist" services/backend/app/api/v1/endpoints/coach_chat.py
3309:        list(_compiled_bundle.citation_allowlist)
```

`_compiled_bundle.citation_allowlist` flows from the Phase 93.5 bundle compiler into `_citation_gate(citation_allowlist=...)` when the compiler flag is on AND the bundle compiled successfully. On flag-OFF / `_compiled_bundle is None`, the allowlist is `None` and the gate falls back to global `CITATION_REGISTRY` keys (Wave 0 baseline behavior).

## Sentry Breadcrumb Hygiene Proof (D-18)

```bash
$ pytest tests/test_citation_gate/test_telemetry.py -q
.........                                                                [100%]
9 passed in 0.05s
```

The 4 contract keys (`verdict`, `retries`, `uncited_numbers_count`, `banned_claims_count`) are the ONLY keys in the breadcrumb data dict. No PII suspect keys (`message`, `text`, `prompt`, `answer`, `body`, `user`, `content`, `narrator`) appear. Emitter is fail-open (try/except).

## Karpathy #3 Surgical Diff Receipt

```bash
$ git diff --stat services/backend/app/api/v1/endpoints/coach_chat.py
 .../backend/app/api/v1/endpoints/coach_chat.py | 132 ++++++++++++++++++---
 1 file changed, 114 insertions(+), 18 deletions(-)

$ git diff services/backend/app/api/v1/endpoints/coach_chat.py | grep -E "^[-+][^-+]" | wc -l
126
```

All 126 changed lines are concentrated at the narrator handler scope (line ~3236 H1 init + ~3268-3370 wrapper). NO edits inside `_run_agent_loop` body (lines 1726-2624). Karpathy #3 surgical contract honored.

## 0-Trust Receipts

```
$ cd services/backend && python3 -m pytest tests/test_citation_gate/ -q --tb=no
........................................................................ [ 42%]
........................................................................ [ 84%]
..........................                                               [100%]
170 passed in 0.80s

$ cd services/backend && python3 -m pytest tests/ -q --ignore=tests/integration
6436 passed, 62 skipped, 1 xfailed in 106.60s (0:01:46)

$ python3 tools/checks/accent_lint_fr.py --file services/backend/app/services/coach/citation_parser.py
EXIT=0

$ python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_parser.py
EXIT=0

$ git log --oneline -3
13230885 feat(94-02): T2 — wire _run_narrator_with_gate() in coach_chat.py + bundle integration + Sentry hygiene
1d9b44f1 feat(94-02): T1 — fatten gate() body + D-04#4 strip + D-12 banned-claim + verbatim FR (D-09/D-10/D-13)
baaf8a87 docs(94-01): complete Wave 0 — SUMMARY + STATE + ROADMAP
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] perf-test fixture undersized**

- **Found during** : Task 1 — `test_4kb_fixture_size_above_threshold` first run.
- **Issue** : `_FR_BLOCK * 8` = 3416 bytes < 4000 byte target. The H3 fix budget is anchored on a 4 kB realistic narrator output ; a 3.4 kB fixture would let perf assertions slip below the spec budget.
- **Fix** : bumped multiplier to `* 10` → ≈ 4270 bytes. Single-line change in `test_gate_performance.py`. Re-run : 3 perf tests green.
- **Files modified** : `services/backend/tests/test_citation_gate/test_gate_performance.py`.

**2. [Rule 3 - Blocking] H1 init-upstream test grepped wrong `if` branch**

- **Found during** : Task 2 — `test_compiled_bundle_init_is_upstream_of_compiler_branch` first run.
- **Issue** : there are TWO `if settings.COACH_BUNDLE_COMPILER_ENABLED:` branches in coach_chat.py. The first (~line 777) is in `_build_system_prompt_with_memory` and is a Phase 93.5 prompt-builder concern, NOT a narrator-handler concern. The H1 init must precede the SECOND branch (~line 3236 — narrator handler) ; the test was matching the FIRST.
- **Fix** : renamed the test to `test_compiled_bundle_init_is_upstream_of_narrator_compiler_branch` and pinned to the narrator-handler-specific `_compiled_bundle = _cb(...)` assignment marker (which only exists in the narrator branch). Re-run : H1 regression suite green (4/4 tests).
- **Files modified** : `services/backend/tests/test_citation_gate/test_bundle_intersect.py`.

**3. [Rule 3 - Cleanliness] Wave 0 skeleton marker comment was still in `GatedResponse` docstring**

- **Found during** : Task 1 — `done` criterion `grep -A 2 "Wave 0 skeleton" citation_parser.py` returned a hit on the dataclass docstring.
- **Issue** : the `gated_text` field doc still mentioned « Wave 0 skeleton : echoes the input verbatim ». Now that the body is fattened, the doc is stale.
- **Fix** : reworded to describe the actual post-fatten contract (PASS-branch substitution, FALLBACK-branch verbatim, REJECTED_*-branch original `response_text`).
- **Files modified** : `services/backend/app/services/coach/citation_parser.py`.

No architectural deviations (Rule 4) ; no skipped tests ; no auth gates.

## Auth Gates

None — Wave 1 is pure parser-logic + handler wiring ; no Anthropic API calls, no Railway service touches, no Maestro flows.

## WORK DONE vs USER VALUE DELIVERED (CLAUDE.md §9 0-Trust separation)

**WORK DONE** :

- Fattened `gate()` body with full retry-or-fallback verdict logic.
- 3 verbatim FR string constants + 1 D-12 banned-claim regex.
- `_run_narrator_with_gate()` wrapper inserted in `coach_chat.py` narrator handler (Karpathy #3 surgical).
- `_compiled_bundle = None` upstream initializer (H1 fix iter 1).
- D-18 Sentry breadcrumb emitter wired with non-PII payload + fail-open try/except.
- 7 new test files + 3 tests appended (≈ 64 new tests). Full backend suite green at 6436.
- D-04#4 placeholder-body strip (M3 fix iter 1) — digits inside `{{cite:<key>}}` bodies exempt from number detection.
- M2 fix iter 1 — 3 documented v1 banned-claim regex false-negatives codified as test fixtures.
- H3 fix iter 1 — end-to-end `gate()` p95 ≤ 50ms on 4 kB FR narrative.

**USER VALUE DELIVERED** :

NONE YET. The flag `COACH_CITATION_GATE_ENABLED` defaults `False` in prod ; flag-OFF path is byte-identical (5 snapshot tests + 1 env-binding sanity test still green). End-user narrator behavior is UNCHANGED.

The user-visible value lands when :

- Plan 94-03 builds the 50-fixture eval pack + extends `eval_narrator.py` with `--gate={on,off}` + lands the Maestro G1 flow + flips the staging flag for Stage 3 eval.
- Plan 94-04 (post-soak) flips the prod flag IF the staging soak shows ≤ 2% fallback rate over 4 weeks (D-21 sunset gate).

Per CLAUDE.md §9 : « PR opened ≠ shipped. Tests passing ≠ feature working. End-to-end user flow on sim before any « ready ». » Wave 1 ships scaffolding + wiring ; the end-to-end user flow has NOT been run on staging — that is Plan 94-03's deliverable.

## Wave 1 → Wave 2 Handoff (Plan 94-03)

Plan 94-03 is now unblocked and will :

1. **Build the 50-fixture eval pack** at `services/backend/tests/fixtures/citation_gate_eval_50.jsonl` per D-14 (20 valid citations + 10 uncited + 10 banned claims + 10 fallback).
2. **Extend `tools/eval_narrator.py`** with `--gate={on,off}` flag (≈ 5-10 LOC delta per RESEARCH §OQ-6) ; reuse the meta-helpers via SSOT alias from Wave 0.
3. **Land Maestro G1 flow** at `tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml` per D-16 ; profile-empty user asks « combien je gagne ? » → response MUST NOT contain a fabricated CHF number.
4. **Run Stage 3 eval on staging** : flip `COACH_CITATION_GATE_ENABLED=true` on Railway staging, run the 50-fixture pack with Sonnet (≥ 95% gate-correct) + Haiku (≥ 90% gate-correct).
5. **Produce FLAG-FLIP-PROPOSAL.md** mirroring `93.5-04-FLAG-FLIP-PROPOSAL.md` template — Plan 94-04 gates the prod flip on Stage-3 PASS + 4-week staging soak.

Foundation is tested, frozen, byte-identity-preserved, and SSOT-clean. Plan 94-03 starts from a green baseline.

## Self-Check : PASSED

Files created (verified existence) :

- FOUND : `services/backend/tests/test_citation_gate/test_retry_flow.py`
- FOUND : `services/backend/tests/test_citation_gate/test_fallback.py`
- FOUND : `services/backend/tests/test_citation_gate/test_banned_claims.py`
- FOUND : `services/backend/tests/test_citation_gate/test_bundle_intersect.py`
- FOUND : `services/backend/tests/test_citation_gate/test_global_registry_fallback.py`
- FOUND : `services/backend/tests/test_citation_gate/test_telemetry.py`
- FOUND : `services/backend/tests/test_citation_gate/test_gate_performance.py`

Commits cited (verified in `git log`) :

- FOUND : `1d9b44f1` (T1 — fatten gate() body)
- FOUND : `13230885` (T2 — wire wrapper)
- FOUND (this commit) : T3 + close-out (final docs commit)

All claims grounded.
