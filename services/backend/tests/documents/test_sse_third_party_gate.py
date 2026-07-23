"""Gate déclaration tiers sur le chemin SSE + bridge PRIVACY_V2 async.

beads MINT_nosync-cbk (résiduels review Codex PR #959 / -tih) :
(1) le flux SSE n'appelait PAS require_declaration_or_block — les docs
    tiers déclarés perdaient la mémoire/diff (et avant #959 les non-déclarés
    étaient persistés SANS gate) ;
(2) _flag_privacy_v2 soumettait la coroutine du flag à SA PROPRE boucle et
    bloquait -> timeout 1 s -> False -> écritures PLAINTEXT sur tout chemin
    async, même flag activé (probe Codex : mock True -> False en 1.008 s).
    Fix : les appelants async résolvent le flag et le passent en paramètre.
"""
from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

import base64

from tests.documents.test_sse_stream import _lpp_result, _png_b64  # type: ignore

_PNG_BYTES = base64.b64decode(_png_b64())


def _third_party_result():
    r = _lpp_result()
    r.third_party_detected = True
    r.third_party_name = "Lauren Example"
    return r


async def _collect(gen):
    return [e async for e in gen]


@pytest.mark.asyncio
async def test_sse_undeclared_third_party_emits_gate_event_and_skips_persist(
    monkeypatch,
):
    from app.services import document_stream as ds
    from app.services import document_third_party as dtp
    from app.services import document_vision_service as dvs

    def _raise_gate(db, *, user_id, understanding, doc_hash):
        raise dtp.ThirdPartyDeclarationRequired(
            subject_names=["Lauren Example"], doc_hash=doc_hash,
        )

    persist_calls = []
    monkeypatch.setattr(dtp, "require_declaration_or_block", _raise_gate)
    monkeypatch.setattr(
        dvs, "persist_document_memory",
        lambda *a, **k: persist_calls.append((a, k)),
    )

    with patch.object(
        ds, "understand_document",
        new=AsyncMock(return_value=_third_party_result()),
    ):
        events = await _collect(ds.stream_understanding(
            _PNG_BYTES, user_id="u-sse-tp", db=object(), file_sha="sha-tp-1",
        ))

    names = [e["event"] for e in events]
    assert "third_party_declaration_required" in names, (
        "le chemin SSE doit porter le blocage 428 du chemin unaire via un "
        f"événement dédié — événements vus : {names}"
    )
    gate = next(
        e for e in events if e["event"] == "third_party_declaration_required"
    )
    assert gate["data"]["subjectNames"] == ["Lauren Example"]
    assert gate["data"]["docHash"] == "sha-tp-1"
    assert (
        gate["data"]["declarationEndpoint"]
        == "/api/v1/consents/grant-nominative"
    )
    done = events[-1]
    assert done["event"] == "done"
    assert done["data"]["third_party_declaration_required"] is not None
    assert persist_calls == [], (
        "un doc tiers NON déclaré ne doit jamais être persisté (PRIV-02)"
    )


@pytest.mark.asyncio
async def test_sse_declared_third_party_persists_with_async_resolved_flag(
    monkeypatch,
):
    from app.services import document_stream as ds
    from app.services import document_third_party as dtp
    from app.services import document_vision_service as dvs
    from app.services import flags_service

    monkeypatch.setattr(
        dtp, "require_declaration_or_block", lambda *a, **k: None,
    )

    flag_queries = []

    async def _is_enabled(name, user_id=None):
        flag_queries.append(name)
        return True

    monkeypatch.setattr(
        flags_service.flags, "is_enabled", _is_enabled, raising=False,
    )

    persist_calls = []
    monkeypatch.setattr(
        dvs, "persist_document_memory",
        lambda db, user_id, result, use_encryption=None: persist_calls.append(
            use_encryption
        ),
    )

    with patch.object(
        ds, "understand_document",
        new=AsyncMock(return_value=_third_party_result()),
    ):
        events = await _collect(ds.stream_understanding(
            _PNG_BYTES, user_id="u-sse-ok", db=object(), file_sha="sha-tp-2",
        ))

    assert persist_calls == [True], (
        "doc tiers DÉCLARÉ -> persistance mémoire avec le flag PRIVACY_V2 "
        "résolu en ASYNC et passé en paramètre (le pont sync timeout-erait "
        f"vers False/plaintext) — appels : {persist_calls}"
    )
    assert "PRIVACY_V2_ENABLED" in flag_queries
    names = [e["event"] for e in events]
    assert "third_party_declaration_required" not in names
    assert events[-1]["data"]["third_party_declaration_required"] is None


@pytest.mark.asyncio
async def test_upsert_accepts_caller_resolved_encryption(monkeypatch):
    """Le paramètre use_encryption court-circuite le pont sync cassé.

    Probe Codex sur dev : depuis une boucle async, _flag_privacy_v2 avec le
    flag mocké True renvoyait False après ~1 s (timeout du pont) -> écriture
    plaintext. Avec use_encryption=True passé par l'appelant, le chiffrement
    est appliqué SANS consulter le pont.
    """
    import app.services.document_memory_service as dms

    bridge_calls = []
    monkeypatch.setattr(
        dms, "_flag_privacy_v2",
        lambda uid: bridge_calls.append(uid) or False,
    )
    monkeypatch.setattr(dms, "encrypt_text", lambda db, uid, data: b"CIPHER")

    from tests.services.document.test_nlpd_gates_enforce import (  # type: ignore
        _mk_understanding,
    )
    from tests.conftest import TestingSessionLocal
    from app.models import User
    from app.models.document_memory import DocumentMemory

    db = TestingSessionLocal()
    try:
        db.add(User(id="u-async-enc", email="ae@test.ch", hashed_password="x"))
        db.commit()
        result = _mk_understanding()
        dms.upsert_and_diff(db, "u-async-enc", result, use_encryption=True)
        row = db.query(DocumentMemory).filter_by(user_id="u-async-enc").one()
        assert row.field_history[0].get("fields_enc"), (
            "use_encryption=True doit chiffrer sans consulter le pont"
        )
        assert "95000" not in str(row.field_history)
        assert bridge_calls == [], (
            "le pont sync ne doit PAS être consulté quand l'appelant a "
            "résolu le flag"
        )
    finally:
        db.close()


def test_sync_e2e_428_grant_retry_persists(client, monkeypatch):
    """Cycle complet chemin unaire : understand -> 428 -> grant-nominative
    -> retry -> 200 + DocumentMemory persisté (bead item 3 — test-gap).

    Utilise le VRAI require_declaration_or_block et le VRAI endpoint
    grant-nominative (aucun stub du gate) — seul understand_document est
    doublé pour éviter Anthropic.
    """
    from tests.conftest import TestingSessionLocal
    from app.models.document_memory import DocumentMemory
    from app.services import document_vision_service as dvs

    async def _fake_understand(**kwargs):
        return _third_party_result()

    # Import local dans l'endpoint -> patcher le module source.
    monkeypatch.setattr(dvs, "understand_document", _fake_understand)

    from app.services import flags_service

    async def _is_enabled(name, user_id=None):
        return name == "DOCUMENTS_V2_ENABLED"

    monkeypatch.setattr(
        flags_service.flags, "is_enabled", _is_enabled, raising=False,
    )

    payload = {
        "documentType": "lpp_certificate",
        "imageBase64": _png_b64(),
    }

    # 1. Sans déclaration -> 428 + pointer structuré.
    first = client.post("/api/v1/documents/extract-vision", json=payload)
    assert first.status_code == 428, first.text
    detail = first.json()["detail"]
    assert detail["code"] == "third_party_declaration_required"
    assert detail["subjectNames"] == ["Lauren Example"]
    doc_hash = detail["docHash"]

    # 2. Déclaration nominative réelle.
    granted = client.post(
        "/api/v1/consents/grant-nominative",
        json={
            "subject_name": "Lauren Example",
            "doc_hash": doc_hash,
            "subject_role": "declared_partner",
        },
    )
    assert granted.status_code in (200, 201), granted.text

    # 3. Retry -> 200 et mémoire persistée.
    retry = client.post("/api/v1/documents/extract-vision", json=payload)
    assert retry.status_code == 200, retry.text

    db = TestingSessionLocal()
    try:
        rows = db.query(DocumentMemory).filter_by(user_id="test-user-id").all()
        assert rows, "le doc tiers déclaré doit être persisté après retry"
    finally:
        db.close()
