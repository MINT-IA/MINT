---
name: mint-backend-dev
description: Backend development for Mint FastAPI services. Use for services/backend/, API contracts, auth, sync, and data persistence.
---

# Mint Backend Development

## Scope

Work in `services/backend/`. API contract changes also update `tools/openapi/`
and any documented mobile contract.

## Read First

- `AGENTS.md`
- `CLAUDE.md`
- `.agents/skills/mint-operating-gates/SKILL.md`
- `docs/data-flow.md` for profile/sync semantics.
- `docs/coach-tool-routing.md` before coach changes.

## Rules

- TDD first: failing backend test before implementation.
- FastAPI/Pydantic v2 conventions.
- No auth/session fallback that can resurrect deleted accounts.
- No profile bootstrap that silently creates product-ready data.
- No financial calculation unless backend owns that L2-L4 layer.
- No compliance or legal claim without cited source.

## Minimum Verification

From `services/backend/`:

```bash
ruff check .
python -m pytest tests/ -q
```

For auth/delete/profile changes, include a mobile contract or runtime gate that
proves the app cannot re-enter with stale credentials or stale profile state.
