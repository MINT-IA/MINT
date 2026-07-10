import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCREEN_CONTRACTS = ROOT / "docs/codex/SCREEN_CONTRACTS.md"
APP_DART = ROOT / "apps/mobile/lib/app.dart"
DATA_BLOCK_SCREEN = (
    ROOT / "apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart"
)
FINANCIAL_REPORT_SCREEN = (
    ROOT / "apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart"
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


def test_data_block_route_does_not_silently_default_to_revenu() -> None:
    app = APP_DART.read_text(encoding="utf-8")
    screen_contracts = SCREEN_CONTRACTS.read_text(encoding="utf-8")
    data_block_screen = DATA_BLOCK_SCREEN.read_text(encoding="utf-8")
    block = _route_block(app, "/data-block/:type")

    assert "?? 'revenu'" not in block
    assert '?? "revenu"' not in block
    assert "blockType: state.pathParameters['type']!" in block
    assert "initialInputKey: state.uri.queryParameters['inputKey']" in block
    assert "The current builder does `state.pathParameters['type'] ?? 'revenu'`" not in screen_contracts
    assert 'Invalid/unknown `:type` → "Ce thème n\'existe pas."' not in screen_contracts
    assert "Validation of `:type` happens IN THE ROUTE BUILDER" not in screen_contracts
    assert "dataBlockUnknown*" in screen_contracts
    assert "'unknown' => _BlockMeta" in data_block_screen
    assert "dataBlockUnknownTitle" in data_block_screen


def test_report_actions_route_coach_topics_without_tools_dead_end() -> None:
    screen_contracts = SCREEN_CONTRACTS.read_text(encoding="utf-8")
    report_screen = FINANCIAL_REPORT_SCREEN.read_text(encoding="utf-8")

    assert "ActionCategory.investment => '/tools'" not in report_screen
    assert "ActionCategory.other => '/tools'" not in report_screen
    assert "ActionCategory.investment => '/coach/chat?topic=investment'" in report_screen
    assert "ActionCategory.other => '/coach/chat?topic=other'" in report_screen
    assert "actionId" not in report_screen
    assert "_routeForAction(ActionItem action)" not in report_screen
    assert "context.go(route)" in report_screen
    assert "maps BOTH `ActionCategory.investment` AND `ActionCategory.other` → `/tools`" not in screen_contracts


def test_legacy_redirect_contract_marks_query_preservation_live() -> None:
    screen_contracts = SCREEN_CONTRACTS.read_text(encoding="utf-8")
    app = APP_DART.read_text(encoding="utf-8")

    assert "String _redirectPreservingQuery(" in app
    assert "final query = state.uri.query;" in app
    assert "query.isEmpty ? targetPath : '$targetPath?$query'" in app
    assert "query params dropped" not in screen_contracts
    assert "`/portfolio` | redirect | redirect → `/home`" not in screen_contracts
    assert "`/score-reveal` | redirect | redirect → `/home`" not in screen_contracts
    for route in ("/ask-mint", "/tools", "/portfolio", "/score-reveal"):
        block = _route_block(app, route)
        assert "_redirectPreservingQuery(state," in block


def test_disability_insurance_contract_is_ledger_first() -> None:
    screen_contracts = SCREEN_CONTRACTS.read_text(encoding="utf-8")
    insurance_row = next(
        line
        for line in screen_contracts.splitlines()
        if line.startswith("| `/disability/insurance`")
    )
    gap_row = next(
        line
        for line in screen_contracts.splitlines()
        if line.startswith("| `/invalidite`")
    )
    health_hub_row = next(
        line
        for line in screen_contracts.splitlines()
        if line.startswith("| `/explore/sante`")
    )
    self_employed_row = next(
        line
        for line in screen_contracts.splitlines()
        if line.startswith("| `/disability/self-employed`")
    )

    assert "`q_gross_salary_annual`" in insurance_row
    assert "`q_cash_total`" in insurance_row
    assert "/data-block/revenu?inputKey=q_gross_salary_annual" in insurance_row
    assert "/data-block/patrimoine?inputKey=q_cash_total" in insurance_row
    assert "/data-block/lpp" not in insurance_row
    assert "salaireBrutMensuel" not in insurance_row
    assert "`q_gross_salary_annual`" in gap_row
    assert "`q_birth_year`" in gap_row
    assert "`q_cash_total`" in gap_row
    assert "/data-block/revenu?inputKey=q_birth_year" in gap_row
    assert "screen-local user fact sliders" not in gap_row
    assert "salaireBrutMensuel" not in gap_row
    assert "`q_self_employed_income`" in self_employed_row
    assert "`q_cash_total`" in self_employed_row
    assert "`q_housing_cost_period_chf`" in self_employed_row
    assert "`q_lamal_premium_monthly_chf`" in self_employed_row
    assert "`depenses.*`" in self_employed_row
    assert "/data-block/revenu?inputKey=q_self_employed_income" in self_employed_row
    assert "/data-block/patrimoine?inputKey=q_cash_total" in self_employed_row
    assert "/budget/setup" in self_employed_row
    assert "/disability/self-employed" in health_hub_row
