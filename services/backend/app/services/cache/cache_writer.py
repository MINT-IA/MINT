"""
Phase mint-calc-engine-v1 W3 Plan 13 — D-CE-12 write-side cache writer.

Inserts a new `ScenarioModel` row + flips `superseded_by` on the prior live row
for the same `(profile_id, kind)` key, preserving the DAG audit chain so future
`cache_reader.lookup(...)` filters return only the most recent compute.

Idempotent on identical `inputs_hash` (no-op return of the existing live row).
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.models.scenario import ScenarioModel


async def write(
    profile_id: str,
    kind: str,
    inputs_hash: str,
    payload: dict[str, Any],
    db: Session,
) -> ScenarioModel:
    """D-CE-12 write-side cache persist.

    Transaction shape (single commit, no nested transaction) :
        1. SELECT live row for (profile_id, kind) ORDER BY created_at DESC LIMIT 1.
        2. If found AND its `inputs_hash == inputs_hash` → idempotent no-op, return it.
        3. INSERT new row with `inputs_hash` + `outputs=payload` + `superseded_by=None`.
        4. If a prior row existed → flip its `superseded_by = new_row.id`.
        5. COMMIT.

    Args:
        profile_id: profile UUID (FK to profiles.id).
        kind: calculator kind.
        inputs_hash: SHA256 hex of canonical JSON inputs (per inputs_hash.py).
        payload: the compute result — persisted into ScenarioModel.outputs (JSON).
        db: SQLAlchemy sync session.

    Returns:
        The newly-inserted `ScenarioModel`, OR the pre-existing one if idempotent.

    Notes:
        - `ScenarioModel.outputs` is the cached compute column (JSON). The plan
          spec uses the word "payload" — this maps to `outputs`. `inputs` is left
          as a placeholder `{}` here ; full inputs persistence is the writer's
          downstream concern (out of scope per Plan 13 §3 surgical changes).
        - `superseded_by` chain depth is unbounded in Plan 13 — Plan 16 ships GC.
    """
    # Step 1 — find the prior live row for this (profile_id, kind) key.
    prior: Optional[ScenarioModel] = (
        db.query(ScenarioModel)
        .filter(
            ScenarioModel.profile_id == profile_id,
            ScenarioModel.kind == kind,
            ScenarioModel.superseded_by.is_(None),
        )
        .order_by(ScenarioModel.created_at.desc())
        .first()
    )

    # Step 2 — idempotent guard.
    if prior is not None and prior.inputs_hash == inputs_hash:
        return prior

    # Step 3 — insert new row.
    new_row = ScenarioModel(
        profile_id=profile_id,
        kind=kind,
        inputs={},  # placeholder ; full inputs persistence is downstream.
        outputs=payload,
        inputs_hash=inputs_hash,
        superseded_by=None,
        created_at=datetime.now(timezone.utc),
    )
    db.add(new_row)
    db.flush()  # populate new_row.id for the supersede pointer below.

    # Step 4 — flip prior.superseded_by → new_row.id (chain integrity).
    if prior is not None:
        prior.superseded_by = new_row.id
        db.add(prior)

    # Step 5 — commit.
    db.commit()
    db.refresh(new_row)
    return new_row
