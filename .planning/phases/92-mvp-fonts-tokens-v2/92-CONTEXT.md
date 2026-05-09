---
phase: 92-mvp-fonts-tokens-v2
description: Foundation perimeter for MINT v2 design system. Bundle Fontshare Supreme + Gambarino .otf into apps/mobile, kill GoogleFonts runtime dependency, add MintColors.mentheVive token, scaffold dark palette + ThemeData.dark factory. Pre-requisite blocker for all v2 perimeters (onboarding-v2, coach-v2-artefacts, etc.).
gathered: 2026-05-09
status: Ready for planning
source: STUB-driven (.planning/decisions/2026-05-08-perimeter-mvp-fonts-tokens-v2/STUB.md is the spec; this CONTEXT just transposes it into GSD format with explicit "Claude's Discretion" calls on open items)
---

# Phase 92: MVP-FONTS-TOKENS-V2 — Context

<domain>
## Phase Boundary

**Deliver** the foundation visuelle MINT v2 dans le mobile codebase :

1. **Supreme** (UI font) — 400, 500, 600 weights, bundled `.otf` under `apps/mobile/assets/fonts/`
2. **Gambarino** (display, italic) — 400 weight, italic baked-in
3. `MintColors.mentheVive` token (vert-cyan vif, default `#7DD3B5` per STUB pixel-sample) + `mentheVive12` (12% opacity surface)
4. `MintTextStyles.displayGambarinoItalic{56,40}` (Landing hero + Onboarding hero) + `titleSupreme18Semibold` + `bodySupreme15Regular` + `labelSupreme12Uppercase025LS`
5. Dark palette tokens (`MintColors.dark*`) + `ThemeData.dark` factory in `app.dart`
6. Sample landing screen using new Gambarino italic — visual proof gate (G1 sim screenshot)
7. Fontshare license texts committed (LICENSE-SUPREME.txt + LICENSE-GAMBARINO.txt)

**Out of scope** (deferred to follow-up perimeters):
- Screen-by-screen dark mode adoption (this phase only adds the tokens + ThemeData.dark; per-screen `colorScheme.brightness` rollout is `MVP-DARK-MODE-V1` later)
- Goldens re-baseline beyond the 3-5 must-have screens (landing, onboarding hero, chat opener) — wider re-baseline lives in `MVP-GOLDENS-RESYNC-V1`
- Removing every `GoogleFonts.*` call site app-wide — Phase 92 keeps the wrapper; LINT-04 (Phase 90 baseline) blocks NEW GoogleFonts uses; existing call sites get swept in `MVP-GOOGLEFONTS-PURGE-V1`

</domain>

<decisions>
## Implementation Decisions

### Locked decisions from STUB (frozen — see source)

- **Fonts:** Supreme (400/500/600) + Gambarino (400 italic). Fontshare commercial-OK license per STUB risk #1 — Julien validates ToS on the LICENSE files at G5 commit.
- **Menthe-vive default hex:** `#7DD3B5` (STUB pixel-sample of MINT Design System.pdf). Julien confirms or adjusts visually post-merge; not blocking.
- **MintColors token names:** `mentheVive`, `mentheVive12` (12% opacity).
- **MintTextStyles names:** `displayGambarinoItalic56`, `displayGambarinoItalic40`, `titleSupreme18Semibold`, `bodySupreme15Regular`, `labelSupreme12Uppercase025LS`.
- **Dark palette token names:** `darkBg`, `darkInk`, `darkInkSoft`, `darkBorderSubtle`, `darkMentheVive` (saturé pour contrast).
- **5 mechanical gates (G1-G5)** per STUB §5 — sim screenshot, device sign-off (Julien), dev CI, regression goldens, license + lint.
- **Effort budget:** 0.6j (~5h work) per STUB.

### Claude's Discretion (decisions made now to keep autonomous chain moving — Julien override anytime)

- **Goldens re-baseline scope (D-92.A):** Re-baseline **only the 3-5 must-have screens** in this phase: landing, onboarding hero, chat opener. Out-of-scope goldens (~50-100 across full app) move to follow-up `MVP-GOLDENS-RESYNC-V1`. Reason: Karpathy #2 simplicity + #3 surgical — Phase 92 proves the font swap landed; broad re-baseline doesn't add evidence the swap worked, just paperwork. STUB risk #4 acknowledged.
- **Dark mode scope (D-92.B):** Add the dark palette tokens and `ThemeData.dark` factory only. Do NOT migrate any specific screen to dark mode in this phase. Reason: Phase 92 is a **foundation token drop**; per-screen migration is a different change shape (visual QA per screen, A11y contrast checks per screen). Bundling them would balloon scope. STUB Goal §5 stays green; STUB Goal §6 (sample landing) demonstrates dark-token availability via a single proof element, not full landing dark variant.
- **Font asset acquisition (D-92.C):** Download `.otf` files from Fontshare public CDN URLs via `WebFetch` during Wave 1 task execution. If CDN URLs are not WebFetch-accessible, FALL BACK to a `BLOCKED` task that asks Julien to drop the four `.otf` files into `apps/mobile/assets/fonts/` manually. License `.txt` files come from the same CDN.
- **Bundle size budget (D-92.D):** Target ≤+400 KB total app size (4 .otf @ ~80-100 KB each). Measured via `flutter build ios --release --analyze-size` before/after. If exceeded, defer 600-weight Supreme to follow-up (use 500 as bold proxy).
- **GoogleFonts.* call sites (D-92.E):** This phase does NOT touch existing `GoogleFonts.*` call sites. The `pubspec.yaml` keeps `google_fonts:` for now. New surfaces use bundled fonts via `MintTextStyles`. LINT-04 (Phase 90 baseline) blocks NEW `GoogleFonts.*` introductions. Sweep happens in `MVP-GOOGLEFONTS-PURGE-V1`.
- **Branch strategy (D-92.F):** New branch `feature/S92-mvp-fonts-tokens-v2` cut from current `docs/phase-2-extractor-v2-research`. Phase 92 work is independent of Phase 91 backend changes; cutting from the live HEAD avoids re-merging Phase 91 work later. CLAUDE.md §4 branch convention respected.
- **Test surface (D-92.G):** New tests added in this phase: (1) golden re-baseline diff for the 3-5 must-have screens; (2) `MintColors.mentheVive` non-null assertion; (3) `MintTextStyles.displayGambarinoItalic56` returns expected `fontFamily: 'Gambarino', fontStyle: italic`. Existing tests must stay green (≥6142 backend baseline + Flutter analyzer green).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source of truth for MINT v2 design
- `.planning/decisions/2026-05-08-perimeter-mvp-fonts-tokens-v2/STUB.md` — this phase's spec
- `.planning/decisions/2026-05-08-coach-onboarding-redesign-panel/SYNTHESIS.md` — adjacent v2 design synthesis
- `docs/MINT_IDENTITY.md` — pivot 2026-04-12 lucidité
- `docs/DESIGN_SYSTEM.md` — current baseline (semi-superseded by v2)

### Existing baseline (DO NOT BREAK)
- `apps/mobile/lib/theme/colors.dart` — `MintColors` baseline (extend, don't rewrite)
- `apps/mobile/lib/theme/mint_text_styles.dart` — `MintTextStyles` baseline (extend, don't rewrite)
- `apps/mobile/lib/theme/mint_spacing.dart` — `MintSpacing` baseline (untouched this phase)
- `apps/mobile/pubspec.yaml` — Flutter assets manifest
- `apps/mobile/lib/app.dart` — `ThemeData` factory location

### Conventions
- `CLAUDE.md` §1 (identity), §4 (branch + tests), §5 NEVER #2 (no hardcoded colors), §7 Karpathy 4, §9 0-trust (banned phrases without citation)
- `apps/mobile/CLAUDE.md` — mobile-specific guidelines (if exists)
- `tools/checks/accent_lint_fr.py` — must pass on any FR text added

### License files (G5 evidence)
- Fontshare ToS — Julien validates at G5 (commercial-OK per Open Source license)
- `apps/mobile/assets/fonts/LICENSE-SUPREME.txt` (to be committed)
- `apps/mobile/assets/fonts/LICENSE-GAMBARINO.txt` (to be committed)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets (extend, don't rewrite)
- `MintColors` class exists at `apps/mobile/lib/theme/colors.dart`. ADD `mentheVive`, `mentheVive12`, dark tokens; do NOT touch existing `primary`, `secondary`, etc.
- `MintTextStyles` class exists at `apps/mobile/lib/theme/mint_text_styles.dart`. ADD new `displayGambarinoItalic*` + `titleSupreme*` + `bodySupreme*` + `labelSupreme*`; do NOT delete existing styles (call sites still using them).
- `ThemeData` factory exists in `apps/mobile/lib/app.dart`. ADD a `darkTheme:` field referencing a new `ThemeData.dark` factory; do NOT change the light `ThemeData.light` shape.
- `pubspec.yaml` already has a `fonts:` block (for GoogleFonts wrapper or empty). EXTEND with the 4 new `.otf` entries; preserve existing block.

### Established patterns
- Conventional commit subjects: `feat(92): <subject>`, `chore(92): <subject>` per `git log --oneline | head -20`.
- Test layout: `apps/mobile/test/theme/<file>_test.dart` for theme-level unit tests; `apps/mobile/test/golden/<file>_golden.dart` for goldens.
- `flutter gen-l10n` regen required if any new ARB key added (this phase shouldn't add any — fonts ≠ strings).
- Pre-push checklist (CLAUDE.md §5 NEVER #6): `flutter analyze && flutter test` green before commit.

### Integration points
- All MINT screens importing `mint_text_styles.dart` — new styles available globally once defined.
- `app.dart` ThemeData consumers — new dark factory available globally once wired.
- Existing screens using `GoogleFonts.*` — UNTOUCHED this phase (D-92.E).

</code_context>

<specifics>
## Specific Ideas

- **Fontshare CDN URLs (probable, validate via WebFetch in Wave 1):**
  - Supreme: `https://api.fontshare.com/v2/css?f[]=supreme@400,500,600&display=swap` returns CSS with `.otf` URLs
  - Gambarino: `https://api.fontshare.com/v2/css?f[]=gambarino@1&display=swap` (italic baked-in)
  - Direct asset URLs need WebFetch to discover (Fontshare wraps in obfuscated CDN paths)
- **Sample landing screen** (STUB §F5): use the existing landing screen file (likely `apps/mobile/lib/screens/landing/landing_screen.dart`) and update the hero text to use `MintTextStyles.displayGambarinoItalic56`. No copy change.
- **Pixel-sample fallback if `#7DD3B5` looks wrong on device:** common Menthe variants include `#7BC3A4`, `#82DABA`, `#6BC9A8`. Julien picks at G2 review.

</specifics>

<deferred>
## Deferred Ideas

- **Per-screen dark mode adoption** → `MVP-DARK-MODE-V1` (separate perimeter, after Phase 92 lands tokens)
- **Full goldens re-baseline (50-100 screens)** → `MVP-GOLDENS-RESYNC-V1`
- **`GoogleFonts.*` call site sweep** → `MVP-GOOGLEFONTS-PURGE-V1` (uses LINT-04 from Phase 90)
- **Variable font version of Supreme/Gambarino** → out of scope; Fontshare doesn't ship variable .ttfs
- **Dynamic font scaling per accessibility settings** → out of scope; respect Flutter's default text scaler
- **Web/macOS/Windows font bundling** → MINT mobile is iOS+Android only this milestone

</deferred>

<requirements>
## Phase Requirements (suggested IDs for ROADMAP wiring)

- **FONT-01** Supreme + Gambarino .otf bundled in `apps/mobile/assets/fonts/` and declared in `pubspec.yaml`
- **FONT-02** `MintColors.mentheVive` + `mentheVive12` exist as `Color(0xFF...)` constants (default `#7DD3B5`)
- **FONT-03** `MintTextStyles.displayGambarinoItalic56` + `displayGambarinoItalic40` + Supreme styles exist with correct `fontFamily` + `fontStyle: italic` for Gambarino
- **FONT-04** `MintColors.dark*` palette tokens exist + `ThemeData.dark` factory wired in `app.dart`
- **FONT-05** Sample landing hero uses `displayGambarinoItalic56` — sim screenshot proof
- **FONT-06** Fontshare LICENSE-SUPREME.txt + LICENSE-GAMBARINO.txt committed under `apps/mobile/assets/fonts/`
- **FONT-07** Goldens re-baseline for landing + onboarding hero + chat opener — diffs reviewed and committed
- **FONT-08** `flutter analyze` + `flutter test` green; ARB lint + accent lint + LSFin lint unchanged

(These IDs aren't in REQUIREMENTS.md yet — plan-phase will surface them or pull from ROADMAP if present.)

</requirements>

---

*Phase: 92-mvp-fonts-tokens-v2*
*Context derived: 2026-05-09 from STUB.md (no smart_discuss interactive gate run — STUB is the discuss output, all major decisions captured there; "Claude's Discretion" subsection above documents the calls I made for the open items so Julien can override pre-execution.)*
