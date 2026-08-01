#!/usr/bin/env python3
"""Fail-closed contract for the bounded MINT Next Batch 2 Vaud fixture."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import yaml

BASE = Path("product/mint_next/batch2")
EXPECTED_PROHIBITED = {"salary_to_taxable_inference", "contribution_recommendation", "product_or_provider_ranking", "filing_submission", "transaction_execution", "LLM_calculation", "production_tax_result"}
EXPECTED_ADJACENT = {"tax_year", "municipality", "civil_status", "children", "ordinary_taxation", "taxable_income_before_after", "pillar3a_amount", "pillar3a_credit_timing", "official_rounding"}
EXPECTED_REQUEST = {"tax_year": 2026, "municipality": "Lausanne", "civil_status_code": 1, "children_full": 0, "children_half": 0, "children_household": 0, "taxable_wealth_icc_chf": 0, "calculate_icc": True, "calculate_ifd": True, "allocation": False}
EXPECTED_SOURCES = {
    "vd_calculator": ("Etat_de_Vaud_ACI", "https://www.vd.ch/etat-droit-finances/impots/impots-pour-les-individus/calculer-mes-impots", None, None),
    "vd_income_scale_2026": ("Etat_de_Vaud_ACI", "https://www.vd.ch/fileadmin/user_upload/organisation/dfin/aci/fichiers_pdf/Bar%C3%A8mes_Revenu_2026.pdf", "34cb7f9f38ff8d8ea8e13b966986720a7a55b72947ad31224ce625209fcf3171", 257586),
    "vd_municipal_rates_2026": ("Etat_de_Vaud", "https://www.vd.ch/fileadmin/user_upload/themes/territoire/communes/finances_communales/fichiers_xls/Arr%C3%AAt%C3%A9s_d_imposition_2026.xls", "e7e04fc78b69a08c09d160afd1083a2291c08fc8b53b3b4726d7bee273cc260a", 104960),
    "ofas_pillar3a_2026": ("OFAS", "https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf", "da5dc20f34e0dc7f4c47d218f253b3915880c10d04e370eaa224b6437a97e1a3", 204118),
    "ifd_scale_2026": ("AFC", "https://www.estv.admin.ch/dam/fr/sd-web/gnde9CmEsalK/dbst-tairfe-58c-2026-dfi.pdf", "a8a0ff6914523b9e5defa533759ee69daee892d3ab8669e21881de4728cfceaa", 142066),
    "vd_cantonal_reduction_2026": ("Etat_de_Vaud_ACI", "https://www.vd.ch/etat-droit-finances/impots/impots-pour-les-individus/payer-mes-impots", None, None),
}
RECEIPT_SHA256 = "5ed976cb07688a6d08cba29f96e9c2a451fb3546f5daf6cc5fe58a4348832293"
VERIFIER_SHA256 = "9cfd4b7ec4e0644633b82af164ae9311deb38b97736179a8774c56f335605a8d"
EXPECTED_LAST_MODIFIED = {
    "vd_income_scale_2026": "Thu, 02 Apr 2026 07:49:44 GMT",
    "vd_municipal_rates_2026": "Tue, 16 Dec 2025 07:30:48 GMT",
    "ofas_pillar3a_2026": "Wed, 05 Nov 2025 13:47:13 GMT",
    "ifd_scale_2026": "Thu, 19 Feb 2026 15:12:05 GMT",
}
EXPECTED_ORACLE_HASHES = {"test_sha256": "516ecb2faf8468d2ed40abd377e317083e5eff10167dd94744bd605aa8a0af08", "fixture_sha256": "11775899c1a736cc69dd3c3df17af3208658726a930983556fc7fa35c9d7a977"}


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
    promotion = load(root, "evidence/promotion-20260801.yaml", errors)
    bead_receipt = load(root, "evidence/bead-MINT_nosync-lrp.yaml", errors)

    promoted_status = "proven_bounded_fixture_not_product_connected"
    if batch.get("status") != promoted_status or batch.get("work_tracking") != {"system": "beads", "id": "MINT_nosync-lrp", "expected_live_status": "closed"}:
        errors.append("Batch 2 promoted status must match its closed live Bead")
    expected_batch_scope = {"includes": ["one_vd_2026_fixture", "official_before_after_capture", "canonical_engine_comparison", "provenance", "mutation_guards", "independent_roast"], "excludes": ["new_tax_engine", "gross_to_taxable_derivation", "flutter_product", "ux_winner", "user_validation", "production_connection", "nationwide_tax_claim", "jos006_closure"]}
    expected_artifacts = {"scope": "product/mint_next/batch2/scope.yaml", "sources": "product/mint_next/batch2/sources.yaml", "fixture": "product/mint_next/batch2/fixture.yaml", "official_capture": "product/mint_next/batch2/evidence/vd-calculator-capture-20260801.yaml", "engine_capture": "product/mint_next/batch2/evidence/mint-engine-capture-20260801.yaml", "normalized_receipt": "product/mint_next/batch2/evidence/vd-calculator-normalized-receipt-20260801.json", "replay_verifier": "product/mint_next/batch2/evidence/verify_vd_calculator_receipt.py", "promotion_receipt": "product/mint_next/batch2/evidence/promotion-20260801.yaml", "work_tracking_receipt": "product/mint_next/batch2/evidence/bead-MINT_nosync-lrp.yaml"}
    expected_promotion = {"author_cannot_approve": True, "requires": ["official_source_hashes", "arithmetic_identity", "canonical_engine_identity", "per_component_oracle_tolerance", "swiss_tax_review", "licensing_boundary_review", "independent_roast_no_p1_p2"], "never_sufficient": ["author_claim", "same_engine_expected_values", "file_existence", "mutable_web_page_without_capture_receipt", "test_exit_code_without_mutation"]}
    if batch.get("scope") != expected_batch_scope or batch.get("artifacts") != expected_artifacts:
        errors.append("Batch 2 exact scope, exclusions, or artifact paths have drifted")
    if batch.get("promotion") != expected_promotion:
        errors.append("Batch 2 zero-trust promotion contract has drifted")
    expected_forbidden = {"fixture_is_a_personal_tax_estimate", "engine_is_exact_for_Vaud", "all_Swiss_tax_cases_are_supported", "FINMA_compliance_is_certified", "direction_winner_selected", "user_testing_completed", "product_runtime_delivered", "official_machine_API_is_licensed"}
    if scope.get("decision") != "bounded_verification_fixture_only" or scope.get("upstream_requirement") != "product/mint_next/batch1/evaluation.yaml#promotion.before_winner_selection" or set(scope.get("forbidden_claims", [])) != expected_forbidden:
        errors.append("Batch 2 bounded decision or forbidden claims have drifted")
    override = scope.get("journey_os_override", {})
    if override != {
        "current_priority": "JOS-006", "remains_open_and_unmodified": True,
        "displaced": False, "runtime_reproof_claimed": False,
        "rationale": "Batch_2_is_a_non_product_prerequisite_explicitly_required_by_the_promoted_Batch_1_contract",
    }:
        errors.append("Batch 2 must not displace or close JOS-006")

    persona = fixture.get("persona_boundary", {})
    expected_persona = {"synthetic": True, "linked_to_Batch1_Lea_salary": False, "gross_income_chf": None, "warning": "taxable_income_is_declared_input_never_derived_from_salary"}
    if persona != expected_persona:
        errors.append("fixture must never derive taxable income from Léa's gross salary")
    if fixture.get("fixture_id") != "B2-VD-3A-2026-01" or fixture.get("purpose") != "compare_three_Batch_1_mechanisms_with_one_identical_officially_captured_counterfactual":
        errors.append("fixture identity or bounded purpose has drifted")
    if any(item.get("schema_version") != 1 for item in (batch, scope, sources, fixture, official, engine, promotion, bead_receipt)):
        errors.append("Batch 2 YAML schema version has drifted")
    expected_reviews = {"scope_roast": {"reviewer": "batch2_scope_roast", "verdict": "ROAST_PASS"}, "swiss_tax_and_licensing": {"reviewer": "batch2_sources_compliance", "verdict": "ROAST_PASS"}, "engine_and_provenance": {"reviewer": "batch2_engine_audit", "verdict": "ROAST_PASS"}}
    expected_proofs = {"targeted_and_workflow_tests": "66_passed", "swiss_tax_targeted_tests": "46_passed", "live_official_replay": "pass_version_echoes_outputs_and_5_percent_claim", "canonical_engine_runtime": "pass_python_3_9_and_3_11", "repository_guards": "pass", "live_work_tracking": "closed"}
    expected_limitations = {"official_result_is_indicative": True, "personalized_tax_estimate_delivered": False, "tax_filing_result_delivered": False, "advice_or_recommendation_delivered": False, "supported_or_licensed_vaud_api_identified": False, "flutter_product_runtime_delivered": False, "production_connection_delivered": False, "nationwide_swiss_tax_coverage_delivered": False, "ux_winner_selected": False, "user_testing_completed": False, "jos006_closed_or_displaced": False, "mint_delta_gap_chf": 62.59}
    if promotion != {"schema_version": 1, "batch": "mint_next_batch2_bounded_vaud_fixture", "status": promoted_status, "audited_head": "d0fc4f587913de9e2b6d044108c29be72fbafee9", "unresolved_p1_p2": 0, "independent_reviews": expected_reviews, "proofs": expected_proofs, "limitations": expected_limitations}:
        errors.append("Batch 2 proven status requires the exact independent promotion receipt")
    normalized_bead = {key: (value.isoformat().replace("+00:00", "Z") if key == "closed_at" and hasattr(value, "isoformat") else value) for key, value in bead_receipt.items()}
    expected_bead = {"schema_version": 1, "id": "MINT_nosync-lrp", "title": "MINT Next Batch 2 — verified Vaud tax fixture", "status": "closed", "closed_at": "2026-08-01T18:47:09Z", "close_reason": "Batch 2 bounded Vaud fixture independently audited with no P1/P2 at d0fc4f587913de9e2b6d044108c29be72fbafee9; no product or nationwide claim.", "audited_head": "d0fc4f587913de9e2b6d044108c29be72fbafee9"}
    if normalized_bead != expected_bead:
        errors.append("Batch 2 closed Bead receipt has drifted")
    assumptions = fixture.get("assumptions", {})
    expected_assumptions = {
        "tax_year": 2026, "canton": "VD", "municipality": "Lausanne",
        "full_year_domicile": True, "taxation": "ordinary", "civil_status": "single",
        "children_full_quotient": 0, "children_half_quotient": 0,
        "children_same_household": 0, "intercantonal_or_international_allocation": False,
        "taxable_wealth_icc_chf": 0, "pillar3a_eligible_employee_with_lpp": True,
        "pillar3a_contribution_credited_in_tax_year": True,
        "retroactive_3a_catchup": False,
    }
    if assumptions != expected_assumptions:
        errors.append("fixture assumptions are incomplete or drifted")
    if fixture.get("status") != promoted_status:
        errors.append("fixture status must match the bounded promotion receipt")
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
    if result.get("source_capture") != "product/mint_next/batch2/evidence/vd-calculator-capture-20260801.yaml":
        errors.append("fixture official source-capture path has drifted")
    display = fixture.get("display_contract", {})
    expected_labels = {"illustrative_counterfactual", "declared_taxable_income_inputs", "official_calculator_indicative_result", "not_personalized", "not_filing_result", "not_advice"}
    if display.get("amount_chf") != 2104.00 or set(display.get("labels", [])) != expected_labels or set(display.get("required_adjacent_assumptions", [])) != EXPECTED_ADJACENT:
        errors.append("fixture display safety contract is incomplete")
    if set(fixture.get("prohibited_use", [])) != EXPECTED_PROHIBITED or str(fixture.get("expires_on")) != "2026-12-31":
        errors.append("fixture prohibited uses or expiry are incomplete")

    captures = official.get("captures", {})
    if official.get("capture_method") != "manual_form_POST_reproduced_with_requests_for_evidence_only_not_a_supported_API" or official.get("calculator_version_visible") != "10.4.0" or official.get("claim_boundary") != "official_page_calls_results_indicative_and_ACI_sets_definitive_tax":
        errors.append("official calculator capture method/version is overstated or drifted")
    if official.get("request_common") != EXPECTED_REQUEST:
        errors.append("official request assumptions have drifted")
    if official.get("captured_utc").isoformat() != "2026-08-01T18:14:30+00:00" or official.get("source_id") != "vd_calculator" or official.get("posted_municipality_value") != "lausanne" or official.get("observed_commune_option") != {"id": "commune3260", "value": "lausanne", "data_periode": 2026, "text": "Lausanne"}:
        errors.append("official capture provenance or commune identity has drifted")
    exact_official = {
        "baseline": {"submitted": {"taxable_income_icc_chf": 80000, "taxable_income_ifd_chf": 80000}, "normalized": {"family_share": 1.0, "taxable_income_displayed_chf": 80000, "icc_base_chf": 6389.0, "cantonal_coefficient": 155.0, "cantonal_reduction_rate": 0.05, "cantonal_charge_chf": 9407.8, "municipal_coefficient": 78.5, "municipal_charge_chf": 5015.35, "icc_total_chf": 14423.15, "ifd_base_chf": 1378.2, "ifd_total_chf": 1378.2, "total_chf": 15801.35}},
        "counterfactual": {"submitted": {"taxable_income_icc_chf": 72742, "taxable_income_ifd_chf": 72742}, "normalized": {"family_share": 1.0, "taxable_income_displayed_chf": 72700, "icc_base_chf": 5603.0, "cantonal_coefficient": 155.0, "cantonal_reduction_rate": 0.05, "cantonal_charge_chf": 8250.4, "municipal_coefficient": 78.5, "municipal_charge_chf": 4398.35, "icc_total_chf": 12648.75, "ifd_base_chf": 1048.6, "ifd_total_chf": 1048.6, "total_chf": 13697.35}},
    }
    for name, expected in exact_official.items():
        capture = captures.get(name, {})
        normalized = capture.get("normalized_output", {})
        if capture.get("submitted") != expected["submitted"]:
            errors.append(f"official {name} submitted inputs have drifted")
        if normalized != expected["normalized"] or not close(normalized.get("icc_total_chf", -1) + normalized.get("ifd_total_chf", -1), normalized.get("total_chf", -2)):
            errors.append(f"official {name} capture is incomplete")
        expected_canton = normalized.get("icc_base_chf", 0) * normalized.get("cantonal_coefficient", 0) / 100 * (1 - normalized.get("cantonal_reduction_rate", 9))
        if not close(expected_canton, normalized.get("cantonal_charge_chf", -1), 0.02):
            errors.append(f"official {name} cantonal reduction arithmetic is incomplete")
    if baseline != {"icc_chf": 14423.15, "ifd_chf": 1378.2, "total_chf": 15801.35} or counter != {"icc_chf": 12648.75, "ifd_chf": 1048.6, "total_chf": 13697.35} or difference != {"icc_chf": 1774.4, "ifd_chf": 329.6, "total_chf": 2104.0}:
        errors.append("fixture official result does not match exact source capture")
    if official.get("raw_source_retention") != "no_dynamic_HTML_retained_canonical_normalized_JSON_and_manual_replay_recipe_only":
        errors.append("official raw-source redistribution boundary has drifted")
    receipt_path = root / str(official.get("normalized_receipt_path", ""))
    verifier_path = root / str(official.get("manual_replay_verifier", ""))
    if official.get("normalized_receipt_sha256") != RECEIPT_SHA256 or not receipt_path.is_file() or hashlib.sha256(receipt_path.read_bytes()).hexdigest() != RECEIPT_SHA256 or not verifier_path.is_file() or hashlib.sha256(verifier_path.read_bytes()).hexdigest() != VERIFIER_SHA256:
        errors.append("canonical normalized calculator receipt or verifier is missing")
    elif subprocess.run([sys.executable, str(verifier_path), "--self-test"], cwd=root, capture_output=True, text=True, timeout=10).returncode:
        errors.append("calculator receipt verifier self-test failed")
    else:
        try:
            if json.loads(receipt_path.read_text(encoding="utf-8")).get("schema_version") != 1:
                errors.append("normalized receipt schema version has drifted")
        except Exception as exc:
            errors.append(f"unable to parse normalized receipt schema: {exc}")

    source_items = {item.get("id"): item for item in sources.get("sources", []) if isinstance(item, dict)}
    if sources.get("captured_utc").isoformat() != "2026-08-01T18:14:30+00:00":
        errors.append("source capture timestamp has drifted")
    if sources.get("redistribution_boundary") != "store_minimal_extracted_facts_urls_dates_and_hashes_only_no_source_documents_or_calculator_code":
        errors.append("source redistribution boundary has drifted")
    if set(source_items) != set(EXPECTED_SOURCES):
        errors.append("official source allowlist is incomplete")
    if sources.get("machine_api_status") != "no_supported_or_licensed_Vaud_API_identified" or not all(item.get("supports") for item in source_items.values()):
        errors.append("source licensing/support claims are incomplete")
    if source_items.get("vd_calculator", {}).get("normalized_receipt_sha256") != RECEIPT_SHA256:
        errors.append("official calculator normalized receipt hash does not match evidence")
    expected_supports = {
        "vd_calculator": {"taxable_income_and_fortune_are_required", "results_are_indicative", "definitive_tax_is_set_by_ACI", "fixture_inputs_and_outputs"},
        "vd_income_scale_2026": {"icc_base_80000_is_6389", "icc_base_72700_is_5603", "fractions_below_100_are_abandoned"},
        "vd_municipal_rates_2026": {"lausanne_income_tax_coefficient_78_5"},
        "ofas_pillar3a_2026": {"employee_with_pension_fund_3a_ceiling_7258"},
        "ifd_scale_2026": {"ifd_2026_single_person_scale"},
        "vd_cantonal_reduction_2026": {"cantonal_personal_income_tax_reduction_5_percent_for_2026"},
    }
    if any(set(source_items.get(key, {}).get("supports", [])) != value for key, value in expected_supports.items()):
        errors.append("official source support claims have drifted")
    for source_id, (authority, url, digest, size) in EXPECTED_SOURCES.items():
        item = source_items.get(source_id, {})
        if item.get("authority") != authority or item.get("url") != url or (digest is not None and (item.get("sha256") != digest or item.get("bytes") != size)):
            errors.append(f"official source metadata has drifted for {source_id}")
    if any(source_items.get(key, {}).get("last_modified_http") != value for key, value in EXPECTED_LAST_MODIFIED.items()) or source_items.get("vd_calculator", {}).get("version_visible") != "10.4.0":
        errors.append("official source version or last-modified metadata has drifted")
    if source_items.get("vd_cantonal_reduction_2026", {}).get("verification") != "exact_claim_checked_by_manual_live_replay":
        errors.append("cantonal reduction claim verification has drifted")

    canonical = engine.get("canonical_engine", {})
    engine_path = root / str(canonical.get("path", ""))
    if canonical.get("path") != "services/backend/app/services/fiscal/cantonal_comparator.py" or canonical.get("symbols") != ["estimate_income_tax", "estimate_income_tax_parts"]:
        errors.append("Batch 2 must reuse only the canonical backend tax engine")
    if not engine_path.is_file() or hashlib.sha256(engine_path.read_bytes()).hexdigest() != canonical.get("sha256"):
        errors.append("canonical engine hash mismatch")
    if canonical.get("git_head") != "f6b8a0172d2ef5007964c73ecb217f280659a87b":
        errors.append("canonical engine git provenance has drifted")
    oracle = engine.get("oracle_comparison", {})
    if engine.get("comparison_basis") != "official_displayed_taxable_income_after_rounding" or engine.get("existing_oracle", {}).get("tolerance_policy") != "max_2_percent_or_measured_point_specific_band_for_cantonal_component_and_1_5_CHF_IFD_2026":
        errors.append("engine comparison basis or oracle policy has drifted")
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
    recomputed = {
        "baseline_cantonal_communal_relative_error": round(abs(outputs.get("baseline", {}).get("cantonal_communal_chf", 0) - 14423.15) / 14423.15, 6),
        "counterfactual_cantonal_communal_relative_error": round(abs(outputs.get("counterfactual", {}).get("cantonal_communal_chf", 0) - 12648.75) / 12648.75, 6),
        "baseline_ifd_absolute_error_chf": round(abs(outputs.get("baseline", {}).get("ifd_chf", 0) - 1378.20), 2),
        "counterfactual_ifd_absolute_error_chf": round(abs(outputs.get("counterfactual", {}).get("ifd_chf", 0) - 1048.60), 2),
    }
    if any(oracle.get(key) != value for key, value in recomputed.items()):
        errors.append("oracle component errors do not match recomputed evidence")
    existing = engine.get("existing_oracle", {})
    if any(existing.get(key) != value for key, value in EXPECTED_ORACLE_HASHES.items()):
        errors.append("existing oracle recorded hashes have drifted")
    for rel, key in (("services/backend/tests/test_estv_oracle.py", "test_sha256"), ("services/backend/tests/fixtures/estv_oracle_2025.jsonl", "fixture_sha256")):
        path = root / rel
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != existing.get(key):
            errors.append(f"existing oracle file hash mismatch for {rel}")
    if engine.get("captured_utc").isoformat() != "2026-08-01T18:14:30+00:00" or engine.get("claim_boundary") != "engine_matches_each_official_component_within_preexisting_oracle_floors_but_delta_error_is_disclosed_not_declared_exact":
        errors.append("engine comparison must disclose that the delta is not exact")
    # Execute the canonical code. Stored engine evidence must not become a
    # self-consistent fiction after a source change.
    try:
        python = sys.executable
        code = """import json, sys, types
from pathlib import Path
module = types.ModuleType("mint_batch2_canonical_engine")
sys.modules[module.__name__] = module
source = Path("app/services/fiscal/cantonal_comparator.py").read_text(encoding="utf-8")
exec(compile("from __future__ import annotations\\n" + source, "cantonal_comparator.py", "exec"), module.__dict__)
estimate_income_tax = module.estimate_income_tax
estimate_income_tax_parts = module.estimate_income_tax_parts
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
    return [] if item.get("status") == "closed" else [f"live Batch 2 Bead must be closed, got {item.get('status')}"]


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
    print("OK mint_next_batch2_guard: bounded Vaud fixture promotion remains evidence-linked and non-product.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
