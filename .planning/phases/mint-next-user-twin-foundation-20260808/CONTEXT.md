# MINT Next — Canonical Lifelong User Twin Foundation

Status: `completed`

MINT must accumulate, maintain and return the user's financial situation across
life events. The immediate correction is deliberately narrow: stop extending
the housing questionnaire and connect its existing facts to the canonical local
profile lifecycle.

- Execution receipt: Bead `MINT_nosync-cnn`; accepted runtime candidate
  `538c52647e58394be16bc87c68e1e6e814a7613e`, evidence commit `b36667a69`.
- Product truth: `.planning/decisions/2026-08-08-lifelong-financial-twin-and-plans.md`.
- Canonical local path: `CoachProfileProvider.mergeAnswers` →
  `ReportPersistenceService` → `SecureWizardStore` / `wizard_answers_v2` →
  `CoachProfile.fromWizardAnswers`.
- `BiographyRepository`, the Design Lab store and direct backend `FactEvent`
  writes are forbidden as housing sources of truth.
- Remote sync is out of scope until a separate consent and conflict contract is
  accepted.
- No new housing question or financial result belongs in this phase.
