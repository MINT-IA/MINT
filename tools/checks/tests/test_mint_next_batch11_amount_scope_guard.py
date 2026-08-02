from __future__ import annotations

import tempfile
import unittest
from copy import deepcopy
from pathlib import Path

import yaml

from tools.checks.mint_next_batch11_amount_scope_guard import LEGACY, SCOPE, SOURCES, WORKFLOW, load, validate


class Batch11AmountScopeGuardTest(unittest.TestCase):
    def test_current_written_contract_passes(self) -> None:
        self.assertEqual(validate(), [])

    def _mutate_scope(self, mutate) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scope.yaml"
            value = deepcopy(load(SCOPE))
            mutate(value)
            path.write_text(yaml.safe_dump(value, sort_keys=False, allow_unicode=True), encoding="utf-8")
            return validate(scope_path=path, check_runtime=False)

    def _mutate_sources(self, mutate) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sources.yaml"
            value = deepcopy(load(SOURCES))
            mutate(value)
            path.write_text(yaml.safe_dump(value, sort_keys=False, allow_unicode=True), encoding="utf-8")
            return validate(sources_path=path, check_runtime=False)

    def _mutate_legacy(self, mutate) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "legacy.yaml"
            value = deepcopy(load(LEGACY))
            mutate(value)
            path.write_text(yaml.safe_dump(value, sort_keys=False, allow_unicode=True), encoding="utf-8")
            return validate(legacy_path=path, check_runtime=False)

    def _mutate_workflow(self, old: str, new: str) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "workflow.yml"
            source = WORKFLOW.read_text(encoding="utf-8")
            self.assertIn(old, source)
            path.write_text(source.replace(old, new, 1), encoding="utf-8")
            return validate(workflow_path=path, check_runtime=False)

    def test_rejects_runtime_authorization(self) -> None:
        errors = self._mutate_scope(lambda value: value["authority"].update({"runtime_change": "allowed"}))
        self.assertIn("Batch11 authority or no-runtime boundary drift", errors)

    def test_rejects_entry_without_explicit_yes(self) -> None:
        errors = self._mutate_scope(lambda value: value["slice"]["entry_preconditions"].update({"ordinary_contribution_status": "unknown"}))
        self.assertIn("Batch11 yes/LPP/year entry invariant drift", errors)

    def test_rejects_unknown_route_to_canton(self) -> None:
        errors = self._mutate_scope(lambda value: value["slice"]["routes"].update({"missing_or_unknown_amount": "fact_canton"}))
        self.assertIn("Batch11 route table drift or dead path", errors)

    def test_rejects_float_money(self) -> None:
        errors = self._mutate_scope(lambda value: value["fact_contract"].update({"canonical_representation": "double"}))
        self.assertIn("Batch11 exact money representation drift", errors)

    def test_rejects_partial_as_complete(self) -> None:
        errors = self._mutate_scope(lambda value: value["fact_contract"]["canonical_value_only_when"].update({"all_personal_providers_reviewed": False}))
        self.assertIn("Batch11 incomplete subtotal could become canonical", errors)

    def test_rejects_yes_or_unknown_becoming_zero(self) -> None:
        errors = self._mutate_scope(lambda value: value["fact_contract"]["zero_invariant"].update({"blank_parse_error_or_unknown": "zero"}))
        self.assertIn("Batch11 unknown/blank/yes could become zero", errors)

    def test_rejects_planned_amount_inference(self) -> None:
        errors = self._mutate_scope(lambda value: value["fact_contract"]["never_derive_from"].remove("planned_scheduled_or_habitual_contribution"))
        self.assertIn("Batch11 unsafe amount inference became allowed", errors)

    def test_rejects_transfer_counting(self) -> None:
        errors = self._mutate_scope(lambda value: value["fact_contract"]["explicit_exclusions"].remove("provider_to_provider_transfer_inbound_and_outbound"))
        self.assertIn("Batch11 special movements could be double-counted", errors)

    def test_rejects_provider_total_plus_contract_lines(self) -> None:
        errors = self._mutate_scope(lambda value: value["aggregation_contract"].update({"do_not_double_count": "optional"}))
        self.assertIn("Batch11 aggregation invariant drift: do_not_double_count", errors)

    def test_rejects_duplicate_certificate_addition(self) -> None:
        errors = self._mutate_scope(lambda value: value["aggregation_contract"].update({"duplicate_or_reissued_evidence": "add_both"}))
        self.assertIn("Batch11 aggregation invariant drift: duplicate_or_reissued_evidence", errors)

    def test_rejects_mental_refund_subtraction(self) -> None:
        errors = self._mutate_scope(lambda value: value["aggregation_contract"].update({"partial_refund": "user_subtracts"}))
        self.assertIn("Batch11 aggregation invariant drift: partial_refund", errors)

    def test_rejects_ceiling_clamp(self) -> None:
        errors = self._mutate_scope(lambda value: value["aggregation_contract"].update({"over_ceiling_assertion": "clamp_to_ceiling"}))
        self.assertIn("Batch11 aggregation invariant drift: over_ceiling_assertion", errors)

    def test_rejects_continue_without_complete_positive_guard(self) -> None:
        errors = self._mutate_scope(lambda value: value["node_contracts"]["fact_contributed_amount"]["controls"]["continue"].update({"guard": "subtotal_nonnegative"}))
        self.assertIn("Batch11 continue can commit incomplete or zero total", errors)

    def test_rejects_dead_unknown_help(self) -> None:
        errors = self._mutate_scope(lambda value: value["node_contracts"]["contributed_amount_unknown_help"]["controls"]["found_amount"].update({"to": "dead"}))
        self.assertIn("Batch11 unknown-help route is dead or personal", errors)

    def test_rejects_ambiguous_separator_guess(self) -> None:
        errors = self._mutate_scope(lambda value: value["input_contract"].update({"ambiguous_or_mixed_separators": "guess"}))
        self.assertIn("Batch11 ambiguous amount parser drift", errors)

    def test_rejects_locale_parser_treating_comma_as_grouping(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["input_contract"].update(
                {"comma_or_point_with_three_trailing_digits": "accept_as_grouping"}
            )
        )
        self.assertIn("Batch11 six-locale parser grammar drift", errors)

    def test_rejects_silent_rounding_or_clamp(self) -> None:
        errors = self._mutate_scope(lambda value: value["input_contract"].update({"no_silent_rounding_truncation_clamping_or_fx": False}))
        self.assertIn("Batch11 parser can silently alter user amount", errors)

    def test_rejects_amount_telemetry(self) -> None:
        errors = self._mutate_scope(lambda value: value["input_contract"].update({"amount_logging_analytics_and_crash_breadcrumbs": "allowed"}))
        self.assertIn("Batch11 private amount telemetry became allowed", errors)

    def test_rejects_stale_amount_after_status_change(self) -> None:
        errors = self._mutate_scope(lambda value: value["interaction_contract"].update({"status_change_to_no_or_unknown": "preserve_total"}))
        self.assertIn("Batch11 status correction leaves stale amount", errors)

    def test_rejects_missing_provider_q_source_anchor(self) -> None:
        def mutate(value) -> None:
            item = next(item for item in value["sources"] if item["id"] == "estv_form_21_edp_notice")
            item["anchors"].remove("marginal_27_provider_total_q_is_actual_total_not_only_deductible_ceiling")
        errors = self._mutate_sources(mutate)
        self.assertIn("Batch11 provider total q source anchor missing", errors)

    def test_rejects_buyback_merged_in_current_form(self) -> None:
        def mutate(value) -> None:
            item = next(item for item in value["sources"] if item["id"] == "estv_form_21_edp_2026")
            item["anchors"].remove("field_x_total_3a_buybacks")
        errors = self._mutate_sources(mutate)
        self.assertIn("Batch11 current form ordinary/buyback separation missing", errors)

    def test_rejects_legacy_habitual_amount_reuse(self) -> None:
        def mutate(value) -> None:
            item = next(item for item in value["candidates"] if item["symbol"] == "q_3a_annual_contribution")
            item["decision"] = "reuse"
        errors = self._mutate_legacy(mutate)
        self.assertIn("Batch11 legacy habitual amount became canonical", errors)

    def test_rejects_legacy_chat_amount_widget_reuse(self) -> None:
        def mutate(value) -> None:
            item = next(item for item in value["candidates"] if item["symbol"] == "ChatAmountInput")
            item["decision"] = "reuse"
        errors = self._mutate_legacy(mutate)
        self.assertIn("Batch11 unsafe ChatAmountInput became reusable", errors)

    def test_rejects_premature_single_big_runtime(self) -> None:
        errors = self._mutate_scope(lambda value: value.update({"implementation_slices_after_written_acceptance": ["full_product_runtime"]}))
        self.assertIn("Batch11 future implementation is no longer split into bounded slices", errors)

    def test_rejects_ci_guard_replaced_by_echo(self) -> None:
        errors = self._mutate_workflow(
            "run: python3 tools/checks/mint_next_batch11_amount_scope_guard.py",
            "run: echo skipped",
        )
        self.assertIn("Batch11 CI job permits skip ignored failure or command drift", errors)

    def test_rejects_ci_job_false_condition(self) -> None:
        errors = self._mutate_workflow(
            "  contract:\n    name:",
            "  contract:\n    if: false\n    name:",
        )
        self.assertIn("Batch11 CI job permits skip ignored failure or command drift", errors)

    def test_rejects_ci_continue_on_error(self) -> None:
        errors = self._mutate_workflow(
            "        run: python3 -m unittest tools.checks.tests.test_mint_next_batch11_amount_scope_guard",
            "        run: python3 -m unittest tools.checks.tests.test_mint_next_batch11_amount_scope_guard\n        continue-on-error: true",
        )
        self.assertIn("Batch11 CI job permits skip ignored failure or command drift", errors)

    def test_rejects_manual_only_ci(self) -> None:
        errors = self._mutate_workflow(
            "on:\n  pull_request:\n    branches: [dev, staging, main]\n  push:\n    branches: [dev, staging, main]",
            "on: workflow_dispatch",
        )
        self.assertIn("Batch11 CI triggers permit the written gate to be skipped", errors)


if __name__ == "__main__":
    unittest.main()
