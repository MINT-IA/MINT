from __future__ import annotations

import importlib
import importlib.util
import re
from pathlib import Path

import pytest

from app.services.document_parser.document_models import (
    DATA_SOURCE_ACCURACY,
    DataSource,
)


REPO_ROOT = Path(__file__).resolve().parents[3]
MOBILE_PROFILE = REPO_ROOT / "apps/mobile/lib/models/coach_profile.dart"
MOBILE_CONFIDENCE_ADAPTER = (
    REPO_ROOT
    / "apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart"
)
MODULE_NAME = "app.services.confidence.source_crosswalk"

EXPECTED_MAPPINGS = {
    "estimated": DataSource.system_estimate,
    "userInput": DataSource.user_entry,
    "crossValidated": DataSource.user_entry_cross_validated,
    "certificate": DataSource.document_scan_verified,
    "openBanking": DataSource.open_banking,
}
EXPECTED_BACKEND_ONLY = frozenset(
    {
        DataSource.document_scan,
        DataSource.institutional_api,
        DataSource.user_estimate,
    }
)


def _crosswalk_module():
    assert importlib.util.find_spec(MODULE_NAME) is not None, (
        "SOURCE-01 business predicate: the authoritative source crosswalk "
        "contract is absent"
    )
    return importlib.import_module(MODULE_NAME)


def _dart_profile_data_sources() -> list[str]:
    source = MOBILE_PROFILE.read_text(encoding="utf-8")
    enum_match = re.search(
        r"enum\s+ProfileDataSource\s*\{(?P<body>.*?)\}",
        source,
        flags=re.DOTALL,
    )
    assert enum_match is not None, "ProfileDataSource enum is missing"

    members: list[str] = []
    for line in enum_match.group("body").splitlines():
        declaration = line.split("//", maxsplit=1)[0].strip().rstrip(",")
        if declaration:
            members.append(declaration)
    return members


def test_crosswalk_matches_the_complete_mobile_enum() -> None:
    module = _crosswalk_module()

    assert _dart_profile_data_sources() == list(EXPECTED_MAPPINGS)
    assert dict(module.MOBILE_TO_BACKEND_SOURCE) == EXPECTED_MAPPINGS
    assert len(module.MOBILE_TO_BACKEND_SOURCE) == len(
        _dart_profile_data_sources()
    )


def test_every_destination_is_a_living_confidence_source() -> None:
    module = _crosswalk_module()

    assert all(
        destination in DATA_SOURCE_ACCURACY
        for destination in module.MOBILE_TO_BACKEND_SOURCE.values()
    )


def test_backend_only_sources_have_no_mobile_preimage() -> None:
    module = _crosswalk_module()

    assert module.BACKEND_ONLY_SOURCES == EXPECTED_BACKEND_ONLY
    assert EXPECTED_BACKEND_ONLY.isdisjoint(
        module.MOBILE_TO_BACKEND_SOURCE.values()
    )


@pytest.mark.parametrize(
    "token",
    [
        "unknownSource",
        "document_scan",
        "institutional_api",
        "user_estimate",
    ],
)
def test_unknown_and_backend_only_mobile_tokens_fail_closed(token: str) -> None:
    module = _crosswalk_module()

    with pytest.raises(ValueError, match=re.escape(token)):
        module.backend_source_for_mobile(token)


def test_flutter_adapter_keeps_the_same_five_identities() -> None:
    adapter = MOBILE_CONFIDENCE_ADAPTER.read_text(encoding="utf-8")
    expected_pairs = {
        "estimated": "systemEstimate",
        "userInput": "userEntry",
        "crossValidated": "userEntryCrossValidated",
        "certificate": "documentScanVerified",
        "openBanking": "openBanking",
    }

    for mobile, backend in expected_pairs.items():
        assert re.search(
            rf"ProfileDataSource\.{mobile}\s*=>\s*DataSource\.{backend}",
            adapter,
        )
