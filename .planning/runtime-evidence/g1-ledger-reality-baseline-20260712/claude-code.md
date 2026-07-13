# Claude Code Audit — G1 Ledger Reality Baseline

## Current bounded audit — G1-LDG-06A remediation

Date: 2026-07-13

- Command: `CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high CLAUDE_AUDIT_MAX_DIFF_LINES=6000 CLAUDE_AUDIT_ALLOW_LARGE_DIFF=1 tools/checks/claude_external_audit.sh code 157e38b0`
- Base: `157e38b02049a25c93c1762d3fa04d1f70e8cf5a`.
- HEAD: `667f12d45c299651d573866925f0bc4dd53db90e`.
- Diff: 11 files, 1,859 insertions, 161 deletions.
- Durable verbatim output: `claude-code-opus-667f12d45.txt`
  (`sha256:ca950f6372ca895015362924c149a67d1dc00ef530bdbba5f0f8686ee78ee6a4`).
- Exit/verdict: `0` / **PASS**; P0 = 0, P1 = 0.

The auditor verified the AVS proxy removal, service-enforced expat opt-in,
official recovery route, backend certified-null boundary, mortgage calculator
extraction, 15/15 hard-floor tests, 100 targeted Dart tests and clean targeted
analysis. It found no privacy, routing, compliance or facade-without-wiring
blocker.

Residual P2: the accented expat and mortgage disclaimers remain hardcoded
French under narrow legacy `lint-ignore` markers rather than ARB/l10n. This is
accepted as explicit i18n debt for this bounded slice, not as a G1-completion
claim.

No rerun was launched: the first-pass Opus code verdict already had no P0/P1,
so the no-carousel rule applies.

---

## Historical bounded audit — superseded snapshot

Command: `CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high CLAUDE_AUDIT_MAX_DIFF_LINES=7000 tools/checks/claude_external_audit.sh code 4e9d4f45b`

Date: 2026-07-12 13:44:43 CEST

SHA: `0d0950181dfb0e09370ff45e0c1f0d223315e006`

Exit code: `0`

---

I have enough to render a verdict. Let me summarize the evidence I verified directly against the working tree.

## MINT External Audit — Code Mode

**Scope:** branch `codex/mint-product-usability-plan-20260712` vs base `4e9d4f45b` (~993 LOC, within budget). Theme: remove domain data from `GoRouter.extra`, resolve scan payloads via an in-memory `ScanSessionProvider`, drop scenario write-backs, add a `CoachProfile`→confidence adapter, and register G1 planning tickets + a Python ledger gate.

### Verification performed
- **Python ledger gate runs green:** `test_g1_p0_ledger_dead_keys.py` → 3 passed. The matrix files it depends on (`G1-ledger-gap-matrix.md`, `G1-provider-boundary.md`) exist — not a dangling reference.
- **Confidence adapter compiles against reality:** every referenced member exists (`checkIns:1428`, `CoachProfile.defaults():1574`, `monthlyNetIncomeDeclared`, `dataTimestamps`, `propertyMarketValue`, `hasPensionFund`, `ramd`, etc.), and `EnhancedConfidenceService.computeConfidence` accepts the `literacyLevel`/`checkInCount` named params used.
- **l10n hard-refs resolve:** `locationValeursProfil` and `routeSuggestionPartialWarning` (fallbacks removed → non-null asserted) exist in all 6 ARB files.
- **Scan flow fully rewired:** no remaining caller pushes domain objects to `/scan/review` or `/scan/impact` with `extra:`; all pushes now carry `scanSessionId` query params; the two remaining route-string hits are `ScreenReturn`/metadata labels, not navigation payloads.
- **`state.extra` domain casts removed from `app.dart`** (matches `no_domain_data_in_extra_test.dart`).

### Findings

**P0 — none.**

**P1 — none.** No correctness, privacy, routing, or facade-without-wiring defect found in the changed code paths. `ScanSessionProvider` is registered in the `MultiProvider` above the router; recovery scaffolds fail closed on cold deep link / eviction, which is the documented intent.

**P2**
1. **Guard test under-scopes its own invariant.** `apps/mobile/test/routing/no_scenario_writeback_to_profile_test.dart` is titled "scenario levers never overwrite durable ledger facts" but only inspects `epl` and `rente_vs_capital`. `affordability_screen.dart:110` (`_writeBackResult`, called at `:381` and `:402`) still persists derived outputs `mortgageCapacity`/`estimatedMonthlyPayment` into `patrimoine` via `provider.updateProfile`. This is *disclosed* debt — `G1-scenario-lever-matrix.md:94` classifies it `derived_output`, `blocks_G2=no` — and it is pre-existing (this diff only removed `_applyPrefill` there). Not a blocker, but the test name overstates enforcement; recommend either widening the matcher to all scenario screens or renaming it to the two routes it actually covers.
2. **Confidence adapter provenance axis asymmetry (display-only).** Completeness is driven by `profileMap` (gated by `proven()` via `userProvidedFields`/`dataSources`), while accuracy+freshness are built solely from `profile.dataSources.entries`. A fact proven only through `userProvidedFields` (e.g. birth year, whose canonical marker is `userProvidedFields.contains('age')` per `disability_gap_screen.dart:58` et al.) counts toward completeness but contributes no `FieldSource`, so it scores 0 on accuracy/freshness. The new unit test seeds `dataSources['age']`, so it passes but doesn't exercise the marker-only path. Impact is confined to the `/confidence` dashboard (can under-report), not P0-loop financial output.

### Verdict

**PASS**

Rationale: the changed code compiles, is wired end-to-end, and its tests plus the Python gate pass. The only residual scenario write-back (affordability) is explicitly recorded as non-G2-blocking debt in the branch's own scenario-lever matrix, so it does not contradict a claimed-and-shipped invariant. The two P2 items are quality/honesty improvements, not correctness, privacy, or wiring failures.

To strengthen before G2: extend the write-back guard to `affordability_screen.dart` (or rename it), and add a `CoachProfileConfidenceAdapter` test whose provenance lives only in `userProvidedFields` to lock the accuracy/freshness behavior.
