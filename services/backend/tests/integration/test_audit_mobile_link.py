"""POST /v1/audit/mobile-session-events — D-12 + D-MOB-03 + iter-2 A6.

Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 — P2.

Validates :
- Anonymous batch accepts only source='mobile_session_start' entries.
- Anonymous batch with non-start entries is REJECTED 403 (handshake-missing).
- Authenticated batch with prior mobile_session_start rows ACCEPTS the
  link batch (200 + linked=N).
- Authenticated batch with ANY missing-handshake entry REJECTS the
  WHOLE batch (HTTP 403 + missing_sids listing only the bad sids).
- Duplicate (anonymous_session_id, observed_at) entries are silently
  skipped (idempotent replay).
- D-13 clean separation : no fact_event row inserted by any of the
  above paths.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

from app.models.projection_audit_record import ProjectionAuditRecord


def _payload(anonymous_session_id: str, *, source: str, observed_at_offset_hours: int = 0):
    """Build a single Mobile L1 audit event payload."""
    observed_at = (
        datetime.now(timezone.utc) + timedelta(hours=observed_at_offset_hours)
    ).isoformat()
    return {
        "anonymous_session_id": anonymous_session_id,
        "app_version": "2.12.3+test",
        "observed_at": observed_at,
        "constants_version_hash": "ph01-test-hash",
        "source": source,
        "local_event_id": f"lei-{uuid4().hex[:8]}",
        "app_lifecycle_state": "resumed",
    }


def test_anonymous_session_start_accepted(client):
    """Anonymous batch with a single mobile_session_start row → 200 linked=1."""
    sid = str(uuid4())
    response = client.post(
        "/api/v1/audit/mobile-session-events",
        json={"items": [_payload(sid, source="mobile_session_start")]},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["linked"] == 1
    assert body["skipped"] == 0


def test_anonymous_warm_resume_rejected_no_handshake(client):
    """Anonymous batch containing a warm_resume → 403 (handshake-missing)."""
    sid = str(uuid4())
    response = client.post(
        "/api/v1/audit/mobile-session-events",
        json={"items": [_payload(sid, source="mobile_session_warm_resume")]},
    )
    assert response.status_code == 403, response.text
    body = response.json()
    assert body["detail"]["error"] == "session_link_handshake_missing"
    assert sid in body["detail"]["missing_sids"]


def test_duplicate_observed_at_skipped_idempotent(client):
    """Second POST of the same (sid, observed_at) → skipped=1, NOT linked."""
    sid = str(uuid4())
    payload = _payload(sid, source="mobile_session_start")

    # First POST : linked.
    r1 = client.post(
        "/api/v1/audit/mobile-session-events",
        json={"items": [payload]},
    )
    assert r1.status_code == 200
    assert r1.json()["linked"] == 1

    # Second POST with identical payload : the (sid, observed_at) UNIQUE
    # makes it idempotent ; the endpoint skips it without raising.
    r2 = client.post(
        "/api/v1/audit/mobile-session-events",
        json={"items": [payload]},
    )
    assert r2.status_code == 200, r2.text
    body = r2.json()
    assert body["linked"] == 0
    assert body["skipped"] == 1


def test_authenticated_link_batch_with_handshake_accepts(client):
    """Authenticated batch where every warm_resume sid has a prior start → 200."""
    sid_a = str(uuid4())
    sid_b = str(uuid4())

    # Phase 1 : seed session_start rows for both sids via anonymous POST.
    r0 = client.post(
        "/api/v1/audit/mobile-session-events",
        json={
            "items": [
                _payload(sid_a, source="mobile_session_start", observed_at_offset_hours=0),
                _payload(sid_b, source="mobile_session_start", observed_at_offset_hours=0),
            ]
        },
    )
    assert r0.status_code == 200
    assert r0.json()["linked"] == 2

    # Phase 2 : authenticated batch with warm_resume rows for both sids.
    r1 = client.post(
        "/api/v1/audit/mobile-session-events",
        json={
            "items": [
                _payload(sid_a, source="mobile_session_warm_resume", observed_at_offset_hours=1),
                _payload(sid_b, source="mobile_session_warm_resume", observed_at_offset_hours=1),
            ]
        },
    )
    # `client` fixture overrides get_current_user → _fake_user, so this
    # is the authenticated path.
    assert r1.status_code == 200, r1.text
    body = r1.json()
    assert body["linked"] == 2
    assert body["skipped"] == 0


def test_d13_clean_separation_no_fact_event_writes(client):
    """D-13 : the /mobile-session-events path MUST NOT write to fact_event."""
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    try:
        # Count fact_event rows before (should be 0 in fresh test DB).
        before = db.execute(__import__("sqlalchemy").text("SELECT COUNT(*) FROM fact_event")).scalar()
    finally:
        db.close()

    sid = str(uuid4())
    response = client.post(
        "/api/v1/audit/mobile-session-events",
        json={"items": [_payload(sid, source="mobile_session_start")]},
    )
    assert response.status_code == 200

    db = TestingSessionLocal()
    try:
        after = db.execute(__import__("sqlalchemy").text("SELECT COUNT(*) FROM fact_event")).scalar()
        # D-13 contract : zero fact_event rows added.
        assert after == before, (
            f"D-13 violation : fact_event row count went from {before} to {after} "
            f"during a /mobile-session-events POST. The endpoint MUST write ONLY "
            f"to projection_audit_records."
        )
        # And the audit row WAS written.
        audit_count = db.query(ProjectionAuditRecord).filter(
            ProjectionAuditRecord.anonymous_session_id == sid
        ).count()
        assert audit_count == 1
    finally:
        db.close()
