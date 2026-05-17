"""Phase mint-calc-engine-v1 W3 — D-CE-12 read-through cache layer.

Provides :
- `lookup(profile_id, kind, inputs_hash, db)` — sub-50ms partial-index read.
- `write(profile_id, kind, inputs_hash, payload, db)` — supersede-chain writer.
- `AsyncSingleflight` + module-level `_singleflight` — Concern E stampede guard.
- `get_or_compute(profile_id, kind, inputs_hash, compute_fn, db)` — orchestrator.

Backed by Plan 12's composite partial index `idx_scenarios_cache_lookup`
(`profile_id, kind, inputs_hash, created_at DESC WHERE superseded_by IS NULL`)
on PostgreSQL. SQLite test path uses the plain index ; query shape is identical.
"""

from app.services.cache.cache_reader import lookup
from app.services.cache.cache_writer import write
from app.services.cache.get_or_compute import get_or_compute
from app.services.cache.singleflight import AsyncSingleflight, _singleflight

__all__ = [
    "AsyncSingleflight",
    "_singleflight",
    "get_or_compute",
    "lookup",
    "write",
]
