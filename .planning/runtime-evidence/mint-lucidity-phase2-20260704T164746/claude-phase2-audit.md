NO_UNRESOLVED_CRITICAL_HIGH

---

## Phase 2 External Acceptance Audit — Data Quest Case Registry

**Auditor perspective:** External. No prior context assumed.
**Evidence reviewed:** Gate script, implementation files, test outputs, Maestro logs, SCORECARD.md.

---

### Delta-only data acquisition — PASS

`DataQuestService.planCase()` correctly implements the staged early-return algorithm: guard → required → useful, surfacing only the current delta. The `_buildAsks()` logic handles three distinct states:

- **Missing** → `collect` mode
- **Stale** (`FreshnessDecayService.needsRefresh()` weight < 0.60) → `reconfirm` mode with prior value
- **Present + `requiresCompleteFact` + no dated fact** → `reconfirm` mode (aggregate fields like `parentAnnualLivingCosts`)

The `allowZero` semantics prevent false positives for fields where 0 is a valid answer (`avoirLpp`, `heirsCount`, etc.). The "known legacy answers without provenance are not false reconfirmed" test explicitly validates the intentional treatment of pre-Phase 4 answers.

**Runtime confirmation (iPhone 17 Pro, iOS 26.2):**
- Empty profile → asks `propertyMarketValue` in `collect` mode ✓
- Fresh property value seeded → advances to `targetRetirementAge` without re-asking ✓
- `MINT_TEST_PROPERTY_STALE=true` → property in `reconfirm` mode, not blank collect ✓

---

### Case registry completeness — PASS

All three P0 cases (`first_salary_tax`, `buy_property`, `transmit_property`) declare the complete required contract: `minimum_variables`, `useful_variables`, `blocking_guard_questions`, `required_questions`, `enrichment_questions`, `pdf_section_id`, `dossier_contract`, `maestro_flow_id`, `patrol_flow_id`, `runtime_input_gate`, `runtime_proof_kind`.

The JSON schema and the Dart `DataQuestCaseRegistry.p0Cases` const map are consistent. `test_p0_case_variable_registry.py` enforces cross-validation against `DATA_LEDGER.md` ledger keys for all `ledger`-role variables. `composed_input` variables (`parentAnnualRetirementIncome`, `parentAnnualLivingCosts`) correctly declare their composition formulas, ledger source keys, and mobile/backend contract paths — all verified as existing files.

The `stressInterestRate` assumption is properly backed by `regulatory/registry.py` (`key="mortgage.theoretical_rate"`) rather than a magic constant.

---

### Write-path discipline — PASS

The single write path is `CoachProfileProvider.mergeAnswers()` (via `fp:` field-path prefix) / `applySaveFact()`. The succession screen uses `fp:patrimoine.propertyMarketValue` which routes through `_answerKeyForFieldPath()` → stamps `dataTimestamps`, `dataSources`, `dataSourceDates` → persists via `ReportPersistenceService.saveAnswers()`. No shortcut writes bypass this path.

`DossierPayloadService.dataQuestFactsFromProfile()` correctly bridges profile provenance to `BiographyFact` objects for use in `DataQuestService.planCase()`. The alias table (`_dataQuestLedgerAliases`) handles camelCase → ledger path mappings without duplication.

`_profileOwnerIdFor()` throws `StateError` on `local_demo_pending` — dossier builds cannot proceed until a stable local owner ID exists. Tests cover this boundary.

---

### Runtime proof — PASS

Evidence in `.planning/runtime-evidence/mint-lucidity-phase2-20260704T164746/`:

| Proof artifact | Result |
|---|---|
| `gate-phase2-run.txt` | 107 Flutter tests + 23 Python tests, all green; Maestro syntax OK |
| `phase2-maestro.txt` | All COMPLETED on iPhone 17 Pro |
| `phase2-reconfirm-maestro.txt` | Stale reconfirm COMPLETED on iPhone 17 Pro |
| `SCORECARD.md` | 9.1/10, co-signed, `cli_exception_consumed: false` |

The `check_phase2_maestro_output_complete` function validates log patterns post-run. The gate script's `set -euo pipefail` discipline means the subsequent Mermaid compile and Flutter test output in the log confirms all prior checks (including the 40+ grep assertions in `check_phase2_data_quest_contract`) passed silently.

---

### Dossier/PDF hooks — PASS

Three JSON schemas in `docs/codex/dossier_stubs/` with `x-mint-owner`, `x-mint-case-id`, `x-mint-pdf-section-id`, and `case_id`/`pdf_section_id` const constraints. `DossierPayloadService.buildP0Case()` produces schema-validated payloads for all three cases. `DossierPayloadSchemaValidator.validateJsonAgainstSchema()` is called in both dossier service tests and `report_route_screen_test.dart`.

PDF generation is verified end-to-end: `PdfService.buildDossierPayloadPdfBytes()` returns bytes starting with `%PDF-` and ending with `%%EOF`. The `_buildP0Dossiers()` guard on `local_demo_pending` correctly defers dossier builds until owner resolution.

`FinancialReportScreenV2` wires stable Semantics identifiers (`report_dossier_${caseId}_card`, `report_dossier_${caseId}_export_cta`) — confirmed by widget tests and the `check_report_maestro_contract` gate.

---

### Facade risk — LOW

`case_registry.dart` is a pure re-export shim with no state. `DataQuestCaseRegistry.p0Cases` is a compile-time `const` map — no runtime mutation possible.

The dual-widget pattern (`DataQuestNextQuestionCard` for human display, `DataQuestProofStrip` for machine-readable proof semantics) is intentional and consistent across succession, mortgage, and 3a screens. The gate enforces both are present in each screen.

---

### Findings

**MEDIUM — `reg()` fallback warnings in live test output:**
`gate-phase2-run.txt` logs `reg() FALLBACK: pillar3a.max_with_lpp → 7258.0` and similar lines for 7 constants. Tests assert against these fallback values directly (e.g., `expect(annual_ceiling, 7258)`). The `uses synced mortgage stress rate` test does cover the synced path, but other tests silently accept fallback values. If the registry sync fails in production, users see values derived from hardcoded constants that are not explicitly versioned. Recommend adding an explicit test that the fallback values match the current Swiss regulatory constants, and logging them as `WARNING` level (not just `FALLBACK`).

**MEDIUM — Living cost composition produces `partial_composition` status in nominal Raiffeisen fixture:**
The Raiffeisen-style test case produces `living_costs_context.status: partial_composition` even when housing (`6600/mo`) and LaMal (`400/mo`) are provided, because `q_pay_frequency: monthly` is present but other components (`electricite`, `transport`, etc.) are absent. The dossier payload surfaces `confidence: low` for this input. This is correct per spec, but the Raiffeisen fixture is presented as the canonical Phase 2 acceptance scenario — auditors and users may be confused that even the "complete" fixture yields `partial_composition`. The scenario naming should clarify this is a deliberately partial fixture.

**MEDIUM — Android runtime proof explicitly deferred (JOS-006):**
`docs/codex/ANDROID_RUNTIME_BLOCKERS.md` marks Android Phase 1 and Phase 2 contracts as requiring a dedicated Gradle/SDK/desugaring pass. iOS-only runtime evidence cannot serve as Android acceptance. The SCORECARD correctly scopes this as a separate compatibility gate. No action required for Phase 2, but Phase 3 should not inherit the iOS-only status without explicit re-evaluation.

**LOW — `first_salary_tax` and `buy_property` have `maestro_flow_id: "pending"`:**
Both are `phase1_runtime_accepted` via Patrol tests. The Phase 2 acceptance criterion ("at least one runnable P0 Maestro YAML") is satisfied by `transmit_property`. No blocking concern, but Phase 4 must resolve the pending Maestro flows before full P0 runtime acceptance can be claimed.

**LOW — `parentAnnualLivingCosts` data quality signal could mislead:**
The `requiresCompleteFact` gate produces `reconfirm` mode even when partial budget evidence exists. The `parentAnnualLivingCosts` field accumulates up to 10 answer keys. The spec correctly handles this, but if a user provides 7 of 10 budget components, they'll see reconfirm prompts indefinitely until a `BiographyFact` with `sourceDate` is written. This is a Phase 4 migration concern (per DATA_QUEST.md §3 note on legacy answers).

---

### Required Fixes Before Phase 3

None. No unresolved CRITICAL or HIGH findings.

The two MEDIUM findings (reg() fallback observability, Raiffeisen fixture naming) can be addressed in Phase 3 without blocking Phase 2 acceptance. The Android gate (MEDIUM) is already tracked as JOS-006.

---

### Residual Risks

1. **Profile provenance survival across app restarts**: The Phase 2-3 bridge uses `_coach_data_timestamps`/`_coach_data_sources`/`_coach_data_source_dates` keys persisted in wizard answers. These survive restarts only if `ReportPersistenceService.saveAnswers()` is called after every `mergeAnswers()` invocation. The read-before-merge discipline in `mergeAnswers()` mitigates but does not eliminate this risk — a cold start between a `mergeAnswers()` and its async `saveAnswers()` completion could lose provenance.

2. **`DataQuestService.planCase()` called with `DateTime.now()`**: The succession screen calls `DataQuestService.planCase(..., now: DateTime.now())` on every `build()`. In tests, a fixed `DateTime.utc(2026, 7, 2)` is used. If clock drift or timezone handling diverges between test and device, freshness thresholds could produce different results. Low probability but worth noting for long-running sessions.

---

### Score: **9.3/10**

Phase 2 is safe to accept and Phase 3 can proceed. The case registry is fully executable: all three P0 cases are runtime-proven or Patrol-proven, dossier contracts are schema-validated, and the write path is singular and enforced.
