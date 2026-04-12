# Roadmap: MINT v2.4 — Fondation

## Milestones

- ✅ **v1.0 MVP** - Phases 1-8 (shipped 2026-03-20)
- ✅ **v2.0 Systeme Vivant** - Phases 1-6 (shipped 2026-04-07)
- ✅ **v2.1 Stabilisation** - Phase 7 (shipped 2026-04-07)

<details>
<summary>Previous milestones (v1.0, v2.0, v2.1) — see MILESTONES.md</summary>

All previous milestone phases (1-8) are documented in `.planning/MILESTONES.md`.
Phase numbering continues from v2.1's last phase (Phase 8).

</details>

## Overview

MINT compiles with 9256 tests passing but is non-functional for real users. The backend pipes are broken (RAG ephemeral, URLs 404, tool calling dead), there is zero navigation shell, and users are trapped on a single screen. This milestone fixes all plumbing in strict sequential order: backend infrastructure first, then front-back connections, then navigation architecture, then human validation on a real iPhone. Zero new features. Recovery only.

## Phases

**Phase Numbering:**
- Phases 9-12 belong to milestone v2.4 (continuing from v2.1 Phase 8)
- Decimal phases (9.1, 10.1): Urgent insertions if needed

- [ ] **Phase 9: Les tuyaux** - Backend infra hardening: SQLite fail-fast, RAG persistence, agent timeout, Docker paths
- [ ] **Phase 10: Les connexions** - Front-back wiring: 5x URL double-prefix, camelCase mismatch, DNS cleanup, staging URL
- [ ] **Phase 11: La navigation** - Shell architecture: 3-tab shell, ProfileDrawer, back button, zombie cleanup, Explorer hubs
- [ ] **Phase 12: La preuve** - End-to-end human validation on real iPhone, 8 flows, annotated screenshots

## Phase Details

### Phase 9: Les tuyaux
**Goal**: Backend is stable on Railway with persistent RAG corpus, fail-fast guards, and bounded agent loop — deploys survive restarts, crashes are loud not silent
**Depends on**: Nothing (first phase of v2.4)
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, INFRA-05
**Success Criteria** (what must be TRUE):
  1. Railway staging deploy with SQLite DATABASE_URL crashes at startup with a clear RuntimeError (not silent data loss)
  2. RAG corpus persists across two consecutive Railway deploys — education insert count is identical before and after redeploy
  3. Agent loop returns a partial response with a timeout message after 55s instead of a 502 Bad Gateway
  4. Education inserts (103 docs) are accessible inside the Docker container and auto-ingested at startup
  5. Missing OPENAI_API_KEY produces a startup warning in Railway logs (not a silent embedding failure on first user request)
**Plans**: 2 plans

Plans:
- [ ] 09-01-PLAN.md — Config guards (SQLite fail-fast, OPENAI_API_KEY) + RAG persistence (ChromaDB volume, education Docker path)
- [ ] 09-02-PLAN.md — Agent loop timeout (55s total deadline + 25s per-iteration cap)

### Phase 10: Les connexions
**Goal**: Every Flutter-to-backend API call reaches its endpoint and returns structured data — zero 404, zero silent failure, tool calling works on server-key path
**Depends on**: Phase 9
**Requirements**: PIPE-01, PIPE-02, PIPE-03, PIPE-04, PIPE-05, PIPE-06, PIPE-07, PIPE-08
**Success Criteria** (what must be TRUE):
  1. Document scan flow completes end-to-end: scan confirmation, Vision OCR extraction, and premier eclairage all return 200 from staging backend
  2. Coach insights sync to backend RAG and can be deleted — both syncInsight and deleteInsight return 200
  3. Tool calling works on server-key path: user sends a message, backend returns toolCalls array, Flutter parses and executes tools
  4. First API call to staging completes in under 3s (no 2s DNS timeout from dead api.mint.ch domain)
  5. TestFlight build can reach staging backend (staging Railway URL present in URL candidates)
**Plans**: TBD

Plans:
- [ ] 10-01: TBD

### Phase 11: La navigation
**Goal**: User can navigate MINT freely — 3 persistent tabs, ProfileDrawer for settings/profile/logout, working back button, no dead screens, Explorer hubs show real content
**Depends on**: Phase 10
**Requirements**: NAV-01, NAV-02, NAV-03, NAV-04, NAV-05, NAV-06, NAV-07
**Success Criteria** (what must be TRUE):
  1. User sees 3 tabs (Aujourd'hui, Coach, Explorer) as a bottom navigation bar and can switch between them without losing scroll position or chat state
  2. User can open ProfileDrawer from any tab, access profile/documents/settings/logout, and close it to return to previous tab
  3. Back button on any screen navigates to a sensible parent — never loops infinitely, never teleports to chat from unrelated screens
  4. All 7 Explorer hubs (/explore/retraite, /explore/famille, etc.) load real hub screens with meaningful content
  5. Tapping "Mon profil" in drawer opens /profile/bilan (not redirect to /coach/chat)
**Plans**: TBD
**UI hint**: yes

Plans:
- [ ] 11-01: TBD

### Phase 12: La preuve
**Goal**: Creator (Julien) cold-starts MINT on a real iPhone and completes 8 end-to-end flows without help — the only gate that matters
**Depends on**: Phase 11
**Requirements**: VALID-01, VALID-02, VALID-03, VALID-04, VALID-05, VALID-06, VALID-07, VALID-08
**Success Criteria** (what must be TRUE):
  1. Cold start to AI coach response with working tool calling completes without crash or error
  2. Document upload produces a 4-layer premier eclairage insight on screen (not a 404, not a spinner forever)
  3. All 3 tabs load, all 7 Explorer hubs show content, ProfileDrawer opens and every item navigates somewhere real
  4. Coach remembers context from previous messages (RAG corpus persisted, not empty after deploy)
  5. All 8 flows validated by Julien on real iPhone via flutter run --release, with annotated screenshots committed to .planning/walkthroughs/v2.4/
**Plans**: TBD

Plans:
- [ ] 12-01: TBD

## Progress

**Execution Order:**
Phases execute sequentially: 9 -> 10 -> 11 -> 12
Each phase must be deployed and verified before the next begins.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 9. Les tuyaux | v2.4 | 0/2 | Planning complete | - |
| 10. Les connexions | v2.4 | 0/TBD | Not started | - |
| 11. La navigation | v2.4 | 0/TBD | Not started | - |
| 12. La preuve | v2.4 | 0/TBD | Not started | - |

---
*Roadmap created: 2026-04-12*
*Last updated: 2026-04-12*
