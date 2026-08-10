from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_three_a_goal_annexes_guard import ROOT, validate


class AnnexGuardTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        src = ROOT / ".planning/phases/mint-next-vertical01-3a-20260802/annexes"
        dst = self.root / src.relative_to(ROOT)
        dst.parent.mkdir(parents=True)
        shutil.copytree(src, dst)
        self.annex = dst
        for relative in ("tools/authority/normalize_three_a_2026_sources.py", "tools/authority/tests/test_normalize_three_a_2026_sources.py"):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)

    def tearDown(self):
        self.tmp.cleanup()

    def test_committed_contract_passes(self):
        validate(self.root)

    def test_rejects_unhashed_mutation(self):
        p = self.annex / "persona-case-matrix.yaml"
        p.write_text(p.read_text() + "\n# drift\n")
        with self.assertRaisesRegex(ValueError, "artifact drift"):
            validate(self.root)

    def test_rejects_source_becoming_unavailable(self):
        p = self.annex / "authority-receipts.yaml"
        data = yaml.safe_load(p.read_text())
        missing = data["receipts"][0]
        missing.update(available=False, http_status=502, bytes=0, sha256=None, failure="hostile")
        p.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rehash("authority-receipts.yaml")
        with self.assertRaisesRegex(ValueError, "source whitelist drift"):
            validate(self.root)

    def test_rejects_product_activation(self):
        p = self.annex / "normalized-ruleset.yaml"
        data = yaml.safe_load(p.read_text())
        data["availability"]["product_feature_flag"] = True
        p.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rehash("normalized-ruleset.yaml")
        with self.assertRaisesRegex(ValueError, "feature flag must be false"):
            validate(self.root)

    def test_rejects_rehashed_fake_authority_url(self):
        p = self.annex / "authority-receipts.yaml"
        data = yaml.safe_load(p.read_text())
        data["receipts"][0]["url"] = "https://example.com/fake"
        p.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rehash("authority-receipts.yaml")
        with self.assertRaisesRegex(ValueError, "source whitelist drift"):
            validate(self.root)

    def test_rejects_rehashed_normalized_extraction(self):
        import json
        p = self.annex / "source-extractions.json"
        data = json.loads(p.read_text())
        data["extractions"][0]["normalized"]["value"] = "tax_exact"
        p.write_text(json.dumps(data, sort_keys=True, separators=(",", ":")) + "\n")
        self._rehash("source-extractions.json")
        self._rebind_extraction_hash()
        with self.assertRaisesRegex(ValueError, "canonical extraction drift"):
            validate(self.root)

    def test_rejects_rehashed_self_promoting_review_receipt(self):
        p = self.annex / "content-review-receipt.yaml"
        data = yaml.safe_load(p.read_text())
        data["assertions"]["engine_unproven"] = False
        p.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rehash("content-review-receipt.yaml")
        with self.assertRaisesRegex(ValueError, "content review receipt drift"):
            validate(self.root)

    def test_rejects_accepted_receipt_with_pending_bundle(self):
        p = self.annex / "bundle.yaml"
        data = yaml.safe_load(p.read_text())
        data["status"] = "mechanically_extracted_pending_independent_content_review_engine_unproven"
        p.write_text(yaml.safe_dump(data, sort_keys=False))
        with self.assertRaisesRegex(ValueError, "bundle post-review status drift"):
            validate(self.root)

    def test_rejects_every_case_contract_mutation(self):
        original = (self.annex / "persona-case-matrix.yaml").read_text()
        for case_id in "ABCDEFGHIJ":
            with self.subTest(case=case_id):
                p = self.annex / "persona-case-matrix.yaml"
                data = yaml.safe_load(original)
                case = next(item for item in data["cases"] if item["id"] == case_id)
                case["plan"] = "eligible_if_affordable" if case["plan"] == "blocked" else "blocked"
                p.write_text(yaml.safe_dump(data, sort_keys=False))
                self._rehash("persona-case-matrix.yaml")
                with self.assertRaisesRegex(ValueError, "case contract drift"):
                    validate(self.root)
                p.write_text(original)
                self._rehash("persona-case-matrix.yaml")

    def _rehash(self, name: str):
        import hashlib
        p = self.annex / "bundle.yaml"
        data = yaml.safe_load(p.read_text())
        data["artifacts"][name] = hashlib.sha256((self.annex / name).read_bytes()).hexdigest()
        p.write_text(yaml.safe_dump(data, sort_keys=False))

    def _rebind_extraction_hash(self):
        import hashlib
        digest = hashlib.sha256((self.annex / "source-extractions.json").read_bytes()).hexdigest()
        for name in ("parser-version-manifest.yaml", "source-authority-manifest.yaml"):
            p = self.annex / name
            data = yaml.safe_load(p.read_text())
            data["source_extractions_sha256"] = digest
            p.write_text(yaml.safe_dump(data, sort_keys=False))
            self._rehash(name)


if __name__ == "__main__":
    unittest.main()
