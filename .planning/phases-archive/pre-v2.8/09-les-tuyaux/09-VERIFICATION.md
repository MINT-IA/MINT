---
phase: 09-les-tuyaux
verified: 2026-04-12T10:15:00Z
status: human_needed
score: 5/5 must-haves verified
gaps: []
deferred: []
human_verification:
  - test: "Deploy to Railway staging twice consecutively and verify RAG corpus count is identical"
    expected: "Education insert count is preserved across redeploys (ChromaDB persist volume survives)"
    why_human: "Requires Railway deployment infrastructure — cannot verify volume persistence locally"
  - test: "Verify Railway Root Directory is set to / (repo root) in the Railway Dashboard"
    expected: "Docker build context resolves from repo root so COPY education/inserts/ works"
    why_human: "Railway Dashboard configuration is external to the codebase"
  - test: "Set CHROMADB_PERSIST_DIR=/data/chromadb in Railway env vars and verify startup logs"
    expected: "RAG vector store: N documents (persist_dir=/data/chromadb) in startup logs"
    why_human: "Requires Railway environment variable configuration and log inspection"
---

# Phase 9: Les tuyaux Verification Report

**Phase Goal:** Backend is stable on Railway with persistent RAG corpus, fail-fast guards, and bounded agent loop — deploys survive restarts, crashes are loud not silent
**Verified:** 2026-04-12T10:15:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Railway staging deploy with SQLite DATABASE_URL crashes at startup with a clear RuntimeError | VERIFIED | `config.py:109-118` — guard raises RuntimeError with "DATABASE_URL must point to PostgreSQL". Test `test_sqlite_failfast_raises_in_staging` passes via subprocess. |
| 2 | RAG corpus persists across two consecutive Railway deploys | VERIFIED (code) | `config.py:20` — CHROMADB_PERSIST_DIR configurable, `main.py:217-219` uses `settings.CHROMADB_PERSIST_DIR`, Dockerfile `mkdir -p /data/chromadb`. Needs Railway deploy to confirm volume mount. |
| 3 | Agent loop returns a graceful timeout message after 55s instead of 502 | VERIFIED | `coach_chat.py:1280-1308` — `asyncio.wait_for` wraps `_run_agent_loop` with 55s deadline, catches `TimeoutError`, returns French message. Test `test_agent_loop_total_timeout` passes. |
| 4 | Education inserts accessible inside Docker container and auto-ingested at startup | VERIFIED (code) | Dockerfile line 45: `COPY education/inserts/ /app/education/inserts/`, `main.py:224-229` Docker-first path with local fallback. 43 files in `education/inserts/`. |
| 5 | Missing OPENAI_API_KEY produces a startup warning | VERIFIED | `config.py:120-130` — warning logged when OPENAI_API_KEY empty in staging/production. Test `test_openai_key_warning_in_staging` passes. |

**Score:** 5/5 truths verified (code-level)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `services/backend/app/core/config.py` | SQLite fail-fast + CHROMADB_PERSIST_DIR + OPENAI_API_KEY | VERIFIED | Lines 20, 23, 109-130 — all three features present and substantive |
| `services/backend/app/main.py` | ChromaDB uses settings.CHROMADB_PERSIST_DIR, education path resolves in Docker | VERIFIED | Lines 217-229 — configurable persist_dir, Docker-first education path with fallback |
| `services/backend/Dockerfile` | Multi-stage build with education inserts from repo root | VERIFIED | Explicit COPY paths, `COPY education/inserts/`, `mkdir -p /data/chromadb`, no blind `COPY . .` |
| `services/backend/railway.json` | dockerfilePath to services/backend/Dockerfile | VERIFIED | `"dockerfilePath": "services/backend/Dockerfile"` — repo-root build context |
| `services/backend/tests/test_config_guards.py` | Tests for SQLite fail-fast and OPENAI_API_KEY warning | VERIFIED | 8 tests, all pass (subprocess-based for module-level guards) |
| `services/backend/app/api/v1/endpoints/coach_chat.py` | asyncio.wait_for wrapping agent loop + per-iteration timeout | VERIFIED | Lines 995, 1280 — two asyncio.wait_for calls, constants at 55s/25s, MAX_ITERATIONS=3 |
| `services/backend/tests/test_agent_loop.py` | Timeout behavior tests | VERIFIED | 27 tests total (24 existing + 3 new), all pass |
| `.dockerignore` | Repo-root exclusions | VERIFIED | Excludes .git, apps/mobile, docs, .planning; includes `!education/inserts/*.md` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `main.py` | `config.py` | `settings.CHROMADB_PERSIST_DIR` | WIRED | Line 217: `persist_dir = settings.CHROMADB_PERSIST_DIR` |
| `Dockerfile` | `education/inserts/` | COPY directive | WIRED | Line 45: `COPY education/inserts/ /app/education/inserts/` |
| `coach_chat.py (endpoint)` | `coach_chat.py (_run_agent_loop)` | `asyncio.wait_for` | WIRED | Line 1280: `asyncio.wait_for(_run_agent_loop(...), timeout=AGENT_LOOP_DEADLINE_SECONDS)` |
| `coach_chat.py (_run_agent_loop)` | `orchestrator.query` | `asyncio.wait_for` per-iteration | WIRED | Line 995: `asyncio.wait_for(orchestrator.query(...), timeout=AGENT_ITERATION_TIMEOUT_SECONDS)` |

### Data-Flow Trace (Level 4)

Not applicable — Phase 9 artifacts are infrastructure (config guards, Docker build, timeouts), not dynamic data rendering components.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Config guard tests pass | `pytest tests/test_config_guards.py -v` | 8/8 passed | PASS |
| Agent loop tests pass | `pytest tests/test_agent_loop.py -v` | 27/27 passed | PASS |
| MAX_AGENT_LOOP_ITERATIONS == 3 | Import + assert | Confirmed in test | PASS |
| AGENT_LOOP_DEADLINE_SECONDS == 55 | grep coach_chat.py | Line 567 confirmed | PASS |
| AGENT_ITERATION_TIMEOUT_SECONDS == 25 | grep coach_chat.py | Line 568 confirmed | PASS |
| Commits exist | git log for 3 hashes | All 3 verified | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| INFRA-01 | 09-01-PLAN | SQLite fail-fast RuntimeError in staging/production | SATISFIED | `config.py:109-118`, test `test_sqlite_failfast_raises_in_staging` |
| INFRA-02 | 09-01-PLAN | ChromaDB persist_directory on Railway volume mount | SATISFIED | `config.py:20`, `main.py:217-219`, Dockerfile `mkdir -p /data/chromadb` |
| INFRA-03 | 09-01-PLAN | Education inserts COPY'd into Docker image | SATISFIED | Dockerfile line 45, `main.py:224-229` Docker-first path |
| INFRA-04 | 09-02-PLAN | Agent loop 55s asyncio.wait_for + graceful timeout | SATISFIED | `coach_chat.py:1280-1308`, test `test_agent_loop_total_timeout` |
| INFRA-05 | 09-01-PLAN | OPENAI_API_KEY in Settings with startup warning | SATISFIED | `config.py:23,120-130`, test `test_openai_key_warning_in_staging` |

All 5 requirements mapped to Phase 9 in REQUIREMENTS.md are satisfied. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | No anti-patterns found in modified files |

**Note:** Education inserts count is 43 files in `education/inserts/`. REQUIREMENTS.md says "103 docs" and roadmap SC says "103 docs". The PLAN and SUMMARY say "43 files". This is a documentation inconsistency (43 files may produce more chunks after ingestion), not a code issue — the COPY directive and path resolution are correct regardless of file count.

### Human Verification Required

### 1. Railway Volume Persistence

**Test:** Deploy to Railway staging twice consecutively. Check startup logs for RAG corpus count after each deploy.
**Expected:** Education insert count is identical before and after redeploy (ChromaDB persist volume at /data/chromadb survives).
**Why human:** Requires Railway deployment infrastructure and volume mount configuration that cannot be verified locally.

### 2. Railway Root Directory Configuration

**Test:** Verify Railway Root Directory is set to `/` (repo root) in the Railway Dashboard, not `services/backend/`.
**Expected:** Docker build context resolves from repo root so `COPY education/inserts/` and `COPY services/backend/...` work correctly.
**Why human:** Railway Dashboard configuration is external to the codebase.

### 3. Railway Environment Variables

**Test:** Set `CHROMADB_PERSIST_DIR=/data/chromadb` in Railway env vars and check startup logs.
**Expected:** Startup log shows "RAG vector store: N documents (persist_dir=/data/chromadb)" confirming the env override is active.
**Why human:** Requires Railway environment variable configuration and log inspection.

### Gaps Summary

No code-level gaps found. All 5 roadmap success criteria are satisfied at the code level. All 5 INFRA requirements are implemented with tests passing.

Three items require human verification on Railway infrastructure: volume persistence across deploys, Root Directory configuration, and CHROMADB_PERSIST_DIR env var override. These are infrastructure deployment concerns that cannot be tested locally.

---

_Verified: 2026-04-12T10:15:00Z_
_Verifier: Claude (gsd-verifier)_
