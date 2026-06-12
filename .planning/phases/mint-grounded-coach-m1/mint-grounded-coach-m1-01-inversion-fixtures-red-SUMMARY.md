---
phase: mint-grounded-coach-m1
plan: 01
subsystem: coach-eval-harness
tags: [eval, compliance-guard, claim-checker, red-proof, tdd, lsfin]
requires:
  - "ComplianceGuard.validate() (compliance_guard.py:355) — the only live coach guard"
  - "citation_gate_eval_50.jsonl line-per-case format (mirrored, not modified)"
provides:
  - "inversions_eval.jsonl — 18 Swiss-assertion inversion cases (subject/relation/object + known_inversions + forbidden_substrings)"
  - "test_coach_claim_inversions.py — deterministic per-case scorer + strict-xfail RED proof of the definitional blind spot"
  - "regression anchor for Plan 04 claim-checker (xfail flips to PASS when wired)"
affects:
  - "Plan 02 (L1/L2 blocking hardening) — guaranteed not to flip these xfail cases to XPASS (hygiene self-test)"
  - "Plan 04 (claim-checker wiring) — owns the RED→GREEN flip; must delete xfail marker + RED-reality test"
tech-stack:
  added: []
  patterns:
    - "Deterministic substring scorer (no LLM judge, CLAUDE.md §9)"
    - "pytest.mark.xfail(strict=True) as committed RED proof artifact"
    - "Fixture-string hygiene by construction + self-test (guard-neutral on L1/L2)"
key-files:
  created:
    - services/backend/tests/fixtures/inversions_eval.jsonl
    - services/backend/tests/test_coach_claim_inversions.py
  modified: []
decisions:
  - "RED proof encoded as xfail-strict so CI is GREEN today while the artifact records the hole deterministically"
  - "Two redundant tripwires: test_inversions_are_blocked (xfail, the contract) + test_guard_passes_inversion_today (passing, documents today's behaviour) — both deleted by Plan 04"
  - "No production code modified — fixture + test only (verification criterion)"
metrics:
  duration: "~1 turn (single sequential session)"
  completed: 2026-06-12
  tasks: 2
  files: 2
---

# Phase mint-grounded-coach-m1 Plan 01: Inversion Fixtures RED Summary

Deterministic, committed RED proof that the live coach guard (`ComplianceGuard.validate`) ships an inverted Swiss financial definition — e.g. "un rachat LPP = sortir ton capital" — unflagged, because every guard layer is lexical/numeric and none inspect a sentence's meaning. 18 guard-neutral inversion fixtures + a per-case strict-xfail scorer anchor the regression that would have caught WTF-W1-01, with the full backend suite still green.

## What Was Built

- **`services/backend/tests/fixtures/inversions_eval.jsonl`** — 18 JSONL cases (≥15 required), one per line, mirroring the line-per-case format of `citation_gate_eval_50.jsonl`. Each case = `{id, concept_key, question_fr, canonical_relation_fr, known_inversions[], forbidden_substrings[]}`. Case 1 is the exact device-proven rachat-inversion (`inv-01-rachat-lpp`, Exhibit A / WTF-W1-01). Coverage of the CONTEXT WS-B top-class concepts: rachat LPP, EPL, rente vs capital imposition, pilier 3a/3b, taux de conversion, lacunes, coordination LPP, libre passage, splitting AVS, bonifications de vieillesse, frontalier, FATCA, EPL-blocage-3-ans (TF 26.02.2026), AVS âge femmes 2026, déductibilité du rachat, retrait 3a.

- **`services/backend/tests/test_coach_claim_inversions.py`** — deterministic, no-LLM scorer (`output_contains_inversion` substring hook + `guard_flags` over `ComplianceGuard.validate`) with:
  - `test_inversions_are_blocked` — **per-case parametrized, `xfail(strict=True)`** — the CONTRACT (guard SHOULD block the inversion). RED proof today; flips to PASS when Plan 04 wires the claim-checker.
  - `test_guard_passes_inversion_today` — per-case, **passing** test documenting today's behaviour: the guard returns `is_compliant=True / use_fallback=False` on every inverted definition. A second tripwire that starts failing the day the hole closes.
  - `test_fixture_strings_are_guard_neutral` — per-case HYGIENE self-test: every fixture string trips NEITHER L1 banned-terms NOR L2 prescriptive patterns, so Plan 02's L1/L2 hardening cannot flip the xfail cases to XPASS for the wrong reason.
  - Integrity tripwires: ≥15 cases, `rachat_lpp` present, schema complete, every `forbidden_substring` lives inside a `known_inversion` (no dead scorer hooks).

## The RED Proof (deterministic citation)

Per-case xfail for the device-proven rachat case (`pytest -rx`):

```
XFAIL tests/test_coach_claim_inversions.py::test_inversions_are_blocked[inv-01-rachat-lpp] - RED proof — claim-checker not yet wired; Plan 04 flips this to PASS
```

Module run (`python3 -m pytest tests/test_coach_claim_inversions.py -q -rx`):

```
57 passed, 18 xfailed, 1 warning in 0.27s
```

All 18 `test_inversions_are_blocked[...]` items are XFAIL (expected failure = green CI), encoding the definitional blind spot as a committed artifact. Direct guard probe of the rachat inversion (manual confirmation during authoring): `ComplianceGuard.validate("Un rachat LPP, c'est sortir ton capital du 2e pilier avant l'heure.")` → `is_compliant=True, use_fallback=False, violations=[]` — the inversion reaches the user unflagged (audit 01 §HOLE-1 / audit 04 §P0).

## Full Backend Suite (no regression)

```
7643 passed, 116 skipped, 22 xfailed, 6 warnings in 92.12s (0:01:32)
```

The 22 xfailed = the 18 new inversion cases + 4 pre-existing. No failures, no errors. `git diff --name-only` for this plan lists only the two files under `tests/` — no production code modified (matches plan verification).

## Tasks Completed

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Author inversion eval fixture set (18 cases) | `62bdcb25d` | services/backend/tests/fixtures/inversions_eval.jsonl |
| 2 | Deterministic scorer + PROVE RED (xfail-strict) | `610c23eca` | services/backend/tests/test_coach_claim_inversions.py |

## Deviations from Plan

None — plan executed exactly as written. One in-flight fixture-string fix applied during authoring (Task 1, before commit, not a post-commit deviation): the `question_fr` of `inv-04-capital-imposition` originally read "Et si je prends le capital, c'est imposé comment ?" which tripped the L2 prescriptive pattern `prends?\s+le\s+capital`; rewritten to "Et le versement en capital de la prévoyance, c'est imposé comment ?" to honour the fixture-string hygiene constraint. All 112 fixture strings across 18 cases are now guard-neutral (verified by self-test).

## Threat Model Coverage

- **T-m1-01-01** (definitional blind spot, disposition `mitigate`): this plan proves the gap deterministically (RED) so Plan 04's claim-checker has a regression anchor. Satisfied — the strict-xfail RED proof is the anchor.
- **T-m1-01-SC** (pip-install tampering, disposition `accept`): no new packages installed — stdlib `json` + existing `pytest` only. No package-legitimacy gate needed.

## Known Stubs

None. The fixture is fully populated (18 cases, no placeholder/empty values) and the scorer is fully wired to the fixture loader. The xfail-strict cases are an intentional, documented RED proof (not a stub) — Plan 04 owns the flip to GREEN.

## Notes for Plan 04 (RED→GREEN flip)

When the deterministic claim-checker is wired into `ComplianceGuard`, two coupled removals are required in `test_coach_claim_inversions.py`:
1. Delete the `@pytest.mark.xfail(strict=True, ...)` marker on `test_inversions_are_blocked` (strict-xfail will otherwise turn the now-passing test into an XPASS-as-failure).
2. Delete (or invert) `test_guard_passes_inversion_today`, which will start failing once the guard begins flagging inversions.
Both are documented inline in the test module docstrings.

## Self-Check: PASSED

- FOUND: services/backend/tests/fixtures/inversions_eval.jsonl
- FOUND: services/backend/tests/test_coach_claim_inversions.py
- FOUND: .planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-01-inversion-fixtures-red-SUMMARY.md
- FOUND commit: 62bdcb25d (Task 1 — fixture)
- FOUND commit: 610c23eca (Task 2 — scorer + RED proof)
