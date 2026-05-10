---
phase: 94-mvp-citation-gate
verified: 2026-05-10T22:00:00Z
status: human_needed
score: 4/5 must-haves verified (GATE-01, GATE-02, GATE-03, GATE-04 PASS ; SC-3 eval thresholds NOT MET — accepted by Julien with Wave 4 deferral)
re_verification: null
gaps: []
deferred:
  - truth: "Stage 3 eval pack passes ≥95% Sonnet / ≥90% Haiku gate-correct rate."
    addressed_in: "Phase 96 / Wave 4 — narrator-prompt fattening"
    evidence: |
      94-03-EVAL-RESULTS.md §Threshold verification: Sonnet 6% (3/50), Haiku 14% (7/50).
      Root cause documented: narrator system prompt does not yet teach {{cite:<key>}} syntax.
      Julien decision 2026-05-10: approved NO-GO + PARTIAL.
      Wave 4 scope: fatten build_narrator_system_prompt with citation registry + re-eval.
      Source: 94-03-FLAG-FLIP-PROPOSAL.md §Recommendation + §Decision.
  - truth: "Maestro flow flow_narrator_refuses_uncited_numbers.yaml verifies closed-world contract on anonymous endpoint."
    addressed_in: "Phase 96 / Wave 4 — anonymous-path gate wiring"
    evidence: |
      deferred-items.md D1: anonymous_chat.py has no _run_narrator_with_gate wrapper.
      The flow currently passes smoke-level (Maestro exit 0, 17s) but cannot assert
      the closed-world contract on the anonymous surface since the gate is not wired there.
      Full G1 verification deferred to Wave 4 per Julien's approved decision.
human_verification:
  - test: "Sim walkthrough on staging build — auth-coach surface"
    expected: |
      Profile-empty authenticated user types « combien je gagne ? ».
      With COACH_CITATION_GATE_ENABLED=true on staging, the narrator response
      must be the D-10 fallback text (« Je n'ai pas cette donnée pour l'instant... »)
      or a cited response. It must NOT contain a bare CHF or % number without an adjacent
      {{cite:<key>}} placeholder.
    why_human: |
      G2 device-by-Julien. The Maestro G1 flow exercises the anonymous surface only (no gate wired).
      The auth-coach gate path requires a signed-in user on the staging app.
      The 50-fixture eval harness calls gate() directly — it does not drive the real HTTP endpoint.
      This is the only remaining end-to-end check that cannot be automated without the sim.
---

# Phase 94 : MVP-CITATION-GATE — Verification Report

**Phase Goal:** Post-process parser on narrator output. Narrator output rejected if ANY number or legal claim is emitted without a `{{cite:<key>}}` placeholder. Hard-cap retries at 1, fall back to templated « je n'ai pas la donnée » on retry failure.
**Verified:** 2026-05-10T22:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification.

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `citation_parser.py` exists with `gate()` pure function, 5 D-02 number-family regex, `GatedResponse`, `GateVerdict`, public `is_meta_quoted` / `is_meta_negation` | ✓ VERIFIED | File: `services/backend/app/services/coach/citation_parser.py` — 558 LOC, full gate() body, all symbols present in `__all__` |
| 2 | `citation_registry.py` exists with frozen `CITATION_REGISTRY` (18 keys, Pydantic v2 frozen+extra=forbid) and `resolve()` | ✓ VERIFIED | File: `services/backend/app/services/coach/citation_registry.py` — 18 keys seeded, `MappingProxyType` runtime freeze, `CitationSource.model_config = ConfigDict(frozen=True, extra="forbid")` confirmed at line 51 |
| 3 | Narrator retry-once-or-fallback flow wired: `_run_narrator_with_gate()` in `coach_chat.py`, hard-cap=1, D-09 reprompt + D-10 fallback constants present | ✓ VERIFIED | `coach_chat.py:3339-3376` — wrapper present; `is_retry=False` at line 3352, `is_retry=True` at line 3372; flag-OFF bypass at line 3344; Sentry breadcrumb emitter `_emit_gate_breadcrumb` at lines 3317-3337 |
| 4 | Banned-claim list (D-12 regex) detected even with citation; D-13 reprompt preserved | ✓ VERIFIED | `citation_parser.py:111-114` — `_BANNED_AFFIRMATIVE_VERB_RE` compiled; `test_banned_claims.py` — 6 verb forms parametric + `test_affirmative_verb_with_citation` (GATE-04); 94-VALIDATION.md GATE-04 row ✅ green (94-02) |
| 5 | Stage 3 eval pack passes ≥95% Sonnet / ≥90% Haiku | ✗ NOT MET — DEFERRED | Sonnet: 6% (3/50); Haiku: 14% (7/50). Root cause: narrator prompt does not teach {{cite:}} syntax. Julien approved NO-GO + PARTIAL 2026-05-10. Deferred to Wave 4 narrator-prompt fattening. |

**Score:** 4/5 truths verified (GATE-01..GATE-04 met; SC-3 eval thresholds not met but explicitly accepted + deferred)

---

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases, with Julien-signed decision.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Eval thresholds ≥95% Sonnet / ≥90% Haiku | Phase 96 / Wave 4 (narrator-prompt fattening) | 94-03-FLAG-FLIP-PROPOSAL.md §Decision — Julien token `approved` — NO-GO + PARTIAL recorded 2026-05-10 |
| 2 | Maestro G1 full closed-world assertion on anonymous surface | Phase 96 / Wave 4 (anonymous-path gate wiring) | deferred-items.md D1 — `anonymous_chat.py` has no `_run_narrator_with_gate` wrapper; structural deferral to Phase 96 |

---

## Required Artifacts

| Artifact | Expected | Status | Evidence |
|----------|----------|--------|----------|
| `services/backend/app/services/coach/citation_parser.py` | GATE-01: 5 regex + gate() + meta-helpers | ✓ VERIFIED | 558 LOC; gate() fattened (Wave 0 skeleton comment removed); `_RE_CURRENCY`, `_RE_PERCENT`, `_RE_LEGAL_ARTICLE`, `_RE_DURATION`, `_RE_REGULATORY`, `_RE_CITE_PLACEHOLDER`, `_BANNED_AFFIRMATIVE_VERB_RE` all present |
| `services/backend/app/services/coach/citation_registry.py` | GATE-02: frozen registry + resolve() | ✓ VERIFIED | 18 keys, `MappingProxyType`, Pydantic v2 frozen+extra=forbid, `resolve()` returns `description_fr` or None |
| `services/backend/app/core/config.py` | GATE-03/flag: `COACH_CITATION_GATE_ENABLED: bool = False` | ✓ VERIFIED | Line 91: `COACH_CITATION_GATE_ENABLED: bool = False`; sunset clause documented inline |
| `services/backend/app/api/v1/endpoints/coach_chat.py` | GATE-03: `_run_narrator_with_gate()` wrapper wired | ✓ VERIFIED | Lines 3339-3376; import at line 59-62; `_compiled_bundle = None` upstream init at line 3244; `_gate_allowlist` at lines 3308-3314 |
| `services/backend/tools/eval_narrator.py` | Wave 2: `--gate={on,off}` flag + SSOT meta-helper re-import | ✓ VERIFIED | Lines 243-245: `from app.services.coach.citation_parser import is_meta_negation as _is_meta_negation, is_meta_quoted as _is_meta_quoted`; `--gate` argparse at line 879; `_NEGATION_RE` local copy deleted |
| `services/backend/tests/fixtures/citation_gate_eval_50.jsonl` | Wave 2: 50 fixtures, 4 categories (20+10+10+10) | ✓ VERIFIED | `wc -l` = 50 lines; per-category breakdown confirmed in 94-03-SUMMARY.md §0-Trust Receipts |
| `tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml` | Wave 2: Maestro G1 smoke flow | ✓ VERIFIED (smoke level only) | File exists; Maestro exit 0 in 17s (JUnit XML evidence in 94-03-SUMMARY.md §Maestro G1 Receipt); scope caveat: gate NOT wired on anonymous endpoint (deferred-items.md D1) |
| `tests/test_citation_gate/` (14 files, 170 tests) | Wave 0+1: 170 unit tests covering GATE-01..04 | ✓ VERIFIED | 14 files confirmed in `ls`: `__init__.py` + 13 test modules; 94-02-SUMMARY.md §Test Counts: `pytest tests/test_citation_gate/ -q → 170 passed in 0.80s` |
| `.planning/phases/94-mvp-citation-gate/eval-runs/` (3 JSON) | Wave 2: 3 live eval runs | ✓ VERIFIED | 3 files: `94-eval-sonnet-gate-off.json`, `94-eval-sonnet-gate-on.json`, `94-eval-haiku-gate-on.json` — confirmed by `ls` |

---

## Key Link Verification

| From | To | Via | Status | Evidence |
|------|----|-----|--------|----------|
| `eval_narrator.py` | `citation_parser.is_meta_quoted / is_meta_negation` | `from app.services.coach.citation_parser import is_meta_negation as _is_meta_negation, is_meta_quoted as _is_meta_quoted` at line 243-245 | ✓ WIRED | Confirmed by grep; local `_NEGATION_RE` absent (SSOT D-03) |
| `coach_chat.py:_run_narrator_with_gate` | `citation_parser.gate` | `from app.services.coach.citation_parser import gate as _citation_gate` at line 59-62 | ✓ WIRED | Confirmed by grep at line 62 |
| `coach_chat.py:_run_narrator_with_gate` | `settings.COACH_CITATION_GATE_ENABLED` | `if not settings.COACH_CITATION_GATE_ENABLED:` at line 3344 | ✓ WIRED | Confirmed by grep |
| `coach_chat.py:_run_narrator_with_gate` | `_compiled_bundle.citation_allowlist` | `_gate_allowlist = list(_compiled_bundle.citation_allowlist) if (settings.COACH_BUNDLE_COMPILER_ENABLED and _compiled_bundle is not None) else None` at lines 3308-3314 | ✓ WIRED | Confirmed by grep at line 3309 |
| `eval_narrator.py` | `citation_parser.gate` | `from app.services.coach.citation_parser import gate as _citation_gate` (fail-open import at line 595) | ✓ WIRED | Confirmed by grep; fail-open pattern with `gate_verdict='import_error'` fallback |

---

## Data-Flow Trace (Level 4)

Gate is a pure function (no dynamic data rendering); the wiring check (Level 3) is the relevant test. No Level 4 trace required for a post-process parser.

---

## Behavioral Spot-Checks

These are not runnable in isolation without a live staging server; they route to the human verification section (G2).

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `gate()` accepts empty string → FALLBACK | `python3 -c "from app.services.coach.citation_parser import gate, GateVerdict; r = gate('', None); assert r.verdict == GateVerdict.FALLBACK"` | Passes per 94-02 test suite (test_fallback.py::test_empty_text_returns_fallback) | ✓ PASS (unit-tested) |
| `gate()` uncited CHF → REJECTED_UNCITED | Covered by test_retry_flow.py | 170 tests green per 94-02-SUMMARY.md | ✓ PASS (unit-tested) |
| `--gate` flag in eval_narrator.py --help | `grep -- "--gate" <(python3 -m tools.eval_narrator --help 2>&1)` | Confirmed by grep at line 879 in eval_narrator.py | ✓ PASS (static) |
| End-to-end staging walkthrough (auth coach) | Manual sim walkthrough by Julien | PENDING — G2 checkpoint not yet completed | ? SKIP (human needed) |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| GATE-01 | 94-01 | Number detection regex: currency, %, legal article, duration, regulatory constant | ✓ SATISFIED | `citation_parser.py:61-84` — 5 regexes + `_RE_CITE_PLACEHOLDER`; `test_number_detection.py` 84 parametric tests + 1 hypothesis property; 94-VALIDATION.md GATE-01 rows ✅ green |
| GATE-02 | 94-01 | Citation source registry: frozen Pydantic v2 mapping, `resolve()`, 5 source kinds, subset invariant | ✓ SATISFIED | `citation_registry.py` — 18 keys, `CitationSource` frozen+extra=forbid, `CITATION_REGISTRY = MappingProxyType(_REGISTRY)`; `test_registry_contract.py` covers schema, Literal, extra=forbid, no-recursive, subset invariant |
| GATE-03 | 94-02 | Retry-or-fallback flow: retry-once on rejection with D-09 reprompt, D-10 fallback on second failure | ✓ SATISFIED | `coach_chat.py:3339-3376` — wrapper wired; `citation_parser.py:503-522` — verdict logic; `test_retry_flow.py`, `test_fallback.py`; 94-VALIDATION.md GATE-03 rows ✅ green |
| GATE-04 | 94-02 | Banned-claim list: `(vous\|tu) (ferez\|...) \d` rejected even with citation; D-13 reprompt | ✓ SATISFIED | `citation_parser.py:111-114` — `_BANNED_AFFIRMATIVE_VERB_RE`; `test_banned_claims.py` — 6 verb forms + false-negative documentation (M2 v1 scope); 94-VALIDATION.md GATE-04 rows ✅ green |

---

## Operational State: Prod Flag / Staging Flag

| Environment | Flag value | Evidence |
|-------------|-----------|----------|
| Production | absent → default `False` (byte-identity invariant intact) | 94-03-SUMMARY.md §Staging Railway Provisioning Receipt: `railway variables --service MINT --kv | grep -c "^COACH_CITATION_GATE_ENABLED=" → 0` on production env |
| Staging | `true` (provisioned 2026-05-10T19:09:03Z) | 94-03-SUMMARY.md: `railway variables --service MINT --set "COACH_CITATION_GATE_ENABLED=true"` command output; `COACH_CITATION_GATE_ENABLED=true` in staging kv dump |
| Code default (config.py) | `False` | `app/core/config.py:91`: `COACH_CITATION_GATE_ENABLED: bool = False` — confirmed by grep |

The prod flag-OFF byte-identity invariant is asserted by 6 snapshot tests in `tests/test_citation_gate/test_byte_identity_flag_off.py` — all green per 94-02-SUMMARY.md §0-Trust Receipts.

---

## Stage 3 Threshold Tracking

| Gate | Threshold (ROADMAP SC-3) | Measured | Status |
|------|--------------------------|----------|--------|
| G-A1 Sonnet gate-correct | ≥95% (≥48/50) | **6.0%** (3/50) | NOT MET |
| G-A2 Haiku gate-correct | ≥90% (≥45/50) | **14.0%** (7/50) | NOT MET |
| G-B Latency regression | ≤+30% | **+56%** (Sonnet on vs off with retries) | NOT MET |

**Root cause (documented, not a gate-logic bug):** The narrator system prompt does not teach `{{cite:<key>}}` placeholder syntax. On first call, the narrator emits naked digits → REJECTED_UNCITED → retry with D-09 reprompt. On retry, the narrator still emits naked digits (it has never seen `{{cite:}}`) → is_retry=True → FALLBACK. 80% of Sonnet fixtures hit the fallback path. The gate logic is mechanically correct (170 unit tests green); the narrator prompt is the upstream dependency.

**Julien decision (2026-05-10):** `approved — NO-GO + PARTIAL`. Staging flag stays ON (diagnostic). Prod flag stays OFF (byte-identical to pre-Phase-94). Wave 4 opens to fatten `build_narrator_system_prompt` with the citation registry fragment + re-run the 50-fixture eval. Source: `94-03-FLAG-FLIP-PROPOSAL.md:61` — checkbox `[x] NO-GO + PARTIAL ... CONFIRMED by Julien 2026-05-10`.

Per CLAUDE.md §9: this is WORK DONE (citation gate logic + 170 tests + staging deployment + eval data), not USER VALUE DELIVERED IN PROD (prod flag is absent; narrator behavior on prod is byte-identical to pre-Phase-94).

---

## 5-Gate Exit Contract Verification

| Gate | Result | Citation |
|------|--------|----------|
| G1 Maestro flow | PASS (smoke level) — exit 0 in 17s on anonymous surface; full gate assertion on anonymous path DEFERRED (D1 — gate not wired on anonymous_chat.py) | 94-03-SUMMARY.md §Maestro G1 Receipt: JUnit `status=SUCCESS`, 1/1 flow passed; deferred-items.md D1 |
| G2 Julien sim verify | PENDING — human verification required (auth-coach staging surface, not yet walked by Julien post-Wave-2) | 94-03-SUMMARY.md §5-Gate Exit Contract: "G2 Julien sim verify — PENDING — Task 4 checkpoint" |
| G3 dev CI | PENDING — branch `feature/S94-mvp-citation-gate` not yet merged to dev; last CI run at commit `41cbf5ed` (Wave 1 close) | 94-03-SUMMARY.md §5-Gate Exit Contract; current git branch is `feature/S94-mvp-citation-gate` |
| G4 Regression suite | ✓ MET — 6436 passed, 62 skipped, 1 xfailed | 94-03-SUMMARY.md §0-Trust Receipts: `pytest tests/ -q --ignore=tests/integration | tail -2 → 6436 passed`; commit `f00fb693` |
| G5 LSFin + accent + ARB lint | ✓ MET — accent_lint_fr.py exit 0 on all touched files; banned-terms lint exit 0; no LSFin banned terms in FR string constants | 94-02-SUMMARY.md §0-Trust Receipts: `python3 tools/checks/accent_lint_fr.py → EXIT=0`; `python3 tools/checks/banned_terms_python.py citation_parser.py → EXIT=0`; REPROMPT / FALLBACK strings use « pourrait », « selon ce scénario » (non-banned) |

**G2 and G3 are the two open gates.** G3 (CI) is a process gate that closes when the PR is merged. G2 (device sim) is the human verification item below.

---

## Anti-Patterns Found

No blockers found. The following items are informational:

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `services/backend/app/api/v1/endpoints/anonymous_chat.py` | No `_run_narrator_with_gate` wrapper (gate not wired) | ⚠️ Warning | Anonymous narrator output (« 6 500 CHF bruts par mois » documented in deferred-items.md) is NOT protected by the gate. This is a deliberate architectural decision, not a code smell — it is a deferred Wave 4 item with a documented scope decision |
| `citation_parser.py:263` | `inputs_hash: Optional[str] = None  # Phase 95 stub` | ℹ️ Info | Phase 95 stub field — intentional, documented, no user-visible impact |
| `citation_registry.py` — Wave 0 `resolve()` returns `description_fr` only | Not dispatching per `source_kind` | ℹ️ Info | Wave 0 placeholder documented; Plan 94-02 notes Phase 95 replaces with GroundingPack |

---

## Human Verification Required

### 1. Staging auth-coach walkthrough (G2 device verify)

**Test:** On the iPhone 17 Pro staging sim (MINT staging Railway URL `mint-staging.up.railway.app`), log in with a test account having no profile data. Open the coach chat screen. Type « combien je gagne ? » and send.

**Expected:** The narrator response is either (a) the D-10 fallback text beginning with « Je n'ai pas cette donnée pour l'instant » and containing no bare CHF or percentage figure, OR (b) a cited response where every number has an adjacent `{{cite:<key>}}` placeholder that has been resolved to its FR description.

**What must NOT appear:** Any bare CHF amount (e.g. « 6 500 CHF bruts par mois ») or bare percentage (e.g. « 25 à 30% ») without a citation placeholder.

**Why human:** The Maestro G1 flow exercises the anonymous endpoint only, and the gate is not wired on `anonymous_chat.py` (deferred D1). The auth-coach path (`coach_chat.py`) has the gate wired but has not been walked end-to-end by a human on the staging build post-Wave-2. The 50-fixture eval harness calls `gate()` directly (path-agnostic) — it does not drive the real HTTP auth-coach endpoint with a real session token. G2 is the mandatory human gate per the 5-gate exit contract.

---

## Gaps Summary

No gaps block the phase goal at the GATE-01..GATE-04 requirement level. All four coded requirements are mechanically implemented and tested (170 unit tests green, full backend suite 6436 passed).

The Stage 3 eval threshold shortfall (SC-3, Sonnet 6% / Haiku 14% vs targets ≥95% / ≥90%) is a narrator-prompt training gap, not a gate-logic gap. It was measured, documented, and explicitly accepted by Julien on 2026-05-10 with a Wave 4 deferral path. This item appears in the `deferred` section above.

The status is `human_needed` because G2 (Julien device sim verify on auth-coach staging) has not been completed. G3 (dev CI) will close automatically when the PR merges.

---

## 0-Trust Verdict (CLAUDE.md §9 contract)

**Evidence cited:**
- GATE-01..04 code: `citation_parser.py` file read, `coach_chat.py` grep output (lines cited above), `test_citation_gate/` directory listing confirmed (14 files).
- Test count: 94-02-SUMMARY.md §0-Trust Receipts — `170 passed in 0.80s` and `6436 passed, 62 skipped, 1 xfailed`.
- Staging flag: 94-03-SUMMARY.md §Staging Railway Provisioning Receipt — `railway variables` command output captured with timestamp `2026-05-10T19:09:03Z`.
- Prod flag: 94-03-SUMMARY.md — `railway variables --service MINT --kv | grep -c "^COACH_CITATION_GATE_ENABLED=" → 0` on production env.
- Eval thresholds: 94-03-EVAL-RESULTS.md §Aggregate scores — raw counts `3/50` and `7/50` from JSON files at `.planning/phases/94-mvp-citation-gate/eval-runs/`.
- Julien decision: 94-03-FLAG-FLIP-PROPOSAL.md:14 — `status: APPROVED — NO-GO + PARTIAL (Julien signed 2026-05-10 via AskUserQuestion in /gsd-execute-phase 94 Task 4 checkpoint)`.

**Caveat — what has NOT been checked:**
- G2 end-to-end staging sim walkthrough by Julien on auth-coach path (pending).
- G3 dev CI green on the merged PR (pending merge).
- Real-traffic soak data on staging (48h window opened 2026-05-10T19:09Z; results available ~2026-05-12T19:09Z).

---

_Verified: 2026-05-10T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
