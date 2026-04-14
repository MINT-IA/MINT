# 14 — Infrastructure Audit Findings (2026-04-12)

> **Context**: 3 parallel audits ran by specialized agents on 2026-04-12.
> **Purpose**: Single source of truth for all infrastructure, pipes, and navigation
> findings. Any future session working on fixes MUST read this file first.
> **Total findings**: 32 (11 P0, 8 P1, 7 P2, 6 P3)

---

## Proposed milestone structure

**Name**: MINT v2.4 — Fondation : tuyaux, connexions, navigation
**Goal**: Un humain externe peut ouvrir MINT sur son iPhone, naviguer sans etre
piege, uploader un document, recevoir un premier eclairage en 4 couches, poser
une question au coach, et recevoir une reponse pertinente basee sur ses donnees.
Zero crash. Zero 404. Zero boucle. Zero feature morte visible.

**4 phases**:
- Phase 1 — Les tuyaux (backend infra) : 2-3 jours CC
- Phase 2 — Les connexions (front-back) : 2-3 jours CC
- Phase 3 — La navigation (architecture) : 5-7 jours CC
- Phase 4 — La preuve (validation end-to-end) : 3-5 jours humain

---

## P0 — App crash / user bloque / feature morte (11 findings)

### From Infra Backend Audit

**P0-INFRA-1: DATABASE_URL fallback SQLite = data loss**
- File: `services/backend/app/core/config.py:17`
- Issue: DATABASE_URL defaults to `sqlite:///./mint.db`. If Railway env var
  missing, app silently uses ephemeral SQLite. All user data lost on restart.
- Fix: Add fail-fast guard — if ENVIRONMENT in (production, staging) and
  DATABASE_URL starts with sqlite, raise RuntimeError.
- Phase: 1

**P0-INFRA-2: RAG corpus vide apres chaque deploy**
- File: `services/backend/app/main.py:215-219`
- Issue: ChromaDB persist_directory is relative path on ephemeral Railway
  filesystem. Lost on every deploy. Auto-ingest looks for education/inserts
  at ../../education/inserts which is outside Docker build context.
- Fix: Mount Railway persistent volume OR copy education/inserts into Docker
  image and fix the path.
- Phase: 1

### From Navigation Audit

**P0-NAV-1: AUCUN SHELL N'EXISTE**
- File: `apps/mobile/lib/app.dart` (entire router, 143 routes)
- Issue: Zero ShellRoute, zero BottomNavigationBar, zero tabs. Specs say
  "3 tabs + ProfileDrawer". Reality: zero tabs. App is single chat screen
  with no visible way to discover 67+ screens.
- Fix: Implement StatefulShellRoute with persistent chat + visible navigation.
- Phase: 3

**P0-NAV-2: ProfileDrawer construit mais JAMAIS monte**
- File: `apps/mobile/lib/widgets/profile_drawer.dart` (280 lines, 0 imports)
- Issue: Widget exists, fully built. Zero imports anywhere. CoachChatScreen
  has no endDrawer. Profile, documents, settings, logout all inaccessible.
- Fix: Add endDrawer to shell scaffold + icon button to open it.
- Phase: 3

**P0-NAV-3: Back button = boucle infinie**
- File: `apps/mobile/lib/screens/coach/coach_chat_screen.dart:1377`
- Issue: safePop(context) when stack empty → context.go('/coach/chat') → same
  screen. User trapped.
- Fix: Fallback to '/' instead of '/coach/chat'. With shell, hide back on root.
- Phase: 3

**P0-NAV-4: /profile redirects to /coach/chat**
- File: `apps/mobile/lib/app.dart:639-644`
- Issue: Route /profile exact match → redirect to /coach/chat. Tapping
  "Mon profil" in drawer dumps to chat.
- Fix: Redirect /profile to /profile/bilan instead.
- Phase: 3

### From Front-Back Pipes Audit

**P0-PIPE-1: URL double-prefix sendScanConfirmation → 404**
- File: `apps/mobile/lib/services/document_service.dart:1086`
- Issue: Builds `$baseUrl/api/v1/documents/scan-confirmation` but baseUrl
  already ends with /api/v1. Actual URL: .../api/v1/api/v1/... → 404.
- Impact: Confirmed scan data never syncs to backend.
- Fix: Remove /api/v1 from path. Use `$baseUrl/documents/scan-confirmation`.
- Phase: 2

**P0-PIPE-2: URL double-prefix extractWithVision → 404**
- File: `apps/mobile/lib/services/document_service.dart:1125`
- Issue: Same double-prefix bug for Vision extraction endpoint.
- Impact: Claude Vision OCR never reaches backend.
- Fix: Same pattern fix.
- Phase: 2

**P0-PIPE-3: URL double-prefix fetchPremierEclairage → 404**
- File: `apps/mobile/lib/services/document_service.dart:1169`
- Issue: Same double-prefix bug for premier eclairage.
- Impact: THE core feature (4-layer insight) never loads after document scan.
- Fix: Same pattern fix.
- Phase: 2

**P0-PIPE-4: URL double-prefix coach sync-insight → 404**
- File: `apps/mobile/lib/services/memory/coach_memory_service.dart:80`
- Issue: Same double-prefix bug for insight sync.
- Impact: Coach insights never sync to backend RAG. Memory is local-only.
- Fix: Same pattern fix.
- Phase: 2

**P0-PIPE-5: Double-prefix + DELETE endpoint missing**
- File: `apps/mobile/lib/services/memory/coach_memory_service.dart:106`
- Issue: (1) Double-prefix same as above. (2) DELETE /coach/sync-insight/{id}
  does not exist on backend.
- Impact: Pruned insights persist in RAG forever (stale data).
- Fix: Fix URL + create backend endpoint.
- Phase: 2

---

## P1 — Feature cassee (8 findings)

**P1-INFRA-1: Agent loop timeout**
- File: `services/backend/app/api/v1/endpoints/coach_chat.py:929-1002`
- Issue: Multi-iteration Claude calls (3x 20-30s each) exceed Railway 60s
  timeout → 502 Bad Gateway.
- Fix: asyncio.wait_for() with 50s total deadline.
- Phase: 1

**P1-INFRA-2: OPENAI_API_KEY not in config**
- File: `services/backend/app/services/rag/insight_embedder.py:49-50`
- Issue: Required for embeddings but not documented/validated in Settings.
- Fix: Add to config.py Settings with startup warning.
- Phase: 1

**P1-INFRA-3: Education inserts path broken in Docker**
- File: `services/backend/app/main.py:217-219`
- Issue: Path ../../education/inserts resolves outside Docker container.
- Fix: Copy education/ into Docker image or fix build context.
- Phase: 1

**P1-NAV-1: safePop 40 call sites all dump to chat**
- File: `apps/mobile/lib/services/navigation/safe_pop.dart:12`
- Issue: 40 screens use safePop with fallback /coach/chat. Back from anywhere
  teleports to chat.
- Fix: Create MintNav with typed fallbacks per screen category.
- Phase: 3

**P1-NAV-2: 6 zombie screens still accessible**
- Files: achievements, score_reveal, cockpit, annual_refresh, portfolio, ask_mint
- Issue: Marked deleted in docs but routes + files still exist.
- Fix: Delete files + routes, add redirects.
- Phase: 3

**P1-NAV-3: 7 Explorer hubs all redirect to /coach/chat**
- File: `apps/mobile/lib/app.dart:229-236`
- Issue: /explore/retraite, /famille, etc. all → /coach/chat.
- Fix: Build Explorer surface OR redirect to specific screens.
- Phase: 3

**P1-PIPE-1: camelCase mismatch kills tool calling**
- File: `apps/mobile/lib/services/coach/coach_chat_api_service.dart:128-150`
- Issue: Backend sends toolCalls (camelCase), Flutter reads tool_calls (snake).
  Key doesnt exist → tool calls silently dropped.
- Impact: Coach tool calling (navigate, simulate) is dead for server-key chat.
- Fix: Read json['toolCalls'] instead of json['tool_calls'].
- Phase: 2

**P1-PIPE-2: api.mint.ch DNS unresolvable**
- File: `apps/mobile/lib/services/api_service.dart:110`
- Issue: Unreachable domain in URL candidates adds 2s latency.
- Fix: Remove from candidates until DNS configured.
- Phase: 2

---

## P2 — Degrade (7 findings)

**P2-INFRA-1**: Migration naming inconsistency (cosmetic, no action needed)
**P2-INFRA-2**: CORS not configured for Flutter Web (mobile OK)
**P2-INFRA-3**: JWT fail-fast bypass if ENVIRONMENT not set
**P2-NAV-1**: 11 legacy redirect shims (backward compat, low impact)
**P2-NAV-2**: /score-reveal builds CoachChatScreen outside router
**P2-PIPE-1**: No staging URL in Flutter URL candidates
**P2-PIPE-2**: 3 document_service methods silently swallow errors

---

## P3 — Tech debt (6 findings)

**P3-INFRA-1**: [docling] extra not in Dockerfile (pdfplumber unavailable)
**P3-INFRA-2**: Base.metadata.create_all() redundant with Alembic in PostgreSQL
**P3-NAV-1**: /budget route missing parentNavigatorKey
**P3-NAV-2**: safePop deprecation announced, never migrated (40 call sites)
**P3-PIPE-1**: Inconsistent URL construction in document_service.dart
**P3-PIPE-2**: Coach chat is synchronous REST (no SSE streaming)

---

## Quick reference: fixes already applied in this session

- **DONE** (GSD quick 260412-dr1): Hardened _get_hybrid_search(),
  _get_vector_store(), _get_orchestrator() in coach_chat.py to catch all
  exceptions and fall back to _NoRagOrchestrator. The 2 original Sentry
  errors (document_embeddings missing, RAG deps not installed) are fixed.
  Commits: 2f65bf01, 11093e46.

---

## How to use this document

1. Create a GSD milestone with 4 phases matching the structure above
2. Each finding has a Phase assignment (1-4)
3. Fix in phase order: tuyaux → connexions → navigation → validation
4. Each fix = atomic commit with test
5. Gate between phases: verify the phase goal before starting the next
6. Phase 4 gate = real human completes walkthrough without help

This document is the REQUIREMENTS input for the milestone ROADMAP.
