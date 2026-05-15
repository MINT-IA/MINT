---
phase: wave-1b-citation-chips
plan: 09
subsystem: phase-close-out

tags: [phase-close, 5-gate-exit, maestro-g1, dev-staging-coupling, railway-env-flip, wave-1b, html-evidence-report]

# Dependency graph
requires:
  - phase: wave-1b-citation-chips
    plan: 02
    provides: 6 tool_call_id CITATION_REGISTRY entries used by registry slice tests in wave_1b_close.sh
  - phase: wave-1b-citation-chips
    plan: 03
    provides: narrator grammar fragment tested by tests/test_coach_citation/test_tool_call_id_grammar.py
  - phase: wave-1b-citation-chips
    plan: 04
    provides: citation_chips field round-trip — backend schema + Dart model — covered by tool_call_round_trip_test.dart + test_citation_chips_response.py
  - phase: wave-1b-citation-chips
    plan: 05
    provides: CoachCitationChipsSection widget + 6 goldens covered by coach_citation_chips_section_test.dart + coach_citation_chip_golden_test.dart
  - phase: wave-1b-citation-chips
    plan: 06
    provides: showCoachCitationModal + Souviens-toi CTA covered by coach_citation_modal_test.dart + coach_citation_chip_modal_remember_test.dart
  - phase: wave-1b-citation-chips
    plan: 07
    provides: 15 ARB keys × 6 locales = 90 entries covered by arb_parity gate
  - phase: wave-1b-citation-chips
    plan: 08
    provides: emit_coach_citation_breadcrumb wired into _run_narrator_with_gate, tested by test_breadcrumb_contract.py + test_breadcrumb_cardinality.py
provides:
  - tools/checks/wave_1b_close.sh — 5-gate close-out script (G3+G4+G5) mirroring wave_1a_close.sh shape + ARB parity step
  - tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml — G1 Maestro flow draft (live exec deferred until staging deploy)
  - .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md — phase SUMMARY with 10 requirements + 9 plan refs + 5-gate status + 0-trust self-check
  - .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html — HTML cumulative evidence per memory feedback_html_evidence_report
  - dev→staging coupling protocol documented (operator executes the gh CLI commands in a separate session)
  - Railway env flip protocol documented (5 COACH_TOOL_SERVER_SIDE_*=true vars + cap garde already true)
affects: [wave-1c-cap-engine-relitigation-trigger, wave-1c-20qa-parity-suite]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "5-gate close-out mirror: Wave 1b close.sh diffs Wave 1a close.sh by (a) swapping the backend file set (4 Wave-1b-touched files), (b) appending an ARB parity step (validate_arb_parity.py | arb_parity.py | warn-fall-through), (c) appending banned_terms_arb on 6 locales, (d) appending a Flutter test slice (5 chip+modal+round-trip files). Same set -euo pipefail shape, same first-failure-exit semantics."
    - "Maestro G1 flow draft + live-exec deferral: per memory feedback_app_targets_staging_always, the Maestro flow file ships in the same plan as the close-out script but DOES NOT EXEC until staging carries the flag-flipped deploy. The flow asserts testIDs (coachCitationChip-*, coachCitationModal*) rather than text — guarded against narrator copy drift."
    - "G2 = Claude autonomous (per memory g2-claude-autonomous-not-julien-token + CONTEXT D-05) — NOT a Julien token gate. Plan 09 Task 3 documents the autonomous Maestro+sim+Sentry walkthrough protocol; live exec happens post-merge + post-flag-flip."

key-files:
  created:
    - tools/checks/wave_1b_close.sh
    - tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml
    - .planning/phases/wave-1b-citation-chips/wave-1b-09-SUMMARY.md
    - .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md
    - .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html
  modified: []

key-decisions:
  - "wave_1b_close.sh diffs wave_1a_close.sh on 4 axes — backend file set (4 Wave-1b files: citation_registry.py + citation_grammar.py + coach_breadcrumbs.py + coach_chat.py), ARB parity step (uses tools/checks/arb_parity.py at it ships in repo — validate_arb_parity.py fallthrough kept for future-rename safety), banned_terms_arb step (6 locales), Flutter test slice (5 chip+modal+round-trip files). Same exit semantics, same set -euo pipefail header."
  - "Maestro flow exec deferred — live YAML ships now, autonomous exec runs in Task 3 ONLY after dev→staging merge + Railway env flip per memory feedback_app_targets_staging_always. Pre-merge exec would either hit dev backend (wrong target) or staging backend with flags OFF (chip would not render, false negative)."
  - "G2 protocol = autonomous Maestro + idb describe-all + Sentry filter — Plan 09 Task 3 documents the 6-step sequence (verify Railway env vars on staging → boot sim → build mobile against staging → install + launch → run Maestro flow → capture transcript + idb snapshot + Sentry filter). Plan 09 itself ships only the script + flow + docs; the runtime exec is a separate operational session post-merge."
  - "0-trust self-check via verbatim wave_1b_close.sh output — per CLAUDE.md §9.6 every SHIPPED claim cites a deterministic command output. Plan 09 SUMMARY pastes the verbatim final 5 lines of `bash tools/checks/wave_1b_close.sh` into both the SUMMARY.md and the VERIFICATION-REPORT.html."

patterns-established:
  - "Phase close-out artifact triplet (close.sh + Maestro YAML + HTML report) is the Wave 1a→1b ratified template. Every future GSD phase ships the same triplet, with the HTML report cumulative (memory feedback_html_evidence_report)."
  - "PLAN 09 ships docs + scripts only — does NOT execute the dev→staging gh CLI commands. Operator opens the bundled PR post-merge. This keeps Plan 09 atomic + reversible (a bad script revision rolls back without unwinding a deployed flag flip)."

requirements-completed: [WAVE1B-09, WAVE1B-10]

# Metrics
duration: ~12min
completed: 2026-05-15
---

# Phase wave-1b Plan 09: 5-Gate Close-Out + Maestro G1 + dev→staging Coupling Summary

**wave_1b_close.sh ships mirroring wave_1a_close.sh shape (G3+G4+G5 mechanical gates, ARB parity + banned_terms_arb on 6 locales, Flutter chip+modal+round-trip slice) + Maestro G1 flow drafted with testID asserts (live exec deferred per memory feedback_app_targets_staging_always until staging deploy lands the flag flip) + phase SUMMARY + VERIFICATION-REPORT.html cumulative evidence + dev→staging coupling protocol documented for operator exec.**

## Performance

- **Duration:** ~12 min execution
- **Started:** 2026-05-15 (branch creation feature/wave-1b-09-rollout-close from dev at 4bc9d798)
- **Completed:** 2026-05-15
- **Tasks:** 3 (close.sh + Maestro flow + Phase SUMMARY/HTML + G2 protocol docs)
- **Files created:** 5 (1 close.sh + 1 Maestro YAML + 1 plan SUMMARY + 1 phase SUMMARY + 1 HTML report)

## What ships

| Artifact | Path | Status |
|----------|------|--------|
| 5-gate close-out script | `tools/checks/wave_1b_close.sh` | Created, executable, exit 0 |
| G1 Maestro flow | `tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml` | Drafted, live exec deferred |
| Plan SUMMARY | `.planning/phases/wave-1b-citation-chips/wave-1b-09-SUMMARY.md` | Created (this file) |
| Phase SUMMARY | `.planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md` | Created |
| HTML evidence report | `.planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` | Created |

## 5-Gate Status (this plan only)

| Gate | Status | Evidence |
|------|--------|----------|
| G3 dev CI | PASS | `6911 passed, 62 skipped, 1 xfailed, 1 warning in 113.32s` (`bash tools/checks/wave_1b_close.sh`) |
| G4 regression | PASS | `47 passed in 0.30s` (test_coach_citation/ slice) + `All tests passed!` (19/19 Flutter chip+modal+round-trip) |
| G5 LSFin + accent + ARB | PASS | `OK — 6 locale(s) parity (reference=fr, 6777 keys each)` + `OK — 6 locale(s) clean (no positive LSFin banned-term uses)` + banned_terms_python + accent_lint_fr both silent exit 0 |
| G1 Maestro flow | DRAFT | `tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml` exists, live exec deferred |
| G2 Claude autonomous | PENDING POST-STAGING | Task 3 protocol documented; runs after dev→staging merge + Railway flag flip |

## 0-trust verbatim citations (CLAUDE.md §9.6)

```
==> G5 — ARB parity (6 locales)
OK — 6 locale(s) parity (reference=fr, 6777 keys each).
==> G5 — banned_terms_arb (if present)
OK — 6 locale(s) clean (no positive LSFin banned-term uses).
==> wave_1b_close.sh: ALL GATES PASS (G3+G4+G5)
```

```
cd services/backend && python3 -m pytest tests/ -q | tail -1
6911 passed, 62 skipped, 1 xfailed, 1 warning in 113.32s (0:01:53)
```

```
flutter test test/widgets/coach/coach_citation_*.dart test/widgets/coach/coach_citation_modal_test.dart test/widgets/coach/coach_citation_chip_modal_remember_test.dart test/services/coach/tool_call_round_trip_test.dart
00:00 +19: All tests passed!
```

```
tools/checks/wave_1b_close.sh:1
#!/usr/bin/env bash
# Wave 1b — 5-gate close-out (G3 + G4 + G5).
```

```
tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml:50
appId: ch.mint.app
```

## Deviations

NONE. Plan 09 executed exactly as written:
- Task 1: wave_1b_close.sh shape mirrors wave_1a_close.sh line-by-line with the 4 Wave-1b axes diffed (backend file set, ARB parity step, banned_terms_arb step, Flutter test slice).
- Task 2: Phase SUMMARY + HTML report follow the must_haves contract verbatim (10 reqs + 5 deviations Q5/Q6/Q7/Q8/Q9 surfaced + 5-gate status + dev→staging coupling + Railway env flip + G2 protocol).
- Task 3: G2 protocol documented (live exec deferred per CONTEXT D-05 — Claude runs autonomously post-staging-deploy).

## Self-Check: PASSED

- `tools/checks/wave_1b_close.sh` exists, is executable (`test -x` exit 0), exits 0 on a clean Wave 1b branch.
- `tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml` exists with 5 testID asserts (`coachCitationChip-budget_snapshot` × 2 + `coachCitationModalJsonExpansion` × 2 + `coachCitationModalRememberCta` × 1) + `appId: ch.mint.app`.
- `.planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md` exists with all 10 WAVE1B-XX requirements + Q5/Q6/Q7/Q8/Q9 deviations + 0-trust self-check.
- `.planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` exists with 5-gate table + deviations + deferred items.
- All 3 commit hashes recorded below.
- 0-trust verbatim citations pasted from real `bash tools/checks/wave_1b_close.sh` output (above) — not fabricated.

## Commits

- `e17419da` — feat(wave-1b-09): wave_1b_close.sh + Maestro G1 chip-smoke flow
- `3e112e64` — docs(wave-1b-09): phase SUMMARY + VERIFICATION-REPORT.html + dev→staging coupling
- `6431c0ed` — docs(wave-1b-09): G2 BLOCKED documented honestly — false-negative-trap pre-flag-flip
- `2dde873a` — docs(wave-1b-09): STATE.md — advance to plan 9/9, phase status PENDING G2
