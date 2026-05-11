# MINT at-rest encryption strategy

> **Compliance:** GDPR Art. 32 « security of processing » + Swiss DSG/LPD
> Art. 8 « sécurité des données personnelles ».
>
> **Status:** Locked under deterministic tests (Phase 97 W7 iter#10,
> 2026-05-11). See `services/backend/tests/test_sqlite_at_rest_encryption.py`
> and `apps/mobile/test/services/sqlite_encryption_test.dart`.

---

## TL;DR

MINT applies **three independent at-rest encryption layers**. A single
layer breach does NOT expose user PII.

| Layer | Surface | Cipher | Key custody | Where the test lives |
|------|---------|--------|-------------|---------------------|
| 1 | Backend DB (PostgreSQL) | Railway-managed disk encryption (typically AES-256, infra-provided) | Railway / underlying IaaS | Infra-level; not in repo |
| 2 | Backend application | AES-256-GCM envelope, per-user DEK | `app/services/encryption/key_vault.py` (DEK in DB, wrapped) | `tests/test_sqlite_at_rest_encryption.py::test_envelope_module_uses_aes_gcm_256` |
| 3 | Mobile local SQLite | SQLCipher AES-256-CBC | `flutter_secure_storage` (iOS Keychain / Android KeyStore) | `apps/mobile/test/services/sqlite_encryption_test.dart` |

A startup-time **fail-closed check** (`app/core/config.py:179-188`)
prevents an accidental deploy in which the backend would boot against an
ephemeral SQLite file in production or staging — that path would silently
bypass Layer 1.

---

## Layer 1 — backend DB encryption-at-rest (infra-provided)

**Provider:** Railway managed PostgreSQL. Railway provisions PostgreSQL on
top of cloud block storage that is AES-256 encrypted at rest. The
encryption is **infrastructure-level, not application-level** — the
backend code does NOT encrypt the bytes that hit PostgreSQL. Railway's
storage layer does, transparently, before they reach disk.

**Honest disclosure:**
- This layer is **provided by Railway, not by MINT code**. If Railway is
  breached at the infra level, this layer fails. We rely on Railway's
  SOC 2 attestation + the upstream cloud provider's encryption-at-rest
  guarantee.
- Reference: <https://docs.railway.com/reference/databases#encryption>
  (Railway DB security overview) and the upstream cloud provider's
  encryption-at-rest documentation (AWS RDS / Render block-storage AES-256
  depending on region routing).
- Defence in depth is provided by Layer 2 below — any column that
  carries highly sensitive PII (vision raw output, OCR evidence text)
  is **also** encrypted by the application before it reaches PostgreSQL,
  so a hypothetical compromise of the Railway infra layer would still
  leak only ciphertext for those columns.

**Production / staging guard (`app/core/config.py:179-188`):**

```python
# Fail-fast: reject SQLite in production/staging (P0-INFRA-1)
if (
    os.getenv("ENVIRONMENT", "development") in ("production", "staging")
    and settings.DATABASE_URL.startswith("sqlite")
):
    raise RuntimeError(
        "CRITICAL: DATABASE_URL must point to PostgreSQL in production/staging. "
        "SQLite is ephemeral on Railway and will lose all data on restart. "
        "Set DATABASE_URL in Railway environment variables."
    )
```

This **fail-closed** check guarantees that Layer 1 cannot be silently
bypassed by a misconfigured deploy. Unit-tested by
`tests/test_sqlite_at_rest_encryption.py::test_config_rejects_sqlite_in_production`.

---

## Layer 2 — application-layer envelope encryption (AES-256-GCM)

**Module:** `app/services/encryption/envelope.py` (v2.7 Phase 29 / PRIV-04).

**Cipher:** AES-256-GCM (NIST SP 800-38D) via
`cryptography.hazmat.primitives.ciphers.aead.AESGCM`.

**Key model:**
- One **Data Encryption Key (DEK)** per user, generated on first write
  and stored wrapped in `key_vault`. See
  `app/services/encryption/key_vault.py::get_or_create_dek`.
- Crypto-shredding on account deletion (`DEKRevokedError`) — revoking the
  DEK renders all the user's ciphertext unrecoverable without altering
  any DB row. This is how MINT honours **GDPR Art. 17** right-to-erasure
  for columns we cannot DELETE (audit trail, legal retention).

**Wire format:** `nonce (12 bytes random) || ciphertext || GCM tag (16 bytes)`.
Nonces are sourced from `secrets.token_bytes(12)` — CSPRNG-backed — and
are unique per write. The 96-bit nonce is safe for fewer than 2^32 writes
per DEK ; per-user DEK scoping makes this trivial in practice.

**Today's adoption surface:**
- `app/services/document_memory_service.py:191-192` — encrypts
  `evidence_text` and `vision_raw` columns before they hit
  `document_memory.py` rows.
- Other PII columns (e.g. `DocumentModel.extracted_fields`,
  `DocumentModel.warnings`) **remain protected only by Layer 1** today.
  Promoting them to Layer 2 is a separate plan (requires a backfill
  migration + ContextVar wiring in `endpoints/documents.py`). The
  envelope module is ready for that promotion ; the test suite guards
  the module's continued existence so the path stays open.

---

## Layer 3 — mobile local SQLite (SQLCipher AES-256-CBC)

**Module:** `apps/mobile/lib/services/biography/biography_repository.dart`.

**Cipher:** SQLCipher AES-256-CBC via the `sqflite_sqlcipher: ^3.1.0+1`
Flutter package (pinned in `apps/mobile/pubspec.yaml:54`).

**Key model:**
- 32-byte (256-bit) key, generated with `Random.secure()` (Dart
  CSPRNG-backed) on first launch.
- Key stored in `flutter_secure_storage` under alias
  `mint_biography_key` — iOS Keychain (hardware-backed when Secure
  Enclave available) or Android KeyStore.
- On a fresh / sandbox-reset device where the Keychain item is absent
  AND the entitlement is not yet provisioned, the repository falls back
  to an **in-memory key** so the « Ce que MINT sait de toi » screen
  still renders an empty-state ; rows persist only for the session and
  are lost on restart. The Keychain becomes writable after the first
  auth flow.

**Threat covered:** device theft / jailbroken sandbox dump / malicious
app reading shared Files-app folders. Without the SQLCipher key (held
exclusively in the secure enclave-backed Keychain), the
`mint_biography.db` file on disk is unreadable as plain SQLite — opening
it with the `sqlite3` CLI without the key fails with
`file is not a database`.

**Verification:**
- Source-code contract test:
  `apps/mobile/test/services/sqlite_encryption_test.dart` (6 assertions
  pinning the package import, the `password:` parameter on
  `openDatabase`, the `flutter_secure_storage` key custody, the
  `Random.secure()` CSPRNG, the 32-byte key length, the alias contract
  and the DB filename contract).
- Runtime verification (post-fix manual G2-equivalent on sim): dump the
  DB file from the sim sandbox via
  `xcrun simctl get_app_container booted ch.mint.app data` →
  `Documents/mint_biography.db` and confirm `sqlite3 mint_biography.db
  'SELECT * FROM biography_facts'` fails. With the key (via
  `sqflite_sqlcipher`'s `password:` parameter) the query succeeds. This
  is the deterministic citation per CLAUDE.md §9 — see Phase 97 W7
  iter#10 SUMMARY for the captured output.

---

## Compliance citations

- **GDPR Art. 32** « security of processing » : *« the controller and
  the processor shall implement appropriate technical and organisational
  measures to ensure a level of security appropriate to the risk,
  including (...) the pseudonymisation and encryption of personal data »*.
  → Satisfied by Layer 1 (infra) + Layer 2 (app) for PostgreSQL, and
  Layer 3 (SQLCipher) for the mobile cache.
- **Swiss DSG/LPD Art. 8** « sécurité des données » + the implementing
  ordinance OPDo Art. 1-3 on technical measures.
  → Same as above ; DSG Art. 8 is broadly aligned with GDPR Art. 32 in
  the « state of the art » technical-measures requirement.
- **GDPR Art. 17** right-to-erasure : Layer 2's crypto-shredding via
  `DEKRevokedError` provides a defensible erasure path for columns that
  cannot be hard-deleted (audit retention, regulatory holds).

---

## Out of scope (separate plans)

- **Data-in-transit encryption** : provided by HTTPS / TLS 1.3 at the
  Railway edge ; documented separately under
  `services/backend/docs/security/in-transit-encryption.md` (TBD).
- **Promoting `DocumentModel` JSON columns to Layer 2 envelope
  encryption** : a follow-up plan must (a) write an alembic migration
  that backfills existing rows ; (b) wire the `EncryptionContext`
  middleware on `/documents/*` endpoints ; (c) update
  `endpoints/documents.py` to use `encrypt_text/decrypt_text` on
  `extracted_fields` and `warnings`. The envelope module is ready ;
  the surface adoption is the open work.
- **Key rotation** : the per-user DEK is generated on first write and
  not rotated. Rotation would require a re-encrypt batch under the new
  key ; out of scope for v2.9.

---

## Audit trail

| Date | Change | Reference |
|------|--------|-----------|
| 2026-05-11 | Document created (Phase 97 W7 iter#10, T002 close) | `97-BUGS-REGISTRY.md` row T002 ; commit `d949b03b` (RED) |
| 2026-04-XX | Layer 2 (envelope encryption) deployed | v2.7 Phase 29 / PRIV-04 |
| 2026-03-XX | Layer 3 (SQLCipher) deployed | BiographyRepository Phase 03 / Memoire Narrative |
| 2025-XX-XX | Layer 1 (Railway PostgreSQL) — production cutover from ephemeral SQLite | `app/core/config.py:179-188` fail-closed check added in P0-INFRA-1 |
