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
