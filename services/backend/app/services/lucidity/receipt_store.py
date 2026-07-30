"""Store → resolve du MoneyTruthReceipt (Tranche firstJob PR-E, E1).

Contrat SPEC §4.3 (acté après revue Codex) :

1. **Écriture** (`store_receipt`) — POST idempotent. Clé d'idempotence =
   ``inputs_hash`` + ``receipt_id`` scopée au propriétaire ; ré-émission = no-op.
   Même ``receipt_id`` avec un ``inputs_hash`` divergent = conflit (ValueError).
2. **Lecture** (`resolve_receipt`) — résolution par ``receipt_id`` **scopée au
   propriétaire** (HMAC de ``user.id`` ou de la session anonyme). L'accès croisé
   renvoie ``not_found`` — JAMAIS le receipt d'autrui.
3. **Pending** — receipt pas encore synchronisé (mobile offline → tap coach
   immédiat) : le payload d'entrée porte AUSSI les inputs normalisés ; la
   résolution renvoie ``pending`` + inputs, jamais d'erreur nue, jamais un
   recalcul avec d'autres inputs.
4. **TTL** — fenêtre de résolvabilité alignée sur la rétention
   ``ProjectionAuditRecord`` (pas de nouveau régime : la ligne n'est PAS
   supprimée, l'expiration est calculée à la lecture). Un receipt expiré =
   ``not_found`` propre + invite à recalculer sur /first-job.

Réutilisation obligatoire (SPEC §4.2, pas de réinvention) :
- ``owner_scope_hash`` ← ``hmac_pepper.hmac_user_id`` / ``hmac_pii`` (même
  entrée canonique que ``projection_audit_records.user_id_hash``).
- Le corps résolu est re-validé par le modèle canonique
  ``MoneyTruthReceipt`` — un octet altéré en base casse la validation.
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from enum import Enum
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.models.lucidity.money_truth_receipt import MoneyTruthReceipt
from app.models.money_truth_receipt_record import MoneyTruthReceiptRecord
from app.services.audit.hmac_pepper import hmac_pii, hmac_user_id

# Fenêtre de résolvabilité du receipt pour le handoff coach. La ligne reste
# en base (append-only, pattern ProjectionAuditRecord) ; passé ce délai la
# résolution renvoie not_found propre (SPEC §4.3 clause 4). 30 jours couvrent
# très largement un aller /first-job → coach ; au-delà, l'étalon a pu bouger,
# donc « recalcule sur /first-job » est la bonne réponse.
RECEIPT_RESOLVE_TTL = timedelta(days=30)


class ReceiptResolveStatus(str, Enum):
    """Verdict de résolution (SPEC §4.3)."""

    RESOLVED = "resolved"
    PENDING = "pending"
    NOT_FOUND = "not_found"


@dataclass(frozen=True)
class StoreResult:
    """Résultat d'une écriture idempotente."""

    status: str  # "stored" | "duplicate"
    receipt_id: str
    inputs_hash: str


@dataclass(frozen=True)
class ResolveResult:
    """Résultat d'une résolution scopée propriétaire."""

    status: ReceiptResolveStatus
    receipt: Optional[MoneyTruthReceipt]
    inputs: Optional[dict[str, Any]]


# ── Helpers ─────────────────────────────────────────────────────────────────


def _owner_scope(
    user: Optional[Any],
    anonymous_session_id: Optional[str],
) -> tuple[str, str]:
    """Résout (owner_scope_hash, owner_kind) — HMAC, jamais en clair.

    Priorité à l'identité authentifiée (le coach est toujours authentifié) ;
    fallback session anonyme (le store /first-job peut être pré-auth). Lève
    ValueError si aucun propriétaire n'est identifiable (jamais de receipt
    « global » non scopé).
    """
    uid = getattr(user, "id", None) if user is not None else None
    if uid:
        scope = hmac_user_id(str(uid))
        if scope:
            return scope, "user"
    if anonymous_session_id:
        scope = hmac_pii(anonymous_session_id)
        if scope:
            return scope, "anon"
    raise ValueError(
        "MoneyTruthReceipt store/resolve exige un propriétaire "
        "(utilisateur authentifié ou anonymous_session_id)."
    )


def _output_hash(value: float) -> str:
    """SHA256 de la valeur — parité tamper-evidence avec projection_audit."""
    return hashlib.sha256(repr(float(value)).encode("utf-8")).hexdigest()


def _as_utc(dt: datetime) -> datetime:
    """Normalise en UTC-aware (SQLite relit des datetimes naïfs)."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _is_expired(row: MoneyTruthReceiptRecord) -> bool:
    return datetime.now(timezone.utc) - _as_utc(row.created_at) > RECEIPT_RESOLVE_TTL


# ── Écriture ─────────────────────────────────────────────────────────────────


def store_receipt(
    db: Session,
    *,
    receipt: MoneyTruthReceipt,
    user: Optional[Any] = None,
    anonymous_session_id: Optional[str] = None,
) -> StoreResult:
    """Persiste un receipt de façon idempotente, scopé au propriétaire.

    - Première écriture → ``stored``.
    - Ré-émission (même owner + receipt_id + inputs_hash) → ``duplicate`` (no-op).
    - Même owner + receipt_id mais inputs_hash divergent → ``ValueError``
      (la clé d'idempotence inputsHash+receiptId est violée : deux calculs
      distincts ne peuvent pas partager un receipt_id).
    """
    owner_scope_hash, owner_kind = _owner_scope(user, anonymous_session_id)

    existing = (
        db.query(MoneyTruthReceiptRecord)
        .filter(
            MoneyTruthReceiptRecord.owner_scope_hash == owner_scope_hash,
            MoneyTruthReceiptRecord.receipt_id == receipt.receipt_id,
        )
        .one_or_none()
    )
    if existing is not None:
        if existing.inputs_hash != receipt.inputs_hash:
            raise ValueError(
                "Conflit d'idempotence : receipt_id "
                f"{receipt.receipt_id!r} déjà stocké avec un inputs_hash "
                "différent — un receipt_id identifie un calcul unique."
            )
        return StoreResult(
            status="duplicate",
            receipt_id=receipt.receipt_id,
            inputs_hash=receipt.inputs_hash,
        )

    row = MoneyTruthReceiptRecord(
        owner_scope_hash=owner_scope_hash,
        owner_kind=owner_kind,
        receipt_id=receipt.receipt_id,
        inputs_hash=receipt.inputs_hash,
        claim_id=receipt.claim_id,
        receipt_body=receipt.model_dump_json(by_alias=True),
        output_hash=_output_hash(receipt.value),
        source="mobile_l1_receipt",
        created_at=datetime.now(timezone.utc),
    )
    db.add(row)
    db.commit()
    return StoreResult(
        status="stored",
        receipt_id=receipt.receipt_id,
        inputs_hash=receipt.inputs_hash,
    )


# ── Lecture ──────────────────────────────────────────────────────────────────


def resolve_receipt(
    db: Session,
    *,
    receipt_id: str,
    inputs_hash: str,
    receipt_inputs: Optional[dict[str, Any]] = None,
    user: Optional[Any] = None,
    anonymous_session_id: Optional[str] = None,
) -> ResolveResult:
    """Résout un receipt par (receipt_id, inputs_hash) scopé au propriétaire.

    Verdict :
    - ``resolved`` : ligne du propriétaire trouvée, non expirée, inputs_hash
      concordant → receipt complet re-validé.
    - ``pending`` : pas de ligne résolvable pour ce propriétaire MAIS le
      payload porte ``receipt_inputs`` → le coach répond depuis les inputs.
    - ``not_found`` : pas de ligne résolvable ET pas d'inputs (ou expiré sans
      inputs) → invite à recalculer.

    L'accès croisé (owner différent) ne matche aucune ligne → ``not_found`` /
    ``pending``, JAMAIS le receipt d'autrui.
    """
    try:
        owner_scope_hash, _ = _owner_scope(user, anonymous_session_id)
    except ValueError:
        # Sans propriétaire identifiable, aucune résolution possible ; on ne
        # renvoie jamais un receipt. Pending si le payload porte les inputs.
        return _pending_or_not_found(receipt_inputs)

    row = (
        db.query(MoneyTruthReceiptRecord)
        .filter(
            MoneyTruthReceiptRecord.owner_scope_hash == owner_scope_hash,
            MoneyTruthReceiptRecord.receipt_id == receipt_id,
            MoneyTruthReceiptRecord.inputs_hash == inputs_hash,
        )
        .one_or_none()
    )
    if row is None or _is_expired(row):
        return _pending_or_not_found(receipt_inputs)

    receipt = MoneyTruthReceipt.model_validate_json(row.receipt_body)
    return ResolveResult(
        status=ReceiptResolveStatus.RESOLVED,
        receipt=receipt,
        inputs=None,
    )


def _pending_or_not_found(
    receipt_inputs: Optional[dict[str, Any]],
) -> ResolveResult:
    if receipt_inputs:
        return ResolveResult(
            status=ReceiptResolveStatus.PENDING,
            receipt=None,
            inputs=dict(receipt_inputs),
        )
    return ResolveResult(
        status=ReceiptResolveStatus.NOT_FOUND,
        receipt=None,
        inputs=None,
    )


# ── Wiring coach ─────────────────────────────────────────────────────────────


def resolve_receipt_context(
    db: Session,
    user: Optional[Any],
    body: Any,
) -> Optional[dict[str, Any]]:
    """Résout le receipt d'une requête coach en un dict de contexte compact.

    Retourne ``None`` quand la requête ne porte pas de ``receipt_id`` (chemin
    coach classique inchangé — aucun effet de bord). Sinon un dict :
    - ``resolved`` → {status, value, base, taxYear, jurisdiction, sources,
      receiptId, inputsHash} : le coach ground sur la MÊME valeur serveur.
    - ``pending``  → {status, inputs?} : le coach répond depuis les inputs.
    - ``not_found``→ {status} : le coach invite à recalculer.

    Le coach étant toujours authentifié (`require_current_user`), le scope
    propriétaire = ``user.id`` — l'accès croisé retombe en pending/not_found.
    """
    receipt_id = getattr(body, "receipt_id", None)
    if not receipt_id:
        return None

    result = resolve_receipt(
        db,
        receipt_id=receipt_id,
        inputs_hash=getattr(body, "inputs_hash", None) or "",
        receipt_inputs=getattr(body, "receipt_inputs", None),
        user=user,
    )

    if result.status == ReceiptResolveStatus.RESOLVED and result.receipt is not None:
        r = result.receipt
        # firstJob P0 #1114 — surface l'appareil de lucidité (bande + confiance)
        # pour que le bloc de grounding coach le rende avec la valeur. Les deux
        # sont REQUIS pour firstjob.net_salary.v1 mais restent nullables ici
        # (autres claims) : le renderer omet la ligne absente.
        band = (
            {"low": r.range.low, "high": r.range.high}
            if r.range is not None
            else None
        )
        confidence_score = (
            r.confidence.score if r.confidence is not None else None
        )
        return {
            "status": result.status.value,
            "receiptId": r.receipt_id,
            "inputsHash": r.inputs_hash,
            "value": r.value,
            "base": r.base,
            "taxYear": r.tax_year,
            "jurisdiction": r.jurisdiction,
            "sources": [
                {"id": s.id, "label": s.label, "vintage": s.vintage}
                for s in r.sources
            ],
            "range": band,
            "confidence": confidence_score,
        }
    if result.status == ReceiptResolveStatus.PENDING:
        ctx: dict[str, Any] = {"status": result.status.value}
        if result.inputs:
            ctx["inputs"] = result.inputs
        return ctx
    return {"status": ReceiptResolveStatus.NOT_FOUND.value}


__all__ = [
    "RECEIPT_RESOLVE_TTL",
    "ReceiptResolveStatus",
    "ResolveResult",
    "StoreResult",
    "resolve_receipt",
    "resolve_receipt_context",
    "store_receipt",
]
