#!/usr/bin/env python3
"""Seal the Batch21 R3 GREEN-GATE governance transition (éclairage integration).

This guard governs the transition that RETIRES the accepted 2/12 expected-RED
replay of the R3 arc (fact_revenu + eclairage_impot_3a) and installs, in its
place, the 14/14 GREEN replay as the active R3 gate — the éclairage INTEGRATION
proof (fact_lieu.continue -> fact_revenu -> fact_revenu.continue -> eclairage,
superseding the batch20 outbound edge; situation + versement display_only; the
révenu refine recomputes by band mapping).

Unlike batch20 (whose test was byte-identical RED->GREEN), the batch21 sealed test
was AMENDED at the integration (R3_08 re-gated to the display_only ruling, the
unused batch20 compile-fixture import dropped). So the GREEN gate pins the AMENDED
test sha (GREEN_TEST_SHA256) and the amended obligation names (GREEN_TEST_NAMES) —
NOT the RED guard's frozen values. The runtime-gates registry keeps the FROZEN RED
R3 gate (the sealed contract) and flips deferred_integration.status -> delivered;
this GREEN gate is the live delivered record.

The design mirrors tools/checks/mint_next_batch20_r2_green_gate_guard.py: a
payload-bound pending/accepted lifecycle, isolated (-I) execution, duplicate-key
rejection. It reuses the sealed replay machinery from
mint_next_batch21_r3_red_guard (isolated runner, lib inventory basis, sha helper).
"""

from __future__ import annotations

import sys

if __name__ == "__main__" and not sys.flags.isolated:
    raise SystemExit(
        "USAGE: run this proof as python3 -I tools/checks/mint_next_batch21_r3_green_gate_guard.py"
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

from tools.checks import mint_next_batch21_r3_red_guard as red

MANIFEST = Path("product/mint_next/batch21/r3-green-gate.yaml")
GUARD = Path("tools/checks/mint_next_batch21_r3_green_gate_guard.py")
TESTS = Path("tools/checks/tests/test_mint_next_batch21_r3_green_gate_guard.py")
# The reviewed path-owner receipt that owns this transition's trust unit. Its
# bytes are bound into the payload so tampering it breaks the candidate binding.
PATH_OWNER = Path(".planning/journeys/path-owners/batch21-r3-green-gate.json")
RED_GUARD = Path("tools/checks/mint_next_batch21_r3_red_guard.py")
REGISTRY = red.REGISTRY  # product/mint_next/batch21/runtime-gates.yaml
# The command that ACTUALLY fires the fail-closed 14/14 replay (validate accepted
# + run_expected_green). Acceptance is attested by a dispatched run of this, not
# by any static check of the CI workflow file.
FULL_MODE_INVOCATION = "python3 -I tools/checks/mint_next_batch21_r3_green_gate_guard.py --release"

# Re-pinned immutables frozen by this transition. These MUST equal the current
# files: the RED guard and the ANCHOR''' registry cannot silently drift while the
# GREEN gate that supersedes their replay is under review.
RED_GUARD_SHA256 = "774cc9378f2b691f528d050ee6b3576de1c2a99aee2317fafc1550de8f030e94"
REGISTRY_SHA256 = "9ab1a173e52c058203bb1b30708832b6ac0f71bd4acefc6944a077908bfaf55b"

WORKING_DIRECTORY = "product/mint_next/batch7/design_lab"
GREEN_COMMAND = [
    "flutter", "test", "test/design_lab_batch21_r3_test.dart",
    "--machine", "--no-pub",
]
GREEN_SUMMARY = {"passed": 14, "failed": 0, "load_or_harness_errors": 0}

# The AMENDED sealed test (integration): R3_08 re-gated to the versement/situation
# display_only ruling, the unused batch20 compile-fixture import dropped. This is
# the delivered test the GREEN replay runs — distinct from red.EXPECTED_TEST_SHA256
# (the frozen RED test).
GREEN_TEST_SHA256 = "41f4bbfca4aabfe95bb8261ae5296a0051b870f70bd992a2cc9c47feaf59df99"
GREEN_TEST_NAMES = {
    "R3_01 the shared entry path reaches the fact_lieu boundary before the R3 fact_revenu runtime",
    "R3_02 fact_revenu shows six taxable income band cards none preselected and no wheel or keyboard",
    "R3_03 fact_revenu arrival focuses the heading not a raised keyboard and the question carries the meaning without a body",
    "R3_04 selecting a taxable income band announces the selection summary and marks the band",
    "R3_05 the revenu imposable glossary sheet opens focus trapped and restores to the anchor",
    "R3_06 fact_revenu error no selection is announced and continue never routes in r3",
    "R3_07 eclairage nominal shows the mechanism a low to high range four hypotheses and the disclaimer never a single number",
    "R3_08 eclairage revenu and lieu are editable hypotheses with a refine affordance and versement and situation are display only",
    "R3_09 eclairage precision refined tightens the range but never collapses it to a single number",
    "R3_10 eclairage pending missing income shows no number and eclairage low income floor shows the honest note",
    "R3_11 eclairage non_applicable source shows no chf amount under the binary gate",
    "R3_12 the deduction glossary sheet opens focus trapped and restored",
    "R3_13 compact 320x700 text scale two shows the eclairage mechanism range and disclaimer without overflow",
    "R3_14 registry keeps R3 after R2 before R4 and excludes later evidence",
}

# (c) CI enforcement. While PENDING only the structure gate runs (--contract).
# Acceptance is attested by EXECUTING the full green replay (run_expected_green
# via --release), fail-closed — NOT by any static presence check of a workflow
# file. Descriptor-immutable.
EXPECTED_CI_ENFORCEMENT = {
    "pending": "contract_only",
    "accepted_attested_by": "dispatched_full_green_replay_run_expected_green",
    "attestation_command": FULL_MODE_INVOCATION,
    "retires": "red_replay_2_12",
}

ROLES = {"scope_integrity", "mechanical_adversary", "journey_safety"}
PENDING_REVIEW = {"verdict": "PENDING", "p1": None, "p2": None, "p3": None}

TOP_KEYS = {
    "schema_version", "status", "current_verdict", "supersedes", "green_gate",
    "re_pinned_immutables", "runtime_regating", "runtime_surface",
    "product_promotion", "reviews", "mechanical_binding", "not_accepted",
    "next_gate",
}

# (a) The RED 2/12 replay is retired; upon promotion + integration the active CI
# gate becomes the GREEN 14/14 replay of the AMENDED sealed test.
EXPECTED_GREEN_GATE = {
    "retires": "red_replay_2_12",
    "active_gate_upon_promotion": "green_replay_14_14",
    "test_file": str(red.TEST),
    "test_sha256": GREEN_TEST_SHA256,
    "command": list(GREEN_COMMAND),
    "working_directory": WORKING_DIRECTORY,
    "expected_summary": dict(GREEN_SUMMARY),
    "expected_exit_code": 0,
    "obligation_test_names": sorted(GREEN_TEST_NAMES),
    "ci_enforcement": dict(EXPECTED_CI_ENFORCEMENT),
}

# (b) The two immutables this transition freezes: the RED guard and the ANCHOR'''
# registry.
EXPECTED_RE_PINNED = {
    "red_guard": {"path": str(RED_GUARD), "sha256": RED_GUARD_SHA256},
    "registry": {"path": str(REGISTRY), "sha256": REGISTRY_SHA256},
}

# (d) The four regated runtime files (registry.runtime_regating) plus fact_lieu
# whose outbound edge the integration wired. The CONTENT seal is the concrete
# green lib-inventory sha (mechanical_binding.green_lib_inventory_sha256), sealed
# at acceptance.
EXPECTED_RUNTIME_REGATING = {
    "scope_owner": "batch21-r3-runtime",
    "regated_files": [
        "product/mint_next/batch7/design_lab/lib/fact_revenu.dart",
        "product/mint_next/batch7/design_lab/lib/eclairage_impot_3a.dart",
        "product/mint_next/batch7/design_lab/lib/r3_eclairage_catalog.g.dart",
        "product/mint_next/batch7/design_lab/lib/design_lab_app.dart",
        "product/mint_next/batch7/design_lab/lib/fact_lieu.dart",
    ],
    "lib_inventory_seal": "sealed_at_acceptance_green_lib_inventory_sha256",
}

# The RED acceptance this GREEN gate supersedes (declarative provenance), from
# product/mint_next/batch21/r3-red-acceptance.json. The RED acceptance was attested
# by a dispatched run at the branch-live CI commit; no fabricated URL is claimed.
EXPECTED_SUPERSEDES = {
    "red_acceptance_receipt": "product/mint_next/batch21/r3-red-acceptance.json",
    "accepted_payload_sha256": "c5f16c5ce0f91840847a6d87c076cb8145a300393a9ba1131dcfcdb1983003f4",
    "red_commit": "343d6f323a59e2e8c14890785b82b51cb187cce5",
    "accepted_receipt_commit": "fe837316b",
    "attestation_dispatched_at_ci_commit": "56797e1c2",
}

# not_accepted is state-DEPENDENT (so it is NOT in the descriptor / payload — the
# replay requires an identical descriptor across pending and accepted). While
# PENDING nothing is accepted; at ACCEPTED the runtime IS integrated and its lib
# inventory IS sealed, so those two leave the boundary. Product route and
# production readiness remain forbidden in BOTH states (hidden runtime only).
PENDING_NOT_ACCEPTED = [
    "runtime_accepted",
    "lib_inventory_sealed",
    "product_route",
    "production_ready",
]
ACCEPTED_NOT_ACCEPTED = [
    "product_route",
    "production_ready",
]
EXPECTED_NEXT_GATE = "seal_R3_green_lib_inventory_then_R4a_safe_exit"

PENDING_STATUS = "candidate_green_gate_unaccepted"
PENDING_VERDICT = "PENDING_INDEPENDENT_ROASTS"
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
    integrated + sealed) and so cannot live in a descriptor that the accepted
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
    receipt is bound too. The descriptor carries the re-pinned immutables, so the
    frozen RED guard and ANCHOR''' registry are bound transitively.
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
    _require(data.get("next_gate") == EXPECTED_NEXT_GATE, "next gate drifted")
    _require(set(data.get("reviews", {})) == ROLES, "review roles drifted")
    _require(
        set(data.get("mechanical_binding", {})) == {
            "candidate_payload_sha256", "reviewed_payload_sha256",
            "reviewed_candidate_commit", "green_lib_inventory_sha256",
        },
        "mechanical binding schema drifted",
    )
    # Freeze: the re-pinned RED guard + ANCHOR''' registry must still equal the
    # current files. The transition may not proceed on a drifted RED contract.
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
    _require(binding.get("green_lib_inventory_sha256") is None, "pending manifest claims a green lib inventory seal")


def _accepted(root: Path, data: dict, payload: str) -> None:
    _require(
        data.get("status") == ACCEPTED_STATUS and data.get("current_verdict") == ACCEPTED_VERDICT,
        "accepted lifecycle drifted",
    )
    _require(data.get("not_accepted") == ACCEPTED_NOT_ACCEPTED, "accepted not-accepted boundary drifted")
    binding = data["mechanical_binding"]
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
    files = [n for n in nodes if n.is_file()]
    for node in nodes:
        if node.is_dir():
            _require(
                any(f.is_relative_to(node) for f in files),
                f"tree contains an empty directory: {node.relative_to(tree).as_posix()}",
            )


def _live_lib_inventory_sha256(root: Path) -> str:
    """Digest of the EXACT live design-lab lib/ tree ({relpath: sha256}).

    Reuses the RED guard's inventory basis (red.LIB_ROOT + red._sha). The green
    gate re-pins it against the accepted seal so no lib file can be smuggled in or
    removed while the 14 tests still pass.
    """
    lib = root / red.LIB_ROOT
    _require(lib.is_dir() and not lib.is_symlink(), "R3 GREEN lib/ is not a regular directory")
    nodes = sorted(lib.rglob("*"))
    _require(
        all(not node.is_symlink() and (node.is_file() or node.is_dir()) for node in nodes),
        "R3 GREEN lib/ contains a symlink or special entry",
    )
    _require_no_empty_dirs(lib, nodes)
    sources = {
        node.relative_to(lib).as_posix(): red._sha(node)
        for node in nodes if node.is_file()
    }
    _require(sources, "R3 GREEN lib/ inventory is empty")
    return hashlib.sha256(
        json.dumps(sources, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    ).hexdigest()


def _seal_runner_inputs(root: Path) -> None:
    """Pin every NON-lib file the runner copies into execution.

    red._run_candidate_command copytree/copy2's the live pubspec, lockfile,
    l10n.yaml, assets/, test, fixture and registry into an isolated dir it then
    runs. Only lib/ and the TEST and the REGISTRY changed from RED to GREEN, so the
    test is pinned to GREEN_TEST_SHA256 (amended), the registry to REGISTRY_SHA256
    (ANCHOR'''), and the unchanged inputs to the frozen RED values.
    """
    pinned = {
        red.PUBSPEC: red.EXPECTED_PUBSPEC_SHA256,
        red.PUBSPEC_LOCK: red.EXPECTED_PUBSPEC_LOCK_SHA256,
        red.L10N_CONFIG: None,  # sealed via the aux digest below
        red.TEST: GREEN_TEST_SHA256,
        red.FIXTURE: red.EXPECTED_FIXTURE_SHA256,  # copied by the shared runner (no longer imported); sealed against poisoning
        red.REGISTRY: REGISTRY_SHA256,
    }
    for relative, expected in pinned.items():
        path = root / relative
        _require(path.is_file() and not path.is_symlink(), f"R3 GREEN runner input is not a regular file: {relative}")
        if expected is not None:
            _require(red._sha(path) == expected, f"R3 GREEN runner input drifted: {relative}")
    assets = root / red.ASSETS_ROOT
    _require(assets.is_dir() and not assets.is_symlink(), "R3 GREEN assets/ is not a regular directory")
    asset_nodes = sorted(assets.rglob("*"))
    _require(
        all(not n.is_symlink() and (n.is_file() or n.is_dir()) for n in asset_nodes),
        "R3 GREEN assets/ contains a symlink or special entry",
    )
    _require_no_empty_dirs(assets, asset_nodes)
    design_lab = red.PUBSPEC.parent
    auxiliary = {"l10n.yaml": red._sha(root / red.L10N_CONFIG)}
    auxiliary.update({
        path.relative_to(root / design_lab).as_posix(): red._sha(path)
        for path in sorted(assets.rglob("*")) if path.is_file()
    })
    _require(auxiliary == red.EXPECTED_AUX_INPUT_SHA256, "R3 GREEN auxiliary input (l10n/assets) drifted")


def run_expected_green(root: Path = REPO_ROOT) -> None:
    """Verify the sealed lib inventory, then replay the AMENDED sealed test 14/14.

    Runs ONLY on an accepted green gate (require_accepted=True). Reuses the RED
    guard's isolated runner.
    """
    validate(root, require_accepted=True, check_git=False)
    manifest = _load_manifest_bytes((root / MANIFEST).read_bytes())
    sealed = manifest["mechanical_binding"]["green_lib_inventory_sha256"]
    _require(
        _live_lib_inventory_sha256(root) == sealed,
        "R3 GREEN lib inventory drifted from the sealed seal (smuggled or removed lib file)",
    )
    _seal_runner_inputs(root)
    try:
        completed = red._run_candidate_command(root, {"command": list(GREEN_COMMAND)})
    except subprocess.TimeoutExpired as exc:
        raise GuardFailure("R3 GREEN command timed out") from exc
    _require(not completed.stderr.strip(), "R3 GREEN runner emitted stderr")
    _require(completed.returncode == 0, f"R3 GREEN exit was {completed.returncode}, expected 0")
    starts: dict[int, str] = {}
    results: dict[str, str] = {}
    load_result: str | None = None
    done_events: list[dict] = []
    error_ids: list[int] = []
    test_done_ids: list[int] = []
    passive_event_types = {"start", "suite", "allSuites", "group", "print"}
    for line in completed.stdout.splitlines():
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            raise GuardFailure("R3 GREEN runner emitted non-JSON stdout")
        if isinstance(event, list):
            _require(
                len(event) == 1 and isinstance(event[0], dict)
                and event[0].get("event") == "test.startedProcess",
                "R3 GREEN runner emitted unknown list event",
            )
            continue
        _require(isinstance(event, dict), "R3 GREEN runner emitted non-object event")
        kind = event.get("type")
        if kind == "testStart":
            test = event["test"]
            _require(test["id"] not in starts, "duplicate R3 GREEN testStart id")
            starts[test["id"]] = test["name"]
        elif kind == "testDone":
            _require(event["testID"] in starts, "testDone without testStart")
            _require(event["testID"] not in test_done_ids, "duplicate testDone id")
            test_done_ids.append(event["testID"])
            name = starts.get(event["testID"], "<unknown>")
            if name.startswith("loading "):
                load_result = event["result"]
            elif not event.get("hidden", False):
                _require(name not in results, "duplicate R3 GREEN test execution")
                results[name] = event["result"]
            else:
                _require(False, "unexpected hidden testDone event")
        elif kind == "error":
            error_ids.append(event["testID"])
        elif kind == "done":
            done_events.append(event)
        else:
            _require(kind in passive_event_types, f"unknown R3 GREEN machine event: {kind}")
    _require(load_result == "success", "R3 GREEN test failed to compile or load")
    _require(set(test_done_ids) == set(starts), "R3 GREEN testStart/testDone inventory drifted")
    _require(
        len(done_events) == 1 and done_events[0].get("success") is True,
        "R3 GREEN final done event is not success",
    )
    _require(not error_ids, "R3 GREEN emitted error events")
    _require(set(results) == GREEN_TEST_NAMES, "executed R3 GREEN test inventory drifted")
    failed = sorted(name for name, result in results.items() if result != "success")
    _require(not failed, f"R3 GREEN tests did not all pass: {failed}")
    summary = {"passed": len(results), "failed": len(failed), "load_or_harness_errors": 0}
    _require(summary == GREEN_SUMMARY, f"R3 GREEN summary drifted: {summary}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", action="store_true", help="validate structure only (no Flutter)")
    parser.add_argument("--release", action="store_true", help="require accepted, then run the GREEN replay")
    args = parser.parse_args()
    try:
        if args.contract:
            validate(REPO_ROOT, check_git=False)
        else:
            run_expected_green(REPO_ROOT)
    except (GuardFailure, OSError, UnicodeError, json.JSONDecodeError, subprocess.CalledProcessError, yaml.YAMLError) as exc:
        print(f"BATCH21 R3 GREEN GATE FAIL: {exc}", file=sys.stderr)
        return 1
    print("BATCH21 R3 GREEN GATE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
