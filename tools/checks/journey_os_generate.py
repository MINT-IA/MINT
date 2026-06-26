#!/usr/bin/env python3
"""Generate Journey OS Markdown and Mermaid views from JSON records."""
from __future__ import annotations

import argparse, json, re
from pathlib import Path
from typing import Any

JOURNEYS = Path(".planning/journeys")
RECORDS = JOURNEYS / "records"
SUMMARY = JOURNEYS / "JOURNEYS.md"
DIAGRAMS = JOURNEYS / "diagrams"
PRIORITY_POSITIVE = {"trust_blast_radius", "release_blocker_weight", "user_frequency", "evidence_gap", "route_centrality", "compliance_risk", "learning_value"}

def load_records(root: Path) -> list[dict[str, Any]]:
    return [json.loads(path.read_text(encoding="utf-8")) for path in sorted((root / RECORDS).glob("*.json"))]

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
    out = {SUMMARY: markdown(records)}
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
