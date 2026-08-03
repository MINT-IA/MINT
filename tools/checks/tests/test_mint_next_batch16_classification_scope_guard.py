from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_batch16_classification_scope_guard import GuardFailure, validate


ROOT = Path(__file__).resolve().parents[3]
ARTIFACTS = (
    Path("product/mint_next/batch16/classification-doubt-scope.yaml"),
    Path("product/mint_next/batch16/navigation.mmd"),
    Path("product/mint_next/batch16/acceptance.yaml"),
    Path("product/mint_next/batch13/multi-provider-navigation-contract.yaml"),
    Path("lefthook.yml"),
    Path(".github/workflows/mint-next-batch16-runtime.yml"),
    Path("tools/checks/mint_next_batch16_classification_scope_guard.py"),
    Path("tools/checks/tests/test_mint_next_batch16_classification_scope_guard.py"),
)


class Batch16ClassificationScopeGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for relative in ARTIFACTS:
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, destination)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _scope(self) -> tuple[Path, dict]:
        path = self.root / ARTIFACTS[0]
        return path, yaml.safe_load(path.read_text())

    def _acceptance(self) -> tuple[Path, dict]:
        path = self.root / ARTIFACTS[2]
        return path, yaml.safe_load(path.read_text())

    def _validate_mutation(self) -> None:
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, check_git=False)

    def test_current_contract_passes_without_repository_git_context(self) -> None:
        validate(self.root, check_digests=True, check_git=False)

    def test_runtime_promotion_is_rejected(self) -> None:
        path, data = self._scope()
        data["status"] = "accepted"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._validate_mutation()

    def test_unresolved_commit_blocker_removal_is_rejected(self) -> None:
        path, data = self._scope()
        del data["row_state_machine"]["unresolved_amount"]["continue"]
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._validate_mutation()

    def test_parent_purge_narrowing_is_rejected(self) -> None:
        path, data = self._scope()
        data["privacy_and_lifecycle"]["purged_fields"]["inherit_exactly"] = "local_subset"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._validate_mutation()

    def test_refund_atomic_R_g_step_removal_is_rejected(self) -> None:
        path, data = self._scope()
        order = data["origin_contract"]["refunded_origin_transaction"]["atomic_order"]
        order.remove("consume_exact_R_g_via_batch15_contentful_remove")
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._validate_mutation()

    def test_swiss_semantic_intent_replacement_is_rejected(self) -> None:
        path, data = self._scope()
        intents = data["six_locale_semantic_contract"]["every_locale_must_distinguish"]
        intents[0] = "generic_copy_parity_only"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._validate_mutation()

    def test_hidden_harness_limit_change_is_rejected(self) -> None:
        path, data = self._scope()
        data["authority"]["runtime_surface"] = "normal_product_route"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._validate_mutation()

    def test_finalize_navigation_removal_is_rejected(self) -> None:
        path = self.root / ARTIFACTS[1]
        path.write_text(path.read_text().replace("Editor_Tombstone --> Editor_RowsMixed: Finaliser la suppression", "Editor_Tombstone --> Editor_RowsMixed: route supprimée"))
        self._validate_mutation()

    def test_destructive_aggregate_edge_is_rejected(self) -> None:
        path = self.root / ARTIFACTS[1]
        path.write_text(path.read_text() + "\n  Editor_AllConfirmed --> Editor_RowsMixed: Modifier / ajouter / supprimer / décocher\n")
        self._validate_mutation()

    def test_missing_hostile_mutation_id_is_rejected(self) -> None:
        path, data = self._acceptance()
        del data["mechanical_binding"]["scope_hostile_mutations_executed"]["runtime_promotion"]
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._validate_mutation()

    def test_nonzero_roast_is_rejected(self) -> None:
        path, data = self._acceptance()
        data["review_required"]["ux_navigation"] = "rejected_p1_1"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._validate_mutation()

    def test_removed_lefthook_binding_is_rejected(self) -> None:
        path = self.root / "lefthook.yml"
        path.write_text(path.read_text().replace("mint-next-batch16-classification-scope-guard:", "removed-batch16-scope-guard:"))
        self._validate_mutation()

    def test_removed_ci_binding_is_rejected(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch16-runtime.yml"
        path.write_text(path.read_text().replace("python3 tools/checks/mint_next_batch16_classification_scope_guard.py", "echo scope-guard-removed"))
        self._validate_mutation()

    def test_duplicate_yaml_key_is_rejected(self) -> None:
        path = self.root / ARTIFACTS[0]
        path.write_text(path.read_text() + "\nstatus: accepted\n")
        self._validate_mutation()


if __name__ == "__main__":
    unittest.main()
