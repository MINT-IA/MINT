# ADR — Authority boundary for the Lausanne 2026 3a vertical

Status: `Proposed — pre_activation / STOP / OFF`

This candidate does not close B0. Real-user exposure is forbidden and all model
output remains unavailable until an independently audited B0 receipt binds the
complete contract.

## Scope

Only a single person, without dependants, ordinarily taxed and domiciled in
Lausanne for all of 2026, with salaried AVS income and confirmed active LPP, is
supported. Every other canton, year, household, liability, catch-up case or
activity is unsupported and fails closed.

## Authority layers

1. Official federal, Vaud and Lausanne sources are legal/source authority for
   the claim, jurisdiction, tax year and effective interval they actually cover.
2. Raw receipts prove provenance only; they do not prove extracted content.
3. Extractions are candidates. Normalized rules are derived, versioned inputs.
4. User-confirmed encrypted facts are personal truth. Documents, APIs and LLMs
   are proposal-only, have no canonical write authority, and can never resolve
   conflicts; contradictions block writes and last-write-wins is forbidden.
5. Versioned deterministic engines own calculations and signed result receipts.
6. Coach and UI navigate and explain those receipts. The Coach never calculates,
   never supplies truth, never fills missing values, and never writes facts,
   results, decisions or plans.

Precedence is resolved by legal layer, jurisdiction, tax year and effective
dates—not by a blanket federal/cantonal/communal order. A missing, stale,
conflicting or divergent authority makes only the affected output unavailable,
with zero canonical writes and activation remaining OFF.

## Semantic invariants

Null is not zero. AVS or salary is not taxable income. IFD taxable income is not
VD taxable income. Ordered is not credited. One contribution line or provider is
not proof of an exhaustive provider inventory. Only one live confirmed fact may
exist for a subject, type and effective period.

## Legacy and future connectors

Legacy MINT is a read-only harvest library. Every candidate is classified as
`reuse_exact`, `adapt_pattern`, `defer`, `reject`, or `archive_receipt`; wholesale
imports are forbidden. Future bank, insurer, LPP, AVS and tax connectors are
proposal-only evidence sources: disabled by default, revocable, provenance-bound,
and without write authority. No endpoint, provider, OAuth flow or SDK is selected.

## Privacy boundary

This ADR does not settle any of: purpose, legal basis, consent, retention,
recipients, or transfers. Those remain unresolved contract references requiring dedicated
privacy and external legal review. No real user value, account identifier,
document, provider name or free text belongs in this contract or its evidence.

## Change control

The integrity and internal hash bindings of authority receipts, extractions,
normalized rules, parser manifest, goldens and bundle are delegated to the
canonical B0a guard `tools/checks/mint_next_three_a_goal_annexes_guard.py`.
This B01 guard binds the SPEC and persona matrix and verifies that delegated
guard is hash-pinned and executed without duplicating its bundle logic. A
changed source, parser, rule, year or scope invalidates dependent outputs and
requires new independent reviews and a new acceptance receipt. 2027 is a new
scope, never a silent update.

## Non-goals

This candidate is not B0 acceptance, an engine, UI, B1 repository, generic tax
support, an API/backend/LLM implementation, a legacy rewrite, deployment,
TestFlight, or work on `dev`.

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  A layered authority model with fail-closed unavailability on any divergence
  could be judged heavier than the product needs at this stage : a simpler
  « latest official PDF wins » rule would ship faster, and most fintech apps
  operate that way. The layered model is kept because a wrong Swiss tax number
  displayed with confidence is a trust-collapse event, and the persona is a
  financial novice who cannot detect the error.
- **What does this source not address ?**
  No empirical measure of how often authority sources actually diverge in
  practice (the fail-closed path is designed but its trigger frequency is
  unknown) ; the privacy boundary explicitly leaves purpose, legal basis,
  consent, retention, recipients and transfers unresolved ; 2027 amounts and
  any non-Lausanne jurisdiction are out of scope by construction.
- **What would change this conclusion ?**
  Per the 2026-08-10 amendment, batch promotion now goes through the unique
  5-condition gate instead of the B0 receipt chain ; if two consecutive
  promoted batches ship an authority-related wrong number that the receipt
  chain would mechanically have blocked, this ADR's change-control section is
  re-litigated. A 2027 scope or a second canton starts a new contract version.
