import subprocess
import sys
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools/checks/financial_core_gate.py"
CI = ROOT / ".github/workflows/ci.yml"
LEFTHOOK = ROOT / "lefthook.yml"


def _diff(path: str, added: list[str], start: int = 1) -> str:
    body = "\n".join(f"+{line}" for line in added)
    return f"diff --git a/{path} b/{path}\n--- a/{path}\n+++ b/{path}\n@@ -0,0 +{start},{len(added)} @@\n{body}\n"


def _run(tmp_path: Path, diff: str) -> subprocess.CompletedProcess[str]:
    diff_path = tmp_path / "changes.diff"
    diff_path.write_text(diff, encoding="utf-8")
    return subprocess.run([sys.executable, str(SCRIPT), "--diff-file", str(diff_path)], cwd=ROOT, text=True, capture_output=True, check=False)


@pytest.mark.parametrize(
    ("diff", "needle"),
    [
        (
            _diff(
                "apps/mobile/lib/services/tax_projection_service.dart",
                ["class TaxProjectionService {", "  static double _calculateTaxSavings(double income, double pillar3a) {", "    return income * 0.12 + pillar3a * 0.25;", "  }", "}"],
            ),
            "_calculateTaxSavings",
        ),
        (
            _diff(
                "apps/mobile/lib/services/mortgage_hint_service.dart",
                ["    final affordability = revenuAnnuel * 0.33 - interetsHypotheque;", "    return affordability;"],
                start=11,
            ),
            "affordability",
        ),
        (
            _diff("apps/mobile/lib/services/risk_service.dart", ["double computeCapacity(double revenuAnnuel, double chargesHypothecaires) => revenuAnnuel * 0.33 - chargesHypothecaires;"]),
            "computeCapacity",
        ),
        (
            _diff("apps/mobile/lib/services/risk_service.dart", ["double get affordabilityRate => revenu * 0.33;"]),
            "affordabilityRate",
        ),
        (
            _diff("apps/mobile/lib/services/pillar3a_hint_service.dart", ["double _pillar3aDeduction(double revenu) => revenu * 0.12;"]),
            "_pillar3aDeduction",
        ),
    ],
)
def test_new_financial_calculation_outside_financial_core_fails(tmp_path: Path, diff: str, needle: str) -> None:
    result = _run(tmp_path, diff)
    diagnostics = result.stdout + result.stderr
    assert result.returncode == 1
    assert needle in diagnostics
    assert "financial_core/" in diagnostics


@pytest.mark.parametrize(
    "diff",
    [
        _diff("apps/mobile/lib/services/financial_core/tax_calculator.dart", ["static double _calculateTaxSavings(double income) => income * 0.12;"]),
        _diff("apps/mobile/lib/services/coach_summary_service.dart", ["final estimate = TaxCalculator.calculate(income: profile.salaireBrutAnnuel);"]),
        _diff("apps/mobile/lib/services/navigation_state_service.dart", ["String _computeRouteLabel(String routeName) => routeName.trim();"]),
        _diff("apps/mobile/lib/l10n/app_localizations_fr.dart", ["String monthlyAmount(Object amount) => 'Total fixe : $amount CHF / mois';"]),
        _diff("apps/mobile/lib/services/coach_copy_service.dart", ["return 'Ton loyer est de 1200 CHF / mois';"]),
        _diff("apps/mobile/lib/services/tax_screen_state_service.dart", ["final width = index * 2.0;"]),
        _diff("apps/mobile/lib/screens/tax_screen.dart", ["void _calculate() {", "  setState(() {});", "}"]),
        _diff("apps/mobile/lib/app.dart", ["String avsGuidePath() => '/scan/avs-guide';"]),
    ],
)
def test_allowed_diffs_pass(tmp_path: Path, diff: str) -> None:
    result = _run(tmp_path, diff)
    assert result.returncode == 0, result.stdout + result.stderr


def test_financial_core_gate_is_wired_into_ci_gate_and_lefthook() -> None:
    ci = CI.read_text(encoding="utf-8")
    gate = ci.split("ci-gate:", maxsplit=1)[1]
    lefthook = LEFTHOOK.read_text(encoding="utf-8")
    assert "financial-core-gate:" in ci
    assert "tools/checks/financial_core_gate.py --base-ref" in ci
    assert "financial-core-gate" in gate
    assert 'financial_core="${{ needs.financial-core-gate.result }}"' in gate
    assert '"$financial_core" != "success"' in gate
    assert "financial-core-gate:" in lefthook
    assert "tools/checks/financial_core_gate.py --staged" in lefthook
