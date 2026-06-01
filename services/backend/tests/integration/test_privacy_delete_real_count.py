"""D-16 / Plan 02-02 P1 — `/privacy/delete` returns REAL DSAR row counts.

Pre-Plan-02-02 the endpoint hardcoded `nb_sessions=0, nb_reports=0,
nb_documents=0, nb_analytics=0` while only counting `coach_insights`. The
nLPD art. 32 « manifest of what was deleted » contract requires truthful
counts ; this test seeds a known number of rows per table for the
authenticated user, calls `/privacy/delete`, and asserts each
`nombre_supprime` matches the seeded count.

Test pattern : SQLite via the conftest `client` fixture (in-memory). The
`_fake_user` override gives `user.id == "test-user-id"`.

References :
- CONTEXT.md D-16 « /privacy/delete real DSAR count »
- services/backend/app/api/v1/endpoints/privacy.py:286-330 (post-Plan-02-02 patch)
- services/backend/tests/conftest.py:35-65 (client + _fake_user override)
"""
from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4


from app.models.analytics_event import AnalyticsEvent
from app.models.coach_insight import CoachInsightRecord
from app.models.document import DocumentModel
from app.models.profile_model import ProfileModel
from app.models.session_model import SessionModel
from app.models.snapshot import SnapshotModel
from app.models.user import User


_FAKE_USER_ID = "test-user-id"  # matches conftest._fake_user.id


def _seed_user_row(db) -> User:
    """Insert the User row that ProfileModel.user_id FK requires."""
    existing = db.query(User).filter(User.id == _FAKE_USER_ID).one_or_none()
    if existing is not None:
        return existing
    user = User(
        id=_FAKE_USER_ID,
        email="test@mint.ch",
        hashed_password="x",
        email_verified=True,
        created_at=datetime.now(timezone.utc),
    )
    db.add(user)
    db.commit()
    return user


def _seed_privacy_fixtures(
    db,
    *,
    nb_sessions: int,
    nb_reports: int,
    nb_documents: int,
    nb_analytics: int,
    nb_coach_insights: int,
) -> None:
    """Insert exactly N rows of each kind for the test user."""
    _seed_user_row(db)

    # ProfileModel — sessions FK on profile.id which itself FKs to user.id
    profile = ProfileModel(id=str(uuid4()), user_id=_FAKE_USER_ID, data={})
    db.add(profile)
    db.commit()

    for _ in range(nb_sessions):
        db.add(SessionModel(id=str(uuid4()), profile_id=profile.id, data={}))
    for _ in range(nb_reports):
        db.add(
            SnapshotModel(
                id=str(uuid4()),
                user_id=_FAKE_USER_ID,
                created_at=datetime.now(timezone.utc),
                trigger="test",
            )
        )
    for _ in range(nb_documents):
        db.add(
            DocumentModel(
                id=str(uuid4()),
                user_id=_FAKE_USER_ID,
                document_type="lpp_cpe",
                upload_date=datetime.now(timezone.utc),
                confidence=0.8,
            )
        )
    for i in range(nb_analytics):
        db.add(
            AnalyticsEvent(
                user_id=_FAKE_USER_ID,
                event_name=f"test_event_{i}",
                event_category="test",
                timestamp=datetime.now(timezone.utc),
            )
        )
    for i in range(nb_coach_insights):
        db.add(
            CoachInsightRecord(
                id=str(uuid4()),
                user_id=_FAKE_USER_ID,
                topic=f"topic_{i}",
                summary="...",
                insight_type="observation",
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc),
            )
        )
    db.commit()


def test_privacy_delete_returns_real_session_count(client) -> None:
    """Seed N sessions ; assert manifest counts N (not 0)."""
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    try:
        _seed_privacy_fixtures(
            db,
            nb_sessions=3,
            nb_reports=0,
            nb_documents=0,
            nb_analytics=0,
            nb_coach_insights=0,
        )
    finally:
        db.close()

    resp = client.post("/api/v1/privacy/delete", json={"mode": "grace_period", "raison": "test"})
    assert resp.status_code == 200, resp.text
    body = resp.json()
    # camelCase wire shape per PrivacyResponse Pydantic alias_generator
    cats = {c["categorie"]: c["nombreSupprime"] for c in body["categoriesTraitees"]}
    assert cats.get("sessions") == 3, (
        f"expected 3 sessions in manifest (REAL count), got {cats.get('sessions')} ; cats={cats}"
    )


def test_privacy_delete_returns_real_snapshot_count(client) -> None:
    """Seed N snapshots ; assert manifest « rapports » category counts N."""
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    try:
        _seed_privacy_fixtures(
            db,
            nb_sessions=0,
            nb_reports=5,
            nb_documents=0,
            nb_analytics=0,
            nb_coach_insights=0,
        )
    finally:
        db.close()

    resp = client.post("/api/v1/privacy/delete", json={"mode": "grace_period", "raison": "test"})
    assert resp.status_code == 200, resp.text
    body = resp.json()
    cats = {c["categorie"]: c["nombreSupprime"] for c in body["categoriesTraitees"]}
    assert cats.get("rapports") == 5, (
        f"expected 5 rapports in manifest (REAL count), got {cats.get('rapports')} ; cats={cats}"
    )


def test_privacy_delete_returns_real_document_and_analytics_counts(client) -> None:
    """Seed N docs + M analytics ; assert each category reflects its count."""
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    try:
        _seed_privacy_fixtures(
            db,
            nb_sessions=0,
            nb_reports=0,
            nb_documents=2,
            nb_analytics=7,
            nb_coach_insights=0,
        )
    finally:
        db.close()

    resp = client.post("/api/v1/privacy/delete", json={"mode": "grace_period", "raison": "test"})
    assert resp.status_code == 200, resp.text
    body = resp.json()
    cats = {c["categorie"]: c["nombreSupprime"] for c in body["categoriesTraitees"]}
    assert cats.get("documents") == 2, (
        f"expected 2 documents, got {cats.get('documents')} ; cats={cats}"
    )
    assert cats.get("analytics") == 7, (
        f"expected 7 analytics, got {cats.get('analytics')} ; cats={cats}"
    )


def test_privacy_delete_zero_seed_returns_zero_user_data(client) -> None:
    """No user data seeded ; manifest may still include core_profile (legal
    obligation conservation row) but must NOT inflate nb_sessions etc."""
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    try:
        _seed_user_row(db)  # User row only, no children
    finally:
        db.close()

    resp = client.post("/api/v1/privacy/delete", json={"mode": "grace_period", "raison": "test"})
    assert resp.status_code == 200, resp.text
    body = resp.json()
    cats = {c["categorie"]: c["nombreSupprime"] for c in body["categoriesTraitees"]}
    # All user-data categories (sessions/rapports/documents/analytics/coach_insights)
    # must be 0 when nothing was seeded. core_profile is allowed to be ≥1
    # (it's the legal-conservation pseudo-row, not user data).
    for cat in ("sessions", "rapports", "documents", "analytics", "coach_insights"):
        assert cats.get(cat, 0) == 0, (
            f"expected 0 for {cat} (none seeded), got {cats.get(cat)} ; cats={cats}"
        )
