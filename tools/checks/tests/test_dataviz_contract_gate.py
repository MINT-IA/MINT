from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CI = ROOT / ".github" / "workflows" / "ci.yml"
DATAVIZ_TEST = ROOT / "apps" / "mobile" / "test" / "goldens" / "dataviz_contract_test.dart"
GOLDENS_README = ROOT / "apps" / "mobile" / "test" / "goldens" / "README.md"


def test_ci_runs_blocking_dataviz_contract_gate() -> None:
    ci = CI.read_text(encoding="utf-8")
    marker = "Dataviz contract gate (Infra-G5)"

    assert marker in ci
    step = ci.split(marker, 1)[1].split("# \u2500\u2500\u2500 Phase 32", 1)[0]
    assert "continue-on-error" not in step
    assert "flutter test test/goldens/dataviz_contract_test.dart --reporter compact" in step


def test_dataviz_contract_names_real_surfaces() -> None:
    source = DATAVIZ_TEST.read_text(encoding="utf-8")

    for widget_name in (
        "MintTrajectoryChart",
        "FriBreakdownBars",
        "BreakevenIndicatorWidget",
        "MintResultHeroCard",
    ):
        assert widget_name in source


def test_goldens_readme_documents_dataviz_contract_policy() -> None:
    readme = GOLDENS_README.read_text(encoding="utf-8")

    assert "Infra-G5 Dataviz Contract Gate" in readme
    assert "CI-blocking" in readme
    assert "pixel" in readme
    assert "Linux" in readme
    assert "FriHistoryChart" in readme
    assert "fri_history_chart" in readme
    assert "historical snake-case screen slug" in readme
    assert "no Flutter widget" in readme
    assert "MintResultHeroCard" in readme
