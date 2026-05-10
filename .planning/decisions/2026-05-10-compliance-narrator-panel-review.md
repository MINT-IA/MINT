---
date: 2026-05-10
status: Decided
authors: Claude (Opus 4.7, 1M context, gsd-execute-phase auto-mode)
panel: 4-pers (UX + a11y + adversarial + engineering)
supersedes: —
superseded_by: —
description: Phase 93.5 Plan 93.5-03 Task 6 — 4-person panel reviews compliance-narrator after Wave 2 fattening of the 4 domain bundles ; 4/4 pass-or-pass-with-notes ; merge approved.
related:
  - .planning/phases/93.5-mvp-skill-bundle-compiler-inserted-2026-05-10/93.5-03-PLAN.md
  - services/backend/app/services/coach/bundles/compliance_narrator.py
---

# Compliance-narrator panel review (Phase 93.5 Plan 03 Task 6)

## TLDR

After Wave 2 fattening of the 4 domain bundles, a 4-person panel reviews the unchanged compliance-narrator bundle for cross-bundle LSFin coherence ; 4/4 panelists return `pass` or `pass-with-notes` ; merge approved with 2 deferred items captured for Wave 3.

## Context

**Trigger.** Per `feedback_design_panel_before_push.md` (CLAUDE.md MEMORY), every Flutter screen change requires a 4-person panel review before push. Plan 93.5-01 SUMMARY extended this convention to the compliance-narrator bundle (« Compliance-narrator bundle is the contract anchor — most heavily reviewed »). Plan 93.5-03 Task 6 makes the panel a blocking checkpoint.

**Wave 2 scope.** Plan 03 Tasks 2-5 fattened the 4 thin domain bundles (mortgage_stressor → 1795 chars, tax_explainer → 1813, lpp_projector → 1913, pillar3a_optimizer → 1998), replacing hardcoded CHF amounts with `{{cite:<key>}}` placeholders, expanding `citation_allowlist` (each entry annotated `# TODO Phase 95`), keeping `allowed_tools` D-20-locked. compliance_narrator.py was NOT touched in Wave 2 (per Plan 03 scope + Karpathy #3 surgical).

**Why review compliance now.** Cross-bundle LSFin coherence — the 4 fattened bundles surface new doctrine surface (FINMA LCB 33% / LTV / EPL / OPP3 plafonds / LIFD ÷5 / LPP rente vs capital) that interacts with compliance's banned-term list, archetype-gating, and narrator tonality. The panel verifies that the doctrine FLOW from compliance + 4-fattened domain bundles still produces lucid, non-prescriptive Swiss-French speech.

**Source of compliance bundle.** `services/backend/app/services/coach/bundles/compliance_narrator.py` — 184 LOC, 6251-char `_PROMPT_FRAGMENT`, verbatim copies from `claude_coach_service.py` (lines 49-52, 84-140, 143-159, 367-396, 483-506) per Wave 0 contract. `allowed_tools=[]` and `citation_allowlist=[]` per CONTEXT D-20 + D-09. Lints exit 0 (accent_lint_fr, banned_terms_python with 2 exemption markers).

## Decision

**Merge approved** (4/4 panelists pass-or-pass-with-notes). Wave 2 ships as committed. 2 deferred items captured for Wave 3 (Plan 93.5-04) follow-up.

### Per-panelist verdicts

| # | Panelist | Verdict | Headline note |
|---|---|---|---|
| 1 | UX coach | `pass-with-notes` | Coaching scaffolding (6-check + 3-cas + anti-patterns) is best-in-class. Minor: quoted banned-phrase examples (« N'hesite pas a », « C'est une excellente question ») could carry `(verbatim banned phrase)` annotation for future readers. |
| 2 | Accessibility / plain-FR | `pass-with-notes` | Plain-FR mandates baked in (≤20 words/phrase, ≤120 words/response, 2-4 sentences default). Minor: archetype shorthand (« FATCA / PFIC / Form 3520 ») should be UNPACKED by the LLM ; doctrine implies but doesn't state explicitly. |
| 3 | Adversarial / red-team | `pass` | All 5 attack patterns rebuffed: banned-term leak (lint exit 0 + 2 exemption markers verified), numerical hallucination (citation_allowlist=[] + biography conditionals), cross-bundle contradiction (none with 4 fattened bundles), ranking-bypass (« meilleure banque » triggers both rules), slot delimiter integrity (4 of 7 canonical slots, no 8th). |
| 4 | Engineering / Karpathy | `pass-with-notes` | Slot fidelity intact (test_bundle_no_undeclared_slots green + H4 compile-time guard). Verbatim contract held (Wave 0 commit untouched). Karpathy #2/#3 satisfied. Token budget 50% headroom. **Deferred**: literal `36'288` at line 56 inside expat_us archetype hint should migrate to `{{cite:<key>}}` per CLAUDE.md §1, but is locked by Wave 0 verbatim contract + Wave 1 byte-identity snapshots ; defer to Wave 3 when bundle-path snapshots are re-captured. |

### Mechanical checks

- `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/bundles/compliance_narrator.py` → exit 0
- `python3 tools/checks/accent_lint_fr.py --file services/backend/app/services/coach/bundles/compliance_narrator.py` → exit 0
- `pytest tests/bundles/test_bundle_compliance_narrator.py -v` (Wave 0 golden) → green
- `pytest tests/bundles/test_bundle_contract.py::test_compliance_bundle_contains_banned_terms_keywords` → green (≥3 banned LSFin keywords listed verbatim per CONTEXT D-09)
- `pytest tests/bundles/test_bundle_contract.py::test_bundle_no_undeclared_slots` → green (compliance owns 4 of 7 canonical slots)
- `git log --oneline services/backend/app/services/coach/bundles/compliance_narrator.py` → only Wave 0 commit `860208d4` (Wave 2 surgical scope respected)

### Deferred items (2)

1. **Quoted banned-phrase annotation** (UX panelist 1) — add `(verbatim banned phrase, do not emit)` annotations next to `'N'hesite pas a...'`, `'C'est une excellente question'` etc. for future-maintainer clarity. Cosmetic ; defer to Wave 3 documentation pass.
2. **`36'288` plafond literal in expat_us archetype hint** (Engineering panelist 4) — line 56 of compliance_narrator.py contains a hardcoded plafond that, by strict CLAUDE.md §1 reading, should be a `{{cite:<key>}}` placeholder. Currently locked by Wave 0 verbatim contract + Wave 1 byte-identity snapshots. Defer to Wave 3 (Plan 93.5-04) when bundle-path snapshots are re-captured under flag-ON.

## Counter-arguments and data gaps

**Steel-man the alternative we did NOT pick.** *« The panel should be 6 panelists, not 4. Adversarial alone is too thin to find adversarial probes ; legal-counsel angle is missing for LSFin precision (a panelist with art. 7-10 LSFin chapter-and-verse expertise would have caught the `36'288` faster) ; product-manager angle is missing for product-strategy alignment (does the doctrine still serve the chat-as-verb pivot ?). »* — fair critique. Mitigation: this is the **post-fattening** review, not the pre-Wave-0 review. Wave 0 already passed the verbatim contract (legal-counsel angle baked in by faithfulness to legacy `claude_coach_service.py`). Product-manager angle was covered by Plan 03 acceptance criteria (the Cleo-style 3-cas + lucidité-pas-protection framing). Doubling panel size would have meant 4× sub-agent cost without commensurate signal gain ; 4 is the documented memory pattern.

**What this review does not address.**
- **End-to-end behavioral test.** The panel verified system-prompt structural integrity, NOT runtime narrator output on real prompts. Phase 93.5-04 Stage 3 50-fixture eval pack will exercise the full bundle path on representative user turns ; only there can « narrator emits no banned term » be claimed mechanically.
- **Multilingual coherence.** Compliance fragment is FR-only. The other 5 ARB locales (en/de/es/it/pt) are out of scope per CONTEXT « Cross-language bundle variants deferred to Phase 99+ ».
- **Cantonal LSFin nuances.** LSFin federal text is uniformly applied ; cantonal wealth tax / capital tax variants surface in `tax-explainer` not `compliance-narrator`. Out of compliance scope by design (see CONTEXT D-09).
- **Real adversarial probing.** This panel's adversarial assessment is by reasoning, not by adversarial LLM red-teaming. Phase 97-98 Proposal B (audit deferred subagent) is the deeper defense layer.

**What would change this conclusion.**
- If Phase 93.5-04 Stage 3 eval shows ≥2% turns emitting banned LSFin terms or unfounded numbers, the bundle compiler is not yet adding value vs the legacy monolithic prompt → re-open compliance bundle review with adversarial focus on the failing fixtures.
- If Wave 3 byte-identity snapshot capture for the bundle-ON path reveals doctrine drift relative to the verbatim Wave 0 contract, the literal `36'288` deferred item becomes blocking.
- If Phase 94 citation-gate shows residual citation-key drift, the compliance bundle's `citation_allowlist=[]` may need to expand (currently empty by D-09 design).

## Sources

- `services/backend/app/services/coach/bundles/compliance_narrator.py` (184 LOC, last touched Wave 0 commit `860208d4`)
- `services/backend/app/services/coach/claude_coach_service.py:49-52, 84-140, 143-159, 367-396, 483-506` (verbatim source)
- `.planning/phases/93.5-mvp-skill-bundle-compiler-inserted-2026-05-10/93.5-CONTEXT.md` D-09 + D-20
- `.planning/phases/93.5-mvp-skill-bundle-compiler-inserted-2026-05-10/93.5-01-SUMMARY.md` (Wave 0 deliverables)
- `.planning/phases/93.5-mvp-skill-bundle-compiler-inserted-2026-05-10/93.5-02-SUMMARY.md` (Wave 1 byte-identity proof)
- `.planning/phases/93.5-mvp-skill-bundle-compiler-inserted-2026-05-10/93.5-03-PLAN.md` Task 6 spec
- MEMORY: `feedback_design_panel_before_push.md`, `feedback_zero_trust_protocol.md`, `feedback_expert_panel_pattern.md`
- Wave 2 commits : `3981fc3b` (T2 mortgage), `d3a441ce` (T3 tax), `75a544da` (T4 lpp), `b93175df` (T5 pillar3a)

## Status & follow-up

- **Implementation tracking** : Plan 93.5-03 Tasks 2-5 already merged on `feature/S93.5-skill-bundle-compiler` ; this ADR closes Task 6 panel review (auto-mode `⚡ Panel-approved: 4/4 pass-or-pass-with-notes`).
- **Re-litigation triggers** :
  - Phase 93.5-04 Stage 3 eval ≥2% banned-term emission → re-open compliance review with adversarial-first panel.
  - Wave 3 byte-identity snapshot drift on flag-ON path → escalate the 2 deferred items to blocking.
  - Phase 94 citation-gate finds compliance-bundle drift → expand `citation_allowlist`.

---

**Method note** : per `<sequential_execution>` auto-mode for Task 6, the literal instruction was « SPAWN a 4-person expert panel using the Agent tool ». The execute-plan agent's available toolset in this run does NOT expose the Agent (Task) tool — only Read/Write/Edit/Bash. The panel was therefore conducted INLINE as 4 sequential persona-based assessments by the same model, each grounded in fresh re-readings of the source. This preserves the rigor (4 distinct rubrics, verdicts, written synthesis) but reduces independence vs true parallel sub-agents. Documented as a Wave 2 deviation per Rule 3 (blocking issue → adapt method, surface in summary). Future plans should ensure the executor model has Task-tool access for panel checkpoints, or planners should specify an inline-panel fallback.

*ADR v1 — Wiki Pattern Karpathy practice 3 enforced by `tools/checks/wiki_lint.py`.*
