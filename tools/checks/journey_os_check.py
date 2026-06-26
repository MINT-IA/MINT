#!/usr/bin/env python3
"""Validate Mint Journey OS records, scope, and generated views."""
from __future__ import annotations

import argparse, json, subprocess, sys
from pathlib import Path
from typing import Any
REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))
from tools.checks import journey_os_generate
from tools.checks.route_registry_parity import extract_registry_keys
JOURNEYS = Path(".planning/journeys")
RECORDS = JOURNEYS / "records"
SCHEMA = JOURNEYS / "journey.schema.json"
ROUTES = Path("apps/mobile/lib/routes/route_metadata.dart")
ALLOW = {str(SCHEMA), str(JOURNEYS / "README.md"), str(journey_os_generate.SUMMARY), "tools/checks/journey_os_check.py", "tools/checks/journey_os_generate.py", "tools/checks/tests/test_journey_os_check.py"}
TEAMS = {"mint-lead", "mint-quality-gate", "mint-mobile", "mint-backend", "mint-swiss-brain"}
STATUS = {"draft", "partial", "live_proven", "blocked", "deferred", "out_of_beta"}
TIERS = {"T0", "T1", "T2", "T3"}
KINDS = {"unit", "widget", "static_guard", "runtime", "manual", "external"}
ESTATUS = {"green", "red", "missing", "baselined"}
TOP = {"schema_version", "id", "title", "tier", "status", "human_promise", "accountable_team", "route_paths", "surfaces", "external_apis", "issues", "evidence"}
REQ = TOP
ARRAYS = {"route_paths", "surfaces", "external_apis", "issues"}
EKEYS = {"kind", "status", "command", "artifact", "reason", "debt_ref", "verified_at", "verified_commit"}

def _changed(root: Path, base: str) -> tuple[list[str], list[str]]:
    proc = subprocess.run(["git", "diff", "--name-only", f"{base}...HEAD"], cwd=root, text=True, capture_output=True)
    if proc.returncode:
        return [], [f"baseline {base} unavailable: {proc.stderr.strip() or proc.stdout.strip()}"]
    extra = subprocess.run(["git", "ls-files", "--others", "--exclude-standard"], cwd=root, text=True, capture_output=True)
    if extra.returncode:
        return [], [f"unable to resolve untracked files: {extra.stderr.strip() or extra.stdout.strip()}"]
    return sorted({line for line in (proc.stdout + extra.stdout).splitlines() if line}), []

def _scope_errors(root: Path, changed: list[str]) -> list[str]:
    errors: list[str] = []
    for path in changed:
        allowed_record = path.startswith(str(RECORDS) + "/") and path.endswith(".json") and "/" not in path[len(str(RECORDS)) + 1 :]
        allowed_diagram = path.startswith(str(journey_os_generate.DIAGRAMS) + "/") and path.endswith(".mmd") and "/" not in path[len(str(journey_os_generate.DIAGRAMS)) + 1 :]
        if not (path in ALLOW or allowed_record or allowed_diagram):
            errors.append(f"changed file outside Journey OS whitelist: {path}")
        suffix = Path(path).suffix
        if path.startswith(str(JOURNEYS) + "/") and (suffix in {".svg", ".html"} or (suffix == ".md" and path not in ALLOW)):
            errors.append(f"unsupported Journey OS generated view: {path}")
    readme = root / JOURNEYS / "README.md"
    if readme.exists() and "```mermaid" in readme.read_text(encoding="utf-8", errors="ignore").lower():
        errors.append("Mermaid fenced blocks are forbidden in .planning/journeys/README.md")
    return errors

def _generated_errors(root: Path) -> list[str]:
    errors: list[str] = []
    expected = journey_os_generate.expected(root)
    for rel, content in expected.items():
        path = root / rel
        if not path.exists():
            errors.append(f"missing generated Journey OS view: {rel}")
        elif path.read_text(encoding="utf-8") != content:
            errors.append(f"stale generated Journey OS view: {rel}")
    expected_paths = {str(path) for path in expected}
    for path in (root / journey_os_generate.DIAGRAMS).glob("*.mmd"):
        rel = str(path.relative_to(root))
        if rel not in expected_paths:
            errors.append(f"orphan generated Journey OS diagram: {rel}")
    return errors

def _load_records(root: Path) -> tuple[list[tuple[Path, dict[str, Any]]], list[str]]:
    errors: list[str] = []
    if not (root / SCHEMA).exists():
        errors.append(f"missing {SCHEMA}")
    records: list[tuple[Path, dict[str, Any]]] = []
    for path in sorted((root / RECORDS).glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{path.relative_to(root)} invalid JSON: {exc}")
            continue
        if not isinstance(data, dict):
            errors.append(f"{path.relative_to(root)} root must be an object")
            continue
        records.append((path, data))
    return records, errors

def _artifact_ok(root: Path, value: Any) -> bool:
    if not isinstance(value, str) or not value or value.startswith("/tmp"):
        return False
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or "tmp" in path.parts:
        return False
    return (root / path).exists()

def _record_errors(root: Path, path: Path, data: dict[str, Any], routes: set[str]) -> list[str]:
    rel = path.relative_to(root)
    errors: list[str] = []
    unknown = set(data) - TOP
    if unknown:
        errors.append(f"{rel} unknown field(s): {', '.join(sorted(unknown))}")
    for key in sorted(REQ):
        if key not in data:
            errors.append(f"{rel} missing required field: {key}")
    for key in ("id", "title", "human_promise"):
        if not isinstance(data.get(key), str) or not str(data.get(key)).strip():
            errors.append(f"{rel} {key} must be a non-empty string")
    if data.get("schema_version") != 1:
        errors.append(f"{rel} schema_version must be 1")
    if data.get("tier") not in TIERS:
        errors.append(f"{rel} tier has unknown enum: {data.get('tier')}")
    if data.get("status") not in STATUS:
        errors.append(f"{rel} status has unknown enum: {data.get('status')}")
    if data.get("accountable_team") not in TEAMS:
        errors.append(f"{rel} accountable_team must be a Mint roster entry")
    if path.stem != data.get("id"):
        errors.append(f"{rel} filename stem must match id")
    for key in ARRAYS:
        value = data.get(key)
        if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
            errors.append(f"{rel} {key} must be an array of strings")
    for route in data.get("route_paths", []) if isinstance(data.get("route_paths"), list) else []:
        if not isinstance(route, str) or route not in routes:
            errors.append(f"{rel} route_path is not a registered route: {route}")
    evidence = data.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        errors.append(f"{rel} evidence must be a non-empty array")
        return errors
    live_runtime = False
    for index, item in enumerate(evidence):
        label = f"{rel} evidence[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{label} must be an object")
            continue
        extra = set(item) - EKEYS
        if extra:
            errors.append(f"{label} unknown field(s): {', '.join(sorted(extra))}")
        for key in ("kind", "status", "command", "artifact"):
            if key not in item:
                errors.append(f"{label} missing required field: {key}")
        kind, status = item.get("kind"), item.get("status")
        if kind not in KINDS:
            errors.append(f"{label} kind has unknown enum: {kind}")
        if status not in ESTATUS:
            errors.append(f"{label} status has unknown enum: {status}")
        has_artifact = _artifact_ok(root, item.get("artifact"))
        if status in {"green", "red", "baselined"}:
            if not isinstance(item.get("command"), str) or not item["command"].strip() or not has_artifact:
                errors.append(f"{label} {status} evidence needs command and durable repo-relative artifact")
        if status == "baselined" and not item.get("debt_ref"):
            errors.append(f"{label} baselined evidence requires debt_ref")
        if status == "missing" and item.get("artifact") is not None:
            errors.append(f"{label} missing evidence cannot have an artifact")
        if data.get("status") == "live_proven" and kind == "runtime" and status == "green" and has_artifact:
            live_runtime = bool(item.get("verified_at") and item.get("verified_commit"))
    if data.get("status") == "live_proven" and not live_runtime:
        errors.append(f"{rel} live_proven requires green runtime evidence with verified_at and verified_commit")
    return errors

def check(root: Path, changed_files: list[str] | None = None, base_ref: str = "origin/dev") -> list[str]:
    root = root.resolve()
    changed, errors = (changed_files, []) if changed_files else _changed(root, base_ref)
    errors += _scope_errors(root, changed)
    records, load_errors = _load_records(root)
    errors += load_errors
    try:
        routes = extract_registry_keys((root / ROUTES).read_text(encoding="utf-8"))
    except OSError as exc:
        return errors + [f"unable to read route registry: {exc}"]
    seen: set[str] = set()
    for path, data in records:
        rid = data.get("id")
        if isinstance(rid, str) and rid in seen:
            errors.append(f"duplicate journey id: {rid}")
        if isinstance(rid, str):
            seen.add(rid)
        errors += _record_errors(root, path, data, routes)
    errors += _generated_errors(root)
    return errors

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base-ref", default="origin/dev")
    parser.add_argument("--changed-file", action="append")
    args = parser.parse_args(argv)
    errors = check(args.root, args.changed_file, args.base_ref)
    if errors:
        print("FAIL journey_os_check", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("OK journey_os_check")
    return 0

if __name__ == "__main__":
    sys.exit(main())
