---
description: "Plan list for phase mint-grounded-coach-m1 (M1 Grounded Coach, refondation lucidity-spine). 8 plans across 7 sequential waves. Wave 1 is fixture-first (rachat-inversion RED proof) then compliance hardening (founder priority). Closure is a persona-walkthrough device gate. Source: mint-grounded-coach-m1-CONTEXT.md (locked decisions) + état-des-lieux reports 01/04."
phase: mint-grounded-coach-m1
date: 2026-06-12
---

# Plan list — mint-grounded-coach-m1

8 plans, 7 sequential waves. The project executes one plan at a time on the main tree;
hotspot files (compliance_guard.py, coach_chat.py, claude_coach_service.py, config.py,
coach_tools.py, coach_reasoner.dart) are never split across same-wave plans (verified clean).

| Wave | NN | Slug | Autonomous | Delivers |
|------|----|------|-----------|----------|
| 1 | 01 | inversion-fixtures-red | yes | Inversion eval fixtures (≥15, incl. rachat) + deterministic scorer PROVEN RED (xfail-strict) against the current coach — CONTEXT decision 3 |
| 1 | 02 | compliance-blocking-gates | yes | ComplianceGuard prescriptive + banned blocking (no >5 tolerance), empty-profile hallucination escape hatch removed — WS-A founder priority |
| 2 | 03 | perimeter-coherence-reframe | yes | coach_reasoner unranked → educational comparison; get_couple_optimization reframed; EPL/79b prose widened (TF 26.02.2026) — WS-A |
| 3 | 04 | concept-registry-claim-checker | yes | Curated Swiss concept registry + deterministic claim-checker wired into ComplianceGuard as a blocking layer; Plan 01 xfail flips GREEN — WS-B/WS-E |
| 4 | 05 | explain-concept-forced-tool | yes | explain_concept tool + intent-forced tool_choice on the authenticated surface + show_fact_card content/source gated against the registry — WS-B |
| 5 | 06 | savefact-return-domain-fixes | yes | save_fact value echoed to mobile (minimal split-brain fix, NOT event-log cutover) + AVS women age 64.5/2026 — WS-D |
| 6 | 07 | activate-or-delete-facades-ci | no (decision) | 3 dark gates + coach_reasoner activated-or-removed (no façade, NEVER #6) + inversion fixtures wired into CI — WS-C/WS-E |
| 7 | 08 | persona-walkthrough-closure | no (human-verify) | W1-cadre-50 persona walkthrough re-run on sim, zero P1 on coach surfaces, suites + fixtures green, VERIFICATION report — CONTEXT decision 5 |

## Wave dependency chain

```
W1: 01 (fixtures RED) → 02 (compliance hardening)         [compliance_guard.py: 01 test-only, 02 prod — serial]
W2: 03 (reasoner/couple reframe + 79b prose)
W3: 04 (registry + claim-checker → flips 01 xfail GREEN)  [compliance_guard.py again — later wave than 02]
W4: 05 (explain_concept + forced tool + fact-card gate)   [coach_chat.py + prompt prose]
W5: 06 (save_fact echo + AVS age)                          [coach_chat.py again — later wave than 05]
W6: 07 (activate-or-delete façades + CI eval gate)        [config.py + coach_chat.py — later wave than 06]
W7: 08 (persona walkthrough device gate + report)
```

## Source coverage (CONTEXT workstreams → plans)

- **WS-A Compliance hardening (prioritaire)** → Plans 02 (blocking gates, known_values hatch) + 03 (reasoner/couple reframe, prompt↔code coherence, 79b)
- **WS-B Grounded definitions** → Plans 04 (registry + claim-checker) + 05 (explain_concept, forced tool, show_fact_card gating)
- **WS-C Façades** → Plan 07 (3 dark gates + coach_reasoner activate-or-delete)
- **WS-D Data path + domaine** → Plan 06 (save_fact echo, AVS 64.5) + Plan 03 (EPL/79b prose alignment)
- **WS-E Eval harness** → Plans 01 (fixtures RED) + 04 (claim-checker scorers) + 07 (CI gate)
- **Milestone exit gate (CONTEXT decision 5)** → Plan 08 (persona walkthrough, zero P1, suites green)

Scope OUT honored: no event-log cutover (M2), no nav refonte (M3), no register redesign (M3),
no doc-upload pipeline (M4). The save_fact fix is the minimal echo, not the spine cutover.
