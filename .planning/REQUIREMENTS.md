# Requirements: MINT v2.14 « Living MINT »

**Defined:** 2026-05-06
**Core Value:** Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, reçoit une réponse qui le surprend, crée un compte pour ne pas perdre ça, et revient chaque mois parce que MINT sait des choses que personne d'autre ne sait sur sa vie financière.

**Source artefacts :**
- `.planning/MILESTONE-MVP.md` (architecture cible MASTERPLAN-aligned)
- `.planning/MILESTONE-MVP-PERIMETER.md` (« living MVP » 6-panel synthesis)
- `.planning/decisions/2026-05-06-test-theater-post-mortem-doctrine.md`
- `docs/USER_WALKTHROUGH_2026-05-06.md` (23 bugs)

---

## v1 Requirements (this milestone)

### Compliance — closing post-walkthrough audit gaps

- [ ] **COMP-01** : Coach message audit log table with 10y retention emit insert hooks in `coach_chat.py` + `anonymous_chat.py` per OAR-G art. 24 + FINMA Guidance 8/2024 §VI (closes BUG #18 P0)
- [ ] **COMP-02** : Eclairage prompt locale branching DE/IT/EN/ES/PT in `anonymous_eclairage_prompt.py` per FinSA art. 8 al. 1 let. d (closes BUG #20 P1)
- [ ] **COMP-03** : 5 simulators (`simulator_3a`, `divorce`, `frontalier`, `compound`, `leasing`) gain `ConfidenceBadge` rendering per CLAUDE.md règle 9 (closes BUG #21 P1)
- [ ] **COMP-04** : FATCA pre-emission gating in coach LLM call when `archetype == expat_us` AND topic ∈ {3a, PFIC, treaty} (closes BUG #22 P1)
- [ ] **COMP-05** : EN locale legal text « LSFin » sweep → « FinSA » across ~60 ARB strings + flutter gen-l10n (closes BUG #12 P3)
- [ ] **COMP-06** : `benchmark_service.dart:118` literal `7000` → `pilier3aPlafondAvecLpp` constant (closes BUG #23 P2)

### Documents — vault upload integration

- [ ] **DOCS-01** : `LppExtractedFields → List<ExtractedField>` typed converter in CoachProfileProvider (new method `updateFromLppExtractedFields`) — closes BUG #4 P0
- [ ] **DOCS-02** : `documents_screen.dart:_pickAndUpload` calls converter post-upload to merge fields into CoachProfile + invalidate confidence + trigger Cap recompute
- [ ] **DOCS-03** : Idempotency-Key persistence via SHA256 of file bytes (not random UUID per call) so retries dedupe — fixes architecture audit concern #4 idempotency

### Vivant — proactive primitives (Cleo parity)

- [ ] **VIVANT-01** : `ProactiveTriggerService` schedules push notifications via `flutter_local_notifications` for 6 of 8 trigger types (paie, doc complete, confidence delta, JITAI dates, lifecycle change, return-after-7d) — closes BUG #5 P0
- [ ] **VIVANT-02** : Cross-session opener — on `CoachChatScreen` open, prepend last `CapMemory` outcome + `ConversationMemoryService` summary so chat never starts cold (Cleo 3.0 parity)
- [ ] **VIVANT-03** : `CoachInterruptBanner` rendered from `coach_chat_screen.dart` listening to `state.activeNudges` (currently 0 call sites — closes facade audit finding #2)
- [ ] **VIVANT-04** : Persona toggle « Calme / Direct / Sans filtre » migrated from Coach screen chips to a Settings/IA panel with persistent SharedPreferences flag — already partially shipped, complete the wiring

### Test infrastructure — closing test theater per doctrine

- [ ] **TEST-01** : promptfoo eval suite (160 prompts × 4 archetypes) GitHub Action merge-blocking gate per doctrine W2
- [ ] **TEST-02** : Pact mobile↔backend consumer-driven contract on `/anonymous/chat`, `/coach/chat`, `/documents/upload`, `/onboarding/premier-eclairage`
- [ ] **TEST-03** : `alembic check` + forward+rollback verification in CI (closes Sentry « column does not exist » class of bug)
- [ ] **TEST-04** : testcontainers-Postgres in backend pytest fixtures (replaces sqlite for migration-sensitive tests)
- [ ] **TEST-05** : pytest-recording (VCR.py) cassettes for Anthropic in `services/backend/tests/cassettes/` + nightly rewrite cron

### Production observability

- [ ] **OBS-01** : Sentry release-health alert : crash-free sessions < 99.5% pages PagerDuty/Slack
- [ ] **OBS-02** : Checkly synthetics on 4 staging endpoints (anon-chat, auth-login, documents-upload, health) with 5-min cron
- [ ] **OBS-03** : Sentry events tag every coach response with `eval_score`, `banned_term_hit`, `eclairage_kind` per doctrine W4

### MVP ship gate

- [ ] **SHIP-01** : Maestro suite E2E (login → /onb → /home → /mon-argent → /budget/setup → /coach/chat → /documents/upload → /explorer/fiscalite levier) green on iPhone 17 Pro + iPhone SE + iPad mini
- [ ] **SHIP-02** : 5 testers TestFlight Internal NDA cohort recruited (5 amis Suisse FR), banner « pré-conformité » + 24h soak ≥ 99.5% crash-free
- [ ] **SHIP-03** : Compliance Control Matrix `docs/compliance/CONTROL_MATRIX.md` (FinSA art. 7/8/9/12/13/16 → control → test ID → last green commit) ≥ 95% coverage
- [ ] **SHIP-04** : 1-hour paid review by Swiss fintech counsel (Pestalozzi / Lenz & Staehelin / Vischer ; CHF 800-1'200) with written sign-off

---

## v2 Requirements (deferred)

### Bank linking (Cleo's revenue engine — not MVP)

- **BANK-01** : Open Banking CH aggregator integration (Klarna Kosma / Yapily) — 80h, defer
- **BANK-02** : Tx categorization + recurring detection — depends on BANK-01
- **BANK-03** : Tx-delta proactive push (full Cleo parity) — depends on BANK-01

### Voice (Cleo Memory shipped July 2025 — not MVP)

- **VOICE-01** : STT/TTS provider integration in `VoiceService` (currently stub) — 30h, defer
- **VOICE-02** : Voice persona « calme suisse » with Apple-grade audio — depends on VOICE-01

### Top 10 Suisse coverage

- **T10-01** to **T10-11** : end-to-end flows for the 11 « Top 10 Suisse » situations per MASTERPLAN §2. v2.14 covers 3-4 ; the rest deferred.

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Cash advances (« Cleo Plus » equivalent) | Lending license + risk model, MINT identity = lucidité not lending |
| Cross-tenant features | Single-user app for MVP |
| Open Banking outside CH | Swiss-only target market |
| Custom advisor matching | « Expert tier » deferred to v3.x post-PMF |
| Form pre-fill agent | « Agent autonome » deferred per MASTERPLAN §3 |
| Dark mode | Brand discipline (calm) ; defer |
| Apple Watch app | Mobile-first, watch later |

---

## Traceability

| Requirement | Phase | Status |
|---|---|---|
| VIVANT-01 | Phase 91 | Pending |
| VIVANT-02 | Phase 91 | Pending |
| VIVANT-03 | Phase 91 | Pending |
| VIVANT-04 | Phase 91 | Pending |
| DOCS-01 | Phase 92 | Pending |
| DOCS-02 | Phase 92 | Pending |
| DOCS-03 | Phase 92 | Pending |
| COMP-01 | Phase 93 | Pending |
| COMP-03 | Phase 93 | Pending |
| COMP-04 | Phase 93 | Pending |
| COMP-02 | Phase 94 | Pending |
| COMP-05 | Phase 94 | Pending |
| COMP-06 | Phase 94 | Pending |
| TEST-01 | Phase 95 | Pending |
| TEST-02 | Phase 95 | Pending |
| TEST-03 | Phase 95 | Pending |
| TEST-04 | Phase 95 | Pending |
| TEST-05 | Phase 95 | Pending |
| OBS-01 | Phase 96 | Pending |
| OBS-02 | Phase 96 | Pending |
| OBS-03 | Phase 96 | Pending |
| SHIP-01 | Phase 97 | Pending |
| SHIP-02 | Phase 97 | Pending |
| SHIP-03 | Phase 97 | Pending |
| SHIP-04 | Phase 97 | Pending |

**Coverage:**
- v1 requirements: 25 total
- Mapped to phases: 25 ✓
- Unmapped: 0 ✓

---

*Requirements defined: 2026-05-06*
*Last updated: 2026-05-06 after gsd-roadmapper traceability fill (Phases 91-97)*
