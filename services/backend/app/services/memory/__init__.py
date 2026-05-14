"""Wave 1a D-07 — Karpathy-wiki memory retrieval (per memory project_user_profile_wiki).

Plan-00 shipped the empty marker; plan-05 fills it. The package is the
deterministic SQL-filtered surface for BM25 retrieval over the user's
CoachInsightRecord rows (no vector embedding, no LLM call).
"""
from app.services.memory.bm25 import InsightHit, retrieve

__all__ = ["retrieve", "InsightHit"]
