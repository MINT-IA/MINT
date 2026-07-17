# G1-COACH-01 verification

Accepted implementation and runtime SHA:
`fec1d4119e4c6f71c6bc81701943621245fee967`

- Ticket decision: **GREEN**
- G1 score and decision: **8.2/10 — NO-GO**
- G2/G3 decision: **forbidden**

## Exact TDD ticket proof

- Registry command:
  `cd apps/mobile && flutter test test/integration/coach_inline_amount_write_contract_test.dart --reporter expanded`.
- Semantic RED SHA `c7809198e1394819d6311f434fbe506f33258fad`:
  the identical command reached the versioned production seams and collected
  ten predicates; **3 controls passed / 7 semantic predicates failed**. The
  failures proved the real awaited-write, canonical-unit, strict-LPP,
  invalid-value and retry contracts were absent; they were not harness errors.
- Core GREEN SHA `cefc66e50436e8a32c04ce503644c292813cb0fc`:
  the identical command reached **14/14 PASS** after the atomic implementation.
- Accepted pushed SHA `fec1d4119e4c6f71c6bc81701943621245fee967`:
  the same command again passed **14/14**, including one serialized canonical
  write before notify/answered/echo, cold reload and exact provenance.
- Machine evidence: `red.json`, `green.json`, `audit-manifest.json` and
  `runtime-summary.json`.

The live `WidgetRenderer -> CoachMessageBubble -> CoachChatScreen` chain now
awaits the canonical provider seam. `salaireBrut` is annual gross CHF and keeps
the persisted 12/13-period authority; `avoirLpp` and `epargne3a` remain total
stocks. Zero is durable, while values above the existing CHF 10M ceiling,
negative values, NaN and infinities fail before side effects. Strict typed-LPP
root presence wins atomically over the loose amount, and a transient persistence
failure keeps the input retryable. No alias or capture facade was added.

All ticket profiles and amounts are synthetic. No private certificate, raw
device identifier, absolute local path or xcresult is retained.

## Exact-SHA Patrol and visual proof

The accepted runtime folder is
`runtime-fec1d4119e-20260717T132538Z/`. Its two-stage Patrol build then
`xcodebuild test-without-building` execution ran the single dedicated target
and finished **1 test / 0 failures** at the exact accepted SHA. Metadata binds
the target, bundle and SHA; the sanitized log and screenshot hashes are frozen
in `runtime-summary.json`. Cleanup restored the original build and removed the
generated bundle and xcresult.

Direct visual inspection accepted `final.png`: the real MINT Coach screen shows
its synthetic annual-salary question, the factual `CHF 120'000` echo and the
completion bubble after the durable write. The same test separately reconstructs
the provider and proves cold-reload provenance before the capture handshake.
The screenshot visibly carries Patrol's DEBUG test-name overlay. It is therefore
honest in-test UI/runtime evidence, not a claim about shipping-default production
chrome.

## External audit disposition

The effective first-pass commands were
`CLAUDE_AUDIT_MAX_DIFF_LINES=7600 tools/checks/claude_external_audit.sh code c7809198e1394819d6311f434fbe506f33258fad`
and the equivalent `product-domain` command. Both used wrapper-default Opus,
high effort, ended at the exact accepted SHA, exited `0`, and returned **PASS**
with P0=0/P1=0. Per the no-carousel rule, no rerun was authorized.

The annual-gross contract and the repaired dropped-salary path resolve two
review observations. Five nonblocking P2 follow-ups remain explicit in
`audit-manifest.json`: field-specific `prompt_text` unit enforcement,
13th-salary wording, a dead normalized display branch, post-persistence
`_sendMessage` recovery UX and non-template ARB metadata normalization.

## Decision boundary

This promotion closes only `G1-COACH-01`. It does not activate a financial
product, close `G1-RUNTIME-01`, complete G1 or authorize G2/G3. The canonical
registry becomes **21 GREEN / 9 `ticket_only` / 1 `red_proven`**: **10 hard
floors remain open**. The next ordered ticket is `G1-FRONT-01`; G1 remains
**8.2/10 — NO-GO**.
