# MINT v2.14 — Counsel Brief (working draft)

**Status:** Drafted 2026-05-07 — internal working draft, source for `docs/compliance/COUNSEL_BRIEF.md`.
**Audience:** internal (Julien + reviewing counsel during the 1-h call). Carries firm names, fee placeholders, and richer link tree.
**Engagement target:** 1-hour paid review with one of Pestalozzi / Lenz & Staehelin / Vischer (CHF 800-1'200 expected).

---

## 1. MINT product overview (extended)

MINT is a Swiss financial lucidity mobile app (Flutter + FastAPI). Position: éclairage / lucidité, not personalised investment recommendation. Audience: 18–99, organised around 18 life events (logement, famille, fiscalité, carrière, dette, prévoyance, indépendant, expatriation, etc.) and 8 archetypes (`swiss_native`, `expat_eu`, `expat_us`, `cross_border`, `independent_no_lpp`, plus four further variants).

Surfaces in v2.14:
- **Coach** (multi-turn) — emits scenario-shaped lucidity outputs (Bas / Moyen / Haut) with editable assumptions + `EnhancedConfidence` rendered pre-emission.
- **Anonymous chat** — single éclairage card per session, same confidence projection, same banned-terms scan.

Pre-emission controls in v2.14:
- Banned-terms scan against the LSFin-sensitive vocabulary (« garanti », « optimal », « sans risque », « certain », « assuré », « parfait », « meilleur »); see `compliance_guard.BANNED_TERMS` and `tools/checks/banned_terms_arb.py`.
- Confidence projection (`EnhancedConfidence` 4-axis: completeness × accuracy × freshness × understanding) rendered on every output before display.
- 6-locale ARB parity (fr / en / de / es / it / pt) with CI-gated `validate_arb_parity()`.
- FATCA gate on `expat_us` archetype before US-tax-sensitive output.
- 10-year audit log on `coach_message_audits`.

For counsel reading: linked product references in this repository:
- `.planning/PROJECT.md` (product scope)
- `.planning/ROADMAP.md` (milestones, including the v2.14 ship gate)
- `.planning/REQUIREMENTS.md` (requirements traceability, SHIP-01..04 rows)
- `docs/MINT_IDENTITY.md` (positioning, life events, archetypes)
- `docs/DESIGN_SYSTEM.md` and `docs/VOICE_SYSTEM.md` (UI and tone constraints)

**Ship target for v2.14:** TestFlight Internal NDA cohort of 5 Swiss-FR friends, pre-conformité banner, 24-hour Sentry release-health soak ≥ 99.5% crash-free, 6-month mutual NDA. Internal Testers tier (≤ 100, no Beta App Review). MINT not currently FINMA-supervised; v2.14 is closed testing.

## 2. FinSA control coverage table (full export)

Source of truth: [`docs/compliance/CONTROL_MATRIX.md`](../../docs/compliance/CONTROL_MATRIX.md) (CI-gated ≥ 95% via `tools/checks/control_matrix_coverage.py`).

| Article | Control | Implementation anchor | Test ID | Status |
|---|---|---|---|---|
| art. 7 (pre-contractual) | Landing screen disclosure | `apps/mobile/lib/screens/landing_screen.dart:166` | `landing_screen_disclosure_test` | GREEN |
| art. 7 (pre-contractual) | Beta disclosure sheet | `apps/mobile/lib/widgets/beta/beta_program_disclosure_sheet.dart` | `beta_disclosure_sheet_test` | GREEN |
| art. 8 al. 1 let. d | 6-locale ARB parity | `apps/mobile/lib/l10n/*.arb` | `validate_arb_parity` | GREEN |
| art. 8 al. 1 let. d | Locale-branched éclairage prompt | `services/backend/app/coach/anonymous_eclairage_prompt.py` | `anonymous_eclairage_locale_test` | GREEN |
| art. 8 al. 6 | Banned-terms pre-emission scan | `services/backend/app/compliance/compliance_guard.py` | `banned_terms_arb_test` + `promptfoo_eval_no_promise` | GREEN |
| art. 9 (format + timing) | Confidence projection rendered pre-emission | `apps/mobile/lib/widgets/mint_trame_confiance.dart` | `mint_trame_confiance_inline_test` | GREEN |
| art. 12 (suitability) | 8-archetype path | `apps/mobile/lib/services/coach/coach_profile.dart:1784` | `coach_profile_archetype_test` | GREEN |
| art. 12 (suitability) | FATCA gate on expat_us | `services/backend/app/coach/fatca_gate.py` | `fatca_gate_test` | GREEN |
| art. 13 (documentation) | `coach_message_audits` table + 10-year retention | `services/backend/app/models/coach_audit.py` | `coach_audit_retention_test` | GREEN |
| art. 16 (cost transparency) | N/A pre-monetization | (no paid tier shipped in v2.14) | DEFERRED to v2.15 | DEFERRED |

(Some anchors above are illustrative for the working draft — counsel reads `docs/compliance/CONTROL_MATRIX.md` for the canonical anchors with their last-green commit hashes; CONTROL_MATRIX is shipped by Plan 97-03 in the same wave.)

## 3. Decision artefact summaries

Decision artefacts in `.planning/decisions/` (status: Proposed pending founder sign-off):

- **Test infrastructure doctrine** (2026-05-06) — `.planning/decisions/2026-05-06-test-theater-post-mortem-doctrine.md`
  - Reframes the walker as a development tool, not a ship gate. Ship-grade testing baseline = promptfoo (LLM behaviour) + Pact (HTTP contracts) + Alembic check (DB migrations) + testcontainers (real Postgres/Redis) + VCR (deterministic LLM transcripts). CI-gated.
- **Data residency** (2026-05-02) — `.planning/decisions/2026-05-02-data-residency.md`
  - Local-first by default; cloud sync explicit opt-in. v2.x: structural alignment with the local-first promise. Q3 2026: primary hosting migration to a Swiss / EU region (Exoscale, Infomaniak, or GCP europe-west6). v3.0: client-side encryption for sensitive data classes (post-PMF).
- **Personal financial wiki v3 candidate** (2026-05-06) — `.planning/decisions/2026-05-06-personal-financial-wiki-v3-candidate.md`
  - v3 lucidity surface scope candidate.

Notes for counsel: these artefacts are not yet founder-signed; counsel review may produce conditions on the artefacts before they move from Proposed to Decided.

## 4. NDA and tester cohort scope

Working draft NDA at [`.planning/compliance/nda-template-2026-05.md`](./nda-template-2026-05.md) (shipped by Plan 97-02 in the same wave). Counsel review covers both the brief and the NDA in the same 1-hour slot, single billable hour.

Cohort details:
- 5 Swiss-FR adults, recruited by the company; archetype mix (target): ≥ 1 swiss_native, ≥ 1 cross_border or expat_eu, ≥ 1 independent_no_lpp.
- 6-month mutual NDA, governing law CH, FR-language.
- TestFlight Internal Testers tier (≤ 100, no Beta App Review).
- 24h Sentry release-health soak, ≥ 99.5% crash-free, alert via Phase 96 OBS-01.
- Tester feedback anonymised (initials only) and committed under `.planning/phases/97-mvp-ship-gate/tester-feedback/<initials>.md`.

Timeline (per CONTEXT.md SHIP-04):
- D11: request fee quotes from the three shortlisted firms.
- D12: pick firm; book 1h slot.
- D13–D14: 1-hour call with counsel (brief + NDA in one slot).
- D14–D15: counsel issues written attestation (PDF on letterhead).
- D15: file PDF at `.planning/compliance/counsel-signoff-2026-05.pdf`; `docs/EVIDENCE.md` row 2 moves PENDING → GREEN.

## 5. Specific questions for counsel (with internal notes)

### Q1 — FinSA art. 8 al. 6 line-drawing on the éclairage card

Counsel will assess whether the anonymous-chat éclairage card sits within the éclairage / information service category, or whether any element of the current rendering would be classified as personalised advice within the meaning of FinSA art. 8 al. 6.

Internal context for Claude / Julien (not for the public version):
- The card returns Bas / Moyen / Haut bands with editable assumptions, never a single number.
- The `EnhancedConfidence` projection is rendered before the card is shown, with uncertainty bands.
- Banned-terms scan blocks « garanti » / « optimal » / « sans risque » / « certain » / « assuré » / « parfait » / « meilleur ».
- Hoped position from counsel: the éclairage card sits within the éclairage / information category and does not require FinSA art. 8 al. 6 retraining.
- Contingency if counsel disagrees: re-frame the card to remove any feature counsel flags (for example, drop editable assumptions for the closed cohort, or add an inline « ceci est une simulation, pas une recommandation » strip on every card).

### Q2 — OAR-G art. 24 retention sufficiency

Counsel will assess whether the 10-year audit-log retention on `coach_message_audits` is sufficient for FINMA / OAR-G inspection on a closed-cohort ship, or whether additional fields are appropriate before scaling beyond the v2.14 cohort.

Internal context:
- Current schema: `coach_message_audits(id, user_id, archetype, locale, prompt_hash, output_hash, banned_terms_hits, confidence_axes, created_at, retained_until)`.
- Sentry tag emit: each audit row gets a tag pair (`audit_id`, `archetype`) for cross-correlation.
- Hoped position: 10-year retention is sufficient for the closed cohort; counsel may suggest adding session JWT fingerprint and geo-stamp before the External Testers expansion.

### Q3 — Pre-licensing scope for the closed cohort

Counsel will assess whether MINT v2.14 may ship to 5 NDA testers without triggering FINMA fintech-license registration, KAG manager registration, or FinSA art. 17 advisor-registry obligations.

Internal context:
- 5 testers under mutual NDA; no payment surface in v2.14; no third-party fund placement; no client portfolio management.
- The pre-conformité banner is shown on first launch and is acknowledged by the user before they reach any éclairage surface.
- Hoped position: closed-cohort NDA testing does not trigger the FINMA fintech-license / KAG / advisor-registry obligations. If counsel identifies a regulatory tension to resolve before shipping, the FINMA fintech sandbox path is the documented fallback (see `<risks>` R2 in plan 97-04).

---

**Reviewer attestation target:** 1-page letter on counsel letterhead, signed, with counsel's position on each of Q1 / Q2 / Q3 and any conditions attached to the closed-cohort ship. PDF filed at `.planning/compliance/counsel-signoff-2026-05.pdf`. EVIDENCE.md row 2 then moves from PENDING to GREEN.
