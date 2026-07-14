---

## MINT Audit — G1-PROV-01 Field-Centric Provenance

**Base ref:** `efef98bca`
**Scope:** 5 modified files, provenance envelope + atomicity refactor

---

### Verdict: **NO-GO**

Two scan writers were not migrated to the new G1-PROV-01 pattern while the rest of the codebase now expects `__provenance` to be the authoritative source for field metadata.

---

## P1 Findings

### P1-1 — `updateFromTaxExtraction` not migrated: publish-before-save, no `__provenance`, stale `_lastAnswers`

**File:** `apps/mobile/lib/providers/coach_profile_provider.dart:2367`

**Reproduction:**
1. User scans LPP certificate → `__provenance` is written (migrated writer).
2. User then scans tax declaration → `updateFromTaxExtraction` runs.
3. At line 2367, `_profile = p.copyWith(dataSources: updatedSources, ...)` — in-memory mutation happens **before** the first `await` at line 2374.
4. `_persistProvenance` is **never called** — `__provenance` in SharedPreferences retains only the LPP entries.
5. `_lastAnswers` is **never updated** — `_syncToBackend()` (fire-and-forget) sends stale answers without fiscal facts.

**Effect on cold reload:** After the LPP scan has written `__provenance`, `hasCanonicalProvenance = true` for all future `fromWizardAnswers` calls. `effectiveSources` excludes legacy paths that are in `canonicalMentionedPaths`. Fiscal paths are not mentioned in `__provenance`, so they fall back to legacy `restoredDataSources`. This currently works via `_coach_tax_source == 'document_scan'` migration, but the arrangement is fragile: a single LPP or AVS write that happens to mention any fiscal path would silently block the legacy fallback for it (fail-closed design, §canonical envelope, docs line ~78).

**No test coverage.** `provenance_on_write_test.dart` has no case for `updateFromTaxExtraction`. The gap is undetected.

---

### P1-2 — `updateFromSalaryExtraction` not migrated: same three defects plus unreachable field paths

**File:** `apps/mobile/lib/providers/coach_profile_provider.dart:2455`

Same pre-publish mutation (line 2455), no `_persistProvenance`, no `_lastAnswers` update.

**Additional defect:** Salary extraction writes `q_monthly_gross_salary_chf`, `q_salary_months`, `q_bonus_percentage` — none of these are in `_answerProvenancePaths` (provider line 152–224). Salary certificate data therefore **can never reach `__provenance`** through any code path. Even if the method were migrated, the canonical paths for these facts would need to be added to the lookup table first.

**No test coverage.**

---

## P2 Findings

### P2-1 — `_resolvedCanonicalValue` calls `profile.toJson()` once per field path

**File:** `coach_profile_provider.dart:260`

```dart
dynamic value = profile.toJson();   // full serialization every call
```

Called from both the `clearedFieldPaths` and `stampedFieldPaths` compressions inside `mergeAnswersWithProvenance`, once per entry in `touchedPaths ∪ requestedStamps`. For a DataBlock enrichment batch (15+ fields) this is ~30 full profile serializations in one merge. Acceptable at current scale; should be memoized if batch writes grow.

### P2-2 — `_persistProvenance` silently drops `dataSources` entries without a matching `dataTimestamps` entry

**File:** `coach_profile_provider.dart:303–311`

```dart
final updatedAt = profile.dataTimestamps[entry.key];
if (updatedAt == null) continue;     // silent drop
```

Legacy profiles hydrated before S47 may carry `dataSources` entries (from `_resolveDataSources` inference) with no corresponding `dataTimestamps`. On the first write after this PR, those entries vanish from `__provenance` without log or fallback. The legacy migration in `fromWizardAnswers` still reconstructs them, but silently losing them from `__provenance` on first write violates the fail-closed contract.

### P2-3 — Double source-booking in `updateFromAvsExtraction` and `updateFromOpenBanking`

Both writers manually populate `updatedSources` with source labels, pass `updatedSources` via `copyWith` into `valueProfile`, and then `_withStampedProvenance` overwrites the same fields with the same label again. The two layers now own the same responsibility; future maintainers editing one without the other will introduce silent divergence.

---

## What's Correct

- `dataSourceDates` field: constructor, `copyWith`, `fromJson`, `toJson`, default `const {}` — all consistent.
- `inferDataSources: false` in `copyWith` correctly bypasses `_resolveDataSources` on round-trips.
- `fromWizardAnswers` canonical envelope parsing fails closed: a malformed entry (present `sourceDate` key that is non-null but unparseable) skips the path **and blocks legacy fallback for that same path** — matches the spec.
- `_syncToBackend` strips `__provenance` before POST — correct local-only isolation.
- Save-before-publish atomicity is correctly enforced in `mergeAnswersWithProvenance`, `updateFromLppExtraction`, `updateFromAvsExtraction`, `updateFromOpenBanking`, `updateInline`.
- The RAMD source change in `coach_profile_provider_test.dart:637` from `estimated` → `certificate` is **correct**: `_withStampedProvenance` + `__provenance` now wins over `_resolveDataSources`'s downgrade; the test name ("cannot certify unrelated values") remains accurate because only RAMD was explicitly extracted.
- All new `provenance_on_write_test.dart` tests (atomicity, cold round-trip, null sourceDate slot, clearing, malformed partial envelope, source date propagation) are structurally sound and pass with the migrated writers.

---

## What Must Change Before PASS

| # | File | Required action |
|---|---|---|
| 1 | `coach_profile_provider.dart:2302` | Migrate `updateFromTaxExtraction` to save-before-publish + `_persistProvenance` + `_lastAnswers` update — identical pattern to `updateFromLppExtraction`. |
| 2 | `coach_profile_provider.dart:2403` | Migrate `updateFromSalaryExtraction` to same pattern; add `q_monthly_gross_salary_chf` / `q_salary_months` / `q_bonus_percentage` (or their canonical equivalents) to `_answerProvenancePaths`. |
| 3 | `provenance_on_write_test.dart` | Add `_expectAtomicColdRoundTrip` coverage for `updateFromTaxExtraction` (`fiscal.tauxMarginal`, `ProfileDataSource.certificate`) and `updateFromSalaryExtraction` (`salaireBrutMensuel`, `ProfileDataSource.certificate`). |
