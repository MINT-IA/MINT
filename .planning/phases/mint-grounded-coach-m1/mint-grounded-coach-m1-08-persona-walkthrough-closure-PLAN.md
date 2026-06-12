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
    - "On the AUTHENTICATED Coach surface, rachat is defined as a versement; on the anonymous surface, no inversion ships"
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
      via: "device re-test of the inversion (per surface)"
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
- STAGING-DEPLOY PRECONDITION (plan-check blocker fix): before ANY walkthrough step, the
  staging backend MUST run the M1 backend HEAD. Evidence required IN THE ARTIFACT: the
  Railway deploy SHA (matching the merged M1 head commit) + a staging health-check 200
  (mint-staging.up.railway.app). If staging lags the M1 head, STOP and promote first —
  walking through against a pre-M1 backend proves nothing about the M1 gates.
- BUILD WITHOUT SEED PIN (plan-check blocker fix): the walkthrough build MUST be compiled
  WITHOUT the `--dart-define=MINT_E2E_ARCHETYPE=…` seed pin (no E2E-seeded CoachProfile).
  The save_fact echo verification ("j'ai 50 ans" → profile reflects it) is only FALSIFIABLE
  on a non-seeded profile — a seed-pinned build pre-fills the profile and masks the echo
  (the W1 caveat-0 lesson). Cite the build invocation in the artifact.
- Maestro is the sim-test harness (memory feedback_maestro_for_sim_tests): use
  tools/simulator/flows + walker scripts; raw simctl screenshot is an anti-pattern. Existing
  flow tools/simulator/flows/auth_coach_post_hotfix.yaml + walker_persona.sh are the base.
- The Exhibit-A re-test is SPLIT BY SURFACE (plan-check blocker fix):
  (a) AUTHENTICATED Coach surface: ask "c'est quoi un rachat" and assert the reply defines
      rachat as a VERSEMENT (paying in / deductible) — explain_concept forcing (Plan 05) is
      authenticated-only, so the grounded definition is asserted HERE. This is WTF-W1-01 closed.
  (b) ANONYMOUS surface ("Parle à Mint"): assert NO INVERSION ships — a correct definition
      OR the templated fallback are BOTH acceptable outcomes. Rationale: `rachat` is not in
      the anonymous _FINANCE_KW keyword set and explain_concept forcing is not wired on the
      anonymous path; the claim-checker (Plan 04) still blocks an inversion there, so the
      acceptable states are "correct" or "guarded fallback", never "inverted".
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
  <action>STAGING-DEPLOY PRECONDITION first (blocking): verify the staging backend runs the M1 backend HEAD — cite the Railway deploy SHA (matching the merged M1 head) and a staging health-check 200 in the artifact BEFORE any walkthrough step; if staging lags, stop and promote first. Build the app WITHOUT the MINT_E2E_ARCHETYPE seed pin (non-seeded profile — cite the build invocation) so the save_fact echo check is falsifiable. Then run a fresh-install persona walkthrough on sim (Marc cadre 50 style) against Railway staging, focused on the coach surfaces touched in M1, with the rachat assertion SPLIT BY SURFACE: (a) AUTHENTICATED Coach surface — "c'est quoi un rachat" must define rachat as a VERSEMENT (explain_concept forcing is authenticated-only); (b) ANONYMOUS surface — assert no inversion ships (correct definition OR templated fallback both acceptable, since `rachat` is not in anonymous _FINANCE_KW). Also test: prescriptive-guard behaviour (a prescriptive prompt must NOT ship a prescriptive answer) and the save_fact echo (state "j'ai 50 ans" on the authenticated surface → confirm the local profile reflects it). Use Maestro flows + idb describe-all for evidence (per memory). Write W1-cadre-50-rerun.md mirroring the W1 format: deploy-SHA + health-check + build-invocation preamble, timeline, WTF log (one finding per line, P-rated), and an explicit per-surface re-test of WTF-W1-01 plus WTF-W1-03/04. Cite idb/Maestro output in the artifact (0-TRUST). Tag any residual finding with severity; the gate requires zero P1 on coach surfaces.</action>
  <verify>
    <human-check>Persona walkthrough re-run completed on sim against an M1-HEAD staging deploy (SHA + health 200 cited) on a non-seeded build (invocation cited); W1-cadre-50-rerun.md shows the AUTHENTICATED rachat reply defines a versement (WTF-W1-01 closed) and the anonymous surface ships no inversion (correct or fallback), no prescriptive answer shipped, save_fact echo reflected in the profile, and zero P1 on coach surfaces. idb/Maestro evidence cited in the artifact.</human-check>
  </verify>
  <done>Walkthrough artifact exists (≥40 lines) with deploy-SHA + health + build preamble, the per-surface rachat results proven on device, and zero P1 on coach surfaces.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>The M1 grounded-coach milestone: education-strict blocking gates, the concept registry + claim-checker (rachat inversion blocked), forced explain_concept retrieval, registry-gated fact cards, save_fact echo to mobile, AVS women age fix, façades resolved, CI eval gate, and the device walkthrough re-run.</what-built>
  <how-to-verify>
    1. Open W1-cadre-50-rerun.md and confirm the preamble cites the Railway deploy SHA (M1 head) + staging health 200 + a build invocation WITHOUT the MINT_E2E_ARCHETYPE seed pin.
    2. Confirm the per-surface rachat results: AUTHENTICATED Coach defines "rachat" as a versement (WTF-W1-01 closed); anonymous surface shows no inversion (correct definition or templated fallback), with idb/Maestro evidence cited.
    3. Confirm zero P1 on coach surfaces in the WTF log.
    4. Open mint-grounded-coach-m1-VERIFICATION-REPORT.html and confirm suite counts + inversion-fixture GREEN + per-plan PRs/verdicts.
    5. Optionally re-run the coach on your own sim to spot-check the rachat reply.
  </how-to-verify>
  <resume-signal>Type "approved" to close M1, or describe residual coach-surface issues to feed a gap-closure plan.</resume-signal>
</task>

<task type="auto">
  <name>Task 3: Cumulative VERIFICATION report</name>
  <files>.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-VERIFICATION-REPORT.html</files>
  <action>Produce/refresh the cumulative HTML evidence report (per memory feedback_html_evidence_report): per-plan summary, suite counts (backend pass total, mobile), inversion-fixture RED→GREEN lineage (Plan 01 xfail → Plan 04 hard pass), the façade resolution decisions (Plan 07), the device walkthrough verdict with the staging deploy SHA + non-seeded build citation, and any deferred items. Neutral design language throughout (public-repo discipline). Link the W1-rerun artifact.</action>
  <verify>
    <automated>test -f .planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-VERIFICATION-REPORT.html && grep -c -E "rachat|inversion|walkthrough" .planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-VERIFICATION-REPORT.html</automated>
  </verify>
  <done>HTML report exists with suite counts, RED→GREEN lineage, façade decisions, and the device verdict (deploy SHA + build citation included).</done>
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
| T-m1-08-02 | Spoofing (stale target) | walkthrough against a pre-M1 staging deploy | mitigate | Staging-deploy precondition: Railway SHA = M1 head + health 200 cited before Task 2 |
| T-m1-08-03 | Repudiation (masked evidence) | E2E seed pin pre-filling the profile | mitigate | Build without MINT_E2E_ARCHETYPE; build invocation cited; echo check falsifiable |
| T-m1-08-SC | Tampering | pip/pub installs | accept | No new packages; existing sim/test tooling only |
</threat_model>

<verification>
- `.planning/phases/mint-grounded-coach-m1/W1-cadre-50-rerun.md` exists; preamble cites the Railway deploy SHA (M1 head) + staging health 200 + non-seeded build invocation; the AUTHENTICATED rachat reply is a versement; the anonymous surface ships no inversion (correct or fallback); zero P1 on coach surfaces; idb/Maestro evidence cited.
- `cd services/backend && python3 -m pytest tests/ -q` exits 0 and the inversion fixtures pass.
- `cd apps/mobile && flutter analyze` clean.
- The VERIFICATION-REPORT.html exists with the RED→GREEN lineage and device verdict.
</verification>

<success_criteria>
The milestone closure gate passes: against an M1-HEAD staging deploy and a non-seeded build,
a persona walkthrough on sim shows the rachat definition correct on the authenticated surface
and no inversion on the anonymous surface, zero P1 on coach surfaces, all suites + inversion
fixtures green, the cumulative evidence report produced, and (optionally) the founder approves.
</success_criteria>

<output>
Create `.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-08-SUMMARY.md` when done.
Cite the device-evidence line (idb describe-all / Maestro junit) proving the rachat fix as the closure citation.
</output>
