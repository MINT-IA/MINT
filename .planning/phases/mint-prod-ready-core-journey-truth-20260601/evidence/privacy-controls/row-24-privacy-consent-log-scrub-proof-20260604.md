# Row 24 — Privacy / Consent / Log Scrub Partial Proof

Date: 2026-06-04
Status impact: Row 24 moves from `UNPROVEN` to `PARTIAL`.

## What This Proves

This is a targeted local proof for the privacy/control surface. It proves that
current mobile and backend tests cover:

- mobile privacy-control screen rendering, edit, delete, grouping, and summary;
- mobile consent sheet purpose rendering and accept flow;
- mobile third-party document declaration analytics emit only aggregate
  `subject_count`, never detected subject names or `docHash`;
- mobile Sentry scrubber and PII breadcrumb guards;
- backend privacy endpoints/contracts;
- backend Sentry event scrubber;
- backend PII scrubber and fact-key allowlist;
- backend consent service and Merkle-chain consent receipt contracts;
- backend privacy delete count integration proof.

## Commands

### Runtime privacy-control screen

Build:

```bash
cd apps/mobile && flutter build ios --simulator --debug \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Install target:

```text
iPhone 17 Pro - iOS 26.2 - B03E429D-0422-4357-B754-536637D979F9
```

Flow:

```bash
MAESTRO_HARD_LIMIT=240 MAESTRO_STALL_THRESHOLD=90 \
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-24-privacy-control-runtime-20260604T182101 \
bash tools/simulator/maestro_with_watchdog.sh test \
  --udid B03E429D-0422-4357-B754-536637D979F9 \
  --debug-output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-24-privacy-control-runtime-20260604T182101/debug \
  --format junit \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-24-privacy-control-runtime-20260604T182101/result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row24_privacy_control_runtime.yaml
```

Result:

```text
1/1 Flow Passed in 21s
JUnit: tests=1, failures=0
watchdog EXIT_CODE=0
```

Durable artifacts:

```text
evidence/maestro-ci/row-24-privacy-control-runtime-20260604T182101/result.xml
evidence/maestro-ci/row-24-privacy-control-runtime-20260604T182101/row24-privacy-control-runtime.png
```

Visual review: screenshot shows `Ce que MINT sait de toi`, `4 données | 100 %
à jour`, profile/canton/financial data cards, and no empty-state text.

### Mobile privacy contracts

```bash
cd apps/mobile && flutter test \
  test/services/privacy_service_test.dart \
  test/widgets/consent/consent_sheet_test.dart \
  test/services/consent/consent_service_local_fallback_test.dart \
  test/screens/profile/privacy_control_screen_test.dart \
  test/widgets/document/third_party_declaration_sheet_test.dart \
  test/services/observability/sentry_scrub_test.dart \
  test/services/sentry_breadcrumbs_pii_test.dart
```

Result:

```text
79 tests passed
```

```bash
cd services/backend && python3 -m pytest \
  tests/test_privacy.py \
  tests/integration/test_privacy_delete_real_count.py \
  tests/services/consent/test_consent_service.py \
  tests/privacy/test_save_fact_pii_redaction.py \
  tests/services/privacy/test_pii_scrubber.py \
  tests/test_sentry_scrub.py \
  tests/services/privacy/test_fact_key_allowlist.py \
  tests/services/consent/test_merkle_chain.py \
  -q
```

Result:

```text
145 passed, 1 skipped, 1 warning
```

## Limits

This does not close Row 24. Missing release-quality proof remains:

- live privacy center / delete-export journey;
- account delete/recovery and data export end-to-end proof;
- runtime proof that document consent and scan/OCR consent are enforced;
- production log/Sentry sampling audit showing no PII in real beta telemetry;
- legal sign-off for nLPD/LPD wording and processor disclosures.

## Decision

Row 24 is no longer `UNPROVEN` because there is current executable proof across
privacy UI, consent contracts, PII scrubbing, and backend deletion contracts.
It remains `PARTIAL` because the proof is test-level, not a complete
release/runtime/legal gate.
