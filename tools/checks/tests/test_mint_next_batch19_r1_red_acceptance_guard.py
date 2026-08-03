from __future__ import annotations

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import yaml

from tools.checks import mint_next_batch19_r1_red_acceptance_guard as guard

ROOT = Path(__file__).resolve().parents[3]
FILES = (guard.ACCEPTANCE, guard.GUARD, guard.TESTS, guard.OWNER, *guard.RED_ARTIFACTS)


class Batch19R1RedAcceptanceGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for relative in FILES:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _validate(self, **kwargs) -> None:
        with patch.object(guard, "_ancestor", return_value=True), patch.object(
            guard,
            "_git_bytes",
            side_effect=lambda root, commit, relative: (ROOT / relative).read_bytes(),
        ):
            guard.validate(self.root, check_git=False, **kwargs)

    def _mutate(self, mutation, expected: str) -> None:
        path = self.root / guard.ACCEPTANCE
        data = yaml.safe_load(path.read_text())
        mutation(data)
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        with self.assertRaisesRegex(guard.GuardFailure, expected):
            self._validate()

    def test_pending_candidate_passes(self) -> None:
        self._validate(require_accepted=False)

    def test_release_rejects_pending(self) -> None:
        with self.assertRaisesRegex(guard.GuardFailure, "still pending"):
            self._validate(require_accepted=True)

    def test_duplicate_yaml_key_is_rejected(self) -> None:
        path = self.root / guard.ACCEPTANCE
        path.write_text(path.read_text() + "\nstatus: accepted\n")
        with self.assertRaisesRegex(guard.GuardFailure, "duplicate YAML key"):
            self._validate()

    def test_runtime_implementation_claim_is_rejected(self) -> None:
        self._mutate(lambda d: d["candidate"].__setitem__("runtime_implemented", True), "candidate identity")

    def test_runtime_acceptance_claim_is_rejected(self) -> None:
        self._mutate(lambda d: d["candidate"].__setitem__("runtime_accepted", True), "candidate identity")

    def test_product_surface_widening_is_rejected(self) -> None:
        self._mutate(lambda d: d["candidate"].__setitem__("product_surface", "product"), "candidate identity")

    def test_later_gate_claim_is_rejected(self) -> None:
        self._mutate(lambda d: d["candidate"].__setitem__("gate", "R2"), "candidate identity")

    def test_proof_command_drift_is_rejected(self) -> None:
        self._mutate(lambda d: d["proof_commands"].__setitem__("isolated_expected_red", "true"), "proof command")

    def test_pending_review_claim_is_rejected(self) -> None:
        self._mutate(lambda d: d["reviews"]["mechanical_evidence"].__setitem__("verdict", "ACCEPT"), "claims reviews")

    def test_pending_review_extra_claim_is_rejected(self) -> None:
        self._mutate(lambda d: d["reviews"]["mechanical_evidence"].__setitem__("runtime_accepted", True), "claims reviews")

    def test_pending_evidence_claim_is_rejected(self) -> None:
        self._mutate(lambda d: d.__setitem__("accepted_evidence", ["runtime"]), "claims accepted evidence")

    def test_not_accepted_boundary_removal_is_rejected(self) -> None:
        self._mutate(lambda d: d.__setitem__("not_accepted", []), "not-accepted boundary")

    def test_red_artifact_drift_is_rejected(self) -> None:
        path = self.root / guard.R1_TEST
        path.write_text(path.read_text() + "\n// drift\n")
        with self.assertRaisesRegex(guard.GuardFailure, "RED artifact drifted"):
            self._validate()

    def test_acceptance_guard_drift_changes_payload(self) -> None:
        path = self.root / guard.GUARD
        path.write_text(path.read_text() + "\n# drift\n")
        with self.assertRaisesRegex(guard.GuardFailure, "candidate payload drifted"):
            self._validate()

    def test_acceptance_tests_drift_changes_payload(self) -> None:
        path = self.root / guard.TESTS
        path.write_text(path.read_text().replace("test_runtime_implementation_claim", "removed_runtime_claim", 1))
        with self.assertRaisesRegex(guard.GuardFailure, "candidate payload drifted"):
            self._validate()

    def test_future_path_owner_does_not_deadlock_accepted_next_gate(self) -> None:
        completed = [
            subprocess.CompletedProcess([], 0, "a" * 40 + "\n", ""),
            subprocess.CompletedProcess(
                [],
                0,
                "\n".join([
                    str(guard.OWNER),
                    str(guard.ACCEPTANCE),
                    str(guard.GUARD),
                    str(guard.TESTS),
                    ".planning/journeys/path-owners/batch20-r1-runtime.json",
                ]) + "\n",
                "",
            ),
        ]
        with patch.object(guard.subprocess, "run", side_effect=completed):
            guard._git_boundary(self.root)

    def test_non_owner_future_path_inside_candidate_window_is_rejected(self) -> None:
        completed = [
            subprocess.CompletedProcess([], 0, "a" * 40 + "\n", ""),
            subprocess.CompletedProcess([], 0, "product/mint_next/hidden-runtime.dart\n", ""),
        ]
        with patch.object(guard.subprocess, "run", side_effect=completed):
            with self.assertRaisesRegex(guard.GuardFailure, "acceptance scope widened"):
                guard._git_boundary(self.root)


if __name__ == "__main__":
    unittest.main()
