#!/usr/bin/env python3
"""Guard the one-time reviewed path-owner Journey dispatcher amendment."""

from __future__ import annotations

import ast
import hashlib
import re
import subprocess
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.checks import mint_next_batch18_runtime_scope_guard as scope_guard

ACCEPTANCE = Path("product/mint_next/batch18/dispatcher-decoupling-acceptance.yaml")
SCOPE_ACCEPTANCE = Path("product/mint_next/batch18/scope-acceptance.yaml")
JOURNEY = Path("tools/checks/journey_os_check.py")
GUARD = Path("tools/checks/mint_next_batch18_dispatcher_decoupling_guard.py")
TESTS = Path("tools/checks/tests/test_mint_next_batch18_dispatcher_decoupling_guard.py")
WORKFLOW = Path(".github/workflows/mint-next-batch18-dispatcher-decoupling.yml")
OLD_WORKFLOW = Path(".github/workflows/mint-next-batch18-canton-runtime-scope.yml")
SPEC = Path(".planning/phases/mint-next-vertical01-3a-20260802/SPEC.md")
ANCHOR = "64a2d41a0e74fbb8ced93bf140484062e6ea98d7"
HISTORICAL_SCOPE_PAYLOAD = "3dc113073d6ba780915b8cd9a5285b02be80122eb377b3a81c8761fe569b2272"
HISTORICAL_SCOPE_CANDIDATE = "83cc9e051945365cf30d08cb3fb0f0970a34ada2"
EXPECTED_OWNER_REGISTRY_AST_SHA256 = "175a6b96bcdecd9dbac9ed02a39a072ca7dc9e3322815ddb9754871d2e7bcb68"

OWNED_MIGRATION_ENTRIES = [
    "product/mint_next/batch18/dispatcher-decoupling-acceptance.yaml",
    "tools/checks/mint_next_batch18_dispatcher_decoupling_guard.py",
    "tools/checks/tests/test_mint_next_batch18_dispatcher_decoupling_guard.py",
    ".github/workflows/mint-next-batch18-dispatcher-decoupling.yml",
]
ALLOWED_DIFF_PATHS = set(OWNED_MIGRATION_ENTRIES[:4]) | {
    str(JOURNEY),
    str(scope_guard.GUARD),
    str(scope_guard.TESTS),
    str(OLD_WORKFLOW),
    str(SPEC),
}
ROLES = {
    "dispatcher_integrity",
    "adversarial_future_batch_append",
    "historical_receipt_preservation",
}
NOT_ACCEPTED = [
    "any_runtime_microstep",
    "hidden_runtime",
    "product_route",
    "user_validation",
    "calculation",
    "persistence",
    "unreviewed_or_literal_Journey_OS_path_widening",
    "arbitrary_executable_Journey_OS_change",
]


class GuardFailure(RuntimeError):
    pass


class UniqueLoader(yaml.SafeLoader):
    pass


class UniqueStringLoader(yaml.BaseLoader):
    pass


def _unique_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise GuardFailure(f"duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


for loader in (UniqueLoader, UniqueStringLoader):
    loader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _unique_mapping)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GuardFailure(message)


def _load(path: Path) -> dict:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueLoader)


def _load_structure(path: Path) -> dict:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueStringLoader)


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _literal_allow_entries(source: str) -> list[str]:
    try:
        tree = ast.parse(source)
    except SyntaxError as exc:
        raise GuardFailure("Journey OS is not parseable") from exc
    assignments = [
        node
        for node in tree.body
        if isinstance(node, ast.Assign)
        and any(isinstance(target, ast.Name) and target.id == "ALLOW" for target in node.targets)
    ]
    _require(len(assignments) == 1 and isinstance(assignments[0].value, ast.Set), "Journey OS ALLOW assignment drifted")
    return [
        element.value
        for element in assignments[0].value.elts
        if isinstance(element, ast.Constant) and isinstance(element.value, str)
    ]


def _normalized_workflow(path: Path) -> bytes:
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    text, hashes = re.subn(
        r"(?m)^(  EXPECTED_DISPATCHER_[A-Z]+_SHA256:) [0-9a-f]{64}$",
        r"\1 <HASH>",
        text,
    )
    _require(hashes == 3, "dispatcher workflow hash shape drifted")
    text, commands = re.subn(
        r"(?m)^(\s*run: python3 tools/checks/mint_next_batch18_dispatcher_decoupling_guard.py)(?: --contract| --release)?$",
        r"\1 <LIFECYCLE>",
        text,
    )
    _require(commands == 1, "dispatcher workflow command shape drifted")
    return text.encode("utf-8")


def _normalized_spec(path: Path) -> bytes:
    text = path.read_text(encoding="utf-8")
    verify = re.search(r"```verify\n(.*?)\n```", text, re.S)
    _require(verify is not None, "SPEC verify block missing")
    lines = [
        re.sub(
            r"(mint_next_batch18_dispatcher_decoupling_guard.py)(?: --contract| --release)?$",
            r"\1 <LIFECYCLE>",
            line,
        )
        for line in verify.group(1).splitlines()
        if line.startswith("batch18-dispatcher-decoupling")
    ]
    _require(len(lines) == 2, "SPEC dispatcher lines drifted")
    return ("\n".join(sorted(lines)) + "\n").encode("utf-8")


def review_payload(root: Path) -> str:
    journey_source = (root / JOURNEY).read_text(encoding="utf-8")
    parts = {
        str(scope_guard.GUARD): (root / scope_guard.GUARD).read_bytes(),
        str(scope_guard.TESTS): (root / scope_guard.TESTS).read_bytes(),
        str(OLD_WORKFLOW): (root / OLD_WORKFLOW).read_bytes(),
        "JOURNEY_EXECUTABLE_OWNER_REGISTRY_AST": scope_guard._normalized_python_ast_bytes(journey_source),
        "OWNED_MIGRATION_ENTRIES": ("\n".join(OWNED_MIGRATION_ENTRIES) + "\n").encode(),
        str(GUARD): (root / GUARD).read_bytes(),
        str(TESTS): (root / TESTS).read_bytes(),
        str(WORKFLOW): _normalized_workflow(root / WORKFLOW),
        "SPEC_DISPATCHER_VERIFY": _normalized_spec(root / SPEC),
        "HISTORICAL_SCOPE_PAYLOAD": HISTORICAL_SCOPE_PAYLOAD.encode(),
    }
    digest = hashlib.sha256()
    for name, payload in parts.items():
        digest.update(name.encode() + b"\0" + payload + b"\0")
    return digest.hexdigest()


def _review_payload_at_commit(root: Path, commit: str) -> str:
    def show(path: Path) -> bytes:
        try:
            return subprocess.run(
                ["git", "show", f"{commit}:{path}"],
                cwd=root,
                check=True,
                capture_output=True,
            ).stdout
        except subprocess.CalledProcessError as exc:
            raise GuardFailure(f"reviewed migration candidate lacks {path}") from exc

    with _MaterializedPayload(root, show) as materialized:
        return review_payload(materialized)


class _MaterializedPayload:
    """Small temporary repo-shaped view for historical payload replay."""

    def __init__(self, root: Path, show):
        import tempfile

        self._temp = tempfile.TemporaryDirectory()
        self.root = Path(self._temp.name)
        for relative in (
            scope_guard.GUARD,
            scope_guard.TESTS,
            OLD_WORKFLOW,
            JOURNEY,
            GUARD,
            TESTS,
            WORKFLOW,
            SPEC,
        ):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(show(relative))

    def __enter__(self) -> Path:
        return self.root

    def __exit__(self, *_args) -> None:
        self._temp.cleanup()


def _validate_diff(root: Path, end: str = "HEAD", *, include_worktree: bool = True) -> None:
    commands = [["git", "diff", "--name-only", f"{ANCHOR}..{end}"]]
    if include_worktree:
        commands.extend(
            (["git", "diff", "--name-only", "HEAD"], ["git", "ls-files", "--others", "--exclude-standard"])
        )
    changed: set[str] = set()
    for command in commands:
        result = subprocess.run(command, cwd=root, check=True, capture_output=True, text=True)
        changed.update(result.stdout.splitlines())
    unexpected = changed - ALLOWED_DIFF_PATHS
    _require(not unexpected, f"dispatcher amendment changed forbidden paths: {sorted(unexpected)}")


def validate(
    root: Path = REPO_ROOT,
    *,
    check_git: bool = True,
    require_accepted: bool | None = None,
) -> None:
    required = (
        ACCEPTANCE,
        SCOPE_ACCEPTANCE,
        JOURNEY,
        GUARD,
        TESTS,
        WORKFLOW,
        OLD_WORKFLOW,
        SPEC,
        scope_guard.GUARD,
        scope_guard.TESTS,
    )
    for relative in required:
        path = root / relative
        _require(path.is_file() and not path.is_symlink(), f"missing regular artifact: {relative}")

    historical = _load(root / SCOPE_ACCEPTANCE)
    old_binding = historical["mechanical_binding"]
    _require(old_binding["reviewed_payload_sha256"] == HISTORICAL_SCOPE_PAYLOAD, "historical scope payload changed")
    _require(old_binding["reviewed_candidate_commit"] == HISTORICAL_SCOPE_CANDIDATE, "historical scope candidate changed")
    try:
        scope_guard.validate(root, check_parent_git=False, require_accepted=True)
    except scope_guard.GuardFailure as exc:
        raise GuardFailure(str(exc)) from exc

    journey_source = (root / JOURNEY).read_text(encoding="utf-8")
    literals = _literal_allow_entries(journey_source)
    for entry in OWNED_MIGRATION_ENTRIES:
        _require(literals.count(entry) == 1, f"owned migration Journey entry missing or duplicated: {entry}")
    executable_hash = hashlib.sha256(scope_guard._normalized_python_ast_bytes(journey_source)).hexdigest()
    _require(
        executable_hash == EXPECTED_OWNER_REGISTRY_AST_SHA256,
        "Journey executable owner-registry logic or literal ALLOW set changed",
    )

    acceptance = _load(root / ACCEPTANCE)
    _require(
        set(acceptance)
        == {
            "schema_version",
            "status",
            "current_verdict",
            "scope_effect",
            "reviews",
            "mechanical_binding",
            "accepted_change",
            "not_accepted",
            "next_gate",
        },
        "dispatcher acceptance schema drifted",
    )
    if require_accepted is None:
        require_accepted = acceptance["status"] == "accepted_dispatcher_decoupling"
    expected_status = (
        "accepted_dispatcher_decoupling"
        if require_accepted
        else "candidate_dispatcher_decoupling_unaccepted"
    )
    expected_verdict = "DISPATCHER_DECOUPLING_ACCEPTED" if require_accepted else "PENDING_INDEPENDENT_ROASTS"
    _require(acceptance["schema_version"] == 1, "dispatcher schema version drifted")
    _require(acceptance["status"] == expected_status and acceptance["current_verdict"] == expected_verdict, "dispatcher lifecycle drifted")
    _require(
        acceptance["scope_effect"]
        == {
            "historical_batch18_scope_receipt": "preserved",
            "reviewed_path_owner_receipts": "enabled",
            "executable_journey_logic": "immutable",
            "runtime_state": "not_evaluated",
        },
        "dispatcher scope effect drifted",
    )
    _require(set(acceptance["reviews"]) == ROLES, "dispatcher review roles drifted")
    pending = {"verdict": "PENDING", "p1": None, "p2": None, "p3": None}
    for review in acceptance["reviews"].values():
        if require_accepted:
            _require(
                set(review) == {"verdict", "p1", "p2", "p3", "reviewed_payload_sha256"}
                and review["verdict"] == "ACCEPT"
                and (review["p1"], review["p2"], review["p3"]) == (0, 0, 0),
                "dispatcher review is not exact zero-finding acceptance",
            )
        else:
            _require(review == pending, "dispatcher candidate review is not pending")
    binding = acceptance["mechanical_binding"]
    _require(
        set(binding)
        == {
            "candidate_review_payload_sha256",
            "reviewed_payload_sha256",
            "reviewed_candidate_commit",
        },
        "dispatcher binding schema drifted",
    )
    payload = review_payload(root)
    _require(binding["candidate_review_payload_sha256"] == payload, "dispatcher candidate payload drifted")
    if require_accepted:
        _require(binding["reviewed_payload_sha256"] == payload, "dispatcher reviewed payload drifted")
        candidate = binding["reviewed_candidate_commit"]
        _require(re.fullmatch(r"[0-9a-f]{40}", candidate or "") is not None, "dispatcher reviewed candidate malformed")
        for review in acceptance["reviews"].values():
            _require(review["reviewed_payload_sha256"] == payload, "dispatcher review payload mismatch")
        _require(acceptance["accepted_change"] == ["reviewed_path_owner_receipts_without_historical_scope_rebinding"], "dispatcher accepted change widened")
        _require(acceptance["next_gate"] == "create_and_review_batch19_r1_path_owner_receipt", "dispatcher accepted next gate drifted")
        if check_git:
            _require(subprocess.run(["git", "merge-base", "--is-ancestor", candidate, "HEAD"], cwd=root).returncode == 0, "dispatcher candidate is not ancestor")
            _require(_review_payload_at_commit(root, candidate) == payload, "dispatcher candidate payload does not replay")
            candidate_acceptance = yaml.load(
                subprocess.run(
                    ["git", "show", f"{candidate}:{ACCEPTANCE}"],
                    cwd=root,
                    check=True,
                    capture_output=True,
                    text=True,
                ).stdout,
                Loader=UniqueLoader,
            )
            _require(candidate_acceptance["status"] == "candidate_dispatcher_decoupling_unaccepted", "reviewed dispatcher anchor was not pending")
            _validate_diff(root, candidate, include_worktree=False)
    else:
        _require(binding["reviewed_payload_sha256"] is None and binding["reviewed_candidate_commit"] is None, "dispatcher candidate carries accepted receipt")
        _require(acceptance["accepted_change"] == [], "dispatcher candidate claims accepted change")
        _require(acceptance["next_gate"] == "independent_zero_finding_roasts", "dispatcher candidate next gate drifted")
    _require(acceptance["not_accepted"] == NOT_ACCEPTED, "dispatcher not-accepted boundary drifted")

    workflow = _load_structure(root / WORKFLOW)
    _require(set(workflow) == {"name", "on", "concurrency", "permissions", "env", "jobs"}, "dispatcher workflow top schema drifted")
    _require(workflow["name"] == "MINT Next Batch 18 Dispatcher Decoupling", "dispatcher workflow name drifted")
    _require(workflow["on"] == {"pull_request": {"branches": ["dev", "staging", "main"]}, "push": {"branches": ["dev", "staging", "main"]}}, "dispatcher workflow triggers drifted")
    _require(workflow["concurrency"] == {"group": "mint-next-batch18-dispatcher-decoupling-${{ github.ref }}", "cancel-in-progress": "true"}, "dispatcher workflow concurrency drifted")
    _require(workflow["permissions"] == {"contents": "read"}, "dispatcher workflow permissions drifted")
    _require(set(workflow["jobs"]) == {"contract"}, "dispatcher workflow jobs drifted")
    command = "python3 tools/checks/mint_next_batch18_dispatcher_decoupling_guard.py" + (" --release" if require_accepted else " --contract")
    expected_hashes = {
        "EXPECTED_DISPATCHER_GUARD_SHA256": _sha(root / GUARD) if require_accepted else "0" * 64,
        "EXPECTED_DISPATCHER_TESTS_SHA256": _sha(root / TESTS) if require_accepted else "0" * 64,
        "EXPECTED_DISPATCHER_ACCEPTANCE_SHA256": _sha(root / ACCEPTANCE) if require_accepted else "0" * 64,
    }
    _require(workflow["env"] == expected_hashes, "dispatcher workflow trust hashes drifted")
    job = workflow["jobs"]["contract"]
    _require(set(job) == {"name", "runs-on", "steps"}, "dispatcher workflow job schema drifted")
    _require(job["name"] == "Verify reviewed path-owner dispatcher amendment" and job["runs-on"] == "ubuntu-latest", "dispatcher workflow job identity drifted")
    expected_steps = [
        {"uses": "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683"},
        {"uses": "actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065b", "with": {"python-version": "3.11"}},
        {"name": "Install exact guard dependency", "run": "python3 -m pip install PyYAML==6.0.2"},
        {"name": "Verify dispatcher amendment candidate", "run": command},
        {"name": "Fire hostile dispatcher mutations", "run": "python3 -m unittest tools.checks.tests.test_mint_next_batch18_dispatcher_decoupling_guard"},
    ]
    _require(job["steps"] == expected_steps, "dispatcher workflow steps drifted")
    spec_lines = re.search(r"```verify\n(.*?)\n```", (root / SPEC).read_text(), re.S).group(1).splitlines()
    _require(spec_lines.count(f"batch18-dispatcher-decoupling: {command}") == 1, "dispatcher SPEC lifecycle command drifted")
    _require(spec_lines.count("batch18-dispatcher-decoupling-hostiles: python3 -m unittest tools.checks.tests.test_mint_next_batch18_dispatcher_decoupling_guard") == 1, "dispatcher SPEC hostile command drifted")
    if check_git and not require_accepted:
        _validate_diff(root)


def main() -> int:
    if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1] not in {"--contract", "--release"}):
        print("usage: mint_next_batch18_dispatcher_decoupling_guard.py [--contract|--release]", file=sys.stderr)
        return 2
    require = True if len(sys.argv) == 2 and sys.argv[1] == "--release" else None
    try:
        validate(require_accepted=require)
    except (GuardFailure, scope_guard.GuardFailure, KeyError, TypeError, yaml.YAMLError, subprocess.CalledProcessError) as exc:
        print(f"Batch18 dispatcher decoupling: FAIL — {exc}", file=sys.stderr)
        return 1
    print("Batch18 dispatcher decoupling: PASS (runtime remains unevaluated)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
