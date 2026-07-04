#!/usr/bin/env python3
"""Extract the Mint 2.0 variable-contract coverage snapshot.

This checker is intentionally read-only. It binds existing sources together so
future PRs can detect drift before adding a runtime dictionary scaffold.
"""

from __future__ import annotations

import argparse
import ast
import json
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any

CHECK_DATE = date(2026, 6, 15)
EXPECTED = {
    ("profile", "ProfileBase_count"): 39,
    ("profile", "ProfileUpdate_count"): 42,
    ("profile", "ProfileUpdate_only"): [
        "householdGrossIncome",
        "spouseEmploymentStatus",
        "spouseSalaryGrossAnnual",
    ],
    ("profile_contract", "write_only"): [
        "householdGrossIncome",
        "spouseEmploymentStatus",
        "spouseSalaryGrossAnnual",
    ],
    ("profile_contract", "derived_mobile"): [
        "annualBonus",
        "avoirLppObligatoire",
        "avoirLppSurobligatoire",
        "employmentRate",
        "incomeGrossMonthly",
        "incomeNetYearly",
    ],
    ("profile_contract", "read_only"): [],
    ("profile_contract", "profile_writable_not_coach_writable"): [
        "isChurchMember",
        "legalForm",
        "nationality",
        "primaryActivity",
        "usTaxPerson",
    ],
    ("profile_contract", "out_of_scope"): [
        "factfindCompletionIndex",
        "fragileModeEnteredAt",
        "n5IssuedThisWeek",
        "recentGravityEvents",
        "voiceCursorPreference",
    ],
    ("profile_contract", "coach_writable"): [
        "annualBonus",
        "avoirLpp",
        "avoirLppObligatoire",
        "avoirLppSurobligatoire",
        "avsContributionYears",
        "birthYear",
        "canton",
        "commune",
        "dateOfBirth",
        "employmentRate",
        "employmentStatus",
        "gender",
        "goal",
        "has2ndPillar",
        "hasAvsGaps",
        "hasDebt",
        "hasVoluntaryLpp",
        "householdType",
        "incomeGrossMonthly",
        "incomeGrossYearly",
        "incomeNetMonthly",
        "incomeNetYearly",
        "lppBuybackMax",
        "lppInsuredSalary",
        "pillar3aAnnual",
        "pillar3aBalance",
        "savingsMonthly",
        "selfEmployedNetIncome",
        "spouseAvsContributionYears",
        "spouseBirthYear",
        "spouseIncomeNetMonthly",
        "targetRetirementAge",
        "totalDebt",
        "totalSavings",
        "wealthEstimate",
    ],
    ("profile_contract", "unclassified_save_fact_without_ProfileBase"): [],
    ("profile_contract", "unclassified_ProfileBase_without_save_fact"): [],
    ("coach_save_fact", "save_fact_count"): 35,
    ("coach_save_fact", "extractor_literal_count"): 35,
    ("coach_save_fact", "llm_tool_enum_count"): 35,
    ("coach_save_fact", "save_fact_minus_extractor"): [],
    ("coach_save_fact", "extractor_minus_save_fact"): [],
    ("coach_save_fact", "save_fact_minus_llm_tool_enum"): [],
    ("coach_save_fact", "llm_tool_enum_minus_save_fact"): [],
    ("mobile_mapping", "map_case_count"): 35,
    ("mobile_mapping", "save_fact_without_map_case"): [],
    ("mobile_mapping", "save_fact_explicitly_unsupported"): ["wealthEstimate"],
    ("secure_wizard_store", "static_sensitive_count"): 101,
    ("secure_wizard_store", "classified_sensitive_outputs"): [
        "q_employment_rate",
        "q_has_3a",
        "q_has_consumer_debt",
        "q_has_pension_fund",
        "q_net_income_period_source",
        "q_pay_frequency",
        "q_self_employed_net_income_annual_chf",
        "q_target_retirement_age",
    ],
    ("secure_wizard_store", "classified_non_sensitive_outputs"): ["q_canton"],
    ("secure_wizard_store", "classified_product_preference_outputs"): ["q_main_goal"],
    ("secure_wizard_store", "mapped_wizard_outputs_unclassified"): [],
    ("onboarding_flush", "completeAndFlushToProfile_key_count"): 21,
    ("onboarding_flush", "completeAndFlushToProfile_keys"): [
        "legacy_onb_intent",
        "onb_axis_schema_version",
        "onb_axis_v2",
        "onb_intent",
        "onb_signal_axes_v2",
        "q_avs_arrival_year",
        "q_avs_lacunes_status",
        "q_avs_years_abroad",
        "q_birth_year",
        "q_canton",
        "q_civil_status",
        "q_date_of_birth",
        "q_employment_status",
        "q_has_pension_fund",
        "q_nationality",
        "q_net_income_confidence",
        "q_net_income_period_chf",
        "q_net_income_period_source",
        "q_net_income_range_high",
        "q_net_income_range_low",
        "q_wants_deeper",
    ],
    ("regulatory", "backend_registry", "count"): 113,
    ("regulatory", "backend_registry", "active_count_on_2026_06_15"): 103,
    ("regulatory", "backend_registry", "version_hash_on_2026_06_15"): (
        "6eb0dcbd291cd0a175d0c6c22558cf609203f1966a5aaa07066e2c831599f98b"
    ),
    ("regulatory", "dart_generated_snapshot", "param_count"): 103,
    ("regulatory", "dart_generated_snapshot", "effective_on"): "2026-06-12",
    ("regulatory", "dart_reg_unique_key_count"): 43,
    ("regulatory", "dart_reg_exact_miss_count"): 9,
    ("regulatory", "dart_reg_exact_misses"): [
        "ac.enhanced_rate_threshold",
        "ac.intermediate_days",
        "ac.min_days",
        "ac.senior_age_threshold",
        "ac.senior_days",
        "projection.avs_indexation_rate",
        "projection.inflation_rate",
        "projection.life_expectancy",
        "projection.safe_withdrawal_rate",
    ],
    ("regulatory", "dart_reg_registry_backfill_required"): [
        "ac.enhanced_rate_threshold",
        "ac.intermediate_days",
        "ac.min_days",
        "ac.senior_age_threshold",
        "ac.senior_days",
    ],
    ("regulatory", "dart_reg_descoped_until_owner_phase"): [
        "projection.avs_indexation_rate",
        "projection.inflation_rate",
        "projection.life_expectancy",
        "projection.safe_withdrawal_rate",
    ],
    ("regulatory", "dart_reg_unclassified_exact_misses"): [],
    ("regulatory", "non_static_reg_keys"): [],
}

DART_REGISTRY_BACKFILL_REQUIRED = {
    "ac.enhanced_rate_threshold",
    "ac.intermediate_days",
    "ac.min_days",
    "ac.senior_age_threshold",
    "ac.senior_days",
}
DART_REG_DESCOPED_UNTIL_OWNER_PHASE = {
    "projection.avs_indexation_rate",
    "projection.inflation_rate",
    "projection.life_expectancy",
    "projection.safe_withdrawal_rate",
}


def _read(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8")


def _class_ann_fields(root: Path, relative: str, class_name: str) -> list[str]:
    tree = ast.parse(_read(root, relative))
    for node in tree.body:
        if isinstance(node, ast.ClassDef) and node.name == class_name:
            return [
                stmt.target.id
                for stmt in node.body
                if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name)
            ]
    raise LookupError(f"{class_name} not found in {relative}")


def _assigned_string_collection(root: Path, relative: str, symbol: str) -> list[str]:
    tree = ast.parse(_read(root, relative))
    for node in ast.walk(tree):
        value: ast.expr | None = None
        if (
            isinstance(node, ast.AnnAssign)
            and isinstance(node.target, ast.Name)
            and node.target.id == symbol
        ):
            value = node.value
        elif isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == symbol
            for target in node.targets
        ):
            value = node.value
        if value is None:
            continue
        if isinstance(value, (ast.Set, ast.List, ast.Tuple)):
            return _strings_from_elts(value.elts)
        raise LookupError(f"{symbol} in {relative} is not a literal collection")
    raise LookupError(f"{symbol} not found in {relative}")


def _literal_alias_values(root: Path, relative: str, symbol: str) -> list[str]:
    tree = ast.parse(_read(root, relative))
    for node in ast.walk(tree):
        value: ast.expr | None = None
        if isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == symbol
            for target in node.targets
        ):
            value = node.value
        elif (
            isinstance(node, ast.AnnAssign)
            and isinstance(node.target, ast.Name)
            and node.target.id == symbol
        ):
            value = node.value
        if value is None:
            continue
        if isinstance(value, ast.Subscript) and isinstance(value.slice, ast.Tuple):
            return _strings_from_elts(list(value.slice.elts))
        raise LookupError(f"{symbol} in {relative} is not a Literal[...] alias")
    raise LookupError(f"{symbol} not found in {relative}")


def _coach_tool_enum_values(
    root: Path,
    relative: str,
    tool_name: str,
    property_name: str,
) -> list[str]:
    tree = ast.parse(_read(root, relative))
    for node in ast.walk(tree):
        value: ast.expr | None = None
        if isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == "COACH_TOOLS"
            for target in node.targets
        ):
            value = node.value
        elif (
            isinstance(node, ast.AnnAssign)
            and isinstance(node.target, ast.Name)
            and node.target.id == "COACH_TOOLS"
        ):
            value = node.value
        if not isinstance(value, ast.List):
            continue
        for tool in value.elts:
            if not isinstance(tool, ast.Dict):
                continue
            if _dict_value(tool, "name") != tool_name:
                continue
            input_schema = _dict_value(tool, "input_schema")
            if not isinstance(input_schema, ast.Dict):
                raise LookupError(f"{tool_name}.input_schema is not a literal dict")
            properties = _dict_value(input_schema, "properties")
            if not isinstance(properties, ast.Dict):
                raise LookupError(f"{tool_name}.input_schema.properties not found")
            property_schema = _dict_value(properties, property_name)
            if not isinstance(property_schema, ast.Dict):
                raise LookupError(f"{tool_name}.{property_name} schema not found")
            enum_values = _dict_value(property_schema, "enum")
            if not isinstance(enum_values, ast.List):
                raise LookupError(f"{tool_name}.{property_name}.enum not found")
            return _strings_from_elts(enum_values.elts)
    raise LookupError(f"{tool_name}.{property_name}.enum not found in COACH_TOOLS")


def _dict_value(node: ast.Dict, key: str) -> ast.expr | str | None:
    for dict_key, value in zip(node.keys, node.values):
        if (
            isinstance(dict_key, ast.Constant)
            and isinstance(dict_key.value, str)
            and dict_key.value == key
        ):
            if isinstance(value, ast.Constant) and isinstance(value.value, str):
                return value.value
            return value
    return None


def _strings_from_elts(elts: list[ast.expr]) -> list[str]:
    return [
        elt.value
        for elt in elts
        if isinstance(elt, ast.Constant) and isinstance(elt.value, str)
    ]


def _extract_mobile_mapping(root: Path, save_fact: list[str]) -> dict[str, Any]:
    source = _read(root, "apps/mobile/lib/providers/coach_profile_provider.dart")
    match = re.search(
        r"Map<String, dynamic> _mapFactKeyToAnswers"
        r"\(String factKey, dynamic value\) \{(?P<body>.*?)\n  \}\n\n  static num\? _asNum",
        source,
        re.S,
    )
    if not match:
        raise LookupError("_mapFactKeyToAnswers body not found")
    body = match.group("body")
    cases = re.findall(r"case '([^']+)':", body)
    outputs_by_case: dict[str, list[str]] = {}
    for index, key in enumerate(cases):
        start = body.find(f"case '{key}':")
        next_key = cases[index + 1] if index + 1 < len(cases) else None
        end = (
            body.find(f"case '{next_key}':", start + 1)
            if next_key
            else body.find("default:", start)
        )
        if end == -1:
            end = len(body)
        block = body[start:end]
        outputs_by_case[key] = sorted(
            set(re.findall(r"'((?:q|_coach)_[A-Za-z0-9_]+)'\s*:", block))
        )
    outputs = sorted({key for values in outputs_by_case.values() for key in values})
    return {
        "map_case_count": len(cases),
        "map_cases": cases,
        "save_fact_without_map_case": sorted(set(save_fact) - set(cases)),
        "save_fact_explicitly_unsupported": sorted(
            key for key, outputs in outputs_by_case.items() if not outputs
        ),
        "map_case_not_in_save_fact": sorted(set(cases) - set(save_fact)),
        "wizard_output_count": len(outputs),
        "wizard_outputs": outputs,
        "wizard_outputs_by_case": outputs_by_case,
    }


def _extract_secure_wizard_store(
    root: Path, wizard_outputs: list[str]
) -> dict[str, Any]:
    source = _read(root, "apps/mobile/lib/services/secure_wizard_store.dart")
    static_keys = _dart_const_string_set(source, "_sensitiveKeys")
    classified_sensitive = _dart_const_string_set(source, "_classifiedSensitiveKeys")
    non_sensitive = _dart_const_string_set(source, "_nonSensitiveKeys")
    product_preference = _dart_const_string_set(source, "_productPreferenceKeys")
    prefixes = re.findall(r"key\.startsWith\('([^']+)'\)", source)
    unclassified = sorted(
        key
        for key in wizard_outputs
        if key not in static_keys
        and not any(key.startswith(prefix) for prefix in prefixes)
        and key not in non_sensitive
        and key not in product_preference
    )
    return {
        "static_sensitive_count": len(static_keys),
        "static_sensitive_keys": static_keys,
        "classified_sensitive_outputs": sorted(
            set(wizard_outputs) & set(classified_sensitive)
        ),
        "classified_non_sensitive_outputs": sorted(
            set(wizard_outputs) & set(non_sensitive)
        ),
        "classified_product_preference_outputs": sorted(
            set(wizard_outputs) & set(product_preference)
        ),
        "mapped_wizard_outputs_unclassified": unclassified,
        "dynamic_prefixes": prefixes,
        "mapped_wizard_outputs_not_static_sensitive": sorted(
            set(wizard_outputs) - set(static_keys)
        ),
        "mapped_wizard_outputs_not_covered_by_static_or_prefix": sorted(
            key
            for key in wizard_outputs
            if key not in static_keys
            and not any(key.startswith(prefix) for prefix in prefixes)
        ),
    }


def _dart_const_string_set(source: str, symbol: str) -> list[str]:
    sets_by_symbol = {
        match.group("symbol"): match.group("body")
        for match in re.finditer(
            r"static const (?P<symbol>_[A-Za-z0-9_]+) = \{(?P<body>.*?)\n  \};",
            source,
            re.S,
        )
    }
    if symbol not in sets_by_symbol:
        raise LookupError(f"{symbol} not found")
    return _resolve_dart_string_set(symbol, sets_by_symbol, seen=set())


def _resolve_dart_string_set(
    symbol: str,
    sets_by_symbol: dict[str, str],
    seen: set[str],
) -> list[str]:
    if symbol in seen:
        raise LookupError(f"cycle while resolving {symbol}")
    seen.add(symbol)
    body = sets_by_symbol[symbol]
    values = re.findall(r"'([^']+)'", body)
    for spread in re.findall(r"\.\.\.(_[A-Za-z0-9_]+)", body):
        if spread not in sets_by_symbol:
            raise LookupError(f"{symbol} spreads unknown set {spread}")
        values.extend(_resolve_dart_string_set(spread, sets_by_symbol, seen=set(seen)))
    return values


PROFILE_BASE_READ_ONLY_USER_DATA = {
    "isChurchMember",
    "legalForm",
    "nationality",
    "primaryActivity",
    "usTaxPerson",
}
PROFILE_BASE_OUT_OF_SCOPE = {
    "factfindCompletionIndex",
    "fragileModeEnteredAt",
    "n5IssuedThisWeek",
    "recentGravityEvents",
    "voiceCursorPreference",
}


def _extract_onboarding_flush(root: Path) -> dict[str, Any]:
    source = _read(
        root, "apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart"
    )
    match = re.search(
        r"Future<void> completeAndFlushToProfile\([\s\S]*?\) async \{"
        r"(?P<body>.*?)\n    final sealed = await ReportPersistenceService\.saveAnswers\(answers\);",
        source,
        re.S,
    )
    if not match:
        raise LookupError("completeAndFlushToProfile body not found")
    keys = sorted(set(re.findall(r"answers\['([^']+)'\]", match.group("body"))))
    return {
        "completeAndFlushToProfile_key_count": len(keys),
        "completeAndFlushToProfile_keys": keys,
    }


def _extract_regulatory(root: Path) -> dict[str, Any]:
    backend_root = root / "services" / "backend"
    sys.path.insert(0, str(backend_root))
    try:
        from app.services.regulatory.registry import RegulatoryRegistry  # type: ignore
    finally:
        try:
            sys.path.remove(str(backend_root))
        except ValueError:
            pass

    registry = RegulatoryRegistry.instance()
    all_params = registry.get_all()
    active_params = [param for param in all_params if param.is_active(CHECK_DATE)]
    active_keys = sorted({param.key for param in active_params})

    generated = _read(
        root,
        "apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart",
    )
    dart_snapshot = {
        "version_hash": _match_required(
            r"regulatoryConstantsVersionHash = '([^']+)'",
            generated,
            "regulatoryConstantsVersionHash",
        ),
        "effective_on": _match_required(
            r"regulatoryConstantsEffectiveOn = '([^']+)'",
            generated,
            "regulatoryConstantsEffectiveOn",
        ),
        "param_count": int(
            _match_required(r'"param_count":(\d+)', generated, "param_count")
        ),
        "payload_integrity_hash": _match_required(
            r"_payloadIntegrityHash = '([^']+)'",
            generated,
            "_payloadIntegrityHash",
        ),
    }

    calls = _extract_dart_reg_calls(root)
    unique_keys = sorted({call["key"] for call in calls})
    exact_misses = sorted(key for key in unique_keys if key not in active_keys)
    non_static = sorted(
        {
            call["raw"] if not call["is_static"] else call["key"]
            for call in calls
            if not call["is_static"] or "${" in call["key"]
        }
    )
    dispositions = _classify_dart_reg_exact_misses(exact_misses)
    return {
        "backend_registry": {
            "count": registry.count(),
            "active_count_on_2026_06_15": len(active_params),
            "version_hash_on_2026_06_15": registry.version_hash(CHECK_DATE),
            "categories": sorted({param.key.split(".")[0] for param in all_params}),
        },
        "dart_generated_snapshot": dart_snapshot,
        "dart_reg_call_count": len(calls),
        "dart_reg_unique_key_count": len(unique_keys),
        "dart_reg_unique_keys": unique_keys,
        "dart_reg_exact_miss_count": len(exact_misses),
        "dart_reg_exact_misses": exact_misses,
        "dart_reg_exact_miss_call_sites": [
            call for call in calls if call["key"] in exact_misses
        ],
        "non_static_reg_keys": non_static,
        **dispositions,
    }


def _extract_dart_reg_calls(root: Path) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    for path in sorted((root / "apps/mobile/lib").rglob("*.dart")):
        relative = path.relative_to(root).as_posix()
        if "/l10n/" in relative or "/generated/" in relative:
            continue
        source = path.read_text(encoding="utf-8")
        for match in re.finditer(r"reg\(\s*(?P<arg>[^,\n)]+)", source):
            line_start = source.rfind("\n", 0, match.start()) + 1
            line_end = source.find("\n", match.start())
            if line_end == -1:
                line_end = len(source)
            line_text = source[line_start:line_end]
            if re.match(
                r"\s*(?:static\s+)?"
                r"(?:double|int|num|String|bool|dynamic|Object|DateTime|Future<[^>]+>)"
                r"\s+reg\s*\(",
                line_text,
            ):
                continue
            raw_arg = match.group("arg").strip()
            static_match = re.fullmatch(r"""["']([^"']+)["']""", raw_arg)
            key = static_match.group(1) if static_match else f"<non-static:{raw_arg}>"
            calls.append(
                {
                    "path": relative,
                    "line": source.count("\n", 0, match.start()) + 1,
                    "key": key,
                    "raw": raw_arg.strip("\"'"),
                    "is_static": static_match is not None,
                }
            )
    return calls


def _classify_dart_reg_exact_misses(exact_misses: list[str]) -> dict[str, Any]:
    miss_set = set(exact_misses)
    registry_backfill = miss_set & DART_REGISTRY_BACKFILL_REQUIRED
    descoped = miss_set & DART_REG_DESCOPED_UNTIL_OWNER_PHASE
    return {
        "dart_reg_registry_backfill_required": sorted(registry_backfill),
        "dart_reg_descoped_until_owner_phase": sorted(descoped),
        "dart_reg_unclassified_exact_misses": sorted(
            miss_set - registry_backfill - descoped
        ),
    }


def _classify_profile_contract(
    profile_base: list[str],
    profile_update: list[str],
    save_fact: list[str],
    wizard_outputs_by_case: dict[str, list[str]],
) -> dict[str, Any]:
    profile_base_set = set(profile_base)
    profile_update_set = set(profile_update)
    save_fact_set = set(save_fact)

    write_only = sorted(profile_update_set - profile_base_set)
    save_fact_without_profile_base = save_fact_set - profile_base_set
    derived_mobile = sorted(
        key for key in save_fact_without_profile_base if wizard_outputs_by_case.get(key)
    )
    profile_base_without_save_fact = profile_base_set - save_fact_set
    read_only = sorted(
        key
        for key in profile_base_without_save_fact
        if key not in profile_update_set and key not in PROFILE_BASE_OUT_OF_SCOPE
    )
    profile_writable_not_coach_writable = sorted(
        key
        for key in profile_base_without_save_fact
        if key in profile_update_set and key in PROFILE_BASE_READ_ONLY_USER_DATA
    )
    out_of_scope = sorted(
        key
        for key in profile_base_without_save_fact
        if key in PROFILE_BASE_OUT_OF_SCOPE
    )

    return {
        "coach_writable": sorted(save_fact_set),
        "write_only": write_only,
        "derived_mobile": derived_mobile,
        "read_only": read_only,
        "profile_writable_not_coach_writable": profile_writable_not_coach_writable,
        "out_of_scope": out_of_scope,
        "unclassified_save_fact_without_ProfileBase": sorted(
            save_fact_without_profile_base - set(derived_mobile)
        ),
        "unclassified_ProfileBase_without_save_fact": sorted(
            profile_base_without_save_fact
            - set(read_only)
            - set(profile_writable_not_coach_writable)
            - set(out_of_scope)
        ),
    }


def _match_required(pattern: str, text: str, label: str) -> str:
    match = re.search(pattern, text)
    if not match:
        raise LookupError(f"{label} not found")
    return match.group(1)


def extract_contract(root: Path) -> dict[str, Any]:
    profile_base = _class_ann_fields(
        root, "services/backend/app/schemas/profile.py", "ProfileBase"
    )
    profile_update = _class_ann_fields(
        root, "services/backend/app/schemas/profile.py", "ProfileUpdate"
    )
    save_fact = _assigned_string_collection(
        root,
        "services/backend/app/api/v1/endpoints/coach_chat.py",
        "_SAVE_FACT_ALLOWED_KEYS",
    )
    extractor = _literal_alias_values(
        root,
        "services/backend/app/services/coach/extractor_schema.py",
        "_ALLOWED_FACT_KEYS",
    )
    llm_tool_enum = _coach_tool_enum_values(
        root,
        "services/backend/app/services/coach/coach_tools.py",
        "save_fact",
        "key",
    )
    mobile_mapping = _extract_mobile_mapping(root, save_fact)
    return {
        "profile": {
            "ProfileBase_count": len(profile_base),
            "ProfileBase_fields": profile_base,
            "ProfileUpdate_count": len(profile_update),
            "ProfileUpdate_fields": profile_update,
            "ProfileUpdate_only": sorted(set(profile_update) - set(profile_base)),
            "ProfileBase_only": sorted(set(profile_base) - set(profile_update)),
        },
        "coach_save_fact": {
            "save_fact_count": len(save_fact),
            "save_fact_keys": save_fact,
            "extractor_literal_count": len(extractor),
            "extractor_keys": extractor,
            "llm_tool_enum_count": len(llm_tool_enum),
            "llm_tool_enum_keys": llm_tool_enum,
            "save_fact_minus_extractor": sorted(set(save_fact) - set(extractor)),
            "extractor_minus_save_fact": sorted(set(extractor) - set(save_fact)),
            "save_fact_minus_llm_tool_enum": sorted(
                set(save_fact) - set(llm_tool_enum)
            ),
            "llm_tool_enum_minus_save_fact": sorted(
                set(llm_tool_enum) - set(save_fact)
            ),
        },
        "profile_contract": _classify_profile_contract(
            profile_base,
            profile_update,
            save_fact,
            mobile_mapping["wizard_outputs_by_case"],
        ),
        "mobile_mapping": mobile_mapping,
        "secure_wizard_store": _extract_secure_wizard_store(
            root, mobile_mapping["wizard_outputs"]
        ),
        "onboarding_flush": _extract_onboarding_flush(root),
        "regulatory": _extract_regulatory(root),
    }


def _value_at(snapshot: dict[str, Any], path: tuple[str, ...]) -> Any:
    value: Any = snapshot
    for part in path:
        value = value[part]
    return value


def check(snapshot: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    for path, expected in EXPECTED.items():
        actual = _value_at(snapshot, path)
        if actual != expected:
            dotted = ".".join(path)
            errors.append(f"{dotted}: expected {expected!r}, got {actual!r}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="Repository root. Defaults to current working directory.",
    )
    parser.add_argument("--json", action="store_true", help="Print snapshot JSON.")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail if the current snapshot drifts from the frozen 02c baseline.",
    )
    args = parser.parse_args(argv)

    root = args.root.resolve()
    try:
        snapshot = extract_contract(root)
    except Exception as exc:
        print(f"FAIL mint_variable_contract_extract: {exc}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps(snapshot, indent=2, ensure_ascii=False))

    if args.check:
        errors = check(snapshot)
        if errors:
            print(
                "FAIL mint_variable_contract_extract: drift detected.", file=sys.stderr
            )
            for error in errors:
                print(f"  - {error}", file=sys.stderr)
            return 1
        print(
            "OK mint_variable_contract_extract: snapshot matches 02c baseline.",
            file=sys.stderr,
        )

    if not args.json and not args.check:
        print(json.dumps(snapshot, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    sys.exit(main())
