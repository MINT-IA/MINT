# Quality gate scorecard — G1 LPP regulation backend slice

**Implementation SHA:**
`e4ce7d6caa2c34438288bdfc5662aed0ff82f0a7`
**Bounded backend score:** **9.0/10**
**Backend authority boundary:** **GREEN**
**End-to-end atom / activation:** **NO-GO**

This score applies only to the backend plan/certificate boundary. It is not a
score for the whole `lppRegulationReference` atom, RET-REF or G1.

| Dimension | Score | Evidence |
|---|---:|---|
| Data contract | 2.0 / 2.0 | Exact `lpp_plan` classification is metadata-only; personal certificate wins explicit heading precedence; ambiguous LPP stays `unknown`; plan extraction/RAG is zero. |
| Swiss correctness | 1.5 / 1.5 | Fund rules remain document authority only and never become one person's LPP facts; FR/DE/IT contract cases pass. |
| UX lucidity | 1.0 / 1.5 | The backend returns an explicit plan/regulation warning, but localized final copy and the mobile next-question state are not accepted. |
| Runtime proof | 1.0 / 1.5 | Real FastAPI upload tests exercise routing, zero extraction and no extractor construction; mobile Maestro/Patrol proof is intentionally absent for this backend-only slice. |
| Automated tests | 1.0 / 1.0 | 10/10 contract, 89/89 documents+Docling, and 30 pass/1 skip classification suites; targeted Ruff lint and diff check pass. |
| External audit | 1.0 / 1.0 | Both bounded wrapper-only first-pass Opus lenses PASS with P0=0/P1=0; P2 findings are explicitly dispositioned. |
| Integration/privacy hygiene | 1.0 / 1.0 | No personal extraction, no RAG, synthetic-only evidence, no raw/private document or PII retained. |
| Diff discipline | 0.5 / 0.5 | One bounded backend commit and minimized hash-addressed evidence; formatter follow-up is disclosed without out-of-scope rewrites. |
| **Total** | **9.0 / 10.0** | Backend slice accepted; no activation or whole-atom promotion. |

## Baseline qualifications

- Full backend: **6,156 passed, 12 skipped, 0 failed**, reported by
  `mint-lead`; not rerun here.
- Repository-wide Ruff: **NO-GO, 92 known debts outside this slice**.
- Targeted Ruff lint: **PASS** on the three touched files.
- Targeted formatter probe: two files would be reformatted; follow-up recorded,
  no mutation performed.
- `git diff --check`: **PASS** for the worktree and
  `c3d64a99d..e4ce7d6ca`.

## Open blockers

1. Mobile still needs exact `lpp_plan` review/authority mapping with explicit
   `sourceDate` and `legalYear`.
2. The current strict self LPP snapshot must bind the serialized ledger writer,
   raw-free BND record, cold resolver and invalidation behavior.
3. Dashboard education and specialist metadata-only handoff need real consumers.
4. Default-false activation, Maestro/Patrol proof and exact-SHA mobile evidence
   remain mandatory.
5. RET-REF and G1 remain open; G2/G3 must not begin.
