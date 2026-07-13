import importlib.util
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools/checks/no_hardcoded_fr.py"


def _load_linter():
    spec = importlib.util.spec_from_file_location("no_hardcoded_fr", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _run_linter(repo: Path, mode: str, path: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), mode, path],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )


def _git(repo: Path, *args: str) -> None:
    subprocess.run(
        ["git", *args],
        cwd=repo,
        text=True,
        capture_output=True,
        check=True,
    )


def test_staged_diff_parser_keeps_new_line_numbers_across_hunks() -> None:
    linter = _load_linter()
    diff = """diff --git a/apps/mobile/lib/example.dart b/apps/mobile/lib/example.dart
--- a/apps/mobile/lib/example.dart
+++ b/apps/mobile/lib/example.dart
@@ -2,0 +3 @@
+const safe = 'Hello';
@@ -10 +11 @@
-const old = 'Hello';
+const fresh = 'épargne nouvelle';
"""

    assert list(linter.added_lines_from_unified_diff(diff)) == [
        (3, "const safe = 'Hello';"),
        (11, "const fresh = 'épargne nouvelle';"),
    ]


def test_staged_file_mode_ignores_legacy_fr_but_rejects_new_fr(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    target = repo / "apps/mobile/lib/example.dart"
    target.parent.mkdir(parents=True)
    target.write_text("const legacy = 'épargne ancienne';\n", encoding="utf-8")
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "mint@example.test")
    _git(repo, "config", "user.name", "MINT Test")
    _git(repo, "add", ".")
    _git(repo, "commit", "-qm", "baseline")

    target.write_text(
        "const legacy = 'épargne ancienne';\nconst safe = 'Hello';\n",
        encoding="utf-8",
    )
    _git(repo, "add", str(target.relative_to(repo)))

    full_file = _run_linter(repo, "--file", str(target.relative_to(repo)))
    staged_safe = _run_linter(repo, "--staged-file", str(target.relative_to(repo)))

    assert full_file.returncode == 1
    assert "example.dart:1:" in full_file.stderr
    assert staged_safe.returncode == 0, staged_safe.stdout + staged_safe.stderr

    target.write_text(
        "const legacy = 'épargne ancienne';\n"
        "const safe = 'Hello';\n"
        "const fresh = 'épargne nouvelle';\n",
        encoding="utf-8",
    )
    _git(repo, "add", str(target.relative_to(repo)))

    staged_fr = _run_linter(repo, "--staged-file", str(target.relative_to(repo)))

    assert staged_fr.returncode == 1
    assert "apps/mobile/lib/example.dart:3:" in staged_fr.stderr
    assert "épargne nouvelle" in staged_fr.stderr
    assert "épargne ancienne" not in staged_fr.stderr


def test_staged_file_mode_handles_new_files(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    target = repo / "apps/mobile/lib/new_screen.dart"
    target.parent.mkdir(parents=True)
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "mint@example.test")
    _git(repo, "config", "user.name", "MINT Test")
    target.write_text(
        "const safe = 'Hello';\nconst fresh = 'épargne nouvelle';\n",
        encoding="utf-8",
    )
    _git(repo, "add", str(target.relative_to(repo)))

    result = _run_linter(repo, "--staged-file", str(target.relative_to(repo)))

    assert result.returncode == 1
    assert "apps/mobile/lib/new_screen.dart:2:" in result.stderr


def test_lefthook_uses_staged_file_mode_for_hardcoded_fr() -> None:
    config = (ROOT / "lefthook.yml").read_text(encoding="utf-8")
    block = config.split("    no-hardcoded-fr:", maxsplit=1)[1].split(
        "    banned-ui-terms:", maxsplit=1
    )[0]

    assert 'no_hardcoded_fr.py --staged-file "$file"' in block
    assert 'no_hardcoded_fr.py --file "$file"' not in block


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
