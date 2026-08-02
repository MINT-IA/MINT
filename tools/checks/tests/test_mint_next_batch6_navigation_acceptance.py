from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_batch6_navigation_acceptance import RECEIPT, validate


class Batch6NavigationAcceptanceTest(unittest.TestCase):
    def mutate(self, callback) -> list[str]:
        data = yaml.safe_load(RECEIPT.read_text(encoding="utf-8"))
        callback(data)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "receipt.yaml"
            path.write_text(yaml.safe_dump(data), encoding="utf-8")
            return validate(path)

    def test_receipt_passes(self) -> None:
        self.assertEqual(validate(), [])

    def test_rejects_contract_hash_drift(self) -> None:
        errors = self.mutate(lambda d: d["contract"].update(sha256="0" * 64))
        self.assertIn("contract acceptance hash is stale or missing", errors)

    def test_rejects_missing_reviewer(self) -> None:
        errors = self.mutate(lambda d: d["independent_reviews"].pop())
        self.assertIn("independent reviewer set is incomplete", errors)

    def test_rejects_nonzero_finding(self) -> None:
        errors = self.mutate(lambda d: d["independent_reviews"][0].update(p2=1))
        self.assertIn("review did not converge: batch6_navigation_roast", errors)

    def test_rejects_runtime_overclaim(self) -> None:
        errors = self.mutate(lambda d: d["explicitly_not_accepted"].remove("flutter_product_runtime"))
        self.assertIn("acceptance limitations are incomplete", errors)


if __name__ == "__main__":
    unittest.main()
