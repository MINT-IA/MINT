"""Tests for lint_status_audit.py — pure stdlib, no pytest required.

Run: python3 lints/tests/test_lint_status_audit.py
Returns 0 if all tests pass, 1 otherwise.
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

# Make lint_status_audit importable
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from lint_status_audit import audit, find_lints, parse_status_md  # noqa: E402


def setup_fixture(tmpdir: Path, lints: list[str], status_entries: list[tuple[str, str]]) -> tuple[Path, Path]:
    """Create a fixture lint dir with given lints and STATUS.md entries."""
    lint_dir = tmpdir / "checks"
    lint_dir.mkdir()
    for name in lints:
        (lint_dir / name).write_text("# stub\n")
    status_file = lint_dir / "STATUS.md"
    lines = ["# Lint Status\n", "| Lint | Status | Wired in |\n", "|---|---|---|\n"]
    for name, status in status_entries:
        lines.append(f"| {name} | {status} | somewhere |\n")
    status_file.write_text("".join(lines))
    return lint_dir, status_file


def assert_eq(actual, expected, msg=""):
    if actual != expected:
        print(f"FAIL: {msg}")
        print(f"  expected: {expected}")
        print(f"  actual:   {actual}")
        return False
    return True


def test_full_coverage_returns_no_missing():
    with tempfile.TemporaryDirectory() as td:
        lint_dir, status_file = setup_fixture(
            Path(td),
            lints=["a.py", "b.sh"],
            status_entries=[("a.py", "enforced-ci"), ("b.sh", "enforced-pre-commit")],
        )
        missing, invalid, orphan = audit(lint_dir, status_file)
        return all([
            assert_eq(missing, [], "missing should be empty when all classified"),
            assert_eq(invalid, [], "invalid should be empty when all valid statuses"),
            assert_eq(orphan, [], "orphan should be empty"),
        ])


def test_missing_lint_detected():
    with tempfile.TemporaryDirectory() as td:
        lint_dir, status_file = setup_fixture(
            Path(td),
            lints=["a.py", "b.sh", "c.py"],
            status_entries=[("a.py", "enforced-ci")],
        )
        missing, _, _ = audit(lint_dir, status_file)
        return assert_eq(sorted(missing), ["b.sh", "c.py"], "should detect missing lints")


def test_invalid_status_detected():
    with tempfile.TemporaryDirectory() as td:
        lint_dir, status_file = setup_fixture(
            Path(td),
            lints=["a.py"],
            status_entries=[("a.py", "totally-bogus")],
        )
        _, invalid, _ = audit(lint_dir, status_file)
        return assert_eq(invalid, ["a.py"], "should detect invalid status string")


def test_orphan_in_status_detected():
    with tempfile.TemporaryDirectory() as td:
        lint_dir, status_file = setup_fixture(
            Path(td),
            lints=["a.py"],
            status_entries=[("a.py", "manual-only"), ("ghost.py", "enforced-ci")],
        )
        _, _, orphan = audit(lint_dir, status_file)
        return assert_eq(orphan, ["ghost.py"], "should detect status entry with no file")


def test_excluded_files_not_treated_as_lints():
    with tempfile.TemporaryDirectory() as td:
        lint_dir = Path(td) / "checks"
        lint_dir.mkdir()
        # Excluded
        (lint_dir / "STATUS.md").write_text("")
        (lint_dir / "README.md").write_text("")
        (lint_dir / "foo-KNOWN-MISSES.md").write_text("")
        (lint_dir / "baseline.baseline").write_text("")
        # Real lint
        (lint_dir / "real.py").write_text("# stub")
        lints = find_lints(lint_dir)
        names = {p.name for p in lints}
        return assert_eq(names, {"real.py"}, "should exclude STATUS, README, KNOWN-MISSES, baselines")


def test_empty_status_file():
    with tempfile.TemporaryDirectory() as td:
        lint_dir = Path(td) / "checks"
        lint_dir.mkdir()
        (lint_dir / "a.py").write_text("# stub")
        status_file = lint_dir / "STATUS.md"
        status_file.write_text("# Empty\n")
        missing, _, _ = audit(lint_dir, status_file)
        return assert_eq(missing, ["a.py"], "empty STATUS.md should report all lints as missing")


def test_missing_status_file():
    with tempfile.TemporaryDirectory() as td:
        lint_dir = Path(td) / "checks"
        lint_dir.mkdir()
        (lint_dir / "a.py").write_text("# stub")
        # No STATUS.md created
        statuses = parse_status_md(lint_dir / "STATUS.md")
        return assert_eq(statuses, {}, "missing STATUS.md should return empty dict not error")


def main():
    tests = [
        test_full_coverage_returns_no_missing,
        test_missing_lint_detected,
        test_invalid_status_detected,
        test_orphan_in_status_detected,
        test_excluded_files_not_treated_as_lints,
        test_empty_status_file,
        test_missing_status_file,
    ]
    passed = 0
    failed = 0
    for t in tests:
        if t():
            print(f"PASS: {t.__name__}")
            passed += 1
        else:
            failed += 1
    print(f"\n{passed}/{len(tests)} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
