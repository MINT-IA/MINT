---
phase: 09-les-tuyaux
plan: 01
subsystem: infra
tags: [railway, docker, chromadb, rag, config-guards, fail-fast]

# Dependency graph
requires: []
provides:
  - SQLite fail-fast guard (RuntimeError in staging/production)
  - Configurable CHROMADB_PERSIST_DIR setting (env var override)
  - OPENAI_API_KEY setting with startup warning
  - Education inserts baked into Docker image
  - Repo-root Docker build context with explicit COPY paths
affects: [10-les-connexions, railway-deploy]

# Tech tracking
tech-stack:
  added: []
  patterns: [fail-fast guards at module import, Docker repo-root build context, env-configurable paths]

key-files:
  created:
    - services/backend/tests/test_config_guards.py
    - .dockerignore
  modified:
    - services/backend/app/core/config.py
    - services/backend/app/main.py
    - services/backend/Dockerfile
    - services/backend/railway.json

key-decisions:
  - "Repo-root Docker build context to include education/inserts without symlinks"
  - "CHROMADB_PERSIST_DIR relative by default (dev), absolute override for Railway /data/chromadb"
  - "Subprocess-based testing for module-level fail-fast guards"

patterns-established:
  - "Fail-fast guard pattern: os.getenv check + RuntimeError at module level"
  - "Docker-first path resolution with local dev fallback"

requirements-completed: [INFRA-01, INFRA-02, INFRA-03, INFRA-05]

# Metrics
duration: 4min
completed: 2026-04-12
---

# Phase 9 Plan 1: Backend Infra Hardening Summary

**SQLite fail-fast guard, configurable ChromaDB persistence, education corpus baked into Docker image, OPENAI_API_KEY startup warning**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-12T09:12:11Z
- **Completed:** 2026-04-12T09:16:43Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- SQLite DATABASE_URL now raises RuntimeError in staging/production, preventing silent data loss on Railway
- ChromaDB persist directory configurable via CHROMADB_PERSIST_DIR env var (default "data/chromadb", Railway "/data/chromadb")
- Education inserts (43 markdown files) baked into Docker image at /app/education/inserts/ with local dev fallback
- Dockerfile rewritten with explicit COPY paths from repo root (no more blind COPY . .)
- OPENAI_API_KEY declared in Settings with startup warning when missing in prod/staging
- 8 tests covering all guard scenarios pass, 5056 existing tests unaffected

## Task Commits

Each task was committed atomically:

1. **Task 1: Add fail-fast guards and new Settings fields** - `382f349c` (feat)
2. **Task 2: Fix ChromaDB persist path, education Docker COPY, build context** - `a0502559` (feat)

## Files Created/Modified
- `services/backend/app/core/config.py` - Added CHROMADB_PERSIST_DIR, OPENAI_API_KEY fields + SQLite/OpenAI guards
- `services/backend/app/main.py` - _auto_ingest_rag uses settings.CHROMADB_PERSIST_DIR, Docker-first education path
- `services/backend/Dockerfile` - Repo-root build context, explicit COPY, education inserts, /data/chromadb volume dir
- `services/backend/railway.json` - dockerfilePath updated to services/backend/Dockerfile
- `services/backend/tests/test_config_guards.py` - 8 tests for SQLite fail-fast, OpenAI warning, ChromaDB setting
- `.dockerignore` - Repo-root context exclusions (Flutter app, docs, secrets, .git)

## Decisions Made
- **Repo-root build context**: Railway builds from repo root so Dockerfile can COPY education/inserts/ directly. This requires Railway Root Directory set to "/" in dashboard.
- **Subprocess testing for guards**: Module-level RuntimeError guards cannot be tested with importlib.reload safely; subprocess approach is deterministic.
- **Relative default for CHROMADB_PERSIST_DIR**: "data/chromadb" works in local dev (relative to backend dir), Railway overrides to "/data/chromadb" (absolute, volume mount).

## Deviations from Plan

None - plan executed exactly as written.

## User Setup Required

**Railway Dashboard change required** (post-deploy):
- Set Railway Root Directory to `/` (repo root) instead of `services/backend/`
- Set `CHROMADB_PERSIST_DIR=/data/chromadb` in Railway environment variables
- Verify education inserts are present: check startup logs for "Auto-ingested N document chunks"

## Threat Flags

None found.

## Next Phase Readiness
- Backend infra hardened: SQLite rejected, ChromaDB persistent, education corpus available
- Ready for Phase 10 (Les connexions): front-back URL wiring can proceed on stable backend
- Railway dashboard change (Root Directory = /) must be done before first deploy with this Dockerfile

---
*Phase: 09-les-tuyaux*
*Completed: 2026-04-12*
