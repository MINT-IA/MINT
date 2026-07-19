I have all the evidence needed. Here is the full audit report.

---

## MINT External Audit — `codex/g1-capital-native-proof-20260718`

**Scope:** staged diff only (G1-FRESH-01 implementation slice)
**Base ref:** HEAD
**Date:** 2026-07-19

---

## Verdict: NO-GO

One confirmed P1 finding; two P2 findings. The P1 is an incomplete refactor that widens a pre-existing divergence.

---

## P1 — `extraction_review_screen.dart:_freshnessCategoryFor` not updated, divergence widens

**File:** `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:3550`

The screen owns a private copy of the category mapping that was already wrong before this diff and is made worse by it.

**Pre-existing divergence (not introduced here, but unrepaired):**

| `FactType` | `FreshnessDecayService.categoryFor` (old & new) | `_freshnessCategoryFor` (screen, unchanged) |
|---|---|---|
| `taxRate` | `annual` | `volatile` ← opposite |
| `mortgageDebt` | `volatile` | `annual` ← opposite |

**New divergence introduced by this diff:**

| `FactType` | `categoryFor` new return | `_freshnessCategoryFor` return |
|---|---|---|
| `civilStatus` | `event_static` | `annual` |
| `employmentStatus` | `event_static` | `annual` |
| `lifeEvent` | `event_static` | `annual` |
| `userDecision` | `event_static` | `annual` |
| `coachPreference` | `event_static` | `annual` |
| `alertAcknowledged` | `static` | `annual` |

**Reproduction path:**

```
apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:3237
  freshnessCategory: _freshnessCategoryFor(factType),

apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:3550-3568
  String _freshnessCategoryFor(FactType type) {
    case FactType.taxRate: return 'volatile';   // ← 3-month decay; canonical = annual (12-month)
    case FactType.mortgageDebt: return 'annual'; // ← 12-month decay; canonical = volatile (3-month)
    case FactType.civilStatus: ...              // ← 'annual' decay; canonical = 'event_static' (no decay)
    ...
  }
```

Any `BiographyFact` created during document scan extraction gets the wrong tier. `taxRate` facts from scan decay 4× faster than facts written through any other path. `mortgageDebt` from scan decays 4× slower. This is a code-path inconsistency that the diff should have repaired. The fix is one line: replace `_freshnessCategoryFor(factType)` with `FreshnessDecayService.categoryFor(factType)` and delete the private copy.

---

## P2-A — Existing on-disk `BiographyFact` records not migrated to new tiers

**File:** `apps/mobile/lib/services/biography/biography_repository.dart:137` (`freshnessCategory TEXT DEFAULT 'annual'`)

Facts for `FactType.civilStatus`, `.employmentStatus`, `.lifeEvent`, `.userDecision`, `.coachPreference` stored on upgraded devices carry `freshnessCategory='annual'` from prior writes. The new `weight()` function correctly handles stored `'annual'` via `_tierFromWireName` → decay applies. New writes of the same types get `'event_static'` → no decay. The two paths are semantically divergent for the same field type until a fact is rewritten. `BiographyRepository` is narrative history only and does not override the canonical profile, so this has no ledger correctness impact, but it causes inconsistent freshness scores in biography views.

No migration step is implemented. If that is intentional (BiographyFacts are append-only event records), document it. If not, a migration read pass converting stored `'annual'` to `'event_static'`/`'static'` for the affected types is needed.

---

## P2-B — `BiographyFact` default `freshnessCategory` unchanged

**File:** `apps/mobile/lib/services/biography/biography_fact.dart:89`

```dart
this.freshnessCategory = 'annual',
```

Any direct `BiographyFact(...)` instantiation that does not pass `freshnessCategory` gets `'annual'`, regardless of fact type. New callers relying on the constructor default for event-static or static types will silently get annual decay. The correct call pattern is `freshnessCategory: FreshnessDecayService.categoryFor(factType)`. No static lint enforces this.

---

## Clean items (verified)

| Item | Status |
|---|---|
| `annualNeedsRefresh` deletion | Clean — zero callers in `lib/` or `test/` source (`grep` confirmed; only stale `.dill` build artifacts matched) |
| `ledgerFieldPolicies` vs matrix | Exact 61-path match — programmatic cross-check confirmed no tier or source-set divergence |
| `specialistReferencePaths` vs matrix | Exact 4-path match |
| `_MemoryProfilePersistence` interface satisfaction | Clean — `SerializedCanonicalAnswerMutationPersistence` mixin provides `inspectAnswers`+`mutateAnswers`; the test class supplies `loadAnswers`+`saveAnswers`; all abstract members of `TaxProfilePersistence`, `LppProfilePersistence` and `CanonicalAnswerMutationPersistence` are covered |
| Matrix file reachability | File present at `.planning/goals/G1-ledger-gap-matrix.md`; relative paths in the test (`../../` from `apps/mobile/`) resolve correctly |
| Day-boundary arithmetic (782/783, 247/248) | Verified — annual threshold = 782.74 days; volatile = 247.87 days; the test fixtures are tight and correct |
| `mergeAnswersWithProvenance` signature | Exists in `CoachProfileProvider` with `source`/`sourceDate` params matching test usage |
| `frontierJurisdictionAt` semantic equivalence | Confirmed — `eventStatic` never decays, so `residenceCountry`/`workCountry` behave identically to the old check; `workCanton` stale boundary is preserved |
| `assessLedgerField` future-timestamp guard | Correctly fails closed (`_floor`) for `updatedAt.isAfter(now)` before any tier lookup |
| G1-FRESH-01 ticket still `ticket_only` | Correct — diff does not claim promotion |

---

## Required fix before promotion

Replace `_freshnessCategoryFor` in `extraction_review_screen.dart:3237` with the canonical service:

```dart
// extraction_review_screen.dart:3237
freshnessCategory: FreshnessDecayService.categoryFor(factType),
```

Then delete the private `_freshnessCategoryFor` method (lines 3548–3569). The corresponding test (`freshness_decay_test.dart`) already covers all `FactType` variants.
