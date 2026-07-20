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


def _run_linter(
    repo: Path, mode: str, path: str, *extra_args: str
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), mode, path, *extra_args],
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


def _git_output(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args],
        cwd=repo,
        text=True,
        capture_output=True,
        check=True,
    ).stdout.strip()


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


def test_changed_file_mode_ignores_legacy_fr_but_rejects_new_fr(
    tmp_path: Path,
) -> None:
    repo = tmp_path / "repo"
    target = repo / "apps/mobile/lib/example.dart"
    target.parent.mkdir(parents=True)
    target.write_text("const legacy = 'épargne ancienne';\n", encoding="utf-8")
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "mint@example.test")
    _git(repo, "config", "user.name", "MINT Test")
    _git(repo, "add", ".")
    _git(repo, "commit", "-qm", "baseline")
    base_ref = _git_output(repo, "rev-parse", "HEAD")

    target.write_text(
        "const legacy = 'épargne ancienne';\nconst safe = 'Hello';\n",
        encoding="utf-8",
    )
    _git(repo, "add", str(target.relative_to(repo)))
    _git(repo, "commit", "-qm", "safe change")

    safe_change = _run_linter(
        repo,
        "--changed-file",
        str(target.relative_to(repo)),
        "--base-ref",
        base_ref,
    )

    assert safe_change.returncode == 0, safe_change.stderr

    target.write_text(
        "const legacy = 'épargne ancienne';\n"
        "const safe = 'Hello';\n"
        "const fresh = 'épargne nouvelle';\n",
        encoding="utf-8",
    )
    _git(repo, "add", str(target.relative_to(repo)))
    _git(repo, "commit", "-qm", "hardcoded French change")

    hardcoded_change = _run_linter(
        repo,
        "--changed-file",
        str(target.relative_to(repo)),
        "--base-ref",
        base_ref,
    )

    assert hardcoded_change.returncode == 1
    assert "apps/mobile/lib/example.dart:3:" in hardcoded_change.stderr
    assert "épargne nouvelle" in hardcoded_change.stderr
    assert "épargne ancienne" not in hardcoded_change.stderr


def test_ci_uses_changed_lines_mode_for_hardcoded_fr() -> None:
    config = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    block = config.split("  no-hardcoded-fr:", maxsplit=1)[1].split(
        "  financial-core-gate:", maxsplit=1
    )[0]

    assert 'no_hardcoded_fr.py --changed-file "$file" --base-ref "$BASE_REF"' in block
    assert 'no_hardcoded_fr.py --file "$file"' not in block


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


def test_regexp_literals_are_exempt_but_same_line_ui_copy_is_not() -> None:
    linter = _load_linter()

    violations = linter.scan_lines(
        [
            (
                1,
                'final pattern = RegExp(r"revenu imposable et déductions"); '
                'const label = "Résumé de l’épargne";',
            ),
        ]
    )

    assert len(violations) == 1
    assert violations[0][0] == 1
    assert "Résumé de l’épargne" in violations[0][1]
    assert "Résumé de l’épargne" in violations[0][2]


def test_multiline_concatenated_regexp_literals_are_exempt_until_closure() -> None:
    linter = _load_linter()

    violations = linter.scan_lines(
        enumerate(
            [
                "final pattern = RegExp(",
                '  r"total des revenus imposables" +',
                '      r" et de la fortune",',
                "  caseSensitive: false,",
                ");",
                'const warning = "Vérifie les valeurs avec le document";',
            ],
            start=1,
        )
    )

    assert [violation[0] for violation in violations] == [6]
    assert "Vérifie les valeurs" in violations[0][1]


def test_full_file_mode_exempts_only_regexp_literals(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    target = repo / "apps/mobile/lib/parser.dart"
    target.parent.mkdir(parents=True)
    target.write_text(
        "final pattern = RegExp(\n"
        '  r"revenu imposable et déductions",\n'
        ");\n"
        'const disclaimer = "Vérifie les valeurs avec le document";\n',
        encoding="utf-8",
    )

    visible_copy = _run_linter(repo, "--file", str(target.relative_to(repo)))

    assert visible_copy.returncode == 1
    assert "apps/mobile/lib/parser.dart:4:" in visible_copy.stderr
    assert "Vérifie les valeurs" in visible_copy.stderr
    assert "revenu imposable et déductions" not in visible_copy.stderr

    target.write_text(
        "final pattern = RegExp(\n"
        '  r"revenu imposable et déductions",\n'
        ");\n",
        encoding="utf-8",
    )

    machine_only = _run_linter(repo, "--file", str(target.relative_to(repo)))

    assert machine_only.returncode == 0, machine_only.stderr


def test_comments_cannot_open_or_close_a_regexp_exemption() -> None:
    linter = _load_linter()

    violations = linter.scan_lines(
        enumerate(
            [
                '// RegExp("revenu de la taxation")',
                'const label = "Résumé de l’épargne";',
                "final pattern = RegExp(",
                '  r"revenu imposable", // ) "Vérifie le document"',
                '  caseSensitive: false,',
                ");",
                'const source = "Source de la taxation";',
            ],
            start=1,
        )
    )

    assert {violation[0] for violation in violations} == {1, 2, 4, 7}


def test_staged_mode_uses_index_context_for_multiline_regexp(
    tmp_path: Path,
) -> None:
    repo = tmp_path / "repo"
    target = repo / "apps/mobile/lib/parser.dart"
    target.parent.mkdir(parents=True)
    target.write_text(
        "final pattern = RegExp(\n"
        '  r"steuerbares einkommen",\n'
        "  caseSensitive: false,\n"
        ");\n",
        encoding="utf-8",
    )
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "mint@example.test")
    _git(repo, "config", "user.name", "MINT Test")
    _git(repo, "add", ".")
    _git(repo, "commit", "-qm", "baseline")

    target.write_text(
        "final pattern = RegExp(\n"
        '  r"steuerbares einkommen" +\n'
        '      r" et revenu de la taxation",\n'
        "  caseSensitive: false,\n"
        ");\n",
        encoding="utf-8",
    )
    _git(repo, "add", str(target.relative_to(repo)))

    machine_pattern = _run_linter(
        repo, "--staged-file", str(target.relative_to(repo))
    )

    assert machine_pattern.returncode == 0, machine_pattern.stderr

    target.write_text(
        target.read_text(encoding="utf-8")
        + 'const warning = "Vérifie les valeurs avec le document";\n',
        encoding="utf-8",
    )
    _git(repo, "add", str(target.relative_to(repo)))

    visible_copy = _run_linter(repo, "--staged-file", str(target.relative_to(repo)))

    assert visible_copy.returncode == 1
    assert "apps/mobile/lib/parser.dart:6:" in visible_copy.stderr
    assert "Vérifie les valeurs" in visible_copy.stderr
    assert "revenu de la taxation" not in visible_copy.stderr
