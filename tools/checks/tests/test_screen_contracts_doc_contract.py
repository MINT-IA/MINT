import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCREEN_CONTRACTS = ROOT / "docs/codex/SCREEN_CONTRACTS.md"
APP_DART = ROOT / "apps/mobile/lib/app.dart"

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
