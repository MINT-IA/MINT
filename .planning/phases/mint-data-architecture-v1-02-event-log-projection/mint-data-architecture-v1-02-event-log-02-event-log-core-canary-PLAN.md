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
    Claude has prepared the Railway env-var procedure documentation (drafted in `docs/operations/audit-pepper-rotation.md` shipped by Plan 02-04, but the live `MINT_AUDIT_HASH_PEPPER` setting MUST exist on Railway before Plan 02-02 Task 2 runs the migrations). Claude has generated the pepper value locally via `python3 -c "import secrets; print(secrets.token_urlsafe(48))"` (≥ 32 chars guaranteed) and is ready to instruct Julien on the exact Railway dashboard steps. Claude CANNOT set Railway env vars autonomously without Railway CLI auth that may have rotated; opt-out to Julien-confirm for this one-time operational gate.
  </what-built>
  <how-to-verify>
    1. **Generate pepper locally** (Claude does this):
       ```bash
       python3 -c "import secrets; print(secrets.token_urlsafe(48))"
       ```
       Capture the output (a 48-byte URL-safe random string, ~64 chars). Save it to a temp file `/tmp/mint_audit_pepper_for_julien.txt` (NOT committed).
    2. **Set on Railway production** (Julien does this):
       - Open Railway dashboard → MINT backend service → Variables tab.
       - Add new variable: name `MINT_AUDIT_HASH_PEPPER`, value = the generated string from step 1.
       - Confirm save.
    3. **Set on Railway staging** (Julien does this):
       - Same as step 2 on the staging service. Use a DIFFERENT pepper value (staging and prod MUST have distinct peppers per security best practice — a leak of one does not compromise the other).
    4. **Verify via Railway CLI** (Julien runs):
       ```bash
       railway variables get MINT_AUDIT_HASH_PEPPER --environment production
       railway variables get MINT_AUDIT_HASH_PEPPER --environment staging
       ```
       Both must return a string ≥ 32 chars. Do NOT paste the output back to Claude (secret hygiene).
    5. **Confirm `MINT_KMS_KEY_ID` exists** (Julien runs):
       ```bash
       railway variables get MINT_KMS_KEY_ID --environment production
       ```
       Expected: returns `mint-master-v1` (per D-02). If missing, Julien adds it with value `mint-master-v1`.
    6. **Verify pepper file deleted**:
       ```bash
       rm /tmp/mint_audit_pepper_for_julien.txt && [ ! -f /tmp/mint_audit_pepper_for_julien.txt ] && echo "OK"
       ```
    7. **D-02 rotation rehearsal** (Julien does this — non-production): in Railway staging, ROTATE `MINT_AUDIT_HASH_PEPPER` (set new value, then immediately revert to original). This rehearsal proves the procedure works for the future rotation that Plan 02-04 documents. Capture the timestamps of both operations. The rehearsal does NOT need a backfill (the audit table has zero rows in staging pre-launch).
  </how-to-verify>
  <resume-signal>
    Type "approved — pepper set on prod + staging, KMS_KEY_ID=mint-master-v1 confirmed, rehearsal procedure works" OR describe issues for Claude to address (e.g., Railway dashboard UI changed, CLI not authenticated).
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
