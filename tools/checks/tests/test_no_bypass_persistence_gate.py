import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools/checks/no_bypass_persistence.py"


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
        (
            "apps/mobile/lib/screens/simulator_3a_screen.dart",
            ["final prefs = await SharedPreferences.getInstance();", "await prefs.setString('wizard_answers_v2', encoded);"],
            "wizard_answers_v2",
        ),
        (
            "apps/mobile/lib/services/salary_cache_service.dart",
            ["final prefs = await SharedPreferences.getInstance();", "await prefs.setDouble('q_gross_salary_annual', salary);"],
            "q_gross_salary_annual",
        ),
        (
            "apps/mobile/lib/screens/simulator_compound_screen.dart",
            ["final prefs = await SharedPreferences.getInstance();"],
            "updateProfile",
        ),
        (
            "apps/mobile/lib/data/budget/budget_local_store.dart",
            ["await prefs.setString('wizard_answers_v2', encoded);"],
            "budget_local_store",
        ),
    ],
)
def test_persistence_bypasses_fail(tmp_path: Path, path: str, added: list[str], needle: str) -> None:
    result = _run(tmp_path, _diff(path, added))
    assert result.returncode == 1
    assert needle in result.stdout


def test_allowed_persistence_paths_and_non_domain_keys_pass(tmp_path: Path) -> None:
    diff = "".join(
        [
            _diff("apps/mobile/lib/services/report_persistence_service.dart", ["await prefs.setString('wizard_answers_v2', encoded);"]),
            _diff("apps/mobile/lib/providers/coach_profile_provider.dart", ["await prefs.setString('q_canton', canton);"]),
            _diff("apps/mobile/lib/data/budget/budget_local_store.dart", ["await prefs.setString('_budget_inputs_v1', encoded);"]),
            _diff("apps/mobile/lib/services/analytics_service.dart", ["await prefs.setString('_analytics_session_id', sessionId);"]),
        ]
    )
    result = _run(tmp_path, diff)
    assert result.returncode == 0, result.stdout + result.stderr


def test_no_bypass_persistence_gate_is_wired_into_ci_and_lefthook() -> None:
    ci = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    gate = ci.split("ci-gate:", maxsplit=1)[1]
    lefthook = (ROOT / "lefthook.yml").read_text(encoding="utf-8")
    assert "no-bypass-persistence:" in ci
    assert "tools/checks/no_bypass_persistence.py --base-ref" in ci
    assert 'no_bypass="${{ needs.no-bypass-persistence.result }}"' in gate
    assert '"$no_bypass" != "success"' in gate
    assert "no-bypass-persistence:" in lefthook
    assert "tools/checks/no_bypass_persistence.py --staged" in lefthook
