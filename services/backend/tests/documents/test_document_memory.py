"""Phase 28-01 / Task 3b-c: DocumentMemory ORM + service tests."""
from __future__ import annotations

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models import User, DocumentMemory  # noqa: F401 — register tables
from app.schemas.document_understanding import (
    ConfidenceLevel,
    DocumentClass,
    DocumentUnderstandingResult,
    ExtractedField,
    ExtractionStatus,
    RenderMode,
)
from app.services.document_memory_service import (
    compute_fingerprint,
    upsert_and_diff,
)


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:", future=True)
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, future=True)
    session = Session()
    # Insert two users so FK constraints (if SQLite enforces them) are satisfied
    from app.models.user import User
    u1 = User(id="user-julien", email="j@example.com", hashed_password="x")
    u2 = User(id="user-lauren", email="l@example.com", hashed_password="x")
    session.add_all([u1, u2])
    session.commit()
    yield session
    session.close()
    engine.dispose()


def _make_result(
    *,
    issuer: str | None = "CPE",
    fields: list[tuple[str, float]] | None = None,
) -> DocumentUnderstandingResult:
    fields = fields or [("avoirLppTotal", 70377.0), ("salaireAssure", 91967.0)]
    return DocumentUnderstandingResult(
        document_class=DocumentClass.lpp_certificate,
        classification_confidence=0.95,
        issuer_guess=issuer,
        extracted_fields=[
            ExtractedField(field_name=n, value=v, confidence=ConfidenceLevel.high, source_text=str(v))
            for n, v in fields
        ],
        overall_confidence=0.92,
        extraction_status=ExtractionStatus.success,
        render_mode=RenderMode.confirm,
    )


def test_compute_fingerprint_deterministic():
    a = compute_fingerprint("lpp_certificate", "CPE", None)
    b = compute_fingerprint("lpp_certificate", "CPE", None)
    assert a == b
    assert len(a) == 32


def test_compute_fingerprint_changes_with_issuer():
    a = compute_fingerprint("lpp_certificate", "CPE", None)
    b = compute_fingerprint("lpp_certificate", "Swisscanto", None)
    assert a != b


def test_first_upload_returns_no_diff(db_session):
    result = _make_result()
    diff = upsert_and_diff(db_session, "user-julien", result)
    assert diff is None
    rows = db_session.query(DocumentMemory).all()
    assert len(rows) == 1
    assert rows[0].user_id == "user-julien"
    assert rows[0].issuer == "CPE"
    assert len(rows[0].field_history) == 1


def test_second_upload_returns_diff_with_delta_pct(db_session):
    # First upload: avoir=70377
    upsert_and_diff(db_session, "user-julien", _make_result(
        fields=[("avoirLppTotal", 70377.0), ("salaireAssure", 91967.0)],
    ))
    # Second upload: avoir grew to 80224 (+13.99%), salary unchanged
    diff = upsert_and_diff(db_session, "user-julien", _make_result(
        fields=[("avoirLppTotal", 80224.0), ("salaireAssure", 91967.0)],
    ))
    assert diff is not None
    assert "avoirLppTotal" in diff
    assert "salaireAssure" not in diff  # unchanged → omitted
    delta = diff["avoirLppTotal"]
    assert delta.old == 70377.0
    assert delta.new == 80224.0
    assert delta.delta_pct is not None
    assert 13.0 < delta.delta_pct < 14.5

    # History should have two entries on the same row
    rows = db_session.query(DocumentMemory).all()
    assert len(rows) == 1
    assert len(rows[0].field_history) == 2


def test_cross_user_isolation(db_session):
    upsert_and_diff(db_session, "user-julien", _make_result(
        fields=[("avoirLppTotal", 70377.0)],
    ))
    diff = upsert_and_diff(db_session, "user-lauren", _make_result(
        fields=[("avoirLppTotal", 19620.0)],
    ))
    # Lauren's first upload → no diff (separate row)
    assert diff is None
    rows = db_session.query(DocumentMemory).all()
    assert len(rows) == 2
    user_ids = {r.user_id for r in rows}
    assert user_ids == {"user-julien", "user-lauren"}


def test_diff_omits_unchanged_fields(db_session):
    upsert_and_diff(db_session, "user-julien", _make_result(
        fields=[("a", 100.0), ("b", 200.0)],
    ))
    diff = upsert_and_diff(db_session, "user-julien", _make_result(
        fields=[("a", 100.0), ("b", 200.0)],
    ))
    # Identical → diff is None (no changed fields)
    assert diff is None


def test_diff_handles_added_and_removed_fields(db_session):
    upsert_and_diff(db_session, "user-julien", _make_result(
        fields=[("a", 100.0)],
    ))
    diff = upsert_and_diff(db_session, "user-julien", _make_result(
        fields=[("b", 200.0)],
    ))
    assert diff is not None
    assert "a" in diff and diff["a"].new is None
    assert "b" in diff and diff["b"].old is None
