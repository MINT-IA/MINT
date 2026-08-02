#!/usr/bin/env python3
"""Fail closed if the accepted Batch 6 navigation evidence drifts."""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]
RECEIPT = ROOT / "product/mint_next/batch6/navigation-acceptance.yaml"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(receipt_path: Path = RECEIPT) -> list[str]:
    receipt = yaml.safe_load(receipt_path.read_text(encoding="utf-8"))
    errors: list[str] = []
    if receipt.get("scope") != "written_batch6_navigation_contract_and_generated_mermaid_only" or receipt.get("verdict") != "accepted":
        errors.append("acceptance scope or verdict is invalid")
    for key in ("contract", "diagram"):
        item = receipt.get(key, {})
        path = ROOT / item.get("path", "")
        if not path.is_file() or item.get("sha256") != digest(path):
            errors.append(f"{key} acceptance hash is stale or missing")
    reviews = receipt.get("independent_reviews", [])
    if {review.get("reviewer") for review in reviews} != {"batch6_navigation_roast", "ux_architecture"}:
        errors.append("independent reviewer set is incomplete")
    for review in reviews:
        if review.get("verdict") != "accepted" or review.get("p1") != 0 or review.get("p2") != 0:
            errors.append(f"review did not converge: {review.get('reviewer')}")
    if receipt.get("next_gate") != "executable_flutter_design_lab_only":
        errors.append("next gate is not bounded to the executable design lab")
    required_limitations = {
        "flutter_product_runtime", "calculation_engine_correctness", "localized_copy",
        "visual_design_quality", "accessibility_runtime", "full_3a_vertical",
    }
    if set(receipt.get("explicitly_not_accepted", [])) != required_limitations:
        errors.append("acceptance limitations are incomplete")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("OK mint_next_batch6_navigation_acceptance: exact written contract has two zero-finding reviews.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
