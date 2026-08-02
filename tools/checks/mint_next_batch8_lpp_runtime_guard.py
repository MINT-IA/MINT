#!/usr/bin/env python3
"""Bind the Batch 8 written LPP contract to the isolated Flutter renderer."""

from __future__ import annotations

import json
import re
import hashlib
import struct
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.checks.mint_next_batch8_lpp_scope_guard import SCOPE, validate as validate_scope
LAB = ROOT / "product/mint_next/batch7/design_lab"
APP = LAB / "lib/design_lab_app.dart"
L10N = LAB / "lib/l10n"
RECEIPT = ROOT / "product/mint_next/batch8/evidence/runtime/receipt.yaml"


def validate(app_path: Path = APP, l10n_path: Path = L10N) -> list[str]:
    errors = validate_scope()
    scope = yaml.safe_load(SCOPE.read_text(encoding="utf-8"))
    source = app_path.read_text(encoding="utf-8")
    required_bindings = {
        "fact_lpp_affiliation",
        "lpp_unknown_help",
        "without_lpp_boundary",
        "fact_contribution",
        "action:fact_tax_year.continue",
        "action:fact_lpp_affiliation.choose_yes",
        "action:fact_lpp_affiliation.choose_no",
        "action:fact_lpp_affiliation.choose_unknown",
        "action:fact_lpp_affiliation.back",
        "action:lpp_unknown_help.back",
        "action:lpp_unknown_help.keep_checklist_local",
        "action:without_lpp_boundary.back",
        "action:without_lpp_boundary.keep_explanation_local",
        "action:fact_contribution.back",
    }
    for binding in sorted(required_bindings):
        if binding not in source:
            errors.append(f"Batch8 Flutter binding missing: {binding}")
    required_semantics = {
        "selected choice state": "selected: selected",
        "button choice role": "button: true",
        "informative checklist label": "lppUnknownListLabel",
    }
    for meaning, token in required_semantics.items():
        if token not in source:
            errors.append(f"Batch8 Flutter semantics missing: {meaning}")
    if source.count("_UnavailableReference(") < 2 or "enabled: false" not in source or "onPressed: null" not in source:
        errors.append("Batch8 disabled persistence controls are not fail-closed")

    locales = scope["slice"]["locales"]
    data_by_locale = {
        locale: json.loads((l10n_path / f"app_{locale}.arb").read_text(encoding="utf-8"))
        for locale in locales
    }
    key_sets = [{key for key in data if not key.startswith("@")} for data in data_by_locale.values()]
    if any(keys != key_sets[0] for keys in key_sets[1:]):
        errors.append("Batch8 ARB keys differ across six locales")
    required_keys = set().union(*(
        set(scope["node_contracts"][node_id]["required_arb_keys"])
        for node_id in scope["slice"]["nodes"]
    )) | {"lppUnknownListLabel", "nextStepEyebrow", "nextStepTitle", "nextStepBody"}
    missing = sorted(required_keys - key_sets[0])
    if missing:
        errors.append("Batch8 required ARB keys missing: " + ", ".join(missing))
    fr = data_by_locale["fr"]
    copy = scope["node_contracts"]
    expected_fr = {
        "lppQuestionTitle": copy["fact_lpp_affiliation"]["reference_copy_fr"]["title"],
        "lppQuestionBody": copy["fact_lpp_affiliation"]["reference_copy_fr"]["body"],
        "lppQuestionEvidence": copy["fact_lpp_affiliation"]["reference_copy_fr"]["evidence_note"],
        "lppUnknownTitle": copy["lpp_unknown_help"]["reference_copy_fr"]["title"],
        "lppUnknownBody": copy["lpp_unknown_help"]["reference_copy_fr"]["body"],
        "withoutLppTitle": copy["without_lpp_boundary"]["reference_copy_fr"]["title"],
        "withoutLppBody": copy["without_lpp_boundary"]["reference_copy_fr"]["body"],
    }
    for key, expected in expected_fr.items():
        if fr.get(key) != expected:
            errors.append(f"Batch8 exact French runtime copy drift: {key}")
    relevant_text = " ".join(str(data.get(key, "")) for data in data_by_locale.values() for key in required_keys)
    if re.search(r"(?:CHF|Fr\.|francs?|\d[’' ]?\d{3}|\d+\s*%)", relevant_text, re.IGNORECASE):
        errors.append("Batch8 LPP slice leaks an amount, threshold or percentage")
    receipt = yaml.safe_load(RECEIPT.read_text(encoding="utf-8"))
    if receipt.get("viewport") != {"width": 390, "height": 844, "device_scale_factor": 1}:
        errors.append("Batch8 runtime viewport receipt drift")
    captures = receipt.get("captures", [])
    if {item.get("node") for item in captures} != {"fact_lpp_affiliation", "lpp_unknown_help", "without_lpp_boundary"}:
        errors.append("Batch8 runtime capture node set drift")
    for item in captures:
        path = ROOT / item.get("path", "")
        data = path.read_bytes() if path.is_file() else b""
        if hashlib.sha256(data).hexdigest() != item.get("sha256"):
            errors.append(f"Batch8 runtime capture hash drift: {item.get('node')}")
        if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", data[16:24]) != (390, 844):
            errors.append(f"Batch8 runtime capture dimensions drift: {item.get('node')}")
    if receipt.get("mechanical_proofs") != ["yes_no_unknown_physically_traversed", "back_restores_selected_state", "unknown_and_no_paths_produce_no_personal_calculation", "disabled_local_reference_is_visible", "zero_external_runtime_resources"]:
        errors.append("Batch8 runtime mechanical proof receipt drift")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("OK mint_next_batch8_lpp_runtime_guard: written LPP routes and copy are bound to six-locale Flutter runtime.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
