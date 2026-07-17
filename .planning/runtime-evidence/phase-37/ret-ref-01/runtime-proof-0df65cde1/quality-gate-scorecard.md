# Quality gate — RET-REF-01 fiscal sub-vertical

Runtime SHA: `0df65cde10b8dc94e1e69a37d478ff21e3208458`

Scope is deliberately limited to the finished, default-off fiscal reference
vertical. This is not a score for all of `RET-REF-01` or G1.

## Verdict and severity

| Boundary | Verdict | P0 | P1 | Reason |
|---|---:|---:|---:|---|
| Fiscal reference technical vertical | GREEN | 0 | 0 | One authority, real writer, cold reconstruction, precise consumer, fail-closed tests and exact-SHA runtime all pass |
| Tax-feature activation | NO-GO | 0 | 1 | Currentness must be modeled as a separate DataQuest re-ask before flags can turn on |
| Whole `RET-REF-01` | ticket_only / open | 0 | not scored in this slice | Three non-fiscal reference variables remain missing |
| G1 | NO-GO | — | — | This bounded vertical cannot close G1 |
| G2/G3 | forbidden | — | — | G1 is not closed |

Missing whole-ticket variables:

1. `lppRegulationReference`
2. `lppCapitalNoticeDeadline`
3. `pillar3aBeneficiaryClause`

The final Opus P1 is accepted as a real **activation condition**, not waived:
an immutable tax decision remains event-static, while “do we have the newest
useful assessment?” belongs to an explicit currentness/DataQuest contract. Both
tax flags remain default-false until that contract and runtime proof exist.

## Fixed 10-point rubric

| Dimension | Score | Evidence |
|---|---:|---|
| Data contract | 2.0 / 2.0 | Typed reference derived from the single fiscal root after exact provenance; UUID/date/context coherence; no second authority |
| Swiss correctness | 1.5 / 1.5 | `legalYear == taxYear`; `sourceDate` remains the issue date; only `inForce + inForceAttested`; permanent Swiss review accepted |
| UX lucidity | 1.0 / 1.5 | Existing fiscal prompt fails closed and flag-off UI is proven; activation loses 0.5 until the separate currentness/re-ask state is explicit |
| Runtime proof | 1.5 / 1.5 | Maestro 9/9; Patrol writer 1/1; explicit terminate 0; independent cold reader 1/1; restoration verified |
| Automated tests | 1.0 / 1.0 | Orchestrator 19/19; docs 30/30; analyze zero; Flutter 9,592/44/0; Mermaid pass |
| External audit | 0.5 / 1.0 | Code Opus and Sonnet rerun have no P0/P1; final Opus overall PASS retains one activation-only P1 |
| Integration/privacy hygiene | 1.0 / 1.0 | Synthetic-only; no second root/backend mirror; sanitized evidence; no PII, real financial data or secrets |
| Diff discipline | 0.5 / 0.5 | Bounded exact-SHA vertical and minimal proof bundle |
| **Total** | **9.0 / 10.0** | Technical acceptance threshold met; activation remains blocked |

## Gate results

- Full MINT Doctor: PASS.
- Patrol tooling guard: PASS.
- Runtime orchestrator contract: 19 passed.
- Mermaid render guard: PASS.
- Documentation contracts: 30 passed.
- Flutter analyze: zero issues.
- Full Flutter suite: 9,592 passed, 44 skipped, 0 failed.
- Maestro flag-off flow: 9/9 passed.
- Patrol process-death confirmation: exit 0.
- Writer xcresult: 1 passed, 0 failed, 0 skipped.
- Explicit app termination: exit 0.
- Cold reader xcresult: 1 passed, 0 failed, 0 skipped.
- External build restoration: restored.
- Claude code Opus: PASS, scoped P0=0/P1=0.
- Claude product Sonnet rerun: PASS, scoped P0=0/P1=0.
- Claude final Opus: overall PASS, activation P0=0/P1=1.

No further audit carousel is permitted. The activation P1 must be implemented
and proven in a separately scoped gate rather than repeatedly re-auditing this
unchanged slice.
