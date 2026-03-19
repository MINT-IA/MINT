# Definition of Done — Mint

A feature or PR is considered "Done" if:

- **Quality & Standards**:
  - Backend: `ruff check .` passes.
  - Mobile: `flutter analyze` passes.
  - Code follows project standards (linting, modular structure).

- **Verification & Tests**:
  - Backend: `pytest -q` passes.
  - Mobile: `flutter test` passes.
  - Financial calculations are covered by unit tests.

- **Documentation & Contracts**:
  - Vision documents updated (if applicable).
  - `mint.openapi.yaml` + `SOT.md` updated and perfectly synchronized.

- **Compliance & Security**:
  - **LEGAL_RELEASE_CHECK.md must pass.**
  - No secrets committed.
  - No sensitive logs (financial data, private IDs).
  - Read-Only MVP respect confirmed.

- **Completion**:
  - Walkthrough.md updated with proof of work (screenshots/recordings).
  - ADR created if major structural decisions were made.

---

## Additional DoD — Coach Vivant Sprints (S30.5+)

- **Financial Core Integrity** (S30.5+):
  - Zero private `_calculate*` methods for financial logic outside `financial_core/`.
  - All CLAUDE.md constants verified identical in backend AND Flutter.
  - Parity check on 10 representative profiles (backend vs Flutter ±1 CHF).

- **Arbitrage Modules** (S32-S33):
  - No ranking of options in any user-facing text.
  - Hypotheses visible and editable on every comparison screen.
  - Sensitivity analysis included.
  - Min 15 backend tests per arbitrage module.

- **Compliance Guard** (S34 — BLOCKER):
  - 25+ adversarial tests passing.
  - 100% of CLAUDE.md banned terms caught.
  - Hallucination detector catches fabricated numbers (< 5% false negatives).
  - Fallback templates valid for every component.

- **Coach Layer** (S35+):
  - App functions identically without BYOK (enhanced fallback templates).
  - Every LLM call passes through ComplianceGuard.
  - Cache invalidation by event, not TTL.
  - CoachContext never includes raw financial amounts (except tax saving potential).

- **FRI** (S38-S39):
  - Only displayed when confidenceScore >= 50%.
  - Always shows breakdown (never total alone).
  - Never uses "faible", "mauvais", or social comparison.

- **Data Acquisition** (S41+):
  - Original images deleted after OCR.
  - Extracted values require user confirmation.
  - Source quality tracked per field.

- **Navigation & i18n** (S49+):
  - All new screens registered in GoRouter (no `Navigator.push`).
  - Screens accessible via 3-tab navigation (Pulse, Mint, Moi).
  - All user-facing strings use `S.of(context)!.key` (6 ARB files).
  - Response Card integration for coach tab on simulators.

- **Enhanced Confidence** (S46+):
  - All projections use `EnhancedConfidence` (4-axis: completeness × accuracy × freshness × understanding).
  - Uncertainty bands mandatory when `combined < 70`.
  - FRI display gated at `combined >= 50`.
  - `ProfileDataSource` and `dataTimestamp` tracked per field.

- **Autoresearch Sprint Execution** (S51+):
  - Sprint deliverables validated by relevant autoresearch skills before merge.
  - Financial calculations: `/autoresearch-calculator-forge` green.
  - Compliance: `/autoresearch-compliance-hardener` green (100% pass rate).
  - Test coverage: `/autoresearch-test-generation` run on new services (min 10 tests).
  - UX: `/autoresearch-ux-polish` run on new screens (0 violations).
  - i18n: `/autoresearch-i18n` confirms 0 hardcoded strings in new files.
