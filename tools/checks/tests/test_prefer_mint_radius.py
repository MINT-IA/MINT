"""Unit tests for prefer_mint_radius (LINT-04, Phase MVP-DESIGN-LINTS-V1).

Allowlist {2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 999}. Outlier values fail.
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lint_test_helpers import LintTestCase, captured_io, load_lint, run_lint_main

LINT = "prefer_mint_radius"


class PreferMintRadiusTest(LintTestCase):
    def test_allowed_value_passes(self):
        # 12 is in the allowlist → no violation.
        self.write(
            "apps/mobile/lib/foo.dart",
            "BorderRadius.circular(12);\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, "circular(12) is allowlisted")

    def test_pill_999_allowed(self):
        self.write(
            "apps/mobile/lib/bar.dart",
            "BorderRadius.circular(999);\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, "circular(999) pill shorthand allowed")

    def test_outlier_value_fails(self):
        # 13 is NOT in allowlist → net-new violation.
        self.write(
            "apps/mobile/lib/baz.dart",
            "BorderRadius.circular(13);\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 1, "circular(13) outlier must fail")

    def test_clean_inside_theme(self):
        self.write(
            "apps/mobile/lib/theme/colors.dart",
            "BorderRadius.circular(13);\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, "outlier inside lib/theme/ is allowed")

    def test_inline_ignore_marker(self):
        self.write(
            "apps/mobile/lib/qux.dart",
            "BorderRadius.circular(13); // lint-ignore: prefer_mint_radius\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0)

    def test_baseline_grandfathers_existing_outlier(self):
        fixture = self.write(
            "apps/mobile/lib/grandfathered.dart",
            "BorderRadius.circular(7);\n",
        )
        rel = f"{self.lib.name}/{fixture.relative_to(self.lib).as_posix()}"
        baseline = self.baseline(LINT, [f"{rel}:1: BorderRadius.circular(7)"])
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, "grandfathered outlier must pass")

    def test_update_baseline_writes_file(self):
        self.write(
            "apps/mobile/lib/qux.dart",
            "BorderRadius.circular(7);\n",
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
        self.assertIn("circular(7)", baseline.read_text())

    def test_file_arg_action_append_multi(self):
        f1 = self.write("apps/mobile/lib/a.dart", "BorderRadius.circular(7);\n")
        f2 = self.write("apps/mobile/lib/b.dart", "BorderRadius.circular(11);\n")
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


if __name__ == "__main__":
    unittest.main()
