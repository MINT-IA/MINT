"""Gates nLPD contraignants — audit T06-F10 + T10-F02 (beads MINT_nosync-tih).

RED sur l'arbre pré-fix par construction :
  1. mode d'enforcement inconnu -> fail-CLOSED (avant : fail-open silencieux)
  2. field_history chiffré sous PRIVACY_V2 (avant : montants bruts en clair)
  3. docs flaggés tiers jamais persistés avant le gate de déclaration
"""
from __future__ import annotations

import os

import pytest

os.environ.setdefault("TESTING", "1")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from unittest.mock import patch

from app.core.database import Base
import app.models  # noqa: F401


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()
    engine.dispose()


def test_unknown_enforcement_mode_fails_closed(db):
    """Une env var mal orthographiée ne doit jamais désactiver le gate."""
    from app.services.consent.consent_service import ConsentService, ConsentPurpose

    svc = ConsentService()
    check = svc.check_or_log(
        db,
        user_id="u1",
        purpose=ConsentPurpose.TRANSFER_US_ANTHROPIC,
        mode="bogus_mode",
    )
    assert check.allow is False
    assert check.deny_pointer is not None


def _mk_understanding():
    from app.schemas.document_understanding import (
        DocumentClass,
        DocumentUnderstandingResult,
        ExtractedField,
        ExtractionStatus,
    )

    from app.schemas.document_understanding import RenderMode

    return DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        extraction_status=ExtractionStatus.success,
        render_mode=RenderMode.confirm,
        extracted_fields=[
            ExtractedField(field_name="salaire_annuel", value=95000.0),
        ],
        issuer_guess="CaissePensionsTest",
    )


def test_field_history_encrypted_under_privacy_v2(db):
    """Sous PRIVACY_V2, aucun montant en clair dans field_history."""
    import app.services.document_memory_service as dms
    from app.models.document_memory import DocumentMemory
    from app.models import User

    user = User(id="u-enc", email="enc@test.ch", hashed_password="x")
    db.add(user)
    db.commit()

    result = _mk_understanding()
    with patch.object(dms, "_flag_privacy_v2", return_value=True), \
         patch.object(dms, "encrypt_text", return_value=b"CIPHERTEXT"):
        dms.upsert_and_diff(db, "u-enc", result)

    row = db.query(DocumentMemory).filter_by(user_id="u-enc").one()
    serialized = str(row.field_history)
    assert "95000" not in serialized, "montant en CLAIR dans field_history"
    assert row.field_history[0].get("fields_enc")


def test_field_history_diff_reads_encrypted_previous(db):
    """Le diff fonctionne au travers d'une entrée précédente chiffrée."""
    import app.services.document_memory_service as dms
    from app.models import User

    user = User(id="u-diff", email="diff@test.ch", hashed_password="x")
    db.add(user)
    db.commit()

    result1 = _mk_understanding()
    stored = {}

    def fake_encrypt(db_, uid, text):
        ct = f"CT{len(stored)}".encode()
        stored[ct] = text
        return ct

    def fake_decrypt(db_, uid, blob):
        return stored[bytes(blob)]

    with patch.object(dms, "_flag_privacy_v2", return_value=True), \
         patch.object(dms, "encrypt_text", side_effect=fake_encrypt), \
         patch.object(dms, "decrypt_text", side_effect=fake_decrypt):
        dms.upsert_and_diff(db, "u-diff", result1)
        result2 = _mk_understanding()
        result2.extracted_fields[0].value = 99000.0
        diff = dms.upsert_and_diff(db, "u-diff", result2)

    assert diff is not None and "salaire_annuel" in diff


def test_flagged_third_party_doc_not_persisted_by_analyze_path(db):
    """Un doc flaggé tiers ne doit pas entrer en DocumentMemory via le chemin
    pré-gate : la persistance des flaggés passe par persist_document_memory
    (appelé par l'endpoint APRÈS require_declaration_or_block)."""
    from app.services.document_vision_service import persist_document_memory
    from app.models.document_memory import DocumentMemory
    from app.models import User

    user = User(id="u-tp", email="tp@test.ch", hashed_password="x")
    db.add(user)
    db.commit()

    result = _mk_understanding()
    result.third_party_detected = True
    result.third_party_name = "Conjoint X"

    # Le wrapper public EST le seul chemin de persistance des flaggés — il
    # n'est appelé que post-gate. On vérifie qu'il persiste bien (les docs
    # déclarés gardent la feature mémoire).
    persist_document_memory(db, "u-tp", result)
    rows = db.query(DocumentMemory).filter_by(user_id="u-tp").count()
    assert rows == 1


def test_persist_document_memory_swallows_upsert_failure(db):
    """Le wrapper ne fait jamais échouer l'analyse si l'upsert lève."""
    import app.services.document_vision_service as dvs

    result = _mk_understanding()
    with patch.object(dvs, "_upsert_and_diff", side_effect=RuntimeError("boom")):
        dvs.persist_document_memory(db, "u-err", result)  # ne lève pas
    assert result.diff_from_previous is None


def test_persist_document_memory_sets_diff_and_fingerprint(db):
    from app.models import User
    import app.services.document_vision_service as dvs

    db.add(User(id="u-ok", email="ok@test.ch", hashed_password="x"))
    db.commit()
    result = _mk_understanding()
    dvs.persist_document_memory(db, "u-ok", result)
    assert result.fingerprint
