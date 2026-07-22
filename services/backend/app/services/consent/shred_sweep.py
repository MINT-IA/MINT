"""Sweep périodique des crypto-shreds en attente (MINT_nosync-tqj).

L'endpoint de révocation promet « suppression sous CASCADE_GRACE_DAYS jours » :
le retry paresseux (grant/revoke) ne suffit pas — un utilisateur qui ne touche
plus jamais aux consentements resterait pendant indéfiniment (review Codex P1).
Ce sweep borne le délai : toutes les SWEEP_INTERVAL_SECONDS, chaque utilisateur
porteur d'un marqueur durable `shred_pending` est re-tenté via
`ConsentService.retry_pending_shreds` (qui applique la garde de supersession).

Câblé dans app.main:lifespan sur le modèle du SLO monitor (non-fatal).
"""
from __future__ import annotations

import asyncio
import logging

logger = logging.getLogger("mint.consent.shred_sweep")

# 6h : borne largement le délai des 30 jours promis, sans charge notable.
SWEEP_INTERVAL_SECONDS = 6 * 3600


def sweep_once() -> int:
    """Re-tente tous les shreds en attente. Retourne le nombre satisfait."""
    from app.core.database import SessionLocal
    from app.models.consent import ConsentModel
    from app.services.consent.consent_service import ConsentService

    svc = ConsentService()
    done = 0
    db = SessionLocal()
    try:
        user_ids = [
            uid
            for (uid,) in db.query(ConsentModel.user_id)
            .filter(ConsentModel.shred_pending.is_(True))
            .distinct()
            .all()
        ]
        for uid in user_ids:
            try:
                done += svc.retry_pending_shreds(db, uid)
            except Exception as exc:  # un user en erreur ne bloque pas les autres
                logger.warning("shred_sweep user=%s failed: %s", uid, exc)
        if user_ids:
            logger.info(
                "shred_sweep: %d pending user(s), %d satisfied", len(user_ids), done
            )
    finally:
        db.close()
    return done


async def run_forever() -> None:
    """Boucle de sweep — démarrée par le lifespan, jamais fatale."""
    while True:
        try:
            await asyncio.to_thread(sweep_once)
        except Exception as exc:  # pragma: no cover — resilience only
            logger.warning("shred_sweep iteration failed: %s", exc)
        await asyncio.sleep(SWEEP_INTERVAL_SECONDS)
