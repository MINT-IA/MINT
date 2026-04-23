# Phase 30.7 Integrity Audit — 2026-04-23

Auditor: Claude Opus 4.7 (1M context), read-only audit
Branch: `feature/S30.7-tools-deterministes`
Commits audited: `6f8d0882` → `edf468b6` (22 commits)

## Summary

| Check | Status | Evidence |
|-------|--------|----------|
| MCP server exists | PASS | `tools/mcp/mint-tools/server.py` (98 LOC added in `0a8ad4fa`) |
| `.mcp.json` registered | PASS | repo-root `.mcp.json` declares `mint-tools` with `PYTHONPATH` |
| 4 tools import | 4/4 | one module name mismatch vs prompt (see Finding A) |
| 4 tools work on real input | 4/4 | all produce well-formed Pydantic results, semantics correct |
| MCP subproject pytest | 78/78 (in venv) — or 74/78 (system python3.9) | see Finding B |
| CLAUDE.md −30% trim | −33.9% (121 → 80 lines) | commit `43a38dff`, 26 insertions / 67 deletions |
| 5 top rules preserved | 5/5 | banned terms, accents, retirement framing, financial_core, i18n all present TOP and BOTTOM |
| 30.7 planning files tracked | 10/15 | 5 `-PLAN.md` files untracked (Finding C) |
| FastMCP server startup smoke | PASS | `python server.py` (in venv) exits 0 on stdin close, no stdout noise |
| MCP tools stanza added | PASS | CLAUDE.md §3 names all 4 tools with signatures |

## Deep findings

### Tools end-to-end (all 4 semantically correct)

1. `get_swiss_constants('pillar3a')` → `ConstantsResult(version='30.7.0', category='pillar3a', jurisdiction='CH', constants=[14 ConstantEntry rows])` with OPP3 art. 7 sources, historical limits 2016-2026, `max_with_lpp=7258.0 CHF`, `max_without_lpp=36288.0 CHF`, `income_rate_without_lpp=0.2`. Sources cited, years dated. Single-source-of-truth pattern respected (`services/backend/app/services/regulatory/registry.py`).

2. `check_banned_terms('Mon rendement garanti et optimal est certain')` → `BannedTermsResult(version='30.7.0', clean=False, banned_found=[3 hits: garanti, optimal, certain], sanitized_text='Mon rendement possible dans ce scénario et adapté est probable', text_length=44)`. LSFin layer 1 scan works; sanitization produces LSFin-compliant replacements.

3. `validate_arb_parity()` → `ArbParityResult(version='30.7.0', status='ok', exit_code=0, stdout='[arb_parity] OK - 6 ARB files parity OK (non-@ keys=6707, placeholder-bearing @keys checked=568)', script_expected_at='.../tools/checks/arb_parity.py')`. Delegates to real shell script, returns full exit + stdout. Docstring correctly warns about pre-Phase-34 `lint_not_available` fallback.

4. `check_accent_patterns('eclairage et securite pour tous')` → `AccentResult(version='30.7.0', clean=False, violations=[2 hits: \beclairage\b → éclairage, \bsecurite\b → sécurité], text_length=31)`. 14-pattern regex scan intact.

### Finding A — prompt module-name mismatch (non-blocker)

The prompt assumed `from tools.accent_patterns import ...` but the real module is `tools.accent` (matching the MCP tool name `check_accent_patterns`). `server.py` correctly imports from `tools.accent`, and the 4 imports `constants` / `banned_terms` / `arb_parity` / `accent` are consistent. This is a prompt-wording issue only, not a shipped-code issue.

### Finding B — Python version split in pytest

Running `python3 -m pytest` under the default shell (`python3.9.6`) yields:
- 74 passed, 2 skipped, 2 FAILED
- failures: `test_python_at_least_310` (asserts Python ≥3.10) and `test_server_module_imports_cleanly` (MCP SDK not installed on 3.9)

Running inside the project venv `tools/mcp/mint-tools/.venv/` (Python 3.11.9) yields **78 passed, 0 skipped, 0 failed** in 3.21s. The `.mcp.json` correctly pins `"command": "python3.11"`, so the shipped behavior is correct. The 3.9 failures are purely a developer-machine artifact; CI / Claude Code must invoke via the `.mcp.json` contract. Not a ship blocker, but the 2 tests that fail under 3.9 are the exact tests that are supposed to fail on wrong interpreter — they are guardrails firing correctly.

### Finding C — 5 untracked `30.7-0X-PLAN.md` at canonical path

```
?? .planning/phases/30.7-tools-d-terministes/30.7-00-PLAN.md
?? .planning/phases/30.7-tools-d-terministes/30.7-01-PLAN.md
?? .planning/phases/30.7-tools-d-terministes/30.7-02-PLAN.md
?? .planning/phases/30.7-tools-d-terministes/30.7-03-PLAN.md
?? .planning/phases/30.7-tools-d-terministes/30.7-04-PLAN.md
```

`git ls-files` shows 10 tracked files in that directory (`30.7-CONTEXT.md`, `30.7-RESEARCH.md`, `30.7-VALIDATION.md`, `30.7-VERIFICATION.md`, `30.7-HUMAN-UAT.md`, and the 5 `-SUMMARY.md`). The 5 `-PLAN.md` files that drove execution are untracked. These may be intentionally gitignored (common for `.planning/` wave plans) — worth confirming against project convention, but does not affect shipped code quality. **Not a blocker**; if convention is to track plans, a follow-up add is trivial.

### Finding D — CLAUDE.md trim integrity (PASS)

- Baseline at commit `43a38dff~1` (before trim): **121 lines**
- After trim commit `43a38dff`: **80 lines**
- Current `HEAD`: **80 lines**
- Reduction: **41 lines removed = −33.9%** (claim was "−30%", actual is slightly better)
- Commit diff: `26 insertions(+), 67 deletions(-)`

All 5 critical rules verified present at both TOP (§TOP, lines 7-11) and BOTTOM (§BOTTOM, lines 76-80) of the new CLAUDE.md, matching the Liu 2024 lost-in-the-middle mitigation doctrine cited in the file itself:

| Rule | TOP line | BOTTOM line |
|------|----------|-------------|
| Banned terms (LSFin) | 7 | 76 |
| Accents 100% FR | 8 (implicit; still in top 5 block) | 77 |
| MINT ≠ retirement app | 9 | 78 |
| Financial_core reuse | 10 | 79 |
| i18n required | 11 | 80 |

New §3 MCP TOOLS stanza (line 26-28) correctly advertises the 4 tools with signatures: `get_swiss_constants(category)`, `check_banned_terms(text)`, `validate_arb_parity()`, `check_accent_patterns(text)`. This is the on-demand context-migration claim delivered.

### Finding E — SUMMARY files match reality

All 5 `30.7-{00..04}-SUMMARY.md` are tracked and present. Phase closing commit `edf468b6` explicitly labels "11/12 auto pass, J0 smoke deferred by plan design" which is consistent with the `30.7-HUMAN-UAT.md` deferral commit `97c31822`. No SUMMARY-vs-reality drift detected.

### P0/P1 issues found

**None.** All 4 MCP tools run cleanly, produce correct Pydantic results, delegate to the expected single-source-of-truth backends, and CLAUDE.md trim preserves the 5 critical rules with proper TOP/BOTTOM duplication.

## Shipping green-light

**Safe to ship 30.7 as its own PR.** Recommended PR gate:

1. Merge gate: run `pytest` via the `.venv/bin/python` or CI python 3.11 runner (NOT system python3.9). The 2 failures under 3.9 are guardrail tests firing on wrong interpreter — they are correct.
2. Cosmetic follow-up (non-blocker): decide whether to `git add` the 5 `30.7-0X-PLAN.md` files or confirm they are intentionally ignored under the `.planning/` convention.
3. Confirm `.mcp.json` is reachable from the repo root in CI and that `python3.11` is on `$PATH` for the agent runtime.

No code changes required. Phase 30.7 ships as described.

## Artifacts referenced

- `/Users/julienbattaglia/Desktop/MINT/.mcp.json`
- `/Users/julienbattaglia/Desktop/MINT/tools/mcp/mint-tools/server.py`
- `/Users/julienbattaglia/Desktop/MINT/tools/mcp/mint-tools/tools/{constants,banned_terms,arb_parity,accent}.py`
- `/Users/julienbattaglia/Desktop/MINT/tools/mcp/mint-tools/tests/` (78 tests, all pass in venv)
- `/Users/julienbattaglia/Desktop/MINT/CLAUDE.md` (80 lines, down from 121)
- `/Users/julienbattaglia/Desktop/MINT/.planning/phases/30.7-tools-d-terministes/30.7-{00..04}-SUMMARY.md`
- Commit `43a38dff` (CLAUDE.md trim), `0a8ad4fa` (server.py), `d11011c6` (.mcp.json), `edf468b6` (phase close)
