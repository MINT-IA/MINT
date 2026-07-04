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
TODAY = JOURNEYS / "TODAY.md"
DIAGRAMS = JOURNEYS / "diagrams"
SYSTEM_MAP = DIAGRAMS / "system_map.mmd"
PRIORITY_POSITIVE = {"trust_blast_radius", "release_blocker_weight", "user_frequency", "evidence_gap", "route_centrality", "compliance_risk", "learning_value"}
EVIDENCE_STATUS_RANK = {"red": 0, "missing": 1, "baselined": 2, "green": 3}

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

def _issues_for(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    grouped: dict[str, list[dict[str, Any]]] = {str(rec.get("id")): [] for rec in records}
    for issue in issues:
        grouped.setdefault(str(issue.get("journey_id", "")), []).append(issue)
    for items in grouped.values():
        items.sort(key=lambda item: str(item.get("id", "")))
    return grouped

def _latest_evidence(rec: dict[str, Any]) -> dict[str, Any]:
    items = [item for item in rec.get("evidence", []) if isinstance(item, dict)]
    if not items:
        return {}
    return items[-1]

def _short_commit(value: object) -> str:
    text = str(value or "")
    return text[:8] if text else ""

def _artifact(value: object) -> str:
    return str(value or "")

def _latest_summary(rec: dict[str, Any]) -> str:
    latest = _latest_evidence(rec)
    if not latest:
        return ""
    status = str(latest.get("status", ""))
    kind = str(latest.get("kind", ""))
    verified_at = str(latest.get("verified_at", ""))
    commit = _short_commit(latest.get("verified_commit"))
    parts = [part for part in (status, kind, verified_at, commit) if part]
    return " / ".join(parts)

def _ranked_issues(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_id = {str(rec.get("id")): rec for rec in records}
    severity_rank = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
    evidence_rank = {"red": 0, "missing": 1, "baselined": 2, "green": 3}
    return sorted(
        issues,
        key=lambda issue: (
            evidence_rank.get(str(issue.get("evidence_status")), 9),
            severity_rank.get(str(issue.get("severity")), 9),
            -int(priority_score(by_id.get(str(issue.get("journey_id")), {})) or 0),
            str(issue.get("id", "")),
        ),
    )

def _board_row(issue: dict[str, Any], journey: dict[str, Any]) -> str:
    latest = _latest_evidence(journey)
    return "| {id} | {severity} | {status} | {journey} | {journey_status} | {priority} | {owner} | {evidence} | {latest} | {artifact} | {action} |".format(
        id=_cell(issue.get("id", "")),
        severity=_cell(issue.get("severity", "")),
        status=_cell(issue.get("status", "")),
        journey=_cell(issue.get("journey_id", "")),
        journey_status=_cell(journey.get("status", "")),
        priority=priority_score(journey),
        owner=_cell(issue.get("owner", "")),
        evidence=_cell(issue.get("evidence_status", "")),
        latest=_cell(_latest_summary(journey)),
        artifact=_cell(_artifact(latest.get("artifact"))),
        action=_cell(issue.get("next_action", "")),
    )

def markdown(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> str:
    grouped = _issues_for(records, issues)
    lines = ["# Mint Journey OS", "", "Generated from `.planning/journeys/records/*.json`. Do not edit directly.", "", "| ID | Tier | Priority | Status | Promise | Accountable team | Routes | Issues | Evidence | Latest proof | Latest artifact |", "|---|---:|---:|---|---|---|---|---|---|---|---|"]
    for rec in records:
        statuses = sorted({str(e.get("status")) for e in rec.get("evidence", []) if isinstance(e, dict)})
        latest = _latest_evidence(rec)
        issue_labels = [
            f"{issue.get('id')}:{issue.get('status')}/{issue.get('evidence_status')}"
            for issue in grouped.get(str(rec.get("id")), [])
        ]
        lines.append("| {id} | {tier} | {priority} | {status} | {promise} | {team} | {routes} | {issues} | {evidence} | {latest} | {artifact} |".format(id=_cell(rec.get("id", "")), tier=_cell(rec.get("tier", "")), priority=priority_score(rec), status=_cell(rec.get("status", "")), promise=_cell(rec.get("human_promise", "")), team=_cell(rec.get("accountable_team", "")), routes=_cell(rec.get("route_paths", [])), issues=_cell(issue_labels), evidence=_cell(statuses), latest=_cell(_latest_summary(rec)), artifact=_cell(_artifact(latest.get("artifact")))))
    return "\n".join(lines) + "\n"

def board(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> str:
    by_id = {str(rec.get("id")): rec for rec in records}
    ranked = _ranked_issues(records, issues)
    lines = [
        "# Next Journey OS Work",
        "",
        "Generated from `.planning/journeys/issues/*.json`. Do not edit directly.",
        "",
        "| Issue | Severity | Status | Journey | Journey status | Journey priority | Owner | Evidence | Latest proof | Artifact | Next action |",
        "|---|---|---|---|---|---:|---|---|---|---|---|",
    ]
    for issue in ranked:
        journey = by_id.get(str(issue.get("journey_id")), {})
        lines.append(_board_row(issue, journey))
    return "\n".join(lines) + "\n"

def today(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> str:
    by_id = {str(rec.get("id")): rec for rec in records}
    top_issue = next(
        (
            issue for issue in _ranked_issues(records, issues)
            if issue.get("evidence_status") in {"missing", "red", "baselined"}
            or issue.get("status") in {"proof_needed", "regressed", "blocked"}
        ),
        None,
    )
    header = "| Issue | Severity | Status | Journey | Journey status | Journey priority | Owner | Evidence | Latest proof | Artifact | Next action |"
    separator = "|---|---|---|---|---|---:|---|---|---|---|---|"
    top_row = (
        _board_row(top_issue, by_id.get(str(top_issue.get("journey_id")), {}))
        if top_issue
        else "No red, missing, or baselined Journey OS issue is currently queued."
    )
    lines = [
        "# Journey OS Today",
        "",
        "Generated from Journey OS records and issues. Do not edit directly.",
        "",
        "## Top Queue Item",
        "",
        header,
        separator,
        top_row or "No Journey OS issue is currently queued.",
        "",
        "## Operating Rule",
        "",
        "Pick the highest ranked red, missing, or baselined T0 issue unless the PR explicitly names the override.",
        "",
        "## Proof Discipline",
        "",
        "A journey proof is valid only when the referenced artifact is durable, repo-relative, and accepted by `python3 tools/checks/journey_os_check.py`.",
    ]
    return "\n".join(lines) + "\n"

def _node(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]+", "_", value).strip("_") or "root"

def _label(value: object) -> str:
    return str(value).replace('"', "'").replace("\n", " ").replace("|", "/")

def _class_for(status: object) -> str:
    text = str(status or "")
    if text in {"live_proven", "verified", "green"}:
        return "green"
    if text in {"regressed", "red"}:
        return "red"
    if text in {"partial", "baselined"}:
        return "amber"
    if text in {"blocked", "missing"}:
        return "blocked"
    return "neutral"

def _class_defs() -> list[str]:
    return [
        "  classDef green fill:#e8f5e9,stroke:#1b5e20,color:#0b3d1a;",
        "  classDef red fill:#ffebee,stroke:#b71c1c,color:#5f1111;",
        "  classDef amber fill:#fff8e1,stroke:#ff8f00,color:#5f3b00;",
        "  classDef blocked fill:#eceff1,stroke:#455a64,color:#263238;",
        "  classDef neutral fill:#f5f5f5,stroke:#616161,color:#212121;",
        "  classDef route fill:#e3f2fd,stroke:#0d47a1,color:#082f66;",
        "  classDef surface fill:#f3e5f5,stroke:#4a148c,color:#2b0d52;",
        "  classDef api fill:#e0f2f1,stroke:#00695c,color:#003d35;",
    ]

def mermaid(rec: dict[str, Any], issues: list[dict[str, Any]]) -> str:
    rid = str(rec["id"])
    latest = _latest_evidence(rec)
    latest_label = _latest_summary(rec) or "no proof"
    lines = [f"%% Generated from .planning/journeys/records/{rid}.json", "flowchart TD", f'  promise["{_label(rec["human_promise"])}"]', f'  team["{_label(rec["accountable_team"])}"]', f'  latest["latest proof: {_label(latest_label)}"]', "  promise --> latest"]
    lines += _class_defs()
    lines += [f"  class latest {_class_for(latest.get('status'))}"]
    if priority_score(rec):
        lines += [f'  priority["priority score {priority_score(rec)}"]', "  priority --> promise"]
    for route in rec.get("route_paths", []):
        node = "route_" + _node(str(route))
        lines += [f'  {node}["{_label(route)}"]', f"  promise --> {node}", f"  {node} --> team", f"  class {node} route"]
    for surface in rec.get("surfaces", []):
        node = "surface_" + _node(str(surface))
        lines += [f'  {node}["{_label(surface)}"]', f"  promise -.-> {node}", f"  class {node} surface"]
    for api in rec.get("external_apis", []):
        node = "api_" + _node(str(api))
        lines += [f'  {node}["{_label(api)}"]', f"  promise -.-> {node}", f"  class {node} api"]
    for issue in issues:
        node = "issue_" + _node(str(issue.get("id", "")))
        label = f"{issue.get('id')} {issue.get('status')}/{issue.get('evidence_status')}"
        lines += [f'  {node}["{_label(label)}"]', f"  {node} --> promise", f"  class {node} {_class_for(issue.get('evidence_status'))}"]
    return "\n".join(lines) + "\n"

def system_map(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> str:
    grouped = _issues_for(records, issues)
    lines = ["%% Generated from .planning/journeys/records/*.json and issues/*.json", "flowchart LR"]
    lines += _class_defs()
    for rec in records:
        jid = "journey_" + _node(str(rec.get("id", "")))
        latest = _latest_evidence(rec)
        label = f"{rec.get('id')}<br/>{rec.get('status')}<br/>latest {latest.get('status', 'missing')}"
        lines += [f'  {jid}["{_label(label)}"]', f"  class {jid} {_class_for(latest.get('status') or rec.get('status'))}"]
        for route in rec.get("route_paths", []):
            route_node = "route_" + _node(str(route))
            lines += [f'  {route_node}["{_label(route)}"]', f"  {jid} --> {route_node}", f"  class {route_node} route"]
        for surface in rec.get("surfaces", []):
            surface_node = "surface_" + _node(str(surface))
            lines += [f'  {surface_node}["{_label(surface)}"]', f"  {jid} -.-> {surface_node}", f"  class {surface_node} surface"]
        for api in rec.get("external_apis", []):
            api_node = "api_" + _node(str(api))
            lines += [f'  {api_node}["{_label(api)}"]', f"  {jid} -.-> {api_node}", f"  class {api_node} api"]
        for issue in grouped.get(str(rec.get("id")), []):
            issue_node = "issue_" + _node(str(issue.get("id", "")))
            label = f"{issue.get('id')}<br/>{issue.get('status')}/{issue.get('evidence_status')}"
            lines += [f'  {issue_node}["{_label(label)}"]', f"  {issue_node} --> {jid}", f"  class {issue_node} {_class_for(issue.get('evidence_status'))}"]
    return "\n".join(dict.fromkeys(lines)) + "\n"

def expected(root: Path) -> dict[Path, str]:
    records = load_records(root)
    issues = load_issues(root)
    grouped = _issues_for(records, issues)
    out = {SUMMARY: markdown(records, issues), BOARD: board(records, issues), TODAY: today(records, issues), SYSTEM_MAP: system_map(records, issues)}
    out.update({DIAGRAMS / f"{rec['id']}.mmd": mermaid(rec, grouped.get(str(rec.get("id")), [])) for rec in records})
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
