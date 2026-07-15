"""Transactional lifecycle for minimized partner-accountability receipts."""

from __future__ import annotations

from datetime import datetime, timezone
import hmac
from uuid import UUID

from sqlalchemy import and_, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.partner_accountability_receipt import PartnerAccountabilityReceipt
from app.models.user import User
from app.schemas.partner_accountability import (
    ACCOUNTABILITY_KIND,
    PURPOSE,
    SUBJECT_KIND,
    PartnerAccountabilityReceiptCreate,
)
from app.services.partner_accountability.receipt_builder import (
    RECEIPT_LIFETIME,
    AccountabilityKeyring,
    approved_bundle,
    build_receipt_material,
    current_versions,
    load_keyring,
    pseudonymize_actor,
)


class PartnerAccountabilityConflict(RuntimeError):
    """The UUID already identifies a different canonical declaration."""


class PartnerAccountabilityNotFound(RuntimeError):
    """No non-erased receipt belongs to the acting principal."""


class PartnerAccountabilityInactive(RuntimeError):
    """The receipt cannot authorize a one-shot LPP extraction."""


class PartnerAccountabilityActorUnavailable(RuntimeError):
    """The authenticated actor disappeared before receipt creation."""


class PartnerAccountabilityVersionNotCurrent(RuntimeError):
    """The request does not bind the externally approved current versions."""


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


class PartnerAccountabilityService:
    def __init__(self, db: Session) -> None:
        self._db = db

    @staticmethod
    def _key_for_row(
        row: PartnerAccountabilityReceipt,
        keyring: AccountabilityKeyring,
    ) -> bytes:
        return keyring.key_for(row.hmac_key_id)

    def _canonical_matches(
        self,
        row: PartnerAccountabilityReceipt,
        *,
        actor_pseudonym: str,
        owner_pseudonym: str,
        body: PartnerAccountabilityReceiptCreate,
    ) -> bool:
        return bool(
            row.erased_at is None
            and row.acting_principal_pseudonym == actor_pseudonym
            and row.subject_owner_pseudonym == owner_pseudonym
            and row.subject_kind == body.subject_kind
            and row.accountability_kind == body.accountability_kind
            and row.purpose == body.purpose
            and row.notice_version == body.notice_version
            and row.policy_version == body.policy_version
        )

    def _existing_matches(
        self,
        row: PartnerAccountabilityReceipt,
        *,
        actor_id: str,
        body: PartnerAccountabilityReceiptCreate,
    ) -> bool:
        if row.erased_at is not None:
            return False
        key = self._key_for_row(row, load_keyring())
        material = build_receipt_material(
            actor_id=actor_id,
            owner_token=body.subject_owner_token.get_secret_value(),
            key=key,
        )
        return self._canonical_matches(
            row,
            actor_pseudonym=material.acting_principal_pseudonym,
            owner_pseudonym=material.subject_owner_pseudonym,
            body=body,
        )

    def _lock_actor_for_receipt_write(self, *, actor_id: str) -> None:
        """Serialize PostgreSQL receipt creation with account deletion.

        The paired delete transaction must remain READ COMMITTED so its later
        receipt query sees a create that committed while the User lock waited.
        """
        if self._db.get_bind().dialect.name != "postgresql":
            return
        actor = (
            self._db.query(User.id)
            .filter(User.id == actor_id)
            .with_for_update()
            .one_or_none()
        )
        if actor is None:
            raise PartnerAccountabilityActorUnavailable

    def create(
        self,
        *,
        actor_id: str,
        body: PartnerAccountabilityReceiptCreate,
    ) -> tuple[PartnerAccountabilityReceipt, bool]:
        self._lock_actor_for_receipt_write(actor_id=actor_id)
        receipt_id = str(body.receipt_id)
        existing = self._db.get(PartnerAccountabilityReceipt, receipt_id)
        if existing is not None:
            if self._existing_matches(existing, actor_id=actor_id, body=body):
                return existing, False
            raise PartnerAccountabilityConflict

        bundle = approved_bundle()
        if (
            body.notice_version != bundle.notice_version
            or body.policy_version != bundle.policy_version
        ):
            raise PartnerAccountabilityVersionNotCurrent
        material = build_receipt_material(
            actor_id=actor_id,
            owner_token=body.subject_owner_token.get_secret_value(),
            key=bundle.hmac_key,
        )

        row = PartnerAccountabilityReceipt(
            receipt_id=receipt_id,
            acting_principal_pseudonym=material.acting_principal_pseudonym,
            subject_owner_pseudonym=material.subject_owner_pseudonym,
            subject_kind=body.subject_kind,
            accountability_kind=body.accountability_kind,
            purpose=body.purpose,
            notice_version=body.notice_version,
            policy_version=body.policy_version,
            hmac_key_id=bundle.hmac_key_id,
            declared_at=material.declared_at,
            expires_at=material.expires_at,
        )
        self._db.add(row)
        try:
            self._db.commit()
        except IntegrityError:
            self._db.rollback()
            concurrent = self._db.get(PartnerAccountabilityReceipt, receipt_id)
            if concurrent is not None and self._existing_matches(
                concurrent,
                actor_id=actor_id,
                body=body,
            ):
                return concurrent, False
            raise PartnerAccountabilityConflict from None
        self._db.refresh(row)
        return row, True

    def _actor_receipt(
        self,
        *,
        actor_id: str,
        receipt_id: UUID,
        for_update: bool = False,
    ) -> PartnerAccountabilityReceipt:
        query = self._db.query(PartnerAccountabilityReceipt).filter(
            PartnerAccountabilityReceipt.receipt_id == str(receipt_id),
            PartnerAccountabilityReceipt.erased_at.is_(None),
        )
        if for_update:
            query = query.with_for_update()
        row = query.one_or_none()
        if row is None:
            raise PartnerAccountabilityNotFound
        key = self._key_for_row(row, load_keyring())
        expected = pseudonymize_actor(actor_id, key=key)
        actual = row.acting_principal_pseudonym
        if actual is None or not hmac.compare_digest(actual, expected):
            raise PartnerAccountabilityNotFound
        return row

    def list_for_actor(self, *, actor_id: str) -> list[PartnerAccountabilityReceipt]:
        key_ids = [
            key_id
            for (key_id,) in self._db.query(
                PartnerAccountabilityReceipt.hmac_key_id
            )
            .filter(PartnerAccountabilityReceipt.erased_at.is_(None))
            .distinct()
            .all()
        ]
        if not key_ids:
            return []
        keyring = load_keyring()
        predicates = []
        for key_id in key_ids:
            key = keyring.key_for(key_id)
            predicates.append(
                and_(
                    PartnerAccountabilityReceipt.hmac_key_id == key_id,
                    PartnerAccountabilityReceipt.acting_principal_pseudonym
                    == pseudonymize_actor(actor_id, key=key),
                )
            )
        return (
            self._db.query(PartnerAccountabilityReceipt)
            .filter(
                PartnerAccountabilityReceipt.erased_at.is_(None),
                or_(*predicates),
            )
            .order_by(PartnerAccountabilityReceipt.declared_at.asc())
            .all()
        )

    def get_status(
        self,
        *,
        actor_id: str,
        receipt_id: UUID,
    ) -> PartnerAccountabilityReceipt:
        return self._actor_receipt(actor_id=actor_id, receipt_id=receipt_id)

    def status_of(self, row: PartnerAccountabilityReceipt) -> str:
        if row.declared_at is None or row.expires_at is None:
            return "stale"
        declared_at = _aware(row.declared_at)
        expires_at = _aware(row.expires_at)
        now = datetime.now(timezone.utc)
        if declared_at > now or expires_at != declared_at + RECEIPT_LIFETIME:
            return "stale"
        if (
            row.subject_owner_pseudonym is None
            or row.subject_kind != SUBJECT_KIND
            or row.accountability_kind != ACCOUNTABILITY_KIND
            or row.purpose != PURPOSE
        ):
            return "stale"
        if row.revoked_at is not None:
            return "revoked"
        if expires_at <= now:
            return "expired"
        current_notice, current_policy = current_versions()
        if (
            current_notice is None
            or current_policy is None
            or row.notice_version != current_notice
            or row.policy_version != current_policy
        ):
            return "stale"
        return "active"

    def revoke(
        self,
        *,
        actor_id: str,
        receipt_id: UUID,
    ) -> PartnerAccountabilityReceipt:
        row = self._actor_receipt(actor_id=actor_id, receipt_id=receipt_id)
        if row.revoked_at is None:
            row.revoked_at = datetime.now(timezone.utc)
            self._db.commit()
            self._db.refresh(row)
        return row

    @staticmethod
    def _erase_row(row: PartnerAccountabilityReceipt, *, erased_at: datetime) -> None:
        row.acting_principal_pseudonym = None
        row.subject_owner_pseudonym = None
        row.subject_kind = None
        row.accountability_kind = None
        row.purpose = None
        row.notice_version = None
        row.policy_version = None
        row.hmac_key_id = None
        row.declared_at = None
        row.expires_at = None
        row.revoked_at = None
        row.consumed_at = None
        row.erased_at = erased_at

    def erase(self, *, actor_id: str, receipt_id: UUID) -> None:
        try:
            row = self._actor_receipt(actor_id=actor_id, receipt_id=receipt_id)
        except PartnerAccountabilityNotFound:
            return
        self._erase_row(row, erased_at=datetime.now(timezone.utc))
        self._db.commit()

    def erase_all_for_actor(self, *, actor_id: str) -> int:
        """Tombstone actor receipts without committing the caller's transaction.

        Under the required PostgreSQL READ COMMITTED isolation, this SELECT gets
        a fresh snapshot after the caller acquires the User lock. That is what
        makes a create-first receipt visible before account deletion commits.
        """
        rows = (
            self._db.query(PartnerAccountabilityReceipt)
            .filter(PartnerAccountabilityReceipt.erased_at.is_(None))
            .with_for_update()
            .all()
        )
        if not rows:
            return 0
        keyring = load_keyring()
        matched = []
        for row in rows:
            key = self._key_for_row(row, keyring)
            expected = pseudonymize_actor(actor_id, key=key)
            actual = row.acting_principal_pseudonym
            if actual is not None and hmac.compare_digest(actual, expected):
                matched.append(row)
        erased_at = datetime.now(timezone.utc)
        for row in matched:
            self._erase_row(row, erased_at=erased_at)
        self._db.flush()
        return len(matched)

    def consume_for_lpp(
        self,
        *,
        actor_id: str,
        receipt_id: UUID,
    ) -> PartnerAccountabilityReceipt:
        """Atomically reserve one permitted extraction before any side effect."""
        approved_bundle()
        try:
            row = self._actor_receipt(
                actor_id=actor_id,
                receipt_id=receipt_id,
                for_update=True,
            )
        except PartnerAccountabilityNotFound:
            raise PartnerAccountabilityInactive from None
        if self.status_of(row) != "active" or row.consumed_at is not None:
            raise PartnerAccountabilityInactive
        row.consumed_at = datetime.now(timezone.utc)
        self._db.commit()
        self._db.refresh(row)
        return row
