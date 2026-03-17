# Source of Truth (SOT) — MINT

> Last updated: 2026-03-17 | Production: v0.1.0

## 1. Domain Object: Profile
- `id`: UUID.
- `birthYear`: int.
- `canton`: string (ISO).
- `householdType`: enum (single, couple_married, couple_concubinage, single_parent).
- `incomeNetMonthly`: double (FactFind).
- `incomeGrossYearly`: double (FactFind).
- `savingsMonthly`: double (FactFind).
- `totalSavings`: double (FactFind).
- `lppInsuredSalary`: double (FactFind).
- `hasDebt`: boolean.
- `factfindCompletionIndex`: double (0.0 to 1.0).
- `commune`: string (NPA ou nom commune — pour multiplicateur fiscal précis ; chef-lieu par défaut).
- `isChurchMember`: boolean (impôt ecclésiastique — optionnel, default false).
- `pillar3aAnnual`: double (versement annuel 3a — pour déduction fiscale).
- `archetype`: enum (swiss_native, expat_eu, expat_non_eu, expat_us, independent_with_lpp, independent_no_lpp, cross_border, returning_swiss).
- `retirementAge`: int (target retirement age, default 65).
- `relationshipStatus`: enum (single, married, concubinage, divorced, widowed).
- `conjointProfile`: Profile? (linked partner profile for couple projections).
- `dataSources`: Map<String, ProfileDataSource> (per-field data source tracking, S46+).
- `dataTimestamps`: Map<String, DateTime> (per-field last-updated timestamps, S47+).

## 2. Domain Object: SessionReport (SoA Compliant)
The central technical deliverable of a Session.
- `id`: UUID.
- `sessionId`: UUID.
- `precisionScore`: double (0.0 to 1.0 - reflects FactFind depth).
- `confidenceScore`: EnhancedConfidence (mandatory on all projections, S46+).
- `title`: String.
- `overview`:
  - `canton`: string.
  - `householdType`: string.
  - `recommendedGoalLabel`: string.
- `statementOfAdvice`:
  - `natureOfService`: string (Mentorship / Informational).
  - `limitations`: string[].
  - `assumptions`: string[].
  - `conflictsOfInterest`: { `partner`: string, `type`: string, `disclosure`: string } [].
- `simulationAssumptions`: Map<String, dynamic> (e.g. `{'growthRate': 0.04, 'marginalTaxRate': '20-22%'}`).
- `chiffreChoc`: { `value`: double, `label`: string, `context`: string } (one impactful number per session).
- `alertes`: List<{ `type`: string, `message`: string, `severity`: string }> (threshold-crossing warnings).
- `generatedLetters`: List<{ `type`: string, `date`: DateTime }> (Audit trail of generated templates).
- `scoreboard`: List (4 to 6 items).
- `topActions`: List (EXACTLY 3 items) with `effortTag` and `ifThen`.
- `recommendations`: List<Recommendation>.
- `disclaimers`: List.
- `generatedAt`: DateTime.

## 3. Domain Object: EnhancedConfidence (S46+)
4-axis confidence scoring — geometric mean of all axes.
- `completeness`: double (0-100) — how much data is present in the profile.
- `accuracy`: double (0-100) — quality of data sources (weighted by ProfileDataSource).
- `freshness`: double (0-100) — how recent the data is (decay: 1.0 at <6mo, ~0.5 at 24mo, floor 0.3 at 36mo+).
- `understanding`: double (0-100) — financial literacy engagement level (beginner/intermediate/advanced + coach session bonus).
- `combined`: double (0-100) — geometric mean of 4 axes.
- `level`: string ('low' | 'medium' | 'high').
- `axisPrompts`: List<EnrichmentPrompt> — axis-specific actions to improve score.

## 4. Enum: ProfileDataSource
| Source | Weight | Description |
|--------|--------|-------------|
| `systemEstimate` | 0.25 | Default/estimated values |
| `userEntry` | 0.50 | User-entered, not validated |
| `userEntryCrossValidated` | 0.70 | User-entered, cross-checked |
| `documentScan` | 0.85 | OCR-extracted from document |
| `documentScanVerified` | 0.95 | OCR-extracted + user-confirmed |
| `openBanking` | 1.00 | Live data from bLink/Open Banking |

## 5. Compliance & Governance Invariants
- **Transparency by Default**: Every recommendation linked to a partner MUST have a `conflictsOfInterest` entry in the SoA.
- **Alternatives**: Partnered recommendations MUST provide at least 1 non-partner alternative.
- **Safe Mode**: Users with a "Debt" flag in profile MUST receive at least 1 recommendation regarding debt prevention/restructuring.
- **Precision Warning**: If `precisionScore < 0.5`, the report MUST display a "Low Precision" warning banner.
- **Confidence Gate**: If `confidenceScore.combined < 50`, FRI display is gated. If < 70, uncertainty bands are mandatory on all projections.
- **Source Tracking**: Every profile field MUST track its `ProfileDataSource` and `dataTimestamp` for freshness decay.
