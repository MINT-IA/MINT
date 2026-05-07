# Roadmap: MINT

## Milestones

- ✅ **v1.0 MVP** — Phases 1-8 (shipped 2026-03-20)
- ✅ **v2.0 Systeme Vivant** — Phases 1-6 (shipped 2026-04-07)
- ✅ **v2.1 Stabilisation** — Phase 7 (shipped 2026-04-07)
- ✅ **v2.4 Fondation** — Phases 9-12 (shipped 2026-04-12)
- ✅ **v2.5 Transformation** — Phases 13-18 (shipped 2026-04-13)
- ✅ **v2.6 Le Coach Qui Marche** — Phases 19-26 (shipped 2026-04-13)
- 🟡 **v2.7 Coach Stabilisation + Document Digestion** — Phases 27-30 (code-complete, awaiting device gate)
- 🔵 **v2.8 L'Oracle & La Boucle** — Phases 30.5, 30.6, 30.7, 31-36 (defining)
- 🌱 **v2.9 Chat Vivant** (planted 2026-04-19) — "Le chat ne raconte plus, il montre." 3 niveaux de projection (inline insight / scene interactive / canvas plein écran) à la Claude Artifacts. Source : `.planning/handoffs/chat-vivant-2026-04-19/` (8 docs + 6 JSX + captures HTML). Estimation P50 = 3 semaines calendar solo (refactor `CoachOrchestrator` Stream + i18n 6 langues + creator-device gate). 3 frictions à trancher avant exécution : (1) scenes inline vs écrans Explorer existants → single source of truth ? (2) `Future<CoachResponse>` → `Stream<ChatMessage>` refactor touche 3 code paths orchestrator, (3) i18n ARB 6 langues ~180 entries non comptées. À réveiller après Phase 31 shippée.
- 🟡 **v2.9 → v2.13 carry-over** — Phases 40-90 (partial ship 2026-04 → 2026-05, see git log)
- 🟢 **v2.14 « Living MINT »** (started 2026-05-06) — Phases 91-97 (defining)

<details>
<summary>Previous milestones (v1.0 → v2.7) — see MILESTONES.md + collapsed v2.5-v2.7 detail below</summary>

Full phase detail for v2.5 (Phases 13-18), v2.6 (Phases 19-26), v2.7 (Phases 27-30) preserved in git history of this file (pre-2026-04-19 revisions) + `.planning/MILESTONES.md`.

</details>

---

## v2.8 L'Oracle & La Boucle — SHIPPED 2026-04-25 (with gaps)

<details>
<summary>v2.8 phase detail (collapsed — full archive in milestones/v2.8-ROADMAP.md)</summary>

5 phases shipped + 13 decimal patches :
- 30.5 Context Sanity Core ✓ · 30.6 Context Sanity Advanced ✓ · 30.7 Tools Déterministes ✓ · 31 Instrumenter ✓ · 32 Cartographier ✓
- 30.8-30.20 : tactical fixes (LAND-01, FIX-02, anonymous CTA, error mapping, accent_lint exclusions, doc extraction uplift…)

Phases unshipped (carried forward to v2.9) :
- 33 Kill-switches (4 P0 flags) — needed for v2.9 if user-value features ship behind flag
- 34 Guardrails — workflow design failed, lessons learned, redo with proper exclusions baked in
- 35 Boucle Daily — automation, defer
- 36 Finissage E2E — spirit absorbed into v2.9 « Coach Visuel Hybride »

Full audit: [milestones/v2.8-MILESTONE-AUDIT.md](milestones/v2.8-MILESTONE-AUDIT.md) · 28/48 reqs · 5/9 phases.

</details>

---

## v2.9 Coach Visuel Hybride — Overview

**Goal:** Verticale « Onboarding-to-First-Insight » : un user qui arrive sur MINT a, en moins de 20 min, son profil financier sur les 6 axes suisses (AVS, LPP, 3a, salaire, fortune, charges) + un hero number actionnable « marge fiscale optimisable cette année » + un coach qui balance vignettes / scènes / canvas pour explorer les arbitrages (3a vs rachat LPP vs amortissement vs hypothèque) avec liens deep-dive vers les écrans Explorer existants.

**Doctrine v2.9 (planted 2026-04-19, validated 2026-04-25):** Le coach EST le produit. 3 niveaux de projection visuelle (vignette inline / scène interactive / canvas modal) intégrés dans le chat, avec arbitrage live et lien vers les écrans Explorer pour deep dive.

**Carry-forward from v2.8:** FIX-01 UUID, FIX-03 save_fact, FIX-04 Coach tab, FIX-05 Wave 2+ bare catches (195 P0+128 P1), FIX-07 234 backend accent violations, Phase 33 kill-flags (subset only).

**Phases planned:**
- **Phase 40 — Marge fiscale backend** (3-5j) : pure function `compute_marge_fiscale(profile)` (3a + rachat LPP + cash availability) + endpoint + 10 unit tests
- **Phase 41 — Hero + Vignettes L1** (1 sem) : `MargeFiscaleHero` + `MargeFiscaleVignette` widget, branche dans PulseScreen + chat
- **Phase 42 — Scènes L2 interactives** (2 sem) : `MintSceneArbitrageRetraite` + `MintSceneArbitrageHypotheque` slider live, `SceneRegistry`, début refactor `Stream<ChatMessage>`
- **Phase 43 — Canvas L3 + lien Explorer** (1-2 sem) : `MintCanvasArbitrage` modal, return contract chat ← canvas, optimisation écrans Explorer existants

**KPIs gating (chaque phase):**
- Coverage profil après 5 min ≥ 60%
- Time-to-first-vignette < 90s
- p95 chat response < 3s
- 0 P0 production
- Diff-coverage PR ≥ 80%
- Walk Julien hebdo simctl
- Bare catches 342 → < 100
- ARB parity 6 langs preserved

**Total estimate:** 5-7 semaines solo-dev. Creator-device gate non-skippable.

---

## v2.14 « Living MINT » — Overview

**Started:** 2026-05-06
**Goal:** Transformer MINT d'un prototype « shipped en code, théâtre en validation » en un MVP qui se walke bout-en-bout sans crash, qui rend personnalisé pour 3 archétypes (julien_swiss / lauren_expat_us / sofia_ticino), qui se sent vivant per Cleo benchmark, et qui passe l'inspecteur FINMA test.

**Source artefacts:**
- `.planning/PROJECT.md` (core value, identity)
- `.planning/REQUIREMENTS.md` (25 v1 requirements)
- `.planning/MILESTONE-MVP.md` (architecture cible MASTERPLAN-aligned)
- `.planning/MILESTONE-MVP-PERIMETER.md` (« living MVP » 6-panel synthesis, 7 must-haves)
- `.planning/decisions/2026-05-06-test-theater-post-mortem-doctrine.md` (W1-W4 plan, 30 jours)
- `docs/USER_WALKTHROUGH_2026-05-06.md` (351 lignes, 23 bugs, 13 fixés)

**Doctrine (locked 2026-05-06):**
- **Walker hits Railway staging LIVE.** Replay-cache fixtures dead. Real LLM nightly, $22/mo Anthropic budget capped.
- **Author-and-grade-same-session = banned.** Fixture and assertion never written by the same agent in the same session.
- **Authority laundering = banned.** Citations must point to existing decision files.
- **Tests pass ≠ product correct.** Promptfoo + Pact + alembic check + testcontainers-Postgres + Sentry release-health = the new « tested ».
- **5 testers TestFlight Internal NDA cohort = ship gate.** No journalist-defensible launch without 24h crash-free ≥ 99.5% over closed cohort.

**Phase numbering:** continuing from Phase 90 (Phase A5). v2.14 starts at Phase 91 in dependency order: critical-bugs first → compliance → test infra → observability → ship gate.

**Critical constraint:** every phase is **shippable on its own** (dev → staging → testflight independently). No phase bundles a year of work. 7 phases × 2-4 days each ≈ 3-week horizon.

**KPIs gating (each phase):**
- Device walk by Julien (`flutter run --release` on iPhone via Mac Mini sim, fresh install) — non-skippable
- HTML evidence report `.planning/phases/<phase>/<phase>-VERIFICATION-REPORT.html` updated
- 4-panel design review (UX + a11y + adversarial + engineering wiring) BEFORE pushing screen changes
- Pre-push checklist: grep all callers of changed signatures + regen OpenAPI / `flutter gen-l10n` + full pytest+flutter test green
- Banner « pré-conformité » + LSFin banned-term lint green on captured responses
- 0 P0 unfixed at phase close

### Phases

- [x] **Phase 91: Vivant Proactive Primitives** — Cleo-parity proactive push + cross-session opener + interrupt banner wired + persona toggle migrated to Settings (closes BUG #5 P0). ✅ shipped 2026-05-06 (commits 46928ec2/d5cb375f/e757d3f5/09f28d06)
- [x] **Phase 92: Documents Vault Typed Wiring** — `LppExtractedFields → ExtractedField` typed converter wired + idempotency-key SHA256 (closes BUG #4 P0). ✅ shipped 2026-05-06 (commit 75f72c3a)
- [ ] **Phase 93: Compliance Hardening (Audit Log + FATCA + Confidence)** — 10y audit log table per OAR-G art. 24, FATCA pre-emission gating expat_us, 5 simulators ConfidenceBadge (closes BUG #18, #21, #22).
- [ ] **Phase 94: Compliance Polish (Locale + i18n + Constants)** — éclairage prompt locale branching DE/IT/EN/ES/PT, EN « LSFin → FinSA » sweep, benchmark literal `7000` → constant (closes BUG #20, #12, #23).
- [ ] **Phase 95: Test Infrastructure Réelle** — promptfoo eval suite 160 prompts × 4 archetypes, Pact mobile↔backend contracts, alembic check forward+rollback, testcontainers-Postgres, VCR cassettes nightly rewrite (closes test theater per doctrine W2).
- [ ] **Phase 96: Production Observability** — Sentry release-health PagerDuty alerts crash-free < 99.5%, Checkly synthetics 4 staging endpoints 5-min cron, Sentry events tagged with `eval_score` / `banned_term_hit` / `eclairage_kind` (closes doctrine W4).
- [ ] **Phase 97: MVP Ship Gate** — Maestro suite green on iPhone 17 Pro + iPhone SE + iPad mini, 5 testers TestFlight Internal NDA cohort 24h soak ≥ 99.5%, Compliance Control Matrix ≥ 95% coverage, 1h Swiss fintech counsel sign-off.

### Phase Details

### Phase 91: Vivant Proactive Primitives
**Goal**: MINT se sent vivant — le coach pousse, n'attend pas. Cross-session memory anchored. Interrupt banner wired. Persona toggle persistent.
**Depends on**: Phase 90 (A5 production safety guards)
**Requirements**: VIVANT-01, VIVANT-02, VIVANT-03, VIVANT-04
**Success Criteria** (what must be TRUE):
  1. The user receives a `flutter_local_notifications` push within 5 minutes of one of 6 trigger types firing (paie scheduled, doc upload complete, confidence delta > 10pts, JITAI date match, lifecycle change, return-after-7d). Verified by `idb` simulator notification capture + Sentry breadcrumb `proactive_push.delivered`.
  2. The user opens `CoachChatScreen` after 24h+ absence and sees the previous `CapMemory` outcome + `ConversationMemoryService` summary prepended as the opener — never a cold start. Verified by `coach_opener_cross_session_test.dart` Maestro flow.
  3. The user sees a `CoachInterruptBanner` rendered above the chat input when `state.activeNudges.isNotEmpty`, with at least one call site in `coach_chat_screen.dart` (closes facade audit finding #2 — currently 0 call sites).
  4. The user finds the « Calme / Direct / Sans filtre » persona toggle in `Settings/IA` panel, picks one, kills app, reopens, and the choice persists via SharedPreferences flag.
**Plans**: TBD
**UI hint**: yes

### Phase 92: Documents Vault Typed Wiring
**Goal**: Documents tab does what the screen promises — upload PDF → 15 fields land in CoachProfile + confidence invalidates + Cap recomputes.
**Depends on**: Phase 91
**Requirements**: DOCS-01, DOCS-02, DOCS-03
**Success Criteria** (what must be TRUE):
  1. The user uploads an LPP CPE PDF via `documents_screen.dart:_pickAndUpload` and sees the 15 typed fields populate `CoachProfile.extractedFields` within 30s — verified by widget test `documents_upload_typed_converter_test.dart` + Maestro `scan_lpp_certificate.yaml`.
  2. The system invalidates `EnhancedConfidence` and triggers Cap recompute immediately after `updateFromLppExtractedFields` — verified by `cap_recompute_after_doc_upload_test.dart` (Cap value differs pre/post).
  3. The user retries an interrupted upload and the backend dedupes via SHA256 of file bytes (not random UUID) — verified by integration test `idempotency_key_sha256_test.py` against staging endpoint.
**Plans**: TBD
**UI hint**: yes

### Phase 93: Compliance Hardening — Audit Log + FATCA + Confidence
**Goal**: MINT passes the FINMA inspector test — every coach response auditable 10y, FATCA emission gated for expat_us, every simulator surfaces confidence.
**Depends on**: Phase 92
**Requirements**: COMP-01, COMP-03, COMP-04
**Success Criteria** (what must be TRUE):
  1. Every `coach_chat.py` and `anonymous_chat.py` response writes a row to the audit log table (Postgres, 10y retention) with `session_id`, `archetype`, `prompt_hash`, `response_hash`, `banned_term_hit`, `eclairage_kind`, `created_at` — verified by `pytest test_audit_log_emit_on_every_response.py` + alembic migration applied.
  2. When `archetype == expat_us` AND topic ∈ {3a, PFIC, treaty}, the LLM call is pre-emption gated and the user sees a FATCA hand-off card instead of generic 3a advice — verified by `test_fatca_pre_emission_gating.py` + Maestro `lauren_expat_us_3a_handoff.yaml`.
  3. The 5 simulators (`simulator_3a`, `divorce`, `frontalier`, `compound`, `leasing`) each render a `ConfidenceBadge` with the 4-axis score visible — verified by 5 widget golden tests + design panel sign-off.
**Plans**: TBD
**UI hint**: yes

### Phase 94: Compliance Polish — Locale + i18n + Constants
**Goal**: éclairage card speaks all 6 supported locales correctly ; EN no longer says « LSFin » ; benchmark service no longer ships literal 7000.
**Depends on**: Phase 93
**Requirements**: COMP-02, COMP-05, COMP-06
**Success Criteria** (what must be TRUE):
  1. `anonymous_eclairage_prompt.py` branches on `locale` and emits a localized éclairage card for each of FR / DE / IT / EN / ES / PT — verified by promptfoo eval suite × 6 locales × 4 archetypes (24 cases) all pass banned-term + structure checks.
  2. ARB sweep replaces ~60 occurrences of « LSFin » → « FinSA » across `app_en.arb` and `flutter gen-l10n` regenerated — verified by `validate_arb_parity()` MCP tool + visual check on landing screen EN locale (closes BUG #12).
  3. `benchmark_service.dart:118` references `pilier3aPlafondAvecLpp` from `social_insurance.dart` (not the literal `7000`) — verified by `grep -rn '7000\.0\?' apps/mobile/lib/services/` returns 0 hits + unit test pulls the constant.
**Plans**: TBD

### Phase 95: Test Infrastructure Réelle
**Goal**: Replace test theater with code-graded, contract-verified, migration-checked, container-isolated CI. Promptfoo + Pact + alembic check + testcontainers + VCR ship and merge-block.
**Depends on**: Phase 94
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04, TEST-05
**Success Criteria** (what must be TRUE):
  1. promptfoo GitHub Action runs `services/backend/evals/promptfooconfig.yaml` (160 prompts × 4 archetypes) on every PR, posts diff comment, **merge-blocks** if pass-rate drops vs `main` — verified by deliberate red-PR experiment.
  2. Pact consumer-driven contracts on `/anonymous/chat`, `/coach/chat`, `/documents/upload`, `/onboarding/premier-eclairage` verify mobile↔backend in CI — verified by intentional schema break causing CI red.
  3. `alembic check` + forward-then-rollback runs on fresh testcontainers-Postgres in CI — verified by deliberate missing-column migration causing CI red (closes Sentry « column does not exist » class of bug).
  4. Backend pytest fixtures use testcontainers-Postgres (not sqlite) for migration-sensitive tests — verified by `pytest --collect-only` showing fixture in scope + at least 5 tests passing under it.
  5. pytest-recording (VCR.py) cassettes live in `services/backend/tests/cassettes/` for Anthropic calls + nightly cron rewrites them from staging-live — verified by cron file `.github/workflows/vcr_nightly_rewrite.yml` green run + cassette drift report.
**Plans**: TBD

### Phase 96: Production Observability
**Goal**: Production is the source of truth. Crash-free SLO paged. Synthetic probes catch outages before users. Coach responses tagged with eval scores.
**Depends on**: Phase 95
**Requirements**: OBS-01, OBS-02, OBS-03
**Success Criteria** (what must be TRUE):
  1. Sentry release-health alert triggers Slack #mint-alerts when crash-free sessions < 99.5% over rolling 1h window — verified by deliberate test crash → Slack notification within 15 min. (PagerDuty deferred — Slack-first per CONTEXT.md decision.)
  2. Checkly synthetic probes hit 4 staging endpoints (`/anonymous/chat`, `/auth/login`, `/documents/upload`, `/health`) on a **10-min cron** (locked at Hobby tier $0/mo per Julien cost-scope decision ; upgrade to Team $30/mo + 5-min cron at TestFlight Beta) and page on failure — verified by deliberate staging downtime drill.
  3. Every coach response in `/anonymous/chat` and `/coach/chat` emits a Sentry event tagged with `eval_score` (from promptfoo runtime), `banned_term_hit` (bool), `eclairage_kind` (str) — verified by Sentry dashboard query + sample 10 events from staging traffic.
**Plans**: 3 plans
Plans:
- [ ] 96-01-PLAN.md — Sentry release-health alert rule + Slack integration + canary scripts (OBS-01) — Wave 1
- [ ] 96-02-PLAN.md — Checkly account + checks-as-code config + 4 probes + downtime drill (OBS-02) — Wave 2 (depends on Slack channel from 96-01)
- [ ] 96-03-PLAN.md — Sentry audit-tag helper + 3 call sites + dashboard saved-query (OBS-03) — Wave 1 (independent code change)

### Phase 97: MVP Ship Gate
**Goal**: TestFlight Internal NDA closed cohort, 5 Swiss FR testers, 24h crash-free ≥ 99.5%, banner « pré-conformité », counsel sign-off, Control Matrix ≥ 95%. The actual ship.
**Depends on**: Phase 96
**Requirements**: SHIP-01, SHIP-02, SHIP-03, SHIP-04
**Success Criteria** (what must be TRUE):
  1. Maestro E2E suite (login → /onb → /home → /mon-argent → /budget/setup → /coach/chat → /documents/upload → /explorer/fiscalite levier) runs green on iPhone 17 Pro + iPhone SE + iPad mini against release-config staging, **NO `MINT_E2E_*` defines** — verified by Maestro Cloud run report archived in `.planning/phases/97-mvp-ship-gate/`.
  2. 5 Swiss-FR testers under NDA receive TestFlight Internal build with banner « version pré-conformité, données non recommandées » + 24h soak run delivers ≥ 99.5% crash-free sessions in Sentry — verified by tester sign-off + Sentry release dashboard screenshot.
  3. `docs/compliance/CONTROL_MATRIX.md` maps FinSA art. 7 / 8 / 9 / 12 / 13 / 16 → control → test ID → last green commit, with ≥ 95% control coverage — verified by `tools/checks/control_matrix_coverage.py` ≥ 0.95.
  4. 1-hour paid Swiss fintech counsel review (Pestalozzi / Lenz & Staehelin / Vischer, CHF 800-1'200) returns written sign-off filed in `.planning/compliance/counsel-signoff-2026-05.pdf` — verified by file existence + summary in `docs/EVIDENCE.md` row 1.
**Plans**: TBD
**UI hint**: yes

### Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 91. Vivant Proactive Primitives | 4/4 | ✅ Shipped | 2026-05-06 |
| 92. Documents Vault Typed Wiring | 1/1 | ✅ Shipped | 2026-05-06 |
| 93. Compliance Hardening (Audit + FATCA + Confidence) | 0/? | Not started | - |
| 94. Compliance Polish (Locale + i18n + Constants) | 0/? | Not started | - |
| 95. Test Infrastructure Réelle | 0/? | Not started | - |
| 96. Production Observability | 0/3 | Not started | - |
| 97. MVP Ship Gate | 0/? | Not started | - |

### Coverage

✓ All 25 v1 requirements mapped to exactly one phase (see `.planning/REQUIREMENTS.md` Traceability table).
✓ No orphans, no duplicates.
✓ Dependency order: critical-bugs (P0) → compliance → test infra → observability → ship gate.

---
*Last updated: 2026-05-06 — v2.14 « Living MINT » opened with Phases 91-97. v2.8 closed at 5/9 + 13 decimals (gaps_found). v2.9-v2.13 carry-over absorbed in Phases 40-90.*
