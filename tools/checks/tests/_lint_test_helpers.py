"""Shared test helpers for the 5 design-system lint scripts (Phase MVP-DESIGN-LINTS-V1).

No external dependencies — pure stdlib (importlib + tempfile + pathlib).
Mirrors the pattern in tools/checks/test_banned_terms_arb.py:13-23 (importlib.util
spec_from_file_location → exec_module). Adapted for the 5 design lints which all
take a `--file` (action='append') CLI plus a `--update-baseline` flag and exit
0/1/2 per the skeleton in RESEARCH.md §Code Examples lines 564-597.

Usage in a unit test:

    from _lint_test_helpers import load_lint, write_fixture, run_lint_main

    def test_violation_detected(self):
        tmp = pathlib.Path(self.tmpdir.name)
        fixture = write_fixture(tmp / 'lib' / 'foo.dart', '... Color(0xFFAB12CD) ...')
        baseline = tmp / 'baseline.txt'
        baseline.write_text('')  # empty allowlist
        rc = run_lint_main(
            'prefer_mint_color_token',
            ['--file', str(fixture), '--baseline', str(baseline), '--scope-root', str(tmp)],
        )
        self.assertEqual(rc, 1)  # net-new violation
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Iterable

# Resolve the tools/checks directory once.
TOOLS_CHECKS = Path(__file__).resolve().parent.parent
REPO_ROOT = TOOLS_CHECKS.parent.parent


def load_lint(name: str):
    """Import a lint script by stem name (e.g. 'prefer_mint_color_token').

    Mirrors test_banned_terms_arb.py:19-23.
    """
    path = TOOLS_CHECKS / f"{name}.py"
    if not path.exists():
        raise FileNotFoundError(f"lint script not found: {path}")
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def write_fixture(path: Path, content: str) -> Path:
    """Write a synthetic .dart fixture; create parent dirs as needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


@contextlib.contextmanager
def captured_io():
    """Capture stdout + stderr for assertion on diagnostic messages."""
    old_out, old_err = sys.stdout, sys.stderr
    out, err = io.StringIO(), io.StringIO()
    sys.stdout, sys.stderr = out, err
    try:
        yield out, err
    finally:
        sys.stdout, sys.stderr = old_out, old_err


def run_lint_main(name: str, argv: list[str]) -> int:
    """Invoke a lint module's main() with monkey-patched sys.argv.

    Returns the exit code (int). Captures sys.stdout/sys.stderr internally to
    avoid noisy test output; tests asserting on diagnostic text should use
    `captured_io()` directly around the lint module's main() call.
    """
    mod = load_lint(name)
    old_argv = sys.argv
    sys.argv = [f"{name}.py", *argv]
    try:
        with captured_io():
            return int(mod.main())
    finally:
        sys.argv = old_argv


class LintTestCase(unittest.TestCase):
    """Common base: provides a fresh tmpdir per test + a synthetic repo skeleton.

    Skeleton:
      <tmp>/apps/mobile/lib/        ← scope root (production-shaped)
      <tmp>/apps/mobile/lib/theme/  ← excluded by all 5 lints
      <tmp>/baselines/              ← per-test baseline files (start empty)
    """

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.lib = self.root / "apps" / "mobile" / "lib"
        self.theme = self.lib / "theme"
        self.baselines = self.root / "baselines"
        self.lib.mkdir(parents=True, exist_ok=True)
        self.theme.mkdir(parents=True, exist_ok=True)
        self.baselines.mkdir(parents=True, exist_ok=True)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def write(self, rel: str, content: str) -> Path:
        """Write a file at `rel` relative to the synthetic repo root."""
        return write_fixture(self.root / rel, content)

    def baseline(self, name: str, lines: Iterable[str] = ()) -> Path:
        """Create a baseline file with the supplied lines (one per line)."""
        p = self.baselines / f"{name}.baseline.txt"
        p.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
        return p


__all__ = [
    "LintTestCase",
    "TOOLS_CHECKS",
    "REPO_ROOT",
    "captured_io",
    "load_lint",
    "run_lint_main",
    "write_fixture",
]
