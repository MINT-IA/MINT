# Official AVS pension ingestion — G1 self-only contract

> **Status:** Wave 0 target contract, not proof of implementation.
> **Scope:** one official monthly old-age pension for the signed-in person.
> **Companions:** [DATA_LEDGER.md](DATA_LEDGER.md),
> [AVS_COUPLE_LEGAL_CONTRACT.md](AVS_COUPLE_LEGAL_CONTRACT.md),
> [AVS_OFFICIAL_PENSION_INGESTION.mmd](AVS_OFFICIAL_PENSION_INGESTION.mmd),
> and [WIRING_GRAPH.mmd](WIRING_GRAPH.mmd).

This contract closes one bounded G1 acquisition gap. It does not activate a
partner pension, a household sum, a marital cap, a replacement rate, or any
other complete AVS projection. It also does not turn the existing individual
account (`CI`) scan into a pension document.

## 1. Machine-checkable identity

- `scope`: `self-only`
- `canonical_key`: `avs_official_monthly_pension`
- `document_type`: `avs_official_pension`
- `secure_key`: `_coach_avs_official_monthly_pension`
- `secure_record`: `{value, source, sourceDate, updatedAt}`
- `mobile_flag`: `enableOfficialAvsPensionIngestion` (default `false`)
- `backend_flag`: `AVS_OFFICIAL_PENSION_INGESTION_ENABLED` (default `false`)

The intended mobile enum label is `avsOfficialPension`; its serialized backend
value is the distinct `avs_official_pension` document type. The exact canonical
fact key is `avs_official_monthly_pension`. The existing typed presentation
path may remain `prevoyance.renteAVSEstimeeMensuelle`, but that path alone is
not evidence: readiness also requires the canonical record and its provenance.

## 2. Certification boundary

Only a personal official pension estimate or decision may enter review as a
certificate candidate. A candidate must carry all of the following:

1. an official AVS compensation-office or equivalent authority marker;
2. a label that identifies the amount as the signed-in person's pension;
3. an explicitly monthly old-age pension amount; and
4. the official document or calculation date.

The acceptance decision is semantic, not value-only. A person may legitimately
receive the statutory minimum or maximum, so equality with such an amount does
not reject a personal official decision. The parser must instead reject labels
or context describing a minimum, maximum, scale table, example, generic
simulation, couple amount, household cap, `150%`, spouse, or partner amount.
An annual-only amount is not silently divided by twelve.

| input or storage | meaning | certification rule |
|---|---|---|
| `avs_official_pension` | personal official pension estimate or decision | may produce a review candidate only when the four requirements above hold |
| `avs_extract` | CI contribution history only | **cannot certify** `avs_official_monthly_pension` |
| `_coach_avs_rente_estimee` | legacy estimate storage | **cannot certify** `avs_official_monthly_pension` |
| `prevoyance.renteAVSEstimeeMensuelle` without the canonical record | ambiguous typed presentation value | remains unverified and cannot unlock official readiness |

## 3. Candidate-only backend boundary

Both flags are independent kill switches and fail closed. The mobile flag
controls entry, review, and the local writer. The backend flag controls the
`avs_official_pension` extraction request. A stale in-flight review must recheck
the mobile flag immediately before persistence.

Backend extraction is **candidate-only**. For this document type there is:

- **NO pre-review write**;
- **NO backend `ProfileModel.data` mirror**;
- no legacy `/scan-confirmation` value write until that path can persist the
  same per-field source, source date, update date, and correction state; and
- no raw document, source line, identity value, or pension amount in logs.

Turning either flag off produces a **kill-switch rejection**, not a partial
write. A candidate is ephemeral and has no ledger authority before review.

## 4. Atomic strict-secure provenance

The fact is persisted as **one strict-secure atomic envelope** under
`_coach_avs_official_monthly_pension`:

```text
{
  "value": <reviewed positive CHF/month number>,
  "source": "certificate",
  "sourceDate": "YYYY-MM-DD",
  "updatedAt": "ISO-8601 confirmation timestamp"
}
```

The persistence implementation must make a no split value/provenance write:
value, source, source date, and update date are accepted or rejected together.
Shared preferences may hold only the secure placeholder, never this envelope
or its amount. Secure-storage failure or timeout leaves the previous durable
and in-memory facts unchanged in every build configuration.

`sourceDate` and `updatedAt` are semantically distinct fields drawn from
distinct events: `sourceDate` is when the authority issued or calculated the
document, while `updatedAt` is when MINT recorded the reviewed fact.
`sourceDate` must never be derived from or replaced by confirmation time. Both
fields must be present for an untouched certificate. Their values may share the
same calendar date when issuance and confirmation occur that day. There is no
mandatory value inequality between them.

| review outcome | persisted provenance | readiness consequence |
|---|---|---|
| untouched accepted official amount | `source=certificate, sourceDate=<official document date>` | eligible as self official evidence after successful secure persistence |
| user changes the amount | `source=userInput, sourceDate=null` | useful declared value, but not official evidence |
| invalid/missing date, rejected label, flag off, or secure failure | no write | previous fact remains unchanged |

A correction cannot inherit the document date or certificate source. This is
the hard floor against provenance laundering.

## 5. Ownership and consumer boundary

Wave 0 and its implementation wave have **no partner writer**. They create no
`conjoint`, `spouse`, `partner`, invitation, grant, household, or couple-cap
storage key. A couple profile still sends this flow to the signed-in person's
self record and never asks whose document it is.

After process/provider relaunch, the AVS guide is the first bounded live
consumer. Its evidence card may show the self amount, source, and `sourceDate`.
A corrected value must be labelled as user input awaiting official evidence.
The card is not a household result.

Until a separate reviewed activation slice closes the legal and product gaps
in [AVS_COUPLE_LEGAL_CONTRACT.md](AVS_COUPLE_LEGAL_CONTRACT.md), **household
calculations remain fail-closed**. Household AVS income, marital cap,
replacement rate, complete retirement income, and monthly retirement gap stay
null/partial even when the self record exists.

In executable-contract terms: household calculations remain fail-closed.

## 6. State and write-order contract

| state | durable fact | allowed next step |
|---|---|---|
| `disabled` | unchanged | enable both bounded flags or continue without AVS amount |
| `candidate` | none | review, correct, reject, or encounter a kill-switch rejection |
| `reviewedCertificate` | none until secure commit succeeds | write the atomic certificate envelope |
| `reviewedUserInput` | none until secure commit succeeds | write the atomic user-input envelope with null `sourceDate` |
| `persisted` | one envelope | rebuild the profile from durable storage |
| `rehydrated` | one envelope | render the self evidence card; keep household calculations partial |

The provider must persist first, reconstruct from the returned durable answer
set, then notify. It must not mutate an in-memory official fact before the
strict-secure write succeeds.

## 7. TDD and runtime acceptance

Implementation is not complete until all of these are proved RED then GREEN:

1. official personal monthly labels with an official date are accepted;
2. minimum/maximum/example/couple/annual/undated candidates are rejected;
3. untouched review persists `certificate` plus the original date;
4. correction persists `userInput` plus null `sourceDate`;
5. secure failure and a kill switch toggled during review produce no write;
6. shared preferences never contain the amount or envelope;
7. a fresh provider/process reconstructs the exact four attributes;
8. the self evidence card renders after relaunch; and
9. household AVS and replacement-rate outputs remain unavailable.

The runtime proof is scan → candidate → review → atomic secure write → process
relaunch → self evidence card. Maestro proves the visible journey. Patrol proves
the numeric edit, strict-secure restart, and fail-closed calculation state.
