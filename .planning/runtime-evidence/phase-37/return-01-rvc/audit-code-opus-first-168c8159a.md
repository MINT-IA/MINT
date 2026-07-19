# MINT External Audit — G1-RETURN-01 RVC Native Proof

**Audit mode:** code · **Base:** `9baffa8fb` → **HEAD:** `168c8159a` · **Diff:** 1090 lines (within 2500 budget)

## Verdict: **PASS**

---

## What was verified (source of truth = code + tests)

**Production wiring is real and minimal (3 widgets):**
- `rente_vs_capital_screen.dart:698-701` wraps `Scaffold` in `Semantics(identifier: 'rvc_screen', container: true)`. Tree balance confirmed (added `)` at close); compiles and renders under widget test.
- `data_block_enrichment_screen.dart:189-199` adds `identifier`/`Key('data_block_lpp_scan_cta')` **only** for `canonicalBlockType == 'lpp'`; the underlying scan-return intent flow (feature-flag gated: `lppEvidenceIngestionEnabled`) is unchanged.
- `indicatif_banner.dart:117-133` wraps the CTA in `Semantics(identifier: 'indicatif_banner_${route}_cta')` + matching `Key`, `onPressed` unchanged.

**All keys referenced by the Patrol test exist in production** (`document_scan_lpp_example_cta`, `lpp_acquisition_self_continue`, `lpp_review_confirm_cta`, `lpp_impact_retirement_cta`, `lpp_review_source_date`) — grep-confirmed in `document_scan_screen.dart`, `extraction_review_screen.dart`, `document_impact_screen.dart`. No facade key.

**The meaningful test runs and passes** (`flutter test`, 52/52):
- `rvc_scan_return_origin_test.dart` exercises the real `IndicatifBanner`→`DataBlock`→`/scan`→`/scan/review`→RVC chain, asserts opaque UUIDv4 `scanReturnId`, deterministic `documentSha256 == 44e89678…`, and **fail-closed** behavior against hostile URIs (case-altered key, double-encoded, duplicate params, injected `returnUri`/`access_token`, mixed Pillar3a). Strengthened, not weakened.
- Python orchestrator test + `bash -n` on the runner: pass, syntax valid.

**Privacy/compliance of the native runner** (`patrol_return01_rvc_lpp_scan_return.sh`): `umask 077`, `chmod 600`, log+screenshot sanitizers strip repo/home/tmp/device/UUIDs and hard-fail if a private identifier survives; metadata redacts device. Requires clean HEAD == requested SHA before writing evidence. No secrets committed.

---

## Findings

### P0 — none

### P1 — none

### P2 (advisory)

1. **Grep/anchor tests give coverage-shaped signal, not behavioral proof.**
   `test/runtime/g1_return01_rvc_lpp_scan_return_runtime_test.dart:11-27` and `tools/checks/tests/test_g1_return01_rvc_runtime_orchestrator.py` assert *string presence* in harness sources, not that the native flow executes. Notably the orchestrator's ordering check —
   `test_g1_return01_rvc_runtime_orchestrator.py:44-49` (`wait_for_visual_marker` < `maestro_with_watchdog.sh` < `remove_visual_marker`) — is satisfied by the single comment line at `patrol_return01_rvc_lpp_scan_return.sh:216-217` regardless of the actual function-definition order (`remove_visual_marker` is in fact *defined* before `wait_for_visual_marker`). The assertion cannot catch a real ordering regression. These are honestly labeled ("Patrol owns the … journey") and supplement the real widget test, so no gate impact — but they should not be read as native-execution guarantees.

2. **No native evidence artifacts are checked in.** `git ls-files .planning/runtime-evidence/phase-37/return-01-rvc/` → empty. The branch adds the *machinery* (Patrol test skipped unless `MINT_PATROL_CLI`, Maestro screenshot-only flow, simulator runner) but the pixel/native proof is only reproducible by manually running the runner against a booted simulator; it is not exercised in CI. To *prove* the native journey, run:
   `tools/simulator/patrol_return01_rvc_lpp_scan_return.sh --device <udid> --bundle-id ch.mint.app --sha 168c8159ac57cb3fda1b1a7a5d5489c9534ae413 --artifacts .planning/runtime-evidence/phase-37/return-01-rvc/runtime-168c8159ac-<UTC>` and inspect `metadata.json` (`patrolResult`/`maestroResult`) + screenshots.

---

**Rationale for PASS:** the shipped production behavior is a small, feature-flag-gated set of test hooks whose end-to-end routing, opaque-token security boundary, and deterministic SHA are verified by a real, passing widget test (52/52). The weaker grep/orchestrator tests and the absence of checked-in native artifacts are quality/evidence gaps (P2), not correctness, privacy, routing, or facade-wiring defects.
