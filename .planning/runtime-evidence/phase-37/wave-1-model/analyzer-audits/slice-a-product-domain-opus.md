Verification complete. Findings:

- **Regex path (`fact_extraction_fallback.dart`)**: `_firstPerson` is a `static const String`; the rewrite `_firstPerson + r"..."` → `'$_firstPerson' r"..."` is compile-time interpolation followed by adjacent-literal concatenation, producing a byte-identical pattern. The `brut`/`gross` split rewrite is a pure line-wrap. No behavioral change to fact extraction, key mapping, or bounds checks.
- **Removed imports**: `minimal_profile_models.dart` (journey tests) and `mint_text_styles.dart` (font_scaling_test) are never referenced by name — inferred locals only, so removal is analyzer-correct.
- **New `const`**: `ResponseCard`/`PremierEclairage`/`CardCta` all have `const` constructors (`response_card.dart:76,126,199`), so the microtypography test const-construction compiles.
- **Route-test regex edits** (`route_scope_leak_test.dart`, `route_doctrine_lint_test.dart`): inside triple-single-quoted strings `\"` and `"` are equivalent; the added `{ continue; }` braces are style-only. Same behavior.
- **Accent edits** (`premier eclairage` → `premier éclairage`) live only in test names/comments.

No production domain logic, routing, ledger write-back, confidence taxonomy, or compliance copy is altered by this diff.

---

Product/domain verdict: PASS

**P0** — none.

**P1** — none. This commit (`be42b9e6e`) is a pure analyzer/lint cleanup: `const` promotion, string-literal concatenation, unused-import removal, brace/format fixes, and test-comment accents. It introduces no new variable collection, no scenario/route, no threshold, and no user-facing copy change, so no Swiss-rule or source-of-truth surface is touched.

**P2**
1. `fact_extraction_fallback.dart` (touched, pre-existing): an unqualified salary number defaults to **net** (`incomeNetMonthly`/`incomeNetYearly`) when neither `brut` nor `gross` is present. Swiss users very frequently state *salaire brut* without the word "brut," so the heuristic will silently mis-tag gross income as net for downstream fiscal/prévoyance logic. Mitigated by `confidence='medium'` tagging, but worth a future disambiguation prompt rather than a default. Not introduced by this diff.
2. `future_builder_safe.dart:96-101`: last-resort error copy stays hardcoded FR behind `// lint-ignore: legacy fallback` with a `TODO(i18n)`. Acceptable as a documented stopgap; ensure the 6-locale backfill actually lands so non-FR users don't hit a French error card.

---

**Swiss domain review**
- **AVS / LPP / 3a / tax / mortgage / insurance / succession**: not affected. No constant, threshold, rente/replacement formula, canton table, or capital-vs-rente logic is modified. The `nadiaIntent = 'birth'`, `juliaIntent = 'marriage'`, etc. remain test-local persona labels feeding only persistence/routing assertions, unchanged. The 3a plafond value `7258` appears only as a static test fixture in the microtypography test and is not asserted as current law here (its correctness is owned elsewhere and out of this diff's scope).
- The fact-extraction bounds (LPP 1k–5M, 3a 100–500k, age 14–100) are unchanged and remain plausibility guards, not legal assertions.

**Mint product logic review**
- Neutral on the ledger → DataQuest → scenario → dossier spine. Nothing advances or regresses it: the ledger write path (`applySaveFact` dispatch, `_coach_*` source tagging), CapSequenceEngine step gating (`blocked`/`completed` from `CapMemory.completedActions`), and PremierEclairage selection are byte-for-byte behavior-preserved. The change is hygiene that keeps the analyzer green so future spine work isn't buried under lint noise — a legitimate but non-substantive step.

Suggested proof if you want independent confirmation: `cd apps/mobile && flutter analyze` (expect clean, per commit intent) and `flutter test test/journeys test/design_system/s0_s5_microtypography_test.dart` to confirm the const/import edits compile and pass.
