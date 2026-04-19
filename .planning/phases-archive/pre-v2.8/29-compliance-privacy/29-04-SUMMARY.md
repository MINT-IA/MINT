---
phase: 29-compliance-privacy
plan: 04
subsystem: backend+mobile
tags: [compliance, privacy, vision, llm-as-judge, prompt-injection, lsfin, priv-05, priv-08]
dependency_graph:
  requires: [29-01, 29-03, 28-01, 28-04]
  provides:
    - VisionGuard (Claude Haiku 4.5 LLM-as-judge) on summary/narrative/premier_eclairage
    - NumericSanity deterministic bounds (rendement/salaire/taux_conversion reject, avoir_lpp human_review)
    - FieldStatus enum (needs_review default, no auto-confirm) + runtime invariant
    - BatchValidationBubble + FieldCorrectionSheet (anti-fatigue per-batch validation)
    - RenderModeHandler.routeConfirm (batch vs review routing)
    - 7 adversarial PDF fixtures in tests/fixtures/documents
  affects:
    - Phase 29-05 (third-party declaration) — can reuse VisionGuard flagged categories
    - Phase 29-06 (Bedrock EU) — HAIKU_MODEL pin tripwire forces conscious update
    - Phase 28-04 (DocumentResultView) — confirm-mode now routable through BatchValidationBubble
tech_stack:
  added:
    - claude-haiku-4-5-20251022 (LLM-as-judge)
  patterns:
    - LLM-as-judge layered after deterministic sanity (cheap-before-expensive)
    - fail-closed on judge API error (Sentry warn, canonical safe fallback)
    - PII pre-scrub (Phase 29-03 pii_scrubber) BEFORE judge sees text
    - env-var hard bypass (VISION_GUARD_ENABLED=false) — emergency only, logged
    - model-id pin tripwire (test_haiku_model_pinned forces conscious update)
    - runtime invariant guard (no auto-confirm loops in document_vision_service)
key_files:
  created:
    - services/backend/app/services/compliance/__init__.py
    - services/backend/app/services/compliance/vision_guard.py
    - services/backend/app/services/compliance/numeric_sanity.py
    - services/backend/alembic/versions/29_04_drop_auto_confirmed.py
    - services/backend/scripts/generate_adversarial_fixtures.py
    - services/backend/tests/services/compliance/test_vision_guard.py
    - services/backend/tests/services/compliance/test_numeric_sanity.py
    - services/backend/tests/services/compliance/test_adversarial_pdfs.py
    - services/backend/tests/fixtures/documents/prompt_injection_white_on_white.pdf
    - services/backend/tests/fixtures/documents/prompt_injection_metadata.pdf
    - services/backend/tests/fixtures/documents/prompt_injection_svg_overlay.pdf
    - services/backend/tests/fixtures/documents/sanity_rendement_15pct.pdf
    - services/backend/tests/fixtures/documents/sanity_avoir_lpp_7M.pdf
    - services/backend/tests/fixtures/documents/sanity_salaire_3M.pdf
    - services/backend/tests/fixtures/documents/sanity_taux_conv_8pct.pdf
    - apps/mobile/lib/widgets/document/batch_validation_bubble.dart
    - apps/mobile/lib/widgets/document/field_correction_sheet.dart
    - apps/mobile/lib/services/document/render_mode_handler.dart
    - apps/mobile/test/widgets/document/batch_validation_bubble_test.dart
  modified:
    - services/backend/app/schemas/document_understanding.py (FieldStatus enum, status+humanReviewFlag on ExtractedField, guard/sanity telemetry on DUR)
    - services/backend/app/services/document_vision_service.py (NumericSanity step 5a, PII pre-scrub step 8a, VisionGuard step 8c, runtime no-auto-confirm invariant step 8d)
    - apps/mobile/lib/services/document_understanding_result.dart (FieldStatus enum + copyWith on ExtractedField)
    - apps/mobile/lib/l10n/app_fr.arb + 5 siblings (10 new keys + humanReviewBadge)
decisions:
  - LLM-as-judge with fail-closed default — accept +800ms latency on 3 critical Vision outputs, small talk bypasses (budget-preserving)
  - Numeric sanity runs BEFORE judge — cheap deterministic gate catches crudest prompt-injection ('rendement 50%') without Haiku cost
  - avoir_lpp > 5M returns human_review (not reject) — rare-but-legal for ultra-HNW; persists with flag instead of blocking
  - Migration 29_04 is SOFT — rewrites JSON payloads in document_memory rather than risky enum DROP; Python enum removes symbol, runtime guard enforces in code
  - PII pre-scrub (Phase 29-03 pii_scrubber) runs BEFORE judge — judge never sees raw IBAN/AVS/employer in transit to Haiku
  - Judge reformulation runs through coach ComplianceGuard Layer 1 — defense-in-depth against the judge itself emitting banned terms
  - BatchValidationBubble forces status=needs_review on its own inputs — defense against caller accidentally pre-confirming (PRIV-08 invariant upheld even in buggy consumers)
  - Adversarial fixtures generated reproducibly via pymupdf script — content stable, bytes not (timestamps); CI asserts content not hash
  - HAIKU_MODEL="claude-haiku-4-5-20251022" pinned with test tripwire — Anthropic retirement forces conscious cost+behaviour re-validation
metrics:
  duration_minutes: 18
  completed_date: 2026-04-14
  task_count: 2
  file_count: 23
  tests_added: 42
---

# Phase 29 Plan 04: ComplianceGuard Vision + Auto-Confirmed Removal Summary

LLM-as-judge (Claude Haiku 4.5) gates Vision summary/narrative + deterministic numeric sanity bounds reject impossible values + every ExtractedField persists as needs_review regardless of pipeline confidence + 7 adversarial PDF fixtures prove prompt-injection payloads never leak to the final narrative and numeric-sanity violators force render_mode=reject.

## What Was Built

### Backend

- **`services/compliance/vision_guard.py`** — `judge_vision_output(summary, narrative, fields_summary)` calls Claude Haiku 4.5 via tool-forced JSON schema. Detects 5 categories: `product_advice`, `return_promise`, `third_party_specific`, `banned_term`, `prescriptive_language`. Returns `GuardVerdict` with `allow`, `flagged_categories`, `reformulation`, `reason`, `cost_usd`. Fail-closed on API error / missing key / no tool_use block. Env-var bypass `VISION_GUARD_ENABLED=false` (logged as warning).
- **`services/compliance/numeric_sanity.py`** — `check(fields) -> SanityVerdict`. Bounds: `rendement > 8%` reject, `salaire > 2M` reject, `taux_conversion > 7%` reject, `avoir_lpp > 5M` human_review. Swiss thousands-separator aware. Duck-typed over ExtractedField shape (works on both v1 and v2 schemas).
- **`schemas/document_understanding.py`** — `FieldStatus` enum (`needs_review` default, `user_validated`, `corrected_by_user`, `rejected`, `human_review`). ExtractedField gains `status` + `human_review_flag`. DUR gains `guard_*` and `sanity_*` telemetry fields.
- **`document_vision_service.understand_document`** — new pipeline steps: (5a) NumericSanity, (8a) PII pre-scrub reusing Phase 29-03, (8c) VisionGuard judge with safe-fallback swap, (8d) runtime no-auto-confirm invariant resets any non-terminal status back to needs_review.
- **Migration `29_04_drop_auto_confirmed.py`** — soft-transitions legacy `"status": "confirmed"` in `document_memory.field_history` JSON to `"needs_review"`. No enum drop at DB layer (Postgres risky).

### Mobile

- **`BatchValidationBubble`** — chat-inline Dismissible: swipe-right confirms all fields (→ userValidated), swipe-left rejects all (→ rejected), tap-row opens per-field correction. Defense: resets caller-supplied statuses to needs_review on render.
- **`FieldCorrectionSheet`** — modal sheet with Swiss thousands-separator parsing; save emits `corrected_by_user`.
- **`RenderModeHandler.routeConfirm`** — <=5 fields AND no human_review → BatchValidationBubble; else ExtractionReviewSheet.
- **ExtractedField** Dart model mirrors backend FieldStatus + `copyWith`.
- **10 i18n keys × 6 langs** — `batchValidationTitle/ConfirmAll/CorrectOne/RejectAll`, `fieldCorrectionTitle/Save/Cancel`, `renderModeRejectBannerSanity/Guard`, `humanReviewBadge`. NBSP before `?` per CLAUDE.md §6.

### Adversarial Suite

- **5 prompt-injection + numeric-sanity fixtures** + 2 extra sanity PDFs generated reproducibly by `scripts/generate_adversarial_fixtures.py`:
    - `prompt_injection_white_on_white.pdf` — white text injection, legitimate LPP content in foreground.
    - `prompt_injection_metadata.pdf` — injection in XMP Keywords/Subject.
    - `prompt_injection_svg_overlay.pdf` — near-transparent overlay with injection.
    - `sanity_rendement_15pct.pdf`, `sanity_salaire_3M.pdf`, `sanity_taux_conv_8pct.pdf` — reject.
    - `sanity_avoir_lpp_7M.pdf` — human_review.

### Tests

- `test_numeric_sanity.py` — 14 cases (boundaries, Swiss separator, batch, non-numeric passthrough).
- `test_vision_guard.py` — 13 cases (5 violation categories, fail-closed, env bypass, reformulation scrub, model pin, cost telemetry, empty bundle).
- `test_adversarial_pdfs.py` — 7 end-to-end cases with Vision mocked + judge mocked (prompt-injection payload never leaks, 3 numeric fixtures force reject, 7M flags human_review).
- `batch_validation_bubble_test.dart` — 8 widget tests (render, confirm all, correct one, row tap, save correction, reject all, PRIV-08 pre-confirm reset, human-review badge).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Dismissible key duplication broke first widget test**
- Found during: Task 2 widget test
- Issue: `Dismissible.key=ValueKey('batchValidationBubble')` collided with the Container key of the same name — test found 2 matches instead of 1.
- Fix: renamed Dismissible to `batchValidationDismissible`; Container kept `batchValidationBubble`.
- Files: `apps/mobile/lib/widgets/document/batch_validation_bubble.dart`.
- Commit: `f8aae684`.

**2. [Rule 3 - Blocker] `withOpacity` deprecated in Flutter 3.32+**
- Found during: `flutter analyze`.
- Fix: swap to `withValues(alpha:)` on the 2 sites.
- Commit: `f8aae684`.

**3. [Rule 2 - Missing critical functionality] PII pre-scrub before judge**
- Plan specified judge on summary/narrative/premier_eclairage but did not explicitly require PII scrub before the Haiku call. Adding it satisfies the threat model (T-29-18 mitigation path: judge never sees raw IBAN/AVS/employer).
- Files: `document_vision_service.py` step 8a.
- Commit: `a83539af`.

**4. [Rule 1 - Bug] Ran render_mode selector after sanity force-reject**
- Without the guard, a sanity reject on a 0.92-confidence document would be overwritten back to `confirm` by the deterministic selector.
- Fix: only run selector when `render_mode != reject`.
- Commit: `a83539af`.

### Scope-boundary notes

- Plan referenced `services/backend/app/api/v1/endpoints/document_upload.py` — that file does not exist in this repo; the fused path lives in `documents.py::/extract-vision`. Wiring already happens at the service layer so no endpoint changes were required.
- Plan referenced `app/services/compliance_guard.py` at top-level — this file also does not exist at the top level (coach version is at `app/services/coach/compliance_guard.py`). Our new package `app/services/compliance/` is distinct and does not conflict.

## Self-Check: PASSED

- [x] `services/backend/app/services/compliance/vision_guard.py` exists.
- [x] `services/backend/app/services/compliance/numeric_sanity.py` exists.
- [x] `services/backend/alembic/versions/29_04_drop_auto_confirmed.py` exists.
- [x] 7 adversarial PDFs in `services/backend/tests/fixtures/documents/`.
- [x] `apps/mobile/lib/widgets/document/batch_validation_bubble.dart` exists.
- [x] `apps/mobile/lib/widgets/document/field_correction_sheet.dart` exists.
- [x] `apps/mobile/lib/services/document/render_mode_handler.dart` exists.
- [x] Commit `a83539af` (Task 1) present on dev.
- [x] Commit `f8aae684` (Task 2) present on dev.
- [x] Backend tests: 27 compliance + 7 adversarial = 34 passing, plus 123 existing documents tests still green.
- [x] Flutter: 8 new widget tests green, 0 analyzer issues on new files.

## Known Stubs

None. Every surface wired end-to-end: VisionGuard is invoked in `understand_document`, NumericSanity dispositions flow to DUR and UI badges, BatchValidationBubble is routable via RenderModeHandler, adversarial fixtures are in CI via `tests/services/compliance/test_adversarial_pdfs.py`.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: cost_surface | `app/services/compliance/vision_guard.py` | Every upload now triggers a secondary Haiku call (~$0.0003). Budget model needs Phase 30 re-baseline before wide rollout. Telemetry field `guard_cost_usd` already populated for analytics. |
