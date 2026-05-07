# MINT v2.14 — Counsel Brief

**Status:** Drafted 2026-05-07 — under counsel review for the v2.14 ship gate (Phase 97 SHIP-04). Status: Proposed.
**Audience:** Swiss fintech counsel (FinSA + DLT-Act + nLPD competency).
**Engagement:** 1-hour paid review + written sign-off on counsel letterhead.
**Intended use:** Prepared so reviewing counsel can read the package in ~15 minutes and use the remaining 45 minutes for Q&A on the three specific questions in section 5.

---

## 1. MINT product overview (1 page)

MINT is a Swiss financial lucidity mobile application (Flutter front-end + FastAPI back-end). The product positions itself as an **éclairage** (illumination) tool for adults aged 18 to 99, organised around 18 life events (logement, famille, fiscalité, carrière, dette, prévoyance, etc.) and 8 user archetypes (`swiss_native`, `expat_eu`, `expat_us`, `cross_border`, `independent_no_lpp`, and four further variants). MINT is explicitly **not framed as a retirement-only product** and does **not deliver personalised investment advice** within the meaning of FinSA art. 3 let. c / art. 8 al. 6.

The two main user-facing surfaces are:

- A **coach** surface that returns scenario-shaped lucidity outputs (Bas / Moyen / Haut bands with editable assumptions) and renders a confidence projection (`EnhancedConfidence`) on every emission.
- An **anonymous-chat** surface that delivers a single éclairage card per session, also accompanied by an explicit confidence projection and the same banned-terms pre-emission scan.

The pre-emission compliance pipeline applies a banned-terms scan against the LSFin-sensitive vocabulary (« garanti », « optimal », « sans risque », « certain », « assuré », « parfait », « meilleur ») on every coach output before display. Locale parity is enforced across six ARB files (fr / en / de / es / it / pt) and verified by a CI-gated linter.

**Ship target for v2.14:** TestFlight Internal NDA cohort of 5 Swiss-FR friends, with a pre-conformité disclosure banner (« données non recommandées pendant la phase de test »), 24-hour soak monitored via Sentry release-health (target ≥ 99.5% crash-free sessions over the rolling 24 hours post-install), and a 6-month mutual NDA. The cohort fits within Apple's Internal Testers tier (≤ 100 users, no Beta App Review). MINT is not currently supervised by FINMA at this stage; the v2.14 ship is a closed testing phase.

Linked product reference: see `.planning/PROJECT.md`, `.planning/ROADMAP.md`, and `.planning/REQUIREMENTS.md` in the same repository for product scope, milestones, and traceability.

## 2. FinSA control coverage table

The full machine-checked matrix is maintained at [`docs/compliance/CONTROL_MATRIX.md`](./CONTROL_MATRIX.md) (CI-gated at ≥ 95% coverage via `tools/checks/control_matrix_coverage.py`). Summary rows below; the matrix file carries the implementation anchors (`file:line`) and test IDs.

| Article | Domain | Status |
|---|---|---|
| art. 7 (pre-contractual disclosure) | Landing screen disclosure + beta disclosure sheet | GREEN |
| art. 8 al. 1 let. d (locale-correct information) | 6-locale ARB parity + locale-branched éclairage prompt | GREEN |
| art. 8 al. 6 (no-promise output) | Banned-terms pre-emission scan + promptfoo evaluation suite | GREEN |
| art. 9 (information format and timing) | Confidence projection rendered before output emission | GREEN |
| art. 12 (suitability via archetype + FATCA gate) | 8-archetype path + FATCA pre-emission gate | GREEN |
| art. 13 (documentation + retention) | `coach_message_audits` table with 10-year retention | GREEN |
| art. 16 (cost transparency) | Deferred to v2.15 (no paid tier shipped in v2.14) | DEFERRED |

Counsel will assess whether the GREEN rows above are evidenced to a level that supports the v2.14 closed-cohort ship, and whether the DEFERRED art. 16 row is acceptable while no paid tier is in market.

## 3. Decision artefact references

The following decision artefacts are filed in `.planning/decisions/` and are available for counsel reading in the same repository:

- **Test infrastructure doctrine** (2026-05-06): `.planning/decisions/2026-05-06-test-theater-post-mortem-doctrine.md` — establishes promptfoo + Pact + Alembic check + testcontainers + VCR as the baseline for the « tested » claim, and reframes the walker as an optional development tool rather than a ship-gate.
- **Data residency** (2026-05-02): `.planning/decisions/2026-05-02-data-residency.md` — local-first by default; cloud sync as an explicit user-controlled opt-in; primary hosting migration to a Swiss / EU region planned for Q3 2026.
- **Personal financial wiki** (2026-05-06): `.planning/decisions/2026-05-06-personal-financial-wiki-v3-candidate.md` — v3 candidate scope for the lucidity surface.

All decision artefacts are marked **Proposed** until founder sign-off, per the public-repo discipline applied to this repository.

## 4. NDA and tester cohort scope

- **Cohort:** 5 Swiss-FR friends, recruited by the company.
- **NDA:** 6-month mutual NDA in FR, governing law CH, working draft at `.planning/compliance/nda-template-2026-05.md`.
- **Distribution:** TestFlight Internal Testers tier (≤ 100 users, no Beta App Review).
- **Disclosure surface:** in-app banner (« pré-conformité, données non recommandées pendant la phase de test ») visible on first launch via the existing beta disclosure sheet.
- **Observability:** Sentry release-health, 24-hour rolling crash-free target ≥ 99.5%, alert paged via Phase 96 OBS-01.
- **Anonymisation:** tester feedback retained with initials only; no full names committed to the repository.

## 5. Specific questions for counsel review

1. **FinSA art. 8 al. 6 line-drawing.** Counsel will assess whether MINT's anonymous-chat éclairage card — which returns Bas / Moyen / Haut scenario bands with editable assumptions and an explicit confidence projection — sits within the éclairage / information service category, or whether any element of the current rendering would be classified as personalised advice within the meaning of FinSA art. 8 al. 6. The relevant pre-emission controls are the banned-terms scan and the confidence projection.
2. **OAR-G art. 24 retention sufficiency.** Counsel will assess whether the 10-year audit-log retention on the `coach_message_audits` table (with searchable identifier and Sentry tag emit) is sufficient for FINMA / OAR-G inspection on a closed-cohort TestFlight ship, or whether additional fields (for example a session JWT fingerprint or geo-stamp) would be appropriate before scaling beyond the v2.14 cohort.
3. **Pre-licensing scope.** Counsel will assess whether MINT v2.14 may ship to 5 NDA testers under the « pré-conformité » banner without triggering FINMA fintech-license registration, KAG manager registration, or FinSA art. 17 advisor-registry obligations. If a sandbox path is preferable (FINMA fintech sandbox), counsel will indicate whether the v2.14 cohort fits within sandbox parameters.

---

**Reviewer attestation:** Counsel name, date, and signature on letterhead, archived as `.planning/compliance/counsel-signoff-2026-05.pdf` post-call. The 1-page attestation summarises counsel's review of the v2.14 ship-gate package and counsel's position on each of the three questions above, together with any conditions counsel attaches to the closed-cohort ship.

---

## Appendix — repository entry points for counsel reading

For counsel who would like to read source material in the same repository before or during the call:

- [`docs/compliance/CONTROL_MATRIX.md`](./CONTROL_MATRIX.md) — full FinSA / DLT-Act / nLPD control matrix with implementation anchors and test IDs (CI-gated ≥ 95%).
- [`.planning/PROJECT.md`](../../.planning/PROJECT.md) — product scope.
- [`.planning/ROADMAP.md`](../../.planning/ROADMAP.md) — milestones, including the v2.14 ship gate.
- [`.planning/REQUIREMENTS.md`](../../.planning/REQUIREMENTS.md) — requirements traceability, SHIP-01..04 rows.
- [`.planning/decisions/2026-05-02-data-residency.md`](../../.planning/decisions/2026-05-02-data-residency.md) — local-first promise and Swiss / EU hosting roadmap.
- [`.planning/decisions/2026-05-06-test-theater-post-mortem-doctrine.md`](../../.planning/decisions/2026-05-06-test-theater-post-mortem-doctrine.md) — test-infrastructure baseline.
- [`docs/MINT_IDENTITY.md`](../MINT_IDENTITY.md) — positioning, life events, archetypes.

All repository links above are reachable on GitHub at `https://github.com/MINT-IA/MINT/blob/main/<path>`.
