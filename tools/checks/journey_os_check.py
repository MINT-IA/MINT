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
ISSUES = JOURNEYS / "issues"
SCHEMA = JOURNEYS / "journey.schema.json"
ISSUE_SCHEMA = JOURNEYS / "issue.schema.json"
ROUTES = Path("apps/mobile/lib/routes/route_metadata.dart")
ALLOW = {
    str(SCHEMA),
    str(ISSUE_SCHEMA),
    str(JOURNEYS / "README.md"),
    str(JOURNEYS / "PRIORITY_RUBRIC.md"),
    str(journey_os_generate.SUMMARY),
    str(journey_os_generate.BOARD),
    ".planning/ACTIVE_CONTEXT.md",
    ".planning/ACTIVE_CONTEXT.json",
    "tools/simulator/flows/maestro-perfect-set/flow_row24_privacy_control_runtime.yaml",
    "tools/checks/journey_os_check.py",
    "tools/checks/journey_os_generate.py",
    "tools/checks/tests/test_journey_os_check.py",
}
TEAMS = {"mint-lead", "mint-quality-gate", "mint-mobile", "mint-backend", "mint-swiss-brain"}
STATUS = {"draft", "partial", "live_proven", "blocked", "deferred", "out_of_beta"}
ISSUE_STATUS = {"found", "triaged", "assigned", "fixing", "proof_needed", "verified", "merged", "regressed", "blocked"}
SEVERITY = {"P0", "P1", "P2", "P3"}
TIERS = {"T0", "T1", "T2", "T3"}
KINDS = {"unit", "widget", "static_guard", "runtime", "manual", "external"}
ESTATUS = {"green", "red", "missing", "baselined"}
TOP = {"schema_version", "id", "title", "tier", "status", "human_promise", "accountable_team", "route_paths", "surfaces", "external_apis", "issues", "priority", "evidence"}
REQ = TOP
ARRAYS = {"route_paths", "surfaces", "external_apis", "issues"}
ITOP = {"schema_version", "id", "title", "journey_id", "status", "owner", "severity", "evidence_status", "next_action", "source"}
IREQ = ITOP
EKEYS = {"kind", "status", "command", "artifact", "reason", "debt_ref", "verified_at", "verified_commit"}
PRIORITY_POSITIVE = {"trust_blast_radius", "release_blocker_weight", "user_frequency", "evidence_gap", "route_centrality", "compliance_risk", "learning_value"}
PRIORITY_KEYS = PRIORITY_POSITIVE | {"proof_cost", "rationale"}

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
        allowed_issue = path.startswith(str(ISSUES) + "/") and path.endswith(".json") and "/" not in path[len(str(ISSUES)) + 1 :]
        allowed_diagram = path.startswith(str(journey_os_generate.DIAGRAMS) + "/") and path.endswith(".mmd") and "/" not in path[len(str(journey_os_generate.DIAGRAMS)) + 1 :]
        allowed_evidence = (
            path.startswith(str(JOURNEYS / "evidence") + "/")
            and Path(path).suffix in {".md", ".txt", ".xml", ".json"}
            and ".." not in Path(path).parts
        )
        if not (path in ALLOW or allowed_record or allowed_issue or allowed_diagram or allowed_evidence):
            errors.append(f"changed file outside Journey OS whitelist: {path}")
        suffix = Path(path).suffix
        if path.startswith(str(JOURNEYS) + "/") and not allowed_evidence and (suffix in {".svg", ".html"} or (suffix == ".md" and path not in ALLOW)):
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

def _load_issues(root: Path) -> tuple[list[tuple[Path, dict[str, Any]]], list[str]]:
    errors: list[str] = []
    if not (root / ISSUE_SCHEMA).exists():
        errors.append(f"missing {ISSUE_SCHEMA}")
    issues: list[tuple[Path, dict[str, Any]]] = []
    for path in sorted((root / ISSUES).glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{path.relative_to(root)} invalid JSON: {exc}")
            continue
        if not isinstance(data, dict):
            errors.append(f"{path.relative_to(root)} root must be an object")
            continue
        issues.append((path, data))
    return issues, errors

def _artifact_ok(root: Path, value: Any) -> bool:
    if not isinstance(value, str) or not value or value.startswith("/tmp"):
        return False
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or "tmp" in path.parts:
        return False
    return (root / path).exists()

def _priority_score(priority: dict[str, Any]) -> int:
    return sum(int(priority[key]) for key in PRIORITY_POSITIVE) - int(priority["proof_cost"])

def _priority_errors(rel: Path, data: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    priority = data.get("priority")
    if not isinstance(priority, dict):
        return [f"{rel} priority must be an object"]
    extra = set(priority) - PRIORITY_KEYS
    if extra:
        errors.append(f"{rel} priority unknown field(s): {', '.join(sorted(extra))}")
    for key in sorted(PRIORITY_KEYS):
        if key not in priority:
            errors.append(f"{rel} priority missing field: {key}")
    for key in sorted(PRIORITY_POSITIVE | {"proof_cost"}):
        value = priority.get(key)
        if isinstance(value, bool) or not isinstance(value, int) or value < 0 or value > 5:
            errors.append(f"{rel} priority.{key} must be an integer from 0 to 5")
    rationale = priority.get("rationale")
    if not isinstance(rationale, str) or len(rationale.strip()) < 20:
        errors.append(f"{rel} priority.rationale must explain the ranking")
    if data.get("tier") == "T0" and not errors and _priority_score(priority) < 15:
        errors.append(f"{rel} T0 priority score must be at least 15")
    return errors

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
    errors += _priority_errors(rel, data)
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

def _issue_errors(root: Path, path: Path, data: dict[str, Any], journey_ids: set[str]) -> list[str]:
    rel = path.relative_to(root)
    errors: list[str] = []
    unknown = set(data) - ITOP
    if unknown:
        errors.append(f"{rel} unknown field(s): {', '.join(sorted(unknown))}")
    for key in sorted(IREQ):
        if key not in data:
            errors.append(f"{rel} missing required field: {key}")
    for key in ("id", "title", "next_action", "source"):
        if not isinstance(data.get(key), str) or not str(data.get(key)).strip():
            errors.append(f"{rel} {key} must be a non-empty string")
    iid = data.get("id")
    if not (isinstance(iid, str) and iid.startswith("JOS-") and len(iid) == 7 and iid[4:].isdigit()):
        errors.append(f"{rel} id must match JOS-###")
    if isinstance(data.get("next_action"), str) and len(str(data["next_action"]).strip()) < 20:
        errors.append(f"{rel} next_action must explain the next step")
    if data.get("schema_version") != 1:
        errors.append(f"{rel} schema_version must be 1")
    if path.stem != data.get("id"):
        errors.append(f"{rel} filename stem must match id")
    if data.get("journey_id") not in journey_ids:
        errors.append(f"{rel} journey_id must reference a Journey OS record")
    if data.get("status") not in ISSUE_STATUS:
        errors.append(f"{rel} status has unknown enum: {data.get('status')}")
    if data.get("owner") not in TEAMS:
        errors.append(f"{rel} owner must be a Mint roster entry")
    if data.get("severity") not in SEVERITY:
        errors.append(f"{rel} severity has unknown enum: {data.get('severity')}")
    if data.get("evidence_status") not in ESTATUS:
        errors.append(f"{rel} evidence_status has unknown enum: {data.get('evidence_status')}")
    return errors

def _issue_progress_errors(root: Path, records: list[tuple[Path, dict[str, Any]]], issues: list[tuple[Path, dict[str, Any]]]) -> list[str]:
    has_green_evidence: set[str] = set()
    for _path, data in records:
        if not isinstance(data.get("id"), str):
            continue
        evidence = data.get("evidence")
        if not isinstance(evidence, list):
            continue
        if any(isinstance(item, dict) and item.get("status") == "green" and _artifact_ok(root, item.get("artifact")) for item in evidence):
            has_green_evidence.add(str(data["id"]))
    errors: list[str] = []
    for path, data in issues:
        has_green = data.get("journey_id") in has_green_evidence
        rel = path.relative_to(root)
        if data.get("evidence_status") == "green" and not has_green:
            errors.append(f"{rel} cannot be green without durable green evidence on referenced journey")
        if not has_green:
            continue
        if data.get("status") in {"found", "triaged"}:
            errors.append(f"{rel} cannot stay {data.get('status')} after referenced journey has durable green evidence")
        if data.get("evidence_status") == "missing":
            errors.append(f"{rel} cannot stay missing after referenced journey has durable green evidence")
    return errors

def check(root: Path, changed_files: list[str] | None = None, base_ref: str = "origin/dev") -> list[str]:
    root = root.resolve()
    changed, errors = (changed_files, []) if changed_files else _changed(root, base_ref)
    errors += _scope_errors(root, changed)
    records, load_errors = _load_records(root)
    errors += load_errors
    issues, issue_load_errors = _load_issues(root)
    errors += issue_load_errors
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
    issue_ids: set[str] = set()
    for path, data in issues:
        iid = data.get("id")
        if isinstance(iid, str) and iid in issue_ids:
            errors.append(f"duplicate Journey OS issue id: {iid}")
        if isinstance(iid, str):
            issue_ids.add(iid)
        errors += _issue_errors(root, path, data, seen)
    errors += _issue_progress_errors(root, records, issues)
    for path, data in records:
        rel = path.relative_to(root)
        for issue in data.get("issues", []) if isinstance(data.get("issues"), list) else []:
            if isinstance(issue, str) and issue.startswith("JOS-") and issue not in issue_ids:
                errors.append(f"{rel} missing Journey OS issue: {issue}")
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
