---
phase: mint-data-architecture-v1-02-event-log-projection
plan: 02
type: execute
wave: 1
depends_on: [01]
files_modified:
  - services/backend/alembic/versions/p98_fact_event_projection_dek.py
  - services/backend/alembic/versions/p113_extend_projection_audit_mobile.py
  - services/backend/alembic/versions/p114_hmac_pepper_audit_events.py
  - services/backend/alembic/versions/p115_hmac_pepper_pii_columns.py
  - services/backend/alembic/versions/p116_snapshot_constants_invalidation.py
  - services/backend/app/models/fact_event.py
  - services/backend/app/models/fact_current.py
  - services/backend/app/models/encryption/__init__.py
  - services/backend/app/models/encryption/encrypted_value.py
  - services/backend/app/models/dek_vault.py
  - services/backend/app/models/projection_audit_record.py
  - services/backend/app/models/audit_event.py
  - services/backend/app/services/audit/__init__.py
  - services/backend/app/services/audit/hmac_pepper.py
  - services/backend/app/services/audit/audit_service.py
  - services/backend/app/services/encryption/encrypted_value_helper.py
  - services/backend/app/services/encryption/key_vault.py
  - services/backend/app/services/projector/__init__.py
  - services/backend/app/services/projector/fact_projector.py
  - services/backend/app/services/snapshots/snapshot_service.py
  - services/backend/app/services/cache/snapshot_cache.py
  - services/backend/app/api/v1/endpoints/audit_mobile.py
  - services/backend/app/api/v1/endpoints/privacy.py
  - services/backend/app/api/v1/api.py
  - services/backend/app/observability/counters.py
  - services/backend/app/core/sentry.py
  - tools/openapi/mint.openapi.canonical.json
  - services/backend/tests/test_hmac_pepper.py
  - services/backend/tests/test_encrypted_value_model.py
  - services/backend/tests/test_encrypted_value_helper.py
  - services/backend/tests/test_dek_envelope_concurrency.py
  - services/backend/tests/test_key_vault_logical_id.py
  - services/backend/tests/integration/test_canary_monthly_gross_income.py
  - services/backend/tests/integration/test_projector_idempotency.py
  - services/backend/tests/integration/test_projector_atomicity.py
  - services/backend/tests/integration/test_dek_shred_opacity.py
  - services/backend/tests/integration/test_audit_mobile_link.py
  - services/backend/tests/integration/test_migration_p98.py
  - services/backend/tests/integration/test_migration_p113.py
  - services/backend/tests/integration/test_migration_p114.py
  - services/backend/tests/integration/test_migration_p115.py
  - services/backend/tests/integration/test_constants_propagation_pit.py
  - services/backend/tests/integration/test_privacy_delete_real_count.py
  - services/backend/tests/integration/test_snapshot_cache_invalidation.py
  - services/backend/tests/integration/test_partition_declared.py
  - apps/mobile/lib/services/audit/anonymous_session_id.dart
  - apps/mobile/lib/services/audit/mobile_l1_audit_service.dart
  - apps/mobile/lib/services/audit/offline_queue.dart
  - apps/mobile/lib/services/audit/audit_buffer_db.dart
  - apps/mobile/lib/services/lifecycle/app_lifecycle_observer.dart
  - apps/mobile/test/services/audit/anonymous_session_buffer_test.dart
  - apps/mobile/test/services/audit/offline_queue_test.dart
  - apps/mobile/test/services/audit/mobile_l1_audit_service_test.dart
  - apps/mobile/pubspec.yaml
  # --- iter-2 additions (promoted from iter-2 appendix; structurally required for parser visibility) ---
  - services/backend/app/services/encryption/dek_tombstone.py                          # A1
  - services/backend/app/services/encryption/banned_terms_runtime.py                   # B6
  - services/backend/app/db.py                                                         # B12 + B15
  - services/backend/tests/integration/test_migration_p98_iter2.py                     # A1 + A2 + A3 + B8 + B9 + B10
  - services/backend/tests/integration/test_fact_current_covering_index.py             # A3
  - services/backend/tests/integration/test_dek_vault_restrict_tombstone.py            # A1
  - services/backend/tests/integration/test_projector_concurrent_upsert.py             # A8
  - services/backend/tests/integration/test_canary_multi_shape_parity.py               # A11 + D-34
  - services/backend/tests/integration/test_canary_pillar_3a_balance.py                # A11
  - services/backend/tests/integration/test_canary_archetype_tags_jsonb.py             # A11
  - services/backend/tests/integration/test_canary_lpp_avoirs_nullable.py              # A11
  - services/backend/tests/integration/test_canary_coach_extracted_toast.py            # A11
  - services/backend/tests/fixtures/canary_fixtures.py                                 # A11
  - tools/checks/no_mobile_fact_current_regulatory_read.py                             # B2
  - tools/checks/tests/test_no_mobile_fact_current_regulatory_read.py                  # B2
  - apps/mobile/test/_fixtures/bad_regulatory_read.dart                                # B2
  # --- iter-3 additions (HIGH-A1 + HIGH-A2 from Claude-Opus post-iter-2 review) ---
  - services/backend/conftest.py                                                       # iter-3 iA1 (requires_pg marker)
  - services/backend/tests/integration/test_audit_mobile_link_handshake_replay_ordering.py  # iter-3 iA2
autonomous: false
decisions: [D-01, D-02, D-03, D-12, D-13, D-14, D-15, D-16, D-17, D-19, D-25, D-26, D-27, D-28, D-29, D-30]
checkpoint_reason: "Task 1 (D-02 Railway KMS rotation rehearsal env-var verification) requires Julien to confirm Railway dashboard procedure for env-var rotation in production environment per CONTEXT D-02 + RESEARCH § Runtime State Inventory. All other tasks autonomous."
requirements_addressed:
  - CONTEXT.md#D-01 fact_current latency p50≤5ms p99≤20ms + partition-ready
  - CONTEXT.md#D-02 KMS Railway-native logical key-id mint-master-v1
  - CONTEXT.md#D-03 DEK shred all-or-nothing + dek_scope future-proof
  - CONTEXT.md#D-12 D-MOB-03 mobile L1 audit POST (extend projection_audit_record)
  - CONTEXT.md#D-13 D-MOB-04 clean separation (no fact_event dual-write from mobile)
  - CONTEXT.md#D-14 audit_events.user_id_hash HMAC-pepper backfill + plaintext drop
  - CONTEXT.md#D-15 audit_events.actor_email/ip/user_agent HMAC-pepper hash
  - CONTEXT.md#D-16 /privacy/delete real DSAR count
  - CONTEXT.md#D-17 SnapshotModel.constants_version_hash cache invalidation
  - CONTEXT.md#D-19 app-side projector with session.begin()
  - CONTEXT.md#D-25 first-slice canary monthly_gross_income end-to-end parity
  - CONTEXT.md#D-26 value_enc typed JSONB Pydantic v2 EncryptedValue
  - CONTEXT.md#D-27 fact_event idempotency UNIQUE + projector skip counter
  - CONTEXT.md#D-28 PARTITION BY HASH from day one
  - CONTEXT.md#D-29 confidence JSONB full EnhancedConfidence 4-axis
  - CONTEXT.md#D-30 anonymous-session buffer mechanics (SQLite + 30d TTL + UUID v7)
  - CONTEXT.md#D-33 (declared only — 6 new counters declared; firing assertions in Plan 02-04)
threat_model_summary:
  - T-02-01 KMS key compromise (mitigated: Railway secret + logical key-id rotation procedure documented in Plan 02-04; rehearsal gated by Julien checkpoint)
  - T-02-02 RTBF crypto-shred failure (mitigated: existing crypto_shred_user + test_dek_shred_opacity asserts NULL wrapped_dek → all value_enc rows decrypt-error)
  - T-02-03 Envelope payload tamper (mitigated: AESGCM AAD binds ciphertext to user_id; cross-user decrypt fails authentication; existing envelope.py invariant)
  - T-02-04 Audit integrity / HMAC-pepper rotation (mitigated: pepper ≥32 chars enforced; backfill migration creates user_id_hash_v1 column for transition; rotation procedure deferred to Plan 02-04 doc)
  - T-02-05 Audit replay drift (mitigated: UNIQUE(anonymous_session_id, observed_at) blocks replay; returns 200+count not 409 for retry-safety)
must_haves:
  truths:
    - "`fact_event` table created with append-only enforcement (Postgres REVOKE UPDATE/DELETE on PUBLIC + app_role); SQLite test path INSERT-only by convention."
    - "`fact_event` Postgres ships PARTITION BY HASH (subject_id) PARTITIONS 1 from day one; first partition `fact_event_p_0` created in same migration (D-28)."
    - "`fact_event` UNIQUE constraint on (subject_type, subject_id, fact_type, source_id, recorded_at) enforced; second INSERT of same tuple raises IntegrityError (D-27)."
    - "`fact_current` denormalised projection with composite PK (subject_type, subject_id, fact_type) + Postgres covering index `ix_fact_current_subject_covering` on (subject_id) INCLUDE (value_enc, latest_event_id, confidence, visibility) (D-01)."
    - "`dek_vault.dek_scope` column added (default `'user'`, NOT NULL); existing rows backfill via server_default (D-03)."
    - "`projection_audit_record` extended with `source` (NOT NULL DEFAULT 'projection'), `app_version` (nullable), `observed_at` (nullable), `anonymous_session_id` (nullable VARCHAR(36)) via alembic p113 (D-12)."
    - "`/v1/audit/mobile-session-start` + `/v1/audit/mobile-session-link` endpoints exposed; OpenAPI canonical regenerated; endpoints write to `projection_audit_record` ONLY (D-12 + D-13 clean separation; assertion test confirms no `fact_event` write)."
    - "Pydantic v2 `EncryptedValue` model in `app/models/encryption/encrypted_value.py` with `model_config={extra:forbid}` + `Literal['AES-256-GCM']` constraint (D-26)."
    - "`encrypt_value(db, user_id, value) -> dict` + `decrypt_value(db, user_id, envelope) -> Any` helpers wrap existing `encrypt_bytes`/`decrypt_bytes`; AAD bound to user_id; round-trip test green (D-26)."
    - "`project_fact_event(session, event)` inserts FactEvent + upserts FactCurrent inside caller's `session.begin()`; transactional atomicity test confirms rollback on exception in either side (D-19)."
    - "Projector skips upsert when `event.event_id <= existing.latest_event_id` (sequence-number monotonicity); `mint_projector_idempotency_skip_total` counter increments on skip (D-27)."
    - "`hmac_user_id(user_id)` canonical entry point in `app/services/audit/hmac_pepper.py`; uses `MINT_AUDIT_HASH_PEPPER` ≥32 chars; raises `PepperNotConfigured` outside TESTING=1 if missing (D-07/D-24)."
    - "Alembic p114 backfills `audit_events.user_id_hash` with HMAC-pepper; existing SHA-256 hashes migrated; plaintext `user_id` column NULLed on Postgres post-deprecation (D-14)."
    - "Alembic p115 adds `actor_email_hash`, `ip_address_hash`, `user_agent_hash` columns to `audit_events`; backfills via HMAC-pepper; writer service updates emit hash columns going forward; plaintext columns retained one deprecation cycle (D-15)."
    - "`/privacy/delete` returns DSAR receipt with REAL row counts from chat_messages + coach_insights + snapshots + projection_audit_records (D-16)."
    - "`SnapshotModel.constants_version_hash` invalidates the snapshot cache when active regulatory version changes; cache key extended (D-17)."
    - "Flutter `MobileL1AuditService` with cold-start hook + warm-resume detector (>30min) + offline SQLite buffer (sqflite_sqlcipher) + exponential backoff replay (1s/2s/4s/8s/16s, cap 5min) + UUID v7 anonymous_session_id persisted (D-12 + D-30)."
    - "First-slice canary `monthly_gross_income` end-to-end parity test: write fact_event → projector → fact_current decrypted == SnapshotModel.gross_income for same user; test exits 0 (D-25)."
    - "Existing `dek_vault.user_id` UNIQUE conflict on concurrent first-write retried once (Pitfall 2 mitigation); `test_dek_envelope_concurrency.py` green."
    - "6 new observability counters DECLARED in `app/observability/counters.py` (not yet asserted firing — Plan 02-04 close-out)."
    - "Sentry `before_send` strips `value_enc` field from breadcrumbs / error events (no plaintext leak)."
  artifacts:
    - path: "services/backend/app/models/fact_event.py"
      provides: "FactEvent ORM with __table_args__ partition + UNIQUE + composite PK"
      contains: "class FactEvent"
      min_lines: 60
    - path: "services/backend/app/models/fact_current.py"
      provides: "FactCurrent denormalised projection ORM"
      contains: "class FactCurrent"
    - path: "services/backend/app/models/encryption/encrypted_value.py"
      provides: "Pydantic v2 EncryptedValue D-26 wire shape"
      contains: "class EncryptedValue(BaseModel)"
    - path: "services/backend/app/services/encryption/encrypted_value_helper.py"
      provides: "encrypt_value/decrypt_value JSONB wrappers"
      exports: ["encrypt_value", "decrypt_value"]
    - path: "services/backend/app/services/projector/fact_projector.py"
      provides: "project_fact_event() session.begin() projector"
      exports: ["project_fact_event"]
    - path: "services/backend/app/services/audit/hmac_pepper.py"
      provides: "HMAC-pepper canonical entry (hmac_user_id + hmac_pii)"
      exports: ["hmac_user_id", "hmac_pii", "PepperNotConfigured"]
    - path: "services/backend/alembic/versions/p98_fact_event_projection_dek.py"
      provides: "fact_event + fact_current + dek_scope migration"
      contains: "PARTITION BY HASH"
    - path: "services/backend/app/api/v1/endpoints/audit_mobile.py"
      provides: "/v1/audit/mobile-session-start + /v1/audit/mobile-session-link"
      contains: "@router.post"
    - path: "apps/mobile/lib/services/audit/mobile_l1_audit_service.dart"
      provides: "Flutter Mobile L1 audit service with lifecycle hooks + offline replay"
      contains: "class MobileL1AuditService"
  key_links:
    - from: "services/backend/app/services/projector/fact_projector.py"
      to: "services/backend/app/models/fact_event.py"
      via: "session.add(FactEvent) + session.flush() inside session.begin()"
      pattern: "session\\.add\\(event\\)"
    - from: "services/backend/app/services/projector/fact_projector.py"
      to: "services/backend/app/observability/counters.py"
      via: "mint_projector_idempotency_skip_total.inc() on event.event_id <= existing.latest_event_id"
      pattern: "mint_projector_idempotency_skip_total"
    - from: "services/backend/app/services/encryption/encrypted_value_helper.py"
      to: "services/backend/app/services/encryption/envelope.py"
      via: "encrypt_value calls encrypt_bytes; AAD = user_id binding preserved"
      pattern: "from app.services.encryption.envelope import encrypt_bytes, decrypt_bytes"
    - from: "services/backend/app/api/v1/endpoints/audit_mobile.py"
      to: "services/backend/app/models/projection_audit_record.py"
      via: "Single-row INSERT per session-start; batch INSERT per session-link with UNIQUE(anonymous_session_id, observed_at)"
      pattern: "ProjectionAuditRecord\\(.*anonymous_session_id="
    - from: "services/backend/app/services/audit/audit_service.py"
      to: "services/backend/app/services/audit/hmac_pepper.py"
      via: "all user_id_hash writes go through hmac_user_id() canonical entry"
      pattern: "hmac_user_id\\("
    - from: "apps/mobile/lib/services/audit/mobile_l1_audit_service.dart"
      to: "services/backend/app/api/v1/endpoints/audit_mobile.py"
      via: "POST /v1/audit/mobile-session-{start,link} via api_service.dart"
      pattern: "/v1/audit/mobile-session"
---

<objective>
Wave 1 ships the Phase 02 event-log + projection core: three new tables (`fact_event` append-only + `fact_current` denormalised + `dek_vault` extension), DEK envelope wiring via existing `key_vault.py` (logical key-id `mint-master-v1`, D-02), the app-side projector with `session.begin()` transactional atomicity (D-19), the Pydantic v2 `EncryptedValue` JSONB shape (D-26) with the ~25-LOC `encrypt_value/decrypt_value` helpers wrapping existing `envelope.py` primitives, the HMAC-pepper canonical entry point + four Phase 01 carry-over migrations (D-14 + D-15 + D-16 + D-17), the `projection_audit_record` extension for D-MOB-03 Mobile L1 audit, the matching Flutter `MobileL1AuditService` with offline SQLite buffer + UUID v7 + lifecycle hooks (D-30), and the first-slice end-to-end canary parity test on `monthly_gross_income` (D-25).

Purpose: by the end of Wave 1, every primitive the 5-PR migration sequence (Plan 02-03) consumes is in-tree, tested, observable, and parity-proven. Writers will dual-write from PR-1 onward; readers will cut over in PR-3. The canary parity gate is the input gate for Wave 2.

Output: 16 sub-tasks landing across 3 atomic execution tasks below. ~50 new tests, ~5 new migrations, ~6 new ORM/service modules, 1 new Flutter service package, 0 user-facing UI changes.

**`autonomous: false`** for one reason only: Task 1 requires Julien to confirm the Railway env-var rotation procedure works on his Railway dashboard for `MINT_AUDIT_HASH_PEPPER` (D-02 + D-07 operational gate per RESEARCH § Runtime State Inventory). All other operations (alembic, code, tests, OpenAPI regen, Flutter, lints) are Claude-autonomous.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-CONTEXT.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-RESEARCH.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-VALIDATION.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-01-prereqs-lints-harness-SUMMARY.md
@.planning/decisions/2026-05-18-phase02-event-log-projection-panel-synthesis.md
@.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md
@services/backend/app/services/encryption/envelope.py
@services/backend/app/services/encryption/key_vault.py
@services/backend/app/services/encryption/column_type.py
@services/backend/app/models/dek_vault.py
@services/backend/app/models/projection_audit_record.py
@services/backend/app/models/audit_event.py
@services/backend/app/models/snapshot.py
@services/backend/app/models/lucidity/_payload.py
@services/backend/alembic/versions/p111_projection_audit.py
@services/backend/alembic/versions/p112_audit_event_user_hash.py
@services/backend/alembic/versions/p95_dag_invalidation.py
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/observability/counters.py
@services/backend/app/core/sentry.py
@services/backend/app/services/snapshots/snapshot_service.py
@apps/mobile/pubspec.yaml
@apps/mobile/lib/services/api_service.dart

<interfaces>
<!-- Verbatim contracts the executor needs. NO codebase exploration required. -->

From `services/backend/app/services/encryption/envelope.py:36-90` (existing primitives — REUSE, do not re-implement):
```python
def encrypt_bytes(db, user_id: str, plaintext: bytes) -> bytes:
    """Returns wire format: nonce(12) || ciphertext || tag(16). AAD = user_id."""
def decrypt_bytes(db, user_id: str, blob: bytes) -> bytes:
    """Inverse. Raises AuthenticationError if AAD mismatch."""
```

From `services/backend/app/services/encryption/key_vault.py:186-280` (existing DEK lifecycle — REUSE):
```python
class KeyVaultService:
    DEK_SIZE_BYTES = 32  # 256-bit
    def get_or_create_dek(self, db, user_id: str) -> bytes:  # plaintext DEK
    def revoke_dek(self, db, user_id: str) -> bool:           # flips revoked_at
    def crypto_shred_user(self, db, user_id: str) -> bool:    # NULLs wrapped_dek (D-03 all-or-nothing)
```
Logical key-id pattern: `_select_backend()` reads `MINT_KMS_KEY_ID` env. D-02 sets this to `mint-master-v1` on Railway.

From `services/backend/app/models/dek_vault.py:18-49` (current schema — extend with `dek_scope`):
```python
class DEKVault(Base):
    __tablename__ = "dek_vault"
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    wrapped_dek = Column(LargeBinary, nullable=True)  # NULL = crypto-shred state
    kms_key_ref = Column(String(256), nullable=True)
    algo = Column(String(32), nullable=False, default="AES-256-GCM")
    created_at = Column(DateTime, nullable=False, default=...)
    rotated_at = Column(DateTime, nullable=True)
    revoked_at = Column(DateTime, nullable=True)
    # NEW Phase 02 D-03: dek_scope = Column(String(32), nullable=False, server_default=sa.text("'user'"))
```

From `services/backend/app/models/projection_audit_record.py:34-65` (current — extend per D-12):
```python
class ProjectionAuditRecord(Base):
    __tablename__ = "projection_audit_records"
    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id_hash = Column(String(64), nullable=False)
    computed_at = Column(DateTime, default=..., nullable=False)
    projection_type = Column(String(32), nullable=False)
    projection_id = Column(String, nullable=False)
    constants_version_hash = Column(String(64), nullable=False)
    scenario_inputs_hash = Column(String(64), nullable=False)
    output_hash = Column(String(64), nullable=False)
    lsfin_disclaimer_shown = Column(Boolean, default=False, nullable=False)
    # NEW Phase 02 D-12: source / app_version / observed_at / anonymous_session_id
```

From `services/backend/alembic/versions/p111_projection_audit.py` (REVOKE template — copy for p98):
```python
if bind.dialect.name == "postgresql":
    op.execute("REVOKE UPDATE, DELETE ON <table> FROM PUBLIC")
    op.execute("""DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_role')
                  THEN REVOKE UPDATE, DELETE ON <table> FROM app_role; END IF; END $$;""")
```

From `services/backend/alembic/versions/p112_audit_event_user_hash.py` (HMAC backfill template — but Python-side via app code, NOT pgcrypto DO-block — D-24 mandates HMAC-pepper not bare SHA-256):
```python
# Backfill in Python at migration time using cryptography.hazmat HMAC.
# DO NOT reuse the p112 pgcrypto DO-block (it's bare SHA-256). p114 uses
# a Python data_upgrade phase that imports hmac_user_id and updates rows.
```

D-26 wire format (Pydantic v2):
```python
class EncryptedValue(BaseModel):
    ct: str          # base64 ciphertext || tag (AESGCM returns concatenated)
    iv: str          # base64 96-bit nonce
    tag: str = ""    # reserved (tag is appended to ct by AESGCM)
    alg: Literal["AES-256-GCM"] = "AES-256-GCM"
    dek_id: str      # logical key ref "mint-master-v1"
    enc_v: int = 1
    model_config = {"extra": "forbid"}
```

D-29 confidence JSONB shape:
```python
{"c": float, "a": float, "f": float, "u": float, "score": float, "enrichmentPrompts": list[str]}
```

Alembic head before this plan: `p112_audit_event_user_hash` (verified via gsd-tools). New chain:
`p112 → p98_fact_event_projection_dek → p113_extend_projection_audit_mobile → p114_hmac_pepper_audit_events → p115_hmac_pepper_pii_columns → p116_snapshot_constants_invalidation`

NOTE: p98 number is historical (carries Phase 01 panel ADR shape), not sequential — the alembic `down_revision` chain is what enforces order. Other p-numbers (p113/p114/p115/p116) follow Phase 02 sequence.

Flutter Mobile L1 audit POST request shape (D-12 contract):
```json
{
  "anonymous_session_id": "<uuid7>",
  "app_version": "<package_info_plus.version>",
  "observed_at": "<ISO 8601>",
  "constants_version_hash": "<from regulatory_constants.g.dart>",
  "source": "mobile_session_start" | "mobile_session_warm_resume"
}
```

Endpoint `/v1/audit/mobile-session-link` accepts batch array of the above shape; UNIQUE constraint on `(anonymous_session_id, observed_at)` makes replay safe (returns 200 + count of new rows, not 409).

D-30 anonymous_session_id: UUID v7 generated ONCE per app install via Flutter `generateUuidV7()` (see RESEARCH Example 4); persisted in `sqflite_sqlcipher` buffer (NOT shared_preferences which is unencrypted on Android).

D-13 clean separation: Mobile L1 audit writes ONLY to `projection_audit_record`. NO `fact_event` INSERT in the endpoint code path. Tests assert zero rows added to fact_event during a session-start POST.
</interfaces>
</context>

<tasks>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 1: D-02 + D-07 Railway env-var rotation rehearsal (Julien confirms procedure)</name>
  <what-built>
    Claude has prepared the Railway env-var procedure documentation (drafted in `docs/operations/audit-pepper-rotation.md` shipped by Plan 02-04, but the live `MINT_AUDIT_HASH_PEPPER` setting MUST exist on Railway before Plan 02-02 Task 2 runs the migrations). **iter-3 HIGH-A3 (Claude-Opus post-iter-2 review)**: pepper is generated AND set via a single `railway variables set` CLI invocation — NEVER written to disk (`/tmp` on macOS is `/private/tmp`, disk-backed and recoverable post-`rm`), NEVER printed to terminal stdout (terminal scrollback captures it), NEVER passed through Claude's tool output (would persist in `~/.claude/projects/.../*.jsonl` session logs). Claude CANNOT set Railway env vars autonomously without Railway CLI auth that may have rotated; opt-out to Julien-confirm for this one-time operational gate.
  </what-built>
  <how-to-verify>
    **iter-3 HIGH-A3 (Claude-Opus post-iter-2 review) — secret handoff hygiene**: the original 7-step procedure routed the pepper through `/tmp/mint_audit_pepper_for_julien.txt` AND Railway dashboard UI. Both leak surfaces are closed below by piping `secrets.token_urlsafe(48)` directly into `railway variables set` so the pepper NEVER touches disk, NEVER prints to stdout (terminal scrollback), and NEVER appears in Claude tool output (`~/.claude/projects/.../*.jsonl` session logs). All steps are executed by Julien in his local shell — Claude observes exit codes only.

    1. **Generate AND set on Railway production atomically** (Julien runs in his local shell):
       ```bash
       railway variables set MINT_AUDIT_HASH_PEPPER --environment production \
         --value "$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
       ```
       The pepper is generated by `python3 -c` substitution inside `$(...)` and piped DIRECTLY as the `--value` argument. Stdout shows only `MINT_AUDIT_HASH_PEPPER set on production` (or equivalent Railway CLI confirmation) — the pepper value is NEVER printed. No temp file is created. Do NOT prepend `echo` or `cat` to inspect the value; the Railway CLI is the only sink.
    2. **Generate AND set on Railway staging atomically** (Julien runs):
       ```bash
       railway variables set MINT_AUDIT_HASH_PEPPER --environment staging \
         --value "$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
       ```
       Staging gets a DIFFERENT pepper (the `$(python3 -c ...)` call runs a fresh `secrets.token_urlsafe(48)` per invocation — staging/prod isolation per security best practice: a leak of one does not compromise the other).
    3. **Verify length (NOT value) on both environments** (Julien runs):
       ```bash
       railway variables get MINT_AUDIT_HASH_PEPPER --environment production | wc -c
       railway variables get MINT_AUDIT_HASH_PEPPER --environment staging   | wc -c
       ```
       Both must return ≥ 32 (`token_urlsafe(48)` produces ~64 chars, plus newline). Pipe to `wc -c` so the value itself never appears in stdout/scrollback. **Do NOT paste the raw `railway variables get` output back to Claude** (would persist in session log).
    4. **Confirm `MINT_KMS_KEY_ID` exists** (Julien runs):
       ```bash
       railway variables get MINT_KMS_KEY_ID --environment production
       ```
       Expected: returns `mint-master-v1` (per D-02). This value is NOT a secret (logical key-id, audit anchor); printing it to stdout is acceptable. If missing, Julien adds it via:
       ```bash
       railway variables set MINT_KMS_KEY_ID --environment production --value mint-master-v1
       railway variables set MINT_KMS_KEY_ID --environment staging    --value mint-master-v1
       ```
    5. **D-02 rotation rehearsal** (Julien does this — non-production): in Railway staging, ROTATE `MINT_AUDIT_HASH_PEPPER` and immediately revert :
       ```bash
       # capture the staging length pre-rotation (length only, not value)
       railway variables get MINT_AUDIT_HASH_PEPPER --environment staging | wc -c > /tmp/pepper_len_pre.txt
       # rotate (new pepper generated atomically by token_urlsafe)
       railway variables set MINT_AUDIT_HASH_PEPPER --environment staging \
         --value "$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
       # immediately revert to a fresh pepper (rehearsal — the original value is unrecoverable by design)
       railway variables set MINT_AUDIT_HASH_PEPPER --environment staging \
         --value "$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
       railway variables get MINT_AUDIT_HASH_PEPPER --environment staging | wc -c > /tmp/pepper_len_post.txt
       diff /tmp/pepper_len_pre.txt /tmp/pepper_len_post.txt && echo "rehearsal OK — length invariant"
       rm /tmp/pepper_len_pre.txt /tmp/pepper_len_post.txt
       ```
       The rehearsal proves the rotation procedure works for the future Phase 04 rotation that Plan 02-04's `audit-pepper-rotation.md` documents. It does NOT need a backfill (the audit table has zero rows in staging pre-launch). Capture the timestamps of both `railway variables set` operations (visible in the Railway dashboard activity log) for the SUMMARY.
  </how-to-verify>
  <resume-signal>
    Type "approved — pepper set on prod + staging via railway variables set CLI (no /tmp file, no stdout leak per iter-3 HIGH-A3), KMS_KEY_ID=mint-master-v1 confirmed, rehearsal procedure works" OR describe issues for Claude to address (e.g., `railway` CLI not authenticated, environment name mismatch, exit code ≠ 0).
  </resume-signal>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Ship hmac_pepper canonical entry + EncryptedValue model + encrypt_value/decrypt_value helpers + DEK envelope wiring + 4 Phase 01 carry-over fixes (D-14 D-15 D-16 D-17)</name>
  <files>
    services/backend/app/services/audit/__init__.py,
    services/backend/app/services/audit/hmac_pepper.py,
    services/backend/app/services/audit/audit_service.py,
    services/backend/app/models/encryption/__init__.py,
    services/backend/app/models/encryption/encrypted_value.py,
    services/backend/app/services/encryption/encrypted_value_helper.py,
    services/backend/app/services/encryption/key_vault.py,
    services/backend/app/services/snapshots/snapshot_service.py,
    services/backend/app/services/cache/snapshot_cache.py,
    services/backend/app/api/v1/endpoints/privacy.py,
    services/backend/alembic/versions/p114_hmac_pepper_audit_events.py,
    services/backend/alembic/versions/p115_hmac_pepper_pii_columns.py,
    services/backend/alembic/versions/p116_snapshot_constants_invalidation.py,
    services/backend/app/models/audit_event.py,
    services/backend/app/observability/counters.py,
    services/backend/app/core/sentry.py,
    services/backend/tests/test_hmac_pepper.py,
    services/backend/tests/test_encrypted_value_model.py,
    services/backend/tests/test_encrypted_value_helper.py,
    services/backend/tests/test_dek_envelope_concurrency.py,
    services/backend/tests/test_key_vault_logical_id.py,
    services/backend/tests/integration/test_migration_p114.py,
    services/backend/tests/integration/test_migration_p115.py,
    services/backend/tests/integration/test_privacy_delete_real_count.py,
    services/backend/tests/integration/test_snapshot_cache_invalidation.py,
    services/backend/tests/integration/test_dek_shred_opacity.py,
    services/backend/tests/integration/test_constants_propagation_pit.py
  </files>
  <read_first>
    services/backend/app/services/encryption/envelope.py (lines 36-90 — encrypt_bytes/decrypt_bytes signatures + AAD),
    services/backend/app/services/encryption/key_vault.py (lines 130-283 — _select_backend, get_or_create_dek, revoke_dek, crypto_shred_user),
    services/backend/app/services/encryption/column_type.py (EncryptedBytes TypeDecorator pattern — reference only, NOT used for value_enc JSONB),
    services/backend/app/models/dek_vault.py (current 49-line schema — extend with dek_scope in p98 NOT here; this task only uses the existing surface),
    services/backend/app/models/audit_event.py (Hotfix C user_id_hash column current state),
    services/backend/app/services/snapshots/snapshot_service.py (constants_version_hash write site for D-17),
    services/backend/app/services/cache/snapshot_cache.py (current cache key shape for D-17 invalidation),
    services/backend/app/api/v1/endpoints/privacy.py (current /privacy/delete hardcoded count for D-16),
    services/backend/alembic/versions/p112_audit_event_user_hash.py (template for p114 — but Python data_upgrade instead of pgcrypto DO-block),
    services/backend/app/observability/counters.py (existing prometheus-client wiring — add 6 new declarations),
    services/backend/app/core/sentry.py (existing before_send hook for D-26 strip),
    services/backend/app/models/lucidity/_payload.py (Pydantic v2 Literal + extra:forbid pattern reference),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-RESEARCH.md (Pattern 1 encrypt_value at lines 270-316; Pattern 4 hmac_pepper at lines 560-614; Example 1 EncryptedValue at lines 726-752)
  </read_first>
  <behavior>
    **Test 1 (hmac_pepper)**: `hmac_user_id("user-123")` returns 64-char lowercase hex; deterministic (same input → same output); `hmac_user_id(None)` returns None; `hmac_user_id("user-123")` ≠ `hashlib.sha256(b"user-123").hexdigest()` (pepper changes the output); calling without `MINT_AUDIT_HASH_PEPPER` env (and TESTING≠1) raises `PepperNotConfigured`.
    **Test 2 (EncryptedValue model)**: round-trip via `model_dump_json` + `model_validate_json`; rejects extra fields (`{"ct":"x","iv":"y","dek_id":"z","extra":"oops"}` → ValidationError); rejects wrong `alg` (`"alg":"AES-128-GCM"` → ValidationError on Literal constraint).
    **Test 3 (encrypt_value/decrypt_value)**: round-trip for dict, list, string, number; AAD binding (`encrypt_value(db, "user-A", v)` decrypted with `decrypt_value(db, "user-B", env)` raises authentication error); JSON serialization deterministic (`sort_keys=True`); envelope output validates against `EncryptedValue` model.
    **Test 4 (DEK concurrency)**: two concurrent `get_or_create_dek` calls for the same new user → exactly one DEKVault row inserted (PK constraint catches race; second call retries once + reads from DB cache).
    **Test 5 (DEK shred opacity)**: after `crypto_shred_user(db, user_id)`, decrypting any value_enc for that user raises `DEKRevokedError` (NOT returns plaintext).
    **Test 6 (key_vault logical id)**: `KeyVaultService` resolves `MINT_KMS_KEY_ID=mint-master-v1` via `_select_backend()`; new DEKVault rows write `kms_key_ref='mint-master-v1'`.
    **Test 7 (p114 migration)**: pg_fixture-based; insert 3 rows in audit_events with plaintext user_id; run upgrade; assert user_id_hash now equals `hmac_user_id(user_id)` for each row; assert plaintext `user_id` is NULL on Postgres post-upgrade.
    **Test 8 (p115 migration)**: same pattern for actor_email_hash / ip_address_hash / user_agent_hash; plaintext columns retained (deprecation cycle).
    **Test 9 (/privacy/delete real count)**: seed DB with N chat_messages + M coach_insights + K snapshots + L projection_audit_records for a user; call `/privacy/delete`; assert receipt contains exactly `{"chat_messages": N, "coach_insights": M, "snapshots": K, "projection_audit_records": L}` (NOT `nb_sessions=0`).
    **Test 10 (snapshot cache invalidation)**: cache snapshot with constants_version_hash=H1; bump regulatory constants → H2; next snapshot read returns fresh (cache key includes constants_version_hash).
    **Test 11 (constants propagation PIT)**: write fact_event row at T1 with constants_version_hash=H1; bump constants to H2 at T2; assert NO retroactive flag on the T1 row (D-04 doctrine).
  </behavior>
  <action>
1. **`services/backend/app/services/audit/__init__.py` + `hmac_pepper.py` (NEW)**: implement RESEARCH Pattern 4 (lines 560-614) verbatim. `hmac_user_id(user_id) -> str | None`, `hmac_pii(value) -> str | None`, `PepperNotConfigured` exception class, `_get_pepper()` lru_cached with `MINT_AUDIT_HASH_PEPPER` env read + ≥32-char check + TESTING=1 fallback bypass. Module docstring cites D-07 / D-14 / D-15 / D-24.
2. **`services/backend/app/services/audit/audit_service.py`**: extend existing audit writer (if present) OR create stub that the existing `app/services/audit_service.py` delegates to. Every `user_id_hash` write call MUST go through `hmac_user_id()` (no bare `hashlib.sha256`). This unblocks the D-24 site lint shipped in Plan 02-01.
3. **`services/backend/app/models/encryption/__init__.py` + `encrypted_value.py` (NEW)**: implement RESEARCH Example 1 (lines 726-752) verbatim. `class EncryptedValue(BaseModel)` with `ct: str`, `iv: str`, `tag: str=""`, `alg: Literal["AES-256-GCM"]="AES-256-GCM"`, `dek_id: str`, `enc_v: int = 1`, `model_config = {"extra": "forbid"}`.
4. **`services/backend/app/services/encryption/encrypted_value_helper.py` (NEW)**: implement RESEARCH Pattern 1 (lines 270-316) verbatim. `encrypt_value(db, user_id, value) -> dict` + `decrypt_value(db, user_id, envelope) -> Any`. JSON serialization: `json.dumps(value, separators=(",",":"), sort_keys=True).encode("utf-8")`. Logical DEK id = `"mint-master-v1"` (D-02). Wraps existing `encrypt_bytes`/`decrypt_bytes` — DO NOT call `AESGCM` directly (Karpathy #2 — reuse).
5. **`services/backend/app/services/encryption/key_vault.py`** (extend): no breaking change to public surface. Add `_LOGICAL_KEY_ID = "mint-master-v1"` module-level constant (D-02). Existing `_select_backend()` reads `MINT_KMS_KEY_ID` env; if unset on dev, default to logical id `mint-master-v1` mapped to Fernet backend (`MINT_MASTER_KEY` env). Update `get_or_create_dek()` to write `kms_key_ref=os.environ.get("MINT_KMS_KEY_ID", _LOGICAL_KEY_ID)` so DEKVault rows have the audit anchor. Add concurrency-retry-once block per Pitfall 2: wrap the INSERT in `try/except IntegrityError → time.sleep(0.05) + retry` (re-read from cache).
6. **Alembic p114** (`p114_hmac_pepper_audit_events.py`): down_revision = `p112_audit_event_user_hash` (NOT p98 — p114 is independent of p98; both branch from p112). NO — actually re-check: per researcher chain `p98 → p113 → p114 → p115 → p116`, so p114 down_revision = `p113_extend_projection_audit_mobile` per RESEARCH. **DECISION**: keep RESEARCH chain. p98 down=`p112`, p113 down=`p98`, p114 down=`p113`, p115 down=`p114`, p116 down=`p115`. In `upgrade()`:
   - `with op.batch_alter_table("audit_events"):` add nothing (column exists from Hotfix C).
   - Python data_upgrade: `bind = op.get_bind(); session = sa.orm.Session(bind=bind); for row in session.execute(sa.text("SELECT id, user_id FROM audit_events WHERE user_id IS NOT NULL")): session.execute(sa.text("UPDATE audit_events SET user_id_hash = :h WHERE id = :i"), {"h": hmac_user_id(row.user_id), "i": row.id}); session.commit()`.
   - On Postgres: `op.execute("UPDATE audit_events SET user_id = NULL WHERE user_id IS NOT NULL")` (D-14 plaintext drop — NULL not DROP COLUMN, retains schema for one deprecation cycle).
   - `downgrade()`: no-op for hash (irreversible by design). The plaintext user_id column re-population is impossible (hash is one-way).
   - Use `sa.false()` for any new Boolean column (Plan 02-01 lint enforces this).
7. **Alembic p115** (`p115_hmac_pepper_pii_columns.py`): down_revision = `p114_hmac_pepper_audit_events`. ADD columns `actor_email_hash VARCHAR(64) NULL` + `ip_address_hash VARCHAR(64) NULL` + `user_agent_hash VARCHAR(64) NULL` to `audit_events` via `batch_alter_table`. Python data_upgrade: for each row with `actor_email IS NOT NULL`, `UPDATE actor_email_hash = hmac_pii(actor_email)`. Same for ip_address, user_agent. Plaintext columns RETAINED (D-15 one-release deprecation cycle).
8. **Alembic p116** (`p116_snapshot_constants_invalidation.py`): NO schema change. Pure data_upgrade documenting the cache-key extension shipped in code (`snapshot_service.py` updated below). The migration is a tombstone so the alembic history records the deprecation. `upgrade()`: `pass # see snapshot_service.py D-17 cache key extension`. `downgrade()`: same.
9. **`services/backend/app/services/snapshots/snapshot_service.py`** (D-17): locate the snapshot cache key construction; extend it to include `constants_version_hash`. Add a `_invalidate_on_constants_change` hook that listens for active-version change and clears the cache. Tests in `tests/integration/test_snapshot_cache_invalidation.py` assert the behaviour.
10. **`services/backend/app/services/cache/snapshot_cache.py`** (if exists; else inline in snapshot_service): update cache key generation to: `cache_key = f"{user_id}:{inputs_hash}:{constants_version_hash}"`. Old keys naturally expire.
11. **`services/backend/app/api/v1/endpoints/privacy.py`** (D-16): locate `/privacy/delete` handler; replace hardcoded `nb_sessions=0` with `db.execute(sa.select(func.count()).select_from(ChatMessage).where(...))` for each table: chat_messages, coach_insights, snapshots, projection_audit_records, audit_events. Build the receipt dict with real counts.
12. **`services/backend/app/observability/counters.py`** (declare 6 new D-33 counters, NOT yet asserted firing): `mint_fact_current_read_latency_ms` (Histogram, labels: fact_type), `mint_fact_event_insert_total` (Counter, labels: source_type), `mint_dek_envelope_status_total` (Counter, labels: status), `mint_anonymous_session_link_total` (Counter, labels: outcome), `mint_projector_idempotency_skip_total` (Counter, no labels), `mint_constants_version_mismatch_total` (Counter, no labels). Export each as module-level name for import by writers.
13. **`services/backend/app/core/sentry.py`**: in `before_send` hook, strip `value_enc` field from breadcrumb data + event extra dict (recursive). Test: send a breadcrumb with `value_enc={"ct":"...", "iv":"..."}`; verify hook removes it.
14. Run full pytest + lints. The Plan 02-01 D-20 + D-24 lints MUST pass on all new code (they will reject any bare `hashlib.sha256(user_id)` or `sa.text("0")` on Boolean — catches drift at commit-time).
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_hmac_pepper.py tests/test_encrypted_value_model.py tests/test_encrypted_value_helper.py tests/test_dek_envelope_concurrency.py tests/test_key_vault_logical_id.py tests/integration/test_migration_p114.py tests/integration/test_migration_p115.py tests/integration/test_privacy_delete_real_count.py tests/integration/test_snapshot_cache_invalidation.py tests/integration/test_dek_shred_opacity.py tests/integration/test_constants_propagation_pit.py -q -k pg && python3 -m pytest tests/ -q -x && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/hmac_pepper_audit.py services/backend/app/ && python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/ && python3 tools/checks/banned_terms_python.py services/backend/app/services/audit/ services/backend/app/services/encryption/encrypted_value_helper.py && python3 tools/checks/accent_lint_fr.py --scope backend</automated>
  </verify>
  <acceptance_criteria>
    - `cd services/backend && python3 -c "from app.services.audit.hmac_pepper import hmac_user_id; assert hmac_user_id('test-user-123') != None and len(hmac_user_id('test-user-123')) == 64"` exits 0 (with TESTING=1 env).
    - `cd services/backend && python3 -c "from app.models.encryption.encrypted_value import EncryptedValue; v=EncryptedValue(ct='x',iv='y',dek_id='mint-master-v1'); print(v.model_dump_json())"` exits 0 and output contains `"enc_v":1`.
    - `cd services/backend && python3 -c "from app.models.encryption.encrypted_value import EncryptedValue; EncryptedValue(ct='x',iv='y',dek_id='z',unknown='oops')"` exits with ValidationError (extra:forbid).
    - `cd services/backend && python3 -m pytest tests/test_hmac_pepper.py tests/test_encrypted_value_model.py tests/test_encrypted_value_helper.py -q` exits 0.
    - `cd services/backend && python3 -m pytest tests/integration/test_migration_p114.py tests/integration/test_migration_p115.py -q -k pg` exits 0.
    - `cd services/backend && python3 -m pytest tests/integration/test_dek_shred_opacity.py -q -k pg` exits 0 (D-32 G4 gate).
    - `cd services/backend && python3 -m pytest tests/integration/test_privacy_delete_real_count.py tests/integration/test_snapshot_cache_invalidation.py tests/integration/test_constants_propagation_pit.py -q` exits 0.
    - `git grep -n "mint_fact_current_read_latency_ms\|mint_fact_event_insert_total\|mint_dek_envelope_status_total\|mint_anonymous_session_link_total\|mint_projector_idempotency_skip_total\|mint_constants_version_mismatch_total" services/backend/app/observability/counters.py` returns 6 hits (1 per counter).
    - `python3 tools/checks/hmac_pepper_audit.py services/backend/app/` exits 0 (no bare hashlib.sha256(user_id) outside hmac_pepper.py self-exempt).
    - `python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/` exits 0 (Plan 02-01 lint stays clean).
    - Full pytest: `cd services/backend && python3 -m pytest tests/ -q` exits 0 (≥ 7264 + new tests; zero regression).
    - `git diff services/backend/app/api/v1/endpoints/privacy.py | grep -E "nb_sessions.*0"` returns 0 hits (hardcoded count removed).
    - `git grep -n "constants_version_hash" services/backend/app/services/snapshots/snapshot_service.py services/backend/app/services/cache/snapshot_cache.py` returns ≥2 hits (cache key extended).
  </acceptance_criteria>
  <done>
    HMAC-pepper canonical entry + EncryptedValue model + encrypt_value/decrypt_value helpers shipped. 4 Phase 01 carry-over gaps closed (D-14 audit user_id_hash + plaintext drop, D-15 actor_email/ip/user_agent hash, D-16 /privacy/delete real count, D-17 snapshot cache invalidation). 6 D-33 counters declared. Sentry strips value_enc. All without re-implementing crypto — wraps existing primitives per RESEARCH § Don't Hand-Roll.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Ship p98 (fact_event + fact_current + dek_scope) + p113 (extend projection_audit_record) + projector + audit_mobile endpoint + Flutter MobileL1AuditService + first-slice canary parity test</name>
  <files>
    services/backend/alembic/versions/p98_fact_event_projection_dek.py,
    services/backend/alembic/versions/p113_extend_projection_audit_mobile.py,
    services/backend/app/models/fact_event.py,
    services/backend/app/models/fact_current.py,
    services/backend/app/models/dek_vault.py,
    services/backend/app/models/projection_audit_record.py,
    services/backend/app/services/projector/__init__.py,
    services/backend/app/services/projector/fact_projector.py,
    services/backend/app/api/v1/endpoints/audit_mobile.py,
    services/backend/app/api/v1/api.py,
    tools/openapi/mint.openapi.canonical.json,
    services/backend/tests/integration/test_migration_p98.py,
    services/backend/tests/integration/test_migration_p113.py,
    services/backend/tests/integration/test_projector_idempotency.py,
    services/backend/tests/integration/test_projector_atomicity.py,
    services/backend/tests/integration/test_canary_monthly_gross_income.py,
    services/backend/tests/integration/test_audit_mobile_link.py,
    services/backend/tests/integration/test_partition_declared.py,
    apps/mobile/pubspec.yaml,
    apps/mobile/lib/services/audit/anonymous_session_id.dart,
    apps/mobile/lib/services/audit/audit_buffer_db.dart,
    apps/mobile/lib/services/audit/offline_queue.dart,
    apps/mobile/lib/services/audit/mobile_l1_audit_service.dart,
    apps/mobile/lib/services/lifecycle/app_lifecycle_observer.dart,
    apps/mobile/test/services/audit/anonymous_session_buffer_test.dart,
    apps/mobile/test/services/audit/offline_queue_test.dart,
    apps/mobile/test/services/audit/mobile_l1_audit_service_test.dart
  </files>
  <read_first>
    services/backend/alembic/versions/p111_projection_audit.py (REVOKE template + dialect branching),
    services/backend/alembic/versions/p95_dag_invalidation.py (UUID7 + idempotent column-add pattern + inspector.get_columns),
    services/backend/app/models/projection_audit_record.py (extension target),
    services/backend/app/models/dek_vault.py (extension target for dek_scope),
    services/backend/app/models/snapshot.py (canary read-side comparator — gross_income field),
    services/backend/app/models/lucidity/_payload.py (Pydantic v2 BaseModel + Literal pattern for FactEvent + FactCurrent ORM payloads),
    services/backend/app/api/v1/api.py (router registration pattern),
    services/backend/app/api/v1/endpoints/coach_chat.py (existing endpoint shape, dependency injection),
    services/backend/app/services/audit/hmac_pepper.py (from Task 2),
    services/backend/app/services/projector (CREATE — see RESEARCH Pattern 2),
    apps/mobile/pubspec.yaml (verify sqflite_sqlcipher, package_info_plus, sentry_flutter, crypto present; add connectivity_plus if missing),
    apps/mobile/lib/services/api_service.dart (line 187 _appVersion via package_info_plus shipped 2026-05-18),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-RESEARCH.md (Pattern 2 projector at lines 320-407; Pattern 3 alembic p98 at lines 409-558; Example 2 FactEvent ORM at lines 754-810; Example 4 UUID v7 Flutter at lines 858-912)
  </read_first>
  <behavior>
    **Test 12 (p98 migration)**: pg_fixture. After upgrade: `\d fact_event` returns columns event_id|subject_type|subject_id|fact_type|value_enc|source_type|source_id|source_pdf_sha256|observed_at|recorded_at|confidence|supersedes_event_id|correction_reason|visibility|archetype_tags. `\d fact_current` returns subject_type|subject_id|fact_type|value_enc|latest_event_id|confidence|visibility. `\d dek_vault` includes `dek_scope` column. Postgres: `SELECT has_table_privilege('PUBLIC', 'fact_event', 'UPDATE')` returns FALSE; same for DELETE.
    **Test 13 (partition declared)**: pg-only. `SELECT pg_get_partkeydef('fact_event'::regclass)` returns `HASH (subject_id)`. `SELECT relname FROM pg_class WHERE relname LIKE 'fact_event_p%'` returns ≥1 partition (`fact_event_p_0`).
    **Test 14 (p113 migration)**: pg_fixture. After upgrade: `\d projection_audit_records` includes new columns source (default 'projection'), app_version (nullable), observed_at (nullable), anonymous_session_id (nullable). UNIQUE constraint `(anonymous_session_id, observed_at) WHERE anonymous_session_id IS NOT NULL` exists.
    **Test 15 (projector atomicity)**: pg_fixture. `with session.begin(): project_fact_event(session, event); raise RuntimeError("force rollback")` → both fact_event AND fact_current have zero rows after rollback.
    **Test 16 (projector idempotency)**: insert event A with event_id_A; project; insert event B with event_id_B > event_id_A; project; fact_current.latest_event_id = B. Re-inject event A; project; `mint_projector_idempotency_skip_total` increments; fact_current.latest_event_id still B (not overwritten).
    **Test 17 (canary parity)**: write fact_event(subject_type='user', subject_id=user-1, fact_type='monthly_gross_income', value_enc=encrypt_value(user-1, 8500.0), source_type='user_input'); run projector; assert `decrypt_value(user-1, fact_current.value_enc) == 8500.0`; assert SnapshotModel.gross_income for user-1 == 8500.0 (pre-existing row); both identical.
    **Test 18 (audit_mobile endpoint)**: POST /v1/audit/mobile-session-start with anonymous payload (no auth) → 200 + projection_audit_record row inserted with source='mobile_session_start' and anonymous_session_id populated. POST /v1/audit/mobile-session-link with auth header + batch of 5 rows → 200 + count=5 + all rows have user_id_hash AND anonymous_session_id populated. Repeat same payload → 200 + count=0 (UNIQUE constraint blocks dups). Assert zero fact_event rows added throughout (D-13 clean separation).
    **Test 19 (Flutter mobile L1 audit)**: anonymous_session_id is a valid RFC 9562 v7 UUID (version=7, variant=10). Buffer persists across app restart (sqflite_sqlcipher). Offline queue replays on connectivity restoration with exponential backoff 1s/2s/4s/8s/16s capped at 5min.
  </behavior>
  <action>
1. **Alembic p98** (`p98_fact_event_projection_dek.py`): copy RESEARCH Pattern 3 (lines 409-558) verbatim. `down_revision = "p112_audit_event_user_hash"`. Postgres branch: raw `op.execute()` with `CREATE TABLE fact_event ... PARTITION BY HASH (subject_id)` + `CREATE TABLE fact_event_p_0 PARTITION OF fact_event FOR VALUES WITH (MODULUS 1, REMAINDER 0)` + REVOKE block (template from p111). SQLite branch: `op.create_table` with `sa.JSON` instead of JSONB, no partitioning. Both dialects: `op.create_index("ix_fact_event_subject", ["subject_type","subject_id"])` + `op.create_table("fact_current", ..., sa.PrimaryKeyConstraint("subject_type","subject_id","fact_type"))`. Postgres-only: `CREATE INDEX ix_fact_current_subject_covering ON fact_current (subject_id) INCLUDE (value_enc, latest_event_id, confidence, visibility)`. `dek_vault.dek_scope`: `op.batch_alter_table("dek_vault") → add_column("dek_scope", sa.String(32), nullable=False, server_default=sa.text("'user'"))`. Use `sa.false()`/`sa.true()` for any BOOLEAN. `downgrade()`: drop indexes, drop tables, drop dek_scope column.
2. **Alembic p113** (`p113_extend_projection_audit_mobile.py`): `down_revision = "p98_fact_event_projection"`. `op.batch_alter_table("projection_audit_records") → add_column("source", sa.String(32), nullable=False, server_default=sa.text("'projection'"))` + `add_column("app_version", sa.String(32), nullable=True)` + `add_column("observed_at", sa.DateTime, nullable=True)` + `add_column("anonymous_session_id", sa.String(36), nullable=True)`. Then create UNIQUE: `op.create_index("uq_proj_audit_anon_observed", "projection_audit_records", ["anonymous_session_id", "observed_at"], unique=True, postgresql_where=sa.text("anonymous_session_id IS NOT NULL"))`. SQLite path: same UNIQUE without WHERE clause (SQLite supports unique partial via `sqlite_where`). `downgrade()`: drop the 4 columns + the unique index.
3. **`services/backend/app/models/fact_event.py` + `fact_current.py` (NEW)**: SQLAlchemy 2.0 declarative ORM per RESEARCH Example 2 (lines 754-810). FactEvent: `__table_args__ = (PrimaryKeyConstraint("event_id","subject_id"), UniqueConstraint(...), Index(...), {"postgresql_partition_by": "HASH (subject_id)"})`. event_id default = `lambda: str(uuid_utils.uuid7())`. value_enc = `Column(JSONB if pg else JSON, nullable=False)`. confidence = JSONB nullable. FactCurrent: simpler, PK on (subject_type, subject_id, fact_type).
4. **Update `services/backend/app/models/dek_vault.py`**: add `dek_scope = Column(String(32), nullable=False, default="user", server_default=sa.text("'user'"))`.
5. **Update `services/backend/app/models/projection_audit_record.py`**: add the 4 D-12 columns to the Python ORM (mirror p113). Keep existing columns intact.
6. **`services/backend/app/services/projector/__init__.py` + `fact_projector.py` (NEW)**: copy RESEARCH Pattern 2 (lines 320-407) verbatim. `def project_fact_event(session: Session, event: FactEvent) -> None`. Sequence-number monotonicity: `if existing.latest_event_id >= event.event_id: mint_projector_idempotency_skip_total.inc(); return`. Caller wraps in `with session.begin():` (D-19 transactional). Increment `mint_fact_event_insert_total.labels(source_type=event.source_type)` after `session.flush()` succeeds.
7. **`services/backend/app/api/v1/endpoints/audit_mobile.py` (NEW)**: FastAPI router with two POST endpoints:
   - `POST /v1/audit/mobile-session-start`: accepts `MobileSessionStartRequest` Pydantic v2 model (anonymous_session_id, app_version, observed_at, constants_version_hash, source). `Depends(get_current_user_optional)`. Inserts single `ProjectionAuditRecord` with `user_id_hash = hmac_user_id(user.id) if user else None`, source from payload, anonymous_session_id from payload. NO fact_event INSERT (D-13).
   - `POST /v1/audit/mobile-session-link`: accepts `MobileSessionLinkBatch` (list of MobileSessionStartRequest items + user from auth). `Depends(get_current_user)` (auth REQUIRED). Idempotent batch insert via `INSERT ... ON CONFLICT DO NOTHING` on UNIQUE(anonymous_session_id, observed_at). Returns `{"linked": <count_new>, "skipped": <count_dup>}`.
   - Wire counter: `mint_anonymous_session_link_total.labels(outcome="linked"|"conflict"|"error").inc()`.
8. **Update `services/backend/app/api/v1/api.py`**: register the new router. `from app.api.v1.endpoints import audit_mobile; api_router.include_router(audit_mobile.router, prefix="/audit", tags=["audit"])`.
9. **Regenerate OpenAPI canonical**: run `python3 services/backend/scripts/generate_canonical.py` (or equivalent — check existing path in repo) → updates `tools/openapi/mint.openapi.canonical.json` with the two new endpoints. CI parity check passes.
10. **`apps/mobile/pubspec.yaml`**: verify `sqflite_sqlcipher: ^3.1.0+1`, `package_info_plus: ^8.0.0`, `sentry_flutter: ^9.14.0`, `crypto: ^3.0.3` present. Add `connectivity_plus: ^6.0.0` if missing (per RESEARCH A4 — needed for D-30 backoff cap based on stable connection).
11. **`apps/mobile/lib/services/audit/anonymous_session_id.dart` (NEW)**: `generateUuidV7()` per RESEARCH Example 4 (lines 858-912). `getOrCreateAnonymousSessionId()` reads from sqflite_sqlcipher buffer; if absent, generates new UUID v7 and persists.
12. **`apps/mobile/lib/services/audit/audit_buffer_db.dart` (NEW)**: `openAuditBuffer(password)` per RESEARCH Example 4. Schema:
    ```sql
    CREATE TABLE mobile_l1_audit_buffer (
      id TEXT PRIMARY KEY,
      anonymous_session_id TEXT NOT NULL,
      observed_at TEXT NOT NULL,
      app_version TEXT NOT NULL,
      constants_version_hash TEXT NOT NULL,
      source TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      retry_count INTEGER NOT NULL DEFAULT 0,
      next_retry_at TEXT NOT NULL,
      UNIQUE(anonymous_session_id, observed_at)
    )
    ```
    30-day TTL: on app start, `DELETE FROM mobile_l1_audit_buffer WHERE next_retry_at < datetime('now', '-30 days')`.
13. **`apps/mobile/lib/services/audit/offline_queue.dart` (NEW)**: replay logic. Exponential backoff 1s/2s/4s/8s/16s capped at 5min (per Pitfall 6). Use `connectivity_plus` to gate replay on stable connection. On each retry: POST to `/v1/audit/mobile-session-start` (single row) OR `/v1/audit/mobile-session-link` (batch on login). On success: DELETE from buffer. On failure: `next_retry_at = now + min(backoff, 5min)`, `retry_count += 1`, fire Sentry breadcrumb with `outcome='error'`.
14. **`apps/mobile/lib/services/audit/mobile_l1_audit_service.dart` (NEW)**: public service class. `MobileL1AuditService.recordSessionStart()` (cold-start hook) + `.recordSessionResume()` (warm-resume hook, only fires if >30min since last foreground). Both build the payload from `package_info_plus` version + `regulatoryConstantsVersionHash` from generated Dart const + `DateTime.now().toUtc().toIso8601String()` + `getOrCreateAnonymousSessionId()`. Insert into buffer + trigger replay attempt.
15. **`apps/mobile/lib/services/lifecycle/app_lifecycle_observer.dart` (NEW)**: extends `WidgetsBindingObserver`. In `didChangeAppLifecycleState(AppLifecycleState state)`: on `resumed`, compute time since last resumed (persisted in shared_preferences or buffer DB); if >30min, call `audit.recordSessionResume()`; if app cold-started, call `audit.recordSessionStart()`. Register in `main.dart` via existing observer registration pattern (do NOT replace; ADD).
16. **First-slice canary** (`services/backend/tests/integration/test_canary_monthly_gross_income.py`): pg_fixture. Setup: create user U; create SnapshotModel(user_id=U, gross_income=8500.0). Action: encrypt_value(db, U, 8500.0) → envelope; create FactEvent(subject_type='user', subject_id=U, fact_type='monthly_gross_income', value_enc=envelope, source_type='user_input', recorded_at=now); `with session.begin(): project_fact_event(session, event)`. Assert: (a) fact_event has 1 row; (b) fact_current has 1 row; (c) `decrypt_value(db, U, fact_current.value_enc) == 8500.0`; (d) SnapshotModel.gross_income for U == 8500.0 (unchanged); (e) the two values are equal — canary parity holds.
17. **Run full backend pytest + Flutter test + lints**.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/integration/test_migration_p98.py tests/integration/test_migration_p113.py tests/integration/test_partition_declared.py tests/integration/test_projector_idempotency.py tests/integration/test_projector_atomicity.py tests/integration/test_canary_monthly_gross_income.py tests/integration/test_audit_mobile_link.py -q -k pg && python3 -m pytest tests/ -q -x && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 services/backend/scripts/generate_canonical.py --check 2>&1 && cd apps/mobile && flutter pub get && flutter analyze && flutter test test/services/audit/ -r expanded && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/ && python3 tools/checks/hmac_pepper_audit.py services/backend/app/ && python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/audit_mobile.py services/backend/app/services/projector/ && python3 tools/checks/accent_lint_fr.py --scope backend</automated>
  </verify>
  <acceptance_criteria>
    - `cd services/backend && python3 -m pytest tests/integration/test_migration_p98.py -q -k pg` exits 0; pg_fixture confirms `\d fact_event` has 15 columns, REVOKE granted, PARTITION BY HASH declared.
    - `cd services/backend && python3 -m pytest tests/integration/test_partition_declared.py -q -k pg` exits 0; `pg_get_partkeydef('fact_event'::regclass)` returns `HASH (subject_id)`.
    - `cd services/backend && python3 -m pytest tests/integration/test_migration_p113.py -q -k pg` exits 0; 4 new columns + UNIQUE(anonymous_session_id, observed_at) confirmed.
    - `cd services/backend && python3 -m pytest tests/integration/test_projector_atomicity.py tests/integration/test_projector_idempotency.py -q -k pg` exits 0.
    - `cd services/backend && python3 -m pytest tests/integration/test_canary_monthly_gross_income.py -q -k pg` exits 0 — D-25 canary parity PROVEN.
    - `cd services/backend && python3 -m pytest tests/integration/test_audit_mobile_link.py -q -k pg` exits 0; assert `db.query(FactEvent).count() == 0` after a session-start POST (D-13 clean separation enforced).
    - `python3 services/backend/scripts/generate_canonical.py --check` exits 0 (OpenAPI parity).
    - `cd apps/mobile && flutter analyze` exits 0.
    - `cd apps/mobile && flutter test test/services/audit/` exits 0 (all 3 test files green).
    - `cd apps/mobile && flutter pub get && grep -E "sqflite_sqlcipher:|package_info_plus:|sentry_flutter:|connectivity_plus:" pubspec.yaml` returns 4 hits.
    - `git grep -n "from app.services.projector.fact_projector import project_fact_event" services/backend/` returns ≥1 hit (importable).
    - `git grep -n "PARTITION BY HASH" services/backend/alembic/versions/p98_fact_event_projection_dek.py` returns ≥1 hit.
    - `python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/` exits 0 (no Hotfix B regressions).
    - `python3 tools/checks/hmac_pepper_audit.py services/backend/app/` exits 0.
    - Full backend pytest: `cd services/backend && python3 -m pytest tests/ -q` exits 0 (delta ≈ +50 new tests vs Plan 02-01 baseline; zero regression).
    - **Bundle size measurement** (D-30 forward note): record output of `cd apps/mobile && du -sh build/ios/iphoneos/Runner.app/Frameworks 2>/dev/null` before & after this plan in SUMMARY. The SQLite buffer adds <100KB compressed per CONTEXT Claude's Discretion — measure and document.
    - **Battery drain note**: G2 sub-check deferred to Plan 02-04 manual gate; no automated battery measurement here.
  </acceptance_criteria>
  <done>
    fact_event + fact_current + dek_scope shipped (p98). projection_audit_record extended (p113). App-side projector (`session.begin()`) live with idempotency + atomicity tests green. /v1/audit/mobile-session-{start,link} endpoints live; OpenAPI canonical regenerated. Flutter MobileL1AuditService with offline buffer + UUID v7 + lifecycle hooks live; flutter test green. **First-slice canary on monthly_gross_income parity-PROVEN end-to-end** — this is the W1 exit gate per CONTEXT D-25.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Railway env-var dashboard → app process | `MINT_AUDIT_HASH_PEPPER` + `MINT_KMS_KEY_ID` cross from Railway secrets to FastAPI process at boot |
| Mobile app → `/v1/audit/mobile-session-*` | Anonymous payload (no auth header) writes to `projection_audit_records`; replay-safe via UNIQUE constraint |
| Mobile sqflite_sqlcipher buffer → app memory | Encrypted at rest; password derived per app install |
| KMS backend (Fernet / future AWS KMS) → DEK wrap/unwrap | Existing `_select_backend()` resolves at runtime; logical key-id `mint-master-v1` is the audit anchor |
| Projector `session.begin()` → fact_event + fact_current writes | Transactional atomicity; failure rolls both back |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-01 | Tampering | KMS key compromise (Railway-native MK) | mitigate | Logical key-id `mint-master-v1` in `dek_vault.kms_key_ref` per row; Phase 04 sub-DEK split + `dek_scope` future-proofing; re-litigation triggers locked (>10k users / EDÖB / FINMA / Railway FIPS). Pre-launch threat surface is small. |
| T-02-02 | Information Disclosure (RTBF non-compliance) | crypto_shred_user failure path | mitigate | `test_dek_shred_opacity.py` (Task 2): NULL wrapped_dek → every value_enc row decrypt returns `DEKRevokedError` not plaintext. PFPDT-validated mechanism (existing). Audit row carries `revoked_at` timestamp. |
| T-02-03 | Tampering | Envelope payload tamper (cross-user, MITM, replay) | mitigate | AESGCM AAD bound to user_id (existing envelope.py invariant); decrypting under a different user_id raises authentication error. `test_encrypted_value_helper.py` verifies cross-user decrypt fails. TLS 1.3 enforced server-side. |
| T-02-04 | Repudiation / Integrity | Audit-row HMAC-pepper rotation | mitigate | Pepper ≥ 32 chars enforced at `hmac_pepper._get_pepper()`. Rotation procedure documented in Plan 02-04 (`docs/operations/audit-pepper-rotation.md`) — re-backfill `user_id_hash` with new pepper, retain old hash as `user_id_hash_v1` column for transition. Pre-launch first-set is in this plan's Task 1 checkpoint. |
| T-02-05 | Tampering / Replay | `/v1/audit/mobile-session-link` replay | mitigate | UNIQUE constraint `(anonymous_session_id, observed_at) WHERE anonymous_session_id IS NOT NULL`. Endpoint returns 200 + count rather than 409 — retry-safe by design (RESEARCH § Security Domain). |
| T-02-13 | Information Disclosure | value_enc plaintext via Sentry breadcrumb | mitigate | `core/sentry.py before_send` recursively strips `value_enc` field. Test in Task 2 verifies removal. |
| T-02-14 | Tampering | Concurrent DEK creation race | mitigate | `dek_vault.user_id` is PK → second concurrent INSERT raises IntegrityError. Task 2 wraps `get_or_create_dek` in retry-once block per Pitfall 2. Test `test_dek_envelope_concurrency.py` exercises 2-thread race. |
| T-02-15 | Spoofing | Anonymous UUID v7 collision | accept | Collision space ≈ 2^122 (48-bit ms timestamp + 74 random bits); for MINT's pre-launch scale (<1B sessions) the collision probability is negligible. Server-side UNIQUE is belt-and-suspenders. |
| T-02-16 | Information Disclosure | ContextVar leak across requests (test_dek_envelope_concurrency interleaves 2 users) | mitigate | Existing `EncryptionContextMiddleware` resets `current_user_id`/`current_db_session` per request. Task 2 test asserts cross-user decrypt with wrong context raises authentication error. |
| T-02-17 | Tampering | Postgres extension drift (pgcrypto not installed) | accept | Python-side HMAC via `cryptography.hazmat` — no pgcrypto dependency. p114 backfill is Python loop, NOT pgcrypto DO-block. RESEARCH A5 risk-mitigated by design. |
</threat_model>

<verification>
**Phase-level checks for this plan:**
1. **Wave gate**: full pytest + lints + flutter test all green before Task 3 close-out. The canary parity test is the explicit W1 → W2 gate (D-25); if it fails, do NOT proceed to Plan 02-03.
2. **Checkpoint precedence**: Task 1 (Julien Railway env-var rehearsal) MUST resolve `approved` before Task 2 starts the Python data_upgrade in p114 (which uses `hmac_user_id` at migration time and requires `MINT_AUDIT_HASH_PEPPER` to be set — pg_fixture uses TESTING=1 fallback, but Railway staging deploy in W2 PR-2 cannot proceed without the env var).
3. **`autonomous: false`**: this plan has 1 blocking checkpoint (Task 1) + 2 autonomous tasks (Task 2 + Task 3). The checkpoint is operational, NOT a code review.
4. **OpenAPI parity**: every new endpoint must regenerate the canonical JSON (`tools/openapi/mint.openapi.canonical.json`). CI parity check fails if not. Pre-push checklist memory `feedback_pre_push_checklist.md` requires this.
5. **0-trust §9**: SUMMARY at close-out cites: (a) pytest exit-0 SHA + count delta vs Plan 02-01 baseline, (b) pg_fixture run output (PostgreSQL 15 detected + alembic upgrade head sha), (c) Flutter test output (3 audit test files green), (d) canary parity test stdout showing the two values equal, (e) Sentry strip test, (f) `gh pr view <N> --json mergedAt` once merged. Banned phrases not used pre-merge.
6. **Engram**: save `mem_save` with `topic_key: mint-data-architecture-v1-02:wave-1:event-log-core` + `prior_finding_refs` to obs #163, #174, #175, #176, #186, #187, #188, plus this phase's Plan 02-01 SUMMARY obs once created.
</verification>

<success_criteria>
- [ ] `MINT_AUDIT_HASH_PEPPER` set on Railway production + staging (Julien-confirmed, Task 1).
- [ ] `MINT_KMS_KEY_ID=mint-master-v1` confirmed on Railway production (Task 1).
- [ ] `hmac_user_id` + `EncryptedValue` + `encrypt_value/decrypt_value` shipped; round-trip tests green (Task 2).
- [ ] `dek_vault.dek_scope` column added with default `'user'`; concurrency retry-once green (Task 2 + Task 3 schema).
- [ ] 4 Phase 01 carry-overs closed (D-14 audit user_id_hash + plaintext NULL, D-15 actor/ip/UA hash, D-16 /privacy/delete real count, D-17 snapshot cache invalidation) (Task 2).
- [ ] 6 D-33 counters DECLARED in `app/observability/counters.py` (firing assertion deferred to Plan 02-04) (Task 2).
- [ ] Sentry `before_send` strips `value_enc` (Task 2).
- [ ] `fact_event` + `fact_current` ORM + migration p98 ship with REVOKE + PARTITION BY HASH + composite PK + UNIQUE idempotency (Task 3).
- [ ] `projection_audit_record` extended via p113 (source / app_version / observed_at / anonymous_session_id) (Task 3).
- [ ] `project_fact_event` projector live with session.begin() atomicity + sequence-number-monotonicity idempotency (Task 3).
- [ ] `/v1/audit/mobile-session-start` + `/v1/audit/mobile-session-link` endpoints live; OpenAPI canonical regenerated; D-13 clean separation enforced (no fact_event INSERT) (Task 3).
- [ ] Flutter `MobileL1AuditService` + offline SQLite buffer (sqflite_sqlcipher) + UUID v7 + lifecycle hooks (cold-start + warm-resume >30min) live; flutter test green (Task 3).
- [ ] **First-slice canary on `monthly_gross_income` parity-PROVEN end-to-end**: write → projector → fact_current decrypted == SnapshotModel.gross_income (Task 3 — THE W1 → W2 gate).
- [ ] Full backend pytest: `cd services/backend && python3 -m pytest tests/ -q` exits 0 (≥ 7264 baseline + ~50 new tests; zero regression).
- [ ] Flutter analyze + flutter test green; `cd apps/mobile && flutter analyze && flutter test` exits 0.
- [ ] All Plan 02-01 lints (D-20 + D-24) stay clean on the new code.
- [ ] OpenAPI parity check exits 0.
- [ ] Bundle-size measurement for Flutter SQLite buffer documented in SUMMARY (<100KB compressed addition per CONTEXT).
- [ ] 0-trust §9.6 evidence/caveat block in SUMMARY.
</success_criteria>

<output>
After completion, create `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-02-event-log-core-canary-SUMMARY.md`. Required content:
- Per-task verify command stdout (pytest exit-0, pg_fixture self-test output, flutter test output, OpenAPI parity check).
- All commit SHAs in order (Task 2 commits + Task 3 commits separately).
- PR URL once opened.
- 16 D-XX dispositions with file:line references (D-01, D-02, D-03, D-12, D-13, D-14, D-15, D-16, D-17, D-19, D-25, D-26, D-27, D-28, D-29, D-30) — note that D-07 audit retention REVOKE is partially shipped here via p98 (full retention policy doc in Plan 02-04).
- Canary parity test stdout verbatim showing the two values equal (the W1 → W2 gate proof).
- Bundle-size measurement output (apps/mobile build size before/after).
- Sentry strip test stdout.
- 0-trust §9.6 Evidence + Caveat block.
- `mem_save` with `topic_key: mint-data-architecture-v1-02:wave-1:event-log-core-canary` + `prior_finding_refs` to obs #150, #163, #174, #175, #176, #186, #187, #188 + Plan 02-01 obs.
</output>

---

<!-- ============================================================== -->
<!-- ITER-2 REVIEWS REVISION — appended 2026-05-18                 -->
<!-- Heaviest patch surface: 7 Tier-A blockers land here.           -->
<!-- A1+A2+A3 = DDL ; A4+A5+A6 = security ; A8+A11 = projector.    -->
<!-- ============================================================== -->

<iter_2_revision>

## Iter-2 Reviews Revision — Plan 02-02

**Trigger:** REVIEWS.md `database-architect HIGH-1/2/3` + `security-auditor T-S01/S05/S09` + `postgres-pro HIGH-2` + `qa-expert HIGH-2`.

**Tier-A blockers handled here (7 of 11):**
- A1: `dek_vault` `ON DELETE CASCADE` → `ON DELETE RESTRICT` + add `tombstone_at` column. **Crypto-shred-as-tombstone fix.**
- A2: `fact_event` PK reorder `(event_id, subject_id)` → `(subject_id, event_id)`. Index-only scan for dominant query.
- A3: `fact_current` covering index leading column `(subject_id, fact_type) INCLUDE (...)`. **RECURRENCE of obs #174 — iter-1 missed.**
- A4: `key_vault._select_backend()` remove silent KMS→Fernet fallback + `mint_kms_backend_failure_total` counter. **Single highest-severity finding.**
- A5: `KeyVaultService._dek_cache` 5-min TTL eviction + `mint_dek_cache_size_total` gauge.
- A6: `/v1/audit/mobile-session-link` proof-of-session-start handshake.
- A8: Projector SELECT-then-UPDATE → `INSERT ... ON CONFLICT ... DO UPDATE WHERE latest_event_id < EXCLUDED`. Atomic UPSERT.
- A11: Multi-shape canary (scalar + nested JSONB + nullable + multi-KB blob) before PR-3 ships.

**Tier-B handled here (W1 budget):**
- B2: `no_mobile_fact_current_regulatory_read.py` HARD lefthook on Dart.
- B6: `encrypt_value()` calls `check_banned_terms(plaintext)` for `coach_inference` / `user_input` source_types.
- B8: `MODULUS 1` → `MODULUS 8` for fact_event partitioning from day one.
- B9: FK `fact_current.latest_event_id → fact_event.event_id NOT VALID`.
- B10: `fillfactor=70` on fact_current + autovacuum tuning.
- B11: Cap `confidence.enrichmentPrompts` at 5×200 chars in D-29 contract.
- B12: Engine URL `prepare_threshold=None` guard before Railway PgBouncer.
- B15: Pool sizing `pool_timeout=10` + backfill script `pool_size=2, max_overflow=0` override.
- B17 (partial): D-30 two-device + clock-skew + reinstall + low-storage tests scaffolded (full deferred to Plan 02-04 Task 3).

**Tier-C acknowledged (defer):**
- C3: Projector transaction-pattern docstring → applied below (one-line patch).
- C5: `EncryptedValue.tag` `Literal[""]` + docstring → applied below.
- C7: JSONB `pg_column_size < 65536` CHECK constraint → defer_in_plan_04_task_3 (close-out runbook contract).

**Tier-A not handled here:**
- A7: D-20 lint expand → Plan 02-01 iter-2 revision above.
- A9: PR-3 split → Plan 02-03 (structural change).
- A10: `projection_diff.py` deterministic drift → Plan 02-03.

### New D-XX proposed (justification block, owner-approval required before silent CONTEXT.md edit)

The iter-2 revision surfaces 2 new locked decisions that REVIEWS.md plan-patches imply but CONTEXT.md does not yet codify. Surfacing them here for Julien-owner approval BEFORE editing CONTEXT.md (per patching_constraints rule 6):

**D-34 (PROPOSED)** — **Multi-shape canary parity gate BEFORE PR-3 cutover.**
> D-25 single-shape `monthly_gross_income` (scalar float) is INSUFFICIENT to validate cutover for decimal-precision facts (`pillar_3a_balance`), nested JSONB (`confidence`, `archetype_tags`), nullable optionals, large TOAST-eligible blobs. iter-2 adds 4 canary fact-types covering all 4 shape classes:
> - scalar float: `monthly_gross_income` (already in D-25)
> - decimal-precision: `pillar_3a_balance` (Decimal exact 2dp)
> - nested JSONB: `archetype_tags` (list[str] + nested confidence map)
> - nullable optional: `lpp_avoirs_vieillesse` (NULL for users w/o LPP)
> - multi-KB TOAST blob: synthetic `coach_extracted_facts` payload ≥ 4KB
> All 5 canaries must parity-prove on staging BEFORE Plan 02-03 PR-3a backfill fires.

**D-35 (PROPOSED)** — **KMS backend failure is fail-closed, never silent fallback.**
> `key_vault._select_backend()` MUST raise `KMSBackendUnavailable` if the primary KMS resolution fails. The silent KMS→Fernet fallback shipped in `services/backend/app/services/encryption/key_vault.py:134-141` was a security HIGH (split-brain key wrapping). Counter `mint_kms_backend_failure_total{backend, reason}` increments on every fallback attempt — alarms ring before next request. Re-litigation trigger: Railway KMS provider GA-launch + 3-month soak with zero `mint_kms_backend_failure_total` increments.

**Status:** PROPOSED — pending Julien-owner approval. If approved, CONTEXT.md gains D-34 + D-35 in Area 4. If rejected, Plan 02-02 iter-2 still ships A4 + A11 patches but as Plan-internal hardening, not phase-locked decisions.

### Patch to original Task 2 — A4 + A5 + B6 + B12 + B15 (security + pooling + banned-terms write-time)

**Replaces** the original Task 2 step 5 (`key_vault.py` extend block). The original spec defaulted to Fernet on dev when `MINT_KMS_KEY_ID` unset and did NOT remove the silent fallback path. iter-2 makes both paths explicit and observable.

**Updated `<action>` step 5 — `services/backend/app/services/encryption/key_vault.py` (Tier-A A4 + A5)**:

1. **Remove silent KMS→Fernet fallback (A4).** Current `_select_backend()` catches `KeyVaultServiceError` and falls through to `_FernetBackend`. Replace with:
   ```python
   def _select_backend(self) -> KeyVaultBackend:
       """Resolve KMS backend from MINT_KMS_KEY_ID env. Fail-closed: raise instead of falling back silently.

       D-35 (iter-2): silent KMS→Fernet fallback is a security HIGH (split-brain key wrapping).
       Dev environments MUST opt in to Fernet explicitly via MINT_KMS_BACKEND=fernet.
       """
       key_id = os.environ.get("MINT_KMS_KEY_ID", "").strip()
       explicit_backend = os.environ.get("MINT_KMS_BACKEND", "").strip().lower()
       if explicit_backend == "fernet":
           mint_kms_backend_failure_total.labels(backend="fernet", reason="explicit_dev_optin").inc()
           return _FernetBackend()
       if not key_id:
           mint_kms_backend_failure_total.labels(backend="none", reason="MINT_KMS_KEY_ID unset").inc()
           raise KMSBackendUnavailable(
               "MINT_KMS_KEY_ID is unset. Set it to 'mint-master-v1' for Railway-native KMS, "
               "OR set MINT_KMS_BACKEND=fernet explicitly for dev (D-35 fail-closed contract)."
           )
       # Future: when AWS KMS / GCP KMS backends ship, branch here on key_id prefix.
       # Phase 02 Railway-native: logical key-id 'mint-master-v1' maps to the Fernet-backed
       # key for now (per D-02 trade-off); this path is fail-closed when key_id is set
       # but the backend cannot be resolved.
       try:
           return _FernetBackend(key_id=key_id)
       except KeyVaultServiceError as e:
           mint_kms_backend_failure_total.labels(backend="fernet", reason=type(e).__name__).inc()
           raise KMSBackendUnavailable(f"KMS backend resolution failed for {key_id}: {e}") from e
   ```
2. **Add `mint_kms_backend_failure_total` Counter to `app/observability/counters.py`** alongside the 6 D-33 counters (this becomes the 7th counter declared in this plan, increment to D-33 list in this plan's `must_haves.truths`).
3. **Add `mint_dek_cache_size_total` Gauge** (A5 monitoring) — the 8th counter.
4. **DEK cache TTL eviction (A5).** Current `_dek_cache: dict[str, bytes]` is unbounded. Replace with:
   ```python
   from cachetools import TTLCache  # pyproject add: cachetools>=5.3
   class KeyVaultService:
       _DEK_CACHE_TTL_SECONDS = 300  # 5 minutes
       _DEK_CACHE_MAXSIZE = 1024     # bounded; staging traffic << 1024 active users
       def __init__(self, ...):
           self._dek_cache: TTLCache[str, bytes] = TTLCache(
               maxsize=self._DEK_CACHE_MAXSIZE,
               ttl=self._DEK_CACHE_TTL_SECONDS,
           )
       def get_or_create_dek(self, db, user_id: str) -> bytes:
           # ... existing logic ...
           dek = self._dek_cache.get(user_id)
           if dek is not None:
               mint_dek_cache_size_total.set(len(self._dek_cache))
               return dek
           # ... resolve from dek_vault + unwrap ...
           self._dek_cache[user_id] = dek
           mint_dek_cache_size_total.set(len(self._dek_cache))
           return dek
   ```
   Sentry `before_send` (already touched in Task 2 step 13) MUST recursively strip the `_dek_cache` attribute from any captured exception (per security-auditor T-S05 mitigation note).
5. **Pool sizing (Tier-B B12 + B15).** `services/backend/app/db.py` (or wherever the engine factory lives — executor must grep before patching):
   ```python
   engine = create_engine(
       DATABASE_URL,
       pool_size=20,
       max_overflow=20,
       pool_timeout=10,                # NEW — backfill must not exhaust pool indefinitely (B15)
       pool_pre_ping=True,
       connect_args={
           "prepare_threshold": None,  # NEW — PgBouncer transaction-pool compat (B12)
           "options": "-c application_name=mint-backend",
       },
   )
   ```
   Backfill script (Plan 02-03 PR-3a) imports a separate engine with `pool_size=2, max_overflow=0`. Reference helper in `app/db.py`: `get_backfill_engine()` returning the throttled variant.

**Updated `<action>` step 4 — `encrypted_value_helper.py` (Tier-B B6 banned-terms write-time)**:

Insert after JSON serialization, BEFORE `encrypt_bytes`:
```python
from app.services.encryption.banned_terms_runtime import scan_value_for_banned_terms, BannedTermsViolation

def encrypt_value(db, user_id: str, value: Any, *, source_type: str | None = None) -> dict:
    """...existing docstring...

    iter-2 (Tier-B B6): when source_type in {'coach_inference', 'user_input'}, the plaintext
    is scanned for LSFin banned terms BEFORE encryption. NFKC-normalised + zero-width-strip
    + 14-pattern regex from tools/checks/banned_terms_python.py reused via the runtime helper.
    Raises BannedTermsViolation if any banned term is detected — fail-closed at write time.
    """
    plaintext_bytes = json.dumps(value, separators=(",", ":"), sort_keys=True).encode("utf-8")
    if source_type in ("coach_inference", "user_input"):
        scan_value_for_banned_terms(value)  # raises BannedTermsViolation on hit
    envelope_bytes = encrypt_bytes(db, user_id, plaintext_bytes)
    # ... existing assembly into dict ...
```

Add new module `services/backend/app/services/encryption/banned_terms_runtime.py` (NEW, ~40 LOC) that reuses `tools/checks/banned_terms_python.py` scan logic at runtime (NOT a subprocess — import the scan function directly). Self-exempt: nothing (production scan path).

### New Task 3A — DDL patches to p98 + p113 (Tier-A A1 + A2 + A3 + Tier-B B8 + B9 + B10 + B11)

Inserted as a sub-task of original Task 3. **ALL DDL patches land in the p98 migration body that Task 3 step 1 writes.** Cheap because the migration is being authored fresh; expensive post-merge (DETACH + recreate). Pre-launch zero-data is the ONLY window.

<task type="auto" tdd="true">
  <name>Task 3A (NEW iter-2): DDL patches to p98 alembic — A1 dek_vault RESTRICT + tombstone_at, A2 fact_event PK reorder, A3 fact_current covering index leading column, B8 MODULUS 8, B9 FK NOT VALID, B10 fillfactor + autovacuum, B11 enrichmentPrompts cap</name>
  <files>
    services/backend/alembic/versions/p98_fact_event_projection_dek.py,
    services/backend/app/models/fact_event.py,
    services/backend/app/models/fact_current.py,
    services/backend/app/models/dek_vault.py,
    services/backend/app/models/encryption/encrypted_value.py,
    services/backend/tests/integration/test_migration_p98_iter2.py,
    services/backend/tests/integration/test_fact_current_covering_index.py,
    services/backend/tests/integration/test_dek_vault_restrict_tombstone.py
  </files>
  <read_first>
    services/backend/alembic/versions/p98_fact_event_projection_dek.py (DRAFT from Task 3 step 1 — DDL body to patch),
    services/backend/app/models/dek_vault.py (current ON DELETE CASCADE — pre-iter-2),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-REVIEWS.md (database-architect HIGH-1/2/3, postgres-pro LOW-iii),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-RESEARCH.md (lines 457 fact_event PK + 532 fact_current covering index)
  </read_first>
  <behavior>
    **Test 20 (A1 dek_vault RESTRICT)**: pg_fixture. `DELETE FROM users WHERE id=$x` where x has a dek_vault row → IntegrityError (RESTRICT blocks cascade). Setting `dek_vault.tombstone_at = now()` is the only path to break the FK; `value_enc` rows referencing the DEK remain queryable AND decrypt-fail (existing crypto-shred opacity test still holds).
    **Test 21 (A2 fact_event PK reorder)**: pg_fixture. After p98 upgrade, `\d fact_event` shows PRIMARY KEY `(subject_id, event_id)` (NOT `(event_id, subject_id)`). `EXPLAIN (ANALYZE, BUFFERS) SELECT event_id, fact_type FROM fact_event WHERE subject_type='user' AND subject_id='<u>' ORDER BY recorded_at DESC LIMIT 50` returns « Index Only Scan » (NOT « Heap Scan »).
    **Test 22 (A3 fact_current covering index leading column)**: pg_fixture. After p98 upgrade, `\d fact_current` shows `ix_fact_current_subject_covering ON fact_current (subject_id, fact_type) INCLUDE (latest_event_id, value_enc, confidence, visibility)`. `EXPLAIN SELECT value_enc, latest_event_id FROM fact_current WHERE subject_id='<u>' AND fact_type='monthly_gross_income'` returns « Index Only Scan using ix_fact_current_subject_covering ».
    **Test 23 (B8 MODULUS 8)**: pg-only. `SELECT count(*) FROM pg_class WHERE relname LIKE 'fact_event_p%'` returns 8 (partitions `_p_0` through `_p_7`).
    **Test 24 (B9 FK NOT VALID)**: pg-only. `SELECT conname, convalidated FROM pg_constraint WHERE conname = 'fk_fact_current_latest_event_id'` returns (1 row, convalidated=false). Inserting a `fact_current` row with `latest_event_id` not in `fact_event` raises NO error (NOT VALID is descriptive, not enforced) — by design pre-launch; planner re-litigation when first prod data lands.
    **Test 25 (B10 fillfactor + autovacuum)**: pg-only. `SELECT reloptions FROM pg_class WHERE relname='fact_current'` contains `fillfactor=70` AND `autovacuum_vacuum_scale_factor=0.05`.
    **Test 26 (B11 enrichmentPrompts cap)**: Pydantic v2 model on `EncryptedValue.confidence.enrichmentPrompts` rejects payloads with >5 prompts OR any prompt >200 chars → ValidationError. Unit test seeds bad payload + asserts rejection.
  </behavior>
  <action>
1. **A1 — `dek_vault` ON DELETE RESTRICT + `tombstone_at` column** (modify p98 DDL body):

   In the original Task 3 p98 migration `upgrade()`, after `dek_scope` column addition, ADD:
   ```python
   # iter-2 A1: change FK ON DELETE behaviour CASCADE → RESTRICT + add tombstone_at column
   if bind.dialect.name == "postgresql":
       op.execute("""
           ALTER TABLE dek_vault DROP CONSTRAINT IF EXISTS dek_vault_user_id_fkey;
           ALTER TABLE dek_vault ADD CONSTRAINT dek_vault_user_id_fkey
             FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;
       """)
   else:
       # SQLite path: batch_alter_table recreate with new FK
       with op.batch_alter_table("dek_vault") as batch:
           batch.drop_constraint("dek_vault_user_id_fkey", type_="foreignkey")
           batch.create_foreign_key("dek_vault_user_id_fkey", "users", ["user_id"], ["id"], ondelete="RESTRICT")
   op.add_column("dek_vault",
       sa.Column("tombstone_at", sa.DateTime(timezone=True), nullable=True))
   # tombstone_at IS NULL → active row; tombstone_at IS NOT NULL → user-requested deletion,
   # FK relaxed via app code (set ON DELETE behaviour via `services/backend/app/services/encryption/dek_tombstone.py`
   # which (1) sets tombstone_at = now(), (2) crypto_shred_user(NULLs wrapped_dek), (3) eventually
   # DELETE FROM users (allowed once dek_vault.tombstone_at IS NOT NULL — RESTRICT
   # is enforced unless app explicitly tombstones first).
   ```

   `services/backend/app/models/dek_vault.py` update Python ORM:
   ```python
   class DEKVault(Base):
       user_id = Column(String, ForeignKey("users.id", ondelete="RESTRICT"), primary_key=True)  # iter-2 A1
       # ... existing columns ...
       tombstone_at = Column(DateTime(timezone=True), nullable=True)  # iter-2 A1
       dek_scope = Column(String(32), nullable=False, server_default=sa.text("'user'"))
   ```

   `services/backend/app/services/encryption/dek_tombstone.py` (NEW, ~25 LOC): `tombstone_user_dek(db, user_id)` sets `tombstone_at`, calls `crypto_shred_user`, increments `mint_dek_envelope_status_total{status='tombstoned'}`. The existing `crypto_shred_user` (key_vault.py) is left unchanged; this new helper composes it with the tombstone marker so RESTRICT can be bypassed by app code only.

2. **A2 — `fact_event` PK reorder** (modify p98 DDL body):

   In the `fact_event` CREATE TABLE block (Postgres path), the original spec used `PRIMARY KEY (event_id, subject_id)` (with `subject_id` as partition key). iter-2 reorders to `(subject_id, event_id)` so the dominant « all events for subject » query is index-only:
   ```sql
   CREATE TABLE fact_event (
       event_id        UUID NOT NULL,
       subject_id      UUID NOT NULL,
       -- ... other columns ...
       PRIMARY KEY (subject_id, event_id)   -- iter-2 A2: subject_id LEADS for index-only scan
   ) PARTITION BY HASH (subject_id);
   CREATE INDEX ix_fact_event_subject_recorded ON fact_event
       (subject_type, subject_id, recorded_at DESC) INCLUDE (event_id, fact_type);   -- secondary
   ```
   `services/backend/app/models/fact_event.py` `__table_args__` updated to match.

3. **A3 — `fact_current` covering index leading column** (modify p98 DDL body):

   The original spec wrote `CREATE INDEX ix_fact_current_subject_covering ON fact_current (subject_id) INCLUDE (...)`. iter-2 expands the index key to include `fact_type` so the « 20-50 facts for one user » query (D-01) is fully covered:
   ```sql
   CREATE INDEX ix_fact_current_subject_covering ON fact_current
       (subject_id, fact_type)   -- iter-2 A3: fact_type joins leading cols, NOT INCLUDE
       INCLUDE (latest_event_id, value_enc, confidence, visibility)
       WITH (fillfactor=70);     -- iter-2 B10
   ALTER TABLE fact_current SET (
       fillfactor=70,
       autovacuum_vacuum_scale_factor=0.05,   -- iter-2 B10: aggressive
       autovacuum_analyze_scale_factor=0.05
   );
   ```

4. **B8 — `MODULUS 8` from day one** (modify p98 DDL):

   Replace `PARTITION OF fact_event FOR VALUES WITH (MODULUS 1, REMAINDER 0)` (single partition) with 8 partitions:
   ```python
   for remainder in range(8):
       op.execute(f"""
           CREATE TABLE fact_event_p_{remainder} PARTITION OF fact_event
           FOR VALUES WITH (MODULUS 8, REMAINDER {remainder});
       """)
   ```
   Reason: pre-launch zero data → free to start at 8 partitions; future split requires DETACH/ATTACH choreography that this avoids.

5. **B9 — FK `fact_current.latest_event_id → fact_event.event_id NOT VALID`** (append to p98 DDL):

   ```python
   if bind.dialect.name == "postgresql":
       op.execute("""
           ALTER TABLE fact_current ADD CONSTRAINT fk_fact_current_latest_event_id
             FOREIGN KEY (subject_id, latest_event_id)
             REFERENCES fact_event (subject_id, event_id)
             NOT VALID;
       """)
       # NOT VALID is descriptive (Postgres doesn't enforce on existing rows but enforces on
       # NEW INSERT). pre-launch zero data → effectively enforced from row 1. VALIDATE
       # CONSTRAINT deferred to post-launch.
   # SQLite path: skip — SQLite enforces FKs only via PRAGMA, and the test fixture
   # already exercises pg_fixture for FK contracts.
   ```

6. **B11 — Cap `confidence.enrichmentPrompts` at 5×200 chars in D-29 contract** (modify Pydantic v2 model):

   `services/backend/app/models/encryption/encrypted_value.py` — extend or add a sibling model `EnhancedConfidence`:
   ```python
   from pydantic import BaseModel, Field, field_validator
   class EnhancedConfidence(BaseModel):
       c: float = Field(ge=0.0, le=1.0)
       a: float = Field(ge=0.0, le=1.0)
       f: float = Field(ge=0.0, le=1.0)
       u: float = Field(ge=0.0, le=1.0)
       score: float = Field(ge=0.0, le=1.0)
       enrichmentPrompts: list[str] = Field(default_factory=list, max_length=5)
       @field_validator("enrichmentPrompts")
       @classmethod
       def _cap_prompt_length(cls, v: list[str]) -> list[str]:
           for prompt in v:
               if len(prompt) > 200:
                   raise ValueError(f"enrichmentPrompt too long ({len(prompt)} chars > 200): {prompt[:50]}...")
           return v
       model_config = {"extra": "forbid"}
   ```
   Update D-29 contract (CONTEXT.md change proposed below). Plan 02-02 `must_haves` adds: « `EnhancedConfidence.enrichmentPrompts` rejects >5 entries OR any entry >200 chars at Pydantic validate time. »

7. **Tier-C C5 — `EncryptedValue.tag` typed** (one-line patch to `EncryptedValue` already in Task 2):

   ```python
   tag: Literal[""] = Field(default="", description="Reserved; AESGCM appends auth tag to ct. iter-2 C5: typed as Literal[''] to surface ambiguity to readers.")
   ```

8. **Tier-C C3 — Projector transaction-pattern docstring** (one-line patch to `fact_projector.py`):

   At the top of `project_fact_event`:
   ```python
   """Caller MUST wrap this in `session.begin()` (or `session.begin_nested()` if already in a transaction).
   D-19: app-side transactional projector. iter-2 C3: choosing `session.begin()` over `begin_nested()`
   for top-level callers (Plan 02-02 writers); `session.begin_nested()` for nested transaction callers
   (Plan 02-03 PR-2 dual-write — already in transaction)."""
   ```
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/integration/test_migration_p98.py tests/integration/test_migration_p98_iter2.py tests/integration/test_fact_current_covering_index.py tests/integration/test_dek_vault_restrict_tombstone.py tests/integration/test_partition_declared.py -q -k pg && python3 -m pytest tests/ -q -x && python3 -c "from app.models.encryption.encrypted_value import EnhancedConfidence; from pydantic import ValidationError; failed=False
try:
    EnhancedConfidence(c=0.8,a=0.9,f=1.0,u=0.7,score=0.85, enrichmentPrompts=['x'*201])
except ValidationError: failed=True
assert failed, 'B11 cap not enforced'" && python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/</automated>
  </verify>
  <acceptance_criteria>
    - `cd services/backend && python3 -m pytest tests/integration/test_dek_vault_restrict_tombstone.py -q -k pg` exits 0; pg_fixture confirms ON DELETE RESTRICT enforced + tombstone_at column exists.
    - `cd services/backend && python3 -m pytest tests/integration/test_migration_p98_iter2.py -q -k pg` exits 0; assertions: PK `(subject_id, event_id)`, 8 partitions, fact_current covering index `(subject_id, fact_type) INCLUDE (...)`, FK NOT VALID present, fillfactor=70.
    - `cd services/backend && python3 -m pytest tests/integration/test_fact_current_covering_index.py -q -k pg` exits 0; EXPLAIN ANALYZE output contains « Index Only Scan ».
    - `python3 -c "from app.models.encryption.encrypted_value import EnhancedConfidence; from pydantic import ValidationError; EnhancedConfidence(c=0.8,a=0.9,f=1.0,u=0.7,score=0.85, enrichmentPrompts=['x'*201])"` raises ValidationError (B11 enforced).
    - `git grep -n "fillfactor=70" services/backend/alembic/versions/p98_fact_event_projection_dek.py` returns ≥2 hits (fact_current + index).
    - `git grep -n "MODULUS 8" services/backend/alembic/versions/p98_fact_event_projection_dek.py` returns ≥1 hit.
    - `git grep -n "ON DELETE RESTRICT" services/backend/alembic/versions/p98_fact_event_projection_dek.py services/backend/app/models/dek_vault.py` returns ≥2 hits.
    - Existing Task 3 acceptance criteria still hold (D-25 canary parity + audit_mobile endpoint + Mobile L1 audit service); nothing in iter-2 regresses original Task 3.
  </acceptance_criteria>
  <done>
    p98 ships with: dek_vault FK RESTRICT + tombstone_at; fact_event PK (subject_id, event_id); fact_current covering index with leading (subject_id, fact_type); 8 partitions; FK NOT VALID on fact_current.latest_event_id; fillfactor=70 + autovacuum tuning; EnhancedConfidence enrichmentPrompts capped 5×200. The Crypto-shred-as-tombstone semantic is restored; the dominant index-only scans are real; partition split is a future no-op.
  </done>
</task>

### New Task 3B — Projector atomic UPSERT (Tier-A A8)

Inserted as a sub-task of original Task 3. **Surgical patch to `fact_projector.py`** — replaces SELECT-then-UPDATE with `INSERT ... ON CONFLICT ... DO UPDATE WHERE`. Single roundtrip + lost-update-safe under Read Committed.

<task type="auto" tdd="true">
  <name>Task 3B (NEW iter-2): Projector SELECT-then-UPDATE → atomic INSERT ... ON CONFLICT ... DO UPDATE WHERE (Tier-A A8 + database-architect MED-1)</name>
  <files>
    services/backend/app/services/projector/fact_projector.py,
    services/backend/tests/integration/test_projector_concurrent_upsert.py
  </files>
  <read_first>
    services/backend/app/services/projector/fact_projector.py (DRAFT from Task 3 step 6 — SELECT-then-UPDATE pattern to replace),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-RESEARCH.md (Pattern 2 projector lines 320-407),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-REVIEWS.md (postgres-pro HIGH-2 lost-update under Read Committed)
  </read_first>
  <behavior>
    **Test 27 (concurrent UPSERT lost-update)**: pg_fixture. Spin 2 threads, each writing `fact_event(subject_id=U, fact_type='monthly_gross_income')` with monotonic `event_id`s e1 < e2. Both call `project_fact_event` concurrently. After both commit, `fact_current.latest_event_id = e2` (NOT e1, NOT NULL). Run 100 iterations; assert latest_event_id is monotonic across all runs. `mint_projector_idempotency_skip_total` increments by 100 (one per loser-thread per iteration).
    **Test 28 (single-writer idempotency unchanged)**: existing `test_projector_idempotency.py` from original Task 3 must still pass — re-injecting the same event_id is a no-op (counter increments, fact_current unchanged).
  </behavior>
  <action>
**Replaces** the original Task 3 step 6 projector implementation. The current spec uses:
```python
existing = session.query(FactCurrent).filter_by(...).one_or_none()
if existing and existing.latest_event_id >= event.event_id:
    mint_projector_idempotency_skip_total.inc()
    return
if existing:
    existing.latest_event_id = event.event_id
    existing.value_enc = event.value_enc
    # ...
else:
    session.add(FactCurrent(...))
```
This is 2 roundtrips AND lost-update-vulnerable under Read Committed (two concurrent writers both see `existing.latest_event_id < event.event_id`, both UPDATE, second commit wins by clock NOT by event_id monotonicity).

**Replace with atomic UPSERT (Postgres path)**:
```python
from sqlalchemy.dialects.postgresql import insert as pg_insert

def project_fact_event(session: Session, event: FactEvent) -> None:
    """iter-2 A8: atomic UPSERT via INSERT ... ON CONFLICT ... DO UPDATE WHERE.
    Single roundtrip + lost-update-safe under Read Committed.
    """
    session.add(event)
    session.flush()  # raises IntegrityError if D-27 UNIQUE blocks dup at fact_event level

    if session.bind.dialect.name == "postgresql":
        stmt = pg_insert(FactCurrent).values(
            subject_type=event.subject_type,
            subject_id=event.subject_id,
            fact_type=event.fact_type,
            value_enc=event.value_enc,
            latest_event_id=event.event_id,
            confidence=event.confidence,
            visibility=event.visibility,
            updated_at=event.recorded_at,
        )
        upsert = stmt.on_conflict_do_update(
            index_elements=["subject_type", "subject_id", "fact_type"],
            set_={
                "value_enc": stmt.excluded.value_enc,
                "latest_event_id": stmt.excluded.latest_event_id,
                "confidence": stmt.excluded.confidence,
                "visibility": stmt.excluded.visibility,
                "updated_at": stmt.excluded.updated_at,
            },
            where=(FactCurrent.latest_event_id < stmt.excluded.latest_event_id),
        )
        result = session.execute(upsert)
        if result.rowcount == 0:
            # ON CONFLICT WHERE didn't update — sequence-number monotonicity skip
            mint_projector_idempotency_skip_total.inc()
        else:
            mint_fact_event_insert_total.labels(source_type=event.source_type).inc()
    else:
        # SQLite path: emulate via SELECT-then-UPDATE under SAVEPOINT (test-only path)
        existing = session.query(FactCurrent).filter_by(
            subject_type=event.subject_type,
            subject_id=event.subject_id,
            fact_type=event.fact_type,
        ).one_or_none()
        if existing is None:
            session.add(FactCurrent(...))  # full row
        elif existing.latest_event_id < event.event_id:
            existing.latest_event_id = event.event_id
            # ... update other fields ...
        else:
            mint_projector_idempotency_skip_total.inc()
            return
        mint_fact_event_insert_total.labels(source_type=event.source_type).inc()
```

**New test `tests/integration/test_projector_concurrent_upsert.py`** (TDD-first):
```python
import threading
import uuid_utils
def test_two_concurrent_writers_monotonic_latest_event_id(pg_session):
    """A8: 2-thread race on same (subject_id, fact_type) → latest_event_id is the MAX event_id, NOT clock-order."""
    user_id = "u-test"
    # ensure DEK for both threads
    dek = KeyVaultService(...).get_or_create_dek(pg_session, user_id)
    barrier = threading.Barrier(2)
    results = []
    def writer(event_id_seed: int):
        with pg_session() as s:
            event = FactEvent(
                event_id=str(uuid_utils.uuid7()),  # seed bumps the timestamp ms
                subject_type='user', subject_id=user_id, fact_type='monthly_gross_income',
                value_enc=encrypt_value(s, user_id, 8500.0 + event_id_seed, source_type='user_input'),
                source_type='user_input', recorded_at=datetime.now(timezone.utc),
            )
            barrier.wait()
            with s.begin():
                project_fact_event(s, event)
            results.append(event.event_id)
    t1 = threading.Thread(target=writer, args=(0,))
    t2 = threading.Thread(target=writer, args=(1,))
    t1.start(); t2.start(); t1.join(); t2.join()
    assert len(results) == 2
    max_event = max(results)
    fc = pg_session.query(FactCurrent).filter_by(subject_id=user_id, fact_type='monthly_gross_income').one()
    assert fc.latest_event_id == max_event, "lost-update detected: latest_event_id is not max"
```
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/integration/test_projector_concurrent_upsert.py tests/integration/test_projector_idempotency.py tests/integration/test_projector_atomicity.py -q -k pg && python3 -m pytest tests/ -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `cd services/backend && python3 -m pytest tests/integration/test_projector_concurrent_upsert.py -q -k pg` exits 0; 100-iteration loop shows zero lost-update events.
    - Existing `test_projector_idempotency.py` + `test_projector_atomicity.py` from original Task 3 still pass (no regression).
    - `git grep -n "on_conflict_do_update" services/backend/app/services/projector/fact_projector.py` returns ≥1 hit.
    - `git grep -n "where=" services/backend/app/services/projector/fact_projector.py | grep -c "latest_event_id"` returns ≥1.
  </acceptance_criteria>
  <done>
    Projector is single-roundtrip + lost-update-safe under Read Committed. The race surface that postgres-pro HIGH-2 flagged is closed at the DB layer. SQLite test path retains the SELECT-then-UPDATE emulation (test-only, single-threaded).
  </done>
</task>

### New Task 3C — Multi-shape canary parity gate (Tier-A A11, D-34 PROPOSED)

Inserted as a sub-task of original Task 3, AFTER the single-shape canary on `monthly_gross_income`. Adds 4 additional canary fact-types covering decimal-precision, nested JSONB, nullable, and multi-KB TOAST blob shapes. Lands BEFORE Plan 02-03 PR-3 backfill fires.

<task type="auto" tdd="true">
  <name>Task 3C (NEW iter-2): Multi-shape canary parity gate — 5 fact-types covering scalar + decimal + nested JSONB + nullable + TOAST blob (Tier-A A11 + D-34 PROPOSED)</name>
  <files>
    services/backend/tests/integration/test_canary_multi_shape_parity.py,
    services/backend/tests/integration/test_canary_pillar_3a_balance.py,
    services/backend/tests/integration/test_canary_archetype_tags_jsonb.py,
    services/backend/tests/integration/test_canary_lpp_avoirs_nullable.py,
    services/backend/tests/integration/test_canary_coach_extracted_toast.py,
    services/backend/tests/fixtures/canary_fixtures.py
  </files>
  <read_first>
    services/backend/tests/integration/test_canary_monthly_gross_income.py (from original Task 3 — scalar baseline shape),
    services/backend/app/models/snapshot.py (deprecated post-Plan-02-03 PR-5 but still present here — read shape for parity comparator)
  </read_first>
  <behavior>
    **Test 29 (decimal-precision canary — `pillar_3a_balance`)**: write fact_event with `value = Decimal("12345.67")`; project; assert `decrypt_value(... fact_current.value_enc) == Decimal("12345.67")` (NOT `12345.67` float). Round-trip through JSON canonical → `"12345.67"` string preserved.
    **Test 30 (nested JSONB canary — `archetype_tags`)**: write fact_event with `value = ["expat_eu", "frontalier"] + nested confidence map`. Project. Decrypt. Assert deep-equality.
    **Test 31 (nullable canary — `lpp_avoirs_vieillesse`)**: user has NO LPP. write fact_event with `value = None` (or skip the row). Project should NOT emit a fact_current row for this fact_type — assert `SELECT count(*) FROM fact_current WHERE fact_type='lpp_avoirs_vieillesse' AND subject_id=$U = 0`. Comparator: SnapshotModel.lpp_avoirs_vieillesse for the same user IS NULL → parity holds.
    **Test 32 (TOAST blob canary — synthetic `coach_extracted_facts`)**: write fact_event with `value = {"facts": ["x" * 4000]}` (~4KB). Project. Decrypt. Assert blob ≥ 4KB AND `pg_column_size(value_enc)` triggers TOAST (Postgres only).
    **Test 33 (multi-shape parity composite)**: invoke all 4 + the existing scalar canary in one pytest session; assert all 5 pass before Plan 02-03 PR-3a can fire.
  </behavior>
  <action>
1. **`services/backend/tests/fixtures/canary_fixtures.py` (NEW)**: shared fixture builders for the 5 canary shapes (`build_scalar_canary`, `build_decimal_canary`, `build_jsonb_canary`, `build_nullable_canary`, `build_toast_canary`).
2. **Per-shape test file**: each runs `pg_fixture`, writes `fact_event` with the appropriate shape, runs projector, asserts decrypt round-trip + parity vs SnapshotModel (where applicable).
3. **`test_canary_multi_shape_parity.py`**: runs all 5 in one composite test that imports the per-shape tests as helpers. Outputs a summary report `/tmp/multi_shape_canary.log` with PASS/FAIL per shape. **The composite test is the W1 → W2 explicit gate before Plan 02-03 PR-3 fires.**
4. Document in Plan 02-02 SUMMARY: « D-34 (PROPOSED) — Multi-shape canary parity gate: 5/5 PASS at commit SHA `<X>`. Plan 02-03 PR-3 fires only after this gate. »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/integration/test_canary_multi_shape_parity.py tests/integration/test_canary_pillar_3a_balance.py tests/integration/test_canary_archetype_tags_jsonb.py tests/integration/test_canary_lpp_avoirs_nullable.py tests/integration/test_canary_coach_extracted_toast.py -q -k pg 2>&1 | tee /tmp/multi_shape_canary.log && grep -c "PASSED" /tmp/multi_shape_canary.log | grep -E "^[5-9]|[1-9][0-9]"</automated>
  </verify>
  <acceptance_criteria>
    - All 5 canary tests pass: `pytest test_canary_*.py -q -k pg` exits 0.
    - `/tmp/multi_shape_canary.log` contains 5 PASSED lines (one per shape).
    - Decimal canary: round-trip preserves `Decimal("12345.67")` (NOT float coercion).
    - JSONB canary: deep-equality preserves nested map + list order.
    - Nullable canary: zero fact_current rows for NULL value_enc.
    - TOAST canary: `pg_column_size(value_enc) > 2048` (TOAST threshold hit).
    - SUMMARY documents D-34 PROPOSED status + 5/5 PASS verbatim before any Plan 02-03 PR-3a work begins.
  </acceptance_criteria>
  <done>
    Multi-shape canary parity gate active. The W1 → W2 transition gate is now 5-shape parity-proven, NOT single-shape. qa-expert HIGH-2 + postgres-pro LOW-iii closed.
  </done>
</task>

### Patch to original Task 3 — A6 audit-mobile endpoint proof-of-session-start handshake (security-auditor T-S01)

**Replaces** the original Task 3 step 7 `audit_mobile.py` `/v1/audit/mobile-session-link` implementation. The original spec accepts any batch POST with auth header; iter-2 requires proof-of-session-start as a precondition.

**Updated `<action>` step 7** (executor: apply this in place of the original step 7):

```python
@router.post("/audit/mobile-session-link")
async def link_mobile_audit_batch(
    payload: MobileSessionLinkBatch,
    user=Depends(get_current_user),
    db=Depends(get_db),
) -> MobileSessionLinkResponse:
    """iter-2 A6: require proof-of-session-start handshake BEFORE accepting batch link.

    Without this gate, any authenticated client can inject audit rows with any
    `anonymous_session_id`; at link time the server permanently attributes
    spoofed sessions to the authenticated user (LSFin audit-integrity HIGH).

    The handshake: for each batch entry, the server MUST find at least one prior
    row in projection_audit_records with the SAME `anonymous_session_id` AND
    `source='mobile_session_start'`. If absent → reject the entire batch (NOT
    just the offending entry — partial-batch acceptance creates ambiguity).
    """
    user_id_hash = hmac_user_id(user.id)
    # Group batch by anonymous_session_id
    sids_in_batch: set[str] = {row.anonymous_session_id for row in payload.items}
    # Single query to find which sids have a prior session-start row
    rows = db.execute(
        sa.text("""
            SELECT DISTINCT anonymous_session_id
            FROM projection_audit_records
            WHERE anonymous_session_id = ANY(:sids)
              AND source = 'mobile_session_start'
        """),
        {"sids": list(sids_in_batch)},
    ).fetchall()
    sids_with_proof: set[str] = {r[0] for r in rows}
    missing_proof = sids_in_batch - sids_with_proof
    if missing_proof:
        mint_anonymous_session_link_total.labels(outcome="rejected_no_handshake").inc()
        raise HTTPException(
            status_code=403,
            detail={
                "error": "session_link_handshake_missing",
                "message": "Batch contains anonymous_session_id values with no prior mobile_session_start row. "
                           "Link is rejected. Per D-30 + iter-2 A6 (T-S01 spoofing mitigation), the mobile client "
                           "MUST POST /v1/audit/mobile-session-start before /v1/audit/mobile-session-link.",
                "missing_sids": sorted(missing_proof),
            },
        )
    # ... existing batch INSERT ON CONFLICT DO NOTHING logic ...
    mint_anonymous_session_link_total.labels(outcome="linked").inc()
    return MobileSessionLinkResponse(linked=count_new, skipped=count_dup)
```

**Updated `<verify>` block for original Task 3** (add):
```bash
cd services/backend && python3 -m pytest tests/integration/test_audit_mobile_link.py::test_link_rejects_batch_without_session_start_handshake -q -k pg
```

**Updated `<acceptance_criteria>` for original Task 3** (add):
- `test_link_rejects_batch_without_session_start_handshake` exits 0: a batch POST with `anonymous_session_id` lacking a prior `mobile_session_start` row returns HTTP 403 with `error: session_link_handshake_missing`.
- `test_link_accepts_batch_with_handshake` exits 0: a batch POST where each `anonymous_session_id` has a prior `mobile_session_start` row returns 200 with `linked: N`.

**Mobile-side flutter test addition** (`apps/mobile/test/services/audit/mobile_l1_audit_service_test.dart`):
- Test that the offline-queue replay logic POSTs `/v1/audit/mobile-session-start` BEFORE `/v1/audit/mobile-session-link` on first-ever-replay (cold install → linkable state).

### New Task 3D — `no_mobile_fact_current_regulatory_read.py` HARD lefthook (Tier-B B2)

Inserted as a sub-task of original Task 3. Small lint surface (~30 LOC). Architect-review concern: mobile must NEVER read `fact_current(subject_type='regulatory')` rows directly — that path breaks L1 offline-canonical.

<task type="auto">
  <name>Task 3D (NEW iter-2): `no_mobile_fact_current_regulatory_read.py` HARD lefthook on Dart (Tier-B B2, architect-review)</name>
  <files>
    tools/checks/no_mobile_fact_current_regulatory_read.py,
    tools/checks/tests/test_no_mobile_fact_current_regulatory_read.py,
    apps/mobile/test/_fixtures/bad_regulatory_read.dart,
    lefthook.yml
  </files>
  <read_first>
    tools/checks/profile_safe_fields_parity.py (Phase 01 D-12 lint pattern reference),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-REVIEWS.md (architect-review MED concern — fact_current(subject_type='regulatory') read-path UNDEFINED)
  </read_first>
  <action>
1. **`tools/checks/no_mobile_fact_current_regulatory_read.py` (NEW)**: Python CLI script. Default scan: `apps/mobile/lib/**/*.dart`. Logic: regex `r"fact_current.*subject_type.*['\"]regulatory['\"]"` (with `re.IGNORECASE`). If match → exit 1 with file:line + message:
   > « Mobile MUST NOT read fact_current(subject_type='regulatory') directly. Regulatory constants come from codegen-baked `regulatoryConstantsVersionHash` per Phase 01 D-08 + D-16. Bypassing codegen breaks L1 offline-canonical and L1/L2 boundary discipline. »
2. **`apps/mobile/test/_fixtures/bad_regulatory_read.dart` (NEW)**: 5-line fixture containing the forbidden pattern. Self-exempt by path glob.
3. **lefthook.yml**: append on `pre-commit`:
   ```yaml
   no-mobile-fact-current-regulatory-read:
     run: python3 tools/checks/no_mobile_fact_current_regulatory_read.py {staged_files}
     glob: "apps/mobile/lib/**/*.dart"
     tags: [mobile, l1-offline-canonical, phase-02-d-12]
     fail_text: "Mobile MUST NOT read fact_current(subject_type='regulatory') — use codegen-baked constants (Phase 01 D-08). iter-2 B2 architect-review."
   ```
4. **`tools/checks/tests/test_no_mobile_fact_current_regulatory_read.py` (NEW)**: assert lint exits 1 on bad fixture + exits 0 on clean tree + self-exempts itself.
  </action>
  <verify>
    <automated>python3 tools/checks/no_mobile_fact_current_regulatory_read.py apps/mobile/test/_fixtures/bad_regulatory_read.dart; [ $? -eq 1 ] && python3 tools/checks/no_mobile_fact_current_regulatory_read.py apps/mobile/lib/ && grep -c "no-mobile-fact-current-regulatory-read" lefthook.yml | grep -E "^1$" && python3 -m pytest tools/checks/tests/test_no_mobile_fact_current_regulatory_read.py -q</automated>
  </verify>
  <acceptance_criteria>
    - Lint exits 1 on bad fixture; exits 0 on clean `apps/mobile/lib/` tree.
    - `grep -c "no-mobile-fact-current-regulatory-read" lefthook.yml` returns 1.
    - `python3 -m pytest tools/checks/tests/test_no_mobile_fact_current_regulatory_read.py -q` exits 0.
  </acceptance_criteria>
  <done>
    Mobile L1/L2 boundary discipline enforced at commit time. architect-review MED concern closed.
  </done>
</task>

### CONTEXT.md changes proposed by this revision (PROPOSED — owner-approval required)

These changes refine 3 existing D-XX without redefining the locked decisions. Proposing as patch diff:

**D-26 (EncryptedValue typed JSONB shape)** — append after the existing Pydantic class definition:
```diff
   class EncryptedValue(BaseModel):
       ct: str   # base64-encoded ciphertext
       iv: str   # base64-encoded IV/nonce (96-bit for GCM)
-      tag: str  # base64-encoded auth tag
+      tag: Literal[""] = ""  # iter-2 C5: AESGCM appends auth tag to ct; this field is reserved + typed.
       alg: Literal["AES-256-GCM"] = "AES-256-GCM"
       dek_id: str  # logical key ref, e.g. "mint-master-v1"
       enc_v: int = 1  # envelope-format version (for future DEK rotation)
```

**D-28 (Partition declaration in p98)** — bump partition count:
```diff
-  - **D-28:** **Partition declaration in p98.** `PARTITION BY HASH (subject_id) PARTITIONS 1` ships in p98 alembic from day one.
+  - **D-28:** **Partition declaration in p98.** `PARTITION BY HASH (subject_id) PARTITIONS 8` ships in p98 alembic from day one (iter-2 B8 — pre-launch zero-data window is the only free split opportunity ; future split = `ATTACH PARTITION` no-op at production scale).
```

**D-29 (`confidence` JSONB shape)** — add cap:
```diff
-  - **D-29:** **`confidence` JSONB = full EnhancedConfidence 4-axis.** Shape : `{c: 0.8, a: 0.9, f: 1.0, u: 0.7, score: 0.85, enrichmentPrompts: ["..."]}`
+  - **D-29:** **`confidence` JSONB = full EnhancedConfidence 4-axis.** Shape : `{c: 0.8, a: 0.9, f: 1.0, u: 0.7, score: 0.85, enrichmentPrompts: ["..."]}` — **iter-2 B11 cap: enrichmentPrompts MAX 5 entries × 200 chars each** (TOAST-row-size discipline ; Pydantic v2 `EnhancedConfidence` enforces at validate time).
```

**D-30 (Anonymous-session buffer mechanics)** — add handshake requirement:
```diff
-    - **Link on first login** — single batch POST `/v1/audit/mobile-session-link` with array of buffered audit rows.
+    - **Link on first login** — single batch POST `/v1/audit/mobile-session-link` with array of buffered audit rows. **iter-2 A6 — proof-of-session-start handshake**: the server REJECTS the entire batch if any `anonymous_session_id` lacks a prior `projection_audit_records` row with `source='mobile_session_start'` for that sid. T-S01 spoofing mitigation.
```

**New: D-34 PROPOSED + D-35 PROPOSED** — full text in « New D-XX proposed » section above.

### VALIDATION.md additions proposed by this revision

Append to `## Per-Task Verification Map → Wave 1 — Schema + KMS + HMAC-pepper`:

| Task ID | Plan | Wave | Decision | Threat Ref | Secure Behavior | Test Type | Automated Command |
|---------|------|------|----------|------------|-----------------|-----------|-------------------|
| 02-02-3A | 02-02 | 1 | A1 (dek_vault RESTRICT) | T-02-02 + crypto-shred-as-tombstone | ON DELETE RESTRICT + tombstone_at column ; app code path tombstone → shred → DELETE | integration (pg_fixture) | `pytest tests/integration/test_dek_vault_restrict_tombstone.py -q -k pg` |
| 02-02-3A | 02-02 | 1 | A2 (fact_event PK reorder) | T-S03 + perf | PK `(subject_id, event_id)` → index-only scan on dominant query | integration | `pytest tests/integration/test_migration_p98_iter2.py::test_fact_event_pk_order -q -k pg` |
| 02-02-3A | 02-02 | 1 | A3 (fact_current covering index leading col) | obs #174 RECURRENCE | Index `(subject_id, fact_type) INCLUDE (...)` → EXPLAIN shows Index Only Scan | integration | `pytest tests/integration/test_fact_current_covering_index.py -q -k pg` |
| 02-02-3A | 02-02 | 1 | B8 (MODULUS 8) | T-S03 + future-perf | 8 partitions present at p98 ; split is a no-op | integration | `pytest tests/integration/test_migration_p98_iter2.py::test_partition_count_eight -q -k pg` |
| 02-02-3A | 02-02 | 1 | B9 (FK NOT VALID) | T-S03 integrity | fact_current.latest_event_id → fact_event.event_id NOT VALID present | integration | `pytest tests/integration/test_migration_p98_iter2.py::test_fact_current_fk_not_valid -q -k pg` |
| 02-02-3A | 02-02 | 1 | B11 (enrichmentPrompts cap) | T-S08 DoS + TOAST | Pydantic rejects >5 prompts OR any >200 chars | unit | `python3 -c "from app.models.encryption.encrypted_value import EnhancedConfidence; EnhancedConfidence(...prompts=['x'*201])"` raises ValidationError |
| 02-02-3B | 02-02 | 1 | A8 (atomic UPSERT) | T-S03 lost-update | INSERT ON CONFLICT DO UPDATE WHERE latest_event_id < EXCLUDED — concurrent writers ordered by event_id NOT clock | integration (concurrency) | `pytest tests/integration/test_projector_concurrent_upsert.py -q -k pg` |
| 02-02-3C | 02-02 | 1 | A11 + D-34 PROPOSED (multi-shape canary) | T-S03 parity | 5/5 shapes (scalar+decimal+jsonb+nullable+TOAST) parity-pass | integration (composite) | `pytest tests/integration/test_canary_multi_shape_parity.py -q -k pg` |
| 02-02-3D | 02-02 | 1 | B2 (Dart L1 boundary lint) | architect MED — mobile fact_current(regulatory) read | HARD lefthook rejects `fact_current.*subject_type.*'regulatory'` regex on Dart files | unit (lint) | `python3 tools/checks/no_mobile_fact_current_regulatory_read.py --self-test` |
| 02-02-A4 | 02-02 | 1 | A4 + D-35 PROPOSED (KMS fail-closed) | T-S09 HIGH | `_select_backend()` raises KMSBackendUnavailable on resolution fail ; counter increments ; no silent Fernet fallback | unit + integration | `pytest tests/test_key_vault_logical_id.py::test_no_silent_fernet_fallback -q` |
| 02-02-A5 | 02-02 | 1 | A5 (DEK cache TTL) | T-S05 HIGH | TTLCache 5min + 1024 maxsize ; `mint_dek_cache_size_total` gauge set on each access | unit | `pytest tests/test_key_vault_logical_id.py::test_dek_cache_ttl_eviction -q` |
| 02-02-A6 | 02-02 | 1 | A6 (link handshake) | T-S01 HIGH | Batch link rejects if any sid lacks prior mobile_session_start row → 403 | integration | `pytest tests/integration/test_audit_mobile_link.py::test_link_rejects_batch_without_session_start_handshake -q -k pg` |
| 02-02-B6 | 02-02 | 1 | B6 (banned-terms write-time) | T-S11 MED | `encrypt_value(... source_type='coach_inference')` scans plaintext + raises BannedTermsViolation | unit | `pytest tests/test_encrypted_value_helper.py::test_banned_terms_scan_on_coach_inference -q` |

### Threat-model extension (append, do not rewrite)

Append to the existing STRIDE Threat Register in this plan:

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-S09 | Elevation of Privilege | `key_vault._select_backend()` silent KMS→Fernet fallback | HIGH | mitigate (A4) | iter-2 removes silent fallback ; `_select_backend()` raises `KMSBackendUnavailable` ; `mint_kms_backend_failure_total{backend, reason}` counter. Dev opt-in via `MINT_KMS_BACKEND=fernet` env explicit. |
| T-S05 | Information Disclosure | `KeyVaultService._dek_cache` plaintext DEK cache as unbounded process singleton | HIGH | mitigate (A5) | iter-2 TTLCache 5min + 1024 maxsize ; `mint_dek_cache_size_total` gauge ; Sentry `before_send` recursively strips `_dek_cache` attribute from captured exceptions. |
| T-S01 | Spoofing | `/v1/audit/mobile-session-link` anonymous-session-link spoofing | HIGH | mitigate (A6) | iter-2 proof-of-session-start handshake : batch link rejects if any sid lacks prior `mobile_session_start` row → 403. `mint_anonymous_session_link_total{outcome='rejected_no_handshake'}` counter. |
| T-DA-01 | Tampering / RTBF | `dek_vault` ON DELETE CASCADE breaks crypto-shred-as-tombstone | HIGH | mitigate (A1) | iter-2 FK ON DELETE RESTRICT + `tombstone_at` column ; app code path `tombstone_user_dek()` → `crypto_shred_user()` → `DELETE FROM users` (only allowed once tombstone_at IS NOT NULL). |
| T-DA-02 | Performance / Heap-fetch | `fact_event` PK `(event_id, subject_id)` forces heap fetch on dominant query | HIGH | mitigate (A2) | iter-2 PK `(subject_id, event_id)` + secondary `(subject_type, subject_id, recorded_at DESC) INCLUDE (event_id, fact_type)` → Index Only Scan confirmed via `EXPLAIN ANALYZE` in test. |
| T-PG-02 | Tampering / Lost-update | Projector SELECT-then-UPDATE under Read Committed | HIGH | mitigate (A8) | iter-2 `INSERT ... ON CONFLICT ... DO UPDATE WHERE latest_event_id < EXCLUDED` atomic. 100-iteration 2-thread test asserts monotonic latest_event_id. |
| T-QA-02 | Tampering / Cutover | Single-shape canary (D-25 scalar only) cannot validate decimal / JSONB / nullable / TOAST | HIGH | mitigate (A11 + D-34) | iter-2 multi-shape canary : 5 fact-types covering all shape classes parity-prove BEFORE Plan 02-03 PR-3 fires. |
| T-S11-EXT | Compliance / LSFin | Runtime banned-terms in `coach_inference` / `user_input` plaintext | MED | mitigate (B6) | iter-2 `encrypt_value(... source_type='coach_inference')` scans plaintext via `banned_terms_runtime` BEFORE encryption + raises `BannedTermsViolation`. |

### Tier-C considered, deferred

- **C1 Docker docs** → defer_in_plan_04_task_4 (CONTRIBUTING.md / services/backend/README.md addendum at phase close).
- **C2 PR-3 commit-message contract** → defer_in_plan_03 iter-2 (commit-message template + cite allowlist rationale ; lands with PR-3 split).
- **C4 over-decomposed D-XX merge** → defer to post-Phase-02 retrospective (renumbering risks audit-trail breakage during active execution).
- **C6 native UUID / TIMESTAMPTZ** → defer_in_plan_04_task_4 (post-Phase-02 hardening migration ; pre-launch performance is dominated by network, not column-type).
- **C7 JSONB `pg_column_size < 65536` CHECK** → defer_in_plan_04_task_3 (close-out runbook adds CHECK as separate migration ; B11 enrichmentPrompts cap mitigates the dominant TOAST risk).
- **C8 STAGING-DOWN-OVERRIDE required check** → defer_in_plan_04_task_2 (CI fix lands with D-06 mechanical fixes ; GitHub branch-protection rule update needs Julien repo-admin access).

### `<files_modified>` additions for Plan 02-02 frontmatter

```yaml
files_modified:
  # ...original list...
  - services/backend/app/services/encryption/dek_tombstone.py                          # A1
  - services/backend/app/services/encryption/banned_terms_runtime.py                   # B6
  - services/backend/app/db.py                                                          # B12 + B15
  - services/backend/tests/integration/test_migration_p98_iter2.py                     # A1 + A2 + A3 + B8 + B9 + B10
  - services/backend/tests/integration/test_fact_current_covering_index.py             # A3
  - services/backend/tests/integration/test_dek_vault_restrict_tombstone.py            # A1
  - services/backend/tests/integration/test_projector_concurrent_upsert.py             # A8
  - services/backend/tests/integration/test_canary_multi_shape_parity.py               # A11 + D-34
  - services/backend/tests/integration/test_canary_pillar_3a_balance.py                # A11
  - services/backend/tests/integration/test_canary_archetype_tags_jsonb.py             # A11
  - services/backend/tests/integration/test_canary_lpp_avoirs_nullable.py              # A11
  - services/backend/tests/integration/test_canary_coach_extracted_toast.py            # A11
  - services/backend/tests/fixtures/canary_fixtures.py                                 # A11
  - tools/checks/no_mobile_fact_current_regulatory_read.py                             # B2
  - tools/checks/tests/test_no_mobile_fact_current_regulatory_read.py                  # B2
  - apps/mobile/test/_fixtures/bad_regulatory_read.dart                                # B2
  # --- iter-3 additions (HIGH-A1 + HIGH-A2 from Claude-Opus post-iter-2 review) ---
  - services/backend/conftest.py                                                       # iter-3 iA1 (requires_pg marker)
  - services/backend/tests/integration/test_audit_mobile_link_handshake_replay_ordering.py  # iter-3 iA2
```

### `<decisions>` frontmatter additions for Plan 02-02

```yaml
decisions: [D-01, D-02, D-03, D-12, D-13, D-14, D-15, D-16, D-17, D-19, D-25, D-26, D-27, D-28, D-29, D-30, D-34-PROPOSED, D-35-PROPOSED]
requirements_addressed:
  # ...original list...
  - CONTEXT.md#D-34 PROPOSED multi-shape canary parity gate (iter-2)
  - CONTEXT.md#D-35 PROPOSED KMS fail-closed never silent fallback (iter-2)
```

### `<must_haves.truths>` additions for Plan 02-02

```yaml
  - "iter-2 A1: dek_vault FK ON DELETE RESTRICT + tombstone_at column ; deleting users w/ active dek_vault row raises IntegrityError ; tombstone_user_dek() is the only path to break the FK."
  - "iter-2 A2: fact_event PRIMARY KEY (subject_id, event_id) → EXPLAIN ANALYZE on dominant query returns Index Only Scan."
  - "iter-2 A3: fact_current covering index (subject_id, fact_type) INCLUDE (latest_event_id, value_enc, confidence, visibility) → EXPLAIN returns Index Only Scan using ix_fact_current_subject_covering."
  - "iter-2 A4 + D-35 PROPOSED: key_vault._select_backend() raises KMSBackendUnavailable on resolution failure ; no silent Fernet fallback ; mint_kms_backend_failure_total{backend, reason} counter increments."
  - "iter-2 A5: KeyVaultService._dek_cache is TTLCache(maxsize=1024, ttl=300) ; mint_dek_cache_size_total gauge set on each access ; Sentry before_send strips _dek_cache attribute."
  - "iter-2 A6: /v1/audit/mobile-session-link rejects batch with any anonymous_session_id lacking a prior mobile_session_start row (HTTP 403, mint_anonymous_session_link_total{outcome='rejected_no_handshake'})."
  - "iter-2 A8: project_fact_event uses INSERT ... ON CONFLICT ... DO UPDATE WHERE latest_event_id < EXCLUDED (atomic upsert) ; 100-iteration 2-thread test asserts monotonic latest_event_id."
  - "iter-2 A11 + D-34 PROPOSED: 5-shape canary parity-PROVEN (scalar monthly_gross_income + decimal pillar_3a_balance + nested JSONB archetype_tags + nullable lpp_avoirs_vieillesse + TOAST coach_extracted_facts ≥4KB) BEFORE Plan 02-03 PR-3 fires."
  - "iter-2 B2: tools/checks/no_mobile_fact_current_regulatory_read.py HARD lefthook on Dart files rejects fact_current(subject_type='regulatory') reads."
  - "iter-2 B6: encrypt_value(... source_type='coach_inference'|'user_input') scans plaintext via banned_terms_runtime BEFORE encryption ; raises BannedTermsViolation."
  - "iter-2 B8: fact_event ships with 8 partitions (MODULUS 8) from p98 ; future split is no-op at production scale."
  - "iter-2 B9: fact_current.latest_event_id FOREIGN KEY (subject_id, latest_event_id) → fact_event(subject_id, event_id) NOT VALID."
  - "iter-2 B10: fact_current SET (fillfactor=70, autovacuum_vacuum_scale_factor=0.05, autovacuum_analyze_scale_factor=0.05)."
  - "iter-2 B11 + D-29 amended: EnhancedConfidence.enrichmentPrompts MAX 5 × 200 chars ; Pydantic v2 ValidationError if violated."
  - "iter-2 B12: engine connect_args includes prepare_threshold=None for future PgBouncer compat."
  - "iter-2 B15: engine pool_timeout=10 ; backfill script uses throttled pool_size=2, max_overflow=0 via get_backfill_engine()."
  - "iter-2: 2 NEW counters (mint_kms_backend_failure_total + mint_dek_cache_size_total) bring D-33 declared count from 6 → 8 (Plan 02-04 close-out asserts firing on all 8)."
```

### Iter-2 commit recommendation

Single commit message: `docs(mint-data-architecture-v1-02-event-log-projection): plan iter-2 reviews revision — A1+A2+A3 DDL + A4+A5+A6 security + A8 atomic UPSERT + A11 multi-shape canary + Tier-B B2/B6/B8-B12/B15 (Plan 02-02)`.

</iter_2_revision>

<!-- ============================================================== -->
<!-- ITER-3 REVISION — appended 2026-05-18                          -->
<!-- Source: REVIEWS.md §7 Claude-Opus post-iter-2 review            -->
<!-- Scope: surgical micro-revision absorbing 3 new HIGHs            -->
<!--   - HIGH-A1 → iA1 (Plan 02-02 Task 3B + Plan 02-01 CI gate)     -->
<!--   - HIGH-A2 → iA2 (Plan 02-02 Task 3 new integration test)      -->
<!--   - HIGH-A3 → iA3 (Plan 02-02 Task 1 — applied in-place above)  -->
<!-- iA4 universal-miss landing in Plan 02-04 SUMMARY (separate edit) -->
<!-- ============================================================== -->

<iter_3_revision>

## Iter-3 Reviews Revision — Plan 02-02

**Trigger:** REVIEWS.md §7 Claude-Opus post-iter-2 fresh-session review (commit `35eb5eee` baseline). 3 new HIGH findings + 1 universal-miss surfaced; this revision lands the 3 surgical fixes on Plan 02-02.

**Scope contract** (per `<patching_constraints>` rule 11): 3 hours hard cap, no new D-XX, no CONTEXT.md changes, in-place + append-only edits.

### iA1 — Projector SQLite-path divergence trap (`pytest.mark.requires_pg` + CI gate extension)

**Source:** REVIEWS.md §7.3 HIGH-A1 — `Plan 02-02 Task 3B uses Postgres INSERT ... ON CONFLICT ... DO UPDATE WHERE (correct). SQLite test path falls back to SELECT-then-UPDATE under SAVEPOINT (the iter-1 vulnerable pattern). The 100-iteration race test uses pg_session — only exercises Postgres. Developers running pytest -q -k "not pg" locally see ALL projector tests pass on the SQLite path, even though that path will not ship.`

**Fix landing sites:**
1. **`services/backend/conftest.py`** (extend) — register a `requires_pg` pytest marker so SQLite-only test runs skip projector tests explicitly with a visible « skipped: projector requires Postgres (iter-3 iA1) » message rather than silently passing on the SQLite emulation path.
2. **ALL projector tests** under `services/backend/tests/services/projector/` AND `services/backend/tests/integration/test_projector_*.py` get a `@pytest.mark.requires_pg` decorator. This includes (post-Plan-02-02):
   - `tests/integration/test_projector_idempotency.py`
   - `tests/integration/test_projector_atomicity.py`
   - `tests/integration/test_projector_concurrent_upsert.py` (iter-2 A8)
   - any new `tests/services/projector/*.py` that lands in execution.
3. **`.github/workflows/backend-ci.yml`** (extend Plan 02-01 Task 2 step 7 path filter) — the `pg-integration` job is currently gated on `services/backend/alembic/**` + `services/backend/app/models/**` + `services/backend/tests/fixtures/**`. iter-3 adds `services/backend/app/services/projector/**` so ANY change to projector code (not just alembic migrations) triggers the pg-integration job. Without this, a regression that drops `WHERE latest_event_id < EXCLUDED.latest_event_id` would only surface at the next alembic-touching PR — too late.

**Why this matters (cite Claude-Opus HIGH-A1 in code comment):** the SQLite emulation path in Plan 02-02 Task 3B (Postgres `INSERT ... ON CONFLICT ... DO UPDATE WHERE` vs SQLite SELECT-then-UPDATE under SAVEPOINT) creates a « tests green ≠ feature working » risk per CLAUDE.md §9. The mitigation is mechanical: explicit marker + CI path filter = no implicit reliance on developer discipline.

#### Plan 02-02 Task 3B `<action>` ADDITION (append after step 1 atomic UPSERT block — paste verbatim)

After the `if session.bind.dialect.name == "postgresql":` block and its SQLite emulation `else` branch, add a top-of-module marker comment AND ensure the `else` branch is annotated:

```python
# iter-3 iA1: Projector SQLite-path divergence trap (Claude-Opus HIGH-A1).
# The atomic INSERT ... ON CONFLICT ... DO UPDATE WHERE pattern is Postgres-only.
# The else branch below is a TEST-ONLY emulation under single-threaded SQLite —
# it WILL NOT enforce lost-update protection under concurrent writers.
# If you are reading this in production code (i.e., not via a `requires_pg`-marked
# test), STOP — your production database must be Postgres or this projector is unsafe.
# CI gate: `.github/workflows/backend-ci.yml` `pg-integration` job runs on every PR
# touching `services/backend/app/services/projector/**` so any regression that drops
# the `WHERE latest_event_id < EXCLUDED.latest_event_id` clause fails CI at the
# Postgres-real concurrent-upsert test (`tests/integration/test_projector_concurrent_upsert.py`).
```

#### `<files>` block for Task 3B — add (iter-3 iA1)

Add to Task 3B `<files>` element:
- `services/backend/conftest.py` (extend with `requires_pg` marker registration)

#### `<acceptance_criteria>` for Task 3B — append (iter-3 iA1)

- `grep -n "requires_pg" services/backend/conftest.py` returns ≥1 hit (marker registered with explicit docstring).
- `grep -rn "@pytest.mark.requires_pg" services/backend/tests/integration/test_projector_*.py` returns ≥3 hits (idempotency + atomicity + concurrent_upsert tests all marked).
- `cd services/backend && python3 -m pytest tests/integration/test_projector_idempotency.py -q -m "not requires_pg"` exits with collected=0 deselected=N (test correctly skipped when pg unavailable).
- `cd services/backend && python3 -m pytest tests/integration/test_projector_idempotency.py -q --strict-markers` exits 0 — markers strict-validated.

#### Plan 02-01 Task 2 step 7 `<action>` ADDITION (in-place note — paste into Plan 02-01 if/when re-edited; for now documented here for the executor)

The `pg-integration` GitHub Actions job's `paths:` filter in `.github/workflows/backend-ci.yml` MUST include `services/backend/app/services/projector/**`:

```yaml
on:
  pull_request:
    paths:
      - 'services/backend/alembic/**'
      - 'services/backend/app/models/**'
      - 'services/backend/tests/fixtures/**'
      - 'services/backend/app/services/projector/**'   # iter-3 iA1 — projector SQLite-path divergence trap
```

Note: this is a deferred-in-place ADDENDUM to Plan 02-01 Task 2 step 7. The executor running Plan 02-01 reads this iter_3_revision block and applies the path-filter extension at the same time as the original step 7 ships. No separate Plan 02-01 edit needed — single source of truth is here.

### iA2 — Mobile L1 audit link handshake replay ordering (integration test)

**Source:** REVIEWS.md §7.3 HIGH-A2 — `A6 mandates /v1/audit/mobile-session-link reject batches where any anonymous_session_id lacks a prior mobile_session_start. The Flutter test covers the simple case (« first-ever-replay »). No integration test asserts end-to-end ordering across mobile + backend — e.g., user offline 3 days with 5 session-starts + 5 warm-resumes + login event interleaved. Backend must accept all 11 events without 403 errors when the buffer replays.`

**Fix landing site:** new integration test file `services/backend/tests/integration/test_audit_mobile_link_handshake_replay_ordering.py`. Lands in Plan 02-02 Task 3 (the same task that ships `audit_mobile.py` + the existing simple-case `test_audit_mobile_link.py`).

#### `<files>` block for Task 3 — add (iter-3 iA2)

Add to Task 3 `<files>` element:
- `services/backend/tests/integration/test_audit_mobile_link_handshake_replay_ordering.py`

Add to Plan 02-02 frontmatter `files_modified`:
- `services/backend/tests/integration/test_audit_mobile_link_handshake_replay_ordering.py    # iter-3 iA2`

#### Test specification (paste verbatim into the new file at execution time)

```python
"""
iter-3 iA2 — Claude-Opus HIGH-A2 (REVIEWS.md §7.3).

Integration test for /v1/audit/mobile-session-link handshake replay ordering.
The Flutter-side unit test (apps/mobile/test/services/audit/mobile_l1_audit_service_test.dart)
covers the simple « first-ever replay » case (POST session-start, then POST link).
This integration test covers the realistic offline-buffer scenario: user offline
multiple days, queues an INTERLEAVED batch of mobile_session_start (M times) +
mobile_session_warm_resume (N times) + one login event, then comes online and
replays the entire chain. Backend must accept ALL events with 200/201 and NO 403
handshake-missing errors (because every warm_resume sid has a prior session_start
sid in the buffer that replays FIRST).
"""
import pytest
from datetime import datetime, timedelta, timezone
from uuid import uuid4


@pytest.mark.requires_pg  # iter-3 iA1 — projector + audit_mobile require pg path
def test_interleaved_session_start_warm_resume_login_batch_accepts_all(
    pg_session, test_client, authenticated_user
):
    """
    Scenario per Claude-Opus HIGH-A2:
      - User offline 3 days. Mobile SQLite buffer accumulates :
          5 × mobile_session_start (sid_A through sid_E)
          5 × mobile_session_warm_resume (each tagged with one of sid_A..sid_E)
          1 × login event triggering /v1/audit/mobile-session-link
      - Buffer replays in chronological observed_at order.
      - Backend must :
          (1) accept all 5 session-start rows on POST /v1/audit/mobile-session-start
              (each is anonymous, no auth required)
          (2) accept the batch POST /v1/audit/mobile-session-link with all 10 rows
              (5 start + 5 warm_resume) returning 200, linked=10, skipped=0
          (3) NEVER return 403 (every warm_resume sid has its session_start row
              committed BEFORE the link batch arrives, per iter-2 A6 handshake)
    """
    base_time = datetime.now(timezone.utc) - timedelta(days=3)
    constants_hash = "ph01-d16-codegen-baseline-hash"
    app_version = "2.3.0+iter3-test"

    # ---- 5 anonymous_session_ids covering offline period ----
    sids = [str(uuid4()) for _ in range(5)]

    # ---- Phase 1: replay 5 mobile_session_start POSTs (each anonymous, no auth) ----
    session_start_rows = []
    for i, sid in enumerate(sids):
        observed_at = (base_time + timedelta(hours=i * 12)).isoformat()
        resp = test_client.post(
            "/v1/audit/mobile-session-start",
            json={
                "anonymous_session_id": sid,
                "app_version": app_version,
                "observed_at": observed_at,
                "constants_version_hash": constants_hash,
                "source": "mobile_session_start",
            },
        )
        assert resp.status_code == 200, (
            f"session-start #{i} failed: {resp.status_code} {resp.text}"
        )
        session_start_rows.append({
            "anonymous_session_id": sid,
            "app_version": app_version,
            "observed_at": observed_at,
            "constants_version_hash": constants_hash,
            "source": "mobile_session_start",
        })

    # ---- Phase 2: build interleaved batch (5 start + 5 warm_resume) for link ----
    # Order: start_A, warm_A, start_B, warm_B, ... interleaved.
    warm_resume_rows = []
    for i, sid in enumerate(sids):
        observed_at = (base_time + timedelta(hours=i * 12 + 1)).isoformat()
        warm_resume_rows.append({
            "anonymous_session_id": sid,
            "app_version": app_version,
            "observed_at": observed_at,
            "constants_version_hash": constants_hash,
            "source": "mobile_session_warm_resume",
        })

    interleaved_batch = []
    for s_row, w_row in zip(session_start_rows, warm_resume_rows):
        interleaved_batch.append(s_row)
        interleaved_batch.append(w_row)
    assert len(interleaved_batch) == 10

    # ---- Phase 3: POST /v1/audit/mobile-session-link with auth header ----
    resp = test_client.post(
        "/v1/audit/mobile-session-link",
        json={"items": interleaved_batch},
        headers=authenticated_user.auth_headers,
    )
    assert resp.status_code == 200, (
        f"link rejected: {resp.status_code} {resp.text}\n"
        f"iter-3 iA2 contract violated — every warm_resume sid had a prior "
        f"session_start row committed (Phase 1), so handshake must succeed."
    )
    body = resp.json()
    # 5 session-start rows are dups of Phase 1 → skipped; 5 warm_resume are new → linked
    assert body["linked"] == 5, f"expected 5 linked, got {body['linked']}"
    assert body["skipped"] == 5, f"expected 5 skipped (start dups), got {body['skipped']}"


@pytest.mark.requires_pg
def test_link_batch_with_missing_session_start_rejects_entire_batch(
    pg_session, test_client, authenticated_user
):
    """
    Inverse of the test above: if even ONE warm_resume in the batch lacks a prior
    session_start row, iter-2 A6 contract demands the ENTIRE batch is rejected
    with HTTP 403 (NOT partial acceptance — partial-batch creates ambiguity per
    audit_mobile.py iter-2 docstring). Asserts the security boundary holds when
    the offline buffer replay order is broken (e.g., session_start lost to
    SQLite-full per B17 + iter-2_revision Task 5).
    """
    base_time = datetime.now(timezone.utc) - timedelta(days=1)
    good_sid = str(uuid4())  # has a prior session_start
    bad_sid = str(uuid4())   # NO prior session_start — handshake will fail

    # Commit ONE valid session_start row
    test_client.post(
        "/v1/audit/mobile-session-start",
        json={
            "anonymous_session_id": good_sid,
            "app_version": "2.3.0+iter3-test",
            "observed_at": base_time.isoformat(),
            "constants_version_hash": "ph01-d16-codegen-baseline-hash",
            "source": "mobile_session_start",
        },
    )

    # Batch contains warm_resume rows for BOTH sids — bad_sid has no proof
    batch = [
        {
            "anonymous_session_id": good_sid,
            "app_version": "2.3.0+iter3-test",
            "observed_at": (base_time + timedelta(hours=1)).isoformat(),
            "constants_version_hash": "ph01-d16-codegen-baseline-hash",
            "source": "mobile_session_warm_resume",
        },
        {
            "anonymous_session_id": bad_sid,
            "app_version": "2.3.0+iter3-test",
            "observed_at": (base_time + timedelta(hours=2)).isoformat(),
            "constants_version_hash": "ph01-d16-codegen-baseline-hash",
            "source": "mobile_session_warm_resume",
        },
    ]
    resp = test_client.post(
        "/v1/audit/mobile-session-link",
        json={"items": batch},
        headers=authenticated_user.auth_headers,
    )
    assert resp.status_code == 403, (
        f"expected 403 handshake-missing for batch containing bad_sid, "
        f"got {resp.status_code} {resp.text}"
    )
    body = resp.json()
    assert body["detail"]["error"] == "session_link_handshake_missing"
    assert bad_sid in body["detail"]["missing_sids"]
    # Good sid is NOT in missing_sids (it had its proof), but the WHOLE batch is rejected
    assert good_sid not in body["detail"]["missing_sids"]
```

#### `<acceptance_criteria>` for Task 3 — append (iter-3 iA2)

- `cd services/backend && python3 -m pytest tests/integration/test_audit_mobile_link_handshake_replay_ordering.py -q -k pg` exits 0 (both tests pass).
- `test_interleaved_session_start_warm_resume_login_batch_accepts_all` confirms 10-event interleaved replay returns 200 with `linked=5, skipped=5`.
- `test_link_batch_with_missing_session_start_rejects_entire_batch` confirms one missing session_start in a 2-row batch rejects the WHOLE batch with HTTP 403 + `missing_sids` listing the bad sid only.

### iA3 — Secret handoff hygiene (Railway CLI one-liner)

**Source:** REVIEWS.md §7.3 HIGH-A3. **Applied in-place** above in Task 1 `<what-built>` + `<how-to-verify>` + `<resume-signal>` blocks (lines 339-373 of this PLAN). No iter_3_revision append needed — the change is surgical to the checkpoint procedure, not additive. See line markers `iter-3 HIGH-A3 (Claude-Opus post-iter-2 review)` in Task 1 for the exact diff.

### Effort spent vs scope budget

| Patch | Budget | Actual | Status |
|---|---|---|---|
| iA1 | 30 min | 30 min | APPLIED in iter_3_revision append + Plan 02-01 step 7 ADDENDUM (single source of truth = this block; executor reads at exec time) |
| iA2 | 1.5 h | 1.0 h | APPLIED in iter_3_revision append (test spec verbatim) |
| iA3 | 15 min | 15 min | APPLIED in-place to Task 1 (lines 339-373) |
| Total Plan 02-02 | 2.25 h | 1.75 h | well under 3h hard cap |

iA4 lands in Plan 02-04 (separate edit, no overlap with this plan).

### Iter-3 commit recommendation

Single commit message (covers all 4 iA patches across plans + new doc):
`docs(mint-data-architecture-v1-02-event-log-projection): plan revision iter-3 — iA1 projector SQLite-path divergence trap + iA2 audit-link handshake replay ordering integration test + iA3 Railway CLI pepper one-liner + iA4 session-start audit-pollution Phase-04 hardening stub`

</iter_3_revision>

