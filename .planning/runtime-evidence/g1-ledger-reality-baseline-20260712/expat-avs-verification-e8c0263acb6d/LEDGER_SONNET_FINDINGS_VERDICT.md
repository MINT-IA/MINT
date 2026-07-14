# Ledger verdict — Sonnet product-domain findings

- **Role:** `mint-data-ledger-architect`
- **Reviewed HEAD:** `5c774caf85e25911ed562b73ffabcaa1afb87aa4`
- **Scope:** Sonnet P1-2 provenance and P2-2 navigation cartography only
- **Product-code edits:** none

## Severity score

| Severity | Open after this review | Verdict |
|---|---:|---|
| P0 | 0 | None in scope. |
| P1 | 0 | P1-2 is closed by the certificate-only read contract; manual/declaration data cannot populate `selfCertifiedYears`. |
| P2 | 0 | P2-2 was real and is corrected by the missing `SCANAVS --> SCAN` edge. |

## P1-2 — `avsGapEvidence.selfCertifiedYears` provenance

**Verdict: CLOSED / audit concern not reproducible as a misleading read.**

`selfCertifiedYears` is a derived, fail-closed view; it is not the storage field
and it is not writable by a manual form. The getter returns the numeric value
only when all of the following are true:

1. `prevoyance.lacunesAVS` is non-null;
2. the value is within `0..44`;
3. `dataSources['prevoyance.lacunesAVS'] == ProfileDataSource.certificate`.

Exact implementation evidence:

- `apps/mobile/lib/models/coach_profile.dart:72-82` documents and defines the
  certificate-backed envelope.
- `apps/mobile/lib/models/coach_profile.dart:2101-2110` applies the
  certificate-only self filter.
- `apps/mobile/lib/models/coach_profile.dart:2112-2125` independently applies
  the same filter to spouse evidence and reports missing paths; it never
  synthesizes a spouse value.

The reviewed scan is the only live producer in this flow that promotes the
field to `certificate` in memory:

- `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:685-695`
  calls `updateFromAvsExtraction(_fields)` only from the user's confirmation
  action.
- `apps/mobile/lib/providers/coach_profile_provider.dart:1957-1960` recognizes
  the reviewed AVS-gap extraction field.
- `apps/mobile/lib/providers/coach_profile_provider.dart:2006-2018` stamps
  `prevoyance.lacunesAVS` as `ProfileDataSource.certificate` only when that
  reviewed field is present.

Manual/declaration paths fail closed:

- `apps/mobile/test/models/avs_gap_evidence_test.dart:52-63` proves every
  declared `AvsGapStatus` remains uncertified.
- `apps/mobile/test/models/avs_gap_evidence_test.dart:65-71` proves a numeric
  value without certificate provenance yields `selfCertifiedYears == null`.
- `apps/mobile/test/models/avs_gap_evidence_test.dart:73-102` proves explicit
  certificate provenance, including an explicit zero, is required for a ready
  fact.
- `apps/mobile/test/models/avs_gap_write_order_test.dart:7-27` proves wizard
  declarations and years abroad cannot fabricate certified gap years.
- `apps/mobile/test/models/avs_gap_write_order_test.dart:29-53` proves all
  declaration-only statuses keep certified years unknown.
- `apps/mobile/test/providers/coach_profile_provider_test.dart:94-131` proves
  smart-flow arrival chronology leaves the numeric gap fact absent and
  `selfCertifiedYears == null`.
- `apps/mobile/test/providers/coach_profile_provider_test.dart:659-671` proves
  coach `save_fact` writes contribution/status facts but no numeric AVS-gap
  fact.

### Durability boundary (existing G1 debt, not a reason to expose a false fact)

The legacy document-wide `_coach_avs_source` marker is deliberately not trusted
as durable field provenance. On reconstruction,
`apps/mobile/lib/models/coach_profile.dart:3249-3252` restores a persisted
`_coach_avs_lacunes` value as `estimated`, and
`apps/mobile/test/models/avs_gap_write_order_test.dart:55-66` proves the
fail-closed downgrade. Therefore a restart may make the fact unavailable until
PROV-01 lands, but it cannot turn a manual/declaration value into a
CI-observed value. This is the safe side of the G1 provenance durability gap.

## P2-2 — missing `avs-guide -> scan` graph edge

**Verdict: CONFIRMED, FIXED in the cartography.**

The live button is real:

- `apps/mobile/lib/screens/document_scan/avs_guide_screen.dart:360-384` renders
  `avs_ci_scan_cta` inside CI branch A.
- `apps/mobile/lib/screens/document_scan/avs_guide_screen.dart:547-549` executes
  `context.push('/scan', extra: DocumentType.avsExtract)`.
- `apps/mobile/test/screens/document_scan/avs_guide_screen_test.dart:61-96`
  proves both official branches and the scan CTA are present; the same test
  invokes both official URL actions.
- `apps/mobile/test/screens/document_scan/avs_guide_screen_test.dart:8-31`
  pins the exact localized 318.282 URLs and the official CI acquisition hub.
- `docs/codex/SCREEN_CONTRACTS.md:445-457` already declares `/scan` with
  `DocumentType.avsExtract` as a route out and declares the no-write evidence
  boundary.

Before this review, `docs/codex/WIRING_GRAPH.mmd:185-187` drew `SCAN -->
SCANAVS` but omitted the live reverse acquisition action. The minimal fix adds:

```mermaid
SCANAVS --> SCAN
```

This is not a speculative route: it records the existing `context.push` call
without changing the product.

## Diff reviewed

```diff
     COACH --> SCAN --> SCANAVS
     EXPAT --> SCANAVS
+    SCANAVS --> SCAN
     SCAN --> SREVIEW --> SIMPACT
```

## Gate results

All commands passed at reviewed HEAD:

- `python3 tools/checks/mermaid_render_guard.py` — PASS.
- `python3 -m pytest tools/checks/tests/test_screen_contracts_route_contract.py -q` — 4 passed.
- `python3 -m pytest tools/checks/tests/test_codex_spec_reality_contract.py -q` — 6 passed.
- `python3 -m pytest tools/checks/tests/test_data_quest_goal_aware_ranking_contract.py -q` — 1 passed.
- `flutter test --no-pub test/models/avs_gap_evidence_test.dart test/models/avs_gap_write_order_test.dart test/providers/coach_profile_provider_test.dart test/screens/document_scan/avs_guide_screen_test.dart` — 74 passed.
- `git diff --check` — PASS.

No external-audit rerun is required for these two findings.
