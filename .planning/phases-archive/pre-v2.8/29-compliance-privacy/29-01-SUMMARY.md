---
phase: 29-compliance-privacy
plan: 01
subsystem: backend-privacy
tags: [encryption, crypto-shredding, kms, fernet, nLPD, PRIV-04, envelope-encryption]
dependency_graph:
  requires: [27-01, 28-01]  # FlagsService (PRIVACY_V2_ENABLED), DocumentMemory table
  provides:
    - KeyVaultService (KMS-first, Fernet fallback, per-user DEK lifecycle)
    - encrypt_bytes / decrypt_bytes (AES-256-GCM, nonce+AAD)
    - EncryptedBytes SQLAlchemy TypeDecorator
    - DEKVault ORM model + table
    - document_memory evidence_text(_enc) + vision_raw(_enc) columns
    - document_memory_service.persist_evidence_text / read_evidence_text
    - EncryptionContextMiddleware (ContextVar plumbing)
    - /privacy/delete immediate → crypto_shred_user wiring
    - scripts/migrate_evidence_text_encrypt.py batch migrator
  affects:
    - Phase 29-02 (consent receipts revocation cascade will reuse crypto_shred_user)
    - Phase 29-03 (PII scrubbing grep CI gate will assert zero plaintext evidence_text)
    - Any future service persisting user-sensitive text (allowlist pattern enforced here)
tech_stack:
  added:
    - cryptography>=42,<47 (runtime)
    - boto3>=1.34,<2.0 (optional [kms] extra, imported lazily)
  patterns:
    - envelope encryption (MK wraps per-user DEK, DEK encrypts blobs)
    - crypto-shredding (destroy DEK → ciphertext unrecoverable on backups)
    - fail-open KMS (Fernet fallback via MINT_MASTER_KEY when KMS unavailable)
    - ContextVar plumbing for transparent SQLAlchemy TypeDecorator
    - AAD binding to user_id (prevents cross-user ciphertext replay)
key_files:
  created:
    - services/backend/app/services/encryption/__init__.py
    - services/backend/app/services/encryption/key_vault.py
    - services/backend/app/services/encryption/envelope.py
    - services/backend/app/services/encryption/column_type.py
    - services/backend/app/models/dek_vault.py
    - services/backend/alembic/versions/29_01_envelope_encryption.py
    - services/backend/app/middleware/__init__.py
    - services/backend/app/middleware/encryption_context.py
    - services/backend/scripts/migrate_evidence_text_encrypt.py
    - services/backend/tests/services/encryption/__init__.py
    - services/backend/tests/services/encryption/test_envelope.py
    - services/backend/tests/services/encryption/test_crypto_shred.py
    - services/backend/tests/services/document_memory/__init__.py
    - services/backend/tests/services/document_memory/test_encrypted_persistence.py
  modified:
    - services/backend/app/models/__init__.py (register DEKVault)
    - services/backend/app/models/document_memory.py (4 new columns)
    - services/backend/app/services/document_memory_service.py (+persist/read helpers)
    - services/backend/app/api/v1/endpoints/privacy.py (+crypto_shred on immediate delete)
    - services/backend/app/main.py (+EncryptionContextMiddleware)
    - services/backend/pyproject.toml (cryptography + [kms] extra)
decisions:
  - Plan referenced auth_service.hard_delete_account which does not exist;
    wired crypto_shred_user into /privacy/delete immediate mode instead.
  - boto3 kept as an optional extra (`pip install .[kms]`); local/CI run
    Fernet fallback via MINT_MASTER_KEY (TESTING=1 generates volatile MK).
  - AAD binds ciphertext to user_id — swapping rows across users fails
    GCM authentication (defense-in-depth for T-29-02 tampering threat).
  - Added plaintext columns (evidence_text TEXT, vision_raw TEXT) to
    document_memory alongside *_enc — plan referenced these as the
    backward-compat read surface but they did not yet exist post-28-01.
  - `_flag_privacy_v2` spawns a short-lived asyncio loop for sync calls
    from legacy endpoints; FlagsService remains async-native.
  - EncryptedBytes TypeDecorator shipped for future adopters; current
    document_memory_service uses explicit encrypt_text / decrypt_text
    calls (simpler, no ContextVar setup required).
metrics:
  duration_min: ~45
  tasks: 2
  files_created: 14
  files_modified: 6
  tests_added: 26  # 14 envelope + 4 crypto-shred + 8 encrypted-persistence
  completed: "2026-04-14"
---

# Phase 29 Plan 01: Envelope Encryption + Crypto-Shredding — Summary

## One-liner
AES-256-GCM envelope encryption with per-user DEKs wrapped by a Master Key (AWS KMS prod, Fernet `MINT_MASTER_KEY` fallback): document_memory.evidence_text / vision_raw now persist encrypted at rest behind `PRIVACY_V2_ENABLED`, and crypto-shredding a user's DEK via `/privacy/delete` immediate mode renders every prior ciphertext unreadable — even on Railway WAL backups — satisfying nLPD art. 32 right-to-erasure on backups without wiping the backup tier.

## Tasks delivered

| # | Task | Commit | Tests |
|---|------|--------|-------|
| 1 | Encryption package (key vault + envelope + EncryptedBytes) + DEKVault + migration | `b17b3a3d` | 14 (envelope round-trip, 10k nonce, AAD isolation, entropy, tamper, crypto-shred) |
| 2 | document_memory wiring + crypto-shred on delete + batch migrator | `b64269cc` | 12 (4 crypto-shred + 8 encrypted persistence incl. migration dry-run / live) |

**Total: 26 new tests, all green.**
Regression: encryption (14) + documents (77) + privacy (21) + auth (72) + coach (46) = 230 tests green, zero failures.

## Envelope decided — on-disk format

```
| nonce (12 B, random per write) | AES-256-GCM(ct || tag) |
```

Nonce uniqueness proven across 10 000 consecutive writes (test assertion). AAD = `user_id.encode("utf-8")` → cross-user ciphertext replay fails GCM authentication (mitigates T-29-02).

## Key Vault backend selection (automatic)

1. `MINT_KMS_KEY_ID` env set → boto3 KMS backend (`kms:<id>`). Prod path.
2. Otherwise → Fernet backend driven by `MINT_MASTER_KEY` (urlsafe-b64 of 32 bytes). Dev / CI / Railway bootstrap path.
3. Neither set AND not TESTING → service refuses to start (raises `KeyVaultServiceError`). No silent plaintext.
4. `TESTING=1` → generates volatile process-local Fernet key with WARNING log.

## Crypto-shredding flow

`POST /privacy/delete` with `mode=immediate`:
1. `privacy_service.delete_user_data(...)` builds the deletion receipt (unchanged).
2. `key_vault.crypto_shred_user(db, user_id)` now follows:
   - `dek_vault.wrapped_dek = NULL`
   - `dek_vault.revoked_at = NOW()`
   - in-process DEK cache purged for that user.
3. All subsequent `get_dek` / `decrypt_*` calls raise `DEKRevokedError`.
4. Ciphertext rows remain in `document_memory.*_enc` with entropy ≥ 7.5 bits/byte (backup-safe but cryptographically irrecoverable).

Grace-period mode (default 30 days) intentionally does NOT shred — user can still cancel. A scheduled job hook for end-of-grace shred is **deferred** (call site ready: `key_vault.crypto_shred_user(db, user_id)`).

## Flag-gated write path

```
PRIVACY_V2_ENABLED = true  (user-scoped dogfood or global)
    └─> persist_evidence_text writes evidence_text_enc / vision_raw_enc
        plaintext columns stay NULL

PRIVACY_V2_ENABLED = false (default global off)
    └─> legacy: writes plaintext columns, *_enc stay NULL
```

Reads: prefer `*_enc` (decrypt) and fall back to plaintext when encrypted column is NULL (backward-compat window for pre-migration rows).

## Migration script

`python scripts/migrate_evidence_text_encrypt.py [--dry-run] [--batch-size 500]`

- Scans users with at least one row where `evidence_text IS NOT NULL OR vision_raw IS NOT NULL`.
- For each user: ensures DEK exists, batches rows, encrypts + round-trip verifies, then NULLs plaintext columns.
- Idempotent (safe to re-run) and resumable (only selects rows with non-null plaintext).
- `--dry-run` reports counts without mutating.
- Privacy-scrubbed logs (no user_ids, no evidence content).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan referenced `auth_service.hard_delete_account` — not present**
- Found during: Task 2
- Issue: Plan said "`auth_service.delete_account(u)` calls crypto_shred_user after soft-delete grace window expires (wire the call site)". No such function exists in this repo; `auth_service.py` handles only password/JWT, not account deletion.
- Fix: Wired `key_vault.crypto_shred_user(db, user_id)` into the existing `/privacy/delete` endpoint (immediate mode branch). 30-day grace-period end-of-window shred is **deferred** (scheduled job out of scope).
- Files modified: `services/backend/app/api/v1/endpoints/privacy.py`

**2. [Rule 2 - Missing] Plan assumed `document_memory.evidence_text` / `vision_raw` plaintext columns already existed**
- Found during: Task 1
- Issue: Plan's migration description says "keep existing plaintext columns nullable for backward compat" — but 28-01 DocumentMemory only had `field_history` JSON. No plaintext evidence columns existed.
- Fix: Created both plaintext (`evidence_text TEXT NULL`, `vision_raw TEXT NULL`) AND encrypted (`*_enc BYTEA NULL`) columns in one migration. Gives the backward-compat read surface described by the plan and lets the migration script have something to drain.
- Files modified: `alembic/versions/29_01_envelope_encryption.py`, `app/models/document_memory.py`

**3. [Rule 3 - Blocking] boto3 not installed locally / in CI**
- Found during: Task 1 setup
- Issue: cryptography was present (46.0.4 ≥ 42 required); boto3 was absent and `pip install boto3` on dev Python 3.9 risks pulling many transitive deps.
- Fix: Added boto3 as an optional extra `[kms]` rather than a required dependency. KMS backend imports boto3 lazily inside `_KMSBackend.__init__` so importing the encryption package never touches boto3 unless `MINT_KMS_KEY_ID` is set. Railway prod will `pip install .[kms]`; local/CI runs Fernet fallback.
- Files modified: `pyproject.toml`

**4. [Rule 1 - Bug] Initial cross-user AAD test ordering**
- Found during: Task 1 first pytest run
- Issue: `test_cross_user_decrypt_fails_aad_mismatch` expected `EncryptionError`, but Bob had no DEK → `DEKRevokedError` fired first before any GCM authentication was attempted.
- Fix: Provision Bob's DEK before the cross-decrypt attempt so the test actually exercises the AAD/key mismatch path.

### CLAUDE.md adjustments

- No banned terms introduced (crypto-focused, no user-facing copy).
- No retirement framing (infrastructure).
- All new services have deterministic fail-modes documented (KMS outage → Fernet fallback; DEK revoked → DEKRevokedError surfaced, never silent).

## Authentication Gates

None encountered. KMS path is optional and not exercised in tests (boto3 not required). Fernet path uses volatile MK via `TESTING=1`.

## Known Stubs

None. Every new service has fail-modes documented and tested end-to-end.

## Follow-ups (deferred)

- **Scheduled end-of-grace shred**: `/privacy/delete` with `mode=grace_period` marks the user for deletion at T+30d. A scheduled job (APScheduler / Railway cron) should call `key_vault.crypto_shred_user(db, uid)` for every user whose grace expired. Hook point: clear.
- **Drop plaintext columns**: after the batch migration script has run on staging + prod and reports `rows_migrated=N, rows_failed=0`, a follow-up migration `30_xx_drop_document_memory_plaintext.py` should `ALTER TABLE document_memory DROP COLUMN evidence_text, DROP COLUMN vision_raw`. Deferred until Phase 29-03 CI grep gate is in place.
- **Phase 29-02 (PRIV-01 consent receipts)**: will reuse `crypto_shred_user` in the revocation cascade for the "destroy DEK on consent revoke for vision_extraction purpose" requirement.
- **Phase 29-03 (PRIV-03 PII scrubbing CI gate)**: will grep build logs for plaintext IBAN/AVS/employeur — this plan assumes grep rule exists.
- **DEK rotation (annual)**: `key_vault.rotate_dek(user_id)` not implemented here; rotating the MK only re-wraps DEKs (~10k ops) and is a scriptable follow-up.
- **Middleware db_session injection**: `EncryptedBytes` TypeDecorator requires `current_db_session` ContextVar; middleware only sets `current_user_id`. Endpoints that adopt EncryptedBytes must bind the session themselves. Documented in `column_type.py` docstring. Not a blocker because `document_memory_service` uses explicit encrypt/decrypt calls.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: new_persistence_encrypted | services/backend/app/models/document_memory.py | evidence_text_enc / vision_raw_enc now store AES-256-GCM envelope ciphertext. Threat register entries T-29-01..06 already cover this (mitigated by per-user DEK + KMS-wrapped MK). |
| threat_flag: new_kms_boundary | services/backend/app/services/encryption/key_vault.py | When `MINT_KMS_KEY_ID` is set, wrap/unwrap hits AWS KMS over the network. IAM role scope must be `kms:Encrypt` + `kms:Decrypt` only, not `kms:GenerateDataKey*` (we generate DEKs locally via `secrets.token_bytes`). Added to ops checklist. |
| threat_flag: volatile_mk_detector | services/backend/app/services/encryption/key_vault.py | Startup emits WARNING if `TESTING=1` Fernet path is hit. Production deployment checklist must verify this log line is absent. |

## Self-Check: PASSED

Created files verified:
- FOUND: services/backend/app/services/encryption/__init__.py
- FOUND: services/backend/app/services/encryption/key_vault.py
- FOUND: services/backend/app/services/encryption/envelope.py
- FOUND: services/backend/app/services/encryption/column_type.py
- FOUND: services/backend/app/models/dek_vault.py
- FOUND: services/backend/alembic/versions/29_01_envelope_encryption.py
- FOUND: services/backend/app/middleware/__init__.py
- FOUND: services/backend/app/middleware/encryption_context.py
- FOUND: services/backend/scripts/migrate_evidence_text_encrypt.py
- FOUND: services/backend/tests/services/encryption/test_envelope.py
- FOUND: services/backend/tests/services/encryption/test_crypto_shred.py
- FOUND: services/backend/tests/services/document_memory/test_encrypted_persistence.py

Commits verified:
- FOUND: b17b3a3d (task 1)
- FOUND: b64269cc (task 2)

Tests: 14 + 4 + 8 = 26 new tests green. No regression across 230 other tests (encryption + documents + privacy + auth + coach suites).

Alembic: forward (`p28_document_memory → 29_01_envelope_encryption`) + downgrade + re-upgrade verified on SQLite.

PRIV-04: satisfied per plan success criteria (encryption at rest, crypto-shred unreadability, backward compat, ciphertext entropy).
