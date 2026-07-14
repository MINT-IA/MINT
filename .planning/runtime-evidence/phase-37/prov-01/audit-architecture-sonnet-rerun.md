I now have enough evidence to issue the verdict. Let me compile the full findings.

---

## MINT Architecture Audit — Branch `codex/mint-product-usability-plan-20260712`

**Audit date:** 2026-07-14
**Scope:** G1 provenance-on-write phase evidence vs. live code

---

## Verdict: **NO-GO**

Three independent P0 blockers prevent G2 eligibility. The G1-PROV-01 implementation is architecturally sound for 6 of 8 writers, but two writers remain live G1 blockers and the runtime gate is unproven.

---

## P0 Findings

### P0-1 — `updateFromTaxExtraction` and `updateFromPartnerLppExtraction` still publish before save with zero provenance

**Files:** `apps/mobile/lib/providers/coach_profile_provider.dart:2116–2136, 2369–2402`

Both methods follow the old broken pattern:

```dart
// updateFromTaxExtraction (line 2369-2402)
_profile = p.copyWith(dataSources: updatedSources, ...)  // ← mutates state
// ... async gap ...
await ReportPersistenceService.saveAnswers(answers);     // ← no _persistProvenance
notifyListeners();
```

```dart
// updateFromPartnerLppExtraction (line 2116-2136)
_profile = p.copyWith(conjoint: updatedConjoint, ...)   // ← mutates state before save
await ReportPersistenceService.saveAnswers(answers);     // ← no _persistProvenance
notifyListeners();
```

Neither calls `_persistProvenance()`. Neither writes a `__provenance` entry. The `docs/data-flow.md:87-89` explicitly confirms this: *"Live legacy exceptions remain full G1 blockers: `updateFromTaxExtraction` → G1-PROV-03 and `updateFromPartnerLppExtraction` → G1-PROV-02 + G1-BND-02A. Both still publish before save and write no canonical provenance."*

**Reproduction:** Call either method with valid extracted fields, kill the app, reload — the `__provenance` key will be absent from `wizard_answers_v2`, and `cold.dataSources` will have no entries for the written fields. The test contract in `provenance_on_write_test.dart` would catch this if these writers were tested — they are not.

---

### P0-2 — G1-PROV-01 gate ticket status not updated; gate registry blocks G2

**File:** `.planning/goals/G1-blocking-gate-tickets.md:28`

```markdown
| G1-PROV-01 | provenance_on_write_test | ... | red_proven |
```

The implementation in this PR (6 migrated writers, `__provenance` canonical envelope, `dataSourceDates` field, cold-roundtrip tests) is architecturally complete for its migrated surface. However the gate registry still shows `red_proven`. The encoded release decision at the bottom of that file is explicit:

> *"G2 allowed: NO until every ticket is implemented, its GREEN command passes, required Maestro and Patrol artifacts exist, external audits are resolved, and the phase score reaches at least 9.0/10."*
> *"Runtime data-spine G2 readiness: NO while any `ticket_only` or `red_proven` row remains."*

The status must be flipped to `green` only after `flutter test test/providers/provenance_on_write_test.dart` is confirmed to pass end-to-end. There is no CI artifact proving this in the current diff.

---

### P0-3 — G1-RUNTIME-01 remains `red_proven` with no artifacts

**File:** `.planning/goals/G1-blocking-gate-tickets.md:51`

```markdown
| G1-RUNTIME-01 | runtime_persistence_test | ... | red_proven |
```

No Maestro YAML, no Patrol artifacts, no `patrol_persistence_process_death.sh` output, and no `simctl terminate` proof exist in this diff. The gate requires:
- Maestro walkthrough on a real UDID with `MINT_WALKER_ARTIFACTS=...`
- Two-stage Patrol write/read across `simctl terminate`

This gate is untouched by this PR and blocks G2 independently of G1-PROV-01 status.

---

## P1 Findings

### P1-1 — 16 `ticket_only` rows with zero implementation

**File:** `.planning/goals/G1-blocking-gate-tickets.md`

Rows still at `ticket_only`: G1-PROV-02, G1-PROV-03, G1-SCN-01, G1-BND-01, G1-BND-02, G1-BND-02A, G1-BND-03, G1-BND-05, G1-BND-06, G1-COACH-01, G1-COACH-02, G1-FRONT-01, G1-RET-STATE-01, G1-RET-REF-01, G1-AVS-02, G1-SUCCESSION-01, G1-RETURN-01, G1-FRESH-01. Each one independently blocks G2. None are touched by this diff.

### P1-2 — G1-PROV-02 scope expanded without implementation

**File:** `.planning/goals/G1-blocking-gate-tickets.md:29`

The diff expands G1-PROV-02's scope to include partner LPP consent lifecycle and save-before-publish. The predicate is now:

> *"Self or partner LPP certificate projections, coverage values, or person-owned provenance disappear after cold reconstruction; or the partner scan publishes before persistence."*

`updateFromPartnerLppExtraction` demonstrably still publishes before persistence (P0-1 above). Widening the ticket scope without fixing the underlying defect makes the ticket harder to close, not easier.

---

## P2 Findings

### P2-1 — `_coach_avs_bonifications_educatives` absent from `_answerProvenancePaths`

**File:** `apps/mobile/lib/providers/coach_profile_provider.dart:152–226`

The map covers `_coach_avs_ramd` and `_coach_avs_rente_estimee` but not `_coach_avs_bonifications_educatives`. This is harmless for the current migrated path because `updateFromAvsExtraction` calls `_withStampedProvenance` directly with `touchedFields` including `'prevoyance.bonificationsEducatives'` when non-null (confirmed in diff at ~line 373). But the gap creates inconsistency: a future `mergeAnswers({'_coach_avs_bonifications_educatives': 6})` call would fail to stamp provenance for `prevoyance.bonificationsEducatives`. Verify by running the `AVS education credits` test in `provenance_on_write_test.dart:475`.

### P2-2 — `CoachProfile.schemaVersion` not incremented

**File:** `apps/mobile/lib/models/coach_profile.dart:1457`

```dart
static const int schemaVersion = 1;
```

This PR adds `dataSourceDates` to the serialization contract and changes how `dataSources` is derived (with the new `inferDataSources` flag). Profiles persisted before this change will correctly fall back via `fromJson`'s `inferDataSources: !json.containsKey('dataSources')` check, but migration code that might branch on `schemaVersion` will not know a format change occurred.

### P2-3 — `updateFromRefresh` persistence still fire-and-forget with silent catch

**File:** `apps/mobile/lib/providers/coach_profile_provider.dart` (not in diff, preexisting)

`docs/data-flow.md:107` lists `updateFromRefresh` as a writer but marks it *"currently orphaned, cf façade audit."* The annual refresh is listed in the writer table without a caller. This is a façade-sans-câblage instance that the audit warns about. Not introduced by this PR but visible in the G1 ticket gap.

---

## What is correct in this PR

The G1-PROV-01 implementation for the migrated surface is architecturally sound:

- **Canonical `__provenance` envelope** — field-keyed `{source, updatedAt, sourceDate}` shape is correct; `saveAnswers` and `loadAnswers` correctly round-trip the JSON object.
- **Fail-closed parsing** — `canonicalMentionedPaths.add(fieldPath)` fires unconditionally before the `!envelope.containsKey('sourceDate') → continue` guard, correctly blocking legacy fallback for malformed entries. Verified by test at `provenance_on_write_test.dart:662`.
- **`inferDataSources: false` in `copyWith()`** — prevents `_resolveDataSources` from overwriting a restored certificate source on every update call. This was the root cause of phantom source loss on profile mutation.
- **`_coach_blink_source` key consistency** — the legacy migration reader in `fromWizardAnswers` checks `_coach_blink_source == 'open_banking'`; `updateFromOpenBanking` writes exactly that key at `coach_profile_provider.dart:2990`. Consistent.
- **6 of 8 writers migrated** — `updateFromLppExtraction`, `updateFromAvsExtraction`, `updateFromSalaryExtraction`, `updateFromOpenBanking`, `updateInline`, and `mergeAnswersWithProvenance` now all follow save→assign→notify order with `_persistProvenance` called before `notifyListeners()`.
- **`bonificationsEducatives` parse gap closed** — `fromWizardAnswers` now reads `_coach_avs_bonifications_educatives` (diff line ~2993). Previously, AVS extraction could write this key and it would be silently discarded on cold reload.

---

## What must happen before G2 is unlocked

| Action | Evidence required |
|--------|-------------------|
| Migrate `updateFromTaxExtraction` (G1-PROV-03) | `flutter test test/providers/tax_provenance_profile_test.dart` green |
| Migrate `updateFromPartnerLppExtraction` (G1-PROV-02) | `flutter test test/providers/provenance_restart_test.dart` green |
| Flip G1-PROV-01 to `green` | `flutter test test/providers/provenance_on_write_test.dart` green + artifact |
| G1-RUNTIME-01 runtime proof | Maestro YAML pass + Patrol two-stage kill/reload artifact on one UDID |
| All `ticket_only` rows | Each GREEN command passes with artifact |
| Phase score ≥ 9.0/10 | Final scorecard |
