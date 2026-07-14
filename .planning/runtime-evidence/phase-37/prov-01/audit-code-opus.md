## MINT External Audit — G1-PROV-01 Field-Centric Provenance

**Scope:** unstaged worktree diff vs `efef98bca` — `coach_profile.dart`, `coach_profile_provider.dart`, two test files, `docs/data-flow.md`. ~1.4k lines, within budget.

### Verification performed
- `flutter analyze` on both changed libs → **No issues found**.
- `flutter test test/providers test/models` → **452 passed**; targeted `provenance_on_write_test.dart` (14) + `coach_profile_provider_test.dart` (54) → **all green**. Total 466 tests exercised, including the atomic cold-round-trip and fail-closed cases.
- Traced the reload path (`fromWizardAnswers` canonical/legacy merge), the write path (`mergeAnswersWithProvenance` → `_persistProvenance`), and the un-migrated tax/salary extractors.

### What holds up
- **Atomicity**: writers now persist `saveAnswers` (value + `__provenance`) *before* assigning `_profile`/`notifyListeners`; tests assert 0 notifications pre-save and 1 post-save (`provenance_on_write_test.dart:*`).
- **Fail-closed reload**: a malformed `__provenance` entry blocks same-path legacy fallback (source → null) but never affects the *value* (values derive from answer keys, not the envelope). Failing toward lower trust is the correct direction for a financial ledger (`coach_profile.dart:3187-3243`, proven by test "partial canonical envelope…").
- **Privacy**: `__provenance` is stripped from the backend payload (`coach_profile_provider.dart:_syncToBackend`, `answers.remove('__provenance')`) and carries no financial values — only `{fieldPath → source, updatedAt, sourceDate}`. Doc invariant matches code.
- **Legacy bridge**: un-migrated `updateFromTaxExtraction`/`updateFromSalaryExtraction` remain coherent because `_coach_*_source` markers + dual-written `_coach_data_timestamps` re-hydrate on the next merge (self-healing into `__provenance`). No fiscal-provenance loss across relaunch.

### Findings

**P0 — none.**

**P1 — none.**

**P2 (non-blocking)**

1. **Silent provenance facade for two debt facts.** `_answerProvenancePaths` (`coach_profile_provider.dart:~180`) maps `q_has_consumer_debt → dettes.hasDette` and `q_debt_payments_period_chf → dettes.totalMensualite`, but neither key exists in `DetteProfile.toJson()` (`coach_profile.dart:1131-1147`). `_resolvedCanonicalValue` therefore returns `null`, so these paths fall into `clearedFieldPaths` and are **never stamped** — provenance is silently not recorded for consumer-debt presence and debt-payment amounts. Metadata-only gap (the values still persist via answer keys), and untested. Repro: `mergeAnswers({'q_has_consumer_debt':'yes'})` then inspect `profile.dataSources['dettes.hasDette']` → `null`.

2. **Stale declared-net after inline gross edit.** `updateInline` was rewritten to persist `q_gross_salary_annual` instead of the previously-computed `q_net_income_period_chf` (deliberate — test "…without inventing net"). Consequence: a user with an existing declared net (`monthlyNetIncomeDeclared` non-null) who inline-edits gross salary keeps the stale net, and `toBudgetInputs()` (`coach_profile.dart:~2230`) prefers `monthlyNetIncomeDeclared ?? breakdown` — so budget "il te reste X" won't reflect the salary change. Defensible trade-off but an untested edge. Repro: seed `q_net_income_period_chf`, then `updateInline(salaireBrutMensuel: …)`, observe `toBudgetInputs().netIncome` unchanged.

Both are metadata/edge-consistency issues, not correctness/privacy/routing blockers, and no facade-without-wiring risk in the core path (the feature is fully wired and exercised end-to-end by passing round-trip tests).

### Verdict

**PASS**
