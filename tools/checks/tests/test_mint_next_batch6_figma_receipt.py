from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_batch6_figma_receipt import RECEIPT, ROOT, validate


class Batch6FigmaReceiptTest(unittest.TestCase):
    def test_committed_receipt_is_coherent(self) -> None:
        self.assertEqual(validate(), [])

    def test_rejects_false_acceptance_with_open_findings(self) -> None:
        data = yaml.safe_load(RECEIPT.read_text(encoding="utf-8"))
        data["status"] = "accepted"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "receipt.yaml"
            path.write_text(yaml.safe_dump(data), encoding="utf-8")
            self.assertIn(
                "candidate with known rejections must remain rejected_pending_corrections",
                validate(path, ROOT),
            )

    def test_rejects_evidence_hash_drift(self) -> None:
        data = yaml.safe_load(RECEIPT.read_text(encoding="utf-8"))
        data["evidence"]["question"]["sha256"] = "0" * 64
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "receipt.yaml"
            path.write_text(yaml.safe_dump(data), encoding="utf-8")
            self.assertIn("hash mismatch for question evidence", validate(path, ROOT))


if __name__ == "__main__":
    unittest.main()
