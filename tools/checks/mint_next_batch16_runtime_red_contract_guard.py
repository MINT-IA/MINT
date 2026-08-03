#!/usr/bin/env python3
"""Fail closed on the candidate Batch16C RED runtime-navigation contract."""

from __future__ import annotations

import json
import hashlib
import re
import sys
from pathlib import Path

import yaml


ACCEPTANCE = Path("product/mint_next/batch16/acceptance.yaml")
MANIFEST = Path("product/mint_next/batch16/runtime-navigation-red.yaml")
WIDGET_TEST = Path(
    "product/mint_next/batch7/design_lab/test/"
    "design_lab_batch16_unresolved_navigation_test.dart"
)
SEMANTIC_FIXTURE = Path("product/mint_next/batch16/six-locale-semantic-fixture.yaml")
GENERATED_SEMANTIC_FIXTURE = Path(
    "product/mint_next/batch7/design_lab/test/batch16_semantic_fixture.g.dart"
)
FUTURE_GUARD_TEST = Path(
    "tools/checks/tests/test_mint_next_batch16_classification_runtime_guard.py"
)
GUARD = Path("tools/checks/mint_next_batch16_runtime_red_contract_guard.py")
GUARD_TESTS = Path(
    "tools/checks/tests/test_mint_next_batch16_runtime_red_contract_guard.py"
)
LEFTHOOK = Path("lefthook.yml")
WORKFLOW = Path(".github/workflows/mint-next-batch16-red-contract.yml")
ANALYSIS_OPTIONS = Path("product/mint_next/batch7/design_lab/analysis_options.yaml")
DESIGN_LAB_LIB = Path("product/mint_next/batch7/design_lab/lib")
DESIGN_LAB_PUBSPEC = Path("product/mint_next/batch7/design_lab/pubspec.yaml")

TRUST_HASHES = {
    "EXPECTED_BATCH16C_RED_GUARD_SHA256": GUARD,
    "EXPECTED_BATCH16C_RED_GUARD_TESTS_SHA256": GUARD_TESTS,
    "EXPECTED_BATCH16C_RED_MANIFEST_SHA256": MANIFEST,
    "EXPECTED_BATCH16C_RED_WIDGET_TEST_SHA256": WIDGET_TEST,
    "EXPECTED_BATCH16C_RED_SWISS_FIXTURE_SHA256": SEMANTIC_FIXTURE,
    "EXPECTED_BATCH16C_RED_GENERATED_FIXTURE_SHA256": GENERATED_SEMANTIC_FIXTURE,
}


class GuardFailure(RuntimeError):
    pass


class UniqueKeyLoader(yaml.SafeLoader):
    pass


def _construct_unique_mapping(
    loader: UniqueKeyLoader,
    node: yaml.MappingNode,
    deep: bool = False,
) -> dict:
    result: dict = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise GuardFailure(f"duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    _construct_unique_mapping,
)


def _load(path: Path) -> dict:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueKeyLoader)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GuardFailure(message)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _normalized_workflow(source: str) -> str:
    for key in TRUST_HASHES:
        source, count = re.subn(
            rf"(?m)^(\s*{re.escape(key)}:\s*)[0-9a-f]{{64}}[ \t]*$",
            rf"\g<1><SHA256>",
            source,
        )
        _require(count == 1, f"workflow trust hash absent or malformed: {key}")
    return source


def _expected_generated_fixture(fixture: dict) -> str:
    lines = [
        "// GENERATED from product/mint_next/batch16/six-locale-semantic-fixture.yaml.",
        "// Do not edit by hand.",
        "const batch16SemanticFixture = <String, Map<String, String>>{",
    ]
    for locale in ("fr", "en", "de", "it", "es", "pt"):
        lines.append(f"  {json.dumps(locale)}: <String, String>{{")
        for intent, translations in fixture["intents"].items():
            lines.append(
                f"    {json.dumps(intent)}: "
                f"{json.dumps(translations[locale], ensure_ascii=False)},"
            )
        lines.append("  },")
    lines.append("};")
    return "\n".join(lines) + "\n"


def _test_segment(source: str, name: str) -> str:
    token = f"testWidgets('{name}"
    start = source.find(token)
    _require(start >= 0, f"mapped widget test is absent: {name}")
    candidates = [
        index
        for marker in ("\n  testWidgets('", "\n  for (final language")
        if (index := source.find(marker, start + len(token))) >= 0
    ]
    end = min(candidates) if candidates else len(source)
    return source[start:end]


def validate(root: Path) -> None:
    acceptance_path = root / ACCEPTANCE
    manifest_path = root / MANIFEST
    widget_path = root / WIDGET_TEST
    fixture_path = root / SEMANTIC_FIXTURE
    generated_fixture_path = root / GENERATED_SEMANTIC_FIXTURE
    guard_path = root / GUARD
    guard_tests_path = root / GUARD_TESTS
    lefthook_path = root / LEFTHOOK
    workflow_path = root / WORKFLOW
    analysis_options_path = root / ANALYSIS_OPTIONS
    design_lab_lib = root / DESIGN_LAB_LIB
    pubspec_path = root / DESIGN_LAB_PUBSPEC
    for path in (
        acceptance_path,
        manifest_path,
        widget_path,
        fixture_path,
        generated_fixture_path,
        guard_path,
        guard_tests_path,
        lefthook_path,
        workflow_path,
        analysis_options_path,
        pubspec_path,
    ):
        _require(path.is_file(), f"missing RED contract artifact: {path.relative_to(root)}")

    acceptance = _load(acceptance_path)
    manifest = _load(manifest_path)
    source = widget_path.read_text(encoding="utf-8")
    fixture = _load(fixture_path)
    lefthook_source = lefthook_path.read_text(encoding="utf-8")
    workflow_source = workflow_path.read_text(encoding="utf-8")
    analysis_options = _load(analysis_options_path)
    pubspec = _load(pubspec_path)
    planned = acceptance["mechanical_binding"]["runtime_hostile_mutations_planned"]
    proofs = manifest["proof_map"]
    canonical_requirements = {
        "canonical_correction_safe_exit_complete": "required_runtime_proofs.complete_navigation.correction_safe_exit_cancel_resume_system_back_and_leave_have_exact_focus_and_purge",
        "canonical_tax_year_purge_callbacks": "required_runtime_proofs.identity_and_hostility.year_leave_status_and_ttl_purge_neutralize_all_callbacks.tax_year",
        "canonical_ttl_app_lifecycle_purge_callbacks": "required_runtime_proofs.identity_and_hostility.year_leave_status_and_ttl_purge_neutralize_all_callbacks.ttl_app_kill",
        "canonical_all_confirmed_full_matrix": "navigation.Editor_AllConfirmed.all_reversible_exits",
        "canonical_three_rows_exact_origin": "required_runtime_proofs.identity_and_hostility.three_rows_exact_origin_round_trip_never_first_row_fallback",
        "canonical_all_confirmed_canton_and_exit": "navigation.Editor_AllConfirmed.complete_canton_and_safe_exit_edges",
        "canonical_mixed_editor_safe_exit": "navigation.Editor_RowsMixed.complete_safe_exit_edges",
        "canonical_accessibility_complete": "required_runtime_proofs.layout_and_semantics.screen_reader_named_row_doubt_error_help_heading_subtotal_and_focus_return",
        "canonical_privacy_no_outputs": "privacy_and_lifecycle.persistence_network_analytics_crash_breadcrumbs.forbidden",
        "canonical_swiss_intents_rendered": "six_locale_semantic_contract.every_locale_must_render_every_reviewed_intent",
        "canonical_refund_subtotal_live": "accessibility.refund_subtotal_polite_live_announcement",
    }

    _require(
        manifest["status"] == "red_candidate_runtime_forbidden",
        "RED status overclaims a commit or runtime acceptance",
    )
    _require(manifest["runtime_surface"] == "none", "RED candidate exposed runtime")
    _require(manifest["product_promotion"] == "forbidden", "RED candidate promoted product")
    _require(manifest["test_file"] == str(WIDGET_TEST), "RED widget test path drifted")
    _require(
        manifest["six_locale_semantic_fixture"] == str(SEMANTIC_FIXTURE),
        "six-locale semantic fixture path drifted",
    )
    _require(
        manifest["expected_red_reason"]
        == [
            "MintNextDesignLabApp.batch16Harness_missing",
            "batch16_six_locale_semantic_getters_missing",
        ],
        "RED reasons are not the exact observed compile boundary",
    )
    _require(
        set(proofs) == set(planned) | set(canonical_requirements),
        "proof map narrowed the accepted registry or broader canonical obligations",
    )

    widget_names: set[str] = set()
    future_ids: set[str] = set()
    for proof_id, proof in proofs.items():
        if proof_id in planned:
            _require(
                proof["planned_test_name"] == planned[proof_id],
                f"planned hostile name drifted: {proof_id}",
            )
        else:
            _require(
                proof["canonical_requirement"] == canonical_requirements[proof_id],
                f"canonical requirement drifted: {proof_id}",
            )
        proof_type = proof["type"]
        if proof_type == "widget_runtime":
            _require(proof["file"] == str(WIDGET_TEST), f"wrong widget proof file: {proof_id}")
            test_name = proof["test_name"]
            widget_names.add(test_name)
            segment = _test_segment(source, test_name)
            _require("skip:" not in segment, f"mapped widget test is skipped: {test_name}")
            anchors = proof["assertion_anchors"]
            _require(isinstance(anchors, list) and len(anchors) >= 3, f"weak anchor inventory: {proof_id}")
            for anchor in anchors:
                _require(anchor in segment, f"missing assertion anchor for {proof_id}: {anchor}")
        elif proof_type == "future_hostile_guard":
            future_ids.add(proof_id)
            _require(
                proof["guard_file"] == str(FUTURE_GUARD_TEST),
                f"future hostile guard path drifted: {proof_id}",
            )
        else:
            raise GuardFailure(f"unknown proof type for {proof_id}: {proof_type}")

    _require(
        future_ids
        == {
            "parent_purge_narrowed",
            "parent_error_order_reordered",
            "runtime_test_skipped_or_commented",
            "lefthook_binding_removed",
            "ci_binding_removed",
            "hidden_harness_limit_changed",
        },
        "guard-only proof allocation drifted",
    )
    executable_names = set(re.findall(r"testWidgets\('([^']+)'", source))
    executable_names = {name.replace("$language", "") for name in executable_names}
    _require(
        set(manifest["atomic_scenarios"]) == executable_names,
        "atomic scenario inventory is not the exact executable widget set",
    )
    _require(widget_names <= executable_names, "mapped widget proof is not executable")
    for symbol in (
        "MintNextDesignLabApp.batch16Harness",
        "batch16AnnualOrdinaryTotalMeaning",
        "batch16ActuallyCreditedMeaning",
        "batch16ExcludedMovementsMeaning",
        "batch16ProviderConfirmedNetMeaning",
        "batch16InsuranceCertificateMeaning",
        "batch16RefundVsAllZeroMeaning",
        "batch16MintNotVerifiedMeaning",
        "batch16NoTaxAdviceMeaning",
    ):
        _require(symbol in source, f"expected RED API obligation absent: {symbol}")

    expected_intents = {
        "batch16AnnualOrdinaryTotalMeaning",
        "batch16ActuallyCreditedMeaning",
        "batch16ExcludedMovementsMeaning",
        "batch16ProviderConfirmedNetMeaning",
        "batch16InsuranceCertificateMeaning",
        "batch16RefundVsAllZeroMeaning",
        "batch16MintNotVerifiedMeaning",
        "batch16NoTaxAdviceMeaning",
    }
    _require(fixture["status"] == "candidate_for_swiss_roast", "semantic fixture overclaims acceptance")
    _require(set(fixture["intents"]) == expected_intents, "Swiss semantic intent inventory drifted")
    locales = {"fr", "en", "de", "it", "es", "pt"}
    for intent, translations in fixture["intents"].items():
        _require(set(translations) == locales, f"six-locale coverage drifted: {intent}")
        _require(len(set(translations.values())) == 6, f"locale copies collapsed: {intent}")
        for locale, value in translations.items():
            _require(value.strip() and "@@" not in value, f"invalid reviewed copy: {intent}/{locale}")
            if "{taxYear}" in value:
                _require(
                    intent == "batch16ActuallyCreditedMeaning",
                    f"unexpected placeholder: {intent}/{locale}",
                )
    _require(
        generated_fixture_path.read_text(encoding="utf-8")
        == _expected_generated_fixture(fixture),
        "generated Dart semantic fixture drifted from reviewed YAML",
    )
    _require(
        "batch16SemanticFixture[language]" in source
        and "replaceAll('{taxYear}', '2026')" in source,
        "runtime getter values are not compared with the reviewed fixture",
    )

    binding = manifest["mechanical_binding"]
    lefthook_command = (
        "mint-next-batch16-runtime-red-contract-guard:\n"
        "      run: python3 tools/checks/mint_next_batch16_runtime_red_contract_guard.py"
    )
    _require(lefthook_command in lefthook_source, "Lefthook RED guard binding drifted")
    for command in (
        "python3 tools/checks/mint_next_batch16_runtime_red_contract_guard.py",
        "python3 -m unittest tools.checks.tests.test_mint_next_batch16_runtime_red_contract_guard",
    ):
        _require(command in workflow_source, f"CI RED guard command absent: {command}")
    for variable, relative in TRUST_HASHES.items():
        expected = _sha256(root / relative)
        _require(
            re.search(rf"(?m)^\s*{re.escape(variable)}:\s*{expected}\s*$", workflow_source)
            is not None,
            f"CI trust hash drifted: {variable}",
        )
    normalized_hash = hashlib.sha256(
        _normalized_workflow(workflow_source).encode("utf-8")
    ).hexdigest()
    _require(
        binding["normalized_ci_workflow_sha256"] == normalized_hash,
        "normalized CI workflow hash drifted",
    )
    _require(
        analysis_options.get("analyzer", {}).get("exclude")
        == ["test/design_lab_batch16_unresolved_navigation_test.dart"],
        "intentional RED analyzer exclusion is absent or broader than one exact test",
    )
    _require(design_lab_lib.is_dir(), "isolated Design Lab lib is absent")
    _require(
        set(pubspec["dependencies"])
        == {"characters", "flutter", "flutter_localizations", "intl", "unorm_dart"},
        "Design Lab dependency boundary gained an unreviewed output capability",
    )
    forbidden_output_tokens = (
        "dart:io",
        "dart:ffi",
        "dart:html",
        "dart:js",
        "dart:js_interop",
        "dart:isolate",
        "package:web",
        "package:http",
        "package:dio",
        "firebase_",
        "package:sentry",
        "package:firebase_analytics",
        "shared_preferences",
        "sqflite",
        "package:hive",
        "path_provider",
        "url_launcher",
        "MethodChannel",
        "EventChannel",
        "BasicMessageChannel",
        "BinaryMessenger",
        "defaultBinaryMessenger",
        "SystemChannels",
        "PlatformMessage",
        "SendPort",
        "ReceivePort",
        "Clipboard.setData",
        "debugPrint",
        "print(",
        "dart:developer",
        ".logEvent(",
        "Image.network",
        "NetworkImage",
        "NetworkAssetBundle",
        "FadeInImage",
        "AndroidView",
        "UiKitView",
        "AppKitView",
        "PlatformViewLink",
        "PlatformViewSurface",
        "HtmlElementView",
        "creationParams",
        "SystemNavigator",
        "SystemChrome",
        "Restoration",
        "Restorable",
        "FlutterError.reportError",
        "FlutterErrorDetails(",
        "throwWithStackTrace",
        "handleUncaughtError",
        "ProcessTextService",
        "SpellCheckService",
        "AutofillGroup",
        "AutofillContextAction",
        "autofillHints",
        "finishAutofillContext",
    )
    for dart_file in design_lab_lib.rglob("*.dart"):
        dart_source = dart_file.read_text(encoding="utf-8").lower()
        dart_source = re.sub(r"/\*.*?\*/", "", dart_source, flags=re.DOTALL)
        dart_source = re.sub(r"//[^\n]*", "", dart_source)
        compact_source = re.sub(r"\s+", "", dart_source)
        for token in forbidden_output_tokens:
            _require(
                re.sub(r"\s+", "", token.lower()) not in compact_source,
                f"forbidden output capability in isolated Design Lab: {dart_file.relative_to(root)}: {token}",
            )


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    try:
        validate(root)
    except (GuardFailure, KeyError, TypeError, yaml.YAMLError) as exc:
        print(f"FAIL mint_next_batch16_runtime_red_contract_guard: {exc}", file=sys.stderr)
        return 1
    print("OK mint_next_batch16_runtime_red_contract_guard: 34 accepted and 11 canonical obligations are mapped; runtime remains RED and forbidden.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
