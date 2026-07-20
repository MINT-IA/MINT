# G1-RETURN-01 — six-origin contract decision

Date: 2026-07-20

Owner: `mint-data-quest-architect`

State: planning contract only; ticket remains `ticket_only`; G1 remains open;
G2/G3 remain forbidden.

## Decision

`G1-RETURN-01` has **six P0 route-stability outcomes**, but only **five are
routed DataBlock collection origins**. `/segments/frontalier` is deliberately
an in-place collector and MUST NOT receive a duplicate DataBlock Ask merely to
make the navigation matrix symmetrical.

This distinction follows the live product contract:

- `/segments/frontalier` reads `CoachProfileProvider.profile`, evaluates only
  `frontierJurisdictionAt(now)`, and collects the exact missing delta inline:
  `q_residence_country`, `q_work_country`, then conditional `q_work_canton`
  (`apps/mobile/lib/screens/frontalier_screen.dart:20-23,58-71,77-184`).
- `frontierJurisdictionAt` requires exactly `residenceCountry`, `workCountry`
  and conditional `workCanton`; it does not consume salary or residence canton
  (`apps/mobile/lib/models/coach_profile.dart:4740-4781,4803-4847`).
- DataBlock has no jurisdiction category or canonical jurisdiction input key
  (`apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart:23-46,
  1409-1509`). Reusing `q_canton` would confuse residence and work canton;
  collecting salary would not change an existing Frontalier consumer.
- The checked-in screen contract therefore names only the three jurisdiction
  facts and routes out to Coach/Fiscal
  (`docs/codex/SCREEN_CONTRACTS.md:398`).

## Exact six-origin matrix

| P0 loop | origin | collection contract | success/save outcome | cancel outcome | persistence-error recovery | RETURN classification |
|---|---|---|---|---|---|---|
| WORK | `/first-job` | Real CTA -> `/data-block/revenu?returnUri=%2Ffirst-job`; collect the existing salary/canton delta. | Canonical provider write succeeds, then exact `/first-job`. | AppBar cancel returns exact `/first-job` without browser/history reliance and without a write. | Keep entered values and visible retry; retry performs one successful canonical write, then exact `/first-job`. | routed |
| HOUSING | `/hypotheque` | Real CTA -> `/data-block/revenu?inputKey=q_gross_salary_annual&returnUri=%2Fhypotheque`. | Successful canonical salary write, then exact `/hypotheque`. | Exact `/hypotheque`, zero writes. | Input remains retryable; successful retry returns exact `/hypotheque`. | routed |
| RETIREMENT | `/rente-vs-capital` | Real IndicatifBanner -> `/data-block/lpp?returnUri=%2Frente-vs-capital`; the scan extension carries only the typed opaque return intent downstream. | Direct DataBlock saves return exact RVC. For LPP scan, reviewed persistence succeeds before the exact linked Review/Impact terminal consumes once and returns RVC. | DataBlock cancel returns exact RVC. A linked scan cancel/recovery uses only its typed authority and never a downstream raw `returnUri`. | Save failure remains editable/retryable; a valid linked scan recovery returns RVC, while absent/untrusted authority fails Home. | routed; bounded native success already proven at `bc839242abc3e2c376363359cd77994355d77190` |
| DISABILITY | `/invalidite` | Real missing-fact CTAs for revenue salary, birth year, and patrimoine cash; every emitted collector URI carries `returnUri=%2Finvalidite`. | Each canonical write returns exact `/invalidite`. | Exact `/invalidite`, zero writes. | Each branch retains its entered value; successful retry returns exact `/invalidite`. | routed |
| SUCCESSION | `/succession` | Real missing-property and missing-mortgage CTAs -> their existing patrimoine input keys with `returnUri=%2Fsuccession`. | Each canonical write returns exact `/succession`. | Exact `/succession`, zero writes. | Each branch retains its entered value; successful retry returns exact `/succession`. | routed |
| FRONTALIER | `/segments/frontalier` | Inline chronological delta: residence country -> work country -> work canton only when work country is CH. No DataBlock, no `returnUri`, no duplicate Ask. | Each awaited canonical write leaves the route exactly `/segments/frontalier` and visibly updates the existing jurisdiction state. | N/A: no modal or routed collector exists; abandoning an untouched inline control leaves the exact origin stable. | Provider failure publishes no changed profile and leaves the exact route stable. Visible retry/recovery belongs to the Frontalier/FRONT contract, not to a fabricated RETURN loop. | in-place; RETURN routed exit N/A |

## Typed target and query contract

The `/data-block/:type` builder parses the already-decoded `returnUri` exactly
once and passes a privately constructed typed internal target. Screens and
downstream flows MUST NOT reparse raw route text. Every terminal exit consumes
the typed target. A valid optional query is canonicalized once and may preserve
only explicitly allowed presentation keys (currently `tab` and `focus`); it
must not retain duplicate, case-varied, encoded-key, nested-return or sensitive
parameters.

Eligibility is not equivalent to “present in the route registry”. A return
target must be a canonical internal product destination appropriate for
return. Registered auth/admin/anonymous, alias, redirect, flow, settings,
report/export, or other non-origin destinations fail closed. Invalid or absent
typed authority never falls back to browser history; invalid authority uses the
safe internal Home destination.

## Adversarial terminal-exit matrix

Each target class below is exercised through every applicable DataBlock
terminal: successful save, AppBar cancel, validation-error-then-cancel, and
persistence-error retry-success/cancel. Before the terminal action, a
persistence error must retain the input and remain on the collector. The final
outcome for every invalid class is the typed safe Home fallback.

| target class | representative input | save | cancel | validation recovery | persistence recovery |
|---|---|---|---|---|---|
| External scheme | `https://evil.example/steal` | Home | Home | collector, then Home | retry/cancel -> Home |
| Scheme-relative authority | `//evil.example/steal` | Home | Home | collector, then Home | retry/cancel -> Home |
| Unknown internal path | `/not-registered` | Home | Home | collector, then Home | retry/cancel -> Home |
| Auth/admin/anonymous | `/auth/login?...`, `/admin/routes`, anonymous destination | Home | Home | collector, then Home | retry/cancel -> Home |
| Registered but inappropriate | settings/report/export/flow/alias destination | Home | Home | collector, then Home | retry/cancel -> Home |
| Traversal or backslash | plain/encoded `..`, encoded separators, `\\` | Home | Home | collector, then Home | retry/cancel -> Home |
| Nested return | allowed-looking origin containing `returnUri=` | Home | Home | collector, then Home | retry/cancel -> Home |
| Sensitive or non-allowlisted query | token/code/session/auth keys; case/percent-encoded variants | Home | Home | collector, then Home | retry/cancel -> Home |
| Duplicate/malformed/fragment | duplicate allowed keys, empty component/value ambiguity, fragment, double encoding | Home | Home | collector, then Home | retry/cancel -> Home |

## RED and proof boundaries

The canonical ticket command remains:

```bash
cd apps/mobile && flutter test test/navigation/data_block_return_uri_test.dart --reporter expanded
```

The current suite being GREEN is not sufficient promotion evidence because its
six-origin loop uses synthetic `router.go` entry and does not parameterize real
producer plus persistence-error recovery across the full routed matrix. A valid
RED must be semantic and captured at an exact SHA/control state using the
identical command. It must fail on at least one required production boundary,
not on imports, compilation, labels, timing, or a test-only router. GREEN must
then prove:

1. all five real producers emit the exact typed collector intent;
2. their real save/cancel/persistence-error recovery outcomes match the matrix;
3. Frontalier remains in place and emits no DataBlock return contract;
4. every adversarial class fails closed for every applicable terminal;
5. encoded valid presentation queries survive exactly once;
6. route reconcile and screen-contract gates remain GREEN with no new route.

The RVC evidence under
`.planning/runtime-evidence/phase-37/return-01-rvc/` proves only its bounded LPP
scan atom. It cannot substitute for the other routed origins, the Frontalier
in-place assertion, or the global canonical RED -> GREEN record. No ticket
promotion, runtime acceptance, registry update, G1 closure, or G2/G3 permission
is created by this decision document.
