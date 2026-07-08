import subprocess
from pathlib import Path
from typing import Union


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools/checks/no_bypass_persistence.py"
LEFTHOOK = ROOT / "lefthook.yml"


def _run(*paths: Union[Path, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(SCRIPT), *(str(path) for path in paths)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def test_no_bypass_persistence_script_exists_and_repo_clean() -> None:
    result = _run()

    assert SCRIPT.exists()
    assert result.returncode == 0, result.stderr


def test_no_bypass_persistence_rejects_direct_domain_key_write(tmp_path: Path) -> None:
    fixture = tmp_path / "bad_writer.dart"
    fixture.write_text(
        """
import 'package:shared_preferences/shared_preferences.dart';

Future<void> writeBad() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('q_birth_year', '1980');
}
""",
        encoding="utf-8",
    )

    result = _run(fixture)

    assert result.returncode == 1
    assert "q_birth_year" in result.stderr
    assert "bad_writer.dart:6" in result.stderr


def test_no_bypass_persistence_rejects_constant_domain_key_write(tmp_path: Path) -> None:
    fixture = tmp_path / "constant_bad_writer.dart"
    fixture.write_text(
        """
import 'package:shared_preferences/shared_preferences.dart';

const String wizardKey = 'wizard_answers_v2';

Future<void> writeBad() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(wizardKey, '{}');
}
""",
        encoding="utf-8",
    )

    result = _run(fixture)

    assert result.returncode == 1
    assert "wizard_answers_v2" in result.stderr


def test_no_bypass_persistence_allows_caches_and_canonical_writers() -> None:
    result = _run(
        ROOT / "apps/mobile/lib/data/budget/budget_local_store.dart",
        ROOT / "apps/mobile/lib/services/report_persistence_service.dart",
        ROOT / "apps/mobile/lib/providers/coach_profile_provider.dart",
    )

    assert result.returncode == 0, result.stderr


def test_lefthook_runs_no_bypass_persistence_for_mobile_dart() -> None:
    lefthook = LEFTHOOK.read_text(encoding="utf-8")

    assert "no-bypass-persistence:" in lefthook
    assert "python3 tools/checks/no_bypass_persistence.py {staged_files}" in lefthook
    assert 'glob: "apps/mobile/lib/**/*.dart"' in lefthook
