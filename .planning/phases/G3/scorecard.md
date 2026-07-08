# G3 Scorecard — stale data reconfirm

Status: revised spec has Claude CLI GO. Product code may start only from a base that includes #851/#852 gates.

## Dependencies

- #851 `no_bypass_persistence`: required for DATA_QUEST DQ-4 / DATA_LEDGER I-3 proof.
- #852 `hardcoded_rate_gate`: required before any financial scenario code touches rates.

## Current PR

This PR only creates the mandatory Swiss Brain spec before code:

- `.planning/phases/G3/swiss-brain-spec.md`
- `.planning/runtime-evidence/G3/claude-audit-20260708.md`

## External Audit Findings

Claude CLI returned NO-GO on 2026-07-08. Resolved in this revision:

- Confirming a stale value would have been a facade because `mergeAnswers()` does not advance/persist `dataTimestamps`.
- Freshness classification must use field paths (`salaireBrutMensuel`, `canton`), not raw `q_*` wizard keys.
- `q_birth_year` is static identity data: collect if missing, never stale/reconfirm.
- Proposed freshness i18n keys did not exist and must be added explicitly.

Claude CLI re-audit returned GO after those fixes, with two implementation constraints:

- evaluate/reuse `BiographyRefreshDetector.detectStaleFields()` before adding UI ask planning;
- prove timestamp advancement survives reload from persisted `_coach_data_timestamps`, not just in-memory state.

## Code Gate

Do not add product code to G3 until the implementation PR can run:

- `python3 tools/checks/no_bypass_persistence.py --base-ref <base>`
- `python3 tools/checks/hardcoded_rate_gate.py --base-ref <base>`
- `cd apps/mobile && flutter test test/services/biography/ test/screens/data_block_enrichment_screen_test.dart`
- `cd apps/mobile && flutter analyze`

## First Implementation Slice

Target one vertical only:

- route: `/data-block/revenu`
- stale/reconfirm fields: `q_gross_salary_annual` → `salaireBrutMensuel`, `q_canton` → `canton`
- collect-only static field: `q_birth_year` → `age`
- behavior: stale known salary/canton → one reconfirm card; fresh known value → no Ask; missing value → existing collect flow.

## Required Anti-Facade Proof Before Code Acceptance

- Confirming a stale salary advances the field-path timestamp.
- Re-running the classifier after confirm returns no stale ask.
- Reloading answers in a new provider/profile instance preserves the advanced `_coach_data_timestamps` entry.
- The implementation either reuses `BiographyRefreshDetector.detectStaleFields()` or documents why a UI-only adapter cannot reuse its coach-nudge text without duplicating decay math.
