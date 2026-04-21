# Phase 27-01 — Deviations log

## DEV-01 — Redis Python client not installed (architectural)

### What was discovered
The plan (27-01-PLAN Task 4/5/6/7) states:

> Feature flags via Redis polling ... Redis already in stack via rate_limit

This is **incorrect**. `slowapi` uses the `limits` library's storage URI
mechanism (`limits.aio.storage.RedisStorage`) internally when `REDIS_URL` is
set. No standalone `redis` or `coredis` Python package is installed in
`services/backend/pyproject.toml`. Verified locally:

```
$ python3 -c "import redis" → ModuleNotFoundError
$ python3 -c "import coredis" → ModuleNotFoundError
$ python3 -c "from limits.aio.storage import RedisStorage" → ok
```

Tasks 4 (TokenBudget), 5 (FlagsService), 6 (SLOMonitor), and 7 (Idempotency)
all require a direct Redis client for atomic INCRBY / GET / SET / TTL
operations. The `limits` transport is not a public-facing async Redis API.

### Why the plan assumption was wrong
The 27-01 planning phase conflated "slowapi stores rate-limit counters in
Redis" with "the backend has a reusable Redis client". Those are different
things: slowapi's storage is internal to the `limits` library and not
designed for custom key operations.

### Options

**Option A — add `redis>=5.0` dependency (recommended)**
- One line in `services/backend/pyproject.toml`
- Industry standard, stable, maintained by Redis Labs
- Supports async (`redis.asyncio`) with same API shape as the plan assumes
- Allows strict fail-open semantics as plan requires
- Wire size: ~600KB, zero runtime cost until first use
- **Risk**: 1 new dep but it was implicit in the plan anyway

**Option B — reuse `limits.aio.storage.RedisStorage`**
- No new dep
- API is NOT designed for user-level operations (only rate-limiter primitives)
- Would require wrapping private methods (brittle)
- **Risk**: high — would break on any `limits` version bump

**Option C — in-memory fallback only (no cross-instance sync)**
- No Redis at all, use `dict` + `asyncio.Lock`
- Works for single-worker Railway service
- **BREAKS** on multi-worker: each Gunicorn worker would have its own flag
  state, own budget, own idempotency cache → user might hit 3 different
  states on 3 successive requests
- **Risk**: high — production Railway runs with `gunicorn -w 2` minimum

### Recommended path
**Option A**. Add `redis>=5.0,<6.0` to `services/backend/pyproject.toml`,
create `app/core/redis_client.py` with fail-open async factory, and proceed
with Tasks 4-7 as planned. Document in 27-01-SUMMARY.md.

### Status
**HALTED for user decision** — do not proceed with Tasks 3-8 until this
deviation is acknowledged. Tasks 1 and 2 are committed and green.

---

## Commits landed so far

| Task | Commit  | Summary                                      |
| ---- | ------- | -------------------------------------------- |
| 1    | 9547203f | Agent loop reflective retry (content blocks) |
| 2    | 24ed5bdd | Tenacity retry for Anthropic 429/5xx/529     |

Both tests green: `pytest services/backend/tests/coach/ -q` → 51 passed.
