---
phase: wave-1a-backend-tools-refactor
plan: 06
subsystem: backend
tags: [coach-tools, cap-status, citation-guard, sentry, feature-flag, lsfin, middleware]

requires:
  - phase: wave-1a-00
    provides: COACH_CAP_CHF_GARDE_ENABLED feature flag (default True), `# >>> dispatch: get_cap_status` marker pair
  - phase: phase-94
    provides: _RE_CURRENCY compiled regex in citation_parser.py:68-70 (re-exported via __all__:721-734)

provides:
  - _validate_cap_response(rendered) middleware in coach_chat.py — strips un-cited CHF tokens from cap text and replaces them with verbatim FR "[montant indisponible]"
  - Sentry breadcrumb "coach.cap.cap_chf_uncited" (non-PII 120-char snippet payload) on every rejection
  - 7 unit tests in tests/test_cap_garde.py covering cite-present passthrough, cite-absent replacement, ±80-char boundary (3a/3b), no-CHF passthrough, flag-OFF passthrough, multi-token offset arithmetic

affects:
  - wave-1a-07 (parity harness can assert the middleware never alters cited cap text)
  - wave-1a-08 (rollout/5-gate close; this flag is already DEFAULT TRUE per D-09 so no toggle action needed)

tech-stack:
  added: []
  patterns:
    - "Output-filter middleware on a Flutter-sourced tool (kept Flutter-source per D-17 option b)"
    - "Substring-window adjacency check (`'{{cite:' in window`) instead of importing a second compiled regex"
    - "Inline import inside function body for telemetry (sentry_sdk) — fail-open via blanket try/except"
    - "Left-to-right replacement with cumulative offset tracking (avoids re-scanning after each swap)"

key-files:
  created:
    - services/backend/tests/test_cap_garde.py
  modified:
    - services/backend/app/api/v1/endpoints/coach_chat.py (inserted _validate_cap_response above _format_cap_status at line 2543; wrapped get_cap_status dispatcher branch inside markers at lines 1933-1936)
    - .planning/phases/wave-1a-backend-tools-refactor/wave-1a-06-PLAN.md (grep-first replan committed with this work)

key-decisions:
  - "Output-filter, not input-mutation: middleware wraps the FINAL rendered cap text rather than ctx field values, so it catches CHF anywhere (headline / why_now / cta / impact / active_goal) without binding to CapEngine's Flutter-side field shape"
  - "Substring check `'{{cite:' in window` instead of `_RE_CITE_PLACEHOLDER.search`: simpler, no second regex compile, sufficient because the cite placeholder always starts with that literal"
  - "Replacement string `[montant indisponible]` is pure ASCII (no accents to lint) — safe regardless of accent_lint_fr.py invocation context"
  - "Sentry breadcrumb category `coach.cap.cap_chf_uncited` distinct from plan-00 helper `coach.tool.<name>` — this is cap-text middleware, NOT a tool invocation"
  - "Inline import of `_RE_CURRENCY` inside the function body (per plan spec) — defers compile until first call, matches plan's grep acceptance pattern verbatim"

patterns-established:
  - "Pattern: adjacent-cite enforcement via fixed-width window substring search around regex match (works for any LSFin claim type, not just CHF — extensible to %, art., durations)"
  - "Pattern: middleware-wraps-formatter for Flutter-sourced tools that cannot be fully recomputed server-side (D-17 option b — minimal surface change, output-only enforcement)"
  - "Pattern: cumulative-offset replacement loop for multi-match string mutations (avoids re-scanning after each substitution and keeps complexity O(n) regardless of replacement count)"

requirements-completed: [WAVE1A-04]

duration: ~25 min
completed: 2026-05-14
---

# Phase wave-1a Plan 06: cap_status CHF Garde Middleware Summary

**`_validate_cap_response(rendered)` middleware wraps `_format_cap_status(ctx)` inside the `get_cap_status` dispatcher branch (markers preserved). The middleware reuses Phase 94's `_RE_CURRENCY` regex (single source of truth at `citation_parser.py:68-70`, re-exported via `__all__:721-734`) to scan for CHF/EUR/USD tokens; any token without `{{cite:<key>}}` within ±80 chars is replaced with the verbatim FR string `[montant indisponible]` and a fail-open Sentry breadcrumb (`coach.cap.cap_chf_uncited`, non-PII 120-char snippet) is emitted for the re-litigation signal per D-17.**

## Performance

- **Duration:** ~25 min
- **Tasks:** 1 (autonomous, TDD)
- **Files modified:** 3 (1 created + 2 modified)
- **Commit:** `bb5af0fc`

## Accomplishments

- **Regex reused, not duplicated**: `grep -Ec '_RE_CURRENCY\s*=\s*re\.compile' coach_chat.py` returns `0` (anti-fabrication grep proof — single source of truth at `citation_parser.py:68-70`).
- **Dispatcher markers preserved exactly**: `grep -c '# >>> dispatch: get_cap_status' coach_chat.py` and `grep -c '# <<< dispatch: get_cap_status' coach_chat.py` both return `1`. Only the BODY between the markers was changed (from `return _format_cap_status(ctx)` to `return _validate_cap_response(_format_cap_status(ctx))`).
- **Plan-00 invariant honored**: `grep -c 'COACH_CAP_CHF_GARDE_ENABLED: bool = True' config.py` returns `1` (unchanged from pre-plan-06). `config.py` is NOT in this plan's `files_modified` list.
- **7 unit tests collected and passing** (plan target was ≥5; plan listed 6 scenarios; Test 3's two sub-assertions ship as 3a/3b as separate test functions for clearer failure attribution).
- **Zero backend regressions**: full `pytest -q` reports `6766 passed, 62 skipped, 1 xfailed` (post-PR-#607 baseline + 7 plan-06 net new). The 6759 → 6766 delta is exactly +7 against the plan-02 SUMMARY baseline of 6759.
- **Sentry breadcrumb payload non-PII verified by Test 2 inline**: payload keys are exactly `{"snippet"}` — no `user_id`, no `profile_id`, no email; snippet length ≤120 chars enforced.

## Task Commits

1. **Task 1: _validate_cap_response middleware + dispatcher wrap + 7 tests** — `bb5af0fc` (feat)
   - Inserted `_validate_cap_response(rendered: str) -> str` function above `_format_cap_status` at line 2543 of `coach_chat.py` (53 lines including docstring).
   - Wrapped get_cap_status dispatcher branch inside markers at lines 1933-1936 with `return _validate_cap_response(_format_cap_status(ctx))`.
   - Created `services/backend/tests/test_cap_garde.py` with 7 unit tests.
   - Also committed the grep-first replan of `wave-1a-06-PLAN.md` (in-place revision per session memory; replan content matches the executed plan verbatim).
   - 3 files changed, 438 insertions(+), 97 deletions(-) (the -97 is the spec diff vs the pre-replan plan).
   - Hooks: lefthook green (memory-retention OK, map-freshness-hint surfaced docs/coach-tool-routing.md as advisory — no invariant change in this plan, see Deviations); commit-msg green.

_TDD pattern: the test file was created in the same commit as the implementation (RED→GREEN collapsed into one commit), matching the plan-02 precedent and the plan's `tdd="true"` interpretation. Tests verified GREEN locally with the implementation in place; running `pytest tests/test_cap_garde.py` against an empty `_validate_cap_response` is the equivalent RED phase (each test asserts middleware behavior that only the real implementation can satisfy)._

## Files Created/Modified

- `services/backend/tests/test_cap_garde.py` (created, 166 lines) — 7 pytest functions: `test_cite_present_within_window_passes_through`, `test_cite_absent_replaces_chf_and_emits_breadcrumb`, `test_boundary_just_inside_window_passes_through`, `test_boundary_just_outside_window_replaces`, `test_no_chf_tokens_passes_through`, `test_flag_off_passes_through`, `test_multi_token_mixed_offset_correctness`.
- `services/backend/app/api/v1/endpoints/coach_chat.py` (modified, +55 / -1) — inserted `_validate_cap_response` above `_format_cap_status`; rewired the body of the `get_cap_status` dispatcher branch between pre-existing markers. No other functions touched.
- `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-06-PLAN.md` (modified, +314 / -97) — the grep-first replan content committed alongside the implementation so the spec lives in git history. Plans 04 and 05 were also replanned this session but are NOT part of this commit (they remain modified in the working tree as separate units of work).

## Decisions Made

- **Tests 3a/3b boundary positions adjusted from plan's literal "80/81" to "73/74"**: the plan's `<behavior>` section described the boundary as `cite at exactly 80 chars from match.end` (caught) versus `cite at 81 chars from match.end` (missed). The implementation uses `window_end = match.end() + 80` (Python slicing — upper bound EXCLUSIVE). For the 7-char substring `{{cite:` to be fully present in `rendered[ws:we]`, its start position must satisfy `cite_start + 7 <= match.end() + 80` — i.e. the latest in-window start is `match.end() + 73`. The plan's literal numbers did not account for the 7-char width of the search string; the tests use `match.end() + 73` (caught) and `match.end() + 74` (missed) and document the off-by-one in the test docstrings using `_RE_CURRENCY.finditer` for position introspection (per the plan's directive: « Use `_RE_CURRENCY` ... to verify `match.start()` / `match.end()` positions on the constructed string »).
- **Test 6 multi-token spacing widened**: the plan suggested 3 CHF tokens in a single short string with cite near token 3. Naïve spacing puts the cite within token 2's ±80-char window too, defeating the multi-replacement test. The shipped Test 6 uses 100 spaces between tokens so each window is disjoint — token 1 and token 2 are both un-cited (replaced); token 3 carries the only cite (preserved).
- **Test 3 split into two pytest functions (3a / 3b)**: the plan listed Test 3 as a single test with two sub-assertions. The shipped suite uses two top-level functions for clearer failure attribution (pytest's collection reports each boundary case as a separate result). Plan target of ≥5 tests is satisfied at 7.

## Deviations from Plan

### Auto-fixed / Documented Issues

**1. [Rule 1 - Bug] Plan boundary numbers off-by-seven (plan-spec ambiguity, corrected in tests)**
- **Found during:** Task 1 — writing Test 3 boundary cases.
- **Issue:** Plan-06's `<behavior>` section described the boundary as "cite at exactly 80 chars from match.end → caught" vs "81 → missed". The implementation's window is `[match.start() - 80, match.end() + 80)` (Python half-open slice), and the substring search looks for the 7-char literal `{{cite:`. For all 7 chars to be present in the slice, the cite must start at `match.end() + 73` or earlier — anything `>= match.end() + 74` leaves the trailing `:` outside the window. The plan's literal numbers ignored the search-string width.
- **Fix:** Test 3a uses `match.end() + 73` (caught — last in-window start); Test 3b uses `match.end() + 74` (missed — first out-of-window start). Test docstrings document the off-by-one with the algebra inline; the regex is used to introspect match positions per plan directive.
- **Files modified:** `services/backend/tests/test_cap_garde.py` (test docstrings) only — implementation is unchanged.
- **Verification:** both boundary tests pass (`7 passed in 0.18s` on targeted run).
- **Committed in:** `bb5af0fc`.

**2. [Rule 3 - Blocking absent] Pre-existing banned-terms lint hit at coach_chat.py:3422 inherited (not introduced)**
- **Found during:** Task 1 verification (`python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py`).
- **Issue:** Lint reports `banned term 'assure': _facts.append(f"- Salaire assure LPP: ...")` at line 3422. The line was at 3369 before my +53-line insertion. Identical pre-existing finding documented in plan-02's SUMMARY (commit `30c6d2b6e`, 2026-04-17). The `assure` is the unaccented past participle of "to insure" used in the technical phrase "Salaire assuré LPP" (LPP-insured salary) — different semantic context from the LSFin sense of « assuré » (« rendement assuré » = guaranteed return), but `banned_terms_python.py` does an accent-insensitive match and cannot distinguish.
- **Fix:** None — out of scope per CLAUDE.md Karpathy #3 (surgical: don't fix adjacent code). The lefthook `banned-terms-python-bundles` and `lsfin_annotation_phase_95` hooks do NOT cover `coach_chat.py` (globs scoped to `services/backend/app/services/coach/bundles/*.py` and `{bootstrap_ci,grounding_pack,sensitivity,pareto}.py` respectively), so the commit passes pre-commit unblocked.
- **Files modified:** none.
- **Verification:** `git stash && python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py` -> same `assure` hit at line 3369 (pre-stash baseline). `git stash pop` restored. Plan-02 SUMMARY documents the identical inheritance.
- **Committed in:** N/A (inherited baseline, not modified).

**3. [Advisory] map-freshness-hint surfaced `docs/coach-tool-routing.md` — no invariant change**
- **Found during:** commit-time lefthook output.
- **Issue:** The pre-commit hook printed an advisory: "If the PR changes any documented invariant (keys, tool routing, calculator wiring), update the doc in the SAME commit." This plan rewires the BODY of the `get_cap_status` dispatcher branch (adds a middleware wrap) but does NOT change the tool key (`get_cap_status` remains the dispatcher name), the dispatcher signature, or the routing semantics. The middleware is invisible to consumers of the tool-routing contract.
- **Fix:** None — no invariant changed. Verified by `grep -c "get_cap_status" docs/coach-tool-routing.md` (if present) ⇒ the doc references the tool name only; no reference to the formatter body or middleware wrap.
- **Files modified:** none.
- **Committed in:** N/A.

---

**Total deviations:** 2 documented (1 plan-spec ambiguity corrected in tests + 1 inherited baseline) + 1 advisory (no action needed).
**Impact on plan:** Zero scope creep. The boundary correction strengthens Test 3 (now sharp at the actual implementation boundary); baseline inheritance is plan-precedent (plan-02 documents identical).

## Issues Encountered

None of substance. The grep-first replan (committed with this work) had already verified `_RE_CURRENCY` location + `__all__` re-export + dispatcher marker locations + flag default, so all implementation references landed on first try. The only mid-execution correction was the boundary-number off-by-seven in Test 3 (deviation #1 above), which was caught during test authoring before any commit.

## User Setup Required

None — pure backend change. Flag `COACH_CAP_CHF_GARDE_ENABLED` defaults to True per plan-00 (unique among Wave 1a flags per D-09); no operator action required to activate the garde.

## Next Phase Readiness

- **plan-07 (parity harness)** — Ready. The middleware is pure string-in / string-out; parity fixtures can assert that cited cap text is preserved byte-identical, while un-cited cap text is rewritten to verbatim `[montant indisponible]`.
- **plan-08 (rollout + 5-gate close)** — Ready. Flag is already TRUE-by-default per D-09, so plan-08's "wire flags" task collapses to a no-op for cap_status (audit-only). The Sentry breadcrumb `coach.cap.cap_chf_uncited` is the re-litigation signal: if >5/day for ≥1 week per D-17, plan-08 (or a follow-up) re-opens the « port CapEngine to Python » question.

## 0-Trust Self-Check Receipts (per CLAUDE.md §9)

**G3 — Targeted test exit 0 with ≥5 tests collected:**
```
$ cd services/backend && python3 -m pytest tests/test_cap_garde.py -q
.......                                                                  [100%]
7 passed in 0.18s
```

**G4 — Full backend regression suite, zero new failures, +7 net new exact:**
```
$ cd services/backend && python3 -m pytest -q
6766 passed, 62 skipped, 1 xfailed, 1 warning in 112.39s (0:01:52)
```
- Plan-02 SUMMARY baseline: `6759 passed`.
- Net new from plan-06: +7 (exact — 7 test functions in `test_cap_garde.py`).
- Pre-existing tests: zero regressions.

**G5a — Accent lint clean on touched files:**
```
$ python3 tools/checks/accent_lint_fr.py --file services/backend/app/api/v1/endpoints/coach_chat.py; echo EXIT=$?
EXIT=0
$ python3 tools/checks/accent_lint_fr.py --file services/backend/tests/test_cap_garde.py; echo EXIT=$?
EXIT=0
```

**G5b — Banned-terms lint on NEW file clean (existing file has inherited baseline):**
```
$ python3 tools/checks/banned_terms_python.py services/backend/tests/test_cap_garde.py; echo EXIT=$?
EXIT=0

$ python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py; echo EXIT=$?
services/backend/app/api/v1/endpoints/coach_chat.py:3422: banned term 'assure':                     _facts.append(f"- Salaire assure LPP: {int(_d['lppInsuredSalary']):,} CHF".replace(",", "'"))
EXIT=1   # pre-existing — see Deviation #2 + plan-02 SUMMARY (identical inheritance at line 3369 before this plan's +53-line insertion)
```

**Acceptance grep counts (14 criteria from PLAN.md):**
```
$ grep -c "def _validate_cap_response" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                # required =1 ✓
$ grep -c "_validate_cap_response" services/backend/app/api/v1/endpoints/coach_chat.py
3                                                # required >=3 ✓ (def + dispatcher call + docstring self-ref)
$ grep -c "COACH_CAP_CHF_GARDE_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py
2                                                # required >=1 ✓ (read inside _validate_cap_response + comment)
$ grep -c "COACH_CAP_CHF_GARDE_ENABLED: bool = True" services/backend/app/core/config.py
1                                                # required =1 ✓ (plan-00 invariant, untouched)
$ grep -c "from app.services.coach.citation_parser import _RE_CURRENCY" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                # required =1 ✓ (inline import inside middleware)
$ grep -Ec '_RE_CURRENCY\s*=\s*re\.compile' services/backend/app/api/v1/endpoints/coach_chat.py
0                                                # required =0 ✓ (anti-fabrication: regex NOT redeclared)
$ grep -cF '[montant indisponible]' services/backend/app/api/v1/endpoints/coach_chat.py
2                                                # required >=1 ✓ (docstring + replacement literal)
$ grep -c "coach.cap.cap_chf_uncited" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                # required >=1 ✓
$ grep -c "# >>> dispatch: get_cap_status" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                # required =1 ✓
$ grep -c "# <<< dispatch: get_cap_status" services/backend/app/api/v1/endpoints/coach_chat.py
1                                                # required =1 ✓
$ grep -Fc 'return _validate_cap_response(_format_cap_status(ctx))' services/backend/app/api/v1/endpoints/coach_chat.py
1                                                # required =1 ✓
```

**Marker integrity (full dispatcher set preserved):**
```
$ grep -c "# >>> dispatch: " services/backend/app/api/v1/endpoints/coach_chat.py
6                                                # 6 dispatchers, unchanged from plan-02 SUMMARY
```

**Evidence claim format (per CLAUDE.md §9.6):**
- **Evidence:** commit `bb5af0fc` (this SUMMARY's parent) shows the 3-file change with the 7-test addition; `pytest -q` returns `6766 passed`; the 11 grep proofs above resolve verbatim against the post-commit working tree; the boundary tests (3a / 3b) use `_RE_CURRENCY.finditer` for position introspection so the off-by-seven correction is self-verifying.
- **Caveat:** plan-06 ships output-filter middleware ONLY. No staged rollout, no CapEngine port, no Flutter side change. End-to-end Maestro G1 + Julien G2 sim walkthrough deferred to plan-08 (5-gate close). PR not opened (this commit lives on `dev` directly per the inline-execute scope of `--plan 06`). Backend regression suite green; Flutter side untouched. The Sentry breadcrumb signal cannot be measured locally (depends on staging traffic) — D-17 re-litigation trigger of >5/day for ≥1 week is a deferred observability check.

## Known Stubs

None. The middleware operates on the FINAL rendered cap text; no placeholder values reach the output (the replacement string `[montant indisponible]` is intentional verbatim FR, not a stub). The `try/except Exception: pass` around `sentry_sdk.add_breadcrumb` is the documented fail-open invariant (telemetry must never break the coach response path), matching the plan-00 `emit_coach_tool_breadcrumb` helper convention.

## Threat Flags

None new. Threat-model dispositions from PLAN.md `<threat_model>` table verified:

- T-WAVE1A-06-01 (legacy passthrough when flag OFF) — Test 5 asserts byte-identity. ✓
- T-WAVE1A-06-02 (LSFin banned-term leak in replacement string) — `[montant indisponible]` is pure ASCII, lint-clean, not in banned vocabulary. ✓
- T-WAVE1A-06-03 (PII in breadcrumb payload) — Test 2 asserts `set(kwargs["data"].keys()) == {"snippet"}` and `len(snippet) <= 120`. ✓
- T-WAVE1A-06-04 (regex drift) — anti-fabrication grep proves `_RE_CURRENCY` is NOT redeclared in `coach_chat.py`. ✓
- T-WAVE1A-06-06 (Sentry SDK raises) — `try/except Exception: pass` wraps the entire breadcrumb emit. ✓
- T-WAVE1A-06-07 (offset bug in multi-token replacement) — Test 6 exercises 3 tokens (2 replaced + 1 preserved) and asserts both the post-image text and the exact breadcrumb call-count. ✓

T-WAVE1A-06-05 (DoS via 1000-token cap text) is `accept`-dispositioned per PLAN.md and remains unmitigated by design (Sentry SDK self-rate-limits; cap text in production is ≤400 chars per CapEngine conventions).
