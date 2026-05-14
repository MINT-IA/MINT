"""Wave 1a plan-05 — BM25 retrieve unit tests.

Per `wave-1a-05-PLAN.md` <behavior> for Task 1. 11 tests covering:
- Happy path BM25 ranking on user's CoachInsightRecord rows.
- ProfileModel.data['recent_insights'] fallback when CoachInsightRecord empty.
- Cross-user isolation via SQL filter (WHERE user_id = ?).
- Score floor 0.3 (BM25Okapi default scale).
- Top-k clamp.
- Corpus tokenizes BOTH topic AND summary columns.
- Case-insensitive tokenization (lowercase).
- Empty / None defenses (topic, user_id, db).
- Determinism (idempotent calls return identical lists).
"""
from __future__ import annotations

import pytest

from tests.conftest import TestingSessionLocal


@pytest.fixture
def db():
    """SQLAlchemy session against the in-memory sqlite from conftest.

    Cleans CoachInsightRecord rows (not in conftest's autouse cleanup list)
    before EACH test so BM25 corpus stays predictable across runs.
    """
    from app.models.coach_insight import CoachInsightRecord

    session = TestingSessionLocal()
    try:
        # Defensive cleanup of CoachInsightRecord (conftest autouse cleanup
        # does not include this model — added by plan-05).
        session.query(CoachInsightRecord).delete()
        session.commit()
        yield session
    finally:
        session.close()


def _add_insight(db, user_id: str, topic: str, summary: str, insight_type: str = "fact"):
    """Helper: insert a CoachInsightRecord row and commit."""
    from app.models.coach_insight import CoachInsightRecord

    rec = CoachInsightRecord(
        user_id=user_id,
        topic=topic,
        summary=summary,
        insight_type=insight_type,
    )
    db.add(rec)
    db.commit()
    return rec


def _ensure_user(db, user_id: str) -> None:
    """Create a User row with the given id so the FK constraint is satisfied."""
    from app.models import User

    existing = db.query(User).filter(User.id == user_id).first()
    if existing is not None:
        return
    db.add(
        User(
            id=user_id,
            email=f"{user_id}@example.com",
            hashed_password="x",
            display_name=user_id,
        )
    )
    db.commit()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


def test_happy_path_top_hit_is_3a_topic(db):
    """Test 1: 5 insights (2 on '3a', 3 unrelated), query '3a' returns >=2 hits all on 3a, top score >= 0.3.

    Note: BM25 IDF requires the query term to be relatively rare. With 5 insights
    in the corpus and only 2 containing '3a', IDF(3a) is high enough that scores
    cross the 0.3 floor. Plan-spec showed only 3 insights total but the IDF math
    only works with sufficient corpus diversity (Rule 1 plan deviation, documented
    in SUMMARY).
    """
    from app.services.memory.bm25 import retrieve

    _ensure_user(db, "user_a")
    _add_insight(db, "user_a", "3a", "J'ai verse 5000 CHF en pilier 3a")
    _add_insight(db, "user_a", "lpp", "LPP avoir 95k")
    _add_insight(db, "user_a", "canton", "habite a Vaud")
    _add_insight(db, "user_a", "revenu", "8000 par mois")
    _add_insight(db, "user_a", "3a", "Plafond 7258 CHF salarie 3a")

    hits = retrieve("3a", "user_a", db, k=5)

    assert len(hits) >= 2
    for h in hits:
        assert h.topic == "3a"
    assert hits[0].score >= 0.3


def test_empty_corpus_falls_back_to_profile_recent_insights(db):
    """Test 2: no CoachInsightRecord rows; ProfileModel.data recent_insights serves."""
    from app.models.profile_model import ProfileModel
    from app.services.memory.bm25 import retrieve

    _ensure_user(db, "user_a")
    profile = ProfileModel(
        user_id="user_a",
        data={
            "recent_insights": [
                {
                    "topic": "3a",
                    "summary": "Plafond 7258 CHF",
                    "created_at": "2026-05-01",
                    "insight_type": "fact",
                }
            ]
        },
    )
    db.add(profile)
    db.commit()

    hits = retrieve("3a", "user_a", db, k=5)

    assert len(hits) == 1
    assert hits[0].score == 1.0
    assert hits[0].topic == "3a"
    assert hits[0].summary == "Plafond 7258 CHF"


def test_user_isolation_at_sql_layer(db):
    """Test 3: insights from user_b never leak into user_a's results.

    user_a has 4 insights (1 on '3a', 3 filler so IDF works); user_b has
    matching shape but DIFFERENT content. The SQL filter `WHERE user_id = ?`
    must prevent user_b's rows from EVER entering user_a's BM25 corpus.
    """
    from app.services.memory.bm25 import retrieve

    _ensure_user(db, "user_a")
    _ensure_user(db, "user_b")
    _add_insight(db, "user_a", "3a", "user_a 3a secret data")
    _add_insight(db, "user_a", "lpp", "user_a lpp filler")
    _add_insight(db, "user_a", "canton", "user_a canton filler")
    _add_insight(db, "user_a", "revenu", "user_a revenu filler")
    _add_insight(db, "user_b", "3a", "user_b 3a secret data")

    hits = retrieve("3a", "user_a", db, k=5)

    assert len(hits) >= 1
    for h in hits:
        assert h.user_id == "user_a"
        assert "user_b" not in h.summary


def test_score_floor_rejects_unrelated_query(db):
    """Test 4: query with no token overlap returns no hits (BM25 score below floor)."""
    from app.services.memory.bm25 import retrieve

    _ensure_user(db, "user_a")
    _add_insight(db, "user_a", "3a", "J'ai verse 5000 CHF en 3a")
    _add_insight(db, "user_a", "lpp", "LPP avoir 95k")
    _add_insight(db, "user_a", "3a", "Plafond 7258 CHF salarie")

    hits = retrieve("totally_unrelated_xyz123", "user_a", db, k=5)

    assert hits == []


def test_top_k_clamp(db):
    """Test 5: 8 insights containing 'plafond' + 3 filler unrelated, k=5 returns exactly 5.

    BM25 IDF requires the queried term to be rare-ish. With ONLY 8 docs all
    containing the term, IDF would be 0 and all scores would be 0 (below
    floor). We insert 3 unrelated filler docs so IDF('plafond') > 0.
    """
    from app.services.memory.bm25 import retrieve

    _ensure_user(db, "user_a")
    for i in range(8):
        _add_insight(db, "user_a", "3a", f"variant {i} plafond du pilier")
    # Filler insights so IDF works (queried term must be relatively rare).
    _add_insight(db, "user_a", "lpp", "rachats lpp possibles")
    _add_insight(db, "user_a", "canton", "habite Vaud")
    _add_insight(db, "user_a", "revenu", "salaire mensuel net")

    hits = retrieve("plafond", "user_a", db, k=5)

    assert len(hits) == 5


def test_corpus_tokenizes_topic_and_summary(db):
    """Test 6: token only in summary (B) still scores positive (proves corpus covers both).

    Need >=3 unrelated docs in corpus so IDF(3a) is high enough that both
    matched rows clear the 0.3 score floor.
    """
    from app.services.memory.bm25 import retrieve

    _ensure_user(db, "user_a")
    _add_insight(db, "user_a", "3a", "random text")  # token in topic
    _add_insight(db, "user_a", "generic", "3a 3a 3a")  # token in summary only
    # Filler — boost IDF for the queried '3a' token.
    _add_insight(db, "user_a", "lpp", "LPP rachats possibles")
    _add_insight(db, "user_a", "canton", "habite a Vaud")
    _add_insight(db, "user_a", "revenu", "8000 par mois")

    hits = retrieve("3a", "user_a", db, k=5)

    summaries = {h.summary for h in hits}
    topics = {h.topic for h in hits}
    # Both rows must surface: one matched on topic, one on summary.
    assert "random text" in summaries
    assert "3a 3a 3a" in summaries
    # And the corpus must contain both topic values.
    assert {"3a", "generic"}.issubset(topics)


def test_case_insensitive_tokenization(db):
    """Test 7: query '3A' matches insights with topic '3a' (lowercases both sides).

    Need filler insights so '3a' has positive IDF and crosses the score floor.
    """
    from app.services.memory.bm25 import retrieve

    _ensure_user(db, "user_a")
    _add_insight(db, "user_a", "3a", "Plafond 7258 CHF")
    _add_insight(db, "user_a", "lpp", "rachats lpp possibles")
    _add_insight(db, "user_a", "canton", "habite Vaud")
    _add_insight(db, "user_a", "revenu", "salaire mensuel")

    hits = retrieve("3A", "user_a", db, k=5)

    assert len(hits) >= 1
    assert hits[0].topic == "3a"


def test_empty_topic_returns_empty(db):
    """Test 8: empty topic short-circuits to []."""
    from app.services.memory.bm25 import retrieve

    _ensure_user(db, "user_a")
    _add_insight(db, "user_a", "3a", "Plafond 7258 CHF")

    hits = retrieve("", "user_a", db, k=5)

    assert hits == []


def test_determinism_same_call_same_result(db):
    """Test 9: retrieve('3a', ...) twice returns identical lists (no RNG inside BM25Okapi)."""
    from app.services.memory.bm25 import retrieve

    _ensure_user(db, "user_a")
    _add_insight(db, "user_a", "3a", "J'ai verse 5000 CHF en 3a")
    _add_insight(db, "user_a", "lpp", "LPP avoir 95k")
    _add_insight(db, "user_a", "3a", "Plafond 7258 CHF salarie")

    a = retrieve("3a", "user_a", db, 5)
    b = retrieve("3a", "user_a", db, 5)

    assert a == b


def test_db_none_returns_empty(db):
    """Test 10: db=None short-circuits to [] (no exception)."""
    from app.services.memory.bm25 import retrieve

    assert retrieve("3a", "user_a", None, 5) == []


def test_user_id_none_returns_empty(db):
    """Test 11: user_id=None short-circuits to [] (no SQL fired)."""
    from app.services.memory.bm25 import retrieve

    assert retrieve("3a", None, db, 5) == []
