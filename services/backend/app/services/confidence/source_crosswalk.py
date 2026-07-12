"""Fail-closed translation between mobile and backend provenance names."""

from __future__ import annotations

from types import MappingProxyType
from typing import Mapping

from app.services.document_parser.document_models import DataSource


MOBILE_TO_BACKEND_SOURCE: Mapping[str, DataSource] = MappingProxyType(
    {
        "estimated": DataSource.system_estimate,
        "userInput": DataSource.user_entry,
        "crossValidated": DataSource.user_entry_cross_validated,
        "certificate": DataSource.document_scan_verified,
        "openBanking": DataSource.open_banking,
    }
)

BACKEND_ONLY_SOURCES = frozenset(
    {
        DataSource.document_scan,
        DataSource.institutional_api,
        DataSource.user_estimate,
    }
)


def backend_source_for_mobile(source_token: str) -> DataSource:
    """Return the backend provenance identity for one mobile source token."""
    try:
        return MOBILE_TO_BACKEND_SOURCE[source_token]
    except KeyError:
        raise ValueError(f"Unmapped mobile source token: {source_token}") from None
