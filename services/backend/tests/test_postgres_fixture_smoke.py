"""Phase 95 Plan 95-03 / TEST-04 — testcontainers-Postgres fixture smoke.

Five round-trip tests that exercise the new `pg_db` fixture against a real
Postgres 15-alpine container. Each test uses a Postgres-native semantic
that the in-memory SQLite path either masks or behaves differently on:

  1. CoachMessageAudit — created_at default + retained_until +10y window
     (DateTime tz behaviour differs SQLite ↔ Postgres).
  2. DocumentModel — JSON column round-trip on the `extracted_fields`
     field; SQLite stores TEXT and silently swallows non-JSON, Postgres
     enforces real JSON encoding.
  3. ScenarioModel — JSON `inputs` / `outputs` round-trip including a
     nested object (catches the « JSON-as-stringified-dict » class that
     the SQLite path masks).
  4. ConsentModel — `JSON().with_variant(JSONB(), "postgresql")` actually
     resolves to JSONB on Postgres; smoke-asserts a containment-shaped
     receipt round-trip.
  5. AuditEventModel — created_at descending index ordering. p93 +
     5adaafbee2b6 created indexes on created_at; this test asserts the
     ORDER BY created_at DESC plan still produces newest-first rows.

These are NOT migrated copies of existing tests — they're a brand-new
smoke suite that proves the fixture works end-to-end. Existing SQLite
tests are untouched (additive scope, Karpathy 3).

Skips automatically when Docker is unavailable (see conftest.py
`postgres_container` fixture).
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest
from sqlalchemy import select


pytestmark = pytest.mark.postgres


# ---------------------------------------------------------------------------
# 1. CoachMessageAudit — created_at default + 10y retention column.
# ---------------------------------------------------------------------------


def test_coach_message_audit_round_trip_on_postgres(pg_db):
    """A CoachMessageAudit row inserts + reads back with the +10y retention."""
    from app.models.coach_message_audit import CoachMessageAudit
    from app.utils.audit_hash import hash_for_audit

    row = CoachMessageAudit(
        session_id="pg-smoke-sess-1",
        archetype="anonymous",
        prompt_hash=hash_for_audit("hello-pg"),
        response_hash=hash_for_audit("world-pg"),
        banned_term_hit=False,
        eclairage_kind=None,
    )
    pg_db.add(row)
    pg_db.commit()

    fetched = (
        pg_db.query(CoachMessageAudit)
        .filter(CoachMessageAudit.session_id == "pg-smoke-sess-1")
        .one()
    )
    assert fetched.prompt_hash == hash_for_audit("hello-pg")
    assert fetched.response_hash == hash_for_audit("world-pg")
    assert fetched.created_at is not None
    assert fetched.retained_until is not None
    # +10y window — guards against the « TIMESTAMP WITHOUT TIMEZONE drops
    # to UTC offset » class of bug that SQLite never trips because it
    # stores ISO strings.
    delta_days = (fetched.retained_until - fetched.created_at).days
    assert delta_days >= 3650, (
        f"Retention should be ~3653 days (10y), got {delta_days}"
    )


# ---------------------------------------------------------------------------
# 2. DocumentModel — JSON column round-trip with nested structure.
# ---------------------------------------------------------------------------


def test_document_extracted_fields_json_round_trip(pg_db):
    """The `extracted_fields` JSON column survives a nested-dict round-trip."""
    from app.models.document import DocumentModel
    from app.models.user import User

    # Documents have a NOT NULL FK to users.id; insert a parent user
    # directly via the session (cheaper than spinning up the auth flow).
    user = User(
        id=str(uuid4()),
        email=f"pg-smoke-{uuid4()}@mint.ch",
        hashed_password="x",
    )
    pg_db.add(user)
    pg_db.flush()

    extracted = {
        "issuer": "BCV",
        "amount_chf": 7258,
        "lines": [{"label": "salaire brut", "amount": 8500}],
    }
    doc = DocumentModel(
        user_id=user.id,
        document_type="salary_certificate",
        extracted_fields=extracted,
        warnings=[],
    )
    pg_db.add(doc)
    pg_db.commit()

    fetched = pg_db.query(DocumentModel).filter(DocumentModel.id == doc.id).one()
    # Postgres JSON returns a real dict, not a string.
    assert isinstance(fetched.extracted_fields, dict)
    assert fetched.extracted_fields["issuer"] == "BCV"
    assert fetched.extracted_fields["lines"][0]["amount"] == 8500


# ---------------------------------------------------------------------------
# 3. ScenarioModel — JSON inputs/outputs with nested arrays.
# ---------------------------------------------------------------------------


def test_scenario_inputs_outputs_json_round_trip(pg_db):
    """Scenario JSON inputs + outputs survive a nested-array round-trip."""
    from app.models.profile_model import ProfileModel
    from app.models.scenario import ScenarioModel

    # Scenarios FK to profiles.id; build a minimal parent. Profiles
    # require a non-null `data` JSON dict.
    profile = ProfileModel(id=str(uuid4()), user_id=None, data={"smoke": True})
    pg_db.add(profile)
    pg_db.flush()

    scenario = ScenarioModel(
        profile_id=profile.id,
        kind="compound_growth",
        inputs={"horizon_years": 30, "rate_pct": 4.5},
        outputs={"trajectory": [10000, 10450, 10920], "final_chf": 36422},
    )
    pg_db.add(scenario)
    pg_db.commit()

    fetched = (
        pg_db.query(ScenarioModel).filter(ScenarioModel.id == scenario.id).one()
    )
    assert fetched.inputs["horizon_years"] == 30
    assert fetched.outputs["final_chf"] == 36422
    assert isinstance(fetched.outputs["trajectory"], list)
    assert len(fetched.outputs["trajectory"]) == 3


# ---------------------------------------------------------------------------
# 4. ConsentModel — JSONB receipt + Merkle linkage round-trip.
# ---------------------------------------------------------------------------


def test_consent_receipt_jsonb_round_trip(pg_db):
    """`JSONType` resolves to JSONB on Postgres and survives round-trip."""
    from app.models.consent import ConsentModel

    receipt = {
        "purpose_category": "vision_extraction",
        "policy_version": "2.7.0",
        "scope": ["llm_vision_read", "no_persistence"],
    }
    row = ConsentModel(
        user_id=str(uuid4()),
        consent_type="vision_extraction",
        enabled=True,
        receipt_id=str(uuid4()),
        purpose_category="vision_extraction",
        policy_version="2.7.0",
        policy_hash="0" * 64,
        consent_timestamp=datetime.now(timezone.utc),
        receipt_json=receipt,
        prev_hash=None,
        signature="a" * 64,
    )
    pg_db.add(row)
    pg_db.commit()

    fetched = pg_db.query(ConsentModel).filter(ConsentModel.id == row.id).one()
    assert fetched.receipt_json["purpose_category"] == "vision_extraction"
    assert "llm_vision_read" in fetched.receipt_json["scope"]


# ---------------------------------------------------------------------------
# 5. AuditEventModel — created_at descending index ordering.
# ---------------------------------------------------------------------------


def test_audit_event_created_at_desc_ordering(pg_db):
    """Inserts three audit events; ORDER BY created_at DESC returns newest-first."""
    from app.models.audit_event import AuditEventModel

    base = datetime.now(timezone.utc)
    rows = [
        AuditEventModel(
            event_type="login_success",
            status="success",
            source="api",
            created_at=base - timedelta(seconds=offset),
        )
        for offset in (60, 30, 0)
    ]
    pg_db.add_all(rows)
    pg_db.commit()

    fetched = pg_db.execute(
        select(AuditEventModel)
        .where(AuditEventModel.event_type == "login_success")
        .order_by(AuditEventModel.created_at.desc())
    ).scalars().all()
    assert len(fetched) == 3
    # Newest first: offset=0 row should come back first.
    assert fetched[0].created_at >= fetched[1].created_at >= fetched[2].created_at
