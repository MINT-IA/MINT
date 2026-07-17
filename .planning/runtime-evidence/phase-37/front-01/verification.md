# G1-FRONT-01 verification

Accepted implementation and runtime SHA:
`cb580c7a8522ee3728ea7ab8ce8faca46ef05497`

- Ticket decision: **GREEN**
- G1 score and decision: **8.2/10 — NO-GO**
- G2/G3 decision: **forbidden**

## Exact TDD ticket proof

- Registry command:
  `cd apps/mobile && flutter test test/models/frontier_canonical_fields_test.dart --reporter expanded`.
- Corrected semantic RED SHA
  `18e0918f66b20c2739107d624f19d8baa868037e`: the identical command reached
  the real model, financial consumers and Frontalier screen and finished
  **15 PASS / 5 semantic FAIL**. The missing production behavior was a live
  canonical provider consumer, real missing/known/non-Swiss states and removal
  of invented defaults/legal calculators. These were business-predicate
  failures, not harness failures.
- Accepted pushed SHA
  `cb580c7a8522ee3728ea7ab8ce8faca46ef05497`: the same command was replayed
  during promotion and passed **20/20**.
- Machine evidence: `red.json`, `green.json`, `audit-manifest.json` and
  `runtime-summary.json`.

Residence country, work country and work canton are independent typed nullable
facts with canonical markers, source, timestamp and source-date slot. Permit G,
nationality, residence canton and frontalier status infer none of them. The
screen writes through the real `CoachProfileProvider`, persists FR/CH/GE,
exposes missing, known and specialist-only states, and treats the work canton
as known at 782 days but stale at 783 days. A non-Swiss work country clears the
Swiss canton atomically. Permit G cannot fabricate 3a eligibility.

The old flat withholding table, universal 90-day gauge and fiscal/social
ranking were removed from this path. Geneva produces only a labelled 1966
instrument **candidate**; fiscal and social-insurance education remain separate
and no personal rate or amount is concluded. No alias, duplicate ledger or
uncalled facade was introduced.

All ticket profiles, jurisdictions and values are synthetic. No private
certificate, raw device identifier, absolute local path or xcresult is retained.

## Regression and operating gates

- Full Flutter suite at the accepted SHA: **9,567 passed / 44 skipped**, exit
  `0`, in 4m22s. The bounded retained summary binds the omitted 3.6 MB progress
  log by SHA-256.
- Full mobile analyzer: **No issues found**, exit `0`.
- Full Mint OS Doctor before runtime: repo and host Patrol, Maestro, Mermaid,
  Claude-wrapper and workflow gates all **PASS**.
- The corrected RED test file analyzer also passed.

Hashes for the bounded logs, original temporary logs and runtime artifacts are
frozen in `runtime-summary.json`.

## Exact-SHA Patrol and visual proof

The first physical run at `af7f265fcc4386260d8e6287791cc7e843d0c841`
was a true runtime RED: Xcode selected the one real Dart test, then the FR
dropdown step timed out because the source `DropdownMenuItem` existed only
offstage. The sanitized log records **1 test / 1 failure** and exit `65`.

After the visible-overlay selector fix, the accepted folder
`runtime-cb580c7a85-20260717T175900Z/` ran the same dedicated Patrol target
through build then `xcodebuild test-without-building`. Exactly one Dart test
was selected and passed **1/1 with 0 failures**. It exercised the production
MintApp route, proved the initial missing state, selected FR/CH/GE through real
controls, checked canonical persistence/provenance, reached the known state,
kept fiscal and social cards distinct, rejected personal amounts and the
universal 90-day result, then completed the screenshot handshake. Cleanup
restored the original build and removed the generated bundle and xcresult.

Direct inspection accepts `final.png` as bounded in-test runtime evidence. The
visible work-country/canton summary, 1966 candidate card, separate social card
and specialist questions are readable. Patrol's red DEBUG test-name overlay
obscures the top heading, so this screenshot does **not** claim shipping-default
chrome or final visual polish. See `visual-review.md`.

No separate Maestro success is claimed by this ticket promotion. The checked-in
Doctor confirms Maestro tooling, while `G1-RUNTIME-01` remains the distinct
Maestro/Patrol process-death hard floor and is still `red_proven`.

## External audit disposition

The first-pass wrapper commands were
`tools/checks/claude_external_audit.sh code 757a5f375ea93f4424c98282f9c744182affea15`
and the equivalent `product-domain` command. Both used wrapper-default Opus at
high effort, ended at the exact accepted code SHA, exited `0`, and returned
**PASS** with P0=0/P1=0. Per the no-carousel rule, no rerun was authorized.

Four nonblocking P2 follow-ups remain explicit in `audit-manifest.json`: a
domestic readiness-label mismatch, canton display order, the conservative
ordinary-tax fallback estimate for an incomplete permit-G profile, and later
dossier export. The audit's runtime-pending observation is resolved by the
exact-SHA Patrol evidence that already existed outside the tracked audit diff
and is now archived with the promotion; none of these observations authorizes
a personal calculation or later product phase.

## Decision boundary

This promotion closes only `G1-FRONT-01`. It does not close
`G1-RUNTIME-01`, complete Plan 37-05, complete G1 or authorize G2/G3. The
canonical registry becomes **22 GREEN / 8 `ticket_only` / 1 `red_proven`**:
**9 hard floors remain open**. The next ordered ticket is `G1-RET-REF-01`; G1
remains **8.2/10 — NO-GO**.
