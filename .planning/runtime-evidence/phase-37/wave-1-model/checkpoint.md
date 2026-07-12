# Phase 37-02 quality checkpoint — local hard floors green, audits pending

**Initial ticket implementation SHA:** `8941a85b3d3baa18656e7f399997c7cca5b73f36`

**P1 semantic remediation SHA:** `134ffd9d2`

**Prior SOT/evidence SHA:** `e8bf8093e`

**Current candidate SHA before this checkpoint:** `885d513f8`

## Green evidence collected

- Six exact ticket commands pass independently on the initial ticket SHA; the
  affected regression suite also passes after the P1 semantic remediation.
- `flutter test test/models/ test/providers/mint_state_proxy_recompute_test.dart --reporter expanded`: 225 passed.
- Latest full Flutter suite: 8,519 passed, 28 skipped, exit 0.
- Touched-file analyzer: no issues, exit 0.
- Global analyzer hard floor is now green: `flutter analyze` reports no issues
  and exits 0 after three atomic remediation lots.
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

That audit remains historical and rejected: the P1 findings were remediated and
the audited head has changed. There is therefore still no final accepted
`audit-manifest.json`, no ticket promotion, and no Phase 37/G2 completion
claim. Both bounded audit modes must now rerun against one frozen final head.

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
clean, and the ledger/screen static gates pass.

## Global analyzer remediation checkpoint

The literal hard floor is now green and archived in
`analyzer-remediation.json`:

- mechanical cleanup: 114 → 16 at `6a2300229`;
- Flutter 3.41 accessibility migration: 16 → 7 at `1cd920326`;
- dormant contract repairs: 7 → 0 at `885d513f8`;
- every lot retained a full-suite result of 8,519 passed / 28 skipped;
- no ignore, `analysis_options` weakening, test deletion, or waiver was used.

Local hard floors are green, but the state remains fail-closed until the code
and product-domain wrapper audits both accept the exact same frozen head with
zero unresolved P0/P1/critical/high findings. The six ticket rows remain
unpromoted until that manifest exists.

**G2 allowed: NO.**
