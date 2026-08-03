from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks import mint_next_batch17_canton_scope_guard as batch17
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
        for relative in FILES:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
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

    def test_review_payload_is_well_formed_and_bound(self) -> None:
        payload = guard.review_payload(self.root)
        self.assertRegex(payload, r"^[0-9a-f]{64}$")
        acceptance = yaml.safe_load((self.root / guard.ACCEPTANCE).read_text())
        self.assertEqual(
            acceptance["mechanical_binding"]["candidate_review_payload_sha256"],
            payload,
        )

    def test_future_literal_append_does_not_rebind_executable_logic(self) -> None:
        path = self.root / guard.JOURNEY
        text = path.read_text()
        text = text.replace(
            "ALLOW = {",
            'ALLOW = {\n    "product/mint_next/batch99/future-contract.yaml",',
            1,
        )
        path.write_text(text)
        guard.validate(self.root, check_git=False, require_accepted=False)

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
        path.write_text(path.read_text().replace(f'    "{guard.OWNED_APPEND_ONLY_ENTRIES[0]}",\n', "", 1))
        with self.assertRaisesRegex(guard.GuardFailure, "owned append-only Journey entry"):
            guard.validate(self.root, check_git=False, require_accepted=False)

    def test_owned_literal_duplication_is_rejected(self) -> None:
        path = self.root / guard.JOURNEY
        entry = f'    "{guard.OWNED_APPEND_ONLY_ENTRIES[0]}",\n'
        path.write_text(path.read_text().replace(entry, entry + entry, 1))
        with self.assertRaisesRegex(guard.GuardFailure, "owned append-only Journey entry"):
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
