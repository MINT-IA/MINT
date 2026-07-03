"""Crosswalk between mobile and backend provenance source enums."""

from __future__ import annotations

from app.services.document_parser.document_models import DataSource


_MOBILE_TO_BACKEND: dict[str, DataSource] = {
    "estimated": DataSource.system_estimate,
    "userInput": DataSource.user_entry,
    "crossValidated": DataSource.user_entry_cross_validated,
    "certificate": DataSource.document_scan_verified,
    "openBanking": DataSource.open_banking,
}


def mobile_source_to_backend(source: str | None) -> DataSource:
    """Map a mobile ProfileDataSource name to backend DataSource."""
    if not source:
        return DataSource.user_entry
    return _MOBILE_TO_BACKEND.get(source, DataSource.user_entry)
