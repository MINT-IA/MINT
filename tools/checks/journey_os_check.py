#!/usr/bin/env python3
"""Validate Mint Journey OS records, scope, and generated views."""
from __future__ import annotations

import argparse, json, re, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from xml.etree import ElementTree

try:
    from jsonschema import Draft202012Validator, exceptions as jsonschema_exceptions
except ImportError:  # pragma: no cover - exercised only on incomplete local envs.
    Draft202012Validator = None
    jsonschema_exceptions = None
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
    str(journey_os_generate.TODAY),
    ".claude/AGENT_BOOTSTRAP.md",
    ".github/pull_request_template.md",
    ".github/workflows/ai-workflow-guards.yml",
    ".planning/ACTIVE_CONTEXT.md",
    ".planning/ACTIVE_CONTEXT.json",
    ".planning/ROADMAP.md",
    ".planning/STATE.md",
    "AGENTS.md",
    "docs/MINT_AGENT_WORKFLOW.md",
    "lefthook.yml",
    "rules.md",
    "tools/simulator/flows/maestro-perfect-set/flow_row24_privacy_control_runtime.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_jos004_coach_advice_turn_runtime.yaml",
    "tools/claude_review.sh",
    "tools/checks/active_context_guard.py",
    "tools/checks/journey_os_check.py",
    "tools/checks/journey_os_generate.py",
    "tools/checks/mermaid_render_guard.py",
    "tools/checks/mint_rules_guard.py",
    "tools/checks/workflow_contract_guard.py",
    "tools/checks/tests/test_active_context_guard.py",
    "tools/checks/tests/test_journey_os_check.py",
    "tools/checks/tests/test_mint_rules_guard.py",
    "tools/checks/tests/test_workflow_contract_guard.py",
}
IGNORED_GENERATED_PREFIXES = (
    "services/backend/mint_backend.egg-info/",
)
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
TEXT_FAILURE_MARKERS = ("[Failed]", "Flow Failed", "FAILED", "Assertion is false", "EXIT — maestro returned 1")
TEXT_SUCCESS_MARKERS = ("[Passed]", "Flow Passed")
FULL_SHA_RE = re.compile(r"^[0-9a-f]{40}$")

def _is_ignored_generated(path: str) -> bool:
    return any(path.startswith(prefix) for prefix in IGNORED_GENERATED_PREFIXES)

def _changed(root: Path, base: str) -> tuple[list[str], list[str]]:
    proc = subprocess.run(["git", "diff", "--name-only", f"{base}...HEAD"], cwd=root, text=True, capture_output=True)
    if proc.returncode:
        return [], [f"baseline {base} unavailable: {proc.stderr.strip() or proc.stdout.strip()}"]
    outputs = [proc.stdout]
    for args, label in (
        (["git", "diff", "--name-only"], "working tree changes"),
        (["git", "diff", "--cached", "--name-only"], "staged changes"),
        (["git", "ls-files", "--others", "--exclude-standard"], "untracked files"),
    ):
        extra = subprocess.run(args, cwd=root, text=True, capture_output=True)
        if extra.returncode:
            return [], [f"unable to resolve {label}: {extra.stderr.strip() or extra.stdout.strip()}"]
        outputs.append(extra.stdout)
    return sorted(
        {
            line
            for output in outputs
            for line in output.splitlines()
            if line and not _is_ignored_generated(line)
        }
    ), []

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

def _schema_validation_errors(root: Path, records: list[tuple[Path, dict[str, Any]]], issues: list[tuple[Path, dict[str, Any]]]) -> list[str]:
    errors: list[str] = []
    if Draft202012Validator is None or jsonschema_exceptions is None:
        return ["python package jsonschema is required for Journey OS schema validation"]
    schema_specs = (
        (SCHEMA, "Journey OS record", records),
        (ISSUE_SCHEMA, "Journey OS issue", issues),
    )
    for rel_schema, label, items in schema_specs:
        path = root / rel_schema
        try:
            schema = json.loads(path.read_text(encoding="utf-8"))
            Draft202012Validator.check_schema(schema)
        except (OSError, json.JSONDecodeError, jsonschema_exceptions.SchemaError) as exc:
            errors.append(f"{rel_schema} is not an executable JSON schema: {exc}")
            continue
        required = schema.get("required")
        if not isinstance(required, list) or len(required) < 5:
            errors.append(f"{rel_schema} must define a non-trivial required field list")
            continue
        validator = Draft202012Validator(schema)
        for item_path, data in items:
            for error in sorted(validator.iter_errors(data), key=lambda err: list(err.path)):
                errors.append(f"{item_path.relative_to(root)} schema violation ({label}): {error.message}")
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

def _junit_counts(path: Path) -> tuple[int, int, int, int]:
    root = ElementTree.parse(path).getroot()
    declared_tests = sum(int(node.attrib.get("tests", "0") or 0) for node in root.iter() if node.tag.endswith("testsuite"))
    testcase_nodes = sum(1 for node in root.iter() if node.tag.endswith("testcase"))
    tests = max(declared_tests, testcase_nodes)
    failures = sum(int(node.attrib.get("failures", "0") or 0) for node in root.iter() if node.tag.endswith("testsuite"))
    errors = sum(int(node.attrib.get("errors", "0") or 0) for node in root.iter() if node.tag.endswith("testsuite"))
    failure_nodes = sum(1 for node in root.iter() if node.tag.endswith("failure") or node.tag.endswith("error"))
    return tests, failures, errors, failure_nodes

def _valid_verified_at(value: Any) -> bool:
    if not isinstance(value, str) or not value.endswith("Z"):
        return False
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return parsed.tzinfo == timezone.utc

def _valid_verified_commit(value: Any) -> bool:
    return isinstance(value, str) and bool(FULL_SHA_RE.fullmatch(value))

def _artifact_status_errors(root: Path, label: str, item: dict[str, Any]) -> list[str]:
    status = item.get("status")
    artifact = item.get("artifact")
    kind = item.get("kind")
    if status not in {"green", "red", "baselined"} or not _artifact_ok(root, artifact):
        return []
    artifact_path = root / str(artifact)
    errors: list[str] = []
    if kind == "runtime" and artifact_path.suffix not in {".xml", ".txt"}:
        errors.append(f"{label} runtime evidence must use a parseable .xml or .txt result artifact")
    if kind == "runtime" and artifact_path.suffix == ".txt" and not str(artifact).startswith(str(JOURNEYS / "evidence") + "/"):
        errors.append(f"{label} runtime text evidence must live under .planning/journeys/evidence/")
    if artifact_path.suffix == ".xml":
        try:
            tests, failures, junit_errors, failure_nodes = _junit_counts(artifact_path)
        except (OSError, ElementTree.ParseError, ValueError) as exc:
            return [f"{label} has unreadable JUnit artifact: {exc}"]
        failed = failures > 0 or junit_errors > 0 or failure_nodes > 0
        if kind == "runtime" and tests == 0:
            errors.append(f"{label} runtime JUnit artifact reports zero executed tests")
        if status == "green" and failed:
            errors.append(f"{label} is green but JUnit artifact reports failures/errors")
        if status == "red" and not failed:
            errors.append(f"{label} is red but JUnit artifact reports no failures/errors")
    elif artifact_path.suffix == ".txt" and str(artifact).startswith(str(JOURNEYS / "evidence") + "/"):
        text = artifact_path.read_text(encoding="utf-8", errors="ignore")
        has_failure = any(marker in text for marker in TEXT_FAILURE_MARKERS)
        has_success = any(marker in text for marker in TEXT_SUCCESS_MARKERS)
        if status == "green" and has_failure:
            errors.append(f"{label} is green but text artifact contains failure markers")
        if status == "red" and not has_failure:
            errors.append(f"{label} is red but text artifact has no failure marker")
        if status == "green" and not has_success:
            errors.append(f"{label} green text artifact needs an explicit success marker")
    return errors

def _latest_evidence(data: dict[str, Any]) -> dict[str, Any] | None:
    latest = journey_os_generate._latest_evidence(data)
    return latest or None

def _latest_runtime_evidence(data: dict[str, Any]) -> dict[str, Any] | None:
    items = [
        item
        for item in data.get("evidence", [])
        if isinstance(item, dict) and item.get("kind") == "runtime"
    ]
    if not items:
        return None
    return items[-1]

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
        if kind == "runtime" and status in {"green", "red", "baselined"} and has_artifact:
            if not _valid_verified_at(item.get("verified_at")):
                errors.append(f"{label} durable runtime evidence requires verified_at as UTC ISO timestamp")
            if not _valid_verified_commit(item.get("verified_commit")):
                errors.append(f"{label} durable runtime evidence requires verified_commit as a full SHA")
        if status == "baselined" and not item.get("debt_ref"):
            errors.append(f"{label} baselined evidence requires debt_ref")
        if status == "missing" and item.get("artifact") is not None:
            errors.append(f"{label} missing evidence cannot have an artifact")
        errors += _artifact_status_errors(root, label, item)
    if data.get("status") == "live_proven":
        latest_runtime = _latest_runtime_evidence(data)
        if not latest_runtime:
            errors.append(f"{rel} live_proven requires runtime evidence")
        elif (
            latest_runtime.get("status") != "green"
            or not _artifact_ok(root, latest_runtime.get("artifact"))
            or not latest_runtime.get("verified_at")
            or not latest_runtime.get("verified_commit")
        ):
            errors.append(f"{rel} live_proven requires latest runtime evidence to be green with verified_at and verified_commit")
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
    latest_by_journey: dict[str, dict[str, Any]] = {}
    for _path, data in records:
        if not isinstance(data.get("id"), str):
            continue
        evidence = data.get("evidence")
        if not isinstance(evidence, list):
            continue
        if any(isinstance(item, dict) and item.get("status") == "green" and _artifact_ok(root, item.get("artifact")) for item in evidence):
            has_green_evidence.add(str(data["id"]))
        latest = _latest_evidence(data)
        if latest:
            latest_by_journey[str(data["id"])] = latest
    errors: list[str] = []
    for path, data in issues:
        has_green = data.get("journey_id") in has_green_evidence
        rel = path.relative_to(root)
        if data.get("evidence_status") == "green" and not has_green:
            errors.append(f"{rel} cannot be green without durable green evidence on referenced journey")
        latest = latest_by_journey.get(str(data.get("journey_id")))
        if latest and data.get("evidence_status") != latest.get("status"):
            errors.append(f"{rel} evidence_status must match latest evidence status {latest.get('status')}")
        if data.get("status") == "verified" and data.get("evidence_status") != "green":
            errors.append(f"{rel} verified issues must have green evidence_status")
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
    changed = [path for path in changed if not _is_ignored_generated(path)]
    errors += _scope_errors(root, changed)
    records, load_errors = _load_records(root)
    errors += load_errors
    issues, issue_load_errors = _load_issues(root)
    errors += issue_load_errors
    errors += _schema_validation_errors(root, records, issues)
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
