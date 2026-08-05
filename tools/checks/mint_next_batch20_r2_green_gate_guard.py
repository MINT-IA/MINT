#!/usr/bin/env python3
"""Seal the Batch20 R2 GREEN-GATE governance transition (pending, pre-impl).

This guard governs the transition that RETIRES the accepted 2/13 expected-RED
replay of the fused fact_lieu (COMMUNE DIRECTE) contract and installs, in its
place, the 15/15 GREEN replay as the active R2 gate. It is a PENDING,
pre-implementation artifact: while pending the R2 runtime path-owner
(batch20-r2-runtime: fact_lieu.dart + fact_lieu_catalog.g.dart) is not yet
accepted, so the GREEN replay is DEFERRED (``run_expected_green``) and never runs
while the manifest is pending; ``--contract`` validates STRUCTURE ONLY and is what
CI runs meanwhile.

The design mirrors tools/checks/mint_next_batch19_r1_green_gate_guard.py: a
payload-bound pending/accepted lifecycle, isolated (-I) execution, duplicate-key
rejection. It reuses the sealed RED replay machinery from
mint_next_batch20_r2_red_guard.
"""

from __future__ import annotations

import sys

if __name__ == "__main__" and not sys.flags.isolated:
    raise SystemExit(
        "USAGE: run this proof as python3 -I tools/checks/mint_next_batch20_r2_green_gate_guard.py"
    )
sys.dont_write_bytecode = True

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.checks import mint_next_batch20_r2_red_guard as red

MANIFEST = Path("product/mint_next/batch20/r2-green-gate.yaml")
GUARD = Path("tools/checks/mint_next_batch20_r2_green_gate_guard.py")
TESTS = Path("tools/checks/tests/test_mint_next_batch20_r2_green_gate_guard.py")
# The reviewed path-owner receipt that owns this transition's trust unit. Its
# bytes are bound into the payload so tampering it breaks the candidate binding.
PATH_OWNER = Path(".planning/journeys/path-owners/batch20-r2-green-gate.json")
RED_GUARD = Path("tools/checks/mint_next_batch20_r2_red_guard.py")
REGISTRY = red.REGISTRY  # product/mint_next/batch20/runtime-gates.yaml
# The command that ACTUALLY fires the fail-closed 15/15 replay (validate accepted
# + run_expected_green). Acceptance is attested by a dispatched run of this, not
# by any static check of the CI workflow file.
FULL_MODE_INVOCATION = "python3 -I tools/checks/mint_next_batch20_r2_green_gate_guard.py --release"

# Re-pinned immutables frozen by this transition. These MUST equal the current
# files: the RED contract and its registry cannot silently drift while the GREEN
# gate that supersedes their replay is under review.
RED_GUARD_SHA256 = "93d9d10000347e9885407b825254bbc737d6272def16860d843502f4b82d3bfe"
REGISTRY_SHA256 = "015fb0aaa0f6df449d6d30a0bee86c4e88d9076451d095a8c1bddbed8a78638e"

WORKING_DIRECTORY = "product/mint_next/batch7/design_lab"
# Same targeted, machine-readable command as the RED replay; only the expected
# outcome changes from 2/13 RED to 15/15 GREEN once the runtime is implemented.
GREEN_COMMAND = [
    "flutter", "test", "test/design_lab_batch20_commune_r2_test.dart",
    "--machine", "--no-pub",
]
GREEN_SUMMARY = {"passed": 16, "failed": 0, "load_or_harness_errors": 0}

# (c) CI enforcement. While PENDING only the structure gate runs (--contract).
# Acceptance is attested by EXECUTING the full green replay (run_expected_green
# via --release), fail-closed — NOT by any static presence check of a workflow
# file (a static check cannot prove execution: it is defeated by a comment,
# `echo`, `|| true`, or a disabled step). This mirrors the RED release
# attestation: the accepted SHA is proven by a dispatched --release run whose
# exit-0 requires the sealed spec to actually replay 15/15. Descriptor-immutable.
EXPECTED_CI_ENFORCEMENT = {
    "pending": "contract_only",
    "accepted_attested_by": "dispatched_full_green_replay_run_expected_green",
    "attestation_command": FULL_MODE_INVOCATION,
    "retires": "red_replay_2_14",
}

ROLES = {"scope_integrity", "mechanical_adversary", "journey_safety"}
PENDING_REVIEW = {"verdict": "PENDING", "p1": None, "p2": None, "p3": None}

TOP_KEYS = {
    "schema_version", "status", "current_verdict", "supersedes", "green_gate",
    "re_pinned_immutables", "runtime_regating", "runtime_surface",
    "product_promotion", "reviews", "mechanical_binding", "not_accepted",
    "next_gate",
}

# (a) The RED 2/13 replay is retired; upon promotion + implementation the active
# CI gate becomes the GREEN 15/15 replay of the exact same sealed spec.
EXPECTED_GREEN_GATE = {
    "retires": "red_replay_2_14",
    "active_gate_upon_promotion": "green_replay_16_16",
    "test_file": str(red.TEST),
    "test_sha256": red.EXPECTED_TEST_SHA256,
    "fixture_file": str(red.FIXTURE),
    "fixture_sha256": red.EXPECTED_FIXTURE_SHA256,
    "command": list(GREEN_COMMAND),
    "working_directory": WORKING_DIRECTORY,
    "expected_summary": dict(GREEN_SUMMARY),
    "expected_exit_code": 0,
    "obligation_test_names": sorted(red.EXPECTED_TEST_NAMES),
    # (c) the 15/15 replay is enforced by EXECUTION (run_expected_green via
    # --release), attested by dispatch — see EXPECTED_CI_ENFORCEMENT.
    "ci_enforcement": dict(EXPECTED_CI_ENFORCEMENT),
}

# (b) The two immutables this transition freezes.
EXPECTED_RE_PINNED = {
    "red_guard": {"path": str(RED_GUARD), "sha256": RED_GUARD_SHA256},
    "registry": {"path": str(REGISTRY), "sha256": REGISTRY_SHA256},
}

# (d) design_lab_app.dart is re-gated (fact_contribution.choose_no now reaches the
# fused fact_lieu node instead of the superseded standalone fact_canton). It is
# already covered by the Journey OS ALLOW list and the accepted batch19-r1-runtime
# owner; the NEW fused-node runtime files (fact_lieu.dart, fact_lieu_catalog.g.dart)
# are owned by batch20-r2-runtime. Its CONTENT seal (a lib-inventory sha pin, like
# Batch16 GREEN) CANNOT be pinned now because the runtime is unimplemented at
# pending; it is deferred to implementation.
EXPECTED_RUNTIME_REGATING = {
    "scope_owner": "batch20-r2-runtime",
    "regated_file": "product/mint_next/batch7/design_lab/lib/design_lab_app.dart",
    "lib_inventory_seal": "deferred_to_implementation_under_this_gate",
}

# The RED acceptance this GREEN gate supersedes (declarative provenance). The
# accepted commit is the final acceptance flip of the batch20 R2 RED contract and
# the dispatched release-attestation run that proved it.
EXPECTED_SUPERSEDES = {
    "red_acceptance_receipt": "product/mint_next/batch20/r2-red-acceptance.json",
    "accepted_payload_sha256": "a81c7cd13c56d19b67c79af0134af06f0373a99e763f1be733e45f125bf4f792",
    "accepted_commit": "062a12ac4650888d8adc2cc7a4e3f9533b6ad7b7",
    "attestation_run": "https://github.com/MINT-IA/MINT/actions/runs/30953934739",
}

# not_accepted is state-DEPENDENT (so it is NOT in the descriptor / payload — the
# replay requires an identical descriptor across pending and accepted). While
# PENDING nothing is built; at ACCEPTED the runtime IS implemented and its lib
# inventory IS sealed, so those two leave the boundary. Product route and
# production readiness remain forbidden in BOTH states (hidden runtime only).
PENDING_NOT_ACCEPTED = [
    "runtime_implemented",
    "lib_inventory_sealed",
    "product_route",
    "production_ready",
]
ACCEPTED_NOT_ACCEPTED = [
    "product_route",
    "production_ready",
]
EXPECTED_NEXT_GATE = "seal_R2_green_lib_inventory_then_R3"

PENDING_STATUS = "candidate_green_gate_unaccepted"
PENDING_VERDICT = "PENDING_INDEPENDENT_ROASTS"
# Acceptance ⟹ the R2 runtime IS implemented + lib-inventory sealed + the 15/15
# replay wired (see _accepted). It remains HIDDEN (design-lab only); product
# route and production readiness stay forbidden. The name reflects that.
ACCEPTED_STATUS = "accepted_green_gate_runtime_implemented_hidden_only"
ACCEPTED_VERDICT = "GREEN_GATE_ACCEPTED_RUNTIME_IMPLEMENTED_HIDDEN_ONLY"


class GuardFailure(RuntimeError):
    pass


class UniqueKeyLoader(yaml.SafeLoader):
    pass


def _unique_mapping(loader: yaml.Loader, node: yaml.MappingNode, deep: bool = False) -> dict:
    result: dict = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise GuardFailure(f"duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _unique_mapping
)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GuardFailure(message)


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


def _load_manifest_bytes(raw: bytes) -> dict:
    data = yaml.load(raw.decode("utf-8"), Loader=UniqueKeyLoader)
    _require(isinstance(data, dict), "green gate manifest root must be a mapping")
    return data


def _descriptor(data: dict) -> dict:
    """The immutable content the payload binds: (a)-(d), identical across states.

    ``not_accepted`` is deliberately EXCLUDED: it narrows at acceptance (runtime
    implemented + sealed) and so cannot live in a descriptor that the accepted
    replay requires to be byte-identical to the reviewed pending one. It is
    instead exact-pinned per lifecycle state in ``_pending`` / ``_accepted``.
    """
    return {
        "supersedes": data.get("supersedes"),
        "green_gate": data.get("green_gate"),
        "re_pinned_immutables": data.get("re_pinned_immutables"),
        "runtime_regating": data.get("runtime_regating"),
    }


def _payload(root: Path = REPO_ROOT, commit: str | None = None) -> str:
    """Hash the immutable descriptor plus the guard, guard-test and owner bytes.

    Binding the guard and its hostile suite means a silent weakening of either
    changes the payload and breaks the candidate binding. The reviewed path-owner
    receipt is bound too, so tampering the receipt that authorizes this trust unit
    also breaks the binding. The descriptor carries the re-pinned immutables, so
    the frozen RED guard and registry are bound transitively.
    """
    def read(relative: Path) -> bytes:
        return _git_bytes(root, commit, relative) if commit else (root / relative).read_bytes()

    manifest = _load_manifest_bytes(read(MANIFEST))
    parts = {
        "GREEN_GATE_DESCRIPTOR": json.dumps(
            _descriptor(manifest), sort_keys=True, separators=(",", ":"),
            ensure_ascii=False,
        ).encode("utf-8"),
        str(GUARD): read(GUARD),
        str(TESTS): read(TESTS),
        str(PATH_OWNER): read(PATH_OWNER),
    }
    digest = hashlib.sha256()
    for name, raw in sorted(parts.items()):
        digest.update(name.encode("utf-8") + b"\0" + raw + b"\0")
    return digest.hexdigest()


def _core(root: Path, data: dict) -> None:
    _require(set(data) == TOP_KEYS and data.get("schema_version") == 1, "green gate schema drifted")
    _require(data.get("supersedes") == EXPECTED_SUPERSEDES, "superseded reference drifted")
    _require(data.get("green_gate") == EXPECTED_GREEN_GATE, "green gate parameters drifted")
    _require(data.get("re_pinned_immutables") == EXPECTED_RE_PINNED, "re-pinned immutables drifted")
    _require(data.get("runtime_regating") == EXPECTED_RUNTIME_REGATING, "runtime re-gating drifted")
    _require(data.get("runtime_surface") == "hidden_design_lab_only", "runtime surface widened")
    _require(data.get("product_promotion") == "forbidden", "product promotion widened")
    # not_accepted is state-dependent (see _descriptor); pinned in _pending/_accepted.
    _require(data.get("next_gate") == EXPECTED_NEXT_GATE, "next gate drifted")
    _require(set(data.get("reviews", {})) == ROLES, "review roles drifted")
    _require(
        set(data.get("mechanical_binding", {})) == {
            "candidate_payload_sha256", "reviewed_payload_sha256",
            "reviewed_candidate_commit", "green_lib_inventory_sha256",
        },
        "mechanical binding schema drifted",
    )
    # Freeze: the re-pinned RED guard + registry must still equal the current
    # files. The transition may not proceed on top of a drifted RED contract.
    _require(red._sha(root / RED_GUARD) == RED_GUARD_SHA256, "re-pinned RED guard drifted")
    _require(red._sha(root / REGISTRY) == REGISTRY_SHA256, "re-pinned registry drifted")


def _pending(data: dict, payload: str) -> None:
    _require(
        data.get("status") == PENDING_STATUS and data.get("current_verdict") == PENDING_VERDICT,
        "pending lifecycle drifted",
    )
    _require(data.get("not_accepted") == PENDING_NOT_ACCEPTED, "not-accepted boundary drifted")
    _require(all(value == PENDING_REVIEW for value in data["reviews"].values()), "pending manifest claims reviews")
    binding = data["mechanical_binding"]
    _require(binding.get("candidate_payload_sha256") == payload, "candidate payload drifted")
    _require(
        binding.get("reviewed_payload_sha256") is None and binding.get("reviewed_candidate_commit") is None,
        "pending manifest claims reviewed binding",
    )
    # No runtime is built while pending, so no concrete lib-inventory seal may be
    # claimed. It becomes mandatory (and non-null) only at acceptance.
    _require(binding.get("green_lib_inventory_sha256") is None, "pending manifest claims a green lib inventory seal")


def _accepted(root: Path, data: dict, payload: str) -> None:
    _require(
        data.get("status") == ACCEPTED_STATUS and data.get("current_verdict") == ACCEPTED_VERDICT,
        "accepted lifecycle drifted",
    )
    # Acceptance ⟹ runtime implemented + lib inventory sealed: those two must have
    # LEFT the not-accepted boundary. A manifest that still forbids them cannot be
    # accepted (an accepted green gate whose runtime is unbuilt is a contradiction).
    _require(data.get("not_accepted") == ACCEPTED_NOT_ACCEPTED, "accepted not-accepted boundary drifted")
    # The 15/15 replay is NOT proven by any static check of the CI workflow file
    # (a static check cannot prove execution). It is proven by EXECUTION:
    # ``--release`` runs ``run_expected_green`` which replays the sealed spec and
    # is fail-closed on anything but exactly 15/15. Acceptance is therefore
    # attested by a dispatched --release run at the accepted SHA (exit 0), exactly
    # as the RED acceptance was attested by its release-attestation run. This
    # structural ``_accepted`` gate validates only the receipt; the runtime proof
    # is the dispatched execution.
    binding = data["mechanical_binding"]
    # Acceptance MUST seal a concrete green lib inventory (the exact live lib/ tree
    # digest). run_expected_green verifies the live lib/ against this value before
    # the behavioral replay, so retiring the RED lib-inventory pin cannot let a
    # smuggled or removed lib file survive merely because the 15 tests still pass.
    inventory = binding.get("green_lib_inventory_sha256")
    _require(
        isinstance(inventory, str) and re.fullmatch(r"[0-9a-f]{64}", inventory) is not None,
        "accepted green lib inventory seal invalid",
    )
    commit = binding.get("reviewed_candidate_commit")
    _require(
        isinstance(commit, str) and re.fullmatch(r"[0-9a-f]{40}", commit) is not None and _ancestor(root, commit),
        "reviewed candidate commit invalid",
    )
    _require(
        binding.get("candidate_payload_sha256") == payload and binding.get("reviewed_payload_sha256") == payload,
        "accepted payload drifted",
    )
    exact = {"verdict": "ACCEPT", "p1": 0, "p2": 0, "p3": 0, "reviewed_payload_sha256": payload}
    _require(all(value == exact for value in data["reviews"].values()), "accepted reviews are not exact")
    previous = _load_manifest_bytes(_git_bytes(root, commit, MANIFEST))
    _core(root, previous)
    _pending(previous, payload)
    _require(_payload(root, commit) == payload, "reviewed pending trust unit cannot replay")


def _require_clean_worktree(root: Path) -> None:
    try:
        dirty = subprocess.run(
            ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
            cwd=root, check=True, capture_output=True,
        ).stdout
    except subprocess.CalledProcessError as exc:
        raise GuardFailure("cannot inspect worktree state") from exc
    _require(not dirty, "green gate acceptance requires a clean worktree")


def validate(root: Path = REPO_ROOT, *, require_accepted: bool | None = None, check_git: bool = True) -> None:
    for relative in (MANIFEST, GUARD, TESTS, PATH_OWNER, RED_GUARD, REGISTRY):
        path = root / relative
        _require(path.is_file() and not path.is_symlink(), f"artifact is not a regular file: {relative}")
    data = _load_manifest_bytes((root / MANIFEST).read_bytes())
    _core(root, data)
    payload = _payload(root)
    status = data.get("status")
    if status == PENDING_STATUS:
        _pending(data, payload)
        _require(require_accepted is not True, "green gate is still pending")
    elif status == ACCEPTED_STATUS:
        _accepted(root, data, payload)
        _require(require_accepted is not False, "expected pending green gate")
    else:
        raise GuardFailure("green gate lifecycle status drifted")
    if check_git:
        _require_clean_worktree(root)


def _require_no_empty_dirs(tree: Path, nodes: list[Path]) -> None:
    """Reject empty directories: a file-only digest does not cover an extra empty
    dir, but shutil.copytree copies it, so the tree topology would not be fully
    sealed. Every directory must (transitively) contain a sealed file."""
    files = [n for n in nodes if n.is_file()]
    for node in nodes:
        if node.is_dir():
            _require(
                any(f.is_relative_to(node) for f in files),
                f"tree contains an empty directory: {node.relative_to(tree).as_posix()}",
            )


def _live_lib_inventory_sha256(root: Path) -> str:
    """Digest of the EXACT live design-lab lib/ tree ({relpath: sha256}).

    Reuses the RED guard's inventory basis (red.LIB_ROOT + red._sha). This is the
    inventory that the retired RED replay used to pin; the green gate re-pins it
    against the accepted seal so no lib file can be smuggled in or removed.
    """
    lib = root / red.LIB_ROOT
    _require(lib.is_dir() and not lib.is_symlink(), "R2 GREEN lib/ is not a regular directory")
    nodes = sorted(lib.rglob("*"))
    # Reject symlinks and special entries outright (mirrors the RED guard's tree
    # discipline). A symlink is excluded from a digest yet DEREFERENCED by the
    # runner's shutil.copytree, so silently skipping it would smuggle unsealed
    # external bytes into execution. Empty lib/ is rejected too.
    _require(
        all(not node.is_symlink() and (node.is_file() or node.is_dir()) for node in nodes),
        "R2 GREEN lib/ contains a symlink or special entry",
    )
    _require_no_empty_dirs(lib, nodes)
    sources = {
        node.relative_to(lib).as_posix(): red._sha(node)
        for node in nodes if node.is_file()
    }
    _require(sources, "R2 GREEN lib/ inventory is empty")
    return hashlib.sha256(
        json.dumps(sources, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    ).hexdigest()


def _seal_runner_inputs(root: Path) -> None:
    """Pin every NON-lib file the runner copies into execution.

    ``red._run_candidate_command`` copytree/copy2's the live pubspec, lockfile,
    l10n.yaml, assets/, test, fixture and registry into an isolated dir it then
    runs. Only lib/ changes from RED to GREEN, so these are pinned against the
    frozen RED contract values (the RED guard file is re-pinned in _core, so its
    EXPECTED_* constants cannot drift). Without this, copytree would carry unsealed
    live bytes — a poisoned dependency, asset, or lockfile — into resolution and
    execution even with a sealed lib/. assets/ gets the same symlink discipline as
    lib/ (copytree dereferences symlinks)."""
    pinned = {
        red.PUBSPEC: red.EXPECTED_PUBSPEC_SHA256,
        red.PUBSPEC_LOCK: red.EXPECTED_PUBSPEC_LOCK_SHA256,
        red.L10N_CONFIG: None,  # sealed via the aux digest below
        red.TEST: red.EXPECTED_TEST_SHA256,
        red.FIXTURE: red.EXPECTED_FIXTURE_SHA256,
        red.REGISTRY: REGISTRY_SHA256,
    }
    for relative, expected in pinned.items():
        path = root / relative
        _require(path.is_file() and not path.is_symlink(), f"R2 GREEN runner input is not a regular file: {relative}")
        if expected is not None:
            _require(red._sha(path) == expected, f"R2 GREEN runner input drifted: {relative}")
    assets = root / red.ASSETS_ROOT
    _require(assets.is_dir() and not assets.is_symlink(), "R2 GREEN assets/ is not a regular directory")
    asset_nodes = sorted(assets.rglob("*"))
    _require(
        all(not n.is_symlink() and (n.is_file() or n.is_dir()) for n in asset_nodes),
        "R2 GREEN assets/ contains a symlink or special entry",
    )
    _require_no_empty_dirs(assets, asset_nodes)
    design_lab = red.PUBSPEC.parent
    auxiliary = {"l10n.yaml": red._sha(root / red.L10N_CONFIG)}
    auxiliary.update({
        path.relative_to(root / design_lab).as_posix(): red._sha(path)
        for path in sorted(assets.rglob("*")) if path.is_file()
    })
    _require(auxiliary == red.EXPECTED_AUX_INPUT_SHA256, "R2 GREEN auxiliary input (l10n/assets) drifted")


def run_expected_green(root: Path = REPO_ROOT) -> None:
    """Verify the sealed lib inventory, then replay the sealed spec for 15/15.

    Runs ONLY on an accepted green gate (require_accepted=True): while pending the
    R2 runtime is unwritten and the replay would still be 2/13, so a pending replay
    has no reason to exist. Reuses the RED guard's isolated runner.
    """
    validate(root, require_accepted=True, check_git=False)
    # Exact-inventory seal BEFORE the behavioral replay: the accepted seal must
    # equal the live lib/ tree digest, else a smuggled/removed lib file that still
    # passes 15/15 would be accepted. The RED replay's SHA pin is retired; this
    # restores it under the green regime.
    manifest = _load_manifest_bytes((root / MANIFEST).read_bytes())
    sealed = manifest["mechanical_binding"]["green_lib_inventory_sha256"]
    _require(
        _live_lib_inventory_sha256(root) == sealed,
        "R2 GREEN lib inventory drifted from the sealed seal (smuggled or removed lib file)",
    )
    # Seal every OTHER input the runner copies (deps, l10n, assets, test, fixture,
    # registry) so no unsealed live bytes reach dependency resolution / execution.
    _seal_runner_inputs(root)
    try:
        completed = red._run_candidate_command(root, {"command": list(GREEN_COMMAND)})
    except subprocess.TimeoutExpired as exc:
        raise GuardFailure("R2 GREEN command timed out") from exc
    _require(not completed.stderr.strip(), "R2 GREEN runner emitted stderr")
    _require(completed.returncode == 0, f"R2 GREEN exit was {completed.returncode}, expected 0")
    starts: dict[int, str] = {}
    results: dict[str, str] = {}
    load_result: str | None = None
    done_events: list[dict] = []
    error_ids: list[int] = []
    test_done_ids: list[int] = []
    # The batch20 R2 test uses no group() wrapping, so machine names carry no
    # group prefix; the executed test name IS the reviewed obligation name.
    passive_event_types = {"start", "suite", "allSuites", "group", "print"}
    for line in completed.stdout.splitlines():
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            raise GuardFailure("R2 GREEN runner emitted non-JSON stdout")
        if isinstance(event, list):
            _require(
                len(event) == 1 and isinstance(event[0], dict)
                and event[0].get("event") == "test.startedProcess",
                "R2 GREEN runner emitted unknown list event",
            )
            continue
        _require(isinstance(event, dict), "R2 GREEN runner emitted non-object event")
        kind = event.get("type")
        if kind == "testStart":
            test = event["test"]
            _require(test["id"] not in starts, "duplicate R2 GREEN testStart id")
            starts[test["id"]] = test["name"]
        elif kind == "testDone":
            _require(event["testID"] in starts, "testDone without testStart")
            _require(event["testID"] not in test_done_ids, "duplicate testDone id")
            test_done_ids.append(event["testID"])
            name = starts.get(event["testID"], "<unknown>")
            if name.startswith("loading "):
                load_result = event["result"]
            elif not event.get("hidden", False):
                _require(name not in results, "duplicate R2 GREEN test execution")
                results[name] = event["result"]
            else:
                _require(False, "unexpected hidden testDone event")
        elif kind == "error":
            error_ids.append(event["testID"])
        elif kind == "done":
            done_events.append(event)
        else:
            _require(kind in passive_event_types, f"unknown R2 GREEN machine event: {kind}")
    _require(load_result == "success", "R2 GREEN test failed to compile or load")
    _require(set(test_done_ids) == set(starts), "R2 GREEN testStart/testDone inventory drifted")
    _require(
        len(done_events) == 1 and done_events[0].get("success") is True,
        "R2 GREEN final done event is not success",
    )
    _require(not error_ids, "R2 GREEN emitted error events")
    _require(set(results) == red.EXPECTED_TEST_NAMES, "executed R2 GREEN test inventory drifted")
    failed = sorted(name for name, result in results.items() if result != "success")
    _require(not failed, f"R2 GREEN tests did not all pass: {failed}")
    summary = {"passed": len(results), "failed": len(failed), "load_or_harness_errors": 0}
    _require(summary == GREEN_SUMMARY, f"R2 GREEN summary drifted: {summary}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", action="store_true", help="validate structure only (no Flutter)")
    parser.add_argument("--release", action="store_true", help="require accepted, then run the GREEN replay")
    args = parser.parse_args()
    try:
        if args.contract:
            # Structure-only gate (no Flutter): valid in either lifecycle state.
            validate(REPO_ROOT, check_git=False)
        else:
            # Both the bare CLI and --release run the accepted-only 15/15 replay;
            # run_expected_green itself requires the accepted state (no pending
            # replay exists).
            run_expected_green(REPO_ROOT)
    except (GuardFailure, OSError, UnicodeError, json.JSONDecodeError, subprocess.CalledProcessError, yaml.YAMLError) as exc:
        print(f"BATCH20 R2 GREEN GATE FAIL: {exc}", file=sys.stderr)
        return 1
    print("BATCH20 R2 GREEN GATE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
