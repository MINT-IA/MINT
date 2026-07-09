import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
LINT = ROOT / "tools/checks/accent_lint_fr.py"

spec = importlib.util.spec_from_file_location("accent_lint_fr", LINT)
assert spec is not None and spec.loader is not None
accent_lint_fr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(accent_lint_fr)


def test_markdown_code_spans_are_not_french_copy(tmp_path: Path) -> None:
    doc = tmp_path / "contract.md"
    doc.write_text(
        "Route slug stays exact: `/coach/chat?topic=premier-ecl" "airage`.\n",
        encoding="utf-8",
    )

    assert accent_lint_fr.scan_file(doc) == []


def test_markdown_plain_french_copy_is_still_linted(tmp_path: Path) -> None:
    doc = tmp_path / "copy.md"
    doc.write_text("Ce premier ecl" "airage doit être accentué.\n", encoding="utf-8")

    violations = accent_lint_fr.scan_file(doc)

    assert len(violations) == 1
    assert "éclairage" in violations[0][2]


def test_dart_route_literals_are_not_french_copy(tmp_path: Path) -> None:
    dart = tmp_path / "app.dart"
    dart.write_text(
        "GoRoute(path: '/onboarding/premier-ecl" "airage', builder: _build);\n",
        encoding="utf-8",
    )

    assert accent_lint_fr.scan_file(dart) == []


def test_dart_plain_ui_copy_is_still_linted(tmp_path: Path) -> None:
    dart = tmp_path / "screen.dart"
    dart.write_text(
        "const Text('Ce premier ecl" "airage doit être accentué');\n",
        encoding="utf-8",
    )

    violations = accent_lint_fr.scan_file(dart)

    assert len(violations) == 1
    assert "éclairage" in violations[0][2]


def test_non_french_arb_is_not_scanned_as_french_copy(tmp_path: Path) -> None:
    arb = tmp_path / "app_de.arb"
    arb.write_text(
        '{"lamalFranchiseIntro": "Verschiebe die Reg' "ler, um zu vergleichen." "}\n",
        encoding="utf-8",
    )

    assert accent_lint_fr.scan_file(arb) == []


def test_french_arb_is_still_linted(tmp_path: Path) -> None:
    arb = tmp_path / "app_fr.arb"
    arb.write_text('{"title": "Ce premier ecl' 'airage compte."}\n', encoding="utf-8")

    violations = accent_lint_fr.scan_file(arb)

    assert len(violations) == 1
    assert "éclairage" in violations[0][2]


def test_non_french_generated_l10n_dart_is_not_scanned_as_french_copy(
    tmp_path: Path,
) -> None:
    dart = tmp_path / "app_localizations_de.dart"
    dart.write_text(
        "String get title => 'Verschiebe die Reg" "ler, um zu vergleichen.';\n",
        encoding="utf-8",
    )

    assert accent_lint_fr.scan_file(dart) == []


def test_french_generated_l10n_dart_is_still_linted(tmp_path: Path) -> None:
    dart = tmp_path / "app_localizations_fr.dart"
    dart.write_text(
        "String get title => 'Ce premier ecl" "airage compte.';\n",
        encoding="utf-8",
    )

    violations = accent_lint_fr.scan_file(dart)

    assert len(violations) == 1
    assert "éclairage" in violations[0][2]
