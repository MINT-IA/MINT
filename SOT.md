# Source of Truth (SOT) — MINT

> **LAST SYNCED**: 2026-06-13 | Production: v0.1.0

## 0. API Contract: Feature Flags

`GET /api/v1/config/feature-flags` is the backend-driven feature flag contract
consumed by Flutter `FeatureFlags.applyFromMap(...)`. It is intentionally
available before login because onboarding route selection happens before
account creation.

- `enableMvpWedgeOnboarding`: boolean, default `false`, env override
  `FF_ENABLE_MVP_WEDGE_ONBOARDING`. When `true`, mobile `/start` enters the
  diagnostic onboarding flow (`/onb`). When `false`, `/start` preserves the
  anonymous chat fallback.

## 1. Domain Object: Profile

### 1a. Backend Profile (`services/backend/app/schemas/profile.py`)

The backend `Profile` schema is the authoritative contract for API communication.

- `id`: string (UUID for normal profiles; legacy/anonymous rows may use string IDs).
- `birthYear`: int (optional).
- `dateOfBirth`: ISO date string (optional).
- `canton`: string (optional, ISO).
- `householdType`: enum (`single`, `couple`, `concubine`, `family`).
- `incomeNetMonthly`: double (optional, FactFind).
- `incomeGrossYearly`: double (optional, FactFind).
- `savingsMonthly`: double (optional, FactFind).
- `totalSavings`: double (optional, FactFind).
- `totalDebt`: double (optional, total debt balance; distinct from monthly debt payments).
- `lppInsuredSalary`: double (optional, FactFind).
- `avoirLpp`: double (optional).
- `lppBuybackMax`: double (optional).
- `pillar3aBalance`: double (optional).
- `hasDebt`: boolean (default false).
- `goal`: enum (house, retire, emergency, invest, optimize_taxes, other).
- `factfindCompletionIndex`: double (0.0 to 1.0).
- `gender`: string (optional).
- `employmentStatus`: string (optional).
- `has2ndPillar`: boolean (optional).
- `legalForm`: string (optional).
- `selfEmployedNetIncome`: double (optional).
- `hasVoluntaryLpp`: boolean (optional).
- `primaryActivity`: string (optional).
- `hasAvsGaps`: boolean (optional).
- `avsContributionYears`: int (optional).
- `spouseBirthYear`: int (optional; only valid for `couple`, `concubine`, or `family`).
- `spouseIncomeNetMonthly`: double (optional; only valid for `couple`, `concubine`, or `family`).
- `spouseAvsContributionYears`: int (optional; only valid for `couple`, `concubine`, or `family`).
- `commune`: string (optional, NPA ou nom commune — pour multiplicateur fiscal précis).
- `isChurchMember`: boolean (default false, impôt ecclésiastique).
- `pillar3aAnnual`: double (optional, versement annuel 3a — pour déduction fiscale).
- `wealthEstimate`: double (optional, fortune nette estimée).
- `nationality`: string (optional, ISO 3166-1 alpha-2).
- `usTaxPerson`: boolean (optional, tri-state FATCA self-declaration).
- `targetRetirementAge`: int (optional, 58 to 70).

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
