# Phase 6: QA Profond - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

All v2.0 capabilities validated across 9 personas, hostile scenarios, accessibility standards, and multilingual accuracy before release. This is the release gate — no feature ships without passing Phase 6.

Requirements: QA-01, QA-02, QA-03, QA-04, QA-05, QA-06, QA-07, QA-08, QA-09, QA-10, COMP-01, COMP-05

</domain>

<decisions>
## Implementation Decisions

### 9 Persona Tests
- 9 personas (Léa, Marc, Sophie, Thomas, Anna, Pierre, Julia, Laurent, Nadia) — each completes golden path integration test — per QA-01
- Each persona includes ≥1 error recovery scenario (blurry doc, wrong income, FATCA missing, etc.) — per QA-02
- Personas cover all 8 archetypes (swiss_native, expat_eu, expat_non_eu, expat_us, independent_with_lpp, independent_no_lpp, cross_border, returning_swiss)

### Visual Testing
- Golden Screenshots: pixel diff >1.5% = red in CI, 2 phone sizes × FR + 1 DE golden per phase — per QA-03
- Patrol integration tests: real navigation on emulator (iOS 17 iPhone 15 + Android API 34 Pixel 7) — per QA-04, QA-05

### Compliance & Language
- ComplianceGuard 100% coverage on ALL new output channels (alerts, narrative refs, coach openers, extraction insights) — per QA-06, COMP-01
- Zero banned terms, zero PII in system prompt, confidence score >0
- DE + IT financial terminology accuracy ≥85% in coach responses — per QA-07
- All user-facing strings in 6 ARB files — zero hardcoded strings — per COMP-05

### Accessibility
- WCAG 2.1 AA on all new screens — per QA-08
- VoiceOver + TalkBack testing
- Contrast ≥4.5:1, tap targets ≥44pt, font scaling 200%

### Document Factory
- SVG templates with persona-specific values, exportable as PDF — per QA-09

### Cross-Cutting
- Every phase includes ComplianceGuard validation, flutter analyze 0 errors, flutter test + pytest pass — per QA-10

### Claude's Discretion
- Specific persona profiles (age, canton, salary, archetype, life events)
- Golden screenshot baseline capture methodology
- Patrol test orchestration and CI integration details
- Document Factory SVG template design
- Accessibility audit tooling choices

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/journeys/lea_golden_path_test.dart` — Phase 1 integration test (template for 8 more personas)
- `services/backend/tests/test_compliance_guard.py` — existing compliance tests
- All Phase 1-5 test suites (regression baseline)
- `test/golden/` — existing golden test data (Julien + Lauren)

### Integration Points
- CI: `.github/workflows/ci.yml` — add golden screenshot + Patrol steps
- All new screens from Phase 1-5 need accessibility audit
- ComplianceGuard: verify all new output channels are gated

</code_context>

<specifics>
## Specific Ideas

- QA-01: 9 personas should cover the full archetype + life event matrix
- QA-03: Golden screenshots are REGRESSION tests, not visual design approval
- QA-09: Document Factory enables deterministic testing without real user documents
- COMP-01: New output channels = alerts (Phase 4), narrative refs (Phase 3), coach openers (Phase 5), extraction insights (Phase 2)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
