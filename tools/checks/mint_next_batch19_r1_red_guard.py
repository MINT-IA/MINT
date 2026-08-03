#!/usr/bin/env python3
"""Fail closed unless Batch18 R1 is an honest, executable RED contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY = Path("product/mint_next/batch18/runtime-gates.yaml")
SCOPE = Path("product/mint_next/batch18/runtime-scope.yaml")
COPY = Path("product/mint_next/batch17/six-locale-copy.yaml")
TEST = Path(
    "product/mint_next/batch7/design_lab/test/"
    "design_lab_batch18_canton_r1_test.dart"
)
FIXTURE = Path(
    "product/mint_next/batch7/design_lab/test/batch18_canton_fixture.g.dart"
)
PUBSPEC = Path("product/mint_next/batch7/design_lab/pubspec.yaml")
LIB_ROOT = Path("product/mint_next/batch7/design_lab/lib")
ANCHOR = "7bbf90b447c5d772597bd807810c39b22b232632"

EXPECTED_SCOPE_SHA256 = "ecb83ff852211d055ca50d9e0667d138b744e1bca1a7ba81131c2c1814761f8a"
EXPECTED_COPY_SHA256 = "3c6d19a37dee264bf5bd0b9e80151eac2796b6a517ddd82a96feb397c49050fe"
EXPECTED_TEST_SHA256 = "b46c2b6c9c60ef9f29eb972b388ba04ccc1a238f51a5cc518c426f95bea1d5fb"
EXPECTED_FIXTURE_SHA256 = "204e505c92a94c650f888d872faf8240b58a763d8d2fa2326ad1c6796b8534ec"
EXPECTED_ORDER = [
    "R1", "R2", "R3", "R4a_safe_exit",
    "R4b_lifecycle_generation_and_privacy",
    "R4c_six_locale_accessibility_and_compact",
    "R4d_cross_step_integration", "R4", "runtime_global",
]
EXPECTED_TEST_NAMES = {
    "R1_01 baseline both legacy origins reach fact_canton",
    "R1_01 exact immutable receipt and Back for both origins",
    "R1_02 entry is unset without fallback or recommendation",
    "R1_03 exact beginner copy and R1-only surface",
    "R1_05 exact six-locale catalog, labels, codes and order",
    "R1_11 every old-generation R1 callback is a total no-op",
    "R1_04 bounded normalized labels-only local search",
    "R1_06 first middle last no-match clear and rapid query",
    "R1_07 clear restores list selection and search focus",
    "R1_10 query changes and clear never mutate selection",
    "R1_12 search exposes no learning or clipboard capability",
    "R1_08 selection commits one allowed ephemeral code only",
    "R1_09 same-code reselection is byte-equivalent no-op",
    "R1_13 all R1 targets and single-select semantics are usable",
    "R1_14 registry keeps R1 before R2 and excludes later evidence",
}
EXPECTED_FAILED_NAMES = EXPECTED_TEST_NAMES - {
    "R1_01 baseline both legacy origins reach fact_canton",
    "R1_14 registry keeps R1 before R2 and excludes later evidence"
}
EXPECTED_RED_SENTINELS = {
    name: name.split(" ", 1)[0]
    for name in EXPECTED_FAILED_NAMES
}
ALLOWED_DIFF_PATHS = {
    str(REGISTRY), str(TEST), str(FIXTURE),
    "tools/checks/mint_next_batch19_r1_red_guard.py",
    "tools/checks/tests/test_mint_next_batch19_r1_red_guard.py",
}
EXPECTED_TOP_KEYS = {
    "schema_version", "status", "batch", "authority", "ordered_gates",
    "gates", "forbidden_claims",
}
EXPECTED_FORBIDDEN_CLAIMS = [
    "runtime_implemented", "runtime_accepted", "user_validated", "production_ready"
]
EXPECTED_BLOCKED_GATES = {
    "R2": "blocked_by_R1",
    "R3": "blocked_by_R2",
    "R4a_safe_exit": "blocked_by_R3",
    "R4b_lifecycle_generation_and_privacy": "blocked_by_R4a",
    "R4c_six_locale_accessibility_and_compact": "blocked_by_R4b",
    "R4d_cross_step_integration": "blocked_by_R4c",
    "R4": "blocked_by_R4d",
    "runtime_global": "blocked_by_R4",
}
FORBIDDEN_CAPABILITY_TOKENS = {
    "package:http", "package:dio", "shared_preferences", "firebase_analytics",
    "package:sentry", "dart:developer", "dart:io", "dart:ffi",
}
FORBIDDEN_CAPABILITY_IDENTIFIERS = {
    "MethodChannel", "BasicMessageChannel", "EventChannel", "BinaryMessenger",
    "ServicesBinding", "SystemChannels", "PlatformDispatcher", "sendPlatformMessage",
    "print", "debugPrint", "debugPrintSynchronously", "debugDumpApp",
    "debugDumpRenderTree", "debugDumpLayerTree", "debugDumpSemanticsTree",
    "debugDumpFocusTree", "dumpErrorToConsole",
    "analytics", "logger",
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


UniqueLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _unique_mapping
)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GuardFailure(message)


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _load(path: Path) -> dict:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueLoader)


def _quoted_values(block: str) -> list[str]:
    return re.findall(r'^\s+"((?:[^"\\]|\\.)*)",?$', block, re.MULTILINE)


def _validate_fixture(root: Path) -> None:
    source = _load(root / COPY)
    text = (root / FIXTURE).read_text(encoding="utf-8")
    _require(_sha(root / COPY) == EXPECTED_COPY_SHA256, "accepted copy digest drifted")
    _require(EXPECTED_COPY_SHA256 in text, "fixture source digest drifted")
    allowed = re.search(
        r"const batch18AllowedCantonCodes = <String>\{(.*?)\n\};", text, re.S
    )
    _require(allowed is not None, "fixture allowed-code block missing")
    codes = _quoted_values(allowed.group(1))
    _require(
        len([line for line in allowed.group(1).splitlines() if line.strip()]) == len(codes),
        "fixture allowed-code block contains executable or unparsed content",
    )
    _require(codes == sorted(source["canton_labels"]["fr"]), "fixture allowed codes drifted")
    for locale in source["locales"]:
        labels = re.search(
            rf'^  "{locale}": <String, String>\{{(.*?)^  \}},$', text, re.S | re.M
        )
        order = re.search(
            rf'^  "{locale}": <String>\[(.*?)^  \],$', text, re.S | re.M
        )
        _require(labels is not None and order is not None, f"fixture locale missing: {locale}")
        pairs = dict(re.findall(r'^    "([A-Z]{2})": "(.*)",$', labels.group(1), re.M))
        _require(
            len([line for line in labels.group(1).splitlines() if line.strip()]) == len(pairs),
            f"fixture labels contain executable or unparsed content: {locale}",
        )
        _require(pairs == source["canton_labels"][locale], f"fixture labels drifted: {locale}")
        parsed_order = _quoted_values(order.group(1))
        _require(
            len([line for line in order.group(1).splitlines() if line.strip()]) == len(parsed_order),
            f"fixture order contains executable or unparsed content: {locale}",
        )
        _require(parsed_order == source["ordered_codes"][locale], f"fixture order drifted: {locale}")


def _validate_diff_boundary(root: Path) -> None:
    try:
        committed = subprocess.run(
            ["git", "diff", "--name-only", f"{ANCHOR}..HEAD"],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.splitlines()
        uncommitted = subprocess.run(
            ["git", "diff", "--name-only", "HEAD"],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.splitlines()
        untracked = subprocess.run(
            ["git", "ls-files", "--others", "--exclude-standard"],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.splitlines()
    except subprocess.CalledProcessError as exc:
        raise GuardFailure("cannot inspect Batch19 git boundary") from exc
    changed = set(committed + uncommitted + untracked)
    unexpected = changed - ALLOWED_DIFF_PATHS
    _require(not unexpected, f"Batch19 RED scope changed forbidden paths: {sorted(unexpected)}")


def validate(root: Path = REPO_ROOT, *, check_git: bool = True) -> None:
    for relative in (REGISTRY, SCOPE, COPY, TEST, FIXTURE, PUBSPEC):
        path = root / relative
        _require(path.is_file() and not path.is_symlink(), f"artifact is not a regular file: {relative}")
    registry = _load(root / REGISTRY)
    scope = _load(root / SCOPE)
    _require(set(registry) == EXPECTED_TOP_KEYS, "registry top-level schema drifted")
    _require(registry.get("schema_version") == 1 and registry.get("batch") == 18, "registry identity drifted")
    _require(_sha(root / SCOPE) == EXPECTED_SCOPE_SHA256, "accepted scope digest drifted")
    _require(
        registry.get("status") == "candidate_expected_red_evidence_runtime_not_implemented",
        "registry lifecycle or runtime claim drifted",
    )
    _require(registry.get("ordered_gates") == EXPECTED_ORDER, "gate order drifted")
    authority = registry.get("authority", {})
    _require(set(authority) == {"immutable_scope", "immutable_scope_sha256", "runtime_surface", "product_promotion"}, "registry authority schema drifted")
    _require(authority.get("immutable_scope") == str(SCOPE), "scope authority drifted")
    _require(authority.get("immutable_scope_sha256") == EXPECTED_SCOPE_SHA256, "scope binding drifted")
    _require(authority.get("runtime_surface") == "hidden_design_lab_only", "runtime surface widened")
    _require(authority.get("product_promotion") == "forbidden", "product promotion widened")
    r1 = registry.get("gates", {}).get("R1", {})
    _require(set(registry.get("gates", {})) == set(EXPECTED_ORDER), "registry gate inventory drifted")
    for gate, state in EXPECTED_BLOCKED_GATES.items():
        _require(registry["gates"][gate] == {"state": state}, f"blocked gate widened: {gate}")
    _require(
        set(r1) == {
            "state", "runtime_implemented", "runtime_accepted", "next_gate",
            "later_gate_evidence_counts_for_R1", "test_file", "fixture_file",
            "command", "working_directory", "expected_exit_code",
            "expected_summary", "candidate_binding", "subgates",
            "obligation_test_names", "expected_red_sentinels",
        },
        "R1 registry schema drifted",
    )
    _require(r1.get("state") == "expected_red", "R1 is not expected RED")
    _require(r1.get("runtime_implemented") is False, "R1 claims implementation")
    _require(r1.get("runtime_accepted") is False, "R1 claims acceptance")
    _require(r1.get("next_gate") == "R2", "R1 next gate drifted")
    _require(r1.get("later_gate_evidence_counts_for_R1") is False, "later evidence can falsely accept R1")
    _require(r1.get("test_file") == str(TEST), "R1 test path drifted")
    _require(r1.get("fixture_file") == str(FIXTURE), "R1 fixture path drifted")
    _require(
        r1.get("command") == ["flutter", "test", "test/design_lab_batch18_canton_r1_test.dart", "--machine"],
        "R1 command is not exact and targeted",
    )
    _require(r1.get("working_directory") == "product/mint_next/batch7/design_lab", "R1 working directory drifted")
    _require(r1.get("expected_exit_code") == 1, "R1 expected exit drifted")
    _require(r1.get("expected_summary") == {"passed": 2, "failed": 13, "load_or_harness_errors": 0}, "R1 expected summary drifted")

    obligation_map = r1.get("obligation_test_names", {})
    expected_ids = {f"R1_{index:02d}" for index in range(1, 15)}
    _require(set(obligation_map) == expected_ids, "R1 obligation coverage drifted")
    mapped_names = set()
    for value in obligation_map.values():
        mapped_names.update(value if isinstance(value, list) else [value])
    _require(mapped_names == EXPECTED_TEST_NAMES, "R1 named-test inventory drifted")
    _require(r1.get("expected_red_sentinels") == EXPECTED_RED_SENTINELS, "R1 RED sentinel binding drifted")
    _require(
        r1.get("subgates") == {
            "R1a_catalog_origin_and_generation": ["R1_01", "R1_02", "R1_03", "R1_05", "R1_11"],
            "R1b_local_search_privacy": ["R1_04", "R1_06", "R1_07", "R1_10", "R1_12"],
            "R1c_selection_semantics_and_layout": ["R1_08", "R1_09", "R1_13"],
        },
        "R1 subgate coverage drifted",
    )
    _require(registry.get("forbidden_claims") == EXPECTED_FORBIDDEN_CLAIMS, "forbidden claims drifted")
    scope_obligations = scope["microsteps"]["R1"]["obligations"]
    _require({item.split("_", 2)[0] + "_" + item.split("_", 2)[1] for item in scope_obligations} == expected_ids, "accepted R1 obligations drifted")

    test_source = (root / TEST).read_text(encoding="utf-8")
    for name in EXPECTED_TEST_NAMES:
        _require(test_source.count(name) == 1, f"R1 test missing or duplicated: {name}")
    _require("batch18Harness" not in test_source, "R1 RED depends on nonexistent harness")
    _require("MintNextDesignLabApp(" in test_source, "R1 tests do not drive real app")
    _validate_fixture(root)
    _require(
        r1.get("candidate_binding") == {
            "test_sha256": EXPECTED_TEST_SHA256,
            "fixture_sha256": EXPECTED_FIXTURE_SHA256,
        },
        "R1 candidate source binding drifted",
    )
    _require(_sha(root / TEST) == EXPECTED_TEST_SHA256, "R1 test digest drifted")
    _require(_sha(root / FIXTURE) == EXPECTED_FIXTURE_SHA256, "R1 fixture digest drifted")
    pubspec = _load(root / PUBSPEC)
    _require(
        set(pubspec.get("dependencies", {}))
        == {"characters", "flutter", "flutter_localizations", "intl", "unorm_dart"},
        "Design Lab dependency capability surface widened",
    )
    capability_source = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((root / LIB_ROOT).rglob("*.dart"))
    )
    leaked = sorted(token for token in FORBIDDEN_CAPABILITY_TOKENS if token in capability_source)
    leaked.extend(
        sorted(
            identifier
            for identifier in FORBIDDEN_CAPABILITY_IDENTIFIERS
            if re.search(rf"(?<![A-Za-z0-9_$]){re.escape(identifier)}(?![A-Za-z0-9_$])", capability_source)
        )
    )
    _require(not leaked, f"Design Lab uninstrumented capability path present: {leaked}")
    if check_git:
        _validate_diff_boundary(root)


def run_expected_red(root: Path = REPO_ROOT, *, check_git: bool = True) -> None:
    validate(root, check_git=check_git)
    registry = _load(root / REGISTRY)
    r1 = registry["gates"]["R1"]
    try:
        completed = subprocess.run(
            r1["command"],
            cwd=root / r1["working_directory"],
            capture_output=True,
            text=True,
            timeout=120,
        )
    except subprocess.TimeoutExpired as exc:
        raise GuardFailure("R1 RED command timed out") from exc
    _require(not completed.stderr.strip(), "R1 runner emitted stderr")
    _require(completed.returncode == 1, f"R1 RED command exit was {completed.returncode}, expected 1")
    starts: dict[int, str] = {}
    results: dict[str, str] = {}
    diagnostics: dict[int, list[str]] = {}
    load_result: str | None = None
    done_events: list[dict] = []
    error_ids: list[int] = []
    test_done_ids: list[int] = []
    passive_event_types = {"start", "suite", "allSuites", "group"}
    for line in completed.stdout.splitlines():
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            raise GuardFailure("R1 runner emitted non-JSON stdout")
        if isinstance(event, list):
            _require(
                len(event) == 1
                and isinstance(event[0], dict)
                and event[0].get("event") == "test.startedProcess",
                "R1 runner emitted unknown list event",
            )
            continue
        _require(isinstance(event, dict), "R1 runner emitted non-object event")
        if event.get("type") == "testStart":
            test = event["test"]
            _require(test["id"] not in starts, "duplicate R1 testStart id")
            starts[test["id"]] = test["name"]
        elif event.get("type") == "print":
            _require(event["testID"] in starts, "print without testStart")
            diagnostics.setdefault(event["testID"], []).append(event.get("message", ""))
        elif event.get("type") == "testDone":
            _require(event["testID"] in starts, "testDone without testStart")
            _require(event["testID"] not in test_done_ids, "duplicate testDone id")
            test_done_ids.append(event["testID"])
            name = starts.get(event["testID"], "<unknown>")
            if name.startswith("loading "):
                load_result = event["result"]
            elif not event.get("hidden", False):
                short = name.split(" ", 1)[1] if name.startswith("R1a_") or name.startswith("R1b_") or name.startswith("R1c_") else name
                _require(short not in results, "duplicate R1 test execution")
                results[short] = event["result"]
            else:
                _require(False, "unexpected hidden testDone event")
        elif event.get("type") == "error":
            error_ids.append(event["testID"])
        elif event.get("type") == "done":
            done_events.append(event)
        else:
            _require(event.get("type") in passive_event_types, f"unknown R1 machine event: {event.get('type')}")
    _require(load_result == "success", "R1 test failed to compile or load")
    _require(set(test_done_ids) == set(starts), "R1 testStart/testDone inventory drifted")
    _require(
        len(done_events) == 1
        and set(done_events[0]) == {"success", "type", "time"}
        and done_events[0]["type"] == "done"
        and done_events[0]["success"] is False
        and isinstance(done_events[0]["time"], int),
        "R1 final done event drifted",
    )
    _require(set(results) == EXPECTED_TEST_NAMES, "executed R1 test inventory drifted")
    failed = {name for name, result in results.items() if result == "error"}
    passed = {name for name, result in results.items() if result == "success"}
    _require(failed == EXPECTED_FAILED_NAMES, f"unexpected RED failures: {sorted(failed ^ EXPECTED_FAILED_NAMES)}")
    _require(passed == EXPECTED_TEST_NAMES - EXPECTED_FAILED_NAMES, "R1 baseline/meta sentinels did not pass")
    expected_error_ids = sorted(
        test_id
        for test_id, full_name in starts.items()
        if (full_name.split(" ", 1)[1] if full_name.startswith(("R1a_", "R1b_", "R1c_")) else full_name)
        in EXPECTED_FAILED_NAMES
    )
    _require(sorted(error_ids) == expected_error_ids, "R1 machine error-event inventory drifted")
    forbidden_diagnostics = (
        "Test timed out", "pumpAndSettle timed out", "NoSuchMethodError",
        "LateInitializationError", "RangeError", "Bad state:",
        "precondition:", "Could not find a generator for route",
    )
    for test_id, full_name in starts.items():
        short = full_name.split(" ", 1)[1] if full_name.startswith(("R1a_", "R1b_", "R1c_")) else full_name
        if short not in EXPECTED_FAILED_NAMES:
            continue
        output = "\n".join(diagnostics.get(test_id, []))
        expected_marker = f"[{EXPECTED_RED_SENTINELS[short]}]"
        _require("TestFailure" in output and expected_marker in output, f"RED failure is not the exact named behavioral assertion: {short}")
        _require(not any(token in output for token in forbidden_diagnostics), f"RED failure is a harness/runtime error: {short}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", action="store_true", help="skip expected-failing Flutter execution")
    args = parser.parse_args()
    try:
        if args.contract:
            validate()
        else:
            run_expected_red()
    except GuardFailure as exc:
        print(f"BATCH19 R1 RED FAIL: {exc}", file=sys.stderr)
        return 1
    print("BATCH19 R1 RED PASS: behavioral failures are expected and runtime remains unimplemented")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
