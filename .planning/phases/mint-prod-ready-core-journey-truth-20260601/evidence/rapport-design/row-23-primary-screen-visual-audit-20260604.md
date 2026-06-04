# Row 23 — Primary Screen Visual Audit — 2026-06-04

## Status

`PARTIAL`.

This is a visual audit of the current primary-screen screenshots captured during
Row 22 runtime crawls. It improves Row 23 evidence, but it does **not** close
the row because runtime focus order, screen-reader semantics, and broader
accessibility proof still need dedicated coverage.

## Evidence Reviewed

Primary seeded crawl, clean watchdog:

`evidence/maestro-ci/row-22-profile-dossier-seeded-crawl-20260604T151030/`

Screenshots reviewed:

- `01-row22-home-primary.png`
- `02-row22-profile-bilan-primary.png`
- `03-row22-mon-argent-primary.png`
- `04-row22-budget-primary.png`
- `05-row22-coach-chat-primary.png`
- `06-row22-rapport-primary.png`
- `07-row22-scan-primary.png`
- `08-row22-explore-primary.png`

Supplemental production-profile proof:

`evidence/maestro-ci/row-22-profile-dossier-production-profile-20260604T153106/`

Prior visual role review:

`evidence/coach-navigation/row-22-primary-screen-visual-crawl-review-20260604.md`

## Findings

### Passes

- **Mon Argent**: first viewport is quiet and readable. Segmented controls wrap
  cleanly, the monthly budget summary uses stable spacing, and bottom navigation
  does not overlap content.
- **Budget**: warning, formula, expandable calculation row, chart, and CTA are
  visually separated. No salary-only first-viewport copy appears in the reviewed
  seeded Budget screenshot.
- **Coach**: first viewport focuses on one conversation fact (`Marge libre
  mensuelle`) with clear composer and bottom nav spacing. No duplicate Budget
  dashboard appears.
- **Rapport / Bilan Flash**: first viewport reads as a synthesis and compliance
  recap, not a dashboard clone. CTA and transparency sections are visible and
  legible.
- **Profile / Dossier**: first viewport now leads with `Dossier vérifiable`,
  sources, correction, and factual patrimoine details before retirement
  projection. Layout is dense but coherent.
- **Scan**: capture surface is clear: document type selection, expected profile
  impact, and camera/gallery/OCR/test-example actions are separated.
- **Explorer**: category grid is visually stable; labels wrap inside tiles
  without collision.

### Issue Found And Fixed

- **Home action chips truncate text**: `Explique...` and `Rassur...` are visible
  in `01-row22-home-primary.png`. The buttons remained usable, but the
  truncation was not acceptable for a primary daily-return surface.
- Fixed in `MintCardActionBar` by scaling the icon+label cluster down inside
  each chip instead of using `TextOverflow.ellipsis`.
- Guarded by the action-bar widget suite (`28` tests), including a regression
  that asserts the verb labels use scale-down rendering rather than ellipsis.
- Manual simulator screenshot proof:
  `evidence/maestro-ci/row-23-home-action-chip-fit-manual-20260604/row23-home-action-chip-fit-manual.png`.

### Follow-up

- **Home is sparse**: large blank vertical space is acceptable for current
  action-of-day emphasis, but it should be revisited once action completion /
  next-priority state is implemented under Row 18/21.
- **Accessibility remains unproven**: screenshots cannot prove focus order,
  semantic grouping, contrast under system settings, or screen-reader clarity.
  Existing dynamic-type tests help, but runtime accessibility proof for Coach
  and Rapport remains a separate gate.

## Runtime Guidance Quality Review

- `mechanical proof`: Row 22 runtime screenshots and supplemental manual Home screenshot were reviewed; widget tests guard the Home chip fix.
- `user-visible outcome`: primary screens present clear first-viewport jobs for Home, Mon Argent, Budget, Coach, Rapport, Profile/Dossier, Scan, and Explorer.
- `guidance quality`: role clarity is improved; reviewed screens no longer show obvious duplicate-role layouts or broken primary CTAs.
- `non-absurd`: Home chip truncation was found and fixed instead of treating the crawl as sufficient.
- `inclusive`: reviewed Budget/Rente copy avoids salary-only first-surface framing.
- `financial trust`: visual audit does not certify financial advice, source quality, focus order, or screen-reader semantics.
- `remaining qualitative gaps`: Coach/Rapport runtime focus, screen-reader proof, broader visual crawl, and Row 18/21 next-state behavior remain open.

## Decision

Keep Row 23 at `PARTIAL`.

This audit supports the claim that the primary screens no longer show obvious
visual collisions or duplicate-role layouts in the reviewed runtime captures.
The concrete Home action-chip truncation found during this review is fixed and
guarded, but Row 23 still lacks runtime accessibility/focus proof.

## Next Proof

- Add runtime accessibility/focus proof for Coach and Rapport/Bilan.
- Re-run a clean Maestro primary-screen visual crawl after the local Java
  runtime issue is resolved and Row 18/21 action-completion state work lands.
