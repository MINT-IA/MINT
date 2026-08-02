from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_batch8_lpp_runtime_guard import ACCEPTANCE, APP, L10N, RECEIPT, WORKFLOW, validate


class Batch8LppRuntimeGuardTest(unittest.TestCase):
    def test_current_runtime_passes(self) -> None:
        self.assertEqual(validate(), [])

    def test_rejects_dead_button_binding(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.dart"
            path.write_text(APP.read_text().replace("action:fact_lpp_affiliation.choose_yes", "action:dead"), encoding="utf-8")
            self.assertIn("Batch8 Flutter binding missing: action:fact_lpp_affiliation.choose_yes", validate(app_path=path))

    def test_rejects_actual_yes_route_mutation_even_when_tokens_remain(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.dart"
            source = APP.read_text(encoding="utf-8")
            source = source.replace(
                "_LppAffiliation.yes => _DesignNode.factContribution,",
                "_LppAffiliation.yes => _DesignNode.lppUnknownHelp,",
            )
            path.write_text(source, encoding="utf-8")
            self.assertIn("Batch8 exact Flutter app bytes drift", validate(app_path=path))

    def test_rejects_harmful_copy_or_amount(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for source in L10N.glob("app_*.arb"):
                data = json.loads(source.read_text())
                if source.name == "app_fr.arb":
                    data["withoutLppBody"] = "Tu es inéligible. CHF 99 999."
                (target / source.name).write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            errors = validate(l10n_path=target)
            self.assertIn("Batch8 exact fr ARB bytes drift", errors)
            self.assertIn("Batch8 LPP slice leaks an amount, threshold or percentage", errors)

    def test_rejects_harmful_german_copy_with_unchanged_keys(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for source in L10N.glob("app_*.arb"):
                data = json.loads(source.read_text())
                if source.name == "app_de.arb":
                    data["withoutLppBody"] = "Du bist nicht berechtigt."
                (target / source.name).write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            self.assertIn("Batch8 exact de ARB bytes drift", validate(l10n_path=target))

    def test_rejects_six_locale_key_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for source in L10N.glob("app_*.arb"):
                data = json.loads(source.read_text())
                if source.name == "app_de.arb":
                    data.pop("lppQuestionTitle")
                (target / source.name).write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            self.assertIn("Batch8 ARB keys differ across six locales", validate(l10n_path=target))

    def test_rejects_safe_exit_destination_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.dart"
            source = APP.read_text(encoding="utf-8")
            self.assertIn("_leaveWithoutSaving();", source)
            source = source.replace(
                "_leaveWithoutSaving();",
                "_go(_DesignNode.dismissed);",
                1,
            )
            path.write_text(source, encoding="utf-8")
            self.assertIn("Batch8 exact Flutter app bytes drift", validate(app_path=path))

    def test_rejects_duplicate_capture_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "receipt.yaml"
            receipt = yaml.safe_load(RECEIPT.read_text(encoding="utf-8"))
            receipt["captures"][1]["path"] = receipt["captures"][0]["path"]
            receipt["captures"][1]["sha256"] = receipt["captures"][0]["sha256"]
            path.write_text(yaml.safe_dump(receipt, sort_keys=False), encoding="utf-8")
            errors = validate(receipt_path=path)
            self.assertIn(
                "Batch8 exact accepted artifact drift: product/mint_next/batch8/evidence/runtime/receipt.yaml",
                errors,
            )
            self.assertIn("Batch8 runtime captures are not distinct", errors)

    def test_rejects_acceptance_limit_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "acceptance.yaml"
            path.write_text(
                ACCEPTANCE.read_text(encoding="utf-8").replace("  - ios_runtime\n", ""),
                encoding="utf-8",
            )
            self.assertIn(
                "Batch8 exact accepted artifact drift: product/mint_next/batch8/design-lab-acceptance.yaml",
                validate(acceptance_path=path),
            )

    def test_rejects_ci_probe_replaced_by_echo(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "workflow.yaml"
            path.write_text(
                WORKFLOW.read_text(encoding="utf-8").replace(
                    "run: python3 tools/checks/mint_next_batch10_contribution_runtime_probe.py",
                    "run: echo skipped",
                    1,
                ),
                encoding="utf-8",
            )
            self.assertIn(
                "Batch8 real Chrome probe is not mechanically enforced in CI",
                validate(workflow_path=path),
            )

    def _assert_ci_skip_mutation_rejected(self, old: str, new: str) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "workflow.yaml"
            source = WORKFLOW.read_text(encoding="utf-8")
            self.assertIn(old, source)
            path.write_text(source.replace(old, new, 1), encoding="utf-8")
            self.assertIn(
                "Batch8 real Chrome CI job permits skip, ignored failure or structural drift",
                validate(workflow_path=path),
            )

    def test_rejects_ci_probe_continue_on_error(self) -> None:
        self._assert_ci_skip_mutation_rejected(
            "        run: python3 tools/checks/mint_next_batch10_contribution_runtime_probe.py",
            "        run: python3 tools/checks/mint_next_batch10_contribution_runtime_probe.py\n        continue-on-error: true",
        )

    def test_rejects_ci_probe_false_condition(self) -> None:
        self._assert_ci_skip_mutation_rejected(
            "        run: python3 tools/checks/mint_next_batch10_contribution_runtime_probe.py",
            "        run: python3 tools/checks/mint_next_batch10_contribution_runtime_probe.py\n        if: false",
        )

    def test_rejects_ci_job_false_condition(self) -> None:
        self._assert_ci_skip_mutation_rejected(
            "  batch10-contribution-real-runtime:\n    name: Batch 10 contribution real Flutter Web navigation\n    runs-on: ubuntu-latest\n    steps:",
            "  batch10-contribution-real-runtime:\n    name: Batch 10 contribution real Flutter Web navigation\n    runs-on: ubuntu-latest\n    if: false\n    steps:",
        )

    def test_rejects_manual_only_ci_trigger(self) -> None:
        self._assert_ci_skip_mutation_rejected_with_message(
            "on:\n  pull_request:\n    branches: [dev, staging, main]\n  push:\n    branches: [dev, staging, main]",
            "on: workflow_dispatch",
            "Batch8 real Chrome CI triggers permit the runtime proof to be skipped",
        )

    def test_rejects_unreachable_ci_branch_trigger(self) -> None:
        self._assert_ci_skip_mutation_rejected_with_message(
            "branches: [dev, staging, main]",
            "branches: [never]",
            "Batch8 real Chrome CI triggers permit the runtime proof to be skipped",
        )

    def test_rejects_top_level_shell_default_bypass(self) -> None:
        self._assert_ci_skip_mutation_rejected_with_message(
            "concurrency:\n",
            "defaults:\n  run:\n    shell: bash -c 'exit 0' {0}\n\nconcurrency:\n",
            "Batch8 workflow top-level defaults or environment can bypass the runtime proof",
        )

    def test_rejects_top_level_environment_bypass(self) -> None:
        self._assert_ci_skip_mutation_rejected_with_message(
            "concurrency:\n",
            "env:\n  BASH_ENV: tools/always_success.sh\n\nconcurrency:\n",
            "Batch8 workflow top-level defaults or environment can bypass the runtime proof",
        )

    def test_rejects_invalid_concurrency_shape(self) -> None:
        self._assert_ci_skip_mutation_rejected_with_message(
            "concurrency:\n  group: ai-workflow-guards-${{ github.ref }}\n  cancel-in-progress: true",
            "concurrency: []",
            "Batch8 workflow concurrency can make the runtime proof invalid or non-runnable",
        )

    def test_rejects_invalid_concurrency_expression(self) -> None:
        self._assert_ci_skip_mutation_rejected_with_message(
            "group: ai-workflow-guards-${{ github.ref }}",
            "group: ${{ definitely invalid }}",
            "Batch8 workflow concurrency can make the runtime proof invalid or non-runnable",
        )

    def _assert_ci_skip_mutation_rejected_with_message(
        self,
        old: str,
        new: str,
        message: str,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "workflow.yaml"
            source = WORKFLOW.read_text(encoding="utf-8")
            self.assertIn(old, source)
            path.write_text(source.replace(old, new, 1), encoding="utf-8")
            self.assertIn(message, validate(workflow_path=path))


if __name__ == "__main__":
    unittest.main()
