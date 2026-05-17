"""
Phase mint-calc-engine-v1 W3 Plan 13 — D-CE-12 read-side cache lookup.

Sub-50ms warm read on PostgreSQL via the Plan 12 composite partial index
`idx_scenarios_cache_lookup ON scenarios (profile_id, kind, inputs_hash, created_at DESC)
WHERE superseded_by IS NULL`. Query shape below MUST match the index column order
verbatim — verified by `services/backend/tests/test_scenarios_cache_index.py` +
production EXPLAIN ANALYZE post-deploy (PG-only, RESEARCH §Q-D lines 675-693).

The async signature is preserved even though SQLAlchemy `Session` is sync — this
lets `get_or_compute` `await` the call inside an `AsyncSingleflight.acquire(...)`
context without restructuring the coroutine. FastAPI handlers stay `async def`.
"""

from __future__ import annotations

from typing import Optional

from sqlalchemy.orm import Session

from app.models.scenario import ScenarioModel


async def lookup(
    profile_id: str,
    kind: str,
    inputs_hash: str,
    db: Session,
) -> Optional[ScenarioModel]:
    """D-CE-12 read-side cache lookup.

    Returns the most recent live scenario row matching the key, or None.

    Args:
        profile_id: profile UUID (FK to profiles.id).
        kind: calculator kind (e.g. "avs", "lpp", "pillar3a").
        inputs_hash: SHA256 hex (64 chars) of RFC 8785 canonical JSON of
            the inputs that produced the cached compute (per
            `app.services.coach.inputs_hash`).
        db: SQLAlchemy sync session.

    Returns:
        The `ScenarioModel` row with `superseded_by IS NULL` and the highest
        `created_at`, or None if no live row matches.

    Notes:
        - Query shape MUST match Plan 12 index column order :
          `(profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL`.
        - On PG14+ this yields `Index Scan using idx_scenarios_cache_lookup`.
        - On SQLite (tests + dev fallback) the partial-WHERE clause filters
          post-scan ; performance not representative of PG.
    """
    return (
        db.query(ScenarioModel)
        .filter(
            ScenarioModel.profile_id == profile_id,
            ScenarioModel.kind == kind,
            ScenarioModel.inputs_hash == inputs_hash,
            ScenarioModel.superseded_by.is_(None),
        )
        .order_by(ScenarioModel.created_at.desc())
        .first()
    )
