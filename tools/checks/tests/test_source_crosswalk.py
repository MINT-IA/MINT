import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "services/backend"))

from app.services.confidence.source_crosswalk import mobile_source_to_backend
from app.services.document_parser.document_models import DataSource


COACH_PROFILE = ROOT / "apps/mobile/lib/models/coach_profile.dart"

EXPECTED = {
    "estimated": DataSource.system_estimate,
    "userInput": DataSource.user_entry,
    "crossValidated": DataSource.user_entry_cross_validated,
    "certificate": DataSource.document_scan_verified,
    "openBanking": DataSource.open_banking,
}


def _mobile_profile_data_sources() -> set[str]:
    text = COACH_PROFILE.read_text(encoding="utf-8")
    match = re.search(r"enum\s+ProfileDataSource\s*\{(?P<body>[^}]+)\}", text)
    assert match, "ProfileDataSource enum not found"
    values: set[str] = set()
    for raw_line in match.group("body").splitlines():
        line = raw_line.split("//", 1)[0].strip().strip(",")
        if line:
            values.add(line)
    return values


def test_every_mobile_profile_data_source_has_backend_crosswalk() -> None:
    assert _mobile_profile_data_sources() == set(EXPECTED)

    for mobile_source, backend_source in EXPECTED.items():
        assert mobile_source_to_backend(mobile_source) is backend_source


def test_certificate_and_user_input_mappings_are_explicit() -> None:
    assert mobile_source_to_backend("certificate") is DataSource.document_scan_verified
    assert mobile_source_to_backend("userInput") is DataSource.user_entry


def test_unknown_and_missing_mobile_sources_degrade_to_user_entry() -> None:
    assert mobile_source_to_backend(None) is DataSource.user_entry
    assert mobile_source_to_backend("") is DataSource.user_entry
    assert mobile_source_to_backend("futureSource") is DataSource.user_entry
