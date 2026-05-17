"""Unit tests for prefer_mint_color_token (LINT-01, Phase MVP-DESIGN-LINTS-V1).

Run via:
    python3 -m unittest tools.checks.tests.test_prefer_mint_color_token

Pattern: stdlib unittest, no pytest, no pip deps. Each test creates an
isolated tmpdir mirroring apps/mobile/lib/ shape, invokes the lint with
--scope-root pointing at the tmpdir + --baseline pointing at a tmp file.
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

# Make _lint_test_helpers importable.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lint_test_helpers import LintTestCase, captured_io, load_lint, run_lint_main


LINT = "prefer_mint_color_token"


class PreferMintColorTokenTest(LintTestCase):
    def test_violation_color_hex_outside_theme(self):
        self.write(
            "apps/mobile/lib/foo.dart",
            "Container(color: Color(0xFFAB12CD));\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            [
                "--scope-root", str(self.lib),
                "--baseline", str(baseline),
            ],
        )
        self.assertEqual(rc, 1, "net-new raw Color(0xFF...) must fail")

    def test_violation_material_color_outside_theme(self):
        self.write(
            "apps/mobile/lib/bar.dart",
            "Container(color: Colors.white);\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 1, "net-new Colors.white must fail")

    def test_clean_inside_theme_dir(self):
        # Theme dir is the source of truth — raw colors allowed.
        self.write(
            "apps/mobile/lib/theme/colors.dart",
            "static const primary = Color(0xFF123456);\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, "raw Color() inside lib/theme/ must pass")

    def test_inline_ignore_marker(self):
        self.write(
            "apps/mobile/lib/baz.dart",
            "Container(color: Color(0xFFAB12CD)); // lint-ignore: prefer_mint_color_token\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, "// lint-ignore must suppress")

    def test_baseline_grandfathers_existing(self):
        fixture = self.write(
            "apps/mobile/lib/grandfathered.dart",
            "Container(color: Color(0xFFAB12CD));\n",
        )
        # Lint emits paths relative to scope_root (with scope-name prefix when scope is `lib`).
        rel = f"{self.lib.name}/{fixture.relative_to(self.lib).as_posix()}"
        baseline = self.baseline(LINT, [f"{rel}:1: Color(0xFFAB12CD)"])
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, "violations in baseline must pass")

    def test_update_baseline_writes_file(self):
        self.write(
            "apps/mobile/lib/qux.dart",
            "Container(color: Color(0xFFAB12CD));\n",
        )
        baseline = self.baselines / f"{LINT}.baseline.txt"
        # Ensure baseline does not exist beforehand.
        if baseline.exists():
            baseline.unlink()
        rc = run_lint_main(
            LINT,
            [
                "--scope-root", str(self.lib),
                "--baseline", str(baseline),
                "--update-baseline",
            ],
        )
        self.assertEqual(rc, 0, "--update-baseline must exit 0")
        self.assertTrue(baseline.exists(), "baseline file must be written")
        body = baseline.read_text()
        self.assertIn("Color(0xFFAB12CD)", body)

    def test_file_arg_action_append_multi(self):
        # R1 mitigation: --file MUST accept multiple values via action='append'.
        f1 = self.write("apps/mobile/lib/a.dart", "Container(color: Color(0xFFAA1111));\n")
        f2 = self.write("apps/mobile/lib/b.dart", "Container(color: Color(0xFFBB2222));\n")
        baseline = self.baseline(LINT)
        # Capture diagnostic to assert both files appear.
        mod = load_lint(LINT)
        old_argv = sys.argv
        sys.argv = [
            f"{LINT}.py",
            "--scope-root", str(self.lib),
            "--baseline", str(baseline),
            "--file", str(f1),
            "--file", str(f2),
        ]
        try:
            with captured_io() as (out, err):
                rc = mod.main()
        finally:
            sys.argv = old_argv
        diag = out.getvalue() + err.getvalue()
        self.assertEqual(rc, 1, "both files have violations → exit 1")
        self.assertIn("a.dart", diag, "diagnostic must reference file a")
        self.assertIn("b.dart", diag, "diagnostic must reference file b")

    def test_skips_generated_dart_files(self):
        self.write(
            "apps/mobile/lib/gen.g.dart",
            "Container(color: Color(0xFFAB12CD));\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, ".g.dart must be excluded")

    def test_missing_baseline_exits_zero_with_info(self):
        # R2 mitigation: missing baseline → exit 0 with INFO log.
        self.write(
            "apps/mobile/lib/foo.dart",
            "Container(color: Color(0xFFAB12CD));\n",
        )
        missing = self.baselines / "does_not_exist.baseline.txt"
        self.assertFalse(missing.exists())
        mod = load_lint(LINT)
        old_argv = sys.argv
        sys.argv = [
            f"{LINT}.py",
            "--scope-root", str(self.lib),
            "--baseline", str(missing),
        ]
        try:
            with captured_io() as (out, err):
                rc = mod.main()
        finally:
            sys.argv = old_argv
        diag = out.getvalue() + err.getvalue()
        self.assertEqual(rc, 0, "missing baseline must exit 0 (R2 graceful)")
        self.assertIn("no baseline", diag.lower(), "must surface INFO log")


if __name__ == "__main__":
    unittest.main()
