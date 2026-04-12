# Requirements: MINT v2.4 — Fondation

**Defined:** 2026-04-12
**Core Value:** Un humain externe peut ouvrir MINT sur son iPhone, naviguer sans etre piege, uploader un document, recevoir un premier eclairage, poser une question au coach, et recevoir une reponse pertinente basee sur ses donnees. Zero crash. Zero 404. Zero boucle. Zero feature morte visible.

## v1 Requirements (milestone v2.4)

Requirements derived from `.planning/architecture/14-INFRA-AUDIT-FINDINGS.md` (32 findings) + research synthesis.

### Backend Infrastructure (INFRA)

- [ ] **INFRA-01**: If ENVIRONMENT is `production` or `staging` and DATABASE_URL starts with `sqlite`, app raises RuntimeError at startup instead of silently using ephemeral SQLite (P0-INFRA-1)
- [ ] **INFRA-02**: ChromaDB persist_directory points to a Railway persistent volume mount (`/data/chromadb`) that survives deploys, verified by deploying twice and confirming corpus count is preserved (P0-INFRA-2)
- [ ] **INFRA-03**: Education inserts (103 docs) are copied into the Docker image via `COPY education/inserts/ /app/education/inserts/` and the auto-ingest path in `main.py` resolves correctly inside the container (P0-INFRA-2, P1-INFRA-3)
- [ ] **INFRA-04**: Agent loop in `coach_chat.py` is wrapped with `asyncio.wait_for(55s)` so partial results are returned gracefully instead of a 502 Bad Gateway (P1-INFRA-1)
- [ ] **INFRA-05**: OPENAI_API_KEY is declared in `config.py` Settings with a startup warning if missing, so embedding failures are diagnosed at boot not at first user request (P1-INFRA-2)

### Front-Back Connections (PIPE)

- [ ] **PIPE-01**: `document_service.dart:sendScanConfirmation` URL no longer double-prefixes `/api/v1` — request reaches the backend endpoint and returns 200 (P0-PIPE-1)
- [ ] **PIPE-02**: `document_service.dart:extractWithVision` URL no longer double-prefixes — Claude Vision OCR reaches backend (P0-PIPE-2)
- [ ] **PIPE-03**: `document_service.dart:fetchPremierEclairage` URL no longer double-prefixes — 4-layer premier eclairage loads after document scan (P0-PIPE-3)
- [ ] **PIPE-04**: `coach_memory_service.dart:syncInsight` URL no longer double-prefixes — coach insights sync to backend RAG (P0-PIPE-4)
- [ ] **PIPE-05**: `coach_memory_service.dart:deleteInsight` URL no longer double-prefixes AND backend DELETE `/coach/sync-insight/{id}` endpoint exists (P0-PIPE-5)
- [ ] **PIPE-06**: `coach_chat_api_service.dart` reads `json['toolCalls']` (camelCase) instead of `json['tool_calls']` — tool calling works on server-key path, verified by integration test (P1-PIPE-1)
- [ ] **PIPE-07**: `api.mint.ch` removed from URL candidates in `api_service.dart` — eliminates 2s latency from DNS resolution failure (P1-PIPE-2)
- [ ] **PIPE-08**: Staging Railway URL added to Flutter URL candidates so TestFlight builds can reach staging backend (P2-PIPE-1)

### Navigation Architecture (NAV)

- [ ] **NAV-01**: App has a `StatefulShellRoute` with 3 persistent tab branches (Aujourd'hui, Coach, Explorer) visible as a bottom navigation bar — user can switch tabs without losing state (P0-NAV-1)
- [ ] **NAV-02**: `ProfileDrawer` (280 lines, already built) is mounted as `endDrawer` on the shell scaffold with a visible icon button to open it — profile, documents, settings, logout are all accessible (P0-NAV-2)
- [ ] **NAV-03**: Back button on root tab screens does NOT navigate — no infinite loop. `safePop` fallback goes to shell root `/` instead of `/coach/chat` (P0-NAV-3)
- [ ] **NAV-04**: Route `/profile` redirects to `/profile/bilan` instead of `/coach/chat` — tapping "Mon profil" in drawer opens profile (P0-NAV-4)
- [ ] **NAV-05**: `safePop` replaced with `MintNav` that has typed fallbacks per screen category — back from any screen goes to a sensible parent, not always chat (P1-NAV-1)
- [ ] **NAV-06**: 6 zombie screens (achievements, score_reveal, cockpit, annual_refresh, portfolio, ask_mint) deleted — routes removed, files deleted, redirects added for deep links (P1-NAV-2)
- [ ] **NAV-07**: 7 Explorer hub routes (`/explore/retraite`, `/explore/famille`, etc.) resolve to real Explorer hub screens instead of redirecting to `/coach/chat` (P1-NAV-3)

### Validation (VALID)

- [ ] **VALID-01**: Cold start -> coach chat -> receive AI response with tool calling (navigate, simulate) working end-to-end on real iPhone
- [ ] **VALID-02**: Upload document -> OCR extraction -> premier eclairage 4-layer insight displayed — zero 404, zero silent failure
- [ ] **VALID-03**: Navigate all 3 tabs (Aujourd'hui, Coach, Explorer) — each loads, back button works, no infinite loops
- [ ] **VALID-04**: Open ProfileDrawer -> view profile, documents, settings -> logout -> confirm session cleared
- [ ] **VALID-05**: Explorer hubs (7) each show meaningful content, not redirects to chat
- [ ] **VALID-06**: Coach remembers context across messages (RAG corpus persisted, not lost on deploy)
- [ ] **VALID-07**: Back button from any screen returns to a sensible parent — zero teleportation to chat
- [ ] **VALID-08**: All 8 flows validated by creator (Julien) on real iPhone via `flutter run --release` with annotated screenshots committed to `.planning/walkthroughs/v2.4/`

## v2 Requirements (deferred)

### P2 Findings (tracked, not blocking)

- **P2-01**: CORS configuration for Flutter Web (mobile OK, web deferred)
- **P2-02**: JWT fail-fast bypass when ENVIRONMENT not set
- **P2-03**: 11 legacy redirect shims (backward compat, low impact)
- **P2-04**: /score-reveal builds CoachChatScreen outside router
- **P2-05**: 3 document_service methods silently swallow errors (partial fix in Phase 10 error handling)

### P3 Findings (tech debt)

- **P3-01**: [docling] extra not in Dockerfile (pdfplumber unavailable)
- **P3-02**: Base.metadata.create_all() redundant with Alembic
- **P3-03**: /budget route missing parentNavigatorKey
- **P3-04**: Coach chat synchronous REST (no SSE streaming)

## Out of Scope

Explicitly excluded for v2.4. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| New features (Monte Carlo UI, withdrawal sequencing) | Foundation milestone — fix plumbing only |
| Anonymous coach endpoint (v2.2 scope) | Depends on v2.4 foundation being solid first |
| i18n remaining ~120 strings | P2, not blocking core flows |
| SSE streaming for coach chat | P3 tech debt, sync REST works for now |
| Flutter Web CORS | Mobile-first, web deferred |
| Android-specific testing | iOS validation this milestone |
| Onboarding flow redesign | Chat-first is a design choice, not a bug |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 9 | Pending |
| INFRA-02 | Phase 9 | Pending |
| INFRA-03 | Phase 9 | Pending |
| INFRA-04 | Phase 9 | Pending |
| INFRA-05 | Phase 9 | Pending |
| PIPE-01 | Phase 10 | Pending |
| PIPE-02 | Phase 10 | Pending |
| PIPE-03 | Phase 10 | Pending |
| PIPE-04 | Phase 10 | Pending |
| PIPE-05 | Phase 10 | Pending |
| PIPE-06 | Phase 10 | Pending |
| PIPE-07 | Phase 10 | Pending |
| PIPE-08 | Phase 10 | Pending |
| NAV-01 | Phase 11 | Pending |
| NAV-02 | Phase 11 | Pending |
| NAV-03 | Phase 11 | Pending |
| NAV-04 | Phase 11 | Pending |
| NAV-05 | Phase 11 | Pending |
| NAV-06 | Phase 11 | Pending |
| NAV-07 | Phase 11 | Pending |
| VALID-01 | Phase 12 | Pending |
| VALID-02 | Phase 12 | Pending |
| VALID-03 | Phase 12 | Pending |
| VALID-04 | Phase 12 | Pending |
| VALID-05 | Phase 12 | Pending |
| VALID-06 | Phase 12 | Pending |
| VALID-07 | Phase 12 | Pending |
| VALID-08 | Phase 12 | Pending |

**Coverage:**
- v1 requirements: 28 total
- Mapped to phases: 28/28
- Unmapped: 0

---
*Requirements defined: 2026-04-12*
*Last updated: 2026-04-12 after roadmap creation (traceability populated)*
