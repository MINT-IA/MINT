from __future__ import annotations

from datetime import datetime, timezone

from app.api.v1.endpoints.coach_chat import _execute_internal_tool
from app.models.profile_model import ProfileModel
from app.services.confidence.source_crosswalk import mobile_source_to_backend
from app.services.document_parser.document_models import DATA_SOURCE_ACCURACY, DataSource


def test_mobile_source_crosswalk_maps_all_allowed_values() -> None:
    assert mobile_source_to_backend("estimated") == DataSource.system_estimate
    assert mobile_source_to_backend("userInput") == DataSource.user_entry
    assert mobile_source_to_backend("crossValidated") == DataSource.user_entry_cross_validated
    assert mobile_source_to_backend("certificate") == DataSource.document_scan_verified
    assert mobile_source_to_backend("openBanking") == DataSource.open_banking

    for mobile_name in (
        "estimated",
        "userInput",
        "crossValidated",
        "certificate",
        "openBanking",
    ):
        assert mobile_source_to_backend(mobile_name) in DATA_SOURCE_ACCURACY


def test_mobile_source_crosswalk_falls_back_for_missing_or_unknown_source() -> None:
    assert mobile_source_to_backend(None) == DataSource.user_entry
    assert mobile_source_to_backend("") == DataSource.user_entry
    assert mobile_source_to_backend("legacyScan") == DataSource.user_entry


def test_save_fact_persists_field_provenance(client) -> None:
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    try:
        profile = ProfileModel(
            user_id="test-user-id",
            data={},
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        db.add(profile)
        db.commit()

        result = _execute_internal_tool(
            {
                "name": "save_fact",
                "input": {
                    "key": "canton",
                    "value": "VD",
                    "confidence": "high",
                    "source": "certificate",
                    "source_date": "2026-01-31",
                },
            },
            memory_block=None,
            user_id="test-user-id",
            db=db,
        )

        assert "Fait enregistré" in result
        db.refresh(profile)
        data = profile.data
        assert data["canton"] == "VD"
        assert data["_provenance"]["sources"]["canton"] == "document_scan_verified"
        assert data["_provenance"]["source_dt"]["canton"] == "2026-01-31"
        updated = data["_provenance"]["updated"]["canton"]
        assert datetime.fromisoformat(updated.replace("Z", "+00:00"))
    finally:
        db.close()


def test_save_fact_persists_user_entry_for_unknown_source(client) -> None:
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    try:
        profile = ProfileModel(
            user_id="test-user-unknown-source",
            data={},
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        db.add(profile)
        db.commit()

        result = _execute_internal_tool(
            {
                "name": "save_fact",
                "input": {
                    "key": "canton",
                    "value": "VD",
                    "confidence": "high",
                    "source": "legacyScan",
                },
            },
            memory_block=None,
            user_id="test-user-unknown-source",
            db=db,
        )

        assert "Fait enregistré" in result
        db.refresh(profile)
        assert profile.data["_provenance"]["sources"]["canton"] == "user_entry"
    finally:
        db.close()
