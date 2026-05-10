"""Unit tests for prefer_mint_text_style (LINT-02, Phase MVP-DESIGN-LINTS-V1)."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lint_test_helpers import LintTestCase, captured_io, load_lint, run_lint_main

LINT = "prefer_mint_text_style"


class PreferMintTextStyleTest(LintTestCase):
    def test_violation_fontsize_outside_theme(self):
        self.write(
            "apps/mobile/lib/foo.dart",
            "TextStyle(fontSize: 14);\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 1, "net-new fontSize: 14 must fail")

    def test_clean_inside_theme(self):
        self.write(
            "apps/mobile/lib/theme/mint_text_styles.dart",
            "TextStyle(fontSize: 14);\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, "fontSize inside lib/theme/ must pass")

    def test_skips_line_comment(self):
        # Doc comment containing fontSize — should not flag.
        self.write(
            "apps/mobile/lib/bar.dart",
            "// historical: fontSize: 14 — see ADR-2024-fontsize-floor\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, "doc comment must not trigger lint")

    def test_inline_ignore_marker(self):
        self.write(
            "apps/mobile/lib/baz.dart",
            "TextStyle(fontSize: 14); // lint-ignore: prefer_mint_text_style\n",
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
            "TextStyle(fontSize: 14);\n",
        )
        rel = f"{self.lib.name}/{fixture.relative_to(self.lib).as_posix()}"
        baseline = self.baseline(LINT, [f"{rel}:1: fontSize: 14"])
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, "violations in baseline must pass")

    def test_update_baseline_writes_file(self):
        self.write(
            "apps/mobile/lib/qux.dart",
            "TextStyle(fontSize: 22);\n",
        )
        baseline = self.baselines / f"{LINT}.baseline.txt"
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
        self.assertEqual(rc, 0)
        self.assertTrue(baseline.exists())
        self.assertIn("fontSize: 22", baseline.read_text())

    def test_file_arg_action_append_multi(self):
        f1 = self.write("apps/mobile/lib/a.dart", "TextStyle(fontSize: 11);\n")
        f2 = self.write("apps/mobile/lib/b.dart", "TextStyle(fontSize: 13);\n")
        baseline = self.baseline(LINT)
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
        self.assertEqual(rc, 1)
        self.assertIn("a.dart", diag)
        self.assertIn("b.dart", diag)

    def test_missing_baseline_exits_zero_with_info(self):
        self.write(
            "apps/mobile/lib/foo.dart",
            "TextStyle(fontSize: 14);\n",
        )
        missing = self.baselines / "absent.baseline.txt"
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
        self.assertEqual(rc, 0)
        self.assertIn("no baseline", diag.lower())


if __name__ == "__main__":
    unittest.main()
