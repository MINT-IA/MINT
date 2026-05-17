"""T002 — at-rest encryption defence-in-depth contract (Phase 97 W7 iter#10).

GDPR Art. 32 « security of processing » + Swiss DSG/LPD Art. 8.

Backend at-rest encryption is provided by THREE layers :

    1. INFRA layer — Railway PostgreSQL ; encryption-at-rest is
       provided by Railway's managed infrastructure (AWS RDS / Render
       block-storage AES-256, depending on region). The app does NOT
       encrypt the bytes that hit Postgres — Railway does, at the disk
       level.

    2. STARTUP-CHECK layer — `app/core/config.py` REFUSES to boot if
       `DATABASE_URL` starts with `sqlite://` while `ENVIRONMENT` is
       `production` or `staging`. Fail-closed prevents an accidental
       deploy where the infra-encryption layer would be bypassed by
       an ephemeral SQLite file living next to the container.

    3. APPLICATION layer — `app/services/encryption/envelope.py` provides
       AES-256-GCM per-user envelope encryption for PII columns
       (used today by `document_memory_service` for raw vision payloads
       and evidence text — PRIV-04, v2.7 Phase 29). A future plan can
       extend the application-layer encryption to `DocumentModel.extracted_fields`
       and `DocumentModel.warnings` ; this test guards the encryption
       module's existence so that path stays open.

This test does NOT verify the Railway-provided disk encryption (that's
infra ; outside the code repo). It verifies the in-repo CONTRACTS that
make the at-rest guarantee defensible end-to-end.

See : T002 row in `97-BUGS-REGISTRY.md` ; Phase 97 W7 iter#10 SUMMARY.
"""
from __future__ import annotations

import os
import re
from pathlib import Path

import pytest

# services/backend/tests/test_sqlite_at_rest_encryption.py → parents :
#   parents[0] = services/backend/tests/
#   parents[1] = services/backend/
#   parents[2] = services/
#   parents[3] = repo root
BACKEND_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[3]


# ─── Layer 2 : startup fail-closed check ─────────────────────────────────────


def test_config_rejects_sqlite_in_production(monkeypatch):
    """`Settings` must FAIL CLOSED if DATABASE_URL=sqlite:// in production."""
    # The config module reads `ENVIRONMENT` at IMPORT TIME, so we must
    # reload it under the new env vars.
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("DATABASE_URL", "sqlite:///./should_never_ship.db")
    # Strong JWT secret to clear the prior fail-closed gate so we
    # reach the SQLite check.
    monkeypatch.setenv("JWT_SECRET_KEY", "x" * 64)

    import importlib
    import app.core.config as cfg

    with pytest.raises(RuntimeError) as exc:
        importlib.reload(cfg)

    msg = str(exc.value)
    assert "DATABASE_URL" in msg, (
        "T002 CONTRACT : the fail-closed error must name DATABASE_URL so the "
        f"operator can correct the misconfig. Got : {msg!r}"
    )
    assert "PostgreSQL" in msg or "postgresql" in msg.lower(), (
        "T002 CONTRACT : the fail-closed error must direct the operator to "
        f"PostgreSQL. Got : {msg!r}"
    )


def test_config_rejects_sqlite_in_staging(monkeypatch):
    """Same fail-closed for staging — Railway staging also runs PostgreSQL."""
    monkeypatch.setenv("ENVIRONMENT", "staging")
    monkeypatch.setenv("DATABASE_URL", "sqlite:///./should_never_ship.db")
    monkeypatch.setenv("JWT_SECRET_KEY", "x" * 64)

    import importlib
    import app.core.config as cfg

    with pytest.raises(RuntimeError):
        importlib.reload(cfg)


def test_config_allows_sqlite_in_development(monkeypatch):
    """SQLite is allowed in development — local dev convenience."""
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setenv("DATABASE_URL", "sqlite:///./dev.db")

    import importlib
    import app.core.config as cfg

    # Must NOT raise.
    importlib.reload(cfg)
    assert cfg.settings.DATABASE_URL.startswith("sqlite")


def test_config_allows_postgresql_in_production(monkeypatch):
    """The happy path : Railway PostgreSQL is accepted in production."""
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv(
        "DATABASE_URL", "postgresql://user:pw@host.railway.internal:5432/mint"
    )
    monkeypatch.setenv("JWT_SECRET_KEY", "x" * 64)

    import importlib
    import app.core.config as cfg

    importlib.reload(cfg)
    assert "postgresql" in cfg.settings.DATABASE_URL


# ─── Layer 3 : AES-256-GCM envelope encryption module is present ──────────


def test_envelope_module_uses_aes_gcm_256():
    """`app/services/encryption/envelope.py` must use AES-GCM with a 256-bit key."""
    envelope_path = BACKEND_ROOT / "app" / "services" / "encryption" / "envelope.py"
    assert envelope_path.exists(), (
        "T002 CONTRACT : the application-layer envelope encryption module "
        "must exist at `app/services/encryption/envelope.py`. This module "
        "provides AES-256-GCM per-user envelope encryption for PII columns."
    )

    src = envelope_path.read_text(encoding="utf-8")

    # AES-GCM via `cryptography.hazmat.primitives.ciphers.aead.AESGCM`
    assert (
        "from cryptography.hazmat.primitives.ciphers.aead import AESGCM" in src
    ), (
        "T002 CONTRACT : envelope.py must import AESGCM from `cryptography`."
    )
    assert "AESGCM(dek)" in src, (
        "T002 CONTRACT : envelope.py must instantiate AESGCM(dek) per encrypt call."
    )

    # 12-byte nonce per NIST SP 800-38D for GCM
    assert "NONCE_SIZE_BYTES = 12" in src, (
        "T002 CONTRACT : envelope.py must use a 12-byte (96-bit) nonce — the "
        "NIST SP 800-38D standard for GCM. Smaller nonces increase reuse risk."
    )

    # `secrets.token_bytes` (CSPRNG) for nonce — never `os.urandom` shimmed
    # by a weak PRNG.
    assert "secrets.token_bytes" in src, (
        "T002 CONTRACT : envelope.py must source nonces from "
        "`secrets.token_bytes` (CSPRNG)."
    )


def test_key_vault_uses_per_user_dek():
    """Per-user DEKs : a breach of one user must NOT compromise others."""
    key_vault_path = (
        BACKEND_ROOT / "app" / "services" / "encryption" / "key_vault.py"
    )
    assert key_vault_path.exists(), (
        "T002 CONTRACT : the key-vault module that issues per-user DEKs must "
        "exist at `app/services/encryption/key_vault.py`."
    )

    src = key_vault_path.read_text(encoding="utf-8")
    assert "get_or_create_dek" in src, (
        "T002 CONTRACT : key_vault must expose `get_or_create_dek(db, user_id)`."
    )
    # DEKRevokedError supports crypto-shredding on account deletion
    # (GDPR Art. 17 right-to-erasure : revoke DEK → ciphertext becomes
    # unrecoverable without altering the DB rows).
    assert "DEKRevokedError" in src, (
        "T002 CONTRACT : key_vault must support crypto-shredding via a "
        "DEKRevokedError exception so account deletion renders ciphertext "
        "unrecoverable (GDPR Art. 17 right-to-erasure)."
    )


# ─── Layer 1 + 2 + 3 : documentation file exists and cites the layers ──────


def test_at_rest_encryption_docs_exist_and_cite_layers():
    """The at-rest encryption strategy must be documented in-repo."""
    doc_path = (
        BACKEND_ROOT / "docs" / "security" / "at-rest-encryption.md"
    )
    assert doc_path.exists(), (
        "T002 CONTRACT : the at-rest encryption strategy MUST be documented "
        f"at `{doc_path.relative_to(REPO_ROOT)}` so an auditor can verify "
        "GDPR Art. 32 compliance without reading source code."
    )

    src = doc_path.read_text(encoding="utf-8")
    # Layer 1 : Railway PostgreSQL infra encryption-at-rest
    assert re.search(r"Railway", src, re.IGNORECASE), (
        "T002 CONTRACT : docs must cite Railway as the infra provider for "
        "PostgreSQL encryption-at-rest."
    )
    assert re.search(r"PostgreSQL", src, re.IGNORECASE), (
        "T002 CONTRACT : docs must cite PostgreSQL as the production DB."
    )
    # Layer 2 : fail-closed startup check
    assert re.search(r"fail[ -]closed", src, re.IGNORECASE), (
        "T002 CONTRACT : docs must describe the fail-closed startup check "
        "that rejects sqlite:// in prod/staging."
    )
    # Layer 3 : application-layer envelope
    assert "AES-256-GCM" in src, (
        "T002 CONTRACT : docs must name the application-layer cipher "
        "(AES-256-GCM)."
    )
    # Compliance citations
    assert "GDPR" in src and "Art. 32" in src, (
        "T002 CONTRACT : docs must cite GDPR Art. 32 (security of processing)."
    )
    assert "DSG" in src or "LPD" in src, (
        "T002 CONTRACT : docs must cite Swiss DSG/LPD Art. 8 (security of "
        "personal data)."
    )
    # Mobile layer
    assert re.search(r"SQLCipher", src, re.IGNORECASE), (
        "T002 CONTRACT : docs must cite SQLCipher (mobile at-rest layer)."
    )
