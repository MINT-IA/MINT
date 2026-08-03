from __future__ import annotations

import hashlib
import json
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
            subprocess.CompletedProcess(
                [], 0, ".planning/journeys/path-owners/batch20-r1-runtime.json\n", ""
            ),
        ]
        with patch.object(guard.subprocess, "run", side_effect=completed), patch.object(
            guard.journey_os_check, "_load_path_owners", return_value=(set(), [])
        ), patch.object(
            guard, "_require_owned_tail_chronology"
        ):
            guard._git_boundary(self.root)

    def test_non_owner_future_path_inside_candidate_window_is_rejected(self) -> None:
        completed = [
            subprocess.CompletedProcess([], 0, "a" * 40 + "\n", ""),
            subprocess.CompletedProcess([], 0, f"{guard.ACCEPTANCE}\n", ""),
            subprocess.CompletedProcess([], 0, "product/mint_next/hidden-runtime.dart\n", ""),
        ]
        with patch.object(guard.subprocess, "run", side_effect=completed), patch.object(
            guard.journey_os_check, "_load_path_owners", return_value=(set(), [])
        ):
            with self.assertRaisesRegex(guard.GuardFailure, "not reviewed-owned"):
                guard._git_boundary(self.root)

    def test_future_target_is_allowed_only_after_accepted_path_ownership(self) -> None:
        target = "product/mint_next/batch20/r1-runtime.dart"
        completed = [
            subprocess.CompletedProcess([], 0, "a" * 40 + "\n", ""),
            subprocess.CompletedProcess([], 0, f"{guard.ACCEPTANCE}\n", ""),
            subprocess.CompletedProcess([], 0, target + "\n", ""),
        ]
        with patch.object(guard.subprocess, "run", side_effect=completed), patch.object(
            guard.journey_os_check, "_load_path_owners", return_value=({target}, [])
        ), patch.object(
            guard, "_require_owned_tail_chronology"
        ):
            guard._git_boundary(self.root)

    def test_future_target_committed_before_owner_promotion_is_rejected(self) -> None:
        """Final accepted ownership must not authorize earlier target work."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.email", "test@mint.invalid"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.name", "MINT Test"], cwd=root, check=True)

            def commit(message: str) -> str:
                subprocess.run(["git", "add", "-A"], cwd=root, check=True)
                subprocess.run(["git", "commit", "-q", "-m", message], cwd=root, check=True)
                return subprocess.run(
                    ["git", "rev-parse", "HEAD"], cwd=root, check=True,
                    capture_output=True, text=True,
                ).stdout.strip()

            (root / "red.txt").write_text("red\n")
            red_commit = commit("red")
            acceptance = root / guard.ACCEPTANCE
            acceptance.parent.mkdir(parents=True, exist_ok=True)
            acceptance.write_text("candidate\n")
            acceptance_candidate = commit("acceptance candidate")

            target = "product/mint_next/batch20/r1-runtime.dart"
            owner_path = root / ".planning/journeys/path-owners/batch20-r1-runtime.json"
            owner_path.parent.mkdir(parents=True, exist_ok=True)
            payload_source = {
                "schema_version": 1,
                "owner_id": "batch20-r1-runtime",
                "paths": [target],
            }
            payload = hashlib.sha256(json.dumps(
                payload_source, sort_keys=True, separators=(",", ":"),
                ensure_ascii=False,
            ).encode("utf-8")).hexdigest()
            pending_review = {"verdict": "PENDING", "p1": None, "p2": None, "p3": None}
            owner = {
                **payload_source,
                "status": "candidate_unaccepted",
                "reviews": {
                    "scope_integrity": pending_review,
                    "mechanical_adversary": pending_review,
                    "journey_safety": pending_review,
                },
                "mechanical_binding": {
                    "candidate_payload_sha256": payload,
                    "reviewed_payload_sha256": None,
                    "reviewed_candidate_commit": None,
                },
            }
            owner_path.write_text(json.dumps(owner, indent=2) + "\n")
            owner_candidate = commit("owner pending")

            runtime = root / target
            runtime.parent.mkdir(parents=True, exist_ok=True)
            runtime.write_text("runtime before authorization\n")
            commit("target before owner accepted")

            accepted_review = {
                "verdict": "ACCEPT", "p1": 0, "p2": 0, "p3": 0,
                "reviewed_payload_sha256": payload,
            }
            owner["status"] = "accepted"
            owner["reviews"] = {
                "scope_integrity": accepted_review,
                "mechanical_adversary": accepted_review,
                "journey_safety": accepted_review,
            }
            owner["mechanical_binding"] = {
                "candidate_payload_sha256": payload,
                "reviewed_payload_sha256": payload,
                "reviewed_candidate_commit": owner_candidate,
            }
            owner_path.write_text(json.dumps(owner, indent=2) + "\n")
            commit("owner promoted after target")

            with patch.object(guard, "RED_COMMIT", red_commit):
                with self.assertRaisesRegex(guard.GuardFailure, "predates owner promotion"):
                    guard._git_boundary(root)

            # Rebuild the same tail in the required order: accepted owner first,
            # target work second. This must remain possible rather than deadlock.
            subprocess.run(["git", "reset", "--hard", "-q", owner_candidate], cwd=root, check=True)
            owner_path.write_text(json.dumps(owner, indent=2) + "\n")
            commit("owner promoted before target")
            runtime.parent.mkdir(parents=True, exist_ok=True)
            runtime.write_text("runtime after authorization\n")
            commit("target after owner accepted")
            with patch.object(guard, "RED_COMMIT", red_commit):
                guard._git_boundary(root)

            # A pre-authorization scratch file cannot be laundered by renaming
            # it into an accepted-owned path after promotion.
            subprocess.run(["git", "reset", "--hard", "-q", acceptance_candidate], cwd=root, check=True)
            scratch = root / "scratch.dart"
            scratch.write_text("runtime authored before authorization\n")
            commit("unowned scratch before owner")
            owner["status"] = "candidate_unaccepted"
            owner["reviews"] = {
                "scope_integrity": pending_review,
                "mechanical_adversary": pending_review,
                "journey_safety": pending_review,
            }
            owner["mechanical_binding"] = {
                "candidate_payload_sha256": payload,
                "reviewed_payload_sha256": None,
                "reviewed_candidate_commit": None,
            }
            owner_path.parent.mkdir(parents=True, exist_ok=True)
            owner_path.write_text(json.dumps(owner, indent=2) + "\n")
            renamed_owner_candidate = commit("owner pending after scratch")
            owner["status"] = "accepted"
            owner["reviews"] = {
                "scope_integrity": accepted_review,
                "mechanical_adversary": accepted_review,
                "journey_safety": accepted_review,
            }
            owner["mechanical_binding"] = {
                "candidate_payload_sha256": payload,
                "reviewed_payload_sha256": payload,
                "reviewed_candidate_commit": renamed_owner_candidate,
            }
            owner_path.write_text(json.dumps(owner, indent=2) + "\n")
            commit("owner promoted after scratch")
            runtime.parent.mkdir(parents=True, exist_ok=True)
            scratch.rename(runtime)
            commit("rename scratch into owned target")
            with patch.object(guard, "RED_COMMIT", red_commit):
                with self.assertRaisesRegex(guard.GuardFailure, "not reviewed-owned"):
                    guard._git_boundary(root)

    def test_dirty_or_untracked_worktree_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.email", "test@mint.invalid"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.name", "MINT Test"], cwd=root, check=True)
            tracked = root / "tracked.txt"
            tracked.write_text("clean\n")
            subprocess.run(["git", "add", "tracked.txt"], cwd=root, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "clean"], cwd=root, check=True)
            guard._require_clean_worktree(root)
            (root / "untracked-runtime.dart").write_text("hidden\n")
            with self.assertRaisesRegex(guard.GuardFailure, "clean worktree"):
                guard._require_clean_worktree(root)


if __name__ == "__main__":
    unittest.main()
