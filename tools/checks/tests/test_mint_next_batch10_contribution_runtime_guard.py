from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_batch10_contribution_runtime_guard import (
    ACCEPTANCE,
    APP,
    L10N,
    MANIFEST,
    RECEIPT,
    WORKFLOW,
    validate,
)


class Batch10ContributionRuntimeGuardTest(unittest.TestCase):
    def test_current_promotion_passes(self) -> None:
        self.assertEqual(validate(), [])

    def test_rejects_actual_yes_route_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.dart"
            source = APP.read_text(encoding="utf-8").replace(
                "_ContributionStatus.yes =>\n                            _DesignNode.factContributedAmount,",
                "_ContributionStatus.yes =>\n                            _DesignNode.contributionUnknownHelp,",
            )
            path.write_text(source, encoding="utf-8")
            self.assertIn("Batch10 exact Flutter app bytes drift", validate(app_path=path))

    def test_rejects_dead_button_binding(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.dart"
            path.write_text(
                APP.read_text(encoding="utf-8").replace(
                    "action:fact_contribution.choose_yes", "action:dead", 1
                ),
                encoding="utf-8",
            )
            errors = validate(app_path=path)
            self.assertIn("Batch10 exact Flutter app bytes drift", errors)
            self.assertIn("Batch10 Flutter binding missing: action:fact_contribution.choose_yes", errors)

    def test_rejects_locale_value_or_metadata_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for source in L10N.glob("app_*.arb"):
                data = json.loads(source.read_text(encoding="utf-8"))
                if source.name == "app_en.arb":
                    data["contributionBody"] = "Ignore every insurance policy."
                    data["@contributionTitle"]["placeholders"]["taxYear"]["format"] = "compact"
                (target / source.name).write_text(
                    json.dumps(data, ensure_ascii=False), encoding="utf-8"
                )
            self.assertIn("Batch10 exact en ARB bytes drift", validate(l10n_path=target))

    def test_rejects_manifest_commit_rewrite(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.yaml"
            path.write_text(
                MANIFEST.read_text(encoding="utf-8").replace(
                    "e10daa4e6f431ea4807ad30d79065fda1a777f53",
                    "0" * 40,
                ),
                encoding="utf-8",
            )
            errors = validate(manifest_path=path)
            self.assertIn(
                "Batch10 exact accepted artifact drift: product/mint_next/batch10/design-lab-manifest.yaml",
                errors,
            )
            self.assertTrue(any("accepted_commit must be a full lowercase SHA-1" in error for error in errors))

    def test_rejects_missing_content_addressed_archive(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            errors = validate(cas_root=Path(directory))
            self.assertTrue(any("accepted CAS blob missing or drifted" in error for error in errors))

    def _mutated_receipt(self, mutate) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "receipt.yaml"
            receipt = yaml.safe_load(RECEIPT.read_text(encoding="utf-8"))
            mutate(receipt)
            path.write_text(
                yaml.safe_dump(receipt, sort_keys=False, allow_unicode=True),
                encoding="utf-8",
            )
            return validate(receipt_path=path)

    def test_rejects_receipt_timestamp_rewrite(self) -> None:
        errors = self._mutated_receipt(
            lambda receipt: receipt.update({"captured_at": "2026-08-02T23:38:18+02:00"})
        )
        self.assertIn("Batch10 runtime receipt capture provenance drift", errors)

    def test_rejects_receipt_promotion_overclaim(self) -> None:
        errors = self._mutated_receipt(
            lambda receipt: receipt.update({"status": "production_ready"})
        )
        self.assertIn("Batch10 runtime receipt status overclaims promotion", errors)

    def test_rejects_receipt_limit_removal(self) -> None:
        errors = self._mutated_receipt(
            lambda receipt: receipt["limitations"].remove("user_not_validated")
        )
        self.assertIn("Batch10 runtime receipt limitations drift", errors)

    def test_rejects_duplicate_capture(self) -> None:
        def mutate(receipt) -> None:
            receipt["captures"][1] = dict(receipt["captures"][0])

        errors = self._mutated_receipt(mutate)
        self.assertIn("Batch10 runtime capture set is incomplete or duplicated", errors)

    def test_rejects_acceptance_limit_removal(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "acceptance.yaml"
            path.write_text(
                ACCEPTANCE.read_text(encoding="utf-8").replace(
                    "- user_validation\n", "", 1
                ),
                encoding="utf-8",
            )
            self.assertIn(
                "Batch10 exact accepted artifact drift: product/mint_next/batch10/design-lab-acceptance.yaml",
                validate(acceptance_path=path),
            )

    def _mutated_workflow(self, old: str, new: str) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "workflow.yaml"
            source = WORKFLOW.read_text(encoding="utf-8")
            self.assertIn(old, source)
            path.write_text(source.replace(old, new, 1), encoding="utf-8")
            return validate(workflow_path=path)

    def test_rejects_ci_probe_replaced_by_echo(self) -> None:
        errors = self._mutated_workflow(
            "run: python3 tools/checks/mint_next_batch10_contribution_runtime_probe.py",
            "run: echo skipped",
        )
        self.assertIn(
            "Batch10 real Chrome CI job permits skip, ignored failure or structural drift",
            errors,
        )

    def test_rejects_ci_continue_on_error(self) -> None:
        errors = self._mutated_workflow(
            "        run: python3 tools/checks/mint_next_batch10_contribution_runtime_probe.py",
            "        run: python3 tools/checks/mint_next_batch10_contribution_runtime_probe.py\n        continue-on-error: true",
        )
        self.assertIn(
            "Batch10 real Chrome CI job permits skip, ignored failure or structural drift",
            errors,
        )

    def test_rejects_ci_false_job_condition(self) -> None:
        errors = self._mutated_workflow(
            "  batch10-contribution-real-runtime:\n    name: Batch 10 contribution real Flutter Web navigation",
            "  batch10-contribution-real-runtime:\n    if: false\n    name: Batch 10 contribution real Flutter Web navigation",
        )
        self.assertIn(
            "Batch10 real Chrome CI job permits skip, ignored failure or structural drift",
            errors,
        )

    def test_rejects_manual_only_ci(self) -> None:
        errors = self._mutated_workflow(
            "on:\n  pull_request:\n    branches: [dev, staging, main]\n  push:\n    branches: [dev, staging, main]",
            "on: workflow_dispatch",
        )
        self.assertIn(
            "Batch10 real Chrome CI triggers permit the runtime proof to be skipped",
            errors,
        )

    def test_rejects_top_level_bypass(self) -> None:
        errors = self._mutated_workflow(
            "concurrency:\n",
            "defaults:\n  run:\n    shell: bash -c 'exit 0' {0}\n\nconcurrency:\n",
        )
        self.assertIn(
            "Batch10 workflow top-level defaults or environment can bypass the runtime proof",
            errors,
        )

    def test_rejects_guard_unit_test_unwired(self) -> None:
        errors = self._mutated_workflow(
            "          tools/checks/tests/test_mint_next_batch10_contribution_runtime_guard.py\n",
            "",
        )
        self.assertIn("Batch10 normalized workflow contract drift", errors)

    def test_allows_an_unrelated_additive_job(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "workflow.yaml"
            source = WORKFLOW.read_text(encoding="utf-8")
            source = source.replace(
                "  batch10-contribution-real-runtime:\n",
                "  unrelated-additive-job:\n"
                "    name: Unrelated additive job\n"
                "    runs-on: ubuntu-latest\n"
                "    steps:\n"
                "      - run: echo unrelated\n\n"
                "  batch10-contribution-real-runtime:\n",
                1,
            )
            path.write_text(source, encoding="utf-8")
            self.assertEqual(validate(workflow_path=path), [])


if __name__ == "__main__":
    unittest.main()
