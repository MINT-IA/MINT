"""Domain-separated HMAC builder for partner-accountability receipts."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import json
import os


HMAC_KEY_ENV = "MINT_PARTNER_ACCOUNTABILITY_HMAC_KEY"
PREVIOUS_HMAC_KEYS_ENV = "MINT_PARTNER_ACCOUNTABILITY_PREVIOUS_HMAC_KEYS_JSON"
NOTICE_VERSION_ENV = "PARTNER_LPP_NOTICE_VERSION"
POLICY_VERSION_ENV = "PARTNER_LPP_POLICY_VERSION"
RECEIPT_LIFETIME = timedelta(days=365)
_KEY_ID_DOMAIN = b"mint.partner-accountability.key-id.v1"


class AccountabilityConfigurationError(RuntimeError):
    """Raised when the externally approved runtime bundle is incomplete."""


@dataclass(frozen=True)
class AccountabilityHmacKey:
    key_id: str
    value: bytes


@dataclass(frozen=True)
class AccountabilityKeyring:
    current: AccountabilityHmacKey | None
    keys: dict[str, bytes]

    def key_for(self, key_id: str | None) -> bytes:
        if key_id is None or key_id not in self.keys:
            raise AccountabilityConfigurationError(
                "partner accountability historical HMAC key absent"
            )
        return self.keys[key_id]


@dataclass(frozen=True)
class ApprovedAccountabilityBundle:
    hmac_key: bytes
    hmac_key_id: str
    notice_version: str
    policy_version: str


@dataclass(frozen=True)
class ReceiptMaterial:
    acting_principal_pseudonym: str
    subject_owner_pseudonym: str
    declared_at: datetime
    expires_at: datetime


def derive_hmac_key_id(key: str | bytes) -> str:
    """Derive a non-secret stable id used to select a rotated HMAC key."""
    key_bytes = key.encode("utf-8") if isinstance(key, str) else key
    return hashlib.sha256(_KEY_ID_DOMAIN + b"\x00" + key_bytes).hexdigest()[:32]


def _validated_key(value: object) -> bytes:
    if not isinstance(value, str):
        raise AccountabilityConfigurationError(
            "partner accountability HMAC keyring invalid"
        )
    normalized = value.strip()
    if len(normalized) < 32:
        raise AccountabilityConfigurationError(
            "partner accountability HMAC keyring invalid"
        )
    return normalized.encode("utf-8")


def load_keyring(*, require_current: bool = False) -> AccountabilityKeyring:
    """Load current and explicitly retained historical keys without fallbacks."""
    keys: dict[str, bytes] = {}
    raw_previous = (os.environ.get(PREVIOUS_HMAC_KEYS_ENV) or "").strip()
    if raw_previous:
        try:
            previous = json.loads(raw_previous)
        except (TypeError, ValueError):
            raise AccountabilityConfigurationError(
                "partner accountability HMAC keyring invalid"
            ) from None
        if not isinstance(previous, dict):
            raise AccountabilityConfigurationError(
                "partner accountability HMAC keyring invalid"
            )
        for configured_id, configured_value in previous.items():
            key = _validated_key(configured_value)
            if not isinstance(configured_id, str) or configured_id != derive_hmac_key_id(key):
                raise AccountabilityConfigurationError(
                    "partner accountability HMAC keyring invalid"
                )
            keys[configured_id] = key

    raw_current = (os.environ.get(HMAC_KEY_ENV) or "").strip()
    current: AccountabilityHmacKey | None = None
    if raw_current:
        current_key = _validated_key(raw_current)
        current_id = derive_hmac_key_id(current_key)
        configured_previous = keys.get(current_id)
        if configured_previous is not None and configured_previous != current_key:
            raise AccountabilityConfigurationError(
                "partner accountability HMAC keyring invalid"
            )
        keys[current_id] = current_key
        current = AccountabilityHmacKey(key_id=current_id, value=current_key)
    elif require_current:
        raise AccountabilityConfigurationError(
            "partner accountability HMAC key absent"
        )
    return AccountabilityKeyring(current=current, keys=keys)


def approved_bundle() -> ApprovedAccountabilityBundle:
    """Load the externally approved versions; no repository fallback exists."""
    keyring = load_keyring(require_current=True)
    assert keyring.current is not None
    notice_version = (os.environ.get(NOTICE_VERSION_ENV) or "").strip()
    policy_version = (os.environ.get(POLICY_VERSION_ENV) or "").strip()
    if not notice_version or not policy_version:
        raise AccountabilityConfigurationError(
            "partner accountability approved versions absent"
        )
    return ApprovedAccountabilityBundle(
        hmac_key=keyring.current.value,
        hmac_key_id=keyring.current.key_id,
        notice_version=notice_version,
        policy_version=policy_version,
    )


def current_versions() -> tuple[str | None, str | None]:
    """Return current versions for lifecycle status without activating creation."""
    notice = (os.environ.get(NOTICE_VERSION_ENV) or "").strip() or None
    policy = (os.environ.get(POLICY_VERSION_ENV) or "").strip() or None
    return notice, policy


def _pseudonym(*, key: bytes, domain: bytes, raw: str) -> str:
    payload = domain + b"\x00" + raw.encode("utf-8")
    return hmac.new(key, payload, hashlib.sha256).hexdigest()


def pseudonymize_actor(actor_id: str, *, key: bytes) -> str:
    return _pseudonym(
        key=key,
        domain=b"mint.partner-accountability.actor.v1",
        raw=actor_id,
    )


def pseudonymize_owner(owner_token: str, *, key: bytes) -> str:
    return _pseudonym(
        key=key,
        domain=b"mint.partner-accountability.owner.v1",
        raw=owner_token,
    )


def build_receipt_material(
    *,
    actor_id: str,
    owner_token: str,
    key: bytes,
    now: datetime | None = None,
) -> ReceiptMaterial:
    declared_at = now or datetime.now(timezone.utc)
    return ReceiptMaterial(
        acting_principal_pseudonym=pseudonymize_actor(actor_id, key=key),
        subject_owner_pseudonym=pseudonymize_owner(owner_token, key=key),
        declared_at=declared_at,
        expires_at=declared_at + RECEIPT_LIFETIME,
    )
