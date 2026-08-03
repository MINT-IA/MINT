#!/usr/bin/env python3
"""Accept the exact R1 expected-RED proof without accepting runtime."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.checks import journey_os_check

ACCEPTANCE = Path("product/mint_next/batch19/r1-red-acceptance.yaml")
GUARD = Path("tools/checks/mint_next_batch19_r1_red_acceptance_guard.py")
TESTS = Path("tools/checks/tests/test_mint_next_batch19_r1_red_acceptance_guard.py")
OWNER = Path(".planning/journeys/path-owners/batch19-r1-red-acceptance.json")
RED_GUARD = Path("tools/checks/mint_next_batch19_r1_red_guard.py")
RED_TESTS = Path("tools/checks/tests/test_mint_next_batch19_r1_red_guard.py")
REGISTRY = Path("product/mint_next/batch18/runtime-gates.yaml")
R1_TEST = Path("product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r1_test.dart")
FIXTURE = Path("product/mint_next/batch7/design_lab/test/batch18_canton_fixture.g.dart")
RED_ARTIFACTS = (REGISTRY, R1_TEST, FIXTURE, RED_GUARD, RED_TESTS)
RED_COMMIT = "387d74a150b49eb38c436d61068e68d596ab89f9"
OWNER_PROMOTION_COMMIT = "91d0652b01b2c9663925af34048a215372e87793"
ROLES = {"architecture_integrity", "mechanical_evidence", "ux_navigation_scope"}
COMMANDS = {
    "hostile_unit": "python3 -m unittest tools.checks.tests.test_mint_next_batch19_r1_red_guard",
    "isolated_expected_red": "python3 tools/checks/mint_next_batch19_r1_red_guard.py",
    "journey_scope": "python3 tools/checks/journey_os_check.py",
}
NOT_ACCEPTED = [
    "runtime_implemented", "runtime_accepted", "user_validated",
    "product_route", "R2_or_later_gate", "production_ready",
]
TOP_KEYS = {
    "schema_version", "status", "current_verdict", "candidate",
    "proof_commands", "reviews", "mechanical_binding", "accepted_evidence",
    "not_accepted", "next_gate",
}


class GuardFailure(RuntimeError):
    pass


class UniqueLoader(yaml.SafeLoader):
    pass


def _unique_mapping(loader: yaml.Loader, node: yaml.MappingNode, deep: bool = False) -> dict:
    result: dict = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise GuardFailure(f"duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _unique_mapping)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GuardFailure(message)


def _load_bytes(raw: bytes) -> dict:
    return yaml.load(raw.decode("utf-8"), Loader=UniqueLoader)


def _load(root: Path, relative: Path) -> dict:
    return _load_bytes((root / relative).read_bytes())


def _git_bytes(root: Path, commit: str, relative: Path) -> bytes:
    try:
        return subprocess.run(
            ["git", "show", f"{commit}:{relative}"], cwd=root,
            check=True, capture_output=True,
        ).stdout
    except subprocess.CalledProcessError as exc:
        raise GuardFailure(f"commit cannot provide {relative}: {commit}") from exc


def _ancestor(root: Path, commit: str) -> bool:
    return subprocess.run(
        ["git", "merge-base", "--is-ancestor", commit, "HEAD"],
        cwd=root, capture_output=True,
    ).returncode == 0


def _descriptor(data: dict) -> dict:
    return {
        "schema_version": data.get("schema_version"),
        "candidate": data.get("candidate"),
        "proof_commands": data.get("proof_commands"),
        "not_accepted": data.get("not_accepted"),
    }


def _payload(root: Path, commit: str | None = None) -> str:
    def read(relative: Path) -> bytes:
        return _git_bytes(root, commit, relative) if commit else (root / relative).read_bytes()

    acceptance = _load_bytes(read(ACCEPTANCE))
    parts = {
        "ACCEPTANCE_DESCRIPTOR": json.dumps(
            _descriptor(acceptance), sort_keys=True, separators=(",", ":"),
            ensure_ascii=False,
        ).encode("utf-8"),
        str(GUARD): read(GUARD),
        str(TESTS): read(TESTS),
        str(OWNER): read(OWNER),
    }
    for relative in RED_ARTIFACTS:
        parts[f"RED@{RED_COMMIT}:{relative}"] = _git_bytes(root, RED_COMMIT, relative)
    digest = hashlib.sha256()
    for name, raw in sorted(parts.items()):
        digest.update(name.encode("utf-8") + b"\0" + raw + b"\0")
    return digest.hexdigest()


def _core(data: dict) -> None:
    _require(set(data) == TOP_KEYS and data.get("schema_version") == 1, "acceptance schema drifted")
    _require(data.get("candidate") == {
        "red_commit": RED_COMMIT,
        "gate": "R1",
        "lifecycle": "expected_red",
        "runtime_implemented": False,
        "runtime_accepted": False,
        "product_surface": "hidden_design_lab_only",
        "expected_summary": {"passed": 2, "failed": 13, "load_or_harness_errors": 0},
    }, "RED candidate identity or boundary drifted")
    _require(data.get("proof_commands") == COMMANDS, "proof command inventory drifted")
    _require(data.get("not_accepted") == NOT_ACCEPTED, "not-accepted boundary drifted")
    _require(set(data.get("reviews", {})) == ROLES, "review roles drifted")
    _require(set(data.get("mechanical_binding", {})) == {
        "candidate_review_payload_sha256", "reviewed_payload_sha256",
        "reviewed_candidate_commit",
    }, "mechanical binding schema drifted")


def _pending(data: dict, payload: str) -> None:
    review = {"verdict": "PENDING", "p1": None, "p2": None, "p3": None}
    _require(data.get("status") == "candidate_red_acceptance_unaccepted" and data.get("current_verdict") == "PENDING_INDEPENDENT_ROASTS", "pending lifecycle drifted")
    _require(all(value == review for value in data["reviews"].values()), "pending receipt claims reviews")
    binding = data["mechanical_binding"]
    _require(binding.get("candidate_review_payload_sha256") == payload, "candidate payload drifted")
    _require(binding.get("reviewed_payload_sha256") is None and binding.get("reviewed_candidate_commit") is None, "pending receipt claims reviewed binding")
    _require(data.get("accepted_evidence") == [], "pending receipt claims accepted evidence")
    _require(data.get("next_gate") == "independent_roasts_of_exact_pending_acceptance_commit", "pending next gate drifted")


def _accepted(root: Path, data: dict, payload: str) -> None:
    _require(data.get("status") == "accepted_expected_red_evidence_runtime_not_implemented" and data.get("current_verdict") == "RED_CONTRACT_ACCEPTED_RUNTIME_NOT_IMPLEMENTED", "accepted lifecycle drifted")
    binding = data["mechanical_binding"]
    commit = binding.get("reviewed_candidate_commit")
    _require(isinstance(commit, str) and re.fullmatch(r"[0-9a-f]{40}", commit) is not None and _ancestor(root, commit), "reviewed candidate commit invalid")
    _require(binding.get("candidate_review_payload_sha256") == payload and binding.get("reviewed_payload_sha256") == payload, "accepted payload drifted")
    exact = {"verdict": "ACCEPT", "p1": 0, "p2": 0, "p3": 0, "reviewed_payload_sha256": payload}
    _require(all(value == exact for value in data["reviews"].values()), "accepted reviews are not exact")
    previous = _load_bytes(_git_bytes(root, commit, ACCEPTANCE))
    _core(previous)
    _pending(previous, payload)
    _require(_payload(root, commit) == payload, "reviewed pending trust unit cannot replay")
    _require(data.get("accepted_evidence") == ["expected_failing_R1_contract_only"], "accepted evidence widened")
    _require(data.get("next_gate") == "create_and_review_R1_runtime_path_owner_receipt", "accepted next gate drifted")


def _require_owned_tail_chronology(
    root: Path,
    candidate_end: str,
    owned_paths: set[str],
    tail: list[str],
) -> None:
    """Prove authorization existed before every owned target change.

    The latest commit touching an accepted owner receipt is deliberately used
    as the conservative promotion boundary. A later receipt rewrite therefore
    cannot retroactively bless older target work.
    """
    manifests_by_path: dict[str, str] = {}
    owners = root / journey_os_check.PATH_OWNERS
    for manifest in sorted(owners.glob("*.json")):
        try:
            data = json.loads(
                manifest.read_text(encoding="utf-8"),
                object_pairs_hook=journey_os_check._reject_duplicate_json_keys,
            )
        except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
            raise GuardFailure(f"cannot inspect accepted path-owner chronology: {manifest}") from exc
        relative = manifest.relative_to(root).as_posix()
        for path in data.get("paths", []) if isinstance(data, dict) else []:
            if path in owned_paths:
                _require(path not in manifests_by_path, f"owned path chronology is ambiguous: {path}")
                manifests_by_path[path] = relative

    targets = {
        path for path in tail
        if not path.startswith(".planning/journeys/path-owners/")
    }
    for path in sorted(targets):
        manifest = manifests_by_path.get(path)
        _require(manifest is not None, f"owned path has no accepted receipt: {path}")
        try:
            promotion = subprocess.run(
                ["git", "log", "-1", "--format=%H", "HEAD", "--", manifest],
                cwd=root, check=True, capture_output=True, text=True,
            ).stdout.strip()
            target_commits = subprocess.run(
                ["git", "log", "--reverse", "--format=%H", f"{candidate_end}..HEAD", "--", path],
                cwd=root, check=True, capture_output=True, text=True,
            ).stdout.splitlines()
        except subprocess.CalledProcessError as exc:
            raise GuardFailure(f"cannot inspect owner chronology for: {path}") from exc
        _require(re.fullmatch(r"[0-9a-f]{40}", promotion) is not None, f"owner promotion commit missing for: {path}")
        _require(target_commits, f"tail path has no replayable commits: {path}")
        for target_commit in target_commits:
            strictly_after = promotion != target_commit and subprocess.run(
                ["git", "merge-base", "--is-ancestor", promotion, target_commit],
                cwd=root, capture_output=True,
            ).returncode == 0
            _require(strictly_after, f"target commit predates owner promotion: {path}@{target_commit}")


def _git_boundary(root: Path) -> None:
    trust_paths = {str(ACCEPTANCE), str(GUARD), str(TESTS)}
    try:
        candidate_end = subprocess.run(
            ["git", "log", "-1", "--format=%H", "HEAD", "--", *sorted(trust_paths)],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.strip()
        _require(re.fullmatch(r"[0-9a-f]{40}", candidate_end) is not None, "cannot locate acceptance candidate commit")
        changed = subprocess.run(
            ["git", "diff", "--name-only", f"{RED_COMMIT}..{candidate_end}"],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.splitlines()
        tail = subprocess.run(
            ["git", "diff", "--name-only", f"{candidate_end}..HEAD"],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.splitlines()
    except subprocess.CalledProcessError as exc:
        raise GuardFailure("cannot inspect acceptance candidate boundary") from exc
    product_changes = {
        path for path in changed
        if not path.startswith(".planning/journeys/path-owners/")
    }
    _require(product_changes <= trust_paths, f"acceptance scope widened: {sorted(product_changes - trust_paths)}")
    owned_paths, owner_errors = journey_os_check._load_path_owners(root)
    _require(not owner_errors, f"future path-owner registry invalid: {owner_errors}")
    unexpected_tail = {
        path for path in tail
        if not path.startswith(".planning/journeys/path-owners/")
        and path not in owned_paths
    }
    _require(not unexpected_tail, f"post-acceptance path is not reviewed-owned: {sorted(unexpected_tail)}")
    _require_owned_tail_chronology(root, candidate_end, owned_paths, tail)


def validate(root: Path = REPO_ROOT, *, require_accepted: bool | None = None, check_git: bool = True) -> None:
    for relative in (ACCEPTANCE, GUARD, TESTS, OWNER, *RED_ARTIFACTS):
        path = root / relative
        _require(path.is_file() and not path.is_symlink(), f"artifact is not regular: {relative}")
    _require(_ancestor(root, RED_COMMIT), "RED commit is not an ancestor")
    _require(_ancestor(root, OWNER_PROMOTION_COMMIT), "acceptance owner is not promoted")
    for relative in RED_ARTIFACTS:
        _require((root / relative).read_bytes() == _git_bytes(root, RED_COMMIT, relative), f"RED artifact drifted: {relative}")
    data = _load(root, ACCEPTANCE)
    _core(data)
    payload = _payload(root)
    if data.get("status") == "candidate_red_acceptance_unaccepted":
        _pending(data, payload)
        _require(require_accepted is not True, "RED acceptance is still pending")
    elif data.get("status") == "accepted_expected_red_evidence_runtime_not_implemented":
        _accepted(root, data, payload)
        _require(require_accepted is not False, "expected pending receipt")
    else:
        raise GuardFailure("acceptance lifecycle status drifted")
    if check_git:
        _git_boundary(root)


def run_proofs(root: Path = REPO_ROOT) -> None:
    with tempfile.TemporaryDirectory(prefix="mint-b19-red-replay-") as directory:
        replay = Path(directory) / "candidate"
        added = subprocess.run(
            ["git", "worktree", "add", "--detach", str(replay), RED_COMMIT],
            cwd=root, capture_output=True, text=True,
        )
        _require(added.returncode == 0, "cannot create detached RED replay")
        try:
            for command in (
                ["python3", "-m", "unittest", "tools.checks.tests.test_mint_next_batch19_r1_red_guard"],
                ["python3", str(RED_GUARD)],
                ["python3", "tools/checks/journey_os_check.py"],
            ):
                _require(subprocess.run(command, cwd=replay).returncode == 0, f"proof failed: {' '.join(command)}")
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(replay)], cwd=root, capture_output=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--proof", action="store_true")
    args = parser.parse_args()
    try:
        validate(require_accepted=True if args.release else None)
        if args.proof or args.release:
            run_proofs()
    except (GuardFailure, OSError, UnicodeError, yaml.YAMLError, subprocess.CalledProcessError) as exc:
        print(f"BATCH19 R1 RED ACCEPTANCE FAIL: {exc}", file=sys.stderr)
        return 1
    print("BATCH19 R1 RED ACCEPTANCE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
