# SOURCE-01 — Quality Gate Evidence

Accepted product SHA: `ee6912679c20ee426c16dbd56585b01d9b205b9e`

Base SHA: `f885fa5072ec2de9b985cf1e08c8ce23fe00a096`

This report closes only `G1-SOURCE-01`. Phase 37 remains incomplete and
`G2 allowed` remains **NO**.

## RED → GREEN

The identical registry command was run on two distinct existing commits:

```text
cd services/backend && python3 -m pytest tests/test_source_crosswalk.py -q
```

- RED at `53dd840c9a210f6c08932607c9d1026c34b890f5`, exit 1:
  `7 failed, 1 passed`; the failure is the named SOURCE-01 business predicate,
  `the authoritative source crosswalk contract is absent`.
- GREEN at `ee6912679c20ee426c16dbd56585b01d9b205b9e`, exit 0:
  `8 passed`.
- Exact raw outputs: `red-output.txt`, `green-output.txt`.
- Strict machine-readable logs: `red.json`, `green.json`.

The RED was reproduced from a detached temporary worktree and removed after
the run. The active branch and its history were never reset, stashed, or
rewritten.

## Verification commands

| Command | Result |
|---|---|
| `python3 tools/checks/mint_os_doctor.py --repo-only` | PASS; 7 repo contracts |
| `python3 -m pytest tools/checks/tests/test_ledger_parity.py tools/checks/tests/test_g1_p0_ledger_dead_keys.py -q` | PASS; 10 tests |
| `cd services/backend && python3 -m pytest tests/test_source_crosswalk.py tests/test_enhanced_confidence.py tests/test_document_parser.py -q` | PASS; 128 tests |
| `cd services/backend && ruff check app/services/confidence/source_crosswalk.py tests/test_source_crosswalk.py` | PASS |
| fail-closed `_audit_manifest_errors(..., {'code', 'product-domain'})` | PASS; zero errors |
| `lefthook run pre-commit --file services/backend/app/services/confidence/source_crosswalk.py` | PASS |
| `lefthook run pre-commit --file services/backend/tests/test_source_crosswalk.py` | PASS |
| `git diff --check` | PASS |

## External audits

Both accepted runs used the checked-in wrapper, Opus high, base
`f885fa5072ec2de9b985cf1e08c8ce23fe00a096`, and head
`ee6912679c20ee426c16dbd56585b01d9b205b9e`.

- `code`: PASS, zero P0/P1/critical/high, two accepted P2 findings.
- `product-domain`: PASS, zero P0/P1/critical/high, two accepted P2 findings.
- Manifest: `audit-manifest.json`; full outputs: `audit-code.md` and
  `audit-product-domain.md`.

The P2 caller finding remains explicitly bounded: PROV-01 must consume this
crosswalk before Phase 37 closes. The P2 partition observation is currently
equivalent to the proven five mapped plus three exact backend-only identities
over the living eight-member `DataSource` enum. The deliberate mobile/backend
weight difference is documented in `DATA_LEDGER.md`; this module translates
identity and copies no weight.

## Privacy and scope

- Evidence is synthetic and contains no name, email, document content,
  authentication material, or real user financial value.
- No backend, mobile, route, UI, or product file was modified by this quality
  gate task.
- The other 21 `ticket_only` rows and `G1-RUNTIME-01: red_proven` are unchanged.

## Slice score

`10.0/10` for the applicable SOURCE-01 ticket gate: exact immutable contract,
Swiss/product-domain review, non-vacuous RED→GREEN, targeted and affected tests,
two accepted external lenses, privacy-safe evidence, and atomic diff discipline.
This is not the Phase 37 scorecard and does not authorize G2.
