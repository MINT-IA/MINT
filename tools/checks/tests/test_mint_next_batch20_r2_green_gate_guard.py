from __future__ import annotations

import copy
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks import mint_next_batch20_r2_green_gate_guard as guard

ROOT = Path(__file__).resolve().parents[3]

# The trust unit whose bytes feed the payload plus the two re-pinned immutables
# read by the freeze assertion. The live GREEN-GATE manifest is deliberately NOT
# in this list: this suite never seeds any assertion from the committed
# manifest's lifecycle. Both the pending and accepted manifests are rebuilt below
# from the guard's own canonical constants, so the suite stays green whether the
# on-disk manifest is pending or accepted.
TRUST_FILES = (
    guard.GUARD,
    guard.TESTS,
    guard.PATH_OWNER,
    guard.RED_GUARD,
    guard.REGISTRY,
)


def _pending_manifest(payload: str) -> dict:
    return {
        "schema_version": 1,
        "status": guard.PENDING_STATUS,
        "current_verdict": guard.PENDING_VERDICT,
        "supersedes": copy.deepcopy(guard.EXPECTED_SUPERSEDES),
        "green_gate": copy.deepcopy(guard.EXPECTED_GREEN_GATE),
        "re_pinned_immutables": copy.deepcopy(guard.EXPECTED_RE_PINNED),
        "runtime_regating": copy.deepcopy(guard.EXPECTED_RUNTIME_REGATING),
        "runtime_surface": "hidden_design_lab_only",
        "product_promotion": "forbidden",
        "reviews": {role: dict(guard.PENDING_REVIEW) for role in guard.ROLES},
        "mechanical_binding": {
            "candidate_payload_sha256": payload,
            "reviewed_payload_sha256": None,
            "reviewed_candidate_commit": None,
            "green_lib_inventory_sha256": None,
        },
        "not_accepted": list(guard.PENDING_NOT_ACCEPTED),
        "next_gate": guard.EXPECTED_NEXT_GATE,
    }


def _accepted_manifest(payload: str, commit: str) -> dict:
    accepted_review = {
        "verdict": "ACCEPT", "p1": 0, "p2": 0, "p3": 0,
        "reviewed_payload_sha256": payload,
    }
    manifest = _pending_manifest(payload)
    manifest["status"] = guard.ACCEPTED_STATUS
    manifest["current_verdict"] = guard.ACCEPTED_VERDICT
    manifest["reviews"] = {role: dict(accepted_review) for role in guard.ROLES}
    manifest["mechanical_binding"] = {
        "candidate_payload_sha256": payload,
        "reviewed_payload_sha256": payload,
        "reviewed_candidate_commit": commit,
        # A concrete 64-hex green lib-inventory seal is mandatory at acceptance.
        "green_lib_inventory_sha256": "e" * 64,
    }
    # Acceptance ⟹ runtime implemented + sealed: those two leave not_accepted.
    manifest["not_accepted"] = list(guard.ACCEPTED_NOT_ACCEPTED)
    return manifest


def _dump(data: dict) -> str:
    return yaml.safe_dump(data, sort_keys=False, allow_unicode=True)


class Batch20R2GreenGateGuardTest(unittest.TestCase):
    """State-agnostic hostile suite for the R2 GREEN-GATE guard.

    Neither setUp nor any assertion reads the live committed manifest's
    lifecycle. The PENDING base is a canonical manifest built here and bound to
    the freshly computed payload; the ACCEPTED lifecycle is exercised against a
    real temp-git repository. The suite therefore asserts BOTH lifecycles and
    their falsifications and stays green whether the on-disk manifest is pending
    or accepted. It does NOT run the GREEN Flutter replay (runtime unimplemented).
    """

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for relative in TRUST_FILES:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        # Canonical pending base, bound to the freshly computed payload — never a
        # copy of the live manifest.
        self._write(_pending_manifest("0" * 64))
        self.payload = guard._payload(self.root)
        self._write(_pending_manifest(self.payload))

    def tearDown(self) -> None:
        self.temp.cleanup()

    # --- helpers -----------------------------------------------------------
    def _write(self, data: dict) -> None:
        path = self.root / guard.MANIFEST
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(_dump(data))

    def _validate(self, **kwargs) -> None:
        guard.validate(self.root, check_git=False, **kwargs)

    def _mutate(self, mutation, expected: str) -> None:
        path = self.root / guard.MANIFEST
        data = yaml.safe_load(path.read_text())
        mutation(data)
        path.write_text(_dump(data))
        with self.assertRaisesRegex(guard.GuardFailure, expected):
            self._validate()

    def _git(self, root: Path, *args: str) -> str:
        return subprocess.run(
            ["git", *args], cwd=root, check=True, capture_output=True, text=True
        ).stdout.strip()

    def _commit(self, root: Path, message: str) -> str:
        self._git(root, "add", "-A")
        self._git(root, "commit", "-q", "-m", message)
        return self._git(root, "rev-parse", "HEAD")

    def _write_at(self, root: Path, data: dict) -> None:
        path = root / guard.MANIFEST
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(_dump(data))

    def _accepted_repo(self):
        """Build a real temp-git repo whose working tree carries the ACCEPTED
        manifest and whose history carries the pending candidate commit.

        Mirrors the temp-git pattern of the RED acceptance suite so that the
        accepted lifecycle is attested by real ``git show`` / ``merge-base``
        rather than by copying the live manifest.
        """
        root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, root, ignore_errors=True)
        self._git(root, "init", "-q")
        self._git(root, "config", "user.email", "test@mint.invalid")
        self._git(root, "config", "user.name", "MINT Test")
        for relative in TRUST_FILES:
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        self._commit(root, "green gate trust unit")
        self._write_at(root, _pending_manifest("0" * 64))
        payload = guard._payload(root)
        self._write_at(root, _pending_manifest(payload))
        pending_commit = self._commit(root, "green gate candidate pending")
        self._write_at(root, _accepted_manifest(payload, pending_commit))
        return root, payload, pending_commit

    # --- pending lifecycle -------------------------------------------------
    def test_pending_candidate_passes(self) -> None:
        self._validate(require_accepted=False)

    def test_release_rejects_pending(self) -> None:
        with self.assertRaisesRegex(guard.GuardFailure, "still pending"):
            self._validate(require_accepted=True)

    def test_duplicate_yaml_key_is_rejected(self) -> None:
        path = self.root / guard.MANIFEST
        path.write_text(path.read_text() + "status: accepted_green_gate_runtime_not_implemented\n")
        with self.assertRaisesRegex(guard.GuardFailure, "duplicate YAML key"):
            self._validate()

    def test_non_mapping_manifest_root_is_rejected(self) -> None:
        (self.root / guard.MANIFEST).write_text("- just\n- a\n- list\n")
        with self.assertRaisesRegex(guard.GuardFailure, "root must be a mapping"):
            self._validate()

    def test_top_level_schema_drift_is_rejected(self) -> None:
        self._mutate(lambda d: d.__setitem__("extra_key", "x"), "schema drifted")

    def test_superseded_reference_drift_is_rejected(self) -> None:
        self._mutate(
            lambda d: d["supersedes"].__setitem__("accepted_commit", "deadbeef"),
            "superseded reference drifted",
        )

    def test_wrong_green_summary_is_rejected(self) -> None:
        self._mutate(
            lambda d: d["green_gate"].__setitem__(
                "expected_summary", {"passed": 14, "failed": 1, "load_or_harness_errors": 0}
            ),
            "green gate parameters drifted",
        )

    def test_wrong_test_sha_is_rejected(self) -> None:
        self._mutate(lambda d: d["green_gate"].__setitem__("test_sha256", "f" * 64), "green gate parameters drifted")

    def test_wrong_expected_exit_code_is_rejected(self) -> None:
        self._mutate(lambda d: d["green_gate"].__setitem__("expected_exit_code", 1), "green gate parameters drifted")

    def test_obligation_name_drop_is_rejected(self) -> None:
        self._mutate(
            lambda d: d["green_gate"].__setitem__(
                "obligation_test_names", sorted(guard.red.EXPECTED_TEST_NAMES)[:-1]
            ),
            "green gate parameters drifted",
        )

    def test_tampered_repin_sha_is_rejected(self) -> None:
        self._mutate(
            lambda d: d["re_pinned_immutables"]["red_guard"].__setitem__("sha256", "0" * 64),
            "re-pinned immutables drifted",
        )

    def test_runtime_regating_seal_premature_pin_is_rejected(self) -> None:
        self._mutate(
            lambda d: d["runtime_regating"].__setitem__("lib_inventory_seal", "a" * 64),
            "runtime re-gating drifted",
        )

    def test_runtime_surface_widening_is_rejected(self) -> None:
        self._mutate(lambda d: d.__setitem__("runtime_surface", "product"), "runtime surface widened")

    def test_product_promotion_widening_is_rejected(self) -> None:
        self._mutate(lambda d: d.__setitem__("product_promotion", "allowed"), "product promotion widened")

    def test_widened_not_accepted_is_rejected(self) -> None:
        self._mutate(
            lambda d: d.__setitem__("not_accepted", list(guard.PENDING_NOT_ACCEPTED)[:-1]),
            "not-accepted boundary drifted",
        )

    def test_path_owner_drift_changes_payload(self) -> None:
        path = self.root / guard.PATH_OWNER
        path.write_text(path.read_text().rstrip("\n") + "\n\n")
        with self.assertRaisesRegex(guard.GuardFailure, "candidate payload drifted"):
            self._validate()

    def test_next_gate_drift_is_rejected(self) -> None:
        self._mutate(lambda d: d.__setitem__("next_gate", "ship_it"), "next gate drifted")

    def test_pending_review_claiming_accept_is_rejected(self) -> None:
        self._mutate(
            lambda d: d["reviews"]["mechanical_adversary"].__setitem__("verdict", "ACCEPT"),
            "pending manifest claims reviews",
        )

    def test_pending_reviewed_binding_claim_is_rejected(self) -> None:
        self._mutate(
            lambda d: d["mechanical_binding"].__setitem__("reviewed_candidate_commit", "a" * 40),
            "pending manifest claims reviewed binding",
        )

    def test_pending_non_null_inventory_seal_is_rejected(self) -> None:
        # A pending manifest cannot claim a concrete lib-inventory seal — no
        # runtime is built yet.
        self._mutate(
            lambda d: d["mechanical_binding"].__setitem__("green_lib_inventory_sha256", "a" * 64),
            "pending manifest claims a green lib inventory seal",
        )

    def test_freeze_rejects_drifted_red_guard_file(self) -> None:
        path = self.root / guard.RED_GUARD
        path.write_text(path.read_text() + "\n# drift\n")
        with self.assertRaisesRegex(guard.GuardFailure, "re-pinned RED guard drifted"):
            self._validate()

    def test_freeze_rejects_drifted_registry_file(self) -> None:
        path = self.root / guard.REGISTRY
        path.write_text(path.read_text() + "\ndrift: true\n")
        with self.assertRaisesRegex(guard.GuardFailure, "re-pinned registry drifted"):
            self._validate()

    def test_guard_drift_changes_payload(self) -> None:
        path = self.root / guard.GUARD
        path.write_text(path.read_text() + "\n# drift\n")
        with self.assertRaisesRegex(guard.GuardFailure, "candidate payload drifted"):
            self._validate()

    def test_tests_drift_changes_payload(self) -> None:
        path = self.root / guard.TESTS
        path.write_text(path.read_text().replace("test_pending_candidate_passes", "renamed_pending", 1))
        with self.assertRaisesRegex(guard.GuardFailure, "candidate payload drifted"):
            self._validate()

    # --- accepted lifecycle (real temp-git) --------------------------------
    def test_accepted_candidate_passes(self) -> None:
        root, _payload, _pending_commit = self._accepted_repo()
        guard.validate(root, require_accepted=True, check_git=False)

    def test_accepted_manifest_rejected_when_expecting_pending(self) -> None:
        root, _payload, _pending_commit = self._accepted_repo()
        with self.assertRaisesRegex(guard.GuardFailure, "expected pending green gate"):
            guard.validate(root, require_accepted=False, check_git=False)

    def test_accepted_non_exact_review_is_rejected(self) -> None:
        root, payload, pending_commit = self._accepted_repo()
        data = _accepted_manifest(payload, pending_commit)
        data["reviews"]["mechanical_adversary"]["p1"] = 1
        self._write_at(root, data)
        with self.assertRaisesRegex(guard.GuardFailure, "accepted reviews are not exact"):
            guard.validate(root, require_accepted=True, check_git=False)

    def test_accepted_wrong_reviewed_payload_is_rejected(self) -> None:
        root, payload, pending_commit = self._accepted_repo()
        data = _accepted_manifest(payload, pending_commit)
        data["mechanical_binding"]["reviewed_payload_sha256"] = "f" * 64
        self._write_at(root, data)
        with self.assertRaisesRegex(guard.GuardFailure, "accepted payload drifted"):
            guard.validate(root, require_accepted=True, check_git=False)

    def test_accepted_reviewed_commit_must_be_a_real_ancestor(self) -> None:
        root, payload, _pending_commit = self._accepted_repo()
        data = _accepted_manifest(payload, "a" * 40)
        self._write_at(root, data)
        with self.assertRaisesRegex(guard.GuardFailure, "reviewed candidate commit invalid"):
            guard.validate(root, require_accepted=True, check_git=False)

    def test_accepted_reviewed_commit_must_carry_the_pending_manifest(self) -> None:
        root, payload, _pending_commit = self._accepted_repo()
        # HEAD's tree parent (the trust-unit commit) is a valid ancestor but
        # never committed a manifest.
        trust_commit = self._git(root, "rev-list", "--max-parents=0", "HEAD")
        data = _accepted_manifest(payload, trust_commit)
        self._write_at(root, data)
        with self.assertRaisesRegex(guard.GuardFailure, "commit cannot provide"):
            guard.validate(root, require_accepted=True, check_git=False)

    def test_accepted_still_forbidding_runtime_is_rejected(self) -> None:
        # An accepted green gate whose not_accepted still forbids the runtime /
        # lib inventory seal is a contradiction (acceptance ⟹ runtime built).
        root, payload, pending_commit = self._accepted_repo()
        data = _accepted_manifest(payload, pending_commit)
        data["not_accepted"] = list(guard.PENDING_NOT_ACCEPTED)
        self._write_at(root, data)
        with self.assertRaisesRegex(guard.GuardFailure, "accepted not-accepted boundary drifted"):
            guard.validate(root, require_accepted=True, check_git=False)

    def test_accepted_null_inventory_seal_is_rejected(self) -> None:
        # Acceptance MUST seal a concrete lib inventory; null is a contradiction.
        root, payload, pending_commit = self._accepted_repo()
        data = _accepted_manifest(payload, pending_commit)
        data["mechanical_binding"]["green_lib_inventory_sha256"] = None
        self._write_at(root, data)
        with self.assertRaisesRegex(guard.GuardFailure, "accepted green lib inventory seal invalid"):
            guard.validate(root, require_accepted=True, check_git=False)

    def _make_lib(self, root: Path) -> Path:
        lib = root / guard.red.LIB_ROOT
        lib.mkdir(parents=True, exist_ok=True)
        (lib / "real.dart").write_text("void main() {}\n")
        return lib

    def test_accepted_inventory_mismatch_fails_replay(self) -> None:
        # The sealed inventory must equal the live lib/ tree digest. A mismatch
        # fails run_expected_green BEFORE the behavioral replay — a smuggled or
        # removed lib file cannot slip through on green tests alone.
        root, payload, pending_commit = self._accepted_repo()
        self._make_lib(root)
        data = _accepted_manifest(payload, pending_commit)
        data["mechanical_binding"]["green_lib_inventory_sha256"] = "a" * 64  # != real digest
        self._write_at(root, data)
        with self.assertRaisesRegex(guard.GuardFailure, "GREEN lib inventory drifted"):
            guard.run_expected_green(root)

    def test_accepted_inventory_rejects_symlink_in_lib(self) -> None:
        # A symlink is excluded from a naive digest but DEREFERENCED by the runner's
        # copytree — it must be rejected outright, else external bytes execute.
        root, payload, pending_commit = self._accepted_repo()
        lib = self._make_lib(root)
        (lib / "evil.dart").symlink_to(lib / "real.dart")
        self._write_at(root, _accepted_manifest(payload, pending_commit))
        with self.assertRaisesRegex(guard.GuardFailure, "symlink or special entry"):
            guard.run_expected_green(root)

    def test_accepted_inventory_rejects_empty_dir_in_lib(self) -> None:
        # An extra empty dir is not covered by a file-only digest but is copied by
        # copytree — the topology must be sealed, so it is rejected.
        root, payload, pending_commit = self._accepted_repo()
        lib = self._make_lib(root)
        (lib / "empty_subdir").mkdir()
        self._write_at(root, _accepted_manifest(payload, pending_commit))
        with self.assertRaisesRegex(guard.GuardFailure, "empty directory"):
            guard.run_expected_green(root)

    def test_accepted_inventory_rejects_missing_lib(self) -> None:
        # Empty / missing lib/ is structurally rejected (cannot seal nothing).
        root, payload, pending_commit = self._accepted_repo()
        self._write_at(root, _accepted_manifest(payload, pending_commit))
        with self.assertRaisesRegex(guard.GuardFailure, "not a regular directory"):
            guard.run_expected_green(root)

    def test_accepted_unsealed_runner_input_is_rejected(self) -> None:
        # A matching lib seal is not enough: every OTHER input the runner copies
        # (pubspec, lockfile, l10n, assets, ...) must be sealed too. Here the temp
        # repo carries none of them, so the runner-input seal rejects before replay.
        root, payload, pending_commit = self._accepted_repo()
        self._make_lib(root)
        seal = guard._live_lib_inventory_sha256(root)
        data = _accepted_manifest(payload, pending_commit)
        data["mechanical_binding"]["green_lib_inventory_sha256"] = seal
        self._write_at(root, data)
        with self.assertRaisesRegex(guard.GuardFailure, "runner input is not a regular file"):
            guard.run_expected_green(root)

    def test_accepted_replay_rejects_tampered_pending_history(self) -> None:
        """A pending commit whose descriptor differs cannot back an acceptance."""
        root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, root, ignore_errors=True)
        self._git(root, "init", "-q")
        self._git(root, "config", "user.email", "test@mint.invalid")
        self._git(root, "config", "user.name", "MINT Test")
        for relative in TRUST_FILES:
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        self._commit(root, "green gate trust unit")
        # A pending manifest whose not_accepted was narrowed. not_accepted is not
        # in the descriptor, so the payload is unchanged — but the accepted replay
        # re-runs _pending on the historical commit and rejects the narrowed scope.
        tampered = _pending_manifest("0" * 64)
        tampered["not_accepted"] = list(guard.PENDING_NOT_ACCEPTED)[:-1]
        self._write_at(root, tampered)
        tampered_payload = guard._payload(root)
        tampered["mechanical_binding"]["candidate_payload_sha256"] = tampered_payload
        self._write_at(root, tampered)
        pending_commit = self._commit(root, "tampered pending")
        # The worktree acceptance uses the canonical scope + its true payload.
        self._write_at(root, _pending_manifest("0" * 64))
        canonical_payload = guard._payload(root)
        self._write_at(root, _accepted_manifest(canonical_payload, pending_commit))
        with self.assertRaisesRegex(guard.GuardFailure, "not-accepted boundary drifted"):
            guard.validate(root, require_accepted=True, check_git=False)

    # --- isolation ---------------------------------------------------------
    # NOTE: no test validates the LIVE on-disk manifest — that would couple this
    # suite to the manifest's lifecycle and break its state-agnosticism. The
    # pending ``--contract`` exit-0 is verified out of band, not here.
    def test_non_isolated_cli_returns_explicit_usage_error(self) -> None:
        result = subprocess.run(
            ["python3", str(ROOT / guard.GUARD)], cwd=ROOT,
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("USAGE: run this proof as python3 -I", result.stderr)


if __name__ == "__main__":
    unittest.main()
