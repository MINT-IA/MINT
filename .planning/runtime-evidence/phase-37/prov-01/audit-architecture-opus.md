I have enough evidence. Let me do a final confirmation that the "publish before save" ordering in the two non-migrated writers has no intervening `await` (making `_profile` observable as unsaved) — already visible in the reads: tax assigns `_profile` at 2369, `saveAnswers` at 2398; partner at 2116 vs 2132. Both skip `_persistProvenance`.

I now have a complete picture. Here is the audit.

---

# MINT External Audit — Architecture Mode

**Phase under audit:** G1-PROV-01 — field-centric provenance-on-write for `CoachProfile` / `coach_profile_provider.dart`, documented in `docs/data-flow.md`.

## What I verified (source of truth = code + tests)

- Ran `flutter test test/providers/provenance_on_write_test.dart` → **17/17 pass**; full `test/providers/` → **170/170 pass**.
- `flutter analyze` on both changed files → **no issues**.
- The **6 migrated writers** (`mergeAnswers`/`mergeAnswersWithProvenance`, `updateFromLppExtraction`, `updateFromAvsExtraction`, `updateFromSalaryExtraction`, `updateFromOpenBanking`, `updateInline`) correctly `await saveAnswers()` **before** assigning `_profile` / `notifyListeners()`. Tests assert `notifications == 0` and unchanged value before the await, `== 1` after — the atomicity claim holds for these paths.
- Canonical `__provenance` shape `{source, updatedAt, sourceDate}` is enforced; fail-closed reconstruction (malformed canonical entry blocks same-path legacy fallback) is proven by `partial canonical envelope falls back field-by-field and fails closed`.
- **Privacy:** `__provenance` is stripped from the backend sync payload (`coach_profile_provider.dart:395`), and the envelope carries no financial values by design. No leak found. Backend sends `wizardAnswers` only; `dataSourceDates` in `toJson()` is not on the sync path.

## Findings

### P0
None. No data-corruption, privacy leak, or routing break proven. The migrated write path is correct and tested.

### P1
**P1-1 — Documented write invariant is contradicted by two wired writers (doc-vs-code drift on a durability invariant).**
`docs/data-flow.md` §3 states the invariant universally: *"A writer … including an extraction writer … must persist the answer values and their provenance in one `ReportPersistenceService.saveAnswers()` snapshot **before** assigning `_profile` or calling `notifyListeners()`. Never publish an in-memory value that has not been durably saved."* The writer table row 3 restates it: scan confirmation writers *"publish only after `saveAnswers()`."*

Two **wired** scan-confirmation writers violate this:
- `updateFromTaxExtraction` — assigns `_profile = p.copyWith(...)` at `coach_profile_provider.dart:2369`, then `saveAnswers()` at `:2398`; it never calls `_persistProvenance` (method body `:2304–2403`).
- `updateFromPartnerLppExtraction` — assigns `_profile` at `:2116`, then `saveAnswers()` at `:2132`; no `_persistProvenance`.

Both are reachable: `extraction_review_screen.dart:696` (tax) and `:689` (partner LPP).

Reproduction / code path: scan a tax certificate → `updateFromTaxExtraction` publishes `_profile` with `fiscal.* = certificate` **before** persistence. If `saveAnswers()` throws at `:2398`, `_profile` already holds unsaved state and the exception propagates (no try/catch), so on next launch disk and memory diverge — exactly the failure class this phase claims to eliminate. Fix: either migrate both writers to the `_withStampedProvenance` + `_persistProvenance` + save-before-publish pattern, or narrow the doc claim to the migrated writers and register tax/partner-LPP as explicit pending debt.

### P2
**P2-1 — `dataSourceDates` / `sourceDate` is captured, persisted, round-tripped and reconstructed, but has no reader (facade-without-wiring risk).** Grep across `apps/mobile/lib` shows only model + provider write/round-trip usages; no freshness/decay/PDF/UI consumer reads `dataSourceDates`. The whole value of `sourceDate` vs `updatedAt` (document age vs save time) is not delivered by any downstream logic. `docs/data-flow.md` covers the *backend* side ("pending its dedicated contract") but not the absence of a **local** consumer. Register an explicit consumer or a dated pending item per MINT's "service with no caller" anti-pattern.

**P2-2 — Partner-LPP certificate provenance is not durable across cold reload.** `updateFromPartnerLppExtraction` sets `conjoint.prevoyance.*` = `certificate` in memory and writes `_coach_conjoint_lpp_source='document_scan'` (`:2131`), but that marker is never read: no legacy reconstruction block for `conjoint.prevoyance.*` exists (grep on `coach_profile.dart` finds only static field-path constants), and the writer doesn't emit `__provenance`. So after restart the spouse LPP source silently downgrades. Pre-existing, but inside the phase's stated goal.

**P2-3 — Fiscal fields bypass the "canonical envelope is source of truth" design.** `updateFromTaxExtraction` still uses the legacy `_stampTimestamps`/`updatedSources` pattern; fiscal provenance survives reload only via `_coach_tax_source` legacy inference (`coach_profile.dart:3312–3328`), never through `__provenance`. No test exercises tax provenance-on-write, so this path is unverified.

## Verdict

# NO-GO

The migrated core is correct, tested, and privacy-safe. The block is **P1-1**: the architecture doc asserts a universal save-before-publish provenance invariant that two live, wired extraction writers (`updateFromTaxExtraction`, `updateFromPartnerLppExtraction`) do not uphold. Per the hard rule that checked-in code is the source of truth and docs must be challenged against it, an unresolved P1 doc-vs-code contradiction on the phase's headline durability invariant withholds PASS. Resolve by migrating those two writers to the persist-before-publish + `_persistProvenance` pattern (add matching provenance-on-write tests), or by explicitly scoping the doc claim and registering tax/partner-LPP as pending debt. P2-1 (unconsumed `sourceDate`) should be wired or dated in the same pass.
