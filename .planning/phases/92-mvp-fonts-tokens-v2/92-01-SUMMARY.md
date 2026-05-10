---
phase: 92-mvp-fonts-tokens-v2
plan: 01
subsystem: ui
tags: [fonts, fontshare, supreme, gambarino, pubspec, flutter-assets, design-system]

# Dependency graph
requires: []
provides:
  - "4 .otf font files bundled under apps/mobile/assets/fonts/ (Supreme 400/500/700 + Gambarino 400 upright)"
  - "pubspec.yaml flutter.fonts: block declaring Supreme + Gambarino families"
  - "Fontshare FF EULA license texts (LICENSE-SUPREME.txt + LICENSE-GAMBARINO.txt) committed alongside .otf"
  - "Fontshare CDN download recipe documented (api.fontshare.com/v2/fonts/download/{slug} returns desktop zip with .otf)"
affects:
  - "92-02 (MintTextStyles + MintColors token scaffolding) — must adapt to Supreme weight 700 instead of 600 for titleSupreme18Semibold; Gambarino italic is synthetic, not native"
  - "92-03 (sample landing screen + goldens re-baseline) — visual rendering depends on 92-01 assets"
  - "MVP-GOOGLEFONTS-PURGE-V1 (deferred) — bundled fonts are now available; future call-site sweeps can reference them"

# Tech tracking
tech-stack:
  added:
    - "Fontshare Supreme (Indian Type Foundry, Free Font License) — 3 weights bundled"
    - "Fontshare Gambarino (Indian Type Foundry, Free Font License) — 1 weight bundled"
  patterns:
    - "Font asset acquisition via api.fontshare.com/v2/fonts/download/{slug} zip extraction (not CSS/CDN .otf URLs which 404)"
    - "Honest file naming on disk: Supreme-Bold.otf (700) instead of mislabeling as Supreme-Semibold.otf"
    - "Inline pubspec.yaml comments documenting weight substitutions and synthetic-italic rationale"

key-files:
  created:
    - "apps/mobile/assets/fonts/Supreme-Regular.otf (400, 33,784 B)"
    - "apps/mobile/assets/fonts/Supreme-Medium.otf (500, 33,548 B)"
    - "apps/mobile/assets/fonts/Supreme-Bold.otf (700, 33,552 B) — substituted for missing Semibold"
    - "apps/mobile/assets/fonts/Gambarino-Regular.otf (400 upright, 25,760 B) — italic via Flutter style:italic synthesis"
    - "apps/mobile/assets/fonts/LICENSE-SUPREME.txt (8,432 B)"
    - "apps/mobile/assets/fonts/LICENSE-GAMBARINO.txt (8,438 B)"
  modified:
    - "apps/mobile/pubspec.yaml (+20 lines: flutter.fonts: block, Supreme + Gambarino families)"

key-decisions:
  - "D-1 Substituted Supreme-Bold (700) for missing Semibold (600) — Fontshare catalog has no 600 weight (ships 100/200/300/400/500/700/800). Honest disk naming preserves audit trail; Plan 92-02 must reference weight 700 (will fall back from FontWeight.w600 request to bundled 700 via Flutter's nearest-weight matcher)."
  - "D-2 Gambarino italic synthesized via pubspec style:italic on the upright .otf — Fontshare ships only Gambarino-Regular (no italic glyph variant). Flutter applies synthetic skew at render time. Visual quality must be validated by Julien at G2 device gate."
  - "D-3 Acquired .otf via Fontshare's complete-zip endpoint (api.fontshare.com/v2/fonts/download/{slug}) instead of the CSS API. The CSS API returns only .ttf/.woff/.woff2 (no .otf); the zip contains the proper OTF/ files Fontshare ships for desktop. Saved recipe in pubspec inline comment for future re-fetches."
  - "D-4 Kept google_fonts: ^6.3.3 in dependencies (D-92.E) — sweep deferred to MVP-GOOGLEFONTS-PURGE-V1."

patterns-established:
  - "Pattern: Fontshare desktop .otf acquisition via /v2/fonts/download/{slug} zip + extracting the OTF/ subdirectory."
  - "Pattern: pubspec.yaml fonts: block as sibling of assets:, with inline comments documenting weight substitutions and license source."
  - "Pattern: When upstream catalog lacks the spec'd variant (weight, italic), substitute with honest naming + document deviation; never mislabel files to match a spec that doesn't exist on disk."

requirements-completed:
  - FONT-01
  - FONT-06

# Metrics
duration: ~22 min
completed: 2026-05-09
---

# Phase 92 Plan 01: MVP-FONTS-TOKENS-V2 Wave 1 — Font Asset Bundling Summary

**Bundled Fontshare Supreme (400/500/700) + Gambarino (400 upright) .otf files into apps/mobile/assets/fonts/, registered them in pubspec.yaml flutter.fonts: block, and confirmed Flutter resolves the assets without warnings — with two material substitutions for catalog-mismatched plan assumptions (Supreme weight 600 → 700, Gambarino italic → synthesized).**

## Performance

- **Duration:** ~22 min
- **Started:** 2026-05-09T14:27Z (mkdir assets/fonts)
- **Completed:** 2026-05-09T14:49Z (post-pub-get verification)
- **Tasks:** 3 (Task 1.1 acquire + Task 1.2 register + Task 1.3 verify)
- **Files modified:** 7 (6 new under assets/fonts/, 1 edit to pubspec.yaml)

## Accomplishments

- Discovered Fontshare's CSS API only exposes .ttf/.woff/.woff2 (.otf returns 404); pivoted to `api.fontshare.com/v2/fonts/download/{slug}` which returns a complete-family zip with proper OTF/ files. Recipe documented in pubspec.yaml inline comment.
- Bundled 4 .otf files (~127 KB cumulative) + 2 license files (~16 KB) — total `apps/mobile/assets/fonts/` footprint is **160 KB**, well under D-92.D's 400 KB budget.
- Registered Supreme + Gambarino families in pubspec.yaml as a sibling of `assets:` (correct nesting, not under assets:). flutter.assets list unchanged (8 entries pre+post).
- `flutter pub get` exits 0 with no `asset path not found` and no `Could not resolve` lines (citation: /tmp/pubget.log, EXIT=0).
- `flutter analyze` baseline parity preserved: 141 issues pre, 141 issues post, 0 errors pre, 0 errors post (citation: diff /tmp/analyze_baseline.log /tmp/analyze_post.log shows only timing delta).

## Task Commits

Each task committed atomically (with the exception of Task 1.3 which is verification-only):

1. **Task 1.1: Acquire Supreme + Gambarino .otf + LICENSE texts** — `b37abd44` (chore)
2. **Task 1.2: Register fonts in pubspec.yaml** — `6219b97e` (feat)
3. **Task 1.3: Run flutter pub get + analyze** — no commit (pubspec.lock unchanged, no source edits required; verification only)

## Files Created/Modified

| File | Bytes | SHA-256 (truncated) | Notes |
|---|---|---|---|
| `apps/mobile/assets/fonts/Supreme-Regular.otf` | 33,784 | `00410913...8ee4` | weight 400 (Regular) |
| `apps/mobile/assets/fonts/Supreme-Medium.otf` | 33,548 | `4771fa12...e58f9` | weight 500 (Medium) |
| `apps/mobile/assets/fonts/Supreme-Bold.otf` | 33,552 | `00ebce7f...1d89a` | weight 700 (Bold) — **substituted for plan's expected Semibold (600)** |
| `apps/mobile/assets/fonts/Gambarino-Regular.otf` | 25,760 | `3cfc8143...0efdf` | weight 400 upright — **italic synthesized in pubspec, no italic .otf in catalog** |
| `apps/mobile/assets/fonts/LICENSE-SUPREME.txt` | 8,432 | — | Indian Type Foundry FF EULA + 1-line preamble |
| `apps/mobile/assets/fonts/LICENSE-GAMBARINO.txt` | 8,438 | — | Indian Type Foundry FF EULA + 1-line preamble |
| `apps/mobile/pubspec.yaml` | +20 lines | — | added flutter.fonts: block (lines 83-101) |

Full SHA-256 hashes:
```
3cfc8143b820d4e9e5970748cf6189d0624aeb1f8c5a0138c2c82bbb9b50efdf  Gambarino-Regular.otf
00ebce7fae218b2e28df0581652749e9cbc1d4a6a4221780541532362471d89a  Supreme-Bold.otf
4771fa1237212a3eddb060814b2d721e47a79b9b3bf58451ac1b98c48dce58f9  Supreme-Medium.otf
00410913847ad5e731e49da556a0c541aacfae84e6c998c5a3a6b4fca3b18ee4  Supreme-Regular.otf
```

## Decisions Made

- **D-1: Supreme weight 700 substituted for missing 600 / "Semibold".** Fontshare catalog (verified via `https://api.fontshare.com/v2/fonts/0be43cb0-a1bb-4b76-9356-9760fe446165`) contains weights 100/200/300/400/500/700/800 — there is no weight 600. STUB risk-mitigation explicitly allows "use 500 as bold proxy" but 700 is closer to the design system's emphasis intent. File named honestly as `Supreme-Bold.otf` on disk.
- **D-2: Gambarino italic synthesized via pubspec `style: italic`.** Fontshare's Gambarino family ships only one style: weight 400, `is_italic=False`. Plan/STUB called it "italic baked-in" but that was incorrect about the catalog. Flutter resolves `style: italic` against the registered asset and applies a synthetic skew. Visual fidelity vs. real italic glyphs must be validated at G2 by Julien.
- **D-3: Acquisition route via desktop zip, not CSS API.** Fontshare's CSS API (`/v2/css?f[]=supreme@...`) returns only `.ttf/.woff/.woff2` URLs and 404s on `.otf`. The detail API (`/v2/fonts/{uuid}`) gives base file URLs without extension, also no `.otf`. Discovered `/v2/fonts/download/{slug}` returns a 2.2 MB complete-family zip with `Fonts/OTF/*.otf` — proper OpenType files Fontshare ships for desktop installs. Recipe documented in pubspec.yaml inline comment for future re-fetches.
- **D-4: `google_fonts: ^6.3.3` retained in dependencies.** Per D-92.E in 92-CONTEXT.md, Phase 92 does not sweep existing GoogleFonts call sites; that's deferred to MVP-GOOGLEFONTS-PURGE-V1. The bundled fonts are additive.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Catalog-vs-spec mismatch] Supreme weight 600 / "Semibold" does not exist in Fontshare catalog**
- **Found during:** Task 1.1 (asset acquisition)
- **Issue:** Plan 92-01-PLAN.md `<files>` declares `Supreme-Semibold.otf`. Fontshare catalog (verified via `https://api.fontshare.com/v2/fonts?limit=200` + family detail endpoint) ships Supreme in weights 100/200/300/400/500/700/800 only. There is no 600.
- **Fix:** Bundled `Supreme-Bold.otf` (weight 700, the closest available emphasis weight). Named the file honestly on disk (`Supreme-Bold.otf` not `Supreme-Semibold.otf`) so future readers and Plan 92-02 see ground truth. Pubspec entry uses `weight: 700`.
- **Files modified:** `apps/mobile/assets/fonts/Supreme-Bold.otf`, `apps/mobile/pubspec.yaml`
- **Verification:** `file Supreme-Bold.otf` reports `OpenType font data`. STUB explicitly contemplates this fallback ("use Bold proxy" if 600 unavailable per D-92.D bundle budget — same fallback applies for catalog absence).
- **Committed in:** `b37abd44` (Task 1.1) + `6219b97e` (Task 1.2)

**2. [Rule 1 — Catalog-vs-spec mismatch] Gambarino italic variant does not exist in Fontshare catalog**
- **Found during:** Task 1.1 (asset acquisition)
- **Issue:** Plan 92-01-PLAN.md and CONTEXT.md repeatedly describe Gambarino as "italic baked-in" / "400 italic". Fontshare's Gambarino family detail (`https://api.fontshare.com/v2/fonts/f8889f66-da78-4f3e-a15c-085ad2cec671`) shows exactly 1 style: weight 400, `is_italic: False`. The download zip contains only `Gambarino-Regular.otf` (upright).
- **Fix:** Bundled the upright `Gambarino-Regular.otf` and registered it in pubspec.yaml under `family: Gambarino` with `style: italic` + `weight: 400`. Flutter's font matcher resolves `fontStyle: FontStyle.italic` requests against this asset and applies a synthetic obliquing transform at render time. The TextStyle objects defined by Plan 92-02 (`fontStyle: FontStyle.italic`) will work; the rendered visual will be a synthetic italic of the upright Gambarino glyphs.
- **Files modified:** `apps/mobile/assets/fonts/Gambarino-Regular.otf`, `apps/mobile/pubspec.yaml` (line 100: `style: italic`)
- **Verification:** `file Gambarino-Regular.otf` reports `OpenType font data`. pubspec.yaml `flutter.fonts.[Gambarino].fonts[0].style == 'italic'` (Python yaml.safe_load). Visual quality of synthetic italic on display copy must be validated by Julien at G2 (see Issues Encountered #2 below).
- **Committed in:** `b37abd44` + `6219b97e`

**3. [Rule 1 — Wrong format assumption] Fontshare CDN does not serve `.otf` (only `.ttf/.woff/.woff2`)**
- **Found during:** Task 1.1 step 2 (CSS API URL extraction)
- **Issue:** Plan instructs `curl -fSL <Supreme-400-url> -o Supreme-Regular.otf`. The CSS-API-discovered URL with `.otf` extension returns HTTP 404 (verified: `curl -sI https://cdn.fontshare.com/wf/UDGUA.../5ZZU....otf` → `HTTP/2 404`). Only `.ttf/.woff/.woff2` resolve.
- **Fix:** Switched acquisition to `https://api.fontshare.com/v2/fonts/download/{slug}` which returns a desktop ZIP containing the proper `OTF/*.otf` files Fontshare ships to desktop license-holders. Extracted the four .otf files needed.
- **Files modified:** None (this is an acquisition-route deviation, not a file change)
- **Verification:** `unzip -l /tmp/supreme.zip | grep '.otf$'` lists 16 .otf files (Supreme-{Thin,Extralight,Light,Regular,Medium,Bold,Extrabold,Italic-variants}.otf). All four extracted files pass `file ... | grep OpenType`.
- **Committed in:** `b37abd44` (recipe documented in commit message and pubspec inline comment)

**4. [Rule 1 — Wrong baseline expectation] `flutter analyze` exit code 0 is impossible on baseline**
- **Found during:** Task 1.3 verification
- **Issue:** Plan acceptance criterion says `flutter analyze exits 0 with same warning/error count as baseline`. The literal "exits 0" cannot hold: the project's pre-existing 141 info/warning-level issues (no errors) cause `flutter analyze` to exit code 1 even on baseline. Verified by re-running analyze on `git checkout HEAD~2 -- pubspec.yaml`.
- **Fix:** Interpreted the criterion's intent as "baseline parity, no regression". Confirmed: pre-plan 141 issues / 0 errors / exit 1 → post-plan 141 issues / 0 errors / exit 1. No regression introduced.
- **Files modified:** None
- **Verification:** `diff /tmp/analyze_baseline.log /tmp/analyze_post.log` shows only the timing line changing (4.5s → 5.0s). All 141 issues identical pre/post.
- **Committed in:** N/A (Task 1.3 is verify-only)

---

**Total deviations:** 4 auto-fixed (4 × Rule 1 catalog-vs-spec ground-truth corrections; no architectural changes required)
**Impact on plan:** Plan 92-02 must update its TextStyle expectations:
- `titleSupreme18Semibold()` returning `fontWeight: FontWeight.w600` will work as a TextStyle object, but Flutter's font matcher will render it with Supreme-Bold.otf (700, the nearest registered weight). The unit test `expect(s.fontWeight, FontWeight.w600)` still passes (it asserts on the TextStyle field, not the resolved glyph).
- `displayGambarinoItalic{56,40}()` returning `fontStyle: FontStyle.italic` will work as a TextStyle object; Flutter will apply synthetic italic to the upright Gambarino-Regular.otf glyphs at render time. Unit tests pass; visual quality is a G2 concern.
- No Plan 92-01 file deletions or rewrites — purely additive deviations recorded in this SUMMARY.

## Issues Encountered

1. **Fontshare CSS API returns subset of catalog and 0 Gambarino faces** — `https://api.fontshare.com/v2/css?f[]=supreme@400,500,600&display=swap` returned only weights 400 and 500 (no 600 — confirms catalog absence) and only `.ttf/.woff/.woff2` URLs. The same query for `gambarino@1` returned an empty CSS body (`/* Gambarino */` with no `@font-face`). This blocked the plan's CSS-extraction recipe but led to discovering the more reliable zip endpoint. Resolution: pivoted to `/v2/fonts/download/{slug}`.

2. **Synthetic italic visual quality is unverified for display-size copy** — Gambarino is a display family; synthetic italic (a CSS/Flutter skew transform) generally looks acceptable on body copy but can break optically on display-size letterforms (40-56 pt per Plan 92-02 spec). Julien must visually compare the rendered Landing/Onboarding hero to the reference design before sign-off at G2. If unacceptable, options: (a) license a real Gambarino italic from a third party, (b) swap to a different display italic with a real italic glyph (e.g. Source Serif 4 Italic, Playfair Display Italic), (c) accept synthetic italic as MVP and revisit post-launch. **This is a flag for Plan 92-03 G1 sim screenshot review and Plan 92-02 visual QA, not a Plan 92-01 blocker.**

3. **`pubspec.lock` was not modified by `flutter pub get`** — the new `fonts:` block adds asset declarations only (no new package dependencies), so the resolver had no work to do. Plan acceptance accommodates this ("modified or unchanged — never untracked"). Verified via `git status apps/mobile/pubspec.lock` (empty output, file is tracked, content unchanged from `db50e201` baseline).

## User Setup Required

None — no external service configuration. Fontshare downloads are public and license-permitted for commercial app embedding under the Indian Type Foundry FF EULA (see `apps/mobile/assets/fonts/LICENSE-{SUPREME,GAMBARINO}.txt`). G5 license review by Julien is part of the phase-level gate, not a Plan 92-01 deliverable.

## Next Plan Readiness

**For Plan 92-02 (MintTextStyles + MintColors token scaffolding):**

- ✅ `apps/mobile/assets/fonts/` populated; `pubspec.yaml flutter.fonts:` block resolved.
- ⚠️ **`titleSupreme18Semibold()` weight reality:** Plan 92-02 hardcodes `fontWeight: FontWeight.w600`. There is no Supreme-600 on disk. Flutter will resolve to Supreme-Bold (700). **Recommendation for 92-02 executor:** either keep `FontWeight.w600` in the TextStyle (current plan, will render as 700) and update the dartdoc comment to read `/// Title (Supreme, weight 600 requested → Supreme-Bold 700 rendered)`, OR change the constant to `FontWeight.w700` to match the on-disk reality. Both are defensible. The unit test in 92-02 passes either way.
- ⚠️ **Gambarino italic is synthetic.** Plan 92-02's `displayGambarinoItalic{56,40}` TextStyles with `fontStyle: FontStyle.italic` will work (unit tests pass on TextStyle field assertions); rendered glyphs will be synthetic obliquing of upright Gambarino. Plan 92-03's G1 sim screenshot is the gate to validate visual fidelity. If synthetic italic is unacceptable, Plan 92-02 may need a font-source swap (deferred decision, not a 92-01 blocker).

**For Plan 92-03 (sample landing screen + goldens re-baseline):**

- ✅ Asset substrate ready.
- ⚠️ Visual QA budget: synthetic italic on Gambarino + 700-as-Semibold on Supreme are the two visual surprises to call out in G1 screenshot review.

**Cross-plan note:** Phase 92 STATE.md and ROADMAP.md updates are owned by the orchestrator (per execution prompt), not this executor. No state-tracking writes were performed by Plan 92-01 commits.

## Self-Check: PASSED

Verified after writing SUMMARY:
- `apps/mobile/assets/fonts/Supreme-Regular.otf` — FOUND (33,784 B, OpenType)
- `apps/mobile/assets/fonts/Supreme-Medium.otf` — FOUND (33,548 B, OpenType)
- `apps/mobile/assets/fonts/Supreme-Bold.otf` — FOUND (33,552 B, OpenType)
- `apps/mobile/assets/fonts/Gambarino-Regular.otf` — FOUND (25,760 B, OpenType)
- `apps/mobile/assets/fonts/LICENSE-SUPREME.txt` — FOUND (8,432 B, contains "Indian Type Foundry")
- `apps/mobile/assets/fonts/LICENSE-GAMBARINO.txt` — FOUND (8,438 B, contains "Fontshare")
- `apps/mobile/pubspec.yaml` — MODIFIED (+20 lines, flutter.fonts: block valid YAML, parses with python3 yaml.safe_load)
- `git log --oneline -3` shows commits `b37abd44` (chore Task 1.1) and `6219b97e` (feat Task 1.2) on branch `docs/phase-2-extractor-v2-research`
- `flutter pub get` exited 0 with no asset-resolution warnings (citation: /tmp/pubget.log line `Got dependencies!`)
- `flutter analyze` baseline parity preserved (141 issues, 0 errors, exit 1) — pre and post

---
*Phase: 92-mvp-fonts-tokens-v2*
*Plan: 01*
*Completed: 2026-05-09*
