# Source of Truth (SOT) — MINT

> **LAST SYNCED**: 2026-07-13 | Production: v0.1.0

## 1. Domain Object: Profile

### 1a. Backend Profile (`services/backend/app/schemas/profile.py`)

The backend `Profile` schema is the authoritative contract for API communication.

- `id`: UUID.
- `birthYear`: int (optional).
- `canton`: string (optional, ISO).
- `householdType`: enum (`single`, `couple`, `concubine`, `family`).
- `incomeNetMonthly`: double (optional, FactFind).
- `incomeGrossYearly`: double (optional, FactFind).
- `savingsMonthly`: double (optional, FactFind).
- `totalSavings`: double (optional, FactFind).
- `lppInsuredSalary`: double (optional, FactFind).
- `hasDebt`: boolean (default false).
- `goal`: enum (house, retire, emergency, invest, optimize_taxes, other).
- `factfindCompletionIndex`: double (0.0 to 1.0).
- `employmentStatus`: string (optional).
- `has2ndPillar`: boolean (optional).
- `legalForm`: string (optional).
- `selfEmployedNetIncome`: double (optional).
- `hasVoluntaryLpp`: boolean (optional).
- `primaryActivity`: string (optional).
- `hasAvsGaps`: boolean (optional).
- `avsContributionYears`: int (optional).
- `spouseAvsContributionYears`: int (optional).
- `commune`: string (optional, NPA ou nom commune — pour multiplicateur fiscal précis).
- `isChurchMember`: boolean (default false, impôt ecclésiastique).
- `pillar3aAnnual`: double (optional, versement annuel 3a — pour déduction fiscale).
- `wealthEstimate`: double (optional, fortune nette estimée).

> **NOTE**: `archetype`, `retirementAge`, `relationshipStatus`, `dataSources`, `dataTimestamps`, and `conjointProfile` do NOT exist on the backend `Profile` schema. See §1b.

### 1b. Frontend CoachProfile (`apps/mobile/lib/models/coach_profile.dart`)

The Flutter-side `CoachProfile` is a richer model used for local state, projections, and prefill. It includes fields absent from the backend schema:

- `archetype`: **computed property** (getter) on `CoachProfile`, derived from `nationality`, `arrivalAge`, `employmentStatus`, `residencePermit`. Returns `FinancialArchetype` enum. NOT stored on the backend `Profile`.
- `targetRetirementAge`: int? (target retirement age, default 65 via `effectiveRetirementAge` getter). Named `targetRetirementAge` (not `retirementAge`).
- `etatCivil`: `CoachCivilStatus` enum (`celibataire`, `marie`, `divorce`, `veuf`, `concubinage`). This is the frontend civil status field — NOT named `relationshipStatus`.
- `conjoint`: `ConjointProfile?` (linked partner profile for couple projections). Frontend-only.
- `dataSources`: `Map<String, ProfileDataSource>` (per-field data source tracking, S46+). Frontend-only.
- `dataTimestamps`: `Map<String, DateTime>` (per-field last-updated timestamps, S47+). Frontend-only.

## 2. Domain Object: SessionReport (SoA Compliant)
The central technical deliverable of a Session.
- `id`: UUID.
- `sessionId`: UUID.
- `precisionScore`: double (0.0 to 1.0 - reflects FactFind depth).
- `title`: String.
- `overview`:
  - `canton`: string.
  - `householdType`: string.
  - `goalRecommendedLabel`: string.
- `mintRoadmap`:
  - `mentorshipLevel`: string.
  - `natureOfService`: string (Coaching / Éducatif).
  - `limitations`: string[].
  - `assumptions`: string[].
  - `conflictsOfInterest`: { `partner`: string, `type`: string, `disclosure`: string } [].
- `scoreboard`: List (4 to 6 items).
- `recommendedGoalTemplate`: GoalTemplate.
- `alternativeGoalTemplates`: List<GoalTemplate> (max 2).
- `topActions`: List (EXACTLY 3 items).
- `recommendations`: List<Recommendation>.
- `disclaimers`: List (min 3).
- `generatedAt`: DateTime.

> **NOT YET IMPLEMENTED** on SessionReport (planned, documented in SOT but absent from code):
> - `confidenceScore`: EnhancedConfidence — not on `SessionReport` model. `EnhancedConfidence` exists as a standalone object in `financial_core/confidence_scorer.dart`.
> - `chiffreChoc`: per-session impactful number — not on `SessionReport`.
> - `alertes`: threshold-crossing warnings — not on `SessionReport`.
> - `simulationAssumptions`: Map<String, dynamic> — not on `SessionReport`.
> - `generatedLetters`: audit trail of generated templates — not on `SessionReport`.

## 3. Domain Object: EnhancedConfidence (S46+)
4-axis confidence scoring — geometric mean of all axes.
Source: `apps/mobile/lib/services/financial_core/confidence_scorer.dart`
- `completeness`: double (0-100) — how much data is present in the profile.
- `accuracy`: double (0-100) — quality of data sources (weighted by ProfileDataSource).
- `freshness`: double (0-100) — how recent the data is (decay: 1.0 at <6mo, ~0.5 at 24mo, floor 0.3 at 36mo+).
- `understanding`: double (0-100) — financial literacy engagement level (beginner/intermediate/advanced + coach session bonus).
- `combined`: double (0-100) — geometric mean of 4 axes.
- `level`: string ('low' | 'medium' | 'high').
- `baseResult`: ProjectionConfidence (backward compat with V2 consumers).
- `axisPrompts`: List<EnrichmentPrompt> — axis-specific actions to improve score.

> **NOTE**: A separate `ConfidenceBreakdown` class in `enhanced_confidence_service.dart` uses a weighted `overall` property (40/35/25 weighting) instead of the geometric `combined`. These are distinct objects.

## 4. Enum: ProfileDataSource
> Must match `coach_profile.dart` enum exactly.

| Source | Weight | Description |
|--------|--------|-------------|
| `estimated` | 0.25 | Default/system-estimated values |
| `userInput` | 0.60 | User-entered, not validated |
| `crossValidated` | 0.70 | User-entered, cross-checked against other data |
| `certificate` | 0.95 | Extracted from official document (LPP cert, tax declaration) |
| `openBanking` | 1.00 | Live data from bLink/Open Banking |

## 5. Compliance & Governance Invariants
- **Transparency by Default**: Every recommendation linked to a partner MUST have a `conflictsOfInterest` entry in the SoA.
- **Alternatives**: Partnered recommendations MUST provide at least 1 non-partner alternative.
- **Safe Mode**: Users with a "Debt" flag in profile MUST receive at least 1 recommendation regarding debt prevention/restructuring.
- **Precision Warning**: If `precisionScore < 0.5`, the report MUST display a "Low Precision" warning banner.
- **Confidence Gate**: If `EnhancedConfidence.combined < 50`, FRI display is gated. If < 70, uncertainty bands are mandatory on all projections.
- **Source Tracking**: Every profile field MUST track its `ProfileDataSource` and `dataTimestamp` for freshness decay (frontend `CoachProfile` only — not on backend `Profile`).

## 6. Official AVS pension extraction candidate (G1)

- Canonical document type: `avs_official_pension` (distinct from the CI-only
  `avs_extract`).
- Canonical candidate field: `avs_official_monthly_pension`.
- Backend entry point: `POST /api/v1/document-parser/parse` with
  `documentType=avs_official_pension`.
- Kill switch: `AVS_OFFICIAL_PENSION_INGESTION_ENABLED`, fail-closed and
  `false` by default.
- An accepted field carries `source=certificate`, the authority's
  `sourceDate`, `needsReview=true`, and a distinct epistemic `evidenceKind`:
  `official_decision`, `official_forecast`, or `official_statement`. Provenance
  never upgrades a forecast into a known pension fact; only a reviewed
  `official_decision` or `official_statement` may later become known.
- A rejected candidate carries no field and a stable `rejectionReason`.
- The endpoint is stateless and candidate-only. It never writes
  `ProfileModel.data` or `DocumentModel` before review. The legacy
  `/documents/scan-confirmation` writer and `/documents/extract-vision` path
  reject this document type; Vision remains blocked pending its separate image
  privacy review.
- There is no mobile consumer or write-back yet. The flag stays off until that
  review path and its strict-secure atomic ledger envelope have runtime proof.

## 7. AVS retirement estimator cash-flow contract (G1)

- `POST /api/v1/retirement/avs/estimate` returns an ordinary recurring pension:
  `renteMensuelle` is one ordinary monthly payment and `renteAnnuelle` is
  exactly twelve ordinary payments.
- `totalCumule`, anticipation/deferral shock figures and breakeven comparisons
  use those twelve ordinary payments only.
- The separate annual AVS supplement paid in December is not emitted or folded
  into these fields. Computing it requires owner-scoped monthly old-age-pension
  evidence and resolved December entitlement; a generic `monthly * 13` or
  `annual * 13 / 12` proxy is forbidden.
- `/api/v1/overview/me` never derives `avsRenteMensuelle` or
  `avsRenteAnnuelle` from `avsContributionYears`: contribution history is not a
  pension amount, and the estimator's missing salary proxy would otherwise
  fabricate the maximum pension. Missing history stays missing and an explicit
  zero remains a valid contribution-history fact, but neither authorizes a
  pension output.
- `isCouple`/`householdType=couple` is civil context, not partner evidence. The
  simplified estimator leaves `renteCoupleMensuelle` null and overview exposes
  no household AVS total until both owner-scoped pensions, entitlement,
  splitting and applicable cap inputs are available.

## 8. Minimal onboarding certified-null AVS boundary (G1)

- `POST /api/v1/onboarding/minimal-profile` has no input for the strict-secure,
  reviewed, owner-scoped official AVS pension envelope described in §6.
- `projectedAvsMonthly`, `estimatedMonthlyRetirement`,
  `estimatedReplacementRatio`, and `retirementGapMonthly` are required nullable
  response fields and are emitted as JSON `null` today. Age, salary, canton,
  civil-status declarations, nationality and arrival hints cannot unlock them.
- Standalone illustrative LPP capital/monthly figures, tax, liquidity and debt
  outputs remain available; none may be relabelled as a complete retirement
  total or converted into a zero AVS pension.
- `POST /api/v1/onboarding/premier-eclairage` does not emit the legacy
  `retirement_gap` or `retirement_income` categories. Its selector ignores
  manually populated legacy AVS-dependent doubles and chooses an independently
  supported liquidity, tax, compound-growth or hourly-rate insight instead.
- Reactivation requires a future typed provenance contract plus reviewed
  ingestion/write-back. A non-null legacy double alone is never sufficient.
