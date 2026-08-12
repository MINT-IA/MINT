from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from tools.authority.normalize_three_a_2026_sources import SPECS, build, derive_claims, locate


class NormalizerHostileTest(unittest.TestCase):
    def test_rejects_missing_source(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                build(Path(directory))

    def test_rejects_mutated_source_before_parsing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for source_id in SPECS:
                (root / f"{source_id}.bin").write_bytes(b"hostile")
            with self.assertRaisesRegex(ValueError, "source bytes mismatch"):
                build(root)

    def test_rejects_missing_reviewed_token_after_hash_gate(self):
        with self.assertRaisesRegex(ValueError, "reviewed token not found"):
            locate("authority text without expected claim", r"7['’]258")

    def test_derives_claims_and_rejects_authority_divergence(self):
        records = [
            {"claim_id": key, "normalized": {"value": value}}
            for key, value in {
                "ordinary_cap_web": 7258, "ordinary_cap_table": 7258,
                "credit_deadline": "31_december", "ifd_single_scale": "form_58c_2026",
                "lausanne_coefficient": 78.5, "vd_coefficient": 155.0,
                "vd_reduction": 5.0, "vd_scale_anchor": "anchors",
            }.items()
        ]
        self.assertEqual(derive_claims(records)["employee_with_lpp_ordinary_cap_chf"], 7258)
        records[1]["normalized"]["value"] = 9999
        with self.assertRaisesRegex(ValueError, "authorities diverged"):
            derive_claims(records)


if __name__ == "__main__":
    unittest.main()
