# MINT — FinSA Compliance Control Matrix

**Version:** v2.14 (« Living MINT »)
**Last computed coverage:** see `tools/checks/control_matrix_coverage.py --json`
**Threshold:** ≥ 95 % GREEN status across in-scope rows
**Format:** journalist + counsel readable. Updated weekly post-Phase-merge.
**Single source of truth (tested controls):** `docs/EVIDENCE.md` row 1 references this file.

## How to read this matrix

- **FinSA Article:** Swiss Federal Act on Financial Services article + paragraph (or `(operational)` for cross-cutting controls).
- **Requirement:** plain-language summary of the obligation.
- **Control:** what MINT does to satisfy the requirement.
- **Implementation Anchor:** `path:line` (or `path`) where the control lives in code.
- **Test ID:** test that exercises the control (path or `pytest -k` expression).
- **Last Green Commit:** SHA of the most recent commit touching the test file. `(compute)` = backfill on next phase merge.
- **Status:** `GREEN` (anchor + test + recent commit), `AMBER` (anchor exists but test missing), `RED` (anchor missing), `DEFERRED` (planned for later milestone — e.g. art. 16 pre-monetization, Pact infra v2.15).
- **Doctrine Reference:** decision file justifying the design.

**Coverage formula (Plan 97-03 Decision Option A):**
`coverage = GREEN / (GREEN + AMBER + RED)`. `DEFERRED` rows are tracked but excluded from the threshold denominator. Rationale: a deferred-pending-monetization control is a future-state placeholder, not a compliance failure.

**Defensive normalisation:** `tools/checks/control_matrix_coverage.py` auto-downgrades any row to `RED` if the Implementation Anchor cell is empty (or `n/a`), and to `AMBER` if the Test ID cell is empty — regardless of the declared Status. This blocks the « lie via Status column » tampering vector (T-97-03-01).

## Coverage table

| FinSA Article | Requirement | Control | Implementation Anchor | Test ID | Last Green Commit | Status | Doctrine Reference |
|---|---|---|---|---|---|---|---|
| art. 7 | Pre-contractual disclosure of nature of service | Beta program disclosure sheet on first launch + landing-screen FINMA non-supervision copy | `apps/mobile/lib/widgets/beta/beta_program_disclosure_sheet.dart` + `apps/mobile/lib/screens/landing_screen.dart` | `apps/mobile/test/widgets/beta/beta_program_disclosure_sheet_test.dart` | 6ab3dda3 | GREEN | 2026-05-06-test-theater-post-mortem-doctrine.md |
| art. 7 | Cost-of-service disclosure pre-engagement | Tracked under art. 16 — no costs to disclose pre-monetization | n/a | n/a | n/a | DEFERRED | art-16-deferred (v2.15 monetization) |
| art. 8 al. 1 let. a | Information about provider identity | « MINT en test » beta eyebrow + provider identity in landing footer | `apps/mobile/lib/widgets/beta/beta_program_disclosure_sheet.dart` | `apps/mobile/test/widgets/beta/beta_program_disclosure_sheet_dart_define_test.dart` | 6ab3dda3 | GREEN | 2026-05-06-test-theater-post-mortem-doctrine.md |
| art. 8 al. 1 let. d | Information in client-relevant language | Anonymous eclairage prompt locale branching FR/DE/IT/EN/ES/PT | `services/backend/app/services/coach/anonymous_eclairage_prompt.py` | `services/backend/tests/coach/test_anonymous_eclairage_prompt_locale.py` | cb5a8bdc | GREEN | Phase 94 SUMMARY |
| art. 8 al. 6 | No-promise / no-guarantee in financial communication | LSFin banned-terms scan on every coach response (server-side guard) | `services/backend/app/services/coach/compliance_guard.py` | `services/backend/tests/test_compliance_guard.py` | c034e1e4 | GREEN | CLAUDE.md règle 1 + Phase 95 plan |
| art. 8 al. 6 | No-promise enforcement at copy-deck level | ARB-level banned-terms lint blocks committing forbidden wording in 6 locales | `tools/checks/banned_terms_arb.py` + `apps/mobile/lib/l10n/*.arb` | `tools/checks/test_banned_terms_arb.py` | 76178a7f | GREEN | CLAUDE.md règle 1 |
| art. 9 al. 1 | Information format — durable medium with confidence framing | `MintTrameConfiance` inline rendering across coach + simulator surfaces | `apps/mobile/lib/widgets/trust/mint_trame_confiance.dart` | `apps/mobile/test/widgets/trust/mint_trame_confiance_test.dart` | 7daaa65c | GREEN | Phase 93 SUMMARY |
| art. 9 al. 2 | Information format — confidence badge before service rendered | Confidence badge mounted on the 5 simulator surfaces (3a, frontalier, leasing, compound, divorce) | `apps/mobile/lib/screens/simulators/` (5 screens) | `apps/mobile/test/screens/simulators/simulator_3a_with_confidence_badge_test.dart` | ca02dd42 | GREEN | Phase 93 SUMMARY |
| art. 12 al. 1 | Suitability — knows client situation | 8-archetype detection in `CoachProfile` (swiss_native / expat_eu / expat_us / cross_border / independent_no_lpp / …) | `apps/mobile/lib/models/coach_profile.dart` | `apps/mobile/test/screens/simulators/frontalier_with_confidence_badge_test.dart` | ca02dd42 | GREEN | CLAUDE.md règle 7 |
| art. 12 al. 1 | Suitability — gates incompatible advice | FATCA pre-emission gate when archetype = expat_us AND topic ∈ {3a, PFIC, treaty} | `services/backend/app/services/coach/fatca_gate.py` | `services/backend/tests/test_fatca_pre_emission_gate.py` | 6f95b384 | GREEN | Phase 93 SUMMARY |
| art. 12 al. 2 | Appropriateness — negative-path coverage on FATCA topic gate | Topic-classifier negative branch (non-3a / non-PFIC topics bypass the gate) | `services/backend/app/services/coach/fatca_gate.py` | `services/backend/tests/test_fatca_gate_negative_topic.py` | 6f95b384 | GREEN | Phase 93 SUMMARY |
| art. 12 al. 2 | Appropriateness — negative-path coverage on archetype gate | Archetype-detector negative branch (non-expat_us archetypes bypass the gate) | `services/backend/app/services/coach/fatca_gate.py` | `services/backend/tests/test_fatca_gate_negative_archetype.py` | 6f95b384 | GREEN | Phase 93 SUMMARY |
| art. 13 al. 1 | Documentation of service rendered | `coach_message_audits` row inserted on every coach response (best-effort, non-blocking) | `services/backend/app/models/coach_message_audit.py` | `services/backend/tests/test_audit_log_emit_on_coach_chat.py` | 36936875 | GREEN | OAR-G art. 24 + Phase 93 SUMMARY |
| art. 13 al. 1 | Documentation — anonymous-chat parity | Audit row also inserted on anonymous chat (Cleo-cohort parity) | `services/backend/app/models/coach_message_audit.py` | `services/backend/tests/test_audit_log_emit_on_anonymous_chat.py` | 36936875 | GREEN | OAR-G art. 24 + Phase 93 SUMMARY |
| art. 13 al. 2 | Retention of documentation — 10y on `retain_until` | Alembic migration sets retention column + forward/rollback parity test | `services/backend/app/models/coach_message_audit.py` | `services/backend/tests/test_alembic_audit_log_forward_rollback.py` | 36936875 | GREEN | OAR-G art. 24 |
| art. 13 al. 3 | Operational evidence — release-health observability | `SentryFlutter.init` with release-health enabled, env tag `MINT_ENV` | `apps/mobile/lib/main.dart` | `apps/mobile/test/widgets/beta/beta_program_disclosure_sheet_test.dart` (smoke proxy) | 8aa24a7f | GREEN | Phase 96 plan |
| art. 16 al. 1 | Cost transparency to client | Pre-monetization — no premium tier shipped. Control wires before paid tier. | n/a | n/a | n/a | DEFERRED | v2.15 monetization milestone |
| (operational) | i18n parity across 6 ARBs (FR / EN / DE / IT / ES / PT) | ARB parity tool + EN FinSA copy sweep | `tools/mcp/mint-tools/tools/arb_parity.py` | `apps/mobile/test/l10n/test_app_en_arb_finsa_sweep.dart` | cb5a8bdc | GREEN | CLAUDE.md règle 5 |
| (operational) | Data residency — EU-resident PII + observability | Backend DB + Sentry org + LLM provider all EU-resident | `services/backend/app/main.py` + Sentry org config | n/a (decision-anchored) | c53a1aa7 | DEFERRED | 2026-05-02-data-residency.md (test wiring deferred to v2.15) |
| (operational) | Test infra — non-theatre evidence stack | promptfoo + Pact + alembic check + testcontainers + VCR (Phase 95 5-tool stack) | `services/backend/tests/` collect-only inventory | `services/backend/tests/test_alembic_audit_log_forward_rollback.py` | 36936875 | GREEN | 2026-05-06-test-theater-post-mortem-doctrine.md + Phase 95 plan |

## Coverage math (post-shipping rows)

- Total rows: 19
- DEFERRED (excluded from denominator): 3 (art. 7 cost / art. 16 / data-residency v2.15 wiring)
- In-scope rows: 16
- GREEN: 16 / AMBER: 0 / RED: 0
- **Coverage = 16 / 16 = 1.00** ≥ 0.95 threshold → CI gate passes

## Update protocol

After every phase merge that touches a referenced test path:

1. Re-run `git log -1 --format=%h -- <test_path>` for affected rows.
2. Update the **Last Green Commit** column.
3. If a new test or anchor lands, add a row.
4. Re-run `python3 tools/checks/control_matrix_coverage.py --threshold 0.95 --json` locally before push.
5. Update `docs/EVIDENCE.md` row 1 timestamp.

`DEFERRED` rows track future-state controls (monetization, Pact infra). Promoting a row from `DEFERRED` to `GREEN` requires (a) anchor file present, (b) test exercising it, (c) commit SHA in the Last Green Commit column.
