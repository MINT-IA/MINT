---
phase: 29-compliance-privacy
plan: 05
subsystem: privacy-third-party
tags: [consent, nLPD-art-19, third-party, opposable-declaration, session-only, PRIV-02]
dependency_graph:
  requires: [27-01, 29-02]  # RedisClient, ConsentService + receipt_builder
  provides:
    - ConsentPurpose.THIRD_PARTY_ATTESTATION (5th enum value)
    - ConsentService.grant_nominative() — signed, merkle-chained
    - document_third_party.require_declaration_or_block() — HTTP 428 gate
    - /api/v1/consents/grant-nominative REST endpoint
    - document_memory_service.persist_fact(is_third_party, session_id) routing
    - Redis session store 'tpf:{session_id}:{hashed_key}' with 2h TTL
    - ThirdPartyDeclarationSheet Flutter widget
    - ThirdPartyFlow.handleGate() orchestration (428 → sheet → grant → retry)
    - ThirdPartyGate428.tryParse() 428 payload parser
    - 8 ARB keys × 6 languages
  affects:
    - Phase 29-06 (Bedrock EU migration — same gate applies when routed through EU)
    - Phase 13 (anonymous auth bridge — session_id already propagated)
    - Phase 28-01 (third-party detection feeds this gate)
tech_stack:
  added:
    - HMAC-SHA256 IP hashing (stdlib hmac, 16-byte truncated)
    - Redis setex session store for third-party atoms
  patterns:
    - Nominative receipt extras inside receipt_json (additive, never overwrites core)
    - Receipt-per-upload binding via declaredDocHash (prevents reuse)
    - 428 Precondition Required as opposable gate
    - Ephemeral atom storage (Redis tpf:*) vs persistent aggregate (profile_facts)
key_files:
  created:
    - services/backend/tests/services/document/__init__.py
    - services/backend/tests/services/document/test_third_party_declaration.py
    - apps/mobile/lib/widgets/document/third_party_declaration_sheet.dart
    - apps/mobile/lib/services/document/third_party_flow.dart
    - apps/mobile/test/widgets/document/third_party_declaration_sheet_test.dart
  modified:
    - services/backend/app/schemas/consent_receipt.py (+THIRD_PARTY_ATTESTATION, +ConsentGrantNominativeRequest)
    - services/backend/app/services/consent/consent_service.py (+grant_nominative)
    - services/backend/app/services/consent/receipt_builder.py (+hash_ip, +extra kwarg)
    - services/backend/app/services/document_third_party.py (+gate + exception)
    - services/backend/app/services/document_memory_service.py (+is_third_party routing)
    - services/backend/app/api/v1/endpoints/consents.py (+POST /grant-nominative)
    - services/backend/app/api/v1/endpoints/documents.py (+428 emission)
    - apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb (+8 keys each)
    - apps/mobile/lib/l10n/app_localizations*.dart (regenerated)
decisions:
  - No alembic migration needed — purpose_category is String(64), NOT a PG enum
    type. Adding the 5th ConsentPurpose value is a code-only change; existing
    receipts are unaffected. The plan's speculative "ALTER TYPE" guidance does
    not apply to this schema (verified in models/consent.py).
  - Gate TTL = 24 hours per doc_hash. Every upload of the same third-party
    doc_hash within 24h reuses the same declaration; after 24h the sheet
    re-appears. This balances audit freshness (T-29-23) with UX friction on
    legitimate re-uploads (T-29-24 still blocked via doc_hash binding).
  - IP stored as HMAC-SHA256(salt=MINT_IP_SALT, ip) truncated to 16 bytes.
    Deterministic for a given salt so audit can cluster receipts by source
    without ever exposing raw IP (satisfies T-29-23 while respecting
    minimisation art. 6 al. 2 nLPD).
  - Invite CTA is stub-only per plan constraints: it fires onInviteIntent
    callback and shows a "coming soon" snackbar. No SMS/email gateway is
    wired — that is deferred post-v2.7 per 29-05-PLAN.
  - session_id defaults to "anon" when absent. Anonymous Phase 13 flows
    therefore still honour session-only third-party atoms — the Redis key
    segments by session regardless of auth state.
  - Redis fail-open: when Redis is unreachable, persist_fact(is_third_party)
    returns True (accepted) but logs "accepted but not stored". Policy gate
    passed (profile_facts still skipped); atom simply has no persistence
    substrate that request. Acceptable because upstream 428 gate already
    proved the declaration exists — the worst case is an in-memory coach
    session forgetting a partner figure, which is the intended outcome at
    session end anyway.
metrics:
  duration_min: ~40
  tasks: 2
  files_created: 5
  files_modified: 15  # 7 backend + 8 Flutter (incl. 6 ARB + generated + tests)
  tests_added: 19  # 9 backend + 10 Flutter
  completed: "2026-04-14"
---

# Phase 29 Plan 05: Third-Party Declaration Opposable (PRIV-02) — Summary

## One-liner
Added the opposable declaration layer on top of Phase 28-01's silent third-party
detection: when a PERSON ≠ user is detected in an uploaded document, the
`/extract-vision` v2 path now emits `HTTP 428 Precondition Required` carrying
`{subjectNames, docHash, declarationEndpoint}` — the Flutter client shows
`ThirdPartyDeclarationSheet`, on accept POSTs to
`/consents/grant-nominative` which creates a signed, merkle-chained
`third_party_attestation` receipt bound to (user, doc_hash, subjectName), then
retries the original upload. Atomic third-party fact_keys are routed to a Redis
session bucket (`tpf:{session_id}:{hashed_key}`, 2h TTL) and never land in
`profile_facts`; aggregated outputs (e.g. `household_ratio`) still flow through
the normal persist path because they carry no atomic third-party signal.

## Tasks delivered

| # | Task | Commit | Tests |
|---|------|--------|-------|
| 1 | Backend — nominative receipt + 428 gate + session routing | `d327e8da` | 9 (gate, shape, TTL, doc_hash binding, revoke, Redis, IP hashing) |
| 2 | Flutter — declaration sheet + 428 flow + 8 ARB × 6 langs | `7e6b61b9` | 10 (sheet UX, parse, flow accept/cancel, invite stub) |

Commit `42ce942a` (TDD RED, failing tests) precedes Task 1.

**Total: 19 new tests green. 32 regression tests green (consent + document_memory + third-party detection).**

## Receipt shape — nominative extras

```json
{
  "receiptId":          "uuid4",
  "piiPrincipalId":     "sha256(user_id)",
  "piiController":      "MINT Finance SA",
  "purposeCategory":    "third_party_attestation",
  "policyUrl":          "https://mint.ch/privacy/v2.3.0",
  "policyVersion":      "v2.3.0",
  "policyHash":         "sha256(privacy_policy_v2.3.0.md)",
  "consentTimestamp":   "2026-04-14T22:30:12Z",
  "jurisdiction":       "CH",
  "lawfulBasis":        "consent_nLPD_art_6_al_6",
  "revocationEndpoint": "/api/v1/consents/{receipt_id}/revoke",
  "prevHash":           "sha256(prev_signature)",
  "subjectName":        "Lauren Martin",
  "subjectRole":        "declared_other",
  "declaredDocHash":    "sha256(uploaded_file_bytes)",
  "declaredFromIp":     "HMAC16(salt, ip)"
}
```

Signature = `HMAC-SHA256(canonical_json(receipt), signing_key)` — same scheme as
every other receipt, same merkle chain across all 5 purposes per user
(T-29-26 mitigation inherits from 29-02).

## Gate semantics

```
understand_document(bytes) → result
    ↓
require_declaration_or_block(user, result, doc_hash=sha256(bytes))
    ├── result.third_party_detected == False  → pass
    ├── fresh, non-revoked receipt matching doc_hash exists  → pass
    └── otherwise  → raise ThirdPartyDeclarationRequired
                      → endpoint returns HTTP 428 with JSON
```

TTL constant: `DECLARATION_TTL_HOURS = 24`. Receipt backdated beyond 24h
triggers gate again (tested). Receipt for a different doc_hash does not
satisfy the gate (tested — T-29-24 mitigation).

## Session-scoped persistence

`document_memory_service.persist_fact` signature extended:

```python
def persist_fact(
    db, user_id, key, value,
    *,
    source="coach",
    is_third_party=False,
    session_id: Optional[str] = None,
) -> bool
```

- `is_third_party=True` → `_persist_third_party_session` writes to Redis with
  `SETEX tpf:{session_id}:{sha12(key)} 7200 {value}`. Never inserts into
  `profile_facts`. Return True as long as the allowlist gate passed.
- `is_third_party=False` (default) → unchanged PRIV-06 path.
- Raw key / value never logged; only the 12-char key hash appears in
  observability (matches PRIV-03 privacy posture).

## HTTP 428 on /extract-vision (v2 path)

```json
{
  "detail": {
    "code": "third_party_declaration_required",
    "subjectNames": ["Lauren Martin"],
    "docHash": "sha256-hex-of-the-upload",
    "declarationEndpoint": "/api/v1/consents/grant-nominative"
  }
}
```

Client reads `response.detail`; FastAPI wraps dict `detail` that way. The
`ThirdPartyGate428.tryParse` helper transparently handles both wrapped and
unwrapped forms. Legacy `/extract-vision` path (pre-DOCUMENTS_V2_ENABLED) is
unaffected — the gate lives only in the v2 understand_document branch, matching
the 29-02 consent guard positioning.

## Flutter UX

- **Sheet copy (FR)** — matches VOICE_SYSTEM.md. No banned terms. `tu` form.
  Non-breaking spaces before `:;?!` where the French string carries punctuation
  bump (e.g. "document\u00a0?"). 8 new keys propagated to en/de/es/it/pt.
- **Buttons** — primary: "Oui, j'ai son consentement"; secondary: "Non, annuler
  l'upload"; stub: "Inviter {Name} sur MINT" (fires analytics + toast).
- **Flow** — `ThirdPartyFlow.handleGate()` orchestrates sheet → grant per
  subject name → returns `GrantOutcome.{granted,cancelled,failed}`. Caller
  retries the upload on granted, aborts on cancelled. All three branches
  covered by widget tests with `postOverride` injection (no ApiService stub
  required).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Plan referenced `services/backend/app/api/v1/endpoints/document_upload.py` which does not exist**
- Found during: Task 1 context load.
- Issue: Plan lists `document_upload.py` as a modified file; the real upload
  endpoint in this codebase is `extract_with_claude_vision` inside
  `endpoints/documents.py` (DOCUMENTS_V2_ENABLED branch, understand_document
  call site).
- Fix: Wired the 428 emission into `documents.py` at the natural spot:
  immediately after `understand_document()` returns, before the function hands
  the result back to the caller. HTTPException is re-raised so the outer
  `except Exception` block cannot swallow the 428.

**2. [Rule 3 — Blocking] `pyffx` missing from local Python 3.9 env**
- Found during: running `test_third_party_fact_routed_to_session_store_not_profile_facts`.
- Issue: `app.services.privacy.__init__` imports `fpe` which imports `pyffx`;
  this module is not installed on the dev machine (affects Phase 29-03 tests
  too — pre-existing).
- Fix: `pip install pyffx` (one-off dev-env fix, not a code change). CI runs
  pin pyffx via requirements already. Kept out of scope per Rule 3 footprint.

**3. [Rule 2 — Missing] Plan suggested an alembic migration `ALTER TYPE consentpurpose ADD VALUE`**
- Found during: Task 1 design.
- Issue: `consents.purpose_category` is `String(64)` (see `models/consent.py`),
  not a Postgres enum type. There is no `consentpurpose` type in the DB to
  alter; the enum is a Python-level string enum persisted as a plain varchar.
- Fix: No migration needed. The new `THIRD_PARTY_ATTESTATION = "third_party_attestation"`
  enum value is a code-only change; storing new rows with this purpose string
  is already allowed by the existing column definition. Documented explicitly
  in the Decisions block above to avoid re-opening later.

### Widget test environment adjustments

- Test harness uses `Locale('fr')` and reads localisations via the generated
  `S` class (matches existing 29-02 widget tests). No surface-size override
  required — the sheet is compact and rendered fully in the default viewport.

## Authentication Gates

None. `/consents/grant-nominative` is JWT-gated via `require_current_user`,
consistent with every other `/api/v1/*` endpoint. Client IP is read from
`Request.client.host` (FastAPI populates it from the peer address) — hashed
before storage via `receipt_builder.hash_ip`.

## Known Stubs

- `Inviter {Name} sur MINT` CTA fires analytics event
  `third_party_invite_intent` and shows a "coming soon" snackbar. No SMS/email
  gateway is wired. This is intentional per 29-05-PLAN constraints (deferred
  post-v2.7). The CTA is visible in UI so the "Shared Album" USP signal ships
  with v2.7 even if the async flow does not.

## Follow-ups (deferred)

- **Async invite (SMS/email)** — wire a real delivery path in phase 30 or
  later. Hook: `ThirdPartyFlow._log('third_party_invite_intent', ...)` already
  captures the intent.
- **Household-aggregate whitelist** — current design trusts callers to pass
  `is_third_party=True` for atoms and `is_third_party=False` for aggregates.
  A later hardening could enforce this via a separate `persist_aggregate`
  API that only accepts a fixed set of aggregate keys (`household_ratio`,
  `couple_rente_combined`, …).
- **ProfileDrawer entry for active declarations** — user cannot currently see
  the list of third-party declarations they signed. Privacy Center screen
  could list them under a "Déclarations de tiers" section.
- **Avocat validation** — the declaration copy ("Tu confirmes avoir obtenu le
  consentement de …") is provisional under nLPD art. 19 / art. 6 al. 6. A
  lawyer-approved PDF should be linked from `thirdPartyDeclarationNoticeLink`
  in a later sprint. Tracked in 29-CONTEXT §DPA Anthropic / Walder Wyss.
- **Replace 24h TTL with user-configurable window** — current TTL is a
  constant; a per-user or per-canton override could come later.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: new_signed_persistence | services/backend/app/services/consent/consent_service.py | `grant_nominative` appends signed HMAC rows to the merkle chain like every other grant. T-29-26 tamper detection inherited. |
| threat_flag: new_auth_boundary | services/backend/app/api/v1/endpoints/consents.py | `POST /grant-nominative` endpoint. user_id sourced from JWT via `require_current_user` — request body cannot forge it. T-29-10 mitigation consistent. |
| threat_flag: ephemeral_atom_store | services/backend/app/services/document_memory_service.py | New Redis session bucket with 2h TTL holding third-party atoms. Never persisted. Scheduled cleanup = TTL expiry. |
| threat_flag: ip_hashing | services/backend/app/services/consent/receipt_builder.py | Client IP persisted as HMAC-SHA256-16 digest (not plaintext). Salt = MINT_IP_SALT env — operators with DB read cannot recover raw IP. |

## Self-Check: PASSED

Created files verified:
- FOUND: services/backend/tests/services/document/__init__.py
- FOUND: services/backend/tests/services/document/test_third_party_declaration.py
- FOUND: apps/mobile/lib/widgets/document/third_party_declaration_sheet.dart
- FOUND: apps/mobile/lib/services/document/third_party_flow.dart
- FOUND: apps/mobile/test/widgets/document/third_party_declaration_sheet_test.dart

Commits verified:
- FOUND: 42ce942a (TDD RED)
- FOUND: d327e8da (Task 1 backend GREEN)
- FOUND: 7e6b61b9 (Task 2 Flutter GREEN)

Tests: 9 backend + 10 Flutter = **19 new tests, all green**.
Regression: 32 related backend tests (consent + document_memory + third-party
detection) green. `flutter analyze` on new files: **0 issues**.

PRIV-02 satisfied: opposable declaration, nominative receipt bound to
(user, doc_hash, subjectName), session-scoped third-party atoms via Redis
TTL, invite stub shipped. Declaration copy stands in for the notional
lawyer-approved nLPD art. 19 text until avocat review.
