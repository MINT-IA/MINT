#!/usr/bin/env python3
"""Generate Journey OS Markdown and Mermaid views from JSON records."""
from __future__ import annotations

import argparse, json, re
from pathlib import Path
from typing import Any

JOURNEYS = Path(".planning/journeys")
RECORDS = JOURNEYS / "records"
ISSUES = JOURNEYS / "issues"
SUMMARY = JOURNEYS / "JOURNEYS.md"
BOARD = JOURNEYS / "BOARD.md"
DIAGRAMS = JOURNEYS / "diagrams"
PRIORITY_POSITIVE = {"trust_blast_radius", "release_blocker_weight", "user_frequency", "evidence_gap", "route_centrality", "compliance_risk", "learning_value"}

def load_records(root: Path) -> list[dict[str, Any]]:
    return [json.loads(path.read_text(encoding="utf-8")) for path in sorted((root / RECORDS).glob("*.json"))]

def load_issues(root: Path) -> list[dict[str, Any]]:
    return [json.loads(path.read_text(encoding="utf-8")) for path in sorted((root / ISSUES).glob("*.json"))]

def _cell(value: object) -> str:
    text = ", ".join(value) if isinstance(value, list) else str(value)
    return text.replace("|", "\\|")

def priority_score(rec: dict[str, Any]) -> str:
    priority = rec.get("priority")
    if not isinstance(priority, dict):
        return ""
    try:
        return str(sum(int(priority.get(key, 0)) for key in PRIORITY_POSITIVE) - int(priority.get("proof_cost", 0)))
    except (TypeError, ValueError):
        return ""

def markdown(records: list[dict[str, Any]]) -> str:
    lines = ["# Mint Journey OS", "", "Generated from `.planning/journeys/records/*.json`. Do not edit directly.", "", "| ID | Tier | Priority | Status | Promise | Accountable team | Routes | Evidence |", "|---|---:|---:|---|---|---|---|---|"]
    for rec in records:
        statuses = sorted({str(e.get("status")) for e in rec.get("evidence", []) if isinstance(e, dict)})
        lines.append("| {id} | {tier} | {priority} | {status} | {promise} | {team} | {routes} | {evidence} |".format(id=_cell(rec.get("id", "")), tier=_cell(rec.get("tier", "")), priority=priority_score(rec), status=_cell(rec.get("status", "")), promise=_cell(rec.get("human_promise", "")), team=_cell(rec.get("accountable_team", "")), routes=_cell(rec.get("route_paths", [])), evidence=_cell(statuses)))
    return "\n".join(lines) + "\n"

def board(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> str:
    by_id = {str(rec.get("id")): rec for rec in records}
    severity_rank = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
    ranked = sorted(
        issues,
        key=lambda issue: (
            0 if issue.get("evidence_status") in {"missing", "red"} else 1,
            severity_rank.get(str(issue.get("severity")), 9),
            -int(priority_score(by_id.get(str(issue.get("journey_id")), {})) or 0),
            str(issue.get("id", "")),
        ),
    )
    lines = [
        "# Next Journey OS Work",
        "",
        "Generated from `.planning/journeys/issues/*.json`. Do not edit directly.",
        "",
        "| Issue | Severity | Status | Journey | Journey priority | Owner | Evidence | Next action |",
        "|---|---|---|---|---:|---|---|---|",
    ]
    for issue in ranked:
        journey = by_id.get(str(issue.get("journey_id")), {})
        lines.append("| {id} | {severity} | {status} | {journey} | {priority} | {owner} | {evidence} | {action} |".format(
            id=_cell(issue.get("id", "")),
            severity=_cell(issue.get("severity", "")),
            status=_cell(issue.get("status", "")),
            journey=_cell(issue.get("journey_id", "")),
            priority=priority_score(journey),
            owner=_cell(issue.get("owner", "")),
            evidence=_cell(issue.get("evidence_status", "")),
            action=_cell(issue.get("next_action", "")),
        ))
    return "\n".join(lines) + "\n"

def _node(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]+", "_", value).strip("_") or "root"

def _label(value: object) -> str:
    return str(value).replace('"', "'").replace("\n", " ")

def mermaid(rec: dict[str, Any]) -> str:
    rid = str(rec["id"])
    lines = [f"%% Generated from .planning/journeys/records/{rid}.json", "flowchart TD", f'  promise["{_label(rec["human_promise"])}"]', f'  team["{_label(rec["accountable_team"])}"]']
    if priority_score(rec):
        lines += [f'  priority["priority score {priority_score(rec)}"]', "  priority --> promise"]
    for route in rec.get("route_paths", []):
        node = "route_" + _node(str(route))
        lines += [f'  {node}["{_label(route)}"]', f"  promise --> {node}", f"  {node} --> team"]
    for surface in rec.get("surfaces", []):
        node = "surface_" + _node(str(surface))
        lines += [f'  {node}["{_label(surface)}"]', f"  promise -.-> {node}"]
    return "\n".join(lines) + "\n"

def expected(root: Path) -> dict[Path, str]:
    records = load_records(root)
    issues = load_issues(root)
    out = {SUMMARY: markdown(records), BOARD: board(records, issues)}
    out.update({DIAGRAMS / f"{rec['id']}.mmd": mermaid(rec) for rec in records})
    return out

def write(root: Path) -> None:
    for rel, content in expected(root).items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    write(args.root.resolve())
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
