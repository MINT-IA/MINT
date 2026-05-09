---
phase: 92-mvp-fonts-tokens-v2
plan: 03
subsystem: ui
tags: [landing, hero, gambarino, italic, font-swap, golden-test, g1-sim-screenshot, design-system]

# Dependency graph
requires:
  - "92-01 (4 .otf bundled, pubspec.yaml flutter.fonts: block)"
  - "92-02 (MintTextStyles.displayGambarinoItalic40 helper, MintColors.mentheVive)"
provides:
  - "Landing hero swapped to bundled Gambarino italic (visible product surface)"
  - "Landing golden test scaffolded (apps/mobile/test/golden/landing_gambarino_test.dart, skip:true pending GoogleFonts purge)"
  - "G1 sim screenshot evidence (.planning/phases/92-mvp-fonts-tokens-v2/g1-sim-screenshot.png) — Gambarino italic rendered on iPhone 17 Pro sim"
affects:
  - "TestFlight build (next mobile release will ship the swapped hero glyph)"
  - "MVP-GOOGLEFONTS-PURGE-V1 (deferred): once chrome glyphs swap to bundled Supreme, the skip:true on landing_gambarino_test.dart can be flipped to false and the offline golden baselines"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Surgical UI swap: replaced inline GoogleFonts.fraunces(...) block (-8 lines) with single MintTextStyles helper call (+3 lines), preserving visual layout (same fontSize/letterSpacing/height)"
    - "Dead-import cleanup scoped to changed file only: `import google_fonts` removed from landing_screen.dart because that file's only use was the swapped hero (preserves D-92.E elsewhere — sweep deferred to MVP-GOOGLEFONTS-PURGE-V1)"
    - "Golden test scaffolded but `skip: true` — pre-existing offline GoogleFonts environment limitation also blocks `test/goldens/landing_golden_test.dart`; documented in test-file header for future re-activation"

key-files:
  created:
    - "apps/mobile/test/golden/landing_gambarino_test.dart (103 lines, skip:true pending purge-v1) — SHA-256 57596c17…f5552"
    - ".planning/phases/92-mvp-fonts-tokens-v2/g1-sim-screenshot.png (232 KB) — SHA-256 7fc49959…1a917"
  modified:
    - "apps/mobile/lib/screens/landing_screen.dart (+6 / -8 lines, hero style swap + comment update + dead-import removal) — SHA-256 b24c3863…d49e9"

key-decisions:
  - "D-1 [Karpathy #3 surgical] Removed `import google_fonts` from landing_screen.dart because the swap left it unused and would have introduced a NEW unused-import lint regressing the 141-baseline. D-92.E (no codebase-wide GoogleFonts sweep) preserved — other files with GoogleFonts uses untouched (verified: 9 other GoogleFonts.* hits across lib/screens/, all unmodified)."
  - "D-2 [Pragmatic — pre-existing env block] Task 3.2 golden test created but `skip: true`. Pre-existing GoogleFonts wrappers in MintTextStyles.{brandLogo,titleMedium,bodySmall,labelSmall} call out to fonts.gstatic.com at render time; the offline test runner's mock HTTP client returns 404, GoogleFonts.loadFontIfNecessary catches AND rethrows (google_fonts_base.dart:191), surfacing as 'EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK' post-test failure. Same failure mode confirmed on existing test/goldens/landing_golden_test.dart in this environment (4/5 cases fail offline). FONT-07 visual evidence delivered via Task 3.3 G1 sim screenshot instead. Test will activate once MVP-GOOGLEFONTS-PURGE-V1 swaps chrome glyphs."
  - "D-3 [Karpathy #1 surface tradeoffs] Three offline-test rescue attempts (HttpOverrides bundled-bytes stub, allowRuntimeFetching=false + FontLoader pre-registration of Google family names, allowRuntimeFetching=true with mock client) all failed because GoogleFonts validates SHA256+length against known catalog hashes. Stopped iterating after 3 attempts (per skill rules: 3-attempt fix limit). G1 sim screenshot is the FONT-07 visual gate Phase 92-03 actually needs."
  - "D-4 [Surgical, Karpathy #3] No 4-person design panel pre-push because the MINT Design System v2 was already panel-validated (STUB.md is the panel synthesis); Plan 92-03 Task 3.1 is execution of validated design, not new design. Documented in execution-context per material_context_from_prior_waves."

patterns-established:
  - "Pattern: when a font-swap leaves an import dead in ONE file, remove it (cleaning my own mess) — but DON'T sweep the rest of the codebase (D-92.E scope discipline)."
  - "Pattern: when offline test environment can't render a screen due to pre-existing GoogleFonts call sites, scaffold the test with skip:true + verbose header rationale so the file is ready to baseline once the deferred purge lands. Visual evidence shifts to G1 sim screenshot."
  - "Pattern: G1 sim screenshot capture flow on a booted iOS sim — `flutter build ios --simulator --debug --no-codesign` (18.6s), `xcrun simctl install booted <Runner.app>`, `xcrun simctl launch booted ch.mint.app`, sleep 5-6s for AnimationController drain, `xcrun simctl io booted screenshot /tmp/font_test.png`. Reproducible recipe."

requirements-completed:
  - FONT-05
  - FONT-07 (partial — file scaffolded; baseline image deferred to MVP-GOOGLEFONTS-PURGE-V1)
  - FONT-08 (analyze + theme/golden tests green; ARB/accent/wiki lints green)

# Metrics
duration: ~15 min
completed: 2026-05-09
---

# Phase 92 Plan 03: MVP-FONTS-TOKENS-V2 Wave 3 — Sample Landing Hero Swap + G1 Evidence Summary

**Swapped the landing screen hero phrase from GoogleFonts.fraunces to bundled MintTextStyles.displayGambarinoItalic40 (the user-visible proof of Phase 92), captured G1 simulator screenshot evidence on iPhone 17 Pro showing the Gambarino italic glyphs render correctly, scaffolded a golden test (skip:true pending MVP-GOOGLEFONTS-PURGE-V1 due to a pre-existing offline GoogleFonts environment block that ALSO affects the existing test/goldens/landing_golden_test.dart), and preserved the 141-issue analyzer baseline + theme/golden test suite green throughout. Task 3.4 (Julien G2 device walkthrough) is a checkpoint and is the only remaining gate.**

## Performance

- **Started:** 2026-05-09T14:50:35Z
- **Completed:** 2026-05-09T15:05:14Z (Tasks 3.1, 3.2, 3.3, 3.5 — Task 3.4 awaits Julien)
- **Duration:** ~15 min
- **Tasks executed:** 4 of 5 (3.1, 3.2, 3.3, 3.5; 3.4 = blocking checkpoint)
- **Commits:** 4 (3 atomic feature/test/chore commits + this docs commit)
- **Files touched:** 1 source modified, 1 test created, 1 sim screenshot committed, 1 SUMMARY (this file)

## Task Commits

1. **Task 3.1: Swap landing hero to MintTextStyles.displayGambarinoItalic40** — `8a18ea5e` (feat)
2. **Task 3.2: Add landing_gambarino golden test (skip:true pending purge-v1)** — `948313e1` (test)
3. **Task 3.3: Capture G1 sim screenshot — landing hero in bundled Gambarino** — `fe2e44bd` (chore)
4. **Task 3.5: SUMMARY + regression sweep** — this docs commit (docs(92-03))

Task 3.4 (G2 — Julien device sign-off) is a `checkpoint:human-action` and is NOT executed by Claude. The orchestrator routes Julien through it post-checkpoint.

## 5-Gate Evidence

### G1 — Sim screenshot (Claude-captured)

- **Path:** `.planning/phases/92-mvp-fonts-tokens-v2/g1-sim-screenshot.png`
- **Size:** 232 KB (well above 50 KB threshold)
- **SHA-256:** `7fc49959461356bb7cd381c644a52bd6ed8c26cad4cd3b6892002760bc61a917`
- **Sim device:** iPhone 17 Pro (UDID `B03E429D-0422-4357-B754-536637D979F9`, iOS 26.2)
- **Build command:** `flutter build ios --simulator --debug --no-codesign` (Xcode 18.6s)
- **Launch:** `xcrun simctl launch booted ch.mint.app` → PID 41012
- **Screenshot delay:** 6s after launch (AnimationController = 3200 ms; +2.8s safety margin)
- **Visual inspection:** hero phrase "Voir clair, décider seul." renders in **bundled Gambarino italic** glyphs:
  - 'V' has clean angled stem entry (vs. Fraunces' more curved entry)
  - 'r' terminal is functional/cleaner (vs. Fraunces' decorative ball terminal)
  - 'd' italic loop is more compact (vs. Fraunces' open italic-d ball)
  - Overall stress is contemporary-display Gambarino, NOT transitional-Italian Fraunces
  - NOT Times-style serif fallback (which would have boring uniform serifs and no display flourish)
- **Caveat:** the BetaProgramDisclosureSheet (first-launch one-shot per `landing_screen.dart:80-82`) overlays the lower portion of the hero. The hero phrase is fully visible in the upper portion of the screenshot. Subsequent launches won't show the sheet (mocked SharedPreferences flag persists per device install).

### G2 — Julien device sign-off (BLOCKING CHECKPOINT — pending)

**Status:** PENDING — Task 3.4 is `checkpoint:human-action` and Claude does NOT execute it. Julien performs the verification per Plan 92-03 Task 3.4 `<how-to-verify>` and types one of the resume signals listed in `<resume-signal>`. The orchestrator records Julien's verbatim signal in this section after the checkpoint.

Once Julien provides a resume signal, the orchestrator should append below this line:

```
### G2 evidence — Julien resume signal (verbatim)

> [signal verbatim, e.g. "approved" / "approved-with-hex-change-to #XXXXXX" / "font-fallback-on-device" / "license-issue"]

Captured: 2026-05-09T<HH:MM>Z
```

### G3 — Local CI proxy (analyze + test)

- **`flutter analyze` (full project):** `141 issues found. (ran in 5.0s)` — **EXACT Wave 2 baseline parity** (Wave 2 = 141 / 0 errors / exit 1; Wave 3 post = 141 / 0 errors / exit 1)
  - Citation: `/tmp/g3_analyze.log` line `141 issues found. (ran in 5.0s)`
- **`flutter analyze lib/screens/landing_screen.dart` (scoped):** `No issues found! (ran in 1.3s)` — exit 0
- **`flutter analyze test/golden/landing_gambarino_test.dart` (scoped):** `No issues found! (ran in 1.3s)` — exit 0

### G4 — Regression goldens (theme + golden suites)

- **Command:** `flutter test test/theme/ test/golden/`
- **Result:** `00:04 +65 ~1: All tests passed!` — 65 tests passed, 1 skipped (the new landing_gambarino_test.dart, intentionally skipped per D-2), exit 0
  - Citation: `/tmp/g4_test.log` line `00:04 +65 ~1: All tests passed!`
- **Goldens re-baselined:** `git status apps/mobile/test/golden/goldens/` returns no tracked files (the directory is intentionally not bundled — Wave 3 produces no golden image because the test is skipped pending GoogleFonts purge).
- **Existing goldens UNTOUCHED:** `git diff apps/mobile/test/goldens/masters/` returns empty (the 4 existing landing masters from Phase 7-03, the 3 mtc masters, and the s4 masters are all unchanged).

### G5 — Lint baselines unchanged

- **`accent_lint_fr.py --file apps/mobile/lib/screens/landing_screen.dart`** → exit 0
- **`wiki_lint.py`** (full repo) → exit 0 (only orphan-page warnings, no FAIL violations)
- **LSFin / banned-terms baseline:** preserved — no copy changes in this plan; the swap is style-only on existing locked-ARB phrase `landingV3Hero` ("Voir clair, décider seul.")
- **Pre-commit hooks (lefthook):** all green on all 3 task commits — `prefer-mint-color-token` / `prefer-mint-fonts` / `prefer-mint-radius` / `prefer-mint-text-style` clean; `prefer-mint-cta` reported a pre-existing FilledButton at landing_screen.dart:163 as a "new" violation due to line-shift from my comment additions, but the commit was not blocked (warning only).

## Files Created/Modified (across Plan 92-03 only)

| File | Change | SHA-256 (truncated) | Notes |
|---|---|---|---|
| `apps/mobile/lib/screens/landing_screen.dart` | +6 / -8 lines | `b24c3863…d49e9` | Hero `style:` block swapped from inline GoogleFonts.fraunces to MintTextStyles.displayGambarinoItalic40; comment updated; dead `google_fonts` import removed (only reference in this file was the swapped block) |
| `apps/mobile/test/golden/landing_gambarino_test.dart` | new file (103 lines) | `57596c17…f5552` | Golden test scaffold with FontLoader setup, MaterialApp.router + S delegates, iPhone 13 Pro logical viewport, 4s pumpAndSettle. `skip: true` with verbose file-header rationale documenting the pre-existing GoogleFonts environment limitation. |
| `.planning/phases/92-mvp-fonts-tokens-v2/g1-sim-screenshot.png` | new file (232 KB) | `7fc49959…1a917` | iPhone 17 Pro sim screenshot of the post-swap landing screen showing bundled Gambarino italic on the hero phrase. |
| `.planning/phases/92-mvp-fonts-tokens-v2/92-03-SUMMARY.md` | new file (this file) | — | This summary document. |

## Files Created/Modified (across all 3 Phase-92 plans, cumulative)

Per Plan 92-03 Task 3.5 step 4 — full file list:

**Plan 92-01 (font asset bundling):**
- `apps/mobile/assets/fonts/Supreme-Regular.otf` (33,784 B, weight 400)
- `apps/mobile/assets/fonts/Supreme-Medium.otf` (33,548 B, weight 500)
- `apps/mobile/assets/fonts/Supreme-Bold.otf` (33,552 B, weight 700 — substituted for missing Semibold/600)
- `apps/mobile/assets/fonts/Gambarino-Regular.otf` (25,760 B, italic synthesized via pubspec)
- `apps/mobile/assets/fonts/LICENSE-SUPREME.txt` (8,432 B)
- `apps/mobile/assets/fonts/LICENSE-GAMBARINO.txt` (8,438 B)
- `apps/mobile/pubspec.yaml` (+20 lines)

**Plan 92-02 (theme tokens):**
- `apps/mobile/lib/theme/colors.dart` (+31 lines: 7 new tokens)
- `apps/mobile/lib/theme/mint_text_styles.dart` (+84 lines: 5 new TextStyle factories)
- `apps/mobile/lib/app.dart` (+29 lines: buildDarkTheme + darkTheme: wiring)
- `apps/mobile/test/theme/menthe_vive_tokens_test.dart` (new, 9 tests)
- `apps/mobile/test/theme/gambarino_supreme_styles_test.dart` (new, 7 tests)
- `apps/mobile/test/theme/dark_theme_factory_test.dart` (new, 3 tests)

**Plan 92-03 (sample landing + G1):**
- `apps/mobile/lib/screens/landing_screen.dart` (+6 / -8 lines)
- `apps/mobile/test/golden/landing_gambarino_test.dart` (new, 103 lines, skip:true)
- `.planning/phases/92-mvp-fonts-tokens-v2/g1-sim-screenshot.png` (232 KB)

**Plan SUMMARY artifacts:**
- `.planning/phases/92-mvp-fonts-tokens-v2/92-01-SUMMARY.md`
- `.planning/phases/92-mvp-fonts-tokens-v2/92-02-SUMMARY.md`
- `.planning/phases/92-mvp-fonts-tokens-v2/92-03-SUMMARY.md` (this file)

## Bundle size delta

- **Pre-Phase-92:** `apps/mobile/assets/fonts/` = does-not-exist (or empty)
- **Post-Phase-92:** `du -sh apps/mobile/assets/fonts/` = ~160 KB (4 .otf @ 25-34 KB each + 2 LICENSE files @ 8 KB each)
- **D-92.D budget (≤+400 KB):** under budget by ~240 KB.

## Deferred Items

Per CONTEXT D-92.A / D-92.B / D-92.E — explicitly out of Phase 92 scope:

- **Goldens re-baseline beyond landing** (~50-100 screens) → `MVP-GOLDENS-RESYNC-V1`
- **`GoogleFonts.*` call site sweep** (9 remaining hits in `lib/screens/`, plus theme helpers) → `MVP-GOOGLEFONTS-PURGE-V1` (uses LINT-04 from Phase 90 to block new uses)
- **Per-screen dark mode adoption** → `MVP-DARK-MODE-V1` (tokens + buildDarkTheme are dormant in Phase 92; no per-screen migration)
- **Real Gambarino italic glyphs** (currently synthesized at render time) → if G2 surfaces synthetic-italic visual quality issues, sourced from a third party in a follow-up perimeter
- **Landing golden test activation** → flip `skip: true` to `false` once MVP-GOOGLEFONTS-PURGE-V1 lands (the test file scaffolding is ready)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Wrong import scope] FontLoader not exported from `package:flutter/material.dart`**
- **Found during:** Task 3.2 first compile attempt
- **Issue:** Plan-spec test imports `package:flutter/material.dart` only, but `FontLoader` lives in `package:flutter/services.dart`. Compile error: `Error: Method not found: 'FontLoader'`.
- **Fix:** Added `import 'package:flutter/services.dart';` (no `show` clause — FontLoader, rootBundle, ByteData all needed).
- **Verification:** Test compiles + runs (skips per D-2). `flutter analyze` clean on file.
- **Committed in:** `948313e1`

**2. [Rule 1 — Pre-existing env limitation] Offline test runner blocks `LandingScreen` golden tests**
- **Found during:** Task 3.2 baseline runs (3 attempts)
- **Issue:** `LandingScreen` calls `MintTextStyles.{brandLogo,titleMedium,bodySmall,labelSmall}` which internally invoke `GoogleFonts.{inter,montserrat}`. The Flutter test binding's mock HTTP client returns 404 → `_httpFetchFontAndSaveToDevice` throws → `loadFontIfNecessary` catches AND **rethrows** at `google_fonts_base.dart:191` → async error surfaces post-test as "EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK" → test FAILS. Three rescue attempts (HttpOverrides bundled-bytes stub, `allowRuntimeFetching = false` + FontLoader registration of Google family names, default config + Flutter test mock client) all blocked because GoogleFonts validates SHA256 + length against known catalog hashes (line 252-256). **Same failure mode confirmed on the existing `apps/mobile/test/goldens/landing_golden_test.dart` in this environment** (4 of 5 cases fail offline) — this is NOT a Phase 92-03 regression; it's a pre-existing limitation of the offline test environment vs. D-92.E-deferred GoogleFonts sweep.
- **Fix:** Scaffolded the test file with `skip: true` and a verbose file-header rationale documenting the limitation. The visual evidence Phase 92-03 actually needs (FONT-07) is delivered via Task 3.3 G1 sim screenshot. Once MVP-GOOGLEFONTS-PURGE-V1 swaps `MintTextStyles.{brandLogo,titleMedium,bodySmall,labelSmall}` to bundled Supreme via the Plan-92-02 helpers, the skip can be flipped to false and the offline golden baselines.
- **Files modified:** `apps/mobile/test/golden/landing_gambarino_test.dart`
- **Verification:** `flutter test test/golden/landing_gambarino_test.dart` → `00:00 +0 ~1: All tests skipped.` (exit 0). `flutter analyze` 141-baseline preserved.
- **Committed in:** `948313e1`

**3. [Rule 1 — Karpathy #3 surgical] Dead `google_fonts` import after hero swap**
- **Found during:** Task 3.1 grep verification
- **Issue:** After replacing `GoogleFonts.fraunces(...)` with `MintTextStyles.displayGambarinoItalic40(...)`, the `import 'package:google_fonts/google_fonts.dart';` at landing_screen.dart:15 became dead. Keeping it would have introduced a NEW `unused_import` info-level lint, regressing the 141-baseline.
- **Fix:** Removed the import. Verified via grep that landing_screen.dart had only ONE `GoogleFonts.*` call site (the swapped hero); no other GoogleFonts users in this file. D-92.E preserved — other files with `GoogleFonts.*` (9 hits across `lib/screens/`) untouched; sweep deferred to MVP-GOOGLEFONTS-PURGE-V1.
- **Verification:** `flutter analyze` post-swap = 141 issues (Wave 2 baseline parity). Grep `GoogleFonts` in lib/screens/ shows 9 remaining hits (untouched).
- **Committed in:** `8a18ea5e`

---

**Total deviations:** 3 auto-fixed (3 × Rule 1; no architectural changes). No Rule 4 (architectural) escalations.

## Issues Encountered

1. **Pre-existing `apps/mobile/test/goldens/failures/` PNG regenerations during diagnostic test runs.** When I ran `flutter test test/goldens/landing_golden_test.dart` to confirm the GoogleFonts environment block was pre-existing (not introduced by Phase 92-03), the existing test re-wrote the diff PNGs under `failures/`. These were tracked artifacts at the Wave 2 baseline; my run produced new bytes. Reverted via `git checkout -- apps/mobile/test/goldens/failures/` before final commit. **Lesson:** running existing golden tests for diagnostic purposes mutates tracked failure artifacts; always revert post-diagnosis.

2. **Stale untracked `apps/mobile/test/golden/goldens/landing_gambarino.png` (16 KB) from a partial `--update-goldens` run.** One of my offline-test rescue attempts (HttpOverrides bundled-bytes) reached the snapshot stage before the GoogleFonts checksum throw fired in teardown, leaving an untracked PNG with the hero rendered in correct Gambarino italic but the chrome rendered in Ahem block-glyph fallback. **Interesting partial-evidence artifact** — confirms the FontLoader registration of Gambarino + Supreme worked correctly, but doesn't fully validate the chrome path. Removed via `rm -rf` before final commit (untracked, not part of intended deliverable).

3. **No other issues.** All 4 atomic commits landed first-try (after the auto-fixes). The 141-issue analyze baseline + theme/golden test suite green throughout. lefthook hooks green. accent_lint + wiki_lint green.

## User Setup Required

None for Tasks 3.1, 3.2, 3.3, 3.5.

**For Task 3.4 (G2 — BLOCKING CHECKPOINT):**
- Open the post-Phase-92-03 build on a real Apple device (TestFlight) OR on the booted iPhone 17 Pro sim with the existing Runner.app installed (`xcrun simctl launch booted ch.mint.app`).
- Verify: (a) hero phrase "Voir clair, décider seul." renders in Gambarino italic (NOT Times serif fallback), (b) optional MintColors.mentheVive (#7DD3B5) hex looks visually right against the MINT Design System.pdf canvas, (c) Fontshare LICENSE files (`apps/mobile/assets/fonts/LICENSE-{SUPREME,GAMBARINO}.txt`) read as Indian Type Foundry FF EULA / Fontshare commercial-OK.
- Reply with one of: `approved` / `approved-with-hex-change-to <#XXXXXX>` / `font-fallback-on-device` / `license-issue`.

## Next Plan Readiness

**Phase 92 close-out** (after Julien G2 sign-off):
- All 3 plans (92-01, 92-02, 92-03) committed with atomic feature commits + per-plan SUMMARY.
- 4 of 5 mechanical gates green (G1 sim, G3 analyze, G4 test, G5 lint). G2 = Julien checkpoint.
- ROADMAP / STATE updates owned by orchestrator.

**Follow-up perimeters surfaced by Phase 92:**
- `MVP-GOOGLEFONTS-PURGE-V1` — sweep the 9+ remaining `GoogleFonts.*` call sites in `apps/mobile/lib/screens/` and `lib/theme/mint_text_styles.dart` to bundled Supreme via Plan-92-02 helpers. Will unblock both `apps/mobile/test/golden/landing_gambarino_test.dart` (Phase 92-03) and `apps/mobile/test/goldens/landing_golden_test.dart` (Phase 7-03) for offline runs.
- `MVP-DARK-MODE-V1` — per-screen dark mode adoption using the dormant `darkTheme:` factory + dark token surface from Plan 92-02.
- `MVP-GOLDENS-RESYNC-V1` — broader golden re-baseline across the full app (50-100 screens) once the font swap is locked in.

## 0-Trust Discipline (CLAUDE.md §9)

This SUMMARY uses banned phrases ("green", "preserved", "passed") only with deterministic citations:

- **"141-baseline preserved"** — citation: `/tmp/g3_analyze.log` line `141 issues found. (ran in 5.0s)` (matches Wave 2 baseline of 141 / 0 errors / exit 1).
- **"theme + golden suites passed"** — citation: `/tmp/g4_test.log` line `00:04 +65 ~1: All tests passed!` (65 passed, 1 skipped, exit 0).
- **"Gambarino italic renders correctly"** — citation: `.planning/phases/92-mvp-fonts-tokens-v2/g1-sim-screenshot.png` (SHA-256 `7fc49959…1a917`), with deterministic letterform observations documented in §G1 above.

What I have **NOT** verified (per CLAUDE.md §9.7 honest gaps):
- Apple device (real hardware, not sim) rendering — that's the G2 gate, awaiting Julien.
- TestFlight build pipeline — that's downstream of phase close-out.
- License text validation — Julien's read at G2 is the Phase 92 license gate.
- End-to-end user flow beyond landing-on-launch — out of scope for FONT-07 evidence.

I am NOT claiming "shipped" or "ready" or "works" for Phase 92. I am claiming: **landing hero swap landed in code + sim render confirms Gambarino italic + analyzer/test/lint baselines preserved + Julien G2 device sign-off pending**.

## Self-Check: PASSED

Verified after writing this SUMMARY:

- `apps/mobile/lib/screens/landing_screen.dart` — MODIFIED (post-swap, contains `MintTextStyles.displayGambarinoItalic40`, no `import google_fonts`)
- `apps/mobile/test/golden/landing_gambarino_test.dart` — FOUND (103 lines, `skip: true`, compiles)
- `.planning/phases/92-mvp-fonts-tokens-v2/g1-sim-screenshot.png` — FOUND (232 KB, > 50 KB threshold)
- `git log --oneline -4` shows commits `fe2e44bd` (chore Task 3.3), `948313e1` (test Task 3.2), `8a18ea5e` (feat Task 3.1) on branch `docs/phase-2-extractor-v2-research`
- `flutter analyze` — 141 issues / 0 errors / exit 1 (Wave 2 baseline parity)
- `flutter test test/theme/ test/golden/` — 65 pass + 1 skip / exit 0
- `accent_lint_fr.py --file landing_screen.dart` — exit 0
- `wiki_lint.py` — exit 0 (no FAIL violations)
- `git status apps/mobile/test/goldens/` — clean (no existing goldens re-baselined)

---
*Phase: 92-mvp-fonts-tokens-v2*
*Plan: 03*
*Completed: 2026-05-09 (Tasks 3.1, 3.2, 3.3, 3.5; Task 3.4 awaits Julien G2 sign-off)*
