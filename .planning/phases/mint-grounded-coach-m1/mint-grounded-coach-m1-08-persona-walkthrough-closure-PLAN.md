---
phase: mint-grounded-coach-m1
plan: 08
type: execute
wave: 7
depends_on:
  - mint-grounded-coach-m1-03-perimeter-coherence-reframe
  - mint-grounded-coach-m1-07-activate-or-delete-facades-ci
files_modified:
  - .planning/phases/mint-grounded-coach-m1/W1-cadre-50-rerun.md
  - .planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-VERIFICATION-REPORT.html
autonomous: false
requirements: [WS-A, WS-B, WS-C, WS-D, WS-E]
must_haves:
  truths:
    - "A persona walkthrough re-run on sim shows zero P1 on the coach surfaces"
    - "The rachat definition is now correct in the live coach flow on the device"
    - "Backend + mobile suites + inversion fixtures are green at closure time"
  artifacts:
    - path: ".planning/phases/mint-grounded-coach-m1/W1-cadre-50-rerun.md"
      provides: "Device-evidence walkthrough re-run (Marc cadre 50 persona) with WTF log"
      min_lines: 40
    - path: ".planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-VERIFICATION-REPORT.html"
      provides: "Cumulative phase evidence report"
  key_links:
    - from: "W1-cadre-50-rerun.md"
      to: "WTF-W1-01 rachat fix"
      via: "device re-test of the inversion"
      pattern: "rachat"
---

<objective>
Run the milestone closure gate (CONTEXT decision 5): a real-persona walkthrough on sim in
the W1-cadre-50 style, proving the coach surfaces have zero P1 — specifically that the rachat
definition is now correct in the live flow — with green suites and green inversion fixtures.
This is the permanent persona-walkthrough gate of the milestone.

Purpose: tests green ≠ feature working (CLAUDE.md §9). The rachat inversion was found by a
device walkthrough, not a unit test; closure must be re-proven on the device. This plan
produces the deterministic device evidence and the cumulative report.
Output: W1-rerun walkthrough + VERIFICATION report; founder sign-off optional, not blocking.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-CONTEXT.md
@.planning/phases/mint-sense-making/walkthroughs/W1-cadre-50.md
@./CLAUDE.md

<interfaces>
Device-gate facts (read in context — do NOT re-explore):
- W1-cadre-50.md is the reference walkthrough format: persona Marc 50 ans cadre Lausanne,
  fresh-install, idb + Maestro conduite, app targets Railway staging (per memory
  feedback_app_targets_staging_always — never local backend for E2E).
- Maestro is the sim-test harness (memory feedback_maestro_for_sim_tests): use
  tools/simulator/flows + walker scripts; raw simctl screenshot is an anti-pattern. Existing
  flow tools/simulator/flows/auth_coach_post_hotfix.yaml + walker_persona.sh are the base.
- The Exhibit-A re-test: ask the coach "c'est quoi un rachat" and assert the reply defines
  rachat as a VERSEMENT (paying in / deductible), not a retrait. This is WTF-W1-01 closed.
- 0-TRUST citation discipline (CLAUDE.md §9): no "works"/"ready" without an idb describe-all
  snapshot or a Maestro junit pass cited in the same artifact. Sim run by Claude; founder
  sign-off is optional per memory feedback_merge_and_device_gates_autonomous.
- HTML evidence report is mandatory per phase (memory feedback_html_evidence_report) — never
  /tmp; lives under .planning/phases/<phase>/.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Pre-gate — all suites + inversion fixtures green</name>
  <files>services/backend, apps/mobile</files>
  <action>Before the device run, confirm the deterministic gates are green: full backend suite, the inversion + claim-checker + concept-registry suites, flutter analyze + flutter test (coach + financial_core scope), and the mechanical lints (accent_lint_fr, banned-terms, validate_arb_parity if strings changed across the phase). Record exit codes. If anything is red, STOP and report — do not proceed to the device gate on a red base.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -4 && python3 -m pytest tests/test_coach_claim_inversions.py tests/test_claim_checker.py tests/test_concept_registry.py -q 2>&1 | tail -4 && cd /Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile && flutter analyze 2>&1 | tail -3</automated>
  </verify>
  <done>Backend suite + inversion fixtures + flutter analyze all green; exit codes recorded.</done>
</task>

<task type="auto">
  <name>Task 2: Persona walkthrough re-run on sim (Maestro/idb), coach surfaces</name>
  <files>.planning/phases/mint-grounded-coach-m1/W1-cadre-50-rerun.md</files>
  <action>Run a fresh-install persona walkthrough on sim (Marc cadre 50 style) against Railway staging, focused on the coach surfaces touched in M1: chat definition flow ("c'est quoi un rachat" → must define as versement), prescriptive-guard behaviour (a prescriptive prompt must NOT ship a prescriptive answer), and the save_fact echo (state "j'ai 50 ans" → confirm the local profile reflects it). Use Maestro flows + idb describe-all for evidence (per memory). Write W1-cadre-50-rerun.md mirroring the W1 format: timeline, WTF log (one finding per line, P-rated), and an explicit re-test of WTF-W1-01/03/04. Cite idb/Maestro output in the artifact (0-TRUST). Tag any residual finding with severity; the gate requires zero P1 on coach surfaces.</action>
  <verify>
    <human-check>Persona walkthrough re-run completed on sim; W1-cadre-50-rerun.md shows the rachat reply defines a versement (WTF-W1-01 closed), no prescriptive answer shipped, save_fact echo reflected in the profile, and zero P1 on coach surfaces. idb/Maestro evidence cited in the artifact.</human-check>
  </verify>
  <done>Walkthrough artifact exists (≥40 lines) with the rachat fix proven on device and zero P1 on coach surfaces.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>The M1 grounded-coach milestone: education-strict blocking gates, the concept registry + claim-checker (rachat inversion blocked), forced explain_concept retrieval, registry-gated fact cards, save_fact echo to mobile, AVS women age fix, façades resolved, CI eval gate, and the device walkthrough re-run.</what-built>
  <how-to-verify>
    1. Open W1-cadre-50-rerun.md and confirm the coach now defines "rachat" as a versement (WTF-W1-01 closed), with idb/Maestro evidence cited.
    2. Confirm zero P1 on coach surfaces in the WTF log.
    3. Open mint-grounded-coach-m1-VERIFICATION-REPORT.html and confirm suite counts + inversion-fixture GREEN + per-plan PRs/verdicts.
    4. Optionally re-run the coach on your own sim to spot-check the rachat reply.
  </how-to-verify>
  <resume-signal>Type "approved" to close M1, or describe residual coach-surface issues to feed a gap-closure plan.</resume-signal>
</task>

<task type="auto">
  <name>Task 3: Cumulative VERIFICATION report</name>
  <files>.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-VERIFICATION-REPORT.html</files>
  <action>Produce/refresh the cumulative HTML evidence report (per memory feedback_html_evidence_report): per-plan summary, suite counts (backend pass total, mobile), inversion-fixture RED→GREEN lineage (Plan 01 xfail → Plan 04 hard pass), the façade resolution decisions (Plan 07), the device walkthrough verdict, and any deferred items. Neutral design language throughout (public-repo discipline). Link the W1-rerun artifact.</action>
  <verify>
    <automated>test -f .planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-VERIFICATION-REPORT.html && grep -c -E "rachat|inversion|walkthrough" .planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-VERIFICATION-REPORT.html</automated>
  </verify>
  <done>HTML report exists with suite counts, RED→GREEN lineage, façade decisions, and the device verdict.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Green suites → "milestone done" claim | Unit-green is not device-working (CLAUDE.md §9) |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-m1-08-01 | Repudiation (false "done") | claiming closure without device proof | mitigate | Persona walkthrough on sim with cited idb/Maestro evidence; founder sign-off optional |
| T-m1-08-SC | Tampering | pip/pub installs | accept | No new packages; existing sim/test tooling only |
</threat_model>

<verification>
- `.planning/phases/mint-grounded-coach-m1/W1-cadre-50-rerun.md` exists, shows the rachat reply as a versement, zero P1 on coach surfaces, idb/Maestro evidence cited.
- `cd services/backend && python3 -m pytest tests/ -q` exits 0 and the inversion fixtures pass.
- `cd apps/mobile && flutter analyze` clean.
- The VERIFICATION-REPORT.html exists with the RED→GREEN lineage and device verdict.
</verification>

<success_criteria>
The milestone closure gate passes: a persona walkthrough on sim shows the rachat definition
correct and zero P1 on coach surfaces, all suites + inversion fixtures are green, the
cumulative evidence report is produced, and (optionally) the founder approves.
</success_criteria>

<output>
Create `.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-08-SUMMARY.md` when done.
Cite the device-evidence line (idb describe-all / Maestro junit) proving the rachat fix as the closure citation.
</output>
