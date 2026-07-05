import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCREEN_CONTRACTS = ROOT / "docs/codex/SCREEN_CONTRACTS.md"
APP_DART = ROOT / "apps/mobile/lib/app.dart"
COACH_PROFILE_PROVIDER = ROOT / "apps/mobile/lib/providers/coach_profile_provider.dart"
MOBILE_PROVENANCE_TEST = (
    ROOT / "apps/mobile/test/providers/coach_profile_provider_save_fact_mapping_test.dart"
)
BACKEND_SAVE_FACT = ROOT / "services/backend/app/api/v1/endpoints/coach_chat.py"
BACKEND_PROVENANCE_TEST = ROOT / "services/backend/tests/test_save_fact_provenance.py"

SIMULATOR_ROUTES = (
    "/rente-vs-capital",
    "/rachat-lpp",
    "/hypotheque",
    "/divorce",
    "/simulator/job-comparison",
    "/simulator/compound",
    "/simulator/leasing",
    "/simulator/credit",
)


def _route_block(source: str, path: str) -> str:
    pattern = re.compile(
        rf"(?:ScopedGoRoute|GoRoute)\s*\(\s*"
        rf"(?:\n\s*)?path:\s*['\"]{re.escape(path)}['\"]"
        rf"(?P<body>.*?)(?=\n\s*(?:ScopedGoRoute|GoRoute)\s*\(|\n\s*\]\s*,|\Z)",
        re.DOTALL,
    )
    match = pattern.search(source)
    assert match is not None, f"{path} route missing from app.dart"
    return match.group(0)


def test_screen_contracts_do_not_reference_missing_simulator_gate() -> None:
    text = SCREEN_CONTRACTS.read_text(encoding="utf-8")

    assert "test/routing/simulator_mode_switch_test.dart" not in text
    assert "tools/checks/tests/test_screen_contracts_doc_contract.py" in text


def test_simulator_routes_render_in_screen_instead_of_redirecting() -> None:
    source = APP_DART.read_text(encoding="utf-8")

    for route in SIMULATOR_ROUTES:
        block = _route_block(source, route)
        assert "builder:" in block, f"{route} must render its own screen"
        assert "redirect:" not in block, (
            f"{route} must use in-screen mode switching, not a route redirect"
        )


def test_screen_contracts_matches_live_per_field_provenance_api() -> None:
    screen_contracts = SCREEN_CONTRACTS.read_text(encoding="utf-8")
    provider = COACH_PROFILE_PROVIDER.read_text(encoding="utf-8")
    mobile_test = MOBILE_PROVENANCE_TEST.read_text(encoding="utf-8")
    backend = BACKEND_SAVE_FACT.read_text(encoding="utf-8")
    backend_test = BACKEND_PROVENANCE_TEST.read_text(encoding="utf-8")

    assert "Per-field `sourceDate` does NOT yet persist end-to-end" not in screen_contracts
    assert "Do NOT assume `sourceDate` already persists" not in screen_contracts
    assert "dataSources`/`dataTimestamps`/`dataSourceDates`" in screen_contracts

    assert "ProfileDataSource source = ProfileDataSource.userInput" in provider
    assert "DateTime? sourceDate" in provider
    assert "updatedSourceDates[fieldPath] = sourceDate" in provider
    assert "applySaveFact records source date provenance and restores it" in mobile_test

    assert 'data["_provenance"] = {' in backend
    assert 'provenance_source_dt[fact_key] = tool_input.get("source_date")' in backend
    assert "test_save_fact_persists_field_provenance" in backend_test
