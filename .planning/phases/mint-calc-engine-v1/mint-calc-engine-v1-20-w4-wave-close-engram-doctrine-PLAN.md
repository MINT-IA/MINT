---
phase: mint-calc-engine-v1
plan: 20
wave: 4
title: W4 — Phase wave-close engram doctrine + ROADMAP update + VERIFICATION-REPORT.html
type: execute
depends_on: [17, 18, 19]
files_modified:
  - .planning/ROADMAP.md
  - .planning/STATE.md
  - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VERIFICATION-REPORT.html
  - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md
autonomous: false
requirements: [D-CE-17, D-CE-18, D-CE-20, Concern-F]
estimated_duration: 3
must_haves:
  truths:
    - "Phase-level VERIFICATION-REPORT.html captures: per-plan PR list + panel verdicts + test counts + deferred items"
    - "ROADMAP.md updated: `mint-calc-engine-v1` marked SHIPPED (status emoji + ✓ checkboxes for 20 D-CE-XX + Concern A-F)"
    - "STATE.md updated: phase closure + next phase pointer"
    - "Phase-level engram observation with prior_finding_refs to ALL 6 wave-close obs (W1+W2+W3+W4 sub-areas)"
    - "Cumulative metric snapshot: profile_grounded_calc_rate baseline + cache hit rate + bundle compile latency"
  artifacts:
    - path: .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VERIFICATION-REPORT.html
      provides: "HTML report per memory feedback_html_evidence_report"
      min_lines: 100
    - path: .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md
      provides: "Phase close-out narrative with per-D-CE-XX disposition + per-Concern disposition"
      min_lines: 80
  key_links:
    - from: .planning/ROADMAP.md
      to: .planning/phases/mint-calc-engine-v1/
      via: "Phase status mark"
      pattern: "mint-calc-engine-v1.*✓\\|SHIPPED"
---

<objective>
Close the phase. Roll up all 19 prior plans into:
- 1 phase-level VERIFICATION-REPORT.html per memory `feedback_html_evidence_report`
- 1 phase-level SUMMARY.md
- ROADMAP.md update (`mint-calc-engine-v1` → ✓ SHIPPED)
- STATE.md update + next-phase pointer
- Phase-level engram observation (Concern F wave-close discipline, compounding observable per CLAUDE.md §3.5)
- 5-gate exit contract verification (G1 Maestro + G2 Julien sim + G3 dev CI + G4 regression + G5 lints)

Purpose: D-CE-18 phase shape + Concern F memory discipline + 5-gate exit contract.

Output: phase-level artifacts + engram + roadmap. **Requires Julien GO on 5-gate exit (G2 device sign-off).**
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-01-w1-shared-helpers-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-02-w1-priority1-endpoints-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-03-w1-priority2-endpoints-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-04-w1-lucidity-payloads-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-05-w1-calc-registry-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-06-w1-sev2-batch-grounding-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-07-w2-tool-registry-adapter-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-08-w2-bundles-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-09-w2-tool-description-rewrite-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-10-w2-coach-tool-response-v2-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-11-w2-deprecation-shims-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-12-w3-composite-index-migration-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-13-w3-cache-reader-writer-singleflight-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-14-w3-reverse-dep-map-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-15-w3-pre-compute-background-tasks-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-16-w3-gc-job-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-17-w4-metrics-counters-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-18-w4-banned-verb-lint-runtime-gate-SUMMARY.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-19-w4-profile-safe-fields-parity-SUMMARY.md
</context>

<tasks>

<task id="W4-04-01" type="auto" tdd="false">
  <name>Task 1: VERIFICATION-REPORT.html per memory feedback_html_evidence_report</name>
  <files>.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VERIFICATION-REPORT.html</files>
  <read_first>
    - All 19 prior Plan SUMMARYs
    - Memory `feedback_html_evidence_report` — required structure (PRs, panel verdicts, test counts, deferred items)
    - .planning/reports/SESSION-*.html (existing precedent if any)
  </read_first>
  <action>
    Build the HTML report per memory pattern. Sections:

    1. **Phase header**: `mint-calc-engine-v1` + ship date + cumulative duration estimate
    2. **20 D-CE-XX disposition table**: each decision row → which plan delivered it + commit sha + test count + status
    3. **6 Concern (A-F) disposition table**: A description rubric, B latency_tier V2, C parity lint, D blank-profile fixture, E singleflight, F engram doctrine
    4. **W0 audit closure**: 12/12 sev-3 closed, X/23 sev-2 closed
    5. **Per-plan PR list**: 20 plans → 20 (or fewer if batched) PRs with merge sha
    6. **Test count delta**: baseline pre-W0 → post-W4 (cumulative new tests)
    7. **5-gate exit contract**: G1-G5 status per plan
    8. **Deferred items**: Q1/Q2/Q3/Q4/Q5/Q6 resolutions + post-phase TODOs (V1 retirement, Grafana panels, etc.)
    9. **Lessons learned**: 3-5 bullets per CLAUDE.md §8 wiki schema

    Use existing reports as visual template if available. If none, simple HTML5 with inline CSS.
  </action>
  <verify>
    <automated>test -f .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VERIFICATION-REPORT.html && wc -l .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VERIFICATION-REPORT.html</automated>
  </verify>
  <acceptance_criteria>
    - File ≥100 lines
    - Contains 8 of 9 sections enumerated above (Section 9 = optional)
    - Lists 20 D-CE-XX rows
    - Lists 6 Concerns rows
    - Documents 5-gate exit contract status
  </acceptance_criteria>
  <done>VERIFICATION-REPORT.html shipped</done>
</task>

<task id="W4-04-02" type="auto" tdd="false">
  <name>Task 2: Phase-level SUMMARY.md</name>
  <files>.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md</files>
  <read_first>
    - All 19 prior Plan SUMMARYs
    - Memory `feedback_session_projection_vs_roadmap` (avoid projection drift)
  </read_first>
  <action>
    Markdown narrative version of the HTML report. Sections:

    1. **TLDR**: 1-paragraph « what shipped, what didn't »
    2. **Per-D-CE-XX disposition**: bullet list with status (✓ shipped / partial / deferred)
    3. **Per-Concern disposition**: same
    4. **Metric snapshot**: profile_grounded_calc_rate baseline + cache hit rate (if measurable on staging) + warm precision/recall + zero_citation_total (must be 0)
    5. **Wave-close engram doctrine roll-up**: list of 6 wave-close obs_ids (W1-w1-99, W2-11-99, W3-16-99, W4-this-plan)
    6. **What got DEFERRED to next phase / backlog**: V1 retirement, Grafana panels, derived-field reverse-dep coupling, 3 truly absent calcs (quasi-resident, bouclier fiscal, Sàrl-vs-RI), full 200-fixture parity coverage
    7. **5-gate exit contract** (G1-G5) per plan
    8. **Next phase pointer**: TBD — likely (a) backend calc-parity scaffold (backlog 999.4) post-TestFlight, (b) ML reverse-dep map if SLI below target, (c) Phase 97 Maestro full power.

    Counter-arguments block (per wiki_lint.py): document what could have gone differently + data gaps remaining.
  </action>
  <verify>
    <automated>wc -l .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md ; python3 tools/checks/wiki_lint.py lint .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - File ≥80 lines
    - `wiki_lint.py` passes (TLDR + counter-arguments)
    - All 20 D-CE-XX listed with disposition
    - All 6 concerns listed
    - 6 prior wave-close engram obs_ids referenced
  </acceptance_criteria>
  <done>Phase SUMMARY.md shipped</done>
</task>

<task id="W4-04-03" type="auto" tdd="false">
  <name>Task 3: ROADMAP.md + STATE.md updates</name>
  <files>.planning/ROADMAP.md, .planning/STATE.md</files>
  <read_first>
    - .planning/ROADMAP.md (current `mint-calc-engine-v1` section line 17-28)
    - .planning/STATE.md (current state)
  </read_first>
  <action>
    **ROADMAP.md patch:**

    Update `### Phase: mint-calc-engine-v1` section:
    - Status: `🚧 ACTIVE` → `✅ SHIPPED 2026-XX-XX`
    - **Plans:** `0 plans` → `20 plans (W1: 6, W2: 5, W3: 5, W4: 4)`
    - Add `Plans:` list with all 20 paths + `[x]` checkboxes:
      ```
      Plans:
      - [x] mint-calc-engine-v1-01-w1-shared-helpers-PLAN.md
      - [x] mint-calc-engine-v1-02-w1-priority1-endpoints-PLAN.md
      ... (18 more)
      ```
    - Add link to VERIFICATION-REPORT.html

    Update milestone line: `🚧 v2.10 Lucidité Engine — ACTIVE` → `✅ v2.10 Lucidité Engine — SHIPPED 2026-XX-XX (Phase mint-calc-engine-v1 closed)`.

    **STATE.md patch:**
    - `stopped_at`: « Completed mint-calc-engine-v1 (20 plans, ~31 endpoints grounded, L1-L4 typed payloads, ToolRegistryAdapter+3 adapters, DAG cache+pre-compute+GC, banned-verb triple defense, Concern C parity lint). Phase SHIPPED. Next phase pending. »
    - `last_activity`: « 2026-XX-XX — Phase mint-calc-engine-v1 SHIPPED »
    - `progress.completed_plans` += 20
    - `progress.completed_phases` += 1
  </action>
  <verify>
    <automated>grep -c "mint-calc-engine-v1.*SHIPPED\|✅.*Lucidité" .planning/ROADMAP.md</automated>
  </verify>
  <acceptance_criteria>
    - ROADMAP.md shows phase ✅ SHIPPED + 20 plan checkboxes ticked
    - STATE.md `stopped_at` reflects closure
    - `progress.completed_plans` incremented by 20
  </acceptance_criteria>
  <done>Index files updated</done>
</task>

<task id="W4-04-04" type="auto" tdd="false">
  <name>Task 4: Phase-level engram observation (Concern F compounding observable)</name>
  <files>(engram)</files>
  <read_first>
    - All 19 prior Plan SUMMARYs (for prior_finding_refs harvest)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Memory Contract
  </read_first>
  <action>
    Phase-level engram save:
    - `topic_key: calc_engine:phase_close:mint_calc_engine_v1`
    - `type: architecture`
    - `prior_finding_refs`: collect ALL 6 wave-close obs_ids (W1 wave-close from Plan 06, W2 wave-close from Plan 11, W3 wave-close from Plan 16, W4-01 from Plan 17, W4-02 from Plan 18, W4-03 from Plan 19) PLUS W0 audit obs (#104-107) PLUS panel synthesis (#103). Target: ≥10 prior_finding_refs.
    - Content: « Phase mint-calc-engine-v1 SHIPPED. 20 plans across W1+W2+W3+W4. All 20 D-CE-XX delivered (table in SUMMARY.md). 12 W0 sev-3 endpoints closed structurally. L1-L4 lucidity payloads structurally forbid ranking creep. ToolRegistryAdapter vendor-agnostic with 3 adapters. DAG cache: composite index + reader/writer + AsyncSingleflight + BackgroundTasks pre-compute + Railway-cron GC. Triple-defense banned verbs. Concern C parity lint. profile_grounded_calc_rate measurable. Next phase candidates: backlog 999.4 (backend parity scaffold post-TestFlight) OR ML reverse-dep map if SLI below target OR Phase 97 (Maestro full power). »
  </action>
  <verify>
    <automated>echo "Engram save expected to return obs_id"</automated>
  </verify>
  <acceptance_criteria>
    - Phase-level engram obs saved
    - ≥10 prior_finding_refs cited (Concern F compounding observable proof)
  </acceptance_criteria>
  <done>Memory closure</done>
</task>

<task id="W4-04-05" type="checkpoint:human-verify" gate="blocking">
  <what-built>
    Full phase mint-calc-engine-v1 closure:
    - 20 plans + 20 SUMMARY.md
    - VERIFICATION-REPORT.html + phase SUMMARY.md
    - ROADMAP.md + STATE.md updated
    - 5-gate exit contract per plan
  </what-built>
  <how-to-verify>
    1. **G1 Maestro full-suite walkthrough**: `bash tools/simulator/walker_audit_tap_render.sh` against the perfect-set. Confirms all coach flows + tool search round-trip + 422 envelope rendering still work end-to-end.
    2. **G2 Julien device walkthrough on TestFlight (or sim)**: open MINT, test 5 scenarios:
       - Coach asks « combien je gagne ? » → narrator emits L1 chip with citation (Phase 94 preserved)
       - Profile-incomplete divorce request → 422 envelope renders FR hint, no crash
       - L4 mortgage-cap invariant tap → reads « 33% LCC plafond » in clean FR
       - Tool Search query « si je divorce demain » → divorce_simulator surfaces in top-3
       - Banned verb « tu devrais » in narrator output → fallback template fires
    3. **G3 dev CI green**: `gh pr checks <merge-sha>` returns all green
    4. **G4 regression suite**: `cd services/backend && pytest tests/ -q` + `cd apps/mobile && flutter test` green
    5. **G5 lints**: `python3 tools/checks/banned_terms_python.py services/` + `accent_lint_fr.py --scope backend mobile` + `wiki_lint.py lint` + `validate_arb_parity()` + `profile_safe_fields_parity.py` all exit 0

    All 5 gates green → Julien signs « SHIPPED ».
  </how-to-verify>
  <resume-signal>
    Reply with one of:
    - "shipped" → phase officially closed
    - "blocked at G<N>: <reason>" → executor re-opens specific plan, re-spawns gate
    - "deferred — staging soak needed" → phase remains 🟡 PENDING G2 in STATE.md, walker.sh repeated post-staging-deploy
  </resume-signal>
</task>

<task id="W4-04-99" type="auto" tdd="false">
  <name>Task 6: Post-checkpoint commit + git tag</name>
  <files>(git)</files>
  <action>
    On checkpoint resume = shipped:
    1. Commit all phase-close docs in one commit: `docs(mint-calc-engine-v1): phase close — 20 plans SHIPPED, 5-gate exit contract green`
    2. Tag: `git tag mint-calc-engine-v1-shipped-2026-XX-XX -m "Phase mint-calc-engine-v1 shipped"`
    3. (Optional, per CLAUDE.md no-push-without-explicit-OK rule) push tag ONLY if Julien explicitly says « push tag ».

    DO NOT push to remote in this task without explicit confirmation.
  </action>
  <verify>
    <automated>git log --oneline -3 | head -3</automated>
  </verify>
  <acceptance_criteria>
    - Phase-close commit present
    - Tag created locally
    - No silent push
  </acceptance_criteria>
  <done>Phase officially closed</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register (phase-level recap)

| Threat ID | Category | Component | Disposition | Notes |
|-----------|----------|-----------|-------------|-------|
| T-mint-calc-PHASE-01 | Information disclosure | VERIFICATION-REPORT.html | accept | No PII in report. Documents technical disposition only. |
| T-mint-calc-PHASE-02 | Tampering | ROADMAP / STATE manual edit | mitigate | Phase-close commit creates atomic git checkpoint. Tag is immutable. |
| T-mint-calc-PHASE-03 | LSFin | phase narrative | mitigate | wiki_lint.py runs on SUMMARY.md + counter-arguments mandatory. |
</threat_model>

<success_criteria>
- VERIFICATION-REPORT.html + SUMMARY.md shipped
- ROADMAP + STATE updated
- Phase-level engram obs with ≥10 prior_finding_refs
- 5-gate exit contract green per Julien G2 verdict
- Phase officially marked SHIPPED
</success_criteria>

<risks>
- **G2 device walkthrough may surface UX regressions.** Plan is `autonomous: false`. If G2 finds a defect, the specific plan re-opens (not the whole phase).
- **20 plans is a LOT to roll up.** Executor may need to triage which plan SUMMARYs are most critical to cite in the phase-level HTML. Aim for completeness in the table but allow narrative compression in « lessons learned ».
- **Phase-level engram with ≥10 refs.** Concern F compounding observable proof. Failure to hit ≥10 is a HARD acceptance criterion.
- **`/ship` skill not used here.** Phase-close is NOT a single PR — it's a phase document commit, distinct from feature/wave PRs.
</risks>

<output>
After Task 6 commits, the phase is closed. The `.planning/phases/mint-calc-engine-v1/` directory now contains 20 PLANs + 20 SUMMARYs + VERIFICATION-REPORT.html + phase SUMMARY.md.
</output>
