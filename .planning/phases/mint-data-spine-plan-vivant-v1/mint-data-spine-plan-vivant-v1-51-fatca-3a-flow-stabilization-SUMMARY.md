# Summary 51 — FATCA 3a flow stabilization

## Outcome

The FATCA 3a gate Maestro flow now passes with the supported `expat_us`
simulator seed.

## Changes

- Removed the landing-page text assertion before routing.
- Updated the FATCA 3a deep-link from `ch.mint.app://pilier-3a` to
  `mintapp:///pilier-3a`.
- Added optional iOS open-confirmation handlers.

## Verification

- Reproduced failure on an `expat_us_seed` simulator build: the flow failed
  before reaching `/pilier-3a`, on the landing text assertion.
- Second reproduction showed `expat_us_seed` is not a valid seed contract for
  this code path; the supported archetype define is `expat_us`.
- Cleared local iOS build xattrs after a simulator codesign packaging failure.
- Passing run: `flow_fatca_3a_gate.yaml` passed on iPhone 17 Pro with
  `MINT_E2E_ARCHETYPE=expat_us`.
