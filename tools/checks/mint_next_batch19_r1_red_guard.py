#!/usr/bin/env python3
"""Fail closed unless Batch18 R1 is an honest, executable RED contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
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
PUBSPEC_LOCK = Path("product/mint_next/batch7/design_lab/pubspec.lock")
LIB_ROOT = Path("product/mint_next/batch7/design_lab/lib")
L10N_CONFIG = Path("product/mint_next/batch7/design_lab/l10n.yaml")
ASSETS_ROOT = Path("product/mint_next/batch7/design_lab/assets")
ANCHOR = "7bbf90b447c5d772597bd807810c39b22b232632"

EXPECTED_SCOPE_SHA256 = "ecb83ff852211d055ca50d9e0667d138b744e1bca1a7ba81131c2c1814761f8a"
EXPECTED_COPY_SHA256 = "3c6d19a37dee264bf5bd0b9e80151eac2796b6a517ddd82a96feb397c49050fe"
EXPECTED_TEST_SHA256 = "c5dde1139cb52855140322c0254b6dc60f3e6a66e1c21cb6060795dd460e071b"
EXPECTED_FIXTURE_SHA256 = "204e505c92a94c650f888d872faf8240b58a763d8d2fa2326ad1c6796b8534ec"
EXPECTED_PUBSPEC_SHA256 = "0b83bf36a5ee2242becbd0fb601235f0c3b2942813207552a03957aaf1569326"
EXPECTED_PUBSPEC_LOCK_SHA256 = "6d7f501ae44e385c80d3726c6a25d830d04d3acf0a7456c6129a293f97f885a1"
EXPECTED_LIB_SOURCE_SHA256 = {
    "design_lab_app.dart": "95a795d2b68360365792da2966864be476ca00f6064a53637454cd686a2d812f",
    "l10n/app_de.arb": "7f283d427787d7bd23138433128c7adc2653906b780e48df8fba668a8564d8ad",
    "l10n/app_en.arb": "59b383b51a9808e7e5514b77d7db55e232f12793f6f91e6f1ce1ae676e07de61",
    "l10n/app_es.arb": "1f8130fee1785858cd878acc768bc8b7a6e92760babbdf63e5ed6b14e41b8dd0",
    "l10n/app_fr.arb": "f37b21af04584bcac05cc932f30b4311628059b263ab76807b496fd9cfbf05a4",
    "l10n/app_it.arb": "01e53567f90955a8828d73355cb92e937dfdd8da50f7af2153ffc639356e36a7",
    "l10n/app_pt.arb": "b44a6f641f21c7300b7dfee4eeb91157ba67fd28487b65e5e885167963a0f462",
    "l10n/generated/mint_next_localizations.dart": "4fb82bcbeb91bfc814d8e773615cf972933b8810749271928ece466034056a13",
    "l10n/generated/mint_next_localizations_de.dart": "950543ea668b2370bd260d362508978a7443b6f5ca527adea8e3f708d01dc45e",
    "l10n/generated/mint_next_localizations_en.dart": "79c5382c4f1832e19ad78bd99223ac60f32c7f53475b381392e6b13303b48998",
    "l10n/generated/mint_next_localizations_es.dart": "e55a7388fa3528c1f4b45fb431ff91c6b8a737b051781cfa3e57b7f3842e4f99",
    "l10n/generated/mint_next_localizations_fr.dart": "d8453505d2b796f9b0e4d53b690b465e7b3b9cd3671dc2f6483937900440f639",
    "l10n/generated/mint_next_localizations_it.dart": "28f997c26dc66796b999aabe23aa8dc67aea440c85c5f45db2854e184e641e95",
    "l10n/generated/mint_next_localizations_pt.dart": "0873ec7c8617e7b84667b0d3ae47e0bca8df86eab296849a84e839279e797370",
    "main.dart": "5c8b1681e8997acde204ff7049204fb55aa9829d98c81dd065202992c85efd24",
    "multi_provider_amount_draft.dart": "6ec168f74f21d56703eb37498c3a5ac86a13d1911b01e1296832144d2849e6c7",
    "multi_provider_amount_editor.dart": "3f2bf5c29e678bc4a0dd8a0d7fba6365a4d0fd751ea9f93f548804a01019f145",
    "multi_provider_casefold_data.dart": "9acee5029f8b19b02c2fc87cc133a199efaf5aa8c9c5226f7ceaca870d5f2115",
    "multi_provider_default_ignorable_data.dart": "0f8bb0b187d94f0c5cfb56e1735f220541c5ed7a9238917a66c92aec799bec66",
    "multi_provider_label.dart": "f39f18d582dcec006422631710f1168d3fd582da1dc688bf330ca0f8c56757ac",
    "ordinary_chf_amount.dart": "43c9850e89d0696f98d11c1b6cdd295ab48aeb480149b8d5e60116fccf4b55be",
    "provider_label.dart": "06f3714e147660539e6eed40898f9f691a77b7fdaa50f7ca6ad7a44d36c3188a",
}
EXPECTED_AUX_INPUT_SHA256 = {
    "l10n.yaml": "0879c4e81347d78e3551434c75ad282aa818efe28ede77d63326dd8b8d4201be",
    "assets/fonts/Gambarino-Regular.otf": "3cfc8143b820d4e9e5970748cf6189d0624aeb1f8c5a0138c2c82bbb9b50efdf",
    "assets/fonts/LICENSE-GAMBARINO.txt": "c2fa18da766a12ef7a1750bc58268048ec01744669e99061494995ea93320e01",
    "assets/fonts/LICENSE-SUPREME.txt": "716d23ed97562988d3436b36c9a2f6a3876be064bafcebceea29b0a135768e03",
    "assets/fonts/Supreme-Bold.otf": "00ebce7fae218b2e28df0581652749e9cbc1d4a6a4221780541532362471d89a",
    "assets/fonts/Supreme-Medium.otf": "4771fa1237212a3eddb060814b2d721e47a79b9b3bf58451ac1b98c48dce58f9",
    "assets/fonts/Supreme-Regular.otf": "00410913847ad5e731e49da556a0c541aacfae84e6c998c5a3a6b4fca3b18ee4",
}
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
        candidate_end = subprocess.run(
            ["git", "log", "-1", "--format=%H", "HEAD", "--", *sorted(ALLOWED_DIFF_PATHS)],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.strip()
        _require(re.fullmatch(r"[0-9a-f]{40}", candidate_end) is not None, "cannot locate Batch19 RED candidate commit")
        committed = subprocess.run(
            ["git", "diff", "--name-only", f"{ANCHOR}..{candidate_end}"],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.splitlines()
    except subprocess.CalledProcessError as exc:
        raise GuardFailure("cannot inspect Batch19 git boundary") from exc
    changed = {
        path for path in committed
        if not path.startswith(".planning/journeys/path-owners/")
    }
    unexpected = changed - ALLOWED_DIFF_PATHS
    _require(not unexpected, f"Batch19 RED scope changed forbidden paths: {sorted(unexpected)}")


def validate(root: Path = REPO_ROOT, *, check_git: bool = True) -> None:
    for relative in (
        REGISTRY, SCOPE, COPY, TEST, FIXTURE, PUBSPEC, PUBSPEC_LOCK,
        L10N_CONFIG,
    ):
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
        r1.get("command") == [
            "flutter", "test", "test/design_lab_batch18_canton_r1_test.dart",
            "--machine", "--no-pub",
        ],
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
    _require(_sha(root / PUBSPEC) == EXPECTED_PUBSPEC_SHA256, "reviewed pubspec digest drifted")
    _require(
        _sha(root / PUBSPEC_LOCK) == EXPECTED_PUBSPEC_LOCK_SHA256,
        "reviewed pubspec lock digest drifted",
    )
    pubspec = _load(root / PUBSPEC)
    _require(
        set(pubspec.get("dependencies", {}))
        == {"characters", "flutter", "flutter_localizations", "intl", "unorm_dart"},
        "Design Lab dependency capability surface widened",
    )
    sources = {
        path.relative_to(root / LIB_ROOT).as_posix(): _sha(path)
        for path in sorted((root / LIB_ROOT).rglob("*"))
        if path.is_file() and not path.is_symlink()
    }
    _require(
        sources == EXPECTED_LIB_SOURCE_SHA256,
        "reviewed RED runtime source inventory or digest drifted",
    )
    design_lab = PUBSPEC.parent
    auxiliary = {"l10n.yaml": _sha(root / L10N_CONFIG)}
    auxiliary.update({
        path.relative_to(root / design_lab).as_posix(): _sha(path)
        for path in sorted((root / ASSETS_ROOT).rglob("*"))
        if path.is_file() and not path.is_symlink()
    })
    _require(
        auxiliary == EXPECTED_AUX_INPUT_SHA256,
        "reviewed RED auxiliary input inventory or digest drifted",
    )
    if check_git:
        _validate_diff_boundary(root)


def _run_candidate_command(root: Path, r1: dict) -> subprocess.CompletedProcess[str]:
    design_lab = PUBSPEC.parent
    with tempfile.TemporaryDirectory(prefix="mint-b19-r1-") as directory:
        isolated_root = Path(directory)
        isolated_lab = isolated_root / design_lab
        isolated_lab.mkdir(parents=True)
        for relative in (PUBSPEC, PUBSPEC_LOCK):
            target = isolated_root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / relative, target)
        for relative in (Path("l10n.yaml"),):
            shutil.copy2(root / design_lab / relative, isolated_lab / relative)
        shutil.copytree(root / LIB_ROOT, isolated_root / LIB_ROOT)
        shutil.copytree(root / design_lab / "assets", isolated_lab / "assets")
        for relative in (TEST, FIXTURE, REGISTRY):
            target = isolated_root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / relative, target)
        resolved = subprocess.run(
            ["flutter", "pub", "get", "--offline", "--enforce-lockfile"],
            cwd=isolated_lab,
            capture_output=True,
            text=True,
            timeout=120,
        )
        _require(
            resolved.returncode == 0,
            "R1 isolated dependency resolution failed",
        )
        return subprocess.run(
            r1["command"],
            cwd=isolated_lab,
            capture_output=True,
            text=True,
            timeout=120,
        )


def run_expected_red(root: Path = REPO_ROOT, *, check_git: bool = True) -> None:
    validate(root, check_git=check_git)
    registry = _load(root / REGISTRY)
    r1 = registry["gates"]["R1"]
    try:
        completed = _run_candidate_command(root, r1)
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
