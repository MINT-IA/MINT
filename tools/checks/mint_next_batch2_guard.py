#!/usr/bin/env python3
"""Fail-closed contract for the bounded MINT Next Batch 2 Vaud fixture."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

BASE = Path("product/mint_next/batch2")
EXPECTED_PROHIBITED = {"salary_to_taxable_inference", "contribution_recommendation", "product_or_provider_ranking", "filing_submission", "transaction_execution", "LLM_calculation", "production_tax_result"}
EXPECTED_ADJACENT = {"tax_year", "municipality", "civil_status", "children", "ordinary_taxation", "taxable_income_before_after", "pillar3a_amount", "official_rounding"}


def load(root: Path, rel: str, errors: list[str]) -> dict:
    try:
        data = yaml.safe_load((root / BASE / rel).read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"unable to load {rel}: {exc}")
        return {}
    if not isinstance(data, dict):
        errors.append(f"{rel} must contain a mapping")
        return {}
    return data


def close(a: float, b: float, tolerance: float = 0.005) -> bool:
    return abs(float(a) - float(b)) <= tolerance


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    batch = load(root, "batch.yaml", errors)
    scope = load(root, "scope.yaml", errors)
    sources = load(root, "sources.yaml", errors)
    fixture = load(root, "fixture.yaml", errors)
    official = load(root, "evidence/vd-calculator-capture-20260801.yaml", errors)
    engine = load(root, "evidence/mint-engine-capture-20260801.yaml", errors)

    if batch.get("status") != "draft_unproven" or batch.get("work_tracking", {}).get("id") != "MINT_nosync-lrp":
        errors.append("Batch 2 must remain draft and linked to its live Bead before promotion")
    excluded = set(batch.get("scope", {}).get("excludes", []))
    if not {"new_tax_engine", "gross_to_taxable_derivation", "flutter_product", "ux_winner", "jos006_closure"} <= excluded:
        errors.append("Batch 2 exclusions are incomplete")
    override = scope.get("journey_os_override", {})
    if override != {
        "current_priority": "JOS-006", "remains_open_and_unmodified": True,
        "displaced": False, "runtime_reproof_claimed": False,
        "rationale": "Batch_2_is_a_non_product_prerequisite_explicitly_required_by_the_promoted_Batch_1_contract",
    }:
        errors.append("Batch 2 must not displace or close JOS-006")

    persona = fixture.get("persona_boundary", {})
    if persona.get("gross_income_chf", "missing") is not None or persona.get("linked_to_Batch1_Lea_salary") is not False:
        errors.append("fixture must never derive taxable income from Léa's gross salary")
    assumptions = fixture.get("assumptions", {})
    expected_assumptions = {
        "tax_year": 2026, "canton": "VD", "municipality": "Lausanne",
        "full_year_domicile": True, "taxation": "ordinary", "civil_status": "single",
        "children_full_quotient": 0, "children_half_quotient": 0,
        "children_same_household": 0, "intercantonal_or_international_allocation": False,
        "taxable_wealth_icc_chf": 0, "pillar3a_eligible_employee_with_lpp": True,
        "retroactive_3a_catchup": False,
    }
    if assumptions != expected_assumptions:
        errors.append("fixture assumptions are incomplete or drifted")
    inputs = fixture.get("inputs", {})
    expected_inputs = {
        "baseline_taxable_income_icc_chf": 80000, "baseline_taxable_income_ifd_chf": 80000,
        "pillar3a_counterfactual_contribution_chf": 7258,
        "counterfactual_taxable_income_submitted_icc_chf": 72742,
        "counterfactual_taxable_income_submitted_ifd_chf": 72742,
        "official_displayed_taxable_income_chf": 72700,
    }
    if inputs != expected_inputs:
        errors.append("fixture taxable-income inputs or official rounding have drifted")

    result = fixture.get("official_result", {})
    baseline, counter, difference = result.get("baseline", {}), result.get("counterfactual", {}), result.get("difference", {})
    for key in ("icc_chf", "ifd_chf", "total_chf"):
        if not close(baseline.get(key, -1) - counter.get(key, -1), difference.get(key, -2)):
            errors.append(f"official fixture arithmetic identity failed for {key}")
    if result.get("arithmetic_identity") != "baseline_minus_counterfactual" or difference.get("total_chf") != 2104.00:
        errors.append("official fixture result identity has drifted")
    display = fixture.get("display_contract", {})
    expected_labels = {"illustrative_counterfactual", "declared_taxable_income_inputs", "official_calculator_indicative_result", "not_personalized", "not_filing_result", "not_advice"}
    if display.get("amount_chf") != 2104.00 or set(display.get("labels", [])) != expected_labels or set(display.get("required_adjacent_assumptions", [])) != EXPECTED_ADJACENT:
        errors.append("fixture display safety contract is incomplete")
    if set(fixture.get("prohibited_use", [])) != EXPECTED_PROHIBITED or str(fixture.get("expires_on")) != "2026-12-31":
        errors.append("fixture prohibited uses or expiry are incomplete")

    captures = official.get("captures", {})
    if official.get("capture_method") != "manual_form_POST_reproduced_with_requests_for_evidence_only_not_a_supported_API" or official.get("calculator_version_visible") != "10.4.0":
        errors.append("official calculator capture method/version is overstated or drifted")
    exact_official = {
        "baseline": {"taxable": 80000, "icc": 14423.15, "ifd": 1378.20, "total": 15801.35, "hash": "7640653ee007938ed3b1c5030b67acb32189949f55492236de53d2c2d1293eb8"},
        "counterfactual": {"taxable": 72700, "icc": 12648.75, "ifd": 1048.60, "total": 13697.35, "hash": "096d533d09b7d26cb0857ad3a8d24df83ca5a15e8489150f62eed76aaf221485"},
    }
    for name, expected in exact_official.items():
        capture = captures.get(name, {})
        normalized = capture.get("normalized_output", {})
        if capture.get("response_sha256") != expected["hash"] or normalized.get("taxable_income_displayed_chf") != expected["taxable"] or normalized.get("icc_total_chf") != expected["icc"] or normalized.get("ifd_total_chf") != expected["ifd"] or normalized.get("total_chf") != expected["total"] or not close(normalized.get("icc_total_chf", -1) + normalized.get("ifd_total_chf", -1), normalized.get("total_chf", -2)):
            errors.append(f"official {name} capture is incomplete")
    if official.get("raw_source_retention") != "hashes_only_public_repo_does_not_store_source_HTML":
        errors.append("official raw-source redistribution boundary has drifted")

    source_items = {item.get("id"): item for item in sources.get("sources", []) if isinstance(item, dict)}
    if set(source_items) != {"vd_calculator", "vd_income_scale_2026", "vd_municipal_rates_2026", "ofas_pillar3a_2026", "ifd_scale_2026"}:
        errors.append("official source allowlist is incomplete")
    if sources.get("machine_api_status") != "no_supported_or_licensed_Vaud_API_identified" or not all(item.get("supports") for item in source_items.values()):
        errors.append("source licensing/support claims are incomplete")
    if source_items.get("vd_calculator", {}).get("response_sha256_baseline") != captures.get("baseline", {}).get("response_sha256") or source_items.get("vd_calculator", {}).get("response_sha256_counterfactual") != captures.get("counterfactual", {}).get("response_sha256"):
        errors.append("official calculator response hashes do not match capture receipt")
    expected_supports = {
        "vd_calculator": {"taxable_income_and_fortune_are_required", "results_are_indicative", "definitive_tax_is_set_by_ACI", "fixture_inputs_and_outputs"},
        "vd_income_scale_2026": {"icc_base_80000_is_6389", "icc_base_72700_is_5603", "fractions_below_100_are_abandoned"},
        "vd_municipal_rates_2026": {"lausanne_income_tax_coefficient_78_5"},
        "ofas_pillar3a_2026": {"employee_with_pension_fund_3a_ceiling_7258"},
        "ifd_scale_2026": {"ifd_2026_single_person_scale"},
    }
    if any(set(source_items.get(key, {}).get("supports", [])) != value for key, value in expected_supports.items()):
        errors.append("official source support claims have drifted")

    canonical = engine.get("canonical_engine", {})
    engine_path = root / str(canonical.get("path", ""))
    if canonical.get("path") != "services/backend/app/services/fiscal/cantonal_comparator.py" or canonical.get("symbols") != ["estimate_income_tax", "estimate_income_tax_parts"]:
        errors.append("Batch 2 must reuse only the canonical backend tax engine")
    if not engine_path.is_file() or hashlib.sha256(engine_path.read_bytes()).hexdigest() != canonical.get("sha256"):
        errors.append("canonical engine hash mismatch")
    oracle = engine.get("oracle_comparison", {})
    if oracle.get("per_component_tolerance_relative") != 0.02 or oracle.get("ifd_tolerance_absolute_chf") != 1.50:
        errors.append("pre-existing oracle tolerance floors have drifted")
    if oracle.get("baseline_cantonal_communal_relative_error", 1) > 0.02 or oracle.get("counterfactual_cantonal_communal_relative_error", 1) > 0.02 or oracle.get("baseline_ifd_absolute_error_chf", 99) > 1.5 or oracle.get("counterfactual_ifd_absolute_error_chf", 99) > 1.5:
        errors.append("canonical engine exceeds the bounded oracle tolerance")
    outputs = engine.get("outputs", {})
    for key in ("cantonal_communal_chf", "ifd_chf", "total_chf"):
        if not close(outputs.get("baseline", {}).get(key, -1) - outputs.get("counterfactual", {}).get(key, -1), outputs.get("difference", {}).get(key, -2)):
            errors.append(f"MINT engine arithmetic identity failed for {key}")
    if oracle.get("official_delta_chf") != 2104.00 or oracle.get("mint_delta_chf") != 2166.59 or oracle.get("delta_difference_chf") != 62.59 or oracle.get("delta_relative_error") != 0.029748:
        errors.append("disclosed MINT-vs-official delta gap has drifted")
    if "delta_error_is_disclosed_not_declared_exact" not in str(engine.get("claim_boundary", "")):
        errors.append("engine comparison must disclose that the delta is not exact")
    # Execute the canonical code. Stored engine evidence must not become a
    # self-consistent fiction after a source change.
    try:
        python = shutil.which("python3.11") or sys.executable
        code = """import json
from app.services.fiscal.cantonal_comparator import estimate_income_tax, estimate_income_tax_parts
out = {}
for name, income in ((\"baseline\", 80000), (\"counterfactual\", 72700)):
    ifd, cc = estimate_income_tax_parts(income, \"VD\")
    out[name] = {\"taxable_income_chf\": income, \"cantonal_communal_chf\": round(cc, 2), \"ifd_chf\": round(ifd, 2), \"total_chf\": round(estimate_income_tax(income, \"VD\"), 2)}
print(json.dumps(out))
"""
        proc = subprocess.run([python, "-c", code], cwd=root / "services/backend", capture_output=True, text=True, timeout=20)
        if proc.returncode:
            raise RuntimeError(proc.stderr[-500:])
        runtime = json.loads(proc.stdout)
        for name in runtime:
            if any(not close(runtime[name][key], outputs.get(name, {}).get(key, -999)) for key in runtime[name]):
                errors.append(f"stored MINT engine evidence does not match runtime for {name}")
    except Exception as exc:
        errors.append(f"unable to execute canonical MINT engine: {exc}")
    return errors


def live_errors(root: Path) -> list[str]:
    common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=root, capture_output=True, text=True)
    if common.returncode:
        return ["unable to locate canonical repository for live Bead check"]
    canonical = Path(common.stdout.strip()).parent
    proc = subprocess.run(["bd", "show", "MINT_nosync-lrp", "--json"], cwd=canonical, capture_output=True, text=True)
    try:
        item = json.loads(proc.stdout)[0]
    except Exception:
        return ["unable to parse live Batch 2 Bead"]
    return [] if item.get("status") == "in_progress" else [f"live Batch 2 Bead must be in_progress, got {item.get('status')}"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--live-work-tracking", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    errors = validate(root)
    if args.live_work_tracking:
        errors.extend(live_errors(root))
    if errors:
        for error in errors:
            print(f"ERROR mint_next_batch2_guard: {error}", file=sys.stderr)
        return 1
    print("OK mint_next_batch2_guard: bounded Vaud fixture remains explicit, sourced, and unpromoted.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
