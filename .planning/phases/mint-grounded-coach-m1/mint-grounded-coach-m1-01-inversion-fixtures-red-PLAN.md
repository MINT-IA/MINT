---
phase: mint-grounded-coach-m1
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - services/backend/tests/fixtures/inversions_eval.jsonl
  - services/backend/tests/test_coach_claim_inversions.py
autonomous: true
requirements: [WS-E, WS-B]
must_haves:
  truths:
    - "An eval fixture set exists that encodes the rachat-inversion + the top-class of Swiss assertion inversions"
    - "The fixtures run RED against the current coach output path (deterministic proof the hole exists)"
    - "The RED proof is captured as a committed test artifact, not a transient log"
  artifacts:
    - path: "services/backend/tests/fixtures/inversions_eval.jsonl"
      provides: "Inversion eval cases (subject/relation/object + known_inversion strings)"
      min_lines: 15
    - path: "services/backend/tests/test_coach_claim_inversions.py"
      provides: "Deterministic scorer that asserts RED today, GREEN after the claim-checker lands"
  key_links:
    - from: "test_coach_claim_inversions.py"
      to: "services/backend/tests/fixtures/inversions_eval.jsonl"
      via: "fixture loader"
      pattern: "inversions_eval\\.jsonl"
---

<objective>
Write the inversion eval fixtures and a deterministic scorer, and PROVE RED against the
current coach output path. This is the fixture-first gate (CONTEXT decision 3): the
"rachat-inversion" case and the top-class of Swiss assertion inversions must fail against
the coach as it exists today, with a committed deterministic artifact, BEFORE any fix lands.

Purpose: a regression test that would have caught WTF-W1-01 (coach defined "rachat" as a
withdrawal). No fix is trustworthy until this fixture set is RED first, then GREEN later.
Output: `inversions_eval.jsonl` (≥15 cases) + `test_coach_claim_inversions.py` proven RED.
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
Existing fixture format to mirror (do NOT modify these files):
- services/backend/tests/fixtures/citation_gate_eval_50.jsonl — JSONL, one case per line
- services/backend/tests/test_coach_doctrine_eval.py — fixture-loader + deterministic scorer pattern

The hole being proven (audit 01 §HOLE-1, audit 04 §P0):
- The live guard is ComplianceGuard.validate() (compliance_guard.py:355). It inspects banned
  terms (L1), prescriptive patterns (L2), numeric hallucinations (L3). NONE inspect the
  MEANING of a definitional sentence. A sentence with no number and no banned word passes
  every layer. The "rachat = retirer ton capital" inversion is exactly this class.
- There is no claim-checker module today. `grep -rn "explain_concept" services/backend` → 0 hits.

Ground truth for the rachat assertion (audit 01 §HOLE-1, W1-cadre-50 WTF-W1-01):
- CANONICAL: "un rachat LPP = verser de l'argent DANS la caisse (déductible, LPP art. 79b)"
- KNOWN INVERSION (must be detected as wrong): any sentence asserting rachat = "retirer",
  "retrait", "sortir", "récupérer" son capital / argent du 2e pilier.

FIXTURE-STRING HYGIENE (load-bearing for the RED proof — plan-check fix):
- Every fixture string (question_fr, canonical_relation_fr, known_inversions,
  forbidden_substrings, and any synthetic test sentence built from them) must contain NO
  ComplianceGuard L1 banned term (BANNED_TERMS, compliance_guard.py:43-117, incl. the
  "certain"-guarantee patterns) and NO L2 prescriptive pattern (PRESCRIPTIVE_PATTERNS,
  compliance_guard.py:238-276). Rationale: Plan 02 makes L1/L2 blocking; a fixture string
  that trips L1/L2 would be blocked for the WRONG reason, flipping the xfail-strict cases
  to XPASS and breaking the suite. The RED proof must isolate the DEFINITIONAL hole only.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Author the inversion eval fixture set</name>
  <files>services/backend/tests/fixtures/inversions_eval.jsonl</files>
  <behavior>
    - ≥15 JSONL cases, one per line, each a (subject, relation, object) triple of a Swiss
      financial assertion plus the canonical truth and ≥1 known-inversion string.
    - Case 1 is the exact rachat-inversion (W1 Exhibit A): subject="rachat_lpp",
      canonical="versement dans la caisse / déductible", known_inversions include
      "retirer", "retrait", "sortir le capital", "récupérer ton argent".
    - Cover the top-class concepts from CONTEXT WS-B: rachat, EPL, splitting,
      bonifications, pilier 3a, pilier 3b, taux de conversion, lacunes, rente vs capital,
      coordination LPP, libre passage, frontalier, FATCA — each with its canonical relation
      and ≥1 plausible inversion an LLM could emit.
    - Each line schema: {"id","concept_key","question_fr","canonical_relation_fr",
      "known_inversions":[...],"forbidden_substrings":[...]} — deterministic, no LLM-judge fields.
    - Fixture-string hygiene (see interfaces): NO L1 banned term, NO L2 prescriptive
      pattern in ANY fixture string — guaranteed by construction, so Plan 02's hardening
      cannot flip the xfail-strict cases to XPASS.
  </behavior>
  <action>Create the JSONL fixture mirroring the line-per-case format of citation_gate_eval_50.jsonl. forbidden_substrings is the deterministic scorer hook: substrings that, if present in coach output for that question, prove an inversion (e.g. for rachat: "retirer ton capital", "retrait du 2e pilier"). All strings FR with correct accents (per CLAUDE.md rule 2). No banned LSFin terms in canonical strings (per CLAUDE.md rule 1 / 5). While authoring, run every fixture string through ComplianceGuard._check_banned_terms and _check_prescriptive and rewrite any string that trips them — the inversion must be expressible in guard-neutral French (e.g. "un rachat c'est retirer ton capital" trips neither L1 nor L2).</action>
  <verify>
    <automated>cd services/backend && python3 -c "import json,pathlib; ls=[json.loads(l) for l in pathlib.Path('tests/fixtures/inversions_eval.jsonl').read_text().splitlines() if l.strip()]; assert len(ls)>=15, len(ls); assert any(c['concept_key']=='rachat_lpp' for c in ls); assert all({'id','concept_key','question_fr','canonical_relation_fr','known_inversions','forbidden_substrings'} <= set(c) for c in ls); print('OK', len(ls))"</automated>
  </verify>
  <done>≥15 valid JSONL cases load; rachat_lpp case present; schema complete on every line; every fixture string guard-neutral (no L1/L2 hit).</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Deterministic scorer + PROVE RED against current coach</name>
  <files>services/backend/tests/test_coach_claim_inversions.py</files>
  <behavior>
    - A pytest module that loads inversions_eval.jsonl and, for each case, runs the coach
      output through the SAME guard the live path uses (ComplianceGuard.validate) and a new
      deterministic inversion-scorer (substring-based, no LLM judge — per CLAUDE.md §9).
    - The scorer FAILS a case when an output containing a known forbidden_substring is NOT
      flagged by any guard layer (proving the hole). It PASSES when the inversion is caught.
    - Tests are PER-CASE parametrized (pytest.mark.parametrize over the fixture ids) so each
      inversion case is an individually reported test item.
    - A dedicated HYGIENE self-test asserts, per fixture string, that
      ComplianceGuard._check_banned_terms and _check_prescriptive return NO hit on the
      fixture strings themselves — guaranteeing the xfail RED proof isolates the
      definitional hole and that Plan 02's L1/L2 hardening cannot flip cases to XPASS.
    - Includes one test parametrized over the fixtures that feeds each case's
      known-inversion text through ComplianceGuard.validate() and asserts (TODAY, RED) that
      the guard returns is_compliant=True / use_fallback=False on an inverted definition —
      i.e. the guard does NOT catch it. Mark this assertion with the RED→GREEN flip note.
    - Provide a second test (xfail today, strict) named test_inversions_are_blocked that
      asserts the guard SHOULD block the inversion. It is xfail-strict now (RED proof) and
      flips to passing once Plan 04 wires the claim-checker into ComplianceGuard.
  </behavior>
  <action>Use pytest.mark.xfail(strict=True, reason="RED proof — claim-checker not yet wired, Plan 04 flips this") on the "should be blocked" test so CI is GREEN today (xfail counts as expected) while the artifact records the deterministic RED proof. Parametrize per fixture id. Add the hygiene self-test (every fixture string guard-neutral on L1/L2). Do NOT call the live Anthropic API — feed the fixture's known-inversion string directly into ComplianceGuard.validate() as if it were LLM output. This isolates the guard hole deterministically and runs in <5s. Capture the RED proof in the SUMMARY by pasting the `pytest -rx` xfail line showing test_inversions_are_blocked XFAIL.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_coach_claim_inversions.py -q -rx 2>&1 | tail -20</automated>
  </verify>
  <done>Suite is GREEN (xfail-strict records the RED proof); `pytest -rx` shows test_inversions_are_blocked as XFAIL with the rachat inversion in the report; the hygiene self-test passes per fixture string. The committed test is the deterministic artifact CONTEXT decision 3 requires.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| LLM coach output → user | Untrusted generated text crosses into a financial-education surface; meaning is unverified |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-m1-01-01 | Information disclosure (mis-information) | ComplianceGuard definitional blind spot | mitigate | This plan proves the gap deterministically (RED) so Plan 04's claim-checker has a regression anchor |
| T-m1-01-SC | Tampering | pip installs | accept | No new packages installed (uses stdlib json + existing pytest). No package legitimacy gate needed. |
</threat_model>

<verification>
- `cd services/backend && python3 -m pytest tests/test_coach_claim_inversions.py -q` exits 0 (xfail-strict GREEN).
- The xfail report names the rachat inversion (deterministic RED proof captured in SUMMARY).
- The hygiene self-test (fixture strings guard-neutral on L1/L2) passes.
- No production code modified in this plan (test + fixture only) — `git diff --name-only` lists only the two files under tests/.
</verification>

<success_criteria>
The inversion fixture set exists (≥15 cases incl. rachat_lpp, every string guard-neutral on
L1/L2 by construction and by self-test), the deterministic per-case-parametrized scorer
records the guard's definitional blind spot as a strict-xfail RED proof, and the suite is
GREEN so it can be wired into CI now and flipped to a hard pass by Plan 04.
</success_criteria>

<output>
Create `.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-01-SUMMARY.md` when done.
Paste the `pytest -rx` xfail line for test_inversions_are_blocked as the deterministic RED citation.
</output>
