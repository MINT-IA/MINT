from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_batch6_navigation_guard import CONTRACT, validate


class Batch6NavigationGuardTest(unittest.TestCase):
    def mutate(self, callback) -> list[str]:
        data = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
        callback(data)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "navigation.yaml"
            path.write_text(yaml.safe_dump(data), encoding="utf-8")
            return validate(path)

    def test_contract_passes(self) -> None:
        self.assertEqual(validate(), [])

    def test_rejects_claim_that_product_flutter_is_ready(self) -> None:
        errors = self.mutate(lambda d: d.update(flutter_allowed=True))
        self.assertIn("accepted contract must allow only the executable design-lab gate", errors)

    def test_rejects_dead_destination(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["orientation"]["actions"]["continue"].update(to="ghost"))
        self.assertTrue(any("unknown target ghost" in error for error in errors))

    def test_rejects_missing_safe_exit(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["fact_canton"]["actions"].pop("open_safe_exit"))
        self.assertIn("fact_canton: missing safe exit", errors)

    def test_rejects_unreachable_screen(self) -> None:
        def add_orphan(data):
            data["nodes"]["orphan"] = {
                "terminal": True,
                "requires_account": False,
                "actions": {"restart": {"to": "today_3a_intent"}},
            }
        errors = self.mutate(add_orphan)
        self.assertTrue(any("unreachable nodes: orphan" in error for error in errors))

    def test_rejects_fact_change_without_result_invalidation(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["fact_contribution"]["actions"]["choose_no"].pop("invalidates"))
        self.assertIn("fact_contribution.choose_no: fact mutation must invalidate result", errors)

    def test_rejects_exit_that_leaves_session_result(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["next_action"]["actions"]["leave_without_saving"].update(persistence="clear_ephemeral"))
        self.assertIn("next_action.leave_without_saving: exit must clear ephemeral and session result", errors)

    def test_rejects_flutter_before_renderer_binding(self) -> None:
        errors = self.mutate(lambda d: d.update(flutter_allowed=True))
        self.assertIn("Flutter cannot be allowed before renderer binding exists", errors)

    def test_rejects_local_reference_fact_leak(self) -> None:
        errors = self.mutate(lambda d: d["persistence_contract"]["local_reference_allowlist"].append("canton"))
        self.assertIn("local reference allowlist is not exact", errors)

    def test_rejects_missing_calculation_failure_state(self) -> None:
        errors = self.mutate(lambda d: d["calculation_contract"]["outcomes"].remove("calculation_failed"))
        self.assertIn("calculation outcomes are incomplete", errors)

    def test_rejects_dependent_amount_not_cleared(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["fact_contribution"]["actions"]["choose_no"].pop("clears"))
        self.assertIn("fact_contribution.choose_no: dependent contributed amount and provider rows must be cleared", errors)

    def test_rejects_overlay_exit_that_leaves_session_result(self) -> None:
        errors = self.mutate(lambda d: d["overlays"]["safe_exit"]["actions"]["leave_without_saving"].update(persistence="clear_ephemeral"))
        self.assertIn("overlay safe_exit.leave_without_saving: exit must clear ephemeral and session result", errors)

    def test_rejects_unknown_renderer_binding_status(self) -> None:
        errors = self.mutate(lambda d: d["renderer_binding"].update(status="claimed_done"))
        self.assertIn("renderer binding status is invalid", errors)

    def test_rejects_swapped_calculation_targets(self) -> None:
        def swap(data):
            outcomes = data["nodes"]["confirm_facts"]["actions"]["calculate"]["outcomes"]
            outcomes["success"], outcomes["unsupported_case"] = outcomes["unsupported_case"], outcomes["success"]
        errors = self.mutate(swap)
        self.assertIn("calculate action outcomes diverge from calculation contract", errors)

    def test_rejects_missing_deductible_cap_formula(self) -> None:
        errors = self.mutate(lambda d: d["calculation_contract"]["formulas"].pop("deductible_amount"))
        self.assertIn("deductible amount and excess formulas are incomplete", errors)

    def test_rejects_unconditional_contributed_amount_edit(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["confirm_facts"]["actions"]["edit_contributed_amount"].pop("visible_when"))
        self.assertIn("contributed amount edit must be conditional on contribution status yes", errors)

    def test_rejects_reference_entry_without_sensitive_purge(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["reference_saved"].pop("on_enter"))
        self.assertIn("reference-saved entry must purge sensitive session state", errors)

    def test_rejects_unversioned_annual_cap(self) -> None:
        errors = self.mutate(lambda d: d["calculation_contract"]["official_constants"].pop("annual_cap"))
        self.assertIn("annual cap is not bound to the verified Swiss constants registry", errors)

    def test_rejects_missing_post_ttl_policy(self) -> None:
        errors = self.mutate(lambda d: d["lifecycle"].pop("background_resume_after_ttl"))
        self.assertIn("post-TTL recovery is not fail-closed", errors)

    def test_rejects_canton_change_that_keeps_old_commune(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["edit_canton"]["actions"]["choose_canton"].pop("clears"))
        self.assertIn("edit_canton.choose_canton: canton mutation must clear dependent commune", errors)

    def test_rejects_ambiguous_resume_precedence(self) -> None:
        errors = self.mutate(lambda d: d["lifecycle"].pop("resume_precedence"))
        self.assertIn("resume precedence is ambiguous", errors)

    def test_rejects_hidden_excess_warning(self) -> None:
        errors = self.mutate(lambda d: d["result_display_contract"]["planned_excess_when_positive"].pop("show_adjacent"))
        self.assertIn("excess contribution warning is incomplete", errors)

    def test_rejects_missing_contribution_normalization(self) -> None:
        errors = self.mutate(lambda d: d["calculation_contract"].pop("normalization"))
        self.assertIn("contributed amount normalization is incomplete", errors)

    def test_rejects_hidden_existing_overcontribution(self) -> None:
        errors = self.mutate(lambda d: d["result_display_contract"].pop("existing_excess_when_positive"))
        self.assertIn("existing over-contribution warning is incomplete", errors)

    def test_rejects_implicit_tax_year(self) -> None:
        errors = self.mutate(lambda d: d["tax_year_contract"].pop("confirmation_visibility"))
        self.assertIn("tax year initialization, visibility, or correction contract is incomplete", errors)

    def test_rejects_canton_edit_that_skips_commune_reconfirmation(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["edit_canton"]["actions"]["confirm_edit"].update(to="confirm_facts"))
        self.assertIn("canton edit must require commune reconfirmation", errors)

    def test_rejects_reference_restart_that_keeps_old_reference(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["reference_saved"]["actions"]["restart"].update(persistence="clear_ephemeral_and_session_result"))
        self.assertIn("reference restart must clear the old local reference", errors)

    def test_rejects_back_that_bypasses_commune_reconfirmation(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["edit_commune_after_canton"]["actions"]["back"].update(to="confirm_facts"))
        self.assertIn("canton-dependent commune edit cannot bypass reconfirmation on Back", errors)

    def test_rejects_restart_that_skips_tax_year(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["education_next_action"]["actions"]["restart_fact_collection"].update(to="fact_lpp_affiliation"))
        self.assertIn("fact-collection restart skips tax year", errors)

    def test_rejects_year_change_that_reuses_annual_facts(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["edit_tax_year"]["actions"]["choose_past_year"].pop("clears"))
        self.assertIn("edit_tax_year.choose_past_year: year change must clear annual facts", errors)

    def test_rejects_past_year_in_ordinary_estimate(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["fact_tax_year"]["actions"]["choose_past_year"].update(to="fact_lpp_affiliation"))
        self.assertIn("past tax year can enter the ordinary estimate", errors)

    def test_rejects_correction_that_skips_recheck(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["teach_back_correction"]["actions"]["retry_simplified"].update(to="next_action"))
        self.assertIn("teach_back_correction: correction must recheck comprehension", errors)

    def test_rejects_household_change_that_keeps_old_income(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["edit_household"]["actions"]["choose_category"].pop("clears"))
        self.assertIn("edit_household.choose_category: household change must clear assessment income", errors)

    def test_rejects_household_edit_that_skips_income_reconfirmation(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["edit_household"]["actions"]["confirm_edit"].update(to="confirm_facts"))
        self.assertIn("household edit must require income reconfirmation", errors)

    def test_rejects_non_aggregated_contributed_amount(self) -> None:
        errors = self.mutate(lambda d: d["contributed_amount_contract"].pop("meaning"))
        self.assertIn("contributed amount is not an explicit all-provider annual total", errors)

    def test_rejects_undefined_teach_back_answer_meaning(self) -> None:
        errors = self.mutate(lambda d: d["teach_back_contract"].pop("proposition"))
        self.assertIn("teach-back meaning and answer mapping are incomplete", errors)

    def test_rejects_missing_multi_provider_total_helper(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["fact_contributed_amount"]["actions"].pop("open_total_helper"))
        self.assertIn("multi-provider total helper is not reachable from amount collection", errors)

    def test_rejects_unknown_help_back_bypass(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["amount_unknown_help"]["actions"]["back"].pop("mutation"))
        self.assertIn("amount_unknown_help.back can retain a bypassable unknown value", errors)

    def test_rejects_calculation_without_year_rollover_precondition(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["confirm_facts"]["actions"]["calculate"].pop("precondition"))
        self.assertIn("calculate action bypasses tax-year execution precondition", errors)

    def test_rejects_income_without_basis_and_source_year(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["edit_income"]["actions"]["choose_band"].update(value="selected"))
        self.assertIn("edit_income.choose_band: income basis and source year are missing", errors)

    def test_rejects_provider_rows_surviving_status_change(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["fact_contribution"]["actions"]["choose_no"].update(clears=["contributed_amount"]))
        self.assertIn("fact_contribution.choose_no: dependent contributed amount and provider rows must be cleared", errors)

    def test_rejects_empty_provider_total(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["contributed_amount_total_helper"]["actions"]["use_automatic_total"].pop("guard"))
        self.assertIn("multi-provider helper can accept an empty or incomplete total", errors)

    def test_rejects_result_without_rollover_guard(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["result"].pop("temporal_guard"))
        self.assertIn("result: missing tax-year rollover guard", errors)

    def test_rejects_zero_direct_contributed_amount(self) -> None:
        errors = self.mutate(lambda d: d["guards"].update(contributed_amount_answered="contributed_amount_is_set"))
        self.assertIn("direct contributed amount can accept zero when status is yes", errors)

    def test_rejects_result_derived_overlay_without_rollover_guard(self) -> None:
        errors = self.mutate(lambda d: d["overlays"]["sources"].pop("temporal_guard"))
        self.assertIn("overlay sources: missing tax-year rollover guard", errors)

    def test_rejects_missing_total_helper_in_correction_context(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["edit_contributed_amount"]["actions"].pop("open_total_helper"))
        self.assertIn("multi-provider total helper is not reachable during correction", errors)

    def test_rejects_correction_helper_wrong_return_context(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["edit_contributed_amount_total_helper"]["actions"]["use_automatic_total"].update(to="fact_contributed_amount"))
        self.assertIn("correction total helper does not return to its edit context", errors)

    def test_rejects_non_transactional_edit_contract(self) -> None:
        errors = self.mutate(lambda d: d["edit_transaction_contract"].pop("rollback_semantics"))
        self.assertIn("edit transaction, rollback, and atomic commit contract is incomplete", errors)

    def test_rejects_result_invalidated_before_fact_change(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["result"]["actions"]["edit_facts"].update(invalidates="result"))
        self.assertIn("opening fact review invalidates the result before a fact changes", errors)

    def test_rejects_fact_review_without_valid_result_return(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["confirm_facts"]["actions"]["back"]["outcomes"].pop("valid_result_review"))
        self.assertIn("fact-review Back cannot return to an unchanged valid result", errors)

    def test_rejects_direct_correction_without_result_review_context(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["result"]["actions"]["correct_additional_planned_amount"].pop("operation"))
        self.assertIn("result.correct_additional_planned_amount: result-review context is not established", errors)

    def test_rejects_noop_commit_that_discards_result(self) -> None:
        errors = self.mutate(lambda d: d["edit_transaction_contract"].pop("no_op_commit"))
        self.assertIn("edit transaction, rollback, and atomic commit contract is incomplete", errors)

    def test_rejects_same_year_noop_that_clears_facts(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["edit_tax_year"]["actions"]["confirm_current_year"].update(to="fact_lpp_affiliation"))
        self.assertIn("same-current-year edit can clear facts or force recollection", errors)

    def test_rejects_dangling_review_context_after_help_back(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["existing_overcontribution_help"]["actions"]["back"].pop("operation"))
        self.assertIn("overcontribution help Back leaves dangling result-review context", errors)

    def test_rejects_partial_rollback_from_past_year_edit(self) -> None:
        errors = self.mutate(lambda d: d["nodes"]["retroactive_3a_boundary"]["actions"]["back"]["outcome_effects"].update(edit_review="clear_selected_past_year"))
        self.assertIn("retroactive boundary Back can retain a past year", errors)


if __name__ == "__main__":
    unittest.main()
