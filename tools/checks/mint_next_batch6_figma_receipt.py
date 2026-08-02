#!/usr/bin/env python3
"""Fail closed when the Batch 6 Figma receipt overclaims its evidence."""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]
RECEIPT = ROOT / "product/mint_next/batch6/figma/design-receipt.yaml"


def validate(receipt_path: Path = RECEIPT, root: Path = ROOT) -> list[str]:
    data = yaml.safe_load(receipt_path.read_text(encoding="utf-8"))
    errors: list[str] = []

    figma = data.get("figma", {})
    if figma.get("file_key") != "J8DV52MVOFVPJv81pOFq2u":
        errors.append("unexpected Figma file key")
    node_ids = [figma.get("wrapper_id"), *figma.get("screen_ids", {}).values()]
    if len(node_ids) != 4 or None in node_ids or len(set(node_ids)) != 4:
        errors.append("Figma wrapper/screen IDs must be four unique concrete IDs")

    for name, evidence in data.get("evidence", {}).items():
        path = root / evidence.get("path", "")
        if not path.is_file():
            errors.append(f"missing {name} evidence")
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != evidence.get("sha256"):
            errors.append(f"hash mismatch for {name} evidence")

    rejections = data.get("known_rejections", [])
    ids = [item.get("id") for item in rejections]
    if not rejections or len(ids) != len(set(ids)):
        errors.append("known rejection IDs must be present and unique")
    if not any(item.get("severity") == "P1" for item in rejections):
        errors.append("receipt must preserve the current P1 rejection")

    blocked = data.get("blocked_correction", {})
    if data.get("status") == "rejected_pending_corrections":
        if blocked.get("accepted") is not False or blocked.get("flutter_allowed") is not False:
            errors.append("rejected candidate cannot be accepted or allow Flutter")
    elif rejections:
        errors.append("candidate with known rejections must remain rejected_pending_corrections")

    roasts = data.get("roasts", {})
    if any(review.get("verdict") != "reject" for review in roasts.values()):
        errors.append("current roast verdicts must remain reject")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("OK mint_next_batch6_figma_receipt: rejected candidate and evidence are coherent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
