#!/usr/bin/env python3
"""Validate Mint 2.0 VZ route decision contracts."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.checks.mint2_navigation_spine_guard import route_metadata

CONTRACT_DIR = Path(
    ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts"
)
RECORDS_DIR = Path(".planning/journeys/records")
GUARDED_TIERS = {"T0", "T1"}
ROUTE_LIST_FIELDS = ("primary_routes", "supporting_routes", "legacy_alias_routes")
REQUIRED_VALUE_RECEIPT_FIELDS = {
    "sources",
    "assumptions",
    "confidence",
    "missing_fields",
    "version",
}
NONE_SOURCE_VALUES = {"", "none", "not_applicable", "n/a"}
CALC_TIERS = ("L1", "L2", "L3", "L4")
ALLOWED_COMPLIANCE_INVARIANTS = {
    "no_absurd_captured_value_leak",
    "no_banned_lsfin_terms",
    "no_certainty_language",
    "no_default_lpp_amount",
    "no_destructive_action_without_confirmation",
    "no_financial_number_without_receipt",
    "no_high_confidence_without_fund_terms",
    "no_known_data_empty_state_regression",
    "no_pii_leakage_after_delete",
    "no_post_delete_authenticated_surface",
    "no_shadow_money_snapshot",
    "no_tax_only_decision",
    "no_uncited_statutory_amount",
}
ALLOWED_AUTH_SCOPES = {"authenticated", "mixed", "onboarding", "public"}
ALLOWED_ROUTE_DOMAINS = {"auth_privacy", "coach", "money_truth", "privacy", "retraite"}
ALLOWED_ROUTE_ROLES = {
    "account_lifecycle",
    "coach_advice",
    "decision",
    "privacy_control",
    "truth_spine",
}
ALLOWED_PERSONAS = {
    "cadre_salarie_lpp_suisse_ready",
    "fresh_anonymous_swiss_user",
    "fresh_disposable_staging_user",
    "julien_swiss",
    "local_mode_profile_user",
}
ROLE_REQUIRED_INVARIANTS = {
    "account_lifecycle": {
        "no_destructive_action_without_confirmation",
        "no_pii_leakage_after_delete",
        "no_post_delete_authenticated_surface",
    },
    "coach_advice": {
        "no_certainty_language",
        "no_uncited_statutory_amount",
    },
    "decision": {
        "no_default_lpp_amount",
        "no_high_confidence_without_fund_terms",
        "no_tax_only_decision",
    },
    "privacy_control": {
        "no_destructive_action_without_confirmation",
        "no_known_data_empty_state_regression",
    },
    "truth_spine": {
        "no_absurd_captured_value_leak",
        "no_shadow_money_snapshot",
    },
}


def _read_json(path: Path) -> tuple[dict[str, Any] | None, str | None]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None, f"missing JSON file: {path}"
    except json.JSONDecodeError as exc:
        return None, f"{path} must be valid JSON: {exc}"
    if not isinstance(data, dict):
        return None, f"{path} must contain a JSON object"
    return data, None


def _json_files(root: Path, rel_dir: Path) -> list[Path]:
    directory = root / rel_dir
    if not directory.exists():
        return []
    return sorted(path for path in directory.glob("*.json") if path.is_file())


def _load_records(root: Path, errors: list[str]) -> dict[str, dict[str, Any]]:
    records: dict[str, dict[str, Any]] = {}
    for path in _json_files(root, RECORDS_DIR):
        data, error = _read_json(path)
        if error:
            errors.append(error)
            continue
        assert data is not None
        journey_id = data.get("id")
        if not isinstance(journey_id, str) or not journey_id:
            errors.append(f"{path.relative_to(root)} missing string id")
            continue
        records[journey_id] = data
    return records


def _load_contracts(root: Path, errors: list[str]) -> dict[str, tuple[dict[str, Any], Path]]:
    contracts: dict[str, tuple[dict[str, Any], Path]] = {}
    files = _json_files(root, CONTRACT_DIR)
    if not files:
        errors.append(f"missing Mint 2.0 route contracts under {CONTRACT_DIR}")
        return contracts
    for path in files:
        data, error = _read_json(path)
        rel = path.relative_to(root)
        if error:
            errors.append(error)
            continue
        assert data is not None
        journey_id = data.get("journey_id")
        if not isinstance(journey_id, str) or not journey_id:
            errors.append(f"{rel} missing string journey_id")
            continue
        if journey_id in contracts:
            errors.append(f"duplicate route contract for journey_id {journey_id}")
            continue
        contracts[journey_id] = (data, rel)
    return contracts


def _strings(data: dict[str, Any], field: str) -> list[str]:
    value = data.get(field)
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, str)]


def _route_list(
    errors: list[str],
    contract: dict[str, Any],
    rel: Path,
    field: str,
    *,
    required: bool,
) -> list[str]:
    value = contract.get(field)
    if not isinstance(value, list):
        errors.append(f"{rel} {field} must be a list")
        return []
    routes: list[str] = []
    for item in value:
        if not isinstance(item, str) or not item.startswith("/"):
            errors.append(f"{rel} {field} entries must be absolute route strings")
            continue
        routes.append(item)
    if required and not routes:
        errors.append(f"{rel} {field} must not be empty")
    duplicates = sorted({route for route in routes if routes.count(route) > 1})
    if duplicates:
        errors.append(f"{rel} {field} contains duplicate routes: {duplicates}")
    return routes


def _green_evidence_artifacts(record: dict[str, Any]) -> set[str]:
    artifacts: set[str] = set()
    evidence = record.get("evidence")
    if not isinstance(evidence, list):
        return artifacts
    for item in evidence:
        if not isinstance(item, dict):
            continue
        if item.get("status") != "green":
            continue
        artifact = item.get("artifact")
        if isinstance(artifact, str) and artifact:
            artifacts.add(artifact)
    return artifacts


def _check_required_shape(
    errors: list[str],
    root: Path,
    contract: dict[str, Any],
    rel: Path,
) -> None:
    if contract.get("schema_version") != 1:
        errors.append(f"{rel} schema_version must be 1")
    for field in (
        "journey_id",
        "tier",
        "human_question",
        "route_domain",
        "route_role",
        "auth_scope",
        "missing_data_behavior",
        "proof_pointer",
    ):
        if not isinstance(contract.get(field), str) or not contract[field].strip():
            errors.append(f"{rel} {field} must be a non-empty string")
    auth_scope = contract.get("auth_scope")
    if isinstance(auth_scope, str) and auth_scope not in ALLOWED_AUTH_SCOPES:
        errors.append(f"{rel} auth_scope is unsupported: {auth_scope!r}")
    route_domain = contract.get("route_domain")
    if isinstance(route_domain, str) and route_domain not in ALLOWED_ROUTE_DOMAINS:
        errors.append(f"{rel} route_domain is unsupported: {route_domain!r}")
    route_role = contract.get("route_role")
    if isinstance(route_role, str) and route_role not in ALLOWED_ROUTE_ROLES:
        errors.append(f"{rel} route_role is unsupported: {route_role!r}")
    for field in (
        "owner_domains",
        "persona_scope",
        "required_inputs",
        "compliance_invariants",
        "source_refs",
    ):
        value = contract.get(field)
        if not isinstance(value, list) or not value:
            errors.append(f"{rel} {field} must be a non-empty list")
    personas = set(_strings(contract, "persona_scope"))
    unknown_personas = sorted(personas - ALLOWED_PERSONAS)
    if unknown_personas:
        errors.append(f"{rel} persona_scope contains unknown personas: {unknown_personas}")

    for field in ("required_inputs", "optional_inputs"):
        value = contract.get(field, [])
        if not isinstance(value, list):
            errors.append(f"{rel} {field} must be a list")
            continue
        for index, item in enumerate(value):
            if not isinstance(item, dict):
                errors.append(f"{rel} {field}[{index}] must be an object")
                continue
            if not isinstance(item.get("key"), str) or not item["key"].strip():
                errors.append(f"{rel} {field}[{index}] missing key")
            if "blocks_value" not in item or not isinstance(item.get("blocks_value"), bool):
                errors.append(f"{rel} {field}[{index}] blocks_value must be boolean")
            if not isinstance(item.get("reason"), str) or not item["reason"].strip():
                errors.append(f"{rel} {field}[{index}] missing reason")

    source_refs = contract.get("source_refs")
    if isinstance(source_refs, list):
        for ref in source_refs:
            path_error = _repo_relative_error(ref)
            if path_error:
                errors.append(f"{rel} source_ref {path_error}: {ref!r}")
                continue
            if not (root / ref).exists():
                errors.append(f"{rel} source_ref does not exist: {ref}")

    invariants = set(_strings(contract, "compliance_invariants"))
    unknown_invariants = sorted(invariants - ALLOWED_COMPLIANCE_INVARIANTS)
    if unknown_invariants:
        errors.append(f"{rel} unknown compliance_invariants: {unknown_invariants}")
    if "no_banned_lsfin_terms" not in invariants:
        errors.append(f"{rel} compliance_invariants must include no_banned_lsfin_terms")
    route_role = contract.get("route_role")
    if isinstance(route_role, str):
        missing_role_invariants = sorted(
            ROLE_REQUIRED_INVARIANTS.get(route_role, set()) - invariants
        )
        if missing_role_invariants:
            errors.append(
                f"{rel} route_role {route_role} missing compliance_invariants: "
                f"{missing_role_invariants}"
            )
    if not isinstance(contract.get("signal_axis"), bool):
        errors.append(f"{rel} signal_axis must be boolean")


def _check_routes(
    errors: list[str],
    metadata: dict[str, dict[str, str]],
    contract: dict[str, Any],
    record: dict[str, Any],
    rel: Path,
) -> None:
    primary = _route_list(errors, contract, rel, "primary_routes", required=True)
    supporting = _route_list(errors, contract, rel, "supporting_routes", required=False)
    legacy_aliases = _route_list(errors, contract, rel, "legacy_alias_routes", required=False)

    record_routes_raw = record.get("route_paths")
    if not isinstance(record_routes_raw, list) or not record_routes_raw:
        errors.append(f"{rel} linked Journey OS record route_paths must be non-empty")
        record_routes: set[str] = set()
    else:
        record_routes = {route for route in record_routes_raw if isinstance(route, str)}

    canonical_routes = set(primary + supporting)
    covered_routes = canonical_routes | set(legacy_aliases)
    missing = sorted(record_routes - covered_routes)
    if missing:
        errors.append(f"{rel} does not cover Journey OS routes: {missing}")

    extra_canonical = sorted(canonical_routes - record_routes)
    if extra_canonical:
        errors.append(
            f"{rel} primary/supporting routes must come from Journey OS route_paths; "
            f"extra={extra_canonical}"
        )

    legacy_in_record = sorted(set(legacy_aliases) & record_routes)
    if legacy_in_record:
        errors.append(f"{rel} Journey OS must not route through legacy aliases: {legacy_in_record}")

    owner_domains = set(_strings(contract, "owner_domains"))
    for field, routes in (
        ("primary_routes", primary),
        ("supporting_routes", supporting),
        ("legacy_alias_routes", legacy_aliases),
    ):
        for route in routes:
            meta = metadata.get(route)
            if meta is None:
                errors.append(f"{rel} {field} route missing from route_metadata.dart: {route}")
                continue
            category = meta.get("category")
            if field in {"primary_routes", "supporting_routes"} and category == "alias":
                errors.append(f"{rel} {route} is a legacy alias and cannot be {field}")
            if field == "legacy_alias_routes" and category != "alias":
                errors.append(
                    f"{rel} {route} must be RouteCategory.alias when listed as legacy_alias_routes"
                )
            owner = meta.get("owner")
            if category != "alias" and owner and owner not in owner_domains:
                errors.append(
                    f"{rel} {route} owner {owner} is not listed in owner_domains {sorted(owner_domains)}"
                )


def _level_tiers(level: str) -> set[str] | None:
    if level.strip().lower() == "none":
        return set()
    parts = level.split("-")
    if len(parts) == 1 and parts[0] in CALC_TIERS:
        return {parts[0]}
    if len(parts) == 2 and all(part in CALC_TIERS for part in parts):
        start = CALC_TIERS.index(parts[0])
        end = CALC_TIERS.index(parts[1])
        if start <= end:
            return set(CALC_TIERS[start : end + 1])
    return None


def _source_missing(source: object) -> bool:
    return not isinstance(source, str) or source.strip().lower() in NONE_SOURCE_VALUES


def _repo_relative_error(value: object) -> str | None:
    if not isinstance(value, str) or not value:
        return "must be a non-empty string"
    path = Path(value)
    if path.is_absolute():
        return "must be repo-relative, not absolute"
    if ".." in path.parts:
        return "must not contain '..'"
    return None


def _source_exists(root: Path, source: object) -> bool:
    if _source_missing(source):
        return True
    assert isinstance(source, str)
    return (root / source).exists()


def _non_alias_auth_values(
    metadata: dict[str, dict[str, str]],
    routes: list[str],
) -> set[str]:
    values: set[str] = set()
    for route in routes:
        meta = metadata.get(route)
        if not meta or meta.get("category") == "alias":
            continue
        value = meta.get("requiresAuth")
        if value in {"true", "false"}:
            values.add(value)
    return values


def _check_calculation_boundary(
    errors: list[str],
    root: Path,
    contract: dict[str, Any],
    rel: Path,
) -> None:
    boundary = contract.get("calculation_boundary")
    if not isinstance(boundary, dict):
        errors.append(f"{rel} calculation_boundary must be an object")
        return

    level = boundary.get("level")
    if not isinstance(level, str) or not level.strip():
        errors.append(f"{rel} calculation_boundary.level must be a non-empty string")
        level = ""
    tiers = _level_tiers(level) if level else None
    if tiers is None:
        errors.append(f"{rel} calculation_boundary.level is unsupported: {level!r}")
        tiers = set()
    may_emit = boundary.get("may_emit_financial_number")
    if not isinstance(may_emit, bool):
        errors.append(
            f"{rel} calculation_boundary.may_emit_financial_number must be boolean"
        )
        may_emit = False

    receipt_required = contract.get("value_receipt_required")
    if not isinstance(receipt_required, bool):
        errors.append(f"{rel} value_receipt_required must be boolean")
        receipt_required = False

    receipt_fields = contract.get("receipt_fields")
    if not isinstance(receipt_fields, list):
        errors.append(f"{rel} receipt_fields must be a list")
        receipt_field_set: set[str] = set()
    else:
        receipt_field_set = {item for item in receipt_fields if isinstance(item, str)}

    if contract.get("signal_axis") is True:
        if may_emit:
            errors.append(f"{rel} signal_axis routes cannot emit financial numbers")
        if receipt_required:
            errors.append(f"{rel} signal_axis routes cannot require a value receipt")

    if not may_emit:
        if level.strip().lower() != "none":
            errors.append(f"{rel} non-value route calculation_boundary.level must be none")
        if receipt_required:
            errors.append(f"{rel} non-value route must not require a value receipt")
        if receipt_field_set:
            errors.append(f"{rel} non-value route must keep receipt_fields empty")
        return

    if level.strip().lower() == "none":
        errors.append(f"{rel} value route calculation_boundary.level cannot be none")
    if not receipt_required:
        errors.append(f"{rel} value route must set value_receipt_required=true")
    missing_fields = sorted(REQUIRED_VALUE_RECEIPT_FIELDS - receipt_field_set)
    if missing_fields:
        errors.append(f"{rel} value route missing receipt_fields: {missing_fields}")

    invariants = set(_strings(contract, "compliance_invariants"))
    if "no_financial_number_without_receipt" not in invariants:
        errors.append(
            f"{rel} value route compliance_invariants must include "
            "no_financial_number_without_receipt"
        )

    if "L1" in tiers and _source_missing(boundary.get("l1_source")):
        errors.append(f"{rel} L1 value route must declare calculation_boundary.l1_source")
    if tiers.intersection({"L2", "L3", "L4"}) and _source_missing(boundary.get("l2_l4_source")):
        errors.append(f"{rel} L2-L4 value route must declare calculation_boundary.l2_l4_source")
    for field in ("l1_source", "l2_l4_source"):
        source = boundary.get(field)
        if _source_missing(source):
            continue
        path_error = _repo_relative_error(source)
        if path_error:
            errors.append(f"{rel} calculation_boundary.{field} {path_error}: {source!r}")
        elif not _source_exists(root, source):
            errors.append(f"{rel} calculation_boundary.{field} does not exist: {source}")


def _check_proof_pointer(
    errors: list[str],
    root: Path,
    contract: dict[str, Any],
    record: dict[str, Any],
    rel: Path,
) -> None:
    proof = contract.get("proof_pointer")
    if not isinstance(proof, str) or not proof:
        return
    path_error = _repo_relative_error(proof)
    if path_error:
        errors.append(f"{rel} proof_pointer {path_error}: {proof!r}")
        return
    green_artifacts = _green_evidence_artifacts(record)
    if proof not in green_artifacts:
        errors.append(
            f"{rel} proof_pointer must match a green Journey OS evidence artifact; "
            f"found {proof}"
        )
        return
    if not (root / proof).exists():
        errors.append(f"{rel} proof_pointer artifact is not accessible: {proof}")


def _check_auth_scope(
    errors: list[str],
    metadata: dict[str, dict[str, str]],
    contract: dict[str, Any],
    rel: Path,
) -> None:
    primary = _strings(contract, "primary_routes")
    supporting = _strings(contract, "supporting_routes")
    auth_values = _non_alias_auth_values(metadata, primary + supporting)
    auth_scope = contract.get("auth_scope")
    if auth_scope == "public" and "true" in auth_values:
        errors.append(f"{rel} auth_scope public cannot include requiresAuth=true routes")
    if auth_scope == "authenticated" and "false" in auth_values:
        errors.append(
            f"{rel} auth_scope authenticated cannot include requiresAuth=false routes"
        )
    if auth_scope == "onboarding":
        primary_auth = _non_alias_auth_values(metadata, primary)
        if "true" in primary_auth:
            errors.append(f"{rel} auth_scope onboarding primary routes must not require auth")
    if auth_scope == "mixed" and auth_values != {"true", "false"}:
        errors.append(
            f"{rel} auth_scope mixed must include both requiresAuth=true and requiresAuth=false routes"
        )


def _check_route_overlap(
    errors: list[str],
    contract: dict[str, Any],
    rel: Path,
) -> None:
    route_sets = {
        field: set(_strings(contract, field))
        for field in ROUTE_LIST_FIELDS
    }
    for left, right in (
        ("primary_routes", "supporting_routes"),
        ("primary_routes", "legacy_alias_routes"),
        ("supporting_routes", "legacy_alias_routes"),
    ):
        overlap = sorted(route_sets[left] & route_sets[right])
        if overlap:
            errors.append(f"{rel} routes cannot appear in both {left} and {right}: {overlap}")


def _check_primary_route_claims(
    errors: list[str],
    contracts: dict[str, tuple[dict[str, Any], Path]],
) -> None:
    claims: dict[str, list[str]] = {}
    for journey_id, (contract, _rel) in contracts.items():
        primary_routes = contract.get("primary_routes")
        if not isinstance(primary_routes, list):
            continue
        for route in primary_routes:
            if isinstance(route, str):
                claims.setdefault(route, []).append(journey_id)
    for route, journey_ids in sorted(claims.items()):
        unique_journeys = sorted(set(journey_ids))
        if len(unique_journeys) > 1:
            errors.append(
                f"{route} is claimed as primary by multiple route contracts: {unique_journeys}"
            )


def check(root: Path) -> list[str]:
    root = root.resolve()
    errors: list[str] = []
    try:
        metadata = route_metadata(root)
    except OSError as exc:
        return [f"unable to read route metadata: {exc}"]

    records = _load_records(root, errors)
    contracts = _load_contracts(root, errors)
    guarded_records = {
        journey_id: record
        for journey_id, record in records.items()
        if record.get("tier") in GUARDED_TIERS
    }

    for journey_id in sorted(guarded_records):
        if journey_id not in contracts:
            errors.append(f"missing route contract for {journey_id}")

    for journey_id, (contract, rel) in sorted(contracts.items()):
        record = records.get(journey_id)
        if record is None:
            errors.append(f"{rel} references unknown Journey OS record {journey_id}")
            continue
        if record.get("tier") not in GUARDED_TIERS:
            errors.append(f"{rel} references unguarded tier {record.get('tier')!r}")
        if contract.get("tier") != record.get("tier"):
            errors.append(
                f"{rel} tier must match Journey OS record {record.get('tier')!r}; "
                f"found {contract.get('tier')!r}"
            )
        _check_required_shape(errors, root, contract, rel)
        _check_routes(errors, metadata, contract, record, rel)
        _check_auth_scope(errors, metadata, contract, rel)
        _check_route_overlap(errors, contract, rel)
        _check_calculation_boundary(errors, root, contract, rel)
        _check_proof_pointer(errors, root, contract, record, rel)

    _check_primary_route_claims(errors, contracts)
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    errors = check(args.root)
    if not errors:
        print("OK mint2_vz_route_contract_guard: Mint 2.0 VZ route contracts are coherent.")
        return 0
    print("FAIL mint2_vz_route_contract_guard: route contract drift detected.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
