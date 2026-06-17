#!/usr/bin/env python3
"""Lint the non-authoritative Mint variable dictionary view.

PR7 intentionally does not define a new source of truth. This module is a thin
scaffold over existing static sources; implementation is added by tests.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import date
from functools import lru_cache
from pathlib import Path
from typing import Any

CHECK_DATE = date(2026, 6, 15)

COLUMNS = (
    "canonical_id",
    "profile_base_field",
    "profile_update_field",
    "save_fact_key",
    "extractor_key",
    "mobile_wizard_keys",
    "coach_profile_path",
    "secure_storage_status",
    "source",
    "source_version",
    "readiness_roles",
    "alias_status",
    "collection_permissions",
)

ALIAS_STATUSES = {
    "identity",
    "source_alias",
    "explicitly_unsupported",
    "registry_backfill_required",
    "descoped_until_owner_phase",
    "unmapped",
}
SECURE_STORAGE_STATUSES = {
    "sensitive",
    "non_sensitive",
    "product_preference",
    "not_applicable",
    "unknown",
}
READINESS_VALUES = {"required", "optional", "derived", "not_required"}
OWNER_KINDS = {"l1_mobile", "l2_l4_backend", "not_calculation"}
COLLECTION_PERMISSIONS = {
    "allowed_if_needed",
    "required_if_needed",
    "preview_only",
    "not_collected",
    "forbidden_detailed_unused",
}

# Source: active Mint 2.0 SPEC.md Required Behavior and Negative Cases.
ACTIVE_SPEC = Path(
    ".planning/phases/mint-2-0-first-experience-rente-capital/SPEC.md"
)
SIGNALETIQUE_AXES = ("logement", "fiscal")

SENSITIVE_TOKENS = (
    "income",
    "salary",
    "salaire",
    "lpp",
    "avs",
    "pillar",
    "3a",
    "debt",
    "dette",
    "wealth",
    "saving",
    "cash",
    "tax",
    "revenu",
    "loyer",
    "impot",
    "hypotheque",
    "fortune",
    "patrimoine",
    "prevoyance",
    "rente",
    "cotisation",
    "epargne",
    "mortgage",
    "rent",
    "birth",
    "date_of_birth",
)
CALCULATION_TOKENS = (
    "income",
    "salary",
    "salaire",
    "lpp",
    "avs",
    "pillar",
    "3a",
    "debt",
    "wealth",
    "saving",
    "cash",
    "tax",
    "revenu",
    "loyer",
    "impot",
    "hypotheque",
    "fortune",
    "patrimoine",
    "prevoyance",
    "rente",
    "cotisation",
    "epargne",
    "mortgage",
    "birthYear",
    "dateOfBirth",
    "canton",
    "employment",
    "retirement",
)
DETAILED_FIELD_TOKENS = (
    "income",
    "salary",
    "lpp",
    "pillar3a",
    "3a",
    "debt",
    "wealth",
    "saving",
    "cash",
    "tax",
    "revenu",
    "loyer",
    "impot",
    "hypotheque",
    "fortune",
    "patrimoine",
    "prevoyance",
    "rente",
    "cotisation",
    "epargne",
    "mortgage",
    "rent",
    "avoir",
    "rachat",
)


@dataclass(frozen=True)
class DictionaryView:
    rows: list[dict[str, Any]]
    scan_counts: dict[str, int]


@dataclass(frozen=True)
class LintError:
    code: str
    canonical_id: str
    field: str
    message: str
    source: str = ""

    def format(self) -> str:
        location = f" ({self.source})" if self.source else ""
        return (
            f"{self.code}: {self.canonical_id}.{self.field}: "
            f"{self.message}{location}"
        )


def build_dictionary(root: Path) -> list[dict[str, Any]]:
    return _build_view(root.resolve()).rows


def lint_rows(
    rows: list[dict[str, Any]],
    *,
    scan_counts: dict[str, int] | None = None,
) -> list[LintError]:
    errors: list[LintError] = []
    counts = scan_counts or {}
    for key in (
        "source_lines",
        "save_fact",
        "profile_fields",
        "extractor_keys",
        "mobile_wizard_keys",
        "reg_keys",
    ):
        if counts.get(key, 0) <= 0:
            errors.append(
                LintError(
                    "MVD001_EMPTY_SCAN",
                    "<scan>",
                    key,
                    "real source scan returned no data",
                )
            )
    if not rows:
        errors.append(
            LintError(
                "MVD001_EMPTY_SCAN",
                "<scan>",
                "rows",
                "dictionary view is empty",
            )
        )

    for row in rows:
        canonical_id = str(row.get("canonical_id") or "<missing>")
        source = str(row.get("source") or "")
        if tuple(row.keys()) != COLUMNS:
            errors.append(
                LintError(
                    "MVD009_COLUMNS",
                    canonical_id,
                    "columns",
                    f"expected {COLUMNS!r}, got {tuple(row.keys())!r}",
                    source,
                )
            )
            continue

        if (
            "tools/checks/mint_variable_dictionary_lint.py" in source
            or str(row["source_version"]).startswith("dictionary:")
        ):
            errors.append(
                LintError(
                    "MVD002_SOURCE_OF_TRUTH",
                    canonical_id,
                    "source",
                    "PR7 dictionary lint cannot be the source of truth",
                    source,
                )
            )

        _lint_enums(row, errors)

        alias_status = row["alias_status"]
        if row["save_fact_key"] and alias_status == "unmapped":
            errors.append(
                LintError(
                    "MVD003_SAVE_FACT_UNBOUND",
                    canonical_id,
                    "save_fact_key",
                    "save_fact key has no binding or explicit disposition",
                    source,
                )
            )
        if row["save_fact_key"] and not (
            row["profile_base_field"]
            or row["profile_update_field"]
            or row["mobile_wizard_keys"]
            or row["coach_profile_path"]
            or alias_status
            in {
                "explicitly_unsupported",
                "registry_backfill_required",
                "descoped_until_owner_phase",
            }
        ):
            errors.append(
                LintError(
                    "MVD003_SAVE_FACT_UNBOUND",
                    canonical_id,
                    "save_fact_key",
                    "save_fact key has no binding or explicit disposition",
                    source,
                )
            )

        if _looks_sensitive(row) and row["secure_storage_status"] == "unknown":
            errors.append(
                LintError(
                    "MVD004_SENSITIVE_UNCLASSIFIED",
                    canonical_id,
                    "secure_storage_status",
                    "sensitive financial or life-planning key is unclassified",
                    source,
                )
            )

        readiness_roles = _as_dict(row["readiness_roles"])
        owner_kind = readiness_roles.get("calculation_owner_kind")
        if _is_active_calculation_variable(row) and owner_kind not in {
            "l1_mobile",
            "l2_l4_backend",
        }:
            errors.append(
                LintError(
                    "MVD005_CALC_OWNER_MISSING",
                    canonical_id,
                    "readiness_roles.calculation_owner_kind",
                    "active calculation variable must name L1 mobile or L2-L4 backend owner",
                    source,
                )
            )

        collection_permissions = _as_dict(row["collection_permissions"])
        if _is_detailed_field(row):
            for axis in SIGNALETIQUE_AXES:
                if collection_permissions.get(axis) == "required_if_needed":
                    errors.append(
                        LintError(
                            "MVD006_SIGNALETIQUE_OVER_COLLECTION",
                            canonical_id,
                            f"collection_permissions.{axis}",
                            "signalétique axis cannot require detailed unused fields",
                            source,
                        )
                    )

        if "reg()" in source and alias_status == "unmapped":
            errors.append(
                LintError(
                    "MVD007_REG_UNCOVERED",
                    canonical_id,
                    "alias_status",
                    "reg() key is not statically covered or explicitly dispositioned",
                    source,
                )
            )

    return errors


def lint(root: Path) -> list[LintError]:
    view = _build_view(root.resolve())
    return lint_rows(view.rows, scan_counts=view.scan_counts)


def _build_view(root: Path) -> DictionaryView:
    extractor = _contract_module()
    contract = extractor.extract_contract(root)

    profile_base = set(contract["profile"]["ProfileBase_fields"])
    profile_update = set(contract["profile"]["ProfileUpdate_fields"])
    save_fact = set(contract["coach_save_fact"]["save_fact_keys"])
    extractor_keys = set(contract["coach_save_fact"]["extractor_keys"])
    wizard_outputs_by_case = contract["mobile_mapping"]["wizard_outputs_by_case"]
    coach_profile_paths = _extract_coach_profile_answer_paths(root)
    secure_status_by_key = _secure_status_by_key(contract)
    unsupported_save_fact = set(
        contract["mobile_mapping"]["save_fact_explicitly_unsupported"]
    )

    rows: list[dict[str, Any]] = []
    canonical_ids = sorted(profile_base | profile_update | save_fact | extractor_keys)
    owner_sources = _extract_calculation_owner_sources(root, canonical_ids)
    for canonical_id in canonical_ids:
        mobile_keys = sorted(wizard_outputs_by_case.get(canonical_id, []))
        coach_profile_path = _coach_profile_path(mobile_keys, coach_profile_paths)
        source_parts = _source_parts_for_variable(
            canonical_id,
            profile_base,
            profile_update,
            save_fact,
            extractor_keys,
            mobile_keys,
            bool(coach_profile_path),
        )
        source = ";".join(source_parts)
        owner_kind = _owner_kind_for(canonical_id, owner_sources)
        rows.append(
            _row(
                canonical_id=canonical_id,
                profile_base_field=canonical_id if canonical_id in profile_base else "",
                profile_update_field=(
                    canonical_id if canonical_id in profile_update else ""
                ),
                save_fact_key=canonical_id if canonical_id in save_fact else "",
                extractor_key=canonical_id if canonical_id in extractor_keys else "",
                mobile_wizard_keys=mobile_keys,
                coach_profile_path=coach_profile_path,
                secure_storage_status=_secure_status_for_keys(
                    mobile_keys,
                    secure_status_by_key,
                ),
                source=source,
                source_version=_static_source_version(root, source_parts),
                readiness_roles=_readiness_roles(canonical_id, owner_kind),
                alias_status=_alias_status(
                    canonical_id,
                    mobile_keys,
                    unsupported_save_fact,
                ),
                collection_permissions=_collection_permissions(canonical_id),
            )
        )

    rows.extend(_regulatory_rows(root, contract))

    scan_counts = {
        "source_lines": _source_lines(root),
        "save_fact": contract["coach_save_fact"]["save_fact_count"],
        "profile_fields": contract["profile"]["ProfileBase_count"]
        + contract["profile"]["ProfileUpdate_count"],
        "extractor_keys": contract["coach_save_fact"]["extractor_literal_count"],
        "mobile_wizard_keys": contract["mobile_mapping"]["wizard_output_count"],
        "reg_keys": contract["regulatory"]["dart_reg_unique_key_count"],
    }
    return DictionaryView(rows=rows, scan_counts=scan_counts)


def _contract_module() -> Any:
    path = Path(__file__).with_name("mint_variable_contract_extract.py")
    spec = importlib.util.spec_from_file_location("mint_variable_contract_extract", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules["mint_variable_contract_extract"] = module
    spec.loader.exec_module(module)
    return module


def _row(**values: Any) -> dict[str, Any]:
    return {column: values[column] for column in COLUMNS}


def _source_parts_for_variable(
    canonical_id: str,
    profile_base: set[str],
    profile_update: set[str],
    save_fact: set[str],
    extractor_keys: set[str],
    mobile_keys: list[str],
    has_coach_profile_path: bool,
) -> list[str]:
    source_parts: list[str] = []
    if canonical_id in profile_base or canonical_id in profile_update:
        source_parts.append("services/backend/app/schemas/profile.py:ProfileBase/ProfileUpdate")
    if canonical_id in save_fact:
        source_parts.append(
            "services/backend/app/api/v1/endpoints/coach_chat.py:_SAVE_FACT_ALLOWED_KEYS"
        )
    if canonical_id in extractor_keys:
        source_parts.append(
            "services/backend/app/services/coach/extractor_schema.py:_ALLOWED_FACT_KEYS"
        )
    if mobile_keys:
        source_parts.append(
            "apps/mobile/lib/providers/coach_profile_provider.dart:_mapFactKeyToAnswers"
        )
    if has_coach_profile_path:
        source_parts.append("apps/mobile/lib/models/coach_profile.dart:fromWizardAnswers")
    return source_parts or ["<unknown>"]


def _alias_status(
    canonical_id: str,
    mobile_keys: list[str],
    unsupported_save_fact: set[str],
) -> str:
    if canonical_id in unsupported_save_fact and not mobile_keys:
        return "explicitly_unsupported"
    if mobile_keys:
        return "identity" if mobile_keys == [canonical_id] else "source_alias"
    return "identity"


def _secure_status_by_key(contract: dict[str, Any]) -> dict[str, str]:
    secure = contract["secure_wizard_store"]
    status_by_key = {
        key: "sensitive" for key in secure["static_sensitive_keys"]
    }
    status_by_key.update({key: "sensitive" for key in secure["classified_sensitive_outputs"]})
    status_by_key.update({key: "non_sensitive" for key in secure["classified_non_sensitive_outputs"]})
    status_by_key.update(
        {key: "product_preference" for key in secure["classified_product_preference_outputs"]}
    )
    status_by_key["__sensitive_prefixes__"] = tuple(secure["dynamic_prefixes"])  # type: ignore[assignment]
    return status_by_key


def _secure_status_for_keys(
    mobile_keys: list[str],
    secure_status_by_key: dict[str, str],
) -> str:
    if not mobile_keys:
        return "not_applicable"
    prefixes = secure_status_by_key.get("__sensitive_prefixes__", ())
    statuses = {
        secure_status_by_key.get(
            key,
            "sensitive"
            if any(key.startswith(prefix) for prefix in prefixes)
            else "unknown",
        )
        for key in mobile_keys
    }
    if "unknown" in statuses:
        return "unknown"
    if "sensitive" in statuses:
        return "sensitive"
    if "product_preference" in statuses:
        return "product_preference"
    return "non_sensitive"


def _extract_coach_profile_answer_paths(root: Path) -> dict[str, str]:
    relative = "apps/mobile/lib/models/coach_profile.dart"
    source = (root / relative).read_text(encoding="utf-8")
    paths: dict[str, str] = {}
    for match in re.finditer(r"answers\['([^']+)'\]", source):
        line = source.count("\n", 0, match.start()) + 1
        paths.setdefault(match.group(1), f"CoachProfile.fromWizardAnswers:{line}")
    return paths


def _coach_profile_path(
    mobile_keys: list[str],
    paths_by_key: dict[str, str],
) -> str:
    paths = [paths_by_key[key] for key in mobile_keys if key in paths_by_key]
    return ",".join(paths)


def _readiness_roles(canonical_id: str, owner_kind: str) -> dict[str, str]:
    return {
        "rente_capital": "required" if _is_core_rente_capital_key(canonical_id) else "optional",
        "logement": "not_required",
        "fiscal": "not_required",
        "calculation_owner_kind": owner_kind,
    }


def _collection_permissions(canonical_id: str) -> dict[str, str]:
    if _name_contains(canonical_id, DETAILED_FIELD_TOKENS):
        signaletique = "not_collected"
    else:
        signaletique = "preview_only"
    return {
        "rente_capital": "allowed_if_needed",
        "logement": signaletique,
        "fiscal": signaletique,
    }


def _is_core_rente_capital_key(canonical_id: str) -> bool:
    return canonical_id in {
        "birthYear",
        "dateOfBirth",
        "canton",
        "gender",
        "targetRetirementAge",
        "avoirLpp",
        "avoirLppObligatoire",
        "avoirLppSurobligatoire",
        "lppInsuredSalary",
        "lppBuybackMax",
        "pillar3aAnnual",
        "pillar3aBalance",
    }


def _extract_calculation_owner_sources(
    root: Path,
    canonical_ids: list[str],
) -> dict[str, set[str]]:
    owner_sources = {canonical_id: set() for canonical_id in canonical_ids}
    source_roots = (
        (root / "apps/mobile/lib/services/financial_core", "l1_mobile", ("*.dart",)),
        (root / "services/backend/app/services", "l2_l4_backend", ("*.py",)),
    )
    for source_root, owner_kind, patterns in source_roots:
        if not source_root.exists():
            continue
        for pattern in patterns:
            for path in source_root.rglob(pattern):
                text = path.read_text(encoding="utf-8", errors="ignore")
                for canonical_id in canonical_ids:
                    if _source_mentions_variable(text, canonical_id):
                        owner_sources[canonical_id].add(owner_kind)
    return owner_sources


def _source_mentions_variable(text: str, canonical_id: str) -> bool:
    names = {canonical_id, _camel_to_snake(canonical_id)}
    return any(re.search(rf"\b{re.escape(name)}\b", text) for name in names if name)


def _camel_to_snake(name: str) -> str:
    return re.sub(r"(?<!^)([A-Z])", r"_\1", name).lower()


def _owner_kind_for(canonical_id: str, owner_sources: dict[str, set[str]]) -> str:
    owners = owner_sources.get(canonical_id, set())
    if "l1_mobile" in owners:
        return "l1_mobile"
    if "l2_l4_backend" in owners:
        return "l2_l4_backend"
    return "not_calculation"


def _regulatory_rows(root: Path, contract: dict[str, Any]) -> list[dict[str, Any]]:
    regulatory = contract["regulatory"]
    version_hash = regulatory["backend_registry"]["version_hash_on_2026_06_15"]
    exact_misses = set(regulatory["dart_reg_exact_misses"])
    backfill = set(regulatory["dart_reg_registry_backfill_required"])
    descoped = set(regulatory["dart_reg_descoped_until_owner_phase"])
    miss_call_sites = {
        call["key"]: f"{call['path']}:{call['line']}:reg()"
        for call in regulatory["dart_reg_exact_miss_call_sites"]
    }
    rows: list[dict[str, Any]] = []
    for key in regulatory["dart_reg_unique_keys"]:
        if key in backfill:
            alias_status = "registry_backfill_required"
        elif key in descoped:
            alias_status = "descoped_until_owner_phase"
        elif key in exact_misses:
            alias_status = "unmapped"
        else:
            alias_status = "identity"
        source = miss_call_sites.get(
            key,
            "apps/mobile/lib:reg();services/backend/app/services/regulatory/registry.py:RegulatoryRegistry",
        )
        rows.append(
            _row(
                canonical_id=f"reg:{key}",
                profile_base_field="",
                profile_update_field="",
                save_fact_key="",
                extractor_key="",
                mobile_wizard_keys=[],
                coach_profile_path="",
                secure_storage_status="not_applicable",
                source=source,
                source_version=f"regulatory:{version_hash}",
                readiness_roles={
                    "rente_capital": "optional",
                    "logement": "not_required",
                    "fiscal": "not_required",
                    "calculation_owner_kind": "not_calculation",
                },
                alias_status=alias_status,
                collection_permissions={
                    "rente_capital": "allowed_if_needed",
                    "logement": "not_collected",
                    "fiscal": "not_collected",
                },
            )
        )
    for key in regulatory["non_static_reg_keys"]:
        rows.append(
            _row(
                canonical_id=f"reg:{key}",
                profile_base_field="",
                profile_update_field="",
                save_fact_key="",
                extractor_key="",
                mobile_wizard_keys=[],
                coach_profile_path="",
                secure_storage_status="not_applicable",
                source=f"apps/mobile/lib:reg({key}):reg()",
                source_version=f"regulatory:{version_hash}",
                readiness_roles={
                    "rente_capital": "optional",
                    "logement": "not_required",
                    "fiscal": "not_required",
                    "calculation_owner_kind": "not_calculation",
                },
                alias_status="unmapped",
                collection_permissions={
                    "rente_capital": "allowed_if_needed",
                    "logement": "not_collected",
                    "fiscal": "not_collected",
                },
            )
        )
    return rows


def _static_source_version(root: Path, source_parts: list[str]) -> str:
    head = _git_head(root)
    digest = hashlib.sha256()
    digest.update(head.encode("utf-8"))
    version_parts = [*source_parts, f"{ACTIVE_SPEC.as_posix()}:validation-vocabulary"]
    version_parts.append("tools/checks/mint_variable_dictionary_lint.py:validation-vocabulary")
    for source in sorted(version_parts):
        digest.update(source.encode("utf-8"))
        relative = source.split(":", 1)[0]
        path = root / relative
        if path.exists() and path.is_file():
            digest.update(_file_hash(path).encode("utf-8"))
    return f"static:{digest.hexdigest()[:24]}"


def _git_head(root: Path) -> str:
    return _git_head_cached(str(root))


@lru_cache(maxsize=8)
def _git_head_cached(root: str) -> str:
    proc = subprocess.run(
        ["git", "-C", root, "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        timeout=10,
    )
    if proc.returncode != 0:
        return "no-git-head"
    return proc.stdout.strip()


@lru_cache(maxsize=None)
def _file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _source_lines(root: Path) -> int:
    relatives = [
        "services/backend/app/schemas/profile.py",
        "services/backend/app/api/v1/endpoints/coach_chat.py",
        "services/backend/app/services/coach/extractor_schema.py",
        "services/backend/app/services/coach/coach_tools.py",
        "apps/mobile/lib/providers/coach_profile_provider.dart",
        "apps/mobile/lib/services/secure_wizard_store.dart",
        "apps/mobile/lib/models/coach_profile.dart",
        "apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart",
        "services/backend/app/services/regulatory/registry.py",
    ]
    total = 0
    for relative in relatives:
        path = root / relative
        if path.exists():
            total += path.read_text(encoding="utf-8").count("\n") + 1
    return total


def _lint_enums(row: dict[str, Any], errors: list[LintError]) -> None:
    canonical_id = str(row["canonical_id"])
    source = str(row["source"])
    _enum(row["secure_storage_status"], SECURE_STORAGE_STATUSES, row, "secure_storage_status", errors)
    _enum(row["alias_status"], ALIAS_STATUSES, row, "alias_status", errors)

    readiness_roles = _as_dict(row["readiness_roles"])
    for key, value in readiness_roles.items():
        if key == "calculation_owner_kind":
            _enum(value, OWNER_KINDS, row, "readiness_roles.calculation_owner_kind", errors)
        else:
            _enum(value, READINESS_VALUES, row, f"readiness_roles.{key}", errors)

    collection_permissions = _as_dict(row["collection_permissions"])
    for key, value in collection_permissions.items():
        _enum(value, COLLECTION_PERMISSIONS, row, f"collection_permissions.{key}", errors)

    if not isinstance(row["mobile_wizard_keys"], list):
        errors.append(
            LintError(
                "MVD008_ENUM",
                canonical_id,
                "mobile_wizard_keys",
                "expected list",
                source,
            )
        )


def _enum(
    value: Any,
    allowed: set[str],
    row: dict[str, Any],
    field: str,
    errors: list[LintError],
) -> None:
    if value not in allowed:
        errors.append(
            LintError(
                "MVD008_ENUM",
                str(row["canonical_id"]),
                field,
                f"unknown value {value!r}; allowed={sorted(allowed)!r}",
                str(row["source"]),
            )
        )


def _as_dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _looks_sensitive(row: dict[str, Any]) -> bool:
    names = [str(row["canonical_id"]), str(row["save_fact_key"]), str(row["extractor_key"])]
    names.extend(str(key) for key in row["mobile_wizard_keys"])
    return any(_name_contains(name, SENSITIVE_TOKENS) for name in names)


def _is_active_calculation_variable(row: dict[str, Any]) -> bool:
    if str(row["canonical_id"]).startswith("reg:"):
        return False
    readiness_roles = _as_dict(row["readiness_roles"])
    if readiness_roles.get("calculation_owner_kind") in {"l1_mobile", "l2_l4_backend"}:
        return True
    return readiness_roles.get("rente_capital") == "required" and _name_contains(
        str(row["canonical_id"]),
        CALCULATION_TOKENS,
    )


def _is_detailed_field(row: dict[str, Any]) -> bool:
    names = [str(row["canonical_id"]), str(row["save_fact_key"])]
    names.extend(str(key) for key in row["mobile_wizard_keys"])
    return any(_name_contains(name, DETAILED_FIELD_TOKENS) for name in names)


def _name_contains(name: str, tokens: tuple[str, ...]) -> bool:
    folded = name.casefold()
    return any(token.casefold() in folded for token in tokens)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="Repository root. Defaults to current working directory.",
    )
    parser.add_argument("--check", action="store_true", help="Run the lint.")
    args = parser.parse_args(argv)

    if args.check:
        errors = lint(args.root.resolve())
        if errors:
            print("FAIL mint_variable_dictionary_lint: drift detected.", file=sys.stderr)
            for error in errors:
                print(f"  - {error.format()}", file=sys.stderr)
            return 1
        print("OK mint_variable_dictionary_lint: dictionary view is coherent.", file=sys.stderr)
        return 0

    for row in build_dictionary(args.root.resolve()):
        print(row)
    return 0


if __name__ == "__main__":
    sys.exit(main())
