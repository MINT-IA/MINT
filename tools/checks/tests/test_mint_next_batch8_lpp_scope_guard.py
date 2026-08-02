from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_batch8_lpp_scope_guard import ACCEPTANCE, SCOPE, SOURCES, validate


class Batch8LppScopeGuardTest(unittest.TestCase):
    def mutate(self, source: Path, callback) -> Path:
        data = yaml.safe_load(source.read_text(encoding="utf-8"))
        callback(data)
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / source.name
        path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
        return path

    def test_current_contract_passes(self) -> None:
        self.assertEqual(validate(), [])

    def test_rejects_binary_or_defaulted_fact(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["fact_contract"].update(allowed_values=["yes", "no"], default="no"))
        self.assertIn("Batch8 affiliation fact must remain tri-state without a default", validate(scope_path=path))

    def test_rejects_unknown_as_no(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["lpp_unknown_help"]["forbidden"].remove("convert_unknown_to_no"))
        self.assertIn("Batch8 unknown path is not fail-closed", validate(scope_path=path))

    def test_rejects_personal_calculation_on_no_branch(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["without_lpp_boundary"]["forbidden"].remove("calculate_personal_result"))
        self.assertIn("Batch8 no-LPP boundary is not honest and calculation-free", validate(scope_path=path))

    def test_rejects_persistence_claim(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["lpp_unknown_help"]["controls"]["keep_checklist_local"].update(enabled=True))
        self.assertIn("Batch8 lpp_unknown_help falsely claims local persistence", validate(scope_path=path))

    def test_rejects_nonofficial_or_changed_source(self) -> None:
        path = self.mutate(SOURCES, lambda data: data["sources"][0].update(url="https://example.com"))
        self.assertIn("Batch8 official source receipt drift", validate(sources_path=path))

    def test_rejects_employer_only_question(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["fact_lpp_affiliation"]["reference_copy_fr"].update(title="Cotises-tu avec ton travail ?", body="Cela passe par ton employeur."))
        self.assertIn("Batch8 exact French question confuses contribution with affiliation", validate(scope_path=path))

    def test_rejects_ambiguous_choice_semantics(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["accessibility_contract"].update(choice_pattern="radio_or_button"))
        self.assertIn("Batch8 choice accessibility pattern is ambiguous", validate(scope_path=path))

    def test_rejects_dead_written_button(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["fact_lpp_affiliation"]["controls"]["choose_yes"].update(immediate_to="dead_node", mutation="lpp_affiliation_no"))
        self.assertIn("Batch8 written affiliation controls drift", validate(scope_path=path))

    def test_rejects_weakened_slice_recovery_and_exit_gate(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["slice"].update(entry_from="dead.action"))
        self.assertIn("Batch8 node slice drift", validate(scope_path=path))
        path = self.mutate(SCOPE, lambda data: data["interaction_contract"].update(safe_exit="keep_everything"))
        self.assertIn("Batch8 interaction and recovery contract drift", validate(scope_path=path))
        path = self.mutate(SCOPE, lambda data: data["exit_gate"].update(required=[]))
        self.assertIn("Batch8 exit gate drift", validate(scope_path=path))

    def test_rejects_weakened_or_extra_source(self) -> None:
        def weaken(data):
            data["sources"][0]["supports"] = []
            data["sources"].append(dict(data["sources"][1]))
        path = self.mutate(SOURCES, weaken)
        self.assertIn("Batch8 official source receipt drift", validate(sources_path=path))

    def test_rejects_fake_checklist_controls_or_resume_promise(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["lpp_unknown_help"].update(evidence_list_semantics="buttons"))
        self.assertIn("Batch8 unknown help promises unsupported resume or fake controls", validate(scope_path=path))

    def test_rejects_harmful_copy_even_if_keywords_still_pass(self) -> None:
        path = self.mutate(SCOPE, lambda data: data["node_contracts"]["without_lpp_boundary"]["reference_copy_fr"].update(body="Tu es inéligible au pilier 3a et ne peux jamais cotiser."))
        self.assertIn("Batch8 exact written scope digest drift", validate(scope_path=path))

    def test_rejects_acceptance_receipt_mutation(self) -> None:
        path = self.mutate(ACCEPTANCE, lambda data: data["not_accepted"].remove("runtime_navigation"))
        self.assertIn("Batch8 exact acceptance receipt digest drift", validate(acceptance_path=path))


if __name__ == "__main__":
    unittest.main()
