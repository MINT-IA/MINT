# Phase 16: Couple Mode Dissymetrique - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

One partner uses MINT alone and gets couple-aware projections using estimates of their partner's situation. Private (partner data never leaves device), honest about uncertainty (degraded confidence), and actionable (5 questions to ask partner). Covers: partner data entry via conversation, SecureStorage persistence, gap-based question generation, couple projection wiring, privacy enforcement.

</domain>

<decisions>
## Implementation Decisions

### Partner Data Entry & Storage
- Coach-guided conversation — detects couple context and asks naturally: "Tu es en couple ? Ca change pas mal de choses." Stores via existing `CoachProfile.civilStatus`.
- Partner estimates entered one question at a time via coach conversation. New `save_partner_estimate` internal tool. Fields: estimatedSalary, estimatedAge, estimatedLpp, estimated3a, estimatedCanton.
- Flutter-only `PartnerEstimateService` using SecureStorage — NEVER sent to backend, NEVER in CoachContext. Coach sees only "partner_declared: true, partner_confidence: 0.35" (aggregate, not data).
- Fixed confidence multiplier: estimated data gets `source: estimated (0.25)` in EnhancedConfidence. Explicit "basee sur vos estimations" disclaimer on couple projections.

### 5 Questions to Ask & Couple Projections
- Template-based gap questions: if field is null, generate corresponding question. 5 templates: salary assure LPP, avoir LPP, 3a capital, age exact, canton fiscal. Prioritized by projection impact.
- Questions presented as coach message with numbered list. Tapping an item opens a quick-entry field.
- Couple projections use existing `financial_core` calculators: `AvsCalculator.computeCouple()`, `TaxCalculator` with couple parameters. Pass partner estimates alongside user data.
- Updates via conversation: "En fait il gagne 80k pas 70k" → `update_partner_estimate`. No sync mechanism.

### Claude's Discretion
- PartnerEstimateService implementation details
- Quick-entry field widget design
- Question prioritization algorithm

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/mobile/lib/services/financial_core/avs_calculator.dart` — `computeCouple()` already handles married cap
- `apps/mobile/lib/services/financial_core/tax_calculator.dart` — couple tax parameters
- `apps/mobile/lib/services/financial_core/confidence_scorer.dart` — EnhancedConfidence with source multipliers
- `apps/mobile/lib/models/coach_profile.dart` — `ConjointProfile` sub-model already exists
- `services/backend/app/services/coach/coach_tools.py` — internal tool patterns from Phase 14-15

### Integration Points
- `save_partner_estimate` internal tool in coach_tools.py (backend acknowledges, Flutter persists)
- PartnerEstimateService in Flutter SecureStorage
- CoachContext: only aggregate partner_declared + partner_confidence (never actual data)
- financial_core calculators: pass partner estimates for couple projections

</code_context>

<specifics>
## Specific Ideas

- Coach prompt: "Tu es en couple ? Ca change pas mal de choses pour les projections."
- Question template: "Demande-lui son salaire assure LPP — ca impacte directement la rente de couple."
- Privacy: "Les donnees de ton/ta conjoint·e restent uniquement sur ton telephone."
- Disclaimer: "Projections basees sur vos estimations — precisez pour affiner."

</specifics>

<deferred>
## Deferred Ideas

- Bidirectional couple mode (both partners on MINT) — explicitly out of scope
- Partner data backup to cloud — deferred
- Couple-specific earmark tracking — Phase 15 handles earmarks generically

</deferred>
