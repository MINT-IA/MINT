import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
LEDGER_MATRIX = ROOT / ".planning/goals/G1-ledger-gap-matrix.md"
PROVIDER_MATRIX = ROOT / ".planning/goals/G1-provider-boundary.md"
TICKET_REGISTRY = ROOT / ".planning/goals/G1-blocking-gate-tickets.md"
NEGATIVE_FIXTURE = (
    ROOT / "tools/checks/fixtures/g1_p0_ledger_dead_keys_negative.md"
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


def test_every_matrix_ticket_has_an_executable_blocking_contract() -> None:
    headers, tickets = _ticket_registry()
    assert headers == TICKET_COLUMNS

    counts = Counter(ticket["ticket_id"] for ticket in tickets)
    assert all(count == 1 for count in counts.values()), counts
    assert _ticket_ids_declared_by_matrices() <= set(counts)

    for ticket in tickets:
        ticket_id = ticket["ticket_id"]
        assert ticket["blocks_G2"] == "yes", ticket_id
        assert ticket["status"] == "ticket_only", ticket_id
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


def test_negative_fixture_proves_duplicate_silent_dead_and_missing_ticket() -> None:
    headers, rows = _parse_table(NEGATIVE_FIXTURE, "## G1_P0_CANONICAL_KEYS")

    errors = _matrix_errors(headers, rows, ticket_ids=set())

    assert any("duplicate canonical_key: duplicateKey" in error for error in errors)
    assert any("silent dead P0 live key" in error for error in errors)
    assert any("requires exact blocking ticket" in error for error in errors)
    assert any("reader evidence file does not exist" in error for error in errors)
    assert any("reader evidence line 999999 exceeds" in error for error in errors)
    assert any("contains none of the row-derived semantic tokens" in error for error in errors)
