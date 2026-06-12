---
phase: mint-grounded-coach-m1
plan: 02
type: execute
wave: 1
depends_on: [mint-grounded-coach-m1-01-inversion-fixtures-red]
files_modified:
  - services/backend/app/services/coach/compliance_guard.py
  - services/backend/tests/test_compliance_guard_blocking.py
autonomous: true
requirements: [WS-A]
must_haves:
  truths:
    - "A prescriptive financial instruction is BLOCKED (fallback), no longer log-only"
    - "A single banned-term hit triggers blocking, not the >5 tolerance"
    - "Numeric hallucination detection no longer requires a populated profile to run"
  artifacts:
    - path: "services/backend/app/services/coach/compliance_guard.py"
      provides: "Blocking prescriptive + banned + hallucination layers (education-strict perimeter)"
      contains: "use_fallback"
    - path: "services/backend/tests/test_compliance_guard_blocking.py"
      provides: "Regression tests for the three hardened gates"
  key_links:
    - from: "compliance_guard.py L2 prescriptive"
      to: "use_fallback"
      via: "blocking branch"
      pattern: "use_fallback\\s*=\\s*True"
---

<objective>
Harden ComplianceGuard to match the education-strict perimeter locked by the founder
(CONTEXT decision 1, WS-A). The fallback must no longer tolerate prescriptive output or
multiple banned terms, and the numeric hallucination check must not be silently disabled
for empty profiles. The CODE matches the perimeter, not just the prompt.

Purpose: today (compliance_guard.py:451-461) prescriptive language is "log only", banned
terms only fall back at >5 (:442), and hallucination detection only runs when the profile
has known_values (:494) — leaving onboarding/anonymous users the least protected. This plan
closes WS-A holes HOLE-3 + HOLE-4 from audit 01.
Output: blocking gates + regression tests, backend suite green.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-CONTEXT.md
@.planning/phases/mint-etat-des-lieux-20260612/01-advice-path-audit.md
@./CLAUDE.md
@services/backend/app/services/coach/compliance_guard.py

<interfaces>
Exact anchors in compliance_guard.py (read in context — do NOT re-explore):
- L1 banned-term tolerance: `if len(banned_found) > 5:` at line 442 → tighten so any banned
  term is blocking under the education-strict perimeter (after sanitisation still flags).
- L2 prescriptive: lines 451-461, comment "NEVER fallback on prescriptive language — always
  log only." → flip to blocking (set use_fallback=True + fallback_reasons append) when
  _check_prescriptive returns hits.
- L3 hallucination escape hatch: `if context and context.known_values:` at line 494 → the
  detector is skipped entirely when the profile is empty. Remove the escape hatch so numeric
  claims are checked even with no profile (audit 01 HOLE-3). The detector already no-ops
  gracefully on an empty known_values dict (hallucination_detector.py), so guard against
  None context only.
- validate() returns ComplianceResult(is_compliant, sanitized_text, violations, use_fallback).
  Fallback path returns sanitized_text="" → the endpoint substitutes a templated safe reply.
- PRESCRIPTIVE_PATTERNS list: compliance_guard.py:238-276 (already comprehensive).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Make prescriptive + banned layers blocking (education-strict)</name>
  <files>services/backend/app/services/coach/compliance_guard.py, services/backend/tests/test_compliance_guard_blocking.py</files>
  <behavior>
    - Given "tu devrais racheter ta LPP maintenant" (one prescriptive hit), validate() now
      returns use_fallback=True (was log-only, shipped to user). Per CONTEXT WS-A: the
      ComplianceGuard fallback must not tolerate >0 prescriptive term.
    - Given any single banned term that survives sanitisation, validate() blocks rather than
      tolerating up to 5. (Sanitisation still runs first; if a residual banned term remains
      OR the input carried a prescriptive marker, block.)
    - Given clean conditional French ("tu pourrais envisager un rachat… l'effet dépend de ta
      tranche"), validate() still passes (no false-positive regression — the W1 reply1
      "excellent" standard must survive).
  </behavior>
  <action>In compliance_guard.py L2 (lines 451-461), replace the log-only branch: when prescriptive_found is non-empty, set use_fallback=True and append a structured fallback_reasons entry "prescriptive_blocked". In L1 (line 442) lower the >5 tolerance: keep sanitisation, but set use_fallback=True when banned terms remain after sanitisation or when count>=1 distinct prescriptive-family term is present. Preserve the negated-guarantee whitelist (_NEGATED_GUARANTEE_PATTERNS) and the certain-family context-awareness so in-doctrine phrases ("rien n'est garanti") do NOT trip. Frame all new log lines with neutral design language ("garde prescriptive bloquante"), no forensic/legal phrasing (public-repo discipline). Add a docstring note that this is the education-strict perimeter (CONTEXT decision 1). Write test_compliance_guard_blocking.py covering: prescriptive→fallback, single residual banned→fallback, clean conditional→pass, negated-guarantee→pass.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_compliance_guard_blocking.py -q 2>&1 | tail -15</automated>
  </verify>
  <done>Prescriptive instruction blocks; clean conditional passes; negated-guarantee passes; new tests green.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Remove the empty-profile hallucination escape hatch</name>
  <files>services/backend/app/services/coach/compliance_guard.py, services/backend/tests/test_compliance_guard_blocking.py</files>
  <behavior>
    - Given context=None, validate() still runs without crashing (no detector call).
    - Given a context with an EMPTY known_values dict, a numeric claim that contradicts a
      regulatory constant is now eligible for detection instead of being skipped at line 494.
    - Given a populated profile (existing behaviour), detection is unchanged — no regression
      in the existing L3 tests.
  </behavior>
  <action>In compliance_guard.py line 494, change `if context and context.known_values:` to run the detector whenever context is not None (guard `if context is not None:`), passing context.known_values (which may be empty). Confirm HallucinationDetector.detect tolerates an empty dict (it returns [] today per hallucination_detector.py:183 — that path stays, but the structural skip for empty profiles is removed so future registry-anchored checks can fire). Keep the major/minor thresholds and cumulative limit unchanged. Add tests: context=None no-crash, empty-known_values path reached, populated-profile regression intact.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_compliance_guard_blocking.py tests/coach -q -k "halluc or compliance or guard" 2>&1 | tail -15</automated>
  </verify>
  <done>Escape hatch removed; None-safe; empty-profile path reachable; no L3 regression.</done>
</task>

<task type="auto">
  <name>Task 3: Full backend suite — no regression from hardening</name>
  <files>services/backend</files>
  <action>Run the full backend suite. The hardened blocking gates can break tests that asserted prescriptive output was shipped (log-only). Update ONLY tests that encoded the now-wrong "ships to user" behaviour to assert the new blocking behaviour — do not weaken the new gates to satisfy stale tests, and do not touch unrelated tests (Karpathy #3 surgical). Document any updated test in the SUMMARY with file:line + reason.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -8</automated>
  </verify>
  <done>Full backend suite green; any updated test justified in SUMMARY as encoding the old non-blocking behaviour.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| LLM coach output → user | Generated prescriptive/banned text crosses into a regulated education surface |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-m1-02-01 | Elevation (perimeter breach) | ComplianceGuard L2 prescriptive log-only | mitigate | Flip L2 to blocking fallback; regression test enforces |
| T-m1-02-02 | Information disclosure | ComplianceGuard L3 empty-profile skip | mitigate | Remove escape hatch so anonymous/onboarding users get numeric verification |
| T-m1-02-SC | Tampering | pip installs | accept | No new packages; stdlib + existing pytest only |
</threat_model>

<verification>
- `cd services/backend && python3 -m pytest tests/ -q` exits 0.
- `grep -n "use_fallback = True" services/backend/app/services/coach/compliance_guard.py` shows a new prescriptive-blocking assignment in the L2 block (lines ~451-461 region).
- `grep -n "if context is not None" services/backend/app/services/coach/compliance_guard.py` confirms the escape hatch is gone.
</verification>

<success_criteria>
ComplianceGuard blocks prescriptive output and residual banned terms, runs hallucination
detection without requiring a populated profile, the W1 "excellent reply1" conditional
standard still passes, and the full backend suite is green.
</success_criteria>

<output>
Create `.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-02-SUMMARY.md` when done.
Cite the `pytest tests/ -q` tail (pass count) as the deterministic green citation.
</output>
