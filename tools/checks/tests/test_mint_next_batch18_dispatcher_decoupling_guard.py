from __future__ import annotations

import shutil
import tempfile
import unittest
import json
import subprocess
from pathlib import Path

import yaml

from tools.checks import mint_next_batch17_canton_scope_guard as batch17
from tools.checks import journey_os_check as journey_os
from tools.checks import mint_next_batch18_dispatcher_decoupling_guard as guard
from tools.checks import mint_next_batch18_runtime_scope_guard as scope_guard
from tools.checks.tests.test_mint_next_batch18_runtime_scope_guard import (
    PARENT_FILES,
)


ROOT = Path(__file__).resolve().parents[3]
FILES = tuple(
    dict.fromkeys(
        (
            guard.ACCEPTANCE,
            guard.SCOPE_ACCEPTANCE,
            guard.JOURNEY,
            guard.GUARD,
            guard.TESTS,
            guard.WORKFLOW,
            guard.OLD_WORKFLOW,
            guard.SPEC,
            scope_guard.SCOPE,
            scope_guard.PARENT,
            scope_guard.GUARD,
            scope_guard.TESTS,
            batch17.LEFTHOOK,
            *PARENT_FILES,
        )
    )
)


class DispatcherDecouplingGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        live_acceptance = yaml.safe_load((ROOT / guard.ACCEPTANCE).read_text())
        reviewed_candidate = live_acceptance.get("mechanical_binding", {}).get("reviewed_candidate_commit")
        candidate_lifecycle_files = {guard.ACCEPTANCE, guard.WORKFLOW, guard.SPEC}
        for relative in FILES:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            if live_acceptance.get("status") == "accepted_dispatcher_decoupling" and relative in candidate_lifecycle_files:
                target.write_bytes(
                    subprocess.run(
                        ["git", "show", f"{reviewed_candidate}:{relative}"],
                        cwd=ROOT,
                        check=True,
                        capture_output=True,
                    ).stdout
                )
            else:
                shutil.copy2(ROOT / relative, target)
        guard.validate(self.root, check_git=False, require_accepted=False)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _acceptance_mutation(self, mutation, expected: str) -> None:
        path = self.root / guard.ACCEPTANCE
        data = yaml.safe_load(path.read_text())
        mutation(data)
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        with self.assertRaisesRegex(guard.GuardFailure, expected):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_current_candidate_passes(self) -> None:
        guard.validate(self.root, check_git=False, require_accepted=False)

    def test_live_repository_lifecycle_passes(self) -> None:
        guard.validate(ROOT, check_git=False, require_accepted=None)

    def test_review_payload_is_well_formed_and_bound(self) -> None:
        payload = guard.review_payload(self.root)
        self.assertRegex(payload, r"^[0-9a-f]{64}$")
        acceptance = yaml.safe_load((self.root / guard.ACCEPTANCE).read_text())
        self.assertEqual(
            acceptance["mechanical_binding"]["candidate_review_payload_sha256"],
            payload,
        )

    def test_unowned_future_literal_append_is_rejected(self) -> None:
        path = self.root / guard.JOURNEY
        text = path.read_text()
        text = text.replace(
            "ALLOW = {",
            'ALLOW = {\n    "product/mint_next/batch99/future-contract.yaml",',
            1,
        )
        path.write_text(text)
        with self.assertRaisesRegex(guard.GuardFailure, "owner-registry logic or literal ALLOW"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_pending_owner_receipt_does_not_authorize_target(self) -> None:
        owner = self.root / journey_os.PATH_OWNERS / "future-red.json"
        owner.parent.mkdir(parents=True)
        target = "product/mint_next/batch99/future-contract.yaml"
        data = self._owner_receipt("future-red", [target])
        owner.write_text(json.dumps(data))
        errors = journey_os._scope_errors(self.root, [owner.relative_to(self.root).as_posix(), target])
        self.assertIn(f"changed file outside Journey OS whitelist: {target}", errors)

    def test_owner_receipt_cannot_own_control_plane(self) -> None:
        owner = self.root / journey_os.PATH_OWNERS / "control-plane.json"
        owner.parent.mkdir(parents=True)
        data = self._owner_receipt("control-plane", ["tools/checks/journey_os_check.py"])
        owner.write_text(json.dumps(data))
        errors = journey_os._scope_errors(self.root, [owner.relative_to(self.root).as_posix()])
        self.assertIn(f"Journey path-owner path set invalid: {owner.relative_to(self.root).as_posix()}", errors)

    def test_fabricated_accepted_owner_receipt_does_not_authorize(self) -> None:
        owner = self.root / journey_os.PATH_OWNERS / "fake.json"
        owner.parent.mkdir(parents=True)
        target = "product/mint_next/batch99/fake.yaml"
        data = self._owner_receipt("fake", [target])
        payload = data["mechanical_binding"]["candidate_payload_sha256"]
        data["status"] = "accepted"
        data["reviews"] = {
            role: {"verdict": "ACCEPT", "p1": 0, "p2": 0, "p3": 0, "reviewed_payload_sha256": payload}
            for role in journey_os._PATH_OWNER_ROLES
        }
        data["mechanical_binding"].update(
            {"reviewed_payload_sha256": payload, "reviewed_candidate_commit": "a" * 40}
        )
        owner.write_text(json.dumps(data))
        errors = journey_os._scope_errors(self.root, [owner.relative_to(self.root).as_posix(), target])
        self.assertIn(f"Journey path-owner candidate cannot replay: {owner.relative_to(self.root).as_posix()}", errors)
        self.assertIn(f"changed file outside Journey OS whitelist: {target}", errors)

    def test_duplicate_path_owners_are_rejected(self) -> None:
        owners = self.root / journey_os.PATH_OWNERS
        owners.mkdir(parents=True)
        target = "product/mint_next/batch99/shared.yaml"
        for owner_id in ("one", "two"):
            (owners / f"{owner_id}.json").write_text(json.dumps(self._owner_receipt(owner_id, [target])))
        errors = journey_os._scope_errors(self.root, [])
        self.assertIn(f"Journey path has multiple owners: {target}", errors)

    def test_independently_reviewed_owner_receipt_authorizes_exact_target(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.email", "guard@example.invalid"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.name", "Guard Fixture"], cwd=root, check=True)
            owner = root / journey_os.PATH_OWNERS / "future-red.json"
            owner.parent.mkdir(parents=True)
            target = "product/mint_next/batch99/future-contract.yaml"
            candidate = self._owner_receipt("future-red", [target])
            owner.write_text(json.dumps(candidate, sort_keys=True))
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-qm", "candidate"], cwd=root, check=True)
            sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, check=True, capture_output=True, text=True).stdout.strip()
            payload = candidate["mechanical_binding"]["candidate_payload_sha256"]
            accepted = self._owner_receipt("future-red", [target])
            accepted["status"] = "accepted"
            accepted["reviews"] = {
                role: {"verdict": "ACCEPT", "p1": 0, "p2": 0, "p3": 0, "reviewed_payload_sha256": payload}
                for role in journey_os._PATH_OWNER_ROLES
            }
            accepted["mechanical_binding"].update(
                {"reviewed_payload_sha256": payload, "reviewed_candidate_commit": sha}
            )
            owner.write_text(json.dumps(accepted, sort_keys=True))
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-qm", "promote"], cwd=root, check=True)
            errors = journey_os._scope_errors(root, [owner.relative_to(root).as_posix(), target])
            self.assertEqual(errors, [])
            other = "product/mint_next/batch99/unowned.yaml"
            self.assertIn(
                f"changed file outside Journey OS whitelist: {other}",
                journey_os._scope_errors(root, [other]),
            )

    @staticmethod
    def _owner_receipt(owner_id: str, paths: list[str]) -> dict:
        data = {
            "schema_version": 1,
            "owner_id": owner_id,
            "status": "candidate_unaccepted",
            "paths": sorted(paths),
            "reviews": {
                role: {"verdict": "PENDING", "p1": None, "p2": None, "p3": None}
                for role in journey_os._PATH_OWNER_ROLES
            },
            "mechanical_binding": {
                "candidate_payload_sha256": None,
                "reviewed_payload_sha256": None,
                "reviewed_candidate_commit": None,
            },
        }
        data["mechanical_binding"]["candidate_payload_sha256"] = journey_os._path_owner_payload(data)
        return data

    def test_nonliteral_allow_append_is_rejected(self) -> None:
        path = self.root / guard.JOURNEY
        path.write_text(path.read_text().replace("ALLOW = {", "ALLOW = {\n    str(Path('evil')),", 1))
        with self.assertRaisesRegex(guard.GuardFailure, "executable logic"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_executable_journey_mutation_is_rejected(self) -> None:
        path = self.root / guard.JOURNEY
        path.write_text(path.read_text() + "\nALLOW.clear()\n")
        with self.assertRaisesRegex(guard.GuardFailure, "ALLOW is reassigned or mutated|executable logic"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_owned_literal_removal_is_rejected(self) -> None:
        path = self.root / guard.JOURNEY
        path.write_text(path.read_text().replace(f'    "{guard.OWNED_MIGRATION_ENTRIES[0]}",\n', "", 1))
        with self.assertRaisesRegex(guard.GuardFailure, "owned migration Journey entry|literal ALLOW"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_owned_literal_duplication_is_rejected(self) -> None:
        path = self.root / guard.JOURNEY
        entry = f'    "{guard.OWNED_MIGRATION_ENTRIES[0]}",\n'
        path.write_text(path.read_text().replace(entry, entry + entry, 1))
        with self.assertRaisesRegex(guard.GuardFailure, "owned migration Journey entry|literal ALLOW"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_historical_scope_payload_mutation_is_rejected(self) -> None:
        path = self.root / guard.SCOPE_ACCEPTANCE
        data = yaml.safe_load(path.read_text())
        data["mechanical_binding"]["reviewed_payload_sha256"] = "0" * 64
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        with self.assertRaisesRegex(guard.GuardFailure, "historical scope payload"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_historical_scope_candidate_mutation_is_rejected(self) -> None:
        path = self.root / guard.SCOPE_ACCEPTANCE
        data = yaml.safe_load(path.read_text())
        data["mechanical_binding"]["reviewed_candidate_commit"] = "a" * 40
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        with self.assertRaisesRegex(guard.GuardFailure, "historical scope candidate"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_candidate_cannot_claim_runtime(self) -> None:
        self._acceptance_mutation(
            lambda data: data.__setitem__("runtime_accepted", True),
            "acceptance schema drifted",
        )

    def test_candidate_cannot_claim_accepted_change(self) -> None:
        self._acceptance_mutation(
            lambda data: data.__setitem__("accepted_change", ["anything"]),
            "candidate claims accepted change",
        )

    def test_candidate_review_cannot_be_preaccepted(self) -> None:
        self._acceptance_mutation(
            lambda data: data["reviews"]["dispatcher_integrity"].update(
                {"verdict": "ACCEPT", "p1": 0, "p2": 0, "p3": 0}
            ),
            "candidate review is not pending",
        )

    def test_candidate_payload_rebinding_is_rejected(self) -> None:
        self._acceptance_mutation(
            lambda data: data["mechanical_binding"].__setitem__(
                "candidate_review_payload_sha256", "0" * 64
            ),
            "candidate payload drifted",
        )

    def test_guard_mutation_invalidates_payload(self) -> None:
        path = self.root / guard.GUARD
        path.write_text(path.read_text() + "\n# mutation\n")
        with self.assertRaisesRegex(guard.GuardFailure, "candidate payload drifted"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_old_guard_mutation_invalidates_payload(self) -> None:
        path = self.root / scope_guard.GUARD
        path.write_text(path.read_text() + "\n# mutation\n")
        old_workflow = self.root / guard.OLD_WORKFLOW
        digest = guard._sha(path)
        import re

        old_workflow.write_text(
            re.sub(
                r"(?m)^(  EXPECTED_BATCH18_GUARD_SHA256:) [0-9a-f]{64}$",
                rf"\1 {digest}",
                old_workflow.read_text(),
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "candidate payload drifted"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_workflow_custom_shell_is_rejected(self) -> None:
        path = self.root / guard.WORKFLOW
        path.write_text(
            path.read_text().replace(
                "        run: python3 tools/checks/mint_next_batch18_dispatcher_decoupling_guard.py --contract",
                "        run: python3 tools/checks/mint_next_batch18_dispatcher_decoupling_guard.py --contract\n        shell: echo {0}",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "candidate payload drifted|workflow steps drifted"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_workflow_false_condition_is_rejected(self) -> None:
        path = self.root / guard.WORKFLOW
        path.write_text(path.read_text().replace("    runs-on: ubuntu-latest", "    runs-on: ubuntu-latest\n    if: false"))
        with self.assertRaisesRegex(guard.GuardFailure, "candidate payload drifted|job schema drifted"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_spec_comment_is_not_operational(self) -> None:
        path = self.root / guard.SPEC
        path.write_text(
            path.read_text().replace(
                "batch18-dispatcher-decoupling:",
                "<!-- batch18-dispatcher-decoupling:",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "SPEC dispatcher lines drifted|SPEC lifecycle"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_duplicate_acceptance_key_is_rejected(self) -> None:
        path = self.root / guard.ACCEPTANCE
        path.write_text(path.read_text() + "\nstatus: accepted_dispatcher_decoupling\n")
        with self.assertRaisesRegex(guard.GuardFailure, "duplicate YAML key"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_symlinked_acceptance_is_rejected(self) -> None:
        path = self.root / guard.ACCEPTANCE
        copy = self.root / "acceptance-copy.yaml"
        path.replace(copy)
        path.symlink_to(copy)
        with self.assertRaisesRegex(guard.GuardFailure, "missing regular artifact"):
            guard.validate(self.root, check_git=False, require_accepted=False)


if __name__ == "__main__":
    unittest.main()
