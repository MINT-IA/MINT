# Source of Truth (SOT) — MINT

## 1. Domain Object: Profile
- `id`: UUID.
- `birthYear`: int.
- `canton`: string (ISO).
- `householdType`: enum.
- `incomeNetMonthly`: double (FactFind).
- `incomeGrossYearly`: double (FactFind).
- `savingsMonthly`: double (FactFind).
- `totalSavings`: double (FactFind).
- `lppInsuredSalary`: double (FactFind).
- `hasDebt`: boolean.
- `factfindCompletionIndex`: double (0.0 to 1.0).

## 2. Domain Object: SessionReport (SoA Compliant)
The central technical deliverable of a Session.
- `id`: UUID.
- `sessionId`: UUID.
- `precisionScore`: double (0.0 to 1.0 - reflects FactFind depth).
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
- `generatedLetters`: List<{ `type`: string, `date`: DateTime }> (Audit trail of generated templates).
- `scoreboard`: List (4 to 6 items).
- `topActions`: List (EXACTLY 3 items) with `effortTag` and `ifThen`.
- `recommendations`: List<Recommendation>.
- `disclaimers`: List.
- `generatedAt`: DateTime.

## 3. Compliance & Governance Invariants
- **Transparency by Default**: Every recommendation linked to a partner MUST have a `conflictsOfInterest` entry in the SoA.
- **Alternatives**: Partnered recommendations MUST provide at least 1 non-partner alternative.
- **Safe Mode**: Users with a "Debt" flag in profile MUST receive at least 1 recommendation regarding debt prevention/restructuring.
- **Precision Warning**: If `precisionScore < 0.5`, the report MUST display a "Low Precision" warning banner.
