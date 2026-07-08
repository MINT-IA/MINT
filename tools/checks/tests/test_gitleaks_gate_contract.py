from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
GITLEAKS_CONFIG = ROOT / ".gitleaks.toml"
LEFTHOOK = ROOT / "lefthook.yml"
CI = ROOT / ".github/workflows/ci.yml"


def test_gitleaks_config_extends_default_rules() -> None:
    config = GITLEAKS_CONFIG.read_text(encoding="utf-8")

    assert "[extend]" in config
    assert "useDefault = true" in config
    assert "[[allowlists]]" in config


def test_lefthook_runs_gitleaks_pre_commit_gate() -> None:
    lefthook = LEFTHOOK.read_text(encoding="utf-8")

    assert "gitleaks-secret-scan:" in lefthook
    assert "command -v gitleaks" in lefthook
    assert "gitleaks git" in lefthook
    assert "--pre-commit" in lefthook
    assert "--staged" in lefthook
    assert "--redact" in lefthook
    assert "--config .gitleaks.toml" in lefthook


def test_ci_runs_gitleaks_and_blocks_ci_gate() -> None:
    ci = CI.read_text(encoding="utf-8")

    assert "secret-scan:" in ci
    assert "Gitleaks secret scan" in ci
    assert "ghcr.io/gitleaks/gitleaks" in ci
    assert "GIT_CONFIG_KEY_0=safe.directory" in ci
    assert "GIT_CONFIG_VALUE_0=/repo" in ci
    assert "--config .gitleaks.toml" in ci
    assert "secret_scan=\"${{ needs.secret-scan.result }}\"" in ci
    assert '[[ "$secret_scan" == "skipped" ]]' not in ci
    assert "secret-scan" in ci.split("ci-gate:", maxsplit=1)[1]
