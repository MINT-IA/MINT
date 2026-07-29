---
phase: wave-1b-citation-chips
plan: 08
subsystem: observability

tags: [sentry, breadcrumb, telemetry, citation-chip, wave-1b, narrator-gate, fail-open]

# Dependency graph
requires:
  - phase: wave-1b-citation-chips
    plan: 01
    provides: 5 SKIPPED breadcrumb stubs (3 contract + 2 cardinality) — Plan 08 unskips + makes green
  - phase: wave-1b-citation-chips
    plan: 04
    provides: citation_chips list on _run_agent_loop result (toolName/inputsHash/computedAt/rawResponse per Plan 04 audit Route b)
  - phase: wave-1a-backend-tools-refactor
    provides: emit_coach_tool_breadcrumb (5-kwarg D-15) and the coach.tool.<name> Sentry breadcrumb category — Plan 08 mirrors the helper pattern with a different category prefix
provides:
  - emit_coach_citation_breadcrumb helper in services/backend/app/observability/coach_breadcrumbs.py
  - _emit_citation_chip_breadcrumbs closure in coach_chat.py invoked on every gate PASS branch of _run_narrator_with_gate
  - 5 unskipped + passing Plan 01 tests (3 breadcrumb_contract + 2 breadcrumb_cardinality)
  - coach.citation.tool_call_id.<tool_name> Sentry category for Wave 1b telemetry baseline
affects: [wave-1b-09-maestro, wave-1c-cap-engine-relitigation-trigger]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-turn dedupe via seen_tool_names set lives in the WRAPPER, not the helper. Helper emits one breadcrumb per call (mirrors emit_coach_tool_breadcrumb idempotence contract); wrapper caps cardinality to ≤1 breadcrumb per tool short-name per turn even when narrator places the same {{cite:tool_*}} placeholder N times."
    - "PASS-only emission via gated.verdict == GateVerdict.PASS branch guard. FALLBACK / REJECTED narrator outputs have no tool_* placeholders to count by construction; the filter inside the helper is a no-op for those paths (acceptance of T-WAVE1B-08-05)."
    - "Read-only consumption of _RE_CITE_PLACEHOLDER from citation_parser.py with key extraction via prefix/suffix slicing (regex has no capture group). Avoids modifying citation_parser.gate() body (CONTEXT hard constraint #4, Phase 94 byte-identity invariant preserved)."

key-files:
  created:
    - .planning/phases/wave-1b-citation-chips/wave-1b-08-SUMMARY.md
  modified:
    - services/backend/app/observability/coach_breadcrumbs.py
    - services/backend/app/api/v1/endpoints/coach_chat.py
    - services/backend/tests/test_coach_citation/test_breadcrumb_contract.py
    - services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py

key-decisions:
  - "elapsed_ms=0 on the citation breadcrumb. Plan 04 audit pinned the chip schema (toolName/inputsHash/computedAt/rawResponse) WITHOUT a per-chip compute-path timing. The Wave 1a coach.tool.<name> breadcrumb already carries the genuine elapsed_ms for cross-correlation via shared inputs_hash. Adding a synthetic timing on the chip side would be misleading. Future Wave 2 telemetry-tuning may surface elapsed_ms_at_emit_time (gate-to-emit latency) as a separate kwarg."
  - "Helper-level test asserts NON-dedupe (each helper call = one breadcrumb). Dedupe responsibility lives in the wrapper via seen_tool_names set. This split keeps the helper idempotent at the API level (matches emit_coach_tool_breadcrumb) while letting the wrapper enforce per-turn cardinality bound (RESEARCH §8.5 ~1k turns/day × 6 tools = ~6k breadcrumbs/day << 30% staging quota)."
  - "Emission on BOTH PASS paths (initial gate PASS at line 4167-4175 + retry-pass at line 4187-4196). FALLBACK collapse on retry produces a narrator template with no tool_* placeholders; the filter inside the helper makes that branch a no-op. Belt-and-braces — wiring on retry costs zero LOC but covers the rare retry-then-PASS path."
  - "Local lazy import pattern inside _emit_citation_chip_breadcrumbs (`from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb`) mirrors the 5 other emit_coach_tool_breadcrumb sites in coach_chat.py (lines 1069, 2518, 2625, 2751, 2964). Consistency with the existing Wave 1a pattern; no module-level import added."

patterns-established:
  - "Wave 1b citation chip → Sentry telemetry contract: every gate-PASS narrator turn that contains a {{cite:tool_*}} placeholder fires one and only one coach.citation.tool_call_id.<tool_short> breadcrumb per distinct tool short-name. Cross-correlatable to Wave 1a coach.tool.<tool_short> via the shared `inputs_hash` value (SHA-256, irreversible). Downstream consumers (Wave 1c CapEngine re-litigation trigger per CONTEXT D-17) can join the two categories on inputs_hash + profile_id_hashed to measure compute-to-emit latency without further wiring."

requirements-completed: [WAVE1B-03, WAVE1B-07]

# Metrics
duration: 8min
completed: 2026-05-15
---

# Phase wave-1b Plan 08: Sentry Breadcrumb on Citation Emission Summary

**emit_coach_citation_breadcrumb helper sibling of Wave 1a's emit_coach_tool_breadcrumb (same 5-kwarg payload, different category prefix `coach.citation.tool_call_id.<tool>`), wired into _run_narrator_with_gate to fire one breadcrumb per distinct {{cite:tool_*}} placeholder on every gate PASS path; all 5 Plan 01 breadcrumb stubs (3 contract + 2 cardinality) unskipped and GREEN, Phase 94 byte-identity preserved (212/212 in test_citation_gate/).**

## Performance

- **Duration:** ~8 min execution
- **Started:** 2026-05-15T (after Plan 06 close, branch creation feature/wave-1b-08-sentry-breadcrumb from dev at 62dd7679)
- **Completed:** 2026-05-15 (last GREEN commit 3319a62b)
- **Tasks:** 2 (helper + wrapper) — TDD on Task 1 (RED `8534a837` → GREEN `adabeac3`); Task 2 wrapper + cardinality tests in one commit since cardinality tests pass at helper level out of the gate (dedupe lives in wrapper, asserted by integration shape — not unit)
- **Files created:** 1 (this SUMMARY)
- **Files modified:** 4 (helper + wrapper + 2 test files)

## Accomplishments

- New `emit_coach_citation_breadcrumb` helper in `services/backend/app/observability/coach_breadcrumbs.py` mirroring the Wave 1a `emit_coach_tool_breadcrumb` shape (D-15 schema parity: tool_name + inputs_hash + profile_id_hashed + elapsed_ms + flag_state) with the only intentional divergence = category prefix `coach.citation.tool_call_id.<tool_name>` to mark a different lifecycle event (narrator emission, NOT tool compute).
- `_emit_citation_chip_breadcrumbs(gated_text, citation_chips)` closure added INSIDE the coach_chat handler (closes over `_user` for `hash_profile_id`, sibling of the existing `_emit_gate_breadcrumb`). Invoked on both gate-PASS branches of `_run_narrator_with_gate` (initial PASS at line 4167-4175 + retry-PASS at line 4187-4196). Dedupes via `seen_tool_names` set — one breadcrumb per distinct tool short-name per turn even when the narrator places the placeholder N times.
- Plan 01 stubs unskipped + GREEN (5/5):
  - `test_emit_coach_citation_breadcrumb_5_kwarg_payload`: category + 5-kwarg payload.
  - `test_emit_coach_citation_breadcrumb_fails_open_when_sentry_unavailable`: no raise when sentry_sdk is None.
  - `test_emit_coach_citation_breadcrumb_payload_is_non_pii`: extra_tags non-clobber + no email/ahv/canton keys.
  - `test_one_breadcrumb_per_tool_placeholder`: helper-level idempotence (each call = one breadcrumb; wrapper dedupes).
  - `test_non_tool_placeholder_does_not_emit_citation_breadcrumb`: spec placeholder (`{{cite:r3a_plafond_salarie_2026}}`) does not classify as `tool_*`.
- Phase 94 / 94.1 byte-identity preserved: `tests/test_citation_gate/` GREEN at 212/212 — wrapper runs OUTSIDE `citation_parser.gate()` (CONTEXT hard constraint #4) by consuming `gated.gated_text` via `_RE_CITE_PLACEHOLDER` in read-only mode.

## Diff size

```
 services/backend/app/observability/coach_breadcrumbs.py                       | +50
 services/backend/app/api/v1/endpoints/coach_chat.py                           | +133 -0 (wrapper closure + 2 PASS-branch invocations)
 services/backend/tests/test_coach_citation/test_breadcrumb_contract.py        | +22 -8 (unskip 3 + expand test 3 body)
 services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py     | +56 -16 (unskip 2 + implement both)
 ─────────────────────────────────────────────────────────────────────────────
 Total                                                                          | +261 -24 LOC across 4 files
```

## Task Commits

Each task landed atomically on `feature/wave-1b-08-sentry-breadcrumb` (branched from `dev` at `62dd7679`):

1. **Task 1 RED: unskip 3 emit_coach_citation_breadcrumb contract tests** — `8534a837` (test)
2. **Task 1 GREEN: emit_coach_citation_breadcrumb helper (5-kwarg + coach.citation.tool_call_id.*)** — `adabeac3` (feat)
3. **Task 2: wire wrapper to emit citation breadcrumb per tool_* placeholder** — `3319a62b` (feat) — wrapper closure + 2 PASS-branch invocations + 2 unskipped cardinality tests in one commit

## Decisions Made

- **Decision 1 (TDD RED → GREEN split on Task 1)** — Plan 08 has `tdd="true"` on both tasks. Task 1 split into 2 commits (RED `8534a837` ImportError 3/3 fail → GREEN `adabeac3` 3/3 pass). Task 2 combined as one commit because cardinality tests assert helper-level behavior (which exists post-Task-1) + a regex-shape semantic check (spec placeholder ≠ tool placeholder); the wrapper-level dedupe is asserted by the integration shape (loop_result.citation_chips + _RE_CITE_PLACEHOLDER + seen_tool_names) rather than a unit boundary, so a RED/GREEN split would have produced a synthetic failure.
- **Decision 2 (elapsed_ms=0 on citation breadcrumb)** — Plan 04 audit pinned the chip schema (toolName/inputsHash/computedAt/rawResponse) WITHOUT a per-chip compute-path timing. The Wave 1a `coach.tool.<name>` breadcrumb already carries the genuine `elapsed_ms` for cross-correlation via the shared `inputs_hash` value (irreversible SHA-256). Adding a synthetic timing on the chip side would be misleading. Future Wave 2 telemetry-tuning may surface `elapsed_ms_at_emit_time` (gate-to-emit latency) as a separate kwarg.
- **Decision 3 (emission on both PASS paths — initial + retry)** — FALLBACK on retry produces a narrator template with no `tool_*` placeholders; the filter inside the helper makes that branch a no-op. Wiring on retry costs ~3 LOC but covers the rare retry-then-PASS path (narrator's first answer was REJECTED for uncited number, second pass added the citation, gate PASSes on retry).
- **Decision 4 (key extraction via prefix/suffix slicing, not new capture-group regex)** — `_RE_CITE_PLACEHOLDER` at `citation_parser.py:98` has no capture group (regex existed for span-strip semantics in the gate). Adding a sibling regex with a capture group would create a second source of truth for the placeholder pattern. Slicing `raw[len("{{cite:"):-len("}}")]` is 2 cheap string operations per match (matches are bounded by `_RE_CITE_PLACEHOLDER` shape) and reuses the canonical regex.

## Deviations from Plan

None - plan executed exactly as written. Plan 08 anticipated speculative names (`agent_result.tool_calls`, `tc.elapsed_ms`) in Task 2 Step 0 and required reading wave-1b-04-AUDIT.md before code edit. The audit's Route (b) decision shipped a `citation_chips` list on `loop_result` (a dict, NOT objects with `.elapsed_ms`), so the wrapper iterates `loop_result["citation_chips"]` dicts directly with `.get("toolName")` / `.get("inputsHash")` access — the audit-confirmed shape, not the speculative shape. No deviations in helper naming, category prefix, payload shape, or wrapper placement.

**Total deviations:** 0 auto-fixed.

## Issues Encountered

- **PreToolUse READ-BEFORE-EDIT reminder fired** on three files (`test_breadcrumb_contract.py`, `coach_breadcrumbs.py`, `test_breadcrumb_cardinality.py`, `coach_chat.py`) despite each being read at the session start. The Write/Edit tools confirmed each modification succeeded and post-edit verifications (test runs, grep counts) match the expected file shape. Hint is a session-safety reminder, not a block. Logged for future tip: re-read each file once immediately before its FIRST edit when a session contains many parallel edits to keep the reminder quiet.
- **Map-freshness hint on `docs/coach-tool-routing.md`** during the Task 2 commit. The hint fires on any touch to `services/backend/app/api/v1/endpoints/coach_chat.py`. Plan 08 does NOT change tool keys, routing, or calculator wiring — only adds telemetry on the consumer side (citation chip → Sentry). No invariant changed, no doc update needed.

## Known Stubs

None introduced by Plan 08. Plan 08 IS the resolution of Plan 01's 5 breadcrumb stubs (3 contract + 2 cardinality); all 5 now unskipped + GREEN.

The remaining 14 mobile widget stubs in `apps/mobile/test/widgets/coach/coach_citation_*.dart` are NOT Plan-08-scope — they were resolved by Plans 05 (4 widget + 6 golden stubs unskipped) and 06 (4 modal stubs unskipped) per the wave-1b-05 and wave-1b-06 SUMMARYs.

## Threat Flags

No NEW threat surface introduced by Plan 08 beyond what the plan's `<threat_model>` already enumerated. All 6 threats (T-WAVE1B-08-01 PII leak / T-WAVE1B-08-02 gate modification / T-WAVE1B-08-03 cardinality / T-WAVE1B-08-04 helper exception / T-WAVE1B-08-05 PASS-only emission / T-WAVE1B-08-06 speculative field names) are mitigated per the plan's disposition column. Mechanical evidence in the 0-trust self-check below.

## User Setup Required

None. Plan 08 ships pure backend telemetry. The new Sentry breadcrumb category `coach.citation.tool_call_id.*` will only emit AFTER the coupled Wave 1a flag flip + Wave 1b deploy (CONTEXT D-01) lands on Railway staging. Until then, the helper is exercised only via unit tests (5 Plan 01 stubs + the existing `tests/test_citation_gate/` Phase 94 byte-identity suite). No Sentry project setting change needed — the default sample rate (10%) applies; if cardinality x10 vs Wave 1a `coach.tool.*` baseline post-flag-flip, downsample to 1% in a Wave 2 telemetry-tuning PR per RESEARCH §8.5.

## Next Phase Readiness

- **Plan 09 (Maestro G1 flow)** — Maestro flow exercises the end-to-end "tap card → coach response with chip → tap chip → modal opens" path. Plan 08's Sentry breadcrumb fires post-PASS-narrator-emit; Plan 09 can `assert` against the breadcrumb log entries OR rely on the chip rendering in the bubble (Plan 05) as the visible proxy. Plan 08 surfaces the wiring needed for the Wave 1c CapEngine re-litigation trigger (CONTEXT D-17 Wave 1a) — `coach.citation.tool_call_id.cap_status.emitted` becomes the threshold metric.
- **Wave 1b dev → staging coupled deploy** — Per CONTEXT D-01, Wave 1a's 5 server-side flags (`COACH_TOOL_SERVER_SIDE_*=true`) flip on Railway in lock-step with the dev → staging merge of Wave 1b. Plan 08's breadcrumb is part of that ship event; baseline cardinality will be captured in the first 24h post-deploy. Pre-deploy: zero entries (flag OFF on dev/prod; breadcrumb only fires when chips render, which requires flag ON).

## 0-trust Self-Check (CLAUDE.md §9.4 + §9.6)

**Evidence (verbatim citations):**

- **Evidence file 1** — Helper exists with new category: `grep -c "def emit_coach_citation_breadcrumb" services/backend/app/observability/coach_breadcrumbs.py` returns `1`. FOUND.
- **Evidence file 2** — Category prefix in helper body + docstring: `grep -c "coach.citation.tool_call_id" services/backend/app/observability/coach_breadcrumbs.py` returns `2`. FOUND.
- **Evidence file 3** — Wrapper closure name + invocation: `grep -c "_emit_citation_chip_breadcrumbs" services/backend/app/api/v1/endpoints/coach_chat.py` returns `4` (1 def + 1 docstring self-reference + 2 PASS-branch calls). FOUND.
- **Evidence file 4** — Per-turn dedupe mechanism: `grep -c "seen_tool_names" services/backend/app/api/v1/endpoints/coach_chat.py` returns `3` (1 declare + 2 uses: contains-check + add). FOUND.
- **Evidence file 5** — Read-only consumption of citation_parser regex: `grep -c "_RE_CITE_PLACEHOLDER" services/backend/app/api/v1/endpoints/coach_chat.py` returns `3` (1 docstring + 1 import + 1 use). FOUND.
- **Evidence file 6** — Zero `@pytest.mark.skip` left in test_breadcrumb_contract.py: `grep -c "@pytest.mark.skip" services/backend/tests/test_coach_citation/test_breadcrumb_contract.py` returns `0`. FOUND.
- **Evidence file 7** — Zero `@pytest.mark.skip` left in test_breadcrumb_cardinality.py: `grep -c "@pytest.mark.skip" services/backend/tests/test_coach_citation/test_breadcrumb_cardinality.py` returns `0`. FOUND.
- **Evidence command 1** — `cd services/backend && python3 -m pytest tests/test_coach_citation/test_breadcrumb_contract.py -q` → `3 passed in 0.20s`. CITED.
- **Evidence command 2** — `cd services/backend && python3 -m pytest tests/test_coach_citation/test_breadcrumb_contract.py tests/test_coach_citation/test_breadcrumb_cardinality.py -q` → `5 passed in 0.22s`. CITED.
- **Evidence command 3** — `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q` → `212 passed in 0.87s`. Phase 94 / 94.1 byte-identity preserved. CITED.
- **Evidence command 4** — `cd services/backend && python3 -m pytest tests/ -q` → `6898 passed, 62 skipped, 1 xfailed, 1 warning in 111.40s`. Net delta vs Plan 04 reported baseline (6880 passed, 67 skipped) = `+18 passed` (5 directly unskipped here + 13 from Plans 05/06/07 between-baselines) and `-5 skipped` (exact match for the 5 Plan 01 stubs unskipped in this plan). Zero regressions. CITED.
- **Evidence command 5** — `python3 tools/checks/banned_terms_python.py services/backend/app/observability/coach_breadcrumbs.py services/backend/app/api/v1/endpoints/coach_chat.py` exits `0`. CITED.
- **Evidence command 6** — `cd services/backend && python3 -c "from app.observability.coach_breadcrumbs import emit_coach_citation_breadcrumb; print('IMPORT OK')"` → `IMPORT OK`. Smoke test of the new helper. CITED.
- **Evidence command 7** — `git log --oneline dev..HEAD` shows `3319a62b` (Task 2) → `adabeac3` (Task 1 GREEN) → `8534a837` (Task 1 RED) on top of base `62dd7679`. CITED.
- **Caveat** — Plan 08 ships the telemetry wiring. It does NOT prove:
  - The Sentry breadcrumb is actually received by the Sentry project in production with the flag ON (requires the coupled Wave 1a flag flip + Wave 1b dev → staging deploy per CONTEXT D-01).
  - Cardinality stays within the staging quota at real-user volume (RESEARCH §8.5 estimate of ~6k breadcrumbs/day is computed, not measured — first 24h post-deploy is the validation window).
  - End-to-end user flow on iPhone-17-Pro sim. NO MAESTRO RUN. NO `idb` SNAPSHOT (that's Plan 09's G1 gate).
  - PR opened against `dev`, NOT merged. Per CLAUDE.md §9.5 — this is Stage 1 of 4 (PR opened). Do NOT claim « shipped », « ready », « works », « validated », « green » outside the cited mechanical evidence above.

## Self-Check: PASSED

- All 4 modified files FOUND on disk with grep-verified contract content (helper def + category + closure + dedupe set + regex import + zero skips × 2).
- All 3 task commits (`8534a837`, `adabeac3`, `3319a62b`) present in `git log dev..HEAD`.
- 3/3 contract tests GREEN; 2/2 cardinality tests GREEN; 5/5 Plan 01 breadcrumb stubs net-positive (was 5 skipped, now 5 passed); 212/212 Phase 94 byte-identity tests GREEN; full backend pytest 6898 passed (zero regressions vs Plan 04 baseline 6880, +18 net = 5 Plan-08 + 13 Plans-05/06/07).
- LSFin banned-terms lint exits 0 on both modified backend files.
- Wrapper runs OUTSIDE citation_parser.gate() — `_RE_CITE_PLACEHOLDER` consumed read-only via `.finditer` on the gate's PASS output. Phase 94 byte-identity invariant preserved (CONTEXT hard constraint #4).
- Zero Rule 1-4 auto-fix deviations from plan.

---

*Phase: wave-1b-citation-chips*
*Plan: 08*
*Completed: 2026-05-15*
*Branch: feature/wave-1b-08-sentry-breadcrumb (base 62dd7679)*
*Commits: 8534a837 (T1 RED) → adabeac3 (T1 GREEN) → 3319a62b (T2 wrapper + cardinality)*
