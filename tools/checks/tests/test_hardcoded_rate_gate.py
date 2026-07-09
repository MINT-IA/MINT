import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools/checks/hardcoded_rate_gate.py"


def _diff(path: str, added: list[str], start: int = 1) -> str:
    body = "\n".join(f"+{line}" for line in added)
    return f"diff --git a/{path} b/{path}\n--- a/{path}\n+++ b/{path}\n@@ -0,0 +{start},{len(added)} @@\n{body}\n"


def _run(tmp_path: Path, diff: str) -> subprocess.CompletedProcess[str]:
    diff_path = tmp_path / "changes.diff"
    diff_path.write_text(diff, encoding="utf-8")
    return subprocess.run([sys.executable, str(SCRIPT), "--diff-file", str(diff_path)], cwd=ROOT, text=True, capture_output=True, check=False)


@pytest.mark.parametrize(
    ("path", "added", "needle"),
    [
        ("services/backend/app/services/tax_projection_service.py", ["def estimate_tax_saving(income: float) -> float:", "    rate = 0.12", "    return income * rate"], "registry.py"),
        ("apps/mobile/lib/services/mortgage_hint_service.dart", ["double estimateInterest(double balance) {", "  return balance * 0.035;", "}"], "financial_core"),
    ],
)
def test_new_hardcoded_financial_rates_fail(tmp_path: Path, path: str, added: list[str], needle: str) -> None:
    result = _run(tmp_path, _diff(path, added))
    assert result.returncode == 1
    assert needle in result.stdout


def test_allowed_registry_financial_core_non_financial_and_tests_pass(tmp_path: Path) -> None:
    diff = "".join(
        [
            _diff("services/backend/app/services/regulatory/registry.py", ["MORTGAGE_REFERENCE_RATE = 0.035"]),
            _diff("apps/mobile/lib/services/financial_core/tax_calculator.dart", ["const baseRate = 0.068;"]),
            _diff("apps/mobile/lib/widgets/layout_grid.dart", ["final opacity = animation.value * 0.08;"]),
            _diff("apps/mobile/lib/widgets/retirement/budget_gauge_widget.dart", ["Divider(color: MintColors.border.withValues(alpha: 0.5)),"]),
            _diff("apps/mobile/lib/screens/budget/budget_screen.dart", ["final refreshRate = 120;"]),
            _diff("apps/mobile/lib/services/mortgage_service.dart", ["final anim = animation.value * 0.5;"]),
            _diff("services/backend/app/services/display.py", ["conversionMultiplier = 1000"]),
            _diff("services/backend/app/services/network.py", ["rateLimit = 5", "rateLimit = 5.0", "interestPeriod = 12", "taxRate = 0", "rateIndex = 0"]),
            _diff("services/backend/app/tests/test_projection.py", ["assert result.rate == 0.12"]),
            _diff("services/backend/app/services/tax_projection_service.py", ['"""Reference tax rate is 0.035 per annum"""']),
            _diff("apps/mobile/test/services/tax_projection_test.dart", ["expect(result.rate, 0.12);"]),
        ]
    )
    result = _run(tmp_path, diff)
    assert result.returncode == 0, result.stdout + result.stderr


def test_hardcoded_rate_gate_is_wired_into_ci_and_lefthook() -> None:
    ci = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    gate = ci.split("ci-gate:", maxsplit=1)[1]
    lefthook = (ROOT / "lefthook.yml").read_text(encoding="utf-8")
    assert "hardcoded-rate-gate:" in ci
    assert "tools/checks/hardcoded_rate_gate.py --base-ref" in ci
    assert 'hardcoded_rates="${{ needs.hardcoded-rate-gate.result }}"' in gate
    assert '"$hardcoded_rates" != "success"' in gate
    assert "hardcoded-rate-gate:" in lefthook
    assert "tools/checks/hardcoded_rate_gate.py --staged" in lefthook


def test_git_diff_modes_do_not_crash() -> None:
    for arg in ("--staged", "--base-ref=HEAD"):
        result = subprocess.run([sys.executable, str(SCRIPT), arg], cwd=ROOT, text=True, capture_output=True, check=False)
        assert result.returncode == 0, result.stdout + result.stderr
