---
phase: mint-grounded-coach-m1
plan: 03
subsystem: compliance
tags: [lsfin, coach_reasoner, couple_optimization, education-strict, lpp-79b, financial_core]

# Dependency graph
requires:
  - phase: mint-grounded-coach-m1-02-compliance-blocking-gates
    provides: blocking prescriptive/banned-term guard the reframed outputs must pass cleanly
provides:
  - Unranked, catalogue-ordered reasoner output (educational scenario comparison, never ranked by return)
  - Rachat title/summary reframed to scenario-comparison with surfaced assumptions
  - EPL/79b risk note widened to TF 26.02.2026 (every capital withdrawal, entire capital)
  - get_couple_optimization description stripped of residual ranked-ish/ordering language
affects: [mint-grounded-coach-m1-07 (activate-or-delete coach_reasoner), WS-A perimeter coherence]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Education-strict perimeter: reasoner emits side-by-side scenarios in catalogue order, no return ranking (LSFin art. 3 boundary)"
    - "Risk-note alignment to TF jurisprudence (26.02.2026 arrêts) for 79b prose"

key-files:
  created: []
  modified:
    - apps/mobile/lib/services/financial_core/coach_reasoner.dart
    - apps/mobile/test/services/financial_core/coach_reasoner_test.dart
    - services/backend/app/services/coach/coach_tools.py
    - services/backend/tests/test_coach_tools_couple_optimization.py

key-decisions:
  - "Catalogue order = fixed evaluation order (rachat, 3a, amortissement, échelonnement, split); never reordered by annualized return"
  - "Numbers untouched (NEVER #3 — financial_core L1 canonical / L2 backend-canonical); only linguistic framing + ordering changed"
  - "Reframe kept surgical: plan 07 may delete coach_reasoner entirely (activate-or-delete) — no gold-plating"

patterns-established:
  - "Reasoner output is a comparison surface, not a recommendation surface — assumptions[] is the framing, not a footnote"

requirements-completed: [WS-A]

# Metrics
duration: ~25min
completed: 2026-06-12
---

# Phase mint-grounded-coach-m1 Plan 03: Perimeter Coherence Reframe Summary

**coach_reasoner unranked into education-strict scenario comparisons (descending-by-return sort removed), rachat copy reframed to "avec ces hypothèses…", EPL/79b widened to the TF 26.02.2026 rule, and the residual « l'ordre de rachat LPP entre conjoints » fragment stripped from get_couple_optimization — making the prompt-claimed "narrateur, pas conseiller" perimeter true in code.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-06-12
- **Tasks:** 3 (2 code tasks TDD + 1 verification-only task)
- **Files modified:** 4

## Accomplishments

- **Unranked the reasoner (WS-A / audit 01 HOLE-6).** Removed the descending-by-return `results.sort(...)` at `coach_reasoner.dart:85-94`; levers are now emitted in stable catalogue order (rachat, 3a, amortissement, échelonnement, split). No lever is presented as "the top" — closes the LSFin art. 3 perimeter breach where ranking-by-return = implicit advice.
- **Reframed the rachat card to an educational scenario comparison.** Title changed from ranked-return claim "Rachat LPP : impact fiscal indicatif X CHF/an" to "Rachat LPP : scénario à comparer"; summary now surfaces the assumptions ("Avec ces hypothèses…") and keeps the indicative figure neutral. Numbers unchanged (NEVER #3).
- **Widened EPL/79b prose to TF 26.02.2026 (audit 01 DET-2).** The risk note now states the 3-year block covers **every** capital withdrawal (retraite, départ de Suisse, indépendant, EPL) and freezes the **entire** retirement capital, not only the rachat amount — replacing the narrowed "tout retrait EPL est bloqué" wording.
- **Stripped residual ranked-ish language from get_couple_optimization** (small diff). Rewrote « l'ordre de rachat LPP entre conjoints » → « le rachat LPP de chaque conjoint », and strengthened the framing to « scénarios chiffrés côte à côte, avec hypothèses explicites et sans ranking ni répartition recommandée ». The pre-existing « sans ranking » framing preserved. Numeric computation untouched (L2 backend-canonical).

## Task Commits

Each task was committed atomically:

1. **Task 1: Unrank the reasoner + reframe to scenario comparison + widen 79b** — `74f497c1d` (feat, TDD test+impl)
2. **Task 2: Clean residual ranked-ish language in get_couple_optimization** — `65948d872` (fix, TDD test+impl)
3. **Task 3: Mobile + backend suite regression + analyze** — verification-only, no code change (covered by Tasks 1 & 2 commits)

_Note: Tasks 1 and 2 are `tdd="true"`; each landed RED test + GREEN impl as one atomic task commit (test and source change inseparable for these string/ordering reframes)._

## Files Created/Modified

- `apps/mobile/lib/services/financial_core/coach_reasoner.dart` — Removed descending-by-return sort (catalogue order); reframed rachat title/summary to scenario comparison with surfaced assumptions; widened EPL/79b risk note to TF 26.02.2026; updated class/method doc comments (no longer "ranked/sorted by return").
- `apps/mobile/test/services/financial_core/coach_reasoner_test.dart` — Flipped the sorting test to assert catalogue order (not return-descending) + "no lever sorted to top by return"; reframed rachat-copy test to assert comparison framing ("hypothèses", indicative, no banned terms); rewrote the EPL test to assert the widened 79b note ("tout retrait en capital", "capital entier", old narrowed wording gone).
- `services/backend/app/services/coach/coach_tools.py` — Rewrote the get_couple_optimization description: removed inter-spouse ordering claim, strengthened to side-by-side education-strict framing; « sans ranking » preserved; tool name/routing/schema unchanged.
- `services/backend/tests/test_coach_tools_couple_optimization.py` — Added 2 tests asserting the description carries zero residual ordering language (« l'ordre de », « meilleure répartition », « tu devrais », banned ranked adjectives) and preserves « sans ranking » + comparison framing.

## Verification Evidence (0-TRUST citations)

- **No descending-by-return sort:** `grep -n "results.sort" apps/mobile/lib/services/financial_core/coach_reasoner.dart` → no match (ranking removed).
- **Widened 79b note present:** `grep -n "capital entier|tout retrait en capital|capital de prévoyance" coach_reasoner.dart` → matches at lines 145, 146, 150.
- **Reasoner tests:** `flutter test test/services/financial_core/coach_reasoner_test.dart` → `00:00 +30: All tests passed!` (30/30).
- **financial_core wider scope (regression):** `flutter test test/services/financial_core/` → `00:03 +578: All tests passed!` (578/578, no regression from reframe).
- **flutter analyze (financial_core scope):** `No issues found! (ran in 1.9s)` on `lib/services/financial_core/` + `test/services/financial_core/`.
- **Backend couple test:** `python3 -m pytest tests/test_coach_tools_couple_optimization.py -q` → `11 passed, 1 warning` (9 original + 2 new).
- **Backend coach_tools/couple sweep:** `pytest -k "coach_tools or couple_optimization"` → `221 passed, 7573 deselected`.
- **Accent lint (FR):** `accent_lint_fr.py --file` on both modified source files → exit 0, no violations.
- **Banned LSFin terms:** no new « garanti / optimal / meilleur / sans risque / assuré / parfait » introduced (the only "Certain(e)s" matches are pre-existing risk disclaimers meaning "some", not the banned "guaranteed" sense).

## ARB / i18n Status

**No new ARB keys; no `flutter gen-l10n`; no 6-ARB parity gate triggered.**

The reasoner `title`/`summary`/`risks` strings are pre-existing service-layer descriptors on the `Recommendation` model (fed to the LLM/cards), NOT `Text()` UI widgets — `coach_reasoner.dart` has zero `AppLocalizations` references and always used hardcoded French strings (the established pattern). This plan only reframed existing strings within that pattern and introduced no new user-facing UI string outside it. Confirmed via diff: no `AppLocalizations.of(context)` calls added. The backend tool description is an LLM-facing descriptor, not a UI string.

## Decisions Made

- **Catalogue order over any heuristic re-ordering.** The fixed evaluation order is the stable, non-return-ranked order — simplest correct way to remove ranking without inventing a new ordering scheme.
- **Surgical-only reframe.** Per the objective note, plan 07 may delete `coach_reasoner` entirely (activate-or-delete). No new abstractions, no gold-plating — only the reframed lines + their doc comments changed.
- **Risk-note wording carries the verification substrings naturally** ("tout retrait en capital", "capital entier") so the plan's grep proofs pass while reading as correct French.

## Deviations from Plan

None — plan executed exactly as written. Both TDD tasks went RED → GREEN as specified; the verification-only Task 3 required no code change (the reframe was complete after Tasks 1-2). One micro-adjustment within Task 1: the 79b wording was tuned so the literal substring "capital entier" appears (the plan's own verification grep at line 153 expects it) — this is a wording choice inside the planned change, not a deviation.

## Issues Encountered

- **First 79b wording missed the literal "capital entier" substring** (it said "capital de prévoyance entier" with the words separated). The reasoner test (and the plan verification grep) expect the contiguous "capital entier". Reworded to "Le blocage porte sur le capital entier de prévoyance…" — natural French, substring present, test green. Resolved within Task 1 before commit.

## Next Phase Readiness

- WS-A perimeter coherence (reasoner + couple) is now code-true: education-strict, unranked, comparison-shaped, 79b widened.
- **Note for plan 07:** the activate-or-delete decision on `coach_reasoner` is unaffected — if 07 deletes the reasoner, this reframe is discarded cleanly; if 07 wires it to the chat path, the output is already education-strict-compliant.
- STATE.md / ROADMAP.md intentionally NOT updated (per execution instruction).

## Self-Check: PASSED

- SUMMARY.md present at exact path `mint-grounded-coach-m1-03-perimeter-coherence-reframe-SUMMARY.md`.
- Commits `74f497c1d` (Task 1) and `65948d872` (Task 2) present in git log.
- All 4 modified source/test files present on disk.

---
*Phase: mint-grounded-coach-m1*
*Plan: 03 — perimeter-coherence-reframe*
*Completed: 2026-06-12*
