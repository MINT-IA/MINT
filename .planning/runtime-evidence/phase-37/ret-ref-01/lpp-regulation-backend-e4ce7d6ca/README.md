# G1 RET-REF-01 — LPP regulation backend evidence

## Scope and exact source

This minimized, sanitized package proves only the backend authority boundary
for `lppRegulationReference`:

- base SHA: `c3d64a99d`
- implementation SHA:
  `e4ce7d6caa2c34438288bdfc5662aed0ff82f0a7`
- starting HEAD: exact implementation SHA
- fixtures: synthetic only
- raw/private LPP document used: false
- new Claude call by this quality agent: false

The implementation distinguishes an explicit FR/DE/IT pension-plan or
regulation from a personal LPP certificate. A plan upload returns
`document_type=lpp_plan`, an empty extraction, zero fields and no RAG indexing.
It never constructs the personal-certificate extractor. A generic LPP/BVG
mention fails closed to `unknown`.

A concurrent permanent mobile agent modified
`apps/mobile/lib/providers/document_provider.dart` after the initial clean
verification. HEAD remained the exact backend implementation SHA throughout
the targeted backend runs, then advanced through separate mobile BND/ledger
slices (074883d57656069d3472f759e4ce3b5d89c59c8a and
38edd8cda674cbbc8519ff383d0f604ffd240bcf at package finalization). No backend path changed; every backend
claim in this package remains bound to implementation SHA
e4ce7d6caa2c34438288bdfc5662aed0ff82f0a7.

## Verdict boundary

| Boundary | Verdict | P0 | P1 |
|---|---:|---:|---:|
| Backend plan/certificate authority slice | **GREEN** | 0 | 0 |
| `lppRegulationReference` end-to-end atom | **NO-GO / open** | — | — |
| Mobile activation and final user copy | **NO-GO** | — | — |
| Whole RET-REF and G1 | **NO-GO / open** | — | — |
| G2/G3 | **forbidden** | — | — |

This package does not claim mobile authority, ledger persistence, BND cold
resolution, Dashboard consumption, specialist handoff, Maestro/Patrol runtime
proof, RET-REF closure or G1 closure.

## Executed gates

| Gate | Result | Artifact |
|---|---:|---|
| Mint OS Doctor `--repo-only` | PASS | `mint-os-doctor-repo-only.log` |
| Targeted Ruff lint on all three touched files | PASS | `targeted-ruff.log` |
| LPP plan upload/classifier contract | **10 passed** | `test-lpp-plan-contract.log` |
| Documents + Docling regression suites | **89 passed** | `test-documents-docling.log` |
| Document classification suites | **30 passed, 1 skipped** | `test-document-classifications.log` |
| Working-tree and exact-slice whitespace check | PASS | `git-diff-check.log` |
| Claude wrapper code lens, Opus first pass | PASS, P0=0/P1=0 | `audit-code-opus-first-pass.sanitized.txt` |
| Claude wrapper product/domain lens, Opus first pass | PASS, P0=0/P1=0 | `audit-product-domain-opus-first-pass.sanitized.txt` |

The full backend baseline (**6,156 passed, 12 skipped, 0 failed**) is reported
by `mint-lead`, not rerun by this evidence-only agent. Repository-wide
`ruff check .` remains a known **NO-GO with 92 debts outside this bounded
slice**; targeted lint is green. See `reported-backend-baseline.txt`.

A separate formatter probe found that `documents.py` and `test_documents.py`
would be reformatted, while the new contract test is already formatted. No
file was rewritten because quality ownership is evidence-only. This transparent
formatter follow-up is recorded in `targeted-ruff-format-follow-up.log`; it does
not change the targeted lint or `git diff --check` results.

## P2 dispositions

1. The closed, line-anchored personal-certificate headings and salary
   precedence have fail-safe recall gaps. Do **not** broaden the heuristic from
   invented examples. A wider classifier needs a reviewed corpus and, for any
   private plan promoted to a positive classifier fixture, a second explicit
   human-reviewed manifest proving document kind, source date, legal year and
   current-plan linkage. Existing certificate/plan fixture roles must not be
   auto-relabelled.
2. The backend English warning is descriptive evidence, not approved final
   mobile copy. Final exposure requires localized mobile wording and a proven
   degraded/next-question state.
3. Counting a plan against the document quota is accepted for this backend
   boundary. It is not approval to activate the mobile path; activation remains
   NO-GO until the review → ledger/BND → consumer chain and runtime proof exist.

No P2 permits plan values to become personal salary, rate, scale, benefit,
return or other ledger facts.

## Privacy and minimization

The tracked package contains source/test names, synthetic classifier examples,
aggregate counts, bounded audit verdicts and hashes only. It contains no PDF,
document bytes/path, OCR payload, extracted personal fact, person name, e-mail,
AVS number, real financial amount, simulator identifier, credential, token,
secret or absolute local path. The temporary raw audit outputs are not tracked.

`SHA256SUMS` hashes every artifact except itself.
