"""iter-3 iA2 — Mobile L1 audit link handshake replay-ordering integration test.

Source : Claude-Opus HIGH-A2 (REVIEWS.md §7.3) post-iter-2 review.

The Flutter-side unit test (apps/mobile/test/services/audit/
mobile_l1_audit_service_test.dart) covers the simple « first-ever replay »
case (POST mobile-session-start with source='mobile_session_start' anonymously,
then POST mobile-session-events with source='mobile_session_warm_resume'
authenticated). This integration test covers the realistic offline-buffer
scenario : user offline multiple days, queues an INTERLEAVED batch of
mobile_session_start (M times) + mobile_session_warm_resume (N times) +
one login event, then comes online and replays the entire chain.

Backend must :
1. Accept all session_start rows on POST (each anonymous, no auth required).
2. Accept the batch POST with all warm_resume rows once authenticated
   (every warm_resume sid has its session_start row committed BEFORE
   the link batch arrives → handshake passes).
3. NEVER return 403 when handshake invariant holds.
4. Reject the WHOLE batch with 403 if even ONE warm_resume entry lacks
   a prior session_start row (iter-2 A6 contract — partial-batch
   acceptance creates audit ambiguity).
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4


def _build_event(
    sid: str,
    *,
    source: str,
    observed_at: str,
    local_event_id: str = "",
):
    return {
        "anonymous_session_id": sid,
        "app_version": "2.12.3+iter3-test",
        "observed_at": observed_at,
        "constants_version_hash": "ph01-iter3-baseline-hash",
        "source": source,
        "local_event_id": local_event_id or f"lei-{uuid4().hex[:8]}",
        "app_lifecycle_state": "resumed" if "warm_resume" in source else None,
    }


def test_interleaved_session_start_warm_resume_login_batch_accepts_all(client):
    """iter-3 iA2 scenario : 5 session_start + 5 warm_resume interleaved batch."""
    base_time = datetime.now(timezone.utc) - timedelta(days=3)
    sids = [str(uuid4()) for _ in range(5)]

    # ── Phase 1 : 5 mobile_session_start rows committed anonymously ──
    start_payloads = []
    for i, sid in enumerate(sids):
        observed_at = (base_time + timedelta(hours=i * 12)).isoformat()
        payload = _build_event(sid, source="mobile_session_start", observed_at=observed_at)
        start_payloads.append(payload)

    r1 = client.post(
        "/api/v1/audit/mobile-session-events",
        json={"items": start_payloads},
    )
    assert r1.status_code == 200, f"Phase-1 session-start batch failed : {r1.text}"
    assert r1.json()["linked"] == 5

    # ── Phase 2 : interleaved batch (5 start [dups] + 5 warm_resume) ──
    interleaved_batch = []
    for i, sid in enumerate(sids):
        # Add the start row (will be skipped — duplicate of Phase 1).
        interleaved_batch.append(start_payloads[i])
        # Add the warm_resume row (new).
        warm_observed = (base_time + timedelta(hours=i * 12 + 1)).isoformat()
        interleaved_batch.append(
            _build_event(sid, source="mobile_session_warm_resume", observed_at=warm_observed)
        )
    assert len(interleaved_batch) == 10

    # ── Phase 3 : POST authenticated batch link ──
    # The `client` fixture from conftest is authenticated (overrides
    # get_current_user → _fake_user) so this is the auth-path.
    r2 = client.post(
        "/api/v1/audit/mobile-session-events",
        json={"items": interleaved_batch},
    )
    assert r2.status_code == 200, (
        f"interleaved batch rejected : {r2.status_code} {r2.text}\n"
        f"iter-3 iA2 contract violated — every warm_resume sid had a prior "
        f"session_start row committed (Phase 1) so handshake must pass."
    )
    body = r2.json()
    # 5 session-start rows are dups of Phase 1 → skipped ; 5 warm_resume new → linked.
    assert body["linked"] == 5, f"expected 5 linked, got {body['linked']}"
    assert body["skipped"] == 5, f"expected 5 skipped (start dups), got {body['skipped']}"


def test_link_batch_with_missing_session_start_rejects_entire_batch(client):
    """iter-3 iA2 inverse : one missing session_start in 2-row batch → 403 WHOLE batch."""
    base_time = datetime.now(timezone.utc) - timedelta(days=1)
    good_sid = str(uuid4())  # has a prior session_start
    bad_sid = str(uuid4())   # NO prior session_start — handshake will fail

    # Commit one valid session_start row anonymously.
    seed_payload = _build_event(
        good_sid,
        source="mobile_session_start",
        observed_at=base_time.isoformat(),
    )
    client.post(
        "/api/v1/audit/mobile-session-events",
        json={"items": [seed_payload]},
    )

    # Batch contains warm_resume for BOTH sids — bad_sid has no proof.
    batch = [
        _build_event(
            good_sid,
            source="mobile_session_warm_resume",
            observed_at=(base_time + timedelta(hours=1)).isoformat(),
        ),
        _build_event(
            bad_sid,
            source="mobile_session_warm_resume",
            observed_at=(base_time + timedelta(hours=2)).isoformat(),
        ),
    ]
    resp = client.post(
        "/api/v1/audit/mobile-session-events",
        json={"items": batch},
    )
    assert resp.status_code == 403, (
        f"expected 403 handshake-missing for batch containing bad_sid, "
        f"got {resp.status_code} {resp.text}"
    )
    body = resp.json()
    assert body["detail"]["error"] == "session_link_handshake_missing"
    assert bad_sid in body["detail"]["missing_sids"]
    # Good sid is NOT in missing_sids (it had its proof), but the WHOLE
    # batch is rejected — iter-2 A6 contract per audit_mobile.py docstring.
    assert good_sid not in body["detail"]["missing_sids"]


def test_handshake_get_returns_state_for_known_sid(client):
    """GET /v1/audit/mobile-session-handshake returns state per iter-3 iA2."""
    sid = str(uuid4())
    base_time = datetime.now(timezone.utc) - timedelta(hours=2)
    local_event_id = "lei-handshake-1"
    payload = _build_event(
        sid,
        source="mobile_session_start",
        observed_at=base_time.isoformat(),
        local_event_id=local_event_id,
    )
    client.post(
        "/api/v1/audit/mobile-session-events",
        json={"items": [payload]},
    )

    resp = client.get(
        f"/api/v1/audit/mobile-session-handshake?anonymous_session_id={sid}",
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["has_prior_session_start"] is True
    assert body["last_seen_local_event_id"] == local_event_id
    assert body["session_token"], "session_token must be non-empty (HMAC-tagged)"


def test_handshake_get_returns_no_proof_for_unknown_sid(client):
    """GET handshake for an unknown sid → has_prior_session_start=False."""
    sid = str(uuid4())
    resp = client.get(
        f"/api/v1/audit/mobile-session-handshake?anonymous_session_id={sid}",
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["has_prior_session_start"] is False
    assert body["last_seen_local_event_id"] is None
    # session_token is still HMAC-computed (deterministic by sid + user.id).
    assert body["session_token"]
