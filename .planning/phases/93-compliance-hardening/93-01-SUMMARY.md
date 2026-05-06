---
phase: 93-compliance-hardening
plan: 01
subsystem: backend-compliance
tags: [audit-log, FINMA, OAR-G, COMP-01, BUG-18-P0]
requires:
  - p86_eclairage_delivered (alembic head before plan)
provides:
  - coach_message_audits table (10y retention)
  - CoachMessageAudit SQLAlchemy model
  - hash_for_audit() helper
  - additive banned_terms_filtered key on ComplianceGuardrails.filter_response
affects:
  - /api/v1/coach/chat (best-effort audit emit before return)
  - /api/v1/anonymous/chat (best-effort audit emit, same txn as eclairage_delivered)
tech-stack:
  added: []
  patterns:
    - Best-effort try/except + Sentry breadcrumb (mirrors coach_chat:2305-2365 profile_extractor)
    - Idempotent alembic guard via inspector.get_table_names (mirrors p86)
    - Additive return-dict key (filter_response banned_terms_filtered)
key-files:
  created:
    - services/backend/app/models/coach_message_audit.py
    - services/backend/app/utils/audit_hash.py
    - services/backend/alembic/versions/p93_coach_message_audit.py
    - services/backend/tests/test_alembic_audit_log_forward_rollback.py
    - services/backend/tests/test_audit_log_emit_on_coach_chat.py
    - services/backend/tests/test_audit_log_emit_on_anonymous_chat.py
    - services/backend/tests/test_audit_log_best_effort.py
  modified:
    - services/backend/app/api/v1/endpoints/coach_chat.py
    - services/backend/app/api/v1/endpoints/anonymous_chat.py
    - services/backend/app/models/__init__.py
    - services/backend/app/services/rag/guardrails.py
decisions:
  - hash v1 unsalted SHA-256 (salt deferred to Phase 96)
  - Re-scan answer with ComplianceGuardrails in audit hook (1 line) instead of plumbing compliance_meta through agent loop (5+ files)
  - filter_response patched (NOT compliance_guard.validate) because that's the actual integration point both endpoints already use
metrics:
  tasks-completed: 2
  tests-added: 21
  duration-mins: ~75
  completed: 2026-05-07
---

# Phase 93 Plan 01: Coach message audit log table + dual hook — Summary

OAR-G art. 24 + FINMA Guidance 8/2024 §VI compliant audit log persists one
hashed-row-per-coach-response so a FINMA inspector can run
`SELECT * FROM coach_message_audits WHERE created_at > '2026-05-06'` and
see prompt+response hashes (nLPD-safe), archetype, banned-term-hit flag,
eclairage kind, and retained_until=+10y. Closes COMP-01 + BUG #18 P0.

## Deliverables

1. **`services/backend/app/models/coach_message_audit.py`** —
   `CoachMessageAudit` SQLAlchemy model, 9 columns, 10y retention default,
   indexed on `session_id` + `created_at`. Mirrors `audit_event.py` style.
2. **`services/backend/alembic/versions/p93_coach_message_audit.py`** —
   forward + rollback migration, idempotency guards on both upgrade and
   downgrade. `revision = "p93_coach_message_audit"`,
   `down_revision = "p86_eclairage_delivered"`. Verified manually:
   forward → table+2 indexes; rollback → clean drop; re-forward → green.
3. **`services/backend/app/utils/audit_hash.py`** — `hash_for_audit(text)`
   SHA-256 hex helper (64 chars). v1 unsalted; Phase 96 will add
   `AUDIT_PROMPT_SALT`.
4. **`services/backend/app/services/rag/guardrails.py`** — additive
   `banned_terms_filtered: bool` key on the `filter_response()` return
   dict so the audit hook can read banned-term hits without re-scanning
   internally — but actually the hook DOES re-scan (see Deviation 2).
5. **Audit hook in `coach_chat.py:2622`** — try/except wrapping a single
   `CoachMessageAudit` insert, immediately before
   `return CoachChatResponse(...)`. Sentry breadcrumb on success.
6. **Audit hook in `anonymous_chat.py:347`** — same pattern, but the
   row is added to the session WITHOUT calling `db.commit()`; the
   existing `db.commit()` below commits the audit row in the same
   transaction as `anon_session.eclairage_delivered=True`.
7. **4 pytest files, 21 tests, all green:**
   - `test_alembic_audit_log_forward_rollback.py` — column-shape +
     nullability/PK invariants (12 parametrized tests), revision graph
     linkage, idempotency-guard reference check, INSERT round-trip.
   - `test_audit_log_emit_on_coach_chat.py` — happy path, banned-term
     propagation, archetype-from-profile.
   - `test_audit_log_emit_on_anonymous_chat.py` — turn 1 (no
     eclairage), turn 2 (eclairage_kind="fiscal_margin_3a").
   - `test_audit_log_best_effort.py` — coach_chat + anonymous_chat
     both handle a mocked DB error (200 response, audit warning logged,
     no row persisted).

## Test Counts

| Bucket                              | Before   | After    | Delta |
| ----------------------------------- | -------- | -------- | ----- |
| Plan-93-01 audit tests              | 0        | 21       | +21   |
| Backend regression (filter_response callers: test_guardrails_coverage + test_rag) | 71 | 71 | 0 |
| Backend regression (test_anonymous_chat + test_coach_chat_endpoint) | 54 | 54 | 0 |
| Full backend `pytest -q` (excl. integration) | ~6028 | 6028 + 21 = 6049 | +21 |

Full backend suite: 6049 passing, 25 skipped, 1 pre-existing failure
(`test_compliance_wording.py::test_no_banned_words` flagging
`anonymous_chat.py:169` "Vocabulaire LSFin interdit" docstring; verified
pre-existing on `feat/phase-A-e2e-unblock` by stashing this plan's
changes — see `deferred-items.md`).

## Deviations from Plan

### Deviation 1 — `ComplianceGuardrails.filter_response`, NOT `ComplianceGuard.filter_response`

**Plan said:** patch `app/services/coach/compliance_guard.py:43-160` so
`filter_response()` (~line 156) returns `banned_terms_filtered: bool`.

**Reality:** `ComplianceGuard.filter_response()` does not exist. The
class has `validate()`. The actual `filter_response()` method lives on
`ComplianceGuardrails` in `app/services/rag/guardrails.py:277`, which is
the integration point both endpoints (and the orchestrator) already
call. Plan referenced two different classes interchangeably; I patched
the real integration point.

**Why:** `ComplianceGuardrails.filter_response` already delegates to
`ComplianceGuard.validate` for FR text and reads back violations. Adding
`banned_terms_filtered` here is the additive 2-line change. Patching
`ComplianceGuard` would have required changing every caller of
`validate()` to read a new key, which `validate()` doesn't even surface
as a dict.

**Files modified:** `app/services/rag/guardrails.py` (NOT
`compliance_guard.py`).

### Deviation 2 — Audit hook re-scans answer instead of plumbing `compliance_meta`

**Plan said:** plumb `banned_terms_filtered` via
`loop_result["compliance_meta"]["banned_terms_filtered"]` (1 line in
`_run_agent_loop` result-merge step).

**Reality:** `loop_result` does not currently expose `compliance_meta`
at all, and the orchestrator's filter happens deep inside
`_NoRagOrchestrator.query` / `RAGOrchestrator.query` — plumbing
`compliance_meta` would have touched 4+ files
(`coach_chat.py:_NoRagOrchestrator.query`, `_run_agent_loop`,
`_call_with_fallback`, `app/services/rag/orchestrator.py:RAGOrchestrator.query`).

**What I did instead:** the audit hook re-runs
`ComplianceGuardrails().filter_response(answer)` once on the final
response text and reads `banned_terms_filtered` from the additive key.
This is one cheap regex pass per request (the same regex pass that
already runs upstream — its result is just discarded from the
top-level scope). Karpathy practice 3 (surgical change): single-file
diff in coach_chat.py, no plumbing.

**Files modified:** `coach_chat.py` only. The orchestrator + agent
loop are untouched.

### Deviation 3 — Idempotent rollback in p93 migration

**Plan said:** `downgrade()` is `op.drop_table(...)` with a guard.

**Reality:** the upgrade ALSO creates 2 named indexes. A clean rollback
must drop indexes first to keep the migration symmetric across
re-runs.

**What I did:** `downgrade()` checks `inspector.get_indexes(...)` and
drops `ix_coach_message_audits_session_id` +
`ix_coach_message_audits_created_at` first, then drops the table.

**Files modified:** `alembic/versions/p93_coach_message_audit.py`
(small extension of the plan's spec).

### Deviation 4 — Per-test cleanup fixture (NOT a conftest.py change)

**Plan said:** use existing pytest fixtures.

**Reality:** `tests/conftest.py:clean_database` does not include
`CoachMessageAudit` (or `AnonymousSession` for the anon test). Adding
to conftest would touch a shared fixture and risk affecting unrelated
tests.

**What I did:** each new audit test file declares its own autouse
`_wipe_audit_rows_between_tests` fixture that wipes only the rows it
cares about. Surgical (Karpathy practice 3).

## Migration Revision Graph

```
... → 29_04_drop_auto_confirmed
       → p86_eclairage_delivered
            → p93_coach_message_audit (NEW; current head)
```

`alembic upgrade head` from a stamped p86 DB creates the table + 2
indexes. `alembic downgrade -1` drops them cleanly. Re-running upgrade
is a no-op (idempotency guard via `inspector.get_table_names()`).

## ComplianceGuardrails Surface Change Audit

`grep -rn 'filter_response('` finds 6 production call sites + 9 test
call sites. All read `result["text"]` and `result["disclaimers_added"]`.
None destructure the dict (no `**kwargs`), so adding
`banned_terms_filtered` is fully additive. Verified by running
`tests/test_guardrails_coverage.py` (3 tests) and `tests/test_rag.py`
(68 tests) — 71/71 green.

## Pre-push Checklist

- [x] `grep -rn 'filter_response('` — no caller broken (additive key).
- [x] `python3 -m pytest tests/` (excl. integration) — green minus 1
      pre-existing failure unrelated to this plan (see `deferred-items.md`).
- [x] No new mobile / ARB strings — no `flutter gen-l10n` needed.
- [x] No endpoint response-shape change — no OpenAPI canonical regen
      needed (audit row is server-internal).
- [x] Real alembic forward → rollback → re-forward verified manually
      against a fresh sqlite DB stamped at p86_eclairage_delivered.
- [x] `git grep "CoachMessageAudit("` finds exactly 2 production call
      sites + 1 model file + 4 test files (no leakage).

## Forward to Phase 95

- Add a `testcontainers-postgres` job to CI that runs
  `alembic upgrade head && alembic downgrade -1 && alembic upgrade head`
  from an empty DB. The `inspector.get_columns("anonymous_sessions")`
  failure visible in p86 (NoSuchTableError on a totally empty DB) is a
  pre-existing alembic chain weakness that p93 inherited; Phase 95
  should also harden p86 to use `get_table_names()` first.
- Add a `coach_message_audits` row to the FINMA inspector test fixture
  (Phase 97) and assert the SELECT pattern emits one row per recent
  coach response.
- Promptfoo evals (Phase 95) should fail any test fixture that does NOT
  produce a `coach_message_audits` row when one was expected.

## Self-Check: PASSED

- `services/backend/app/models/coach_message_audit.py` — FOUND
- `services/backend/app/utils/audit_hash.py` — FOUND
- `services/backend/alembic/versions/p93_coach_message_audit.py` — FOUND
- `services/backend/tests/test_alembic_audit_log_forward_rollback.py` — FOUND (14 tests)
- `services/backend/tests/test_audit_log_emit_on_coach_chat.py` — FOUND (3 tests)
- `services/backend/tests/test_audit_log_emit_on_anonymous_chat.py` — FOUND (2 tests)
- `services/backend/tests/test_audit_log_best_effort.py` — FOUND (2 tests)
- `services/backend/app/api/v1/endpoints/coach_chat.py` — modified (audit hook before return)
- `services/backend/app/api/v1/endpoints/anonymous_chat.py` — modified (audit hook before commit)
- `services/backend/app/services/rag/guardrails.py` — modified (additive `banned_terms_filtered` key)
- `services/backend/app/models/__init__.py` — modified (CoachMessageAudit registration)
- 21/21 audit tests green
- Real alembic forward+rollback+forward green
- BUG #18 P0 closed
