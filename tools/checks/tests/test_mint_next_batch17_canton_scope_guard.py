from __future__ import annotations

import shutil
import tempfile
import unittest
import hashlib
import re
import subprocess
from pathlib import Path

import yaml

from tools.checks.mint_next_batch17_canton_scope_guard import GuardFailure, validate
from tools.checks.mint_next_batch17_canton_scope_guard import _review_payload_sha256


ROOT = Path(__file__).resolve().parents[3]
ARTIFACTS = (
    Path("product/mint_next/batch17/canton-scope.yaml"),
    Path("product/mint_next/batch17/official-sources.yaml"),
    Path("product/mint_next/batch17/legacy-inventory.yaml"),
    Path("product/mint_next/batch17/canton-acceptance.yaml"),
    Path("product/mint_next/batch17/six-locale-copy.yaml"),
    Path("product/mint_next/batch17/source-receipt.txt"),
    Path("product/mint_next/batch6/navigation.yaml"),
    Path("lefthook.yml"),
    Path(".github/workflows/mint-next-batch17-canton-contract.yml"),
    Path("tools/checks/mint_next_batch17_canton_scope_guard.py"),
    Path("tools/checks/tests/test_mint_next_batch17_canton_scope_guard.py"),
)


class Batch17CantonScopeGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for relative in ARTIFACTS:
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, destination)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _yaml(self, relative: Path) -> tuple[Path, dict]:
        path = self.root / relative
        return path, yaml.safe_load(path.read_text(encoding="utf-8"))

    def _mutate_scope(self, mutation) -> None:
        path, data = self._yaml(ARTIFACTS[0])
        mutation(data)
        path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def _accepted_git_fixture(self) -> str:
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "config", "user.email", "batch17@example.invalid"], cwd=self.root, check=True)
        subprocess.run(["git", "config", "user.name", "Batch17 Test"], cwd=self.root, check=True)
        subprocess.run(["git", "add", "."], cwd=self.root, check=True)
        subprocess.run(["git", "commit", "-qm", "candidate"], cwd=self.root, check=True)
        candidate = subprocess.run(["git", "rev-parse", "HEAD"], cwd=self.root, check=True, text=True, capture_output=True).stdout.strip()
        payload = _review_payload_sha256(self.root)
        scope_path, scope = self._yaml(ARTIFACTS[0])
        scope["status"] = "accepted_written_contract_runtime_forbidden"
        scope_path.write_text(yaml.safe_dump(scope, sort_keys=False), encoding="utf-8")
        acceptance_path, acceptance = self._yaml(ARTIFACTS[3])
        acceptance["status"] = "accepted_written_contract_runtime_unimplemented"
        acceptance["current_verdict"] = "CONTRACT_ACCEPTED_RUNTIME_UNIMPLEMENTED"
        acceptance["current_evidence"]["scope_guard_complete"] = True
        acceptance["current_evidence"]["six_locale_semantic_review_complete"] = True
        acceptance["mechanical_binding"]["artifact_sha256"]["scope"] = hashlib.sha256(scope_path.read_bytes()).hexdigest()
        acceptance["mechanical_binding"]["reviewed_payload_sha256"] = payload
        acceptance["mechanical_binding"]["reviewed_candidate_commit"] = candidate
        copy = yaml.safe_load((self.root / "product/mint_next/batch17/six-locale-copy.yaml").read_text())
        assertions = copy["semantic_receipt"]["semantic_assertions_per_locale"]
        acceptance["locale_reviews"] = {locale: {"reviewer": "batch17_round5_ux_locale_roast", "status": "ACCEPT", "reviewed_at": "2026-08-03", "assertions_validated": assertions, "reviewed_payload_sha256": payload} for locale in ("fr", "en", "de", "it", "es", "pt")}
        for review in acceptance["reviews"].values():
            review.update({"verdict": "ACCEPT", "p1": 0, "p2": 0, "p3": 0, "reviewed_payload_sha256": payload})
        acceptance_path.write_text(yaml.safe_dump(acceptance, sort_keys=False), encoding="utf-8")
        workflow_path = self.root / ".github/workflows/mint-next-batch17-canton-contract.yml"
        workflow = workflow_path.read_text()
        hashes = {"GUARD": hashlib.sha256((self.root / ARTIFACTS[-2]).read_bytes()).hexdigest(), "TESTS": hashlib.sha256((self.root / ARTIFACTS[-1]).read_bytes()).hexdigest(), "ACCEPTANCE": hashlib.sha256(acceptance_path.read_bytes()).hexdigest()}
        for name, digest in hashes.items():
            workflow = re.sub(rf"(?m)^(  EXPECTED_BATCH17_{name}_SHA256:) [0-9a-f]{{64}}$", rf"\1 {digest}", workflow)
        workflow_path.write_text(workflow)
        return candidate

    def test_current_contract_passes_for_its_declared_lifecycle(self) -> None:
        validate(self.root, check_digests=True, require_accepted=None)

    def test_release_gate_rejects_unaccepted_candidate(self) -> None:
        scope_path, scope = self._yaml(ARTIFACTS[0])
        scope["status"] = "candidate_written_contract_runtime_forbidden"
        scope_path.write_text(yaml.safe_dump(scope, sort_keys=False), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=True, require_accepted=True)

    def test_accepted_git_anchor_reproduces_candidate_payload(self) -> None:
        self._accepted_git_fixture()
        validate(self.root, check_digests=True, require_accepted=True, check_git=True)

    def test_malformed_git_anchor_is_rejected(self) -> None:
        self._accepted_git_fixture()
        path, acceptance = self._yaml(ARTIFACTS[3])
        acceptance["mechanical_binding"]["reviewed_candidate_commit"] = "abc123"
        path.write_text(yaml.safe_dump(acceptance, sort_keys=False), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=True, check_git=True)

    def test_nonancestor_git_anchor_is_rejected(self) -> None:
        self._accepted_git_fixture()
        tree = subprocess.run(["git", "mktree"], cwd=self.root, input="", text=True, check=True, capture_output=True).stdout.strip()
        orphan = subprocess.run(["git", "commit-tree", tree, "-m", "orphan"], cwd=self.root, check=True, text=True, capture_output=True).stdout.strip()
        path, acceptance = self._yaml(ARTIFACTS[3])
        acceptance["mechanical_binding"]["reviewed_candidate_commit"] = orphan
        path.write_text(yaml.safe_dump(acceptance, sort_keys=False), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=True, check_git=True)

    def test_runtime_promotion_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["authority"].__setitem__("runtime_change", "implemented"))

    def test_commune_collection_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["slice"].__setitem__("implemented_nodes", ["fact_canton", "fact_commune"]))

    def test_no_contribution_entry_is_rejected_when_removed(self) -> None:
        self._mutate_scope(lambda d: d["slice"]["entry_preconditions"]["discriminated_origins"].pop("fact_contribution"))

    def test_crossed_origin_states_are_rejected(self) -> None:
        self._mutate_scope(lambda d: d["slice"]["entry_preconditions"].__setitem__("crossed_origin_states", "allowed"))

    def test_default_canton_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["fact_contract"].__setitem__("initial_state", "selected_ZH"))

    def test_inference_channel_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["fact_contract"]["never_derive_from"].remove("gps_or_device_location"))

    def test_complex_case_gate_removal_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["fact_contract"].pop("complex_or_uncertain_case"))

    def test_unknown_knowledge_deficit_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["fact_contract"].__setitem__("unknown_state_semantics", "user_does_not_know"))

    def test_wrong_canton_set_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["fact_contract"]["allowed_codes"].remove("JU"))

    def test_free_text_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["input_contract"].__setitem__("free_text", True))

    def test_personal_storage_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["fact_contract"].__setitem__("storage", "persistent"))

    def test_search_control_removal_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["node_contracts"]["fact_canton"]["controls"].pop("clear_search"))

    def test_search_privacy_widening_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["input_contract"]["search_behavior"].__setitem__("maximum_code_points", 10000))

    def test_auto_route_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["navigation_contract"].__setitem__("explicit_continue_required", False))

    def test_safe_exit_action_is_rejected_when_removed(self) -> None:
        self._mutate_scope(lambda d: d["navigation_contract"]["safe_exit"].pop("keep_local_reference"))

    def test_unknown_personal_result_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["node_contracts"]["canton_unknown_help"]["controls"]["continue_education_only"].__setitem__("to", "personal_result"))

    def test_back_origin_is_rejected_when_collapsed(self) -> None:
        self._mutate_scope(lambda d: d["navigation_contract"]["back"].__setitem__("fact_canton", "fact_contributed_amount"))

    def test_commune_not_cleared_on_change_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["mutation_contract"]["select_or_change_canton"]["atomic_order"].remove("clear_commune"))

    def test_stale_callback_protection_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["lifecycle_contract"].__setitem__("stale_callback", "may_commit"))

    def test_six_locale_semantics_are_rejected_when_narrowed(self) -> None:
        self._mutate_scope(lambda d: d["six_locale_semantic_contract"]["locales"].remove("pt"))

    def test_locale_payload_omission_is_rejected(self) -> None:
        path, data = self._yaml(Path("product/mint_next/batch17/six-locale-copy.yaml"))
        del data["copy"]["it"]["privacy"]
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_localized_canton_label_omission_is_rejected(self) -> None:
        path, data = self._yaml(Path("product/mint_next/batch17/six-locale-copy.yaml"))
        del data["canton_labels"]["de"]["JU"]
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_compact_accessibility_regression_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["accessibility_contract"].__setitem__("minimum_target_size_points", 44))

    def test_privacy_logging_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["privacy_contract"].__setitem__("analytics", "allowed"))

    def test_controller_notice_gate_removal_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["privacy_contract"].pop("controller_privacy_notice_ref"))

    def test_generic_reference_personal_data_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["navigation_contract"]["safe_exit"]["keep_local_reference"]["generic_reference_allowlist"].append("canton"))

    def test_purge_event_narrowing_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["lifecycle_contract"]["exact_purge_events"].remove("ttl_expiry"))

    def test_localized_order_swap_is_rejected(self) -> None:
        path, data = self._yaml(Path("product/mint_next/batch17/six-locale-copy.yaml"))
        data["ordered_codes"]["fr"][0], data["ordered_codes"]["fr"][1] = data["ordered_codes"]["fr"][1], data["ordered_codes"]["fr"][0]
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_calculation_is_rejected(self) -> None:
        self._mutate_scope(lambda d: d["scope_exclusions"].remove("tax_calculation_or_personal_result"))

    def test_source_becoming_advice_authority_is_rejected(self) -> None:
        path, data = self._yaml(ARTIFACTS[1])
        data["implementation_limits"]["authorize_personal_tax_result"] = True
        path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_official_source_url_drift_is_rejected(self) -> None:
        path, data = self._yaml(ARTIFACTS[1])
        data["sources"][0]["url"] = "https://example.com/not-estv"
        data["sources"][0]["retrieved_url"] = data["sources"][0]["url"]
        data["sources"][0]["final_url"] = data["sources"][0]["url"]
        path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_source_receipt_digest_drift_is_rejected(self) -> None:
        path = self.root / "product/mint_next/batch17/source-receipt.txt"
        path.write_text(path.read_text() + "drift\n")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_legacy_fallback_is_rejected(self) -> None:
        path, data = self._yaml(ARTIFACTS[2])
        data["summary"]["silent_default_or_rate_fallback_reusable"] = True
        path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_nonzero_roast_is_rejected(self) -> None:
        path, data = self._yaml(ARTIFACTS[3])
        data["reviews"]["ux_navigation_accessibility"]["p3"] = 1
        path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_runtime_evidence_overclaim_is_rejected(self) -> None:
        path, data = self._yaml(ARTIFACTS[3])
        data["current_evidence"]["runtime_implemented"] = True
        path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_removed_lefthook_binding_is_rejected(self) -> None:
        path = self.root / "lefthook.yml"
        path.write_text(path.read_text().replace("mint-next-batch17-canton-scope-guard:", "removed-batch17-guard:"))
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_removed_ci_command_is_rejected(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch17-canton-contract.yml"
        path.write_text(path.read_text().replace("python3 tools/checks/mint_next_batch17_canton_scope_guard.py", "echo removed"))
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_ci_hash_in_unused_comment_is_rejected(self) -> None:
        path = self.root / ".github/workflows/mint-next-batch17-canton-contract.yml"
        text = path.read_text()
        text = text.replace("test \"$(sha256sum tools/checks/mint_next_batch17_canton_scope_guard.py", "# unused hash; test \"$(sha256sum tools/checks/mint_next_batch17_canton_scope_guard.py")
        path.write_text(text)
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_duplicate_yaml_key_is_rejected(self) -> None:
        path = self.root / ARTIFACTS[0]
        path.write_text(path.read_text() + "\nstatus: accepted\n")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_scope_byte_drift_is_rejected_by_digest(self) -> None:
        path = self.root / ARTIFACTS[0]
        path.write_text(path.read_text() + "\n# byte drift\n")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=True, require_accepted=False)

    def test_copy_byte_drift_is_rejected_by_digest(self) -> None:
        path = self.root / "product/mint_next/batch17/six-locale-copy.yaml"
        path.write_text(path.read_text() + "\n# byte drift\n")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=True, require_accepted=False)

    def test_sources_byte_drift_is_rejected_by_digest(self) -> None:
        path = self.root / ARTIFACTS[1]
        path.write_text(path.read_text() + "\n# byte drift\n")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=True, require_accepted=False)

    def test_legacy_byte_drift_is_rejected_by_digest(self) -> None:
        path = self.root / ARTIFACTS[2]
        path.write_text(path.read_text() + "\n# byte drift\n")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=True, require_accepted=False)

    def test_honest_copy_rebind_invalidates_prior_review_receipts(self) -> None:
        # Promote the copied candidate honestly, then mutate and rebind every
        # self-declared digest except the immutable prior review receipts.
        scope_path, scope = self._yaml(ARTIFACTS[0])
        scope["status"] = "accepted_written_contract_runtime_forbidden"
        scope_path.write_text(yaml.safe_dump(scope, sort_keys=False), encoding="utf-8")
        acceptance_path, acceptance = self._yaml(ARTIFACTS[3])
        prior_payload = acceptance["mechanical_binding"]["candidate_review_payload_sha256"]
        acceptance["status"] = "accepted_written_contract_runtime_unimplemented"
        acceptance["current_verdict"] = "CONTRACT_ACCEPTED_RUNTIME_UNIMPLEMENTED"
        acceptance["current_evidence"]["scope_guard_complete"] = True
        acceptance["current_evidence"]["six_locale_semantic_review_complete"] = True
        assertions = yaml.safe_load((self.root / "product/mint_next/batch17/six-locale-copy.yaml").read_text())["semantic_receipt"]["semantic_assertions_per_locale"]
        acceptance["locale_reviews"] = {locale: {"reviewer": "batch17_round5_ux_locale_roast", "status": "ACCEPT", "reviewed_at": "2026-08-03", "assertions_validated": assertions, "reviewed_payload_sha256": prior_payload} for locale in ("fr", "en", "de", "it", "es", "pt")}
        for review in acceptance["reviews"].values():
            review.update({"verdict": "ACCEPT", "p1": 0, "p2": 0, "p3": 0, "reviewed_payload_sha256": prior_payload})
        acceptance["mechanical_binding"]["reviewed_payload_sha256"] = prior_payload
        # Now make a semantic copy drift and honestly rebind candidate/artifact
        # declarations. Old review receipts must remain invalid.
        copy_path, copy = self._yaml(Path("product/mint_next/batch17/six-locale-copy.yaml"))
        copy["copy"]["en"]["body"] = copy["copy"]["en"]["body"].replace("No personal tax result has been calculated at this step.", "A personal tax result is ready.")
        copy_path.write_text(yaml.safe_dump(copy, sort_keys=False, allow_unicode=True), encoding="utf-8")
        acceptance["mechanical_binding"]["artifact_sha256"]["copy"] = hashlib.sha256(copy_path.read_bytes()).hexdigest()
        acceptance_path.write_text(yaml.safe_dump(acceptance, sort_keys=False), encoding="utf-8")
        new_payload = _review_payload_sha256(self.root)
        acceptance["mechanical_binding"]["candidate_review_payload_sha256"] = new_payload
        acceptance_path.write_text(yaml.safe_dump(acceptance, sort_keys=False), encoding="utf-8")
        workflow_path = self.root / ".github/workflows/mint-next-batch17-canton-contract.yml"
        workflow = workflow_path.read_text()
        hashes = {
            "GUARD": hashlib.sha256((self.root / "tools/checks/mint_next_batch17_canton_scope_guard.py").read_bytes()).hexdigest(),
            "TESTS": hashlib.sha256((self.root / "tools/checks/tests/test_mint_next_batch17_canton_scope_guard.py").read_bytes()).hexdigest(),
            "ACCEPTANCE": hashlib.sha256(acceptance_path.read_bytes()).hexdigest(),
        }
        for name, digest in hashes.items():
            workflow = re.sub(rf"(?m)^(  EXPECTED_BATCH17_{name}_SHA256:) [0-9a-f]{{64}}$", rf"\1 {digest}", workflow)
        workflow_path.write_text(workflow)
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=True, require_accepted=True)

    def test_rehashed_parent_safe_exit_removal_is_rejected_semantically(self) -> None:
        parent_path, parent = self._yaml(Path("product/mint_next/batch6/navigation.yaml"))
        del parent["nodes"]["fact_canton"]["actions"]["open_safe_exit"]
        parent_path.write_text(yaml.safe_dump(parent, sort_keys=False), encoding="utf-8")
        digest = __import__("hashlib").sha256(parent_path.read_bytes()).hexdigest()
        scope_path, scope = self._yaml(ARTIFACTS[0])
        scope["authority"]["parent_navigation_sha256"] = digest
        scope_path.write_text(yaml.safe_dump(scope, sort_keys=False), encoding="utf-8")
        acceptance_path, acceptance = self._yaml(ARTIFACTS[3])
        acceptance["mechanical_binding"]["artifact_sha256"]["parent_navigation"] = digest
        acceptance_path.write_text(yaml.safe_dump(acceptance, sort_keys=False), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)

    def test_rehashed_parent_continue_guard_removal_is_rejected_semantically(self) -> None:
        parent_path, parent = self._yaml(Path("product/mint_next/batch6/navigation.yaml"))
        del parent["nodes"]["fact_canton"]["actions"]["continue"]["guard"]
        parent_path.write_text(yaml.safe_dump(parent, sort_keys=False), encoding="utf-8")
        digest = __import__("hashlib").sha256(parent_path.read_bytes()).hexdigest()
        scope_path, scope = self._yaml(ARTIFACTS[0])
        scope["authority"]["parent_navigation_sha256"] = digest
        scope_path.write_text(yaml.safe_dump(scope, sort_keys=False), encoding="utf-8")
        acceptance_path, acceptance = self._yaml(ARTIFACTS[3])
        acceptance["mechanical_binding"]["artifact_sha256"]["parent_navigation"] = digest
        acceptance_path.write_text(yaml.safe_dump(acceptance, sort_keys=False), encoding="utf-8")
        with self.assertRaises(GuardFailure):
            validate(self.root, check_digests=False, require_accepted=False)


if __name__ == "__main__":
    unittest.main()
