# G1 RET-REF-01 fiscal exact-SHA runtime proof

Scoped vertical: `latestTaxDecisionReference` derived from the typed fiscal
ledger, written through the real tax-review flow, reconstructed after process
death and consumed fail-closed by `ConfidenceScorer`.

Runtime source SHA:
`0df65cde10b8dc94e1e69a37d478ff21e3208458`

Capture date: 2026-07-17 UTC. All fixtures are synthetic.

## Decision boundary

- Fiscal reference technical vertical: **GREEN** (`P0=0`, `P1=0` in the
  accepted default-off technical scope).
- Production activation: **NO-GO** (`P0=0`, `P1=1`). A separate
  currentness/DataQuest re-ask contract is required before either tax flag can
  be enabled. The durable tax decision reference itself must not acquire an
  artificial calendar TTL.
- Whole `RET-REF-01`: **ticket_only / open**.
  `lppRegulationReference`, `lppCapitalNoticeDeadline` and
  `pillar3aBeneficiaryClause` are still missing.
- G1: **NO-GO**. G2/G3 remain forbidden.

The final allowed Opus confirmation returned overall PASS but raised the
activation-only currentness P1. Permanent Swiss and ledger review adjudicated
it as a separate pre-activation DataQuest obligation, not a reason to corrupt
the event-static legal reference. No further Claude audit is authorized for
this gate: the product-domain first pass recorded before this bundle, Sonnet
rerun and final Opus confirmation exhaust the bounded audit loop. The code
audit is a separate first-pass gate.

## Exact-SHA proof chain

1. Full MINT Doctor, Patrol tooling guard, Mermaid render guard, the 19-test
   runtime orchestrator contract, 30 documentation contracts, Flutter analyze
   and the full Flutter suite passed.
2. Maestro passed 9/9 steps with both tax-acquisition flags off. Its
   `landing_route` startup barrier completed before the tax deep link; the
   generic scan route rendered while every tax-specific acquisition/review
   control stayed absent.
3. Patrol wrote one synthetic final tax decision through the real UI:
   assessment notice, `inForce`, explicitly attested, exact provenance and
   metadata-only reference.
4. `simctl terminate` returned 0. A separately built reader cold-reloaded the
   same authoritative snapshot/reference, proved precision readiness and
   confirmed that the matching fiscal document prompt is suppressed.
5. Independent xcresult summaries report writer 1/1 and cold reader 1/1, with
   zero failures and zero skips. The temporary build isolation restored the
   original build tree.
6. Claude code Opus passed with no P0/P1. The product-domain Sonnet rerun passed
   with no scoped P0/P1. Final Opus passed overall and recorded the one
   activation-only P1 described above.

Full Flutter result: 9,592 passed, 44 skipped, 0 failed. Flutter analyze:
zero issues.

## Tracked sanitized artifacts

- `quality-gate-scorecard.md` — fixed-rubric score, severity accounting and
  activation boundary.
- `gate-exit-codes.json` — deterministic exit-code record.
- `patrol-metadata.sanitized.json` — exact SHA, lifecycle exits, synthetic-only
  mode, restoration state and xcresult hashes.
- `write-xcresult-summary.sanitized.json` — independent writer result, 1/1.
- `read-xcresult-summary.sanitized.json` — independent cold-reader result, 1/1.
- `maestro-summary.sanitized.json` — 9/9 result, startup barrier, flag-off
  assertions and screenshot hash.
- `audit-code-opus-first-pass.txt` — bounded code audit.
- `audit-product-domain-sonnet-rerun.txt` — authorized product/domain rerun.
- `audit-product-domain-opus-final-confirmation.txt` — final allowed
  confirmation and activation P1.
- `SHA256SUMS` — hashes of every tracked proof artifact except the manifest.

The binary screenshot, raw logs, build products and complete xcresult bundles
remain in the ignored local raw evidence bundle. They are intentionally not
copied here.

## Sanitization and privacy

Absolute home/repository/temp paths and simulator identifiers are replaced by
`<REPO>`, `<PATROL_BIN>`, `<TMP_BUILD>` and `<SIMULATOR_UDID>`. The tracked
proof contains no raw document, OCR payload, person name, e-mail, AVS number,
real financial record, credential, token or secret. The screenshot hash is
retained without copying the PNG. Visual inspection confirmed a generic scan
screen with tax-only controls absent and no user data.
