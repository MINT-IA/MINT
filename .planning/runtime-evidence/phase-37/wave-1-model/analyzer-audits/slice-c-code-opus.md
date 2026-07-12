All changed test files pass (102 + 49 tests green), analyzer clean, and I verified every migrated API against the actual pinned SDK source. Here is the audit.

---

# MINT External Audit — Phase 37 Analyzer Contract Repair

**Scope:** `e266da836..HEAD` (2 commits: `c48c1a935` a11y API migration, `429aec5d9` dormant test repair). 11 files, +37/−74 lines — well under the 4500-line budget.

## Verdict: **PASS**

---

## Evidence of correctness

**Environment matches migration target.** Local `Flutter 3.41.6` / CI `3.41.4` (`.github/workflows/ci.yml:282`, `web.yml:58`, `testflight.yml:157`). The diff migrates *away* from APIs that were pinned for the old 3.27.x line — consistent, not speculative.

**Every migrated API verified against the real SDK, not docs:**

| Change (file:line) | Verified against SDK |
|---|---|
| `SemanticsService.sendAnnouncement(View.of(context), label, dir)` — `mint_trame_confiance.dart:411` | `semantics_service.dart:81` — exact signature `sendAnnouncement(FlutterView, String, TextDirection, {Assertiveness})`. Old `announce` is now `@Deprecated` (`:52`) with the multi-window incompatibility message. Migration is the sanctioned replacement. |
| `cur.flagsCollection.isLiveRegion` — `coach_live_region_test.dart` | `SemanticsNode.flagsCollection` getter exists (`semantics.dart:3365`); `isLiveRegion` is `final bool` on `SemanticsFlags` (sky_engine `semantics.dart`). |
| `semantics.flagsCollection.isButton` — `wcag_audit_test.dart` | Same getter; `isButton` is `final bool`. |

**WCAG luminance change is a fidelity *preservation*, not a weakening** (`wcag_audit_test.dart`). The naive migration `color.red/255.0` → `color.r` would silently change results (deprecated `.red` = rounded 8-bit int; `.r` = raw double). The added `byteNormalized()` re-derives the exact deprecated byte semantics `(c*255).round().clamp(0,255)/255`. Self-check tests still assert black/white = 21:1 and white/white = 1:1 — green.

**Test changes strengthen or preserve, no facade:**
- `would_have_fired_payload_test.dart:+3` — **adds** an assertion (`returnBeforeExtra.hasMatch(...) isTrue`); no assertion removed.
- `calculator_prefill_writeback_test.dart` — extracted `simulateWriteBack(bool)` helper; both branches still assert `isFalse`/`isTrue`.
- Renamed test titles / doc comments (`announce` → `sendAnnouncement`) with assertions intact.

**Dead-code deletions confirmed unreferenced** (grep across `test/` returns zero hits): `_normalApp` (font_scaling), `_allowedLegalKeyPatterns` (route_doctrine_lint — behavior already driven by the `category != 'raw-legal-reference'` filter, `knownPreExistingCount=2` gate unchanged), `parentPattern` (route_cycle), shadowed `fact` (biography_repo). No live code path lost.

**Runtime proof:**
- `flutter analyze` on changed lib + a11y tests → *No issues found*.
- `flutter test` MTC + a11y + response_card → **102 passed**, including the sendAnnouncement dedup contract (announce-exactly-once, no re-announce on same ref, re-announce on ref change).
- `flutter test` architecture + font_scaling + calculator + biography → **49 passed**.

## Findings

- **P0:** none.
- **P1:** none.
- **P2 (non-blocking):** `View.of(context)` in `_maybeAnnounce` is called from both `didChangeDependencies` (initial) and `didUpdateWidget`; both have a valid mounted `context` with a `View` ancestor, and tests confirm `debugAnnounceCount==1`. No defect — noting only that a future teardown-race would surface here first.

## Not covered by this diff (out of scope, flagged for completeness)
This audit does not prove the *rest* of the app is free of remaining `SemanticsService.announce`/`hasFlag` deprecated call sites. Those still compile under 3.41 (deprecated ≠ removed), so they cannot break CI. To confirm full migration hygiene, run: `flutter analyze` on the whole `apps/mobile` and `rg "SemanticsService.announce|hasFlag\(SemanticsFlag" apps/mobile/lib`.
