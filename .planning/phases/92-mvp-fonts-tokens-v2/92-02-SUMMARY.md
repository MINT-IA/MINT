---
phase: 92-mvp-fonts-tokens-v2
plan: 02
subsystem: ui
tags: [theme-tokens, mint-colors, mint-text-styles, dark-theme, menthe-vive, gambarino, supreme, design-system]

# Dependency graph
requires:
  - "92-01 (Supreme + Gambarino .otf bundled in apps/mobile/assets/fonts/ + pubspec.yaml flutter.fonts: block)"
provides:
  - "MintColors.mentheVive (#7DD3B5) + mentheVive12 (alpha 0x1F surface tint)"
  - "MintColors dark palette: darkBg, darkInk, darkInkSoft, darkBorderSubtle, darkMentheVive"
  - "5 new MintTextStyles using bundled families directly (no GoogleFonts): displayGambarinoItalic56, displayGambarinoItalic40, titleSupreme18Semibold, bodySupreme15Regular, labelSupreme12Uppercase025LS"
  - "Top-level buildDarkTheme() factory in app.dart + darkTheme: wiring on MaterialApp.router (dormant runtime; fallback path only)"
  - "3 new theme unit-test files (19 new tests)"
affects:
  - "92-03 (sample landing screen + goldens re-baseline) — MintTextStyles.displayGambarinoItalic56 now available for the landing hero swap; MintColors.mentheVive now available for hero accent"
  - "MVP-DARK-MODE-V1 (deferred) — token surface + ThemeData.dark factory ready; per-screen migration can begin without further token work"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure additive theme-token extension: new tokens / styles inserted at end-of-class, no edits to existing tokens (verified via git diff: 0 deletions across all 3 source files)"
    - "Dartdoc propagation of upstream catalog reality: titleSupreme18Semibold doc-notes that Flutter's nearest-weight matcher resolves w600 → bundled Supreme-Bold (700); displayGambarinoItalic* doc-notes that italic is synthesized at render time"
    - "Dark theme wired via top-level public buildDarkTheme() (not class-private _build*) so unit tests can import + assert without pkg-private workarounds"

key-files:
  created:
    - "apps/mobile/test/theme/menthe_vive_tokens_test.dart (9 tests — Menthe-vive hex + dark palette existence + regression guard on primary/inkPrimary)"
    - "apps/mobile/test/theme/gambarino_supreme_styles_test.dart (7 tests — fontFamily/fontStyle/fontSize/fontWeight/letterSpacing/color-override + brandLogo regression)"
    - "apps/mobile/test/theme/dark_theme_factory_test.dart (3 tests — brightness, scaffoldBackgroundColor, colorScheme.onSurface)"
  modified:
    - "apps/mobile/lib/theme/colors.dart (+31 lines: 7 new tokens at end of class)"
    - "apps/mobile/lib/theme/mint_text_styles.dart (+84 lines: 5 new TextStyle factories at end of class + Wave-1-finding doc notes)"
    - "apps/mobile/lib/app.dart (+29 lines: buildDarkTheme factory + darkTheme: field on MaterialApp.router)"

key-decisions:
  - "D-1 [Wave 1 finding propagation] Kept `FontWeight.w600` on titleSupreme18Semibold per plan spec (option a from execution prompt). Added dartdoc explaining Flutter's nearest-weight matcher resolves to bundled Supreme-Bold (700) at render time. Rationale: matches plan unit-test assertions (which check the TextStyle field, not resolved glyph) and keeps callsite intent honest (design system asks for Semibold; render-time substitution is bundled-asset reality)."
  - "D-2 [Wave 1 finding propagation] Added dartdoc on displayGambarinoItalic{56,40} flagging synthetic italic — Fontshare ships no italic glyph variant; Flutter applies skew transform at render time. Visual fidelity at 40-56pt display sizes is a G2 device-gate concern handled in Plan 92-03."
  - "D-3 [Surgical edit, Karpathy #3] All 3 source-file edits are additive only (verified via `git diff --stat`: 0 deletions across colors.dart, mint_text_styles.dart, app.dart). No reordering, no comment-style change, no formatting touch on existing code."
  - "D-4 [Test infra fix, Rule 1 auto-fix] Added `TestWidgetsFlutterBinding.ensureInitialized()` to gambarino_supreme_styles_test.dart so the brandLogo regression test (which calls GoogleFonts.montserrat) doesn't crash on `Binding has not yet been initialized`. Single-line addition, scoped to this test file only."
  - "D-5 [D-92.B compliance] `themeMode: ThemeMode.light` UNCHANGED on MaterialApp.router (line 1584). Dark theme is wired but DORMANT at runtime — fallback path only. Per-screen migration deferred to MVP-DARK-MODE-V1."

patterns-established:
  - "Pattern: when bundled-asset reality diverges from design-system intent (Supreme-600 absent, Gambarino italic synthesized), keep the design-system intent in the TextStyle field and document the runtime resolution in dartdoc rather than mutating the spec."
  - "Pattern: 3-tier theme unit-test layout: (1) value assertions on raw tokens (Color hex, TextStyle fields), (2) regression guards on adjacent untouched tokens, (3) test-binding init when any helper that touches the asset bundle is called."

requirements-completed:
  - FONT-02
  - FONT-03
  - FONT-04

# Metrics
duration: ~5 min
completed: 2026-05-09
---

# Phase 92 Plan 02: MVP-FONTS-TOKENS-V2 Wave 2 — Theme Tokens Summary

**Added Menthe-vive accent + dark palette tokens to MintColors, 5 new MintTextStyles bound to the bundled Supreme + Gambarino fonts (Plan 92-01), and a top-level buildDarkTheme() factory wired as a dormant `darkTheme:` fallback on MaterialApp.router — all as purely additive edits across 3 source files (0 deletions, 144 insertions cumulative) backed by 19 new unit tests, with full theme suite green and `flutter analyze` count unchanged at the Wave 1 baseline (141 info, 0 errors).**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-09T14:39:25Z (RED test for Task 2.1 created)
- **Completed:** 2026-05-09T14:44:33Z (full theme suite + analyze verification passed)
- **Tasks:** 4 (Task 2.1 menthe-vive + dark tokens; Task 2.2 5 new TextStyles; Task 2.3 buildDarkTheme; Task 2.4 verification-only)
- **Commits:** 3 atomic feature commits + this docs commit

## Accomplishments

- **7 new MintColors tokens** added end-of-class with exact ARGB values from STUB pixel-sample:
  - `mentheVive = Color(0xFF7DD3B5)` — MINT v2 accent color (vert-cyan vif)
  - `mentheVive12 = Color(0x1F7DD3B5)` — same hue at 12% alpha (31/255 ≈ 0.122) for surface tints
  - `darkBg = Color(0xFF0F1411)` — near-black with warm undertone
  - `darkInk = Color(0xFFEDEAE3)` — warm off-white text
  - `darkInkSoft = Color(0xFFA8A39A)` — warm grey for metadata
  - `darkBorderSubtle = Color(0xFF2A2F2C)` — barely-perceptible hairline
  - `darkMentheVive = Color(0xFF8FE6C8)` — saturated for ≥4.5:1 on darkBg
- **5 new MintTextStyles** added end-of-class, bound to bundled families via `fontFamily: 'Gambarino'` / `'Supreme'` (no GoogleFonts wrapper):
  - `displayGambarinoItalic56` — Landing hero (56pt, italic, w400, height 1.15, letterSpacing -0.5, color inkPrimary)
  - `displayGambarinoItalic40` — Onboarding hero (40pt, italic, w400, height 1.2, letterSpacing -0.4)
  - `titleSupreme18Semibold` — Card/section title (18pt, w600 → renders Bold/700 per Wave 1 finding, height 1.3)
  - `bodySupreme15Regular` — MINT v2 default body (15pt, w400, height 1.5)
  - `labelSupreme12Uppercase025LS` — Eyebrow/micro-label (12pt, w500, letterSpacing 0.25, default color textMutedAaa)
- **buildDarkTheme() top-level public factory** in app.dart returning ThemeData(brightness: dark) with ColorScheme.dark referencing MintColors.dark* tokens; wired as `darkTheme:` on MaterialApp.router immediately after existing `theme: _buildPremiumTheme()`. `themeMode: ThemeMode.light` UNCHANGED (D-92.B) — dark theme is a dormant fallback only.
- **19 new unit tests** across 3 files, **47/47 theme tests pass** (existing 28 + new 19). Citation: `/tmp/theme_tests_92_02.log` line `00:00 +47: All tests passed!`.
- **flutter analyze unchanged at baseline:** 141 info issues / 0 errors (Wave 1 baseline = 141 / 0). Citation: `/tmp/analyze_92_02.log`, `141 issues found. (ran in 5.0s)`. No regression in 6000+ existing surfaces.

## Task Commits

Each task committed atomically (Task 2.4 is verification-only — no commit):

1. **Task 2.1: Menthe-vive + dark palette tokens to MintColors** — `6235db87` (feat)
2. **Task 2.2: 5 new MintTextStyles using bundled Gambarino + Supreme** — `9fc09a12` (feat)
3. **Task 2.3: buildDarkTheme factory + darkTheme: wiring on MaterialApp** — `95fa8eb8` (feat)
4. **Task 2.4: Full theme test suite + analyze regression check** — no commit (verify-only)

## Files Created/Modified

| File | Change | Notes |
|---|---|---|
| `apps/mobile/lib/theme/colors.dart` | +31 lines, 0 deletions | 7 new tokens appended at end of class (mentheVive, mentheVive12, dark{Bg,Ink,InkSoft,BorderSubtle,MentheVive}). Section header marks Phase 92 origin. `static const Color` count: 168 → 175 (+7 exact). |
| `apps/mobile/lib/theme/mint_text_styles.dart` | +84 lines, 0 deletions | 5 new TextStyle factories appended at end of class + Wave-1-finding doc notes. `static TextStyle` count: 21 → 26 (+5 exact). 5 occurrences of `fontFamily: '` (bundled-family pattern) — none in pre-edit baseline. |
| `apps/mobile/lib/app.dart` | +29 lines, 0 deletions | New top-level `ThemeData buildDarkTheme()` after `_buildPremiumTheme()`; new `darkTheme: buildDarkTheme(),` field on MaterialApp.router (line 1583, between `theme:` and `themeMode:`). `themeMode: ThemeMode.light` preserved (line 1584). |
| `apps/mobile/test/theme/menthe_vive_tokens_test.dart` | new file (44 lines) | 9 tests: 2 Menthe-vive hex assertions, 5 dark-palette existence checks, 2 regression guards on primary/inkPrimary. |
| `apps/mobile/test/theme/gambarino_supreme_styles_test.dart` | new file (60 lines) | 7 tests: 3 Gambarino (fontFamily/fontStyle/fontSize/fontWeight + color override), 3 Supreme (fontFamily/fontWeight/fontSize/letterSpacing), 1 brandLogo regression. Top of `main()` calls `TestWidgetsFlutterBinding.ensureInitialized()` (auto-fix; see Deviations). |
| `apps/mobile/test/theme/dark_theme_factory_test.dart` | new file (24 lines) | 3 tests: brightness == Brightness.dark, scaffoldBackgroundColor == MintColors.darkBg, colorScheme.onSurface == MintColors.darkInk. |

## Decisions Made

- **D-1 Supreme weight 600 → render-time resolution to bundled Bold (700) — kept design intent in TextStyle field.** Wave 1 surfaced that Fontshare ships no Supreme-600 (catalog has 100/200/300/400/500/700/800). Plan 92-02 specced `titleSupreme18Semibold` with `FontWeight.w600` and the unit test asserts on that field. Two options were on the table (per execution prompt): (a) keep w600 + dartdoc note, or (b) change to w700 for ground-truth. Chose **(a)** — Karpathy #3 surgical (the test passes as written), and it preserves design-system intent at the callsite. The dartdoc on `titleSupreme18Semibold` documents that Flutter's nearest-weight matcher resolves the w600 request to bundled Supreme-Bold (700) at render time. If Julien wants ground-truth at render layer, swap to w700 in a follow-up — but that'd surface a different design-vs-render reality and isn't a 92-02 blocker.
- **D-2 Gambarino synthetic italic — dartdoc note added on display{56,40} factories.** Wave 1 finding #2: Fontshare's Gambarino ships only Gambarino-Regular.otf (upright); italic is synthesized via Flutter's `style: italic` skew transform on the upright at render time. Both Gambarino TextStyles have a NOTE block in their dartdoc flagging "synthetic italic — visual fidelity validated at G2 sim screenshot review". This is a Plan 92-03 G1 visual concern, not a 92-02 blocker (TextStyle objects are correct).
- **D-3 buildDarkTheme is public (no leading underscore).** Plan/test prescribed `import 'package:mint_mobile/app.dart' show buildDarkTheme;`. Library-private `_buildPremiumTheme` mirrors the existing pattern but can't be tested across files. The new factory is public exclusively to expose it for unit testing — same pattern other Flutter test surfaces use. No callsites outside app.dart currently reference it; the surface is additive-only.
- **D-4 themeMode: ThemeMode.light UNCHANGED.** D-92.B in 92-CONTEXT.md is unambiguous: token drop only, no per-screen dark migration this phase. The `darkTheme:` field is wired so that MaterialApp's contract is complete — but since `themeMode` is hard-locked to light, the dark theme is dormant at runtime. Per-screen rendering remains unchanged. A future phase can switch to `ThemeMode.system` to activate.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Test infrastructure bug] gambarino_supreme_styles_test.dart needs `TestWidgetsFlutterBinding.ensureInitialized()` to test brandLogo regression**
- **Found during:** Task 2.2 GREEN-step test run (initial run after styles added).
- **Issue:** The plan-spec test file (Step A of Task 2.2) calls `MintTextStyles.brandLogo()` for the regression assertion. `brandLogo()` invokes `GoogleFonts.montserrat()`, which synchronously triggers an asset-bundle read via the services binding. Without `TestWidgetsFlutterBinding.ensureInitialized()` at the start of `main()`, the first call throws: `Binding has not yet been initialized. The "instance" getter on the ServicesBinding binding mixin is only available once that binding has been initialized.` 6/7 tests passed; the brandLogo regression test failed with this binding-not-initialized error (confirmed with `flutter test`, exit code 1, error stack pointed to `google_fonts_base.dart` → `loadFontIfNecessary`).
- **Fix:** Added `TestWidgetsFlutterBinding.ensureInitialized();` as the first line of `main()` in `gambarino_supreme_styles_test.dart`. With the binding initialized, GoogleFonts attempts the asset-bundle read, fails over to a default font when assets aren't present in the test runner, but no longer throws. brandLogo regression test now reaches its `expect(s.fontFamily, isNot(equals('Supreme')))` assertion and passes.
- **Files modified:** `apps/mobile/test/theme/gambarino_supreme_styles_test.dart` (single line + comment block at top of `main()`).
- **Verification:** `flutter test test/theme/gambarino_supreme_styles_test.dart` → 7/7 pass after fix. `flutter test test/theme/` → 47/47 pass (no spillover).
- **Committed in:** `9fc09a12` (Task 2.2 commit, since the fix lives in the same task's test file).

---

**Total deviations:** 1 auto-fixed (Rule 1 — test infrastructure). No architectural changes, no scope expansion, no plan-spec rewrites.

**Wave 1 finding propagation outcomes:**
- **Finding #1 (Supreme 600 absent):** Resolved with option (a) — kept `FontWeight.w600`, added dartdoc explaining Flutter's nearest-weight resolution to bundled Bold/700.
- **Finding #2 (Gambarino synthetic italic):** Dartdoc NOTE blocks added to both `displayGambarinoItalic56` and `displayGambarinoItalic40` factories flagging "italic synthesized at render time" + G2 visual gate.
- **Finding #3 (analyze baseline = exit 1, 141 info, 0 errors):** Used as regression baseline. Post-92-02: 141 info, 0 errors. Exact parity, no regression.
- **Finding #4 (don't touch pubspec.yaml):** pubspec.yaml not in `git diff` for this plan — confirmed untouched.

## Issues Encountered

1. **Test-runner asset bundle missing for GoogleFonts** — see Deviation #1. Resolved by initializing the test binding. Worth noting for future MINT theme tests that touch `GoogleFonts.*`: this pattern (binding init) is mandatory whenever the test calls a TextStyle factory wrapping GoogleFonts.

2. **No other issues encountered.** All 3 atomic commits landed first-try; full theme suite (47 tests) passed first-try after the binding-init fix; full project analyze stayed at the Wave 1 baseline of 141 info / 0 errors / exit 1.

## User Setup Required

None — Phase 92-02 is purely additive code + tests. No external service config. No new secrets, no new env vars, no new APIs.

## Next Plan Readiness

**For Plan 92-03 (sample landing screen + goldens re-baseline):**

- ✅ `MintTextStyles.displayGambarinoItalic56` available for the landing hero swap.
- ✅ `MintColors.mentheVive` available for hero accent / CTA ring.
- ⚠️ **G2 visual concerns to surface in 92-03 G1 sim screenshot review:**
  - Synthetic Gambarino italic at 56pt display size (skew transform on upright glyphs — visual fidelity TBD).
  - Supreme-Bold (700) rendering for `titleSupreme18Semibold` callsites that request w600 — emphasis is one notch heavier than design-system spec.
- ⚠️ Goldens re-baseline budget for 92-03: only landing + onboarding hero + chat opener (D-92.A scope cap), not the full app surface.

**For MVP-DARK-MODE-V1 (deferred):**

- ✅ Dark token surface complete (5 dark colors via MintColors.dark*).
- ✅ `buildDarkTheme()` factory available — per-screen migration can begin without further token work.
- ⚠️ Activation requires switching `themeMode:` from `ThemeMode.light` to `ThemeMode.system` (or wiring a user toggle) — single-line change, but gates a per-screen visual QA pass.

**Cross-plan note:** Per execution prompt, STATE.md and ROADMAP.md updates are owned by the orchestrator (which writes after the wave completes), not this executor. No state-tracking writes performed by Plan 92-02 commits.

## Self-Check: PASSED

Verified after writing SUMMARY:

- `apps/mobile/lib/theme/colors.dart` — MODIFIED (+31 lines, 175 `static const Color` declarations vs 168 baseline, +7 exact)
- `apps/mobile/lib/theme/mint_text_styles.dart` — MODIFIED (+84 lines, 26 `static TextStyle` declarations vs 21 baseline, +5 exact; 5 `fontFamily: '` (bundled) usages, none in baseline)
- `apps/mobile/lib/app.dart` — MODIFIED (+29 lines, contains `ThemeData buildDarkTheme()` and `darkTheme: buildDarkTheme(),` and unchanged `themeMode: ThemeMode.light`)
- `apps/mobile/test/theme/menthe_vive_tokens_test.dart` — FOUND (44 lines, 9 tests, all green)
- `apps/mobile/test/theme/gambarino_supreme_styles_test.dart` — FOUND (60 lines + binding-init line, 7 tests, all green)
- `apps/mobile/test/theme/dark_theme_factory_test.dart` — FOUND (24 lines, 3 tests, all green)
- `git log --oneline -3` shows commits `95fa8eb8` (feat 92-02 Task 2.3), `9fc09a12` (feat 92-02 Task 2.2), `6235db87` (feat 92-02 Task 2.1) on branch `docs/phase-2-extractor-v2-research`
- `flutter test test/theme/` — 47/47 pass (citation: `/tmp/theme_tests_92_02.log` line `00:00 +47: All tests passed!`)
- `flutter analyze` — 141 info / 0 errors / exit 1 (citation: `/tmp/analyze_92_02.log` line `141 issues found. (ran in 5.0s)`) — exact Wave 1 baseline parity
- pubspec.yaml — UNTOUCHED (per Wave 1 finding #4 + plan scope; verified no entry in `git status` or task-stage diffs)

---
*Phase: 92-mvp-fonts-tokens-v2*
*Plan: 02*
*Completed: 2026-05-09*
