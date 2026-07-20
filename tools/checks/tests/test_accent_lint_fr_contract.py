from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
LINT = ROOT / "tools/checks/accent_lint_fr.py"

spec = importlib.util.spec_from_file_location("accent_lint_fr", LINT)
assert spec is not None and spec.loader is not None
accent_lint_fr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(accent_lint_fr)


def _run_cli(*args: str | Path, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(LINT), *(str(arg) for arg in args)],
        cwd=cwd,
        check=False,
        capture_output=True,
        text=True,
    )


def _git(repo: Path, *args: str) -> None:
    subprocess.run(
        ["git", *args],
        cwd=repo,
        check=True,
        capture_output=True,
        text=True,
    )


def _git_output(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args],
        cwd=repo,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def test_markdown_code_spans_are_not_french_copy(tmp_path: Path) -> None:
    doc = tmp_path / "contract.md"
    doc.write_text(
        "Route slug stays exact: `/coach/chat?topic=premier-eclairage`.\n",
        encoding="utf-8",
    )

    assert accent_lint_fr.scan_file(doc) == []


def test_markdown_plain_french_copy_is_still_linted(tmp_path: Path) -> None:
    doc = tmp_path / "copy.md"
    doc.write_text("Ce premier eclairage doit être accentué.\n", encoding="utf-8")

    violations = accent_lint_fr.scan_file(doc)

    assert len(violations) == 1
    assert "éclairage" in violations[0][2]


def test_dart_route_literals_are_not_french_copy(tmp_path: Path) -> None:
    dart = tmp_path / "app.dart"
    dart.write_text(
        "GoRoute(path: '/onboarding/premier-eclairage', builder: _build);\n",
        encoding="utf-8",
    )

    assert accent_lint_fr.scan_file(dart) == []


def test_python_route_literals_are_not_french_copy(tmp_path: Path) -> None:
    python = tmp_path / "endpoint.py"
    python.write_text(
        "@router.post('/premier-eclairage')\n",
        encoding="utf-8",
    )

    assert accent_lint_fr.scan_file(python) == []


def test_dart_plain_ui_copy_is_still_linted(tmp_path: Path) -> None:
    dart = tmp_path / "screen.dart"
    dart.write_text(
        "const Text('Ce premier eclairage doit être accentué');\n",
        encoding="utf-8",
    )

    violations = accent_lint_fr.scan_file(dart)

    assert len(violations) == 1
    assert "éclairage" in violations[0][2]


def test_non_french_arb_is_not_scanned_as_french_copy(tmp_path: Path) -> None:
    arb = tmp_path / "app_de.arb"
    payload = {"lamalFranchiseIntro": "Verschiebe die Regler, um zu vergleichen."}
    arb.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")

    assert json.loads(arb.read_text(encoding="utf-8")) == payload
    assert accent_lint_fr.scan_file(arb) == []


def test_french_arb_is_still_linted(tmp_path: Path) -> None:
    arb = tmp_path / "app_fr.arb"
    arb.write_text('{"title": "Ce premier eclairage compte."}\n', encoding="utf-8")

    violations = accent_lint_fr.scan_file(arb)

    assert len(violations) == 1
    assert "éclairage" in violations[0][2]


def test_non_french_generated_l10n_dart_is_not_scanned_as_french_copy(
    tmp_path: Path,
) -> None:
    dart = tmp_path / "app_localizations_de.dart"
    dart.write_text(
        "String get title => 'Verschiebe die Regler, um zu vergleichen.';\n",
        encoding="utf-8",
    )

    assert accent_lint_fr.scan_file(dart) == []


def test_french_generated_l10n_dart_is_still_linted(tmp_path: Path) -> None:
    dart = tmp_path / "app_localizations_fr.dart"
    dart.write_text(
        "String get title => 'Ce premier eclairage compte.';\n",
        encoding="utf-8",
    )

    violations = accent_lint_fr.scan_file(dart)

    assert len(violations) == 1
    assert "éclairage" in violations[0][2]


def test_dart_comments_identifiers_and_machine_ids_are_not_ui_copy(
    tmp_path: Path,
) -> None:
    flattened = "securite"
    dart = tmp_path / "visibility_score_service.dart"
    dart.write_text(
        f"""// {flattened} is an internal axis name.
/* The {flattened} axis is weighted below. */
final {flattened} = computeAxis();
return VisibilityAxis(
  id: '{flattened}',
  score: {flattened}.score,
);
""",
        encoding="utf-8",
    )

    assert accent_lint_fr.scan_file(dart) == []


def test_dart_ui_copy_is_linted_even_when_it_is_one_identifier_shaped_word(
    tmp_path: Path,
) -> None:
    flattened = "securite"
    dart = tmp_path / "screen.dart"
    dart.write_text(
        f"Text('{flattened}');\nSemantics(label: 'Reste en {flattened}');\n",
        encoding="utf-8",
    )

    violations = accent_lint_fr.scan_file(dart)

    assert [violation[0] for violation in violations] == [1, 2]
    assert all("sécurité" in violation[2] for violation in violations)


def test_dart_interpolation_identifiers_are_not_mistaken_for_ui_copy(
    tmp_path: Path,
) -> None:
    flattened = "securite"
    dart = tmp_path / "screen.dart"
    dart.write_text(
        f"Text('Score: ${flattened}');\nText('Score: ${{state.{flattened}}}');\n",
        encoding="utf-8",
    )

    assert accent_lint_fr.scan_file(dart) == []


def test_plain_braces_do_not_create_an_interpolation_bypass(tmp_path: Path) -> None:
    flattened = "securite"
    dart = tmp_path / "screen.dart"
    dart.write_text(f"Text('{{{flattened}}}');\n", encoding="utf-8")
    python = tmp_path / "screen.py"
    python.write_text(f"show('{{{flattened}}}')\n", encoding="utf-8")

    assert len(accent_lint_fr.scan_file(dart)) == 1
    assert len(accent_lint_fr.scan_file(python)) == 1


def test_dart_switch_pattern_tokens_are_not_ui_copy(tmp_path: Path) -> None:
    flattened = "securite"
    dart = tmp_path / "icon.dart"
    dart.write_text(
        f"final icon = switch (axisId) {{ '{flattened}' => Icons.shield }};\n",
        encoding="utf-8",
    )

    assert accent_lint_fr.scan_file(dart) == []


def test_comment_markers_inside_dart_ui_strings_do_not_hide_copy(
    tmp_path: Path,
) -> None:
    flattened = "securite"
    dart = tmp_path / "screen.dart"
    dart.write_text(
        f"Text('Reste // en {flattened}');\nText('Reste /* en {flattened} */');\n",
        encoding="utf-8",
    )

    violations = accent_lint_fr.scan_file(dart)

    assert [violation[0] for violation in violations] == [1, 2]


def test_python_comments_identifiers_and_machine_ids_are_not_ui_copy(
    tmp_path: Path,
) -> None:
    flattened = "securite"
    python = tmp_path / "score.py"
    python.write_text(
        f"""# {flattened} is an internal axis name.
{flattened} = compute_axis()
axis = Axis(id='{flattened}', score={flattened}.score)
""",
        encoding="utf-8",
    )

    assert accent_lint_fr.scan_file(python) == []


def test_python_user_copy_remains_linted(tmp_path: Path) -> None:
    flattened = "securite"
    python = tmp_path / "screen.py"
    python.write_text(
        f"show_message('Reste en {flattened}')\n",
        encoding="utf-8",
    )

    violations = accent_lint_fr.scan_file(python)

    assert len(violations) == 1
    assert "sécurité" in violations[0][2]


def test_cli_blocks_unaccented_copy_in_production_dart_and_python(
    tmp_path: Path,
) -> None:
    dart = tmp_path / "apps/mobile/lib/screen.dart"
    python = tmp_path / "services/backend/app/endpoint.py"
    dart.parent.mkdir(parents=True)
    python.parent.mkdir(parents=True)
    dart.write_text("Text('Reste en securite');\n", encoding="utf-8")
    python.write_text("show_message('Reste en securite')\n", encoding="utf-8")

    for production_file in (dart, python):
        result = _run_cli("--file", production_file)
        assert result.returncode == 1
        assert "sécurité" in result.stderr


def test_cli_ignores_check_self_test_fixtures_but_direct_scan_stays_active(
    tmp_path: Path,
) -> None:
    fixture = tmp_path / "tools/checks/tests/test_fixture.py"
    fixture.parent.mkdir(parents=True)
    fixture.write_text("show_message('Reste en securite')\n", encoding="utf-8")

    assert accent_lint_fr.scan_file(fixture)
    assert _run_cli("--file", fixture).returncode == 0


def test_staged_mode_ignores_legacy_debt_and_rejects_new_flattened_french(
    tmp_path: Path,
) -> None:
    repo = tmp_path / "repo"
    target = repo / "apps/mobile/test/visibility_score_service_test.dart"
    target.parent.mkdir(parents=True)
    target.write_text("test('securite legacy', () {});\n", encoding="utf-8")
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "mint@example.test")
    _git(repo, "config", "user.name", "MINT Test")
    _git(repo, "add", ".")
    _git(repo, "commit", "-qm", "baseline")

    target.write_text(
        "test('securite legacy', () {});\nconst provenance = 'salary';\n",
        encoding="utf-8",
    )
    _git(repo, "add", str(target.relative_to(repo)))

    safe = _run_cli("--staged-file", target.relative_to(repo), cwd=repo)
    assert safe.returncode == 0, safe.stderr

    target.write_text(
        target.read_text(encoding="utf-8") + "Text('Reste en securite');\n",
        encoding="utf-8",
    )
    _git(repo, "add", str(target.relative_to(repo)))

    violation = _run_cli("--staged-file", target.relative_to(repo), cwd=repo)
    assert violation.returncode == 1
    assert "Reste en securite" in violation.stderr
    assert "securite legacy" not in violation.stderr


def test_changed_mode_preserves_multiline_context_and_reports_only_added_lines(
    tmp_path: Path,
) -> None:
    repo = tmp_path / "repo"
    target = repo / "apps/mobile/lib/screen.dart"
    target.parent.mkdir(parents=True)
    target.write_text("const label = '''\nLegacy copy\n''';\n", encoding="utf-8")
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "mint@example.test")
    _git(repo, "config", "user.name", "MINT Test")
    _git(repo, "add", ".")
    _git(repo, "commit", "-qm", "baseline")
    base_ref = _git_output(repo, "rev-parse", "HEAD")

    target.write_text(
        "const label = '''\nLegacy copy\nReste en securite\n''';\n",
        encoding="utf-8",
    )
    _git(repo, "add", str(target.relative_to(repo)))
    _git(repo, "commit", "-qm", "new flattened French")

    result = _run_cli(
        "--changed-file",
        target.relative_to(repo),
        "--base-ref",
        base_ref,
        cwd=repo,
    )

    assert result.returncode == 1
    assert "screen.dart:3:" in result.stderr
    assert "Reste en securite" in result.stderr
    assert "Legacy copy" not in result.stderr


def test_local_and_ci_use_introduced_lines_modes() -> None:
    lefthook = (ROOT / "lefthook.yml").read_text(encoding="utf-8")
    local_block = lefthook.split("    accent-lint-fr:", maxsplit=1)[1].split(
        "    no-hardcoded-fr:", maxsplit=1
    )[0]
    workflow = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    ci_block = workflow.split("  accent-lint-fr:", maxsplit=1)[1].split(
        "  no-hardcoded-fr:", maxsplit=1
    )[0]

    assert 'accent_lint_fr.py --staged-file "$file"' in local_block
    assert 'accent_lint_fr.py --file "$file"' not in local_block
    assert (
        'accent_lint_fr.py --changed-file "$file" --base-ref "$BASE_REF"'
        in ci_block
    )
    assert 'accent_lint_fr.py --file "$file"' not in ci_block
