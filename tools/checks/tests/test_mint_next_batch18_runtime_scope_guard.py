from __future__ import annotations

import hashlib
import re
import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks import mint_next_batch17_canton_scope_guard as batch17
from tools.checks.mint_next_batch18_runtime_scope_guard import (
    ACCEPTANCE,
    GUARD,
    GuardFailure,
    JOURNEY_GUARD,
    PARENT,
    SCOPE,
    SPEC,
    TESTS,
    WORKFLOW,
    _validate_pending_candidate_artifacts,
    validate,
)


ROOT = Path(__file__).resolve().parents[3]
PARENT_FILES = (
    batch17.SCOPE, batch17.SOURCES, batch17.LEGACY, batch17.ACCEPTANCE,
    batch17.COPY, batch17.SOURCE_RECEIPT, batch17.PARENT_NAV, batch17.GUARD,
    batch17.TESTS, batch17.WORKFLOW,
)


class Batch18RuntimeScopeGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for relative in dict.fromkeys((SCOPE, ACCEPTANCE, PARENT, WORKFLOW, SPEC, GUARD, TESTS, JOURNEY_GUARD, batch17.LEFTHOOK, *PARENT_FILES)):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        validate(self.root, check_parent_git=False, require_accepted=None)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _mutate(self, mutation, expected: str) -> None:
        path = self.root / SCOPE
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        mutation(data)
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True), encoding="utf-8")
        with self.assertRaisesRegex(GuardFailure, expected):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def _promote_fixture(self) -> None:
        scope_path = self.root / SCOPE
        scope_text = scope_path.read_text()
        if "status: accepted_scope_contract_runtime_state_not_evaluated" in scope_text:
            return
        self.assertEqual(scope_text.count("status: candidate_scope_acceptance_absent"), 1)
        scope_path.write_text(scope_text.replace(
            "status: candidate_scope_acceptance_absent",
            "status: accepted_scope_contract_runtime_state_not_evaluated",
            1,
        ))
        acceptance_path = self.root / ACCEPTANCE
        acceptance = yaml.safe_load(acceptance_path.read_text())
        payload = acceptance["mechanical_binding"]["candidate_review_payload_sha256"]
        acceptance["status"] = "accepted_scope_contract_runtime_not_evaluated"
        acceptance["current_verdict"] = "SCOPE_ACCEPTED_RUNTIME_NOT_EVALUATED"
        for review in acceptance["reviews"].values():
            review.update({"verdict": "ACCEPT", "p1": 0, "p2": 0, "p3": 0, "reviewed_payload_sha256": payload})
        acceptance["mechanical_binding"]["reviewed_payload_sha256"] = payload
        acceptance["mechanical_binding"]["reviewed_candidate_commit"] = "a" * 40
        acceptance["accepted_scope_only"] = ["written_batch18_runtime_scope_and_microstep_order"]
        acceptance["next_gate"] = "write_expected_failing_R1_tests"
        acceptance_path.write_text(yaml.safe_dump(acceptance, sort_keys=False, allow_unicode=True))
        workflow_path = self.root / WORKFLOW
        workflow = workflow_path.read_text().replace(
            "python3 tools/checks/mint_next_batch18_runtime_scope_guard.py --contract",
            "python3 tools/checks/mint_next_batch18_runtime_scope_guard.py",
        )
        hashes = {"GUARD": GUARD, "TESTS": TESTS, "ACCEPTANCE": ACCEPTANCE}
        for name, relative in hashes.items():
            digest = hashlib.sha256((self.root / relative).read_bytes()).hexdigest()
            workflow = re.sub(rf"(?m)^(  EXPECTED_BATCH18_{name}_SHA256:) [0-9a-f]{{64}}$", rf"\1 {digest}", workflow)
        workflow_path.write_text(workflow)
        spec_path = self.root / SPEC
        spec_path.write_text(spec_path.read_text().replace(
            "python3 tools/checks/mint_next_batch18_runtime_scope_guard.py --contract",
            "python3 tools/checks/mint_next_batch18_runtime_scope_guard.py",
        ))

    def _candidate_fixture(self) -> None:
        scope_path = self.root / SCOPE
        scope_text = scope_path.read_text()
        if "status: candidate_scope_acceptance_absent" in scope_text:
            return
        self.assertEqual(scope_text.count("status: accepted_scope_contract_runtime_state_not_evaluated"), 1)
        scope_path.write_text(scope_text.replace(
            "status: accepted_scope_contract_runtime_state_not_evaluated",
            "status: candidate_scope_acceptance_absent",
            1,
        ))
        acceptance_path = self.root / ACCEPTANCE
        acceptance = yaml.safe_load(acceptance_path.read_text())
        acceptance["status"] = "candidate_scope_unaccepted"
        acceptance["current_verdict"] = "PENDING_INDEPENDENT_ROASTS"
        for review in acceptance["reviews"].values():
            review.clear()
            review.update({"verdict": "PENDING", "p1": None, "p2": None, "p3": None})
        acceptance["mechanical_binding"]["reviewed_payload_sha256"] = None
        acceptance["mechanical_binding"]["reviewed_candidate_commit"] = None
        acceptance["accepted_scope_only"] = []
        acceptance["next_gate"] = "stabilize_candidate_trust_unit_then_independent_roasts"
        acceptance_path.write_text(yaml.safe_dump(acceptance, sort_keys=False, allow_unicode=True))
        workflow_path = self.root / WORKFLOW
        workflow = workflow_path.read_text().replace(
            "python3 tools/checks/mint_next_batch18_runtime_scope_guard.py\n",
            "python3 tools/checks/mint_next_batch18_runtime_scope_guard.py --contract\n",
            1,
        )
        workflow = re.sub(
            r"(?m)^(  EXPECTED_BATCH18_[A-Z0-9_]+_SHA256:) [0-9a-f]{64}$",
            rf"\1 {'0' * 64}",
            workflow,
        )
        workflow_path.write_text(workflow)
        spec_path = self.root / SPEC
        spec_path.write_text(spec_path.read_text().replace(
            "batch18-canton-runtime-scope: python3 tools/checks/mint_next_batch18_runtime_scope_guard.py\n",
            "batch18-canton-runtime-scope: python3 tools/checks/mint_next_batch18_runtime_scope_guard.py --contract\n",
            1,
        ))

    def test_current_scope_passes(self) -> None:
        validate(self.root, check_parent_git=False, require_accepted=None)

    def test_release_gate_matches_declared_lifecycle(self) -> None:
        status = yaml.safe_load((self.root / ACCEPTANCE).read_text())["status"]
        if status == "candidate_scope_unaccepted":
            with self.assertRaisesRegex(GuardFailure, "scope acceptance status drifted"):
                validate(self.root, check_parent_git=False, require_accepted=True)
        else:
            validate(self.root, check_parent_git=False, require_accepted=True)

    def test_promoted_fixture_passes_and_hostile_is_not_lifecycle_vacuous(self) -> None:
        self._promote_fixture()
        validate(self.root, check_byte_digest=True, check_parent_git=False, require_accepted=None)
        scope_path = self.root / SCOPE
        scope = yaml.safe_load(scope_path.read_text())
        scope["product_promotion"] = "allowed"
        scope_path.write_text(yaml.safe_dump(scope, sort_keys=False, allow_unicode=True))
        with self.assertRaisesRegex(GuardFailure, "product promotion widened"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_candidate_binding_extra_runtime_claim_is_rejected(self) -> None:
        self._candidate_fixture()
        path = self.root / ACCEPTANCE
        data = yaml.safe_load(path.read_text())
        data["mechanical_binding"]["runtime_accepted"] = True
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        with self.assertRaisesRegex(GuardFailure, "mechanical binding schema drifted"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_candidate_review_extra_runtime_claim_is_rejected(self) -> None:
        self._candidate_fixture()
        path = self.root / ACCEPTANCE
        data = yaml.safe_load(path.read_text())
        data["reviews"]["engineering_parent_feasibility"]["runtime_implemented"] = True
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        with self.assertRaisesRegex(GuardFailure, "candidate review is not pending"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_promoted_binding_extra_runtime_claim_is_rejected(self) -> None:
        self._promote_fixture()
        path = self.root / ACCEPTANCE
        data = yaml.safe_load(path.read_text())
        data["mechanical_binding"]["runtime_accepted"] = True
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        with self.assertRaisesRegex(GuardFailure, "mechanical binding schema drifted"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_promoted_review_extra_user_validated_claim_is_rejected(self) -> None:
        self._promote_fixture()
        path = self.root / ACCEPTANCE
        data = yaml.safe_load(path.read_text())
        data["reviews"]["ux_accessibility_microstep_scope"]["user_validated"] = True
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        with self.assertRaisesRegex(GuardFailure, "accepted review schema drifted"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_ci_custom_shell_cannot_make_commands_inert(self) -> None:
        path = self.root / WORKFLOW
        data = yaml.load(path.read_text(), Loader=yaml.BaseLoader)
        data["jobs"]["scope"]["steps"][3]["shell"] = "echo {0}"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        with self.assertRaisesRegex(GuardFailure, "CI scope steps are not exact executable steps"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_ci_workflow_default_shell_cannot_make_all_commands_inert(self) -> None:
        path = self.root / WORKFLOW
        text = path.read_text().replace("\njobs:\n", "\ndefaults:\n  run:\n    shell: echo {0}\n\njobs:\n")
        path.write_text(text)
        with self.assertRaisesRegex(GuardFailure, "CI workflow top-level schema drifted"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_ci_workflow_default_working_directory_is_rejected(self) -> None:
        path = self.root / WORKFLOW
        text = path.read_text().replace("\njobs:\n", "\ndefaults:\n  run:\n    working-directory: /tmp\n\njobs:\n")
        path.write_text(text)
        with self.assertRaisesRegex(GuardFailure, "CI workflow top-level schema drifted"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_journey_entries_commented_out_are_not_active(self) -> None:
        path = self.root / JOURNEY_GUARD
        text = path.read_text()
        for entry in (
            "product/mint_next/batch18/runtime-scope.yaml",
            "product/mint_next/batch18/scope-acceptance.yaml",
            "tools/checks/mint_next_batch18_runtime_scope_guard.py",
            "tools/checks/tests/test_mint_next_batch18_runtime_scope_guard.py",
            ".github/workflows/mint-next-batch18-canton-runtime-scope.yml",
        ):
            text = text.replace(f'    "{entry}",', f'    # "{entry}",')
        path.write_text(text)
        with self.assertRaisesRegex(GuardFailure, "Journey OS active scope entry missing"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_journey_entries_moved_to_dead_string_are_not_active(self) -> None:
        path = self.root / JOURNEY_GUARD
        text = path.read_text()
        dead = []
        for entry in (
            "product/mint_next/batch18/runtime-scope.yaml",
            "product/mint_next/batch18/scope-acceptance.yaml",
            "tools/checks/mint_next_batch18_runtime_scope_guard.py",
            "tools/checks/tests/test_mint_next_batch18_runtime_scope_guard.py",
            ".github/workflows/mint-next-batch18-canton-runtime-scope.yml",
        ):
            text = text.replace(f'    "{entry}",\n', "")
            dead.append(entry)
        path.write_text(text + '\nDEAD_BATCH18_NAMES = "' + "|".join(dead) + '"\n')
        with self.assertRaisesRegex(GuardFailure, "Journey OS active scope entry missing"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_journey_allow_cannot_be_cleared_after_declaration(self) -> None:
        path = self.root / JOURNEY_GUARD
        path.write_text(path.read_text() + "\nALLOW.clear()\n")
        with self.assertRaisesRegex(GuardFailure, "Journey OS ALLOW is reassigned or mutated"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_journey_allow_alias_clear_invalidates_review_payload(self) -> None:
        path = self.root / JOURNEY_GUARD
        path.write_text(path.read_text() + "\n_BATCH18_ALIAS = ALLOW\n_BATCH18_ALIAS.clear()\n")
        with self.assertRaisesRegex(GuardFailure, "review payload drifted"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_journey_allow_helper_mutation_invalidates_review_payload(self) -> None:
        path = self.root / JOURNEY_GUARD
        path.write_text(path.read_text() + "\ndef _batch18_mutate(value):\n    value.clear()\n_batch18_mutate(ALLOW)\n")
        with self.assertRaisesRegex(GuardFailure, "review payload drifted"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_journey_allow_alias_isub_invalidates_review_payload(self) -> None:
        path = self.root / JOURNEY_GUARD
        path.write_text(path.read_text() + "\n_BATCH18_ALIAS = ALLOW\n_BATCH18_ALIAS -= set(ALLOW)\n")
        with self.assertRaisesRegex(GuardFailure, "review payload drifted"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_journey_allow_container_alias_invalidates_review_payload(self) -> None:
        path = self.root / JOURNEY_GUARD
        path.write_text(path.read_text() + "\n_BATCH18_BOX = [ALLOW]\n_BATCH18_BOX[0].clear()\n")
        with self.assertRaisesRegex(GuardFailure, "review payload drifted"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_current_artifacts_are_a_pending_candidate_anchor(self) -> None:
        self._candidate_fixture()
        expected_payload = yaml.safe_load((self.root / ACCEPTANCE).read_text())["mechanical_binding"]["candidate_review_payload_sha256"]
        _validate_pending_candidate_artifacts(
            (self.root / SCOPE).read_text(),
            (self.root / ACCEPTANCE).read_text(),
            (self.root / WORKFLOW).read_text(),
            (self.root / SPEC).read_text(),
            expected_payload,
        )

    def test_candidate_anchor_with_extra_runtime_claim_is_rejected(self) -> None:
        self._candidate_fixture()
        acceptance = yaml.safe_load((self.root / ACCEPTANCE).read_text())
        expected_payload = acceptance["mechanical_binding"]["candidate_review_payload_sha256"]
        acceptance["mechanical_binding"]["runtime_accepted"] = True
        with self.assertRaisesRegex(GuardFailure, "reviewed anchor binding schema drifted"):
            _validate_pending_candidate_artifacts(
                (self.root / SCOPE).read_text(),
                yaml.safe_dump(acceptance, sort_keys=False),
                (self.root / WORKFLOW).read_text(),
                (self.root / SPEC).read_text(),
                expected_payload,
            )

    def test_candidate_anchor_with_wrong_well_formed_payload_is_rejected(self) -> None:
        self._candidate_fixture()
        acceptance = yaml.safe_load((self.root / ACCEPTANCE).read_text())
        expected_payload = acceptance["mechanical_binding"]["candidate_review_payload_sha256"]
        acceptance["mechanical_binding"]["candidate_review_payload_sha256"] = "0" * 64
        with self.assertRaisesRegex(GuardFailure, "reviewed anchor candidate payload was not self-bound"):
            _validate_pending_candidate_artifacts(
                (self.root / SCOPE).read_text(),
                yaml.safe_dump(acceptance, sort_keys=False),
                (self.root / WORKFLOW).read_text(),
                (self.root / SPEC).read_text(),
                expected_payload,
            )

    def test_promoted_artifacts_cannot_be_reused_as_candidate_anchor(self) -> None:
        expected_payload = yaml.safe_load((self.root / ACCEPTANCE).read_text())["mechanical_binding"]["candidate_review_payload_sha256"]
        self._promote_fixture()
        with self.assertRaisesRegex(GuardFailure, "reviewed anchor was not a pending scope candidate"):
            _validate_pending_candidate_artifacts(
                (self.root / SCOPE).read_text(),
                (self.root / ACCEPTANCE).read_text(),
                (self.root / WORKFLOW).read_text(),
                (self.root / SPEC).read_text(),
                expected_payload,
            )

    def test_r4_planned_file_swap_is_rejected(self) -> None:
        self._mutate(
            lambda d: d["microsteps"]["R4"]["subgate_contracts"]["R4a_safe_exit"].update(
                planned_test_file="one_shared_fake_test.dart"
            ),
            "R4a_safe_exit planned test ownership drifted",
        )

    def test_planned_topology_cannot_claim_runtime_state(self) -> None:
        self._mutate(
            lambda d: d["planned_gate_topology"]["gates"]["R1"].update(state="PASS", command="true"),
            "planned gate topology drifted",
        )

    def test_byte_drift_has_its_own_failure(self) -> None:
        path = self.root / SCOPE
        path.write_text(path.read_text() + "\n")
        with self.assertRaisesRegex(GuardFailure, "scope bytes drifted"):
            validate(self.root, check_parent_git=False, require_accepted=None)

    def test_duplicate_yaml_key_is_rejected_semantically(self) -> None:
        path = self.root / SCOPE
        path.write_text(path.read_text().replace("status:", "status: duplicate\nstatus:", 1))
        with self.assertRaisesRegex(GuardFailure, "duplicate YAML key: status"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_scope_acceptance_claim_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d.update(status="accepted_scope"), "scope acceptance status drifted")

    def test_runtime_knowledge_claim_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["acceptance_model"].update(runtime_state_evaluated_by_scope_guard=True), "scope guard claims runtime knowledge")

    def test_product_promotion_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d.update(product_promotion="allowed"), "product promotion widened")

    def test_hidden_surface_widening_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d.update(runtime_surface="production_route"), "runtime surface widened")

    def test_authority_retarget_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["authority"].update(rule="runtime_may_ignore_parent"), "authority contract drifted")

    def test_complete_gate_removal_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["acceptance_model"]["complete_runtime_gate_requires"].pop(), "complete runtime gate obligations drifted")

    def test_post_runtime_product_promotion_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["acceptance_model"].update(product_promotion_after_runtime_acceptance="allowed_now"), "post-runtime product promotion widened")

    def test_partial_microstep_acceptance_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["acceptance_model"].update(microstep_acceptance="allowed"), "a microstep can promote runtime")

    def test_contradictory_extra_acceptance_key_is_rejected(self) -> None:
        self._mutate(lambda d: d["acceptance_model"].update(runtime_accepted=True), "acceptance schema drifted")

    def test_microstep_removal_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["microsteps"].pop("R3"), "microstep order or coverage drifted")

    def test_subgate_weakening_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["microsteps"]["R4"]["subgates"].pop(), "R4 subgates drifted")

    def test_r4_obligation_ownership_swap_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["microsteps"]["R4"]["subgate_contracts"]["R4a_safe_exit"]["obligation_ids"].__setitem__(0, "R4_06"), "R4a obligation ownership drifted")

    def test_obligation_removal_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["microsteps"]["R4"]["obligations"].pop(), "R4 obligation coverage drifted")

    def test_same_prefix_nonsense_obligation_is_rejected_exactly(self) -> None:
        self._mutate(lambda d: d["microsteps"]["R1"]["obligations"].__setitem__(0, "R1_99_nonsense"), "R1 exact obligations drifted")

    def test_required_control_removal_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["required_controls"]["safe_exit"].remove("keep_local_reference"), "required control topology drifted")

    def test_any_out_of_scope_removal_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["hard_out_of_scope"].remove("bank_insurance_pension_AVS_AI_or_tax_authority_integration"), "hard out-of-scope inventory drifted")

    def test_required_test_mode_removal_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["required_test_modes"].clear(), "required test modes drifted")

    def test_forbidden_privacy_claim_removal_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["forbidden_claims_until_separate_acceptance"].remove("privacy_compliant_by_declaration"), "forbidden claim inventory drifted")

    def test_runtime_gate_registry_claim_is_rejected_semantically(self) -> None:
        self._mutate(lambda d: d["planned_gate_topology"]["gates"]["R1"].update(state="PASS"), "planned gate topology drifted")

    def test_parent_drift_is_rejected_even_if_scope_parent_hash_is_rebound(self) -> None:
        parent = self.root / PARENT
        parent.write_text(parent.read_text() + "\n# drift\n")
        scope = yaml.safe_load((self.root / SCOPE).read_text())
        import hashlib
        scope["authority"]["parent_contract_sha256"] = hashlib.sha256(parent.read_bytes()).hexdigest()
        (self.root / SCOPE).write_text(yaml.safe_dump(scope, sort_keys=False))
        with self.assertRaisesRegex(GuardFailure, "accepted Batch17 parent drifted"):
            validate(self.root, check_byte_digest=False, check_parent_git=False, require_accepted=None)

    def test_parent_locale_copy_drift_is_rejected_by_parent_guard(self) -> None:
        path = self.root / batch17.COPY
        path.write_text(path.read_text() + "\n")
        with self.assertRaisesRegex(batch17.GuardFailure, "candidate review payload drifted"):
            validate(self.root, check_parent_git=False, require_accepted=None)

    def test_ci_comment_is_not_operational(self) -> None:
        path = self.root / WORKFLOW
        path.write_text(path.read_text().replace("        run: python3 tools/checks/mint_next_batch18_runtime_scope_guard.py", "        # run: python3 tools/checks/mint_next_batch18_runtime_scope_guard.py"))
        with self.assertRaisesRegex(GuardFailure, "CI scope steps are not exact executable steps"):
            validate(self.root, check_parent_git=False, require_accepted=None)

    def test_ci_false_condition_is_rejected(self) -> None:
        path = self.root / WORKFLOW
        path.write_text(path.read_text().replace("  scope:\n", "  scope:\n    if: false\n"))
        with self.assertRaisesRegex(GuardFailure, "CI scope job schema drifted"):
            validate(self.root, check_parent_git=False, require_accepted=None)

    def test_spec_comment_is_not_operational(self) -> None:
        path = self.root / SPEC
        path.write_text(path.read_text().replace("batch18-canton-runtime-scope:", "<!-- batch18-canton-runtime-scope:"))
        with self.assertRaisesRegex(GuardFailure, "operational SPEC guard binding"):
            validate(self.root, check_parent_git=False, require_accepted=None)

    def test_guard_source_drift_invalidates_candidate_receipt(self) -> None:
        path = self.root / GUARD
        path.write_text(path.read_text() + "\n# weakened\n")
        with self.assertRaisesRegex(GuardFailure, "candidate review payload drifted"):
            validate(self.root, check_parent_git=False, require_accepted=None)

    def test_hostile_test_deletion_invalidates_registry(self) -> None:
        path = self.root / TESTS
        text = path.read_text()
        start = text.index("    def test_byte_drift_has_its_own_failure")
        end = text.index("    def test_duplicate_yaml_key_is_rejected_semantically", start)
        path.write_text(text[:start] + text[end:])
        with self.assertRaisesRegex(GuardFailure, "immutable test inventory drifted"):
            validate(self.root, check_parent_git=False, require_accepted=None)

    def test_acceptance_claim_without_reviews_is_rejected(self) -> None:
        self._candidate_fixture()
        path = self.root / ACCEPTANCE
        data = yaml.safe_load(path.read_text())
        data["status"] = "accepted_scope_contract_runtime_not_evaluated"
        data["current_verdict"] = "SCOPE_ACCEPTED_RUNTIME_NOT_EVALUATED"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        with self.assertRaisesRegex(GuardFailure, "scope acceptance lifecycle drifted"):
            validate(self.root, check_parent_git=False, require_accepted=False)


if __name__ == "__main__":
    unittest.main()
