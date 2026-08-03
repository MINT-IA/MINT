from __future__ import annotations

import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from unittest.mock import patch

import yaml

from tools.checks.mint_next_batch13_multi_provider_contract_guard import (
    ACCEPTED_CANDIDATE_COMMIT,
    ACCEPTED_CANDIDATE_TREE,
    BASE_COMMIT,
    CONTRACT,
    EXPECTED_PROOF_OBLIGATIONS,
    ROOT,
    _candidate_tree,
    _runtime_drift,
    load,
    validate,
)


class Batch13MultiProviderContractGuardTest(unittest.TestCase):
    def _mutate_contract(self, mutate) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "contract.yaml"
            value = deepcopy(load(CONTRACT))
            mutate(value)
            path.write_text(yaml.safe_dump(value, sort_keys=False, allow_unicode=True), encoding="utf-8")
            return validate(contract_path=path, check_runtime=False)

    def test_current_package_passes(self) -> None:
        self.assertEqual(validate(), [])

    def test_runtime_boundary_is_bound_to_exact_candidate_not_future_head(self) -> None:
        with patch("tools.checks.mint_next_batch13_multi_provider_contract_guard.subprocess.run") as run:
            run.return_value.stdout = ""
            self.assertEqual(_runtime_drift(), [])
        run.assert_called_once_with(
            [
                "git", "diff", "--name-only", BASE_COMMIT, ACCEPTED_CANDIDATE_COMMIT, "--",
                "product/mint_next/batch7/design_lab", "apps/mobile", "services/backend",
            ],
            cwd=ROOT, check=True, capture_output=True, text=True,
        )

    def test_candidate_tree_is_bound_to_exact_commit(self) -> None:
        self.assertEqual(_candidate_tree(), ACCEPTED_CANDIDATE_TREE)

    def test_rejects_duplicate_yaml_mapping_key(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate.yaml"
            path.write_text(CONTRACT.read_text(encoding="utf-8") + "\nstatus: allowed\n", encoding="utf-8")
            errors = validate(contract_path=path, check_runtime=False)
        self.assertTrue(any("duplicate YAML key" in error for error in errors), errors)

    def test_rejects_removal_of_every_declared_hostile_obligation(self) -> None:
        for obligation in EXPECTED_PROOF_OBLIGATIONS:
            with self.subTest(obligation=obligation):
                errors = self._mutate_contract(
                    lambda value, item=obligation: value["proof_contract"]["written_guard_must_reject"].remove(item)
                )
                self.assertIn("Batch13 hostile written-proof obligations drift", errors)

    def test_rejects_runtime_authorization(self) -> None:
        errors = self._mutate_contract(lambda value: value["authority"].update({"runtime_change": "allowed"}))
        self.assertIn("Batch13 runtime authorization drift", errors)

    def test_rejects_six_locale_scope_loss(self) -> None:
        errors = self._mutate_contract(lambda value: value["scope"]["locales"].remove("de"))
        self.assertIn("Batch13 exact six-locale scope drift", errors)

    def test_rejects_any_implementation_boundary_opening(self) -> None:
        for boundary in load(CONTRACT)["content_boundaries"]:
            with self.subTest(boundary=boundary):
                errors = self._mutate_contract(
                    lambda value, key=boundary: value["content_boundaries"].update({key: "allowed"})
                )
                self.assertIn("Batch13 forbidden implementation boundary drift", errors)

    def test_rejects_dead_help_back_focus(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["graph"]["contributed_amount_unknown_help"]["mode_partial_known"]["back_or_system_back"].update(
                {"focus": "missing_amount_trigger"}
            )
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_unallocated_recovery_without_deterministic_under_capacity_path(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["missing_provider_resolution_contract"]["recovery_control_while_unallocated"].pop("under_capacity")
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_add_with_empty_row(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["graph"]["fact_contributed_amount"]["controls"]["add_provider"].update({"guard": "always"})
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_removing_the_only_row(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["graph"]["fact_contributed_amount"]["controls"]["remove_provider"].update(
                {"minimum_active_non_tombstoned_rows_after_removal": 0}
            )
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_silent_contentful_row_deletion(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["graph"]["fact_contributed_amount"]["controls"]["remove_provider"]["operation"].update(
                {"row_with_any_content": "delete_immediately"}
            )
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_partial_or_unconfirmed_continue(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["graph"]["fact_contributed_amount"]["controls"]["continue"].update({"guard": "subtotal_positive"})
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_subtotal_as_tax_result(self) -> None:
        errors = self._mutate_contract(lambda value: value["subtotal_contract"].update({"label_intent": "tax_saving"}))
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_float_or_unchecked_aggregate(self) -> None:
        errors = self._mutate_contract(lambda value: value["subtotal_contract"].update({"addition": "floating_point_sum"}))
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_overflow_confirmation(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["subtotal_contract"]["aggregate_overflow"].update({"confirmation": True})
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_identity_grade_duplicate_claim(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["row_contract"]["provider_name"].update({"alias_homoglyph_or_renamed_provider_identity_proof": "supported"})
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_private_state_persistence_telemetry_or_network(self) -> None:
        keys = [
            "provider_name_and_amount_persistence",
            "analytics_and_crash_reporting_of_names_amounts_or_subtotal",
            "network_transmission_of_names_amounts_subtotal_or_rows",
        ]
        for key in keys:
            with self.subTest(key=key):
                errors = self._mutate_contract(lambda value, target=key: value["state_contract"].update({target: "allowed"}))
                self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_stale_confirmation_after_edit(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["graph"]["fact_contributed_amount"]["controls"]["edit_amount"]["mutations"].remove("clear_all_providers_reviewed")
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_missing_token_or_provenance_from_purge(self) -> None:
        for field in ["missing_request_token", "missing_request_bound_row_id", "missing_request_row_provenance"]:
            with self.subTest(field=field):
                errors = self._mutate_contract(lambda value, item=field: value["state_contract"]["personal_state_purge_fields"].remove(item))
                self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_any_personal_purge_field_loss(self) -> None:
        for field in load(CONTRACT)["state_contract"]["personal_state_purge_fields"]:
            with self.subTest(field=field):
                errors = self._mutate_contract(lambda value, item=field: value["state_contract"]["personal_state_purge_fields"].remove(item))
                self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_remove_undo_remove_token_reuse(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["state_contract"]["tombstone_lifecycle"]["operation_token_generation"].update(
                {"remove_after_undo": "reuse_previous_remove_token"}
            )
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_tombstone_or_live_token_after_immediate_empty_remove(self) -> None:
        for transition in ["successful_ordinary_unbound_empty_remove_R_g", "successful_bound_missing_empty_remove_R_g"]:
            with self.subTest(transition=transition):
                errors = self._mutate_contract(
                    lambda value, key=transition: value["state_contract"]["tombstone_lifecycle"]["operation_token_generation"].update(
                        {key: "consume_R_then_create_tombstone_and_keep_callbacks_live"}
                    )
                )
                self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_implicit_reallocation_after_bound_missing_empty_remove(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["state_contract"]["tombstone_lifecycle"]["operation_token_generation"].update(
                {"successful_bound_missing_empty_remove_R_g": "consume_R_then_apply_recovery_and_allocate_immediately"}
            )
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_live_row_token_or_callback_after_synthetic_missing_retraction(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["missing_provider_resolution_contract"].update(
                {"explicit_retraction_bound_synthetic_empty_row": "remove_row_then_clear_request_only"}
            )
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_bound_missing_empty_dispatch_through_ordinary_branch(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["graph"]["fact_contributed_amount"]["controls"]["remove_provider"].update(
                {"operation_dispatch": "ordinary_empty_first"}
            )
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_callback_revival_after_terminal_purge(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["state_contract"]["stale_callback_after_finalize_immediate_remove_or_any_terminal_purge"].update(
                {"generation_and_session_identity": "may_be_reused"}
            )
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_technical_limit_becoming_fiscal(self) -> None:
        errors = self._mutate_contract(lambda value: value["row_count_contract"].update({"never_present_as_provider_or_3a_legal_limit": False}))
        self.assertIn("Batch13 exact navigation contract drift", errors)

    def test_rejects_missing_limit_locale_intent(self) -> None:
        errors = self._mutate_contract(
            lambda value: value["six_locale_intent_contract"]["mandatory_intents"].remove(
                "technical_non_fiscal_50_rendered_row_limit_and_finalize_add_education_only_or_safe_exit_recovery_choices"
            )
        )
        self.assertIn("Batch13 exact navigation contract drift", errors)


if __name__ == "__main__":
    unittest.main()
