import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCREEN_CONTRACTS = ROOT / "docs/codex/SCREEN_CONTRACTS.md"
APP_DART = ROOT / "apps/mobile/lib/app.dart"
DATA_BLOCK_SCREEN = (
    ROOT / "apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart"
)
COACH_PROFILE_PROVIDER = ROOT / "apps/mobile/lib/providers/coach_profile_provider.dart"
MOBILE_PROVENANCE_TEST = (
    ROOT / "apps/mobile/test/providers/coach_profile_provider_save_fact_mapping_test.dart"
)
BACKEND_SAVE_FACT = ROOT / "services/backend/app/api/v1/endpoints/coach_chat.py"
BACKEND_PROVENANCE_TEST = ROOT / "services/backend/tests/test_save_fact_provenance.py"
FINANCIAL_REPORT_SCREEN = (
    ROOT / "apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart"
)
LEGACY_REDIRECT_TEST = ROOT / "apps/mobile/test/routing/legacy_redirect_query_preservation_test.dart"

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


def test_data_block_route_does_not_silently_default_to_revenu() -> None:
    app = APP_DART.read_text(encoding="utf-8")
    screen_contracts = SCREEN_CONTRACTS.read_text(encoding="utf-8")
    data_block_screen = DATA_BLOCK_SCREEN.read_text(encoding="utf-8")
    block = _route_block(app, "/data-block/:type")

    assert "?? 'revenu'" not in block
    assert '?? "revenu"' not in block
    assert "state.pathParameters['type']!" in block
    assert "The current builder does `state.pathParameters['type'] ?? 'revenu'`" not in screen_contracts
    assert 'Invalid/unknown `:type` → "Ce thème n\'existe pas."' not in screen_contracts
    assert "Validation of `:type` happens IN THE ROUTE BUILDER" not in screen_contracts
    assert "dataBlockUnknown*" in screen_contracts
    assert "'unknown' => _BlockMeta" in data_block_screen
    assert "dataBlockUnknownTitle" in data_block_screen


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


def test_report_actions_route_coach_topics_without_tools_dead_end() -> None:
    screen_contracts = SCREEN_CONTRACTS.read_text(encoding="utf-8")
    report_screen = FINANCIAL_REPORT_SCREEN.read_text(encoding="utf-8")

    assert "ActionCategory.investment => '/tools'" not in report_screen
    assert "ActionCategory.other => '/tools'" not in report_screen
    assert "ActionCategory.investment => '/coach/chat?topic=investment'" in report_screen
    assert "ActionCategory.other => '/coach/chat?topic=other'" in report_screen
    assert "actionId" in report_screen
    assert "context.go(route)" in report_screen
    assert "maps BOTH `ActionCategory.investment` AND `ActionCategory.other` → `/tools`" not in screen_contracts


def test_legacy_redirect_contract_marks_query_preservation_live() -> None:
    screen_contracts = SCREEN_CONTRACTS.read_text(encoding="utf-8")
    app = APP_DART.read_text(encoding="utf-8")
    redirect_test = LEGACY_REDIRECT_TEST.read_text(encoding="utf-8")

    assert "query params dropped" not in screen_contracts
    assert "`/portfolio` | redirect | redirect → `/home`" not in screen_contracts
    assert "`/score-reveal` | redirect | redirect → `/home`" not in screen_contracts
    assert "_redirectPreservingQuery(state, '/home')" in app
    assert "'/portfolio': '/home'" in redirect_test
    assert "'/score-reveal': '/home'" in redirect_test
