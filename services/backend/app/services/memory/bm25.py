"""Wave 1a D-07 — BM25 ranking over CoachInsightRecord rows.

Karpathy wiki (per Julien 2026-05-13, memory project_user_profile_wiki):
« the user variable library is a Karpathy LLM Wiki, not vector-RAG.
Per-user pages, BM25 lookup over (topic + summary), no vector
embedding, no LLM call. »

Schema (verified 2026-05-14 by reading services/backend/app/models/coach_insight.py):
  CoachInsightRecord columns: id, user_id, topic, summary, insight_type,
  created_at, updated_at. The CONTEXT D-07 mentions of additional columns
  were fabrications resolved at plan-time. Corpus per row is
  tokenize(topic + " " + summary).

Score floor: 0.3 (BM25Okapi default scale; tune in Wave 1c if recall insufficient).
Top-k: 5 (matches legacy max_results=3..10 envelope at coach_chat.py:1912).
User isolation: WHERE user_id = ? at the SQL layer — no cross-user
  leakage possible at this surface. Uses the existing
  (user_id, topic) composite index (coach_insight.py:60).
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from rank_bm25 import BM25Okapi

_SCORE_FLOOR: float = 0.3
_MAX_CORPUS_ROWS: int = 500
_DEFAULT_K: int = 5


@dataclass(frozen=True)
class InsightHit:
    """One BM25 retrieval result. Mirrors CoachInsightRecord shape + score."""

    record_id: str
    user_id: str
    topic: str
    summary: str
    insight_type: str
    score: float


def _tokenize(text: str) -> list[str]:
    """Lowercase + whitespace tokenization. No stemming (FR + EN mix)."""
    return text.lower().split()


def retrieve(
    topic: str,
    user_id: Optional[str],
    db,
    k: int = _DEFAULT_K,
) -> list[InsightHit]:
    """Return top-k InsightHits for the user, BM25-ranked over their insights.

    Args:
        topic: free-text query. Empty string returns [].
        user_id: WHERE clause — cross-user isolation guarantee. None -> [].
        db: SQLAlchemy session. None -> [].
        k: max results. Hits below _SCORE_FLOOR (0.3) are dropped.

    Returns:
        list[InsightHit] ordered by BM25 score desc, score >= 0.3.
        Empty list if no insights match OR the user has no
        CoachInsightRecord rows AND no ProfileModel.data["recent_insights"].
    """
    if not topic or db is None or not user_id:
        return []
    from app.models.coach_insight import CoachInsightRecord

    rows = (
        db.query(CoachInsightRecord)
        .filter(CoachInsightRecord.user_id == user_id)
        .order_by(CoachInsightRecord.updated_at.desc())
        .limit(_MAX_CORPUS_ROWS)
        .all()
    )
    if not rows:
        return _profile_fallback(topic, user_id, db, k)

    corpus = [_tokenize(f"{(r.topic or '')} {(r.summary or '')}") for r in rows]
    if not any(corpus):
        return []
    bm25 = BM25Okapi(corpus)
    scores = bm25.get_scores(_tokenize(topic))
    paired = list(zip(rows, scores))
    paired.sort(key=lambda x: x[1], reverse=True)
    hits: list[InsightHit] = []
    for r, s in paired[:k]:
        score = float(s)
        if score < _SCORE_FLOOR:
            continue
        hits.append(
            InsightHit(
                record_id=r.id,
                user_id=r.user_id,
                topic=r.topic,
                summary=r.summary,
                insight_type=r.insight_type,
                score=score,
            )
        )
    return hits


def _profile_fallback(topic: str, user_id: str, db, k: int) -> list[InsightHit]:
    """Fallback: scan ProfileModel.data['recent_insights'] for topic match.

    ProfileModel.data is a JSON dict (services/backend/app/models/profile_model.py).
    Wave 1a does NOT mandate the 'recent_insights' key — if absent, return [].
    Score=1.0 for exact topic-substring matches (bypass BM25 entirely).
    """
    from app.models.profile_model import ProfileModel

    profile = (
        db.query(ProfileModel)
        .filter(ProfileModel.user_id == user_id)
        .order_by(ProfileModel.updated_at.desc())
        .first()
    )
    if profile is None or not profile.data:
        return []
    recent = profile.data.get("recent_insights") or []
    if not isinstance(recent, list):
        return []
    topic_tokens = set(_tokenize(topic))
    hits: list[InsightHit] = []
    for entry in recent:
        if not isinstance(entry, dict):
            continue
        entry_topic = (entry.get("topic") or "").lower()
        if any(t in entry_topic for t in topic_tokens):
            hits.append(
                InsightHit(
                    record_id=f"profile_recent_{entry.get('created_at', '')}",
                    user_id=user_id,
                    topic=entry.get("topic", ""),
                    summary=entry.get("summary", ""),
                    insight_type=entry.get("insight_type", "fact"),
                    score=1.0,
                )
            )
            if len(hits) >= k:
                break
    return hits
