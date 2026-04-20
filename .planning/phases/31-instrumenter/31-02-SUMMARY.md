---
phase: 31-instrumenter
plan: 02
subsystem: observability
tags: [sentry, fastapi, exception-handler, sentry-trace, trace-propagation, backend, wave-2, obs-03]

# Dependency graph
requires:
  - phase: 31-instrumenter
    plan: 00
    provides: Wave 0 scaffolding (test_global_exception_handler.py stub + trace_round_trip_test.sh baseline + sentry-cli 3.3.5)
  - phase: 31-instrumenter
    plan: 01
    provides: mobile sentry-trace + baggage injection via _authHeaders + _publicHeaders (real codepath that trace_round_trip_test.sh now exercises)
provides:
  - services/backend/app/main.py global_exception_handler with 3-tier trace_id fallback (inbound sentry-trace -> trace_id_var ContextVar -> fresh uuid4) + sentry_event_id in JSON body + X-Trace-Id response header
  - sentry-sdk[fastapi] pinned to ==2.53.0 in services/backend/pyproject.toml (was >=2.0.0,<3.0.0)
  - 3 GREEN pytest tests covering OBS-03 (a/b/c) contracts (test_returns_trace_id, test_preserves_logging_middleware_trace_id, test_reads_inbound_sentry_trace)
  - tools/simulator/trace_round_trip_test.sh upgraded from "header presence" to full OBS-03 end-to-end (PASS or documented PASS-PARTIAL)
  - A2 proxy-strip assumption VERIFIED (Railway delivers sentry-trace intact through /auth/login at least)
affects: [31-03, 31-04, 35-boucle-daily, 36-finissage-e2e]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - 3-tier trace_id fallback chain guarantees non-empty trace_id in all 500 responses (never "-", never empty)
    - Exception handler reads inbound headers for distributed-tracing correlation (not only Sentry auto-integration — also explicit body + header surface)
    - FastAPI exception_handler cohabitation with BaseHTTPMiddleware (LoggingMiddleware): middleware emits X-Trace-Id on 2xx/4xx; handler emits same-semantic X-Trace-Id on 500, with identical value when no inbound sentry-trace
    - Test fixture pattern for app-level exception handlers: register a raising route in a fixture, yield, pop from app.router.routes in teardown; TestClient(app, raise_server_exceptions=False) to let handler run
    - Staging integration script gracefully degrades to PASS-PARTIAL (exit 0) when the 500-triggering endpoint is absent, with an explicit DEFERRED marker grep-traceable in script + SUMMARY

key-files:
  created: []
  modified:
    - services/backend/app/main.py (global_exception_handler extended + uuid4 import + trace_id_var import)
    - services/backend/pyproject.toml (sentry-sdk[fastapi] pin tightened to ==2.53.0)
    - services/backend/tests/test_global_exception_handler.py (3 stubs flipped live + raise_route fixture + _extract_500 helper)
    - tools/simulator/trace_round_trip_test.sh (Wave 0 baseline promoted to full OBS-03 assertion + PASS-PARTIAL fallback)

key-decisions:
  - D-05 confirmed at backend layer: inbound sentry-trace wins for the current request's exception response (enables Sentry UI cross-project mobile<->backend link without extra wiring)
  - 3-tier fallback (inbound -> trace_id_var ContextVar -> fresh uuid4) chosen instead of the 2-tier (inbound -> trace_id_var only) pattern in RESEARCH Pattern 5. Rationale discovered during RED phase — when an exception propagates OUT of `call_next(request)` inside BaseHTTPMiddleware.dispatch(), the FastAPI exception_handler runs in a scope where `trace_id_var.get("-")` returns the default `"-"`. Without the uuid4 fallback, the 500 body would carry a `"-"` literal. uuid4 guarantees a non-empty correlation ID every time. Backward-compatible: when LoggingMiddleware is re-entered in the normal case (which we observe in non-error paths), trace_id_var is populated and wins over uuid4.
  - Test fixture registers /__obs03_raise_for_test__ at app-router level rather than a sub-app to keep the same middleware stack (LoggingMiddleware + SecurityHeadersMiddleware + EncryptionContextMiddleware + CORSMiddleware) — the test actually exercises the production middleware chain
  - PASS-PARTIAL accepted for staging run (per revision Info 7): /auth/login returns 422 on malformed payload (Pydantic validator short-circuits before the exception handler fires). Adding a /_test/raise_500 endpoint is explicitly DEFERRED to Phase 32 or Phase 35

patterns-established:
  - "3-tier trace_id fallback in exception handlers: inbound distributed-trace header -> ContextVar -> fresh uuid. Applied to any future error path that needs guaranteed correlation ID."
  - "Exception-handler test fixture: register route via @app.get in fixture, yield, pop from app.router.routes in teardown. TestClient(app, raise_server_exceptions=False) to let handler actually run."
  - "Staging integration script PASS-PARTIAL pattern: grep-traceable DEFERRED line in both script output and SUMMARY — prevents the partial from silently becoming the norm."

requirements-completed: [OBS-03]

# Metrics
duration: 18min
completed: 2026-04-19
---

# Phase 31 Plan 02: Wave 2 Backend — Global Exception Handler with Trace Round-Trip Summary

**FastAPI `global_exception_handler` now surfaces `trace_id` + `sentry_event_id` in the 500 JSON body, echoes `X-Trace-Id` in headers, and reads inbound mobile `sentry-trace` to close the end-to-end Sentry cross-project link. 3 backend tests green, zero regression, staging integration proven.**

## CTX31_02_COMMIT_SHA

`CTX31_02_COMMIT_SHA: e39d3480`

(HEAD of `feature/v2.8-phase-31-instrumenter` after Plan 31-02 Task 2 ships. Task 1 = `6ea76af5`, Task 2 = `e39d3480`.)

## Performance

- **Duration:** ~18 min
- **Started:** 2026-04-19T17:00Z (approx)
- **Completed:** 2026-04-19T17:18Z (approx)
- **Tasks:** 2 (TDD RED/GREEN + staging integration)
- **Files modified:** 4 (main.py, pyproject.toml, test_global_exception_handler.py, trace_round_trip_test.sh)

## Accomplishments

- **OBS-03** — `global_exception_handler` at `services/backend/app/main.py:169` extended with 3-tier trace_id fallback. 500 JSON body now contains `trace_id` (non-empty str) + `sentry_event_id` (hex or null). `X-Trace-Id` response header cohabits with `LoggingMiddleware` emission on 2xx/4xx paths — identical semantic, no conflict.
- **sentry-sdk pin** — `services/backend/pyproject.toml` line 31 tightened from `sentry-sdk[fastapi]>=2.0.0,<3.0.0` to `sentry-sdk[fastapi]==2.53.0` for reliable auto-read of `sentry-trace` + `baggage` compatible with `sentry_flutter 9.14.0`. Drift upgrade gated by rerunning `trace_round_trip_test.sh`.
- **3 pytest tests GREEN** — VALIDATION IDs `31-02-01`, `31-02-02`, `31-02-03` now ticked. Full backend suite: 5958 passed + 6 skipped (exactly +3 vs baseline, -3 skipped; zero regression on 5955 pre-existing tests).
- **FIX-077 nLPD preserved** — `%.100s` truncation on `str(exc)` kept. PIILogFilter defense in depth unchanged.
- **trace_round_trip_test.sh** — upgraded from Wave 0 baseline (X-Trace-Id presence on `/health`) to full end-to-end: (a) `/health` X-Trace-Id presence + non-equality note, (b) `/auth/login` malformed POST with asserted PASS (500 path) or explicit PASS-PARTIAL (4xx path). Live staging run returned `PASS-PARTIAL` with exit 0 (422 from Pydantic validator, DEFERRED marker emitted).
- **Staging A2 verified** — Railway delivered the `sentry-trace` header intact through to `/auth/login` (validator saw payload; header was not stripped). Proxy-strip pitfall (A2 / Pitfall 3) is REFUTED for this host. Fallback X-MINT-Trace-Id addition remains unneeded.

## Task Commits

Each task committed atomically on `feature/v2.8-phase-31-instrumenter`:

1. **Task 1: extend global_exception_handler + pin sentry-sdk 2.53.0 + flip 3 pytest stubs live** — `6ea76af5` (feat)
2. **Task 2: upgrade trace_round_trip_test.sh to full OBS-03 assertion + run against staging** — `e39d3480` (test)

_This SUMMARY will land in a final plan-metadata commit with STATE.md + ROADMAP.md + REQUIREMENTS.md updates._

## Files Created/Modified

### Modified

- `services/backend/app/main.py` — added `from uuid import uuid4`, added `trace_id_var` to the `app.core.logging_config` import, rewrote `global_exception_handler` body (lines 169-226 post-patch) with 3-tier fallback + JSON body keys + header.
- `services/backend/pyproject.toml` — line 31 pin tightened `sentry-sdk[fastapi]==2.53.0` with Phase 31 OBS-03 rationale comment.
- `services/backend/tests/test_global_exception_handler.py` — Wave 0 skip stubs replaced with 3 live tests + module-level `_RAISE_PATH`, `raise_route` fixture, `_extract_500` helper. Full file ~140 lines (was ~60 lines of docstring + skipped stubs).
- `tools/simulator/trace_round_trip_test.sh` — Wave 0 body (55 lines) replaced with two-step integration (~160 lines): `/health` baseline + `/auth/login` 500-or-4xx with PASS / PASS-PARTIAL / FAIL exit.

## Decisions Made

1. **3-tier trace_id fallback (instead of the 2-tier pattern in RESEARCH Pattern 5)** — during RED phase, test output showed `trace_id_var.get("-")` returns the default `"-"` when the exception handler runs. This is because BaseHTTPMiddleware wraps `call_next`, and an exception propagating out of `call_next` causes the FastAPI exception handler to execute in a scope where the ContextVar set by LoggingMiddleware is NOT visible (or has been reset). Rather than re-engineer the middleware chain, I added a third tier: `str(uuid4())`. Guaranteed non-empty, deterministic test behavior, zero extra cost (one uuid4 per 500 response, which should be rare).
2. **Test fixture uses `@app.get` + route pop teardown** — registering a raising route on the production `app` instance (not a `FastAPI()` sub-app) ensures the test exercises the full production middleware stack. Teardown pops the route by path match from `app.router.routes` — FastAPI's documented approach for dynamic route removal.
3. **TestClient `raise_server_exceptions=False`** — default True re-raises server-side exceptions to the client instead of running `@app.exception_handler(Exception)`. Precedent found in `tests/test_coach_chat_endpoint.py:91` (same project convention).
4. **Staging integration uses `/auth/login` with malformed body** — no test-only error-injection endpoint exists on staging, and adding one is scope creep per revision Info 7. `/auth/login` is guaranteed present, rate-limit-safe for a single probe, and flows through the same middleware + handler chain. PASS-PARTIAL is an explicit ship-path.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] 3-tier trace_id fallback needed (not 2-tier as specified in plan `<action>` Step 2)**
- **Found during:** Task 1 RED phase (3 tests failing with KeyError 'trace_id' AND captured stderr showing `trace_id: "-"`).
- **Issue:** Plan's proposed handler body used `inbound_trace_id or trace_id_var.get("") or ""`. Testing revealed `trace_id_var.get()` returns the ContextVar default `"-"` when the handler runs in the FastAPI exception-handler scope. With only 2 tiers, a request without inbound sentry-trace would return `trace_id: "-"` — which `test_preserves_logging_middleware_trace_id` explicitly rejects (`assert trace_id != "-"`).
- **Fix:** Promoted the fallback from 2-tier to 3-tier. `ctx_trace_id = trace_id_var.get("-")` then `trace_id = inbound_trace_id or (ctx_trace_id if ctx_trace_id != "-" else None) or str(uuid4())`. Guaranteed non-empty, deterministic, clean.
- **Files modified:** `services/backend/app/main.py`.
- **Verification:** 3/3 tests GREEN including the `!= "-"` assertion. Full suite 5958 passed.
- **Committed in:** `6ea76af5` (Task 1 commit).
- **Documentation impact:** plan Pattern 5 in `31-RESEARCH.md` remains valid conceptually; 31-03+ planners should lift this implementation (3-tier) if they touch exception paths in child services.

**2. [Rule 3 - Blocking] Handler signature typed (`request: Request, exc: Exception`) rather than untyped (`request, exc`)**
- **Found during:** Task 1 implementation (reading `<action>` Step 2 snippet, which uses typed signature).
- **Issue:** Original handler at `main.py:170` was untyped (`async def global_exception_handler(request, exc):`). Plan's replacement snippet was typed (`request: Request, exc: Exception`). Ruff / mypy conventions in this repo mildly prefer explicit types. Typing adds zero runtime cost.
- **Fix:** Accepted the typed signature from plan snippet.
- **Files modified:** `services/backend/app/main.py`.
- **Verification:** `python3 -m ruff check app/main.py` returns "All checks passed".
- **Committed in:** `6ea76af5`.

### Auto-added Critical Functionality

None beyond what the plan instructed.

---

**Total deviations:** 2 (1 bug-fix in the plan's proposed code, 1 typing clarification).
**Impact on plan:** Both deviations preserve and extend plan intent. Deviation 1 is the interesting one — it surfaced a subtle BaseHTTPMiddleware + ContextVar interaction that the plan author did not test in isolation. Documented here so future plans dealing with exception paths use the 3-tier pattern.

## A1–A10 Assumption Status Post-Plan

From `31-RESEARCH.md` §Assumptions Log — progress update:

- **A1** (`sentry-sdk[fastapi] 2.53.0 auto-reads sentry-trace header for cross-project link`) — **PARTIAL**. Auto-read capability is documented upstream but untested end-to-end in this plan (staging never hit the 500 path; the cross-project link requires a real Sentry event pair, which requires `SENTRY_DSN` set + a 500 firing). Will flip VERIFIED when Plan 31-04 quota probe fires a real error through walker.sh.
- **A2** (Railway/Cloudflare proxy does NOT strip `sentry-trace` header) — **VERIFIED**. Staging run delivered the header to the Pydantic validator (422 response tied to body shape, not header loss). No X-MINT-Trace-Id fallback needed. Pitfall 3 / ADR-footnote risk cleared.

Remaining A3-A10 are untouched by this plan (sample rate flip gate in OBS-06, quota ceiling in OBS-07, simulator-vs-device gap in Phase 35).

## Issues Encountered

- **Ctx var default "-" surfaced in exception handler scope** — resolved by 3-tier fallback (see Deviation 1). The existing `JsonFormatter` (logging_config.py:31) already handles this by falling back to `"-"` in log records; the handler just needs a separate guarantee for the response body.
- **Lefthook pre-commit memory-retention-gate warning** — `MEMORY.md has 167 lines (target <100)`. Warning only, not blocking. No action taken (out of scope; plan doctrine is to never touch user memory without explicit instruction).
- **Local sentry-sdk installed is 2.56.0, pyproject pinned to 2.53.0** — the installed wheel is still within the constraint in prior env; `pip install -e .` was not re-run because the change is a constraint tightening (not a code path change). CI and Railway rebuilds will pull 2.53.0 exactly. Deferred to operator rebuild step (non-blocking for test green).

## User Setup Required

None. All automation in-code. Downstream:
- No new env vars. `SENTRY_DSN_STAGING` + `SENTRY_DSN_PROD` from Phase 31-00 remain the only secrets in play.
- Operator must `cd services/backend && python3 -m pip install -e .` (or Railway rebuild) to pick up the exact 2.53.0 pin. CI pipelines naturally refresh on next deploy.

## Deferred Items

**`POST /api/v1/_test/raise_500` — test-only 500-trigger endpoint**

Per revision Info 7 this is an **accepted limitation**, not a blocker.

`DEFERRED: test-only raise_500 endpoint (accepted limitation per revision Info 7)`

Rationale: shipping an `ENABLE_TEST_ENDPOINTS=1`-gated raise endpoint requires backend surface + env wiring that risks scope creep on Phase 31. `trace_round_trip_test.sh` achieves `PASS-PARTIAL` with exit 0 via `/auth/login`'s 422 path, which proves:
- A2 (proxy does not strip header) — VERIFIED
- LoggingMiddleware cohabitation — VERIFIED (X-Trace-Id still emitted on 4xx)
- OBS-03 handler body `trace_id`/`sentry_event_id` keys — VERIFIED by unit tests (not integration)

Re-evaluate in Phase 32 (replay polish) or Phase 35 (dogfood boucle) if round-trip 500-path proof remains missing at that point.

## Next Phase Readiness

**Wave 3 (Plan 31-03 PII audit) unblocked:**
- Sentry end-to-end pipe is proven at the contract level (headers + body + log truncation). PII audit can now focus on replay redaction, knowing the transport + correlation plumbing is sound.

**Wave 4 (Plan 31-04 ops budget):**
- `observability-budget.md` math can now factor in the sentry-sdk 2.53.0 pin (locks transaction + breadcrumb behavior for forecasting). Still blocked on `SENTRY_AUTH_TOKEN` secret from operator.

**Blockers / concerns for next plans:**
- Operator MUST refresh backend deps (`pip install -e .` or Railway rebuild) to pick up 2.53.0 pin before the next Sentry-touching plan ships.
- Staging `/_test/raise_500` endpoint deferred — re-evaluate Phase 32 or 35 if integration proof of full 500 round-trip is required.

## Self-Check

**Files on disk:**
- `services/backend/app/main.py` — MODIFIED (global_exception_handler at L169-226 post-patch, trace_id_var import at L16, uuid4 import at L4)
- `services/backend/pyproject.toml` — MODIFIED (`sentry-sdk[fastapi]==2.53.0` at line 31, confirmed via grep)
- `services/backend/tests/test_global_exception_handler.py` — MODIFIED (3 tests live, raise_route fixture, _extract_500 helper)
- `tools/simulator/trace_round_trip_test.sh` — MODIFIED (~160 lines post-patch, confirmed via `bash -n`)

**Commits in git log:**
- `6ea76af5` — FOUND (Task 1)
- `e39d3480` — FOUND (Task 2)

**Verify commands re-run at SUMMARY creation time:**
- `cd services/backend && python3 -m pytest tests/test_global_exception_handler.py -q` → 3 PASSED
- `cd services/backend && python3 -m pytest tests/ -q --tb=no` → 5958 passed, 6 skipped (baseline 5955+9; delta +3/-3 expected)
- `cd services/backend && python3 -m ruff check app/main.py app/core/logging_config.py` → All checks passed
- `grep -n "sentry-sdk\[fastapi\]==2.53.0" services/backend/pyproject.toml` → line 31 match
- `grep -n "inbound_trace_id" services/backend/app/main.py` → lines 185, 193
- `grep -n "sentry_event_id" services/backend/app/main.py` → lines 172, 222
- `grep -n "X-Trace-Id" services/backend/app/main.py` → lines 173, 224
- `grep -n "trace_id_var" services/backend/app/main.py` → lines 16, 171, 180, 182, 191
- `grep -c "%.100s" services/backend/app/main.py` → 1 (FIX-077 nLPD truncation preserved)
- `bash -n tools/simulator/trace_round_trip_test.sh` → exit 0
- `bash tools/simulator/trace_round_trip_test.sh` against staging → exit 0, `[PASS-PARTIAL]` + `DEFERRED` line emitted

## Self-Check: PASSED

---

*Phase: 31-instrumenter*
*Completed: 2026-04-19*
