All remaining consumers (`weight`, `needsRefresh`, `categoryFor`) use retained, signature-compatible methods; the only new consumer is `frontierJurisdictionAt`. No import cycle (the service imports only `biography_fact`, never `coach_profile`), and no compile break from the removed `annualNeedsRefresh`. I have enough to render a verdict.

---

Product/domain verdict: PASS

This is a Data Quest / ledger-freshness infrastructure change (G1-FRESH-01). It consolidates freshness into a single canonical service, wires one real production consumer (frontier jurisdiction), and removes a duplicated tier table from the scan writer. It is domain-coherent with Swiss reality, introduces no advice/compliance violations, and is honestly scoped (ticket remains `ticket_only`, not over-claimed as GREEN or G1 GO).

### P0 findings
None.

### P1 findings
None blocking. Verification performed:
- **Registry is a true projection of the SOT, not invented decay.** Replicating the test's derivation against `.planning/goals/G1-ledger-gap-matrix.md` yields exactly **61 policy paths + 4 specialist references, zero tier conflicts** — matching `freshness_decay_service.dart:ledgerFieldPolicies` and `specialistReferencePaths`. Tier distribution: 39 annual / 10 event_static / 7 volatile / 5 static. Spot-checked domain-sensitive fields (LPP obligatoire = annual/certificate-only, mortgage balance & rate = volatile, `etatCivil` = event_static/userInput, `tauxConversion` = annual/certificate|estimated) all match the matrix.
- **No stale/unsupported Swiss legal constant introduced.** The frontier constants (GE→CDI 1966 art. 17; the eight accord-1983 cantons BE/SO/BS/BL/VD/VS/NE/JU) are pre-existing context, unchanged by this diff — only the freshness-check path was rerouted. The `frontierJurisdictionAt` stale boundary is preserved (annual `_decay(months,12,36) < 0.60`, i.e. known@782d / stale@783d), so the accepted FRONT-01 semantics do not regress.
- **Fails closed, no laundering.** `assessLedgerField` returns `invalid`@floor for missing/future timestamp, unknown path, or disallowed source, while preserving `previousValue` (`freshness_decay_service.dart:353-405`). Certificate-only fields return `renewEvidence` (cannot be refreshed by a tap), mixed-source fields return `confirmAsUserInput` — a correct provenance property. Same-value reconfirmation restamps `{userInput, updatedAt:now, sourceDate:null}` through the real provider and survives cold reload (`stale_reconfirmation_test.dart`).

### P2 findings
- **Deferred consumers (facade risk, honestly labeled).** The 61-entry registry is consumed in production only by `frontierJurisdictionAt` (3 paths); the stale→reconfirm UI for the other 58 paths is explicitly deferred to G2/DataQuest (`DATA_LEDGER.md` §5.2, "deferred UI"). This is disclosed debt, not a hidden facade, and the registry is test-enforced against the SOT — acceptable while the ticket stays `ticket_only`, but the surface area is not yet delivering user value.
- **Biography weight behavior shift.** New writes for `lifeEvent`/`civilStatus`/`employmentStatus` now map to `event_static`/`static` (never decay) instead of `annual`; unknown persisted categories and future timestamps now return floor 0.3 instead of 1.0/annual (`freshness_decay_service.dart:weight`). This is more correct (point-in-time events don't go stale) and legacy `annual` rows are unaffected, but it silently changes refresh-prompt cadence for `biography_refresh_detector`/`biography_provider` consumers. Worth a one-line changelog note.
- `biography_fact.dart:100-104` doc now says production writers "must pass `categoryFor`," but the constructor/decoder default is still `'annual'`; consider asserting non-default in debug for scan/coach writers to prevent silent legacy-tier writes.

### Swiss domain review
- **AVS/LPP/3a:** Not recalculated. Freshness tiers on LPP/3a/AVS fields are certificate-appropriate (LPP projections/coverage = certificate-only annual; `avsGapStatus` = annual). No AVS/LPP legal constant touched; no gap-effect pricing introduced.
- **Tax:** `latestTaxDecisionReference` correctly kept out of generic TTL as a `specialist_reference` (root/BND selector owns authority). No marginal/average conflation touched.
- **Mortgage/insurance/housing:** `dettes.hypotheque`, `patrimoine.mortgageRate`, `depenses.loyer` = volatile; `depenses.assuranceMaladie` = annual — coherent with how these move in practice.
- **Frontalier:** FR/CH/GE and accord-1983 cantonal routing preserved; freshness only gates readiness (canton annual, countries no-TTL). No personal fiscal/social conclusion added.
- **Succession/disability:** Not affected by this diff.

### Mint product logic review
Moves Mint toward the ledger → DataQuest spine: one freshness SOT replacing the scan writer's private tier table, provenance-preserving reconfirmation through the canonical provider, and fail-closed handling of unknown facts. The scenario/dossier stages are untouched. Net positive for the spine; remaining gap (stale-reconfirm surfacing for the 58 non-frontier fields) is disclosed, not disguised.
