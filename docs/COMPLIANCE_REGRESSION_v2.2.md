# COMPLIANCE_REGRESSION_v2.2

Final ComplianceGuard regression run for v2.2 ship gate. Every output channel touched in v2.0 / v2.1 / v2.2 is enumerated and walked through `ComplianceGuard.validate()`. Zero violations is required for ship.

## Run Metadata

- **Run date**: 2026-04-08 12:01:33 UTC
- **Git SHA**: `1a1aafc2`
- **Fixture**: `services/backend/data/compliance_regression/v2_2_channels.json`
- **Test file**: `services/backend/tests/services/compliance/test_compliance_regression_v2_2.py`
- **Runner**: `tools/compliance/run_v2_2_regression.py`
- **Overall status**: **GREEN**
- **Total samples**: 61
- **Passed**: 61
- **Violations**: 0

## Channels Under Test

| # | Channel ID | Channel | Samples | Passed | Pass Rate |
|---|-----------|---------|--------:|-------:|----------:|
| 1 | `alerts_mint_alert_object` | MintAlertObject (Phase 9) — Gravity G2/G3 x VoiceLevel N1-N5 | 10 | 10 | 100.0% |
| 2 | `biography_facts` | Biography / BiographyFact entries (Phase 9 ack, Phase 11 fragility, v2.0 narrative) | 6 | 6 | 100.0% |
| 3 | `openers_first_message` | Coach openers / first-message templates (claude_coach_service) | 5 | 5 | 100.0% |
| 4 | `extraction_summaries` | Document extraction summaries / educational inserts | 5 | 5 | 100.0% |
| 5 | `alert_grammar_triples` | MintAlertObject grammar (fact / cause / nextMoment) — 5 alert types | 5 | 5 | 100.0% |
| 6 | `rewritten_coach_phrases` | Plan 11-01 rewritten coach phrases (subset, multi-level rendering) | 10 | 10 | 100.0% |
| 7 | `voice_cursor_outputs` | Voice cursor outputs at all 5 levels (Phase 5 — VOICE_CURSOR_SPEC) | 10 | 10 | 100.0% |
| 8 | `ton_chooser_micro_examples` | Ton chooser micro-examples (D-06) | 3 | 3 | 100.0% |
| 9 | `regional_voice_overlays` | Regional voice overlays (Romandie / Deutschschweiz / Ticino) | 3 | 3 | 100.0% |
| 10 | `landing_onboarding_copy` | Landing v2 + Onboarding v2 copy | 4 | 4 | 100.0% |

## Exclusions & Rationale

- **Internal logs / audit trails** — never reach the user, out of scope.
- **Backend exception messages** — surfaced only as generic localized errors via the mobile app, covered by Phase 9 fallback strings.
- **Pure numeric outputs** (calculator results without prose) — covered by hallucination detection in the live runtime path, not by this anti-shame text regression.
- **Admin / dev tooling text** — internal-only, not user-facing.

## Run Results

All **61** samples across **10** channels passed `ComplianceGuard.validate()` with **zero violations**. Audit fix B4 satisfied. Ship gate: **OPEN**.

## Reproduction

```bash
cd services/backend && \
  python3 -m pytest tests/services/compliance/test_compliance_regression_v2_2.py -q

# or, full report:
python3 tools/compliance/run_v2_2_regression.py
```
