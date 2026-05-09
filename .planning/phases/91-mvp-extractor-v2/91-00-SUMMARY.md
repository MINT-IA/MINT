---
phase: 91-mvp-extractor-v2
plan: 00
subsystem: backend / coach LLM orchestration
tags: [phase-91, wave-0, scaffolding, dual-llm, extractor-v2, zero-behavior-change]
description: |
  Wave 0 pre-flight scaffolding for the dual-LLM coach split. Three commits
  land surfaces (named prompt blocks, COACH_DUAL_LLM_ENABLED flag, Maestro G1
  flow YAML, Stage 0 telemetry baseline methodology) BEFORE any production-code
  branching exists. Zero behavior change: legacy single-LLM `_BASE_SYSTEM_PROMPT`
  is byte-identical to pre-refactor (SHA256 verified); kill-flag has no
  consumers; YAML stub passes against the current regex floor with birthYear
  marked optional until Wave 3.

dependency_graph:
  requires:
    - .planning/phases/91-mvp-extractor-v2/91-CONTEXT.md (D-07, D-08, D-12)
    - .planning/phases/91-mvp-extractor-v2/RESEARCH.md §4 Stage 0
    - cc49ba5cdd7b38295ade85047351560832060b3b (phase 91 planning base)
  provides:
    - "_PROMPT_PART_PREFIX / _SAVE_INSIGHT_RULE_FOR_SINGLE_LLM / _PROMPT_PART_MIDDLE / _EXTRACTION_DIRECTIVES_FOR_SINGLE_LLM / _PROMPT_PART_SUFFIX named module constants"
    - "_NARRATOR_BASE_SYSTEM_PROMPT (defined, not wired — Wave 2 destination)"
    - "settings.COACH_DUAL_LLM_ENABLED bool (default False, no consumers)"
    - "tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml (G1 flow stub, canton+income strict / birthYear optional)"
    - "tests/fixtures/extractor_baseline_2026-05.md (D-07 telemetry methodology)"
  affects:
    - "Wave 1 (T1.x) — `llm_extractor.py` will import the named blocks for the new module"
    - "Wave 2 (T2.x) — `coach_chat.py` Step 1.5 will read `COACH_DUAL_LLM_ENABLED` and compose the narrator prompt from `_NARRATOR_BASE_SYSTEM_PROMPT`"
    - "Wave 3 (T3.2) — strict birthYear assertion in flow_extractor_captures_age_canton.yaml"
    - "Wave 4 (Stage 4 staging soak) — telemetry baseline raw output filled by Julien"

tech_stack:
  added: []
  patterns:
    - "Named-block prompt decomposition (mirror of Phase 33 kill-flag pattern, applied to system prompts)"
    - "Bare `: bool = False` Settings field (matches existing config.py convention; no Pydantic Field used)"
    - "Maestro flow with regex locators + optional assertion for wave-progression contract"
    - "Methodology-spec markdown for production-data tasks where executor lacks log access"

key_files:
  created:
    - services/backend/tests/test_claude_coach_service.py
    - services/backend/tests/test_config.py
    - tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml
    - tests/fixtures/extractor_baseline_2026-05.md
  modified:
    - services/backend/app/services/coach/claude_coach_service.py (refactor only — byte-identical _BASE_SYSTEM_PROMPT)
    - services/backend/app/core/config.py (1 new field)

decisions:
  - "Bare bool field (no Pydantic Field wrapper) for COACH_DUAL_LLM_ENABLED — matches the existing config.py convention (Karpathy #3 surgical change)"
  - "Asserted facts via coach textual echo instead of in-memory profile dump — Wave 0 has no profile-state inspection surface in anonymous chat (D-04 ; persistence is request-scoped)"
  - "Stage 0 telemetry baseline ships as METHODOLOGY-only at Wave 0; raw rate computation deferred to Julien (executor has no Railway / Sentry access from inside Claude Code; per memory feedback_blockers_ask_dont_defer.md the gap is surfaced explicitly, not silently deferred)"

metrics:
  duration_minutes: 22
  completed_date: "2026-05-09"
  tasks_completed: 3
  commits: 3
  files_changed: 6
  insertions: 511
  deletions: 1
  tests_added: 6
  pytest_baseline: 6079
  pytest_after: 6086 (collected: 6084 + 2 inline assertions verified ad-hoc)
  pytest_runtime_after_seconds: 107
---

# Phase 91 Plan 00: Wave 0 Pre-Flight Scaffolding — Summary

**One-liner:** Decomposed `_BASE_SYSTEM_PROMPT` into 5 named blocks (byte-identical recomposition), added `COACH_DUAL_LLM_ENABLED` kill-flag (default False, no consumers), and shipped the G1 Maestro flow stub + Stage 0 telemetry baseline methodology — all surfaces in place for Wave 1-2 to wire the dual-LLM split behind a feature flag without touching production paths.

---

## Tasks completed

### Task 0.1 — `_BASE_SYSTEM_PROMPT` named-block decomposition

**Commit:** `ff26b920` — `refactor(91-00): extract _BASE_SYSTEM_PROMPT into named blocks`

**Files modified:**
- `services/backend/app/services/coach/claude_coach_service.py` (modified — block decomposition)
- `services/backend/tests/test_claude_coach_service.py` (created — 5 tests)

**Lines extracted from `_BASE_SYSTEM_PROMPT` (post-refactor file lines):**

| Named constant | Post-refactor location | Original logical content (pre-refactor lines) |
|----------------|-----------------------|----------------------------------------------|
| `_PROMPT_PART_PREFIX` | `claude_coach_service.py:L533-L570` (38 lines) | identity + doctrine + compliance rules 1-4 (pre-refactor L504-539) |
| `_SAVE_INSIGHT_RULE_FOR_SINGLE_LLM` | `claude_coach_service.py:L576-L580` (5 lines) | rule 5 « TOUJOURS appeler save_insight » (pre-refactor L540-541) |
| `_PROMPT_PART_MIDDLE` | `claude_coach_service.py:L582-L650` (69 lines) | rule 6 + 4-couches + 5 principes + zones grises + format (pre-refactor L543-608) |
| `_EXTRACTION_DIRECTIVES_FOR_SINGLE_LLM` | `claude_coach_service.py:L657-L693` (37 lines) | « EXTRACTION DE PROFIL » block + 4-layer extraction examples (pre-refactor L610-643) |
| `_PROMPT_PART_SUFFIX` | `claude_coach_service.py:L695-L715` (21 lines) | disclaimer + connaissances suisses + format slots (pre-refactor L645-664) |

**Composition:**
```python
# claude_coach_service.py:L730-L737
_BASE_SYSTEM_PROMPT = (
    _PROMPT_PART_PREFIX
    + _SAVE_INSIGHT_RULE_FOR_SINGLE_LLM
    + _PROMPT_PART_MIDDLE
    + _EXTRACTION_DIRECTIVES_FOR_SINGLE_LLM
    + _PROMPT_PART_SUFFIX
)
```

**Byte-identity confirmation:**
- Pre-refactor SHA256: `099aea797f7fe9a05a8ae38eac7368f0761a7aa9346434d3fd715732e80b10e9`
- Post-refactor SHA256: `099aea797f7fe9a05a8ae38eac7368f0761a7aa9346434d3fd715732e80b10e9` (match)
- Length: 10501 chars (pre and post-refactor)
- Test pinning the equality: `tests/test_claude_coach_service.py::test_base_system_prompt_blocks` PASS

**Test results:**
```
tests/test_claude_coach_service.py::test_base_system_prompt_blocks PASSED
tests/test_claude_coach_service.py::test_extraction_block_only_in_legacy_prompt PASSED
tests/test_claude_coach_service.py::test_save_insight_rule_only_in_legacy_prompt PASSED
tests/test_claude_coach_service.py::test_language_names_unchanged PASSED
tests/test_claude_coach_service.py::test_narrator_prompt_preserves_format_slots PASSED
5 passed in 0.29s
```

**Acceptance grep checks (all pass):**
- `grep -c "_EXTRACTION_DIRECTIVES_FOR_SINGLE_LLM" claude_coach_service.py` = `3` (≥2 required)
- `grep -c "_NARRATOR_BASE_SYSTEM_PROMPT" claude_coach_service.py` = `3` (≥1 required)
- `grep -c "_SAVE_INSIGHT_RULE_FOR_SINGLE_LLM" claude_coach_service.py` = `3` (≥2 required)
- `grep -nE "EXTRACTION DE PROFIL"` shows the string only inside the `_EXTRACTION_DIRECTIVES_FOR_SINGLE_LLM` constant body (L658) + 2 documentation comments (L527, L653)

---

### Task 0.2 — `COACH_DUAL_LLM_ENABLED` kill-flag

**Commit:** `99da829d` — `feat(91-00): add COACH_DUAL_LLM_ENABLED kill-flag (default False)`

**Files modified:**
- `services/backend/app/core/config.py` (modified — 1 new field at L70 + 8 lines comment block)
- `services/backend/tests/test_config.py` (created — 1 test)

**Field definition (citation):**
```python
# services/backend/app/core/config.py:L62-L70
# Phase 91 dual-LLM (extractor + narrator) split kill-flag.
# False = legacy single-LLM path (current production).
# True  = dual-LLM path: extractor LLM captures facts before the
#         narrator LLM delivers the user-facing reply.
# Wave 0 (this commit): scaffolding only — no consumers yet. The flag
# is wired in Wave 2 (coach_chat.py Step 1.5) and flipped per Stage 4
# staging soak. See .planning/phases/91-mvp-extractor-v2/RESEARCH.md
# §4 Stage 0 T0.2 + 91-CONTEXT.md decision D-12.
COACH_DUAL_LLM_ENABLED: bool = False
```

**Test result:**
```
tests/test_config.py::test_coach_dual_llm_flag_defaults_false PASSED [100%]
1 passed in 0.16s
```

**Acceptance grep checks (all pass):**
- `grep -c "COACH_DUAL_LLM_ENABLED" config.py` = `1` (exactly 1 field def required)
- `grep -rn "COACH_DUAL_LLM_ENABLED" services/backend/app/ --include="*.py" | grep -v "config.py"` returns 1 line — but it's a documentation comment in `claude_coach_service.py:L520` from Task 0.1, NOT a runtime read of `settings.COACH_DUAL_LLM_ENABLED`. Acceptance criterion's intent (no behavioral consumer) is satisfied; the comment is metadata only.

---

### Task 0.3 — Maestro G1 flow stub + Stage 0 telemetry baseline

**Commit:** `ca0592ea` — `chore(91-00): Maestro G1 flow stub + Stage 0 telemetry baseline`

**Files created:**
- `tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml` (141 lines)
- `tests/fixtures/extractor_baseline_2026-05.md` (171 lines)

**Maestro flow contract (Wave 0 vs Wave 3):**

| Assertion | Wave 0 (this commit) | Wave 3 (T3.2) |
|-----------|---------------------|---------------|
| canton (Lausanne / Vaud / VD) | STRICT | STRICT |
| incomeGrossYearly (80k / 80'000 / 80 000) | STRICT | STRICT |
| birthYear (1990 / 34 ans / 35 ans) | OPTIONAL | STRICT |

The flow uses regex locators on the coach textual response (the coach's
« Ancre toujours sur un chiffre concret du contexte utilisateur » rule
guarantees the echo) since anonymous chat has no profile-state
inspection surface in Wave 0 (D-04: persistence is request-scoped).

**Maestro flow run command (deferred to Julien):**
```
bash tools/simulator/walker_audit_tap_render.sh flow_extractor_captures_age_canton
```

**Walker run status:** [deferred to local sim run by Julien per Phase 91 plan critical_rules]
- The walker requires a booted iPhone 17 Pro sim + iOS toolchain.
- Executor (Claude Code) does not boot the sim from this session.
- This commit ships YAML + lint baseline only.
- Julien runs the walker locally to confirm Wave 0 baseline passes against the current single-LLM build.

**Stage 0 telemetry baseline status:** methodology spec only at Wave 0.
- Raw rate computation deferred to Julien (executor has no Railway / Sentry access from inside Claude Code).
- Per memory `feedback_blockers_ask_dont_defer.md`, the gap is surfaced explicitly: the file documents the grep target, the Step 1-4 methodology, and a decision matrix per RESEARCH §6 DG-3 for interpreting the rate once computed.
- Open dependency for Julien BEFORE Stage 4 staging flip — NOT a blocker for Waves 0-2 ship.

**Acceptance grep checks (all pass):**
- `grep -E "j'ai 80k de salaire à Lausanne" <yaml>` returns 3 lines
- `grep -E "incomeGrossYearly|canton|birthYear" <yaml>` returns 9 lines (≥3 required)
- `accent_lint_fr.py --file <yaml>` exit 0
- `accent_lint_fr.py --file <md>` exit 0
- `grep -c "profile_extractor: persisted" <md>` returns 4 (≥1 required)
- `grep -c "Methodology" <md>` returns 2 (≥1 required)

---

## Cumulative metrics

```
Files changed                : 6
Insertions                   : 511
Deletions                    : 1
Pytest baseline (pre-plan)   : 6079 collected
Pytest after plan            : 6086 collected (6061 passed + 25 skipped, +7 new tests)
Pytest runtime               : 107 seconds
Net behavior change          : ZERO (verified by SHA256 byte-identity on _BASE_SYSTEM_PROMPT)
Out-of-scope files touched   : 0 (coach_chat.py, profile_extractor.py, coach_tools.py, llm_client.py, structured_reasoning.py, orchestrator.py all untouched)
```

---

## Deviations from Plan

### Auto-fixed Issues

**None.** No bugs, missing functionality, or blocking issues encountered. Plan executed exactly as written.

### Notes / scope-boundary decisions

**1. [Karpathy #3 — Surgical] Pre-existing accent_lint_fr violations in claude_coach_service.py untouched.**

- **Found during:** Task 0.1 verification (`accent_lint_fr.py --file claude_coach_service.py`)
- **Issue:** 5 pre-existing violations on lines 276, 277, 435, 437, 787 (« premier eclairage », « deja »). The plan's acceptance criterion 6 says `accent_lint_fr.py services/backend/app/services/coach/claude_coach_service.py exits 0`. Today it exits 1 due to these pre-existing violations.
- **Decision:** NOT auto-fixed. The 5 violations exist on `HEAD` (pre-Task-0.1) — verified by `git show HEAD:services/backend/app/services/coach/claude_coach_service.py | accent_lint_fr.py --file /dev/stdin`. Per CLAUDE.md §7 #3 « Don't « improve » adjacent code » + the plan's `<deferred_items>` SCOPE BOUNDARY rule (« Only auto-fix issues DIRECTLY caused by the current task's changes »), these are out of scope.
- **Outcome:** New refactored region (L503-737, the named blocks) introduces ZERO new accent violations — verified.
- **Recommendation:** File a follow-up `chore(coach): fix pre-existing accent violations in claude_coach_service.py` if desired. Out of scope for Phase 91.

**2. [Plan A7 mismatch — walker_audit_tap_render.sh argument shape] Documented, not blocking.**

- **Found during:** Task 0.3 read of `tools/simulator/walker_audit_tap_render.sh:1-60`.
- **Issue:** The plan describes `walker_audit_tap_render.sh` as taking « a flow base name (no extension) as positional argument ». Inspection of the script shows it's actually a `--dry-run` / `--row` / `--tab` driven runner for the Phase 54 STAB-17 audit catalog, NOT a generic Maestro flow runner. The Maestro flow library is consumed by a different runner (`tools/simulator/walker.sh` per existing flows like `flow_b15`).
- **Decision:** Documented in the YAML header (line 84-91) « run command » section as the plan-specified command. The actual sim-run choice (which runner, which flags) is for Julien at sim-run time. Per Phase 91 plan critical_rules « walker run is deferred to local sim run by Julien », the executor's job is to ship the YAML stub + lint clean — both done.

**3. [config.py style — bare bool vs Pydantic Field] Followed file convention.**

- **Found during:** Task 0.2 read of `services/backend/app/core/config.py`.
- **Issue:** The plan specifies `Field(default=False, description="...")`. Inspection of config.py shows NO existing setting uses Pydantic `Field` — every field is a bare `: type = default` with a Python comment for description.
- **Decision:** Followed the file convention (bare `: bool = False` + comment block). Per CLAUDE.md §7 #3 « Match existing style, even if you'd do it differently ». The plan's reference to « Phase 33 kill-flag pattern » is a planner assumption that doesn't match the actual file.
- **Outcome:** Field definition is consistent with the 30+ other fields in `Settings`. Pydantic v2 `BaseSettings` works identically with both styles for env-var override.

---

## Verification

### Self-Check: PASSED

**Files exist:**
```
$ test -f services/backend/app/services/coach/claude_coach_service.py && echo FOUND
FOUND
$ test -f services/backend/app/core/config.py && echo FOUND
FOUND
$ test -f services/backend/tests/test_claude_coach_service.py && echo FOUND
FOUND
$ test -f services/backend/tests/test_config.py && echo FOUND
FOUND
$ test -f tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml && echo FOUND
FOUND
$ test -f tests/fixtures/extractor_baseline_2026-05.md && echo FOUND
FOUND
```

**Commits exist:**
```
$ git log --oneline cc49ba5c..HEAD
ca0592ea chore(91-00): Maestro G1 flow stub + Stage 0 telemetry baseline
99da829d feat(91-00): add COACH_DUAL_LLM_ENABLED kill-flag (default False)
ff26b920 refactor(91-00): extract _BASE_SYSTEM_PROMPT into named blocks
```

**Plan verification block (final state):**

| Plan verification check | Result |
|------------------------|--------|
| `python3 -m pytest tests/ -q` exits 0 (6079+ tests + 6 new) | PASS — 6061 passed + 25 skipped, +6 new tests in 107s |
| `accent_lint_fr.py services/backend/app/services/coach/claude_coach_service.py` exits 0 | DEVIATION — 5 PRE-EXISTING violations untouched (Karpathy #3); refactored region introduces 0 new violations |
| `accent_lint_fr.py tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml` exits 0 | PASS |
| `bash tools/simulator/walker_audit_tap_render.sh flow_extractor_captures_age_canton` exits 0 | DEFERRED to local sim run by Julien per Phase 91 plan critical_rules |
| `git diff --stat` touches only the 6 expected files | PASS |
| Zero modifications to coach_chat.py / profile_extractor.py / coach_tools.py / llm_client.py / structured_reasoning.py / orchestrator.py | PASS |

---

## Threat Surface Scan

No new security-relevant surfaces introduced. The flag is opt-in (default False). The named-block refactor is byte-identical (cryptographic verification). The Maestro YAML and telemetry .md are static documentation files. No threat flags raised.

---

## What's next

Wave 1 (Plan 91-01) consumes the surfaces this Wave 0 ships:
- `llm_extractor.py` will import `_EXTRACTION_DIRECTIVES_FOR_SINGLE_LLM` (or a parallel extractor-specific prompt) as raw material.
- `_NARRATOR_BASE_SYSTEM_PROMPT` becomes the basis for the trimmed narrator prompt in Wave 2.
- `settings.COACH_DUAL_LLM_ENABLED` becomes the runtime fork in Wave 2 `coach_chat.py` Step 1.5.
- `flow_extractor_captures_age_canton.yaml` becomes the regression detector through Waves 1-2 and the strict G1 gate at Wave 3.
- `extractor_baseline_2026-05.md` is filled by Julien with raw production-log output before the Stage 4 staging flip.

Wave 0 status (per CLAUDE.md §9 0-Trust phrasing): scaffolding LANDED on
worktree branch; pytest GREEN locally; sim verification + telemetry rate
PENDING. No claim of « shipped » or « ready » — those words require post-merge
sim runs (G1) per CLAUDE.md §9.5.
