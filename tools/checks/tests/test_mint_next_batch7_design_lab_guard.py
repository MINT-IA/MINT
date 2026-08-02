from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_batch7_design_lab_guard import ACCEPTANCE, SCOPE, formal_voice_errors, validate


class Batch7DesignLabGuardTest(unittest.TestCase):
    def mutate(self, callback) -> list[str]:
        data = yaml.safe_load(SCOPE.read_text(encoding="utf-8"))
        callback(data)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scope.yaml"
            path.write_text(yaml.safe_dump(data), encoding="utf-8")
            return validate(path)

    def test_scope_passes(self) -> None:
        self.assertEqual(validate(), [])

    def test_rejects_navigation_hash_drift(self) -> None:
        errors = self.mutate(lambda d: d["authority"].update(navigation_sha256="0" * 64))
        self.assertIn("design-lab scope is not bound to the accepted navigation hash", errors)

    def test_rejects_product_route_claim(self) -> None:
        errors = self.mutate(lambda d: d["runtime_boundary"].update(product_route_added=True))
        self.assertIn("design lab is not isolated from product runtime", errors)

    def test_rejects_missing_locale(self) -> None:
        errors = self.mutate(lambda d: d["first_visual_slice"]["locales"].remove("de"))
        self.assertIn("six-locale scope is incomplete or reordered", errors)

    def test_rejects_formal_voice_in_informal_locale(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app_fr.arb"
            path.write_text('{"@@locale":"fr","body":"MINT vous informe."}', encoding="utf-8")
            self.assertEqual(
                formal_voice_errors(path, "fr"),
                ["fr copy drifts from informal singular voice: vous"],
            )

    def test_rejects_mutated_review_verdict(self) -> None:
        data = yaml.safe_load(ACCEPTANCE.read_text(encoding="utf-8"))
        data["advisory_roasts"][0]["verdict"] = "FAIL"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "acceptance.yaml"
            path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
            errors = validate(acceptance_path=path)
        self.assertIn("design-lab exact acceptance receipt digest drift", errors)
        self.assertIn("design-lab advisory roast record drift", errors)


if __name__ == "__main__":
    unittest.main()
