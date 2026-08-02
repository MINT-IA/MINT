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

    def test_rejects_full_refund_auto_zero(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["aggregation_contract"]["full_refund"].update(
                {"aggregate_becomes_zero": "commit_zero_and_continue"}
            )
        )
        self.assertIn("Batch11 full refund can silently commit zero", errors)

    def test_rejects_sensitive_identifier_in_optional_label(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["aggregation_contract"].update(
                {"provider_name_forbidden_content": []}
            )
        )
        self.assertIn("Batch11 duplicate-provider or sensitive-identifier invariant drift", errors)

    def test_rejects_forbidding_the_required_provider_name(self) -> None:
        def mutate(value) -> None:
            forbidden = value["node_contracts"]["fact_contributed_amount"]["forbidden"]
            forbidden.remove("mandatory_account_policy_avs_or_iban_identifier")
            forbidden.append("mandatory_provider_name_or_identifier")
        errors = self._mutate_scope(mutate)
        self.assertIn("Batch11 required provider name contradicts its forbidden controls", errors)

    def test_rejects_duplicate_provider_rows_becoming_canonical(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["fact_contract"]["canonical_value_only_when"].update(
                {"normalized_provider_names_unique": False}
            )
        )
        self.assertIn("Batch11 incomplete subtotal could become canonical", errors)

    def test_rejects_provider_name_not_being_ephemeral(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["aggregation_contract"].update(
                {"provider_name_storage": "persisted"}
            )
        )
        self.assertIn("Batch11 privacy-safe provider discriminator drift", errors)

    def test_rejects_continue_without_complete_positive_guard(self) -> None:
        errors = self._mutate_scope(lambda value: value["node_contracts"]["fact_contributed_amount"]["controls"]["continue"].update({"guard": "subtotal_nonnegative"}))
        self.assertIn("Batch11 continue can commit incomplete or zero total", errors)

    def test_rejects_removing_the_only_provider_row(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["node_contracts"]["fact_contributed_amount"]["controls"]["remove_provider"].update(
                {"minimum_rows_after_removal": 0}
            )
        )
        self.assertIn("Batch11 provider removal can leave zero rows", errors)

    def test_rejects_missing_disclosure_copy(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["node_contracts"]["fact_contributed_amount"]["reference_copy_fr"].pop("where_to_find_body")
        )
        self.assertIn("Batch11 provider-label privacy or disclosure copy drift", errors)

    def test_rejects_stale_empty_error_action_label(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["node_contracts"]["fact_contributed_amount"]["inline_errors"].update(
                {"all_rows_empty": "Choisis Je ne sais pas."}
            )
        )
        self.assertIn("Batch11 inline error does not match visible action or duplicate state", errors)

    def test_rejects_partial_action_without_positive_draft_guard(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["node_contracts"]["fact_contributed_amount"]["controls"]["missing_amount"].update(
                {"visible_when": "always"}
            )
        )
        self.assertIn("Batch11 partial and no-amount actions can contradict working state", errors)

    def test_rejects_unknown_action_with_positive_draft(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["node_contracts"]["fact_contributed_amount"]["controls"]["unknown_amount"].update(
                {"visible_when": "always"}
            )
        )
        self.assertIn("Batch11 partial and no-amount actions can contradict working state", errors)

    def test_rejects_dead_unknown_help(self) -> None:
        errors = self._mutate_scope(lambda value: value["node_contracts"]["contributed_amount_unknown_help"]["controls"]["found_amount"].update({"to": "dead"}))
        self.assertIn("Batch11 unknown-help route is dead or personal", errors)

    def test_rejects_missing_help_back_label(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["node_contracts"]["contributed_amount_unknown_help"]["reference_copy_fr"].pop("back")
        )
        self.assertIn("Batch11 help variants or Back copy missing", errors)

    def test_rejects_help_primary_action_redundant_with_back(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["node_contracts"]["contributed_amount_unknown_help"]["controls"]["found_amount"].pop("mutation")
        )
        self.assertIn("Batch11 help primary action and Back remain semantically redundant", errors)

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

    def test_rejects_forbidden_token_removal(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["input_contract"].update({"forbidden_tokens": []})
        )
        self.assertIn("Batch11 forbidden numeric token contract drift", errors)

    def test_rejects_missing_technical_overflow_bound(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["input_contract"].update(
                {"maximum_minor_units_technical_not_fiscal": None}
            )
        )
        self.assertIn("Batch11 non-fiscal technical input bound drift", errors)

    def test_rejects_stale_amount_after_status_change(self) -> None:
        errors = self._mutate_scope(lambda value: value["interaction_contract"].update({"status_change_to_no_or_unknown": "preserve_total"}))
        self.assertIn("Batch11 status correction leaves stale amount", errors)

    def test_rejects_stale_amount_after_fact_correction(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["fact_contract"].update(
                {"correction_effect": "preserve_canonical_total_and_result"}
            )
        )
        self.assertIn("Batch11 correction or tax-year clearing invariant drift", errors)

    def test_rejects_stale_amount_after_tax_year_change(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["fact_contract"].update(
                {"tax_year_change_effect": "keep_rows_and_result"}
            )
        )
        self.assertIn("Batch11 correction or tax-year clearing invariant drift", errors)

    def test_rejects_private_amount_after_app_kill(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["interaction_contract"].update(
                {"app_kill_or_ttl_expiry": "preserve_forever"}
            )
        )
        self.assertIn("Batch11 app-kill or TTL privacy purge drift", errors)

    def test_rejects_each_six_locale_semantic_invariant_removal(self) -> None:
        contract = load(SCOPE)["six_locale_intent_contract"]
        for intent in contract["required_distinctions_per_locale"]:
            with self.subTest(intent=intent):
                errors = self._mutate_scope(
                    lambda value, target=intent: value["six_locale_intent_contract"]["required_distinctions_per_locale"].remove(target)
                )
                self.assertIn("Batch11 six-locale semantic contract drift", errors)

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

    def test_rejects_contradictory_source_inference_unknown_is_zero(self) -> None:
        def mutate(value) -> None:
            value["derived_product_safety_inferences"].append(
                {
                    "id": "unknown_is_zero",
                    "reasoning": "Missing means zero.",
                    "classification": "product_safety_inference_not_direct_official_quote",
                    "source_ids": ["estv_circular_18a"],
                }
            )
        errors = self._mutate_sources(mutate)
        self.assertIn("Batch11 exact written artifact drift: product/mint_next/batch11/official-sources.yaml", errors)

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

    def test_rejects_slice1_without_completeness_control(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["implementation_slices_after_written_acceptance"][0]["rendered_controls"].remove("all_providers_reviewed")
        )
        self.assertIn("Batch11 future implementation is no longer split into bounded slices", errors)

    def test_rejects_mandatory_roast_removal(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["exit_gate"]["required"].remove("adversarial_roast")
        )
        self.assertIn("Batch11 mandatory roast or evidence gate drift", errors)

    def test_rejects_zero_copy_that_auto_changes_status(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["node_contracts"]["fact_contributed_amount"]["inline_errors"].update(
                {"zero": "Nous avons mis ta réponse sur non et continué."}
            )
        )
        self.assertIn("Batch11 exact written artifact drift: product/mint_next/batch11/ordinary-contribution-amount-scope.yaml", errors)

    def test_rejects_personal_tax_saving_copy(self) -> None:
        errors = self._mutate_scope(
            lambda value: value["node_contracts"]["fact_contributed_amount"]["reference_copy_fr"].update(
                {"not_result_note": "Tu économiseras CHF 2’000 d’impôt."}
            )
        )
        self.assertIn("Batch11 exact written artifact drift: product/mint_next/batch11/ordinary-contribution-amount-scope.yaml", errors)

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
