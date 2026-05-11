---
description: Phase 97 W0 — 1-shot deep audit of services/backend/. 25 bugs identified covering bare-except silencing, TURN_COUNTER multi-process drift, Pydantic v2 missing model_config, sync DB I/O in async handlers, PII log leaks, dead TODOs, stale flags, and more.
phase: 97
date: 2026-05-11
auditor: Claude (Sonnet 4.6)
scope: services/backend/app/ — all 380 Python files
evidence_method: direct grep + AST parse + file read (deterministic)
status: FINAL
---

# Audit Backend API — Phase 97 W0

## TLDR — Top 5 P0 bugs

| Rank | ID | Title | File:line |
|------|-----|-------|-----------|
| 1 | B001 | `TURN_COUNTER` in-memory dict — Railway deploys **2 workers** (`-w 2`), so turn-cap state is split across processes; users can exceed the 3-turn cap | `services/backend/app/services/coach/turn_cap.py:40` + `railway.json:8` |
| 2 | B002 | Sync DB calls inside `async def coach_chat` block the event loop on every request — `_build_commitment_memory_block`, `_build_intelligence_memory_block`, `_build_insight_memory_block` are sync | `coach_chat.py:3038-3040`, `coach_chat.py:594,655,707` |
| 3 | B003 | Phase 94 citation-gate thresholds still NOT MET on prod path — Sonnet gate-correct was 6% (threshold 95%) in Stage 3; narrator prompt STILL does not teach `{{cite:<key>}}` syntax when `COACH_BUNDLE_COMPILER_ENABLED=False` | `core/config.py:80,91` + `94-03-FLAG-FLIP-PROPOSAL.md:33` |
| 4 | B004 | `except Exception: pass` at `auth.py:55` silently swallows JTI-blacklist check failures — a compromised revoked token could authenticate if the blacklist query raises | `core/auth.py:53-56` |
| 5 | B005 | 124 `BaseModel` subclasses across `app/schemas/` lack `model_config = ConfigDict(extra="forbid")` — extra client-supplied fields pass through silently (injection surface) | `schemas/sync.py:9,25`, `schemas/auth.py:11-168`, `schemas/billing.py:10-85`, … (124 total) |

---

## Bug catalogue

### B001 — TURN_COUNTER multi-process drift (P0)

```yaml
- id: B001
  severity: P0
  surface: backend
  archetype: all
  feature: chat_as_verb / turn_cap
  title: « TURN_COUNTER in-memory dict splits across Railway -w 2 workers; turn-cap not enforced »
  repro: « services/backend/railway.json:8 — gunicorn -w 2; services/backend/app/services/coach/turn_cap.py:40 — module-level dict. Grep: grep -n "TURN_COUNTER" app/services/coach/turn_cap.py »
  blast_radius: « Users on chat-as-verb surface bypass the 3-turn cap because requests alternate between worker 1 and worker 2. Phase 96 W2 D-09 contract is violated. Token cost unbounded. VERB-05 Sentry breadcrumb never fires for cap hits spread across workers. »
  fix_cost: small
  status: OPEN
  found_in: 2026-05-11
  notes: « turn_cap.py:7-9 documents the caveat: "uvicorn workers > 1 will NOT share this dict … run with workers=1". But railway.json deploys -w 2. Fix: change -w 2 to -w 1 OR add Redis backing (Phase 97 scope per CONTEXT §Deferred Ideas §7). Immediate fix is -w 1 in railway.json. »
```

Evidence: `services/backend/railway.json:8` — `gunicorn app.main:app -w 2 -k uvicorn.workers.UvicornWorker`. `turn_cap.py:40` — `TURN_COUNTER: Dict[Tuple[str, str], int] = {}` at module scope.

### B002 — Sync DB calls in async handler block event loop (P0)

```yaml
- id: B002
  severity: P0
  surface: backend
  archetype: all
  feature: coach_chat
  title: « _build_commitment/intelligence/insight_memory_block are sync functions with db.query() called from async def coach_chat — blocks event loop »
  repro: « grep -n "def _build_commitment_memory_block\|def _build_intelligence_memory_block\|def _build_insight_memory_block" app/api/v1/endpoints/coach_chat.py → lines 594, 655, 707 (all sync). Called at coach_chat.py:3038-3040 inside async def coach_chat. »
  blast_radius: « Under concurrent load, each coach chat request blocks the entire uvicorn event loop during the 3 DB queries. Starvation / latency spikes for ALL concurrent users on the same worker. »
  fix_cost: small
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: wrap each in asyncio.to_thread() or use run_in_executor(). Pattern precedent in services/llm/router.py:244 (loop.run_in_executor already used there). »
```

Evidence: `coach_chat.py:594` — `def _build_commitment_memory_block(...)` (sync, `db.query()` inside). `coach_chat.py:3038` — called bare without `await asyncio.to_thread(...)`.

### B003 — Phase 94 citation-gate: narrator still cannot emit `{{cite:<key>}}` when BUNDLE_COMPILER_ENABLED=False (P0)

```yaml
- id: B003
  severity: P0
  surface: backend
  archetype: all
  feature: citation_gate
  title: « With COACH_BUNDLE_COMPILER_ENABLED=False (prod default), CitationGrammarBundle is NEVER appended — narrator never learns cite syntax; gate fires fallback 60-80% of turns »
  repro: « app/core/config.py:80 COACH_BUNDLE_COMPILER_ENABLED=False (default). app/services/coach/bundle_compiler.py:205: CitationGrammarBundle only appended when COACH_BUNDLE_COMPILER_ENABLED=True AND COACH_CITATION_GATE_ENABLED=True. When the bundle compiler is off, the narrator has no cite-syntax training. »
  blast_radius: « Prod flag COACH_CITATION_GATE_ENABLED is False (core/config.py:91) so the gate is currently OFF on prod, which is the correct interim state per 94-03-FLAG-FLIP-PROPOSAL.md. However the root cause from Phase 94 Stage 3 (narrator has never seen {{cite:<key>}} syntax) is still unresolved. Phase 97 W0 is the right time to fatten the legacy narrator path. »
  fix_cost: medium
  status: OPEN
  found_in: 2026-05-11
  notes: « Evidence: .planning/phases/94-mvp-citation-gate/94-03-SUMMARY.md:52 — gate_correct=3/50 (6%) Sonnet; threshold ≥95%. The Phase 94.1 bundle_compiler path (bundle_compiler.py:192-207) does teach the syntax — but only when COACH_BUNDLE_COMPILER_ENABLED=True. Legacy narrator path (build_system_prompt) still lacks it. Unblocks the prod flag flip. »
```

### B004 — `except Exception: pass` silences JTI-blacklist check (P1)

```yaml
- id: B004
  severity: P1
  surface: backend
  archetype: all
  feature: auth / token_revocation
  title: « core/auth.py:55 bare except swallows any error in JTI-blacklist check; revoked token could authenticate silently »
  repro: « grep -n -A3 "except Exception" app/core/auth.py → line 55: except Exception: pass — comment says "If decode fails entirely, let decode_token handle it". But the try block (lines 44-56) also calls is_jti_blacklisted(db, jti) — a DB query that may raise IntegrityError, OperationalError, etc. Those are swallowed too. »
  blast_radius: « A revoked JWT whose JTI is blacklisted could authenticate if the blacklist DB query raises (e.g. DB overload, migration-drift). Auth-bypass via infrastructure degradation. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: add except (OperationalError, IntegrityError) as db_exc: logger.error(...); raise HTTPException(401) BEFORE the bare except. Reserve except Exception: pass only for the JWT decode path. The comment at line 56 shows intent but implementation over-catches. »
```

Evidence: `core/auth.py:53-56`:
```python
    except HTTPException:
        raise  # Re-raise auth failures
    except Exception:
        pass  # If decode fails entirely, let decode_token handle it
```

### B005 — 124 schema classes missing `extra="forbid"` (P1)

```yaml
- id: B005
  severity: P1
  surface: backend
  archetype: all
  feature: api_schemas
  title: « 124 BaseModel subclasses in app/schemas/ have no model_config — extra client fields silently ignored (injection surface, schema drift hidden) »
  repro: « python3 -c "<AST scan>" → Total: 124 classes without model_config. Key examples: schemas/sync.py:9 ClaimLocalDataRequest, schemas/auth.py:11-168 (23 auth schemas), schemas/billing.py:10-85 (9 billing schemas). »
  blast_radius: « Extra keys from mobile clients (e.g. injected fields in ClaimLocalDataRequest.wizard_answers) pass through without validation. Schema drift between mobile and backend is invisible. Pydantic v2 default extra="ignore" means typos in field names are silently dropped. »
  fix_cost: medium
  status: OPEN
  found_in: 2026-05-11
  notes: « Precedent: citation_registry.py:51 uses ConfigDict(frozen=True, extra="forbid"). Priority subsets: schemas/sync.py (ClaimLocalDataRequest/Response carry untrusted device payloads — fix first), schemas/auth.py (auth request bodies). Not all 124 need frozen=True but all need extra="forbid". »
```

### B006 — `auth.py:1283` bare except in Apple Sign-in no log (P1)

```yaml
- id: B006
  severity: P1
  surface: backend
  archetype: all
  feature: auth / apple_signin
  title: « auth.py:1283 bare except: swallows base64-decode + JSON parse errors with no log — silent 400 returned, undiagnosable in Sentry »
  repro: « grep -n -A3 "1283" app/api/v1/endpoints/auth.py → lines 1281-1287: except HTTPException: raise; except Exception: raise HTTPException(400, "Failed to decode Apple identity token"). No logging before raise. »
  blast_radius: « Apple Sign-in failures during token parsing (malformed JWTs, encoding edge cases) are undiagnosable. Sentry does not capture the original exception type. Affects all Apple SSO users. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: add logger.warning("Apple token decode failed: %s", type(exc).__name__) before raising HTTPException. »
```

### B007 — `coach_chat.py:1131` bare except returns hardcoded FR string (P2)

```yaml
- id: B007
  severity: P2
  surface: backend
  archetype: all
  feature: coach_chat / suggested_actions
  title: « coach_chat.py:1131 bare except in _compute_suggested_actions returns hardcoded FR fallback without logging — i18n violation + silent DB failure »
  repro: « grep -n -A2 "1131" app/api/v1/endpoints/coach_chat.py → line 1131: except Exception: return [{"label": "Parle-moi de ta situation financière", "type": "question"}]. Hardcoded FR string violates CLAUDE.md §5 i18n rule. No log means the DB error is invisible. »
  blast_radius: « DB errors in profile-reading silently degrade suggested actions for all users. Hardcoded FR string breaks EN/DE/ES/IT/PT users. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: add logger.warning(...) before return; replace hardcoded FR string with a key from AppLocalizations (or remove it and return [] — the caller handles empty). »
```

### B008 — `coach_chat.py:3009` bare except swallows regex-covered-keys computation (P2)

```yaml
- id: B008
  severity: P2
  surface: backend
  archetype: all
  feature: coach_chat / dual_llm_extractor
  title: « coach_chat.py:3009 bare except silently resets _regex_covered_keys to empty set — STAGE 2 LLM extractor potentially re-extracts all facts »
  repro: « grep -n -A3 "3009" app/api/v1/endpoints/coach_chat.py → line 3009: except Exception: _regex_covered_keys = set(). No log. If locals().get("extracted_facts") raises, the LLM extractor re-covers all keys unnecessarily, doubling token cost for STAGE 1 facts. »
  blast_radius: « When COACH_DUAL_LLM_ENABLED=True, this causes unnecessary LLM calls for already-extracted facts. Cost regression per turn. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « The entire locals().get("extracted_facts") construction is a code smell — extracted_facts is defined earlier in the same function scope and should be referenced directly. »
```

### B009 — `coach_chat.py:1414/1417` nested bare except swallows rollback errors (P2)

```yaml
- id: B009
  severity: P2
  surface: backend
  archetype: all
  feature: coach_chat / fact_persistence
  title: « _persist_extracted_fact: nested except Exception: pass at lines 1414/1417 — rollback failure is silently swallowed, DB in inconsistent state »
  repro: « grep -n -A5 "1414" app/api/v1/endpoints/coach_chat.py → outer except Exception: try: db.rollback(); except Exception: pass. If rollback() itself fails (connection lost), the outer logger.exception fires but no exception is re-raised and function returns False — caller has no way to know the DB is corrupted. »
  blast_radius: « Profile fact persistence failures during extraction leave the DB session in an undefined state. Subsequent DB operations on the same session may fail or silently commit stale data. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: log the rollback error (logger.warning). The function returning False is acceptable; the DB session corruption risk is not. »
```

### B010 — `coach_chat.py:1571` bare except swallows cache-replay construction (P2)

```yaml
- id: B010
  severity: P2
  surface: backend
  archetype: all
  feature: coach_chat / extractor_cache
  title: « coach_chat.py:1571 bare except in cache-replay loop: bad ExtractedFact schema silently skipped, no log »
  repro: « grep -n -A2 "1571" app/api/v1/endpoints/coach_chat.py → line 1571: except Exception: continue. No log. »
  blast_radius: « If cache contains a stale/invalid fact structure (e.g. schema drift from a code update), the cache silently skips it and the narrator runs with partial context. Users experience « coach forgets » symptoms. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: logger.debug("cache-replay fact skipped: %s", type(exc).__name__). Keeping continue is fine. »
```

### B011 — `coach_chat.py:3538` bare except swallows SLO record_response (P3)

```yaml
- id: B011
  severity: P3
  surface: backend
  archetype: all
  feature: slo_monitoring
  title: « coach_chat.py:3538 bare except: pass on SLO record_response — SLO monitor silently stops recording »
  repro: « grep -n -A2 "3538" app/api/v1/endpoints/coach_chat.py → line 3538: except Exception: pass. »
  blast_radius: « SLO dashboard goes dark silently if slo_monitor import fails or record_response raises. No alert, no log. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Acceptable to keep fail-open, but add logger.debug at minimum so failures appear in Railway log. »
```

### B012 — `documents.py:469,746,859` bare except on file.read() drops error type (P2)

```yaml
- id: B012
  severity: P2
  surface: backend
  archetype: all
  feature: documents / upload
  title: « documents.py:469,746,859 bare except on await file.read() returns generic 400 with no logging — upload failures undiagnosable »
  repro: « grep -n "except Exception" app/api/v1/endpoints/documents.py → lines 469, 746, 859. Each: except Exception: raise HTTPException(400, "Invalid request parameters"). No logger call. »
  blast_radius: « File upload failures (network interruption, multipart corruption, ASGI limit) are silently turned into generic 400s. No Sentry event, no log line. Support cannot distinguish between user error and infrastructure failure. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: add logger.warning("file.read() failed: %s", type(exc).__name__) before raise. Three identical occurrences — extract to a helper. »
```

### B013 — `documents.py:1187` bare except on base64 decode (P2)

```yaml
- id: B013
  severity: P2
  surface: backend
  archetype: all
  feature: documents / v2_scan
  title: « documents.py:1187 bare except on _b64.b64decode — returns 400 with no log; Sentry dark »
  repro: « grep -n -A2 "1187" app/api/v1/endpoints/documents.py → line 1187: except Exception: raise HTTPException(400, "Invalid base64 image"). No log. »
  blast_radius: « Documents V2 scan (DOCUMENTS_V2_ENABLED gate) upload failures are invisible. All archival document-scan errors from mobile clients silently produce 400 with no diagnostic data. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Same pattern as B012. »
```

### B014 — `privacy.py:189` bare except swallows pgvector query (P2)

```yaml
- id: B014
  severity: P2
  surface: backend
  archetype: all
  feature: privacy / data_export
  title: « privacy.py:189 bare except: pass on pgvector embedding query — GDPR data export silently skips coach memory embeddings »
  repro: « grep -n -A3 "189" app/api/v1/endpoints/privacy.py → line 189: except Exception: # pgvector not available … pass. »
  blast_radius: « On production Railway (which HAS pgvector), a transient DB error during nLPD Art. 25 data export silently omits the coach memory section. User receives an incomplete data export without notice. GDPR/nLPD compliance gap. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: check for specific ImportError / ModuleNotFoundError (CI/dev SQLite path) and log + re-raise OperationalError (production path). »
```

### B015 — `auth.py:1143` logs full user_id UUID (P2)

```yaml
- id: B015
  severity: P2
  surface: backend
  archetype: all
  feature: auth / account_deletion
  title: « auth.py:1143 logger.error logs full user_id UUID — PII in Railway logs violates nLPD Art. 6 data minimization »
  repro: « grep -n "logger.error.*user_id" app/api/v1/endpoints/auth.py → line 1143: logger.error("Account deletion failed for user %s: %s", user_id, e). user_id is the full UUID, not truncated. »
  blast_radius: « Full UUIDs in logs are a low severity on their own but in combination with other log fields (timestamp + error type) they could allow correlation with external data. Inconsistent: auth.py:1132 already does user_id[:8]. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: user_id[:8] to match established pattern at auth.py:1132. »
```

### B016 — `coach_chat.py:3546` logs full `_user.id` UUID (P2)

```yaml
- id: B016
  severity: P2
  surface: backend
  archetype: all
  feature: coach_chat / token_budget
  title: « coach_chat.py:3546 logger.warning logs full _user.id UUID — inconsistent PII truncation »
  repro: « grep -n "3546" app/api/v1/endpoints/coach_chat.py → logger.warning("token_budget consume failed user=%s err=%s", _user.id, exc). »
  blast_radius: « As B015 — inconsistent truncation. UUID in Railway logs. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: str(_user.id)[:8]. »
```

### B017 — Sync DB engine, no async pool, 20+20 overflow in async app (P1)

```yaml
- id: B017
  severity: P1
  surface: backend
  archetype: all
  feature: database / connection_pool
  title: « SQLAlchemy sync engine with pool_size=20 + max_overflow=20 used from async handlers — 40 connections held indefinitely during await gaps, starving other requests »
  repro: « app/core/database.py:20-21: pool_size=20, max_overflow=20 (total 40 connections). get_db() is sync generator Depends. app/api/v1/endpoints/coach_chat.py:2750: Depends(get_db). The async coach_chat handler holds a sync DB connection across multiple await points (LLM calls can take 5-15s). »
  blast_radius: « With -w 2 (2 workers), each with 40-connection pool = 80 max connections. A burst of 40 concurrent coach_chat requests per worker holds DB connections across 5-15s LLM latency windows. Connection pool exhaustion under moderate concurrency (>40 simultaneous users). »
  fix_cost: large
  status: OPEN
  found_in: 2026-05-11
  notes: « Proper fix: migrate to async SQLAlchemy (sqlalchemy[asyncio] + asyncpg). Interim mitigation: close the session before the LLM call and re-open after. This is a known architectural debt. »
```

### B018 — `GROUNDING_PACK_KEYS_REGISTRY` empty frozenset makes bundle-contract test always xfail (P2)

```yaml
- id: B018
  severity: P2
  surface: backend
  archetype: all
  feature: citation_gate / bundle_contract
  title: « grounding_pack.py:104 exports empty GROUNDING_PACK_KEYS_REGISTRY frozenset — test_bundle_citation_allowlist_subset_of_grounding_pack perpetually xfails, hiding real key drift »
  repro: « app/services/coach/grounding_pack.py:104: GROUNDING_PACK_KEYS_REGISTRY: frozenset = frozenset(). tests/bundles/test_bundle_contract.py:116: if not GROUNDING_PACK_KEYS_REGISTRY: pytest.xfail(...). »
  blast_radius: « Any bundle that invents a citation key not in CITATION_REGISTRY goes undetected. The test was supposed to be enabled in Phase 95 (comment: "Phase 95 populates") — it was not. The invariant enforcer is permanently disabled. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: GROUNDING_PACK_KEYS_REGISTRY = frozenset(CITATION_REGISTRY.keys()). This is a one-liner that populates it from the already-correct CITATION_REGISTRY (18 keys). The xfail becomes a real assertion. »
```

### B019 — 20 stale `# TODO Phase 95 — pending GroundingPack registry` comments in bundles (P3)

```yaml
- id: B019
  severity: P3
  surface: backend
  archetype: all
  feature: citation_gate / bundles
  title: « 20 stale "# TODO Phase 95 — pending GroundingPack registry" comments across pillar3a_optimizer.py, tax_explainer.py, mortgage_stressor.py, lpp_projector.py — misleading, Phase 95 is DONE »
  repro: « grep -rn "# TODO Phase 95" app/services/coach/bundles/ → 20 hits. Phase 95 is complete (grounding_pack.py and CITATION_REGISTRY exist). The TODO comments are now false. »
  blast_radius: « Future engineers (and agents) reading these comments will incorrectly believe the registry is not yet populated. Low blast, high confusion risk. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: replace "# TODO Phase 95 — pending GroundingPack registry" with "# citation_registry.CITATION_REGISTRY key (populated Phase 94)". »
```

### B020 — `ClaimLocalDataRequest` no `extra="forbid"` — untrusted device payload (P1)

```yaml
- id: B020
  severity: P1
  surface: backend
  archetype: all
  feature: sync / local_data_claim
  title: « schemas/sync.py:9 ClaimLocalDataRequest has no model_config — arbitrary extra keys in wizard_answers/budget_snapshot accepted without validation »
  repro: « app/schemas/sync.py:9: class ClaimLocalDataRequest(BaseModel). No model_config. Field wizard_answers: dict[str, Any] is especially dangerous — unvalidated arbitrary dict from untrusted device. »
  blast_radius: « Mobile client (or attacker) can send extra top-level fields that Pydantic v2 ignores silently. Downstream sync.py code iterates the dict — extra keys could confuse the merge logic. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: add model_config = ConfigDict(extra="forbid") to ClaimLocalDataRequest and ClaimLocalDataResponse. »
```

### B021 — Anonymous chat path has no citation gate (P1, deferred from Phase 94)

```yaml
- id: B021
  severity: P1
  surface: backend
  archetype: all
  feature: citation_gate / anonymous_chat
  title: « anonymous_chat.py has no citation_parser.gate() wiring — Phase 94 G-D-scope deferred item D1 still open »
  repro: « grep -n "citation_parser\|CITATION_GATE" app/api/v1/endpoints/anonymous_chat.py → no match. .planning/phases/94-mvp-citation-gate/94-03-FLAG-FLIP-PROPOSAL.md:48: "anonymous chat endpoint has NO gate wrapper today". »
  blast_radius: « Anonymous users receive ungrounded numerical claims in the Premier Éclairage surface. LSFin compliance gap on the highest-traffic pre-auth surface. »
  fix_cost: medium
  status: OPEN
  found_in: 2026-05-11
  notes: « Known deferred item from Phase 94. Phase 97 W0 confirms it is still unresolved. »
```

### B022 — `main.py:133` bare except swallows SLO monitor shutdown (P3)

```yaml
- id: B022
  severity: P3
  surface: backend
  archetype: all
  feature: slo_monitoring / lifecycle
  title: « main.py:133 bare except: pass on lifespan shutdown swallows SLO monitor stop errors silently »
  repro: « grep -n -A2 "133" app/main.py → line 133: except Exception: pass inside the lifespan shutdown block. »
  blast_radius: « SLO monitor teardown errors (e.g. task.cancel() raising CancelledError on non-started task) are invisible. Low blast since lifespan shutdown is a one-shot operation. »
  fix_cost: trivial
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: log at DEBUG level. CancelledError should be caught explicitly rather than swallowed by broad except Exception. »
```

### B023 — Snapshots and Open Banking use in-memory stores (no DB migration landed) (P1)

```yaml
- id: B023
  severity: P1
  surface: backend
  archetype: all
  feature: snapshots / open_banking
  title: « Snapshots endpoint logs "in-memory fallback active — snapshot data will NOT survive restart" at every startup — DB migration for snapshots table not yet in alembic/versions/ »
  repro: « app/api/v1/endpoints/snapshots.py:52: warning logged at import time. ls services/backend/alembic/versions/ | grep snapshot → no result (only p10_scenarios_table.py exists, not snapshots). »
  blast_radius: « ALL snapshot data is lost on every Railway deploy/restart. Users lose their financial snapshot history silently. Affects every registered user using the scenario/snapshot feature. »
  fix_cost: medium
  status: OPEN
  found_in: 2026-05-11
  notes: « A new alembic migration is needed. The model app/models/snapshot.py exists but no migration was generated. »
```

### B024 — `ParetoPoint.weights/allocation/projected_outcomes` typed as `dict` (no field constraints) (P2)

```yaml
- id: B024
  severity: P2
  surface: backend
  archetype: all
  feature: citation_gate / grounding_pack
  title: « grounding_pack.py:78-81 ParetoPoint fields weights, allocation, projected_outcomes are bare dict — no key constraint, Pydantic cannot validate shape »
  repro: « app/services/coach/grounding_pack.py:78-81: weights: dict; allocation: dict; projected_outcomes: dict. No TypedDict, no field_validator. »
  blast_radius: « A ProjectionGroundingPack with malformed pareto_points passes validation silently and reaches the narrator. The narrator may serialize malformed CHF values leading to garbled output. »
  fix_cost: small
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: define a TypedDict or use dict[str, Decimal] with field_validator. Precedent: GroundingPackEntry.raw is also bare dict — same pattern. »
```

### B025 — `banned_terms_python.py` flags coach prompt strings as false positives (P3)

```yaml
- id: B025
  severity: P3
  surface: backend
  archetype: all
  feature: lsfin_compliance / tooling
  title: « tools/checks/banned_terms_python.py produces 30+ false positives on coach prompt docstrings that TEACH the banned-term list — CI noise that masks real violations »
  repro: « python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/ → flags claude_coach_service.py:83 ("garanti, certain…" in system prompt) and compliance_guard.py:45-171 (the guard's own term list). »
  blast_radius: « Any real LSFin violation in a coach template is drowned by 30 false positives. The check is not usable as a CI gate. »
  fix_cost: small
  status: OPEN
  found_in: 2026-05-11
  notes: « Fix: add a # noqa: LSFIN inline comment convention or a known-false-positive allowlist file (similar to arb_meta_level_grandfathered.txt). The guard files themselves must be excluded. »
```

---

## Deep-dive findings

### Schema drift assessment

No `alembic check` available without live DB connection. Structural comparison shows:

- `app/models/scenario.py:32-33` adds `inputs_hash` and `superseded_by` columns — migration `alembic/versions/p95_dag_invalidation.py` exists and uses idempotency guard. **OK.**
- `app/models/snapshot.py` exists as an ORM model but **no corresponding alembic migration found** in `alembic/versions/`. This is B023 above.
- `alembic/versions/p86a_create_anonymous_sessions.py` exists for anonymous sessions table. **OK.**

### `_substitute_placeholders` consumer audit

Callers of `citation_parser._substitute_placeholders`:
- `citation_parser.py:585` — called with `pack=pack`. Correct.
- All other call sites are internal to `citation_parser.py`.

No caller passes `pack` as a positional argument (all use `pack=`). The keyword-only contract (enforced by the `*` in the signature at line 359) is respected. **No bug here.**

### `TURN_COUNTER` multi-process drift (see B001)

Confirmed: `railway.json:8` deploys `-w 2`. `turn_cap.py:7-9` explicitly documents that `workers > 1 WILL NOT share this dict`. This is an **already-known issue** that Phase 97 must close by either changing `-w 1` or adding Redis.

### LSFin banned terms in narrator path

`tools/checks/banned_terms_python.py` output on `app/services/coach/` generates 30+ false positives on the banned-term list definitions themselves (compliance_guard.py, prompt_registry.py). No genuine LSFin violations found in narrator output templates after filtering out definition/teaching contexts. The `fallback_templates.py` explicitly notes banned terms must not appear. **See B025 for the tooling issue.**

### Phase 94 threshold status

Per `94-03-FLAG-FLIP-PROPOSAL.md:33`:
- Sonnet gate-correct: **6%** (threshold ≥95%) — **NOT MET** at Phase 94 Stage 3
- `COACH_CITATION_GATE_ENABLED=False` on prod (correct interim state)
- `COACH_BUNDLE_COMPILER_ENABLED=False` on prod — CitationGrammarBundle never appended to legacy narrator path

The bundle compiler path (`bundle_compiler.py:205`) does add `CitationGrammarBundle` when both flags are ON. But since both flags default to False, the narrator on prod has never learned `{{cite:<key>}}` syntax. **Phase 97 must either (a) enable the bundle compiler or (b) fatten the legacy narrator prompt directly.**

### Citation registry namespace (18 keys)

`CITATION_REGISTRY` has exactly 18 keys (verified by reading `citation_registry.py:65-178`). All 18 are `spec` or `reasoning` source_kind. Phase 95+96 code references keys via `pack.inputs_hash` guard — no keys invented outside the registry in production code (Phase 95 `grounding_pack.py` `entries` dict is generic, populated at runtime by financial_core callers). **No namespace expansion drift detected** in static analysis.

### PII leak risk summary

- `send_default_pii=False` set in Sentry init (`main.py:30`) — **correct**.
- `main.py:206-210`: exception handler logs `type(exc).__name__` + first 100 chars of str(exc) — acceptable.
- Sentry breadcrumbs in `coach_chat.py:828-836` — no user message content, only bundle names + token counts. **Correct.**
- Sentry breadcrumbs in `citation_parser.py:388` — keys only, no user text. **Correct.**
- `coach_chat.py:3546`: full UUID in warning log — **see B016**.
- `auth.py:1143`: full UUID in error log — **see B015**.
- Test fixture `conftest.py:26`: `user.email = "test@mint.ch"` — synthetic fixture, not real PII. **Acceptable.**

### Async/sync DB pattern

The codebase uses a **sync SQLAlchemy engine** injected into `async def` handlers via `Depends(get_db)`. This is a known Starlette/FastAPI pattern that works via the sync-compatible `Depends` mechanism but blocks the event loop during DB I/O. **B002 and B017** cover the two most critical surfaces. The `_build_*_memory_block` helpers (`coach_chat.py:594,655,707`) make multiple `db.query()` calls in sequence while the handler is already in the async context. The LLM call in `_run_agent_loop` takes 5-15s and holds the session open across the await.

---

## Counter-arguments

1. **Most bare-excepts are intentional fail-open telemetry.** Sentry breadcrumbs, SLO recording, and Maestro test infra are legitimately designed to never fail the main request. The pattern at `turn_cap.py:33` (sentry import), `coach_chat.py:837` (`noqa: BLE001 — telemetry must never break narrator`), and `narrative_sleeve_lint.py:103` is **correct** for those sites. Bugs B011, B022 only flag the ones with zero logging — the truly invisible failures. This audit does NOT flag the `noqa: BLE001` annotated telemetry sites.

2. **`pool_size=20 + max_overflow=20` is standard FastAPI + sync SA practice.** The sync DB + async handler tension (B017) is a well-known trade-off in FastAPI apps that have not yet migrated to `sqlalchemy[asyncio]`. The existing pool config is not wrong per se — it is a performance risk under concurrent load, not an immediate correctness bug. Migration cost is large and may not be Phase 97 scope.

3. **The 124 schemas without `model_config` (B005) is an incomplete picture.** Many of those schemas inherit from parent classes (e.g. `SnapshotBaseModel` at `snapshots.py:26` has `model_config` defined) which means their subclasses inherit it. The AST scan cannot track inheritance chains. The real count of schemas with NO inherited model_config is likely lower than 124. However, `schemas/sync.py`, `schemas/auth.py` top-level classes (not subclassing a configured parent) are genuine gaps.

---

## Data gaps

1. **No live `alembic check` run** — schema drift between ORM models and DB columns cannot be fully verified without a live DB connection. The snapshot model gap (B023) was found structurally but column-level drift on other models is unverified.

2. **Railway staging env vars not inspectable from this session** — whether `COACH_CITATION_GATE_ENABLED=true` is still set on staging (as noted in 94-03-FLAG-FLIP-PROPOSAL.md:18) cannot be confirmed without `railway variables --service MINT`.

3. **`pytest --cov` not run** — test coverage percentages per module are unknown. B002 (sync DB in async handler) is not covered by a test that would detect the event loop blocking; this is an architectural finding not surfaced by the test suite.

4. **OpenAPI canonical drift** — no `generate_canonical.py` script found in `services/backend/scripts/`. Cannot verify if the OpenAPI schema has drifted from the live endpoint definitions without running `uvicorn` and diffing.

---

## AUDIT COMPLETE

**25 bugs found.** Severity breakdown: P0=3, P1=7, P2=12, P3=3.

Priority order for Phase 97 W0 fixes:
1. B001 — change railway.json to `-w 1` (1 line, immediate)
2. B004 — fix JTI-blacklist bare except (3 lines, security)
3. B018 — populate GROUNDING_PACK_KEYS_REGISTRY from CITATION_REGISTRY (1 line, enables gate test)
4. B015/B016 — truncate user_id in logs (2 lines each)
5. B003 — fatten legacy narrator prompt with cite syntax (medium, unblocks prod gate flip)
6. B002 — wrap sync memory-block builders in asyncio.to_thread (small)
7. B023 — generate + land snapshot alembic migration (medium, data loss risk)
8. B020 — add extra="forbid" to ClaimLocalDataRequest (trivial)
9. B012/B013/B014 — add logging to bare-except upload handlers (trivial each)
