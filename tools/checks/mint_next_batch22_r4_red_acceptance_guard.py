#!/usr/bin/env python3
"""Accept the exact R4 (FERMETURE DE LA BOUCLE — scenarios_versement +
fact_etat_civil) expected-RED proof without accepting runtime."""

from __future__ import annotations

import sys

if __name__ == "__main__" and not sys.flags.isolated:
    raise SystemExit("USAGE: run this proof as python3 -I tools/checks/mint_next_batch22_r4_red_acceptance_guard.py")
sys.dont_write_bytecode = True

import argparse
import hashlib
import json
import os
import pwd
import re
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

if __name__ != "__main__":
    from tools.checks import journey_os_check
else:
    journey_os_check = None

ACCEPTANCE = Path("product/mint_next/batch22/r4-red-acceptance.json")
LEGACY_ACCEPTANCE = Path("product/mint_next/batch22/r4-red-acceptance.yaml")
GUARD = Path("tools/checks/mint_next_batch22_r4_red_acceptance_guard.py")
TESTS = Path("tools/checks/tests/test_mint_next_batch22_r4_red_acceptance_guard.py")
OWNER = Path(".planning/journeys/path-owners/batch22-r4-red-acceptance-json.json")
TRUST_OWNER = Path(".planning/journeys/path-owners/batch22-r4-red-acceptance.json")
RED_GUARD = Path("tools/checks/mint_next_batch22_r4_red_guard.py")
RED_TESTS = Path("tools/checks/tests/test_mint_next_batch22_r4_red_guard.py")
REGISTRY = Path("product/mint_next/batch22/runtime-gates.yaml")
R4_TEST = Path("product/mint_next/batch7/design_lab/test/design_lab_batch22_r4_test.dart")
RED_ARTIFACTS = (REGISTRY, R4_TEST, RED_GUARD, RED_TESTS)
RED_COMMIT = "d4a31c62c1af0f49a20b61608c136322963a88e6"
OWNER_PROMOTION_COMMIT = "5700522574a3f3d94b93b07c591f81a44647a118"
TRUST_OWNER_PROMOTION_COMMIT = "5700522574a3f3d94b93b07c591f81a44647a118"
ROLES = {"architecture_integrity", "mechanical_evidence", "ux_navigation_scope"}
ISOLATED_BOOTSTRAP = (
    "import runpy,site,sys;"
    "root,deps,module,*args=sys.argv[1:];"
    "sys.path[:0]=[root,deps];"
    "sys.argv=[module,*args];"
    "runpy.run_module(module,run_name='__main__')"
)
COMMANDS = {
    "hostile_unit": "python3 -ISB -c <isolated_bootstrap> {detached_root} {dependency_site} unittest tools.checks.tests.test_mint_next_batch22_r4_red_guard",
    "isolated_expected_red": "python3 -ISB -c <isolated_bootstrap> {detached_root} {dependency_site} tools.checks.mint_next_batch22_r4_red_guard",
    # ownership proof runs against the LIVE tree (path-owners live there, not at
    # the detached RED_COMMIT); delta-scope is preserved by --base-ref RED_COMMIT^.
    "journey_scope": "python3 -ISB -c <isolated_bootstrap> {live_root} {dependency_site} tools.checks.journey_os_check --base-ref RED_COMMIT^",
}
NOT_ACCEPTED = [
    "runtime_implemented", "runtime_accepted", "user_validated",
    "product_route", "runtime_global_or_later_gate", "production_ready",
]
TOP_KEYS = {
    "schema_version", "status", "current_verdict", "candidate",
    "proof_commands", "reviews", "mechanical_binding", "accepted_evidence",
    "not_accepted", "next_gate",
}


class GuardFailure(RuntimeError):
    pass


def _reject_duplicate_json_keys(pairs: list[tuple[str, object]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        if key in result:
            raise GuardFailure(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GuardFailure(message)


def _journey_os_module():
    global journey_os_check
    if journey_os_check is None:
        from tools.checks import journey_os_check as module
        journey_os_check = module
    return journey_os_check


def _load_bytes(raw: bytes) -> dict:
    data = json.loads(raw.decode("utf-8"), object_pairs_hook=_reject_duplicate_json_keys)
    _require(isinstance(data, dict), "acceptance JSON root must be an object")
    return data


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
        str(TRUST_OWNER): read(TRUST_OWNER),
    }
    for relative in RED_ARTIFACTS:
        parts[f"RED@{RED_COMMIT}:{relative}"] = _git_bytes(root, RED_COMMIT, relative)
    digest = hashlib.sha256()
    for name, raw in sorted(parts.items()):
        digest.update(name.encode("utf-8") + b"\0" + raw + b"\0")
    return digest.hexdigest()


def _core(data: dict) -> None:
    _require(set(data) == TOP_KEYS and data.get("schema_version") == 2, "acceptance schema drifted")
    _require(data.get("candidate") == {
        "red_commit": RED_COMMIT,
        "gate": "R4",
        "lifecycle": "expected_red",
        "runtime_implemented": False,
        "runtime_accepted": False,
        "product_surface": "hidden_design_lab_only",
        "expected_summary": {"passed": 2, "failed": 14, "load_or_harness_errors": 0},
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
    _require(data.get("accepted_evidence") == ["expected_failing_R4_contract_only"], "accepted evidence widened")
    _require(data.get("next_gate") == "create_and_review_R4_runtime_path_owner_receipt", "accepted next gate drifted")


def _commit_path_changes(root: Path, start: str, end: str) -> list[tuple[str, set[str]]]:
    try:
        commits = subprocess.run(
            ["git", "rev-list", "--reverse", "--topo-order", f"{start}..{end}"],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.splitlines()
        changes: list[tuple[str, set[str]]] = []
        for commit in commits:
            paths = set(subprocess.run(
                [
                    "git", "diff-tree", "--root", "-m", "--no-commit-id",
                    "--name-only", "-r", "--no-renames", commit,
                ],
                cwd=root, check=True, capture_output=True, text=True,
            ).stdout.splitlines())
            changes.append((commit, paths))
        return changes
    except subprocess.CalledProcessError as exc:
        raise GuardFailure(f"cannot inspect commit-by-commit path history: {start}..{end}") from exc


def _require_clean_worktree(root: Path) -> None:
    try:
        dirty = subprocess.run(
            ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
            cwd=root, check=True, capture_output=True,
        ).stdout
        index_tags = subprocess.run(
            ["git", "ls-files", "-v", "-z"],
            cwd=root, check=True, capture_output=True,
        ).stdout.decode("utf-8").split("\0")
        ignored = subprocess.run(
            [
                "git", "ls-files", "--others", "--ignored",
                "--exclude-standard", "-z", "--",
                "product/mint_next", ".planning/journeys/path-owners",
                "tools", ":(top,glob)*.py", ":(top,glob)*/*.py",
            ],
            cwd=root, check=True, capture_output=True,
        ).stdout.decode("utf-8").split("\0")
    except subprocess.CalledProcessError as exc:
        raise GuardFailure("cannot inspect worktree state") from exc
    _require(not dirty, "acceptance proof requires a clean worktree and index")
    hidden_index = sorted(
        entry[2:] for entry in index_tags
        if len(entry) > 2 and (entry[0].islower() or entry[0] == "S")
    )
    _require(not hidden_index, f"acceptance proof rejects hidden index flags: {hidden_index}")
    hidden_ignored = sorted(path for path in ignored if path)
    _require(not hidden_ignored, f"acceptance proof rejects ignored protected files: {hidden_ignored}")


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
    journey = _journey_os_module()
    owners = root / journey.PATH_OWNERS
    for manifest in sorted(owners.glob("*.json")):
        try:
            data = json.loads(
                manifest.read_text(encoding="utf-8"),
                object_pairs_hook=journey._reject_duplicate_json_keys,
            )
        except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
            raise GuardFailure(f"cannot inspect accepted path-owner chronology: {manifest}") from exc
        relative = manifest.relative_to(root).as_posix()
        for path in data.get("paths", []) if isinstance(data, dict) else []:
            if path in owned_paths:
                _require(path not in manifests_by_path, f"owned path chronology is ambiguous: {path}")
                manifests_by_path[path] = relative

    trust_paths = {str(ACCEPTANCE), str(LEGACY_ACCEPTANCE), str(GUARD), str(TESTS)}
    for commit, paths in _commit_path_changes(root, RED_COMMIT, candidate_end):
        unexpected = {
            path for path in paths
            if not path.startswith(".planning/journeys/path-owners/")
            and path not in trust_paths
        }
        _require(not unexpected, f"acceptance commit history widened: {commit}:{sorted(unexpected)}")

    promotion_by_manifest: dict[str, str] = {}
    for commit, paths in _commit_path_changes(root, candidate_end, "HEAD"):
        for path in sorted(paths):
            if path.startswith(".planning/journeys/path-owners/"):
                continue
            manifest = manifests_by_path.get(path)
            _require(manifest is not None, f"post-acceptance commit path is not reviewed-owned: {commit}:{path}")
            promotion = promotion_by_manifest.get(manifest)
            if promotion is None:
                try:
                    promotion = subprocess.run(
                        ["git", "log", "-1", "--format=%H", "HEAD", "--", manifest],
                        cwd=root, check=True, capture_output=True, text=True,
                    ).stdout.strip()
                except subprocess.CalledProcessError as exc:
                    raise GuardFailure(f"cannot inspect owner chronology for: {path}") from exc
                _require(re.fullmatch(r"[0-9a-f]{40}", promotion) is not None, f"owner promotion commit missing for: {path}")
                promotion_by_manifest[manifest] = promotion
            strictly_after = promotion != commit and subprocess.run(
                ["git", "merge-base", "--is-ancestor", promotion, commit],
                cwd=root, capture_output=True,
            ).returncode == 0
            _require(strictly_after, f"target commit predates owner promotion: {path}@{commit}")

    # The net tail remains an independent completeness check. It must not name
    # a target that vanished from the per-commit walk because of Git plumbing.
    for path in sorted({
        path for path in tail
        if not path.startswith(".planning/journeys/path-owners/")
    }):
        _require(path in manifests_by_path, f"owned path has no accepted receipt: {path}")


def _git_boundary(root: Path) -> None:
    trust_paths = {str(ACCEPTANCE), str(LEGACY_ACCEPTANCE), str(GUARD), str(TESTS)}
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
    owned_paths, owner_errors = _journey_os_module()._load_path_owners(root)
    _require(not owner_errors, f"future path-owner registry invalid: {owner_errors}")
    unexpected_tail = {
        path for path in tail
        if not path.startswith(".planning/journeys/path-owners/")
        and path not in owned_paths
    }
    _require(not unexpected_tail, f"post-acceptance path is not reviewed-owned: {sorted(unexpected_tail)}")
    _require_owned_tail_chronology(root, candidate_end, owned_paths, tail)


def validate(root: Path = REPO_ROOT, *, require_accepted: bool | None = None, check_git: bool = True) -> None:
    for relative in (ACCEPTANCE, GUARD, TESTS, OWNER, TRUST_OWNER, *RED_ARTIFACTS):
        path = root / relative
        _require(path.is_file() and not path.is_symlink(), f"artifact is not regular: {relative}")
    _require(_ancestor(root, RED_COMMIT), "RED commit is not an ancestor")
    _require(_ancestor(root, OWNER_PROMOTION_COMMIT), "acceptance owner is not promoted")
    _require(_ancestor(root, TRUST_OWNER_PROMOTION_COMMIT), "acceptance trust owner is not promoted")
    _require(not (root / LEGACY_ACCEPTANCE).exists(), "legacy YAML acceptance path still exists")
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
        _require_clean_worktree(root)
        _git_boundary(root)


def run_proofs(root: Path = REPO_ROOT) -> None:
    trusted_home = pwd.getpwuid(os.getuid()).pw_dir
    dependency_site = subprocess.run(
        ["python3", "-ISB", "-c", "import site;print(site.getusersitepackages())"],
        check=True, capture_output=True, text=True,
        env={**os.environ, "HOME": trusted_home},
    ).stdout.strip()
    _require(Path(dependency_site).is_dir(), "trusted dependency site is unavailable")
    # journey_os_check defaults to `origin/dev...HEAD`. Each gate proves only its
    # own delta (supersession doctrine), so the base is pinned to RED_COMMIT's
    # parent (ANCHOR): the diff is exactly this batch's delta since ANCHOR, not
    # the accumulated branch state.
    journey_base = subprocess.run(
        ["git", "rev-parse", f"{RED_COMMIT}^"],
        cwd=root, check=True, capture_output=True, text=True,
    ).stdout.strip()
    with tempfile.TemporaryDirectory(prefix="mint-b22-r4-red-replay-") as directory:
        replay = Path(directory) / "candidate"
        added = subprocess.run(
            ["git", "worktree", "add", "--detach", str(replay), RED_COMMIT],
            cwd=root, capture_output=True, text=True,
        )
        _require(added.returncode == 0, "cannot create detached RED replay")
        try:
            # The two RED proofs attest the RED artifacts and re-run the RED test
            # at the sealed RED_COMMIT snapshot; they do NOT depend on path-owners,
            # so they run in the detached RED_COMMIT replay.
            replay_prefix = [
                "python3", "-ISB", "-c", ISOLATED_BOOTSTRAP,
                str(replay), dependency_site,
            ]
            for command in (
                [*replay_prefix, "unittest", "tools.checks.tests.test_mint_next_batch22_r4_red_guard"],
                [*replay_prefix, "tools.checks.mint_next_batch22_r4_red_guard"],
            ):
                _require(subprocess.run(command, cwd=replay).returncode == 0, f"proof failed: {' '.join(command)}")
            # INVARIANT: the ownership proof evaluates ownership WHERE OWNERSHIP
            # LIVES — the current (live) tree at attestation time, NOT the detached
            # RED_COMMIT replay. The RED delta cannot own itself at its own commit:
            # path-owners are necessarily born AFTER RED_COMMIT (two-commit path —
            # review receipt, then work), so a detached replay at RED_COMMIT has no
            # owners and would wrongly reject the very RED delta it seals. Running
            # journey_os_check against the live root (with --base-ref RED_COMMIT^,
            # so the delta-scope is unchanged) resolves ownership from the accepted
            # path-owners that exist in the live tree at attestation time.
            live_prefix = [
                "python3", "-ISB", "-c", ISOLATED_BOOTSTRAP,
                str(root), dependency_site,
            ]
            journey = [*live_prefix, "tools.checks.journey_os_check", "--base-ref", journey_base]
            _require(subprocess.run(journey, cwd=root).returncode == 0, f"proof failed: {' '.join(journey)}")
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(replay)], cwd=root, capture_output=True)


def run_acceptance_hostile_suite(root: Path = REPO_ROOT) -> None:
    """Execute the sealed, state-agnostic hostile suite as part of the proof.

    Binding the hostile mutations into --proof/--release means release
    verification no longer depends on a mutable CI job running the same tests:
    the guard itself asserts both the pending and accepted lifecycles and their
    falsifications before it can print PASS.
    """
    completed = subprocess.run(
        [
            sys.executable, "-m", "unittest",
            "tools.checks.tests.test_mint_next_batch22_r4_red_acceptance_guard",
        ],
        cwd=root,
    )
    _require(completed.returncode == 0, "acceptance hostile suite failed")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--proof", action="store_true")
    args = parser.parse_args()
    try:
        validate(require_accepted=True if args.release else None)
        if args.proof or args.release:
            run_proofs()
            run_acceptance_hostile_suite()
    except (GuardFailure, OSError, UnicodeError, json.JSONDecodeError, subprocess.CalledProcessError) as exc:
        print(f"BATCH22 R4 RED ACCEPTANCE FAIL: {exc}", file=sys.stderr)
        return 1
    print("BATCH22 R4 RED ACCEPTANCE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
