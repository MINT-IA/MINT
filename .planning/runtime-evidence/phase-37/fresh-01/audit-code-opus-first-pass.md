Verification complete. Let me record the final evidence check on the two behavior-change surfaces (dead method + `weight` semantics) before ruling.

The frontier regression suite is green (`All tests passed!` at +23), and the FRESH-01 gate is 30/30. I have enough to rule.

---

# MINT External Audit — G1-FRESH-01 (`stale_reconfirmation_test`)

**Audit mode:** code · **Base ref:** HEAD · **Scope:** staged worktree diff (freshness adapter + frontier consumer rewire + registry docs)

## Verdict: **PASS**

Scoped, honestly-labeled `ticket_only` slice. The freshness adapter is real, the one production consumer (`frontierJurisdictionAt`) is genuinely rewired to it, and I reproduced GREEN on the ticket command plus the frontier regression suite. No P0/P1.

## What I verified (not trusting docs)

| Claim | Evidence |
|---|---|
| FRESH-01 gate passes | Ran `stale_reconfirmation_test.dart` + `freshness_decay_test.dart` → **30/30 passed** |
| Registry = exact 61-path projection | Manually counted `ledgerFieldPolicies` = 61 entries; `hasLength(61)` parity test derives from `.planning/goals/G1-ledger-gap-matrix.md` (file exists, header at line 126) and passes |
| Source strings match enum | `ProfileDataSource` = {estimated, userInput, crossValidated, certificate, openBanking} (`coach_profile.dart:97-103`); `.name` matches every `allowedSourceNames` token |
| 782/783 & 247/248 boundaries | Verified analytically against `_decay` math; matches the frozen boundary claim |
| Frontier consumer no regression | `frontierJurisdictionAt` rewrite (`coach_profile.dart:3686`) preserves the prior known/missing/stale predicate (source-allow + non-future-timestamp + `dataSourceDates` slot all retained); `frontier_canonical_fields_test` + persistence test **passed** |
| Model-free / synchronous adapter | Source contains no `models/coach_profile.dart` import and no `Future<` (test-enforced + confirmed) |
| Honest status | G1-FRESH-01 row remains `ticket_only`; registry still declares G2 = NO |

## Findings

**P0 — none.**

**P1 — none.**

**P2 (non-blocking):**
1. **Dead production method.** `FreshnessDecayService.annualNeedsRefresh` (`freshness_decay_service.dart:464`) has zero `lib/` callers after the frontier switch to `assessLedgerField` — grep confirms only its definition remains. Retained for tests/back-compat; recommend removal or a comment.
2. **Silent behavior change to existing `weight(BiographyFact)` consumers.** The refactor now floors unknown `freshnessCategory` and **future-dated** facts at 0.3 (previously future dates returned 1.0 via `_decay`, and non-`volatile`/unknown categories decayed as annual). This shifts the fresh/stale partition in `biography_provider.dart:78/86`, `fact_card.dart:46`, and `anonymized_biography_service.dart:72/97`. Behavior is defensible (future = suspect; all real categories from `categoryFor` are handled), but no test covers the unknown-category → floor path. Add a regression test if this consumer matters.
3. **Facade-adjacent breadth, but disclosed.** 58 of 61 registry policies are not consumed by any production code path — only the 3 frontier paths flow through `assessLedgerField`. This is explicitly deferred to G2 UI in `DATA_LEDGER.md §5.1/§5.2` and the ticket is `ticket_only`, so it is honest scoped debt, not a completion overclaim.

## Reproduction commands
```
cd apps/mobile && flutter test test/services/biography/stale_reconfirmation_test.dart test/services/biography/freshness_decay_test.dart --reporter expanded   # 30/30
cd apps/mobile && flutter test test/models/frontier_canonical_fields_test.dart test/providers/frontier_jurisdiction_persistence_test.dart                      # green, no regression
```

No correctness, privacy, compliance, routing, or facade-without-wiring defect rises to P0/P1. The frontier consumer is really wired; the deferred surface is disclosed and the ticket is not claimed complete.
