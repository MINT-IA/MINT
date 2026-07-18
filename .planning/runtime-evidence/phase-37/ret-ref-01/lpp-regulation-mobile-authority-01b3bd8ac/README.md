# G1 RET-REF-01 — LPP regulation mobile authority exact-SHA proof

## Scope

This minimized, sanitized package proves the bounded mobile authority layer at
exact SHA `01b3bd8acad2a98fce0c0f2778340c5ddef7a7a7`:

- strict `self.lppRegulationReference` model and round trip;
- local default-false/non-remote feature flag;
- serialized save-before-publish ledger writer and exact receipt matcher;
- raw-free BND admission, record, replacement and cold resolver;
- capital-notice coexistence and shared mutation serialization;
- account SessionEpoch hydration/publication protection.

All fixtures are synthetic. No private LPP plan/certificate, raw bytes, OCR,
document path, simulator identifier or real financial record is used.

## Boundary verdict

| Boundary | Verdict | P0 | P1 |
|---|---:|---:|---:|
| Mobile authority code | **GREEN** | 0 | 0 |
| Production acquisition caller | **NO-GO** | 0 | 1 |
| Screen/dossier/specialist consumer | **NO-GO** | 0 | 1 |
| Device runtime and activation | **NO-GO** | — | blocked by preceding edges |
| Whole `lppRegulationReference` atom, RET-REF and G1 | **NO-GO / open** | — | — |
| G2/G3 | **forbidden** | — | — |

The two P1 findings come from the document product/domain Opus audit and are
retained, not waived. The bridge has no production write caller or read
consumer. Default-off authority primitives can be code-GREEN without claiming
user value or activation.

## Executed gates

| Gate | Result | Artifact |
|---|---:|---|
| Repo-only Mint OS Doctor | PASS | `mint-os-doctor-repo-only.log` |
| Targeted model/specialist/BND/writer/bridge/capital/generic/session suite | **112 passed** | `flutter-targeted-authority-suite.log` |
| Analyze eight authority files | **8/8, zero issues** | `dart-analyze-touched-files.log` |
| Full-project Flutter analyze | **NO-GO: two untouched info lints** | `flutter-analyze.log` |
| Worktree and exact-slice diff check | PASS | `git-diff-check.log` |
| Six bounded first-pass Opus outputs | **6 PASS** | `audit-*.sanitized.txt` |
| Audit severity/dispositions | Authority P0=0/P1=0; delivered product P1=2 | `audit-dispositions.md` |
| Privacy/minimization scan | PASS | `privacy-inventory-check.log` |

The targeted test command includes:

- `lpp_regulation_reference_ledger_contract_test.dart`;
- `specialist_reference_contract_test.dart`;
- `lpp_regulation_reference_document_authority_test.dart`;
- `lpp_regulation_reference_provider_test.dart`;
- `lpp_regulation_reference_document_bridge_test.dart`, including hardening;
- `lpp_capital_notice_document_reference_test.dart`;
- `document_reference_bridge_test.dart`;
- the full relevant `account_session_epoch_test.dart`.

## Full-analyzer qualification

`flutter analyze --no-pub` reports only two `prefer_const_declarations` infos in
`test/providers/lpp_capital_notice_deadline_provider_test.dart`, which is outside
the authority-slice file list. No existing source was changed. The targeted
authority analysis is green; the repository-wide analyzer baseline is recorded
as non-green.

## Tracked evidence

- `quality-gate-scorecard.md` — fixed-rubric bounded score.
- `audit-dispositions.md` — all P0/P1/P2 dispositions.
- Six `audit-*.sanitized.txt` files — existing wrapper-only Opus outputs.
- `gate-exit-codes.json` and `head-and-scope.txt` — deterministic scope/results.
- Doctor, Flutter test/analyze and diff-check logs.
- `privacy-inventory-check.log` — raw/PII/path scan.
- `SHA256SUMS` — hashes every artifact except itself.

No new Claude call was made by this quality agent. Acquisition, user consumer,
specialist handoff, device runtime, activation, RET-REF and G1 remain open.
