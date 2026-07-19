# MINT External Audit — G1-RETURN-01 RVC LPP Native Proof

**Mode:** code · **Base:** `9baffa8fb` → **HEAD:** `0447ac488` (+ unstaged doc/comment changes) · **Diff:** ~1090 code lines + doc updates, within budget.

## Verdict: **PASS**

---

## What I verified (source of truth = code + tests, not docs)

**Production wiring is minimal, real, and non-behavioral (3 widgets, test hooks only):**
- `rente_vs_capital_screen.dart:698-701` — `Scaffold` wrapped in `Semantics(identifier: 'rvc_screen', container: true)`. Tree balance confirmed by direct read; `container:true` (not merge-all-descendants) preserves child a11y. The unstaged worktree change is pure whitespace re-indentation — no semantic change.
- `data_block_enrichment_screen.dart:189-199` — identifier/`Key('data_block_lpp_scan_cta')` added **only** for `canonicalBlockType == 'lpp'`; the `onPressed`/scan-return-intent logic (flag-gated by `lppEvidenceIngestionEnabled`) is untouched.
- `indicatif_banner.dart:117-133` — CTA wrapped in `Semantics(identifier: 'indicatif_banner_${route}_cta')` + matching `Key`; `onPressed` unchanged.

**No facade-without-wiring.** Every key the Patrol test drives is grep-confirmed live in production: `document_scan_lpp_example_cta` / `lpp_acquisition_self_continue` (`document_scan_screen.dart`), `lpp_review_source_date` / `lpp_review_confirm_cta` (`extraction_review_screen.dart`), `lpp_impact_retirement_cta` (`document_impact_screen.dart`).

**The behavioral test is strengthened, not weakened.** `rvc_scan_return_origin_test.dart` still exercises the real `IndicatifBanner → DataBlock → /scan → /scan/review → RVC` chain, and now also asserts the new semantics identifiers plus deterministic `documentSha256 == 44e89678…`. Fail-closed hostile-URI cases (case-altered key, double-encoded, duplicate params, injected `returnUri`/`access_token`) remain intact.

**Native runtime evidence exists and passed** (gitignored via `.git/info/exclude` — correct, since it holds device screenshots): `metadata.json` at `runtime-0447ac488b-…` shows `result/patrolResult/maestroResult = passed`; `patrol.log` ends `TEST EXECUTE SUCCEEDED` (1 test, 0 failures); visual review confirms synthetic write-back (LPP 350k→143'288) with no PII/paths/session IDs on screen.

**Privacy/compliance of the runner** (`patrol_return01_rvc_lpp_scan_return.sh`): `umask 077`, `chmod 600`, log+screenshot sanitizers redact repo/home/tmp/device/UUIDs and hard-fail if a private identifier survives; metadata redacts device; requires clean HEAD == requested SHA. No secrets committed.

---

## Findings

### P0 — none
### P1 — none

### P2 (advisory, no gate impact)
1. **Textual anchor/ordering tests are not behavioral.** `test/runtime/g1_return01_rvc_lpp_scan_return_runtime_test.dart` and `tools/checks/tests/test_g1_return01_rvc_runtime_orchestrator.py` assert *string presence/ordering* in harness sources. The ordering assertion (`test_…orchestrator.py:44-49`) matches **call-site** text in the runner, so it reflects execution order only incidentally and cannot catch a genuine reordering regression. Honestly labeled; supplements the real widget test.
2. **Native proof is not in CI.** The Patrol target is `skip: !MINT_PATROL_CLI`; evidence is reproducible only by running the runner against a booted simulator. Generated locally at `0447ac488b` and passing, but not machine-verified in the pipeline.
3. **Double-button semantics** in `indicatif_banner.dart` (`Semantics(button:true, child: TextButton…)`) creates nested button nodes — minor a11y redundancy, but consistent with the pre-existing `data_block_enrichment_screen.dart` pattern.

**Rationale:** shipped production behavior is a small, feature-flag-gated set of accessibility/test hooks with no business-logic change; end-to-end routing, the opaque-token security boundary, and the deterministic certificate SHA are proven by a real passing widget test and reproduced by passing native (Patrol + Maestro + simctl) evidence. Remaining items are evidence/quality gaps (P2), not correctness, privacy, routing, or facade-wiring defects. Consistent with the branch's own honest scope note: this closes the bounded RVC LPP atom only — `G1-RETURN-01` stays `ticket_only` and G1 remains NO-GO globally, which the diff does not overclaim.
