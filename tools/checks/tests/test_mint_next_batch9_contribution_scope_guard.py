from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import yaml

import tools.checks.mint_next_batch9_contribution_scope_guard as guard_module
from tools.checks.mint_next_batch9_contribution_scope_guard import ACCEPTANCE, CI_WORKFLOW, LEGACY, SCOPE, SOURCES, validate


class Batch9ContributionScopeGuardTest(unittest.TestCase):
    def mutate(self, source: Path, callback) -> Path:
        data = yaml.safe_load(source.read_text(encoding="utf-8"))
        callback(data)
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / source.name
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True), encoding="utf-8")
        return path

    def test_current_draft_passes(self) -> None:
        self.assertEqual(validate(), [])

    def test_rejects_binary_or_defaulted_fact(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["fact_contract"].update(allowed_values=["yes", "no"], default="no"))
        self.assertIn("Batch9 contribution fact must remain explicit tri-state without default", validate(scope_path=path))

    def test_rejects_account_ownership_or_plan_inference(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["fact_contract"]["never_derive_from"].remove("planned_contribution"))
        self.assertIn("Batch9 unsafe contribution inference became allowed", validate(scope_path=path))

    def test_rejects_transfer_buyback_pending_or_refund_as_ordinary(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["fact_contract"]["explicit_exclusions"].remove("retroactive_buyback_for_past_year"))
        self.assertIn("Batch9 special movements are no longer excluded", validate(scope_path=path))

    def test_rejects_unknown_as_zero_or_personal_calculation(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["contribution_unknown_help"]["forbidden"].remove("infer_zero"))
        self.assertIn("Batch9 unknown path is not fail-closed", validate(scope_path=path))

    def test_rejects_yes_as_known_amount(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["fact_contract"]["invariants"].update(yes="credited_total_is_maximum"))
        self.assertIn("Batch9 yes/no/unknown amount invariants drift", validate(scope_path=path))

    def test_rejects_dead_or_wrong_route(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["fact_contribution"]["controls"]["choose_no"].update(immediate_to="dead"))
        self.assertIn("Batch9 written contribution controls drift", validate(scope_path=path))

    def test_rejects_question_that_counts_bank_debit(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["fact_contribution"]["reference_copy_fr"].update(credited_note="Ton compte a été débité, donc cela compte."))
        self.assertIn("Batch9 exact beginner French question drift", validate(scope_path=path))

    def test_rejects_one_provider_only(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["fact_contribution"].update(all_provider_scope="first_bank_only"))
        self.assertIn("Batch9 question no longer covers every provider", validate(scope_path=path))

    def test_rejects_missing_edge_case_or_routed_disclosure(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["fact_contribution"]["edge_help_contract"]["cases"].pop("provider_transfer"))
        self.assertIn("Batch9 edge-case help is incomplete or became a route", validate(scope_path=path))

    def test_rejects_transfer_double_counting_help(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["contribution_unknown_help"]["reference_copy_fr"].update(transfer_warning="Additionne tous les mouvements."))
        self.assertIn("Batch9 unknown help permits transfer double-counting", validate(scope_path=path))

    def test_rejects_year_rollover_retention(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["interaction_contract"].update(tax_year_rollover="keep_old_answer"))
        self.assertIn("Batch9 interaction, exit or year-rollover contract drift", validate(scope_path=path))

    def test_rejects_accessible_group_without_year(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["accessibility_contract"].update(dynamic_year_in_choice_group_label=False))
        self.assertIn("Batch9 accessibility choice/year/disclosure contract drift", validate(scope_path=path))

    def test_rejects_noisy_year_repetition_in_each_choice(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["accessibility_contract"].update(repeat_year_in_each_choice_label=True))
        self.assertIn("Batch9 accessibility choice/year/disclosure contract drift", validate(scope_path=path))

    def test_rejects_unsafe_exit_focus_or_purge_contract(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["accessibility_contract"]["safe_exit"].update(overlay_focus_trap=False))
        self.assertIn("Batch9 accessibility choice/year/disclosure contract drift", validate(scope_path=path))
        path = self.mutate(SCOPE, lambda data: data["accessibility_contract"]["safe_exit"].update(leave_action_clears_ephemeral_facts_before_dismissed_boundary=False))
        self.assertIn("Batch9 accessibility choice/year/disclosure contract drift", validate(scope_path=path))

    def test_rejects_loss_of_partial_refund_route_contract(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["fact_contribution"]["edge_help_contract"]["cases"].pop("partial_refund_known_net"))
        self.assertIn("Batch9 edge-case help is incomplete or became a route", validate(scope_path=path))

    def test_rejects_counting_transfer_return_or_adjustment_as_contribution(self) -> None:
        for case in ("provider_transfer", "investment_return_or_interest", "non_contribution_adjustment"):
            path = self.mutate(SCOPE, lambda data, key=case: data["node_contracts"]["fact_contribution"]["edge_help_contract"]["cases"].pop(key))
            self.assertIn("Batch9 edge-case help is incomplete or became a route", validate(scope_path=path))

    def test_rejects_harmful_edge_or_unknown_copy_mutations(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["fact_contribution"]["edge_help_contract"]["cases"].update(provider_transfer="Compte toujours le transfert."))
        self.assertIn("Batch9 scope exact digest drift", validate(scope_path=path))
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["fact_contribution"]["edge_help_contract"]["cases"].update(partial_refund_known_net="Réponds non."))
        self.assertIn("Batch9 scope exact digest drift", validate(scope_path=path))
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["contribution_unknown_help"]["reference_copy_fr"].update(body="Choisis non si tu ne sais pas."))
        self.assertIn("Batch9 scope exact digest drift", validate(scope_path=path))

    def test_rejects_removed_arb_keys_or_weakened_accessibility(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["fact_contribution"].update(required_arb_keys=[]))
        self.assertIn("Batch9 question ARB delivery contract drift", validate(scope_path=path))
        mutations = [
            ("choice_semantics", "decorative"),
            ("focus_on_route", "none"),
            ("minimum_touch_target", "12x12"),
        ]
        for field, value in mutations:
            path = self.mutate(SCOPE, lambda data, key=field, replacement=value: data["accessibility_contract"].update({key: replacement}))
            self.assertIn("Batch9 critical accessibility semantics drift", validate(scope_path=path))

    def test_rejects_key_parity_as_translation_proof(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["six_locale_intent_contract"].update(key_parity_alone_is_insufficient=False))
        self.assertIn("Batch9 six-locale semantic contract drift", validate(scope_path=path))

    def test_rejects_personal_amount_or_retroactive_calculation(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["content_boundaries"].update(no_remaining_room_or_tax_saving=False))
        self.assertIn("Batch9 content boundary drift", validate(scope_path=path))

    def test_rejects_nonfederal_or_weakened_source(self) -> None:
        path = self.mutate(SOURCES, lambda data: data["sources"][0].update(url="https://example.com"))
        self.assertIn("Batch9 non-federal source entered the authority receipt", validate(sources_path=path))
        path = self.mutate(SOURCES, lambda data: data["direct_facts"].remove("a_provider_transfer_is_not_a_new_ordinary_contribution"))
        self.assertIn("Batch9 official facts or implementation limits drift", validate(sources_path=path))

    def test_rejects_unscored_or_direct_legacy_reuse(self) -> None:
        path = self.mutate(LEGACY, lambda data: data["candidates"][0].pop("score"))
        self.assertIn("Batch9 legacy candidates are not exhaustively scored", validate(legacy_path=path))
        path = self.mutate(LEGACY, lambda data: data.update(legacy_code_reused_in_batch9_runtime=True))
        self.assertIn("Batch9 legacy inventory verdict or schema drift", validate(legacy_path=path))

    def test_rejects_duplicate_yaml_key(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "scope.yaml"
        path.write_text(SCOPE.read_text(encoding="utf-8") + "\nstatus: accepted\n", encoding="utf-8")
        self.assertTrue(any("duplicate YAML key" in error for error in validate(scope_path=path)))

    def test_rejects_harmful_unknown_or_boundary_copy_even_when_shape_survives(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["contribution_unknown_help"]["reference_copy_fr"].update(education_limit="Nous estimons ton économie fiscale personnelle."))
        self.assertIn("Batch9 scope exact digest drift", validate(scope_path=path))
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["fact_canton_boundary"]["reference_copy_fr"].update(body="Tu économiseras CHF 2 000."))
        self.assertIn("Batch9 scope exact digest drift", validate(scope_path=path))

    def test_rejects_dishonest_human_outcome_or_exit_gate(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["human_outcome"].update(question="Ship whatever exists."))
        self.assertIn("Batch9 scope exact digest drift", validate(scope_path=path))
        path = self.mutate(SCOPE, lambda data: data["exit_gate"].update(accepted_only_if="agent_self_score_is_ten"))
        self.assertIn("Batch9 scope exact digest drift", validate(scope_path=path))

    def test_rejects_fake_source_authority_support_or_inference(self) -> None:
        path = self.mutate(SOURCES, lambda data: data["sources"][0].update(authority="A random blog"))
        self.assertIn("Batch9 official sources exact digest drift", validate(sources_path=path))
        path = self.mutate(SOURCES, lambda data: data["sources"][0].update(supports=[]))
        self.assertIn("Batch9 official sources exact digest drift", validate(sources_path=path))
        path = self.mutate(SOURCES, lambda data: data.update(derived_product_safety_inferences=[]))
        self.assertIn("Batch9 official sources exact digest drift", validate(sources_path=path))

    def test_rejects_legacy_overclaim_or_required_fact_erasure(self) -> None:
        path = self.mutate(LEGACY, lambda data: data["candidates"][0].update(score=10, decision="reuse_directly"))
        self.assertIn("Batch9 legacy inventory exact digest drift", validate(legacy_path=path))
        path = self.mutate(LEGACY, lambda data: data["required_new_fact"].update(dimensions=[]))
        self.assertIn("Batch9 legacy inventory exact digest drift", validate(legacy_path=path))

    def test_rejects_acceptance_or_ci_byte_drift(self) -> None:
        path = self.mutate(ACCEPTANCE, lambda data: data.update(status="product_shipped"))
        self.assertIn("Batch9 acceptance exact digest drift", validate(acceptance_path=path))
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        workflow = Path(directory.name) / CI_WORKFLOW.name
        workflow.write_bytes(CI_WORKFLOW.read_bytes() + b"\n# bypass\n")
        self.assertIn("Batch9 CI workflow exact digest drift", validate(ci_workflow_path=workflow))

    def test_rejects_unaccepted_previous_authority(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        previous = Path(directory.name) / "previous.yaml"
        previous.write_text("status: product_shipped_without_proof\n", encoding="utf-8")
        with patch.object(guard_module, "PREVIOUS_ACCEPTANCE", previous):
            self.assertIn("Batch9 authority or semantic-refinement binding drift", validate())

    def test_rejects_removed_spec_lefthook_or_journey_wiring(self) -> None:
        for attribute, decoy in (
            ("SPEC", "<!-- batch9-contribution-written-scope: python3 tools/checks/mint_next_batch9_contribution_scope_guard.py -->\n"),
            ("LEFTHOOK", "# run: python3 tools/checks/mint_next_batch9_contribution_scope_guard.py\n"),
            ("JOURNEY_GUARD", '# "product/mint_next/batch9/contribution-status-acceptance.yaml"\nALLOW = set()\n'),
        ):
            directory = tempfile.TemporaryDirectory()
            self.addCleanup(directory.cleanup)
            path = Path(directory.name) / "wiring.txt"
            path.write_text(decoy, encoding="utf-8")
            with patch.object(guard_module, attribute, path):
                self.assertTrue(any(error.startswith("Batch9 required wiring drift") for error in validate()))

    def test_rejects_missing_or_invalid_acceptance_timestamp(self) -> None:
        path = self.mutate(ACCEPTANCE, lambda data: data.update(accepted_at=None))
        self.assertIn("Batch9 acceptance timestamp is absent or invalid", validate(acceptance_path=path))
        path = self.mutate(ACCEPTANCE, lambda data: data.update(accepted_at="2026-08-02T20:00:00"))
        self.assertIn("Batch9 acceptance timestamp is absent or invalid", validate(acceptance_path=path))

    def test_rejects_rebound_verifier_hashes_even_when_ci_normalized_digest_survives(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        workflow = Path(directory.name) / CI_WORKFLOW.name
        text = CI_WORKFLOW.read_text(encoding="utf-8").replace(
            "EXPECTED_BATCH9_GUARD_SHA256: " + guard_module.ci_binding(CI_WORKFLOW, "EXPECTED_BATCH9_GUARD_SHA256"),
            "EXPECTED_BATCH9_GUARD_SHA256: " + "0" * 64,
        )
        workflow.write_text(text, encoding="utf-8")
        self.assertEqual(guard_module.normalized_ci_digest(workflow), guard_module.normalized_ci_digest(CI_WORKFLOW))
        self.assertIn("Batch9 verifier trust-unit binding drift", validate(ci_workflow_path=workflow))


if __name__ == "__main__":
    unittest.main()
