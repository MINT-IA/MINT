from __future__ import annotations

import hashlib
import re
import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_batch16_classification_model_guard import validate_static


ROOT = Path(__file__).resolve().parents[3]
FILES = (
    Path("product/mint_next/batch7/design_lab/lib/multi_provider_amount_draft.dart"),
    Path("product/mint_next/batch7/design_lab/lib/multi_provider_amount_editor.dart"),
    Path("product/mint_next/batch7/design_lab/lib/design_lab_app.dart"),
    Path("product/mint_next/batch7/design_lab/lib/main.dart"),
    Path("product/mint_next/batch7/design_lab/test/multi_provider_classification_test.dart"),
    Path("product/mint_next/batch16/model-groundwork-acceptance.yaml"),
    Path("lefthook.yml"),
    Path(".github/workflows/mint-next-batch16-runtime.yml"),
    Path("tools/checks/mint_next_batch16_classification_model_guard.py"),
    Path("tools/checks/tests/test_mint_next_batch16_classification_model_guard.py"),
    Path("product/mint_next/batch7/design_lab/test/multi_provider_amount_draft_test.dart"),
    Path("product/mint_next/batch7/design_lab/test/design_lab_multi_provider_runtime_test.dart"),
    Path("product/mint_next/batch7/design_lab/test/multi_provider_unresolved_siblings_test.dart"),
    Path("product/mint_next/batch16/runtime-navigation-acceptance.yaml"),
)


class Batch16ClassificationModelGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for relative in FILES:
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, destination)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _rebind_receipt_hash(self) -> None:
        receipt = self.root / FILES[5]
        workflow = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        digest = hashlib.sha256(receipt.read_bytes()).hexdigest()
        source = workflow.read_text()
        source = re.sub(
            r"(?m)^(  EXPECTED_BATCH16_MODEL_RECEIPT_SHA256: )[0-9a-f]{64}$",
            rf"\g<1>{digest}",
            source,
        )
        workflow.write_text(source)

    def test_current_model_groundwork_passes(self) -> None:
        self.assertEqual(validate_static(self.root), [])

    def test_missing_executable_test_is_rejected(self) -> None:
        path = self.root / FILES[4]
        path.write_text(path.read_text().replace("test('unresolved remains provisional but blocks review and commit'", "test('removed hostile proof'"))
        self.assertTrue(validate_static(self.root))

    def test_classification_test_digest_drift_is_rejected(self) -> None:
        path = self.root / FILES[4]
        path.write_text(path.read_text() + "\n// weakened proof\n")
        self.assertTrue(validate_static(self.root))

    def test_missing_sibling_executable_test_is_rejected(self) -> None:
        path = self.root / FILES[12]
        path.write_text(
            path.read_text().replace(
                "doubt issues distinct provider refund and all-zero siblings",
                "removed sibling proof",
            )
        )
        self.assertTrue(validate_static(self.root))

    def test_sibling_test_digest_drift_is_rejected(self) -> None:
        path = self.root / FILES[12]
        path.write_text(path.read_text() + "\n// weakened sibling proof\n")
        self.assertTrue(validate_static(self.root))

    def test_editor_exposure_is_rejected(self) -> None:
        path = self.root / FILES[1]
        path.write_text(path.read_text() + "\n// markAmountUnresolved\n")
        self.assertTrue(validate_static(self.root))

    def test_indirect_editor_classification_exposure_is_rejected(self) -> None:
        path = self.root / FILES[1]
        path.write_text(path.read_text() + "\n// row.classification\n")
        self.assertTrue(validate_static(self.root))

    def test_design_app_route_exposure_is_rejected(self) -> None:
        path = self.root / FILES[2]
        path.write_text(path.read_text() + "\n// MultiProviderAmountClassification\n")
        self.assertTrue(validate_static(self.root))

    def test_entrypoint_exposure_is_rejected(self) -> None:
        path = self.root / FILES[3]
        path.write_text(path.read_text() + "\n// markAmountUnresolved\n")
        self.assertTrue(validate_static(self.root))

    def test_runtime_acceptance_is_rejected(self) -> None:
        path = self.root / FILES[5]
        data = yaml.safe_load(path.read_text())
        data["full_batch16_runtime_acceptance"] = "accepted"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self.assertTrue(validate_static(self.root))

    def test_product_promotion_is_rejected(self) -> None:
        path = self.root / FILES[5]
        data = yaml.safe_load(path.read_text())
        data["product_promotion"] = "accepted"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rebind_receipt_hash()
        self.assertTrue(validate_static(self.root))

    def test_coordinated_behavior_claim_drift_is_rejected(self) -> None:
        path = self.root / FILES[5]
        data = yaml.safe_load(path.read_text())
        data["accepted_behavior"]["provider_total"] = "confirmed"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rebind_receipt_hash()
        self.assertTrue(validate_static(self.root))

    def test_coordinated_hidden_exclusion_removal_is_rejected(self) -> None:
        path = self.root / FILES[5]
        data = yaml.safe_load(path.read_text())
        data["explicitly_not_implemented"].remove("product_route")
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rebind_receipt_hash()
        self.assertTrue(validate_static(self.root))

    def test_red_first_commit_identity_drift_is_rejected(self) -> None:
        path = self.root / FILES[5]
        data = yaml.safe_load(path.read_text())
        data["red_test_commit"] = "not-red-first"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rebind_receipt_hash()
        self.assertTrue(validate_static(self.root))

    def test_coordinated_proof_claim_drift_is_rejected(self) -> None:
        path = self.root / FILES[5]
        data = yaml.safe_load(path.read_text())
        data["proofs"]["combined_model_and_widget_runtime_tests"] = 8
        data["proofs"]["flutter_analyze"] = "not_run"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rebind_receipt_hash()
        self.assertTrue(validate_static(self.root))

    def test_coordinated_receipt_identity_and_extra_claim_are_rejected(self) -> None:
        path = self.root / FILES[5]
        data = yaml.safe_load(path.read_text())
        data["schema_version"] = 999
        data["batch"] = "other"
        data["contract_ref"] = "product/mint_next/batch0/foundation.yaml"
        data["runtime_accepted"] = True
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rebind_receipt_hash()
        self.assertTrue(validate_static(self.root))

    def test_coordinated_nested_exact_files_claim_is_rejected(self) -> None:
        path = self.root / FILES[5]
        data = yaml.safe_load(path.read_text())
        data["exact_files"]["runtime_route"] = "accepted"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rebind_receipt_hash()
        self.assertTrue(validate_static(self.root))

    def test_prior_model_suite_drift_is_rejected(self) -> None:
        path = self.root / "product/mint_next/batch7/design_lab/test/multi_provider_amount_draft_test.dart"
        path.write_text("void main() {}\n")
        self.assertTrue(validate_static(self.root))

    def test_prior_widget_suite_drift_is_rejected(self) -> None:
        path = self.root / "product/mint_next/batch7/design_lab/test/design_lab_multi_provider_runtime_test.dart"
        path.write_text("void main() {}\n")
        self.assertTrue(validate_static(self.root))

    def test_nonzero_roast_is_rejected(self) -> None:
        path = self.root / FILES[5]
        data = yaml.safe_load(path.read_text())
        data["roast_receipt"]["adversarial"] = "rejected_p2_1"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self.assertTrue(validate_static(self.root))

    def test_duplicate_receipt_key_is_rejected(self) -> None:
        path = self.root / FILES[5]
        path.write_text(path.read_text() + "\nstatus: promoted\n")
        self.assertTrue(validate_static(self.root))

    def test_removed_lefthook_binding_is_rejected(self) -> None:
        path = self.root / "lefthook.yml"
        path.write_text(path.read_text().replace("mint-next-batch16-classification-model-guard:", "removed-model-guard:"))
        self.assertTrue(validate_static(self.root))

    def test_commented_lefthook_binding_is_rejected(self) -> None:
        path = self.root / "lefthook.yml"
        source = path.read_text()
        source = source.replace(
            "    mint-next-batch16-classification-model-guard:",
            "    # mint-next-batch16-classification-model-guard:",
        ).replace(
            "      run: python3 tools/checks/mint_next_batch16_classification_model_guard.py",
            "      # run: python3 tools/checks/mint_next_batch16_classification_model_guard.py",
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_global_lefthook_skip_is_rejected(self) -> None:
        path = self.root / "lefthook.yml"
        source = path.read_text().replace(
            "pre-commit:\n",
            "pre-commit:\n  skip: true\n",
            1,
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_root_lefthook_skip_policy_drift_is_rejected(self) -> None:
        path = self.root / "lefthook.yml"
        source = path.read_text().replace(
            "skip:\n  - merge\n  - rebase\n",
            "skip: true\n",
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_model_lefthook_command_skip_is_rejected(self) -> None:
        path = self.root / "lefthook.yml"
        source = path.read_text().replace(
            "    mint-next-batch16-classification-model-guard:\n",
            "    mint-next-batch16-classification-model-guard:\n      skip: true\n",
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_removed_ci_binding_is_rejected(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        path.write_text(path.read_text().replace("python3 tools/checks/mint_next_batch16_classification_model_guard.py --static-only", "echo removed-model-guard"))
        self.assertTrue(validate_static(self.root))

    def test_commented_ci_binding_is_rejected(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        source = path.read_text().replace(
            "        run: python3 tools/checks/mint_next_batch16_classification_model_guard.py --static-only",
            "        # run: python3 tools/checks/mint_next_batch16_classification_model_guard.py --static-only",
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_manual_only_ci_trigger_is_rejected(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        source = path.read_text().replace(
            "on:\n  pull_request:\n    branches: [dev, staging, main]\n  push:\n    branches: [dev, staging, main]\n",
            "on: workflow_dispatch\n",
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_commented_ci_trust_hash_is_rejected(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        source = path.read_text().replace(
            "  EXPECTED_BATCH16_MODEL_RECEIPT_SHA256:",
            "  # EXPECTED_BATCH16_MODEL_RECEIPT_SHA256:",
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_disabled_ci_jobs_are_rejected(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        source = path.read_text().replace(
            "  hidden-model-trust:\n",
            "  hidden-model-trust:\n    if: false\n",
        ).replace(
            "  hidden-model-flutter:\n",
            "  hidden-model-flutter:\n    if: false\n",
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_soft_fail_ci_jobs_are_rejected(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        source = path.read_text().replace(
            "  hidden-model-trust:\n",
            "  hidden-model-trust:\n    continue-on-error: true\n",
        ).replace(
            "  hidden-model-flutter:\n",
            "  hidden-model-flutter:\n    continue-on-error: true\n",
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_ci_proof_jobs_cannot_gain_skip_dependencies(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        source = path.read_text().replace(
            "  hidden-model-trust:\n",
            "  hidden-model-trust:\n    needs: written-contract\n",
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_ci_flutter_job_rejects_fake_tool_path_hijack(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        source = path.read_text().replace(
            "  hidden-model-flutter:\n    name: Hidden classification model Flutter proof\n    runs-on: ubuntu-latest\n    steps:\n",
            "  hidden-model-flutter:\n    name: Hidden classification model Flutter proof\n    runs-on: ubuntu-latest\n    steps:\n      - name: Inject fake Flutter\n        run: |\n          mkdir -p /tmp/fake-flutter\n          printf '#!/bin/sh\\nexit 0\\n' > /tmp/fake-flutter/flutter\n          chmod +x /tmp/fake-flutter/flutter\n          echo /tmp/fake-flutter >> \"$GITHUB_PATH\"\n",
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_ci_rejects_root_path_or_defaults_injection(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        source = path.read_text().replace(
            "env:\n",
            "defaults:\n  run:\n    shell: /tmp/fake-shell\nenv:\n  PATH: /tmp/fake-flutter\n",
            1,
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_ci_rejects_untrusted_proof_runner(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        source = path.read_text().replace(
            "    runs-on: ubuntu-latest",
            "    runs-on: self-hosted",
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))

    def test_soft_fail_ci_proof_step_is_rejected(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        source = path.read_text().replace(
            "      - name: Verify hidden classification model and all prior model behavior\n",
            "      - name: Verify hidden classification model and all prior model behavior\n        continue-on-error: true\n",
        )
        path.write_text(source)
        self.assertTrue(validate_static(self.root))


if __name__ == "__main__":
    unittest.main()
