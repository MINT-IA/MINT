"""Unit tests for prefer_mint_cta (LINT-05, Phase MVP-DESIGN-LINTS-V1).

Baseline-only mode: net-new raw button widgets (Elevated/Outlined/Filled/Text)
fail outside `lib/widgets/cta/` and `lib/theme/`. Phase 4 will pivot to
hard mode against `MintCTA.{primary,secondary,tertiary,destructive}`.
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lint_test_helpers import LintTestCase, captured_io, load_lint, run_lint_main

LINT = "prefer_mint_cta"


class PreferMintCtaTest(LintTestCase):
    def test_violation_elevated_button(self):
        self.write(
            "apps/mobile/lib/foo.dart",
            "ElevatedButton(onPressed: () {}, child: Text('x'));\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 1)

    def test_violation_outlined_filled_text_buttons(self):
        self.write(
            "apps/mobile/lib/bar.dart",
            "OutlinedButton(onPressed: () {});\nFilledButton(onPressed: () {});\nTextButton(onPressed: () {});\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 1)

    def test_clean_inside_widgets_cta(self):
        self.write(
            "apps/mobile/lib/widgets/cta/mint_cta.dart",
            "ElevatedButton(onPressed: () {});\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0, "raw button inside lib/widgets/cta/ allowed")

    def test_clean_inside_theme(self):
        self.write(
            "apps/mobile/lib/theme/buttons.dart",
            "ElevatedButton(onPressed: () {});\n",
        )
        baseline = self.baseline(LINT)
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0)

    def test_inline_ignore_marker(self):
        self.write(
            "apps/mobile/lib/baz.dart",
            "ElevatedButton(onPressed: () {}); // lint-ignore: prefer_mint_cta\n",
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
            "ElevatedButton(onPressed: () {});\n",
        )
        rel = f"{self.lib.name}/{fixture.relative_to(self.lib).as_posix()}"
        baseline = self.baseline(LINT, [f"{rel}:1: ElevatedButton("])
        rc = run_lint_main(
            LINT,
            ["--scope-root", str(self.lib), "--baseline", str(baseline)],
        )
        self.assertEqual(rc, 0)

    def test_diagnostic_mentions_phase_4(self):
        # Diagnostic copy must mention Phase 4 / MintCTA so devs know what to wait for.
        self.write(
            "apps/mobile/lib/foo.dart",
            "ElevatedButton(onPressed: () {});\n",
        )
        baseline = self.baseline(LINT)
        mod = load_lint(LINT)
        old_argv = sys.argv
        sys.argv = [
            f"{LINT}.py",
            "--scope-root", str(self.lib),
            "--baseline", str(baseline),
        ]
        try:
            with captured_io() as (out, err):
                rc = mod.main()
        finally:
            sys.argv = old_argv
        diag = out.getvalue() + err.getvalue()
        self.assertEqual(rc, 1)
        # Must reference the upcoming Phase 4 widget so devs understand the deferred fix.
        self.assertIn("MintCTA", diag)
        self.assertIn("Phase 4", diag)


if __name__ == "__main__":
    unittest.main()
