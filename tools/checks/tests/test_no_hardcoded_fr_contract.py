import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools/checks/no_hardcoded_fr.py"


def test_file_mode_respects_l10n_generated_exclusion() -> None:
    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--file",
            "apps/mobile/lib/l10n/app_localizations.dart",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr


def test_file_mode_respects_legacy_debt_prevention_allowlist() -> None:
    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--file",
            "apps/mobile/lib/services/debt_prevention_service.dart",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
