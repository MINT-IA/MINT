"""Consent service — grant / revoke / list / verify_chain.

v2.7 Phase 29 / PRIV-01.

Wires receipt_builder + merkle_chain into a single façade used by the REST
layer. Revocation of `persistence_365d` cascades to `crypto_shred_user` (a 30d
scheduled shred is the current design; here we expose the immediate shred hook
and let the background job scheduler call it — see Phase 29-01 summary for the
rationale behind the deferred scheduled job).
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Callable, Dict, List, Optional

from app.models.consent import ConsentModel
from app.schemas.consent_receipt import ConsentPurpose
from app.services.consent import merkle_chain
from app.services.consent.receipt_builder import (
    build_receipt,
    compute_policy_hash,
    hash_ip,
    sign_receipt,
)
from app.services.encryption.key_vault import key_vault as _key_vault

logger = logging.getLogger(__name__)

# Grace window before crypto-shred fires on revoking persistence_365d.
CASCADE_GRACE_DAYS = 30


@dataclass(frozen=True)
class ConsentCheckResult:
    """Result of a ConsentService.check_or_log() call — Phase 97.5 W2-T5.

    Carries the gate decision + the payload the caller needs to act on it.

    Fields:
        grant_exists   : True if an active (non-revoked) grant exists.
        allow          : True if the gate should let the request through.
                         In `log_only` + `soft_block` modes this is always True
                         (gate is telemetry-only). In `hard_block` mode this is
                         False when grant_exists is False.
        warning_header : Optional `X-MINT-Consent-Warning` header value the
                         caller should attach to the response. Populated only
                         in `soft_block` mode when the grant is missing.
                         v2.10 wires header propagation ; v2.9 leaves the
                         structure defined but the field unused.
        deny_pointer   : Optional structured pointer JSON the caller should
                         attach to the 403 detail. Populated only in
                         `hard_block` mode when the grant is missing.
                         Shape: {"action", "purpose", "modal_copy_key"}.
    """

    grant_exists: bool
    allow: bool
    warning_header: Optional[str] = None
    deny_pointer: Optional[Dict[str, Any]] = None


class ConsentError(Exception):
    pass


class ConsentNotFoundError(ConsentError):
    pass


class ConsentService:
    """Façade: backend of /api/v1/consents/*."""

    # Inject-able so tests can stub the shred call without monkey-patching.
    def __init__(self, shred_hook: Optional[Callable[[object, str], bool]] = None) -> None:
        self._shred_hook = shred_hook

    def _shred(self, db, user_id: str) -> bool:
        """True ssi l'obligation d'effacement est satisfaite.

        `crypto_shred_user` renvoie False quand AUCUN DEK n'existe — il n'y a
        alors rien à effacer : l'obligation est satisfaite (review Codex
        MINT_nosync-tqj P0 : traiter ce False comme un échec créait un marqueur
        pending rassis capable de détruire un DEK re-créé après re-consent).
        False = uniquement une vraie erreur (exception du vault).
        """
        if self._shred_hook is not None:
            return self._shred_hook(db, user_id)
        try:
            _key_vault.crypto_shred_user(db, user_id)
            return True
        except Exception as exc:  # pragma: no cover — log only
            logger.warning("consent.cascade_shred failed user=%s err=%s", user_id, exc)
            return False

    # -- grant -----------------------------------------------------------------
    def grant(
        self,
        db,
        *,
        user_id: str,
        purpose: str,
        policy_version: str,
        extra: Optional[Dict[str, Any]] = None,
    ) -> ConsentModel:
        """Append a new consent receipt to the user's merkle chain.

        `extra` (added in Phase 97.5 W2-T5) is an additive dict merged into
        `receipt_json` by `build_receipt`. Existing callers pass nothing and
        get the byte-identical behaviour. New callers (`grant_with_basis`)
        inject `{"basis": "..."}` for audit-trail provenance.
        """
        # Retry paresseux d'un crypto-shred en attente (MINT_nosync-tqj).
        self.retry_pending_shreds(db, user_id)
        prev_signature = merkle_chain.latest_signature(db, user_id)
        # Full microsecond precision — two consecutive grants in the same
        # second must order deterministically in verify_chain.
        now = datetime.now(timezone.utc)
        receipt_json = build_receipt(
            user_id=user_id,
            purpose=purpose,
            policy_version=policy_version,
            prev_signature=prev_signature,
            now=now,
            extra=extra,
        )
        signature = sign_receipt(receipt_json)
        row = merkle_chain.append_receipt(
            db,
            user_id=user_id,
            purpose=purpose,
            policy_version=policy_version,
            policy_hash=receipt_json["policyHash"],
            receipt_id=receipt_json["receiptId"],
            consent_timestamp=now,
            receipt_json=receipt_json,
            prev_hash=receipt_json["prevHash"],
            signature=signature,
        )
        return row

    # -- has_active_grant (Phase 97.5 W2-T5 gate read path) -------------------
    def has_active_grant(
        self,
        db,
        *,
        user_id: str,
        purpose: ConsentPurpose,
    ) -> bool:
        """Return True if ANY non-revoked grant exists for (user_id, purpose).

        Semantic per julien-go 2026-05-12 + 97.5-PLAN.md §D.1 + Option A
        scope-decision: "active" means at least one row in `consents` with
        `(user_id == X, purpose_category == Y.value, revoked_at IS NULL)`.

        This is a read of the audit log, NOT a merkle-chain integrity check.
        Chain verification stays on `verify_chain(...)` — the gate read path
        intentionally does not pay that cost on every request.

        The PRIV-01 design appends a new receipt on every regrant, so multiple
        non-revoked rows for the same (user, purpose) can coexist legitimately
        (e.g. user re-confirms consent after policy version bump). "ANY non-
        revoked row answers yes" is cheaper than "DESC LIMIT 1" and is
        semantically equivalent for the gate question « does the user have
        current consent right now ».
        """
        return (
            db.query(ConsentModel)
            .filter(
                ConsentModel.user_id == user_id,
                ConsentModel.purpose_category == purpose.value,
                ConsentModel.revoked_at.is_(None),
            )
            .first()
            is not None
        )

    # -- grant_with_basis (Phase 97.5 W2-T6 idempotent backfill granter) ------
    def grant_with_basis(
        self,
        db,
        *,
        user_id: str,
        purpose: ConsentPurpose,
        policy_version: str,
        basis: str,
    ) -> Optional[ConsentModel]:
        """Idempotent grant variant carrying a provenance `basis` field.

        Semantic per julien-go 2026-05-12 Option A:
        1. If `has_active_grant(user_id, purpose)` already returns True, this
           is a no-op and returns None. (LSFin Art 8 audit-trail discipline:
           we never silently stack duplicate grants for the same purpose
           when the gate would already pass.)
        2. Otherwise: call `grant(...)` with `extra={"basis": basis}` injected
           into `receipt_json`. Returns the new ConsentModel row.

        `basis` discriminates user-initiated grants from admin-backfilled ones
        in the audit log. v2.9 known values (not enforced as a whitelist per
        Karpathy #2):
            - "legal-continuity-pre-granular-T&C" — W2-T6 backfill of users
              who accepted T&C before the granular-consent schema landed.
            - "user-initiated" — T&C-acceptance flow grants.
            - "admin-restore" — future use (operator-driven restore).

        The merkle chain invariant is preserved: this method does not bypass
        `grant()` ; it just gates the call behind the idempotency check.
        """
        if self.has_active_grant(db, user_id=user_id, purpose=purpose):
            return None
        return self.grant(
            db,
            user_id=user_id,
            purpose=purpose.value,
            policy_version=policy_version,
            extra={"basis": basis},
        )

    # -- check_or_log (Phase 97.5 W2-T5 gate dispatch) ------------------------
    def check_or_log(
        self,
        db,
        *,
        user_id: str,
        purpose: ConsentPurpose,
        mode: str,
    ) -> ConsentCheckResult:
        """Gate dispatch per Phase 97.5 W2-T5 + 97.5-PLAN.md §D.

        Behaviour by mode:

        - `log_only`   : emit structured warning log + Sentry breadcrumb when
                         the grant is missing ; ALWAYS returns allow=True.
                         Pure telemetry — no UX impact. v2.9 default.
        - `soft_block` : same logging + populate `warning_header` with
                         "missing:<purpose>" when grant is missing.
                         allow=True. Caller chooses to attach the header to
                         the response (v2.10 wiring).
        - `hard_block` : same logging + populate `deny_pointer` with the
                         structured 403 detail. allow=False. Caller raises
                         HTTPException(403, detail=deny_pointer).
        - Unknown mode : treated as `log_only` (fail-OPEN per R-2 mitigation).
                         A misconfigured env var must never block traffic in
                         v2.9. A warning log records the misconfiguration.

        When the grant DOES exist, allow=True and no side-effects fire,
        regardless of mode.
        """
        grant_exists = self.has_active_grant(
            db, user_id=user_id, purpose=purpose
        )
        if grant_exists:
            return ConsentCheckResult(grant_exists=True, allow=True)

        # --- side-effect: structured telemetry on missing grant ---
        # Always fires regardless of mode (mode controls the user-visible
        # consequence, not the telemetry — LSFin Art 8 traceability).
        logger.warning(
            "consent_missing",
            extra={
                "purpose": purpose.value,
                "user_id": user_id,
                "mode": mode,
            },
        )
        try:
            import sentry_sdk  # local import — keeps test env light
            sentry_sdk.add_breadcrumb(
                category="consent",
                message="missing",
                level="warning",
                data={"purpose": purpose.value, "mode": mode},
            )
        except Exception:  # pragma: no cover — Sentry is best-effort
            pass

        if mode == "soft_block":
            return ConsentCheckResult(
                grant_exists=False,
                allow=True,
                warning_header=f"missing:{purpose.value}",
            )
        if mode == "hard_block":
            pointer = {
                "action": "POST /api/v1/consents/grant",
                "purpose": purpose.value,
                "modal_copy_key": f"consent_modal_{purpose.value}",
            }
            return ConsentCheckResult(
                grant_exists=False,
                allow=False,
                deny_pointer=pointer,
            )

        # log_only: explicit observe-only mode (choix produit, cf. -tih pour
        # le passage en hard_block une fois l'UX de grant accessible).
        if mode == "log_only":
            return ConsentCheckResult(grant_exists=False, allow=True)

        # Mode inconnu/mal configure -> FAIL-CLOSED (audit T10-F02,
        # MINT_nosync-tih) : une typo d'env var ne doit jamais desactiver
        # silencieusement le gate.
        logger.error(
            "consent_gate_unknown_mode_failing_closed",
            extra={"mode": mode},
        )
        return ConsentCheckResult(
            grant_exists=False,
            allow=False,
            deny_pointer={
                "action": "POST /api/v1/consents/grant",
                "purpose": purpose.value,
                "modal_copy_key": f"consent_modal_{purpose.value}",
            },
        )

    # -- grant nominative (PRIV-02) -------------------------------------------
    def grant_nominative(
        self,
        db,
        *,
        user_id: str,
        subject_name: str,
        doc_hash: str,
        declared_from_ip: Optional[str],
        policy_version: str = "v2.3.0",
        subject_role: str = "declared_other",
    ) -> ConsentModel:
        """Create a THIRD_PARTY_ATTESTATION receipt bound to (doc_hash, subject_name).

        The receipt is signed + merkle-chained like every other consent row but
        its `receipt_json` carries three extra fields that make it opposable:

            - subjectName      : the detected PERSON string (never hashed —
                                 audit requires the same string the user saw).
            - subjectRole      : "declared_partner" | "declared_other".
            - declaredDocHash  : sha256 of the uploaded file bytes; gate
                                 requires an exact match before proceeding.
            - declaredFromIp   : HMAC-SHA256 of raw IP truncated to 16 bytes;
                                 audit can cluster without PII exposure.

        Per D-PRIV-02: one receipt per (user, doc_hash) — no receipt reuse
        across documents. The gate enforces this via the doc_hash match.
        """
        prev_signature = merkle_chain.latest_signature(db, user_id)
        now = datetime.now(timezone.utc)
        extra = {
            "subjectName": subject_name,
            "subjectRole": subject_role,
            "declaredDocHash": doc_hash,
            "declaredFromIp": hash_ip(declared_from_ip),
        }
        receipt_json = build_receipt(
            user_id=user_id,
            purpose="third_party_attestation",
            policy_version=policy_version,
            prev_signature=prev_signature,
            now=now,
            extra=extra,
        )
        signature = sign_receipt(receipt_json)
        row = merkle_chain.append_receipt(
            db,
            user_id=user_id,
            purpose="third_party_attestation",
            policy_version=policy_version,
            policy_hash=receipt_json["policyHash"],
            receipt_id=receipt_json["receiptId"],
            consent_timestamp=now,
            receipt_json=receipt_json,
            prev_hash=receipt_json["prevHash"],
            signature=signature,
        )
        return row

    # -- revoke ----------------------------------------------------------------
    def revoke(
        self,
        db,
        *,
        user_id: str,
        receipt_id: str,
    ) -> tuple[ConsentModel, bool]:
        """Revoke a receipt. Returns (row, cascade_scheduled).

        If purpose == persistence_365d AND this was the last active grant for
        that purpose, `cascade_scheduled=True` and a shred is initiated.
        """
        self.retry_pending_shreds(db, user_id)
        row: Optional[ConsentModel] = (
            db.query(ConsentModel)
            .filter(
                ConsentModel.user_id == user_id,
                ConsentModel.receipt_id == receipt_id,
            )
            .one_or_none()
        )
        if row is None:
            raise ConsentNotFoundError(f"receipt {receipt_id} not found for user")
        if row.revoked_at is not None:
            return row, False  # idempotent

        row.revoked_at = datetime.now(timezone.utc)
        row.enabled = False

        # Audit T02-F49 (MINT_nosync-tqj): le retour de _shred etait ignore —
        # l'API affirmait cascade_scheduled=True meme quand rien n'avait ete
        # efface, sans retry. Le marqueur shred_pending est pose dans la MEME
        # transaction que la revocation (review Codex P1 : un crash entre les
        # deux commits laissait une revocation sans marqueur = fail-open), puis
        # efface seulement si le shred immediat satisfait l'obligation.
        cascade = False
        if row.purpose_category == "persistence_365d":
            # Autoflush: la revocation ci-dessus est vue par ce count.
            active = (
                db.query(ConsentModel)
                .filter(
                    ConsentModel.user_id == user_id,
                    ConsentModel.purpose_category == "persistence_365d",
                    ConsentModel.revoked_at.is_(None),
                )
                .count()
            )
            if active == 0:
                row.shred_pending = True
                cascade = True
        db.commit()
        db.refresh(row)

        if cascade:
            if self._shred(db, user_id):
                row.shred_pending = False
                db.commit()
            else:
                logger.error(
                    "consent.cascade_shred FAILED — durable shred_pending "
                    "kept user=%s receipt=%s (retry: interactions + sweep)",
                    user_id,
                    row.receipt_id,
                )
        return row, cascade

    # -- durable shred retry ---------------------------------------------------
    def retry_pending_shreds(self, db, user_id: str) -> int:
        """Re-attempt crypto-shreds marked durable by a failed cascade.

        Returns the number of users actually shredded (0 or 1 here). Called
        lazily from grant()/revoke(); also usable by a periodic sweep.
        """
        pending = (
            db.query(ConsentModel)
            .filter(
                ConsentModel.user_id == user_id,
                ConsentModel.shred_pending.is_(True),
            )
            .all()
        )
        if not pending:
            return 0
        # Garde de supersession (review Codex P0) : si l'utilisateur a
        # RE-CONSENTI a la persistance depuis, la base legale du stockage est
        # renouvelee — executer l'ancienne obligation detruirait le DEK (et
        # donc les donnees) legitimement re-crees. On efface le marqueur sans
        # shredder.
        active_persistence = (
            db.query(ConsentModel)
            .filter(
                ConsentModel.user_id == user_id,
                ConsentModel.purpose_category == "persistence_365d",
                ConsentModel.revoked_at.is_(None),
            )
            .count()
        )
        if active_persistence > 0:
            logger.info(
                "consent.pending_shred superseded by re-consent user=%s",
                user_id,
            )
            for row in pending:
                row.shred_pending = False
            db.commit()
            return 0
        if not self._shred(db, user_id):
            return 0  # keep the durable flags — retried next interaction
        for row in pending:
            row.shred_pending = False
        db.commit()
        return 1

    # -- list ------------------------------------------------------------------
    def list_for_user(self, db, user_id: str) -> List[ConsentModel]:
        return (
            db.query(ConsentModel)
            .filter(
                ConsentModel.user_id == user_id,
                ConsentModel.purpose_category.isnot(None),
            )
            .all()
        )

    # -- verify chain ---------------------------------------------------------
    def verify_chain(self, db, user_id: str):
        return merkle_chain.verify_chain(db, user_id)

    # -- helper: current policy hash ------------------------------------------
    @staticmethod
    def policy_hash(version: str) -> str:
        return compute_policy_hash(version)


# Module-level singleton (stateless)
consent_service = ConsentService()
