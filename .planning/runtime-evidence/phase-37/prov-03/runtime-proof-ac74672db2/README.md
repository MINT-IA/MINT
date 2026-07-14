# G1-PROV-03 exact-SHA runtime proof

Ticket: `G1-PROV-03`

Runtime source SHA:
`ac74672db209c20f35b4903e26d83d8f0ca2c93f`

Runtime window: 2026-07-14 15:01–15:06 UTC

Decision:

- PROV-03 code gate: **GREEN**.
- Exact-SHA runtime: **GREEN**.
- Claude code audit: **PASS**, zero P0/P1.
- Claude product-domain audit: **PASS**, zero P0/P1.
- Production activation: **NO**. Both tax-ingestion feature flags remain false;
  the runtime enables them only in the isolated Patrol test process.
- G1: **NO-GO**. This proof closes one ticket only and does not close
  `G1-RUNTIME-01` or any of the other open Phase 37 rows.

## Runtime chain

One physical iOS Simulator and one exact source SHA were used for the whole
chain:

1. Full MINT Doctor and Patrol tooling guard passed.
2. The normal application built and installed with both feature flags off.
3. Maestro proved the flag-off state.
4. A dedicated Patrol writer confirmed one synthetic tax assessment through
   the real scan-review/provider/secure-store path.
5. The simulator was explicitly booted, the app launched, terminated through
   `simctl`, and a separately built Patrol reader was installed.
6. The reader cold-reloaded the typed snapshot and validated its exact values,
   owner/profile identifiers, source/source-date provenance, freshness,
   conflict-free canonical selectors and privacy boundary.
7. Independent `xcresulttool` summaries report exactly one passed writer test
   and one passed reader test, with zero failures and zero skips.
8. The external build tree and normal application were restored. Maestro,
   Doctor, Patrol tooling guard and the 19-test orchestrator contract all
   passed again.
9. Full Flutter analyze found zero issues and the full suite completed with
   8,899 passed, 33 skipped and zero failed at this same source SHA.

Every runtime fixture is synthetic. No raw tax document, OCR text, name,
e-mail, AVS number or real financial value is retained in this tracked proof.

## Tracked evidence

- `patrol-metadata.sanitized.json` — commands, exact SHA, lifecycle exit codes,
  feature activation mode, restoration status and binary entitlement hashes.
- `write-xcresult-summary.sanitized.json` — independent writer result, 1/1.
- `read-xcresult-summary.sanitized.json` — independent cold-reader result, 1/1.
- `gate-exit-codes.json` — deterministic zero/non-zero record for the runtime
  and external-audit commands.
- `architecture-sonnet-p1-remediation.json` — two exact RED stages and the
  final 23 disclaimer passes / 0 failures, four-file accent, zero-issue analyze and 689/689
  financial-core GREEN proof, followed by the 8,900/33/0 full Flutter suite.
- `original-bundle-core-sha256.json` — hashes of the three core files in the
  complete local runtime bundle before sanitization.
- `SHA256SUMS` — hashes of the sanitized tracked artifacts.
- `audit-code-opus-first-pass.txt` — bounded code audit PASS.
- `audit-product-domain-opus-first-pass.txt` — Swiss product/domain audit PASS.
- `audit-architecture-opus-first-pass.txt` — G1-level NO-GO that correctly
  found stale acceptance documents; its two path attributions were verified
  and corrected during reconciliation.
- `audit-architecture-sonnet-rerun.txt` — the one authorized rerun at
  `9daede134`; it confirms the stale-document P1s resolved and PROV-03
  architecture-clean, while correctly retaining full G1 NO-GO for the 18 open
  rows. Its two newly identified French-accent P1 literals are repaired in the
  follow-up commit that records the audit.

The raw build products, full `.xcresult` bundles and screenshots remain local
and excluded from Git. This directory is the minimal, reviewable and sanitized
proof set.
