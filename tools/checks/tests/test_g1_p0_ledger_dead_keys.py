from __future__ import annotations

import copy
import json
import re
import subprocess
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
LEDGER_MATRIX = ROOT / ".planning/goals/G1-ledger-gap-matrix.md"
PROVIDER_MATRIX = ROOT / ".planning/goals/G1-provider-boundary.md"
TICKET_REGISTRY = ROOT / ".planning/goals/G1-blocking-gate-tickets.md"
NEGATIVE_FIXTURE = (
    ROOT / "tools/checks/fixtures/g1_p0_ledger_dead_keys_negative.md"
)
TICKET_EVIDENCE_NEGATIVE_FIXTURE = (
    ROOT / "tools/checks/fixtures/g1_phase37_ticket_evidence_negative.json"
)
AUDIT_MANIFEST_NEGATIVE_FIXTURE = (
    ROOT / "tools/checks/fixtures/g1_phase37_audit_manifest_negative.json"
)
TICKET_EVIDENCE_INDEX = (
    ROOT / ".planning/runtime-evidence/phase-37/ticket-evidence.json"
)
ACTIVE_G1_COUNT_DOCS = (
    ROOT / ".planning/PROJECT.md",
    ROOT / ".planning/ROADMAP.md",
    ROOT / ".planning/STATE.md",
    ROOT / ".planning/goals/G1-blocking-gate-tickets.md",
    ROOT / ".planning/goals/v3-product-reality-migration-manifest-2026-07-12.md",
    ROOT / ".planning/phases/37-ledger-runtime-readiness/37-CONTEXT.md",
    ROOT / ".planning/phases/37-ledger-runtime-readiness/37-VALIDATION.md",
    ROOT / ".planning/phases/37-ledger-runtime-readiness/37-07-PLAN.md",
    ROOT / ".planning/runtime-evidence/g1-ledger-reality-baseline-20260712/SCORECARD.md",
)

MATRIX_COLUMNS = [
    "canonical_key",
    "storage_key",
    "coach_profile_path",
    "type_unit",
    "allowed_sources",
    "freshness_tier",
    "confidence_weight",
    "classification",
    "profile_owner",
    "write_path",
    "reader_evidence",
    "consumers",
    "p0_loops",
    "tier",
    "required_for_output",
    "allowed_output_when_missing",
    "legal_source_asof",
    "sensitivity_purpose",
    "status",
    "existing_gate",
    "missing_gate",
    "blocks_G2",
    "ticket",
]
TICKET_COLUMNS = [
    "ticket_id",
    "gate_name",
    "owner",
    "target_files",
    "failing_predicate",
    "fixture_input",
    "red_command",
    "green_command",
    "blocks_G2",
    "blocked_P0_loops",
    "planned_implementation_slice",
    "status",
]
NON_LIVE_STATUSES = {
    "missing",
    "dead_on_restart",
    "semantic_mismatch",
    "quarantined",
}
LIVE_STATUSES = {"live", "partial"}
FAIL_CLOSED_OUTPUTS = {"partial+ask", "educational_only"}
ALLOWED_CLASSIFICATIONS = {
    "fact",
    "scenario_lever",
    "derived_output",
    "completion_marker",
    "specialist_reference",
}
SPECIALIST_REFERENCE_TYPES = {"document_ref", "list_document_ref", "ISO_date"}
RESERVED_REFERENCE_TYPES = {"document_ref", "list_document_ref"}
SUBLEDGER_TYPES = {
    "ConjointProfile": "conjoint",
    "PrevoyanceProfile": "prevoyance",
    "PatrimoineProfile": "patrimoine",
    "DepensesProfile": "depenses",
    "DetteProfile": "dettes",
}
CANONICAL_MODEL_IMPORT = "package:mint_mobile/models/coach_profile.dart"
CANONICAL_PROVIDER_IMPORT = (
    "package:mint_mobile/providers/coach_profile_provider.dart"
)
CANONICAL_PROVIDER_PACKAGE_IMPORT = "package:provider/provider.dart"
CANONICAL_BUILD_CONTEXT_IMPORTS = {
    "package:flutter/cupertino.dart",
    "package:flutter/material.dart",
    "package:flutter/widgets.dart",
}
CANONICAL_LEDGER_DECLARATIONS = {
    "CoachProfile": "apps/mobile/lib/models/coach_profile.dart",
    "CoachProfileProvider": (
        "apps/mobile/lib/providers/coach_profile_provider.dart"
    ),
}
REQUIRED_GATE_NAMES = {
    "provenance_on_write_test",
    "source_crosswalk_test",
    "provider_bridge_recompute_test",
    "default_is_not_known_test",
    "stale_reconfirmation_test",
    "return_uri_test",
    "runtime_persistence_test",
    "scenario_fact_isolation_test",
}
READER_EVIDENCE_RE = re.compile(
    r"(?P<path>[A-Za-z0-9_./-]+\.dart)#"
    r"(?P<class>[A-Za-z_][A-Za-z0-9_]*)\."
    r"(?P<member>[A-Za-z_][A-Za-z0-9_]*)@"
    r"(?P<token>[A-Za-z_][A-Za-z0-9_.]*)"
)
FORBIDDEN_READER_MEMBERS = {
    "fromWizardAnswers",
    "fromJson",
    "toJson",
}
SHA_RE = re.compile(r"[0-9a-f]{40}")
UTC_RE = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z")
EVIDENCE_ROOT = Path(".planning/runtime-evidence/phase-37")
TICKET_RECORD_FIELDS = {
    "ticket_id",
    "state",
    "command",
    "evidence_mode",
    "red_sha",
    "red_artifact",
    "control_sha",
    "control_artifact",
    "green_sha",
    "green_artifact",
    "accepted_sha",
}
EVIDENCE_LOG_FIELDS = {
    "ticket_id",
    "stage",
    "command",
    "sha",
    "recorded_at",
    "exit_code",
    "evidence_class",
    "assertion",
    "output",
    "synthetic_data_only",
}
AUDIT_RUN_FIELDS = {
    "command",
    "mode",
    "model",
    "base_sha",
    "head_sha",
    "exit_code",
    "output_artifact",
    "findings",
    "severity_counts",
}
AUDIT_FINDING_FIELDS = {"id", "severity", "status", "summary", "evidence"}
AUDIT_COUNT_FIELDS = {
    "p0",
    "p1",
    "p2",
    "critical",
    "high",
    "unresolved_p0",
    "unresolved_p1",
    "unresolved_critical",
    "unresolved_high",
}
FORBIDDEN_HARNESS_RED = (
    "no such file or directory",
    "file not found",
    "modulenotfounderror",
    "importerror",
    "syntaxerror",
    "command not found",
)


def _parse_table(path: Path, heading: str) -> tuple[list[str], list[dict[str, str]]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    try:
        start = lines.index(heading) + 1
    except ValueError as error:
        raise AssertionError(f"{path} is missing exact heading {heading!r}") from error

    while start < len(lines) and not lines[start].startswith("|"):
        start += 1
    assert start + 1 < len(lines), f"{path}: no Markdown table after {heading}"

    headers = [cell.strip() for cell in lines[start].strip("|").split("|")]
    separator = [cell.strip() for cell in lines[start + 1].strip("|").split("|")]
    assert len(separator) == len(headers)
    assert all(re.fullmatch(r":?-{3,}:?", cell) for cell in separator)

    rows: list[dict[str, str]] = []
    for line in lines[start + 2 :]:
        if not line.startswith("|"):
            break
        values = [cell.strip() for cell in line.strip("|").split("|")]
        assert len(values) == len(headers), (
            f"{path}: expected {len(headers)} cells, got {len(values)} in {line}"
        )
        rows.append(dict(zip(headers, values)))
    assert rows, f"{path}: empty table after {heading}"
    return headers, rows


def _json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _markdown_command(value: str) -> str:
    if value.startswith("`") and value.endswith("`"):
        return value[1:-1]
    return value


def _head_sha() -> str:
    return subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def _sha_exists(sha: object, root: Path) -> bool:
    if not isinstance(sha, str) or SHA_RE.fullmatch(sha) is None:
        return False
    return (
        subprocess.run(
            ["git", "cat-file", "-e", f"{sha}^{{commit}}"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        ).returncode
        == 0
    )


def _artifact_path_errors(path_value: object, root: Path, label: str) -> list[str]:
    if not isinstance(path_value, str) or not path_value:
        return [f"{label}: artifact path is required"]
    path = Path(path_value)
    if path.is_absolute() or ".." in path.parts:
        return [f"{label}: artifact path must stay repo-relative"]
    try:
        path.relative_to(EVIDENCE_ROOT)
    except ValueError:
        return [f"{label}: artifact path must stay below {EVIDENCE_ROOT}"]
    resolved = (root / path).resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError:
        return [f"{label}: artifact path escapes repository"]
    if not resolved.is_file():
        return [f"{label}: artifact does not exist: {path_value}"]
    if resolved.stat().st_size == 0:
        return [f"{label}: artifact is empty: {path_value}"]
    return []


def _evidence_log_errors(
    path_value: object,
    *,
    root: Path,
    ticket: dict[str, str],
    record_sha: object,
    command: str,
    stage: str,
) -> list[str]:
    label = f"{ticket['ticket_id']} {stage}"
    errors = _artifact_path_errors(path_value, root, label)
    if errors:
        return errors
    assert isinstance(path_value, str)
    try:
        payload = _json(root / path_value)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        return [f"{label}: artifact must be a JSON evidence log: {error}"]
    if not isinstance(payload, dict):
        return [f"{label}: artifact must contain one JSON object"]
    if set(payload) != EVIDENCE_LOG_FIELDS:
        errors.append(f"{label}: evidence log fields drifted: {sorted(payload)}")
        return errors
    if payload["ticket_id"] != ticket["ticket_id"]:
        errors.append(f"{label}: evidence log ticket mismatch")
    if payload["stage"] != stage:
        errors.append(f"{label}: evidence log stage mismatch")
    if payload["command"] != command:
        errors.append(f"{label}: evidence log command mismatch")
    if payload["sha"] != record_sha:
        errors.append(f"{label}: evidence log SHA mismatch")
    if not isinstance(payload["recorded_at"], str) or UTC_RE.fullmatch(
        payload["recorded_at"]
    ) is None:
        errors.append(f"{label}: recorded_at must be UTC second precision")
    if payload["synthetic_data_only"] is not True:
        errors.append(f"{label}: evidence must be synthetic-data-only")
    if payload["assertion"] != ticket["gate_name"]:
        errors.append(f"{label}: assertion must equal the registry gate_name")
    output = payload["output"]
    if not isinstance(output, str) or not output.strip():
        errors.append(f"{label}: output must be non-empty")
    if stage in {"RED", "CONTROL"}:
        if not isinstance(payload["exit_code"], int) or payload["exit_code"] == 0:
            errors.append(f"{label}: semantic failure must have non-zero exit code")
        if payload["evidence_class"] != "business_predicate":
            errors.append(f"{label}: failure is not a semantic business predicate")
        lowered = output.lower() if isinstance(output, str) else ""
        if any(marker in lowered for marker in FORBIDDEN_HARNESS_RED):
            errors.append(f"{label}: missing-file/import/syntax failure is not semantic RED")
    else:
        if payload["exit_code"] != 0:
            errors.append(f"{label}: GREEN evidence must have exit code 0")
        if payload["evidence_class"] != "pass":
            errors.append(f"{label}: GREEN evidence must be classified pass")
    return errors


def _ticket_record_errors(
    record: object,
    *,
    ticket: dict[str, str] | None,
    root: Path,
) -> list[str]:
    if not isinstance(record, dict):
        return ["ticket evidence record must be an object"]
    errors: list[str] = []
    if set(record) != TICKET_RECORD_FIELDS:
        errors.append(f"ticket evidence fields drifted: {sorted(record)}")
        return errors
    ticket_id = record["ticket_id"]
    if ticket is None:
        return [f"unknown ticket: {ticket_id}"]
    command = _markdown_command(ticket["green_command"])
    if ticket["red_command"] != ticket["green_command"]:
        errors.append(f"{ticket_id}: RED and GREEN registry commands must be identical")
    if record["command"] != command:
        errors.append(f"{ticket_id}: evidence command does not match registry")
    state = record["state"]
    if state not in {"ticket_only", "red_proven", "green"}:
        errors.append(f"{ticket_id}: unsupported evidence state {state!r}")
        return errors
    nullable_fields = (
        "red_sha",
        "red_artifact",
        "control_sha",
        "control_artifact",
        "green_sha",
        "green_artifact",
        "accepted_sha",
    )
    if state == "ticket_only":
        if record["evidence_mode"] is not None:
            errors.append(f"{ticket_id}: pending evidence_mode must be null")
        if any(record[field] is not None for field in nullable_fields):
            errors.append(f"{ticket_id}: pending ticket cannot claim evidence")
        return errors

    mode = record["evidence_mode"]
    if mode not in {"red_green", "baseline_green_controlled"}:
        errors.append(f"{ticket_id}: unsupported evidence_mode {mode!r}")
        return errors
    if mode == "red_green":
        if record["red_sha"] is None or record["red_artifact"] is None:
            errors.append(f"{ticket_id}: red_green requires RED evidence")
        if record["control_sha"] is not None or record["control_artifact"] is not None:
            errors.append(f"{ticket_id}: red_green cannot borrow CONTROL evidence")
        if record["red_sha"] is not None:
            if not _sha_exists(record["red_sha"], root):
                errors.append(f"{ticket_id}: red_sha must be an existing 40-hex commit")
            if record["red_artifact"] is not None:
                errors.extend(
                    _evidence_log_errors(
                        record["red_artifact"],
                        root=root,
                        ticket=ticket,
                        record_sha=record["red_sha"],
                        command=command,
                        stage="RED",
                    )
                )
    else:
        if record["control_sha"] is None or record["control_artifact"] is None:
            errors.append(f"{ticket_id}: baseline_green_controlled requires CONTROL evidence")
        if record["red_sha"] is not None or record["red_artifact"] is not None:
            errors.append(f"{ticket_id}: baseline_green_controlled cannot claim RED")
        if record["control_sha"] is not None:
            if not _sha_exists(record["control_sha"], root):
                errors.append(f"{ticket_id}: control_sha must be an existing 40-hex commit")
            if record["control_artifact"] is not None:
                errors.extend(
                    _evidence_log_errors(
                        record["control_artifact"],
                        root=root,
                        ticket=ticket,
                        record_sha=record["control_sha"],
                        command=command,
                        stage="CONTROL",
                    )
                )

    if state == "red_proven":
        if mode != "red_green":
            errors.append(f"{ticket_id}: red_proven requires red_green mode")
        if any(record[field] is not None for field in ("green_sha", "green_artifact", "accepted_sha")):
            errors.append(f"{ticket_id}: red_proven cannot claim GREEN or acceptance")
        return errors

    for field in ("green_sha", "green_artifact", "accepted_sha"):
        if record[field] is None:
            errors.append(f"{ticket_id}: green state requires {field}")
    if record["green_sha"] is not None:
        if not _sha_exists(record["green_sha"], root):
            errors.append(f"{ticket_id}: green_sha must be an existing 40-hex commit")
        if record["green_artifact"] is not None:
            errors.extend(
                _evidence_log_errors(
                    record["green_artifact"],
                    root=root,
                    ticket=ticket,
                    record_sha=record["green_sha"],
                    command=command,
                    stage="GREEN",
                )
            )
    if record["accepted_sha"] != record["green_sha"]:
        errors.append(f"{ticket_id}: accepted_sha must equal green_sha")
    return errors


def _registry_evidence_errors(
    tickets: list[dict[str, str]],
    records: list[object],
    *,
    root: Path,
    require_complete: bool,
) -> list[str]:
    errors: list[str] = []
    tickets_by_id = {ticket["ticket_id"]: ticket for ticket in tickets}
    record_ids = [record.get("ticket_id") for record in records if isinstance(record, dict)]
    duplicate_ids = [ticket_id for ticket_id, count in Counter(record_ids).items() if count > 1]
    for ticket_id in sorted(str(value) for value in duplicate_ids):
        errors.append(f"duplicate evidence ticket_id: {ticket_id}")
    if require_complete and set(record_ids) != set(tickets_by_id):
        errors.append("evidence index must contain exactly the registry ticket IDs")
    for record in records:
        ticket_id = record.get("ticket_id") if isinstance(record, dict) else None
        ticket = tickets_by_id.get(ticket_id)
        errors.extend(_ticket_record_errors(record, ticket=ticket, root=root))
        if ticket is not None and isinstance(record, dict):
            if ticket["status"] != record["state"]:
                errors.append(f"{ticket_id}: registry/evidence status disagreement")
    return errors


def _expected_audit_command(mode: str, model: str, base_sha: str) -> str | None:
    prefix = "CLAUDE_AUDIT_RERUN=1 " if model == "sonnet" else ""
    if model not in {"opus", "sonnet"}:
        return None
    if mode == "architecture":
        return f"{prefix}tools/checks/claude_external_audit.sh architecture"
    if mode in {"code", "product-domain"}:
        return f"{prefix}tools/checks/claude_external_audit.sh {mode} {base_sha}"
    return None


def _audit_manifest_errors(
    manifest: object,
    *,
    root: Path,
    expected_required_modes: set[str],
) -> list[str]:
    if not isinstance(manifest, dict):
        return ["audit manifest must be an object"]
    errors: list[str] = []
    if set(manifest) != {"required_modes", "runs"}:
        errors.append(f"audit manifest fields drifted: {sorted(manifest)}")
        return errors
    required_modes = manifest["required_modes"]
    runs = manifest["runs"]
    if not isinstance(required_modes, list) or set(required_modes) != expected_required_modes:
        errors.append("audit manifest required_modes mismatch")
    if not isinstance(required_modes, list) or len(required_modes) != len(set(required_modes)):
        errors.append("audit manifest required_modes contains duplicates")
    if not isinstance(runs, list):
        return errors + ["audit manifest runs must be a list"]
    run_modes = [run.get("mode") for run in runs if isinstance(run, dict)]
    if set(run_modes) != expected_required_modes or len(run_modes) != len(expected_required_modes):
        errors.append("audit manifest needs exactly one accepted run per required mode")
    if len(run_modes) != len(set(run_modes)):
        errors.append("audit manifest contains duplicate accepted mode")
    head_shas: set[str] = set()
    for run in runs:
        if not isinstance(run, dict):
            errors.append("audit run must be an object")
            continue
        if set(run) != AUDIT_RUN_FIELDS:
            errors.append(f"audit run fields drifted: {sorted(run)}")
            continue
        mode = run["mode"]
        model = run["model"]
        base_sha = run["base_sha"]
        head_sha = run["head_sha"]
        if not _sha_exists(base_sha, root):
            errors.append(f"{mode}: base_sha must be an existing 40-hex commit")
        if not _sha_exists(head_sha, root):
            errors.append(f"{mode}: head_sha must be an existing 40-hex commit")
        if isinstance(head_sha, str):
            head_shas.add(head_sha)
        expected_command = _expected_audit_command(mode, model, base_sha)
        if expected_command is None or run["command"] != expected_command:
            errors.append(f"{mode}: audit command/model/base mismatch")
        if run["exit_code"] != 0:
            errors.append(f"{mode}: non-zero audit exit cannot be accepted")
        output_errors = _artifact_path_errors(
            run["output_artifact"], root, f"{mode} audit"
        )
        errors.extend(output_errors)
        if not output_errors:
            assert isinstance(run["output_artifact"], str)
            output_text = (root / run["output_artifact"]).read_text(
                encoding="utf-8"
            )
            expected_verdict = (
                "Product/domain verdict: PASS"
                if mode == "product-domain"
                else "PASS"
            )
            if expected_verdict not in output_text:
                errors.append(f"{mode}: accepted output is missing its PASS verdict")
            lowered_output = output_text.lower()
            if any(
                marker in lowered_output
                for marker in (
                    "quota exceeded",
                    "not authenticated",
                    "authentication failed",
                    "timed out",
                    "timeout before verdict",
                )
            ):
                errors.append(f"{mode}: quota/auth/timeout output cannot be accepted")
        findings = run["findings"]
        counts = run["severity_counts"]
        if not isinstance(findings, list):
            errors.append(f"{mode}: findings must be a complete list")
            findings = []
        if not isinstance(counts, dict) or set(counts) != AUDIT_COUNT_FIELDS:
            errors.append(f"{mode}: severity counts are incomplete")
            counts = {}
        else:
            if any(not isinstance(value, int) or value < 0 for value in counts.values()):
                errors.append(f"{mode}: severity counts must be non-negative integers")
            for severity in ("p0", "p1", "p2", "critical", "high"):
                observed = sum(
                    1
                    for finding in findings
                    if isinstance(finding, dict) and finding.get("severity") == severity
                )
                if counts[severity] != observed:
                    errors.append(f"{mode}: {severity} count does not match findings")
            for severity in ("p0", "p1", "critical", "high"):
                observed = sum(
                    1
                    for finding in findings
                    if isinstance(finding, dict)
                    and finding.get("severity") == severity
                    and finding.get("status") == "unresolved"
                )
                if counts[f"unresolved_{severity}"] != observed:
                    errors.append(f"{mode}: unresolved {severity} count does not match findings")
                if counts[f"unresolved_{severity}"] != 0:
                    errors.append(f"{mode}: unresolved {severity} blocks acceptance")
        for finding in findings:
            if not isinstance(finding, dict) or set(finding) != AUDIT_FINDING_FIELDS:
                errors.append(f"{mode}: finding fields are incomplete")
                continue
            if finding["severity"] not in {"p0", "p1", "p2", "critical", "high"}:
                errors.append(f"{mode}: unsupported finding severity")
            if finding["status"] not in {"resolved", "unresolved", "accepted_p2"}:
                errors.append(f"{mode}: unsupported finding status")
            if not all(isinstance(finding[field], str) and finding[field].strip() for field in ("id", "summary", "evidence")):
                errors.append(f"{mode}: finding content is incomplete")
    if len(head_shas) > 1:
        errors.append("audit accepted runs have head SHA drift")
    return errors


def _replace_fixture_tokens(value: Any, *, head_sha: str) -> Any:
    if isinstance(value, dict):
        return {key: _replace_fixture_tokens(item, head_sha=head_sha) for key, item in value.items()}
    if isinstance(value, list):
        return [_replace_fixture_tokens(item, head_sha=head_sha) for item in value]
    if value == "<HEAD_SHA>":
        return head_sha
    if isinstance(value, str):
        return value.replace("<HEAD_SHA>", head_sha)
    return value


def _json_path_parent(document: Any, path: str) -> tuple[Any, str]:
    parts = path.split(".")
    current = document
    while len(parts) > 1:
        if isinstance(current, list):
            current = current[int(parts.pop(0))]
            continue
        complete_key = ".".join(parts)
        if complete_key in current:
            return current, complete_key
        matched = False
        for width in range(len(parts) - 1, 0, -1):
            candidate = ".".join(parts[:width])
            if candidate in current:
                current = current[candidate]
                parts = parts[width:]
                matched = True
                break
        if not matched:
            raise KeyError(path)
    return current, parts[0]


def _json_path_value(document: Any, path: str) -> Any:
    parent, final = _json_path_parent(document, path)
    return parent[int(final)] if isinstance(parent, list) else parent[final]


def _set_json_path(document: Any, path: str, value: Any) -> None:
    current, final = _json_path_parent(document, path)
    if isinstance(current, list):
        current[int(final)] = value
    else:
        current[final] = value


def _remove_json_path(document: Any, path: str) -> None:
    current, final = _json_path_parent(document, path)
    if isinstance(current, list):
        del current[int(final)]
    else:
        del current[final]


def _mutated_candidate(base: Any, operations: list[dict[str, Any]]) -> Any:
    candidate = copy.deepcopy(base)
    for operation in operations:
        if operation["op"] == "set":
            _set_json_path(candidate, operation["path"], operation["value"])
        elif operation["op"] == "remove":
            _remove_json_path(candidate, operation["path"])
        elif operation["op"] == "duplicate":
            source = _json_path_value(candidate, operation["path"])
            target = _json_path_value(candidate, operation["target"])
            target.append(copy.deepcopy(source))
        elif operation["op"] == "append":
            target = _json_path_value(candidate, operation["path"])
            target.append(copy.deepcopy(operation["value"]))
        else:
            raise AssertionError(f"unsupported fixture mutation: {operation}")
    return candidate


def _ticket_ids_declared_by_matrices() -> set[str]:
    pattern = re.compile(r"\bG1-[A-Z]+(?:-[A-Z]+)*-\d+\b")
    return {
        match.group(0)
        for path in (LEDGER_MATRIX, PROVIDER_MATRIX)
        for match in pattern.finditer(path.read_text(encoding="utf-8"))
    }


def _semantic_reader_tokens(row: dict[str, str]) -> set[str]:
    tokens = {row.get("canonical_key", "")}
    tokens.update(row.get("storage_key", "").split("+"))

    profile_path = row.get("coach_profile_path", "")
    tokens.add(profile_path)
    tokens.update(profile_path.split("."))

    return {token for token in tokens if token not in {"", "NONE"} and len(token) >= 3}


def _mask_dart_source(source: str, *, mask_strings: bool) -> str:
    """Mask comments and optionally strings without changing source offsets."""

    chars = list(source)
    masked = list(source)

    def blank(index: int) -> None:
        if masked[index] not in {"\n", "\r"}:
            masked[index] = " "

    index = 0
    while index < len(chars):
        if source.startswith("//", index):
            while index < len(chars) and chars[index] not in {"\n", "\r"}:
                blank(index)
                index += 1
            continue
        if source.startswith("/*", index):
            depth = 1
            blank(index)
            blank(index + 1)
            index += 2
            while index < len(chars) and depth > 0:
                if source.startswith("/*", index):
                    depth += 1
                    blank(index)
                    blank(index + 1)
                    index += 2
                elif source.startswith("*/", index):
                    depth -= 1
                    blank(index)
                    blank(index + 1)
                    index += 2
                else:
                    blank(index)
                    index += 1
            continue
        if chars[index] not in {"'", '"'}:
            index += 1
            continue

        quote = chars[index]
        delimiter = quote * 3 if source.startswith(quote * 3, index) else quote
        raw = (
            index > 0
            and chars[index - 1] in {"r", "R"}
            and (index < 2 or not (chars[index - 2].isalnum() or chars[index - 2] == "_"))
        )
        string_start = index
        index += len(delimiter)
        while index < len(chars):
            if not raw and chars[index] == "\\":
                index = min(len(chars), index + 2)
                continue
            if source.startswith(delimiter, index):
                index += len(delimiter)
                break
            index += 1
        if mask_strings:
            for string_index in range(string_start, index):
                blank(string_index)

    return "".join(masked)


def _matching_delimiter_end(
    source: str,
    opening_index: int,
    opening: str,
    closing: str,
) -> int | None:
    depth = 0
    for index in range(opening_index, len(source)):
        char = source[index]
        if char == opening:
            depth += 1
        elif char == closing:
            depth -= 1
            if depth == 0:
                return index + 1
    return None


def _dart_class_body(
    structural_source: str,
    class_name: str,
) -> tuple[int, int] | None:
    declaration = re.compile(
        rf"\b(?:abstract\s+|base\s+|final\s+|interface\s+|sealed\s+)?"
        rf"(?:class|mixin|extension(?:\s+type)?)\s+{re.escape(class_name)}\b"
    ).search(structural_source)
    if declaration is None:
        return None
    opening = structural_source.find("{", declaration.end())
    if opening < 0:
        return None
    closing = _matching_delimiter_end(structural_source, opening, "{", "}")
    if closing is None:
        return None
    return opening + 1, closing - 1


def _top_level_depths(source: str, start: int, end: int) -> list[int]:
    depths = [0] * (end - start)
    depth = 0
    for absolute in range(start, end):
        relative = absolute - start
        depths[relative] = depth
        if source[absolute] == "{":
            depth += 1
        elif source[absolute] == "}":
            depth = max(0, depth - 1)
    return depths


def _skip_space_and_async_modifiers(source: str, index: int, end: int) -> int:
    while True:
        while index < end and source[index].isspace():
            index += 1
        modifier = re.match(r"(?:async\*?|sync\*)\b", source[index:end])
        if modifier is None:
            return index
        index += modifier.end()


def _arrow_expression_end(source: str, start: int, end: int) -> int | None:
    paren_depth = bracket_depth = brace_depth = 0
    for index in range(start, end):
        char = source[index]
        if char == "(":
            paren_depth += 1
        elif char == ")":
            paren_depth = max(0, paren_depth - 1)
        elif char == "[":
            bracket_depth += 1
        elif char == "]":
            bracket_depth = max(0, bracket_depth - 1)
        elif char == "{":
            brace_depth += 1
        elif char == "}":
            brace_depth = max(0, brace_depth - 1)
        elif char == ";" and paren_depth == bracket_depth == brace_depth == 0:
            return index + 1
    return None


def _generic_type_parameters_end(
    source: str,
    opening_index: int,
    end: int,
) -> int | None:
    """Match a method's bounded ``<...>`` before its parameter list."""

    depth = 0
    for index in range(opening_index, end):
        if source[index] == "<":
            depth += 1
        elif source[index] == ">":
            depth -= 1
            if depth == 0:
                return index + 1
    return None


def _dart_member_body(
    structural_source: str,
    *,
    class_body: tuple[int, int],
    class_name: str,
    member_name: str,
) -> tuple[int, int, int, int] | str:
    start, end = class_body
    depths = _top_level_depths(structural_source, start, end)
    saw_declaration = False
    for occurrence in re.finditer(rf"\b{re.escape(member_name)}\b", structural_source[start:end]):
        absolute_start = start + occurrence.start()
        if depths[occurrence.start()] != 0:
            continue

        statement_start = absolute_start - 1
        while statement_start >= start and structural_source[statement_start] not in ";}":
            statement_start -= 1
        header = structural_source[statement_start + 1 : absolute_start]
        if "=" in header or "=>" in header:
            continue

        cursor = start + occurrence.end()
        while cursor < end and structural_source[cursor].isspace():
            cursor += 1

        if cursor < end and structural_source[cursor] == "<":
            generic_end = _generic_type_parameters_end(
                structural_source, cursor, end
            )
            if generic_end is None:
                saw_declaration = True
                continue
            cursor = generic_end
            while cursor < end and structural_source[cursor].isspace():
                cursor += 1

        if cursor < end and structural_source[cursor] == "(":
            params_end = _matching_delimiter_end(
                structural_source, cursor, "(", ")"
            )
            if params_end is None or params_end > end:
                continue
            cursor = _skip_space_and_async_modifiers(
                structural_source, params_end, end
            )
        elif re.search(r"\bget\s*$", header) is None:
            saw_declaration = True
            continue

        if structural_source.startswith("=>", cursor):
            expression_end = _arrow_expression_end(
                structural_source, cursor + 2, end
            )
            if expression_end is not None:
                return (
                    cursor + 2,
                    expression_end,
                    statement_start + 1,
                    expression_end,
                )
        elif cursor < end and structural_source[cursor] == "{":
            body_end = _matching_delimiter_end(
                structural_source, cursor, "{", "}"
            )
            if body_end is not None and body_end <= end + 1:
                return (
                    cursor + 1,
                    body_end - 1,
                    statement_start + 1,
                    body_end,
                )
        else:
            saw_declaration = True

    if saw_declaration:
        return "declaration is not a consumer"
    return "missing member"


def _dart_member_is_constructor(
    structural_source: str,
    *,
    class_body: tuple[int, int],
    class_name: str,
    member_name: str,
) -> bool:
    """Return true for unnamed, named, redirecting, and factory constructors."""

    start, end = class_body
    depths = _top_level_depths(structural_source, start, end)
    if member_name == class_name:
        pattern = re.compile(rf"\b{re.escape(class_name)}\s*\(")
    else:
        pattern = re.compile(
            rf"\b{re.escape(class_name)}\s*\.\s*"
            rf"{re.escape(member_name)}\s*\("
        )

    for occurrence in pattern.finditer(structural_source[start:end]):
        if depths[occurrence.start()] != 0:
            continue
        absolute_start = start + occurrence.start()
        statement_start = absolute_start - 1
        while statement_start >= start and structural_source[statement_start] not in ";}":
            statement_start -= 1
        declaration_prefix = structural_source[statement_start + 1 : absolute_start]
        if "=" in declaration_prefix or "=>" in declaration_prefix:
            continue
        return True
    return False


def _receiver_access_pattern(
    receiver: str,
    path_parts: list[str],
) -> re.Pattern[str]:
    separator = r"\s*(?:\?|!)?\.\s*"
    suffix = separator.join(re.escape(part) for part in path_parts)
    pattern = rf"\b{re.escape(receiver)}{separator}{suffix}\b"
    return re.compile(pattern)


def _typed_names(member: str, type_name: str) -> set[str]:
    return {
        match.group("name")
        for match in re.finditer(
            rf"\b{re.escape(type_name)}\s*\??\s+"
            r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\b",
            member,
        )
    }


def _has_exact_unaliased_import(source: str, uri: str) -> bool:
    """Require the checked-in package URI, not a same-named local type."""

    structural_source = _mask_dart_source(source, mask_strings=True)
    import_pattern = re.compile(
        rf"(?m)^[ \t]*(?P<keyword>import)\s+"
        rf"(?P<quote>['\"]){re.escape(uri)}(?P=quote)\s*;[ \t]*$"
    )
    for match in import_pattern.finditer(source):
        keyword_start = match.start("keyword")
        if structural_source[keyword_start : keyword_start + 6] == "import":
            return True
    return False


def _declares_type_named(source: str, type_name: str) -> bool:
    structural_source = _mask_dart_source(source, mask_strings=True)
    return (
        re.search(
            rf"\b(?:class|mixin|enum|typedef|extension\s+type)\s+"
            rf"{re.escape(type_name)}\b",
            structural_source,
        )
        is not None
    )


def _trusted_provider_acquisition_pattern(
    source: str,
    member: str,
    class_name: str,
) -> str:
    """Return only Provider acquisitions with a canonical BuildContext."""

    imports_provider = _has_exact_unaliased_import(
        source, CANONICAL_PROVIDER_PACKAGE_IMPORT
    )
    imports_build_context = any(
        _has_exact_unaliased_import(source, uri)
        for uri in CANONICAL_BUILD_CONTEXT_IMPORTS
    )
    structural_member = _mask_dart_source(member, mask_strings=True)
    context_receivers = _typed_names(structural_member, "BuildContext")
    structural_source = _mask_dart_source(source, mask_strings=True)
    flutter_state = re.search(
        rf"\bclass\s+{re.escape(class_name)}\b[^{{;]*"
        r"\bextends\s+State\s*<",
        structural_source,
    )
    local_context = re.search(
        r"\b(?:final|var|const|late)\s+"
        r"(?:[A-Za-z_][A-Za-z0-9_]*\s*\??\s+)?context\b",
        structural_member,
    )
    if (
        flutter_state is not None
        and local_context is None
        and not _declares_type_named(source, "State")
    ):
        context_receivers.add("context")
    if (
        not imports_provider
        or not imports_build_context
        or not context_receivers
        or _declares_type_named(source, "BuildContext")
        or _declares_type_named(source, "Provider")
    ):
        return r"(?!)"

    context_receiver = "(?:" + "|".join(
        map(re.escape, sorted(context_receivers))
    ) + ")"
    provider_type = r"CoachProfileProvider\s*\??"
    return (
        r"(?:"
        rf"{context_receiver}\s*\.\s*(?:read|watch)\s*<\s*"
        rf"{provider_type}\s*>\s*\(\s*\)"
        r"|Provider\s*\.\s*of\s*<\s*"
        rf"{provider_type}\s*>\s*\(\s*{context_receiver}\b[^;]*?\)"
        r")"
    )


def _ledger_receivers(
    source: str,
    member: str,
    class_name: str,
) -> tuple[set[str], dict[str, set[str]]]:
    """Resolve receivers whose canonical origin is proven inside one member.

    Detached sub-ledger parameters deliberately fail closed: canonical type
    identity does not prove they belong to the owner profile. A sub-ledger
    receiver qualifies only when acquired from an eligible profile in-member.
    """

    structural_member = _mask_dart_source(member, mask_strings=True)
    has_model_import = _has_exact_unaliased_import(
        source, CANONICAL_MODEL_IMPORT
    )
    has_provider_import = _has_exact_unaliased_import(
        source, CANONICAL_PROVIDER_IMPORT
    )
    coach_receivers = (
        _typed_names(structural_member, "CoachProfile")
        if has_model_import
        else set()
    )
    provider_receivers = (
        _typed_names(structural_member, "CoachProfileProvider")
        if has_provider_import
        else set()
    )

    provider_assignment = re.compile(
        r"\b(?:final|var)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*"
        rf"{_trusted_provider_acquisition_pattern(source, member, class_name)}\s*;",
        re.DOTALL,
    )
    if has_provider_import:
        provider_receivers.update(
            match.group("name")
            for match in provider_assignment.finditer(structural_member)
        )

    direct_profile_assignment = re.compile(
        r"\b(?:final|var)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*"
        rf"{_trusted_provider_acquisition_pattern(source, member, class_name)}\s*"
        r"(?:\?|!)?\.\s*profile\b",
        re.DOTALL,
    )
    if has_provider_import:
        coach_receivers.update(
            match.group("name")
            for match in direct_profile_assignment.finditer(structural_member)
        )

    for provider in provider_receivers:
        indirect_profile_assignment = re.compile(
            r"\b(?:final|var)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*"
            rf"{re.escape(provider)}\s*(?:\?|!)?\.\s*profile\b"
        )
        coach_receivers.update(
            match.group("name")
            for match in indirect_profile_assignment.finditer(structural_member)
        )

    subledger_receivers = {segment: set() for segment in SUBLEDGER_TYPES.values()}
    for profile in coach_receivers:
        for segment in SUBLEDGER_TYPES.values():
            inferred = re.compile(
                r"\b(?:final|var)\s+"
                r"(?:[A-Za-z_][A-Za-z0-9_]*\s*\??\s+)?"
                r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*"
                rf"{re.escape(profile)}\s*(?:\?|!)?\.\s*"
                rf"{re.escape(segment)}\b"
            )
            subledger_receivers[segment].update(
                match.group("name")
                for match in inferred.finditer(structural_member)
            )

    return coach_receivers, subledger_receivers


def _qualified_ledger_access_occurs(
    body: str,
    *,
    source: str,
    member: str,
    class_name: str,
    profile_path: str,
    token: str,
    classification: str,
) -> bool:
    path_parts = profile_path.split(".")
    if profile_path in {"", "NONE"} or token != path_parts[-1]:
        return False

    coach_receivers, subledger_receivers = _ledger_receivers(
        source, member, class_name
    )
    structural_body = _mask_dart_source(body, mask_strings=True)
    for receiver in coach_receivers:
        if _receiver_access_pattern(receiver, path_parts).search(structural_body):
            return True

    first_segment = path_parts[0]
    if len(path_parts) > 1 and first_segment in subledger_receivers:
        for receiver in subledger_receivers[first_segment]:
            if _receiver_access_pattern(receiver, path_parts[1:]).search(
                structural_body
            ):
                return True

    if classification != "completion_marker" or len(path_parts) < 2:
        return False

    # Completion markers are the sole string-key exception, and only when the
    # key is looked up through the exact typed marker collection from the row.
    marker_collection = path_parts[:-1]
    for receiver in coach_receivers:
        collection = _receiver_access_pattern(
            receiver, marker_collection
        ).pattern
        marker_lookup = re.compile(
            rf"{collection}\s*\.\s*(?:contains|containsKey)\s*\(\s*"
            rf"(?P<quote>['\"]){re.escape(token)}(?P=quote)\s*\)"
        )
        if marker_lookup.search(body) is not None:
            return True

    return False


def _reader_evidence_errors(
    row: dict[str, str],
    *,
    root: Path = ROOT,
) -> list[str]:
    key = row.get("canonical_key", "<unknown>")
    evidence = row.get("reader_evidence", "")
    match = READER_EVIDENCE_RE.fullmatch(evidence)
    if match is None:
        return [
            f"{key}: reader evidence must be exact "
            "repo/path.dart#ClassName.memberName@fieldToken"
        ]

    member_name = match.group("member")
    if member_name in FORBIDDEN_READER_MEMBERS or member_name.startswith("copyWith"):
        return [f"{key}: forbidden reconstruction/serializer member {member_name}"]
    evidence_token = match.group("token")
    row_tokens = _semantic_reader_tokens(row)
    if evidence_token not in row_tokens:
        return [
            f"{key}: evidence token {evidence_token!r} is not row-derived; "
            f"expected one of {sorted(row_tokens)}"
        ]

    relative_path = Path(match.group("path"))
    if relative_path.is_absolute() or ".." in relative_path.parts:
        return [f"{key}: reader evidence path must stay repo-relative"]

    source_path = (root / relative_path).resolve()
    try:
        source_path.relative_to(root.resolve())
    except ValueError:
        return [f"{key}: reader evidence path escapes repository"]
    if not source_path.is_file():
        return [f"{key}: reader evidence file does not exist: {relative_path}"]

    source = source_path.read_text(encoding="utf-8")
    structural_source = _mask_dart_source(source, mask_strings=True)
    class_name = match.group("class")
    class_body = _dart_class_body(structural_source, class_name)
    if class_body is None:
        return [f"{key}: missing class {class_name} in {relative_path}"]
    if _dart_member_is_constructor(
        structural_source,
        class_body=class_body,
        class_name=class_name,
        member_name=member_name,
    ):
        return [f"{key}: forbidden constructor member {class_name}.{member_name}"]
    member_body = _dart_member_body(
        structural_source,
        class_body=class_body,
        class_name=class_name,
        member_name=member_name,
    )
    if isinstance(member_body, str):
        return [f"{key}: {member_body} {class_name}.{member_name}"]

    body_start, body_end, member_start, member_end = member_body
    semantic_body = _mask_dart_source(
        source[body_start:body_end], mask_strings=False
    )
    semantic_member = source[member_start:member_end]
    shadowed_types = {
        type_name
        for type_name, declaration_path in CANONICAL_LEDGER_DECLARATIONS.items()
        if relative_path.as_posix()
        != declaration_path
        and _declares_type_named(source, type_name)
    }
    if shadowed_types:
        return [
            f"{key}: {class_name}.{member_name} contains no profile-typed receiver "
            "access because canonical ledger type names are locally declared: "
            f"{sorted(shadowed_types)}"
        ]
    if not _qualified_ledger_access_occurs(
        semantic_body,
        source=source,
        member=semantic_member,
        class_name=class_name,
        profile_path=row.get("coach_profile_path", ""),
        token=evidence_token,
        classification=row.get("classification", "fact"),
    ):
        return [
            f"{key}: {class_name}.{member_name} contains no profile-typed receiver "
            "access "
            f"derived from coach_profile_path {row.get('coach_profile_path')!r} "
            f"for token {evidence_token!r}"
        ]
    return []


def _matrix_errors(
    headers: list[str],
    rows: list[dict[str, str]],
    ticket_ids: set[str],
) -> list[str]:
    errors: list[str] = []
    if headers != MATRIX_COLUMNS:
        errors.append(f"required columns drifted: {headers}")

    counts = Counter(row.get("canonical_key", "") for row in rows)
    for key, count in sorted(counts.items()):
        if not key or count != 1:
            errors.append(f"duplicate canonical_key: {key or '<blank>'} ({count})")

    for row in rows:
        key = row.get("canonical_key", "<unknown>")
        classification = row.get("classification", "")
        type_unit = row.get("type_unit", "")
        if classification not in ALLOWED_CLASSIFICATIONS:
            errors.append(f"{key}: unsupported classification {classification!r}")
        if classification == "completion_marker" and type_unit != "completion_marker":
            errors.append(
                f"{key}: completion_marker classification requires "
                "completion_marker type_unit"
            )
        if type_unit == "completion_marker" and classification != "completion_marker":
            errors.append(
                f"{key}: completion_marker type_unit requires "
                "completion_marker classification"
            )
        if (
            classification == "specialist_reference"
            and type_unit not in SPECIALIST_REFERENCE_TYPES
        ):
            errors.append(
                f"{key}: specialist_reference classification has incompatible "
                f"type_unit {type_unit!r}"
            )
        if (
            type_unit in RESERVED_REFERENCE_TYPES
            and classification != "specialist_reference"
        ):
            errors.append(
                f"{key}: {type_unit} type_unit requires specialist_reference "
                "classification"
            )
        if classification in {"scenario_lever", "derived_output"}:
            durable_edges = [
                column
                for column in ("storage_key", "coach_profile_path", "write_path")
                if row.get(column) not in {"", "NONE"}
            ]
            if durable_edges:
                errors.append(
                    f"{key}: {classification} must not claim durable edges "
                    + ",".join(durable_edges)
                )
        tier = row.get("tier", "")
        status = row.get("status", "")
        if status not in LIVE_STATUSES | NON_LIVE_STATUSES:
            errors.append(f"{key}: unsupported {tier} status {status!r}")

        missing_edges = [
            column
            for column in ("write_path", "reader_evidence", "consumers")
            if row.get(column) in {"", "NONE"}
        ]
        if status in LIVE_STATUSES and missing_edges:
            errors.append(
                f"{key}: silent dead {tier} {status} key missing "
                + ",".join(missing_edges)
            )

        if key == "has3a" and (
            status != "quarantined"
            or row.get("reader_evidence") != "NONE"
            or row.get("consumers") != "NONE"
            or "typed_consumer"
            not in row.get("missing_gate", "").split(",")
        ):
            errors.append(
                "has3a: quarantine contract drifted; keep status=quarantined "
                "and reader_evidence=consumers=NONE with typed_consumer in "
                "missing_gate until a typed production consumer is proven"
            )

        if key == "hasAvsGaps" and (
            status != "quarantined"
            or row.get("reader_evidence") != "NONE"
            or row.get("consumers") != "NONE"
            or "typed_consumer"
            not in row.get("missing_gate", "").split(",")
        ):
            errors.append(
                "hasAvsGaps: quarantine contract drifted; keep "
                "status=quarantined and reader_evidence=consumers=NONE with "
                "typed_consumer in missing_gate until a typed production "
                "consumer of avsGapStatus is proven"
            )

        if tier != "P0":
            continue

        if status in LIVE_STATUSES and row.get("reader_evidence") not in {"", "NONE"}:
            errors.extend(_reader_evidence_errors(row))

        if status in NON_LIVE_STATUSES:
            if row.get("allowed_output_when_missing") not in FAIL_CLOSED_OUTPUTS:
                errors.append(f"{key}: non-live P0 status does not fail closed")
            if row.get("blocks_G2") != "yes":
                errors.append(f"{key}: non-live P0 status must block G2")

        if row.get("blocks_G2") == "yes":
            if row.get("missing_gate") in {"", "NONE"}:
                errors.append(f"{key}: blocks G2 without an exact missing_gate")
            ticket = row.get("ticket", "")
            if not re.fullmatch(r"G1-[A-Z]+(?:-[A-Z]+)*-\d+", ticket):
                errors.append(f"{key}: requires exact blocking ticket, got {ticket!r}")
            elif ticket not in ticket_ids:
                errors.append(f"{key}: blocking ticket {ticket} is not registered")

        if row.get("p0_loops") in {"", "NONE"}:
            errors.append(f"{key}: missing P0 loop ownership")
    return errors


def _ticket_registry() -> tuple[list[str], list[dict[str, str]]]:
    assert TICKET_REGISTRY.is_file(), (
        "G1 blocking ticket registry is missing; baseline debt is not actionable"
    )
    return _parse_table(TICKET_REGISTRY, "## Blocking tickets")


def test_g1_p0_canonical_matrix_is_non_vacuous_and_fail_closed() -> None:
    ticket_headers, ticket_rows = _ticket_registry()
    assert ticket_headers == TICKET_COLUMNS
    ticket_ids = {row["ticket_id"] for row in ticket_rows}
    headers, rows = _parse_table(LEDGER_MATRIX, "## G1_P0_CANONICAL_KEYS")

    errors = _matrix_errors(headers, rows, ticket_ids)

    assert errors == []


def test_phase37_typed_fields_keep_real_consumers_and_quarantine_dead_fact() -> None:
    """Live typed facts need real readers; quarantined facts must not fake one.

    A field declaration, JSON serializer, or ``fromWizardAnswers`` assignment
    is not a consumer.  Pin each matrix row to the production method that uses
    the fact while allowing line numbers to move as the implementation evolves.
    Keep the declared AVS-gap fact separate from certified gap-year evidence.
    """

    _, rows = _parse_table(LEDGER_MATRIX, "## G1_P0_CANONICAL_KEYS")
    rows_by_key = {row["canonical_key"]: row for row in rows}
    expected = {
        "pillar3aAnnual": (
            "pillar3aAnnualContribution",
            "apps/mobile/lib/services/financial_fitness_service.dart"
            "#FinancialFitnessService._calculatePrevoyance"
            "@pillar3aAnnualContribution",
        ),
        "savingsMonthly": (
            "monthlySavingsContribution",
            "apps/mobile/lib/services/financial_fitness_service.dart"
            "#FinancialFitnessService._calculateBudget"
            "@monthlySavingsContribution",
        ),
    }

    assert expected.keys() <= rows_by_key.keys()
    for key, (token, expected_evidence) in expected.items():
        row = rows_by_key[key]
        assert row["coach_profile_path"] == token, key
        assert row["status"] in LIVE_STATUSES, key
        assert row["reader_evidence"] == expected_evidence, key
        assert _reader_evidence_errors(row) == [], key

    has_avs_gaps = rows_by_key["hasAvsGaps"]
    assert has_avs_gaps["storage_key"] == "q_avs_lacunes_status"
    assert has_avs_gaps["coach_profile_path"] == "avsGapStatus"
    assert has_avs_gaps["write_path"] == "applySaveFact,mergeAnswers,scan_confirm"
    assert has_avs_gaps["status"] == "quarantined"
    assert has_avs_gaps["reader_evidence"] == "NONE"
    assert has_avs_gaps["consumers"] == "NONE"
    assert "typed_consumer" in has_avs_gaps["missing_gate"].split(",")

    forged_reader = copy.deepcopy(has_avs_gaps)
    forged_reader["reader_evidence"] = (
        "apps/mobile/lib/services/financial_fitness_service.dart"
        "#FinancialFitnessService._calculatePrevoyance@avsGapStatus"
    )
    forged_reader["consumers"] = "AVS_unknown_score_gate"
    errors = _matrix_errors(
        MATRIX_COLUMNS,
        [forged_reader],
        ticket_ids={"G1-LDG-06"},
    )
    assert any("hasAvsGaps: quarantine contract drifted" in error for error in errors)


def _semantic_reader_row(evidence: str) -> dict[str, str]:
    return {
        "canonical_key": "monthlyExpenses",
        "storage_key": "q_monthly_expenses",
        "coach_profile_path": "userProvidedFields.monthlyExpenses",
        "classification": "completion_marker",
        "reader_evidence": evidence,
    }


def test_semantic_reader_anchor_survives_unrelated_line_insertions(
    tmp_path: Path,
) -> None:
    source_path = tmp_path / "lib/consumer.dart"
    source_path.parent.mkdir(parents=True)
    source = """
import 'package:mint_mobile/models/coach_profile.dart';

class SampleConsumer {
  double compute(CoachProfile profile) {
    return profile.userProvidedFields.monthlyExpenses;
  }
}
"""
    source_path.write_text(source, encoding="utf-8")
    row = _semantic_reader_row(
        "lib/consumer.dart#SampleConsumer.compute@monthlyExpenses"
    )

    assert _reader_evidence_errors(row, root=tmp_path) == []

    source_path.write_text(("// unrelated insertion\n" * 200) + source, encoding="utf-8")

    assert _reader_evidence_errors(row, root=tmp_path) == []


def test_semantic_reader_anchor_rejects_missing_symbol_and_out_of_scope_read(
    tmp_path: Path,
) -> None:
    source_path = tmp_path / "lib/consumer.dart"
    source_path.parent.mkdir(parents=True)
    source_path.write_text(
        """
import 'package:mint_mobile/models/coach_profile.dart';

class SampleConsumer {
  double compute(CoachProfile profile) => 0;

  double other(CoachProfile profile) =>
      profile.userProvidedFields.monthlyExpenses;

  double labelled(CoachProfile profile) {
    print('monthlyExpenses');
    return 0;
  }

  double commented(CoachProfile profile) {
    // monthlyExpenses is documentation, not a read.
    return 0;
  }

  double misleading(CoachProfile profile) {
    notcontains('monthlyExpenses');
    return 0;
  }

  bool completionMarker(CoachProfile profile) =>
      profile.userProvidedFields.contains('monthlyExpenses');
}
""",
        encoding="utf-8",
    )
    anchors = {
        "missing class": "lib/consumer.dart#MissingConsumer.compute@monthlyExpenses",
        "missing member": "lib/consumer.dart#SampleConsumer.missing@monthlyExpenses",
        "contains none": "lib/consumer.dart#SampleConsumer.compute@monthlyExpenses",
        "contains none in unrelated label": (
            "lib/consumer.dart#SampleConsumer.labelled@monthlyExpenses"
        ),
        "contains none in comment": (
            "lib/consumer.dart#SampleConsumer.commented@monthlyExpenses"
        ),
        "contains none in similarly named call": (
            "lib/consumer.dart#SampleConsumer.misleading@monthlyExpenses"
        ),
    }

    for expected_error, evidence in anchors.items():
        errors = _reader_evidence_errors(
            _semantic_reader_row(evidence), root=tmp_path
        )
        marker = (
            "contains no profile-typed receiver access"
            if expected_error.startswith("contains none")
            else expected_error
        )
        assert any(marker in error for error in errors), (evidence, errors)

    marker_row = _semantic_reader_row(
        "lib/consumer.dart#SampleConsumer.completionMarker@monthlyExpenses"
    )
    assert _reader_evidence_errors(marker_row, root=tmp_path) == []


def test_semantic_reader_anchor_requires_qualified_ledger_access(
    tmp_path: Path,
) -> None:
    source_path = tmp_path / "lib/consumer.dart"
    source_path.parent.mkdir(parents=True)
    source_path.write_text(
        """
import 'package:mint_mobile/models/coach_profile.dart';

class SampleConsumer {
  double qualified(CoachProfile profile) =>
      profile.userProvidedFields.monthlyExpenses;

  double localShadow(CoachProfile profile) {
    final monthlyExpenses = 42.0;
    return monthlyExpenses;
  }

  double parameterShadow(CoachProfile profile, double monthlyExpenses) =>
      monthlyExpenses;
}
""",
        encoding="utf-8",
    )

    qualified = _semantic_reader_row(
        "lib/consumer.dart#SampleConsumer.qualified@monthlyExpenses"
    )
    assert _reader_evidence_errors(qualified, root=tmp_path) == []

    for member in ("localShadow", "parameterShadow"):
        row = _semantic_reader_row(
            f"lib/consumer.dart#SampleConsumer.{member}@monthlyExpenses"
        )
        errors = _reader_evidence_errors(row, root=tmp_path)
        assert any("profile-typed receiver access" in error for error in errors), (
            member,
            errors,
        )


def test_semantic_reader_anchor_rejects_arbitrary_qualified_receivers(
    tmp_path: Path,
) -> None:
    source_path = tmp_path / "lib/consumer.dart"
    source_path.parent.mkdir(parents=True)
    source_path.write_text(
        """
class SampleConsumer {
  double fakeMarker(Impostor impostor) =>
      impostor.userProvidedFields.monthlyExpenses;

  int fakeBirthYear(Unrelated unrelated) => unrelated.birthYear;

  bool fakePillar(Impostor impostor) =>
      impostor.prevoyance.hasPensionFund;
}
""",
        encoding="utf-8",
    )

    rows = (
        _semantic_reader_row(
            "lib/consumer.dart#SampleConsumer.fakeMarker@monthlyExpenses"
        ),
        {
            "canonical_key": "birthYear",
            "storage_key": "q_birth_year",
            "coach_profile_path": "birthYear",
            "classification": "fact",
            "reader_evidence": (
                "lib/consumer.dart#SampleConsumer.fakeBirthYear@birthYear"
            ),
        },
        {
            "canonical_key": "has2ndPillar",
            "storage_key": "q_has_pension_fund",
            "coach_profile_path": "prevoyance.hasPensionFund",
            "classification": "fact",
            "reader_evidence": (
                "lib/consumer.dart#SampleConsumer.fakePillar@hasPensionFund"
            ),
        },
    )

    for row in rows:
        errors = _reader_evidence_errors(row, root=tmp_path)
        assert any("profile-typed receiver" in error for error in errors), (
            row,
            errors,
        )


def test_semantic_reader_anchor_supports_generic_consumer_members(
    tmp_path: Path,
) -> None:
    source_path = tmp_path / "lib/consumer.dart"
    source_path.parent.mkdir(parents=True)
    source_path.write_text(
        """
import 'package:mint_mobile/models/coach_profile.dart';

class SampleConsumer {
  T compute<T extends num>(CoachProfile profile, T fallback) {
    final value = profile.userProvidedFields.monthlyExpenses;
    return value is T ? value : fallback;
  }
}
""",
        encoding="utf-8",
    )
    row = _semantic_reader_row(
        "lib/consumer.dart#SampleConsumer.compute@monthlyExpenses"
    )

    assert _reader_evidence_errors(row, root=tmp_path) == []


def test_semantic_reader_anchor_rejects_forged_canonical_receivers(
    tmp_path: Path,
) -> None:
    source_path = tmp_path / "lib/consumer.dart"
    source_path.parent.mkdir(parents=True)
    model = "import 'package:mint_mobile/models/coach_profile.dart';\n"
    provider = (
        "import 'package:mint_mobile/providers/coach_profile_provider.dart';\n"
    )
    provider_runtime = (
        "import 'package:flutter/material.dart';\n"
        "import 'package:provider/provider.dart';\n"
    )
    marker_row = _semantic_reader_row(
        "lib/consumer.dart#SampleConsumer.compute@monthlyExpenses"
    )
    pillar_row = {
        **marker_row,
        "canonical_key": "has2ndPillar",
        "coach_profile_path": "prevoyance.hasPensionFund",
        "reader_evidence": "lib/consumer.dart#SampleConsumer.compute@hasPensionFund",
    }
    consumer = (
        "class SampleConsumer { double compute(CoachProfile profile) => "
        "profile.userProvidedFields.monthlyExpenses; }"
    )
    probes = {
        "unimported type": (consumer, marker_row),
        "local type shadow": (
            model + "class CoachProfile {}\n" + consumer,
            marker_row,
        ),
        "dynamic generic factory": (
            model + provider + "dynamic fake<T>() => FakeProvider();\n"
            "class SampleConsumer { double compute() { final profile = "
            "fake<CoachProfileProvider>().profile; return "
            "profile.userProvidedFields.monthlyExpenses; } }",
            marker_row,
        ),
        "untyped fake context": (
            provider_runtime + model + provider
            + "class FakeContext { dynamic read<T>() => FakeProvider(); }\n"
            "class SampleConsumer extends State<StatefulWidget> { double compute() { "
            "final context = FakeContext(); final profile = "
            "context.read<CoachProfileProvider>().profile; return "
            "profile.userProvidedFields.monthlyExpenses; } }",
            marker_row,
        ),
        "local Provider shadow": (
            provider_runtime + model + provider
            + "class Provider { static dynamic of<T>(BuildContext context) => "
            "FakeProvider(); }\nclass SampleConsumer { double compute(BuildContext "
            "context) { final profile = Provider.of<CoachProfileProvider>(context)"
            ".profile; return profile.userProvidedFields.monthlyExpenses; } }",
            marker_row,
        ),
        "detached subledger": (
            model + "class SampleConsumer { bool compute(PrevoyanceProfile "
            "prevoyance) => prevoyance.hasPensionFund; }",
            pillar_row,
        ),
    }

    for label, (source, row) in probes.items():
        source_path.write_text(source, encoding="utf-8")
        errors = _reader_evidence_errors(row, root=tmp_path)
        assert any("profile-typed receiver" in error for error in errors), (
            label,
            errors,
        )


def test_semantic_reader_anchor_accepts_canonical_provider_and_derived_subledger(
    tmp_path: Path,
) -> None:
    source_path = tmp_path / "lib/consumer.dart"
    source_path.parent.mkdir(parents=True)
    source_path.write_text(
        "import 'package:flutter/material.dart';\n"
        "import 'package:provider/provider.dart';\n"
        "import 'package:mint_mobile/models/coach_profile.dart';\n"
        "import 'package:mint_mobile/providers/coach_profile_provider.dart';\n"
        "class SampleConsumer extends State<StatefulWidget> { bool compute() { "
        "final profile = context.read<CoachProfileProvider>().profile; final "
        "prevoyance = profile!.prevoyance; return prevoyance.hasPensionFund; } }",
        encoding="utf-8",
    )
    row = {
        "canonical_key": "has2ndPillar",
        "storage_key": "q_has_pension_fund",
        "coach_profile_path": "prevoyance.hasPensionFund",
        "classification": "fact",
        "reader_evidence": (
            "lib/consumer.dart#SampleConsumer.compute@hasPensionFund"
        ),
    }

    assert _reader_evidence_errors(row, root=tmp_path) == []


def test_live_non_p0_row_cannot_drop_reader_or_consumer_edges() -> None:
    _, rows = _parse_table(LEDGER_MATRIX, "## G1_P0_CANONICAL_KEYS")
    has3a = copy.deepcopy(
        next(row for row in rows if row["canonical_key"] == "has3a")
    )
    assert has3a["tier"] == "P1"
    assert has3a["status"] == "quarantined"
    assert has3a["reader_evidence"] == "NONE"
    assert has3a["consumers"] == "NONE"

    has3a["status"] = "live"
    errors = _matrix_errors(MATRIX_COLUMNS, [has3a], ticket_ids=set())

    assert any("silent dead P1 live key" in error for error in errors), errors
    assert any("has3a: quarantine contract drifted" in error for error in errors)

    has3a = copy.deepcopy(
        next(row for row in rows if row["canonical_key"] == "has3a")
    )
    has3a["missing_gate"] = "semantic_roundtrip,provenance_on_write"
    errors = _matrix_errors(MATRIX_COLUMNS, [has3a], ticket_ids=set())

    assert any("has3a: quarantine contract drifted" in error for error in errors)
    assert any("typed_consumer in missing_gate" in error for error in errors)


def test_semantic_reader_anchor_rejects_named_and_factory_constructors(
    tmp_path: Path,
) -> None:
    source_path = tmp_path / "lib/consumer.dart"
    source_path.parent.mkdir(parents=True)
    source_path.write_text(
        """
class SampleConsumer {
  final double value;

  SampleConsumer.named(CoachProfile profile)
      : value = profile.userProvidedFields.monthlyExpenses;

  factory SampleConsumer.fromProfile(CoachProfile profile) => SampleConsumer.raw(
        profile.userProvidedFields.monthlyExpenses,
      );

  SampleConsumer.raw(this.value);
}
""",
        encoding="utf-8",
    )

    for member in ("named", "fromProfile"):
        row = _semantic_reader_row(
            f"lib/consumer.dart#SampleConsumer.{member}@monthlyExpenses"
        )
        errors = _reader_evidence_errors(row, root=tmp_path)
        assert any("constructor" in error for error in errors), (member, errors)


def test_semantic_reader_anchor_rejects_reconstruction_and_declaration(
    tmp_path: Path,
) -> None:
    source_path = tmp_path / "lib/coach_profile.dart"
    source_path.parent.mkdir(parents=True)
    source_path.write_text(
        """
class CoachProfile {
  final double monthlyExpenses;

  CoachProfile(this.monthlyExpenses);

  factory CoachProfile.fromWizardAnswers(Map<String, dynamic> answers) =>
      CoachProfile(answers['monthlyExpenses']);

  factory CoachProfile.fromJson(Map<String, dynamic> json) =>
      CoachProfile(json['monthlyExpenses']);

  Map<String, dynamic> toJson() =>
      {'monthlyExpenses': monthlyExpenses};

  CoachProfile copyWith({double? monthlyExpenses}) =>
      CoachProfile(monthlyExpenses ?? this.monthlyExpenses);
}
""",
        encoding="utf-8",
    )
    for member in (
        "fromWizardAnswers",
        "fromJson",
        "toJson",
        "copyWith",
        "monthlyExpenses",
    ):
        evidence = (
            f"lib/coach_profile.dart#CoachProfile.{member}@monthlyExpenses"
        )
        errors = _reader_evidence_errors(
            _semantic_reader_row(evidence), root=tmp_path
        )
        assert errors, member
        assert any(
            marker in error
            for error in errors
            for marker in ("forbidden", "declaration is not a consumer")
        ), (member, errors)


def test_every_matrix_ticket_has_an_executable_blocking_contract() -> None:
    headers, tickets = _ticket_registry()
    assert headers == TICKET_COLUMNS

    counts = Counter(ticket["ticket_id"] for ticket in tickets)
    assert all(count == 1 for count in counts.values()), counts
    assert _ticket_ids_declared_by_matrices() <= set(counts)

    for ticket in tickets:
        ticket_id = ticket["ticket_id"]
        assert ticket["blocks_G2"] == "yes", ticket_id
        for field in (
            "gate_name",
            "owner",
            "target_files",
            "failing_predicate",
            "fixture_input",
            "red_command",
            "green_command",
            "blocked_P0_loops",
            "planned_implementation_slice",
        ):
            value = ticket[field]
            assert value not in {"", "NONE", "TBD", "TODO"}, f"{ticket_id}: {field}"
        assert len(ticket["failing_predicate"]) >= 24, ticket_id

    gate_names = {ticket["gate_name"] for ticket in tickets}
    assert REQUIRED_GATE_NAMES <= gate_names

    evidence_index = _json(TICKET_EVIDENCE_INDEX)
    assert set(evidence_index) == {"schema_version", "phase", "tickets"}
    assert evidence_index["schema_version"] == 1
    assert evidence_index["phase"] == 37
    evidence_errors = _registry_evidence_errors(
        tickets,
        evidence_index["tickets"],
        root=ROOT,
        require_complete=True,
    )
    assert evidence_errors == []


def test_active_g1_acceptance_docs_match_live_ticket_count() -> None:
    _, tickets = _ticket_registry()
    expected_total = len(tickets)
    assert expected_total == len(_json(TICKET_EVIDENCE_INDEX)["tickets"])

    stale_markers = ("23/23", "all 23 G1", "23 G1 blockers", "23 G1 tickets")
    for path in ACTIVE_G1_COUNT_DOCS:
        text = path.read_text(encoding="utf-8")
        current_markers = (
            f"{expected_total}/{expected_total}",
            f"{expected_total} G1",
            f"{expected_total} rows",
        )
        assert any(marker in text for marker in current_markers), path
        assert not any(marker in text for marker in stale_markers), path


def test_negative_fixture_proves_duplicate_silent_dead_and_missing_ticket() -> None:
    headers, rows = _parse_table(NEGATIVE_FIXTURE, "## G1_P0_CANONICAL_KEYS")

    errors = _matrix_errors(headers, rows, ticket_ids=set())

    assert any("duplicate canonical_key: duplicateKey" in error for error in errors)
    assert any("silent dead P0 live key" in error for error in errors)
    assert any("requires exact blocking ticket" in error for error in errors)
    assert any("reader evidence file does not exist" in error for error in errors)
    assert any("missing member" in error for error in errors)
    assert any("contains no profile-typed receiver access" in error for error in errors)
    assert any("unsupported classification 'banana'" in error for error in errors)
    assert any(
        "completion_marker classification requires completion_marker type_unit"
        in error
        for error in errors
    )


def _materialize_fixture_artifacts(root: Path, artifacts: dict[str, Any]) -> None:
    for relative_path, payload in artifacts.items():
        path = root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(payload, (dict, list)):
            path.write_text(
                json.dumps(payload, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
        else:
            path.write_text(str(payload), encoding="utf-8")


def _ticket_by_id(ticket_id: str) -> dict[str, str]:
    _, tickets = _ticket_registry()
    return next(ticket for ticket in tickets if ticket["ticket_id"] == ticket_id)


def test_progressive_red_proven_fixture_is_rejected_only_by_old_registry_rule(
    tmp_path: Path,
) -> None:
    fixture = _replace_fixture_tokens(
        _json(TICKET_EVIDENCE_NEGATIVE_FIXTURE), head_sha=_head_sha()
    )["valid_progressive"]
    _materialize_fixture_artifacts(tmp_path, fixture["artifacts"])
    ticket = copy.deepcopy(_ticket_by_id(fixture["record"]["ticket_id"]))
    ticket["status"] = "red_proven"

    errors = _registry_evidence_errors(
        [ticket], [fixture["record"]], root=tmp_path, require_complete=True
    )

    assert errors == []


def test_both_green_evidence_modes_are_strict_and_non_vacuous(tmp_path: Path) -> None:
    fixture = _replace_fixture_tokens(
        _json(TICKET_EVIDENCE_NEGATIVE_FIXTURE), head_sha=_head_sha()
    )
    for fixture_name in ("valid_red_green", "valid_baseline_green_controlled"):
        candidate = fixture[fixture_name]
        _materialize_fixture_artifacts(tmp_path, candidate["artifacts"])
        ticket = _ticket_by_id(candidate["record"]["ticket_id"])

        errors = _ticket_record_errors(
            candidate["record"], ticket=ticket, root=tmp_path
        )

        assert errors == [], (fixture_name, errors)


def test_ticket_evidence_negative_cases_fail_for_their_named_reason(
    tmp_path: Path,
) -> None:
    fixture = _replace_fixture_tokens(
        _json(TICKET_EVIDENCE_NEGATIVE_FIXTURE), head_sha=_head_sha()
    )
    base = fixture["valid_progressive"]
    for case in fixture["negative_cases"]:
        candidate = _mutated_candidate(base, case["operations"])
        _materialize_fixture_artifacts(tmp_path, candidate["artifacts"])
        ticket = copy.deepcopy(_ticket_by_id("G1-SOURCE-01"))
        ticket["status"] = case.get("registry_status", "red_proven")
        records = [candidate["record"]]
        if case.get("duplicate_record"):
            records.append(copy.deepcopy(candidate["record"]))

        errors = _registry_evidence_errors(
            [ticket], records, root=tmp_path, require_complete=False
        )

        assert any(case["expected_error"] in error for error in errors), (
            case["name"],
            errors,
        )


def test_valid_wave_and_final_audit_manifests_are_accepted(tmp_path: Path) -> None:
    fixture = _replace_fixture_tokens(
        _json(AUDIT_MANIFEST_NEGATIVE_FIXTURE), head_sha=_head_sha()
    )["valid"]
    _materialize_fixture_artifacts(tmp_path, fixture["artifacts"])

    wave_errors = _audit_manifest_errors(
        fixture["manifest"],
        root=tmp_path,
        expected_required_modes={"code", "product-domain"},
    )

    final_candidate = copy.deepcopy(fixture)
    architecture_run = copy.deepcopy(final_candidate["manifest"]["runs"][0])
    architecture_run.update(
        {
            "command": "tools/checks/claude_external_audit.sh architecture",
            "mode": "architecture",
            "output_artifact": ".planning/runtime-evidence/phase-37/fixture/audit-architecture.md",
        }
    )
    final_candidate["manifest"]["required_modes"].append("architecture")
    final_candidate["manifest"]["runs"].append(architecture_run)
    final_candidate["artifacts"][architecture_run["output_artifact"]] = (
        "PASS\nNo P0/P1 architecture findings.\n"
    )
    _materialize_fixture_artifacts(tmp_path, final_candidate["artifacts"])
    final_errors = _audit_manifest_errors(
        final_candidate["manifest"],
        root=tmp_path,
        expected_required_modes={"code", "product-domain", "architecture"},
    )

    assert wave_errors == []
    assert final_errors == []


def test_audit_manifest_negative_cases_fail_for_their_named_reason(
    tmp_path: Path,
) -> None:
    fixture = _replace_fixture_tokens(
        _json(AUDIT_MANIFEST_NEGATIVE_FIXTURE), head_sha=_head_sha()
    )
    base = fixture["valid"]
    for case in fixture["negative_cases"]:
        candidate = _mutated_candidate(base, case["operations"])
        _materialize_fixture_artifacts(tmp_path, candidate["artifacts"])

        errors = _audit_manifest_errors(
            candidate["manifest"],
            root=tmp_path,
            expected_required_modes={"code", "product-domain"},
        )

        assert any(case["expected_error"] in error for error in errors), (
            case["name"],
            errors,
        )
