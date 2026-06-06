"""Integration smoke for the 5 design-system lints (Phase MVP-DESIGN-LINTS-V1).

This is the « net-new violation introduces a fail » test that closes T12
of PLAN.md. For each of the 5 lints:

  1. Build a synthetic apps/mobile/lib/* tree in a tmpdir.
  2. Inject a single net-new violation crafted for that lint.
  3. Invoke the lint with an empty baseline (every violation = net-new).
  4. Assert exit 1 + diagnostic referencing the fixture path:line.

Plus a positive smoke: every lint exits 0 against a clean tree.

Run:
    python3 -m unittest tools.checks.tests.test_design_lints_smoke
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lint_test_helpers import LintTestCase, captured_io, load_lint


SMOKE_FIXTURES: dict[str, str] = {
    "prefer_mint_color_token": "Container(color: Color(0xFF112233));\n",
    "prefer_mint_text_style": "TextStyle(fontSize: 13);\n",
    "prefer_mint_fonts": "GoogleFonts.inter();\n",
    "prefer_mint_radius": "BorderRadius.circular(13);\n",
    "prefer_mint_cta": "ElevatedButton(onPressed: () {});\n",
}


class DesignLintsSmokeTest(LintTestCase):
    def test_each_lint_fails_on_net_new_violation(self):
        for lint_name, content in SMOKE_FIXTURES.items():
            with self.subTest(lint=lint_name):
                # Fresh tmpdir per lint (LintTestCase.setUp won't re-run
                # inside subTest, so we add a sub-fixture file per lint
                # under a unique path).
                fixture = self.write(
                    f"apps/mobile/lib/_smoke_{lint_name}.dart", content
                )
                baseline = self.baseline(lint_name)  # empty baseline
                mod = load_lint(lint_name)
                old_argv = sys.argv
                sys.argv = [
                    f"{lint_name}.py",
                    "--scope-root", str(self.lib),
                    "--baseline", str(baseline),
                    "--file", str(fixture),
                ]
                try:
                    with captured_io() as (out, err):
                        rc = mod.main()
                finally:
                    sys.argv = old_argv
                diag = out.getvalue() + err.getvalue()
                self.assertEqual(
                    rc, 1,
                    f"{lint_name} must fail with exit 1 on net-new "
                    f"violation; got {rc}, diag={diag!r}",
                )
                self.assertIn(
                    f"_smoke_{lint_name}.dart", diag,
                    f"{lint_name} diagnostic must reference the fixture path",
                )

    def test_each_lint_passes_on_clean_tree(self):
        # Empty lib tree (only a token file inside lib/theme/, which all
        # lints exclude). Empty baseline. Each lint should exit 0.
        self.write(
            "apps/mobile/lib/theme/colors.dart",
            "static const primary = Color(0xFF123456);\n",
        )
        for lint_name in SMOKE_FIXTURES:
            with self.subTest(lint=lint_name):
                baseline = self.baseline(lint_name)
                mod = load_lint(lint_name)
                old_argv = sys.argv
                sys.argv = [
                    f"{lint_name}.py",
                    "--scope-root", str(self.lib),
                    "--baseline", str(baseline),
                ]
                try:
                    with captured_io():
                        rc = mod.main()
                finally:
                    sys.argv = old_argv
                self.assertEqual(
                    rc, 0,
                    f"{lint_name} must pass on a clean tree; got {rc}",
                )

    def test_each_lint_respects_inline_ignore(self):
        # Same violation, but with the inline ignore marker → no violation.
        for lint_name, content in SMOKE_FIXTURES.items():
            with self.subTest(lint=lint_name):
                # Strip trailing newline, append the marker, restore newline.
                line = content.rstrip("\n") + f" // lint-ignore: {lint_name}\n"
                fixture = self.write(
                    f"apps/mobile/lib/_ignore_{lint_name}.dart", line
                )
                baseline = self.baseline(lint_name)
                mod = load_lint(lint_name)
                old_argv = sys.argv
                sys.argv = [
                    f"{lint_name}.py",
                    "--scope-root", str(self.lib),
                    "--baseline", str(baseline),
                    "--file", str(fixture),
                ]
                try:
                    with captured_io():
                        rc = mod.main()
                finally:
                    sys.argv = old_argv
                self.assertEqual(
                    rc, 0,
                    f"{lint_name} must respect // lint-ignore: {lint_name}",
                )

    def test_each_lint_accepts_lefthook_file_argument_shape(self):
        # lefthook currently expands `--file {staged_files}` to
        # `--file first.dart second.dart`. The scripts must treat the trailing
        # positional paths as files, not argparse errors hidden by `|| true`.
        for lint_name, content in SMOKE_FIXTURES.items():
            with self.subTest(lint=lint_name):
                clean = self.write(
                    f"apps/mobile/lib/_lefthook_clean_{lint_name}.dart",
                    "const ok = 1;\n",
                )
                violation = self.write(
                    f"apps/mobile/lib/_lefthook_{lint_name}.dart", content
                )
                baseline = self.baseline(lint_name)
                mod = load_lint(lint_name)
                old_argv = sys.argv
                sys.argv = [
                    f"{lint_name}.py",
                    "--scope-root", str(self.lib),
                    "--baseline", str(baseline),
                    "--file", str(clean), str(violation),
                ]
                try:
                    with captured_io() as (out, err):
                        rc = mod.main()
                finally:
                    sys.argv = old_argv
                diag = out.getvalue() + err.getvalue()
                self.assertEqual(
                    rc, 1,
                    f"{lint_name} must lint both lefthook-shaped paths; "
                    f"got {rc}, diag={diag!r}",
                )
                self.assertIn(f"_lefthook_{lint_name}.dart", diag)


if __name__ == "__main__":
    unittest.main()
