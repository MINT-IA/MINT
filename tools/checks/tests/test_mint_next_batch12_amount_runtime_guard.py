from __future__ import annotations

import hashlib
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks import mint_next_batch12_amount_runtime_guard as guard


class Batch12AmountRuntimeGuardTest(unittest.TestCase):
    def _write_yaml(self, directory: str, name: str, value: object) -> Path:
        path = Path(directory) / name
        path.write_text(yaml.safe_dump(value, sort_keys=False), encoding="utf-8")
        return path

    def test_canonical_candidate_is_green(self) -> None:
        self.assertEqual(guard.validate(), [])

    def test_receipt_cannot_claim_promotion(self) -> None:
        receipt = yaml.safe_load(guard.RECEIPT.read_text(encoding="utf-8"))
        receipt["status"] = "accepted_product"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "receipt.yaml"
            path.write_text(yaml.safe_dump(receipt), encoding="utf-8")
            errors = guard.validate(receipt_path=path)
        self.assertIn("Batch12 exact runtime receipt drift", errors)
        self.assertIn("Batch12 receipt overclaims promotion", errors)

    def test_multi_provider_limitation_cannot_disappear(self) -> None:
        receipt = yaml.safe_load(guard.RECEIPT.read_text(encoding="utf-8"))
        receipt["limitations"].remove("multi_provider_collection_not_accepted")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "receipt.yaml"
            path.write_text(yaml.safe_dump(receipt), encoding="utf-8")
            errors = guard.validate(receipt_path=path)
        self.assertIn("Batch12 runtime limitations drift", errors)

    def test_manifest_commit_cannot_be_relabelled(self) -> None:
        manifest = yaml.safe_load(guard.MANIFEST.read_text(encoding="utf-8"))
        manifest["accepted_commit"] = "0" * 40
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.yaml"
            path.write_text(yaml.safe_dump(manifest, sort_keys=False), encoding="utf-8")
            errors = guard.validate(manifest_path=path)
        self.assertIn("Batch12 exact manifest drift", errors)
        self.assertIn("Batch12 manifest commit, tree or closure drift", errors)

    def test_missing_cas_blob_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            errors = guard.validate(cas_root=Path(directory))
        self.assertTrue(any("CAS blob missing or drifted" in error for error in errors))

    def test_written_navigation_is_exactly_bound(self) -> None:
        self.assertEqual(guard._digest(guard.NAVIGATION), guard.EXPECTED_NAVIGATION_SHA256)

    def test_acceptance_cannot_drop_multi_provider_limitation(self) -> None:
        acceptance = yaml.safe_load(guard.ACCEPTANCE.read_text(encoding="utf-8"))
        acceptance["not_accepted"].remove("multi_provider_collection")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "acceptance.yaml"
            path.write_text(yaml.safe_dump(acceptance), encoding="utf-8")
            errors = guard.validate(acceptance_path=path)
        self.assertIn("Batch12 acceptance limitations overclaim", errors)

    def test_acceptance_cannot_drop_p3_disclosure(self) -> None:
        acceptance = yaml.safe_load(guard.ACCEPTANCE.read_text(encoding="utf-8"))
        adversarial = next(item for item in acceptance["advisory_roasts"] if item["role"] == "adversarial")
        del adversarial["p3_disclosed_as"]
        with tempfile.TemporaryDirectory() as directory:
            path = self._write_yaml(directory, "acceptance.yaml", acceptance)
            errors = guard.validate(acceptance_path=path)
        self.assertIn("Batch12 normalized acceptance semantics drift", errors)

    def test_acceptance_cannot_expand_accepted_scope(self) -> None:
        for capability in ("multi_provider_collection", "user_validation"):
            with self.subTest(capability=capability):
                acceptance = yaml.safe_load(guard.ACCEPTANCE.read_text(encoding="utf-8"))
                acceptance["accepted_scope_only"].append(capability)
                with tempfile.TemporaryDirectory() as directory:
                    path = self._write_yaml(directory, "acceptance.yaml", acceptance)
                    errors = guard.validate(acceptance_path=path)
                self.assertIn("Batch12 normalized acceptance semantics drift", errors)

    def test_acceptance_cannot_erase_external_trust_limitation(self) -> None:
        acceptance = yaml.safe_load(guard.ACCEPTANCE.read_text(encoding="utf-8"))
        acceptance["mechanical_acceptance_basis"]["limitation"] = "none"
        with tempfile.TemporaryDirectory() as directory:
            path = self._write_yaml(directory, "acceptance.yaml", acceptance)
            errors = guard.validate(acceptance_path=path)
        self.assertIn("Batch12 normalized acceptance semantics drift", errors)

    def test_workflow_cannot_skip_jobs_or_commands(self) -> None:
        source = guard.WORKFLOW.read_text(encoding="utf-8")
        mutations = (
            source.replace("  trust-unit:\n", "  trust-unit:\n    if: false\n").replace(
                "  real-runtime:\n", "  real-runtime:\n    if: false\n"
            ),
            source.replace(
                "run: python3 tools/checks/mint_next_batch12_amount_runtime_guard.py",
                "run: echo skipped",
            ),
            source.replace("    runs-on: ubuntu-latest\n", "    continue-on-error: true\n    runs-on: ubuntu-latest\n", 1),
        )
        for index, mutation in enumerate(mutations):
            with self.subTest(index=index), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "workflow.yml"
                path.write_text(mutation, encoding="utf-8")
                errors = guard.validate(workflow_path=path)
            self.assertIn("Batch12 normalized workflow semantics drift", errors)

    def test_coordinated_acceptance_hash_rewrite_still_fails(self) -> None:
        acceptance = yaml.safe_load(guard.ACCEPTANCE.read_text(encoding="utf-8"))
        acceptance["accepted_scope_only"].append("user_validation")
        with tempfile.TemporaryDirectory() as directory:
            acceptance_path = self._write_yaml(directory, "acceptance.yaml", acceptance)
            digest = hashlib.sha256(acceptance_path.read_bytes()).hexdigest()
            workflow = guard.WORKFLOW.read_text(encoding="utf-8")
            workflow = workflow.replace(
                guard._workflow_trust_binding(guard.WORKFLOW, "EXPECTED_BATCH12_ACCEPTANCE_SHA256"),
                digest,
            )
            workflow_path = Path(directory) / "workflow.yml"
            workflow_path.write_text(workflow, encoding="utf-8")
            errors = guard.validate(acceptance_path=acceptance_path, workflow_path=workflow_path)
        self.assertIn("Batch12 normalized acceptance semantics drift", errors)
        self.assertNotIn(
            "Batch12 workflow trust binding drift: EXPECTED_BATCH12_ACCEPTANCE_SHA256",
            errors,
        )

    def test_workflow_hash_mismatch_fails_explicit_binding(self) -> None:
        source = guard.WORKFLOW.read_text(encoding="utf-8").replace(
            guard._workflow_trust_binding(guard.WORKFLOW, "EXPECTED_BATCH12_TESTS_SHA256"),
            "0" * 64,
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "workflow.yml"
            path.write_text(source, encoding="utf-8")
            errors = guard.validate(workflow_path=path)
        self.assertIn(
            "Batch12 workflow trust binding drift: EXPECTED_BATCH12_TESTS_SHA256",
            errors,
        )


if __name__ == "__main__":
    unittest.main()
