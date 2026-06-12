---
phase: mint-grounded-coach-m1
plan: 03
type: execute
wave: 2
depends_on: [mint-grounded-coach-m1-02-compliance-blocking-gates]
files_modified:
  - apps/mobile/lib/services/financial_core/coach_reasoner.dart
  - apps/mobile/test/services/financial_core/coach_reasoner_test.dart
  - services/backend/app/services/coach/coach_tools.py
  - services/backend/tests/test_coach_tools_couple_optimization.py
autonomous: true
requirements: [WS-A]
must_haves:
  truths:
    - "Reasoner output is an educational scenario comparison with explicit assumptions, not a ranked recommendation"
    - "The reasoner no longer sorts levers by return into a 'top' recommendation"
    - "get_couple_optimization output is framed as an educational comparison, not a personalised ranked arbitrage"
  artifacts:
    - path: "apps/mobile/lib/services/financial_core/coach_reasoner.dart"
      provides: "Unranked, comparison-shaped reasoner output (education-strict)"
      contains: "ReasonerResult"
  key_links:
    - from: "coach_reasoner.dart"
      to: "no descending sort by annualized return"
      via: "removed ranking"
      pattern: "results"
---

<objective>
Make the prompt-claimed "narrateur, pas conseiller" perimeter TRUE in code (CONTEXT WS-A,
audit 01 §5.1 / HOLE-6). Today coach_reasoner.dart:94 sorts personalised levers by return
into a ranked "top" recommendation, and get_couple_optimization computes a personalised
arbitrage — both cross from education into ranked advice while the prompt claims pure
information. Reframe these outputs to education-strict scenario comparisons with explicit
assumptions. Align the EPL/79b prose with the TF 26.02.2026 arrêts in the same pass since
the reasoner risk note carries the same under-specification.

Purpose: the founder locked education-strict, bulletproof. Ranking by "effective annual
return" is implicit advice; this plan unwires it. WS-D registry value fixes (avs 64.5) land
separately in Plan 06.
Output: unranked comparison-shaped reasoner + couple output, EPL/79b prose widened, suites green.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-CONTEXT.md
@.planning/phases/mint-etat-des-lieux-20260612/01-advice-path-audit.md
@./CLAUDE.md
@apps/mobile/lib/services/financial_core/coach_reasoner.dart

<interfaces>
Exact anchors (read in context — do NOT re-explore):
- coach_reasoner.dart:85-94 — the descending sort by annualized impact that produces the
  ranked "top" recommendation. Audit 01 HOLE-6: arbitrage_engine.dart:19 documents
  "NEVER rank options — side-by-side only", but the reasoner ranks. Remove the ranking;
  emit comparison-shaped results (stable, non-return-ordered, e.g. catalogue order).
- coach_reasoner.dart:154-168 — Recommendation for rachat: title "Rachat LPP : impact
  fiscal indicatif … CHF/an" is a ranked-to-top return claim. Reframe title/summary to an
  educational scenario-comparison phrasing with explicit assumptions (the assumptions[]
  block at :137-142 already exists — keep it, surface it as the framing, not a footnote).
- coach_reasoner.dart:144-146 — risk note "tout retrait EPL est bloqué pendant 3 ans après
  un rachat" is narrowed. Widen per audit 01 DET-2 / TF 26.02.2026: the 3-year block applies
  to EVERY capital withdrawal (retraite, départ de Suisse, indépendant, EPL) and freezes the
  ENTIRE retirement capital, not only the rachat amount.
- get_couple_optimization tool: coach_tools.py:67 (name) + :715 (definition).
  STALE-PREMISE CORRECTION (plan-check fix): the :715 description ALREADY states
  « sans ranking » — it is partially education-framed today. The target of Task 2 is the
  RESIDUAL ranked-ish language in the description/descriptor strings (e.g. « l'ordre de
  rachat LPP entre conjoints »), not a from-scratch reframe. The executor should expect a
  SMALL diff, not a rewrite.
- financial_core is L1 canonical (CLAUDE.md NEVER #3) — do NOT re-implement calculations,
  only reshape framing/ordering of the existing reasoner output.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Unrank the reasoner + reframe to scenario comparison</name>
  <files>apps/mobile/lib/services/financial_core/coach_reasoner.dart, apps/mobile/test/services/financial_core/coach_reasoner_test.dart</files>
  <behavior>
    - analyse() returns recommendations in a stable, non-return-ranked order (catalogue
      order), so no single lever is presented as "the top".
    - The rachat Recommendation title/summary reads as an educational scenario comparison
      with its assumptions surfaced ("avec ces hypothèses…"), not "impact fiscal indicatif X
      CHF/an" sorted to the top.
    - The EPL/79b risk note states: every capital withdrawal is blocked 3 years after a
      rachat, on the entire retirement capital (not only the rachat amount).
    - No banned LSFin term, no prescriptive verb in any reframed string (CLAUDE.md rule 1/5).
  </behavior>
  <action>Remove the descending sort at coach_reasoner.dart:85-94; emit results in catalogue order. Reframe the rachat title/summary (lines 154-168) to a comparison framing with explicit assumptions — keep the existing numbers (do NOT recompute — NEVER #3), only change the linguistic framing from ranked-advice to educational-comparison. Widen the :144-146 risk note per TF 26.02.2026. Use neutral design language; never "tu devrais", never "meilleur". Update coach_reasoner_test.dart: assert output order is catalogue-stable (not return-descending), assert the rachat string contains the comparison framing + widened 79b note, assert no banned term via a substring check.</action>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/financial_core/coach_reasoner_test.dart 2>&1 | tail -12</automated>
  </verify>
  <done>Reasoner emits unranked comparison output; 79b note widened; reasoner test green.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Clean residual ranked-ish language in get_couple_optimization</name>
  <files>services/backend/app/services/coach/coach_tools.py, services/backend/tests/test_coach_tools_couple_optimization.py</files>
  <behavior>
    - PREMISE (corrected by plan-check): the get_couple_optimization description
      (coach_tools.py:715 block) ALREADY says « sans ranking ». This task hunts and rewrites
      the RESIDUAL ranked-ish phrasing only (e.g. « l'ordre de rachat LPP entre conjoints »)
      in the description and any human-facing descriptor strings — expect a small diff.
    - After the pass, the description/descriptors instruct the LLM to present couple
      scenarios side-by-side with stated assumptions, with zero residual ranked/ordering
      language ("l'ordre de…", "la meilleure répartition", "tu devrais…").
    - Existing numeric computation is unchanged (L2 backend-canonical — do not move calc).
  </behavior>
  <action>Scan the get_couple_optimization definition (coach_tools.py:715) and its descriptor strings for residual ranked-ish/ordering language and rewrite only those fragments in education-strict comparison phrasing (explicit assumptions, scenarios side-by-side, no "for your couple X beats Y", no inter-spouse ordering claims). Do NOT rewrite the parts already education-framed (« sans ranking » stays). Do NOT change the numeric calculation. Update test_coach_tools_couple_optimization.py to assert the description carries education-strict comparison framing and no ranked-advice/ordering substring (incl. « l'ordre de »).</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_coach_tools_couple_optimization.py -q 2>&1 | tail -10</automated>
  </verify>
  <done>Residual ranked-ish language removed (small diff); « sans ranking » framing preserved; test green; numerics untouched.</done>
</task>

<task type="auto">
  <name>Task 3: Mobile + backend suite regression + analyze</name>
  <files>apps/mobile, services/backend</files>
  <action>Run flutter analyze + the financial_core test scope + the touched backend test scope. The reframe changes user-facing Dart strings; if any of those strings are surfaced via ARB they must go through AppLocalizations (CLAUDE.md rule 5) — confirm the reasoner strings are NOT new hardcoded user-facing UI strings outside the existing pattern (they are service-layer descriptors fed to the LLM/cards). If any NEW user-facing string was introduced, add the 6-ARB key + run flutter gen-l10n; otherwise note "no new ARB keys" in SUMMARY. Surgical: only the reframed lines change.</action>
  <verify>
    <automated>cd apps/mobile && flutter analyze 2>&1 | tail -6 && cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend && python3 -m pytest tests/test_coach_tools_couple_optimization.py -q 2>&1 | tail -4</automated>
  </verify>
  <done>flutter analyze clean on touched files; backend couple test green; ARB status noted in SUMMARY.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Reasoner/couple output → user | Personalised ranked arbitrage crossing the education perimeter |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-m1-03-01 | Elevation (perimeter breach) | coach_reasoner ranking | mitigate | Remove return-descending sort; emit unranked comparison |
| T-m1-03-02 | Information disclosure | EPL/79b narrowed risk note | mitigate | Widen to "every capital withdrawal, entire capital" per TF 26.02.2026 |
| T-m1-03-SC | Tampering | npm/pub installs | accept | No new packages; existing test runners only |
</threat_model>

<verification>
- `grep -n "results.sort" apps/mobile/lib/services/financial_core/coach_reasoner.dart` returns no descending-by-return sort (the ranking is gone).
- `grep -n "capital entier\|tout retrait en capital\|capital de prévoyance" apps/mobile/lib/services/financial_core/coach_reasoner.dart` confirms the widened 79b note.
- `cd apps/mobile && flutter test test/services/financial_core/coach_reasoner_test.dart` exits 0.
- `cd services/backend && python3 -m pytest tests/test_coach_tools_couple_optimization.py -q` exits 0.
</verification>

<success_criteria>
The reasoner output is an education-strict scenario comparison with explicit assumptions and
no ranked-advice framing, get_couple_optimization carries zero residual ranked-ish language
(small-diff pass — « sans ranking » already present), the EPL/79b prose is widened to the
TF 26.02.2026 rule, and mobile + backend touched suites are green.
</success_criteria>

<output>
Create `.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-03-SUMMARY.md` when done.
Note ARB status (no new keys vs keys added + gen-l10n run).
</output>
