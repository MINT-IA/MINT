# G1-FRONT-01 visual review

Accepted screenshot:
`runtime-cb580c7a85-20260717T175900Z/final.png`

- Exact code/runtime SHA:
  `cb580c7a8522ee3728ea7ab8ce8faca46ef05497`
- Pixel size: **1206 × 2622**
- SHA-256:
  `1939c023b49866ddb77e83ce4948ab595965ad985bc8286f5631f570dbf33bae`
- Decision: **accepted as bounded functional runtime evidence**
- Shipping-default visual-polish claim: **none**

## Directly observed

- The work country `CH` and work canton `GE` are visible in the jurisdiction
  summary. The selected residence country is above the captured scroll
  position; its `FR` value is proved by the Patrol assertions, not by pixels.
- The fiscal card clearly says that the 1966 Franco-Swiss convention is an
  instrument **candidate** and explicitly avoids concluding a regime or amount.
- The social-insurance card is visually separate and says that affiliation,
  telework and any A1 certificate must be checked independently.
- The specialist-question card is visible and asks concrete handoff questions.
- No CHF/EUR/Fr. amount and no universal “90 jours” result are visible.
- Card text wraps without visible horizontal overflow. The specialist card
  continues below the viewport as normal scroll content; this is not treated as
  a clipping defect.

## Bounded limitation

Patrol's long red DEBUG test-name overlay overlaps the app heading and the first
summary row. It makes the test identity obvious but prevents an honest claim
about production title spacing or pristine shipping chrome. The screenshot is
therefore accepted for state, content separation and runtime wiring only. It is
not a release-store screenshot, a full accessibility audit or an automated
contrast measurement.

The underlying physical run selected one real Dart test and passed 1/1 with 0
failures. `runtime-summary.json` binds the screenshot, sanitized log, metadata,
cleanup result and prior runtime RED by SHA-256.
