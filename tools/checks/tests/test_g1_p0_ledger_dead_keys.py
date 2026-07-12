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
    r"(?P<path>[A-Za-z0-9_./-]+\.dart):(?P<line>[1-9][0-9]*)"
)
READER_WINDOW_RADIUS = 5
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
    tokens.add(profile_path.rsplit(".", maxsplit=1)[-1])

    return {token for token in tokens if token not in {"", "NONE"} and len(token) >= 3}


def _reader_evidence_errors(row: dict[str, str]) -> list[str]:
    key = row.get("canonical_key", "<unknown>")
    evidence = row.get("reader_evidence", "")
    match = READER_EVIDENCE_RE.fullmatch(evidence)
    if match is None:
        return [f"{key}: reader evidence must be exact repo/path.dart:line"]

    relative_path = Path(match.group("path"))
    if relative_path.is_absolute() or ".." in relative_path.parts:
        return [f"{key}: reader evidence path must stay repo-relative"]

    source_path = (ROOT / relative_path).resolve()
    try:
        source_path.relative_to(ROOT.resolve())
    except ValueError:
        return [f"{key}: reader evidence path escapes repository"]
    if not source_path.is_file():
        return [f"{key}: reader evidence file does not exist: {relative_path}"]

    lines = source_path.read_text(encoding="utf-8").splitlines()
    line_number = int(match.group("line"))
    if line_number > len(lines):
        return [
            f"{key}: reader evidence line {line_number} exceeds "
            f"{relative_path} length {len(lines)}"
        ]

    center = line_number - 1
    start = max(0, center - READER_WINDOW_RADIUS)
    end = min(len(lines), center + READER_WINDOW_RADIUS + 1)
    window = "\n".join(lines[start:end])
    tokens = _semantic_reader_tokens(row)
    if not any(token in window for token in tokens):
        return [
            f"{key}: reader evidence window {relative_path}:{start + 1}-{end} "
            f"contains none of the row-derived semantic tokens {sorted(tokens)}"
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
        if row.get("tier") != "P0":
            continue

        status = row.get("status", "")
        if status not in LIVE_STATUSES | NON_LIVE_STATUSES:
            errors.append(f"{key}: unsupported P0 status {status!r}")

        missing_edges = [
            column
            for column in ("write_path", "reader_evidence", "consumers")
            if row.get(column) in {"", "NONE"}
        ]
        if status in LIVE_STATUSES and missing_edges:
            errors.append(
                f"{key}: silent dead P0 {status} key missing "
                + ",".join(missing_edges)
            )
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


def test_phase37_typed_fields_point_to_real_production_consumers() -> None:
    """The Phase 37 typed facts must be read outside model reconstruction.

    A field declaration, JSON serializer, or ``fromWizardAnswers`` assignment
    is not a consumer.  Pin each matrix row to the production method that uses
    the fact while allowing line numbers to move as the implementation evolves.
    """

    _, rows = _parse_table(LEDGER_MATRIX, "## G1_P0_CANONICAL_KEYS")
    rows_by_key = {row["canonical_key"]: row for row in rows}
    expected = {
        "pillar3aAnnual": (
            "pillar3aAnnualContribution",
            Path("apps/mobile/lib/services/financial_fitness_service.dart"),
            "static SubScore _calculatePrevoyance",
            "static SubScore _calculatePatrimoine",
        ),
        "savingsMonthly": (
            "monthlySavingsContribution",
            Path("apps/mobile/lib/services/financial_fitness_service.dart"),
            "static SubScore _calculateBudget",
            "static SubScore _calculatePrevoyance",
        ),
        "has3a": (
            "hasPillar3a",
            Path("apps/mobile/lib/models/coach_profile.dart"),
            "CoachingProfile toCoachingProfile",
            "factory CoachProfile.fromJson",
        ),
        "hasAvsGaps": (
            "avsGapStatus",
            Path("apps/mobile/lib/services/financial_fitness_service.dart"),
            "static SubScore _calculatePrevoyance",
            "static SubScore _calculatePatrimoine",
        ),
    }

    assert expected.keys() <= rows_by_key.keys()
    for key, (token, expected_path, section_start, section_end) in expected.items():
        row = rows_by_key[key]
        assert row["coach_profile_path"] == token, key

        match = READER_EVIDENCE_RE.fullmatch(row["reader_evidence"])
        assert match is not None, key
        assert Path(match.group("path")) == expected_path, key

        source = (ROOT / expected_path).read_text(encoding="utf-8")
        lines = source.splitlines()
        line_number = int(match.group("line"))
        assert 1 <= line_number <= len(lines), key

        start_line = next(
            index
            for index, line in enumerate(lines, start=1)
            if section_start in line
        )
        end_line = next(
            index
            for index, line in enumerate(lines, start=1)
            if index > start_line and section_end in line
        )
        assert start_line < line_number < end_line, (
            f"{key}: reader evidence must be inside {section_start}, "
            "not a declaration/factory/serializer"
        )

        center = line_number - 1
        window_start = max(0, center - READER_WINDOW_RADIUS)
        window_end = min(len(lines), center + READER_WINDOW_RADIUS + 1)
        window = "\n".join(lines[window_start:window_end])
        assert token in window, (
            f"{key}: {row['reader_evidence']} does not prove a read of {token}"
        )


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


def test_negative_fixture_proves_duplicate_silent_dead_and_missing_ticket() -> None:
    headers, rows = _parse_table(NEGATIVE_FIXTURE, "## G1_P0_CANONICAL_KEYS")

    errors = _matrix_errors(headers, rows, ticket_ids=set())

    assert any("duplicate canonical_key: duplicateKey" in error for error in errors)
    assert any("silent dead P0 live key" in error for error in errors)
    assert any("requires exact blocking ticket" in error for error in errors)
    assert any("reader evidence file does not exist" in error for error in errors)
    assert any("reader evidence line 999999 exceeds" in error for error in errors)
    assert any("contains none of the row-derived semantic tokens" in error for error in errors)


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
