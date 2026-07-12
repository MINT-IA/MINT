# Phase 37-02 quality checkpoint — fail closed

**Product SHA:** `8941a85b3d3baa18656e7f399997c7cca5b73f36`

**SOT/evidence SHA:** `3693978ea439d686096f5b4e0b0eab7c6bf616c4`

## Green evidence collected

- Six exact ticket commands pass independently on the product SHA.
- `flutter test test/models/ test/providers/mint_state_proxy_recompute_test.dart --reporter expanded`: 225 passed.
- Final full Flutter suite supplied by the mobile executor: 8,514 passed, 28 skipped, exit 0.
- Touched-file analyzer: no issues, exit 0.
- Global analyzer floor remains the pre-existing 114 diagnostics and exit 1; it is recorded as an unchanged baseline floor, not reported as a global PASS.
- Repo Doctor, Mermaid render, ledger parity, progressive ticket gate, and screen-contract route gate pass.
- The 39 stale `reader_evidence` windows in `G1-ledger-gap-matrix.md` were mechanically synchronized to live readers.
- Lefthook passed on the SOT/evidence checkpoint.

## Blocking audit state

The wrapper-only `code` audit was rerun after Claude became available:

```text
CLAUDE_AUDIT_MAX_DIFF_LINES=4500 tools/checks/claude_external_audit.sh code 3397d48b2
```

The default Opus/high run exited 0 with verdict PASS, zero unresolved P0/P1,
and two explicit non-blocking P2 findings archived in `audit-code.md`. The
earlier preflight refusal and Claude session-limit attempt remain recorded in
`audit-failed-attempts.json`; neither is an accepted audit run.

The required `product-domain` audit then ran from an isolated detached worktree
at the same audited head `ef80e8cb8`. The wrapper exited 0 and the external
auditor wrote `PASS`, but the report contains three unresolved P1 findings:
wizard-derived AVS gaps are stamped as certificate-grade, four new typed fields
have no direct production consumer, and the G1 matrix points canonical paths at
those unread fields. The run is archived as `audit-product-domain-p1.md` and is
not accepted.

The exact global `flutter analyze` hard floor also remains RED with 114
diagnostics. The plan requires that command to exit 0 and contains no baseline
waiver. There is therefore no final accepted `audit-manifest.json`, no ticket
promotion, and no Phase 37/G2 completion claim. Fix the P1 findings and the
global analyzer floor, then use the bounded rerun/final-confirmation policy.

## P1 remediation checkpoint

The three product/domain P1 findings were repaired test-first and pushed at
product SHA `134ffd9d2`:

- wizard AVS status is declared; only confirmed `_coach_avs_lacunes` hydrates
  certified gap years;
- manual contribution years are `userInput`, while persisted AVS scan data is
  `certificate`;
- current 3a, monthly-savings, 3a-presence, and AVS-status facts now have real
  production consumers using exclusive `typed ?? legacy` precedence;
- the G1 matrix and checked-in contracts point to those real consumers through
  a non-vacuous static gate.

Local proof is archived in `p1-remediation.json`: 317 affected Flutter tests
passed, the final full suite passed 8,519 with 28 skipped, touched analyzer is
clean, and the ledger/screen static gates pass. The global analyzer remains the
only known local hard-floor failure at 114 diagnostics. Because the audited
head changed, both accepted audit modes must be rerun against the same final
post-analyzer SHA before any manifest or ticket promotion.

**G2 allowed: NO.**
