"""Tranche firstJob PR-E (E1) — store/resolve du MoneyTruthReceipt pour le coach.

Contrat SPEC §4.3 (store → resolve), testé mécaniquement :

1. Écriture idempotente : clé = ``inputsHash`` + ``receiptId`` ; ré-émission = no-op.
2. Lecture scopée au propriétaire : l'accès croisé renvoie ``not_found`` — JAMAIS
   le receipt d'autrui (test d'accès croisé STRICT, exigence PR-E).
3. Cas ``pending`` : receipt pas encore synchronisé → le payload porte les inputs,
   la résolution renvoie ``pending`` + inputs, jamais d'erreur nue.
4. TTL aligné ``ProjectionAuditRecord`` : receipt expiré = ``not_found`` propre.

Les tests de service utilisent une session DB directe (deux propriétaires
distincts pour l'accès croisé) ; les tests d'endpoint passent par le
``client`` (auth surchargée `_fake_user`).
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.services.coach.inputs_hash import compute_inputs_hash
from app.services.lucidity.receipt_store import (
    RECEIPT_RESOLVE_TTL,
    ReceiptResolveStatus,
    resolve_receipt,
    resolve_receipt_context,
    store_receipt,
)
from app.models.lucidity.money_truth_receipt import (
    FIRST_JOB_NET_SALARY_CLAIM_ID,
    MoneyTruthReceipt,
)
from app.models.money_truth_receipt_record import MoneyTruthReceiptRecord


# ── Helpers ─────────────────────────────────────────────────────────────────


def _make_receipt(
    *,
    receipt_id: str = "rcpt-aaaa-1111",
    value: float = 6104.92,
    salaire: float = 6788.0,
    canton: str = "ZH",
    age: int = 30,
) -> MoneyTruthReceipt:
    """Construit un MoneyTruthReceipt v1 valide (range + confidence requis)."""
    inputs = {
        "salaireBrutMensuel": salaire,
        "age": age,
        "canton": canton,
        "tauxActivite": 100.0,
        "etatCivil": "celibataire",
    }
    return MoneyTruthReceipt.model_validate(
        {
            "claimId": FIRST_JOB_NET_SALARY_CLAIM_ID,
            "receiptId": receipt_id,
            "inputs": inputs,
            "inputsHash": compute_inputs_hash(inputs),
            "jurisdiction": f"CH-{canton}",
            "taxYear": 2026,
            "base": "net",
            "civilStatus": "celibataire",
            "assumptions": ["tauxActivite=100%", "13e exclu"],
            "engine": "financial_core.first_job_service",
            "engineVersion": "constants-abc+2.12.4",
            "rounding": "CHF arrondi au 1 franc",
            "sources": [
                {"id": "avs", "label": "AVS/AI/APG", "vintage": 2026},
                {"id": "ofs_ess", "label": "OFS ESS", "vintage": 2022},
            ],
            "value": value,
            "range": {"low": value - 14.0, "high": value + 20.0},
            "confidence": {
                "completeness": 1.0,
                "accuracy": 0.9,
                "freshness": 1.0,
                "understanding": 0.5,
                "score": 0.79,
            },
            "computedAt": "2026-07-29T10:00:00+00:00",
        }
    )


def _db():
    from tests.conftest import TestingSessionLocal

    return TestingSessionLocal()


class _User:
    def __init__(self, uid: str):
        self.id = uid


# ── Service : idempotence ────────────────────────────────────────────────────


def test_store_is_idempotent_same_owner():
    db = _db()
    try:
        r = _make_receipt(receipt_id="rcpt-idem")
        first = store_receipt(db, receipt=r, anonymous_session_id="sess-A")
        second = store_receipt(db, receipt=r, anonymous_session_id="sess-A")
        assert first.status == "stored"
        assert second.status == "duplicate"
        # Une seule ligne persistée (ré-émission = no-op).
        rows = (
            db.query(MoneyTruthReceiptRecord)
            .filter(MoneyTruthReceiptRecord.receipt_id == "rcpt-idem")
            .all()
        )
        assert len(rows) == 1
    finally:
        db.close()


def test_store_conflict_same_receipt_different_inputs_hash():
    """Même receiptId, inputsHash différent (clé d'idempotence violée) → conflit."""
    db = _db()
    try:
        r1 = _make_receipt(receipt_id="rcpt-conflict", salaire=6788.0)
        r2 = _make_receipt(receipt_id="rcpt-conflict", salaire=9999.0)
        assert r1.inputs_hash != r2.inputs_hash
        store_receipt(db, receipt=r1, anonymous_session_id="sess-A")
        with pytest.raises(ValueError):
            store_receipt(db, receipt=r2, anonymous_session_id="sess-A")
    finally:
        db.close()


# ── Service : résolution scopée + accès croisé ──────────────────────────────


def test_store_then_resolve_same_owner_returns_receipt():
    db = _db()
    try:
        r = _make_receipt(receipt_id="rcpt-own", value=6104.92)
        store_receipt(db, receipt=r, user=_User("user-a"))
        res = resolve_receipt(
            db,
            receipt_id="rcpt-own",
            inputs_hash=r.inputs_hash,
            user=_User("user-a"),
        )
        assert res.status == ReceiptResolveStatus.RESOLVED
        assert res.receipt is not None
        assert res.receipt.value == pytest.approx(6104.92)
        assert res.receipt.receipt_id == "rcpt-own"
        # provenance intacte
        assert res.receipt.tax_year == 2026
        assert res.receipt.range is not None
        assert res.receipt.confidence is not None
    finally:
        db.close()


def test_resolve_cross_owner_returns_not_found():
    """ACCÈS CROISÉ STRICT : owner B ne résout JAMAIS le receipt de owner A."""
    db = _db()
    try:
        r = _make_receipt(receipt_id="rcpt-cross", value=6104.92)
        store_receipt(db, receipt=r, user=_User("user-a"))

        # user-b avec le MÊME receiptId + inputsHash (il a intercepté l'URL).
        res = resolve_receipt(
            db,
            receipt_id="rcpt-cross",
            inputs_hash=r.inputs_hash,
            user=_User("user-b"),
        )
        assert res.status == ReceiptResolveStatus.NOT_FOUND
        assert res.receipt is None

        # même en fournissant les inputs, il obtient au mieux `pending` sur SES
        # inputs — jamais la valeur d'autrui.
        res2 = resolve_receipt(
            db,
            receipt_id="rcpt-cross",
            inputs_hash=r.inputs_hash,
            receipt_inputs={"salaireBrutMensuel": 6788.0},
            user=_User("user-b"),
        )
        assert res2.status == ReceiptResolveStatus.PENDING
        assert res2.receipt is None

        # session anonyme distincte : idem.
        res3 = resolve_receipt(
            db,
            receipt_id="rcpt-cross",
            inputs_hash=r.inputs_hash,
            anonymous_session_id="sess-other",
        )
        assert res3.status == ReceiptResolveStatus.NOT_FOUND
        assert res3.receipt is None
    finally:
        db.close()


def test_resolve_wrong_inputs_hash_same_owner_not_resolved():
    db = _db()
    try:
        r = _make_receipt(receipt_id="rcpt-hashmiss", value=6104.92)
        store_receipt(db, receipt=r, user=_User("user-a"))
        res = resolve_receipt(
            db,
            receipt_id="rcpt-hashmiss",
            inputs_hash="f" * 64,  # inputsHash ne correspond pas
            user=_User("user-a"),
        )
        assert res.status == ReceiptResolveStatus.NOT_FOUND
        assert res.receipt is None
    finally:
        db.close()


# ── Service : pending / not_found ────────────────────────────────────────────


def test_resolve_pending_when_unknown_but_inputs_provided():
    db = _db()
    try:
        res = resolve_receipt(
            db,
            receipt_id="rcpt-never-stored",
            inputs_hash="a" * 64,
            receipt_inputs={"salaireBrutMensuel": 5400.0, "age": 24, "canton": "VD"},
            user=_User("user-a"),
        )
        assert res.status == ReceiptResolveStatus.PENDING
        assert res.receipt is None
        assert res.inputs == {"salaireBrutMensuel": 5400.0, "age": 24, "canton": "VD"}
    finally:
        db.close()


def test_resolve_not_found_when_unknown_and_no_inputs():
    db = _db()
    try:
        res = resolve_receipt(
            db,
            receipt_id="rcpt-nope",
            inputs_hash="a" * 64,
            user=_User("user-a"),
        )
        assert res.status == ReceiptResolveStatus.NOT_FOUND
        assert res.receipt is None
        assert res.inputs is None
    finally:
        db.close()


def test_resolve_expired_receipt_returns_not_found():
    """TTL aligné ProjectionAuditRecord : receipt expiré = not_found propre."""
    db = _db()
    try:
        r = _make_receipt(receipt_id="rcpt-expired", value=6104.92)
        store_receipt(db, receipt=r, user=_User("user-a"))
        # Vieillir la ligne au-delà de la fenêtre de résolvabilité.
        row = (
            db.query(MoneyTruthReceiptRecord)
            .filter(MoneyTruthReceiptRecord.receipt_id == "rcpt-expired")
            .one()
        )
        row.created_at = datetime.now(timezone.utc) - RECEIPT_RESOLVE_TTL - timedelta(days=1)
        db.add(row)
        db.commit()

        res = resolve_receipt(
            db,
            receipt_id="rcpt-expired",
            inputs_hash=r.inputs_hash,
            user=_User("user-a"),
        )
        assert res.status == ReceiptResolveStatus.NOT_FOUND
        assert res.receipt is None
    finally:
        db.close()


# ── Coach wiring : resolve_receipt_context ──────────────────────────────────


class _Body:
    def __init__(self, receipt_id=None, inputs_hash=None, receipt_inputs=None):
        self.receipt_id = receipt_id
        self.inputs_hash = inputs_hash
        self.receipt_inputs = receipt_inputs


def test_resolve_receipt_context_none_when_no_receipt_id():
    db = _db()
    try:
        assert resolve_receipt_context(db, _User("user-a"), _Body()) is None
    finally:
        db.close()


def test_resolve_receipt_context_returns_grounded_dict_for_stored():
    db = _db()
    try:
        r = _make_receipt(receipt_id="rcpt-ctx", value=6104.92)
        store_receipt(db, receipt=r, user=_User("user-a"))
        ctx = resolve_receipt_context(
            db,
            _User("user-a"),
            _Body(receipt_id="rcpt-ctx", inputs_hash=r.inputs_hash),
        )
        assert ctx is not None
        assert ctx["status"] == "resolved"
        assert ctx["value"] == pytest.approx(6104.92)
        assert ctx["base"] == "net"
        assert ctx["taxYear"] == 2026
        assert ctx["receiptId"] == "rcpt-ctx"
        assert ctx["inputsHash"] == r.inputs_hash
    finally:
        db.close()


def test_resolve_receipt_context_surfaces_band_and_confidence():
    """P0 #1114 — le contexte résolu porte l'appareil de lucidité (fourchette +
    confiance) pour que le bloc de grounding coach le rende avec la valeur."""
    db = _db()
    try:
        r = _make_receipt(receipt_id="rcpt-band", value=6104.92)
        store_receipt(db, receipt=r, user=_User("user-a"))
        ctx = resolve_receipt_context(
            db,
            _User("user-a"),
            _Body(receipt_id="rcpt-band", inputs_hash=r.inputs_hash),
        )
        assert ctx is not None
        assert ctx["range"] == {"low": pytest.approx(6090.92), "high": pytest.approx(6124.92)}
        assert ctx["confidence"] == pytest.approx(0.79)
    finally:
        db.close()


def test_resolve_receipt_context_pending_no_row_with_inputs():
    """DOUBLE CEINTURE (Codex P1) : le coach grounde via `pending` depuis les
    `receiptInputs` SEULS — aucune ligne en base (store échoué / non appelé),
    JAMAIS `not_found` muet quand le payload porte les inputs (SPEC §4.3 c.3)."""
    db = _db()
    try:
        inputs = {"salaireBrutMensuel": 6788.0, "age": 30, "canton": "ZH"}
        ctx = resolve_receipt_context(
            db,
            _User("user-a"),
            _Body(
                receipt_id="rcpt-never-stored",
                inputs_hash="a" * 64,
                receipt_inputs=inputs,
            ),
        )
        assert ctx is not None
        assert ctx["status"] == "pending"
        assert ctx["inputs"] == inputs
        assert "value" not in ctx  # pas de valeur inventée sans receipt résolu
    finally:
        db.close()


def test_resolve_receipt_context_not_found_no_row_no_inputs():
    """Sans ligne ET sans inputs -> not_found propre (le CTA doit donc TOUJOURS
    porter receiptInputs — c'est la raison de la ceinture 2)."""
    db = _db()
    try:
        ctx = resolve_receipt_context(
            db,
            _User("user-a"),
            _Body(receipt_id="rcpt-nada", inputs_hash="a" * 64),
        )
        assert ctx == {"status": "not_found"}
    finally:
        db.close()


def test_resolve_receipt_context_pending_for_cross_owner_with_inputs():
    db = _db()
    try:
        r = _make_receipt(receipt_id="rcpt-ctx-cross", value=6104.92)
        store_receipt(db, receipt=r, user=_User("user-a"))
        ctx = resolve_receipt_context(
            db,
            _User("user-b"),  # propriétaire différent
            _Body(
                receipt_id="rcpt-ctx-cross",
                inputs_hash=r.inputs_hash,
                receipt_inputs={"salaireBrutMensuel": 6788.0},
            ),
        )
        assert ctx is not None
        assert ctx["status"] == "pending"
        assert "value" not in ctx  # jamais la valeur d'autrui
    finally:
        db.close()


# ── Endpoints ────────────────────────────────────────────────────────────────


def test_store_endpoint_persists_and_is_idempotent(client):
    r = _make_receipt(receipt_id="rcpt-ep")
    body = {"receipt": r.model_dump(by_alias=True)}
    resp1 = client.post("/api/v1/lucidity/receipts", json=body)
    assert resp1.status_code == 200, resp1.text
    assert resp1.json()["status"] == "stored"
    assert resp1.json()["receiptId"] == "rcpt-ep"

    resp2 = client.post("/api/v1/lucidity/receipts", json=body)
    assert resp2.status_code == 200, resp2.text
    assert resp2.json()["status"] == "duplicate"


def test_resolve_endpoint_returns_receipt_for_owner(client):
    r = _make_receipt(receipt_id="rcpt-ep-resolve", value=4615.0)
    client.post("/api/v1/lucidity/receipts", json={"receipt": r.model_dump(by_alias=True)})

    resp = client.post(
        "/api/v1/lucidity/receipts/resolve",
        json={"receiptId": "rcpt-ep-resolve", "inputsHash": r.inputs_hash},
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["status"] == "resolved"
    assert data["receipt"]["value"] == pytest.approx(4615.0)
    assert data["receipt"]["receiptId"] == "rcpt-ep-resolve"


def test_resolve_endpoint_pending_for_unknown_with_inputs(client):
    resp = client.post(
        "/api/v1/lucidity/receipts/resolve",
        json={
            "receiptId": "rcpt-ep-unknown",
            "inputsHash": "a" * 64,
            "receiptInputs": {"salaireBrutMensuel": 5000.0},
        },
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["status"] == "pending"
    assert data["receipt"] is None


def test_coach_chat_request_accepts_receipt_fields():
    """Le coach REÇOIT receiptId + inputsHash (schéma additif, pas de 422)."""
    from app.schemas.coach_chat import CoachChatRequest

    req = CoachChatRequest.model_validate(
        {
            "message": "explique mon net",
            "receiptId": "rcpt-x",
            "inputsHash": "b" * 64,
            "receiptInputs": {"salaireBrutMensuel": 6788.0},
        }
    )
    assert req.receipt_id == "rcpt-x"
    assert req.inputs_hash == "b" * 64
    assert req.receipt_inputs == {"salaireBrutMensuel": 6788.0}


def test_coach_chat_grounds_on_resolved_receipt(client):
    """CÂBLAGE RÉEL (pas de façade) : /coach/chat porteur d'un receiptId résout
    le receipt owner-scoped et l'injecte dans le profile_context passé à
    l'orchestrateur — le coach ground sur la MÊME valeur (SPEC §4.3).

    Le fixture ``client`` surcharge get_db (TestingSessionLocal) + l'auth
    (`_fake_user`, id 'test-user-id') + sème le grant de transfert. On stocke
    donc le receipt sous 'test-user-id' via LA MÊME session que l'endpoint.
    """
    from unittest.mock import AsyncMock, MagicMock, patch

    from app.services.billing_service import ALL_FEATURES

    # Persiste un receipt scopé à l'utilisateur du fixture (comme le store
    # /first-job), via la MÊME session (TestingSessionLocal / get_db surchargé).
    db = _db()
    try:
        r = _make_receipt(receipt_id="rcpt-coach", value=6104.92)
        store_receipt(db, receipt=r, user=_User("test-user-id"))
    finally:
        db.close()

    mock_orch = MagicMock()
    mock_orch.query = AsyncMock(
        return_value={
            "answer": "Ton net pourrait etre autour de ce montant.",
            "sources": [],
            "disclaimers": [],
            "tokens_used": 10,
        }
    )

    with patch(
        "app.api.v1.endpoints.coach_chat.recompute_entitlements",
        return_value=("premium", ALL_FEATURES),
    ), patch(
        "app.api.v1.endpoints.coach_chat._get_orchestrator",
        return_value=mock_orch,
    ):
        resp = client.post(
            "/api/v1/coach/chat",
            json={
                "message": "explique mon net firstJob",
                "apiKey": "sk-test-byok",
                "receiptId": "rcpt-coach",
                "inputsHash": r.inputs_hash,
            },
        )

    assert resp.status_code == 200, resp.text
    # L'orchestrateur a été appelé avec un profile_context portant le
    # receipt RÉSOLU (server-side, owner-scoped), pas un recalcul.
    assert mock_orch.query.await_count >= 1
    grounded = [
        call.kwargs.get("profile_context") or {}
        for call in mock_orch.query.await_args_list
    ]
    receipts = [
        pc.get("money_truth_receipt")
        for pc in grounded
        if isinstance(pc, dict) and pc.get("money_truth_receipt")
    ]
    assert receipts, "le receipt résolu n'a pas atteint le contexte coach"
    assert receipts[0]["status"] == "resolved"
    assert receipts[0]["value"] == pytest.approx(6104.92)
    assert receipts[0]["receiptId"] == "rcpt-coach"
