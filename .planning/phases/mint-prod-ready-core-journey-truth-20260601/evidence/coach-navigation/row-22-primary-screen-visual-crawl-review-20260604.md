# Row 22 Primary Screen Visual Crawl Review — 2026-06-04

Runtime evidence:
`evidence/maestro-ci/row-22-primary-screen-crawl-20260604T141534/`.

Follow-up profile-first runtime evidence:
`evidence/maestro-ci/row-22-profile-dossier-seeded-crawl-20260604T151030/`.

Non-seeded production profile persistence evidence:
`evidence/maestro-ci/row-22-profile-dossier-production-profile-20260604T153106/`.

Maestro result:
- `result.xml` reports `tests=1`, `failures=0`, `status=SUCCESS`, `time=84.0`.
- The watchdog returned `124` after a post-completion silent period and wrote
  `STALLED`. Treat the run as screenshot/JUnit evidence, but not as a clean
  wrapper gate until the watchdog race is fixed.
- Screenshots captured:
  - `01-row22-home-primary.png`
  - `02-row22-mon-argent-primary.png`
  - `03-row22-budget-primary.png`
  - `04-row22-coach-chat-primary.png`
  - `05-row22-rapport-primary.png`
  - `06-row22-profile-bilan-primary.png`
  - `07-row22-scan-primary.png`
  - `08-row22-explore-primary.png`

Follow-up Maestro result:
- `row-22-profile-dossier-seeded-crawl-20260604T151030/result.xml` reports
  `tests=1`, `failures=0`, `status=SUCCESS`, `time=50.0`.
- The watchdog returned `0`; this run is a clean wrapper gate for the seeded
  visual crawl.
- The flow was intentionally changed to require
  `--dart-define=MINT_E2E_ARCHETYPE=julien_swiss` and to capture
  `/profile/bilan` before budget setup writes partial persisted answers. This
  is visual role evidence, not onboarding persistence evidence.
- `02-row22-profile-bilan-primary.png` now shows `Dossier vérifiable`, source
  chips, `Corriger`, and the expanded `Ce que tu as` facts drawer before any
  retirement projection is visible.

Non-seeded profile-persistence result:
- `row-22-profile-dossier-production-profile-20260604T153106/result.xml`
  reports `tests=1`, `failures=0`, `status=SUCCESS`, `time=57.0`.
- The watchdog returned `0`.
- The flow built the profile through `/onb`, restarted the app with
  `clearState:false`, then opened `/profile/bilan` and asserted the same
  dossier/provenance/correction contract.
- Important local gotcha: the same flow failed on a `--no-codesign` simulator
  build because SecureWizardStore could not persist sensitive wizard answers.
  A normal simulator build after `xattr -rc build/ios` passed.

## Visual Findings

- Home: daily-action surface, but first card is `Versement 3a 2026` with
  `Simuler mon 3a`. Acceptable as action-of-day, but it can visually drift
  toward Explorer/simulator if repeated too heavily.
- Mon Argent vs Budget: acceptable split. Mon Argent summarizes current money
  state (`Revenus`, `Dépenses`, `Reste`); Budget owns formula, data quality,
  detail toggle, and flow gauge.
- Coach: acceptable split. It shows a short conversational budget fact, not a
  hidden duplicate budget surface.
- Rapport: acceptable split. It presents `Ton Bilan Flash`, action and
  transparency/compliance; it does not restage the Budget dashboard viewport.
- Profile / Dossier: fixed in both the seeded visual crawl and the non-seeded
  production-onboarding/restart flow. The first viewport leads with dossier
  facts, source provenance, correction, and detailed patrimoine facts. The
  retirement-gap projection is below the first viewport.
- Scan: clear capture/ingestion role.
- Explorer: clear secondary domain hub role.

## Row 22 Decision

Keep Row 22 at `PARTIAL`.

Reason: primary routes are inventoried and runtime-captured, `/budget` routing
no longer creates an inline/direct-answer or drawer-placeholder role conflict,
and unit regressions now lock the real production `budget_overview` ready path
to `/budget` plus the missing-income fallback to registered `/onboarding/quick`.
The Budget/Mon Argent/Coach/Rapport split is coherent, and the Profile/Dossier
first viewport now reads as facts/provenance/correction in both seeded visual
evidence and a non-seeded onboarding/restart persistence flow. Keep `PARTIAL`
because Row 23 design/i18n/accessibility closure and broader primary-screen
release proof still remain separate gates.

Row 23 i18n note: the Budget setup/card French fallback copy in DE/ES/IT/PT was
fixed after this review and guarded in
`apps/mobile/test/i18n/hardcoded_string_audit_test.dart`. Row 23 still remains
open for broader primary-screen locale review, dynamic type, focus/semantics,
and contrast evidence.
