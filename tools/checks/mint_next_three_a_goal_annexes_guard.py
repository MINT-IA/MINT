#!/usr/bin/env python3
"""Fail-closed structural guard for the bounded Batch56 B0a contract."""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
ANNEX = ROOT / ".planning/phases/mint-next-vertical01-3a-20260802/annexes"
FILES = {
    "authority-receipts.yaml", "content-review-receipt.yaml", "golden-fixtures.json", "normalized-ruleset.yaml",
    "parser-version-manifest.yaml", "persona-case-matrix.yaml",
    "source-authority-manifest.yaml", "source-extractions.json",
}
SOURCE_IDS = {
    "afc_circular_18a", "ifd_scale_2026", "lausanne_tax_decree_2025_2029",
    "ofas_amounts_2026", "ofas_contribution_page", "vd_cantonal_reduction_2026",
    "vd_deductions_2026", "vd_income_scale_2026",
}
EXPECTED_CASES = {
    "A": ("primary_complete", "exact_arithmetic", "non_binding_model_estimate", "eligible_if_affordable", None, "supported"),
    "B": ("independent_without_LPP", "unavailable", "unavailable", "blocked", "unsupported_persona", "unsupported"),
    "C": ("mixed_activity_or_LPP_ambiguous", "unavailable", "unavailable", "blocked", "clarification_required", "unavailable"),
    "D": ("no_AVS_income", "ineligible", "unavailable", "blocked", "no_eligibility", "unsupported"),
    "E": ("multi_provider_inventory_incomplete", "unknown", "unavailable", "blocked", "completeness_unconfirmed", "unavailable"),
    "F": ("ordinary_room_zero_and_2025_catchup_requested", 0, "unavailable", "blocked", "catchup_detected_unsupported", "unsupported"),
    "G": ("source_tax_frontier_or_partial_liability", "unavailable", "unavailable", "blocked", "unsupported_taxation", "unsupported"),
    "H": ("dual_income_couple", "unavailable", "unavailable", "blocked", "unsupported_household", "unsupported"),
    "I": ("activity_after_reference_age", "unavailable", "unavailable", "blocked", "unsupported_age_activity", "unsupported"),
    "J": ("primary_but_affordability_gate_fails", "displayable", "unavailable_until_engine_independently_proven", "blocked", "safety_gate", "unavailable"),
}
SHA = re.compile(r"[0-9a-f]{64}")
EXPECTED_EXTRACTIONS_SHA256 = "080658b9388b9c7eea748d904ec73b406d50b91560d2ed3b62ba7a1759fb54a0"
EXPECTED_CONTENT_REVIEW_SHA256 = "ff22a3c8f9841a74ab9d77093a46e680b38eca7680395fb005b82ea44e24c401"
EXPECTED_SOURCE_BYTES = {
    "afc_circular_18a": ("AFC", "https://www.estv.admin.ch/dam/fr/sd-web/yQgKmvu80LEr/dbst-ks-2025-1-018a-dv-fr.pdf", 298396, "68b8d3a4b2cf436a1db9eeed6b21d40e5c2ca723a52e11cf9c45d1bb0d4b3934"),
    "ifd_scale_2026": ("AFC", "https://www.estv.admin.ch/dam/fr/sd-web/gnde9CmEsalK/dbst-tairfe-58c-2026-dfi.pdf", 142066, "a8a0ff6914523b9e5defa533759ee69daee892d3ab8669e21881de4728cfceaa"),
    "lausanne_tax_decree_2025_2029": ("Ville_de_Lausanne", "https://www.lausanne.ch/dam/jcr%3A268e78be-adb8-459a-976c-2abe38813029/Comptes-2023-preavis-annexe-1.pdf", 650628, "8824562fe48194f339b89786ad8e62741c3f64c6ef8bb7e83d47b6b9a4c7ed1b"),
    "ofas_amounts_2026": ("OFAS", "https://www.bsv.admin.ch/dam/fr/sd-web/sAgdISSXenMT/f_Betr%C3%A4ge%202026.pdf", 204118, "da5dc20f34e0dc7f4c47d218f253b3915880c10d04e370eaa224b6437a97e1a3"),
    "ofas_contribution_page": ("OFAS", "https://www.bsv.admin.ch/fr/votre-cotisation-au-3e-pilier", 339755, "0c4826c99bdc62472ae0416b06e9c873c34d0253df87843836251c48c68e7ae3"),
    "vd_cantonal_reduction_2026": ("VD_ACI", "https://www.vd.ch/etat-droit-finances/impots/impots-pour-les-individus/payer-mes-impots", 53397, "cecac1bab45eae3ddda9dfafd5e6b9299af6035a69103a96170b259d00b3e3c8"),
    "vd_deductions_2026": ("VD_ACI", "https://www.vd.ch/fileadmin/user_upload/organisation/dfin/aci/fichiers_pdf/Tableau_des_d%C3%A9ductions_2026.pdf", 231744, "687e8e2ee5c45187d53ada71cf13d27d2a063c894905b007529dd057c818c7f3"),
    "vd_income_scale_2026": ("VD_ACI", "https://www.vd.ch/fileadmin/user_upload/organisation/dfin/aci/fichiers_pdf/Bar%C3%A8mes_Revenu_2026.pdf", 257586, "34cb7f9f38ff8d8ea8e13b966986720a7a55b72947ad31224ce625209fcf3171"),
}
EXPECTED_EXTRACTIONS = {
    "afc_circular_18a": ("credit_deadline", "31_december", "date_rule"),
    "ifd_scale_2026": ("ifd_single_scale", "form_58c_2026", "table"),
    "lausanne_tax_decree_2025_2029": ("lausanne_coefficient", 78.5, "percent"),
    "ofas_amounts_2026": ("ordinary_cap_table", 7258, "CHF"),
    "ofas_contribution_page": ("ordinary_cap_web", 7258, "CHF"),
    "vd_cantonal_reduction_2026": ("vd_reduction", 5.0, "percent"),
    "vd_deductions_2026": ("vd_coefficient", 155.0, "percent"),
    "vd_income_scale_2026": ("vd_scale_anchor", "72700:5603.00|80000:6389.00", "CHF_pairs"),
}


def load(name: str):
    path = ANNEX / name
    return json.loads(path.read_text()) if path.suffix == ".json" else yaml.safe_load(path.read_text())


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def validate(root: Path = ROOT) -> None:
    global ANNEX
    old = ANNEX
    ANNEX = root / ".planning/phases/mint-next-vertical01-3a-20260802/annexes"
    try:
        bundle = load("bundle.yaml")
        require(bundle["scope"] == "B0a_only_does_not_close_B0_or_activate_Goal", "scope drift")
        review_pending = "mechanically_extracted_pending_independent_content_review_engine_unproven"
        review_accepted = "mechanically_extracted_content_review_accepted_engine_unproven"
        require(bundle["status"] == review_accepted, "bundle post-review status drift")
        require(set(bundle["artifacts"]) == FILES, "bundle inventory drift")
        require(bundle["next_gate"] == "Batch56b_SPEC_hash_pinning_only", "next gate drift")
        for name, expected in bundle["artifacts"].items():
            require(SHA.fullmatch(expected) is not None, f"invalid artifact hash: {name}")
            require(hashlib.sha256((ANNEX / name).read_bytes()).hexdigest() == expected, f"artifact drift: {name}")
        external = {"tools/authority/normalize_three_a_2026_sources.py", "tools/authority/tests/test_normalize_three_a_2026_sources.py"}
        require(set(bundle["external_artifacts"]) == external, "external inventory drift")
        for name, expected in bundle["external_artifacts"].items():
            require(hashlib.sha256((root / name).read_bytes()).hexdigest() == expected, f"external artifact drift: {name}")

        raw = "\n".join((ANNEX / name).read_text() for name in FILES | {"bundle.yaml"})
        require(not re.search(r"\b(TBD|TODO|PLACEHOLDER)\b", raw, re.I), "placeholder forbidden")

        matrix = load("persona-case-matrix.yaml")
        expected_persona = {"age": "18_to_65", "domicile": "Lausanne_VD_full_2026", "taxation": "ordinary_not_source", "household": "single_no_children", "activity": "salaried_with_AVS_income", "lpp": "confirmed_active", "contribution": "ordinary_2026_only", "provider_inventory": "exhaustively_confirmed", "financial_literacy": "novice"}
        require(matrix["primary_persona"] == expected_persona, "primary persona drift")
        cases = matrix["cases"]
        require([case["id"] for case in cases] == list("ABCDEFGHIJ"), "cases must be exact ordered A-J")
        for case in cases:
            expected = EXPECTED_CASES[case["id"]]
            actual = tuple(case.get(k) for k in ("condition", "room", "tax_delta", "plan", "reason", "expected"))
            require(actual == expected, f"case contract drift: {case['id']}")

        receipts = load("authority-receipts.yaml")["receipts"]
        require({r["id"] for r in receipts} == SOURCE_IDS and len(receipts) == 8, "authority receipt inventory drift")
        for receipt in receipts:
            require(receipt["url"].startswith("https://"), f"non-HTTPS source: {receipt['id']}")
            require(receipt["retrieved_at"] == "2026-08-09T10:30:00+02:00", f"retrieval timestamp drift: {receipt['id']}")
            require(receipt["review_status"] == "mechanically_extracted_pending_independent_content_review", f"review status drift: {receipt['id']}")
            require(receipt["citation_id"] == receipt["id"], f"citation drift: {receipt['id']}")
            require(receipt["effective_through"] == "2026-12-31" and receipt.get("effective_from"), f"effective period missing: {receipt['id']}")
            if receipt["available"]:
                require(receipt["http_status"] == 200 and receipt["bytes"] > 0, f"invalid available receipt: {receipt['id']}")
                require(isinstance(receipt["sha256"], str) and SHA.fullmatch(receipt["sha256"]) is not None, f"missing source hash: {receipt['id']}")
            else:
                require(receipt["http_status"] != 200 and receipt["bytes"] == 0 and receipt["sha256"] is None and receipt.get("failure"), f"invalid unavailable receipt: {receipt['id']}")
            require((receipt["authority"], receipt["url"], receipt["bytes"], receipt["sha256"]) == EXPECTED_SOURCE_BYTES[receipt["id"]], f"source whitelist drift: {receipt['id']}")

        manifest = load("source-authority-manifest.yaml")
        rules = load("normalized-ruleset.yaml")
        require(set(manifest["required_source_ids"]) == SOURCE_IDS, "manifest source inventory drift")
        require(set(rules["source_ids"]) == SOURCE_IDS, "ruleset source inventory drift")
        require(all(r["available"] for r in receipts), "all eight frozen authorities must be available")
        require(manifest["status"] == rules["status"] == review_pending, "source/engine status drift")
        require(rules["availability"]["tax_delta"].startswith("unavailable_"), "tax delta must remain unavailable")
        require(rules["availability"]["product_feature_flag"] is False, "feature flag must be false")
        require(set(rules["prohibitions"]) == {"tax_exact_claim", "personalized_tax_output", "catchup_calculation", "runtime_network", "LLM_calculation", "silent_recompute"}, "ruleset prohibitions drift")
        require(rules["constants"]["employee_with_lpp_ordinary_cap_chf"] == 7258, "3a cap drift")
        require(rules["constants"]["lausanne_income_tax_coefficient_percent"] == 78.5, "Lausanne coefficient drift")
        require(rules["constants"]["vd_cantonal_income_tax_coefficient_percent"] == 155.0, "VD coefficient drift")
        require(rules["constants"]["vd_cantonal_income_tax_reduction_percent"] == 5.0, "VD reduction drift")
        expected_claims = {
            "ordinary_cap": (7258, "CHF", ("ofas_contribution_page", "ofas_amounts_2026")),
            "lausanne_coefficient": (78.5, "percent", ("lausanne_tax_decree_2025_2029",)),
            "vd_coefficient": (155.0, "percent", ("vd_deductions_2026",)),
            "vd_reduction": (5.0, "percent", ("vd_cantonal_reduction_2026",)),
            "ifd_single_scale": ("form_58c_2026", "table", ("ifd_scale_2026",)),
        }
        actual_claims = {c["id"]: (c["value"], c["unit"], tuple(c["sources"])) for c in manifest["claims"]}
        require(actual_claims == expected_claims, "authority claims drift")
        require(manifest["product_claim"] == "non_binding_estimate_only_after_independent_engine_proof", "product claim drift")
        require(str(manifest["fail_closed"]["expired_after"]) == "2026-12-31", "authority expiry drift")

        parser = load("parser-version-manifest.yaml")
        require(parser["parser_version"] == "1.0.0" and parser["status"] == "executable_offline_provenance_pending_independent_content_review", "parser contract drift")
        require(parser["pdftotext_version"] == "pdftotext version 26.03.0", "pdftotext contract drift")
        extraction_raw = (ANNEX / "source-extractions.json").read_bytes()
        extraction_sha = hashlib.sha256(extraction_raw).hexdigest()
        require(extraction_sha == EXPECTED_EXTRACTIONS_SHA256, "canonical extraction drift")
        require(parser["source_extractions_sha256"] == extraction_sha == manifest["source_extractions_sha256"], "extraction binding drift")
        extraction = json.loads(extraction_raw)
        require(extraction["status"] == "mechanically_extracted_pending_independent_content_review", "extraction status drift")
        require(extraction["parser"] == {"id": "three_a_authority_normalizer", "pdftotext": "pdftotext version 26.03.0", "version": "1.0.0"}, "extraction parser identity drift")
        require(len(extraction["extractions"]) == 8, "extraction cardinality drift")
        require({x["source_id"] for x in extraction["extractions"]} == SOURCE_IDS, "extraction source inventory drift")
        require(len({x["claim_id"] for x in extraction["extractions"]}) == 8, "extraction claim uniqueness drift")
        require(extraction["source_receipts_sha256"] == hashlib.sha256((ANNEX / "authority-receipts.yaml").read_bytes()).hexdigest(), "receipt/extraction binding drift")
        receipt_hashes = {r["id"]: r["sha256"] for r in receipts}
        require(all(x["document_sha256"] == receipt_hashes[x["source_id"]] for x in extraction["extractions"]), "extraction document binding drift")
        actual_extractions = {x["source_id"]: (x["claim_id"], x["normalized"]["value"], x["normalized"]["unit"]) for x in extraction["extractions"]}
        require(actual_extractions == EXPECTED_EXTRACTIONS, "normalized extraction drift")
        require(set(extraction["prohibitions"]) == {"advice", "engine_valid", "phase_passed", "product_activation", "tax_output"}, "extraction prohibitions drift")
        claims = extraction["normalized_claims"]
        require(rules["constants"]["employee_with_lpp_ordinary_cap_chf"] == claims["employee_with_lpp_ordinary_cap_chf"], "cap extraction/ruleset drift")
        require(rules["constants"]["lausanne_income_tax_coefficient_percent"] == claims["lausanne_income_tax_coefficient_percent"], "Lausanne extraction/ruleset drift")
        require(rules["constants"]["vd_cantonal_income_tax_coefficient_percent"] == claims["vd_cantonal_income_tax_coefficient_percent"], "VD coefficient extraction/ruleset drift")
        require(rules["constants"]["vd_cantonal_income_tax_reduction_percent"] == claims["vd_cantonal_income_tax_reduction_percent"], "VD reduction extraction/ruleset drift")
        require(rules["policies"]["credit_deadline"] == claims["credit_deadline"], "deadline extraction/ruleset drift")
        require(rules["anchors"] == {"ifd_single_scale": claims["ifd_single_scale"], "vd_income_scale": claims["vd_income_scale_anchor"]}, "anchor extraction/ruleset drift")
        require(rules["derived_from_source_extractions_sha256"] == extraction_sha, "ruleset extraction hash drift")

        review_raw = (ANNEX / "content-review-receipt.yaml").read_bytes()
        require(hashlib.sha256(review_raw).hexdigest() == EXPECTED_CONTENT_REVIEW_SHA256, "content review receipt drift")
        review = yaml.safe_load(review_raw)
        require(review["reviewed_product_sha"] == "516a4baccece1e950c4313b511bcf540d79ab77b", "reviewed product SHA drift")
        require(review["scope"] == "provenance_content_review_only", "content review scope drift")
        require(review["verdict"] == {"score": 10.0, "p1": 0, "p2": 0, "p3": 0, "result": "ACCEPT"}, "content review verdict drift")
        require(len(review["claim_reviews"]) == 8 and all(c["semantic_context"] == "ACCEPT" for c in review["claim_reviews"]), "claim review drift")
        require(review["replay"]["exit_code"] == 0 and review["replay"]["output_sha256"] == EXPECTED_EXTRACTIONS_SHA256, "review replay drift")
        require(review["assertions"] == {"engine_unproven": True, "no_tax_output": True, "no_advice": True, "no_activation": True, "does_not_close_B0_or_phase": True, "feature_flag": False}, "review boundary drift")
        goldens = load("golden-fixtures.json")
        require(goldens["status"] == "contract_goldens_not_product_engine_proof", "goldens overclaim")
        require(goldens["tolerance"] == {"CHF": "0_for_contract_status_and_room", "tax_delta": "not_evaluated_while_engine_unproven"}, "golden tolerance drift")
        require({x["inputs"]["persona_case"] for x in goldens["fixtures"]} == set("ABCDEFGHIJ"), "goldens must cover A-J")
        by_id = {case["id"]: case for case in cases}
        for fixture in goldens["fixtures"]:
            case = by_id[fixture["inputs"]["persona_case"]]
            mirror = {key: case.get(key) for key in ("room", "tax_delta", "plan", "reason", "expected")}
            require(fixture["expected"] == mirror, f"golden/matrix drift: {case['id']}")
            require(not isinstance(fixture["expected"]["tax_delta"], (int, float)), "numeric tax delta forbidden")
            require(fixture["oracle"] == "pending_independent_content_review_and_engine_unproven", f"golden oracle status drift: {case['id']}")
    finally:
        ANNEX = old


if __name__ == "__main__":
    try:
        validate()
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError, yaml.YAMLError) as exc:
        print(f"FAIL mint_next_three_a_goal_annexes_guard: {exc}", file=sys.stderr)
        raise SystemExit(1)
    print("OK 3a provenance content review is hash-bound; engine remains unproven")
