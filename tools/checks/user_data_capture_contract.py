#!/usr/bin/env python3
"""Require lifecycle contracts for newly touched Dart screen data capture."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


SCREEN_PREFIX = "apps/mobile/lib/screens/"
CAPTURE_PRIMITIVE = re.compile(
    r"\b(?:TextFormField|TextField|DropdownButtonFormField|Checkbox|Switch|Radio|Slider)\s*(?:<[^>]+>)?\s*\("
)
WRITE_CALL = re.compile(
    r"\b(?:(?:save|persist|store|write|update|upsert|insert|delete|remove|set)[A-Z_a-z0-9]*|mergeAnswers)\s*\("
)
REQUIRED_REFS = (
    "canonical_write_ref",
    "visibility_ref",
    "edit_ref",
    "delete_ref",
    "lifecycle_test_ref",
)


def _git_changed_files(root: Path, base_ref: str) -> list[str]:
    commands = (
        ["git", "diff", "--name-only", "--diff-filter=ACMR", base_ref, "--", SCREEN_PREFIX],
        ["git", "ls-files", "--others", "--exclude-standard", "--", SCREEN_PREFIX],
    )
    found: set[str] = set()
    for command in commands:
        proc = subprocess.run(command, cwd=root, capture_output=True, text=True)
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr.strip() or f"failed: {' '.join(command)}")
        found.update(line.strip() for line in proc.stdout.splitlines() if line.strip())
    return sorted(found)


def _validate_ref(root: Path, value: object, label: str, errors: list[str]) -> None:
    if not isinstance(value, str) or "#" not in value:
        errors.append(f"{label} must be a path#symbol reference")
        return
    rel, symbol = value.rsplit("#", 1)
    if not rel or not symbol:
        errors.append(f"{label} must be a path#symbol reference")
        return
    path = root / rel
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        errors.append(f"{label} references missing path: {rel}")
        return
    if not re.search(rf"\b{re.escape(symbol)}\b", text):
        errors.append(f"{label} references missing symbol: {value}")


def _validate_contract(root: Path, source_rel: str, source: str, errors: list[str]) -> None:
    contract_rel = f"{source_rel}.capture.json"
    contract_path = root / contract_rel
    if not contract_path.is_file():
        errors.append(f"{source_rel}: missing capture contract {contract_rel}")
        return
    try:
        contract = json.loads(contract_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"{contract_rel}: invalid JSON: {exc}")
        return
    if not isinstance(contract, dict) or contract.get("schema_version") != 1:
        errors.append(f"{contract_rel}: schema_version must be 1")
        return
    capture = contract.get("capture")
    if capture is False:
        if not isinstance(contract.get("reason"), str) or not contract["reason"].strip():
            errors.append(f"{contract_rel}: capture:false requires a non-empty reason")
        if WRITE_CALL.search(source):
            errors.append(f"{contract_rel}: capture:false waiver is forbidden when the screen has a write call")
        return
    if capture is not True:
        errors.append(f"{contract_rel}: capture must be true or false")
        return
    fact_ids = contract.get("fact_ids")
    if not isinstance(fact_ids, list) or not fact_ids or not all(isinstance(v, str) and v.strip() for v in fact_ids):
        errors.append(f"{contract_rel}: fact_ids must be a non-empty string list")
    for field in REQUIRED_REFS:
        if field not in contract:
            errors.append(f"{contract_rel}: missing {field}")
        else:
            _validate_ref(root, contract[field], f"{contract_rel}.{field}", errors)
    consumers = contract.get("external_consumer_refs")
    if not isinstance(consumers, list) or not consumers:
        errors.append(f"{contract_rel}: external_consumer_refs must be a non-empty list")
    else:
        for index, ref in enumerate(consumers):
            _validate_ref(root, ref, f"{contract_rel}.external_consumer_refs[{index}]", errors)
            if isinstance(ref, str) and ref.split("#", 1)[0] == source_rel:
                errors.append(f"{contract_rel}.external_consumer_refs[{index}] must reference another file")


def check(root: Path, changed_files: list[str]) -> list[str]:
    errors: list[str] = []
    for rel in changed_files:
        rel = rel.replace("\\", "/")
        if not rel.startswith(SCREEN_PREFIX) or not rel.endswith(".dart"):
            continue
        path = root / rel
        if not path.is_file():
            continue
        source = path.read_text(encoding="utf-8", errors="ignore")
        if CAPTURE_PRIMITIVE.search(source):
            _validate_contract(root, rel, source, errors)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base-ref", default="origin/dev")
    parser.add_argument("--changed-file", action="append", default=[])
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        changed = args.changed_file or _git_changed_files(root, args.base_ref)
    except RuntimeError as exc:
        print(f"ERROR user_data_capture_contract: {exc}", file=sys.stderr)
        return 1
    errors = check(root, changed)
    if errors:
        for error in errors:
            print(f"ERROR user_data_capture_contract: {error}", file=sys.stderr)
        return 1
    print(f"OK user_data_capture_contract: checked {len(changed)} changed path(s).", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
