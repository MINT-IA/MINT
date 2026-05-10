"""Unit tests for prefer_mint_fonts (LINT-03, Phase MVP-DESIGN-LINTS-V1).

Blocks GoogleFonts.* and TextStyle(fontFamily: '...') outside lib/theme/.
Phase 3 (MVP-FONTS-TOKENS-V2) will drop google_fonts entirely; this lint
prevents Phase 3's sweep from re-introducing it.
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lint_test_helpers import LintTestCase, captured_io, load_lint, run_lint_main

LINT = "prefer_mint_fonts"


class PreferMintFontsTest(LintTestCase):
    def test_violation_googlefonts_outside_theme(self):
        self.write(
            "apps/mobile/lib/foo.dart",
            "Text('hi', style: GoogleFonts.inter());\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 1, "net-new GoogleFonts.* must fail")

    def test_violation_textstyle_fontfamily(self):
        self.write(
            "apps/mobile/lib/bar.dart",
            "TextStyle(fontFamily: 'Inter');\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 1, "net-new fontFamily must fail")

    def test_clean_inside_theme(self):
        self.write(
            "apps/mobile/lib/theme/mint_text_styles.dart",
            "GoogleFonts.inter();\nTextStyle(fontFamily: 'Inter');\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, "GoogleFonts inside lib/theme/ must pass")

    def test_inline_ignore_marker(self):
        self.write(
            "apps/mobile/lib/baz.dart",
            "GoogleFonts.inter(); // lint-ignore: prefer_mint_fonts\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0)

    def test_baseline_grandfathers_existing(self):
        fixture = self.write(
            "apps/mobile/lib/grandfathered.dart",
            "GoogleFonts.inter();\n",
        )
        rel = f"{self.lib.name}/{fixture.relative_to(self.lib).as_posix()}"
        baseline = self.baseline(LINT, [f"{rel}:1: GoogleFonts.inter"])
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0)

    def test_file_arg_action_append_multi(self):
        f1 = self.write("apps/mobile/lib/a.dart", "GoogleFonts.inter();\n")
        f2 = self.write("apps/mobile/lib/b.dart", "TextStyle(fontFamily: 'Inter');\n")
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
