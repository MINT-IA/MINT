"""MoneyTruthReceiptRecord — append-only store→resolve du MoneyTruthReceipt.

Tranche firstJob PR-E (E1). Persistance du handoff /first-job → coach :
le mobile calcule le net L1, émet un ``MoneyTruthReceipt`` (contrat de vérité
chiffrée, `app/models/lucidity/money_truth_receipt.py`) et le STOCKE ici ; le
coach le RÉSOUT ensuite par ``receipt_id`` + ``inputs_hash`` scopé au
propriétaire, pour rendre la MÊME valeur (SPEC §4.3).

Pourquoi une table dédiée et NON `projection_audit_records`
===========================================================
`projection_audit_records` est un journal de conformité LSFin **hash-only**,
sans PII, à rétention longue (~10 ans, append-only avec REVOKE UPDATE/DELETE).
Le coach ne peut PAS reconstruire ``receipt.value`` depuis un `output_hash`
(SHA256 irréversible) : la résolution exige le corps complet du receipt.
Stocker ce corps (valeur nette + inputs salaire/âge/canton) dans le journal
de conformité ~10 ans serait un problème nLPD (D12). Cette table suit le
**pattern** ProjectionAuditRecord — modèle SQLAlchemy ``Base``, migration
alembic, scoping propriétaire par hash HMAC, append-only sur Postgres — mais
comme un **store de résolution à fenêtre bornée** (voir `receipt_store.py`
``RECEIPT_RESOLVE_TTL``), distinct du journal ~10 ans. Ce n'est PAS une
nouvelle infra : même DB, même Base, même mécanisme de migration, mêmes
helpers de hachage (`hmac_pepper`).

Doctrine
========
- **Scoping propriétaire STRICT** : ``owner_scope_hash`` = HMAC(pepper) de
  ``user.id`` (authentifié) OU de l'``anonymous_session_id`` — jamais en clair.
  La résolution filtre TOUJOURS sur ``owner_scope_hash`` : l'accès croisé ne
  matche aucune ligne (SPEC §4.3 clause 2).
- **Idempotence** : UNIQUE(owner_scope_hash, receipt_id). La ré-émission du
  MÊME receipt = no-op (SPEC §4.3 clause 1). Un même ``receipt_id`` avec un
  ``inputs_hash`` divergent est un conflit (rejeté par le store).
- **Append-only** : Postgres REVOKE UPDATE, DELETE (migration p126). SQLite
  (tests) : INSERT-only par convention. La fenêtre de résolvabilité (TTL) est
  calculée à la lecture depuis ``created_at`` — la ligne N'EST PAS supprimée
  (pas de nouveau régime de rétention).
- **PII** : ``owner_scope_hash`` est un HMAC ; ``receipt_body`` contient la
  valeur nette + inputs (salaire/âge/canton) en clair — d'où la fenêtre de
  résolvabilité bornée + la séparation d'avec le journal de conformité.

Références
----------
- .planning/phases/mint-2-0-first-experience-rente-capital/TRANCHE-FIRSTJOB-SPEC.md
  §4.2 (persistance), §4.3 (contrat store → resolve : idempotence, scoping,
  pending, TTL).
- app/models/projection_audit_record.py (pattern append-only + user_id_hash).
- app/services/lucidity/receipt_store.py (store/resolve + owner-scoping + TTL).
"""

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import Column, DateTime, Index, String, Text, UniqueConstraint

from app.core.database import Base


class MoneyTruthReceiptRecord(Base):
    """Ligne append-only : un MoneyTruthReceipt persisté, scopé propriétaire.

    ``receipt_body`` porte le receipt COMPLET sérialisé camelCase (mêmes clés
    que le miroir Dart) : c'est ce que le coach RÉSOUT pour rendre la MÊME
    ``value``. ``output_hash`` (SHA256 de la valeur) est conservé pour
    l'uniformité tamper-evidence avec `projection_audit_records`.
    """

    __tablename__ = "money_truth_receipts"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    # HMAC(pepper) de user.id OU de anonymous_session_id — jamais en clair.
    owner_scope_hash = Column(String(64), nullable=False)
    owner_kind = Column(String(16), nullable=False)  # "user" | "anon"
    receipt_id = Column(String(64), nullable=False)
    inputs_hash = Column(String(64), nullable=False)
    claim_id = Column(String(64), nullable=False)
    # Corps complet du receipt (JSON camelCase). Le net vit ici en clair : la
    # fenêtre de résolvabilité (RECEIPT_RESOLVE_TTL) borne l'exposition.
    receipt_body = Column(Text, nullable=False)
    # SHA256 de la valeur — parité tamper-evidence avec projection_audit_records.
    output_hash = Column(String(64), nullable=False)
    source = Column(
        String(32),
        nullable=False,
        default="mobile_l1_receipt",
        server_default="mobile_l1_receipt",
    )
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    __table_args__ = (
        # Idempotence + scoping : un receipt_id est unique PAR propriétaire.
        # La ré-émission (même owner + même receipt_id) est un no-op ; l'accès
        # croisé (owner différent) ne matche jamais cette ligne.
        UniqueConstraint(
            "owner_scope_hash",
            "receipt_id",
            name="uq_money_truth_owner_receipt",
        ),
        # Chemin de requête dominant : résolution par (owner, receipt_id).
        Index(
            "ix_money_truth_owner_receipt",
            "owner_scope_hash",
            "receipt_id",
        ),
    )


__all__ = ["MoneyTruthReceiptRecord"]
