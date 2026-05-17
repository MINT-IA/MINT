---
phase: mint-data-architecture-v1-01-calc-engine-canonical
plan: 03
subsystem: api
tags: [fastapi, regulatory-registry, etag, conditional-get, rfc-7232, openapi, byte-stability, tdd, canonical-insertion-rule]

# Dependency graph
requires:
  - phase: mint-data-architecture-v1-01-calc-engine-canonical
    provides: "Plan 01 measurement script (tools/measurement/regulatory_snapshot_bundle_size.py) — Task 2 reuses its _build_payload(today) for byte-parity assertion."
  - phase: mint-data-architecture-v1-01-calc-engine-canonical
    provides: "Plan 02 doctrine + skill SKILL.md naming the 2 endpoints as the D-15 contract (mint-backend-dev SKILL.md)."
  - phase: mint-calc-engine-v1
    provides: "RegulatoryRegistry.instance() singleton + .version_hash(today) SHA-256 hex digest + .get_all() + .is_active(today) filter — reused verbatim."
provides:
  - "GET /api/v1/regulatory/constants/version — 3-key {version_hash, effective_from, reviewed_at} payload (140 bytes), weak ETag W/\"<hash>\", Cache-Control 60s."
  - "GET /api/v1/regulatory/constants/snapshot — full 27-jurisdiction payload (42 340 bytes), weak ETag, Cache-Control 300s, If-None-Match conditional GET → 304."
  - "Byte-stable serialisation pipeline matching Plan 01 measurement script (json.dumps separators=(',',':'), sort_keys=True, ensure_ascii=False) — endpoint bytes == measurement bytes (42 340 == 42 340 verified)."
  - "OpenAPI canonical regenerated — both new operations published in tools/openapi/mint.openapi.canonical.json with their descriptions documenting ETag + If-None-Match + 304 contract for downstream codegen."
  - "+17 backend tests (6 version + 8 snapshot + 3 openapi) — zero regression on 7331 baseline → 7348 passed."
affects:
  - mint-data-architecture-v1-01-calc-engine-canonical/Plan 04 (codegen — fetches /constants/snapshot from staging, parses byte-stable JSON, bakes Dart file ; OpenAPI canonical pins the contract for mock testing)
  - mint-data-architecture-v1-01-calc-engine-canonical/Plan 05 (parity lint — reads the baked Dart constants + reads /constants/snapshot live, diffs)
  - Future runtime delta-check on app launch (D-08) — calls /version, compares hash to baked hash, fetches /snapshot on mismatch, persists to local cache

# Tech tracking
tech-stack:
  added: []  # No new deps ; fastapi.Request + fastapi.Response + fastapi.responses.JSONResponse already in service. stdlib json + datetime.
  patterns:
    - "Byte-stable raw Response: hand-construct json.dumps body with separators+sort_keys+ensure_ascii to bypass FastAPI's jsonable_encoder ; preserves byte-parity contract across measurement / endpoint / mobile codegen."
    - "Canonical insertion rule enforced at TEST time (not line-number time): test asserts 200 (not 404 with detail='version not found') to prove the catch-all does not shadow the new route. Survives line-number drift."
    - "Conditional GET via If-None-Match string-equality compare against W/\"<hash>\" ETag — RFC 7232 §3.2 compliant ; 304 response carries ETag + Cache-Control + empty body."
    - "Null-safe min/max derivation: ``min((p.effective_from for p in active if p.effective_from is not None), default=None)`` — codex MEDIUM finding closed without try/except."
    - "Endpoint docstring as OpenAPI contract surface: ``description`` field auto-derived from docstring ; explicit mention of ETag + If-None-Match + 304 + RFC 7232 is the codegen-consumable contract."

key-files:
  created:
    - "services/backend/tests/test_regulatory_constants_version_endpoint.py"
    - "services/backend/tests/test_regulatory_constants_snapshot_endpoint.py"
    - "services/backend/tests/test_openapi_regulatory_endpoints_p03.py"
    - ".planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/01-03-SUMMARY.md"
  modified:
    - "services/backend/app/api/v1/endpoints/regulatory.py (+2 endpoints, +1 import block extension)"
    - "tools/openapi/mint.openapi.canonical.json (regenerated — 2 new paths + 1 docstring change)"

key-decisions:
  - "Canonical insertion rule enforced via TEST behaviour (assert 200, not 404 from catch-all) rather than line-number assertions — survives refactors that reorder code as long as decorator order is preserved."
  - "Byte-stability primitive: raw ``Response(content=body, media_type='application/json')`` with explicit ``json.dumps(..., sort_keys=True, separators=(',',':'), ensure_ascii=False)`` body construction. Rejected ``JSONResponse(content=payload)`` because FastAPI's jsonable_encoder adds whitespace + reorders keys, breaking byte-parity with Plan 01 measurement script."
  - "Two cohabitating hash keys on /snapshot: ``active_version_hash`` (legacy, preserves Plan 01 measurement byte-parity) + ``version_hash`` (D-15 canonical, consumed by mobile codegen). Both SHA-256, same value. Documented inline in code with rationale comments."
  - "ETag is weak (``W/`` prefix) because the byte content depends on (a) registry state at request time and (b) JSON serialisation rules — semantically the snapshot is the same as long as version_hash matches, even if a future serialiser tweak shifts bytes. RFC 7232 §2.3 weak vs strong ETag : we choose weak."
  - "Cache-Control differs per endpoint : version=60s (small payload, polled on launch), snapshot=300s (heavy payload, only fetched on hash mismatch). Both ``public, must-revalidate`` so CDN / Railway edge caches can absorb load while always honouring If-None-Match."
  - "If-None-Match conditional GET ELEVATED from codex LOW finding (« add later ») to first-class behaviour shipped in Task 2 itself, per plan deviations §5. Test 6 of snapshot suite asserts the full 200 → 304 cycle."
  - "OpenAPI contract documentation lives in the endpoint docstring (auto-rendered as ``description``) rather than a separate ``responses.200.headers`` declaration. Reason : FastAPI does NOT auto-emit header schemas for hand-constructed Response returns. Test 3 of openapi suite asserts the docstring text mentions ETag + If-None-Match + 304 — that IS the codegen contract."

patterns-established:
  - "Pattern : new route registered AT decorator-execution-order BEFORE a path-catch-all on the same router, enforced by behavioural test (200 vs 404 with catch-all error string)."
  - "Pattern : byte-stable hand-serialised Response for endpoints whose body MUST exactly equal another producer's body (measurement script, codegen, parity lint)."
  - "Pattern : cohabitating legacy + canonical keys with identical value + inline rationale comment — keeps byte-parity with upstream measurement while publishing the canonical D-15 contract key."
  - "Pattern : null-safe derivation via generator expressions with ``if x is not None`` filter + ``default=None`` to handle empty-active-set edge case without try/except."
  - "Pattern : RFC 7232 If-None-Match string-equality compare against the same ETag value — no quote-stripping needed because we control both sides of the contract."

requirements-completed: [D-08, D-15, planner-discretion-etag-conditional-get]

# Metrics
duration: 9min
completed: 2026-05-17
---

# Phase mint-data-architecture-v1-01 Plan 03 — Two regulatory constants sync endpoints

**`GET /api/v1/regulatory/constants/version` (140 bytes, weak ETag) + `GET /api/v1/regulatory/constants/snapshot` (42 340 bytes, ETag conditional GET → 304) shipped behind the canonical insertion rule so the existing `/constants/{key:path}` catch-all cannot shadow them. Byte-parity with Plan 01 measurement script verified (42 340 == 42 340). OpenAPI canonical regenerated. +17 tests green, zero regression on 7331 baseline → 7348.**

## Performance

- **Duration:** ~9 min (3 atomic TDD tasks)
- **Started:** 2026-05-17T16:44Z
- **Completed:** 2026-05-17T16:53Z
- **Tasks:** 3 (all TDD ; all atomic-commit ; all `--no-verify` per parallel-executor contract)
- **Files created or modified:** 6 (3 test files + 1 endpoint module + 1 OpenAPI canonical + 1 SUMMARY)

## Accomplishments

- **`GET /api/v1/regulatory/constants/version`** ships :
  - 3-key payload `{version_hash, effective_from, reviewed_at}`, sorted, no extras.
  - 140 bytes total response content (well under 1 KB semantic guard).
  - Weak ETag `W/"<sha256>"` derived from `RegulatoryRegistry.version_hash(today)`.
  - `Cache-Control: public, max-age=60, must-revalidate`.
  - Null-safe derivation of `effective_from` / `reviewed_at` on empty active set (returns `null` not 500) — codex MEDIUM finding closed.
- **`GET /api/v1/regulatory/constants/snapshot`** ships :
  - Full 27-jurisdiction payload (CH + 26 cantons) per D-14 bake-all posture.
  - 42 340 bytes raw JSON (matches Plan 01 measurement, verified byte-equal).
  - Cohabitating hash keys : `active_version_hash` (legacy / measurement parity) + `version_hash` (D-15 canonical / mobile codegen).
  - Weak ETag matching `/version` endpoint hash → enables /version delta-check before /snapshot fetch.
  - `Cache-Control: public, max-age=300, must-revalidate` — longer than /version because the payload is heavier.
  - `If-None-Match` conditional GET → 304 Not Modified per RFC 7232 §3.2 (codex LOW finding elevated to first-class per plan deviations §5).
- **Both endpoints registered BEFORE the existing `/constants/{key:path}` catch-all** — canonical insertion rule (codex HIGH #2 closed). Line numbers : `/constants` (35) < `/constants/version` (64) < `/constants/snapshot` (108) < `/constants/{key:path}` (161). Non-shadowing enforced behaviourally by Test 1 of each suite (assert 200, not 404 with catch-all error string).
- **Byte-parity with Plan 01 measurement script verified empirically** : `_build_payload(today)` + `version_hash` key added + same `json.dumps(separators=(',',':'), sort_keys=True, ensure_ascii=False)` rules → both produce 42 340 bytes (Test 7 of snapshot suite).
- **OpenAPI canonical regenerated** : `tools/openapi/mint.openapi.canonical.json` now contains both `/api/v1/regulatory/constants/version` and `/api/v1/regulatory/constants/snapshot` GET operations. Snapshot operation description explicitly mentions `ETag`, `If-None-Match`, `304 Not Modified`, `RFC 7232` so Plan 04 codegen + future consumers know the contract from the spec alone (no need to read the source code).
- **+17 backend tests** : 6 version + 8 snapshot + 3 openapi — every claim above carries a deterministic assertion.
- **Full backend suite : 7348 passed, 82 skipped, 3 xfailed, 0 failed** — exact baseline + 17 (Plan 02 baseline = 7331). Zero regression.
- **LSFin banned-terms + accent lints clean** on all 4 touched code files.

## Endpoint signatures + line numbers (canonical insertion rule receipts)

| Line | Decorator | Function | Plan |
|------|-----------|----------|------|
| 35 | `@router.get("/constants")` | `list_constants` | pre-existing |
| 64 | `@router.get("/constants/version")` | `get_constants_version` | **03 Task 1** |
| 108 | `@router.get("/constants/snapshot")` | `get_constants_snapshot` | **03 Task 2** |
| 161 | `@router.get("/constants/{key:path}")` | `get_constant` | pre-existing (catch-all) |

The two new decorators have line numbers strictly less than the catch-all (64 < 108 < 161). Canonical insertion rule satisfied. Behavioural assertion (200 vs 404) confirms FastAPI router matches the new routes first.

## Response shapes (live captures)

### `/constants/version` — 140 bytes

```json
{
  "effective_from": "2026-01-01",
  "reviewed_at": "2026-03-26",
  "version_hash": "b2ae1c9ae06773a180705851c71f7f535309c41556c0dd50ddd00a41c4b1fb07"
}
```

ETag : `W/"b2ae1c9ae06773a180705851c71f7f535309c41556c0dd50ddd00a41c4b1fb07"`
Cache-Control : `public, max-age=60, must-revalidate`

### `/constants/snapshot` — 42 340 bytes (excerpt)

Top-level keys : `active_version_hash` (legacy, byte-parity with Plan 01), `version_hash` (D-15 canonical, same value), `effective_on`, `param_count`, `parameters` (list of 88 active params spanning the 27 jurisdictions).

ETag : `W/"b2ae1c9ae06773a180705851c71f7f535309c41556c0dd50ddd00a41c4b1fb07"` (identical to `/version`)
Cache-Control : `public, max-age=300, must-revalidate`
If-None-Match → 304 Not Modified, body empty, ETag preserved.

## Byte-parity result (codex MEDIUM #4 closed)

| Producer | Bytes | Method |
|----------|-------|--------|
| `tools/measurement/regulatory_snapshot_bundle_size.py` `_build_payload(today)` + measurement-style serialise + add `version_hash` key | **42 340** | `json.dumps(separators=(',',':'), sort_keys=True, ensure_ascii=False).encode('utf-8')` |
| `GET /api/v1/regulatory/constants/snapshot` response.content | **42 340** | same |

Equality verified by `test_snapshot_endpoint_byte_parity_with_measurement_script` (Test 7 of snapshot suite).

## Task Commits

Each task committed atomically with `--no-verify` per parallel-executor contract :

1. **Task 1 — `/constants/version` endpoint + 6 tests** : `66378197`
   `feat(mint-data-architecture-v1-01-03): GET /v1/regulatory/constants/version endpoint (Task 1)`
2. **Task 2 — `/constants/snapshot` endpoint + 8 tests + OpenAPI regen** : `43caae06`
   `feat(mint-data-architecture-v1-01-03): GET /v1/regulatory/constants/snapshot + OpenAPI regen (Task 2)`
3. **Task 3 — OpenAPI contract tests + ETag docstring + canonical regen** : `49d3a524`
   `test(mint-data-architecture-v1-01-03): OpenAPI contract tests + ETag docstring (Task 3)`

## Decisions Made

1. **Canonical insertion rule enforced by behavioural tests** — Test 1 of both /version and /snapshot suites asserts `200`, not `404` with `detail='... not found'`. The line-number ordering is a documentation receipt ; the test is the mechanical guarantee that survives refactors.
2. **Byte-stability via raw `Response` + explicit `json.dumps`** — rejected `JSONResponse(content=payload)` because FastAPI's `jsonable_encoder` adds whitespace and reorders keys. The contract with Plan 04 codegen + the parity lint is byte-level, not just shape-level.
3. **Two hash keys cohabit on /snapshot** (`active_version_hash` + `version_hash`, same value) — keeps byte-parity with Plan 01 measurement script (which only emits the legacy key) while publishing the D-15 canonical key for Plan 04 codegen. The `active_version_hash` key is added to the measurement payload in Test 7 so both sides of the byte-equality check have it.
4. **Weak ETag** (`W/` prefix) — RFC 7232 §2.3. Semantically the snapshot is « the same » as long as `version_hash` matches, even if a future serialiser tweak shifts bytes. Strong ETag would require asserting byte-exact equivalence which the spec does not require for our cache-invalidation purpose.
5. **Cache-Control differs per endpoint** : `/version` = 60s (small payload polled on app launch), `/snapshot` = 300s (heavy payload only fetched on hash mismatch). Both `public, must-revalidate` so CDN / Railway can absorb load while still honouring `If-None-Match`.
6. **If-None-Match elevated to first-class** (was codex LOW finding) — Task 2 of this plan ships it ; Test 6 of snapshot suite asserts the full 200 → 304 cycle. No deferral to a later phase.
7. **OpenAPI contract surface = endpoint docstring** — FastAPI does NOT auto-emit `responses.200.headers.ETag` schemas for hand-constructed `Response` returns. Test 3 of openapi suite asserts the docstring text mentions ETag + If-None-Match + 304 ; that IS the codegen-readable contract.
8. **Null-safe derivation via `min/max(..., default=None)`** — rejected try/except because the empty-iterator case is the EXPECTED behaviour (registry might transiently be empty during reload), not an exception path.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Snapshot endpoint docstring missing « ETag » literal**
- **Found during:** Task 3 RED phase (`test_openapi_snapshot_endpoint_documents_request_header_or_etag_behavior` failed).
- **Issue:** Initial docstring said « Supports If-None-Match conditional GET (304 Not Modified) per RFC 7232. Cache-Control: ... » without the literal word « ETag », so the OpenAPI `description` field didn't expose the ETag contract to downstream codegen tools that read the spec alone.
- **Fix:** Expanded the docstring to « Response carries a weak ETag header `W/"<version_hash>"` ; supports If-None-Match conditional GET (304 Not Modified) per RFC 7232. » — 1 sentence inserted, no other change.
- **Files modified:** `services/backend/app/api/v1/endpoints/regulatory.py` (1 line of docstring expanded), `tools/openapi/mint.openapi.canonical.json` (regenerated).
- **Verification:** Test 3 of openapi suite → PASS after fix. Full Plan 03 suite : 17/17 green.
- **Committed in:** Task 3 commit `49d3a524`.

**2. [Rule 3 - Blocker] Worktree state confusion after soft-reset to expected base**
- **Found during:** initial `<worktree_branch_check>` execution.
- **Issue:** Worktree HEAD was at `255373bb` (hotfix lineage). Per protocol I ran `git reset --soft 4d696d6f`, which moved HEAD to the calc-engine Plan 02 commit but marked 1500+ files as staged-deletions (because hotfix lineage and calc-engine lineage share only `f2a71acd` as ancestor). After unstaging via `git reset HEAD`, the working tree was further confused : `tools/measurement/regulatory_snapshot_bundle_size.py` showed as « deleted » in `git status` even though it existed in HEAD's tree (Plan 01 work). The measurement script was needed for Task 2 Test 7 byte-parity assertion.
- **Fix:** `git checkout HEAD -- .` to restore the working tree to match HEAD. After this, the only `git status` entries were genuinely-untracked items from prior worktree lineage (skill SKILL.md from other phases, audit outputs) — left alone per scope discipline.
- **Files modified:** none directly ; working-tree restoration only.
- **Verification:** `ls tools/measurement/regulatory_snapshot_bundle_size.py` → exists ; `python3 -c "import regulatory_snapshot_bundle_size"` from the test → imports cleanly.
- **Committed in:** N/A (pre-task housekeeping).

**Total deviations:** 2 auto-fixed (1 Rule 1 docstring, 1 Rule 3 worktree state). No Rule 4 architectural changes. Plan structure 100% as written.

### Codex findings applied during execution (from REVIEWS.md)

- **HIGH #2 — Route-placement instructions contradictory** → Resolved structurally : Tasks 1 + 2 use the « insert immediately before `/constants/{key:path}` » rule from the plan `<interfaces>` section ; behavioural tests assert non-shadowing. CLOSED.
- **MEDIUM — `effective_from` derivation may fail on empty filtered list** → Task 1 uses `min((... for p in active if p.effective_from is not None), default=None)` ; Test 5 monkeypatches `get_all()` to `[]` and asserts 200 + null derivations. CLOSED.
- **MEDIUM — `<500 bytes` test brittle** → Replaced with 1 KB semantic guard ; docstring on Test 3 names the rationale (« single TCP segment delta-check »). CLOSED.
- **MEDIUM — Serialisation parity ambiguous** → Task 2 uses raw `Response(content=body, media_type='application/json')` with explicit `json.dumps(separators=(',',':'), sort_keys=True, ensure_ascii=False)` ; Test 7 asserts byte-equal with the measurement script payload (42 340 == 42 340). CLOSED.
- **LOW — Cache-Control without If-None-Match roadmap** → Elevated to first-class : `/snapshot` handles `If-None-Match` and returns 304 per RFC 7232 ; Test 6 of snapshot suite asserts the full cycle. CLOSED.

## 0-Trust Evidence Receipts (CLAUDE.md §9 protocol)

Each claim above carries a deterministic citation :

| Claim | Evidence |
|---|---|
| 3 task commits exist | `git log --oneline 4d696d6f..HEAD` returns 3 lines (`66378197`, `43caae06`, `49d3a524`) at 2026-05-17T16:53Z. |
| /version returns 200 + 140 bytes + ETag | `client.get('/api/v1/regulatory/constants/version')` in TestClient : status 200, `len(response.content) == 140`, `response.headers['ETag'] == 'W/"b2ae1c9ae...c4b1fb07"'`. |
| /snapshot returns 200 + 42 340 bytes + ETag + Cache-Control | `client.get('/api/v1/regulatory/constants/snapshot')` : status 200, `len(response.content) == 42_340`, ETag same hash, Cache-Control = `public, max-age=300, must-revalidate`. |
| Byte-parity with Plan 01 | `_measurement._build_payload(today)` + add `version_hash` key + same json.dumps rules → 42 340 bytes ; endpoint → 42 340 bytes ; `response.content == expected_body` returns True (Test 7 of snapshot suite). |
| Canonical insertion rule satisfied | `grep -n '@router.get("/constants' services/backend/app/api/v1/endpoints/regulatory.py` returns lines 35, 64, 108, 161 — both new routes strictly less than the 161 catch-all line. |
| If-None-Match → 304 cycle works | Test 6 of snapshot suite : first GET → 200 + ETag ; second GET with `If-None-Match: <etag>` → 304 + empty body + ETag preserved. |
| OpenAPI canonical regenerated | `python3 tools/openapi/generate_canonical.py` exit 0, output « Paths: 214, Schemas: 477 ». `grep -c '/regulatory/constants/version\|/regulatory/constants/snapshot' tools/openapi/mint.openapi.canonical.json` returns 2. |
| OpenAPI snapshot description mentions ETag + If-None-Match + 304 | Test 3 of openapi suite : asserts `'ETag' in combined` AND `('If-None-Match' in combined or '304' in combined)`. Both pass. |
| Plan 03 tests : 17/17 green | `pytest tests/test_regulatory_constants_version_endpoint.py tests/test_regulatory_constants_snapshot_endpoint.py tests/test_openapi_regulatory_endpoints_p03.py -q` → `17 passed in 0.29s`. |
| Full backend suite : 7348 passed (zero regression) | `pytest tests/ -q --tb=no` → `7348 passed, 82 skipped, 3 xfailed, 3 warnings in 128.05s`. Plan 02 baseline was 7331 ; delta = +17 exactly matches Plan 03 deltas. |
| LSFin clean | `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/regulatory.py services/backend/tests/test_regulatory_constants_*.py` exit 0 (no output). |
| Accent lint clean | `python3 tools/checks/accent_lint_fr.py --scope backend` exit 0. |
| /version + /snapshot hashes equal | Test 8 of snapshot suite : `snap['version_hash'] == ver['version_hash']` → True. Live capture : both endpoints return `b2ae1c9ae06773a180705851c71f7f535309c41556c0dd50ddd00a41c4b1fb07`. |

**Caveats** (per CLAUDE.md §9.4 « what I have NOT checked ») :
- Endpoints NOT exercised against the live staging deployment (Railway) — only against `TestClient(app)` in-process. Plan 04 codegen run against staging will be the first real network exercise. The byte-stable contract should hold (no proxy is going to mutate `application/json` body content) but transport-layer gzip / chunked-encoding might surface differences ; Plan 04 codegen MUST verify the live staging response can be parsed with the same byte-stable rules.
- No live CDN cache behaviour verified — `Cache-Control: public, max-age=300` is declared but Railway's edge / any CDN in front has its own honour policy. Acceptable risk : the headers are RFC-compliant ; if Railway ignores them, that's a Railway misconfiguration not an endpoint bug.
- No load test of the conditional-GET 304 path — for the v1 use-case (mobile clients polling /version on launch), the load profile is « one request per app-launch per device » which is trivial. Phase 02 telemetry will surface real-world load if needed.
- Engram MCP save NOT executed yet — handled at the end of this SUMMARY via mint_infra_contract block ; orchestrator-side belt-and-suspenders fallback per CLAUDE.md §3.5.

## Next Phase Readiness

- **Plan 04 (mobile codegen `tools/codegen/regulatory_constants_to_dart.py`)** UNBLOCKED — has 2 endpoints + OpenAPI canonical contract to consume. The byte-stable serialisation contract means the codegen can hash the raw response bytes and assert equality with the published `version_hash`, providing end-to-end integrity from registry → endpoint → bundle.
- **Plan 05 (parity lint extension)** UNBLOCKED — can read the Plan-04-generated Dart file's baked hash and call `GET /api/v1/regulatory/constants/version` to compare live ; the contract is concrete and testable.
- **Future runtime D-08 delta-check** UNBLOCKED — mobile fetches `/version` on launch, compares to baked hash, fetches `/snapshot` on mismatch, persists to local cache. All three steps have deterministic contracts now.
- **No blockers** for downstream plans in this wave.

## Known Stubs

None. All deliverables are wired end-to-end :
- Both endpoints serve real data (the live `RegulatoryRegistry` singleton).
- ETag conditional GET works for real (300 → 200 → 200 with If-None-Match → 304 cycle verified).
- OpenAPI canonical contains both paths with descriptions documenting the contract.
- The 17 tests are behavioural, not source-grep — they exercise the actual HTTP path through `TestClient(app)`.

## Threat Flags

None — both endpoints return public Swiss regulatory data (no PII per D-13). The `If-None-Match` header is treated as opaque client-supplied text and only compared for equality with the server-computed ETag string ; no control-flow hijack, no reflection. RegulatoryRegistry is in-process read-only. All threats in the plan's `<threat_model>` (T-mintda-03-01 through 04) are addressed exactly as documented.

## MINT infra compliance (CLAUDE.md mint_infra_contract)

- **File lints (Bash, since mint-tools MCP doesn't propagate to subagents per anthropics/claude-code#13898)** :
  - `python3 tools/checks/banned_terms_python.py <4 touched code files>` → exit 0.
  - `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0.
  - ARB parity not applicable (no Flutter / ARB changes in this plan).
- **Engram persistence** — orchestrator's responsibility per CLAUDE.md §3.5 ; this subagent did not have `mcp__plugin_engram_engram__mem_save` in its tool whitelist. Orchestrator should save with `topic_key: data-architecture:regulatory-constants:sync-endpoints` and `prior_finding_refs: [plan-01 BUNDLE-SIZE-REPORT obs id, plan-02 doctrine atomicity obs id]`.

## Self-Check: PASSED

Files (4/4 found) :
- `services/backend/app/api/v1/endpoints/regulatory.py` (MODIFIED) — FOUND. `grep -c '@router.get("/constants/version")' = 1`, `grep -c '@router.get("/constants/snapshot")' = 1`.
- `services/backend/tests/test_regulatory_constants_version_endpoint.py` (NEW) — FOUND.
- `services/backend/tests/test_regulatory_constants_snapshot_endpoint.py` (NEW) — FOUND.
- `services/backend/tests/test_openapi_regulatory_endpoints_p03.py` (NEW) — FOUND.
- `tools/openapi/mint.openapi.canonical.json` (REGEN) — FOUND, `grep -c '/regulatory/constants/version\|/regulatory/constants/snapshot' = 2`.
- `.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/01-03-SUMMARY.md` — THIS FILE, FOUND.

Commits (3/3 found in `git log --all`) : `66378197`, `43caae06`, `49d3a524`.

---
*Phase: mint-data-architecture-v1-01-calc-engine-canonical*
*Plan: 03*
*Completed: 2026-05-17*
*Next: Plan 04 (mobile codegen — fetches /constants/snapshot from staging, bakes Dart file) and Plan 05 (parity lint extension) — both can ship in parallel per CONTEXT wave structure.*
