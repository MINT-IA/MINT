---
phase: mint-grounded-coach-m1
plan: 07
type: execute
wave: 6
depends_on:
  - mint-grounded-coach-m1-04-concept-registry-claim-checker
  - mint-grounded-coach-m1-05-explain-concept-forced-tool
  - mint-grounded-coach-m1-06-savefact-return-domain-fixes
files_modified:
  - services/backend/app/core/config.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - apps/mobile/lib/services/financial_core/financial_core.dart
  - .github/workflows/coach-eval.yml
  - services/backend/tests/test_facade_resolution.py
autonomous: false
requirements: [WS-C, WS-E]
must_haves:
  truths:
    - "Each of the 3 dark gates is either activated/wired or removed — no flag-OFF dead guard remains"
    - "coach_reasoner is either wired to a production caller or removed — no façade remains"
    - "The inversion fixtures run in CI as a regression gate"
  artifacts:
    - path: ".github/workflows/coach-eval.yml"
      provides: "CI gate running the inversion + claim-checker fixtures"
      contains: "inversions"
    - path: "services/backend/tests/test_facade_resolution.py"
      provides: "Test proving each dark gate / reasoner reached a wired-or-deleted resolution"
  key_links:
    - from: "coach-eval.yml"
      to: "test_coach_claim_inversions"
      via: "CI invocation"
      pattern: "claim_inversions|inversions"
---

<objective>
Resolve the façades (CONTEXT decision 4 / WS-C, NEVER #6) and wire the eval harness into CI
(WS-E). For each of the 3 dark gates (COACH_DUAL_LLM_ENABLED, COACH_BUNDLE_COMPILER_ENABLED,
COACH_CITATION_GATE_ENABLED — config.py:71,80,91) and the unwired coach_reasoner, take a
binding decision: activate/wire it in M1 or remove it. No flag-OFF dead guard and no
unwired reasoner may remain. Then add the inversion fixtures as a CI regression gate so the
rachat class can never regress silently.

Purpose: the audit found ~1500 lines of dark guard code creating false confidence in reviews
(audit 01 C-5) and a flagship reasoner with no caller (HOLE-5). M1 ends the ambiguity. The
education-strict perimeter + claim-checker are now live (Plans 02/04/05), so the citation
gate's role is decidable.
Output: each façade resolved with a documented decision; CI eval gate live.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-CONTEXT.md
@.planning/phases/mint-etat-des-lieux-20260612/01-advice-path-audit.md
@.planning/phases/mint-etat-des-lieux-20260612/04-coach-orchestrator.md
@./CLAUDE.md

<interfaces>
Exact anchors (read in context — do NOT re-explore):
- config.py:71 COACH_DUAL_LLM_ENABLED = False (Phase 91 extractor/narrator split, dark).
- config.py:80 COACH_BUNDLE_COMPILER_ENABLED = False (Phase 93.5 bundle compiler, dark).
- config.py:91 COACH_CITATION_GATE_ENABLED = False (Phase 94 closed-world citation gate, dark).
- coach_chat.py:1517 / :5296-5398 — the flag-OFF live path and the gate branches that only
  run when COACH_CITATION_GATE_ENABLED is ON (runtime_verb_gate :5313, freshness :5344,
  temporal :5373, citation_parser.gate :5398). These are the consumers to either activate or
  remove.
- coach_reasoner.dart — CoachReasonerService is exported only via financial_core.dart barrel;
  no production caller (audit 01 HOLE-5). Decision per CONTEXT decision 4: wire it (give it a
  production caller in the coach surface) OR remove it + its barrel export.

DECISION GUIDANCE (this is a checkpoint:decision — surface the resolution, then execute):
- Citation gate: with the claim-checker + education-strict gates now LIVE, the numeric
  citation gate is the smaller remaining surface. Recommended default: activate it on the
  authenticated narrator stage (flip the flag + keep the byte-identity test for the OFF path
  as a rollback), OR remove the flag + dead branches if activation needs work beyond M1.
  Pick ONE and make it true — do not leave it dark.
- Dual-LLM + bundle compiler: recommended default REMOVE (out of M1 scope to activate;
  carrying them dark violates NEVER #6). Removal = delete flag + dead consumers + their
  dark-only tests, leaving the legacy single-LLM live path (which Plans 02/04/05 hardened).
- Reasoner: recommended default REMOVE the unwired CoachReasonerService + barrel export
  (its education-strict reframe in Plan 03 keeps the file honest if kept, but with no caller
  it is a façade). If a thin production caller is cheap, wire it instead. Pick ONE.
</interfaces>
</context>

<tasks>

<task type="checkpoint:decision" gate="blocking">
  <decision>For each dark gate (dual-LLM, bundle compiler, citation gate) and the unwired coach_reasoner: activate/wire or remove?</decision>
  <context>CONTEXT decision 4 forbids leaving any of these as a flag-OFF façade. The education-strict gates + claim-checker are now live, so the citation gate's marginal value and the reasoner's role are decidable. This decision sets Task 1 and Task 2 scope.</context>
  <options>
    <option id="recommended">
      <name>Citation gate ACTIVATE; dual-LLM + bundle compiler REMOVE; reasoner REMOVE (or thin-wire)</name>
      <pros>Ends all façades; smallest activation surface; keeps the hardened legacy live path; rollback via retained byte-identity test</pros>
      <cons>Removing dual-LLM/bundle deletes prior phase scaffolding (intentional per NEVER #6)</cons>
    </option>
    <option id="activate-all">
      <name>Activate all three gates + wire reasoner</name>
      <pros>Maximum guard coverage live</pros>
      <cons>Dual-LLM + bundle activation likely exceeds M1 context budget; risks regression breadth</cons>
    </option>
    <option id="remove-all">
      <name>Remove all three gates + reasoner</name>
      <pros>Leanest spine; fewest moving parts</pros>
      <cons>Discards the citation gate whose numeric grounding complements the new claim-checker</cons>
    </option>
  </options>
  <resume-signal>Select: recommended, activate-all, remove-all, or specify per-item</resume-signal>
</task>

<task type="auto">
  <name>Task 1: Resolve the 3 dark gates per the decision</name>
  <files>services/backend/app/core/config.py, services/backend/app/api/v1/endpoints/coach_chat.py, services/backend/tests/test_facade_resolution.py</files>
  <action>Execute the decision. For ACTIVATE: flip the flag default + ensure the consumers run on the live path + keep any byte-identity/rollback test. For REMOVE: delete the flag from config.py, delete the dead-only consumer branches in coach_chat.py, and delete the tests that only exercised the dark path — surgically, tracing each deleted line to the decision (Karpathy #3). Write test_facade_resolution.py asserting the post-state: removed flags are absent from Settings; activated flags default-ON with their consumer reachable. Use neutral design language in any comment/log.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_facade_resolution.py tests/ -q 2>&1 | tail -8</automated>
  </verify>
  <done>No dark flag-OFF guard remains; each gate activated or removed; full backend suite green.</done>
</task>

<task type="auto">
  <name>Task 2: Resolve the coach_reasoner façade</name>
  <files>apps/mobile/lib/services/financial_core/financial_core.dart, apps/mobile/lib/services/financial_core/coach_reasoner.dart</files>
  <action>Execute the reasoner decision. REMOVE: delete CoachReasonerService + its barrel export from financial_core.dart + any now-orphan tests (the Plan 03 reframe test moves/deletes with it — note in SUMMARY). WIRE: add the thin production caller and keep the file. Either way, after this task grep must show NO unwired exported reasoner service. Run flutter analyze to confirm no broken imports.</action>
  <verify>
    <automated>cd apps/mobile && flutter analyze 2>&1 | tail -6 && flutter test test/services/financial_core/ 2>&1 | tail -6</automated>
  </verify>
  <done>Reasoner wired-or-removed; no façade; flutter analyze clean; financial_core tests green.</done>
</task>

<task type="auto">
  <name>Task 3: Wire the inversion fixtures into CI</name>
  <files>.github/workflows/coach-eval.yml, services/backend/tests/test_facade_resolution.py</files>
  <action>Add a CI workflow (or extend an existing coach test job) that runs the inversion + claim-checker + concept-registry suites on every backend-touching PR: test_coach_claim_inversions.py, test_claim_checker.py, test_concept_registry.py. The job MUST fail the build on any inversion regression. Path-filter on services/backend so it fires for backend changes (mind the CI path-filter blind-spot lesson — also wire it for coach-prompt + registry files). Document the gate in the workflow.</action>
  <verify>
    <automated>cd services/backend && python3 -c "import yaml,pathlib; w=yaml.safe_load(pathlib.Path('../../.github/workflows/coach-eval.yml').read_text()); print('jobs', list(w.get('jobs',{}).keys()))" && grep -c -E "inversion|claim_checker|concept_registry" /Users/julienbattaglia/Desktop/MINT.nosync/.github/workflows/coach-eval.yml</automated>
  </verify>
  <done>CI workflow runs the inversion regression gate; valid YAML; references the fixtures.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Dark guard code → review confidence | Flag-OFF guards create false confidence that coverage exists |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-m1-07-01 | Repudiation (false confidence) | 3 dark gates + unwired reasoner | mitigate | Activate-or-delete each; test_facade_resolution asserts no dark/unwired remains |
| T-m1-07-02 | Information disclosure (regression) | inversion class re-emerges | mitigate | CI eval gate fails build on any inversion regression |
| T-m1-07-SC | Tampering | pip/pub installs | accept | No new packages; CI uses existing runners |
</threat_model>

<verification>
- `grep -nE "COACH_DUAL_LLM_ENABLED|COACH_BUNDLE_COMPILER_ENABLED|COACH_CITATION_GATE_ENABLED" services/backend/app/core/config.py` reflects the decision (removed lines absent, or activated default flipped).
- `grep -rn "CoachReasonerService" apps/mobile/lib` shows either a production caller or zero references (removed).
- `.github/workflows/coach-eval.yml` exists, is valid YAML, references the inversion fixtures.
- `cd services/backend && python3 -m pytest tests/ -q` exits 0; `cd apps/mobile && flutter analyze` clean.
</verification>

<success_criteria>
Every dark gate and the reasoner reach a binding wired-or-deleted resolution (no façade
remains per NEVER #6), the inversion fixtures run as a CI regression gate, and backend +
mobile suites/analyze are green.
</success_criteria>

<output>
Create `.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-07-SUMMARY.md` when done.
Record the per-item activate/remove decision and its rationale.
</output>
