#!/usr/bin/env python3
"""Fail closed on the accepted Batch16C GREEN runtime-navigation contract."""

from __future__ import annotations

import json
import hashlib
import re
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

import yaml


ACCEPTANCE = Path("product/mint_next/batch16/acceptance.yaml")
PARENT_CONTRACT = Path(
    "product/mint_next/batch13/multi-provider-navigation-contract.yaml"
)
SCOPE = Path("product/mint_next/batch16/classification-doubt-scope.yaml")
NAVIGATION = Path("product/mint_next/batch16/navigation.mmd")
MANIFEST = Path("product/mint_next/batch16/runtime-navigation-acceptance.yaml")
WIDGET_TEST = Path(
    "product/mint_next/batch7/design_lab/test/"
    "design_lab_batch16_unresolved_navigation_test.dart"
)
SEMANTIC_FIXTURE = Path("product/mint_next/batch16/six-locale-semantic-fixture.yaml")
OFFICIAL_SOURCES = Path("product/mint_next/batch16/official-sources.yaml")
GENERATED_SEMANTIC_FIXTURE = Path(
    "product/mint_next/batch7/design_lab/test/batch16_semantic_fixture.g.dart"
)
FUTURE_GUARD_TEST = Path(
    "tools/checks/tests/test_mint_next_batch16_classification_runtime_guard.py"
)
GUARD = Path("tools/checks/mint_next_batch16_runtime_guard.py")
GUARD_TESTS = Path(
    "tools/checks/tests/test_mint_next_batch16_runtime_guard.py"
)
LEFTHOOK = Path("lefthook.yml")
WORKFLOW = Path(".github/workflows/mint-next-batch16-runtime-acceptance.yml")
ANALYSIS_OPTIONS = Path("product/mint_next/batch7/design_lab/analysis_options.yaml")
DESIGN_LAB_LIB = Path("product/mint_next/batch7/design_lab/lib")
DESIGN_LAB_PUBSPEC = Path("product/mint_next/batch7/design_lab/pubspec.yaml")
RUNTIME_FILES = tuple(
    DESIGN_LAB_LIB / name
    for name in (
        "design_lab_app.dart",
        "main.dart",
        "multi_provider_amount_editor.dart",
        "multi_provider_amount_draft.dart",
        "multi_provider_casefold_data.dart",
        "multi_provider_default_ignorable_data.dart",
        "multi_provider_label.dart",
        "ordinary_chf_amount.dart",
        "provider_label.dart",
        "l10n/app_fr.arb",
        "l10n/app_en.arb",
        "l10n/app_de.arb",
        "l10n/app_it.arb",
        "l10n/app_es.arb",
        "l10n/app_pt.arb",
        "l10n/generated/mint_next_localizations.dart",
        "l10n/generated/mint_next_localizations_fr.dart",
        "l10n/generated/mint_next_localizations_en.dart",
        "l10n/generated/mint_next_localizations_de.dart",
        "l10n/generated/mint_next_localizations_it.dart",
        "l10n/generated/mint_next_localizations_es.dart",
        "l10n/generated/mint_next_localizations_pt.dart",
    )
)
REVIEWED_PAYLOAD_FILES = tuple(
    sorted(
        (
            *RUNTIME_FILES,
            ACCEPTANCE,
            PARENT_CONTRACT,
            WIDGET_TEST,
            SCOPE,
            NAVIGATION,
            SEMANTIC_FIXTURE,
            OFFICIAL_SOURCES,
        ),
        key=str,
    )
)

TRUST_HASHES = {
    "EXPECTED_BATCH16C_GREEN_GUARD_SHA256": GUARD,
    "EXPECTED_BATCH16C_GREEN_GUARD_TESTS_SHA256": GUARD_TESTS,
    "EXPECTED_BATCH16C_GREEN_MANIFEST_SHA256": MANIFEST,
    "EXPECTED_BATCH16C_GREEN_SCOPE_SHA256": SCOPE,
    "EXPECTED_BATCH16C_GREEN_NAVIGATION_SHA256": NAVIGATION,
    "EXPECTED_BATCH16C_GREEN_WIDGET_TEST_SHA256": WIDGET_TEST,
    "EXPECTED_BATCH16C_GREEN_SWISS_FIXTURE_SHA256": SEMANTIC_FIXTURE,
    "EXPECTED_BATCH16C_GREEN_OFFICIAL_SOURCES_SHA256": OFFICIAL_SOURCES,
    "EXPECTED_BATCH16C_GREEN_GENERATED_FIXTURE_SHA256": GENERATED_SEMANTIC_FIXTURE,
}

MAX_OFFICIAL_SOURCE_REVIEW_DAYS = 180
EXPECTED_DESIGN_APP_SHA256 = "95a795d2b68360365792da2966864be476ca00f6064a53637454cd686a2d812f"
EXPECTED_EDITOR_SHA256 = "3f2bf5c29e678bc4a0dd8a0d7fba6365a4d0fd751ea9f93f548804a01019f145"
EXPECTED_PUBLIC_MAIN = """import 'package:flutter/material.dart';

import 'design_lab_app.dart';

const _evidenceLocale = String.fromEnvironment('MINT_LAB_LOCALE');

void main() => runApp(
  MintNextDesignLabApp(
    locale: _evidenceLocale.isEmpty ? null : Locale(_evidenceLocale),
  ),
);
"""


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


def _reviewed_payload_sha256(root: Path) -> str:
    digest = hashlib.sha256()
    for relative in REVIEWED_PAYLOAD_FILES:
        digest.update(str(relative).encode("utf-8"))
        digest.update(b"\0")
        digest.update((root / relative).read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def _iso_date(value: object, label: str) -> date:
    try:
        return date.fromisoformat(str(value))
    except ValueError as exc:
        raise GuardFailure(f"invalid ISO date: {label}") from exc


def _iso_datetime(value: object, label: str) -> datetime:
    try:
        return datetime.fromisoformat(str(value))
    except ValueError as exc:
        raise GuardFailure(f"invalid ISO timestamp: {label}") from exc


def _normalized_workflow(source: str) -> str:
    for key in TRUST_HASHES:
        source, count = re.subn(
            rf"(?m)^(\s*{re.escape(key)}:\s*)[0-9a-f]{{64}}[ \t]*$",
            rf"\g<1><SHA256>",
            source,
        )
        _require(count == 1, f"workflow trust hash absent or malformed: {key}")
    return source


def _dart_code_only(source: str) -> str:
    """Preserve Dart code/newlines while blanking comments and string literals."""
    output = list(source)
    index = 0
    state = "code"
    quote = ""
    triple = False
    while index < len(source):
        char = source[index]
        pair = source[index : index + 2]
        if state == "code":
            if pair == "//":
                output[index] = output[index + 1] = " "
                state = "line_comment"
                index += 2
                continue
            if pair == "/*":
                output[index] = output[index + 1] = " "
                state = "block_comment"
                index += 2
                continue
            if char in ("'", '"'):
                quote = char
                triple = source[index : index + 3] == char * 3
                width = 3 if triple else 1
                for offset in range(width):
                    output[index + offset] = " "
                state = "string"
                index += width
                continue
        elif state == "line_comment":
            if char == "\n":
                state = "code"
            else:
                output[index] = " "
        elif state == "block_comment":
            if pair == "*/":
                output[index] = output[index + 1] = " "
                state = "code"
                index += 2
                continue
            if char != "\n":
                output[index] = " "
        else:
            if char == "\\" and not triple and index + 1 < len(source):
                output[index] = " "
                if source[index + 1] != "\n":
                    output[index + 1] = " "
                index += 2
                continue
            closing = quote * (3 if triple else 1)
            if source[index : index + len(closing)] == closing:
                for offset in range(len(closing)):
                    output[index + offset] = " "
                state = "code"
                index += len(closing)
                continue
            if char != "\n":
                output[index] = " "
        index += 1
    return "".join(output)


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


def validate(root: Path, *, require_accepted: bool = True) -> None:
    acceptance_path = root / ACCEPTANCE
    parent_contract_path = root / PARENT_CONTRACT
    scope_path = root / SCOPE
    navigation_path = root / NAVIGATION
    manifest_path = root / MANIFEST
    widget_path = root / WIDGET_TEST
    fixture_path = root / SEMANTIC_FIXTURE
    official_sources_path = root / OFFICIAL_SOURCES
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
        parent_contract_path,
        scope_path,
        navigation_path,
        manifest_path,
        widget_path,
        fixture_path,
        official_sources_path,
        generated_fixture_path,
        guard_path,
        guard_tests_path,
        lefthook_path,
        workflow_path,
        analysis_options_path,
        pubspec_path,
    ):
        _require(path.is_file(), f"missing GREEN acceptance artifact: {path.relative_to(root)}")

    acceptance = _load(acceptance_path)
    scope = _load(scope_path)
    _require(
        scope["authority"]["parent_contract"] == str(PARENT_CONTRACT),
        "scope parent contract path drifted",
    )
    _require(
        scope["authority"]["parent_contract_sha256"]
        == _sha256(parent_contract_path),
        "scope parent contract digest drifted",
    )
    manifest = _load(manifest_path)
    source = widget_path.read_text(encoding="utf-8")
    main_source = (design_lab_lib / "main.dart").read_text(encoding="utf-8")
    app_source = (design_lab_lib / "design_lab_app.dart").read_text(encoding="utf-8")
    editor_source = (design_lab_lib / "multi_provider_amount_editor.dart").read_text(
        encoding="utf-8"
    )
    fixture = _load(fixture_path)
    official_sources = _load(official_sources_path)
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
        "canonical_platform_learning_disabled": "privacy_and_lifecycle.local_inputs.disable_platform_learning_and_suggestions",
        "canonical_swiss_intents_rendered": "six_locale_semantic_contract.every_locale_must_render_every_reviewed_intent",
        "canonical_refund_subtotal_live": "accessibility.refund_subtotal_polite_live_announcement",
        "canonical_system_back_complete": "navigation.system_back.every_rendered_node_has_explicit_edge",
        "canonical_rules_disclosure_mapped": "navigation.unresolved_help_rules_disclosure.same_origin_no_mutation",
        "canonical_compact_first_choice_discoverable": "required_runtime_proofs.layout_and_semantics.first_choice_visible_at_320_text2_keyboard_without_scroll",
        "canonical_destructive_correction_warning": "navigation.contribution_status_correction.no_or_unknown_announces_irreversible_local_purge",
        "canonical_compact_header_no_overflow": "required_runtime_proofs.layout_and_semantics.320_width_six_locales_have_no_header_overflow_and_contextual_safe_exit",
        "canonical_text_scaling_preserved": "required_runtime_proofs.layout_and_semantics.text_scale_2_preserves_base_typography_and_at_least_doubles_effective_help_and_correction_heading_sizes",
        "canonical_correction_question_first": "required_runtime_proofs.layout_and_semantics.correction_question_intersects_the_initial_320_viewport_before_warning_and_actions_at_text_scale_1_and_2",
    }
    runtime_manifest_keys = [
        key for key in scope if str(key).startswith("runtime_manifest_at_head_")
    ]
    _require(len(runtime_manifest_keys) == 1, "scope runtime manifest identity drifted")
    scoped_runtime = scope[runtime_manifest_keys[0]]
    _require(
        "unresolved_help_rules_disclosure"
        in scoped_runtime["batch16_new_rendered_controls"],
        "rules disclosure is absent from the written control inventory",
    )
    _require(
        "full_correction_question_with_selected_tax_year_first_in_scroll_order"
        in scoped_runtime["rendered_existing_correction_boundary_controls"],
        "full correction question is absent from the written controls",
    )
    _require(
        "destructive_purge_warning_for_no_and_unknown"
        in scoped_runtime["rendered_existing_correction_boundary_controls"],
        "destructive correction warning is absent from the written controls",
    )
    _require(
        scope["accessibility"]["help_action_order"]
        == [
            "provider_total_obtained",
            "one_provider_refunded_when_guard_true",
            "all_providers_zero",
            "education",
            "rules_disclosure",
            "back",
            "safe_exit",
        ],
        "written help action order drifted",
    )
    _require(
        scope["privacy_and_lifecycle"]["ttl_semantics"]
        == {
            "duration": "30_minutes",
            "mode": "sliding_since_last_pointer_or_keyboard_activity",
            "activity_resets_deadline_without_persisting_or_logging": True,
        },
        "written TTL semantics drifted",
    )
    navigation_source = navigation_path.read_text(encoding="utf-8")
    for edge in (
        "Help_Unresolved --> Help_Unresolved: Voir / masquer les règles",
        "avertissement visible; effacement irréversible annoncé",
    ):
        _require(edge in navigation_source, f"written navigation edge absent: {edge}")

    status_pair = (
        manifest["status"],
        manifest["acceptance_boundary"]["hidden_batch16_runtime"],
    )
    allowed_status_pairs = {
        ("candidate_hidden_runtime", "candidate"),
        ("accepted_hidden_runtime", "accepted"),
    }
    _require(status_pair in allowed_status_pairs, "GREEN runtime acceptance status drifted")
    if require_accepted:
        _require(
            status_pair == ("accepted_hidden_runtime", "accepted"),
            "GREEN runtime is still a candidate",
        )
    if status_pair == ("accepted_hidden_runtime", "accepted"):
        expected_receipt_scopes = {
            "batch16_green_ux_roast": "ux_navigation_accessibility",
            "batch16_green_swiss_privacy_roast": "swiss_privacy_provenance",
            "batch16c_final_ux_roast": "adversarial_final_mechanical",
        }
        receipts = manifest.get("roast_receipts")
        reviewed_payload_sha256 = _reviewed_payload_sha256(root)
        _require(
            isinstance(receipts, list) and len(receipts) == 3,
            "accepted runtime roast receipt inventory drifted",
        )
        receipt_by_reviewer = {receipt.get("reviewer"): receipt for receipt in receipts}
        _require(
            len(receipt_by_reviewer) == 3
            and set(receipt_by_reviewer) == set(expected_receipt_scopes),
            "accepted runtime roast reviewer inventory drifted",
        )
        for reviewer, expected_scope in expected_receipt_scopes.items():
            receipt = receipt_by_reviewer[reviewer]
            _require(
                set(receipt)
                == {
                    "reviewer",
                    "scope",
                    "verdict",
                    "reviewed_on",
                    "reviewed_payload_sha256",
                    "severity_counts",
                }
                and receipt["scope"] == expected_scope
                and receipt["verdict"] == "ACCEPT"
                and receipt["reviewed_on"] == "2026-08-03"
                and receipt["reviewed_payload_sha256"] == reviewed_payload_sha256
                and receipt["severity_counts"] == {"P1": 0, "P2": 0, "P3": 0},
                f"accepted runtime roast receipt is not unanimous zero: {reviewer}",
            )
    _require(manifest["runtime_surface"] == "batch16_harness", "GREEN hidden runtime surface drifted")
    _require(manifest["contract_ref"] == str(SCOPE), "GREEN scope linkage drifted")
    _require(manifest["navigation_ref"] == str(NAVIGATION), "GREEN navigation linkage drifted")
    _require(manifest["product_promotion"] == "forbidden", "GREEN hidden runtime promoted product")
    expected_runtime_files = {str(path) for path in RUNTIME_FILES}
    actual_runtime_files = {
        str(path.relative_to(root))
        for path in design_lab_lib.rglob("*")
        if path.is_file()
    }
    _require(
        actual_runtime_files == expected_runtime_files,
        "GREEN runtime library inventory drifted",
    )
    runtime_hashes = manifest["runtime_files_sha256"]
    _require(set(runtime_hashes) == expected_runtime_files, "GREEN runtime hash inventory drifted")
    for relative, expected_hash in runtime_hashes.items():
        runtime_path = root / relative
        _require(runtime_path.is_file(), f"GREEN runtime file missing: {relative}")
        _require(_sha256(runtime_path) == expected_hash, f"GREEN runtime file drifted: {relative}")
    _require(manifest["test_file"] == str(WIDGET_TEST), "GREEN widget test path drifted")
    _require(
        manifest["six_locale_semantic_fixture"] == str(SEMANTIC_FIXTURE),
        "six-locale semantic fixture path drifted",
    )
    _require(
        manifest["official_sources"] == str(OFFICIAL_SOURCES),
        "official source registry path drifted",
    )
    _require(
        manifest["green_proof_commands"]
        == [
            "cd product/mint_next/batch7/design_lab && flutter analyze",
            "cd product/mint_next/batch7/design_lab && flutter test test/design_lab_batch16_unresolved_navigation_test.dart",
            "cd product/mint_next/batch7/design_lab && flutter test",
        ],
        "GREEN proof commands drifted",
    )
    _require(
        set(proofs) == set(planned) | set(canonical_requirements),
        "proof map narrowed the accepted registry or broader canonical obligations",
    )

    widget_names: set[str] = set()
    future_ids: set[str] = set()
    static_guard_ids: set[str] = set()
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
        elif proof_type == "static_guard":
            static_guard_ids.add(proof_id)
            _require(
                proof["guard_file"] == str(GUARD),
                f"static guard path drifted: {proof_id}",
            )
            anchors = proof["assertion_anchors"]
            guard_source = guard_path.read_text(encoding="utf-8")
            _require(
                isinstance(anchors, list) and len(anchors) >= 3,
                f"weak static guard anchor inventory: {proof_id}",
            )
            for anchor in anchors:
                _require(
                    anchor in guard_source,
                    f"missing static guard anchor for {proof_id}: {anchor}",
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
    _require(
        static_guard_ids == {"canonical_privacy_no_outputs"},
        "static guard proof allocation drifted",
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
        _require(symbol in source, f"expected GREEN API obligation absent: {symbol}")
    _require(
        main_source == EXPECTED_PUBLIC_MAIN,
        "GREEN hidden runtime promoted through public entrypoint",
    )
    app_code = _dart_code_only(app_source)
    constructors = re.findall(
        r"(?m)^\s*const MintNextDesignLabApp(\.batch14Harness|\.batch16Harness)?\s*\(\{",
        app_code,
    )
    _require(
        constructors == ["", ".batch14Harness", ".batch16Harness"],
        "GREEN Batch16 constructor inventory drifted",
    )
    flag_lines = [
        line.strip()
        for line in app_code.splitlines()
        if "enableBatch14MultiProvider" in line
        or "enableBatch16Unresolved" in line
        or "enableBatch16:" in line
    ]
    _require(
        flag_lines
        == [
            "}) : _enableBatch14MultiProvider = false,",
            "_enableBatch16Unresolved = false,",
            "}) : _enableBatch14MultiProvider = true,",
            "_enableBatch16Unresolved = false,",
            "}) : _enableBatch14MultiProvider = true,",
            "_enableBatch16Unresolved = true;",
            "final bool _enableBatch14MultiProvider;",
            "final bool _enableBatch16Unresolved;",
            "enableBatch14MultiProvider: _enableBatch14MultiProvider,",
            "enableBatch16Unresolved: _enableBatch16Unresolved,",
            "required this.enableBatch14MultiProvider,",
            "required this.enableBatch16Unresolved,",
            "final bool enableBatch14MultiProvider;",
            "final bool enableBatch16Unresolved;",
            "if (!widget.enableBatch16Unresolved) return;",
            "if (!mounted || !widget.enableBatch16Unresolved) return;",
            "_DesignNode.factContributedAmount when widget.enableBatch16Unresolved =>",
            "if (widget.enableBatch14MultiProvider) {",
            "if (widget.enableBatch16Unresolved &&",
            "if (widget.enableBatch14MultiProvider &&",
            "widget.enableBatch14MultiProvider",
            "enableBatch16:",
            "widget.enableBatch16Unresolved,",
        ],
        "GREEN Batch16 flag dataflow drifted",
    )
    editor_code = _dart_code_only(editor_source)
    editor_flag_lines = [
        line.strip()
        for line in editor_code.splitlines()
        if "enableBatch16" in line
    ]
    _require(
        editor_flag_lines
        == [
            "this.enableBatch16 = false,",
            "final bool enableBatch16;",
            "if (widget.enableBatch16) ...[",
        ],
        "GREEN Batch16 editor consumer dataflow drifted",
    )
    _require(
        _sha256(design_lab_lib / "design_lab_app.dart")
        == EXPECTED_DESIGN_APP_SHA256
        and _sha256(design_lab_lib / "multi_provider_amount_editor.dart")
        == EXPECTED_EDITOR_SHA256,
        "GREEN canonical Batch16 route source drifted",
    )

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
    expected_fixture_status = (
        "reviewed_for_hidden_runtime"
        if status_pair == ("accepted_hidden_runtime", "accepted")
        else "candidate_for_swiss_roast"
    )
    _require(
        fixture["status"] == expected_fixture_status,
        "semantic fixture review status does not match runtime acceptance",
    )
    expected_source_ids = {
        "estv_circular_18a",
        "estv_form_21_edp_notice",
        "estv_form_21_edp_2026",
        "ofas_your_third_pillar_contribution",
    }
    _require(
        set(official_sources)
        == {
            "schema_version",
            "checked_at",
            "retrieved_at",
            "review_due_at",
            "jurisdiction",
            "scope",
            "reused_from",
            "sources",
            "review_boundaries",
        },
        "official source registry schema drifted",
    )
    _require(
        official_sources["jurisdiction"] == "CH"
        and official_sources["scope"] == "batch16_ordinary_3a_classification_help",
        "official source jurisdiction or scope drifted",
    )
    _require(
        official_sources["review_boundaries"]
        == {
            "official_sources_support": [
                "provider_scoped_annual_attestation_and_ordinary_total",
                "actual_credit_timing_for_selected_tax_year",
                "separation_of_transfer_retroactive_buyback_refund_and_ordinary_contribution",
                "insurance_and_bank_foundations_are_both_in_scope",
            ],
            "product_safety_inferences_not_direct_official_quotes": [
                "a_full_refund_at_one_provider_does_not_prove_every_provider_is_zero",
                "mint_does_not_verify_user_input_in_this_local_harness",
                "this_collection_step_returns_no_tax_result_or_recommendation",
            ],
            "not_authorized": [
                "tax_result",
                "tax_saving_or_deduction",
                "recommendation",
                "provider_import_scan_ocr_or_api",
                "persistence_logging_or_network_output",
            ],
        },
        "official source review boundaries drifted",
    )
    checked_at = _iso_date(official_sources["checked_at"], "checked_at")
    retrieved_at = _iso_datetime(
        official_sources["retrieved_at"], "retrieved_at"
    )
    _require(
        retrieved_at.tzinfo is not None,
        "official source retrieval timestamp lacks timezone",
    )
    review_due = _iso_date(official_sources["review_due_at"], "review_due_at")
    _require(
        retrieved_at.date() <= checked_at <= review_due,
        "official source dates are not ordered",
    )
    _require(
        retrieved_at <= datetime.now(tz=retrieved_at.tzinfo),
        "official source retrieval is future-dated",
    )
    _require(checked_at <= date.today(), "official source check is future-dated")
    _require(review_due >= date.today(), "official source review is stale")
    _require(
        review_due <= checked_at + timedelta(days=MAX_OFFICIAL_SOURCE_REVIEW_DAYS),
        "official source review horizon exceeds 180 days",
    )
    source_by_id = {item["id"]: item for item in official_sources["sources"]}
    _require(
        len(source_by_id) == len(official_sources["sources"])
        and set(source_by_id) == expected_source_ids,
        "official source identity inventory drifted",
    )
    for source_id, item in source_by_id.items():
        _require(
            set(item)
            == {
                "id",
                "authority",
                "title",
                "url",
                "version",
                "effective_from",
                "anchors",
            },
            f"official source schema drifted: {source_id}",
        )
        _require(
            str(item["url"]).startswith(
                ("https://www.estv.admin.ch/", "https://www.bsv.admin.ch/")
            ),
            f"non-official source domain: {source_id}",
        )
        _require(
            all(str(item[key]).strip() for key in ("authority", "title", "version"))
            and _iso_date(item["effective_from"], f"{source_id}.effective_from")
            <= review_due
            and isinstance(item["anchors"], list)
            and item["anchors"],
            f"official source metadata incomplete: {source_id}",
        )
    provenance = fixture["provenance"]
    _require(
        provenance
        == {
            "registry": str(OFFICIAL_SOURCES),
            "checked_at": official_sources["checked_at"],
            "retrieved_at": official_sources["retrieved_at"],
            "review_due_at": official_sources["review_due_at"],
            "jurisdiction": "CH",
        },
        "semantic fixture provenance drifted from official registry",
    )
    intent_provenance = fixture["intent_provenance"]
    _require(
        set(intent_provenance) == expected_intents,
        "intent provenance does not cover the exact semantic inventory",
    )
    inferred_intents = {
        "batch16RefundVsAllZeroMeaning",
        "batch16MintNotVerifiedMeaning",
        "batch16NoTaxAdviceMeaning",
    }
    for intent, linkage in intent_provenance.items():
        expected_keys = {"source_ids", "classification"} if intent in inferred_intents else {"source_ids"}
        _require(set(linkage) == expected_keys, f"intent provenance schema drifted: {intent}")
        source_ids = linkage["source_ids"]
        _require(
            isinstance(source_ids, list)
            and source_ids
            and len(source_ids) == len(set(source_ids))
            and set(source_ids) <= expected_source_ids,
            f"intent source linkage invalid: {intent}",
        )
        if intent in inferred_intents:
            _require(
                linkage["classification"]
                == "product_safety_inference_not_direct_official_quote",
                f"product safety inference masquerades as official fact: {intent}",
            )
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
        "mint-next-batch16-runtime-guard:\n"
        "      run: python3 tools/checks/mint_next_batch16_runtime_guard.py"
    )
    _require(lefthook_command in lefthook_source, "Lefthook GREEN guard binding drifted")
    for command in (
        "python3 tools/checks/mint_next_batch16_runtime_guard.py",
        "python3 -m unittest tools.checks.tests.test_mint_next_batch16_runtime_guard",
    ):
        _require(command in workflow_source, f"CI GREEN guard command absent: {command}")
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
        "test/design_lab_batch16_unresolved_navigation_test.dart"
        not in (analysis_options.get("analyzer", {}).get("exclude") or []),
        "Batch16 GREEN test remains excluded from analyzer",
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
        print(f"FAIL mint_next_batch16_runtime_guard: {exc}", file=sys.stderr)
        return 1
    print("OK mint_next_batch16_runtime_guard: mapped obligations, isolated privacy boundary, and hidden GREEN runtime acceptance are coherent.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
